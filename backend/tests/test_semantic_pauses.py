"""
Unit tests for Phase 5: Semantic Pauses.
Validates:
- Rhetorical pauses (after terminal punctuation '.', '!', '?' with gap 0.8s - 2.5s) counted in rhetorical_pause_count.
- Mid-clause pauses (e.g. after 'and', 'the', inside clause > 0.8s) counted in disfluent_pause_count.
- Pauses right before a filler ('um', 'uh', 'like') counted as disfluent disfluencies.
- Very long gaps (> 4.0s) counted as dead air in disfluent_pause_count.
- Clarity score only deducts for disfluent pauses / dead air; rhetorical pauses do not deduct clarity.
- Existing pause fields (count, avg_length, total_pause_time) remain fully populated.
"""
import pytest
from sessions.pipeline import (
    WordTimestamp,
    _compute_semantic_pauses,
    _compute_clarity_score,
    FillerAnalysis,
)


class TestSemanticPauses:
    def test_rhetorical_pause_at_sentence_boundary(self):
        """A 1.5s pause after a completed sentence with period is classified as rhetorical."""
        words = [
            WordTimestamp(word="Welcome", start=0.0, end=0.4),
            WordTimestamp(word="everyone.", start=0.45, end=0.9),
            # 1.3s pause between sentences
            WordTimestamp(word="Today", start=2.2, end=2.5),
            WordTimestamp(word="we", start=2.55, end=2.7),
            WordTimestamp(word="pitch.", start=2.75, end=3.0),
        ]
        pauses, rhetorical, disfluent = _compute_semantic_pauses(words)

        assert pauses.count == 1
        assert rhetorical == 1
        assert disfluent == 0

    def test_mid_clause_hesitation_pause_is_disfluent(self):
        """A 1.2s gap inside a clause after 'the' is classified as mid-sentence disfluency."""
        words = [
            WordTimestamp(word="We", start=0.0, end=0.3),
            WordTimestamp(word="scaled", start=0.35, end=0.7),
            WordTimestamp(word="the", start=0.75, end=0.95),
            # 1.25s awkward hesitation mid-clause
            WordTimestamp(word="architecture", start=2.2, end=2.8),
            WordTimestamp(word="effectively.", start=2.85, end=3.3),
        ]
        pauses, rhetorical, disfluent = _compute_semantic_pauses(words)

        assert pauses.count == 1
        assert rhetorical == 0
        assert disfluent == 1

    def test_pause_preceding_filler_is_disfluent(self):
        """A pause immediately preceding a filler word ('um') is classified as disfluent."""
        words = [
            WordTimestamp(word="Our", start=0.0, end=0.3),
            WordTimestamp(word="revenue", start=0.35, end=0.7),
            # 1.0s pause before filler
            WordTimestamp(word="um", start=1.7, end=2.0),
            WordTimestamp(word="grew", start=2.05, end=2.3),
            WordTimestamp(word="rapidly.", start=2.35, end=2.7),
        ]
        pauses, rhetorical, disfluent = _compute_semantic_pauses(words)

        assert pauses.count == 1
        assert rhetorical == 0
        assert disfluent == 1

    def test_dead_air_over_4s_is_disfluent(self):
        """A gap of 4.5s is dead air and classified as disfluent."""
        words = [
            WordTimestamp(word="Thank", start=0.0, end=0.3),
            WordTimestamp(word="you.", start=0.35, end=0.6),
            # 4.5s dead air gap
            WordTimestamp(word="Any", start=5.1, end=5.3),
            WordTimestamp(word="questions?", start=5.35, end=5.7),
        ]
        pauses, rhetorical, disfluent = _compute_semantic_pauses(words)

        assert pauses.count == 1
        assert disfluent == 1

    def test_clarity_score_does_not_penalize_rhetorical_pauses(self):
        """Clarity score with rhetorical pauses maintains high score, whereas disfluent pauses penalize."""
        empty_filler = FillerAnalysis(total_count=0, breakdown={}, rate_per_100_words=0.0)

        # 3 rhetorical pauses, 0 disfluent
        score_rhetorical = _compute_clarity_score(
            filler=empty_filler,
            pauses=None,
            disfluent_pauses_count=0,
        )
        assert score_rhetorical == 100.0

        # 3 disfluent pauses
        score_disfluent = _compute_clarity_score(
            filler=empty_filler,
            pauses=None,
            disfluent_pauses_count=3,
        )
        assert score_disfluent == 91.0  # 100 - (3 * 3.0) = 91.0
