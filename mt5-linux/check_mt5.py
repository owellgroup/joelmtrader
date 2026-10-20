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
