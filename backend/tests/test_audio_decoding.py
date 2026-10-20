"""
Unit tests for Phase 1: FFmpeg Audio Decoding & Normalization.
Validates decode_to_pcm16k_mono on synthetic WAV, M4A, and MP3 files/bytes,
asserts sample rate, mono channel, decoded length, and validates that
arbitrary raw garbage bytes are rejected (no garbage-as-PCM fallback).
"""
import io
import math
import os
import shutil
import struct
import subprocess
import tempfile
import wave
import numpy as np
import pytest

from audio_analysis.vocal_delivery import (
    decode_to_pcm16k_mono,
    analyze_vocal_delivery,
    VocalDeliveryMetrics,
)

FFMPEG_AVAILABLE = shutil.which("ffmpeg") is not None


def _create_synthetic_wav_bytes(duration_s: float = 2.0, sample_rate: int = 16000, freq: float = 440.0) -> bytes:
    """Generate synthetic sine wave as 16-bit PCM WAV in memory."""
    total_samples = int(duration_s * sample_rate)
    samples = []
    for i in range(total_samples):
        t = i / float(sample_rate)
        val = int(16000 * math.sin(2 * math.pi * freq * t))
        samples.append(max(-32767, min(32767, val)))

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    return buf.getvalue()


@pytest.mark.skipif(not FFMPEG_AVAILABLE, reason="FFmpeg not available")
class TestAudioDecoding:
    def test_decode_wav_bytes_and_file(self):
        """Decode WAV bytes and WAV file path to 16kHz mono float32."""
        duration_s = 2.0
        wav_bytes = _create_synthetic_wav_bytes(duration_s=duration_s, sample_rate=16000)

        # 1. Test bytes input
        samples_b, sr_b = decode_to_pcm16k_mono(wav_bytes)
        assert sr_b == 16000
        assert isinstance(samples_b, np.ndarray)
        assert samples_b.dtype == np.float32
        assert samples_b.ndim == 1  # Mono
        # Duration should match closely (within 100ms tolerance)
        assert abs(len(samples_b) - int(duration_s * 16000)) < 1600

        # 2. Test file path input
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(wav_bytes)
            f_name = f.name

        try:
            samples_f, sr_f = decode_to_pcm16k_mono(f_name)
            assert sr_f == 16000
            assert isinstance(samples_f, np.ndarray)
            assert samples_f.ndim == 1
            assert abs(len(samples_f) - int(duration_s * 16000)) < 1600
        finally:
            if os.path.exists(f_name):
                os.remove(f_name)

    def test_decode_m4a_encoded_audio(self):
        """Decode M4A (AAC) encoded audio to 16kHz mono float32."""
        duration_s = 2.5
        wav_bytes = _create_synthetic_wav_bytes(duration_s=duration_s, sample_rate=16000)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_wav:
            f_wav.write(wav_bytes)
            wav_path = f_wav.name

        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as f_m4a:
            m4a_path = f_m4a.name

        try:
            # Convert WAV to AAC in .m4a container
            proc = subprocess.run(
                ["ffmpeg", "-y", "-i", wav_path, "-c:a", "aac", m4a_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            assert proc.returncode == 0
            assert os.path.getsize(m4a_path) > 0

            # Decode from m4a file path
            samples, sr = decode_to_pcm16k_mono(m4a_path)
            assert sr == 16000
            assert samples.ndim == 1
            assert abs(len(samples) - int(duration_s * 16000)) < 2400

            # Decode from in-memory m4a bytes
            with open(m4a_path, "rb") as mf:
                m4a_bytes = mf.read()
            samples_bytes, sr_bytes = decode_to_pcm16k_mono(m4a_bytes)
            assert sr_bytes == 16000
            assert samples_bytes.ndim == 1
            assert abs(len(samples_bytes) - int(duration_s * 16000)) < 2400
        finally:
            if os.path.exists(wav_path):
                os.remove(wav_path)
            if os.path.exists(m4a_path):
                os.remove(m4a_path)

    def test_decode_mp3_audio(self):
        """Decode MP3 audio to 16kHz mono float32."""
        duration_s = 1.5
        wav_bytes = _create_synthetic_wav_bytes(duration_s=duration_s, sample_rate=16000)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_wav:
            f_wav.write(wav_bytes)
            wav_path = f_wav.name

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f_mp3:
            mp3_path = f_mp3.name

        try:
            proc = subprocess.run(
                ["ffmpeg", "-y", "-i", wav_path, "-c:a", "libmp3lame", mp3_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if proc.returncode != 0:
                pytest.skip("libmp3lame encoder not built into ffmpeg")

            samples, sr = decode_to_pcm16k_mono(mp3_path)
            assert sr == 16000
            assert samples.ndim == 1
            assert abs(len(samples) - int(duration_s * 16000)) < 2400
        finally:
            if os.path.exists(wav_path):
                os.remove(wav_path)
            if os.path.exists(mp3_path):
                os.remove(mp3_path)

    def test_raw_garbage_bytes_rejected_no_fallback(self):
        """Arbitrary random bytes must NOT be treated as raw PCM, returning empty samples and neutral score."""
        garbage_bytes = b"COMPRESSED_OR_INVALID_HEADERLESS_DATA_1234567890" * 20
        samples, sr = decode_to_pcm16k_mono(garbage_bytes)
        assert len(samples) == 0
        assert sr == 16000

        # analyze_vocal_delivery should return clean default metrics, never crash or analyze garbage
        metrics = analyze_vocal_delivery(garbage_bytes)
        assert isinstance(metrics, VocalDeliveryMetrics)
        assert len(metrics.energy_curve) == 30
        assert metrics.pitch_variation_score == 60.0

    def test_empty_input_handled_gracefully(self):
        """Empty inputs (bytes, empty string, non-existent file) return empty samples."""
        s1, _ = decode_to_pcm16k_mono(b"")
        assert len(s1) == 0

        s2, _ = decode_to_pcm16k_mono("non_existent_file_123456.m4a")
        assert len(s2) == 0

        s3, _ = decode_to_pcm16k_mono(None)
        assert len(s3) == 0
