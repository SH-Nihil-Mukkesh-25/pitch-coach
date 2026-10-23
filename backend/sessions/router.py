"""Session CRUD routes: start, finish (upload + async pipeline), get, list."""
import os
import tempfile
import uuid
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse, RedirectResponse

from auth.dependencies import get_current_user, get_current_user_optional
from auth.utils import decode_token
from config import get_groq_key, get_settings
from database.mongodb import get_db, MongoDatabaseWrapper, SESSIONS_COL
from firestore import get_bucket
from models import PracticeSession, User
from schemas import (
    FeedbackItem,
    SessionResult,
    SessionSummary,
    StartSessionRequest,
    StartSessionResponse,
    WordTimestamp,
)
from sessions.pipeline import analyze_audio
from d1.d1_client import get_d1_client
from d1.sync import upsert_session_to_d1, retry_d1_sync

router = APIRouter(prefix="/sessions", tags=["sessions"])
settings = get_settings()

_ALLOWED_AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".webm", ".ogg", ".aac"}


import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _to_result(s: PracticeSession) -> SessionResult:
    feedback = []
    for item in (s.ai_feedback or []):
        if isinstance(item, dict):
            feedback.append(FeedbackItem(
                category=item.get("category", "clarity"),
                message=item.get("message", ""),
                severity=item.get("severity", "tip"),
                example=item.get("example"),
            ))
    word_timestamps = []
    for item in (s.word_timestamps or []):
        if isinstance(item, dict):
            word_timestamps.append(WordTimestamp(
                word=str(item.get("word", "")),
                start=float(item.get("start", 0.0)),
                end=float(item.get("end", 0.0)),
            ))
    return SessionResult(
        id=s.id,
        parent_session_id=s.parent_session_id,
        template_id=getattr(s, "template_id", None),
        structure_score=getattr(s, "structure_score", None),
        template_sections_detected=getattr(s, "template_sections_detected", None) or [],
        template_sections_missing=getattr(s, "template_sections_missing", None) or [],
        mode=s.mode,
        topic_or_question=s.topic_or_question,
        duration_seconds=s.duration_seconds or 0.0,
        transcript=s.transcript,
        word_timestamps=word_timestamps,
        audio_offset_seconds=getattr(s, "audio_offset_seconds", 0.0) or 0.0,
        wpm=s.wpm or 0.0,
        filler_word_count=s.filler_word_count or 0,
        filler_word_breakdown=s.filler_word_breakdown or {},
        pause_count=s.pause_count or 0,
        avg_pause_length=s.avg_pause_length or 0.0,
        clarity_score=s.clarity_score or 0.0,
        confidence_score=s.confidence_score or 0.0,
        overall_score=s.overall_score or 0.0,
        ai_feedback=feedback,
        created_at=s.created_at,
        local_date=s.local_date,
        tz_offset_minutes=s.tz_offset_minutes,
        is_analyzed=s.is_analyzed,
        analysis_failed=s.analysis_failed,
        failure_reason=s.failure_reason,
        audio_url=f"/sessions/{s.id}/audio" if _audio_exists(s.audio_url) else None,
        energy_curve=getattr(s, "energy_curve", None) or [],
        pitch_variation_score=getattr(s, "pitch_variation_score", None),
        volume_consistency_score=getattr(s, "volume_consistency_score", None),
        no_speech=getattr(s, "no_speech", None),
        active_wpm=getattr(s, "active_wpm", None),
        repetitions_count=getattr(s, "repetitions_count", None),
        rhetorical_pause_count=getattr(s, "rhetorical_pause_count", None),
        disfluent_pause_count=getattr(s, "disfluent_pause_count", None),
    )


def _to_summary(s: PracticeSession) -> SessionSummary:
    return SessionSummary(
        id=s.id,
        parent_session_id=s.parent_session_id,
        template_id=getattr(s, "template_id", None),
        structure_score=getattr(s, "structure_score", None),
        mode=s.mode,
        topic_or_question=s.topic_or_question,
        duration_seconds=s.duration_seconds or 0.0,
        overall_score=s.overall_score or 0.0,
        confidence_score=s.confidence_score or 0.0,
        created_at=s.created_at,
        local_date=s.local_date,
        tz_offset_minutes=s.tz_offset_minutes,
        is_analyzed=s.is_analyzed,
        analysis_failed=s.analysis_failed,
        failure_reason=s.failure_reason,
    )


