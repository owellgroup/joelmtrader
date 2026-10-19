# How the live backend connects to the MT5 desktop

MetaTrader 5 is the Windows program you installed on this PC. It is not a container on the server. The Flutter app never talks to it. The Python engine on the server reaches it through a small bridge that you leave running on this PC.

```
This Windows PC                              Server 145.241.187.174
──────────────────────────                   ────────────────────────────────
MetaTrader 5 desktop                         Java API            Python engine
(the EXE you installed)                      port 8080           port 8000
        ▲                                      ▲                    │
        │ official MT5 API                     │                    │
Bridge (mt5-bridge-windows.bat)                │                    │
TCP port 18812  ◄──────────────────────────────┼────────────────────┘
                                               │  RPyC
Flutter app  ──────────────────────────────────┘
http://145.241.187.174:8088                    HTTP JSON
```

Java, Python, and Flutter stay on `145.241.187.174`. The database stays on `84.8.131.140`, database `forex2`. Nothing in Docker starts MetaTrader. Port **3009** is not an MT5 screen.

## What each part is

| Part | Where it runs | What it does |
|---|---|---|
| Flutter app | `http://145.241.187.174:8088` | Sign-in and dashboard. Sends the MT5 account number, server, and trading password to the Java API. |
| Java API | Docker service `api`, port **8080** | Checks the login, stores the MT5 password encrypted, tells the Python engine what to do. |
| Python engine | Docker service `engine`, port **8000** (not public) | Scans XAUUSD, EURUSD, GBPUSD and sends orders through the bridge. |
| Bridge | This PC, `scripts\mt5-bridge-windows.bat`, port **18812** | Lets the cloud engine call the MT5 window on this PC. |
| MT5 desktop | This PC, the EXE you installed | The only program that talks to the broker. |
| PostgreSQL | `84.8.131.140:5432` database `forex2` | Trades, admins, the saved MT5 login. |

## One-time setup on this PC

1. Open the MetaTrader 5 you installed. **File → Login to Trade Account**. Use a **demo** account first.
2. **Tools → Options → Expert Advisors** → tick **Allow algorithmic trading**.
3. Click **Algo Trading** on the toolbar until it is green.
4. In Market Watch, confirm `XAUUSD`, `EURUSD`, and `GBPUSD` are listed. If the names look like `EURUSDm`, set `SYMBOL_SUFFIX=m` on the server and restart the engine.
5. Double-click `backend\scripts\mt5-bridge-windows.bat`. The first run installs Python packages. Leave that black window open. Leave the MT5 window open. Closing either one stops trading.
6. Find this PC's public IP (search "what is my ip"). It is not `127.0.0.1` and it is not `145.241.187.174`.
7. On the server (Dokploy environment for this project) set:

   ```
   MT5_RPYC_HOST=<that public IP>
   MT5_RPYC_PORT=18812
   ```

   Remove the old values `MT5_RPYC_HOST=mt5` and `MT5_RPYC_PORT=8001` if they are still there. Redeploy so the engine container restarts with the new host.
8. Windows Firewall: allow inbound TCP **18812** from `145.241.187.174` only. If this PC is behind a home router, forward TCP 18812 to this PC. The server opens the connection; you do not open port 18812 on the Oracle server.

The PC must stay on, and both windows must stay open, while the bot trades. If the public IP changes, update `MT5_RPYC_HOST` and restart the engine.

## Link the account from the Flutter app

The app login and the MT5 login are two different passwords.

1. Open `http://145.241.187.174:8088`.
2. Sign in with `joel@wayaspot.com` and the admin password.
3. On the dashboard, fill **Log in to your MT5 account**:

   | Field | Example |
   |---|---|
   | MT5 login | `12345678` |
   | Broker server | `Exness-MT5Trial` |
   | Trading password | the password from the broker, not the investor (read-only) password |

4. Press **Connect MT5**.

What happens, in order:

```
Flutter  PUT http://145.241.187.174:8088/api/settings/mt5
         { "login": "12345678", "server": "Exness-MT5Trial", "password": "..." }
            │
Java API    stores login + server in PostgreSQL
            stores the password encrypted
            POST http://engine:8000/mt5/connect
            │
Python      calls the bridge on this PC (port 18812):
            initialize(login=12345678, password="...", server="Exness-MT5Trial")
            │
MT5 desktop on this PC logs that account in
            │
Python      returns { "connected": true }
Flutter     the card disappears and the dashboard shows CONNECTED
```

The same form is on **Settings → Broker account**. The API retries the saved login about once a minute if the terminal drops.

## Trade Now

Press **Trade Now** on the dashboard.

```
Flutter  POST /api/bot/start
Java     checks the engine is connected to MT5 and reads the balance
Java     POST http://engine:8000/bot/start
Python   every few seconds, for XAUUSD, EURUSD, GBPUSD:
           copy_rates  ← candles from the MT5 window on this PC
           order_send  → market order, only if the score and risk rules pass
MT5      sends the order to the broker
Python   POST http://api:8080/internal/events   "trade opened"
Java     writes the trade into PostgreSQL
Flutter  refreshes the dashboard and shows the new trade
```

**Stop trade** is `POST /api/bot/stop`.

## Ports

| Port | Where | Who should reach it |
|---|---|---|
| 8088 | Server | You, in a browser (Flutter) |
| 8080 | Server | You, from the Flutter app |
| 8000 | Server | Nobody on the internet. Java reaches the engine as `http://engine:8000` |
| 18812 | This Windows PC | Only `145.241.187.174` |
| 5432 | `84.8.131.140` | Only the API server |
