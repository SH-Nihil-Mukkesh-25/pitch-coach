"""GET /me, PATCH /me, POST /me/avatar, and DELETE /me — user profile endpoints."""
import os
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from google.cloud import firestore as fs

from auth.dependencies import get_current_user
from firestore import get_db
from models import (
    User,
    USERS_COL,
    SESSIONS_COL,
    ACHIEVEMENTS_COL,
    SLIDE_DECKS_COL,
)
from schemas import UpdateProfileRequest, UserResponse

router = APIRouter(prefix="/users", tags=["users"])

AVATARS_DIR = Path("avatars")
AVATARS_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_AVATAR_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_AVATAR_SIZE = 5 * 1024 * 1024  # 5 MB


def _build_user_response(user: User) -> UserResponse:
    return UserResponse(
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
        avatar_url=user.avatar_url,
        settings=user.settings,
        created_at=user.created_at,
    )


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return _build_user_response(current_user)


@router.patch("/me", response_model=UserResponse)
def update_me(
    req: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    updates = req.model_dump(exclude_none=True)
    if updates:
        db.collection(USERS_COL).document(current_user.id).update(updates)
        for field, value in updates.items():
            setattr(current_user, field, value)
    return _build_user_response(current_user)


@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_AVATAR_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported image format. Allowed: JPG, PNG, WEBP",
        )

    filename = f"{current_user.id}_{int(datetime.now(timezone.utc).timestamp())}{ext}"
    dest_path = AVATARS_DIR / filename

    # Read and validate size
    content = await file.read()
    if len(content) > MAX_AVATAR_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Avatar image size exceeds 5MB limit",
        )

    with open(dest_path, "wb") as f:
        f.write(content)

    avatar_url = f"/users/avatar/{filename}"
    db.collection(USERS_COL).document(current_user.id).update({"avatar_url": avatar_url})
    current_user.avatar_url = avatar_url
    return _build_user_response(current_user)


@router.get("/avatar/{filename}")
def get_avatar_file(filename: str):
    file_path = AVATARS_DIR / filename
    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Avatar not found")
    return FileResponse(file_path)


@router.delete("/me")
def delete_account(
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Permanently delete user account and cascade delete associated records."""
    from auth.account_service import delete_user_account
    user_id = current_user.id
    results = delete_user_account(current_user, db=db)

    return {
        "status": "success",
        "message": "Account successfully deleted",
        "user_id": user_id,
        **results,
    }

