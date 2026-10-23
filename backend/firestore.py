"""
Database and Storage client accessors for Pitch Coach backend.

NOTE: All document storage has migrated from Google Cloud Firestore to MongoDB!
`get_db()` returns the thread-safe MongoDB database wrapper.
`get_bucket()` continues to provide Firebase Storage bucket access for audio/image blobs if configured.
"""
import logging
import os
import firebase_admin
from firebase_admin import credentials, storage
from config import get_settings
from database.mongodb import get_db, get_mongo_db, MongoDatabaseWrapper

logger = logging.getLogger(__name__)
_app: firebase_admin.App | None = None


def _init_app() -> None:
    global _app
    if _app is not None or firebase_admin._apps:
        return
    settings = get_settings()
    if not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        logger.warning("[firebase] FIREBASE_SERVICE_ACCOUNT_PATH not set in config.")
        return
    if not os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT_PATH):
        logger.warning("[firebase] Service account file not found at: %s", settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        return
    try:
        cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        options = {"storageBucket": settings.FIREBASE_STORAGE_BUCKET} if settings.FIREBASE_STORAGE_BUCKET else None
        _app = firebase_admin.initialize_app(cred, options)
        logger.info("[firebase] Firebase Admin SDK successfully initialized.")
    except Exception as exc:
        logger.error("[firebase] Failed to initialize Firebase Admin SDK: %s", exc)


# Initialize Firebase Admin on module load
_init_app()
init_firebase = _init_app


def get_bucket():
    """Returns the default Firebase Storage bucket (audio recordings)."""
    _init_app()
    if not get_settings().FIREBASE_STORAGE_BUCKET:
        raise RuntimeError("FIREBASE_STORAGE_BUCKET is not set in backend/.env")
    return storage.bucket()
