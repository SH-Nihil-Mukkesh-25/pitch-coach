from typing import List, Optional
from pydantic import model_validator
from pydantic_settings import BaseSettings
from functools import lru_cache

INSECURE_SECRET_KEYS = {
    "",
    "change-me-in-production-use-a-long-random-string",
    "replace_with_a_long_random_secret_in_production",
}


class Settings(BaseSettings):
    # JWT
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24   # 1 day
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Security & Access Control
    ALLOWED_ORIGINS: str = ""
    ADMIN_USER_IDS: str = ""

    # Cloudflare D1 (SQL storage for metrics and aggregates)
    CF_ACCOUNT_ID: str = ""
    CF_D1_DATABASE_ID: str = ""
    CF_API_TOKEN: str = ""

    # MongoDB (Document storage: users, sessions, slide_decks, achievements, quotas)
    MONGODB_URI: str = "mongodb://localhost:27017"
    MONGODB_DB_NAME: str = "pitch_coach"

    @property
    def allowed_origins_list(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    @property
    def admin_user_id_list(self) -> List[str]:
        return [a.strip() for a in self.ADMIN_USER_IDS.split(",") if a.strip()]

    @model_validator(mode="after")
    def validate_secret_key(self):
        secret = (self.SECRET_KEY or "").strip()
        if not secret or secret in INSECURE_SECRET_KEYS:
            raise ValueError(
                "Insecure or missing SECRET_KEY! A strong, random SECRET_KEY must be configured in .env. "
                "Generate one using: python -c \"import secrets; print(secrets.token_urlsafe(64))\""
            )
        return self

    # Groq key dedicated to the audio-analysis pipeline (Whisper STT + agentic coach).
    # Falls back to GROQ_API_KEY when empty.
    GROQ_AUDIO_API_KEY: str = ""
    GROQ_API_KEY: str = ""
    # Unified default text model across audio coach and slide coach
    GROQ_WHISPER_MODEL: str = "whisper-large-v3-turbo"
    GROQ_LLM_MODEL: str = "qwen/qwen3.8-27b"

    # Firebase Admin SDK — path to service-account JSON
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "./firebase_service_account.json"

    # Firebase Storage bucket for recordings, e.g. "<project-id>.firebasestorage.app"
    # (Firebase Console -> Storage shows the exact name).
    FIREBASE_STORAGE_BUCKET: str = ""

    # Uploads larger than this are rejected (recordings are small AAC files)
    MAX_AUDIO_UPLOAD_MB: int = 25

    # Audio storage directory fallback for local disk
    AUDIO_UPLOAD_DIR: str = "./audio_files"
    # Audio retention policy in days (0 = delete audio after analysis, 30 = 30-day retention)
    AUDIO_RETENTION_DAYS: int = 30

    # Slide Coach Groq models
    # Groq deprecated llama-4-scout and llama-3.3-70b-versatile in mid-2026.
    # Current active models with Vision & JSON mode are qwen/qwen3.8-27b and openai/gpt-oss-120b.
    GROQ_VISION_MODEL: str = "qwen/qwen3.8-27b"
    GROQ_TEXT_MODEL: str = "openai/gpt-oss-120b"

    # Slide Deck storage & TTL
    SLIDE_DECK_DIR: str = "./slide_decks"
    SLIDE_DECK_TTL_DAYS: int = 7

    # Guest account expiry
    GUEST_EXPIRE_DAYS: int = 30

    # Abuse protection quotas (per user per UTC day)
    MAX_DECKS_PER_DAY: int = 10
    MAX_SESSIONS_PER_DAY: int = 50

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()


def get_groq_key(feature: Optional[str] = None) -> str:
    """Returns the appropriate Groq API key for the requested feature ('audio' vs general)."""
    settings = get_settings()
    if feature == "audio" and settings.GROQ_AUDIO_API_KEY:
        return settings.GROQ_AUDIO_API_KEY
    return settings.GROQ_API_KEY or settings.GROQ_AUDIO_API_KEY
