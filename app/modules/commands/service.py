"""
OTS Hub — Commands Module

Gerencia comandos enviados pelo admin/dashboard para os processos.
O Hub atua como proxy: recebe comando → roteia para target → coleta ack.
"""

import logging
import uuid
import time
from typing import Dict, Optional

logger = logging.getLogger("hub.commands")

VALID_ACTIONS = {
    # Universal
    "pause", "resume", "status", "get_state",
    # Executor
    "close_all", "close_symbol", "close_position",
    "reload_config",
    "get_symbol_config", "set_symbol_config",
    "get_general_config", "set_general_config",
    # Preditor
    "load_model", "unload_model", "list_models",
    "get_available_models", "request_history",
    # Connector
    "get_history", "get_account", "get_positions", "reconnect",
}


class CommandRouter:
    """Roteia comandos do admin para processos conectados."""

    def __init__(self):
        self._pending: Dict[str, dict] = {}
        self._msg_id_map: Dict[str, str] = {}
        self._history: list = []

    def create_command(
        self,
        action: str,
        target_instance: str,
        origin_id: str = "",
        params: Optional[dict] = None,
        original_msg_id: Optional[str] = None,
    ) -> Optional[dict]:
        if action not in VALID_ACTIONS:
            logger.warning(f"Invalid action: {action}")
            return None

        cmd_id = f"cmd-{uuid.uuid4().hex[:8]}"
        envelope = {
            "type": "command",
            "id": cmd_id,
            "timestamp": time.time(),
            "payload": {
                "action": action,
                "params": params or {},
            }
        }

        self._pending[cmd_id] = {
            "command": envelope,
            "target": target_instance,
            "origin": origin_id,
            "sent_at": time.time(),
            "ack": None,
        }
        if original_msg_id:
            self._msg_id_map[cmd_id] = original_msg_id

        return envelope

    def process_ack(self, instance_id: str, ack_payload: dict) -> tuple[Optional[str], Optional[dict]]:
        ref_id = ack_payload.get("ref_id")
        if not ref_id or ref_id not in self._pending:
            return None, None

        pending = self._pending.pop(ref_id)
        pending["ack"] = {
            "from": instance_id,
            "status": ack_payload.get("status", "unknown"),
            "result": ack_payload.get("result"),
            "received_at": time.time(),
        }

        self._history.append(pending)
        if len(self._history) > 100:
            self._history = self._history[-100:]

        logger.info(f"Ack received: {ref_id} from {instance_id} status={ack_payload.get('status')}")

        original_msg_id = self._msg_id_map.pop(ref_id, None)
        if original_msg_id:
            ack_payload = {**ack_payload, "ref_id": original_msg_id}

        return pending["origin"], ack_payload

    def get_pending(self) -> list:
        return [
            {"id": k, "target": v["target"], "action": v["command"]["payload"]["action"]}
            for k, v in self._pending.items()
        ]

    def get_history(self, limit: int = 20) -> list:
        return self._history[-limit:]

    def cleanup_stale(self, timeout: float = 30.0):
        now = time.time()
        expired = [k for k, v in self._pending.items() if now - v["sent_at"] > timeout]
        for k in expired:
            self._pending.pop(k)
            logger.warning(f"Command {k} expired (no ack)")


command_router = CommandRouter()
