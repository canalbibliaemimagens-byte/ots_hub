"""
OTS Hub — Telemetry Module

Recebe, cacheia e persiste telemetria dos processos.
"""

import asyncio
import logging
import time
from collections import defaultdict
from typing import Dict, Optional

from app.core.database import supabase

logger = logging.getLogger("hub.telemetry")


class TelemetryStore:
    """Armazena telemetria em memória + persiste no Supabase."""

    def __init__(self):
        self._latest: Dict[str, dict] = {}
        self._last_received: Dict[str, float] = {}
        self._last_persist: Dict[str, float] = {}
        self._counts: Dict[str, int] = defaultdict(int)

    async def process(self, instance_id: str, payload: dict) -> dict:
        now = time.time()
        enriched = {"instance_id": instance_id, "server_ts": now, **payload}

        self._latest[instance_id] = enriched
        self._last_received[instance_id] = now
        self._counts[instance_id] += 1

        if supabase:
            last_persist = self._last_persist.get(instance_id, 0)
            if now - last_persist >= 30:
                self._last_persist[instance_id] = now
                asyncio.create_task(self._persist(enriched))

        return {"status": "ok", "count": self._counts[instance_id]}

    async def _persist(self, data: dict):
        try:
            record = {
                "instance_id": data["instance_id"],
                "balance": data.get("balance"),
                "equity": data.get("equity"),
                "status": data.get("status"),
                "raw_data": data,
            }
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: supabase.table("telemetry").insert(record).execute()
            )
        except Exception as e:
            logger.error(f"Supabase persist failed: {e}")

    def get_latest(self, instance_id: str) -> Optional[dict]:
        return self._latest.get(instance_id)

    def get_all_latest(self) -> Dict[str, dict]:
        return dict(self._latest)

    def get_connected_instances(self) -> list:
        now = time.time()
        return [iid for iid, ts in self._last_received.items() if ts > now - 300]

    def remove(self, instance_id: str):
        self._latest.pop(instance_id, None)
        self._last_received.pop(instance_id, None)


telemetry_store = TelemetryStore()
