"""
OTS Hub — Test Suite
"""

import json
import time
import pytest
from unittest.mock import AsyncMock, patch


# ═══════════════════════════════════════════════════════════
# Auth
# ═══════════════════════════════════════════════════════════

class TestAuth:
    def test_valid_token(self):
        from app.modules.auth.service import validate_token
        with patch("app.modules.auth.service.settings") as s:
            s.ORACLE_TOKEN = "test-123"
            assert validate_token("test-123") is True

    def test_invalid_token(self):
        from app.modules.auth.service import validate_token
        with patch("app.modules.auth.service.settings") as s:
            s.ORACLE_TOKEN = "test-123"
            assert validate_token("wrong") is False

    def test_empty_token(self):
        from app.modules.auth.service import validate_token
        assert validate_token("") is False

    def test_permissions_connector(self):
        from app.modules.auth.service import get_permissions
        perms = get_permissions("connector")
        assert "bar:push" in perms
        assert "order_command:listen" in perms

    def test_permissions_preditor(self):
        from app.modules.auth.service import get_permissions
        perms = get_permissions("preditor")
        assert "signal:push" in perms

    def test_permissions_executor(self):
        from app.modules.auth.service import get_permissions
        perms = get_permissions("executor")
        assert "order_command:push" in perms


# ═══════════════════════════════════════════════════════════
# Telemetry
# ═══════════════════════════════════════════════════════════

class TestTelemetry:
    def setup_method(self):
        from app.modules.telemetry.service import TelemetryStore
        self.store = TelemetryStore()

    @pytest.mark.asyncio
    async def test_process_stores(self):
        result = await self.store.process("bot-01", {"balance": 10000, "equity": 10050})
        assert result["status"] == "ok"
        assert result["count"] == 1
        assert self.store.get_latest("bot-01")["balance"] == 10000

    @pytest.mark.asyncio
    async def test_increments(self):
        await self.store.process("bot-01", {"balance": 100})
        await self.store.process("bot-01", {"balance": 200})
        result = await self.store.process("bot-01", {"balance": 300})
        assert result["count"] == 3

    def test_remove(self):
        self.store._latest["bot-01"] = {"test": True}
        self.store.remove("bot-01")
        assert self.store.get_latest("bot-01") is None


# ═══════════════════════════════════════════════════════════
# Commands
# ═══════════════════════════════════════════════════════════

class TestCommands:
    def setup_method(self):
        from app.modules.commands.service import CommandRouter
        self.router = CommandRouter()

    def test_create_valid(self):
        cmd = self.router.create_command("pause", "executor-01")
        assert cmd is not None
        assert cmd["payload"]["action"] == "pause"

    def test_create_invalid(self):
        assert self.router.create_command("hack", "bot-01") is None

    def test_v3_actions(self):
        for action in ("load_model", "get_positions", "reconnect", "request_history"):
            cmd = self.router.create_command(action, "some-process")
            assert cmd is not None, f"{action} should be valid"

    def test_ack_processing(self):
        cmd = self.router.create_command("pause", "bot-01", "admin-01")
        origin, payload = self.router.process_ack("bot-01", {"ref_id": cmd["id"], "status": "success"})
        assert origin == "admin-01"
        assert len(self.router.get_pending()) == 0

    def test_cleanup_stale(self):
        cmd = self.router.create_command("pause", "bot-01")
        self.router._pending[cmd["id"]]["sent_at"] = time.time() - 60
        self.router.cleanup_stale(timeout=30)
        assert len(self.router.get_pending()) == 0


# ═══════════════════════════════════════════════════════════
# Connection Manager
# ═══════════════════════════════════════════════════════════

class TestConnectionManager:
    def setup_method(self):
        from app.websockets.manager import ConnectionManager
        self.mgr = ConnectionManager()

    @pytest.mark.asyncio
    async def test_connect_disconnect(self):
        ws = AsyncMock()
        await self.mgr.connect(ws, "bot-01")
        assert self.mgr.count == 1
        self.mgr.disconnect("bot-01")
        assert self.mgr.count == 0

    @pytest.mark.asyncio
    async def test_authenticate(self):
        ws = AsyncMock()
        await self.mgr.connect(ws, "pred-01")
        self.mgr.authenticate("pred-01", "preditor")
        assert self.mgr.is_authenticated("pred-01")
        assert self.mgr.get_by_role("preditor") == ["pred-01"]

    @pytest.mark.asyncio
    async def test_broadcast_by_role(self):
        ws_pred = AsyncMock()
        ws_exec = AsyncMock()
        await self.mgr.connect(ws_pred, "pred-01")
        await self.mgr.connect(ws_exec, "exec-01")
        self.mgr.authenticate("pred-01", "preditor")
        self.mgr.authenticate("exec-01", "executor")

        await self.mgr.broadcast("test-msg", role="preditor")
        ws_pred.send_text.assert_called_once_with("test-msg")
        ws_exec.send_text.assert_not_called()

        self.mgr.disconnect("pred-01")
        self.mgr.disconnect("exec-01")


# ═══════════════════════════════════════════════════════════
# Router — v3 Pipeline Routing
# ═══════════════════════════════════════════════════════════

