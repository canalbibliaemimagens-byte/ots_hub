"""
OTS Hub — Configuração via Supabase

Carrega configurações do Supabase ao invés de .env direto.
Mantém compatibilidade com .env como fallback.
"""

import os
import asyncio
from typing import List, Union, Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "OTS Hub"
    API_V1_STR: str = "/api/v1"
    VERSION: str = "3.0.0"

    # Supabase (sempre necessário)
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""

    # Defaults (serão substituídos por valores do Supabase se disponíveis)
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = False
    ORACLE_TOKEN: str = "change-me-in-production"
    AUTH_TIMEOUT: int = 5
    ALLOWED_ORIGINS: Union[str, List[str]] = "*"
    TELEMETRY_INTERVAL_MIN: int = 10

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"

    async def load_from_supabase(self):
        """Load settings from Supabase database."""
        if not self.SUPABASE_URL or not self.SUPABASE_KEY:
            print("⚠️ SUPABASE_URL ou SUPABASE_KEY não definidos — usando .env apenas")
            return

        try:
            from supabase import create_client

            client = create_client(self.SUPABASE_URL, self.SUPABASE_KEY)

            # Fetch all Hub config
            result = client.table("ots_config").select("key, value").execute()

            if result.data:
                config_map = {row["key"]: row["value"] for row in result.data}

                # Apply to settings
                if "host" in config_map:
                    self.HOST = config_map["host"]
                if "port" in config_map:
                    self.PORT = int(config_map["port"])
                if "debug" in config_map:
                    self.DEBUG = config_map["debug"].lower() == "true"
                if "oracle_token" in config_map:
                    self.ORACLE_TOKEN = config_map["oracle_token"]
                if "auth_timeout" in config_map:
                    self.AUTH_TIMEOUT = int(config_map["auth_timeout"])
                if "allowed_origins" in config_map:
                    origins = config_map["allowed_origins"]
                    self.ALLOWED_ORIGINS = origins.split(",") if "," in origins else origins
                if "telemetry_interval_min" in config_map:
                    self.TELEMETRY_INTERVAL_MIN = int(config_map["telemetry_interval_min"])

                print(f"✅ Configuração carregada do Supabase ({len(config_map)} keys)")
            else:
                print("⚠️ Nenhuma configuração encontrada no Supabase — usando defaults")

        except Exception as e:
            print(f"❌ Erro ao carregar config do Supabase: {e}")
            print("   Usando configuração do .env como fallback")


# Create settings instance
settings = Settings()


# Helper function to initialize settings
async def init_settings() -> Settings:
    """Initialize settings from Supabase."""
    await settings.load_from_supabase()
    return settings
