"""FastAPI endpoints for Slide Coach deck upload, processing, review, and editing."""
import hashlib
import json
import logging
import os
import tempfile
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from groq import Groq

from auth.dependencies import get_current_user
from config import get_groq_key, get_settings
from models import SlideDeck, User
from slides.pipeline import (
    convert_pptx_to_pdf,
    evaluate_qa_answer,
    extract_all_slides_vision,
    generate_qa_questions,
    run_slide_rehearsal_pipeline,
    synthesize_deck_coaching,
    validate_and_render_pdf,
)
from slides.schemas import (
    DeckCoachingResult,
    DeckRehearsalResponse,
    DeckSummary,
    QaEvaluationResponse,
    QaQuestion,
    QaQuestionsResponse,
    SlideCoaching,
    SlideDeckResponse,
    SlideDeckStatusResponse,
    SlidePatchRequest,
    SlideRehearsalReport,
)
from slides.store import deck_store

from quota import check_and_increment_daily_quota
import pymupdf

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/slides", tags=["slide_coach"])
settings = get_settings()


# ─────────────────────────────────────────────────────────────────────────────
# Background Task Pipeline Runner
# ─────────────────────────────────────────────────────────────────────────────

def _run_deck_pipeline(
    deck_id: str,
    pdf_bytes: bytes,
    audience: str,
    time_limit_seconds: int,
    goal: str,
    user_id: str,
) -> None:
    """Executes Stage A -> Stage B -> Stage C asynchronously."""
    deck = deck_store.get(deck_id)
    if not deck:
        return

    client = Groq(api_key=get_groq_key())
    slides_dir = deck_store.get_slides_dir(deck_id)

    try:
        # ── Stage A: Render ──
        deck.stage = "rendering"
        deck.progress = 15
        deck_store.save(deck)

        page_count, image_paths = validate_and_render_pdf(
            pdf_bytes=pdf_bytes,
            output_dir=slides_dir,
        )
        deck.page_count = page_count
        deck.progress = 30
        deck_store.save(deck)

        # Upload slide images to Firebase Storage if configured
        try:
            deck_store.upload_slide_images_to_storage(deck_id, image_paths)
        except Exception as upload_err:
            logger.warning("Optional slide image storage upload failed for %s: %s", deck_id, upload_err)

        # ── Stage B: Vision Extraction ──
        deck.stage = "reading_slides"
        deck.progress = 45
        deck_store.save(deck)

        def on_vision_progress(completed: int, total: int):
            deck.progress = min(70, 45 + int((completed / total) * 25))
            deck_store.save(deck)

        descriptions = extract_all_slides_vision(
            image_paths=image_paths,
            client=client,
            model=settings.GROQ_VISION_MODEL,
            on_progress=on_vision_progress,
        )
        deck.progress = 70
        deck_store.save(deck)

        # ── Stage C: Coaching Synthesis ──
        deck.stage = "writing_coaching"
        deck.progress = 85
        deck_store.save(deck)

        coaching_result = synthesize_deck_coaching(
            descriptions=descriptions,
            audience=audience,
            time_limit_seconds=time_limit_seconds,
            goal=goal,
            client=client,
            model=settings.GROQ_TEXT_MODEL,
        )

        # Format slides with image URLs
        slides_data = []
        for s in coaching_result.slides:
            s_dict = s.model_dump()
            s_dict["image_url"] = f"/slides/{deck_id}/slides/{s.slide_number}/image"
            slides_data.append(s_dict)

        deck.deck_summary = coaching_result.deck_summary.model_dump()
        deck.slides = slides_data
        deck.status = "done"
        deck.progress = 100
        deck.error = None
        deck.failure_reason = None
        deck_store.save(deck)
        logger.info("Deck %s successfully analyzed with %d slides", deck_id, len(slides_data))

    except Exception as e:
        logger.exception("Pipeline failed for deck %s: %s", deck_id, e)
        deck.status = "failed"
        deck.error = str(e)
        deck.failure_reason = str(e)
        deck_store.save(deck)


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/upload",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Upload a presentation deck PDF for AI coaching analysis",
)
async def upload_deck(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    audience: str = Form("investors", max_length=100),
    time_limit_seconds: int = Form(180, ge=30, le=1800),
    goal: str = Form("", max_length=500),
    current_user: User = Depends(get_current_user),
):
    # Enforce daily quota
    check_and_increment_daily_quota(current_user.id, "decks", settings.MAX_DECKS_PER_DAY)

    filename = file.filename or "deck.pdf"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in [".pdf", ".pptx", ".ppt"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF and PPTX presentation files are supported.",
        )

    # 2. Streaming read and validate size (max 25MB)
    max_bytes = 25 * 1024 * 1024
    raw_bytes = await file.read(max_bytes + 1)
    if len(raw_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File size exceeds the 25 MB limit.",
        )
    if not raw_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    # Convert PPTX to PDF if PowerPoint file
    if ext in [".pptx", ".ppt"]:
        try:
            pdf_bytes = convert_pptx_to_pdf(raw_bytes)
        except Exception as e:
            logger.error("Failed to convert PPTX to PDF: %s", e)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unable to parse presentation file: {e}",
            )
    else:
        pdf_bytes = raw_bytes
        # Validate PDF magic bytes
        if not pdf_bytes.startswith(b"%PDF"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file format. The file is not a valid PDF.",
            )

    # 4. Validate page count (1 to 60 pages)
    try:
        doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
        page_count = len(doc)
        doc.close()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid PDF file: {e}")

    if page_count < 1:
        raise HTTPException(status_code=400, detail="The PDF document is empty (0 pages).")
    if page_count > 20:
        raise HTTPException(status_code=400, detail=f"PDF exceeds maximum allowed pages (found {page_count}, limit is 20).")

    # 5. Check SHA-256 cache
    content_hash = hashlib.sha256(
        pdf_bytes + f"{audience}:{time_limit_seconds}:{goal}".encode("utf-8")
    ).hexdigest()

    existing = deck_store.find_by_hash(current_user.id, content_hash)
    if existing:
        return {
            "deck_id": existing.id,
            "status": existing.status,
            "cached": True,
        }

    # 6. Create new job
    new_deck = SlideDeck(
        user_id=current_user.id,
        content_hash=content_hash,
        filename=filename,
        audience=audience,
        time_limit_seconds=time_limit_seconds,
        goal=goal,
        status="processing",
        stage="rendering",
        progress=0,
    )
    deck_store.save(new_deck)

    # Save original PDF locally
    deck_dir = deck_store.get_deck_dir(new_deck.id)
    with open(os.path.join(deck_dir, "deck.pdf"), "wb") as f:
        f.write(pdf_bytes)

    # 7. Dispatch background worker
    background_tasks.add_task(
        _run_deck_pipeline,
        deck_id=new_deck.id,
        pdf_bytes=pdf_bytes,
        audience=audience,
        time_limit_seconds=time_limit_seconds,
        goal=goal,
        user_id=current_user.id,
    )

    return {
        "deck_id": new_deck.id,
        "status": "processing",
    }


