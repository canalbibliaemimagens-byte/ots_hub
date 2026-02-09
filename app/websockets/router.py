"""
OTS Hub — WebSocket Message Router v2.0

Dispatcher central: parseia JSON, roteia por type.

Roteamento v3 (processos independentes):
  bar            → connector publica,  preditor recebe
  signal         → preditor publica,   executor + dashboard recebe
  order_command  → executor publica,   connector recebe
  order_result   → connector publica,  executor + dashboard recebe
  position_event → connector publica,  executor + dashboard recebe
  account_update → connector publica,  executor + dashboard recebe
  history_response → connector publica, preditor recebe

Roles: preditor, executor, connector, dashboard, admin, bot (legacy)
"""

import json
import logging
import time

from app.modules.auth.service import validate_token
from app.modules.telemetry.service import telemetry_store
from app.modules.commands.service import command_router
from app.websockets.manager import manager

logger = logging.getLogger("hub.router")


async def route_message(raw_data: str, instance_id: str) -> str:
    """
    Roteia mensagem WebSocket para o módulo correto.

    Returns:
        JSON string com resposta, ou "" se fire-and-forget.
    """
    try:
        data = json.loads(raw_data)
    except json.JSONDecodeError:
        return _error("Invalid JSON")

    msg_type = data.get("type")
    payload = data.get("payload", {})
    msg_id = data.get("id", "")

    conn = manager.get(instance_id)
    if conn:
        conn.last_message_at = time.time()

    # ── AUTH ──────────────────────────────────────────────
    if msg_type == "auth":
        token = payload.get("token", "")
        role = payload.get("role", "bot")
        if validate_token(token):
            manager.authenticate(instance_id, role)
            return _ack(msg_id, "authenticated", {"instance_id": instance_id, "role": role})
        else:
            return _error("Invalid token", ref_id=msg_id, code=4001)

    # ── Rejeita não-autenticados ─────────────────────────
    if not manager.is_authenticated(instance_id):
        return _error("Not authenticated. Send 'auth' first.", ref_id=msg_id, code=4001)

    # =================================================================
    # PIPELINE v3 — processos se comunicam via Hub
    # =================================================================

    # ── BAR (connector → preditor) ────────────────────────
    if msg_type == "bar":
        await manager.broadcast(_envelope("bar", instance_id, payload), role="preditor")
        return ""

    # ── SIGNAL (preditor → executor + dashboard) ──────────
    if msg_type == "signal":
        fwd = _envelope("signal", instance_id, payload)
        await manager.broadcast(fwd, role="executor")
        await manager.broadcast(fwd, role="dashboard")
        await manager.broadcast(fwd, role="admin")
        return ""

    # ── ORDER_COMMAND (executor → connector) ──────────────
    if msg_type == "order_command":
        await manager.broadcast(_envelope("order_command", instance_id, payload), role="connector")
        return ""

    # ── ORDER_RESULT (connector → executor + dashboard) ───
    if msg_type == "order_result":
        fwd = _envelope("order_result", instance_id, payload)
        await manager.broadcast(fwd, role="executor")
        await manager.broadcast(fwd, role="dashboard")
        return ""

    # ── POSITION_EVENT (connector → executor + dashboard) ─
    if msg_type == "position_event":
        fwd = _envelope("position_event", instance_id, payload)
        await manager.broadcast(fwd, role="executor")
        await manager.broadcast(fwd, role="dashboard")
        return ""

    # ── ACCOUNT_UPDATE (connector → executor + dashboard) ─
    if msg_type == "account_update":
        fwd = _envelope("account_update", instance_id, payload)
        await manager.broadcast(fwd, role="executor")
        await manager.broadcast(fwd, role="dashboard")
        return ""

    # ── HISTORY_RESPONSE (connector → preditor) ───────────
    if msg_type == "history_response":
        await manager.broadcast(_envelope("history_response", instance_id, payload), role="preditor")
        return ""

    # =================================================================
    # EXISTING — backward compatible
    # =================================================================

    # ── TELEMETRY ────────────────────────────────────────
    if msg_type == "telemetry":
        result = await telemetry_store.process(instance_id, payload)
        fwd = _envelope("telemetry", instance_id, payload)
        await manager.broadcast(fwd, role="dashboard")
        await manager.broadcast(fwd, role="admin")
        return _ack(msg_id, "telemetry_ok", result)

    # ── ACK (resposta de comando) ────────────────────────
    if msg_type == "ack":
        origin_id, response = command_router.process_ack(instance_id, payload)
        if origin_id and response:
            fwd = json.dumps({"type": "ack", "timestamp": time.time(), "payload": response})
            await manager.send(origin_id, fwd)
        return ""

    # ── COMMAND (admin/dashboard → qualquer processo) ────
    if msg_type == "command":
        conn_info = manager.get(instance_id)
        if not conn_info or conn_info.role not in ("admin", "dashboard"):
            return _error("Only admin/dashboard can send commands", ref_id=msg_id)

        target = payload.get("target")
        action = payload.get("action")
        params = payload.get("params", {})

        if not action:
            return _error("Command requires 'action'", ref_id=msg_id)

        if not target:
            for role in ("bot", "preditor", "executor", "connector"):
                candidates = manager.get_by_role(role)
                if candidates:
                    target = candidates[0]
                    break
            if not target:
                return _error("No target connected", ref_id=msg_id)

        cmd = command_router.create_command(action, target, instance_id, params, original_msg_id=msg_id)
        if not cmd:
            return _error(f"Invalid action: {action}", ref_id=msg_id)

        sent = await manager.send(target, json.dumps(cmd))
        if sent:
            return ""
        else:
            return _error(f"Target {target} not connected", ref_id=msg_id)

    return _error(f"Unknown type: {msg_type}", ref_id=msg_id)


# =================================================================
# Helpers
# =================================================================

def _envelope(msg_type: str, from_id: str, payload: dict) -> str:
    return json.dumps({
        "type": msg_type,
        "from": from_id,
        "payload": payload,
        "timestamp": time.time(),
    })


def _ack(ref_id: str, status: str, result: dict = None) -> str:
    resp = {"type": "ack", "timestamp": time.time(), "payload": {"ref_id": ref_id, "status": status}}
    if result:
        resp["payload"]["result"] = result
    return json.dumps(resp)


def _error(message: str, ref_id: str = "", code: int = 0) -> str:
    resp = {"type": "error", "timestamp": time.time(), "payload": {"message": message}}
    if ref_id:
        resp["payload"]["ref_id"] = ref_id
    if code:
        resp["payload"]["code"] = code
    return json.dumps(resp)
