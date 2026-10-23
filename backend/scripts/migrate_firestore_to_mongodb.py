"""
Firestore to MongoDB Migration Script.

Migrates all collections from Google Cloud Firestore into MongoDB:
- users
- user_emails
- sessions
- slide_decks
- achievements
- user_quotas
- feedback

Usage:
    python scripts/migrate_firestore_to_mongodb.py [--dry-run]
"""
import argparse
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

import firebase_admin
from firebase_admin import credentials, firestore

from config import get_settings
from database.mongodb import (
    ACHIEVEMENTS_COL,
    FEEDBACK_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    USERS_COL,
    USER_EMAILS_COL,
    USER_QUOTAS_COL,
    get_mongo_db,
    init_db_indexes,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

ALL_COLLECTIONS = [
    USERS_COL,
    USER_EMAILS_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    ACHIEVEMENTS_COL,
    USER_QUOTAS_COL,
    FEEDBACK_COL,
]


def init_firestore():
    """Initializes and returns Firestore client."""
    settings = get_settings()
    cred_path = settings.FIREBASE_SERVICE_ACCOUNT_PATH
    if not cred_path:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_PATH is not configured in settings/.env")

    try:
        cred = credentials.Certificate(cred_path)
        try:
            app = firebase_admin.get_app()
        except ValueError:
            app = firebase_admin.initialize_app(cred)
        return firestore.client(app=app)
    except Exception as exc:
        logger.error("Could not initialize Firestore client: %s", exc)
        return None


def migrate_collection(fs_client, mongo_db, collection_name: str, dry_run: bool = False) -> int:
    """Migrates all documents from a Firestore collection into MongoDB."""
    logger.info("Starting migration for collection: '%s'...", collection_name)
    fs_col = fs_client.collection(collection_name)
    mongo_col = mongo_db[collection_name]

    count = 0
    try:
        docs = list(fs_col.stream())
        logger.info("Found %d documents in Firestore collection '%s'.", len(docs), collection_name)

        for doc in docs:
            data = doc.to_dict() or {}
            doc_id = doc.id
            data["id"] = data.get("id") or doc_id
            data["_id"] = doc_id

            if collection_name == USERS_COL and data.get("email") is None:
                data.pop("email", None)

            if not dry_run:
                mongo_col.update_one(
                    {"_id": doc_id},
                    {"$set": data},
                    upsert=True,
                )
            count += 1

        logger.info("Successfully migrated %d documents for '%s'%s.", count, collection_name, " (DRY RUN)" if dry_run else "")
    except Exception as exc:
        logger.error("Error migrating collection '%s': %s", collection_name, exc)

    return count


def main():
    parser = argparse.ArgumentParser(description="Migrate Firestore collections to MongoDB")
    parser.add_argument("--dry-run", action="store_true", help="Inspect documents without writing to MongoDB")
    parser.add_argument("--collection", type=str, default=None, help="Migrate a specific collection only")
    args = parser.parse_args()

    mongo_db = get_mongo_db()
    init_db_indexes(mongo_db)
    logger.info("Target MongoDB database: '%s'", mongo_db.raw.name)

    fs_client = init_firestore()
    if not fs_client:
        logger.warning("Firestore client could not be connected. Verifying MongoDB readiness only.")
        logger.info("MongoDB collections available: %s", mongo_db.list_collection_names())
        return

    targets = [args.collection] if args.collection else ALL_COLLECTIONS
    summary: Dict[str, int] = {}

    for col in targets:
        count = migrate_collection(fs_client, mongo_db, col, dry_run=args.dry_run)
        summary[col] = count

    logger.info("=== Migration Summary ===")
    total = 0
    for col, cnt in summary.items():
        logger.info(" - %s: %d documents", col, cnt)
        total += cnt
    logger.info("Total documents migrated: %d%s", total, " (DRY RUN)" if args.dry_run else "")


if __name__ == "__main__":
    main()
