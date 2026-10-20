"""
Multi-Turn AI Interviewer Pipeline.
Evaluates candidate answers per question turn for vagueness (lacks root cause, outcome/metrics, or concrete specifics).
Enforces max 2 follow-ups per question.
Scores the full multi-turn exchange.
"""
import json
import logging
import re
import time
from typing import Dict, List, Optional, Tuple

from groq import Groq
from config import get_settings
from interviewer.schemas import (
    ExchangeScoreResponse,
    TurnEvaluateRequest,
    TurnEvaluateResponse,
    TurnMessage,
)

logger = logging.getLogger(__name__)

LLM_MODEL = "qwen/qwen3.8-27b"
MAX_FOLLOW_UPS = 2


def _heuristic_evaluate_vagueness(
    question: str,
    answer: str,
    follow_up_count: int,
) -> Tuple[bool, Optional[str], str]:
    """
    Deterministic heuristic fallback for when LLM call is unavailable or fails to parse.
    Checks for presence of root cause, concrete specifics, and measurable results.
    """
    if follow_up_count >= MAX_FOLLOW_UPS:
        return (
            False,
            None,
            "Maximum follow-up questions reached (2/2). Moving on to overall exchange evaluation."
        )

    words = answer.strip().split()
    word_count = len(words)
    answer_lower = answer.lower()

    has_root_cause = any(kw in answer_lower for kw in [
        "root cause", "caused by", "because", "due to", "underlying", "diagnosed", "discovered that", "reason was"
    ])
    has_results = any(kw in answer_lower for kw in [
        "result", "improved", "reduced", "increased", "%", "percent", "metric", "latency", "seconds", "outcome", "saving"
    ])
    has_specifics = any(kw in answer_lower for kw in [
        "implemented", "configured", "built", "designed", "architecture", "database", "api", "cache", "service", "algorithm"
    ]) or word_count >= 50

    is_vague = word_count < 25 or not (has_root_cause and (has_results or has_specifics))

    if is_vague:
        if not has_root_cause:
            follow_up = "Could you explain what the exact root cause of the issue was, and how you diagnosed it?"
            reason = "The answer mentions the situation but does not detail the technical root cause or diagnosis."
        elif not has_results:
            follow_up = "What was the measurable outcome or result of the solution you put in place?"
            reason = "The action is clear, but the answer lacks measurable outcomes or business impact."
        else:
            follow_up = "Can you provide more specific implementation details on the steps and tools you personally used?"
            reason = "The answer is high-level and needs concrete technical specifics."
        return (True, follow_up, reason)

    return (
        False,
        None,
        "Clear and comprehensive answer with concrete cause, technical specifics, and results. Ready to move on."
    )


