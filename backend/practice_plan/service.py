"""
Personalized Practice Plan Service (Feature 6).
Aggregates recent session metrics, diagnoses user weaknesses,
generates targeted drills, and verifies drill completions.
"""
from datetime import datetime, timezone
import logging
from typing import Any, Dict, List, Optional, Tuple

from d1.d1_client import get_d1_client
from database.mongodb import get_db, SESSIONS_COL, USERS_COL
from practice_plan.schemas import (
    MetricDiagnosis,
    PracticeDrill,
    PracticePlanResponse,
)

logger = logging.getLogger(__name__)

# Sensible default onboarding drills for users with 0 sessions
DEFAULT_DRILLS = [
    PracticeDrill(
        id="drill_default_zero_fillers",
        title="30 Seconds, Zero Fillers",
        description="Deliver a crisp introduction for at least 30 seconds without saying 'um', 'like', or 'uh'.",
        target_metric="fillers",
        target_duration_seconds=30,
        success_criteria={"max_filler_count": 0, "min_duration_seconds": 25.0},
        reason="Mastering a clean 30-second start establishes immediate executive presence.",
    ),
    PracticeDrill(
        id="drill_default_pacing_metronome",
        title="Steady Cadence (120–160 WPM)",
        description="Practice speaking at an optimal conversational tempo between 120 and 160 words per minute for 60 seconds.",
        target_metric="wpm",
        target_duration_seconds=60,
        success_criteria={"min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 45.0},
        reason="120–160 WPM is the golden standard for clear comprehension and listener retention.",
    ),
    PracticeDrill(
        id="drill_default_controlled_pauses",
        title="Controlled Pauses Mastery",
        description="Speak for 45 seconds using deliberate breaths, ensuring no awkward pauses exceed 1.5 seconds.",
        target_metric="pauses",
        target_duration_seconds=45,
        success_criteria={"max_long_pauses": 1, "min_duration_seconds": 35.0},
        reason="Deliberate pauses allow listeners to absorb your core value proposition.",
    ),
]


def _fetch_last_n_sessions(
    user_id: str,
    n_sessions: int = 5,
    db=None,
    d1=None,
) -> List[Dict[str, Any]]:
    """Fetches user's last N analyzed sessions, first from D1 then Firestore fallback."""
    sessions: List[Dict[str, Any]] = []

    # 1. Try D1
    try:
        client = d1 or get_d1_client()
        query = (
            "SELECT id, duration_seconds, wpm, filler_word_count, pause_count, "
            "clarity_score, confidence_score, overall_score, local_date, created_at "
            "FROM session_metrics "
            "WHERE user_id = ? AND status = 'analyzed' "
            "ORDER BY created_at DESC LIMIT ?"
        )
        rows = client.query(query, [user_id, n_sessions])
        if rows:
            return rows
    except Exception as exc:
        logger.debug("[PracticePlan] D1 query fallback to Firestore: %s", exc)

    # 2. MongoDB fallback
    try:
        mongo_db = db or get_db()
        cursor = (
            mongo_db[SESSIONS_COL]
            .find({"user_id": user_id, "is_analyzed": True})
            .sort("created_at", -1)
            .limit(n_sessions)
        )
        for doc in cursor:
            sessions.append(doc)
        return sessions
    except Exception as exc:
        logger.warning("[PracticePlan] MongoDB query error: %s", exc)
        return []


def _diagnose_metrics(sessions: List[Dict[str, Any]]) -> MetricDiagnosis:
    """Diagnoses the user's primary speech weakness from aggregated session history."""
    if not sessions:
        return MetricDiagnosis(
            weakest_metric="onboarding",
            avg_wpm=0.0,
            avg_fillers_per_100=0.0,
            avg_pause_count=0.0,
            sessions_analyzed=0,
            score_trend="insufficient_data",
            diagnostics_summary="Complete your first session to unlock personalized AI diagnostic drills.",
        )

    count = len(sessions)
    wpms = [float(s.get("wpm", 0.0) or 0.0) for s in sessions]
    fillers = [int(s.get("filler_word_count", 0) or 0) for s in sessions]
    durations = [float(s.get("duration_seconds", 0.0) or 0.0) for s in sessions]
    pauses = [int(s.get("pause_count", 0) or 0) for s in sessions]
    scores = [float(s.get("overall_score", 0.0) or 0.0) for s in sessions]

    avg_wpm = round(sum(wpms) / count, 1)
    total_duration_minutes = sum(durations) / 60.0
    total_words = sum(wpms[i] * (durations[i] / 60.0) for i in range(count))

    if total_words > 0:
        avg_fillers_per_100 = round((sum(fillers) / total_words) * 100, 2)
    else:
        avg_fillers_per_100 = round(sum(fillers) / max(1, count), 1)

    avg_pause_count = round(sum(pauses) / count, 1)

    # Score trend: compare older half with newer half
    if count >= 2:
        mid = count // 2
        recent_avg = sum(scores[:mid]) / max(1, mid)
        older_avg = sum(scores[mid:]) / max(1, count - mid)
        if recent_avg - older_avg >= 3.0:
            trend = "improving"
        elif older_avg - recent_avg >= 3.0:
            trend = "declining"
        else:
            trend = "steady"
    else:
        trend = "insufficient_data"

    # Weakness scoring
    # 1. Filler penalty: ideal is < 2.0 per 100 words
    filler_deficit = max(0.0, (avg_fillers_per_100 - 2.0) * 10.0)

    # 2. Pacing penalty: ideal is 120 - 160 WPM
    if avg_wpm < 120:
        wpm_deficit = (120 - avg_wpm) * 0.8
    elif avg_wpm > 160:
        wpm_deficit = (avg_wpm - 160) * 0.8
    else:
        wpm_deficit = 0.0

    # 3. Pause penalty: ideal is <= 2 long pauses per minute
    duration_min = max(0.5, total_duration_minutes)
    pauses_per_min = sum(pauses) / duration_min
    pause_deficit = max(0.0, (pauses_per_min - 2.0) * 8.0)

    deficits = {
        "fillers": filler_deficit,
        "wpm": wpm_deficit,
        "pauses": pause_deficit,
    }

    weakest = max(deficits, key=deficits.get)

    if deficits[weakest] <= 2.0:
        weakest = "clarity"
        summary = (
            f"Strong baseline across {count} sessions! Pacing ({avg_wpm:.0f} WPM) and "
            f"fillers ({avg_fillers_per_100:.1f}/100w) are within optimal thresholds."
        )
    elif weakest == "fillers":
        summary = (
            f"High filler frequency ({avg_fillers_per_100:.1f} per 100 words). "
            f"Targeting deliberate micro-pauses will immediately elevate clarity."
        )
    elif weakest == "wpm":
        pace_label = "rushing" if avg_wpm > 160 else "dragging"
        summary = (
            f"Speaking rate is {pace_label} at {avg_wpm:.0f} WPM (target band: 120–160 WPM). "
            f"Focusing on rhythm drills will stabilize listener attention."
        )
    else:
        summary = (
            f"Frequent long pauses ({avg_pause_count:.1f} per session). "
            f"Practicing phrase transitions will smooth your verbal delivery."
        )

    return MetricDiagnosis(
        weakest_metric=weakest,
        avg_wpm=avg_wpm,
        avg_fillers_per_100=avg_fillers_per_100,
        avg_pause_count=avg_pause_count,
        sessions_analyzed=count,
        score_trend=trend,
        diagnostics_summary=summary,
    )


def _generate_targeted_drills(diagnosis: MetricDiagnosis) -> List[PracticeDrill]:
    """Generates 3 customized drills targeting the diagnosed weak metric."""
    weakest = diagnosis.weakest_metric

    if weakest == "fillers":
        return [
            PracticeDrill(
                id="drill_zero_fillers_30s",
                title="30 Seconds, Zero Fillers",
                description="Deliver your opening statement for 30s without a single 'um', 'uh', or 'like'.",
                target_metric="fillers",
                target_duration_seconds=30,
                success_criteria={"max_filler_count": 0, "min_duration_seconds": 25.0},
                reason=f"Your filler rate was {diagnosis.avg_fillers_per_100:.1f} per 100 words across recent runs.",
            ),
            PracticeDrill(
                id="drill_silent_pause_substitution",
                title="Silent Pause Substitution",
                description="Replace every impulse to use a filler word with a 1-second silent breath for 45s.",
                target_metric="fillers",
                target_duration_seconds=45,
                success_criteria={"max_filler_count": 1, "min_duration_seconds": 40.0},
                reason="Replacing vocalized hesitation with silence conveys confidence and gravitas.",
            ),
            PracticeDrill(
                id="drill_clean_60s_sprint",
                title="60-Second Clean Flow Sprint",
                description="Speak for 60 seconds maintaining under 1 filler word per 100 words.",
                target_metric="fillers",
                target_duration_seconds=60,
                success_criteria={"max_filler_count": 1, "min_duration_seconds": 55.0},
                reason="Builds stamina for multi-minute presentations without filler drift.",
            ),
        ]

    elif weakest == "wpm":
        is_fast = diagnosis.avg_wpm > 160
        title_cadence = "Brisk Enunciation (Slow Down)" if is_fast else "Dynamic Cadence (Pick Up Pace)"
        desc_cadence = (
            "Deliberately speak with calm enunciation between 125 and 150 WPM."
            if is_fast
            else "Energize your delivery and aim for 135 to 155 WPM."
        )

        return [
            PracticeDrill(
                id="drill_metronome_pacing_60s",
                title=title_cadence,
                description=desc_cadence,
                target_metric="wpm",
                target_duration_seconds=60,
                success_criteria={"min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 45.0},
                reason=f"Your average speaking pace was {diagnosis.avg_wpm:.0f} WPM (target band: 120–160 WPM).",
            ),
            PracticeDrill(
                id="drill_rapid_rephrase_45s",
                title="Controlled 45s Hook Sprint",
                description="Deliver a crisp problem-solution pitch staying strictly within the 120–160 WPM band.",
                target_metric="wpm",
                target_duration_seconds=45,
                success_criteria={"min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 35.0},
                reason="Prevents opening anxiety from corrupting your conversational tempo.",
            ),
            PracticeDrill(
                id="drill_zero_fillers_at_target_pace",
                title="Zero Fillers at Target Pace",
                description="Maintain 120–160 WPM pace while keeping filler count to zero for 30 seconds.",
                target_metric="fillers",
                target_duration_seconds=30,
                success_criteria={"max_filler_count": 0, "min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 25.0},
                reason="Combines pacing discipline with verbal clarity.",
            ),
        ]

    elif weakest == "pauses":
        return [
            PracticeDrill(
                id="drill_transition_flow_45s",
                title="Seamless Transition Flow",
                description="Deliver 45 seconds of speech ensuring no pauses stall longer than 1.5 seconds.",
                target_metric="pauses",
                target_duration_seconds=45,
                success_criteria={"max_long_pauses": 1, "min_duration_seconds": 40.0},
                reason=f"You averaged {diagnosis.avg_pause_count:.1f} extended pauses (>1.5s) per session.",
            ),
            PracticeDrill(
                id="drill_30s_bullet_points",
                title="30-Second Bullet Precision",
                description="State 3 key accomplishments or product benefits without hesitation gaps.",
                target_metric="pauses",
                target_duration_seconds=30,
                success_criteria={"max_long_pauses": 0, "min_duration_seconds": 25.0},
                reason="Trains rapid mental indexing so you never get lost mid-sentence.",
            ),
            PracticeDrill(
                id="drill_steady_cadence_60s",
                title="60s Steady Rhythmic Delivery",
                description="Speak for 60 seconds with consistent pacing and brief, purposeful breaths.",
                target_metric="pauses",
                target_duration_seconds=60,
                success_criteria={"max_long_pauses": 2, "min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 50.0},
                reason="Stabilizes breathing patterns across longer answers.",
            ),
        ]

    else:  # clarity / general polish
        return [
            PracticeDrill(
                id="drill_high_clarity_elevator_60s",
                title="Executive Elevator Pitch",
                description="Deliver a crisp 60s summary achieving a clarity score of 85 or above.",
                target_metric="clarity",
                target_duration_seconds=60,
                success_criteria={"min_clarity": 85.0, "min_duration_seconds": 50.0},
                reason="Elevate your baseline clarity score to top-tier executive standards.",
            ),
            PracticeDrill(
                id="drill_zero_fillers_30s",
                title="30 Seconds, Zero Fillers",
                description="30-second rapid answer with zero verbal fillers.",
                target_metric="fillers",
                target_duration_seconds=30,
                success_criteria={"max_filler_count": 0, "min_duration_seconds": 25.0},
                reason="Maintains sharp diction during impromptu responses.",
            ),
            PracticeDrill(
                id="drill_controlled_pauses_45s",
                title="Controlled Cadence & Pauses",
                description="45-second pitch staying in optimal pace with natural micro-pauses.",
                target_metric="wpm",
                target_duration_seconds=45,
                success_criteria={"min_wpm": 120.0, "max_wpm": 160.0, "min_duration_seconds": 40.0},
                reason="Ensures consistent verbal rhythm across all pitch contexts.",
            ),
        ]


def _evaluate_drill_completion(drill: PracticeDrill, session: Dict[str, Any]) -> bool:
    """Evaluates if a practice session satisfies the success criteria of a drill."""
    crit = drill.success_criteria
    duration = float(session.get("duration_seconds", 0.0) or 0.0)
    wpm = float(session.get("wpm", 0.0) or 0.0)
    fillers = int(session.get("filler_word_count", 0) or 0)
    pauses = int(session.get("pause_count", 0) or 0)
    clarity = float(session.get("clarity_score", 0.0) or 0.0)

    # Check minimum duration if specified
    if "min_duration_seconds" in crit and duration < crit["min_duration_seconds"]:
        return False

    # Check max fillers
    if "max_filler_count" in crit and fillers > crit["max_filler_count"]:
        return False

    # Check WPM range
    if "min_wpm" in crit and wpm < crit["min_wpm"]:
        return False
    if "max_wpm" in crit and wpm > crit["max_wpm"]:
        return False

    # Check pauses
    if "max_long_pauses" in crit and pauses > crit["max_long_pauses"]:
        return False

    # Check clarity
    if "min_clarity" in crit and clarity < crit["min_clarity"]:
        return False

    return True


def get_practice_plan(
    user_id: str,
    db=None,
    d1=None,
    n_sessions: int = 5,
) -> PracticePlanResponse:
    """
    Constructs personalized practice plan for user.
    - If 0 sessions, returns sensible defaults.
    - If >= 1 sessions, diagnoses weakest metric and returns 3 targeted drills.
    - Checks completion status against completed list and recent sessions.
    """
    sessions = _fetch_last_n_sessions(user_id=user_id, n_sessions=n_sessions, db=db, d1=d1)

    if not sessions:
        diagnosis = _diagnose_metrics([])
        drills = [d.model_copy() for d in DEFAULT_DRILLS]
        is_default = True
    else:
        diagnosis = _diagnose_metrics(sessions)
        drills = _generate_targeted_drills(diagnosis)
        is_default = False

    # Fetch user's recorded completed drills from MongoDB
    mongo_db = db or get_db()
    completed_drill_ids = set()
    try:
        user_doc = mongo_db.collection(USERS_COL).document(user_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict() or {}
            completed_drill_ids = set(user_data.get("completed_drills", []))
    except Exception as exc:
        logger.debug("[PracticePlan] Error reading completed drills: %s", exc)

    # Also check if the most recent session achieved completion for any drill
    most_recent = sessions[0] if sessions else None

    for drill in drills:
        if drill.id in completed_drill_ids:
            drill.is_completed = True
        elif most_recent and _evaluate_drill_completion(drill, most_recent):
            drill.is_completed = True
            # Persist completion
            try:
                mongo_db.collection(USERS_COL).document(user_id).update({
                    "completed_drills": list(completed_drill_ids | {drill.id})
                })
            except Exception:
                pass

    return PracticePlanResponse(
        diagnosis=diagnosis,
        drills=drills,
        generated_at=datetime.now(timezone.utc),
        is_default_plan=is_default,
    )


def mark_drill_completed(
    user_id: str,
    drill_id: str,
    db=None,
) -> bool:
    """Explicitly marks a practice drill complete for user."""
    mongo_db = db or get_db()
    try:
        user_ref = mongo_db.collection(USERS_COL).document(user_id)
        doc = user_ref.get()
        current = set(doc.to_dict().get("completed_drills", [])) if doc.exists else set()
        current.add(drill_id)
        user_ref.update({"completed_drills": list(current)})
        return True
    except Exception as exc:
        logger.warning("[PracticePlan] Error marking drill complete: %s", exc)
        return False