def _save_file(path: str, data: bytes) -> None:
    with open(path, "wb") as f:
        f.write(data)


def _audio_exists(ref: Optional[str]) -> bool:
    """True if the stored audio reference (Storage path, or legacy local path) is readable."""
    if not ref:
        return False
    if os.path.exists(ref):  # legacy sessions saved to local disk
        return True
    try:
        return get_bucket().blob(ref).exists()
    except Exception:
        return False


def _fetch_audio(ref: str) -> tuple[str, bool]:
    """Returns (local_path, is_temp). Downloads from Storage when needed."""
    if os.path.exists(ref):
        return ref, False
    fd, tmp = tempfile.mkstemp(suffix=os.path.splitext(ref)[1] or ".m4a")
    os.close(fd)
    try:
        get_bucket().blob(ref).download_to_filename(tmp)
    except Exception:
        os.remove(tmp)
        raise
    return tmp, True


# ─────────────────────────────────────────────────────────────────────────────
# Background pipeline task
# ─────────────────────────────────────────────────────────────────────────────

def _run_pipeline_bg(
    session_id: str,
    audio_ref: str,
    duration: float,
    user_profile: dict,
) -> None:
    """Runs in a background thread (FastAPI BackgroundTasks)."""
    from database.mongodb import get_db as _get_db  # local import avoids circular issues

    db = _get_db()
    local_path, is_temp = None, False
    try:
        doc_ref = db.collection(SESSIONS_COL).document(session_id)
        doc = doc_ref.get()
        if not doc.exists:
            return

        doc_data = doc.to_dict() or {}
        template_id = doc_data.get("template_id")
        user_id = doc_data.get("user_id")

        local_path, is_temp = _fetch_audio(audio_ref)
        analysis = analyze_audio(
            audio_path=local_path,
            duration_seconds=duration,
            user_profile=user_profile,
            groq_api_key=get_groq_key("audio"),
            whisper_model=settings.GROQ_WHISPER_MODEL,
            llm_model=settings.GROQ_LLM_MODEL,
            template_id=template_id,
            mode=doc_data.get("mode", "interview"),
        )

        doc_ref.update({
            "transcript": analysis.transcript,
            "word_timestamps": [
                {
                    "word": wt.word,
                    "start": round(wt.start, 2),
                    "end": round(wt.end, 2),
                }
                for wt in analysis.word_timestamps
            ],
            "audio_offset_seconds": 0.0,
            "wpm": analysis.wpm,
            "filler_word_count": analysis.filler.total_count,
            "filler_word_breakdown": analysis.filler.breakdown,
            "pause_count": analysis.pauses.count,
            "avg_pause_length": analysis.pauses.avg_length,
            "clarity_score": analysis.clarity_score,
            "confidence_score": analysis.confidence_score,
            "overall_score": analysis.overall_score,
            "structure_score": analysis.structure_score,
            "template_sections_detected": analysis.template_sections_detected,
            "template_sections_missing": analysis.template_sections_missing,
            "template_id": analysis.template_id,
            "duration_seconds": analysis.duration_seconds,
            "no_speech": getattr(analysis, "no_speech", False),
            "active_wpm": getattr(analysis, "active_wpm", analysis.wpm),
            "repetitions_count": getattr(analysis, "repetitions_count", 0),
            "rhetorical_pause_count": getattr(analysis, "rhetorical_pause_count", 0),
            "disfluent_pause_count": getattr(analysis, "disfluent_pause_count", 0),
            "ai_feedback": [
                {
                    "category": f.category,
                    "message": f.message,
                    "severity": f.severity,
                    "example": f.example,
                }
                for f in analysis.ai_feedback
            ],
            "metrics": {
                "wpm": analysis.wpm,
                "overall": analysis.overall_score,
                "clarity": analysis.clarity_score,
                "confidence": analysis.confidence_score,
                "structure_score": analysis.structure_score,
                "pause_count": analysis.pauses.count,
                "duration": analysis.duration_seconds,
                "filler_count": analysis.filler.total_count,
            },
            "stage": "done",
            "is_analyzed": True,
        })
        logger.info("[pipeline] Session %s analyzed OK. Score=%.1f", session_id, analysis.overall_score)

        # Dual write to D1
        try:
            from d1.sync import upsert_session_to_d1
            session_data = doc_ref.get().to_dict() or {}
            session_data["id"] = session_id
            d1_ok = upsert_session_to_d1(session_data)
            doc_ref.update({"d1_pending": not d1_ok})
        except Exception as d1_err:
            logger.warning("[pipeline] D1 dual write failed for session %s: %s", session_id, d1_err)
            try:
                doc_ref.update({"d1_pending": True})
            except Exception:
                pass

        # Evaluate unlock rules after each analyzed session
        try:
            from achievements.service import evaluate_user_achievements
            if user_id:
                evaluate_user_achievements(user_id, db=db)
        except Exception as ach_err:
            logger.warning("[pipeline] Achievement evaluation error: %s", ach_err)

    except Exception as exc:
        logger.error("[pipeline] ERROR for session %s: %s", session_id, exc)
        # Stop the app polling, but flag the failure so stats ignore the zero scores
        try:
            db.collection(SESSIONS_COL).document(session_id).update({
                "stage": "failed",
                "is_analyzed": True,
                "analysis_failed": True,
                "failure_reason": str(exc),
            })
        except Exception:
            pass
    finally:
        if is_temp and local_path and os.path.exists(local_path):
            os.remove(local_path)


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