def evaluate_interview_turn(
    request: TurnEvaluateRequest,
    groq_api_key: Optional[str] = None,
    model_override: Optional[str] = None,
) -> TurnEvaluateResponse:
    """
    Evaluates a candidate's answer for an interview turn.
    If the answer lacks root cause, results/metrics, or concrete specifics, asks ONE follow-up.
    Strictly caps follow-ups at 2 per question.
    """
    start_time = time.perf_counter()

    # Rule: strictly cap follow-ups at 2 per question
    if request.follow_up_count >= MAX_FOLLOW_UPS:
        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return TurnEvaluateResponse(
            follow_up=None,
            move_on=True,
            reason=f"Follow-up limit reached ({MAX_FOLLOW_UPS}/{MAX_FOLLOW_UPS}). Advancing to next question.",
            is_vague=False,
            latency_ms=elapsed_ms,
        )

    settings = get_settings()
    api_key = groq_api_key or settings.GROQ_API_KEY or settings.GROQ_AUDIO_API_KEY
    model = model_override or getattr(settings, "GROQ_LLM_MODEL", None) or getattr(settings, "LLM_MODEL", None) or LLM_MODEL

    # If no key, use deterministic evaluation
    if not api_key:
        is_vague, follow_up, reason = _heuristic_evaluate_vagueness(
            request.question,
            request.candidate_answer,
            request.follow_up_count,
        )
        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return TurnEvaluateResponse(
            follow_up=follow_up if is_vague else None,
            move_on=not is_vague,
            reason=reason,
            is_vague=is_vague,
            latency_ms=elapsed_ms,
        )

    # Format dialogue history
    history_str = ""
    for msg in request.turn_history:
        history_str += f"{msg.role.upper()}: {msg.content}\n"

    system_prompt = (
        "You are an expert technical and behavioral placement interviewer conducting a live mock interview.\n"
        "Your task is to evaluate the candidate's latest response to the interview question.\n\n"
        "CRITICAL RULES:\n"
        "1. Check if the answer is VAGUE:\n"
        "   - Does it lack the root cause or underlying explanation?\n"
        "   - Does it lack concrete technical or situational specifics (tools, actions, architecture, trade-offs)?\n"
        "   - Does it lack the measurable result, impact, or outcome?\n"
        "2. If the answer is vague or missing key specifics:\n"
        "   - If follow_up_count < 2, generate ONE sharp, concise follow-up question (1-2 sentences maximum) targeting the missing element.\n"
        "   - Set 'move_on': false.\n"
        "   - Set 'reason': explanation of what was missing (e.g., 'Missing technical root cause and performance metrics').\n"
        "3. If the answer is thorough, specific, and provides root cause and results:\n"
        "   - Set 'follow_up': null.\n"
        "   - Set 'move_on': true.\n"
        "   - Set 'reason': positive note affirming the answer's specificity.\n"
        "4. If follow_up_count is already 2, you MUST set 'move_on': true and 'follow_up': null.\n"
        "5. Return ONLY a single valid JSON object with EXACT keys:\n"
        '   {"follow_up": string or null, "move_on": boolean, "reason": string}\n'
        "Do not include any other markdown formatting or text outside the JSON."
    )

    user_prompt = (
        f"Original Question: {request.question}\n"
        f"Follow-ups already asked so far: {request.follow_up_count} (Cap: 2)\n\n"
        f"Dialogue History:\n{history_str or 'None'}\n\n"
        f"Candidate's Latest Answer:\n{request.candidate_answer}\n\n"
        "Evaluate the candidate's latest answer. Output JSON."
    )

    try:
        client = Groq(api_key=api_key)
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.2,
            max_tokens=300,
            timeout=12.0,
        )

        content = completion.choices[0].message.content or "{}"
        data = json.loads(content)

        follow_up = data.get("follow_up")
        move_on = bool(data.get("move_on", False))
        reason = str(data.get("reason", "Evaluation complete."))

        # Hard enforcement of follow-up cap
        if request.follow_up_count >= MAX_FOLLOW_UPS:
            follow_up = None
            move_on = True

        is_vague = not move_on and follow_up is not None
        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)

        return TurnEvaluateResponse(
            follow_up=follow_up if not move_on else None,
            move_on=move_on,
            reason=reason,
            is_vague=is_vague,
            latency_ms=elapsed_ms,
        )

    except Exception as exc:
        logger.warning("[interviewer_pipeline] LLM evaluation error: %s. Using heuristic fallback.", exc)
        is_vague, follow_up, reason = _heuristic_evaluate_vagueness(
            request.question,
            request.candidate_answer,
            request.follow_up_count,
        )
        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return TurnEvaluateResponse(
            follow_up=follow_up if is_vague else None,
            move_on=not is_vague,
            reason=reason,
            is_vague=is_vague,
            latency_ms=elapsed_ms,
        )


