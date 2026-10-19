"""End-to-end smoke test in PAPER mode (no MT5, no Java needed). Run:  python -m tests.smoke_test"""
import json, os, sys, threading, time
from http.server import BaseHTTPRequestHandler, HTTPServer

os.environ.update(BROKER_MODE="paper", PAPER_SPEED=os.getenv("PAPER_SPEED", "120"), DATA_DIR="/tmp/fbdata",
                  JAVA_EVENTS_URL="http://127.0.0.1:18080/internal/events", ENGINE_API_KEY="k", INTERNAL_API_KEY="i")
events = []

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); events.append(json.loads(self.rfile.read(n)))
        self.send_response(200); self.end_headers()
    def log_message(self, *a): pass

threading.Thread(target=HTTPServer(("127.0.0.1", 18080), H).serve_forever, daemon=True).start()
from app import main  # noqa: E402

DURATION = int(os.getenv("DURATION", "75"))
print("broker:", main.broker.name, "balance:", main.broker.account()["balance"])
t0 = time.time(); sc = main.bot.force_scan(); print(f"first scan took {time.time()-t0:.1f}s")
for r in sc["rankings"]:
    print(f"  {r['symbol']:7s} {r['side']:4s} score={r['score']:5.1f} rank={r['rankScore']:5.1f} rr={r['rr']} setup={r['setup']} tradable={r['tradable']} riskMin={r['riskPctAtMinLot']}% | {r['blockedReasons'][:2]}")
print("why:", sc["why"][:200])
ch = main.chart_payload("EURUSD", "M5", 120, main.md, main.broker, sc)
print("chart:", len(ch["candles"]), "candles; zones", len(ch["zones"]), "trendlines", len(ch["trendlines"]), "OB", len(ch["orderBlocks"]), "FVG", len(ch["fvgs"]), "swings", len(ch["swings"]))
for tf in ("D1", "H4", "M1"):
    c = main.chart_payload("XAUUSD", tf, 100, main.md, main.broker, sc); assert len(c["candles"]) > 50
main.config_store.update({"trade_start_utc": 0, "trade_end_utc": 24, "min_score": 45, "min_rr": 1.2}, persist=False)
print(main.bot.start(1)["status"])
time.sleep(DURATION)
st = main.bot.stop(True)
print("stats:", st["stats"], "account:", {k: st["account"][k] for k in ("balance", "equity")})
for a in reversed(st["activity"][:25]): print("  ", a["message"])
print("events:", {t: sum(1 for e in events if e["type"] == t) for t in {e["type"] for e in events}})
print("OK")
