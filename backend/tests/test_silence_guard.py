"""
Unit tests for Phase 2: Silence & Hallucination Guard.
Validates:
- Pure silence detection
- Low-level background noise detection
- Short speech burst (< 1.0s) detection
- Speech followed by long silence passes threshold
- Whisper segment hallucination filtering (high no_speech_prob & low avg_logprob)
- Phantom phrase filtering on low-confidence/tail segments
- Tail repetition collapse
"""
import io
import math
import struct
import wave
import numpy as np
import pytest

from sessions.pipeline import (
    compute_active_speech_duration,
    MIN_SPEECH_DURATION_S,
    _is_phantom_segment,
    _collapse_tail_repetitions,
    SessionAnalysis,
)


def _generate_wav_bytes(duration_s: float, amplitude: float = 0.0, freq: float = 300.0) -> bytes:
    """Generate 16kHz mono 16-bit PCM WAV."""
    sample_rate = 16000
    n = int(duration_s * sample_rate)
    samples = []
    for i in range(n):
        if amplitude > 0.0:
            t = i / float(sample_rate)
            val = int(amplitude * 32767.0 * math.sin(2 * math.pi * freq * t))
        else:
            val = 0
        samples.append(max(-32767, min(32767, val)))

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    return buf.getvalue()


class TestSilenceGuard:
    def test_pure_silence_duration_is_zero(self):
        """Pure silence produces 0.0s active speech and falls below MIN_SPEECH_DURATION_S."""
        wav_bytes = _generate_wav_bytes(duration_s=3.0, amplitude=0.0)
        dur = compute_active_speech_duration(wav_bytes)
        assert dur == 0.0
        assert dur < MIN_SPEECH_DURATION_S

    def test_low_level_noise_is_gated(self):
        """Low-level background noise below RMS 0.012 is gated out as silence."""
        sample_rate = 16000
        duration_s = 3.0
        noise = np.random.normal(0, 0.003 * 32767, int(sample_rate * duration_s)).astype(np.int16)

        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(noise.tobytes())

        dur = compute_active_speech_duration(buf.getvalue())
        assert dur == 0.0
        assert dur < MIN_SPEECH_DURATION_S

    def test_short_speech_burst_is_flagged(self):
        """Speech burst shorter than 1.0s (e.g. 0.4s mic tap or cough) falls below threshold."""
        # 0.4s speech surrounded by silence
        sample_rate = 16000
        total_samples = sample_rate * 3
        data = np.zeros(total_samples, dtype=np.int16)

        burst_len = int(sample_rate * 0.4)
        t = np.linspace(0, 0.4, burst_len, False)
        data[sample_rate : sample_rate + burst_len] = (0.2 * 32767 * np.sin(2 * np.pi * 300 * t)).astype(np.int16)

        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(data.tobytes())

        dur = compute_active_speech_duration(buf.getvalue())
        assert 0.0 < dur < MIN_SPEECH_DURATION_S

    def test_speech_followed_by_long_silence_passes(self):
        """2.0s of genuine speech followed by 4.0s of silence passes the 1.0s speech gate."""
        sample_rate = 16000
        total_samples = sample_rate * 6
        data = np.zeros(total_samples, dtype=np.int16)

        speech_len = int(sample_rate * 2.0)
        t = np.linspace(0, 2.0, speech_len, False)
        data[:speech_len] = (0.25 * 32767 * np.sin(2 * np.pi * 250 * t)).astype(np.int16)

        buf = io.BytesIO()
        with wave.open(buf, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(data.tobytes())

        dur = compute_active_speech_duration(buf.getvalue())
        assert dur >= 1.5
        assert dur >= MIN_SPEECH_DURATION_S


class TestHallucinationAndRepetitionFilters:
    def test_phantom_segment_dropped_when_short_or_low_conf(self):
        """Known YouTube/subtitles hallucinations are flagged when short or low-confidence."""
        # Typical end-of-audio hallucination
        is_phantom = _is_phantom_segment(
            text="Thank you for watching.",
            duration=1.2,
            avg_logprob=-0.75,
            no_speech_prob=0.55,
            is_tail=True,
        )
        assert is_phantom is True

        is_sub = _is_phantom_segment(
            text="Subtitles by the Amara.org community",
            duration=2.0,
            avg_logprob=-0.9,
            no_speech_prob=0.7,
            is_tail=False,
        )
        assert is_sub is True

    def test_legitimate_speech_mentioning_phrase_is_not_dropped(self):
        """Legitimate speech that contains a phrase during an actual lecture is preserved."""
        is_phantom = _is_phantom_segment(
            text="In this presentation, please subscribe to our thesis regarding renewable energy.",
            duration=5.5,
            avg_logprob=-0.15,
            no_speech_prob=0.01,
            is_tail=False,
        )
        assert is_phantom is False

    def test_tail_repetitions_collapsed(self):
        """Repeated phrases (4+ times) at the tail of a transcript are collapsed to 1."""
        text = "I am excited to show our demo. Thank you. Thank you. Thank you. Thank you."
        collapsed = _collapse_tail_repetitions(text)
        assert collapsed == "I am excited to show our demo. Thank you."

        text_normal = "Thank you so much for your time and thank you for listening."
        assert _collapse_tail_repetitions(text_normal) == text_normal
