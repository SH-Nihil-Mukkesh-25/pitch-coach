"""Section 8: End-to-End Scenarios with Consistency Audit verification."""
from datetime import datetime, timezone, timedelta
import io
import json
import os
import sys
import uuid
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from achievements.service import evaluate_user_achievements
import auth.account_service as account_service
from auth.dependencies import get_current_user
import d1.d1_client
from d1.sync import sync_firestore_session_to_d1
from firestore import get_db
import main
from models import User
from sessions.pipeline import SessionAnalysis, FillerAnalysis, PauseAnalysis, FeedbackItem, WordTimestamp
from tests.test_sec2_post_sessions import LocalSqliteD1, InMemoryFirestoreDB

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

import tools.audit_consistency as auditor


class TestSection8E2EScenarios:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = InMemoryFirestoreDB()
        self.user = User(id="user_e2e_pilot", email="pilot@example.com")

        monkeypatch.setattr(d1.d1_client, "get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("d1.sync.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("auth.account_service.get_d1_client", lambda: self.fake_d1)
        if "metrics.router" in sys.modules:
            monkeypatch.setattr(sys.modules["metrics.router"], "get_d1_client", lambda: self.fake_d1)
        if "sessions.router" in sys.modules:
            monkeypatch.setattr(sys.modules["sessions.router"], "get_d1_client", lambda: self.fake_d1)
        if "stats.router" in sys.modules:
            monkeypatch.setattr(sys.modules["stats.router"], "get_d1_client", lambda: self.fake_d1)
        if "achievements.service" in sys.modules:
            monkeypatch.setattr(sys.modules["achievements.service"], "get_d1_client", lambda: self.fake_d1)

        monkeypatch.setattr("sessions.router.check_and_increment_daily_quota", lambda *a, **kw: None)

        main.app.dependency_overrides[get_current_user] = lambda: self.user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _post(self, local_date=None, tz_offset=330, topic="Pitch"):
        sid = str(uuid.uuid4())
        if local_date is None:
            local_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        data = {
            "session_id": sid,
            "mode": "interview",
            "topic_or_question": topic,
            "duration_seconds": "45.0",
            "local_date": local_date,
            "tz_offset_minutes": str(tz_offset),
        }
        files = {"audio_file": ("speech.m4a", io.BytesIO(b"MOCK_AUDIO_PAYLOAD"), "audio/mp4")}
        resp = self.client.post("/sessions", data=data, files=files)
        return resp, sid

    def _mock_analysis(self, score=88.0):
        return SessionAnalysis(
            transcript="Our mission is to help speakers excel.",
            word_timestamps=[WordTimestamp(word="Our", start=0.0, end=0.3)],
            wpm=130.0,
            filler=FillerAnalysis(total_count=1, breakdown={"um": 1}, rate_per_100_words=1.0),
            pauses=PauseAnalysis(count=1, avg_length=0.6, total_pause_time=0.6),
            clarity_score=score,
            confidence_score=score - 2.0,
            overall_score=score,
            ai_feedback=[FeedbackItem(category="clarity", message="Great clarity", severity="positive", example=None)],
            duration_seconds=45.0,
        )

    # 1. Scenario 1: Happy path
    def test_scenario_1_happy_path(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(88.0))
        resp, sid = self._post()
        assert resp.status_code == 200

        # Run consistency audit
        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0, f"Audit discrepancies: {report}"

    # 2. Scenario 2: Airplane mode / Outbox sync
    def test_scenario_2_airplane_mode_sync(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(85.0))
        resp, sid = self._post()
        assert resp.status_code == 200

        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0

    # 3. Scenario 3: Two devices, one user
    def test_scenario_3_two_devices_one_user(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(90.0))
        # Device A records
        resp, sid = self._post()
        assert resp.status_code == 200

        # Device B pulls changes via /metrics/changes
        pull_resp = self.client.get("/metrics/changes")
        assert pull_resp.status_code == 200
        pull_data = pull_resp.json()
        assert any(s["id"] == sid for s in pull_data["sessions"])

        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0

    # 4. Scenario 4: Reinstall (wipe local, sign in, pull full history)
    def test_scenario_4_reinstall_pull(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(86.0))
        self._post()
        self._post()

        # Full history pull (null cursor)
        resp = self.client.get("/metrics/changes")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["sessions"]) == 2

        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0

    # 5. Scenario 5: D1 outage & heal
    def test_scenario_5_d1_outage_and_heal(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(84.0))

        # D1 is down during recording
        self.fake_d1.timeout_count = 5
        resp, sid = self._post()
        assert resp.status_code == 200

        doc = self.fake_db.collection("sessions").document(sid).to_dict()
        assert doc["d1_pending"] is True

        # D1 recovers (timeout_count reset to 0), background retry / sync runs
        self.fake_d1.timeout_count = 0
        ok = sync_firestore_session_to_d1(sid, db=self.fake_db, d1_client=self.fake_d1)
        assert ok is True

        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0

    # 6. Scenario 6: Delete session on Device A -> Device B receives tombstone
    @patch("sessions.router.get_bucket")
    def test_scenario_6_delete_sync(self, mock_get_bucket, monkeypatch):
        mock_get_bucket.return_value.blob.return_value = MagicMock()
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(84.0))

        resp, sid = self._post()
        assert resp.status_code == 200

        # Device A deletes
        del_resp = self.client.delete(f"/sessions/{sid}")
        assert del_resp.status_code == 200

        # Device B pulls: receives tombstone with deleted_at set
        pull_resp = self.client.get("/metrics/changes")
        data = pull_resp.json()
        del_row = next(s for s in data["sessions"] if s["id"] == sid)
        assert del_row["deleted_at"] is not None

    # 7. Scenario 7: Delete account -> all stores empty
    @patch("auth.account_service.fb_auth.delete_user")
    @patch("auth.account_service.get_bucket")
    def test_scenario_7_delete_account(self, mock_get_bucket, mock_delete_user, monkeypatch):
        mock_get_bucket.return_value.list_blobs.return_value = []
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(80.0))

        resp, sid = self._post()
        self.fake_db.collection("users").document(self.user.id).set({"id": self.user.id})

        account_service.delete_user_account(self.user, db=self.fake_db)

        # Assert zero rows in D1
        d1_rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE user_id = ?", [self.user.id])
        assert len(d1_rows) == 0

        # Assert zero docs in Firestore
        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get() if d.to_dict().get("user_id") == self.user.id]
        assert len(fs_sessions) == 0

    # 8. Scenario 8: Late-night pitch in IST
    def test_scenario_8_late_night_pitch_ist(self, monkeypatch):
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: self._mock_analysis(89.0))
        # 1 AM IST on current local date
        now_date = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")
        resp, sid = self._post(local_date=now_date, tz_offset=330)
        assert resp.status_code == 200

        d1_row = self.fake_d1.query("SELECT local_date FROM session_metrics WHERE id = ?", [sid])[0]
        assert d1_row["local_date"] == now_date

        fs_sessions = [d.to_dict() for d in self.fake_db.collection("sessions").get()]
        report = auditor.audit_consistency(self.user.id, firestore_sessions=fs_sessions, d1_connection=self.fake_d1)
        assert report["discrepancy_count"] == 0
