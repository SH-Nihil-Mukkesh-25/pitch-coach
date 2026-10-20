"""
Unit tests for Phase 3: Active-Speech WPM.
Validates:
- 20s of speech + 40s silence gives reasonable active_wpm (~140-150 WPM) and not penalized as 'too slow'.
- Inter-word gaps > 3.0s are excluded from the active speech denominator.
- Continuous normal speech without long gaps keeps active_wpm close to gross_wpm.
- Tiny samples (< 10 words) return neutral pace score (75.0) without penalty.
"""
import pytest
from sessions.pipeline import (
    WordTimestamp,
    _compute_active_wpm,
    _compute_wpm_score,
)


class TestActiveWpm:
    def test_speech_then_long_silence_computes_accurate_active_wpm(self):
        """20 seconds of speech (50 words) followed by 40s of silence yields active_wpm ~150."""
        # 50 words evenly spaced over 20 seconds (0.0s to 20.0s)
        # Total recording duration = 60.0s
        words = []
        n_words = 50
        duration_seconds = 60.0
        speech_span = 20.0

        for i in range(n_words):
            start = i * (speech_span / n_words)
            end = start + 0.3
            words.append(WordTimestamp(word=f"word{i}", start=start, end=end))

        gross_wpm, active_wpm = _compute_active_wpm(words, duration_seconds)

        # Gross WPM sees 50 words / 1.0 min = 50.0 WPM (which would be penalized as too slow)
        assert gross_wpm == 50.0
        # Active WPM sees 50 words / (20s / 60) = 150.0 WPM (optimal conversational pace!)
        assert 145.0 <= active_wpm <= 155.0

        # WPM score on active_wpm gives high score, whereas gross would fail
        active_score = _compute_wpm_score(active_wpm, word_count=n_words)
        gross_score = _compute_wpm_score(gross_wpm, word_count=n_words)

        assert active_score >= 95.0
        assert gross_score < 50.0

    def test_inter_word_gap_greater_than_3s_excluded(self):
        """A single 10s gap inside speech is excluded from active speech denominator."""
        # Word 1-15: 0.0s to 5.0s
        # 10s pause
        # Word 16-30: 15.0s to 20.0s
        # Total duration = 20.0s
        words = []
        for i in range(15):
            t = i * (5.0 / 15.0)
            words.append(WordTimestamp(word=f"first{i}", start=t, end=t + 0.2))

        for j in range(15):
            t = 15.0 + j * (5.0 / 15.0)
            words.append(WordTimestamp(word=f"second{j}", start=t, end=t + 0.2))

        gross_wpm, active_wpm = _compute_active_wpm(words, duration_seconds=20.0)

        # Gross duration = 20s (30 words / (20/60) = 90 WPM)
        assert gross_wpm == 90.0
        # Active duration excludes the ~10s gap: 20s span - 9.8s gap ≈ 10.2s
        # Active WPM: 30 / (10.2 / 60) ≈ 176 WPM
        assert active_wpm > gross_wpm + 50.0

    def test_normal_fluent_speech_matches_within_tolerance(self):
        """Normal speech without long pauses yields active_wpm close to gross_wpm."""
        words = []
        n_words = 70
        duration_seconds = 30.0  # 140 WPM pace

        for i in range(n_words):
            start = i * (duration_seconds / n_words)
            end = start + 0.3
            words.append(WordTimestamp(word=f"w{i}", start=start, end=end))

        gross_wpm, active_wpm = _compute_active_wpm(words, duration_seconds)
        assert abs(active_wpm - gross_wpm) < 10.0

    def test_tiny_sample_returns_neutral_score(self):
        """Fewer than 10 words does not penalize pace, returning neutral 75.0 score."""
        words = [
            WordTimestamp(word="hello", start=0.0, end=0.5),
            WordTimestamp(word="world", start=0.6, end=1.0),
        ]
        gross_wpm, active_wpm = _compute_active_wpm(words, duration_seconds=30.0)
        assert gross_wpm == active_wpm

        score = _compute_wpm_score(active_wpm, word_count=len(words))
        assert score == 75.0
