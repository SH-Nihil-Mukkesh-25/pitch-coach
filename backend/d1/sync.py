"""D1 synchronization helpers for PracticeSession and filler word breakdown.

Handles:
- Upserting session_metrics and session_fillers into D1
- Fallback flag d1_pending=true in Firestore on failure
- Background retries
"""
from datetime import datetime, timezone
import logging
from typing import Any, Dict, List, Optional, Tuple

from d1.d1_client import D1Client, get_d1_client
from database.mongodb import get_db, SESSIONS_COL

logger = logging.getLogger(__name__)


def _format_iso(dt: Any) -> str:
    """Ensure datetime or string is formatted as ISO-8601 UTC string."""
    if dt is None:
        return datetime.now(timezone.utc).isoformat()
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc).isoformat()
    if hasattr(dt, "to_datetime"):
        d = dt.to_datetime()
        if d.tzinfo is None:
            d = d.replace(tzinfo=timezone.utc)
        return d.astimezone(timezone.utc).isoformat()
    return str(dt)


def build_d1_upsert_statements(session_data: Dict[str, Any]) -> List[Tuple[str, List[Any]]]:
    """Constructs parameterized SQL statements to upsert a session and its fillers into D1."""
    session_id = session_data.get("id", "")
    user_id = session_data.get("user_id", "")
    mode = session_data.get("mode", "interview")
    topic = session_data.get("topic_or_question", "")

    # Metrics
    metrics = session_data.get("metrics") or {}
    duration = float(metrics.get("duration", session_data.get("duration_seconds", 0.0)) or 0.0)
    wpm = float(metrics.get("wpm", session_data.get("wpm", 0.0)) or 0.0)
    filler_count = int(metrics.get("filler_count", session_data.get("filler_word_count", 0)) or 0)
    pause_count = int(metrics.get("pause_count", session_data.get("pause_count", 0)) or 0)
    avg_pause_length = float(session_data.get("avg_pause_length", 0.0) or 0.0)
    clarity = float(metrics.get("clarity", session_data.get("clarity_score", 0.0)) or 0.0)
    confidence = float(metrics.get("confidence", session_data.get("confidence_score", 0.0)) or 0.0)
    overall = float(metrics.get("overall", session_data.get("overall_score", 0.0)) or 0.0)

    # Status: 'pending' | 'uploading' | 'analyzing' | 'analyzed' | 'failed'
    if session_data.get("analysis_failed"):
        status = "failed"
    elif session_data.get("is_analyzed") or session_data.get("stage") == "done":
        status = "analyzed"
    else:
        status = session_data.get("status") or session_data.get("stage") or "pending"

    created_at = _format_iso(session_data.get("created_at"))
    updated_at = _format_iso(datetime.now(timezone.utc))
    local_date = session_data.get("local_date") or created_at[:10]
    tz_offset = int(session_data.get("tz_offset_minutes", 0) or 0)
    deleted_at = session_data.get("deleted_at")

    metrics_sql = """
    INSERT INTO session_metrics (
      id, user_id, mode, topic_or_question, duration_seconds,
      wpm, filler_word_count, pause_count, avg_pause_length,
      clarity_score, confidence_score, overall_score,
      status, created_at, local_date, tz_offset_minutes,
      updated_at, deleted_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      user_id=excluded.user_id,
      mode=excluded.mode,
      topic_or_question=excluded.topic_or_question,
      duration_seconds=excluded.duration_seconds,
      wpm=excluded.wpm,
      filler_word_count=excluded.filler_word_count,
      pause_count=excluded.pause_count,
      avg_pause_length=excluded.avg_pause_length,
      clarity_score=excluded.clarity_score,
      confidence_score=excluded.confidence_score,
      overall_score=excluded.overall_score,
      status=excluded.status,
      local_date=excluded.local_date,
      tz_offset_minutes=excluded.tz_offset_minutes,
      updated_at=excluded.updated_at,
      deleted_at=excluded.deleted_at;
    """
    metrics_params = [
        session_id, user_id, mode, topic, duration,
        wpm, filler_count, pause_count, avg_pause_length,
        clarity, confidence, overall,
        status, created_at, local_date, tz_offset,
        updated_at, deleted_at,
    ]

    statements: List[Tuple[str, List[Any]]] = [(metrics_sql, metrics_params)]

    # Fillers breakdown
    fillers = session_data.get("filler_word_breakdown") or {}
    if isinstance(fillers, dict) and fillers:
        for word, count in fillers.items():
            clean_word = str(word).strip().lower()
            if not clean_word:
                continue
            f_sql = """
            INSERT INTO session_fillers (session_id, filler_word, count)
            VALUES (?, ?, ?)
            ON CONFLICT(session_id, filler_word) DO UPDATE SET count=excluded.count;
            """
            statements.append((f_sql, [session_id, clean_word, int(count)]))

    return statements


def upsert_session_to_d1(
    session_data: Dict[str, Any],
    d1_client: Optional[D1Client] = None,
) -> bool:
    """Upserts session_metrics and session_fillers into D1.

    Returns True on success, False on error.
    """
    client = d1_client or get_d1_client()
    if not client.is_configured:
        logger.warning("[d1] Cloudflare D1 credentials not configured, skipping direct D1 write.")
        return False

    stmts = build_d1_upsert_statements(session_data)
    try:
        client.batch(stmts)
        logger.info("[d1] Successfully synced session %s to D1.", session_data.get("id"))
        return True
    except Exception as exc:
        logger.warning("[d1] Failed to upsert session %s to D1: %s", session_data.get("id"), exc)
        return False


def sync_firestore_session_to_d1(
    session_id: str,
    db=None,
    d1_client: Optional[D1Client] = None,
) -> bool:
    """Reads a session doc from Firestore, upserts it into D1, and updates d1_pending flag."""
    if db is None:
        db = get_db()
    if db is None:
        return False

    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists:
        logger.warning("[d1] Cannot sync session %s: doc does not exist.", session_id)
        return False

    data = doc.to_dict() or {}
    success = upsert_session_to_d1(data, d1_client=d1_client)

    try:
        doc_ref.update({"d1_pending": not success})
    except Exception as exc:
        logger.warning("[d1] Could not update d1_pending on session %s: %s", session_id, exc)

    return success


def retry_d1_sync(session_id: str) -> None:
    """Background task callback to retry syncing a pending session to D1."""
    logger.info("[d1] Running background retry for session %s...", session_id)
    sync_firestore_session_to_d1(session_id)


# MongoDB migration alias
sync_mongo_session_to_d1 = sync_firestore_session_to_d1
