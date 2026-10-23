"""Privacy-preserving weekly leaderboard service.

Rules:
1. Opt-in flag: Users must opt in to display non-anonymous identifiers.
2. By default: Anonymous pseudonym ("Anonymous Speaker #XX").
3. Email and full real names are NEVER exposed.
4. Resets cleanly on weekly boundaries (Monday 00:00 UTC).
"""
import hashlib
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from achievements.challenges import get_current_week_id, get_current_week_start
from d1.d1_client import get_d1_client
from database.mongodb import get_db, SESSIONS_COL, USERS_COL

logger = logging.getLogger(__name__)


def generate_pseudonym(user_id: str) -> str:
    """Generates a stable, privacy-preserving pseudonym from user_id."""
    digest = hashlib.sha256(f"pc_privacy_salt_{user_id}".encode()).hexdigest()
    num = (int(digest[:8], 16) % 900) + 100
    return f"Anonymous Speaker #{num}"


def get_weekly_leaderboard(
    current_user_id: str,
    limit: int = 20,
    week_start: Optional[datetime] = None,
    d1_client=None,
    db=None,
) -> Dict[str, Any]:
    """Computes weekly leaderboard rankings while preserving speaker privacy."""
    start_dt = week_start or get_current_week_start()
    start_iso = start_dt.isoformat()
    week_id = get_current_week_id(start_dt)

    d1 = d1_client or get_d1_client()
    mongo_db = db or get_db()

    aggregated_users: List[Dict[str, Any]] = []

    # 1. Query D1
    if d1.is_configured:
        try:
            sql = """
            SELECT user_id, COUNT(*) AS sessions_count, ROUND(AVG(overall_score), 1) AS avg_score
            FROM session_metrics
            WHERE status = 'analyzed' AND deleted_at IS NULL AND created_at >= ?
            GROUP BY user_id
            ORDER BY avg_score DESC, sessions_count DESC;
            """
            rows = d1.query(sql, [start_iso])
            for r in rows:
                uid = r.get("user_id")
                if uid and uid not in ("guest", "demo-guest"):
                    aggregated_users.append({
                        "user_id": uid,
                        "sessions_count": int(r.get("sessions_count") or 0),
                        "avg_score": float(r.get("avg_score") or 0.0),
                    })
        except Exception as e:
            logger.warning("[leaderboard] D1 query failed: %s, falling back to Firestore", e)
            aggregated_users = []

    # 2. Firestore fallback if D1 empty or not configured
    if not aggregated_users and mongo_db:
        try:
            docs = (
                mongo_db.collection(SESSIONS_COL)
                .where("is_analyzed", "==", True)
                .get()
            )
            user_stats: Dict[str, List[float]] = {}
            for d in docs:
                data = d.to_dict()
                if data.get("analysis_failed"):
                    continue
                uid = data.get("user_id")
                if not uid or uid in ("guest", "demo-guest"):
                    continue
                c_at = data.get("created_at")
                if isinstance(c_at, str):
                    try:
                        c_dt = datetime.fromisoformat(c_at.replace("Z", "+00:00"))
                    except Exception:
                        c_dt = None
                elif isinstance(c_at, datetime):
                    c_dt = c_at
                else:
                    c_dt = None

                if c_dt and c_dt >= start_dt:
                    score = float(data.get("overall_score") or 0.0)
                    user_stats.setdefault(uid, []).append(score)

            for uid, scores in user_stats.items():
                aggregated_users.append({
                    "user_id": uid,
                    "sessions_count": len(scores),
                    "avg_score": round(sum(scores) / len(scores), 1) if scores else 0.0,
                })

            aggregated_users.sort(
                key=lambda x: (x["avg_score"], x["sessions_count"]),
                reverse=True,
            )
        except Exception as e:
            logger.warning("[leaderboard] Firestore query fallback error: %s", e)

    # 3. Retrieve user privacy preferences from Firestore
    user_settings_map: Dict[str, Dict[str, Any]] = {}
    if mongo_db and aggregated_users:
        all_uids = {u["user_id"] for u in aggregated_users}
        all_uids.add(current_user_id)
        for uid in all_uids:
            try:
                udoc = mongo_db.collection(USERS_COL).document(uid).get()
                if udoc.exists:
                    udata = udoc.to_dict()
                    user_settings_map[uid] = {
                        "settings": udata.get("settings") or {},
                        "full_name": udata.get("full_name") or "",
                    }
            except Exception:
                pass

    current_user_opted_in = bool(
        user_settings_map.get(current_user_id, {})
        .get("settings", {})
        .get("leaderboard_opt_in", False)
    )

    # 4. Construct leaderboard entries with privacy rules
    entries = []
    current_user_entry = None

    for rank_idx, item in enumerate(aggregated_users, start=1):
        uid = item["user_id"]
        u_info = user_settings_map.get(uid, {})
        settings = u_info.get("settings") or {}
        opted_in = bool(settings.get("leaderboard_opt_in", False))

        # Privacy resolution:
        # If opted in, allow pseudonym or first name alias; NEVER show email or full name.
        if opted_in:
            alias = settings.get("leaderboard_alias")
            if not alias:
                first_name = (u_info.get("full_name") or "").strip().split(" ")[0]
                alias = f"{first_name} (Speaker)" if first_name else generate_pseudonym(uid)
            display_name = alias
        else:
            display_name = generate_pseudonym(uid)

        entry = {
            "rank": rank_idx,
            "display_name": display_name,
            "score": item["avg_score"],
            "sessions_count": item["sessions_count"],
            "is_current_user": (uid == current_user_id),
        }

        if uid == current_user_id:
            current_user_entry = entry

        if rank_idx <= limit:
            entries.append(entry)

    # If current user hasn't completed any sessions this week
    if not current_user_entry:
        current_user_entry = {
            "rank": None,
            "display_name": (
                user_settings_map.get(current_user_id, {})
                .get("settings", {})
                .get("leaderboard_alias")
                or generate_pseudonym(current_user_id)
            ),
            "score": 0.0,
            "sessions_count": 0,
            "is_current_user": True,
        }

    return {
        "week_id": week_id,
        "week_start": start_iso,
        "user_opted_in": current_user_opted_in,
        "entries": entries,
        "current_user_entry": current_user_entry,
    }
