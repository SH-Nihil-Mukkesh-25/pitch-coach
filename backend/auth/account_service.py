"""Account deletion service.

Permanently deletes all data associated with a user across:
1. Cloudflare D1 (session_metrics, session_fillers, user_achievements)
2. Firebase Firestore (users, sessions, slide_decks, achievements, user_emails)
3. Firebase Storage (audio recordings, slide renderings)
4. Firebase Auth user
"""
import logging
from typing import Dict, Any

from pathlib import Path
from firebase_admin import auth as fb_auth
from d1.d1_client import get_d1_client
from firestore import get_bucket, get_db
from models import (
    ACHIEVEMENTS_COL,
    FEEDBACK_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    USERS_COL,
    User,
)
from slides.store import deck_store

logger = logging.getLogger(__name__)
USER_EMAILS_COL = "user_emails"
AVATARS_DIR = Path("data/avatars")


def delete_user_account(user: User, db=None) -> Dict[str, Any]:
    """Permanently deletes user account from all stores."""
    user_id = user.id
    email = user.email.strip().lower() if user.email else ""
    firestore_db = db or get_db()
    results = {
        "user_id": user_id,
        "d1_deleted": False,
        "firestore_deleted": False,
        "storage_deleted": False,
        "auth_deleted": False,
    }

    # 1. Cloudflare D1 deletion (fillers first to respect foreign keys, then metrics, then achievements)
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

    # 2. Firebase Storage deletion
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

    # 3. Firestore deletion
    if firestore_db is not None:
        try:
            # Sessions
            sessions = firestore_db.collection(SESSIONS_COL).where("user_id", "==", user_id).stream()
            for s in sessions:
                firestore_db.collection(SESSIONS_COL).document(s.id).delete()

            # Slide Decks
            decks = firestore_db.collection(SLIDE_DECKS_COL).where("user_id", "==", user_id).stream()
            for d in decks:
                deck_store.delete(d.id)

            # Achievements
            achievements = firestore_db.collection(ACHIEVEMENTS_COL).where("user_id", "==", user_id).stream()
            for a in achievements:
                firestore_db.collection(ACHIEVEMENTS_COL).document(a.id).delete()

            # Feedback submitted by user
            feedbacks = firestore_db.collection(FEEDBACK_COL).where("user_id", "==", user_id).stream()
            for f in feedbacks:
                firestore_db.collection(FEEDBACK_COL).document(f.id).delete()

            # Email reservation
            if email:
                firestore_db.collection(USER_EMAILS_COL).document(email).delete()

            # User document
            firestore_db.collection(USERS_COL).document(user_id).delete()

            results["firestore_deleted"] = True
            logger.info("[account] Deleted Firestore docs for user %s.", user_id)
        except Exception as exc:
            logger.error("[account] Firestore deletion error for user %s: %s", user_id, exc)

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
