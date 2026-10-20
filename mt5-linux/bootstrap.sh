#!/bin/bash
# Save this file first with:  cat > /tmp/bootstrap.sh
# Then run:  bash /tmp/bootstrap.sh
set -euo pipefail
echo "=== MT5 setup on 37.27.56.188 ==="
if [ "$(uname -m)" != "x86_64" ]; then
  echo "This server is $(uname -m). MetaTrader 5 needs x86_64. Stop here."
  exit 1
fi
sudo mkdir -p /opt/mt5-bridge
sudo rm -rf /opt/mt5-bridge/*
sudo tee /opt/mt5-bridge/Dockerfile >/dev/null << 'END_DOCKERFILE'
# MT5 under Wine + the Windows Python bridge, one container.
# Build on 84.8.131.140:  docker build -t mt5-bridge:latest /opt/mt5-bridge
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:99 \
    WINEPREFIX=/wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    MALLOC_ARENA_MAX=2

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates wget curl gnupg2 unzip cabextract procps xauth tini \
      supervisor xvfb x11vnc novnc websockify openbox \
 && mkdir -pm755 /etc/apt/keyrings \
 && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
 && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources \
 && apt-get update \
 && apt-get install -y --install-recommends winehq-stable \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY mt5_bridge.py check_mt5.py svc.sh entrypoint.sh supervisord.conf /opt/mt5/
RUN chmod +x /opt/mt5/svc.sh /opt/mt5/entrypoint.sh

WORKDIR /opt/mt5
EXPOSE 6080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/mt5/entrypoint.sh"]
END_DOCKERFILE
sudo tee /opt/mt5-bridge/entrypoint.sh >/dev/null << 'END_ENTRYPOINT_SH'
#!/usr/bin/env bash
# One container stays up. The MetaTrader screen is on port 6080 for the whole install.
# After install, supervisord keeps MetaTrader and the Python bridge running.
set -uo pipefail
mkdir -p "$WINEPREFIX"
unset XAUTHORITY
export DISPLAY=:99

start_screen() {
  if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
    Xvfb :99 -screen 0 1280x800x24 -ac -nolisten tcp >/tmp/xvfb.log 2>&1 &
    sleep 1
  fi
  if [ "${ENABLE_VNC:-1}" = "1" ] && ! pgrep -x x11vnc >/dev/null 2>&1; then
    # Xvfb is started with -ac. Do not pass -auth. A guessed cookie makes XOpenDisplay fail.
    if [ -n "${VNC_PASSWORD:-}" ]; then
      x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass >/dev/null 2>&1
      x11vnc -display :99 -forever -shared -rfbport 5900 -rfbauth /tmp/vncpass -noxdamage -bg -o /tmp/x11vnc.log
    else
      x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -noxdamage -bg -o /tmp/x11vnc.log
    fi
  fi
  if [ "${ENABLE_VNC:-1}" = "1" ] && ! pgrep -x websockify >/dev/null 2>&1; then
    websockify --web=/usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 >/tmp/novnc.log 2>&1 &
  fi
}

if [ ! -f "$WINEPREFIX/.provisioned-v1" ]; then
  echo "[entrypoint] Installing MT5. Open http://37.27.56.188:6080/vnc.html and click Next if a window is waiting."
  start_screen
  while [ ! -f "$WINEPREFIX/.provisioned-v1" ]; do
    if /opt/mt5/svc.sh provision; then
      break
    fi
    echo "[entrypoint] MetaTrader is not installed yet. The screen stays up. Retrying in 30 seconds."
    start_screen
    sleep 30
  done
  pkill -x x11vnc || true
  pkill -x websockify || true
  pkill -x Xvfb || true
  sleep 1
fi

exec /usr/bin/supervisord -n -c /opt/mt5/supervisord.conf
END_ENTRYPOINT_SH
sudo tee /opt/mt5-bridge/svc.sh >/dev/null << 'END_SVC_SH'
#!/usr/bin/env bash
# usage: svc.sh <provision|xvfb|wm|vnc|novnc|mt5|bridge|watchdog|health|check>
export DISPLAY=:99
PYW='C:\Python311\python.exe'
MT5_EXE='C:\Program Files\MetaTrader 5\terminal64.exe'
HB=/tmp/mt5_bridge_heartbeat

provision() {
  set -euo pipefail
  local PYDIR="$WINEPREFIX/drive_c/Python311"
  local MT5DIR="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
  local PY_URL="https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
  # mt5.md downloads this script. The script then downloads mt5setup.exe from the same folder.
  local MT5_SH_URL="https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh"
  local MT5_URLS="${MT5_SETUP_URLS:-}"
  cd /tmp

  echo "[provision] 1/4 creating the Wine prefix"
  wineboot -u >/dev/null 2>&1 || true
  wine winecfg -v win10 >/dev/null 2>&1 || true

  echo "[provision] 2/4 installing Python 3.11 (embeddable) under Wine"
  if [ ! -f "$PYDIR/python.exe" ]; then
    mkdir -p "$PYDIR"
    wget -q -O /tmp/py.zip "$PY_URL"
    unzip -q -o /tmp/py.zip -d "$PYDIR"
    sed -i 's/^#import site/import site/' "$PYDIR/python311._pth"
    printf '\nLib\\site-packages\n' >> "$PYDIR/python311._pth"
  fi
  if ! wine "$PYW" -c "import MetaTrader5, websockets, numpy" >/dev/null 2>&1; then
    wget -q -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
    wine "$PYW" 'Z:\tmp\get-pip.py' --no-warn-script-location
    wine "$PYW" -m pip install --no-cache-dir --no-warn-script-location \
        "MetaTrader5>=5.0.45" "websockets>=13" "numpy>=1.26,<3"
  fi
  wine "$PYW" -c "import MetaTrader5, websockets, numpy; print('python packages OK, MetaTrader5', MetaTrader5.__version__)"

  echo "[provision] 3/4 installing MetaTrader 5 from the mt5.md script"
  if [ ! -f "$MT5DIR/terminal64.exe" ]; then
    local ok=0 url found="" setup="$WINEPREFIX/cache/mt5setup.exe"
    mkdir -p "$WINEPREFIX/cache"
    wget -q -O "$WINEPREFIX/cache/mt5linux.sh" "$MT5_SH_URL" || true
    if [ -s "$WINEPREFIX/cache/mt5linux.sh" ]; then
      found=$(grep -oE 'https://[^" ]+mt5setup\.exe' "$WINEPREFIX/cache/mt5linux.sh" | head -n 1 || true)
    fi
    MT5_URLS="$found https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe $MT5_URLS"
    if [ -s "$setup" ] && [ "$(stat -c%s "$setup")" -gt 1000000 ]; then
      echo "[provision] using the installer already saved on the volume"
      ok=1
    fi
    if [ "$ok" != 1 ]; then
      for url in $MT5_URLS; do
        [ -n "$url" ] || continue
        echo "[provision] downloading $url"
        rm -f "$setup"
        if wget -O "$setup" --timeout=60 --tries=2 --user-agent="Mozilla/5.0" --progress=dot:mega "$url" && [ -s "$setup" ]; then
          ok=1
          break
        fi
        echo "[provision] that download failed"
      done
    fi
    [ "$ok" = 1 ] || { echo "[provision] cannot download mt5setup.exe"; exit 1; }
    echo "[provision] installer ready ($(stat -c%s "$setup") bytes). Starting it."
    echo "[provision] If this waits, open http://37.27.56.188:6080/vnc.html and finish the MetaTrader window."
    cp -f "$setup" "$WINEPREFIX/drive_c/mt5setup.exe"
    ( timeout 1500 wine 'C:\mt5setup.exe' /auto >"$WINEPREFIX/cache/mt5setup.log" 2>&1 || true ) &
    local waited=0 found="" quiet=0
    while [ "$waited" -lt 2700 ]; do
      found="$(find "$WINEPREFIX/drive_c" -name terminal64.exe 2>/dev/null | head -n 1 || true)"
      if [ -n "$found" ]; then break; fi
      if pgrep -f mt5setup.exe >/dev/null 2>&1; then
        echo "[provision] installer is still open (${waited}s). Open http://37.27.56.188:6080/vnc.html and click Next."
        quiet=0
      else
        quiet=$((quiet + 15))
        echo "[provision] installer process is gone (${waited}s)."
        if [ "$quiet" -ge 60 ]; then break; fi
      fi
      sleep 15
      waited=$((waited + 15))
    done
    if [ -n "$found" ] && [ ! -f "$MT5DIR/terminal64.exe" ]; then
      mkdir -p "$(dirname "$MT5DIR")"
      ln -sfn "$(dirname "$found")" "$MT5DIR"
    fi
    [ -f "$MT5DIR/terminal64.exe" ] || { echo "[provision] MT5 did not install. Log:"; tail -n 40 "$WINEPREFIX/cache/mt5setup.log"; exit 1; }
    waited=0
    while pgrep -f mt5setup.exe >/dev/null && [ "$waited" -lt 300 ]; do sleep 5; waited=$((waited + 5)); done
    sleep 20
    wineserver -k || true
    sleep 3
  fi

  echo "[provision] 4/4 done"
  touch "$WINEPREFIX/.provisioned-v1"
}

case "${1:-}" in
  provision) provision ;;

  xvfb)
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
    exec Xvfb :99 -screen 0 1024x768x16 -nolisten tcp -ac ;;

  wm)
    sleep 2
    exec openbox ;;

  vnc)
    if [ "${ENABLE_VNC:-1}" != "1" ]; then exec sleep infinity; fi
    sleep 3
    if [ -n "${VNC_PASSWORD:-}" ]; then
      x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass >/dev/null 2>&1
      exec x11vnc -display :99 -forever -shared -rfbport 5900 -rfbauth /tmp/vncpass -noxdamage
    fi
    exec x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -noxdamage ;;

  novnc)
    if [ "${ENABLE_VNC:-1}" != "1" ]; then exec sleep infinity; fi
    sleep 4
    exec websockify --web=/usr/share/novnc 6080 127.0.0.1:5900 ;;

  mt5)
    sleep 5
    CFG="$WINEPREFIX/drive_c/mt5start.ini"
    {
      echo "[Common]"
      if [ -n "${MT5_LOGIN:-}" ] && [ -n "${MT5_PASSWORD:-}" ] && [ -n "${MT5_SERVER:-}" ]; then
        echo "Login=$MT5_LOGIN"
        echo "Password=$MT5_PASSWORD"
        echo "Server=$MT5_SERVER"
      fi
      echo "NewsEnable=0"
      echo
      echo "[Experts]"
      echo "AllowLiveTrading=1"
      echo "AllowDllImport=0"
      echo "Enabled=1"
    } > "$CFG"
    ( sleep 90; rm -f "$CFG" ) >/dev/null 2>&1 &
    exec wine "$MT5_EXE" '/config:C:\mt5start.ini' ;;

  bridge)
    for _ in $(seq 1 90); do pgrep -f terminal64.exe >/dev/null && break; sleep 2; done
    sleep 10
    exec wine "$PYW" -u 'Z:\opt\mt5\mt5_bridge.py' ;;

  watchdog)
    touch "$HB"
    sleep 240
    stage=0
    while sleep 30; do
      now=$(date +%s); hb=$(stat -c %Y "$HB" 2>/dev/null || echo 0); age=$((now - hb))
      if [ "$age" -lt 90 ]; then stage=0; continue; fi
      if   [ "$age" -ge 1800 ] && [ "$stage" -lt 3 ]; then
        stage=3; echo "[watchdog] no heartbeat for ${age}s -> restarting the container"; kill -TERM 1
      elif [ "$age" -ge 900 ]  && [ "$stage" -lt 2 ]; then
        stage=2; echo "[watchdog] no heartbeat for ${age}s -> restarting MT5 + bridge"; supervisorctl restart mt5 bridge
      elif [ "$age" -ge 300 ]  && [ "$stage" -lt 1 ]; then
        stage=1; echo "[watchdog] no heartbeat for ${age}s -> restarting bridge"; supervisorctl restart bridge
      fi
    done ;;

  health)
    if [ ! -f "${WINEPREFIX:-/wine}/.provisioned-v1" ]; then exit 0; fi
    hb=$(stat -c %Y "$HB" 2>/dev/null) || exit 1
    [ $(( $(date +%s) - hb )) -lt 180 ] || exit 1
    pgrep -f terminal64.exe >/dev/null || exit 1
    exit 0 ;;

  check)
    exec wine "$PYW" 'Z:\opt\mt5\check_mt5.py' ;;

  *) echo "usage: $0 {provision|xvfb|wm|vnc|novnc|mt5|bridge|watchdog|health|check}"; exit 2 ;;
esac
END_SVC_SH
sudo tee /opt/mt5-bridge/supervisord.conf >/dev/null << 'END_SUPERVISORD_CONF'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
pidfile=/tmp/supervisord.pid

[unix_http_server]
file=/tmp/supervisor.sock

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface

[program:xvfb]
command=/opt/mt5/svc.sh xvfb
priority=10
autostart=true
autorestart=true
startsecs=2
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:wm]
command=/opt/mt5/svc.sh wm
priority=15
autostart=true
autorestart=true
startsecs=0
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:vnc]
command=/opt/mt5/svc.sh vnc
priority=16
autostart=true
autorestart=true
startsecs=0
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:novnc]
command=/opt/mt5/svc.sh novnc
priority=17
autostart=true
autorestart=true
startsecs=0
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:mt5]
command=/opt/mt5/svc.sh mt5
priority=20
autostart=true
autorestart=true
startsecs=5
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=40
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:bridge]
command=/opt/mt5/svc.sh bridge
priority=30
autostart=true
autorestart=true
startsecs=5
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=15
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true

[program:watchdog]
command=/opt/mt5/svc.sh watchdog
priority=40
autostart=true
autorestart=true
startsecs=0
startretries=999
stopasgroup=true
killasgroup=true
stopwaitsecs=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
redirect_stderr=true
END_SUPERVISORD_CONF
sudo tee /opt/mt5-bridge/mt5_bridge.py >/dev/null << 'END_MT5_BRIDGE_PY'
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
END_MT5_BRIDGE_PY
sudo tee /opt/mt5-bridge/check_mt5.py >/dev/null << 'END_CHECK_MT5_PY'
"""Run inside the container:  docker exec -it mt5-bridge /opt/mt5/svc.sh check"""
import os
import MetaTrader5 as mt5

path = os.environ.get("MT5_EXE_PATH", r"C:\Program Files\MetaTrader 5\terminal64.exe")
if not mt5.initialize(path=path):
    print("initialize() FAILED:", mt5.last_error())
    raise SystemExit(1)

terminal = mt5.terminal_info()
account = mt5.account_info()
print("MT5 build                      :", terminal.build)
print("Terminal connected to broker   :", terminal.connected)
print("Algo trading allowed (terminal):", terminal.trade_allowed)
if account is None:
    print("Account                        : NONE - set MT5_LOGIN, MT5_PASSWORD and MT5_SERVER in Portainer")
else:
    print("Account                        :", account.login, "|", account.server, "|", account.balance, account.currency, "| leverage 1:%s" % account.leverage)
    print("Trading allowed (account)      :", account.trade_allowed)
names = [s.name for s in (mt5.symbols_get() or [])]
for base in ("XAUUSD", "EURUSD", "GBPUSD"):
    hits = [n for n in names if n.upper().startswith(base)]
    if not hits and base == "XAUUSD":
        hits = [n for n in names if n.upper().startswith("GOLD")]
    print(f"Symbol {base:7s}                 :", hits[:3] or "NOT FOUND (set SYMBOL_SUFFIX on the backend or add it in Market Watch)")
mt5.shutdown()
END_CHECK_MT5_PY
sudo chmod +x /opt/mt5-bridge/entrypoint.sh /opt/mt5-bridge/svc.sh
sudo docker build -t mt5-bridge:latest /opt/mt5-bridge
echo "IMAGE READY"
