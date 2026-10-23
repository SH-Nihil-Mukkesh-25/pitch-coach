"""Achievement evaluation service.

Evaluates unlock rules after each analyzed session using D1 queries,
upserts into user_achievements (which sync down via /metrics/changes),
and maintains Firestore achievements in sync.
"""
from datetime import datetime, timezone
import logging
from typing import Dict, List, Optional
import uuid

from d1.d1_client import get_d1_client
from database.mongodb import get_db, SESSIONS_COL, ACHIEVEMENTS_COL
from models import Achievement, PracticeSession

logger = logging.getLogger(__name__)


def evaluate_user_achievements(
    user_id: str,
    d1_client=None,
    db=None,
) -> List[str]:
    """Evaluates achievement unlock criteria for user_id.

    Returns a list of newly unlocked achievement keys.
    """
    if not user_id or user_id in ("guest", "demo-guest"):
        return []

    d1 = d1_client or get_d1_client()
    mongo_db = db or get_db()
    newly_unlocked: List[str] = []
    now_iso = datetime.now(timezone.utc).isoformat()

    if d1.is_configured:
        try:
            # 1. Fetch already unlocked achievements from D1
            existing_rows = d1.query(
                "SELECT achievement_key FROM user_achievements WHERE user_id = ?;",
                [user_id],
            )
            unlocked_set = {r["achievement_key"] for r in existing_rows}

            # 2. Check first_session & 50_sessions
            count_rows = d1.query(
                "SELECT COUNT(*) AS total FROM session_metrics WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL;",
                [user_id],
            )
            total_sessions = int(count_rows[0]["total"]) if count_rows else 0

            if total_sessions >= 1 and "first_session" not in unlocked_set:
                newly_unlocked.append("first_session")
            if total_sessions >= 50 and "50_sessions" not in unlocked_set:
                newly_unlocked.append("50_sessions")

            # 3. Check clarity_master (clarity_score >= 85)
            if "clarity_master" not in unlocked_set:
                clarity_rows = d1.query(
                    "SELECT 1 FROM session_metrics WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL AND clarity_score >= 85 LIMIT 1;",
                    [user_id],
                )
                if clarity_rows:
                    newly_unlocked.append("clarity_master")

            # 4. Check early_bird (session before 8:00 AM local time)
            if "early_bird" not in unlocked_set:
                early_rows = d1.query(
                    """
                    SELECT 1 FROM session_metrics
                    WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
                      AND (((CAST(strftime('%H', created_at) AS INTEGER) * 60 + CAST(strftime('%M', created_at) AS INTEGER) + tz_offset_minutes + 1440) % 1440) < 480)
                    LIMIT 1;
                    """,
                    [user_id],
                )
                if early_rows:
                    newly_unlocked.append("early_bird")

            # 5. Check 7_day_streak
            if "7_day_streak" not in unlocked_set:
                streak_sql = """
                WITH d AS (
                  SELECT DISTINCT local_date FROM session_metrics
                  WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
                ), g AS (
                  SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
                )
                SELECT MAX(streak) AS max_streak FROM (
                  SELECT COUNT(*) AS streak FROM g GROUP BY grp
                );
                """
                streak_rows = d1.query(streak_sql, [user_id])
                max_streak = int(streak_rows[0]["max_streak"] or 0) if streak_rows and streak_rows[0].get("max_streak") is not None else 0
                if max_streak >= 7:
                    newly_unlocked.append("7_day_streak")

            # 6. Upsert newly unlocked into D1
            if newly_unlocked:
                upsert_stmts = [
                    (
                        """
                        INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at)
                        VALUES (?, ?, ?, ?)
                        ON CONFLICT(user_id, achievement_key) DO UPDATE SET
                          updated_at = excluded.updated_at;
                        """,
                        [user_id, key, now_iso, now_iso],
                    )
                    for key in newly_unlocked
                ]
                d1.batch(upsert_stmts)
                logger.info("[achievements] Unlocked %s for user %s in D1.", newly_unlocked, user_id)

                # Also sync to MongoDB for consistency
                if mongo_db:
                    for key in newly_unlocked:
                        ach = Achievement(
                            id=str(uuid.uuid4()),
                            user_id=user_id,
                            key=key,
                            unlocked_at=datetime.now(timezone.utc),
                            criteria_met={"d1_evaluated": True},
                        )
                        mongo_db.collection(ACHIEVEMENTS_COL).document(ach.id).set(ach.to_dict())

            return newly_unlocked

        except Exception as exc:
            logger.warning("[achievements] D1 evaluation failed: %s. Falling back to MongoDB evaluation.", exc)

    # Fallback to MongoDB evaluation if D1 is not configured or failed
    try:
        session_docs = (
            mongo_db.collection(SESSIONS_COL)
            .where("user_id", "==", user_id)
            .where("is_analyzed", "==", True)
            .get()
        )
        sessions = [PracticeSession.from_dict(d.to_dict()) for d in session_docs]
        sessions = [s for s in sessions if not s.analysis_failed]

        ach_docs = (
            mongo_db.collection(ACHIEVEMENTS_COL)
            .where("user_id", "==", user_id)
            .get()
        )
        existing_keys = {d.to_dict().get("key") for d in ach_docs}

        # Check definitions
        if len(sessions) >= 1 and "first_session" not in existing_keys:
            newly_unlocked.append("first_session")
        if len(sessions) >= 50 and "50_sessions" not in existing_keys:
            newly_unlocked.append("50_sessions")
        if any((s.clarity_score or 0) >= 85 for s in sessions) and "clarity_master" not in existing_keys:
            newly_unlocked.append("clarity_master")
        if any(s.created_at.hour < 8 for s in sessions) and "early_bird" not in existing_keys:
            newly_unlocked.append("early_bird")

        # Streak check
        dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
        if dates and "7_day_streak" not in existing_keys:
            streak, prev = 1, dates[0]
            max_s = 1
            for d in dates[1:]:
                if (prev - d).days == 1:
                    streak += 1
                    max_s = max(max_s, streak)
                    prev = d
                else:
                    streak, prev = 1, d
            if max_s >= 7:
                newly_unlocked.append("7_day_streak")

        for key in newly_unlocked:
            ach = Achievement(
                id=str(uuid.uuid4()),
                user_id=user_id,
                key=key,
                unlocked_at=datetime.now(timezone.utc),
                criteria_met={"session_count": len(sessions)},
            )
            mongo_db.collection(ACHIEVEMENTS_COL).document(ach.id).set(ach.to_dict())

        return newly_unlocked

    except Exception as exc:
        logger.error("[achievements] MongoDB evaluation fallback error: %s", exc)
        return []
