"""
Unit tests for Phase 4: Contextual Fillers & Stutters (English).
Validates:
- 'like' is not flagged when following pronouns/perception verbs or comparisons
- 'like' is flagged when surrounded by pauses, hesitations, or mid-clause copula
- 'so', 'well', 'right', 'actually', 'basically' contextual logic
- Stutters / immediate repetitions ('the the', 'I I') counted in repetitions_count
- Stutters not double-counted as fillers
- Flagged filler debug log records reason and timestamps
"""
import pytest
from sessions.pipeline import (
    WordTimestamp,
    _compute_contextual_fillers_and_stutters,
)


def _build_timestamps(tokens_with_timing):
    """
    Helper to construct WordTimestamp list from:
    [(word, start, end), ...] or [word, ...] with default 0.3s duration and 0.1s gap.
    """
    result = []
    t = 0.0
    for item in tokens_with_timing:
        if isinstance(item, tuple):
            w, s, e = item
            result.append(WordTimestamp(word=w, start=s, end=e))
            t = e
        else:
            result.append(WordTimestamp(word=item, start=t, end=t + 0.3))
            t += 0.4
    return result


class TestContextualFillers:
    def test_sentence_table_expected_counts(self):
        """Table of standard sentences validating contextual filler counts."""
        test_cases = [
            # 1. "I like working with React" -> 0 fillers
            ("I like working with React", 0, {}),
            # 2. "We would like to present our results" -> 0 fillers
            ("We would like to present our results", 0, {}),
            # 3. "It looks like a viable architecture" -> 0 fillers
            ("It looks like a viable architecture", 0, {}),
            # 4. "It feels like something we can scale" -> 0 fillers
            ("It feels like something we can scale", 0, {}),
            # 5. "it was, like, really good" -> 1 filler ("like")
            # Construct with hesitations/pauses around like
            (
                [
                    ("it", 0.0, 0.2),
                    ("was,", 0.25, 0.45),
                    ("like,", 0.85, 1.15),  # gap before = 0.4s
                    ("really", 1.55, 1.85),  # gap after = 0.4s
                    ("good", 1.95, 2.25),
                ],
                1,
                {"like": 1},
            ),
            # 6. "So today we will build a mobile application" (fluent start) -> 0 fillers
            (
                [
                    ("So", 0.0, 0.2),
                    ("today", 0.25, 0.5),  # gap <= 0.3s, no comma
                    ("we", 0.55, 0.7),
                    ("will", 0.75, 0.9),
                    ("build", 0.95, 1.2),
                ],
                0,
                {},
            ),
            # 7. "So, um, basically we started" -> fillers ("so", "um", "basically")
            (
                [
                    ("So,", 0.0, 0.3),
                    ("um,", 0.7, 0.9),  # gap = 0.4s
                    ("basically", 1.3, 1.6),  # gap = 0.4s
                    ("we", 1.9, 2.1),
                    ("started", 2.15, 2.45),
                ],
                3,
                {"so": 1, "um": 1, "basically": 1},
            ),
            # 8. "All right, let's begin right now" -> 0 fillers
            ("All right, let's begin right now", 0, {}),
            # 9. "We need to deploy this, right?" -> 1 filler ("right")
            (
                [
                    ("We", 0.0, 0.2),
                    ("need", 0.25, 0.45),
                    ("to", 0.5, 0.65),
                    ("deploy", 0.7, 1.0),
                    ("this,", 1.05, 1.3),
                    ("right?", 1.7, 1.9),  # gap before = 0.4s
                ],
                1,
                {"right": 1},
            ),
            # 10. "The model performed very well" -> 0 fillers
            ("The model performed very well", 0, {}),
            # 11. "Well, I am not sure about that" -> 1 filler ("well")
            (
                [
                    ("Well,", 0.0, 0.3),
                    ("I", 0.65, 0.8),  # gap = 0.35s
                    ("am", 0.85, 1.0),
                    ("not", 1.05, 1.2),
                    ("sure", 1.25, 1.45),
                ],
                1,
                {"well": 1},
            ),
        ]

        for item, expected_total, expected_breakdown in test_cases:
            if isinstance(item, str):
                tokens = [w for w in item.split() if w]
                words = _build_timestamps(tokens)
            else:
                words = _build_timestamps(item)

            analysis, rep_count, debug_list = _compute_contextual_fillers_and_stutters(words)
            assert analysis.total_count == expected_total, f"Failed for {item}: expected {expected_total}, got {analysis.total_count} ({analysis.breakdown})"
            for k, v in expected_breakdown.items():
                assert analysis.breakdown.get(k, 0) == v, f"Expected {k}={v} in breakdown for {item}, got {analysis.breakdown}"

    def test_stutter_repetition_detection_and_no_double_count(self):
        """Immediate repetitions ('the the', 'I I', 'and and') are counted as repetitions, not duplicate fillers."""
        tokens = [
            ("the", 0.0, 0.2),
            ("the", 0.25, 0.45),  # stutter 1
            ("system", 0.5, 0.8),
            ("is", 0.85, 1.0),
            ("and", 1.05, 1.2),
            ("and", 1.25, 1.45),  # stutter 2
            ("scalable", 1.5, 1.8),
        ]
        words = _build_timestamps(tokens)
        analysis, repetitions_count, debug_list = _compute_contextual_fillers_and_stutters(words)

        assert repetitions_count == 2
        # 'the' and 'and' are not fillers
        assert analysis.total_count == 0

        # If a filler is repeated ('um um')
        tokens_filler_rep = [
            ("um", 0.0, 0.3),
            ("um", 0.35, 0.6),  # stutter on filler
            ("let", 0.9, 1.1),
            ("us", 1.15, 1.3),
            ("continue", 1.35, 1.6),
        ]
        words_fr = _build_timestamps(tokens_filler_rep)
        analysis_fr, rep_fr, _ = _compute_contextual_fillers_and_stutters(words_fr)

        assert rep_fr == 1
        # First 'um' is a filler, second 'um' is counted in repetitions, NOT double counted
        assert analysis_fr.total_count == 1
        assert analysis_fr.breakdown.get("um") == 1

    def test_debug_list_contains_reason_and_timestamps(self):
        """Flagged fillers record detailed diagnostic reasons."""
        tokens = [
            ("it", 0.0, 0.2),
            ("was", 0.25, 0.45),
            ("like,", 0.85, 1.15),
            ("super", 1.55, 1.85),
            ("fast", 1.9, 2.1),
        ]
        words = _build_timestamps(tokens)
        analysis, rep_count, debug_list = _compute_contextual_fillers_and_stutters(words)

        assert len(debug_list) == 1
        entry = debug_list[0]
        assert entry["word"] == "like"
        assert entry["start"] == 0.85
        assert "reason" in entry
        assert len(entry["reason"]) > 0
