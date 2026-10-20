# Final setup

This is the setup that is running. MetaTrader 5 is installed on the Linux server with MetaQuotes' own installer. A Windows Python program next to that terminal dials out to the Python engine. The Flutter app never talks to MetaTrader. It sends the broker account to the Java API, and the engine sends the trading calls back down the open bridge.

Do not deploy the old `mt5-bridge` Portainer stack again. That container used a different Wine build, exited while the installer was open, and MetaTrader reported a debugger.

## Machines

| Machine | Role |
|---|---|
| `37.27.56.188` | Ubuntu, x86_64, root over SSH. Flutter, Java API, Python engine, and MetaTrader all run here. |
| `84.8.131.140` | Postgres only. Database `forex2`. This machine is ARM. MetaTrader cannot be installed on it. |

| Piece | Where it is | Address |
|---|---|---|
| Flutter app | Docker container `forexbot-web` | http://37.27.56.188:8088 |
| Java API | Docker container `forexbot-api` | port 8080, reached by the app through nginx |
| Python engine | Docker container `forexbot-engine` | port 8000, not published. Nginx forwards `/mt5-bridge` to it |
| Postgres | `84.8.131.140` | database `forex2` |
| MetaTrader 5 | On the host, user `mt5`, under Wine | screen at http://37.27.56.188:6080/vnc.html |
| Python bridge | systemd service `mt5-bridge` | dials `ws://37.27.56.188:8088/mt5-bridge` |

Dokploy and the other sites on this server stay as they are. MetaTrader is not one of those stacks.

## How a connection travels

```text
Browser
  http://37.27.56.188:8088
        │
        ▼
forexbot-web (nginx)
  /api            → forexbot-api:8080
  /mt5-bridge     → forexbot-engine:8000
        │
        ▼
Flutter  Connect MT5
  account number, trading password, broker server
        │
        ▼
Java API
  stores the password encrypted
  asks the engine to connect
        │
        ▼
Python engine
  sends MetaTrader5 calls down the open websocket
        │
        ▲
        │  the bridge dials out. Nothing dials in.
        │
Wine on the host, user mt5
  C:\Python311\python.exe  Z:\home\mt5\mt5_bridge.py
  MetaTrader5 5.0.6231
        │
        ▼
terminal64.exe
  /home/mt5/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe
```

One terminal holds one broker account at a time. Pressing **Connect MT5** in the app switches that account. The account is not typed into Portainer, and it is not typed on the VNC screen.

The bridge sends header `X-Api-Key`. The value is `ENGINE_API_KEY` from the `forexbot-engine` container. `mt5-link.sh` reads it from that container and writes it to `/etc/mt5-bridge.env`. That file is not in this repository.

## What was installed on the host

User `mt5` can use sudo without a password (`/etc/sudoers.d/mt5`). The official installer refuses to run as root and asks for a password through sudo. This user is how a root SSH login runs it with no password prompt.

The screen has no X cookie. `Xvfb` is started with `-ac`, and `x11vnc` is started with no `-auth`. A cookie was what made VNC fail with "failed to connect to server".

| Program | Purpose |
|---|---|
| `xvfb` | Virtual screen `:99` |
| `x11vnc` | VNC on `127.0.0.1:5900`, no password |
| `websockify` and noVNC | Browser page on `0.0.0.0:6080` |
| Wine, from `mt5linux.sh` | Runs the Windows terminal |
| Python 3.11.9 embeddable | Windows Python inside the Wine prefix |
| `MetaTrader5` 5.0.6231, `websockets` 17.3, `numpy` 2.4.6 | The packages the bridge imports |

Wine prefix: `/home/mt5/.mt5`

Installed terminal:

```text
/home/mt5/.mt5/drive_c/Program Files/MetaTrader 5/terminal64.exe
```

Windows path used by the bridge:

```text
C:\Program Files\MetaTrader 5\terminal64.exe
```

Bridge program: `/home/mt5/mt5_bridge.py`

## 1. Install MetaTrader

Script in this repo: `backend/mt5-official.sh`

On the server, as root:

```bash
cat > /root/mt5-official.sh
```

Paste the file, press Enter, then Ctrl+D.

```bash
bash /root/mt5-official.sh
```

The script does four things:

1. Removes the old `mt5-bridge` Docker service so it cannot take port 6080 or restart the broken installer.
2. Installs `xvfb`, `x11vnc`, `novnc`, and `websockify`.
3. Creates user `mt5` and starts the screen.
4. Downloads and runs the official installer as that user:

```bash
wget https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh
chmod +x mt5linux.sh
./mt5linux.sh
```

The screen is http://37.27.56.188:6080/vnc.html. Click **Connect**. Leave Encrypt off. There is no password. Click **Next** through the MetaTrader installer on that screen.

Install is finished when this prints a path:

```bash
find /home/mt5 -name terminal64.exe -print
```

The path on this server is the one in the table above. Leave the MetaTrader window open.

