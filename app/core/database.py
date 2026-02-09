"""
OTS Hub — Database (Supabase)
"""

import logging
from app.core.config import settings

logger = logging.getLogger("hub.db")

supabase = None

if settings.SUPABASE_URL and settings.SUPABASE_KEY:
    try:
        from supabase import create_client
        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        logger.info(f"Supabase initialized: {settings.SUPABASE_URL[:40]}...")
    except Exception as e:
        logger.error(f"Supabase init failed: {e}")
else:
    logger.warning("Supabase not configured — telemetry will only be in-memory")