@router.get(
    "",
    response_model=List[SlideDeckResponse],
    summary="List all saved presentation decks for the current user",
)
def list_user_decks(
    current_user: User = Depends(get_current_user),
):
    decks = deck_store.list_user_decks(current_user.id)
    results = []
    for deck in decks:
        summary_obj = DeckSummary.model_validate(deck.deck_summary) if deck.deck_summary else None
        slides_objs = [SlideCoaching.model_validate(s) for s in deck.slides]
        results.append(
            SlideDeckResponse(
                id=deck.id,
                filename=deck.filename,
                audience=deck.audience,
                time_limit_seconds=deck.time_limit_seconds,
                goal=deck.goal,
                status=deck.status,
                stage=deck.stage,
                progress=deck.progress,
                page_count=deck.page_count,
                deck_summary=summary_obj,
                slides=slides_objs,
                created_at=deck.created_at.isoformat() if hasattr(deck.created_at, "isoformat") else str(deck.created_at),
                updated_at=deck.updated_at.isoformat() if hasattr(deck.updated_at, "isoformat") else str(deck.updated_at),
            )
        )
    return results


@router.post(
    "/{deck_id}/reanalyze",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Re-run AI coaching analysis on an existing deck",
)
def reanalyze_deck(
    deck_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    pdf_path = os.path.join(deck_store.get_deck_dir(deck.id), "deck.pdf")
    if not os.path.exists(pdf_path):
        raise HTTPException(status_code=404, detail="Original deck PDF file not found on server")

    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()

    deck.status = "processing"
    deck.stage = "rendering"
    deck.progress = 0
    deck.error = None
    deck.failure_reason = None
    deck_store.save(deck)

    background_tasks.add_task(
        _run_deck_pipeline,
        deck_id=deck.id,
        pdf_bytes=pdf_bytes,
        audience=deck.audience,
        time_limit_seconds=deck.time_limit_seconds,
        goal=deck.goal,
        user_id=current_user.id,
    )

    return {"status": "reanalyzing", "deck_id": deck.id}


@router.get(
    "/{deck_id}/status",
    response_model=SlideDeckStatusResponse,
    summary="Poll processing status and progress for a deck",
)
def get_deck_status(
    deck_id: str,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    return SlideDeckStatusResponse(
        deck_id=deck.id,
        status=deck.status,
        stage=deck.stage,
        progress=deck.progress,
        error=deck.error,
    )


@router.get(
    "/{deck_id}",
    response_model=SlideDeckResponse,
    summary="Get full structured coaching result for a deck",
)
def get_deck_details(
    deck_id: str,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    summary_obj = DeckSummary.model_validate(deck.deck_summary) if deck.deck_summary else None
    slides_objs = [SlideCoaching.model_validate(s) for s in deck.slides]

    return SlideDeckResponse(
        id=deck.id,
        filename=deck.filename,
        audience=deck.audience,
        time_limit_seconds=deck.time_limit_seconds,
        goal=deck.goal,
        status=deck.status,
        stage=deck.stage,
        progress=deck.progress,
        page_count=deck.page_count,
        deck_summary=summary_obj,
        slides=slides_objs,
        created_at=deck.created_at.isoformat() if hasattr(deck.created_at, "isoformat") else str(deck.created_at),
        updated_at=deck.updated_at.isoformat() if hasattr(deck.updated_at, "isoformat") else str(deck.updated_at),
    )


@router.get(
    "/{deck_id}/slides/{slide_number}/image",
    summary="Serve rendered JPEG image for a slide",
)
def get_slide_image(
    deck_id: str,
    slide_number: int,
):
    image_path = deck_store.get_slide_image_path(deck_id, slide_number)
    if not os.path.exists(image_path):
        raise HTTPException(status_code=404, detail="Slide image not found")

    return FileResponse(
        image_path,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.patch(
    "/{deck_id}/slides/{slide_number}",
    summary="Save user edits to a slide's talking points or script",
)
def patch_slide_coaching(
    deck_id: str,
    slide_number: int,
    patch_req: SlidePatchRequest,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    found = False
    for s in deck.slides:
        if s.get("slide_number") == slide_number:
            found = True
            if patch_req.talking_points is not None:
                s["talking_points"] = patch_req.talking_points
            if patch_req.suggested_script is not None:
                s["suggested_script"] = patch_req.suggested_script
            if patch_req.slide_title is not None:
                s["slide_title"] = patch_req.slide_title
            if patch_req.target_duration_seconds is not None:
                s["target_duration_seconds"] = patch_req.target_duration_seconds
            break

    if not found:
        raise HTTPException(status_code=404, detail=f"Slide {slide_number} not found in deck")

    deck_store.save(deck)
    return {"status": "saved", "slide_number": slide_number}


@router.delete(
    "/{deck_id}",
    summary="Delete a slide deck and its rendered assets",
)
def delete_deck(
    deck_id: str,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    deck_store.delete(deck_id)
    return {"status": "deleted", "deck_id": deck_id}


# ─────────────────────────────────────────────────────────────────────────────
# Rehearsal Mode Endpoint
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/{deck_id}/rehearse",
    response_model=DeckRehearsalResponse,
    summary="Submit recorded audio and slide transition timestamps for rehearsal coaching",
)
async def rehearse_deck(
    deck_id: str,
    file: UploadFile = File(...),
    slide_timestamps: str = Form(...),  # JSON array string: [{"slide_number": 1, "entered_at_ms": 0}, ...]
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    # 1. Parse timestamps JSON
    try:
        markers = json.loads(slide_timestamps)
        if not isinstance(markers, list) or not markers:
            raise ValueError("slide_timestamps must be a non-empty array of objects")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid slide_timestamps JSON: {e}")

    # 2. Save uploaded audio to a temporary file
    ext = os.path.splitext(file.filename or ".m4a")[1] or ".m4a"
    fd, tmp_audio_path = tempfile.mkstemp(suffix=ext)
    os.close(fd)
    try:
        max_bytes = settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024
        content = await file.read(max_bytes + 1)
        if len(content) > max_bytes:
            raise HTTPException(status_code=413, detail="Audio file exceeds size limit")
        if not content:
            raise HTTPException(status_code=400, detail="Audio file is empty")

        with open(tmp_audio_path, "wb") as f:
            f.write(content)

        client = Groq(api_key=get_groq_key("audio"))
        whisper_model = settings.GROQ_WHISPER_MODEL
        text_model = settings.GROQ_TEXT_MODEL

        # 3. Run Rehearsal Pipeline
        report = run_slide_rehearsal_pipeline(
            audio_path=tmp_audio_path,
            slide_timestamps=markers,
            deck_data=deck.to_dict(),
            client=client,
            whisper_model=whisper_model,
            text_model=text_model,
        )

        rehearsal_id = str(uuid.uuid4())
        created_at_str = datetime.now(timezone.utc).isoformat()
        report_record = {
            "rehearsal_id": rehearsal_id,
            "created_at": created_at_str,
            **report,
        }

        # 4. Save to deck rehearsals list & persist in MongoDB
        deck.rehearsals.append(report_record)
        deck_store.save(deck)

        return DeckRehearsalResponse(
            rehearsal_id=rehearsal_id,
            deck_id=deck.id,
            total_duration_seconds=report["total_duration_seconds"],
            time_limit_seconds=report["time_limit_seconds"],
            overall_wpm=report["overall_wpm"],
            overall_filler_count=report["overall_filler_count"],
            overall_coverage_percentage=report["overall_coverage_percentage"],
            overall_feedback=report["overall_feedback"],
            slide_reports=[SlideRehearsalReport.model_validate(r) for r in report["slide_reports"]],
            created_at=created_at_str,
        )

    finally:
        if os.path.exists(tmp_audio_path):
            os.remove(tmp_audio_path)


# ─────────────────────────────────────────────────────────────────────────────
# Q&A Mode Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/{deck_id}/qa/questions",
    response_model=QaQuestionsResponse,
    summary="Generate audience-specific tough Q&A questions for this deck",
)
def generate_questions(
    deck_id: str,
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    client = Groq(api_key=get_groq_key())
    text_model = settings.GROQ_TEXT_MODEL

    questions_raw = generate_qa_questions(
        deck_summary=deck.deck_summary or {},
        slides=deck.slides,
        audience=deck.audience,
        client=client,
        model=text_model,
    )

    qa_list = []
    for i, q in enumerate(questions_raw):
        qa_list.append(QaQuestion(
            id=q.get("id") or f"q{i+1}",
            question=q.get("question", ""),
            why_they_ask=q.get("why_they_ask", ""),
            targeted_slide_number=q.get("targeted_slide_number"),
        ))

    deck.qa_questions = [q.model_dump() for q in qa_list]
    deck_store.save(deck)

    return QaQuestionsResponse(deck_id=deck.id, questions=qa_list)


@router.post(
    "/{deck_id}/qa/answer",
    response_model=QaEvaluationResponse,
    summary="Grade spoken answer to a Q&A question with Whisper + Coach scoring",
)
async def evaluate_answer(
    deck_id: str,
    question_id: str = Form(...),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    deck = deck_store.get(deck_id)
    if not deck or deck.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Deck not found")

    # Find question
    target_q = None
    for q in deck.qa_questions:
        if q.get("id") == question_id:
            target_q = q
            break
    if not target_q:
        raise HTTPException(status_code=404, detail=f"Question {question_id} not found in deck")

    ext = os.path.splitext(file.filename or ".m4a")[1] or ".m4a"
    fd, tmp_audio_path = tempfile.mkstemp(suffix=ext)
    os.close(fd)
    try:
        max_bytes = settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024
        content = await file.read(max_bytes + 1)
        if len(content) > max_bytes:
            raise HTTPException(status_code=413, detail="Audio file exceeds size limit")
        if not content:
            raise HTTPException(status_code=400, detail="Audio file is empty")

        with open(tmp_audio_path, "wb") as f:
            f.write(content)

        client = Groq(api_key=get_groq_key("audio"))
        whisper_model = settings.GROQ_WHISPER_MODEL
        text_model = settings.GROQ_TEXT_MODEL

        eval_result = evaluate_qa_answer(
            question=target_q["question"],
            why_they_ask=target_q.get("why_they_ask", ""),
            audio_path=tmp_audio_path,
            client=client,
            whisper_model=whisper_model,
            text_model=text_model,
        )

        return QaEvaluationResponse(
            question_id=question_id,
            question=target_q["question"],
            spoken_transcript=eval_result.get("spoken_transcript", ""),
            clarity_score=eval_result.get("clarity_score", 70),
            directness_score=eval_result.get("directness_score", 70),
            evidence_score=eval_result.get("evidence_score", 70),
            confidence_score=eval_result.get("confidence_score", 70),
            overall_score=eval_result.get("overall_score", 70),
            critique=eval_result.get("critique", ""),
            sample_better_answer=eval_result.get("sample_better_answer", ""),
        )

    finally:
        if os.path.exists(tmp_audio_path):
            os.remove(tmp_audio_path)


# ─────────────────────────────────────────────────────────────────────────────
# Maintenance / Cleanup Endpoint
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/cleanup",
    summary="Cleanup decks and rendered files older than TTL (default 7 days) (Admin only)",
)
def cleanup_old_decks(
    ttl_days: Optional[int] = Query(None, ge=1, le=365),
    current_user: User = Depends(get_current_user),
):
    settings = get_settings()
    admin_ids = settings.admin_user_id_list
    if not admin_ids or current_user.id not in admin_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required to trigger deck maintenance cleanup",
        )
    deleted_count = deck_store.cleanup_expired(ttl_days)
    return {"deleted_count": deleted_count}
