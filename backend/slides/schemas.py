"""Pydantic schemas for Slide Coach pipeline and API endpoints."""
from typing import List, Optional
from pydantic import BaseModel, Field


# ── Stage B Vision Extraction ──────────────────────────────────────────────────

class SlideVisionDescription(BaseModel):
    slide_number: int
    title: str = ""
    main_message: str = ""
    visible_text: str = ""
    visuals: str = ""
    text_density: str = "medium"  # "low" | "medium" | "high"
    readability_issues: List[str] = Field(default_factory=list)
    too_much_text: bool = False
    weak_title: bool = False
    missing_cta: bool = False
    visual_hierarchy_rating: str = "good"  # "poor" | "fair" | "good" | "excellent"
    design_critique: List[str] = Field(default_factory=list)


class BatchVisionResponse(BaseModel):
    slides: List[SlideVisionDescription] = Field(default_factory=list)


# ── Stage C Coaching Synthesis ────────────────────────────────────────────────

class DeckSummary(BaseModel):
    story_arc: str
    missing_sections: List[str] = Field(default_factory=list)
    overall_score: int = Field(ge=0, le=100)
    top_3_fixes: List[str] = Field(default_factory=list)
    has_problem: bool = False
    has_solution: bool = False
    has_traction: bool = False
    has_ask: bool = False
    missing_pillars: List[str] = Field(default_factory=list)
    story_arc_warnings: List[str] = Field(default_factory=list)
    audience: Optional[str] = "investors"


class SlideCoaching(BaseModel):
    slide_number: int
    slide_title: str
    target_duration_seconds: int = Field(ge=5)
    key_takeaway: str
    talking_points: List[str] = Field(default_factory=list)
    suggested_script: Optional[str] = None
    transition_to_next: str = ""
    slide_critique: List[str] = Field(default_factory=list)
    image_url: Optional[str] = None
    visuals: Optional[str] = None
    text_density: Optional[str] = None
    readability_issues: List[str] = Field(default_factory=list)
    too_much_text: bool = False
    weak_title: bool = False
    missing_cta: bool = False
    visual_hierarchy_rating: str = "good"
    design_critique: List[str] = Field(default_factory=list)
    audience_tip: Optional[str] = None
    what_to_emphasize: Optional[str] = None
    what_to_avoid: Optional[str] = None
    delivery_pacing: Optional[str] = None


class DeckCoachingResult(BaseModel):
    deck_summary: DeckSummary
    slides: List[SlideCoaching]


# ── API Requests & Responses ──────────────────────────────────────────────────

class SlidePatchRequest(BaseModel):
    talking_points: Optional[List[str]] = None
    suggested_script: Optional[str] = None
    slide_title: Optional[str] = None
    target_duration_seconds: Optional[int] = None


class SlideDeckStatusResponse(BaseModel):
    deck_id: str
    status: str          # "processing" | "done" | "failed"
    stage: str           # "rendering" | "reading_slides" | "writing_coaching"
    progress: int        # 0 to 100
    error: Optional[str] = None
    failure_reason: Optional[str] = None


class SlideDeckResponse(BaseModel):
    id: str
    filename: str
    audience: str
    time_limit_seconds: int
    goal: str
    status: str
    stage: str
    progress: int
    error: Optional[str] = None
    failure_reason: Optional[str] = None
    page_count: int
    deck_summary: Optional[DeckSummary] = None
    slides: List[SlideCoaching] = Field(default_factory=list)
    created_at: str
    updated_at: str


# ── Rehearsal Schemas ─────────────────────────────────────────────────────────

class SlideTimestamp(BaseModel):
    slide_number: int
    entered_at_ms: int


class SlideTalkingPointCoverage(BaseModel):
    point: str
    covered: bool
    evidence: Optional[str] = None


class SlideRehearsalReport(BaseModel):
    slide_number: int
    slide_title: str
    target_duration_seconds: int
    actual_duration_seconds: float
    wpm: float
    filler_count: int
    filler_breakdown: dict = Field(default_factory=dict)
    transcript: str
    talking_points_coverage: List[SlideTalkingPointCoverage] = Field(default_factory=list)
    coverage_percentage: float
    ai_feedback: List[dict] = Field(default_factory=list)


class DeckRehearsalResponse(BaseModel):
    rehearsal_id: str
    deck_id: str
    total_duration_seconds: float
    time_limit_seconds: int
    overall_wpm: float
    overall_filler_count: int
    overall_coverage_percentage: float
    overall_feedback: List[str] = Field(default_factory=list)
    slide_reports: List[SlideRehearsalReport] = Field(default_factory=list)
    created_at: str


# ── Q&A Prep Schemas ──────────────────────────────────────────────────────────

class QaQuestion(BaseModel):
    id: str
    question: str
    why_they_ask: str
    targeted_slide_number: Optional[int] = None


class QaQuestionsResponse(BaseModel):
    deck_id: str
    questions: List[QaQuestion]


class QaEvaluationResponse(BaseModel):
    question_id: str
    question: str
    spoken_transcript: str
    clarity_score: int
    directness_score: int
    evidence_score: int
    confidence_score: int
    overall_score: int
    critique: str
    sample_better_answer: str
