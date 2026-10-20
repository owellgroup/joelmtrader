#!/bin/bash
# Official MetaTrader installer from mt5.md, for a root SSH login with no password.
# The screen is http://37.27.56.188:6080/vnc.html
set -u
export DEBIAN_FRONTEND=noninteractive
export DISPLAY=:99

echo "Stopping the old mt5-bridge container so it cannot restart the broken installer."
docker service rm mt5-bridge_mt5 >/dev/null 2>&1 || true
docker rm -f $(docker ps -aq --filter ancestor=mt5-bridge:latest) >/dev/null 2>&1 || true
sleep 2

apt-get update
apt-get install -y sudo wget ca-certificates xvfb x11vnc novnc websockify

if ! id mt5 >/dev/null 2>&1; then
  useradd -m -s /bin/bash mt5
fi
echo 'mt5 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/mt5
chmod 440 /etc/sudoers.d/mt5

unset XAUTHORITY
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
pkill -x Xvfb || true
pkill -x x11vnc || true
pkill -x websockify || true
sleep 1
Xvfb :99 -screen 0 1280x800x24 -ac -nolisten tcp >/var/log/mt5-xvfb.log 2>&1 &
sleep 2
x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -noxdamage -bg -o /var/log/mt5-x11vnc.log
sleep 1
if ! grep -q "PORT=5900" /var/log/mt5-x11vnc.log; then
  echo "VNC failed. x11vnc log:"
  cat /var/log/mt5-x11vnc.log
  exit 1
fi
websockify --web=/usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 >/var/log/mt5-novnc.log 2>&1 &
sleep 1
echo "Screen is ready: http://37.27.56.188:6080/vnc.html"
echo "Click Connect. Leave Encrypt off. No password."
echo "The official MetaTrader installer will open there. Click Next through it."
echo

su - mt5 -c 'cd "$HOME" && wget -O mt5linux.sh https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh && chmod +x mt5linux.sh && export DISPLAY=:99 && unset XAUTHORITY && export WINEDEBUG=-all && ./mt5linux.sh'

echo
echo "Official installer finished."
find /home/mt5 -name terminal64.exe -print
echo "If terminal64.exe is listed above, MetaTrader is installed."
echo "Leave this server as it is and tell me that line. The Flutter connection is the next step."
