#!/bin/bash
# Connect the installed MetaTrader to the Flutter app.
# Do not type the broker login on the VNC screen. The app sends it.
set -u
export DEBIAN_FRONTEND=noninteractive

PREFIX=/home/mt5/.mt5
PYDIR="$PREFIX/drive_c/Python311"
KEY="$(docker exec forexbot-engine printenv ENGINE_API_KEY 2>/dev/null || true)"
KEY="$(printf '%s' "$KEY" | tr -d '\r')"
if [ -z "$KEY" ]; then
  echo "Could not read ENGINE_API_KEY from the forexbot-engine container."
  echo "The Flutter app cannot connect until that container is running."
  exit 1
fi

apt-get install -y unzip wget ca-certificates >/dev/null

if [ ! -x "$PYDIR/python.exe" ]; then
  echo "Installing Windows Python next to MetaTrader. This takes a few minutes."
  mkdir -p "$PYDIR"
  wget -q -O /tmp/py.zip https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip
  unzip -q -o /tmp/py.zip -d "$PYDIR"
  sed -i 's/^#import site/import site/' "$PYDIR/python311._pth"
  printf '\nLib\\site-packages\n' >> "$PYDIR/python311._pth"
  chown -R mt5:mt5 "$PYDIR"
fi

if ! su - mt5 -c "export DISPLAY=:99 WINEPREFIX=$PREFIX WINEDEBUG=-all; wine 'C:\\Python311\\python.exe' -c 'import MetaTrader5, websockets, numpy'" >/dev/null 2>&1; then
  echo "Installing the MetaTrader Python package."
  wget -q -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
  su - mt5 -c "export DISPLAY=:99 WINEPREFIX=$PREFIX WINEDEBUG=-all; wine 'C:\\Python311\\python.exe' 'Z:\\tmp\\get-pip.py' --no-warn-script-location"
  su - mt5 -c "export DISPLAY=:99 WINEPREFIX=$PREFIX WINEDEBUG=-all; wine 'C:\\Python311\\python.exe' -m pip install --no-cache-dir 'MetaTrader5>=5.0.45' 'websockets>=13' 'numpy>=1.26,<3'"
fi

cat > /home/mt5/mt5_bridge.py << 'PY'
import asyncio, inspect, json, os, sys, time
import MetaTrader5 as mt5
import numpy as np
import websockets

SERVER = os.environ.get("MT5_BRIDGE_URL", "ws://37.27.56.188:8088/mt5-bridge").strip()
API_KEY = os.environ.get("ENGINE_API_KEY", "").strip()
MT5_PATH = os.environ.get("MT5_EXE_PATH", r"C:\Program Files\MetaTrader 5\terminal64.exe")

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

async def serve():
    headers = {"X-Api-Key": API_KEY}
    while True:
        try:
            print(f"Connecting to {SERVER} ...", flush=True)
            params = {"ping_interval": 20, "ping_timeout": 30, "max_size": 20000000}
            if "additional_headers" in inspect.signature(websockets.connect).parameters:
                params["additional_headers"] = headers
            else:
                params["extra_headers"] = headers
            async with websockets.connect(SERVER, **params) as ws:
                print("Connected to the engine.", flush=True)
                async for raw in ws:
                    req = json.loads(raw)
                    try:
                        result = await asyncio.to_thread(dispatch, req["method"], req.get("args") or [], req.get("kwargs") or {})
                        await ws.send(json.dumps({"id": req["id"], "ok": True, "result": result}))
                    except Exception as exc:
                        await ws.send(json.dumps({"id": req.get("id"), "ok": False, "error": f"{type(exc).__name__}: {exc}"}))
            print("Connection closed. Reconnecting in 5 seconds.", flush=True)
        except Exception as exc:
            print(f"Not connected ({type(exc).__name__}: {exc}). Retrying in 5 seconds.", flush=True)
        await asyncio.sleep(5)

if __name__ == "__main__":
    if not API_KEY:
        print("ENGINE_API_KEY is missing.", flush=True)
        sys.exit(1)
    asyncio.run(serve())
PY
chown mt5:mt5 /home/mt5/mt5_bridge.py

umask 077
cat > /etc/mt5-bridge.env << EOF
DISPLAY=:99
WINEPREFIX=$PREFIX
WINEDEBUG=-all
MT5_BRIDGE_URL=ws://37.27.56.188:8088/mt5-bridge
ENGINE_API_KEY=$KEY
MT5_EXE_PATH=C:\\Program Files\\MetaTrader 5\\terminal64.exe
EOF
chmod 600 /etc/mt5-bridge.env

cat > /etc/systemd/system/mt5-bridge.service << 'EOF'
[Unit]
Description=MetaTrader bridge for the Flutter app
After=network-online.target

[Service]
User=mt5
EnvironmentFile=/etc/mt5-bridge.env
ExecStart=/usr/bin/wine C:/Python311/python.exe -u Z:/home/mt5/mt5_bridge.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mt5-bridge
systemctl restart mt5-bridge
sleep 8
echo
echo "Bridge log:"
journalctl -u mt5-bridge --no-pager -n 30
echo
echo "Leave the MetaTrader window open."
echo "When the log says Connected to the engine, open http://37.27.56.188:8088"
echo "Sign in, press Connect MT5, and type the account there."
