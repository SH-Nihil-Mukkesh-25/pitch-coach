"""Auth routes: signup, login, guest, refresh, upgrade-guest."""
import logging
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from firebase_admin import auth as fb_auth
from pymongo.errors import DuplicateKeyError

from auth.dependencies import get_current_user
from auth.utils import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from config import get_settings
from database.mongodb import get_db, MongoDatabaseWrapper, USERS_COL, USER_EMAILS_COL
from limiter import limiter
from models import User
from schemas import AuthResponse, FirebaseLoginRequest, LoginRequest, RefreshRequest, SignupRequest, UpgradeGuestRequest, UserResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _build_auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user=UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role_occupation=user.role_occupation,
            primary_objective=user.primary_objective,
            target_industry=user.target_industry,
            experience_level=user.experience_level,
            feedback_style=user.feedback_style,
            is_guest=user.is_guest,
            dark_mode=user.dark_mode,
        ),
    )


def _register_user_atomic(db: MongoDatabaseWrapper, user: User, normalized_email: str):
    """Atomically registers user and locks unique email in user_emails collection."""
    # Check existing users collection
    existing_user = db[USERS_COL].find_one({"email": normalized_email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    existing_email = db[USER_EMAILS_COL].find_one({"email": normalized_email})
    if existing_email:
        raise HTTPException(status_code=400, detail="Email already registered")

    try:
        # Reserve email
        db[USER_EMAILS_COL].insert_one({
            "_id": normalized_email,
            "id": normalized_email,
            "email": normalized_email,
            "user_id": user.id,
            "created_at": datetime.now(timezone.utc),
        })
        # Save user document
        db.collection(USERS_COL).document(user.id).set(user.to_dict())
    except DuplicateKeyError:
        raise HTTPException(status_code=400, detail="Email already registered")


def _upgrade_user_atomic(db: MongoDatabaseWrapper, user_id: str, normalized_email: str, update_dict: dict):
    """Atomically reserves email and updates guest user document."""
    existing_user = db[USERS_COL].find_one({"email": normalized_email, "id": {"$ne": user_id}})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    existing_email = db[USER_EMAILS_COL].find_one({"email": normalized_email})
    if existing_email and existing_email.get("user_id") != user_id:
        raise HTTPException(status_code=400, detail="Email already registered")

    try:
        db[USER_EMAILS_COL].update_one(
            {"email": normalized_email},
            {"$set": {
                "id": normalized_email,
                "email": normalized_email,
                "user_id": user_id,
                "created_at": datetime.now(timezone.utc),
            }},
            upsert=True,
        )
        db.collection(USERS_COL).document(user_id).update(update_dict)
    except DuplicateKeyError:
        raise HTTPException(status_code=400, detail="Email already registered")


@router.post("/signup", response_model=AuthResponse)
@limiter.limit("5/minute")
def signup(request: Request, req: SignupRequest, db: MongoDatabaseWrapper = Depends(get_db)):
    email_normalized = req.email.strip().lower()
    user = User(
        id=str(uuid.uuid4()),
        email=email_normalized,
        password_hash=hash_password(req.password),
        full_name=req.full_name.strip(),
        is_guest=False,
    )
    _register_user_atomic(db, user, email_normalized)
    return _build_auth_response(user)


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
def login(request: Request, req: LoginRequest, db: MongoDatabaseWrapper = Depends(get_db)):
    email_normalized = req.email.strip().lower()
    doc_dict = db[USERS_COL].find_one({"email": email_normalized})
    if not doc_dict:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    user = User.from_dict(doc_dict)
    if not user.password_hash or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _build_auth_response(user)


@router.post("/firebase", response_model=AuthResponse)
def firebase_login(req: FirebaseLoginRequest, db: MongoDatabaseWrapper = Depends(get_db)):
    """Exchange a Firebase ID token (from the Flutter app) for backend JWTs.

    The Firebase uid is used as the user document id, so the same person
    always maps to the same MongoDB user. The user doc is created on first use.
    """
    try:
        decoded = fb_auth.verify_id_token(req.id_token)
    except Exception as exc:
        logger.warning("[auth] Firebase token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail=f"Invalid Firebase token: {exc}")

    uid: str = decoded["uid"]
    doc = db.collection(USERS_COL).document(uid).get()
    if doc.exists:
        user = User.from_dict(doc.to_dict())
    else:
        email = decoded.get("email")
        if email:
            email = email.strip().lower()
        user = User(
            id=uid,
            email=email,
            full_name=decoded.get("name") or "User",
            is_guest=False,
        )
        db.collection(USERS_COL).document(uid).set(user.to_dict())
        if email:
            db.collection(USER_EMAILS_COL).document(email).set({
                "user_id": uid,
                "email": email,
                "created_at": datetime.now(timezone.utc),
            })
    return _build_auth_response(user)


@router.post("/guest", response_model=AuthResponse)
@limiter.limit("10/hour")
def guest_login(request: Request, db: MongoDatabaseWrapper = Depends(get_db)):
    """Creates an anonymous account. History is preserved if the user later upgrades."""
    user = User(
        id=str(uuid.uuid4()),
        is_guest=True,
        full_name="Guest User",
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.GUEST_EXPIRE_DAYS),
    )
    db.collection(USERS_COL).document(user.id).set(user.to_dict())
    return _build_auth_response(user)


@router.post("/refresh")
@limiter.limit("10/minute")
def refresh_token(request: Request, req: RefreshRequest, db: MongoDatabaseWrapper = Depends(get_db)):
    payload = decode_token(req.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user_id: str = payload["sub"]
    doc = db.collection(USERS_COL).document(user_id).get()
    if not doc.exists:
        raise HTTPException(status_code=401, detail="User not found")
    return {"access_token": create_access_token({"sub": user_id}), "token_type": "bearer"}


@router.post("/upgrade-guest", response_model=AuthResponse)
def upgrade_guest(
    req: UpgradeGuestRequest,
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """Convert a guest account into a full account — keeps all session history."""
    if not current_user.is_guest:
        raise HTTPException(status_code=400, detail="Not a guest account")

    email_normalized = req.email.strip().lower()
    update_dict = {
        "email": email_normalized,
        "password_hash": hash_password(req.password),
        "full_name": req.full_name.strip(),
        "is_guest": False,
        "expires_at": None,
    }
    _upgrade_user_atomic(db, current_user.id, email_normalized, update_dict)

    # Refresh local object
    current_user.email = email_normalized
    current_user.full_name = req.full_name.strip()
    current_user.is_guest = False
    current_user.expires_at = None
    return _build_auth_response(current_user)


@router.delete("/account")
def delete_account(
    current_user: User = Depends(get_current_user),
    db: MongoDatabaseWrapper = Depends(get_db),
):
    """
    DELETE /auth/account:
    Permanently deletes all user data across D1, MongoDB, Storage, and Auth.
    """
    from auth.account_service import delete_user_account
    result = delete_user_account(current_user, db=db)
    return {"deleted": True, **result}
