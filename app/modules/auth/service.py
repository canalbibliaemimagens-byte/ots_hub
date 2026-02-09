"""
OTS Hub — Auth Module

Valida token no handshake WebSocket.
"""

import logging
from app.core.config import settings

logger = logging.getLogger("hub.auth")


def validate_token(token: str) -> bool:
    """Valida token contra ORACLE_TOKEN configurado."""
    if not token:
        return False
    return token == settings.ORACLE_TOKEN


def get_permissions(role: str) -> list:
    """Retorna permissões por role."""
    perms = {
        "bot":        ["telemetry:push", "signal:push", "command:listen"],
        "preditor":   ["signal:push", "bar:listen", "command:listen"],
        "executor":   ["order_command:push", "signal:listen", "command:listen"],
        "connector":  ["bar:push", "order_result:push", "order_command:listen", "command:listen"],
        "admin":      ["telemetry:read", "command:send", "signal:read"],
        "dashboard":  ["telemetry:read", "signal:read"],
    }
    return perms.get(role, [])
