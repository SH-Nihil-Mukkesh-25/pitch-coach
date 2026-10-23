"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import logging

from config import get_settings
from limiter import limiter
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from firestore import get_db  # noqa: F401 — initialises Firebase on first import
from auth.router import router as auth_router
from users.router import router as users_router
from sessions.router import router as sessions_router, sweep_stuck_sessions
from stats.router import router as stats_router
from achievements.router import router as achievements_router
from slides.router import router as slides_router
from metrics.router import router as metrics_router
from feedback.router import router as feedback_router
from resume.router import router as resume_router
from interviewer.router import router as interviewer_router
from templates.router import router as templates_router
from practice_plan.router import router as practice_plan_router
from reports.router import router as reports_router
from slides.store import deck_store

logger = logging.getLogger(__name__)
settings = get_settings()

app = FastAPI(
    title="Pitch Coach API",
    version="2.0.0",
    description="Backend API for the Pitch Coach Flutter app — powered by MongoDB & Cloudflare D1.",
)


@app.on_event("startup")
async def on_startup():
    try:
        from firestore import init_firebase
        init_firebase()
        from database.mongodb import get_mongo_db, init_db_indexes
        db = get_mongo_db()
        if db is not None:
            init_db_indexes(db)
        swept_decks = deck_store.sweep_stuck_decks()
        swept_sessions = sweep_stuck_sessions()
        logger.info("Startup sweep: recovered %d stuck decks and %d stuck sessions", swept_decks, swept_sessions)
    except Exception as exc:
        logger.warning("Startup stuck job sweep failed: %s", exc)

# Attach rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(sessions_router)
app.include_router(stats_router)
app.include_router(achievements_router)
app.include_router(slides_router)
app.include_router(metrics_router)
app.include_router(feedback_router)
app.include_router(resume_router)
app.include_router(interviewer_router)
app.include_router(templates_router)
app.include_router(practice_plan_router)
app.include_router(reports_router)


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok", "version": "2.0.0", "db": "mongodb"}


from auth.dependencies import get_current_user
from models import User
from fastapi import Depends
from google.cloud import firestore as fs


@app.delete("/account", tags=["account"])
def delete_account_root(
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """
    DELETE /account:
    Permanently deletes all user data across D1, Firestore, Storage, and Auth.
    """
    from auth.account_service import delete_user_account
    result = delete_user_account(current_user, db=db)
    return {"deleted": True, **result}
