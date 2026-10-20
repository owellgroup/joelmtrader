"""MT5 bridge for the Linux (Wine) server.

Runs inside Wine, next to terminal64.exe. It dials OUT to the engine
websocket and answers MetaTrader5 calls. The heartbeat file stays fresh
while this process is alive, including while it is waiting to reconnect,
so a short backend outage does not restart MetaTrader.
"""
import asyncio
import inspect
import json
import os
import sys
import time

import MetaTrader5 as mt5
import numpy as np
import websockets

SERVER = os.environ.get("MT5_BRIDGE_URL", "ws://37.27.56.188:8088/mt5-bridge").strip()
API_KEY = os.environ.get("ENGINE_API_KEY", "").strip()
MT5_PATH = os.environ.get("MT5_EXE_PATH", r"C:\Program Files\MetaTrader 5\terminal64.exe")
HEARTBEAT = os.environ.get("MT5_HEARTBEAT_FILE", r"Z:\tmp\mt5_bridge_heartbeat")


def pack(obj):
    if obj is None or isinstance(obj, (bool, int, float, str)):
        return obj
    if isinstance(obj, np.generic):
        return obj.item()
    if isinstance(obj, np.ndarray):
        if obj.dtype.names:
            return [{name: pack(val) for name, val in zip(obj.dtype.names, row)} for row in obj.tolist()]
        return [pack(v) for v in obj.tolist()]
    if hasattr(obj, "_asdict"):
        return {k: pack(v) for k, v in obj._asdict().items()}
    if isinstance(obj, dict):
        return {str(k): pack(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [pack(v) for v in obj]
    return str(obj)


def dispatch(method, args, kwargs):
    if method == "__lookup__":
        obj = getattr(mt5, args[0])
        return {"callable": callable(obj), "value": None if callable(obj) else pack(obj)}
    if method == "initialize" and "path" not in kwargs and not args and MT5_PATH:
        kwargs = dict(kwargs, path=MT5_PATH)
    return pack(getattr(mt5, method)(*args, **kwargs))


def beat():
    try:
        with open(HEARTBEAT, "w", encoding="utf-8") as handle:
            handle.write(str(int(time.time())))
    except OSError:
        pass


async def heartbeat():
    while True:
        beat()
        await asyncio.sleep(10)


async def serve():
    headers = {"X-Api-Key": API_KEY}
    hb = asyncio.create_task(heartbeat())
    try:
        while True:
            try:
                print(f"Connecting to {SERVER} ...", flush=True)
                params = {"ping_interval": 20, "ping_timeout": 30, "max_size": 20_000_000}
                if "additional_headers" in inspect.signature(websockets.connect).parameters:
                    params["additional_headers"] = headers
                else:
                    params["extra_headers"] = headers
                async with websockets.connect(SERVER, **params) as ws:
                    print("Connected to the engine.", flush=True)
                    async for raw in ws:
                        req = json.loads(raw)
                        try:
                            result = await asyncio.to_thread(
                                dispatch, req["method"], req.get("args") or [], req.get("kwargs") or {})
                            await ws.send(json.dumps({"id": req["id"], "ok": True, "result": result}))
                        except Exception as exc:  # noqa: BLE001
                            await ws.send(json.dumps({
                                "id": req.get("id"), "ok": False, "error": f"{type(exc).__name__}: {exc}"}))
                print("Connection closed by the engine. Reconnecting in 5 seconds.", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"Not connected ({type(exc).__name__}: {exc}). Retrying in 5 seconds.", flush=True)
            await asyncio.sleep(5)
    finally:
        hb.cancel()


if __name__ == "__main__":
    if not SERVER or not API_KEY:
        print("MT5_BRIDGE_URL and ENGINE_API_KEY must be set in the stack environment.", flush=True)
        time.sleep(30)
        sys.exit(1)
    asyncio.run(serve())
