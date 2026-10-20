"""
Plain Python dataclasses that mirror Firestore document shapes.
No SQLAlchemy — documents are dicts in Firestore; these classes are used
for type-safety inside the Python backend only.
"""
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


def _gen_uuid() -> str:
    return str(uuid.uuid4())


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


# ─────────────────────────────────────────────────────────────────────────────
# Firestore collection names
# ─────────────────────────────────────────────────────────────────────────────

USERS_COL = "users"
SESSIONS_COL = "sessions"
ACHIEVEMENTS_COL = "achievements"
SLIDE_DECKS_COL = "slide_decks"
FEEDBACK_COL = "feedback"


# ─────────────────────────────────────────────────────────────────────────────
# Data shapes (used as typed dicts when reading/writing Firestore docs)
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class User:
    id: str = field(default_factory=_gen_uuid)
    email: Optional[str] = None
    password_hash: Optional[str] = None
    full_name: str = "Guest User"
    role_occupation: str = ""
    primary_objective: str = "Technical Interviews & Pitch Presentations"
    target_industry: str = "Software & Technology"
    experience_level: str = "Intermediate"
    feedback_style: str = "Encouraging & Constructive"
    is_guest: bool = False
    dark_mode: bool = False
    avatar_url: Optional[str] = None
    settings: Dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=_now_utc)
    expires_at: Optional[datetime] = None

    # ── Firestore helpers ──────────────────────────────────────────────────

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "email": self.email,
            "password_hash": self.password_hash,
            "full_name": self.full_name,
            "role_occupation": self.role_occupation,
            "primary_objective": self.primary_objective,
            "target_industry": self.target_industry,
            "experience_level": self.experience_level,
            "feedback_style": self.feedback_style,
            "is_guest": self.is_guest,
            "dark_mode": self.dark_mode,
            "avatar_url": self.avatar_url,
            "settings": self.settings,
            "created_at": self.created_at,
            "expires_at": self.expires_at,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "User":
        return User(
            id=d.get("id", ""),
            email=d.get("email"),
            password_hash=d.get("password_hash"),
            full_name=d.get("full_name", "Guest User"),
            role_occupation=d.get("role_occupation", ""),
            primary_objective=d.get("primary_objective", ""),
            target_industry=d.get("target_industry", ""),
            experience_level=d.get("experience_level", "Intermediate"),
            feedback_style=d.get("feedback_style", "Encouraging & Constructive"),
            is_guest=d.get("is_guest", False),
            dark_mode=d.get("dark_mode", False),
            avatar_url=d.get("avatar_url"),
            settings=d.get("settings") or {},
            created_at=d.get("created_at") or _now_utc(),
            expires_at=d.get("expires_at"),
        )


@dataclass
class PracticeSession:
    id: str = field(default_factory=_gen_uuid)
    user_id: str = ""
    parent_session_id: Optional[str] = None
    template_id: Optional[str] = None
    structure_score: Optional[float] = None
    template_sections_detected: Optional[List[str]] = None
    template_sections_missing: Optional[List[str]] = None
    mode: str = "interview"
    topic_or_question: str = "Tell me about yourself."
    audio_url: Optional[str] = None
    duration_seconds: float = 0.0
    transcript: Optional[str] = None
    word_timestamps: Optional[List[Dict[str, Any]]] = None
    audio_offset_seconds: float = 0.0

    wpm: float = 0.0
    filler_word_count: int = 0
    filler_word_breakdown: Dict[str, int] = field(default_factory=dict)
    pause_count: int = 0
    avg_pause_length: float = 0.0

    clarity_score: float = 0.0
    confidence_score: float = 0.0
    overall_score: float = 0.0

    energy_curve: Optional[List[float]] = None
    pitch_variation_score: Optional[float] = None
    volume_consistency_score: Optional[float] = None
    no_speech: Optional[bool] = None
    active_wpm: Optional[float] = None
    repetitions_count: Optional[int] = None
    rhetorical_pause_count: Optional[int] = None
    disfluent_pause_count: Optional[int] = None

    ai_feedback: List[Dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=_now_utc)
    local_date: Optional[str] = None
    tz_offset_minutes: int = 0
    d1_pending: bool = False
    stage: str = "pending"
    is_analyzed: bool = False
    analysis_failed: bool = False
    failure_reason: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "parent_session_id": self.parent_session_id,
            "template_id": self.template_id,
            "structure_score": self.structure_score,
            "template_sections_detected": self.template_sections_detected or [],
            "template_sections_missing": self.template_sections_missing or [],
            "energy_curve": self.energy_curve or [],
            "pitch_variation_score": self.pitch_variation_score,
            "volume_consistency_score": self.volume_consistency_score,
            "no_speech": self.no_speech,
            "active_wpm": self.active_wpm,
            "repetitions_count": self.repetitions_count,
            "rhetorical_pause_count": self.rhetorical_pause_count,
            "disfluent_pause_count": self.disfluent_pause_count,
            "mode": self.mode,
            "topic_or_question": self.topic_or_question,
            "audio_url": self.audio_url,
            "duration_seconds": self.duration_seconds,
            "transcript": self.transcript,
            "word_timestamps": self.word_timestamps or [],
            "audio_offset_seconds": self.audio_offset_seconds,
            "wpm": self.wpm,
            "filler_word_count": self.filler_word_count,
            "pause_count": self.pause_count,
            "avg_pause_length": self.avg_pause_length,
            "clarity_score": self.clarity_score,
            "confidence_score": self.confidence_score,
            "overall_score": self.overall_score,
            "ai_feedback": self.ai_feedback,
            "created_at": self.created_at,
            "local_date": self.local_date,
            "tz_offset_minutes": self.tz_offset_minutes,
            "d1_pending": self.d1_pending,
            "stage": self.stage,
            "metrics": {
                "wpm": self.wpm,
                "overall": self.overall_score,
                "clarity": self.clarity_score,
                "confidence": self.confidence_score,
                "pause_count": self.pause_count,
                "duration": self.duration_seconds,
                "filler_count": self.filler_word_count,
            },
            "is_analyzed": self.is_analyzed,
            "analysis_failed": self.analysis_failed,
            "failure_reason": self.failure_reason,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "PracticeSession":
        return PracticeSession(
            id=d.get("id", ""),
            user_id=d.get("user_id", ""),
            parent_session_id=d.get("parent_session_id"),
            template_id=d.get("template_id"),
            structure_score=d.get("structure_score"),
            template_sections_detected=d.get("template_sections_detected"),
            template_sections_missing=d.get("template_sections_missing"),
            energy_curve=d.get("energy_curve") or [],
            pitch_variation_score=d.get("pitch_variation_score"),
            volume_consistency_score=d.get("volume_consistency_score"),
            no_speech=d.get("no_speech"),
            active_wpm=d.get("active_wpm"),
            repetitions_count=d.get("repetitions_count"),
            rhetorical_pause_count=d.get("rhetorical_pause_count"),
            disfluent_pause_count=d.get("disfluent_pause_count"),
            mode=d.get("mode", "interview"),
            topic_or_question=d.get("topic_or_question", ""),
            audio_url=d.get("audio_url"),
            duration_seconds=d.get("duration_seconds", 0.0),
            transcript=d.get("transcript"),
            word_timestamps=d.get("word_timestamps") or [],
            audio_offset_seconds=float(d.get("audio_offset_seconds", 0.0)),
            wpm=d.get("wpm", 0.0),
            filler_word_count=d.get("filler_word_count", 0),
            filler_word_breakdown=d.get("filler_word_breakdown", {}),
            pause_count=d.get("pause_count", 0),
            avg_pause_length=d.get("avg_pause_length", 0.0),
            clarity_score=d.get("clarity_score", 0.0),
            confidence_score=d.get("confidence_score", 0.0),
            overall_score=d.get("overall_score", 0.0),
            ai_feedback=d.get("ai_feedback", []),
            created_at=d.get("created_at") or _now_utc(),
            local_date=d.get("local_date"),
            tz_offset_minutes=d.get("tz_offset_minutes", 0),
            d1_pending=d.get("d1_pending", False),
            stage=d.get("stage", "done" if d.get("is_analyzed") else "pending"),
            is_analyzed=d.get("is_analyzed", False),
            analysis_failed=d.get("analysis_failed", False),
            failure_reason=d.get("failure_reason"),
        )


