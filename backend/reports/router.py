"""Reports API Router for exporting PDF reports."""
from datetime import datetime, timezone, timedelta
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Response

from auth.dependencies import get_current_user
from database.mongodb import get_db, MongoDatabaseWrapper, SESSIONS_COL
from models import PracticeSession, User
from reports.service import generate_session_pdf_report, generate_weekly_pdf_report

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/sessions/{session_id}/pdf")
def get_session_pdf_report(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Generates and downloads a branded PDF report for a completed session."""
    doc = db.collection(SESSIONS_COL).document(session_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")

    data = doc.to_dict() or {}
    if data.get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    session = PracticeSession.from_dict(data)
    user_name = current_user.full_name or "Pitch Coach Member"

    try:
        pdf_bytes = generate_session_pdf_report(session, user_name=user_name)
    except Exception as exc:
        logger.error("Failed to generate session PDF report for %s: %s", session_id, exc)
        raise HTTPException(status_code=500, detail="Failed to generate PDF report")

    filename = f"pitch_coach_report_{session_id}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{filename}"',
            "Cache-Control": "private, max-age=3600",
        },
    )


@router.get("/weekly/pdf")
def get_weekly_pdf_report(
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Generates and downloads a weekly rehearsal summary PDF report."""
    user_id = current_user.id
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)

    sessions: List[PracticeSession] = []
    try:
        docs = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", user_id)
            .stream()
        )
        for doc in docs:
            data = doc.to_dict() or {}
            created = data.get("created_at")
            if isinstance(created, datetime) and created >= cutoff:
                if data.get("is_analyzed") and not data.get("analysis_failed"):
                    sessions.append(PracticeSession.from_dict(data))
    except Exception as exc:
        logger.warning("Error fetching sessions for weekly report: %s", exc)

    # Sort descending by date
    sessions.sort(key=lambda s: s.created_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    user_name = current_user.full_name or "Pitch Coach Member"

    try:
        pdf_bytes = generate_weekly_pdf_report(sessions, user_name=user_name)
    except Exception as exc:
        logger.error("Failed to generate weekly PDF report for user %s: %s", user_id, exc)
        raise HTTPException(status_code=500, detail="Failed to generate weekly PDF report")

    filename = "pitch_coach_weekly_report.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{filename}"',
            "Cache-Control": "private, max-age=1800",
        },
    )
