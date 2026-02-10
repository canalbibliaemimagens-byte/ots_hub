"""
OTS Hub — WebSocket Connection Manager

Gerencia conexões ativas, tracking de auth e roteamento de mensagens.
"""

import logging
import time
from typing import Dict, Optional
from fastapi import WebSocket

logger = logging.getLogger("hub.ws")


class ConnectionInfo:
    """Metadados de uma conexão."""

    __slots__ = ("websocket", "instance_id", "role", "authenticated",
                 "connected_at", "last_message_at")

    def __init__(self, websocket: WebSocket, instance_id: str):
        self.websocket = websocket
        self.instance_id = instance_id
        self.role: str = "unknown"
        self.authenticated: bool = False
        self.connected_at: float = time.time()
        self.last_message_at: float = 0.0


class ConnectionManager:
    """Gerencia conexões WebSocket ativas."""

    def __init__(self):
        self._connections: Dict[str, ConnectionInfo] = {}

    async def connect(self, websocket: WebSocket, instance_id: str) -> ConnectionInfo:
        # Close stale connection if exists (e.g. client reconnected)
        old = self._connections.get(instance_id)
        if old and old.websocket != websocket:
            try:
                await old.websocket.close(code=4000, reason="Replaced by new connection")
            except Exception:
                pass
            logger.info(f"Replaced stale connection: {instance_id}")

        await websocket.accept()
        info = ConnectionInfo(websocket, instance_id)
        self._connections[instance_id] = info
        logger.info(f"Connected: {instance_id} (total={len(self._connections)})")
        return info

    def disconnect(self, instance_id: str):
        if instance_id in self._connections:
            del self._connections[instance_id]
            logger.info(f"Disconnected: {instance_id} (total={len(self._connections)})")

    def authenticate(self, instance_id: str, role: str = "bot"):
        if instance_id in self._connections:
            conn = self._connections[instance_id]
            conn.authenticated = True
            conn.role = role
            logger.info(f"Authenticated: {instance_id} (role={role})")

    def is_authenticated(self, instance_id: str) -> bool:
        conn = self._connections.get(instance_id)
        return conn.authenticated if conn else False

    def get(self, instance_id: str) -> Optional[ConnectionInfo]:
        return self._connections.get(instance_id)

    async def send(self, instance_id: str, message: str) -> bool:
        conn = self._connections.get(instance_id)
        if not conn:
            return False
        try:
            await conn.websocket.send_text(message)
            return True
        except Exception as e:
            logger.error(f"Send to {instance_id} failed: {e}")
            return False

    async def broadcast(self, message: str, role: Optional[str] = None,
                        exclude: Optional[str] = None):
        """
        Broadcast para conexões autenticadas.
        Itera sobre snapshot do dict para evitar RuntimeError se
        conexões são adicionadas/removidas durante o broadcast.
        """
        # Snapshot — evita "dictionary changed size during iteration"
        targets = list(self._connections.items())
        dead = []

        for iid, conn in targets:
            if not conn.authenticated:
                continue
            if exclude and iid == exclude:
                continue
            if role and conn.role != role:
                continue
            try:
                await conn.websocket.send_text(message)
            except Exception as e:
                logger.error(f"Broadcast to {iid} failed: {e}")
                dead.append(iid)

        # Remove conexões mortas detectadas durante broadcast
        for iid in dead:
            logger.warning(f"Removing dead connection: {iid}")
            self._connections.pop(iid, None)

    def list_connections(self) -> list:
        return [
            {
                "instance_id": iid,
                "role": conn.role,
                "authenticated": conn.authenticated,
                "connected_at": conn.connected_at,
                "last_message_at": conn.last_message_at,
            }
            for iid, conn in self._connections.items()
        ]

    def get_by_role(self, role: str) -> list:
        return [
            iid for iid, conn in self._connections.items()
            if conn.authenticated and conn.role == role
        ]

    @property
    def count(self) -> int:
        return len(self._connections)

    @property
    def authenticated_count(self) -> int:
        return sum(1 for c in self._connections.values() if c.authenticated)


manager = ConnectionManager()
