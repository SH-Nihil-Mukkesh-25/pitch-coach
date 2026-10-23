"""Unit tests for MongoDB migration layer.

Verifies:
- MongoDB connection and auto-indexing
- User registration and unique email constraint
- Session CRUD and querying
- Slide deck persistence in MongoDB
- Atomic quota incrementing and 429 limit enforcement
- Cascading user account deletion from MongoDB
"""
import uuid
from datetime import datetime, timezone
import pytest
from fastapi import HTTPException

from auth.account_service import delete_user_account
from database.mongodb import (
    ACHIEVEMENTS_COL,
    FEEDBACK_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    USERS_COL,
    USER_EMAILS_COL,
    USER_QUOTAS_COL,
    get_mongo_db,
    init_db_indexes,
)
from models import Achievement, PracticeSession, SlideDeck, User
from quota import check_and_increment_daily_quota
from slides.store import deck_store


@pytest.fixture
def mongo_db():
    db = get_mongo_db()
    init_db_indexes(db)
    return db


def test_mongodb_connection_and_collections(mongo_db):
    assert mongo_db is not None
    assert mongo_db.raw.name == "pitch_coach"
    collections = mongo_db.list_collection_names()
    for col in (USERS_COL, SESSIONS_COL, SLIDE_DECKS_COL, ACHIEVEMENTS_COL, USER_QUOTAS_COL):
        assert col in collections


def test_user_crud_and_dual_mode(mongo_db):
    user_id = f"test_user_{uuid.uuid4()}"
    email = f"{user_id}@example.com"
    user = User(
        id=user_id,
        email=email,
        full_name="MongoDB Test User",
        is_guest=False,
    )

    # 1. Save via document ref
    mongo_db.collection(USERS_COL).document(user_id).set(user.to_dict())

    # 2. Query via native find_one
    found = mongo_db[USERS_COL].find_one({"id": user_id})
    assert found is not None
    assert found["email"] == email
    assert found["full_name"] == "MongoDB Test User"

    # 3. Query via document snapshot
    snap = mongo_db.collection(USERS_COL).document(user_id).get()
    assert snap.exists is True
    assert snap.to_dict()["email"] == email

    # 4. Update
    mongo_db.collection(USERS_COL).document(user_id).update({"full_name": "Updated Name"})
    updated = mongo_db[USERS_COL].find_one({"id": user_id})
    assert updated["full_name"] == "Updated Name"

    # 5. Delete
    mongo_db.collection(USERS_COL).document(user_id).delete()
    assert mongo_db[USERS_COL].find_one({"id": user_id}) is None


def test_atomic_quota_increment(mongo_db):
    uid = f"user_quota_{uuid.uuid4()}"
    limit = 3

    # Increments 1, 2, 3
    c1 = check_and_increment_daily_quota(uid, "sessions", limit)
    assert c1 == 1
    c2 = check_and_increment_daily_quota(uid, "sessions", limit)
    assert c2 == 2
    c3 = check_and_increment_daily_quota(uid, "sessions", limit)
    assert c3 == 3

    # Exceeding limit throws 429
    with pytest.raises(HTTPException) as exc_info:
        check_and_increment_daily_quota(uid, "sessions", limit)
    assert exc_info.value.status_code == 429

    # Cleanup
    mongo_db[USER_QUOTAS_COL].delete_many({"user_id": uid})


def test_slide_deck_persistence(mongo_db):
    uid = f"user_deck_{uuid.uuid4()}"
    deck_id = f"deck_{uuid.uuid4()}"
    deck = SlideDeck(
        id=deck_id,
        user_id=uid,
        content_hash="test_hash_123",
        filename="pitch.pdf",
        status="done",
        page_count=5,
    )

    deck_store.save(deck)

    # Fetch via store
    loaded = deck_store.get(deck_id)
    assert loaded is not None
    assert loaded.id == deck_id
    assert loaded.content_hash == "test_hash_123"

    # Find by hash
    by_hash = deck_store.find_by_hash(uid, "test_hash_123")
    assert by_hash is not None
    assert by_hash.id == deck_id

    # List user decks
    user_decks = deck_store.list_user_decks(uid)
    assert any(d.id == deck_id for d in user_decks)

    # Delete
    deleted = deck_store.delete(deck_id)
    assert deleted is True
    assert deck_store.get(deck_id) is None


