"""
FastAPI router for Personalized Practice Plan (Feature 6).
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status

from auth.dependencies import get_current_user
from d1.d1_client import get_d1_client
from database.mongodb import get_db, MongoDatabaseWrapper
from limiter import limiter
from models import User
from practice_plan.schemas import (
    CompleteDrillRequest,
    PracticePlanResponse,
)
from practice_plan.service import get_practice_plan, mark_drill_completed

router = APIRouter(prefix="/practice-plan", tags=["practice-plan"])


@router.get(
    "",
    response_model=PracticePlanResponse,
    summary="Get user's personalized practice plan and 3 targeted drills",
)
@limiter.limit("30/minute")
def get_practice_plan_endpoint(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """
    Analyzes last N sessions to detect weakest metric (WPM, fillers, pauses, or clarity)
    and prescribes 3 targeted drills with completion criteria.
    Returns sensible onboarding drills if user has no session history.
    """
    try:
        plan = get_practice_plan(user_id=current_user.id, db=db)
        return plan
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate practice plan: {str(exc)}",
        )


@router.post(
    "/complete",
    summary="Mark a targeted practice drill complete",
)
@limiter.limit("30/minute")
def complete_drill_endpoint(
    request: Request,
    body: CompleteDrillRequest,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Explicitly marks a drill as completed by the user."""
    ok = mark_drill_completed(user_id=current_user.id, drill_id=body.drill_id, db=db)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to record drill completion.",
        )
    return {"status": "success", "drill_id": body.drill_id, "is_completed": True}