## 2. Install Windows Python and the bridge

Script in this repo: `backend/mt5-link.sh`

```bash
cat > /root/mt5-link.sh
```

Paste the file, press Enter, then Ctrl+D.

```bash
bash /root/mt5-link.sh
```

The script does four things:

1. Reads `ENGINE_API_KEY` from `docker exec forexbot-engine printenv ENGINE_API_KEY`.
2. Unzips Python 3.11.9 into `/home/mt5/.mt5/drive_c/Python311` if it is not already there.
3. Runs `pip` under Wine and installs `MetaTrader5`, `websockets`, and `numpy`.
4. Writes `/home/mt5/mt5_bridge.py`, `/etc/mt5-bridge.env`, and the systemd service, then starts it.

The service file must use forward slashes. systemd treats backslashes as escapes and drops them:

```ini
ExecStart=/usr/bin/wine C:/Python311/python.exe -u Z:/home/mt5/mt5_bridge.py
```

Environment file `/etc/mt5-bridge.env`:

```text
DISPLAY=:99
WINEPREFIX=/home/mt5/.mt5
WINEDEBUG=-all
MT5_BRIDGE_URL=ws://37.27.56.188:8088/mt5-bridge
ENGINE_API_KEY=<same value as the engine container>
MT5_EXE_PATH=C:\Program Files\MetaTrader 5\terminal64.exe
```

The bridge is connected when the log contains this line:

```text
Connected to the engine.
```

```bash
journalctl -u mt5-bridge --no-pager -n 20
```

On this server that line was printed as `wine[15995]: Connected to the engine.` Pip's install text was still scrolling, so the line was easy to miss. The bridge was already connected.

## 3. Connect from the Flutter app

Do not log in on the VNC screen. The app sends the account.

1. Leave the MetaTrader window open.
2. Open http://37.27.56.188:8088 and sign in.
3. Press **Connect MT5**.
4. Type the account number, the trading password, and the broker server. The investor password cannot place trades.
5. The engine calls `initialize` through the bridge. The bridge adds the path to `terminal64.exe` because the engine does not send a Windows path.

The Java API stores the trading password encrypted. Changing `APP_ENCRYPTION_KEY` after this makes the saved password unreadable, and Connect MT5 has to be done again.

In the terminal, **Tools → Options → Expert Advisors**, tick **Allow algorithmic trading**, and turn **Algo Trading** green. If that button stays red, the app can see prices and the broker rejects orders.

## Files

| File | Where |
|---|---|
| `backend/mt5-official.sh` | Installer script. Copy to `/root/mt5-official.sh` |
| `backend/mt5-link.sh` | Python and bridge script. Copy to `/root/mt5-link.sh` |
| `backend/mt5.md` | The official one-line installer this setup is based on |
| `/home/mt5/mt5linux.sh` | The script MetaQuotes' server downloaded |
| `/home/mt5/.mt5` | Wine prefix. Do not delete this |
| `/home/mt5/mt5_bridge.py` | The program systemd runs |
| `/etc/mt5-bridge.env` | Bridge settings, including the API key |
| `/etc/systemd/system/mt5-bridge.service` | Restarts the bridge if it exits |

## Check that it is still up

```bash
systemctl is-active mt5-bridge
journalctl -u mt5-bridge --no-pager -n 15
find /home/mt5 -name terminal64.exe -print
docker ps --format '{{.Names}} {{.Status}}' | grep forexbot
```

`mt5-bridge` should be `active`. The log should still show `Connected to the engine.` `forexbot-web`, `forexbot-api`, and `forexbot-engine` should be running. If `forexbot-api` is unhealthy, Connect MT5 fails even while the bridge is connected.

## After a reboot

The bridge service is enabled, so it comes back. The screen and the MetaTrader window were started by hand, so they do not. Run this as root, then open the VNC page and leave MetaTrader open:

```bash
unset XAUTHORITY
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 1280x800x24 -ac -nolisten tcp >/var/log/mt5-xvfb.log 2>&1 &
sleep 2
x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -noxdamage -bg -o /var/log/mt5-x11vnc.log
websockify --web=/usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 >/var/log/mt5-novnc.log 2>&1 &
su - mt5 -c 'export DISPLAY=:99 WINEPREFIX=$HOME/.mt5 WINEDEBUG=-all; wine "C:\\Program Files\\MetaTrader 5\\terminal64.exe"' &
systemctl restart mt5-bridge
```

Open http://37.27.56.188:6080/vnc.html. Confirm the log says `Connected to the engine.` Then use the Flutter app.

## Do not

- Do not install MetaTrader on `84.8.131.140`.
- Do not start the `mt5-bridge` stack in Portainer.
- Do not run `docker compose down -v` against the bot stack. Postgres data and the other sites are on this machine.
- Do not put `ENGINE_API_KEY`, the database password, or the broker password in this file or in a Portainer stack.
- Do not close the MetaTrader window. Closing it stops trading until it is opened again.
