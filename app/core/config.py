"""
OTS Hub — Configuração Central
"""

from pydantic_settings import BaseSettings
from typing import List, Union


class Settings(BaseSettings):
    PROJECT_NAME: str = "OTS Hub"
    API_V1_STR: str = "/api/v1"
    VERSION: str = "2.0.0"

    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = False

    # Auth — token estático compartilhado entre Hub e processos
    ORACLE_TOKEN: str = "change-me-in-production"
    AUTH_TIMEOUT: int = 5

    ALLOWED_ORIGINS: Union[str, List[str]] = "*"

    # Supabase (opcional)
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""

    TELEMETRY_INTERVAL_MIN: int = 10

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()