class TestRouterV3:
    @pytest.mark.asyncio
    async def test_auth_success(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws = AsyncMock()
        await manager.connect(ws, "test-p1")
        with patch("app.websockets.router.validate_token", return_value=True):
            resp = await route_message(
                json.dumps({"type": "auth", "id": "a1", "payload": {"token": "ok", "role": "preditor"}}),
                "test-p1"
            )
            data = json.loads(resp)
            assert data["payload"]["status"] == "authenticated"
            assert data["payload"]["result"]["role"] == "preditor"
        manager.disconnect("test-p1")

    @pytest.mark.asyncio
    async def test_bar_routes_to_preditor(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws_conn = AsyncMock()
        ws_pred = AsyncMock()
        await manager.connect(ws_conn, "conn-01")
        await manager.connect(ws_pred, "pred-01")
        manager.authenticate("conn-01", "connector")
        manager.authenticate("pred-01", "preditor")

        resp = await route_message(
            json.dumps({"type": "bar", "payload": {"symbol": "EURUSD", "close": 1.085}}),
            "conn-01"
        )
        assert resp == ""
        ws_pred.send_text.assert_called_once()
        msg = json.loads(ws_pred.send_text.call_args[0][0])
        assert msg["type"] == "bar"
        assert msg["payload"]["symbol"] == "EURUSD"

        manager.disconnect("conn-01")
        manager.disconnect("pred-01")

    @pytest.mark.asyncio
    async def test_signal_routes_to_executor(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws_pred = AsyncMock()
        ws_exec = AsyncMock()
        await manager.connect(ws_pred, "pred-02")
        await manager.connect(ws_exec, "exec-01")
        manager.authenticate("pred-02", "preditor")
        manager.authenticate("exec-01", "executor")

        await route_message(
            json.dumps({"type": "signal", "payload": {"symbol": "EURUSD", "action": "LONG_MODERATE"}}),
            "pred-02"
        )
        ws_exec.send_text.assert_called_once()
        msg = json.loads(ws_exec.send_text.call_args[0][0])
        assert msg["type"] == "signal"
        assert msg["payload"]["action"] == "LONG_MODERATE"

        manager.disconnect("pred-02")
        manager.disconnect("exec-01")

    @pytest.mark.asyncio
    async def test_order_command_routes_to_connector(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws_exec = AsyncMock()
        ws_conn = AsyncMock()
        await manager.connect(ws_exec, "exec-02")
        await manager.connect(ws_conn, "conn-02")
        manager.authenticate("exec-02", "executor")
        manager.authenticate("conn-02", "connector")

        await route_message(
            json.dumps({"type": "order_command", "payload": {"action": "open", "symbol": "EURUSD"}}),
            "exec-02"
        )
        ws_conn.send_text.assert_called_once()
        msg = json.loads(ws_conn.send_text.call_args[0][0])
        assert msg["type"] == "order_command"

        manager.disconnect("exec-02")
        manager.disconnect("conn-02")

    @pytest.mark.asyncio
    async def test_order_result_routes_to_executor(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws_conn = AsyncMock()
        ws_exec = AsyncMock()
        await manager.connect(ws_conn, "conn-03")
        await manager.connect(ws_exec, "exec-03")
        manager.authenticate("conn-03", "connector")
        manager.authenticate("exec-03", "executor")

        await route_message(
            json.dumps({"type": "order_result", "payload": {"request_id": "r1", "success": True, "ticket": 123}}),
            "conn-03"
        )
        ws_exec.send_text.assert_called_once()
        msg = json.loads(ws_exec.send_text.call_args[0][0])
        assert msg["type"] == "order_result"
        assert msg["payload"]["ticket"] == 123

        manager.disconnect("conn-03")
        manager.disconnect("exec-03")

    @pytest.mark.asyncio
    async def test_unauthenticated_rejected(self):
        from app.websockets.router import route_message
        from app.websockets.manager import manager

        ws = AsyncMock()
        await manager.connect(ws, "unauth-01")
        resp = await route_message(
            json.dumps({"type": "bar", "payload": {}}), "unauth-01"
        )
        data = json.loads(resp)
        assert data["type"] == "error"
        assert "Not authenticated" in data["payload"]["message"]
        manager.disconnect("unauth-01")


# ═══════════════════════════════════════════════════════════
# FastAPI Integration
# ═══════════════════════════════════════════════════════════

class TestFastAPI:
    @pytest.mark.asyncio
    async def test_health(self):
        from httpx import AsyncClient, ASGITransport
        from app.main import app
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/health")
            assert resp.status_code == 200
            assert resp.json()["status"] == "ok"

    @pytest.mark.asyncio
    async def test_root(self):
        from httpx import AsyncClient, ASGITransport
        from app.main import app
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/")
            assert resp.status_code == 200
            assert "OTS Hub" in resp.json()["service"]

    @pytest.mark.asyncio
    async def test_status(self):
        from httpx import AsyncClient, ASGITransport
        from app.main import app
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            resp = await ac.get("/api/v1/status")
            assert resp.status_code == 200
            assert "connections" in resp.json()
