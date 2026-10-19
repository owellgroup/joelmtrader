# Set up the MT5 desktop on this PC

Java, Python, and the Flutter app are already running on the server. This guide is only the remaining piece: the MetaTrader 5 program installed on this Windows PC.

You do not install MT5 on the server. You do not open port 3009. The MT5 window on this PC is the terminal the bot trades through.

## What is already running

| Piece | Address | You do this |
|---|---|---|
| Flutter app | http://145.241.187.174:8088 | Open it in a browser and sign in |
| Java API | http://145.241.187.174:8080 | Nothing. The app talks to it for you |
| Python engine | inside Docker, port 8000, not public | Nothing. The laptop bridge calls it |
| Database | `84.8.131.140`, database `forex2` | Nothing |

Sign in to the app with the same admin account you already use (`joel@wayaspot.com`).

## How a trade reaches the broker

```
This Windows PC                         Server 145.241.187.174
────────────────────────                ─────────────────────────────────
MetaTrader 5 (the EXE)                  Flutter app  :8088
        ▲                                    │
        │ official MT5 library               │  you press Connect MT5
Bridge window                                ▼
        │                               Java API     :8080
        │  dials out to :8088/mt5-bridge     │  stores the password encrypted
        └──────────────────────────────► Python engine
             this PC calls the server        scans XAUUSD, EURUSD, GBPUSD
                                             and sends orders back down that link
```

The Flutter app never talks to MetaTrader. It sends the account number, server name, and trading password to Java. Java sends them to Python. The bridge on this PC keeps a connection open to the server, and Python sends the MT5 calls back down that connection. The home router does not need a port forward. The server cannot dial into a home network, which is why the old timeout happened.

## Information you will need

Collect these before you start. Each one comes from a specific place.

| What | Where you get it | Where you type it |
|---|---|---|
| MT5 account number | Bottom of the MT5 window, left side. It is a number such as `12345678`. The same number is in the broker email that opened the account, and under **Navigator → Accounts**. | Flutter dashboard, field **MT5 login** |
| Broker server name | Bottom of the MT5 window, next to the account number. Also under **File → Login to Trade Account**. Copy it exactly, including capital letters and hyphens. Example: `Exness-MT5Trial`. | Flutter dashboard, field **Broker server** |
| Trading password | The password you chose when the broker created the account. It is the password that can place trades. The **investor** password is read-only and will not work. If you forgot it, reset it in the broker's website, not inside this project. | Flutter dashboard, field **Trading password** |
| Symbol names | MT5 **Market Watch** (Ctrl+M). Look for `XAUUSD`, `EURUSD`, `GBPUSD`. | Only if the names have an extra ending. See the symbol section below. |

## Before the first Connect MT5

The server must be running the version of the project that talks to a Windows PC. If Connect MT5 reports that it is looking for a host named `mt5`, or port `8001`, the server is still on the old container setup.

Push this project and redeploy once in Dokploy. After that redeploy, the running services are only `forexbot-api`, `forexbot-engine`, and `forexbot-web`. There is no MT5 container.

## 1. Prepare the MT5 window

1. Open the MetaTrader 5 you already installed.
2. **File → Login to Trade Account**. Use a **demo** account the first time.
3. After it connects, read the account number and server name from the bottom of the window. Write them down. Those are the two values the Flutter form needs.
4. **Tools → Options → Expert Advisors**. Tick **Allow algorithmic trading**. Press OK.
5. On the toolbar, click **Algo Trading** until the button is green. If this stays red, the bot can see prices but the broker will reject every order. The app then shows `TRADING DISABLED IN TERMINAL`.
6. Press Ctrl+M to open **Market Watch**. Confirm `XAUUSD`, `EURUSD`, and `GBPUSD` are listed. Right-click the list and choose **Show All** if one is missing. Some brokers name gold `GOLD` and add a suffix such as `m` or `.a` (`EURUSDm`). See the symbol section if that is the case.
7. Leave this window open. Minimizing it is fine. Closing it stops the bot.

## 2. Install Python, then start the bridge

The bridge is a small program on this PC. The cloud engine uses it to reach the MT5 window.

1. If `python` is not installed, download Python 3 from https://www.python.org/downloads/windows/ and run the installer. On the first screen, tick **Add python.exe to PATH**.
2. Close any old Command Prompt windows so they see the new Python.
3. In File Explorer, open the project folder and double-click:

   `backend\scripts\mt5-bridge-windows.bat`

