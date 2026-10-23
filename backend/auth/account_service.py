"""Account deletion service.

Permanently deletes all data associated with a user across:
1. Cloudflare D1 (session_metrics, session_fillers, user_achievements)
2. MongoDB (users, sessions, slide_decks, achievements, user_emails, quotas, feedback)
3. Storage (audio recordings, slide renderings)
4. Firebase Auth user
"""
import logging
from typing import Dict, Any
from pathlib import Path
from firebase_admin import auth as fb_auth

from d1.d1_client import get_d1_client
from database.mongodb import (
    ACHIEVEMENTS_COL,
    FEEDBACK_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    USERS_COL,
    USER_EMAILS_COL,
    USER_QUOTAS_COL,
    get_db,
)
from firestore import get_bucket
from models import User
from slides.store import deck_store

logger = logging.getLogger(__name__)
AVATARS_DIR = Path("data/avatars")


def delete_user_account(user: User, db=None) -> Dict[str, Any]:
    """Permanently deletes user account from all stores."""
    user_id = user.id
    email = user.email.strip().lower() if user.email else ""
    mongo_db = db or get_db()
    results = {
        "user_id": user_id,
        "d1_deleted": False,
        "mongodb_deleted": False,
        "firestore_deleted": False,  # backwards-compatibility alias for test assertions
        "storage_deleted": False,
        "auth_deleted": False,
    }

    # 1. Cloudflare D1 deletion
    d1 = get_d1_client()
    if d1.is_configured:
        try:
            d1.batch([
                ("DELETE FROM session_fillers WHERE session_id IN (SELECT id FROM session_metrics WHERE user_id = ?);", [user_id]),
                ("DELETE FROM user_achievements WHERE user_id = ?;", [user_id]),
                ("DELETE FROM session_metrics WHERE user_id = ?;", [user_id]),
            ])
            results["d1_deleted"] = True
            logger.info("[account] Deleted D1 rows (fillers, metrics, achievements) for user %s.", user_id)
        except Exception as exc:
            logger.warning("[account] D1 deletion error for user %s: %s", user_id, exc)

    # 2. Storage deletion (Firebase Storage or local disk)
    try:
        bucket = get_bucket()
        if bucket is not None:
            # Delete audio files
            audio_blobs = list(bucket.list_blobs(prefix=f"audio/{user_id}/"))
            for blob in audio_blobs:
                try:
                    blob.delete()
                except Exception:
                    pass

            # Delete slide decks for user
            user_decks = deck_store.list_user_decks(user_id) if hasattr(deck_store, "list_user_decks") else []
            for deck in user_decks:
                deck_blobs = list(bucket.list_blobs(prefix=f"slides/{deck.id}/"))
                for blob in deck_blobs:
                    try:
                        blob.delete()
                    except Exception:
                        pass

            # Delete avatar images in Storage
            avatar_blobs = list(bucket.list_blobs(prefix=f"avatars/{user_id}"))
            for blob in avatar_blobs:
                try:
                    blob.delete()
                except Exception:
                    pass

            results["storage_deleted"] = True
            logger.info("[account] Deleted Storage blobs for user %s.", user_id)
    except Exception as exc:
        logger.warning("[account] Storage deletion notice for user %s: %s", user_id, exc)

    # 3. MongoDB deletion
    if mongo_db is not None:
        try:
            # Delete slide deck files via deck_store
            user_decks = deck_store.list_user_decks(user_id) if hasattr(deck_store, "list_user_decks") else []
            for d in user_decks:
                deck_store.delete(d.id)

            def _get_col(name: str):
                if hasattr(mongo_db, "collection"):
                    return mongo_db.collection(name)
                return mongo_db[name]

            # Collections cleanup in MongoDB
            for col_name in [SESSIONS_COL, SLIDE_DECKS_COL, ACHIEVEMENTS_COL, FEEDBACK_COL, USER_QUOTAS_COL]:
                col = _get_col(col_name)
                if hasattr(col, "delete_many"):
                    col.delete_many({"user_id": user_id})
                elif hasattr(col, "where"):
                    for doc in list(col.where("user_id", "==", user_id).stream()):
                        col.document(doc.id).delete()

            if email:
                col_emails = _get_col(USER_EMAILS_COL)
                if hasattr(col_emails, "delete_one"):
                    col_emails.delete_one({"email": email})
                elif hasattr(col_emails, "document"):
                    col_emails.document(email).delete()

            col_users = _get_col(USERS_COL)
            if hasattr(col_users, "delete_one"):
                col_users.delete_one({"$or": [{"id": user_id}, {"_id": user_id}]})
            elif hasattr(col_users, "document"):
                col_users.document(user_id).delete()

            results["mongodb_deleted"] = True
            results["firestore_deleted"] = True
            logger.info("[account] Deleted MongoDB docs for user %s.", user_id)
        except Exception as exc:
            logger.error("[account] MongoDB deletion error for user %s: %s", user_id, exc)

    # 4. Local avatar files on disk
    if AVATARS_DIR.exists():
        for existing in AVATARS_DIR.glob(f"{user_id}_*"):
            try:
                existing.unlink(missing_ok=True)
            except OSError:
                pass

    # 5. Firebase Auth user deletion
    try:
        fb_auth.delete_user(user_id)
        results["auth_deleted"] = True
        logger.info("[account] Deleted Firebase Auth user %s.", user_id)
    except Exception as exc:
        logger.info("[account] Firebase Auth delete notice (guest or non-firebase): %s", exc)

    return results
