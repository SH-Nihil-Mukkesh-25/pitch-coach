"""Achievements: evaluate criteria, persist unlocks, return full list."""
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from achievements.challenges import (
    evaluate_user_challenges,
    get_current_week_id,
)
from achievements.leaderboard import get_weekly_leaderboard
from auth.dependencies import get_current_user
from database.mongodb import get_db, MongoDatabaseWrapper, SESSIONS_COL, ACHIEVEMENTS_COL, USERS_COL
from models import Achievement, PracticeSession, User
from schemas import (
    AchievementResponse,
    ChallengeResponse,
    ClaimChallengeResponse,
    LeaderboardResponse,
)

router = APIRouter(prefix="/achievements", tags=["achievements"])



# ─────────────────────────────────────────────────────────────────────────────
# Achievement definitions
# ─────────────────────────────────────────────────────────────────────────────

def _has_n_day_streak(sessions: list, n: int) -> bool:
    dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
    if not dates:
        return False
    streak, prev = 1, dates[0]
    for d in dates[1:]:
        if (prev - d).days == 1:
            streak += 1
            if streak >= n:
                return True
            prev = d
        else:
            streak, prev = 1, d
    return streak >= n


ACHIEVEMENT_DEFS: List[dict] = [
    {
        "key": "first_session",
        "title": "First Step",
        "icon": "mic",
        "check": lambda s, _u: len(s) >= 1,
        "desc": lambda s, _u: "Complete your first practice session.",
    },
    {
        "key": "7_day_streak",
        "title": "7-Day Streak",
        "icon": "fire",
        "check": lambda s, _u: _has_n_day_streak(s, 7),
        "desc": lambda s, _u: "Practice 7 days in a row.",
    },
    {
        "key": "50_sessions",
        "title": "50 Sessions",
        "icon": "target",
        "check": lambda s, _u: len(s) >= 50,
        "desc": lambda s, _u: f"Complete 50 practice sessions. {len(s)}/50 so far.",
    },
    {
        "key": "clarity_master",
        "title": "Clarity Master",
        "icon": "diamond",
        "check": lambda s, _u: any((x.clarity_score or 0) >= 85 for x in s),
        "desc": lambda s, _u: "Achieve a clarity score ≥ 85% in any session.",
    },
    {
        "key": "early_bird",
        "title": "Early Bird",
        "icon": "sunrise",
        "check": lambda s, _u: any(x.created_at.hour < 8 for x in s),
        "desc": lambda s, _u: "Complete a session before 8:00 AM.",
    },
]


@router.get("", response_model=List[AchievementResponse])
def get_achievements(
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    # Evaluate and persist any newly eligible unlocks in D1 / Firestore
    from achievements.service import evaluate_user_achievements
    evaluate_user_achievements(current_user.id, db=db)

    # Fetch analyzed sessions
    session_docs = (
        db.collection(SESSIONS_COL)
        .where("user_id", "==", current_user.id)
        .where("is_analyzed", "==", True)
        .get()
    )
    sessions = [PracticeSession.from_dict(d.to_dict()) for d in session_docs]
    sessions = [s for s in sessions if not s.analysis_failed]

    # Fetch existing achievements
    ach_docs = (
        db.collection(ACHIEVEMENTS_COL)
        .where("user_id", "==", current_user.id)
        .get()
    )
    existing = {d.to_dict()["key"]: Achievement.from_dict(d.to_dict()) for d in ach_docs}

    result = []
    for defn in ACHIEVEMENT_DEFS:
        key = defn["key"]
        is_unlocked: bool = defn["check"](sessions, current_user)

        # Persist newly unlocked achievements
        if is_unlocked and key not in existing:
            ach = Achievement(
                id=str(uuid.uuid4()),
                user_id=current_user.id,
                key=key,
                unlocked_at=datetime.now(timezone.utc),
                criteria_met={"session_count": len(sessions)},
            )
            db.collection(ACHIEVEMENTS_COL).document(ach.id).set(ach.to_dict())
            existing[key] = ach

        unlocked_at = existing[key].unlocked_at if (key in existing and is_unlocked) else None

        result.append(AchievementResponse(
            key=key,
            title=defn["title"],
            icon=defn["icon"],
            is_unlocked=is_unlocked,
            unlocked_at=unlocked_at,
            description=defn["desc"](sessions, current_user),
        ))

    return result


# ─────────────────────────────────────────────────────────────────────────────
# Weekly Challenges & Privacy Leaderboard
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/challenges", response_model=List[ChallengeResponse])
def get_challenges(
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns rotating weekly challenges with user's progress and claim status."""
    week_id = get_current_week_id()
    claimed_challenges = set(
        current_user.settings.get("claimed_challenges", {}).get(week_id, [])
    )
    raw_challenges = evaluate_user_challenges(
        user_id=current_user.id,
        claimed_set=claimed_challenges,
        db=db,
    )
    return [ChallengeResponse(**c) for c in raw_challenges]


@router.post("/challenges/{challenge_id}/claim", response_model=ClaimChallengeResponse)
def claim_challenge(
    challenge_id: str,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Claims reward XP for a completed weekly challenge."""
    week_id = get_current_week_id()
    user_settings = dict(current_user.settings or {})
    claimed_dict = dict(user_settings.get("claimed_challenges") or {})
    week_claimed = list(claimed_dict.get(week_id) or [])

    if challenge_id in week_claimed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Challenge already claimed for this week.",
        )

    raw_challenges = evaluate_user_challenges(
        user_id=current_user.id,
        claimed_set=set(week_claimed),
        db=db,
    )
    target_c = next((c for c in raw_challenges if c["id"] == challenge_id), None)
    if not target_c:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Challenge '{challenge_id}' not found.",
        )
    if not target_c["is_completed"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Challenge criteria not yet completed.",
        )

    # Award points and update claimed list
    reward_points = target_c["reward_points"]
    week_claimed.append(challenge_id)
    claimed_dict[week_id] = week_claimed
    user_settings["claimed_challenges"] = claimed_dict
    current_points = int(user_settings.get("gamification_points") or 0) + reward_points
    user_settings["gamification_points"] = current_points

    if db:
        try:
            db.collection(USERS_COL).document(current_user.id).update({
                "settings": user_settings,
            })
        except Exception:
            pass
    current_user.settings = user_settings

    return ClaimChallengeResponse(
        success=True,
        challenge_id=challenge_id,
        reward_points=reward_points,
        total_claimed_points=current_points,
        message=f"Challenge '{target_c['title']}' claimed! +{reward_points} XP awarded.",
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    opt_in: Optional[bool] = Query(None, description="Toggle leaderboard opt-in preference"),
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Returns privacy-preserving weekly leaderboard, with optional opt-in toggle."""
    if opt_in is not None:
        user_settings = dict(current_user.settings or {})
        user_settings["leaderboard_opt_in"] = opt_in
        current_user.settings = user_settings
        if db:
            try:
                db.collection(USERS_COL).document(current_user.id).update({
                    "settings": user_settings,
                })
            except Exception:
                pass

    board = get_weekly_leaderboard(
        current_user_id=current_user.id,
        limit=20,
        db=db,
    )
    return LeaderboardResponse(**board)