def score_full_exchange(
    question: str,
    turns: List[TurnMessage],
    wpm: Optional[float] = None,
    filler_words_per_100: Optional[float] = None,
    pause_count: Optional[int] = None,
    groq_api_key: Optional[str] = None,
    model_override: Optional[str] = None,
) -> ExchangeScoreResponse:
    """
    Scores the full multi-turn interview exchange, taking into account how the candidate
    elaborated across all turns (original answer + follow-ups).
    """
    start_time = time.perf_counter()
    settings = get_settings()
    api_key = groq_api_key or settings.GROQ_API_KEY or settings.GROQ_AUDIO_API_KEY
    model = model_override or getattr(settings, "GROQ_LLM_MODEL", None) or getattr(settings, "LLM_MODEL", None) or LLM_MODEL

    exchange_text = "\n".join([f"{t.role.upper()}: {t.content}" for t in turns])

    # Fallback response in case of API failure
    candidate_words = sum(len(t.content.split()) for t in turns if t.role.lower() == "candidate")
    base_clarity = 75.0 if candidate_words > 40 else 55.0
    base_confidence = 80.0 if (wpm and 120 <= wpm <= 160) else 70.0
    base_overall = round(0.4 * base_clarity + 0.4 * base_confidence + 0.2 * 75.0, 1)

    fallback_response = ExchangeScoreResponse(
        clarity_score=base_clarity,
        confidence_score=base_confidence,
        overall_score=base_overall,
        feedback_summary="Good attempt covering the interview prompt across multi-turn interactions.",
        strengths=[
            "Addressed the primary question and maintained dialogue continuity.",
            "Responded to interviewer prompts and questions.",
        ],
        improvements=[
            "Include more quantifiable metrics and quantifiable results.",
            "Explicitly define technical trade-offs made during implementation.",
        ],
        star_assessment={
            "situation": "Context outlined in the response.",
            "task": "Role and objectives described.",
            "action": "Key actions taken by candidate.",
            "result": "Outcomes discussed.",
        },
        latency_ms=round((time.perf_counter() - start_time) * 1000, 2),
    )

    if not api_key:
        return fallback_response

    system_prompt = (
        "You are an expert executive interview coach. Evaluate the entire multi-turn interview exchange.\n"
        "The exchange includes the original question, candidate responses, and follow-up Q&A turns.\n"
        "Score the candidate fairly on:\n"
        "- clarity_score (0-100): Structure, articulation, conciseness, communication clarity.\n"
        "- confidence_score (0-100): Tone, authority, depth of domain knowledge, conviction.\n"
        "- overall_score (0-100): Calculated composite (approx 40% clarity + 40% confidence + 20% content depth).\n\n"
        "Output ONLY a valid JSON object with the following schema:\n"
        "{\n"
        '  "clarity_score": number (0-100),\n'
        '  "confidence_score": number (0-100),\n'
        '  "overall_score": number (0-100),\n'
        '  "feedback_summary": string,\n'
        '  "strengths": [string, string],\n'
        '  "improvements": [string, string],\n'
        '  "star_assessment": {\n'
        '    "situation": string,\n'
        '    "task": string,\n'
        '    "action": string,\n'
        '    "result": string\n'
        '  }\n'
        "}\n"
        "Do not include any extra text."
    )

    user_prompt = (
        f"Question: {question}\n\n"
        f"Multi-Turn Exchange:\n{exchange_text}\n\n"
        f"Acoustic metrics: WPM={wpm or 'N/A'}, Fillers/100={filler_words_per_100 or 'N/A'}, Pauses={pause_count or 'N/A'}\n"
    )

    try:
        client = Groq(api_key=api_key)
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=600,
            timeout=15.0,
        )
        content = completion.choices[0].message.content or "{}"
        data = json.loads(content)

        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return ExchangeScoreResponse(
            clarity_score=float(data.get("clarity_score", base_clarity)),
            confidence_score=float(data.get("confidence_score", base_confidence)),
            overall_score=float(data.get("overall_score", base_overall)),
            feedback_summary=str(data.get("feedback_summary", fallback_response.feedback_summary)),
            strengths=list(data.get("strengths", fallback_response.strengths)),
            improvements=list(data.get("improvements", fallback_response.improvements)),
            star_assessment=data.get("star_assessment", fallback_response.star_assessment),
            latency_ms=elapsed_ms,
        )
    except Exception as exc:
        logger.warning("[interviewer_pipeline] Score exchange error: %s. Returning fallback.", exc)
        fallback_response.latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
        return fallback_response
