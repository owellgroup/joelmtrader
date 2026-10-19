# How the live backend connects to MT5

The Flutter app does not talk to MetaTrader 5. The Python engine does not click the MT5 window. Each piece talks only to the next piece.

```
Your phone or PC                         Your server (Docker)
─────────────────                        ─────────────────────────────────────────
Flutter app                              Java API          Python engine         MT5 desktop
(login + dashboard)                      port 8080         port 8000             port 3000 (screen)
                                         │                 │                     port 8001 (private)
     HTTP JSON  ─────────────────────────►                 │                     │
     "start the bot"                      │  HTTP JSON     │                     │
     "here is my MT5 login"               ├───────────────►│                     │
                                          │                │  official MT5 API   │
                                          │                ├────────────────────►│  broker servers
                                          │                │  (rpyc / mt5linux)  │
                                          │  events        │                     │
                                          ◄────────────────┤  trade opened       │
                                     PostgreSQL            │                     │
                                     Resend e-mail         │                     │
```

## What each part is

| Part | Where it runs | What it does |
|---|---|---|
| Flutter app | Your phone, Windows, or `http://SERVER/` | Sign-in screen and dashboard. Sends your MT5 account number, server, and trading password to the Java API. |
| Java API | Docker service `api`, port **8080** | Checks the login, stores the MT5 password encrypted, tells the Python engine what to do. |
| Python engine | Docker service `engine`, port **8000** (not public) | Scans XAUUSD, EURUSD, GBPUSD and sends orders. |
| MT5 desktop | Docker service `mt5` | The real MetaTrader 5 terminal. This is the only program that talks to your broker. |
| PostgreSQL | `84.8.131.140:5432` database `forex` | Trades, admins, the saved MT5 login. Already set in `application.properties`. |

The Java API reads the database and mail settings from `backend/api/src/main/resources/application.properties`. Those values come from `backend/.env.example` (Postgres on `84.8.131.140`, Resend SMTP). A `.env` file next to `docker-compose.yml` can still override them.

## Deploy everything, including Python

From the server:

```bash
cd backend
cp .env.example .env
# set MT5_VNC_PASSWORD and the JWT / encryption keys before going live
docker compose up -d --build
```

That one command builds and starts four containers:

1. `forexbot-api` — Java
2. `forexbot-engine` — Python (FastAPI). The engine image installs Python and `mt5linux`.
3. `forexbot-web` — the Flutter app, already pointed at `http://84.8.131.140:8080`
4. `forexbot-mt5` — the MT5 desktop

Check:

- API health: `http://84.8.131.140:8080/actuator/health`
- Flutter site: `http://84.8.131.140/` (port 80)
- MT5 screen: `http://84.8.131.140:3000`

The Windows or Android app uses the same API. The default server URL in the app is `http://84.8.131.140:8080`. It is shown on the sign-in screen under **Live backend URL**. Change it there if you put a domain in front of the API, then rebuild the web image if you also serve the site from Docker (`PUBLIC_API_URL` in `.env`).

## One-time MT5 desktop setup

The MT5 window has to exist before the bot can trade. Docker already downloads and runs it. You still log the terminal into your broker once.

1. Open `http://YOUR_SERVER:3000`.
2. Sign in to the VNC screen with `MT5_VNC_USER` / `MT5_VNC_PASSWORD` from `.env` (default user `admin`).
3. In the MetaTrader 5 window: **File → Login to Trade Account**. Use a **demo** account first.
4. **Tools → Options → Expert Advisors** → tick **Allow algorithmic trading**.
5. Click **Algo Trading** on the toolbar until it is green.
6. In Market Watch, confirm `XAUUSD` (some brokers call it `GOLD`), `EURUSD`, and `GBPUSD` are listed. If the names look like `EURUSDm`, set `SYMBOL_SUFFIX=m` in `.env` and restart the engine container.
7. Leave the terminal running. You can close the browser. Do not stop the `forexbot-mt5` container.