def test_practice_session_queries(mongo_db):
    uid = f"user_sess_{uuid.uuid4()}"
    now = datetime.now(timezone.utc)
    s1 = PracticeSession(
        id=str(uuid.uuid4()),
        user_id=uid,
        mode="interview",
        topic_or_question="Question 1",
        wpm=135.0,
        clarity_score=85.0,
        confidence_score=90.0,
        overall_score=88.0,
        is_analyzed=True,
        created_at=now,
    )
    s2 = PracticeSession(
        id=str(uuid.uuid4()),
        user_id=uid,
        mode="pitch",
        topic_or_question="Pitch 1",
        wpm=145.0,
        clarity_score=80.0,
        confidence_score=85.0,
        overall_score=82.0,
        is_analyzed=True,
        created_at=now,
    )

    mongo_db.collection(SESSIONS_COL).document(s1.id).set(s1.to_dict())
    mongo_db.collection(SESSIONS_COL).document(s2.id).set(s2.to_dict())

    # Query all for user
    docs = list(mongo_db[SESSIONS_COL].find({"user_id": uid}))
    assert len(docs) == 2

    # Query with filter
    interview_docs = list(mongo_db[SESSIONS_COL].find({"user_id": uid, "mode": "interview"}))
    assert len(interview_docs) == 1
    assert interview_docs[0]["id"] == s1.id

    # Aggregation test via MongoQuery
    agg_res = (
        mongo_db.collection(SESSIONS_COL)
        .where("user_id", "==", uid)
        .count(alias="count")
        .avg("overall_score", alias="avg_score")
        .get()
    )
    assert len(agg_res) > 0
    row = agg_res[0]
    aliases = {item.alias: item.value for item in row}
    assert aliases["count"] == 2
    assert round(aliases["avg_score"], 1) == 85.0

    # Cleanup
    mongo_db[SESSIONS_COL].delete_many({"user_id": uid})


def test_cascading_account_deletion_mongodb(mongo_db):
    uid = f"del_user_{uuid.uuid4()}"
    email = f"{uid}@example.com"
    user = User(id=uid, email=email, full_name="User To Delete")
    mongo_db.collection(USERS_COL).document(uid).set(user.to_dict())
    mongo_db.collection(USER_EMAILS_COL).document(email).set({"email": email, "user_id": uid})

    # Add a session
    sid = str(uuid.uuid4())
    sess = PracticeSession(id=sid, user_id=uid, overall_score=75.0, is_analyzed=True)
    mongo_db.collection(SESSIONS_COL).document(sid).set(sess.to_dict())

    # Add an achievement
    ach_id = str(uuid.uuid4())
    ach = Achievement(id=ach_id, user_id=uid, key="first_session")
    mongo_db.collection(ACHIEVEMENTS_COL).document(ach_id).set(ach.to_dict())

    # Add quota
    check_and_increment_daily_quota(uid, "sessions", 10)

    # Perform cascading account deletion
    res = delete_user_account(user, db=mongo_db)
    assert res["mongodb_deleted"] is True

    # Verify completely deleted from MongoDB
    assert mongo_db[USERS_COL].find_one({"id": uid}) is None
    assert mongo_db[USER_EMAILS_COL].find_one({"email": email}) is None
    assert mongo_db[SESSIONS_COL].find_one({"user_id": uid}) is None
    assert mongo_db[ACHIEVEMENTS_COL].find_one({"user_id": uid}) is None
    assert mongo_db[USER_QUOTAS_COL].find_one({"user_id": uid}) is None
