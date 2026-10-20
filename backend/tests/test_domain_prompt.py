"""
Unit tests for Phase 6: Domain-Aware Whisper Prompt.
Validates:
- Base disfluency string is always present in all generated prompts.
- Practice mode vocabularies ('interview', 'presentation', 'free_talk', 'quick_practice') are appended correctly.
- Fallback for unknown modes defaults safely to interview vocabulary.
- Custom terms list is appended when provided.
- Prompt remains compact and within Whisper token limits.
"""
import pytest
from sessions.pipeline import (
    BASE_WHISPER_PROMPT,
    DOMAIN_VOCABULARY,
    get_whisper_prompt,
)


class TestDomainAwareWhisperPrompt:
    def test_base_disfluency_always_present(self):
        """Base disfluency string must always be at the start to ensure Whisper preserves fillers."""
        for mode in ["interview", "presentation", "free_talk", "quick_practice", "unknown_mode", ""]:
            prompt = get_whisper_prompt(mode)
            assert prompt.startswith(BASE_WHISPER_PROMPT)

    def test_mode_vocab_appended_correctly(self):
        """Each recognized mode appends its specific domain vocabulary."""
        p_interview = get_whisper_prompt("interview")
        assert "System architecture" in p_interview
        assert "Kubernetes" in p_interview

        p_pres = get_whisper_prompt("presentation")
        assert "Key metrics" in p_pres
        assert "ROI" in p_pres

        p_free = get_whisper_prompt("free_talk")
        assert "Daily routine" in p_free

        p_quick = get_whisper_prompt("quick_practice")
        assert "Elevator pitch" in p_quick

    def test_unknown_mode_fallback(self):
        """Unknown or missing practice mode falls back cleanly to interview vocabulary."""
        prompt = get_whisper_prompt("non_existent_special_mode_123")
        assert prompt.startswith(BASE_WHISPER_PROMPT)
        assert DOMAIN_VOCABULARY["interview"] in prompt

    def test_custom_terms_appended(self):
        """Custom domain terms (e.g. from slide deck) are appended properly."""
        custom = ["GraphQL", "Stripe Connect", "PitchCoachAI"]
        prompt = get_whisper_prompt("interview", custom_terms=custom)

        assert prompt.startswith(BASE_WHISPER_PROMPT)
        assert "GraphQL, Stripe Connect, PitchCoachAI." in prompt

    def test_prompt_token_length_budget(self):
        """Prompt length remains concise (well under 150 words / ~224 tokens)."""
        prompt = get_whisper_prompt("interview", custom_terms=["Term1", "Term2", "Term3"])
        words = prompt.split()
        assert len(words) < 75  # ~50-60 words is safely ~70-90 tokens
