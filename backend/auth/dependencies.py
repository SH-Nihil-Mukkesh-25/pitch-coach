from datetime import datetime, timezone, timedelta
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from config import get_settings
from database.mongodb import get_db, MongoDatabaseWrapper, USERS_COL
from models import User
from auth.utils import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: MongoDatabaseWrapper = Depends(get_db),
) -> User:
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id: str = payload["sub"]
    doc = db.collection(USERS_COL).document(user_id).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    user = User.from_dict(doc.to_dict())

    # Check guest expiration
    if user.is_guest:
        now = datetime.now(timezone.utc)
        settings = get_settings()
        expiry = user.expires_at or (user.created_at + timedelta(days=settings.GUEST_EXPIRE_DAYS))
        if now > expiry:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Guest session has expired. Please sign up to keep your data.",
            )

    return user


oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def get_current_user_optional(
    token: str | None = Depends(oauth2_scheme_optional),
    db: MongoDatabaseWrapper = Depends(get_db),
) -> User | None:
    if not token:
        return None
    try:
        return get_current_user(token=token, db=db)
    except HTTPException:
        return None