After that, close port 3000 in the firewall if you do not want the desktop screen on the internet. The Python engine still reaches MT5 on the private Docker address `mt5:8001`.

## Example: link the account from the Flutter app

The app login and the MT5 login are two different passwords.

1. Open the Flutter app (or `http://84.8.131.140/`).
2. **Live backend URL** is already `http://84.8.131.140:8080`.
3. Sign in with the admin created by the API (`ADMIN_USERNAME` / `ADMIN_PASSWORD` in `.env`).
4. On the dashboard, the card **Log in to your MT5 account** is shown until the terminal is connected. Example:

   | Field | Example |
   |---|---|
   | MT5 login | `12345678` |
   | Broker server | `Exness-MT5Trial` |
   | Trading password | the password from the broker, not the investor (read-only) password |

5. Press **Connect MT5**.

What happens, in order:

```
Flutter  PUT http://84.8.131.140:8080/api/settings/mt5
         { "login": "12345678", "server": "Exness-MT5Trial", "password": "..." }
            │
Java API    stores login + server in PostgreSQL
            stores the password encrypted
            POST http://engine:8000/mt5/connect
            { "login": "12345678", "server": "Exness-MT5Trial", "password": "..." }
            │
Python      calls the MT5 library:
            initialize(login=12345678, password="...", server="Exness-MT5Trial")
            │
MT5 desktop logs that account in and starts receiving prices
            │
Python      returns { "connected": true, "login": 12345678, "server": "Exness-MT5Trial" }
Java        returns that to Flutter
Flutter     the card disappears and the dashboard shows CONNECTED
```

The same form is on **Settings → Broker account** if you need to change it later. The API retries the saved login about once a minute if the terminal drops.

## Example: Trade Now

Press **Trade Now** on the dashboard.

```
Flutter  POST /api/bot/start
Java     GET  http://engine:8000/mt5/status     must be connected
Java     GET  http://engine:8000/account        reads balance from MT5
Java     POST http://engine:8000/bot/start
Python   every few seconds, for XAUUSD, EURUSD, GBPUSD:
           copy_rates  ← candles from the MT5 terminal
           order_send  → market order, only if the score and risk rules pass
MT5      sends the order to the broker
Python   POST http://api:8080/internal/events   "trade opened"
Java     writes the trade into PostgreSQL
Flutter  GET /api/dashboard every 3 seconds and shows the new trade
```

**Stop trade** is `POST /api/bot/stop`. The API asks the engine to stop the loop. If you leave “close open positions” ticked, the engine sends close orders through the same MT5 terminal.

## Why the Python container cannot see a Windows MT5 you installed by hand

The official `MetaTrader5` Python package only works in a Windows process sitting next to `terminal64.exe`. The engine container is Linux. It uses `mt5linux` instead, which is a remote control for the MT5 desktop container on this same Docker network.

So the MT5 you trade with is the one at `http://SERVER:3000`, not a separate MetaTrader window on your laptop. Installing MT5 on your laptop does not connect it to this server.

If you later want the Windows desktop app on a Windows VPS instead of the container:

1. Install MT5 and Python on that Windows machine.
2. Run `backend/scripts/run-engine-windows.bat` there (same `ENGINE_API_KEY` and `INTERNAL_API_KEY`).
3. In the server `.env` set `ENGINE_URL_OVERRIDE=http://WINDOWS_VPS_IP:8000` and do not rely on the `engine` container.

The Flutter app does not change. It still only calls the Java API.

## Ports to keep private

| Port | Who should reach it |
|---|---|
| 80 | You, in a browser (Flutter web) |
| 8080 | You, from the Flutter app. Put HTTPS in front of it when you can. |
| 3000 | You, once, to set up MT5. Then close it. |
| 8000 | Nobody on the internet. Java reaches the engine as `http://engine:8000`. |
| 8001 | Nobody on the internet. Python reaches MT5 as `mt5:8001`. |
| 5432 | Only the API server. |
