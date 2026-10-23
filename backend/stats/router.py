"""Stats endpoints: summary, trend chart, skill breakdown, and streak.

Architecture:
- Flat numeric metrics read from Cloudflare D1
- Trends and streaks group by local_date (user's local day)
- Fallback to Firestore aggregation queries (count(), avg()) if D1 is unreachable
"""
from collections import defaultdict
from datetime import datetime, timedelta, timezone
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Query

from auth.dependencies import get_current_user
from d1.d1_client import D1Error, get_d1_client
from database.mongodb import get_db, MongoDatabaseWrapper, SESSIONS_COL
from models import PracticeSession, User
from schemas import SkillBreakdown, StatsSummary, StreakResponse, TrendPoint

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stats", tags=["stats"])


# ─────────────────────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────────────────────

def _get_user_local_dates(tz_offset_minutes: int) -> tuple[str, str]:
    """Returns (today, yesterday) in 'YYYY-MM-DD' formatted strings for the user's timezone."""
    now_local = datetime.now(timezone.utc) + timedelta(minutes=tz_offset_minutes)
    today = now_local.strftime("%Y-%m-%d")
    yesterday = (now_local - timedelta(days=1)).strftime("%Y-%m-%d")
    return today, yesterday


def _streak_from_dates(dates: List[str], today: str, yesterday: str) -> int:
    """Computes active streak from ordered distinct local_date strings (descending)."""
    if not dates:
        return 0
    unique_dates = sorted(set(dates), reverse=True)
    if not unique_dates:
        return 0
    # Streak is active only if most recent practice was today or yesterday
    if unique_dates[0] not in (today, yesterday):
        return 0
    streak = 0
    expected = unique_dates[0]
    expected_dt = datetime.strptime(expected, "%Y-%m-%d").date()
    for d_str in unique_dates:
        curr_dt = datetime.strptime(d_str, "%Y-%m-%d").date()
        if curr_dt == expected_dt:
            streak += 1
            expected_dt -= timedelta(days=1)
        elif curr_dt < expected_dt:
            break
    return streak


def _streak(sessions: List[PracticeSession]) -> int:
    """Count consecutive days with at least one session (from today backwards)."""
    if not sessions:
        return 0
    dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
    today = datetime.now(timezone.utc).date()
    streak = 0
    expected = today if today in dates else today - timedelta(days=1)
    for d in dates:
        if d == expected:
            streak += 1
            expected -= timedelta(days=1)
        elif d < expected:
            break
    return streak


