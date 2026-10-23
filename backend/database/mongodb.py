"""
MongoDB client connection and collections layer for Pitch Coach backend.

Replaces Firestore with MongoDB for:
- users
- user_emails
- sessions
- slide_decks
- achievements
- feedback
- user_quotas

Exposes:
- `get_mongo_client()`: Cached MongoClient instance
- `get_mongo_db()` / `get_db()`: Database instance with both native PyMongo
  queries and dual-mode collection helpers for drop-in migration.
- `init_db_indexes(db)`: Idempotently creates unique and performance indexes.
"""
from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Iterator, List, Optional, Tuple, Union

import pymongo
from pymongo import ASCENDING, DESCENDING, MongoClient, ReturnDocument
from pymongo.collection import Collection
from pymongo.database import Database
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError

from config import get_settings

logger = logging.getLogger(__name__)

# Collection Names
USERS_COL = "users"
USER_EMAILS_COL = "user_emails"
SESSIONS_COL = "sessions"
SLIDE_DECKS_COL = "slide_decks"
ACHIEVEMENTS_COL = "achievements"
FEEDBACK_COL = "feedback"
USER_QUOTAS_COL = "user_quotas"

_mongo_client: Optional[MongoClient] = None
_mongo_db_instance: Optional[MongoDatabaseWrapper] = None
_indexes_initialized: bool = False


def _ensure_utc(dt: Any) -> Any:
    """Ensure datetime has timezone.utc attached."""
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
    return dt


