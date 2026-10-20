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
    local waited=0 found=""
    until found="$(find "$WINEPREFIX/drive_c" -name terminal64.exe 2>/dev/null | head -n 1)" && [ -n "$found" ] || [ "$waited" -ge 1200 ]; do
      if pgrep -f mt5setup.exe >/dev/null 2>&1; then
        echo "[provision] installer is still open (${waited}s). Click it on port 6080 if a window is waiting."
      else
        echo "[provision] installer process is gone (${waited}s) and terminal64.exe is not installed yet."
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
      exec x11vnc -display :99 -forever -shared -rfbport 5900 -localhost -rfbauth /tmp/vncpass -noxdamage -quiet
    fi
    exec x11vnc -display :99 -forever -shared -rfbport 5900 -localhost -nopw -noxdamage -quiet ;;

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