@dataclass
class Achievement:
    id: str = field(default_factory=_gen_uuid)
    user_id: str = ""
    key: str = ""
    unlocked_at: Optional[datetime] = None
    criteria_met: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "key": self.key,
            "unlocked_at": self.unlocked_at,
            "criteria_met": self.criteria_met,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "Achievement":
        return Achievement(
            id=d.get("id", ""),
            user_id=d.get("user_id", ""),
            key=d.get("key", ""),
            unlocked_at=d.get("unlocked_at"),
            criteria_met=d.get("criteria_met", {}),
        )


@dataclass
class SlideDeck:
    id: str = field(default_factory=_gen_uuid)
    user_id: str = ""
    content_hash: str = ""
    filename: str = "deck.pdf"
    audience: str = "investors"
    time_limit_seconds: int = 180
    goal: str = ""
    status: str = "processing"          # processing | done | failed
    stage: str = "rendering"            # rendering | reading_slides | writing_coaching
    progress: int = 0
    error: Optional[str] = None
    failure_reason: Optional[str] = None
    page_count: int = 0
    deck_summary: Optional[Dict[str, Any]] = None
    slides: List[Dict[str, Any]] = field(default_factory=list)
    qa_questions: List[Dict[str, Any]] = field(default_factory=list)
    rehearsals: List[Dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=_now_utc)
    updated_at: datetime = field(default_factory=_now_utc)

    def to_dict(self) -> Dict[str, Any]:
        err = self.failure_reason or self.error
        return {
            "id": self.id,
            "user_id": self.user_id,
            "content_hash": self.content_hash,
            "filename": self.filename,
            "audience": self.audience,
            "time_limit_seconds": self.time_limit_seconds,
            "goal": self.goal,
            "status": self.status,
            "stage": self.stage,
            "progress": self.progress,
            "error": err,
            "failure_reason": err,
            "page_count": self.page_count,
            "deck_summary": self.deck_summary,
            "slides": self.slides,
            "qa_questions": self.qa_questions,
            "rehearsals": self.rehearsals,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "SlideDeck":
        err = d.get("failure_reason") or d.get("error")
        return SlideDeck(
            id=d.get("id", ""),
            user_id=d.get("user_id", ""),
            content_hash=d.get("content_hash", ""),
            filename=d.get("filename", "deck.pdf"),
            audience=d.get("audience", "investors"),
            time_limit_seconds=d.get("time_limit_seconds", 180),
            goal=d.get("goal", ""),
            status=d.get("status", "processing"),
            stage=d.get("stage", "rendering"),
            progress=d.get("progress", 0),
            error=err,
            failure_reason=err,
            page_count=d.get("page_count", 0),
            deck_summary=d.get("deck_summary"),
            slides=d.get("slides", []),
            qa_questions=d.get("qa_questions", []),
            rehearsals=d.get("rehearsals", []),
            created_at=d.get("created_at") or _now_utc(),
            updated_at=d.get("updated_at") or _now_utc(),
        )