def _clean_doc_for_app(doc: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Normalizes document from MongoDB for application consumption."""
    if not doc:
        return None
    d = dict(doc)
    doc_id = str(d.get("id") or d.get("_id") or "")
    d["id"] = doc_id
    # Clean datetime fields to UTC
    for k, v in list(d.items()):
        if isinstance(v, datetime):
            d[k] = _ensure_utc(v)
    return d


class MongoDocumentSnapshot:
    """Snapshot mirroring Firestore DocumentSnapshot for drop-in compatibility."""

    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]], exists: bool = True):
        self.id = doc_id
        self._data = _clean_doc_for_app(data) if data else None
        self.exists = exists and (self._data is not None)

    def to_dict(self) -> Dict[str, Any]:
        return dict(self._data) if self._data else {}

    def get(self, field: str, default: Any = None) -> Any:
        return self._data.get(field, default) if self._data else default

    def __getitem__(self, item: str) -> Any:
        if self._data and item in self._data:
            return self._data[item]
        raise KeyError(item)


class MongoDocumentRef:
    """Document reference with .get(), .set(), .update(), .delete()."""

    def __init__(self, collection: Collection, doc_id: str):
        self._col = collection
        self.id = doc_id

    def get(self, transaction=None) -> MongoDocumentSnapshot:
        doc = self._col.find_one({"$or": [{"id": self.id}, {"_id": self.id}]})
        if not doc:
            return MongoDocumentSnapshot(self.id, None, exists=False)
        return MongoDocumentSnapshot(self.id, doc, exists=True)

    def set(self, data: Dict[str, Any], merge: bool = False) -> None:
        payload = dict(data)
        payload["id"] = self.id
        payload["_id"] = self.id
        # Normalize datetimes
        for k, v in payload.items():
            if isinstance(v, datetime):
                payload[k] = _ensure_utc(v)

        if merge:
            self._col.update_one(
                {"$or": [{"id": self.id}, {"_id": self.id}]},
                {"$set": payload},
                upsert=True,
            )
        else:
            self._col.replace_one(
                {"$or": [{"id": self.id}, {"_id": self.id}]},
                payload,
                upsert=True,
            )

    def update(self, data: Dict[str, Any]) -> None:
        payload = dict(data)
        for k, v in payload.items():
            if isinstance(v, datetime):
                payload[k] = _ensure_utc(v)
        self._col.update_one(
            {"$or": [{"id": self.id}, {"_id": self.id}]},
            {"$set": payload},
            upsert=True,
        )

    def delete(self) -> None:
        self._col.delete_one({"$or": [{"id": self.id}, {"_id": self.id}]})


class MongoAggItem:
    def __init__(self, alias: str, value: Any):
        self.alias = alias
        self.value = value


class MongoQuery:
    """Query builder supporting Firestore-like filtering, ordering, and aggregation."""

    def __init__(self, collection: Collection):
        self._col = collection
        self._filter: Dict[str, Any] = {}
        self._sort: List[Tuple[str, int]] = []
        self._limit: Optional[int] = None
        self._agg_ops: Dict[str, Any] = {}

    def where(self, field: Any = None, op: Optional[str] = None, val: Any = None, *, filter=None) -> MongoQuery:
        # Support FieldFilter or (field, op, val)
        if filter is not None:
            f = filter
            f_field = getattr(f, "field_path", None) or getattr(f, "field", "")
            f_op = getattr(f, "op_string", None) or getattr(f, "op", "==")
            f_val = getattr(f, "value", None)
            return self.where(f_field, f_op, f_val)

        if field and op is not None:
            if isinstance(val, datetime):
                val = _ensure_utc(val)

            if op == "==":
                self._filter[field] = val
            elif op == ">=":
                self._filter.setdefault(field, {})["$gte"] = val
            elif op == "<=":
                self._filter.setdefault(field, {})["$lte"] = val
            elif op == ">":
                self._filter.setdefault(field, {})["$gt"] = val
            elif op == "<":
                self._filter.setdefault(field, {})["$lt"] = val
            elif op == "!=":
                self._filter.setdefault(field, {})["$ne"] = val
            elif op in ("in", "array-contains-any"):
                self._filter.setdefault(field, {})["$in"] = val
            elif op == "array-contains":
                self._filter[field] = val
        return self

    def order_by(self, field: str, direction: Any = ASCENDING) -> MongoQuery:
        dir_val = DESCENDING if str(direction).upper() in ("DESCENDING", "DESC", "-1") else ASCENDING
        self._sort.append((field, dir_val))
        return self

    def limit(self, count: int) -> MongoQuery:
        self._limit = count
        return self

    def stream(self) -> Iterator[MongoDocumentSnapshot]:
        cursor = self._col.find(self._filter)
        if self._sort:
            cursor = cursor.sort(self._sort)
        if self._limit:
            cursor = cursor.limit(self._limit)
        for doc in cursor:
            yield MongoDocumentSnapshot(str(doc.get("id") or doc.get("_id")), doc, exists=True)

    def get(self) -> Union[List[MongoDocumentSnapshot], List[List[MongoAggItem]]]:
        if self._agg_ops:
            return self._execute_aggregation()

        return list(self.stream())

    def count(self, alias: str = "count") -> MongoQuery:
        self._agg_ops[alias] = {"$sum": 1}
        return self

    def avg(self, field: str, alias: str = "avg") -> MongoQuery:
        self._agg_ops[alias] = {"$avg": f"${field}"}
        return self

    def _execute_aggregation(self) -> List[List[MongoAggItem]]:
        group_stage: Dict[str, Any] = {"_id": None}
        for alias, op in self._agg_ops.items():
            group_stage[alias] = op

        pipeline = []
        if self._filter:
            pipeline.append({"$match": self._filter})
        pipeline.append({"$group": group_stage})

        results = list(self._col.aggregate(pipeline))
        row: List[MongoAggItem] = []
        if results:
            first = results[0]
            for alias in self._agg_ops.keys():
                row.append(MongoAggItem(alias, first.get(alias)))
        else:
            for alias in self._agg_ops.keys():
                row.append(MongoAggItem(alias, 0))
        return [row]


class MongoCursorWrapper:
    """Cursor wrapper that cleans documents on iteration while preserving chaining methods."""

    def __init__(self, cursor: Any):
        self._cursor = cursor

    def sort(self, *args, **kwargs) -> "MongoCursorWrapper":
        self._cursor = self._cursor.sort(*args, **kwargs)
        return self

    def limit(self, *args, **kwargs) -> "MongoCursorWrapper":
        self._cursor = self._cursor.limit(*args, **kwargs)
        return self

    def skip(self, *args, **kwargs) -> "MongoCursorWrapper":
        self._cursor = self._cursor.skip(*args, **kwargs)
        return self

    def __iter__(self) -> Iterator[Dict[str, Any]]:
        for doc in self._cursor:
            yield _clean_doc_for_app(doc)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._cursor, name)


class MongoCollectionWrapper:
    """Wraps PyMongo Collection to offer both native Mongo and dual-mode collection helpers."""

    def __init__(self, raw_collection: Collection):
        self._col = raw_collection

    @property
    def raw(self) -> Collection:
        return self._col

    # ── PyMongo pass-throughs ──────────────────────────────────────────────────
    def find_one(self, *args, **kwargs):
        doc = self._col.find_one(*args, **kwargs)
        return _clean_doc_for_app(doc)

    def find(self, *args, **kwargs) -> MongoCursorWrapper:
        cursor = self._col.find(*args, **kwargs)
        return MongoCursorWrapper(cursor)

    def insert_one(self, document: Dict[str, Any], *args, **kwargs):
        doc = dict(document)
        if "id" in doc and "_id" not in doc:
            doc["_id"] = doc["id"]
        return self._col.insert_one(doc, *args, **kwargs)

    def update_one(self, filter: Dict[str, Any], update: Dict[str, Any], *args, **kwargs):
        return self._col.update_one(filter, update, *args, **kwargs)

    def update_many(self, filter: Dict[str, Any], update: Dict[str, Any], *args, **kwargs):
        return self._col.update_many(filter, update, *args, **kwargs)

    def delete_one(self, filter: Dict[str, Any], *args, **kwargs):
        return self._col.delete_one(filter, *args, **kwargs)

    def delete_many(self, filter: Dict[str, Any], *args, **kwargs):
        return self._col.delete_many(filter, *args, **kwargs)

    def aggregate(self, pipeline: List[Dict[str, Any]], *args, **kwargs):
        return self._col.aggregate(pipeline, *args, **kwargs)

    def count_documents(self, filter: Dict[str, Any], *args, **kwargs):
        return self._col.count_documents(filter, *args, **kwargs)

    def create_index(self, *args, **kwargs):
        return self._col.create_index(*args, **kwargs)

    def find_one_and_update(self, *args, **kwargs):
        doc = self._col.find_one_and_update(*args, **kwargs)
        return _clean_doc_for_app(doc)

    # ── Dual-mode helpers ─────────────────────────────────────────────────────
    def document(self, doc_id: str) -> MongoDocumentRef:
        return MongoDocumentRef(self._col, doc_id)

    def where(self, field: Any = None, op: Optional[str] = None, val: Any = None, *, filter=None) -> MongoQuery:
        q = MongoQuery(self._col)
        return q.where(field, op, val, filter=filter)

    def order_by(self, field: str, direction: Any = ASCENDING) -> MongoQuery:
        q = MongoQuery(self._col)
        return q.order_by(field, direction)

    def limit(self, count: int) -> MongoQuery:
        q = MongoQuery(self._col)
        return q.limit(count)

    def stream(self) -> Iterator[MongoDocumentSnapshot]:
        return MongoQuery(self._col).stream()

    def get(self) -> List[MongoDocumentSnapshot]:
        return MongoQuery(self._col).get()

    def __getattr__(self, item: str):
        return getattr(self._col, item)


class MongoDatabaseWrapper:
    """Database wrapper providing collection access via `db[name]` and `db.collection(name)`."""

    def __init__(self, raw_db: Database):
        self._db = raw_db
        self._collections: Dict[str, MongoCollectionWrapper] = {}

    @property
    def raw(self) -> Database:
        return self._db

    def collection(self, name: str) -> MongoCollectionWrapper:
        if name not in self._collections:
            self._collections[name] = MongoCollectionWrapper(self._db[name])
        return self._collections[name]

    def __getitem__(self, name: str) -> MongoCollectionWrapper:
        return self.collection(name)

    def __getattr__(self, name: str):
        if hasattr(self._db, name):
            return getattr(self._db, name)
        return self.collection(name)

    def list_collection_names(self) -> List[str]:
        return self._db.list_collection_names()


def init_db_indexes(db: MongoDatabaseWrapper) -> None:
    """Initializes indexes across all core collections idempotently."""
    global _indexes_initialized
    if _indexes_initialized:
        return
    try:
        # Users
        db[USERS_COL].create_index([("id", ASCENDING)], unique=True)
        try:
            for idx in db[USERS_COL].list_indexes():
                if idx.get("name") == "email_1" and "partialFilterExpression" not in idx:
                    db[USERS_COL].drop_index("email_1")
                    break
        except Exception:
            pass
        db[USERS_COL].create_index(
            [("email", ASCENDING)],
            unique=True,
            partialFilterExpression={"email": {"$type": "string"}},
        )

        # User emails reservation
        db[USER_EMAILS_COL].create_index([("email", ASCENDING)], unique=True)

        # Sessions
        db[SESSIONS_COL].create_index([("id", ASCENDING)], unique=True)
        db[SESSIONS_COL].create_index([("user_id", ASCENDING), ("created_at", DESCENDING)])
        db[SESSIONS_COL].create_index([("user_id", ASCENDING), ("is_analyzed", ASCENDING)])
        db[SESSIONS_COL].create_index([("d1_pending", ASCENDING)])

        # Slide Decks
        db[SLIDE_DECKS_COL].create_index([("id", ASCENDING)], unique=True)
        db[SLIDE_DECKS_COL].create_index([("user_id", ASCENDING), ("created_at", DESCENDING)])
        db[SLIDE_DECKS_COL].create_index([("user_id", ASCENDING), ("content_hash", ASCENDING), ("status", ASCENDING)])

        # Achievements
        db[ACHIEVEMENTS_COL].create_index([("id", ASCENDING)], unique=True)
        db[ACHIEVEMENTS_COL].create_index([("user_id", ASCENDING), ("key", ASCENDING)])

        # User Quotas
        db[USER_QUOTAS_COL].create_index([("doc_id", ASCENDING)], unique=True, sparse=True)
        db[USER_QUOTAS_COL].create_index([("user_id", ASCENDING), ("feature", ASCENDING), ("date", ASCENDING)])

        # Feedback
        db[FEEDBACK_COL].create_index([("id", ASCENDING)], unique=True)
        db[FEEDBACK_COL].create_index([("user_id", ASCENDING)])

        _indexes_initialized = True
        logger.info("[mongodb] Database indexes successfully initialized.")
    except Exception as exc:
        logger.warning("[mongodb] Index initialization notice: %s", exc)


def get_mongo_client() -> MongoClient:
    """Returns singleton PyMongo MongoClient instance."""
    global _mongo_client
    if _mongo_client is None:
        settings = get_settings()
        uri = settings.MONGODB_URI or "mongodb://localhost:27017"
        logger.info("[mongodb] Connecting to MongoDB at %s...", uri.split("@")[-1])
        _mongo_client = MongoClient(
            uri,
            serverSelectionTimeoutMS=15000,
            connectTimeoutMS=15000,
            socketTimeoutMS=30000,
            maxPoolSize=50,
            minPoolSize=0,
        )
    return _mongo_client


def get_mongo_db(db_name: Optional[str] = None) -> MongoDatabaseWrapper:
    """FastAPI dependency and factory for MongoDB database wrapper."""
    global _mongo_db_instance
    if _mongo_db_instance is None:
        client = get_mongo_client()
        settings = get_settings()
        name = db_name or settings.MONGODB_DB_NAME or "pitch_coach"
        raw_db = client[name]
        _mongo_db_instance = MongoDatabaseWrapper(raw_db)
        init_db_indexes(_mongo_db_instance)
    return _mongo_db_instance


def get_db() -> MongoDatabaseWrapper:
    """Default database dependency matching earlier signature for seamless integration."""
    return get_mongo_db()