def _filler_reduction(sessions: List[PracticeSession]) -> float:
    """Percentage improvement in filler count between first half and second half of sessions."""
    if len(sessions) < 2:
        return 0.0
    ordered = sorted(sessions, key=lambda s: s.created_at)
    half = max(1, len(ordered) // 2)
    old_avg = sum((s.filler_word_count or 0) for s in ordered[:half]) / half
    new_avg = sum((s.filler_word_count or 0) for s in ordered[half:]) / max(len(ordered) - half, 1)
    if old_avg == 0:
        return 0.0
    return round((old_avg - new_avg) / old_avg * 100.0, 1)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/summary", response_model=StatsSummary)
def get_summary(
    days: Optional[int] = Query(None, ge=1, le=365),
    tz_offset_minutes: int = Query(330, description="User timezone offset in minutes (default +330 IST)"),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns summary stats for dashboard reading from D1 with Firestore fallback."""
    d1 = get_d1_client()
    today, yesterday = _get_user_local_dates(tz_offset_minutes)

    if d1.is_configured:
        try:
            # 1. Summary query
            summary_sql = """
            SELECT COUNT(*) AS total_sessions,
                   ROUND(AVG(overall_score), 1) AS avg_score,
                   ROUND(AVG(wpm), 1) AS avg_wpm,
                   ROUND(AVG(clarity_score), 1) AS avg_clarity,
                   ROUND(AVG(confidence_score), 1) AS avg_confidence,
                   ROUND(SUM(duration_seconds), 1) AS total_duration
            FROM session_metrics
            WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL;
            """
            rows = d1.query(summary_sql, [current_user.id])
            if rows and rows[0].get("total_sessions", 0) > 0:
                total_sessions = int(rows[0]["total_sessions"])
                avg_confidence = float(rows[0].get("avg_confidence") or 0.0)
                avg_score = float(rows[0]["avg_score"]) if rows[0].get("avg_score") is not None else None
                avg_wpm = float(rows[0]["avg_wpm"]) if rows[0].get("avg_wpm") is not None else None
                avg_clarity = float(rows[0]["avg_clarity"]) if rows[0].get("avg_clarity") is not None else None
                total_duration = float(rows[0]["total_duration"]) if rows[0].get("total_duration") is not None else None

                # 2. Gaps-and-islands streak query
                streak_sql = """
                WITH d AS (
                  SELECT DISTINCT local_date FROM session_metrics
                  WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
                ), g AS (
                  SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
                )
                SELECT COUNT(*) AS streak, MAX(local_date) AS last_day
                FROM g GROUP BY grp ORDER BY last_day DESC LIMIT 1;
                """
                streak_rows = d1.query(streak_sql, [current_user.id])
                streak_days = 0
                if streak_rows and streak_rows[0].get("last_day"):
                    last_day = streak_rows[0]["last_day"]
                    if last_day in (today, yesterday):
                        streak_days = int(streak_rows[0].get("streak") or 0)

                # 3. Filler reduction query
                filler_sql = """
                WITH ordered AS (
                  SELECT filler_word_count,
                         ROW_NUMBER() OVER (ORDER BY created_at ASC) AS rn,
                         COUNT(*) OVER () AS total_count
                  FROM session_metrics
                  WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
                )
                SELECT
                  AVG(CASE WHEN rn <= total_count / 2 THEN filler_word_count END) AS first_half_avg,
                  AVG(CASE WHEN rn > total_count / 2 THEN filler_word_count END) AS second_half_avg
                FROM ordered;
                """
                filler_rows = d1.query(filler_sql, [current_user.id])
                filler_reduction = 0.0
                if filler_rows and filler_rows[0].get("first_half_avg") is not None:
                    first_avg = float(filler_rows[0]["first_half_avg"] or 0.0)
                    second_avg = float(filler_rows[0].get("second_half_avg") or 0.0)
                    if first_avg > 0:
                        filler_reduction = round((first_avg - second_avg) / first_avg * 100.0, 1)

                return StatsSummary(
                    total_sessions=total_sessions,
                    avg_confidence=avg_confidence,
                    streak_days=streak_days,
                    filler_reduction_pct=filler_reduction,
                    avg_score=avg_score,
                    avg_wpm=avg_wpm,
                    avg_clarity=avg_clarity,
                    total_duration=total_duration,
                )
            else:
                return StatsSummary(
                    total_sessions=0,
                    avg_confidence=0.0,
                    streak_days=0,
                    filler_reduction_pct=0.0,
                    avg_score=0.0,
                    avg_wpm=0.0,
                    avg_clarity=0.0,
                    total_duration=0.0,
                )
        except Exception as exc:
            logger.warning("[stats] D1 error in get_summary (%s), falling back to Firestore aggregations.", exc)

    # ── Fallback: Firestore aggregation queries (count() and avg()), NOT full-doc scan ──
    try:
        query = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", current_user.id)
            .where("is_analyzed", "==", True)
            .where("analysis_failed", "==", False)
        )
        agg_result = query.count(alias="count").avg("confidence_score", alias="avg_conf").get()
        count_val = 0
        avg_conf_val = 0.0
        if agg_result and len(agg_result) > 0 and len(agg_result[0]) > 0:
            for item in agg_result[0]:
                if item.alias == "count":
                    count_val = int(item.value or 0)
                elif item.alias == "avg_conf":
                    avg_conf_val = float(item.value or 0.0)

        if count_val == 0:
            return StatsSummary(
                total_sessions=0,
                avg_confidence=0.0,
                streak_days=0,
                filler_reduction_pct=0.0,
                avg_score=0.0,
                avg_wpm=0.0,
                avg_clarity=0.0,
                total_duration=0.0,
            )

        # Streak fallback: query recent bounded sessions (up to 30) for local dates
        recent_docs = (
            query.order_by("created_at", direction="DESC")
            .limit(30)
            .get()
        )
        local_dates = []
        for d in recent_docs:
            data = d.to_dict() or {}
            ld = data.get("local_date")
            if not ld and data.get("created_at"):
                ld = data["created_at"].strftime("%Y-%m-%d")
            if ld:
                local_dates.append(ld)

        streak_val = _streak_from_dates(local_dates, today, yesterday)

        return StatsSummary(
            total_sessions=count_val,
            avg_confidence=round(avg_conf_val, 1),
            streak_days=streak_val,
            filler_reduction_pct=0.0,
            avg_score=None,
            avg_wpm=None,
            avg_clarity=None,
            total_duration=None,
        )
    except Exception as exc:
        logger.error("[stats] Firestore aggregation fallback error: %s", exc)
        return StatsSummary(
            total_sessions=0,
            avg_confidence=0.0,
            streak_days=0,
            filler_reduction_pct=0.0,
            avg_score=0.0,
            avg_wpm=0.0,
            avg_clarity=0.0,
            total_duration=0.0,
        )


@router.get("/trend", response_model=List[TrendPoint])
def get_trend(
    range: str = Query("week", enum=["week", "month"]),
    tz_offset_minutes: int = Query(330, description="User timezone offset in minutes"),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns trend chart points grouped by user's local_date."""
    days = 7 if range == "week" else 30
    now_local = datetime.now(timezone.utc) + timedelta(minutes=tz_offset_minutes)
    cutoff_date = (now_local - timedelta(days=days)).strftime("%Y-%m-%d")

    d1 = get_d1_client()
    if d1.is_configured:
        try:
            trend_sql = """
            SELECT local_date,
                   ROUND(AVG(overall_score), 1) AS score,
                   ROUND(AVG(wpm), 1) AS wpm,
                   ROUND(AVG(clarity_score), 1) AS clarity,
                   ROUND(AVG(confidence_score), 1) AS confidence,
                   COUNT(*) AS session_count
            FROM session_metrics
            WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL AND local_date >= ?
            GROUP BY local_date ORDER BY local_date ASC;
            """
            rows = d1.query(trend_sql, [current_user.id, cutoff_date])

            grouped = defaultdict(list)
            for r in rows:
                ld = r.get("local_date") or ""
                try:
                    dt = datetime.strptime(ld, "%Y-%m-%d")
                    if range == "week":
                        key = dt.strftime("%a")
                    else:
                        wk = (dt.day - 1) // 7 + 1
                        key = f"W{wk}"
                except Exception:
                    key = ld
                grouped[key].append(float(r.get("confidence") or 0.0))

            return [
                TrendPoint(date=k, confidence=round(sum(v) / len(v), 1))
                for k, v in grouped.items()
            ]
        except Exception as exc:
            logger.warning("[stats] D1 error in get_trend (%s), falling back to Firestore.", exc)

    # Fallback to Firestore
    try:
        since_utc = datetime.now(timezone.utc) - timedelta(days=days)
        docs = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", current_user.id)
            .where("is_analyzed", "==", True)
            .where("created_at", ">=", since_utc)
            .order_by("created_at")
            .get()
        )
        grouped = defaultdict(list)
        for doc in docs:
            data = doc.to_dict() or {}
            if data.get("analysis_failed"):
                continue
            created = data.get("created_at")
            if range == "week":
                key = created.strftime("%a") if created else "Mon"
            else:
                day = created.day if created else 1
                key = f"W{(day - 1) // 7 + 1}"
            grouped[key].append(data.get("confidence_score") or 0)

        return [
            TrendPoint(date=k, confidence=round(sum(v) / len(v), 1))
            for k, v in grouped.items()
        ]
    except Exception as exc:
        logger.error("[stats] Firestore trend fallback error: %s", exc)
        return []


@router.get("/streak", response_model=StreakResponse)
def get_streak(
    tz_offset_minutes: int = Query(330, description="User timezone offset in minutes"),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Calculates active streak using D1 gaps-and-islands grouped by local_date."""
    d1 = get_d1_client()
    today, yesterday = _get_user_local_dates(tz_offset_minutes)

    if d1.is_configured:
        try:
            streak_sql = """
            WITH d AS (
              SELECT DISTINCT local_date FROM session_metrics
              WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
            ), g AS (
              SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
            )
            SELECT COUNT(*) AS streak, MAX(local_date) AS last_day
            FROM g GROUP BY grp ORDER BY last_day DESC LIMIT 1;
            """
            rows = d1.query(streak_sql, [current_user.id])
            if rows and rows[0].get("last_day"):
                last_day = rows[0]["last_day"]
                if last_day in (today, yesterday):
                    return StreakResponse(streak=int(rows[0].get("streak") or 0), last_day=last_day)
                return StreakResponse(streak=0, last_day=last_day)
            return StreakResponse(streak=0, last_day=None)
        except Exception as exc:
            logger.warning("[stats] D1 error in get_streak (%s), falling back to Firestore.", exc)

    # Fallback to Firestore
    try:
        recent_docs = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", current_user.id)
            .where("is_analyzed", "==", True)
            .order_by("created_at", direction="DESC")
            .limit(30)
            .get()
        )
        dates = []
        for d in recent_docs:
            data = d.to_dict() or {}
            if not data.get("analysis_failed"):
                ld = data.get("local_date") or (data["created_at"].strftime("%Y-%m-%d") if data.get("created_at") else None)
                if ld:
                    dates.append(ld)
        streak = _streak_from_dates(dates, today, yesterday)
        last_day = dates[0] if dates else None
        return StreakResponse(streak=streak, last_day=last_day)
    except Exception as exc:
        logger.error("[stats] Streak fallback error: %s", exc)
        return StreakResponse(streak=0, last_day=None)


@router.get("/skills", response_model=SkillBreakdown)
def get_skills(
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns skill breakdown averages."""
    d1 = get_d1_client()
    if d1.is_configured:
        try:
            skills_sql = """
            SELECT ROUND(AVG(clarity_score), 1) AS avg_clarity,
                   ROUND(AVG(confidence_score), 1) AS avg_confidence,
                   ROUND(AVG(wpm), 1) AS avg_wpm,
                   ROUND(AVG(filler_word_count), 1) AS avg_fillers
            FROM (
              SELECT clarity_score, confidence_score, wpm, filler_word_count
              FROM session_metrics
              WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
              ORDER BY created_at DESC LIMIT ?
            );
            """
            rows = d1.query(skills_sql, [current_user.id, limit])
            if rows and rows[0].get("avg_clarity") is not None:
                r = rows[0]
                clarity = float(r.get("avg_clarity") or 0.0)
                conf = float(r.get("avg_confidence") or 0.0)
                wpm = float(r.get("avg_wpm") or 0.0)
                pace = max(0.0, 100.0 - max(0.0, abs(wpm - 140) - 20) * 0.8) if wpm > 0 else 0.0
                filler_count = float(r.get("avg_fillers") or 0.0)
                filler_score = max(0.0, 100.0 - filler_count * 5.0)
                engagement = conf * 0.6 + clarity * 0.4
                return SkillBreakdown(
                    clarity=round(min(clarity, 100.0), 1),
                    pace=round(min(pace, 100.0), 1),
                    filler_words=round(min(filler_score, 100.0), 1),
                    confidence=round(min(conf, 100.0), 1),
                    engagement=round(min(engagement, 100.0), 1),
                )
        except Exception as exc:
            logger.warning("[stats] D1 error in get_skills (%s), falling back to Firestore.", exc)

    # Fallback to Firestore
    try:
        docs = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", current_user.id)
            .where("is_analyzed", "==", True)
            .order_by("created_at", direction="DESC")
            .limit(limit)
            .get()
        )
        sessions = [PracticeSession.from_dict(d.to_dict()) for d in docs]
        sessions = [s for s in sessions if not s.analysis_failed]
        if not sessions:
            return SkillBreakdown(clarity=0, pace=0, filler_words=0, confidence=0, engagement=0)

        n = len(sessions)
        avg_clarity = sum(s.clarity_score or 0 for s in sessions) / n
        avg_conf = sum(s.confidence_score or 0 for s in sessions) / n
        pace_scores = []
        for s in sessions:
            w = s.wpm or 0
            if w > 0:
                dev = max(0.0, abs(w - 140) - 20)
                pace_scores.append(max(0.0, 100.0 - dev * 0.8))
        avg_pace = sum(pace_scores) / max(len(pace_scores), 1)

        filler_scores = []
        for s in sessions:
            wc = len((s.transcript or "").split())
            rate = ((s.filler_word_count or 0) / max(wc, 1)) * 100
            filler_scores.append(max(0.0, 100.0 - rate * 3.0))
        avg_filler = sum(filler_scores) / max(len(filler_scores), 1)
        avg_engagement = avg_conf * 0.6 + avg_clarity * 0.4

        return SkillBreakdown(
            clarity=round(min(avg_clarity, 100.0), 1),
            pace=round(min(avg_pace, 100.0), 1),
            filler_words=round(min(avg_filler, 100.0), 1),
            confidence=round(min(avg_conf, 100.0), 1),
            engagement=round(min(avg_engagement, 100.0), 1),
        )
    except Exception as exc:
        logger.error("[stats] Firestore get_skills fallback error: %s", exc)
        return SkillBreakdown(clarity=0, pace=0, filler_words=0, confidence=0, engagement=0)
