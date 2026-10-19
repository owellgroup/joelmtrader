"""Holds the live link to the MT5 desktop.

The laptop dials out to this engine. The engine never dials into the home network.
"""
import asyncio
import json
import logging
import threading
import uuid

from fastapi import WebSocketDisconnect

log = logging.getLogger("mt5")


class BridgeHub:
    def __init__(self):
        self.ws = None
        self.loop = None
        self.pending = {}

    @property
    def online(self):
        return self.ws is not None and self.loop is not None

    async def attach(self, ws):
        old = self.ws
        self.ws = ws
        self.loop = asyncio.get_running_loop()
        if old is not None and old is not ws:
            try:
                await old.close()
            except Exception:
                pass
        log.info("MT5 bridge connected from the laptop")
        try:
            while True:
                msg = json.loads(await ws.receive_text())
                waiter = self.pending.pop(msg.get("id"), None)
                if waiter is None:
                    continue
                event, box = waiter
                box["msg"] = msg
                event.set()
        except WebSocketDisconnect:
            pass
        except Exception as e:  # noqa: BLE001
            log.warning("MT5 bridge closed: %s", e)
        finally:
            if self.ws is ws:
                self.ws = None
                log.warning("MT5 bridge disconnected")
            for event, box in list(self.pending.values()):
                box["msg"] = {"ok": False, "error": "bridge disconnected"}
                event.set()
            self.pending.clear()

    async def _safe_send(self, ws, payload, req_id, event, box):
        try:
            await ws.send_text(payload)
        except Exception as e:  # noqa: BLE001
            self.pending.pop(req_id, None)
            box["msg"] = {"ok": False, "error": str(e)}
            event.set()

    def call(self, method, args, kwargs, timeout=60):
        if not self.online:
            raise RuntimeError(
                "The laptop bridge is not connected to the server. "
                "Close the old bridge window and start scripts\\mt5-bridge-windows.bat again. "
                "Leave it open until it says Connected to the server."
            )
        event = threading.Event()
        box = {}
        req_id = str(uuid.uuid4())

        def _send():
            if self.ws is None:
                box["msg"] = {"ok": False, "error": "bridge disconnected"}
                event.set()
                return
            self.pending[req_id] = (event, box)
            payload = json.dumps({
                "id": req_id,
                "method": method,
                "args": list(args),
                "kwargs": kwargs,
            })
            asyncio.create_task(self._safe_send(self.ws, payload, req_id, event, box))

        self.loop.call_soon_threadsafe(_send)
        if not event.wait(timeout):
            self.pending.pop(req_id, None)
            raise TimeoutError(f"MT5 bridge did not answer {method} within {timeout}s")
        msg = box.get("msg") or {}
        if not msg.get("ok"):
            raise RuntimeError(msg.get("error") or "MT5 bridge call failed")
        return msg.get("result")


hub = BridgeHub()
