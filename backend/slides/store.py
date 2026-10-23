"""Storage layer for slide decks: MongoDB persistence with local disk image cache and Firebase Storage integration."""
import json
import logging
import os
import shutil
from collections import OrderedDict
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from config import get_settings
from database.mongodb import SLIDE_DECKS_COL, get_mongo_db, get_db
from firestore import get_bucket
from models import SlideDeck

logger = logging.getLogger(__name__)

MAX_CACHE_SIZE = 100
STUCK_CUTOFF_SECONDS = 600  # 10 minutes


class DeckStore:
    """Manages slide deck persistence across MongoDB, Storage, and local storage."""

    def __init__(self):
        self.settings = get_settings()
        self.base_dir = self.settings.SLIDE_DECK_DIR
        os.makedirs(self.base_dir, exist_ok=True)
        # In-memory LRU cache for hot status updates (bounded to 100 entries)
        self._memory_cache: OrderedDict[str, SlideDeck] = OrderedDict()

    def get_deck_dir(self, deck_id: str) -> str:
        d = os.path.join(self.base_dir, deck_id)
        os.makedirs(d, exist_ok=True)
        return d

    def get_slides_dir(self, deck_id: str) -> str:
        d = os.path.join(self.get_deck_dir(deck_id), "slides")
        os.makedirs(d, exist_ok=True)
        return d

    def get_slide_image_path(self, deck_id: str, slide_number: int) -> str:
        return os.path.join(self.get_slides_dir(deck_id), f"slide_{slide_number}.jpg")

    def upload_slide_images_to_storage(self, deck_id: str, image_paths: List[str]) -> None:
        """Optionally uploads slide images to Firebase Storage bucket if configured."""
        if not self.settings.FIREBASE_STORAGE_BUCKET:
            return
        try:
            bucket = get_bucket()
            for path in image_paths:
                if not os.path.exists(path):
                    continue
                filename = os.path.basename(path)
                blob_path = f"slides/{deck_id}/{filename}"
                blob = bucket.blob(blob_path)
                blob.upload_from_filename(path, content_type="image/jpeg")
            logger.info("Successfully uploaded %d slide images for deck %s to storage", len(image_paths), deck_id)
        except Exception as e:
            logger.warning("Could not upload slide images for deck %s to storage: %s", deck_id, e)

    def _update_cache(self, deck: SlideDeck) -> None:
        self._memory_cache[deck.id] = deck
        self._memory_cache.move_to_end(deck.id)
        if len(self._memory_cache) > MAX_CACHE_SIZE:
            self._memory_cache.popitem(last=False)

    def check_and_mark_stuck(self, deck: SlideDeck, cutoff_seconds: int = STUCK_CUTOFF_SECONDS) -> bool:
        """If deck is stuck in processing for > cutoff_seconds, mark it failed."""
        if deck.status == "processing":
            now = datetime.now(timezone.utc)
            delta = (now - deck.updated_at).total_seconds()
            if delta > cutoff_seconds:
                logger.warning(
                    "Deck %s has been stuck in processing for %.1fs. Marking as failed.",
                    deck.id, delta,
                )
                deck.status = "failed"
                deck.error = "Processing timed out"
                deck.failure_reason = "Processing timed out"
                self.save(deck)
                return True
        return False

    def save(self, deck: SlideDeck) -> None:
        """Persist to LRU cache, local metadata.json, and MongoDB."""
        deck.updated_at = datetime.now(timezone.utc)
        self._update_cache(deck)

        # 1. Local backup JSON
        try:
            deck_dir = self.get_deck_dir(deck.id)
            meta_path = os.path.join(deck_dir, "metadata.json")
            with open(meta_path, "w", encoding="utf-8") as f:
                d = deck.to_dict()
                d["created_at"] = deck.created_at.isoformat()
                d["updated_at"] = deck.updated_at.isoformat()
                json.dump(d, f, indent=2)
        except Exception as e:
            logger.warning("Could not save local deck metadata for %s: %s", deck.id, e)

        # 2. MongoDB document (single source of truth - propagates write errors)
        try:
            db = get_mongo_db()
            if db is not None:
                payload = deck.to_dict()
                payload["id"] = deck.id
                payload["_id"] = deck.id
                db[SLIDE_DECKS_COL].update_one(
                    {"$or": [{"id": deck.id}, {"_id": deck.id}]},
                    {"$set": payload},
                    upsert=True,
                )
        except Exception as e:
            logger.error("MongoDB save failed for deck %s: %s", deck.id, e)
            raise e

    def get(self, deck_id: str) -> Optional[SlideDeck]:
        """Fetch deck by ID from memory, MongoDB, or disk."""
        deck: Optional[SlideDeck] = None

        # 1. Memory cache
        if deck_id in self._memory_cache:
            deck = self._memory_cache[deck_id]
            self._memory_cache.move_to_end(deck_id)
        else:
            # 2. MongoDB
            try:
                db = get_mongo_db()
                if db is not None:
                    doc = db[SLIDE_DECKS_COL].find_one({"$or": [{"id": deck_id}, {"_id": deck_id}]})
                    if doc:
                        deck = SlideDeck.from_dict(doc)
                        self._update_cache(deck)
            except Exception as e:
                logger.warning("MongoDB get failed for deck %s: %s", deck_id, e)

            # 3. Local disk fallback
            if deck is None:
                try:
                    meta_path = os.path.join(self.base_dir, deck_id, "metadata.json")
                    if os.path.exists(meta_path):
                        with open(meta_path, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            if isinstance(data.get("created_at"), str):
                                data["created_at"] = datetime.fromisoformat(data["created_at"])
                            if isinstance(data.get("updated_at"), str):
                                data["updated_at"] = datetime.fromisoformat(data["updated_at"])
                            deck = SlideDeck.from_dict(data)
                            self._update_cache(deck)
                except Exception as e:
                    logger.warning("Disk fallback load failed for deck %s: %s", deck_id, e)

        if deck is not None:
            self.check_and_mark_stuck(deck)

        return deck

    def find_by_hash(self, user_id: str, content_hash: str) -> Optional[SlideDeck]:
        """Find an already-completed deck by user_id and SHA-256 hash."""
        # Memory check
        for deck in self._memory_cache.values():
            if deck.user_id == user_id and deck.content_hash == content_hash and deck.status == "done":
                return deck

        # MongoDB check
        try:
            db = get_mongo_db()
            if db is not None:
                doc = db[SLIDE_DECKS_COL].find_one({
                    "user_id": user_id,
                    "content_hash": content_hash,
                    "status": "done",
                })
                if doc:
                    deck = SlideDeck.from_dict(doc)
                    self._update_cache(deck)
                    return deck
        except Exception as e:
            logger.warning("MongoDB query by hash failed: %s", e)

        return None

    def list_user_decks(self, user_id: str) -> List[SlideDeck]:
        """List all slide decks for a user."""
        decks = []
        try:
            db = get_mongo_db()
            if db is not None:
                cursor = db[SLIDE_DECKS_COL].find({"user_id": user_id}).sort("created_at", -1)
                for doc in cursor:
                    decks.append(SlideDeck.from_dict(doc))
        except Exception as e:
            logger.warning("MongoDB list_user_decks failed: %s", e)

        # Fallback to local memory if mongodb failed or returned empty
        if not decks:
            decks = [d for d in self._memory_cache.values() if d.user_id == user_id]

        # Also inspect local disk if memory has nothing
        if not decks and os.path.exists(self.base_dir):
            try:
                for entry in os.listdir(self.base_dir):
                    meta_path = os.path.join(self.base_dir, entry, "metadata.json")
                    if os.path.exists(meta_path):
                        with open(meta_path, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            if data.get("user_id") == user_id:
                                decks.append(SlideDeck.from_dict(data))
            except Exception as e:
                logger.warning("Local disk deck listing fallback error: %s", e)

        decks.sort(key=lambda d: d.created_at, reverse=True)
        return decks

    def delete(self, deck_id: str) -> bool:
        """Delete from memory, MongoDB, Storage, and local files."""
        self._memory_cache.pop(deck_id, None)

        # Remove local disk files
        try:
            deck_dir = os.path.join(self.base_dir, deck_id)
            if os.path.exists(deck_dir):
                shutil.rmtree(deck_dir, ignore_errors=True)
        except Exception as e:
            logger.warning("Failed to delete local dir for deck %s: %s", deck_id, e)

        # Remove from Storage if bucket configured
        if self.settings.FIREBASE_STORAGE_BUCKET:
            try:
                bucket = get_bucket()
                blobs = bucket.list_blobs(prefix=f"slides/{deck_id}/")
                for blob in blobs:
                    blob.delete()
            except Exception as e:
                logger.warning("Failed to delete Storage blobs for deck %s: %s", deck_id, e)

        # Remove MongoDB doc
        try:
            db = get_mongo_db()
            if db is not None:
                db[SLIDE_DECKS_COL].delete_one({"$or": [{"id": deck_id}, {"_id": deck_id}]})
            return True
        except Exception as e:
            logger.warning("MongoDB delete failed for deck %s: %s", deck_id, e)
            return False

    def sweep_stuck_decks(self, cutoff_seconds: int = STUCK_CUTOFF_SECONDS) -> int:
        """Finds all decks in processing state exceeding cutoff_seconds and marks them failed."""
        cutoff = datetime.now(timezone.utc) - timedelta(seconds=cutoff_seconds)
        count = 0

        # 1. Sweep memory
        for deck in list(self._memory_cache.values()):
            if deck.status == "processing" and deck.updated_at < cutoff:
                deck.status = "failed"
                deck.error = "Processing timed out (sweeper)"
                deck.failure_reason = "Processing timed out"
                self.save(deck)
                count += 1

        # 2. Sweep MongoDB
        try:
            db = get_mongo_db()
            if db is not None:
                res = db[SLIDE_DECKS_COL].update_many(
                    {"status": "processing", "updated_at": {"$lt": cutoff}},
                    {"$set": {
                        "status": "failed",
                        "error": "Processing timed out (sweeper)",
                        "failure_reason": "Processing timed out",
                        "updated_at": datetime.now(timezone.utc),
                    }}
                )
                count += res.modified_count
        except Exception as e:
            logger.warning("Error sweeping stuck decks from MongoDB: %s", e)

        return count

    def cleanup_expired(self, ttl_days: Optional[int] = None) -> int:
        """Delete decks older than TTL days (bounded between 1 and 365)."""
        ttl = ttl_days if ttl_days is not None else self.settings.SLIDE_DECK_TTL_DAYS
        ttl = max(1, min(365, ttl))
        cutoff = datetime.now(timezone.utc) - timedelta(days=ttl)
        deleted_ids = set()

        # 1. Scan local directories
        if os.path.exists(self.base_dir):
            for deck_id in os.listdir(self.base_dir):
                deck_path = os.path.join(self.base_dir, deck_id)
                if not os.path.isdir(deck_path):
                    continue
                deck = self.get(deck_id)
                if deck is not None:
                    if deck.created_at < cutoff:
                        self.delete(deck_id)
                        deleted_ids.add(deck_id)
                else:
                    # Orphaned folder with no metadata/MongoDB doc
                    try:
                        mtime = datetime.fromtimestamp(os.path.getmtime(deck_path), tz=timezone.utc)
                        if mtime < cutoff:
                            shutil.rmtree(deck_path, ignore_errors=True)
                            deleted_ids.add(deck_id)
                    except Exception as e:
                        logger.warning("Error checking orphaned folder %s: %s", deck_path, e)

        # 2. Check expired MongoDB decks that may not have local folders
        try:
            db = get_mongo_db()
            if db is not None:
                docs = db[SLIDE_DECKS_COL].find({"created_at": {"$lt": cutoff}})
                for doc in docs:
                    deck_id = doc.get("id") or str(doc.get("_id"))
                    if deck_id not in deleted_ids:
                        self.delete(deck_id)
                        deleted_ids.add(deck_id)
        except Exception as e:
            logger.warning("Error querying expired decks from MongoDB: %s", e)

        return len(deleted_ids)


# Singleton instance
deck_store = DeckStore()
