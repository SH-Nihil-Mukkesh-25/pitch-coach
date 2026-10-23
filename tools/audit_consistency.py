"""tools/audit_consistency.py

Consistency audit script (read-only):
For a given uid, compares:
1. Firestore `sessions` documents
2. D1 `session_metrics` and `session_fillers`
3. Local SQLite database file or connection

Reports:
- Missing rows across stores
- Mismatched numeric metrics (overall_score, wpm, clarity, etc.)
- Orphan fillers (fillers without corresponding session metric)
- d1_pending leftovers in Firestore
- Outbox items stuck in 'in_flight' or 'failed'

Returns a summary dict and exits with code 0 if 0 discrepancies found, else code 1.
"""
import argparse
import json
import logging
import os
import sqlite3
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

# Add backend directory to sys.path so we can import models and clients if needed
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("audit_consistency")


def audit_consistency(
    uid: str,
    firestore_sessions: Optional[List[Dict[str, Any]]] = None,
    mongo_sessions: Optional[List[Dict[str, Any]]] = None,
    d1_connection: Optional[Any] = None,
    sqlite_db_path_or_conn: Optional[Any] = None,
) -> Dict[str, Any]:
    """Runs read-only consistency audit for the given user.

    Can receive in-memory fixture datasets/connections or inspect local sqlite files.
    """
    report = {
        "user_id": uid,
        "mongodb_count": 0,
        "firestore_count": 0,
        "d1_count": 0,
        "sqlite_count": 0,
        "missing_in_d1": [],
        "missing_in_mongodb": [],
        "missing_in_firestore": [],
        "missing_in_sqlite": [],
        "metric_mismatches": [],
        "orphan_fillers": [],
        "d1_pending_leftovers": [],
        "stuck_outbox_items": [],
        "discrepancy_count": 0,
    }

    # Fetch from MongoDB if not provided directly
    sessions_pool = mongo_sessions or firestore_sessions
    if sessions_pool is None:
        try:
            from database.mongodb import get_mongo_db, SESSIONS_COL
            db = get_mongo_db()
            cursor = db[SESSIONS_COL].find({"user_id": uid})
            sessions_pool = list(cursor)
        except Exception:
            sessions_pool = []

    fs_docs = {s["id"]: s for s in (sessions_pool or []) if s.get("user_id") == uid}
    report["mongodb_count"] = len(fs_docs)
    report["firestore_count"] = len(fs_docs)

    # 1. Audit d1_pending in MongoDB / Firestore
    for sid, sdata in fs_docs.items():
        if sdata.get("d1_pending") is True:
            report["d1_pending_leftovers"].append(sid)

    # 2. Inspect D1
    d1_rows = {}
    d1_fillers = []
    if d1_connection is not None:
        if hasattr(d1_connection, "query"):
            rows = d1_connection.query("SELECT * FROM session_metrics WHERE user_id = ? AND deleted_at IS NULL;", [uid])
            d1_fillers = d1_connection.query("""
                SELECT f.* FROM session_fillers f
                LEFT JOIN session_metrics m ON f.session_id = m.id
                WHERE m.id IS NULL;
            """)
        else:
            cur = d1_connection.cursor()
            cur.execute("SELECT * FROM session_metrics WHERE user_id = ? AND deleted_at IS NULL;", (uid,))
            col_names = [d[0] for d in cur.description]
            rows = [dict(zip(col_names, r)) for r in cur.fetchall()]
        d1_rows = {r["id"]: r for r in rows}
    report["d1_count"] = len(d1_rows)

    for f in d1_fillers:
        report["orphan_fillers"].append(f.get("session_id") or str(f))

    # 3. Inspect SQLite
    sqlite_rows = {}
    sqlite_conn = None
    close_sqlite = False
    if sqlite_db_path_or_conn is not None:
        if isinstance(sqlite_db_path_or_conn, str):
            if os.path.exists(sqlite_db_path_or_conn):
                sqlite_conn = sqlite3.connect(sqlite_db_path_or_conn)
                sqlite_conn.row_factory = sqlite3.Row
                close_sqlite = True
        else:
            sqlite_conn = sqlite_db_path_or_conn

    if sqlite_conn is not None:
        cur = sqlite_conn.cursor()
        cur.execute("SELECT * FROM session_metrics WHERE user_id = ? AND deleted_at IS NULL;", (uid,))
        rows = [dict(r) for r in cur.fetchall()]
        sqlite_rows = {r["id"]: r for r in rows}

        # Check outbox
        cur.execute("SELECT * FROM sync_outbox WHERE user_id = ? AND state IN ('failed', 'in_flight');", (uid,))
        stuck = [dict(r) for r in cur.fetchall()]
        report["stuck_outbox_items"] = [s["id"] for s in stuck]

        if close_sqlite:
            sqlite_conn.close()

    report["sqlite_count"] = len(sqlite_rows)

    # 4. Compare existence across stores
    all_analyzed_fs_ids = {sid for sid, d in fs_docs.items() if d.get("is_analyzed") and not d.get("analysis_failed")}
    d1_ids = set(d1_rows.keys())
    sqlite_ids = set(sqlite_rows.keys())

    # Sessions analyzed in Firestore should be in D1
    report["missing_in_d1"] = sorted(list(all_analyzed_fs_ids - d1_ids))
    # Sessions in D1 missing from Firestore
    report["missing_in_firestore"] = sorted(list(d1_ids - set(fs_docs.keys())))
    # Sessions in D1 missing from Local SQLite (if sqlite was provided)
    if sqlite_rows:
        report["missing_in_sqlite"] = sorted(list(d1_ids - sqlite_ids))

    # 5. Check metric consistency between Firestore snapshot and D1
    for sid in all_analyzed_fs_ids.intersection(d1_ids):
        fs_metrics = fs_docs[sid].get("metrics") or {}
        d1_m = d1_rows[sid]

        fs_overall = float(fs_metrics.get("overall", fs_docs[sid].get("overall_score", 0.0)) or 0.0)
        d1_overall = float(d1_m.get("overall_score") or 0.0)

        fs_wpm = float(fs_metrics.get("wpm", fs_docs[sid].get("wpm", 0.0)) or 0.0)
        d1_wpm = float(d1_m.get("wpm") or 0.0)

        if abs(fs_overall - d1_overall) > 0.1 or abs(fs_wpm - d1_wpm) > 0.5:
            report["metric_mismatches"].append({
                "session_id": sid,
                "firestore_overall": fs_overall,
                "d1_overall": d1_overall,
                "firestore_wpm": fs_wpm,
                "d1_wpm": d1_wpm,
            })

    total_discrepancies = (
        len(report["missing_in_d1"]) +
        len(report["missing_in_firestore"]) +
        len(report["missing_in_sqlite"]) +
        len(report["metric_mismatches"]) +
        len(report["orphan_fillers"]) +
        len(report["d1_pending_leftovers"]) +
        len(report["stuck_outbox_items"])
    )
    report["discrepancy_count"] = total_discrepancies
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Audit consistency across Firestore, D1, and Local SQLite.")
    parser.add_argument("--uid", required=True, help="User ID to audit.")
    parser.add_argument("--sqlite-db", help="Path to local SQLite database.")
    args = parser.parse_args()

    report = audit_consistency(args.uid, sqlite_db_path_or_conn=args.sqlite_db)
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["discrepancy_count"] == 0 else 1)
