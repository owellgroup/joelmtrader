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