from quota import check_and_increment_daily_quota

@router.post("", response_model=SessionResult)
async def create_session(
    background_tasks: BackgroundTasks,
    audio_file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    parent_session_id: Optional[str] = Form(None),
    template_id: Optional[str] = Form(None),
    mode: str = Form("interview"),
    topic_or_question: str = Form("Tell me about yourself."),
    duration_seconds: float = Form(0.0),
    local_date: Optional[str] = Form(None),
    tz_offset_minutes: Optional[int] = Form(0),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """
    POST /sessions (Phase 1 dual-write flow):
    (1) Verify token & derive user_id from uid
    (2) Analyze audio
    (3) Write Firestore first (rich data plus metrics snapshot)
    (4) Upsert into D1 (session_metrics)
    (5) Upsert session_fillers into D1
    (6) Return the metrics. If D1 write fails, set d1_pending=true & retry in bg.
    """
    # 1. Validate session_id
    if session_id:
        try:
            uuid.UUID(session_id)
        except ValueError:
            raise HTTPException(status_code=422, detail="session_id must be a valid UUID")
    else:
        session_id = str(uuid.uuid4())

    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    existing_doc = doc_ref.get()
    if existing_doc.exists:
        data = existing_doc.to_dict()
        if data.get("user_id") != current_user.id:
            raise HTTPException(status_code=403, detail="Forbidden")
        if data.get("is_analyzed") and not data.get("analysis_failed"):
            # Idempotent response: return existing analyzed session
            return _to_result(PracticeSession.from_dict(data))
        if data.get("stage") == "analyzing":
            # Idempotent response: return existing in-progress session without duplicate queueing
            return _to_result(PracticeSession.from_dict(data))

    # Validate dates
    now_utc = datetime.now(timezone.utc)
    tz_offset = tz_offset_minutes if tz_offset_minutes is not None else 0
    if not (-720 <= tz_offset <= 840):
        raise HTTPException(status_code=422, detail="tz_offset_minutes must be between -720 and 840")

    if local_date:
        local_date = local_date.strip()
        try:
            parsed_date = datetime.strptime(local_date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=422, detail="local_date must be in YYYY-MM-DD format")
        local_now = (now_utc + timedelta(minutes=tz_offset)).date()
        if abs((parsed_date - local_now).days) > 2:
            raise HTTPException(status_code=400, detail="local_date is outside the acceptable range")
    else:
        local_date = (now_utc + timedelta(minutes=tz_offset)).strftime("%Y-%m-%d")

    check_and_increment_daily_quota(current_user.id, "sessions", settings.MAX_SESSIONS_PER_DAY)

    # 2. Audio validation & save
    raw_name = audio_file.filename or "recording.m4a"
    ext = os.path.splitext(raw_name)[1].lower() or ".m4a"
    if ext not in _ALLOWED_AUDIO_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported audio format")

    max_bytes = settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024
    content = await audio_file.read(max_bytes + 1)
    if len(content) > max_bytes:
        raise HTTPException(status_code=413, detail="Audio file is too large")
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    stored_ref = None
    if settings.FIREBASE_STORAGE_BUCKET:
        candidate_ref = f"audio/{current_user.id}/{session_id}{ext}"
        try:
            await run_in_threadpool(
                lambda: get_bucket().blob(candidate_ref).upload_from_string(
                    content, content_type=audio_file.content_type or "audio/mp4"
                )
            )
            stored_ref = candidate_ref
        except Exception as exc:
            logger.warning("[storage] Firebase upload failed for session %s: %s; falling back to local disk", session_id, exc)

    temp_path = None
    if not stored_ref:
        upload_dir = os.path.abspath(settings.AUDIO_UPLOAD_DIR)
        os.makedirs(upload_dir, exist_ok=True)
        stored_ref = os.path.join(upload_dir, f"{session_id}{ext}")
        await run_in_threadpool(lambda: _save_file(stored_ref, content))
        analysis_audio_path = stored_ref
    else:
        fd, temp_path = tempfile.mkstemp(suffix=ext)
        os.close(fd)
        with open(temp_path, "wb") as f:
            f.write(content)
        analysis_audio_path = temp_path

    # Analyze
    try:
        user_profile = {
            "feedback_style": current_user.feedback_style,
            "experience_level": current_user.experience_level,
        }
        analysis = await run_in_threadpool(
            lambda: analyze_audio(
                audio_path=analysis_audio_path,
                duration_seconds=duration_seconds,
                user_profile=user_profile,
                groq_api_key=get_groq_key("audio"),
                whisper_model=settings.GROQ_WHISPER_MODEL,
                llm_model=settings.GROQ_LLM_MODEL,
                template_id=template_id,
            )
        )
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

    # 3. Write Firestore first (rich data plus metrics snapshot)
    feedback_dicts = [
        {
            "category": f.category,
            "message": f.message,
            "severity": f.severity,
            "example": f.example,
        }
        for f in analysis.ai_feedback
    ]
    metrics_snapshot = {
        "wpm": analysis.wpm,
        "overall": analysis.overall_score,
        "clarity": analysis.clarity_score,
        "confidence": analysis.confidence_score,
        "structure_score": analysis.structure_score,
        "pause_count": analysis.pauses.count,
        "duration": analysis.duration_seconds,
        "filler_count": analysis.filler.total_count,
    }

    doc_data = {
        "id": session_id,
        "user_id": current_user.id,
        "parent_session_id": parent_session_id,
        "template_id": template_id,
        "structure_score": analysis.structure_score,
        "template_sections_detected": analysis.template_sections_detected,
        "template_sections_missing": analysis.template_sections_missing,
        "mode": mode,
        "topic_or_question": topic_or_question,
        "audio_url": stored_ref,
        "duration_seconds": analysis.duration_seconds,
        "transcript": analysis.transcript,
        "energy_curve": analysis.energy_curve,
        "pitch_variation_score": analysis.pitch_variation_score,
        "volume_consistency_score": analysis.volume_consistency_score,
        "wpm": analysis.wpm,
        "filler_word_count": analysis.filler.total_count,
        "filler_word_breakdown": analysis.filler.breakdown,
        "pause_count": analysis.pauses.count,
        "avg_pause_length": analysis.pauses.avg_length,
        "clarity_score": analysis.clarity_score,
        "confidence_score": analysis.confidence_score,
        "overall_score": analysis.overall_score,
        "ai_feedback": feedback_dicts,
        "metrics": metrics_snapshot,
        "stage": "done",
        "is_analyzed": True,
        "analysis_failed": False,
        "failure_reason": None,
        "local_date": local_date,
        "tz_offset_minutes": tz_offset,
        "created_at": now_utc,
        "d1_pending": False,
    }

    doc_ref.set(doc_data)

    # 4 & 5. Upsert into D1 (session_metrics and session_fillers)
    d1_ok = upsert_session_to_d1(doc_data)
    if not d1_ok:
        doc_ref.update({"d1_pending": True})
        doc_data["d1_pending"] = True
        background_tasks.add_task(retry_d1_sync, session_id)

    # Evaluate unlock rules after analyzed session
    try:
        from achievements.service import evaluate_user_achievements
        evaluate_user_achievements(current_user.id, db=db)
    except Exception as ach_err:
        logger.warning("[sessions] Achievement evaluation error: %s", ach_err)

    # 6. Return the metrics / SessionResult
    session = PracticeSession.from_dict(doc_data)
    return _to_result(session)


@router.post("/start", response_model=StartSessionResponse)
def start_session(
    req: StartSessionRequest,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Creates a session document in Firestore and returns its ID."""
    now_utc = datetime.now(timezone.utc)
    tz_offset = req.tz_offset_minutes if req.tz_offset_minutes is not None else 0
    if req.local_date:
        parsed_date = datetime.strptime(req.local_date, "%Y-%m-%d").date()
        local_now = (now_utc + timedelta(minutes=tz_offset)).date()
        if abs((parsed_date - local_now).days) > 2:
            raise HTTPException(status_code=400, detail="local_date is outside the acceptable range for current timestamp.")
        local_date = req.local_date
    else:
        local_date = (now_utc + timedelta(minutes=tz_offset)).strftime("%Y-%m-%d")

    session_id = req.session_id or str(uuid.uuid4())

    if db is not None:
        try:
            existing = db.collection(SESSIONS_COL).document(session_id).get()
            if existing.exists is True:
                return StartSessionResponse(session_id=session_id)
        except Exception as exc:
            logger.warning("[sessions] Error checking existing session %s: %s", session_id, exc)

    check_and_increment_daily_quota(current_user.id, "sessions", settings.MAX_SESSIONS_PER_DAY)

    session = PracticeSession(
        id=session_id,
        user_id=current_user.id,
        parent_session_id=req.parent_session_id,
        template_id=req.template_id,
        mode=req.mode,
        topic_or_question=req.topic_or_question,
        local_date=local_date,
        tz_offset_minutes=tz_offset,
        created_at=now_utc,
    )
    if db is not None:
        db.collection(SESSIONS_COL).document(session.id).set(session.to_dict())
    return StartSessionResponse(session_id=session.id)


@router.post("/{session_id}/finish", response_model=SessionResult)
async def finish_session(
    session_id: str,
    background_tasks: BackgroundTasks,
    audio_file: UploadFile = File(...),
    duration_seconds: float = Form(0.0),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """
    Receives the recorded audio file, saves it to disk, then kicks off the
    AI pipeline in the background.  Returns the session doc immediately
    (is_analyzed=False); the Flutter app polls GET /{id} until is_analyzed=True.
    """
    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")

    session_data = doc.to_dict()
    if session_data.get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    # Validate, then save the recording (Firebase Storage if configured, else local disk)
    raw_name = audio_file.filename or "recording.m4a"
    ext = os.path.splitext(raw_name)[1].lower() or ".m4a"
    if ext not in _ALLOWED_AUDIO_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported audio format")

    max_bytes = settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024
    content = await audio_file.read(max_bytes + 1)
    if len(content) > max_bytes:
        raise HTTPException(status_code=413, detail="Audio file is too large")
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    # ── Storage: Firebase Storage if bucket is configured, else local disk fallback ──
    stored_ref = None
    if settings.FIREBASE_STORAGE_BUCKET:
        candidate_ref = f"audio/{current_user.id}/{session_id}{ext}"
        try:
            await run_in_threadpool(
                lambda: get_bucket().blob(candidate_ref).upload_from_string(
                    content, content_type=audio_file.content_type or "audio/mp4"
                )
            )
            stored_ref = candidate_ref
            logger.info("[storage] Saved recording to Firebase Storage: %s", stored_ref)
        except Exception as exc:
            logger.warning("[storage] Firebase upload failed for session %s: %s; falling back to local disk", session_id, exc)

    if not stored_ref:
        # Local disk fallback — ensures recordings are preserved safely
        upload_dir = os.path.abspath(settings.AUDIO_UPLOAD_DIR)
        os.makedirs(upload_dir, exist_ok=True)
        stored_ref = os.path.join(upload_dir, f"{session_id}{ext}")
        try:
            await run_in_threadpool(
                lambda: _save_file(stored_ref, content)
            )
            logger.info("[storage] Saved recording locally: %s", stored_ref)
        except Exception as exc:
            logger.error("[storage] Local disk save failed for session %s: %s", session_id, exc)
            raise HTTPException(status_code=503, detail="Could not store the recording. Please try again.")

    audio_ref = stored_ref

    doc_ref.update({
        "audio_url": audio_ref,
        "duration_seconds": duration_seconds,
    })

    # Kick off AI pipeline in background
    user_profile = {
        "feedback_style": current_user.feedback_style,
        "experience_level": current_user.experience_level,
    }
    background_tasks.add_task(
        _run_pipeline_bg, session_id, audio_ref, duration_seconds, user_profile
    )

    updated_doc = doc_ref.get()
    session = PracticeSession.from_dict(updated_doc.to_dict())
    return _to_result(session)



@router.post("/{session_id}/retry", response_model=SessionResult)
def retry_analysis(
    session_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Re-runs the AI pipeline on the already-uploaded audio of a failed session."""
    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists or doc.to_dict().get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    data = doc.to_dict()
    if not data.get("analysis_failed"):
        raise HTTPException(status_code=400, detail="Session did not fail analysis")
    audio_ref = data.get("audio_url")
    if not _audio_exists(audio_ref):
        raise HTTPException(status_code=410, detail="Original recording is no longer available")

    doc_ref.update({"is_analyzed": False, "analysis_failed": False})
    background_tasks.add_task(
        _run_pipeline_bg,
        session_id,
        audio_ref,
        data.get("duration_seconds") or 0.0,
        {
            "feedback_style": current_user.feedback_style,
            "experience_level": current_user.experience_level,
        },
    )
    return _to_result(PracticeSession.from_dict(doc_ref.get().to_dict()))


def sweep_stuck_sessions(cutoff_seconds: int = 600) -> int:
    """Finds all sessions stuck in processing exceeding cutoff_seconds and marks them failed."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=cutoff_seconds)
    db = get_db()
    count = 0
    if db is not None:
        try:
            docs = (
                db.collection(SESSIONS_COL)
                .where("is_analyzed", "==", False)
                .stream()
            )
            for doc in docs:
                data = doc.to_dict()
                created = data.get("created_at")
                if isinstance(created, datetime) and created < cutoff:
                    db.collection(SESSIONS_COL).document(doc.id).update({
                        "is_analyzed": True,
                        "analysis_failed": True,
                        "failure_reason": "Processing timed out (sweeper)",
                    })
                    count += 1
        except Exception as exc:
            logger.warning("Error sweeping stuck sessions from MongoDB: %s", exc)
    return count


@router.get("/{session_id}", response_model=SessionResult)
def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Poll this endpoint every ~2 s after finish until is_analyzed=True."""
    doc = db.collection(SESSIONS_COL).document(session_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")
    data = doc.to_dict()
    if data.get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    session = PracticeSession.from_dict(data)

    # Check if processing has been stuck for >10 minutes
    if not session.is_analyzed and not session.analysis_failed:
        delta = (datetime.now(timezone.utc) - session.created_at).total_seconds()
        if delta > 600:
            logger.warning("Session %s stuck for %.1fs. Marking as failed.", session_id, delta)
            session.is_analyzed = True
            session.analysis_failed = True
            session.failure_reason = "Processing timed out"
            try:
                db.collection(SESSIONS_COL).document(session_id).update({
                    "is_analyzed": True,
                    "analysis_failed": True,
                    "failure_reason": "Processing timed out",
                })
            except Exception:
                pass

    return _to_result(session)


@router.get("/{session_id}/audio")
def get_session_audio(
    session_id: str,
    token: Optional[str] = Query(None),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Streams the session's recorded audio for in-app playback."""
    doc = db.collection(SESSIONS_COL).document(session_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")
    data = doc.to_dict()

    # If user context is provided via header or query token, verify ownership
    req_user_id = current_user.id if current_user else None
    if not req_user_id and token:
        payload = decode_token(token)
        if payload and payload.get("type") == "access":
            req_user_id = payload.get("sub")

    if req_user_id and data.get("user_id") != req_user_id:
        raise HTTPException(status_code=404, detail="Session not found")

    audio_ref = data.get("audio_url")
    if not audio_ref:
        raise HTTPException(status_code=404, detail="No audio recorded for this session")

    # Local disk playback
    if os.path.exists(audio_ref):
        return FileResponse(audio_ref, media_type="audio/mp4", filename=f"session_{session_id}.m4a")

    # Firebase Storage playback
    if settings.FIREBASE_STORAGE_BUCKET:
        try:
            blob = get_bucket().blob(audio_ref)
            if blob.exists():
                url = blob.generate_signed_url(expiration=timedelta(hours=2))
                return RedirectResponse(url=url)
        except Exception as exc:
            logger.error("[storage] Failed to generate signed URL for %s: %s", audio_ref, exc)

    raise HTTPException(status_code=404, detail="Audio file not found")


@router.get("", response_model=List[SessionSummary])
def list_sessions(
    mode: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns paginated session history for history_screen and home recent card."""
    try:
        criteria: dict = {"user_id": current_user.id}
        if mode:
            criteria["mode"] = mode
        cursor = db[SESSIONS_COL].find(criteria).sort("created_at", -1)
        sessions = [PracticeSession.from_dict(d) for d in cursor]
    except Exception:
        query = db.collection(SESSIONS_COL).where("user_id", "==", current_user.id)
        if mode:
            query = query.where("mode", "==", mode)
        all_docs = query.get()
        sessions = [PracticeSession.from_dict(d.to_dict()) for d in all_docs]
        sessions.sort(key=lambda s: s.created_at, reverse=True)

    if search:
        search_lower = search.lower()
        sessions = [s for s in sessions if search_lower in s.topic_or_question.lower()]

    # Manual pagination
    start = (page - 1) * limit
    sessions = sessions[start: start + limit]

    return [_to_summary(s) for s in sessions]


@router.delete("/{session_id}")
def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """
    DELETE /sessions/{session_id}:
    (1) Soft delete in D1 first (so tombstones sync via /metrics/changes).
    (2) Remove the Firestore doc.
    (3) Remove Storage audio.
    """
    now_iso = datetime.now(timezone.utc).isoformat()

    # 1. Soft delete in D1 first
    d1 = get_d1_client()
    if d1.is_configured:
        try:
            d1.query(
                """
                UPDATE session_metrics
                SET deleted_at = ?, updated_at = ?
                WHERE id = ? AND user_id = ?;
                """,
                [now_iso, now_iso, session_id, current_user.id],
            )
            logger.info("[sessions] Soft deleted session %s in D1.", session_id)
        except Exception as exc:
            logger.warning("[sessions] D1 soft-delete error for session %s: %s", session_id, exc)

    # 2. Check & delete Firestore doc
    if db is not None:
        doc_ref = db.collection(SESSIONS_COL).document(session_id)
        doc_snap = doc_ref.get()
        if doc_snap.exists:
            data = doc_snap.to_dict() or {}
            if data.get("user_id") and data.get("user_id") != current_user.id:
                raise HTTPException(status_code=403, detail="Forbidden: session belongs to another user.")
            doc_ref.delete()
            logger.info("[sessions] Deleted Firestore session doc %s.", session_id)

    # 3. Remove Storage audio
    try:
        bucket = get_bucket()
        if bucket is not None:
            for ext in (".m4a", ".mp3", ".wav"):
                blob = bucket.blob(f"audio/{current_user.id}/{session_id}{ext}")
                if blob.exists():
                    blob.delete()
                    logger.info("[sessions] Deleted Storage audio blob %s.", blob.name)
                    break
    except Exception as exc:
        logger.warning("[sessions] Storage delete notice for session %s: %s", session_id, exc)

    return {"deleted": True, "id": session_id}
