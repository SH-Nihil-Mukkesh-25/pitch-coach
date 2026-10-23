"""Weekly rotating challenges for gamification.

Three weekly challenges:
1. "Zero Fillers Take": Complete a practice session with 0 filler words and duration >= 30s.
2. "Pacing Pro": Complete a session with WPM in 120-160 band and duration >= 30s.
3. "Consistency Streak": Complete at least 3 practice sessions in the current week.
"""
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
import hashlib
from typing import Any, Dict, List, Optional
import logging

from d1.d1_client import get_d1_client
from database.mongodb import get_db, SESSIONS_COL, USERS_COL

logger = logging.getLogger(__name__)


def get_current_week_start(now: Optional[datetime] = None) -> datetime:
    """Returns the Monday 00:00:00 UTC start of the current week."""
    dt = now or datetime.now(timezone.utc)
    start = dt - timedelta(days=dt.weekday())
    return start.replace(hour=0, minute=0, second=0, microsecond=0)


def get_current_week_id(now: Optional[datetime] = None) -> str:
    """Returns ISO format week identifier, e.g. 2026-W42."""
    dt = now or datetime.now(timezone.utc)
    year, week, _ = dt.isocalendar()
    return f"{year}-W{week:02d}"


CHALLENGE_DEFINITIONS = [
    {
        "id": "zero_fillers",
        "title": "Zero Fillers Take",
        "description": "Complete a session (min 30s) with 0 filler words.",
        "icon": "shield-check",
        "target": 1,
        "reward_points": 100,
    },
    {
        "id": "pacing_pro",
        "title": "Pacing Pro",
        "description": "Deliver a speech within the optimal 120-160 WPM pace band (min 30s).",
        "icon": "speed",
        "target": 1,
        "reward_points": 150,
    },
    {
        "id": "consistency_streak",
        "title": "Consistency Streak",
        "description": "Complete 3 practice sessions during this week.",
        "icon": "calendar-check",
        "target": 3,
        "reward_points": 200,
    },
]


def evaluate_user_challenges(
    user_id: str,
    claimed_set: Optional[set] = None,
    week_start: Optional[datetime] = None,
    d1_client=None,
    db=None,
) -> List[Dict[str, Any]]:
    """Evaluates weekly rotating challenges for a user."""
    start_dt = week_start or get_current_week_start()
    start_iso = start_dt.isoformat()
    claimed = claimed_set or set()

    d1 = d1_client or get_d1_client()
    mongo_db = db or get_db()

    sessions: List[Dict[str, Any]] = []

    # 1. Try D1 query
    if d1.is_configured:
        try:
            rows = d1.query(
                """
                SELECT id, duration_seconds, wpm, filler_word_count, created_at
                FROM session_metrics
                WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL AND created_at >= ?;
                """,
                [user_id, start_iso],
            )
            for r in rows:
                sessions.append({
                    "duration_seconds": float(r.get("duration_seconds") or 0),
                    "wpm": float(r.get("wpm") or 0),
                    "filler_word_count": int(r.get("filler_word_count") or 0),
                })
        except Exception as e:
            logger.warning("[challenges] D1 query failed: %s, falling back to MongoDB", e)
            sessions = []

    # 2. MongoDB fallback if D1 not available or empty and database exists
    if not sessions and mongo_db:
        try:
            docs = (
                mongo_db.collection(SESSIONS_COL)
                .where("user_id", "==", user_id)
                .where("is_analyzed", "==", True)
                .get()
            )
            for d in docs:
                data = d.to_dict()
                if data.get("analysis_failed"):
                    continue
                c_at = data.get("created_at")
                if isinstance(c_at, str):
                    try:
                        c_dt = datetime.fromisoformat(c_at.replace("Z", "+00:00"))
                    except Exception:
                        c_dt = None
                elif isinstance(c_at, datetime):
                    c_dt = c_at
                else:
                    c_dt = None

                if c_dt and c_dt >= start_dt:
                    sessions.append({
                        "duration_seconds": float(data.get("duration_seconds") or 0),
                        "wpm": float(data.get("wpm") or 0),
                        "filler_word_count": int(data.get("filler_word_count") or 0),
                    })
        except Exception as e:
            logger.warning("[challenges] Firestore fallback error: %s", e)

    # Calculate metrics
    zero_fillers_count = sum(
        1 for s in sessions
        if s["duration_seconds"] >= 30 and s["filler_word_count"] == 0
    )
    pacing_pro_count = sum(
        1 for s in sessions
        if s["duration_seconds"] >= 30 and 120 <= s["wpm"] <= 160
    )
    total_sessions_count = len(sessions)

    results = []
    for c_def in CHALLENGE_DEFINITIONS:
        cid = c_def["id"]
        target = c_def["target"]
        if cid == "zero_fillers":
            current = zero_fillers_count
        elif cid == "pacing_pro":
            current = pacing_pro_count
        elif cid == "consistency_streak":
            current = total_sessions_count
        else:
            current = 0

        is_completed = current >= target
        is_claimed = cid in claimed

        results.append({
            "id": cid,
            "title": c_def["title"],
            "description": c_def["description"],
            "icon": c_def["icon"],
            "current_progress": min(current, target),
            "target": target,
            "is_completed": is_completed,
            "is_claimed": is_claimed,
            "reward_points": c_def["reward_points"],
        })

    return results
