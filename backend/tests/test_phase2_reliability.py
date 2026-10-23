"""Unit tests for Phase 2: Reliability and Cost Control."""
import unittest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from models import PracticeSession, SlideDeck, User
from quota import check_and_increment_daily_quota
from slides.store import DeckStore
from sessions.router import sweep_stuck_sessions
from auth.dependencies import get_current_user


class TestPhase2Reliability(unittest.TestCase):

    def test_quota_increment_and_limit_enforcement(self):
        """Verify check_and_increment_daily_quota enforces limits and throws 429."""
        mock_db = MagicMock()
        mock_col = MagicMock()
        mock_db.__getitem__.return_value = mock_col

        # Test within limit: count is 5, limit is 10 -> increments to 6
        mock_col.find_one.return_value = {"count": 5}
        mock_col.find_one_and_update.return_value = {"count": 6}

        with patch("quota.get_mongo_db", return_value=mock_db):
            new_count = check_and_increment_daily_quota("user_123", "decks", limit=10)
            self.assertEqual(new_count, 6)
            mock_col.find_one_and_update.assert_called_once()

        # Test limit reached: count is 10, limit is 10 -> raises 429
        mock_col.find_one.return_value = {"count": 10}
        with patch("quota.get_mongo_db", return_value=mock_db):
            with self.assertRaises(HTTPException) as ctx:
                check_and_increment_daily_quota("user_123", "decks", limit=10)
            self.assertEqual(ctx.exception.status_code, 429)
            self.assertIn("Daily quota exceeded", ctx.exception.detail)

    def test_expired_guest_token_rejected(self):
        """Verify get_current_user rejects expired guest accounts with 401."""
        expired_date = datetime.now(timezone.utc) - timedelta(days=2)
        expired_user = User(
            id="guest_expired",
            full_name="Guest User",
            is_guest=True,
            created_at=datetime.now(timezone.utc) - timedelta(days=40),
            expires_at=expired_date,
        )

        mock_db = MagicMock()
        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = expired_user.to_dict()
        mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

        with patch("auth.dependencies.decode_token", return_value={"sub": "guest_expired", "type": "access"}):
            with self.assertRaises(HTTPException) as ctx:
                get_current_user(token="mock_token", db=mock_db)
            self.assertEqual(ctx.exception.status_code, 401)
            self.assertIn("Guest session has expired", ctx.exception.detail)

    def test_deck_store_lru_cache_bounds(self):
        """Verify DeckStore._memory_cache stays bounded to 100 entries."""
        store = DeckStore()
        # Mock get_mongo_db so save doesn't require database
        with patch("slides.store.get_mongo_db", return_value=None):
            for i in range(120):
                d = SlideDeck(id=f"deck_{i}", user_id="user_1")
                store.save(d)

            self.assertLessEqual(len(store._memory_cache), 100)
            # The earliest entries (e.g. deck_0 .. deck_19) should have been evicted
            self.assertNotIn("deck_0", store._memory_cache)
            self.assertIn("deck_119", store._memory_cache)

    def test_stuck_deck_sweeper(self):
        """Verify decks stuck in processing for >10 min are marked failed."""
        store = DeckStore()
        old_time = datetime.now(timezone.utc) - timedelta(minutes=15)
        stuck_deck = SlideDeck(
            id="stuck_deck_1",
            user_id="user_1",
            status="processing",
            created_at=old_time,
            updated_at=old_time,
        )
        store._memory_cache[stuck_deck.id] = stuck_deck

        with patch("slides.store.get_mongo_db", return_value=None):
            count = store.sweep_stuck_decks(cutoff_seconds=600)
            self.assertEqual(count, 1)
            self.assertEqual(stuck_deck.status, "failed")
            self.assertIn("timed out", stuck_deck.failure_reason)

    def test_stuck_session_sweeper(self):
        """Verify sessions stuck for >10 min are swept as failed."""
        mock_db = MagicMock()
        old_time = datetime.now(timezone.utc) - timedelta(minutes=15)

        mock_doc = MagicMock()
        mock_doc.id = "session_stuck_1"
        mock_doc.to_dict.return_value = {
            "id": "session_stuck_1",
            "user_id": "user_1",
            "is_analyzed": False,
            "created_at": old_time,
        }

        mock_db.collection.return_value.where.return_value.stream.return_value = [mock_doc]

        with patch("sessions.router.get_db", return_value=mock_db):
            count = sweep_stuck_sessions(cutoff_seconds=600)
            self.assertEqual(count, 1)
            mock_db.collection.return_value.document.return_value.update.assert_called_once()
            update_arg = mock_db.collection.return_value.document.return_value.update.call_args[0][0]
            self.assertTrue(update_arg["analysis_failed"])
            self.assertIn("timed out", update_arg["failure_reason"])


if __name__ == "__main__":
    unittest.main()
