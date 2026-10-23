"""End-to-End verification script for the Pitch Coach storage pipeline:
App (Simulated) -> Local DB (SQLite) -> Backend API -> Cloudflare D1
"""
import os
import sys
import sqlite3
import tempfile
import uuid
from datetime import datetime, timezone

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from d1.d1_client import get_d1_client
from d1.sync import upsert_session_to_d1

def test_local_sqlite():
    print("\n--- 1. Testing Local SQLite Database (App Layer) ---")
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name

    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # Create schema matching LocalDatabaseService
        cur.execute("""
        CREATE TABLE session_metrics (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            mode TEXT NOT NULL DEFAULT 'interview',
            topic_or_question TEXT NOT NULL,
            duration_seconds REAL NOT NULL DEFAULT 0,
            wpm REAL NOT NULL DEFAULT 0,
            filler_word_count INTEGER NOT NULL DEFAULT 0,
            pause_count INTEGER NOT NULL DEFAULT 0,
            avg_pause_length REAL NOT NULL DEFAULT 0,
            clarity_score REAL NOT NULL DEFAULT 0,
            confidence_score REAL NOT NULL DEFAULT 0,
            overall_score REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            local_date TEXT NOT NULL,
            tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        );
        """)
        cur.execute("""
        CREATE TABLE session_fillers (
            session_id TEXT NOT NULL,
            filler_word TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY (session_id, filler_word)
        );
        """)
        cur.execute("""
        CREATE TABLE sync_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            table_name TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0
        );
        """)

        # Insert a simulated practice session locally
        session_id = f"test-e2e-{uuid.uuid4().hex[:8]}"
        user_id = "test-user-dakshin"
        now_iso = datetime.now(timezone.utc).isoformat()
        today = now_iso[:10]

        cur.execute("""
        INSERT INTO session_metrics (
            id, user_id, mode, topic_or_question, duration_seconds,
            wpm, filler_word_count, pause_count, avg_pause_length,
            clarity_score, confidence_score, overall_score,
            status, created_at, local_date, tz_offset_minutes,
            updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            session_id, user_id, 'interview', 'Tell me about yourself',
            45.0, 130.0, 3, 2, 1.2, 88.0, 85.0, 86.5,
            'analyzed', now_iso, today, 330, now_iso
        ))

        # Insert fillers
        cur.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES (?, ?, ?)", (session_id, "um", 2))
        cur.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES (?, ?, ?)", (session_id, "like", 1))

        # Insert into outbox
        cur.execute("""
        INSERT INTO sync_outbox (action, table_name, payload, created_at)
        VALUES ('UPSERT', 'session_metrics', ?, ?)
        """, (f'{{"id": "{session_id}"}}', now_iso))

        conn.commit()

        # Verify query from local DB
        cur.execute("SELECT id, overall_score, status FROM session_metrics WHERE id = ?", (session_id,))
        row = cur.fetchone()
        assert row is not None, "Failed to retrieve local session"
        print(f"  [SQLite] Session successfully written locally: id={row[0]}, score={row[1]}, status={row[2]}")

        cur.execute("SELECT filler_word, count FROM session_fillers WHERE session_id = ?", (session_id,))
        fillers = cur.fetchall()
        print(f"  [SQLite] Fillers recorded: {dict(fillers)}")

        cur.execute("SELECT COUNT(*) FROM sync_outbox")
        outbox_count = cur.fetchone()[0]
        print(f"  [SQLite] Outbox items queued: {outbox_count}")
        assert outbox_count == 1

        conn.close()
        return session_id, user_id, now_iso, today
    finally:
        if os.path.exists(db_path):
            try:
                os.remove(db_path)
            except Exception:
                pass

def test_cloudflare_d1_sync(session_id, user_id, created_at, local_date):
    print("\n--- 2. Testing Cloudflare D1 Sync & Storage ---")
    d1 = get_d1_client()
    assert d1.is_configured, "D1 Client is not configured!"

    # Session data payload simulating what the backend receives and syncs to D1
    session_data = {
        "id": session_id,
        "user_id": user_id,
        "mode": "interview",
        "topic_or_question": "Tell me about yourself",
        "duration_seconds": 45.0,
        "wpm": 130.0,
        "filler_word_count": 3,
        "pause_count": 2,
        "avg_pause_length": 1.2,
        "clarity_score": 88.0,
        "confidence_score": 85.0,
        "overall_score": 86.5,
        "status": "analyzed",
        "is_analyzed": True,
        "created_at": created_at,
        "local_date": local_date,
        "tz_offset_minutes": 330,
        "filler_word_breakdown": {"um": 2, "like": 1},
    }

    print(f"  [D1] Upserting session {session_id} to Cloudflare D1...")
    success = upsert_session_to_d1(session_data, d1_client=d1)
    assert success, "D1 upsert failed!"
    print("  [D1] Upsert returned SUCCESS.")

    # Verify query from Cloudflare D1
    print("  [D1] Querying session_metrics from Cloudflare D1 remote database...")
    rows = d1.query("SELECT id, user_id, mode, overall_score, status FROM session_metrics WHERE id = ?", [session_id])
    assert len(rows) == 1, f"Expected 1 row in D1, found {len(rows)}"
    d1_row = rows[0]
    print(f"  [D1] Verified remote row: id={d1_row['id']}, user_id={d1_row['user_id']}, score={d1_row['overall_score']}, status={d1_row['status']}")

    # Verify fillers in Cloudflare D1
    f_rows = d1.query("SELECT filler_word, count FROM session_fillers WHERE session_id = ? ORDER BY filler_word", [session_id])
    print(f"  [D1] Verified remote fillers: {f_rows}")
    assert len(f_rows) == 2, f"Expected 2 fillers in D1, found {len(f_rows)}"

    # Clean up test row from D1
    print("  [D1] Cleaning up test row from Cloudflare D1...")
    d1.execute("DELETE FROM session_fillers WHERE session_id = ?", [session_id])
    d1.execute("DELETE FROM session_metrics WHERE id = ?", [session_id])
    verify_del = d1.query("SELECT id FROM session_metrics WHERE id = ?", [session_id])
    assert len(verify_del) == 0, "Failed to clean up test row"
    print("  [D1] Cleaned up successfully.")

def main():
    print("=== STARTING END-TO-END STORAGE PIPELINE VERIFICATION ===")
    session_id, user_id, created_at, local_date = test_local_sqlite()
    test_cloudflare_d1_sync(session_id, user_id, created_at, local_date)
    print("\n=== ALL STORAGE & CONNECTIVITY CHECKS PASSED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
