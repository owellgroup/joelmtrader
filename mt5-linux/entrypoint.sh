#!/usr/bin/env bash
# First start installs the Wine prefix, MetaTrader 5 and Windows Python into the /wine volume.
# The installer is shown on port 6080 so a Next button can be clicked.
# Every later start hands control to supervisord, which restarts any process that dies.
set -uo pipefail
mkdir -p "$WINEPREFIX"
export DISPLAY=:99

start_screen() {
  if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
    Xvfb :99 -screen 0 1280x800x16 -nolisten tcp -ac >/tmp/xvfb.log 2>&1 &
    sleep 1
  fi
  if [ "${ENABLE_VNC:-1}" = "1" ] && ! pgrep -f "x11vnc -display :99" >/dev/null 2>&1; then
    if [ -n "${VNC_PASSWORD:-}" ]; then
      x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass >/dev/null 2>&1
      x11vnc -display :99 -forever -shared -rfbport 5900 -rfbauth /tmp/vncpass -noxdamage -bg -o /tmp/x11vnc.log
    else
      x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -noxdamage -bg -o /tmp/x11vnc.log
    fi
  fi
  if [ "${ENABLE_VNC:-1}" = "1" ] && ! pgrep -f "websockify --web=/usr/share/novnc 6080" >/dev/null 2>&1; then
    websockify --web=/usr/share/novnc 6080 127.0.0.1:5900 >/tmp/novnc.log 2>&1 &
  fi
}

if [ ! -f "$WINEPREFIX/.provisioned-v1" ]; then
  echo "[entrypoint] First start: installing MT5 + Python under Wine."
  echo "[entrypoint] Open http://37.27.56.188:6080/vnc.html and click through the MetaTrader installer if it is waiting."
  start_screen
  if ! /opt/mt5/svc.sh provision; then
    echo "[entrypoint] Provisioning FAILED. Waiting 2 minutes, then Docker restarts the container."
    sleep 120
    exit 1
  fi
fi

exec /usr/bin/supervisord -n -c /opt/mt5/supervisord.conf
