"""Daily quota management using MongoDB user_quotas collection."""
import logging
from datetime import datetime, timezone
from fastapi import HTTPException, status
from pymongo import ReturnDocument
from database.mongodb import USER_QUOTAS_COL, get_mongo_db, get_db

logger = logging.getLogger(__name__)


def check_and_increment_daily_quota(user_id: str, feature: str, limit: int) -> int:
    """
    Checks and increments daily usage counter for a user and feature.
    Throws HTTP 429 if limit is exceeded.
    Returns the new counter value.
    """
    if limit <= 0:
        return 0
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    doc_id = f"{user_id}_{feature}_{today_str}"

    db = get_mongo_db()
    if db is None:
        return 0

    try:
        col = db[USER_QUOTAS_COL]
        # Check current count first
        doc = col.find_one({"doc_id": doc_id})
        current_count = int(doc.get("count", 0)) if doc else 0

        if current_count >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Daily quota exceeded: you have reached the maximum of {limit} {feature} per day.",
            )

        updated = col.find_one_and_update(
            {"doc_id": doc_id},
            {
                "$inc": {"count": 1},
                "$setOnInsert": {
                    "doc_id": doc_id,
                    "id": doc_id,
                    "user_id": user_id,
                    "feature": feature,
                    "date": today_str,
                },
                "$set": {
                    "updated_at": datetime.now(timezone.utc),
                },
            },
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return int(updated.get("count", current_count + 1)) if updated else current_count + 1
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Could not update daily quota for %s (%s): %s", user_id, feature, exc)
        return 0