4. The first run installs `MetaTrader5`, `websockets`, and `numpy`. Wait until that finishes.
5. The window then prints `Connected to the server. Leave this window open.`
6. Leave the black window open. Closing it disconnects the server from MT5.

The bridge calls `ws://145.241.187.174:8088/mt5-bridge`. Your public IP and port 18812 are not used. A home router port forward is not required.

Push this project and redeploy in Dokploy before starting the bridge. The server must be running the build that accepts `/mt5-bridge`. Redeploy both the engine and the web container.

## 3. Connect the account from the app

1. Open http://145.241.187.174:8088 and sign in.
2. On the dashboard, the card **Log in to your MT5 account** is shown until the terminal is connected.
3. Fill the three fields with the values from the table at the top of this guide.
4. Press **Connect MT5**. Only the super admin can press it.

What you should see:

- A toast **Connected to MT5**.
- The card goes away.
- **Settings → Broker account (MetaTrader 5)** shows a green **CONNECTED** pill, the login, the server name, and a **DEMO** tag.

The same form is on that Settings page, with **Save & connect** and **Reconnect**. Use **Reconnect** after you restart the bridge or the MT5 window. Java also retries the saved login about once a minute.

The trading password is encrypted on the server. It is not shown again. To change it, type a new one and press **Save & connect**. Leaving the password box empty keeps the saved one.

## 4. Start trading

On the dashboard, press **Trade Now**.

The engine reads candles from the MT5 window for `XAUUSD`, `EURUSD`, and `GBPUSD`, and sends an order only when its score and risk rules pass. A new trade shows on the dashboard within a few seconds, and it also appears in the MT5 **Trade** tab on this PC.

**Stop trade** stops the loop. If you leave “close open positions” ticked, the engine closes them through the same MT5 window.

## Symbol names

The engine looks for `XAUUSD`, `EURUSD`, and `GBPUSD`.

| What Market Watch shows | What to set in Dokploy |
|---|---|
| `EURUSD`, `GBPUSD`, `XAUUSD` | Leave `SYMBOL_SUFFIX` empty |
| `EURUSDm`, `GBPUSDm`, `XAUUSDm` | `SYMBOL_SUFFIX=m` |
| `EURUSD.a` | `SYMBOL_SUFFIX=.a` |
| Gold is only listed as `GOLD` | Add `XAUUSD` from the broker's symbol list, or the scan for gold will stay empty |

After changing `SYMBOL_SUFFIX`, restart the engine and press **Reconnect** in Settings.

## What has to stay on

| Thing | If you close it |
|---|---|
| This PC | The server cannot reach MT5 |
| The MetaTrader 5 window | Orders and prices stop |
| The black bridge window | The engine reports that it cannot connect |
| Algo Trading, green | Orders are rejected. Prices still work |
| `forexbot-api`, `forexbot-engine`, `forexbot-web` | The app or the bot stops |

You can close the browser. The bot keeps running on the server as long as the three rows above are still up.

## Check that it worked

1. Bridge window shows `Connected to the server. Leave this window open.`
2. Settings in the app shows **CONNECTED**, the right login, and **DEMO**.
3. The tag `TRADING DISABLED IN TERMINAL` is absent.
4. Press **Trade Now**. The dashboard status becomes running.
5. In MT5, **Toolbox → Trade** shows the same positions the dashboard shows.

## If it does not connect

| Message or symptom | What to do |
|---|---|
| `laptop bridge is not connected` or a timeout to `105.232.129.56:18812` | The server is still on the old build, or the bridge window is closed. Push, redeploy, then start `mt5-bridge-windows.bat` again until it says `Connected to the server` |
| `Not connected` repeating in the bridge window | The new web container is not deployed yet, so port 8088 has no `/mt5-bridge`. Redeploy, then start the bridge again |
| `initialize() failed` with an auth error | The server name does not match the bottom of the MT5 window, or the password is the investor password |
| `Terminal started but no account is logged in` | Open MT5 and log in, then press **Reconnect** |
| `TRADING DISABLED IN TERMINAL` | Turn **Algo Trading** green, and tick **Allow algorithmic trading** |
| Connected, but no gold or forex prices | The Market Watch names do not match. Set `SYMBOL_SUFFIX` |
| `Saved, but MT5 did not connect` | Read the rest of that toast. It is the engine's reason |

A working bridge window stays on the line `Connected to the server`. The real test is **Connect MT5** in the app.
