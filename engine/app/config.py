"""Central configuration: environment settings + live-editable risk configuration."""
import json
import os
import threading
from dataclasses import dataclass, field, asdict, fields

SYMBOLS = ["XAUUSD", "EURUSD", "GBPUSD"]
TIMEFRAMES = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
TF_SECONDS = {"M1": 60, "M5": 300, "M15": 900, "M30": 1800, "H1": 3600, "H4": 14400, "D1": 86400}

DATA_DIR = os.getenv("DATA_DIR", "./data")
os.makedirs(DATA_DIR, exist_ok=True)


def env(name, default=None):
    v = os.getenv(name)
    return v if v not in (None, "") else default


class Settings:
    broker_mode = env("BROKER_MODE", "paper").lower()          # paper | mt5
    api_key = env("ENGINE_API_KEY", "change-me-engine-key")
    events_url = env("JAVA_EVENTS_URL", "http://localhost:8080/internal/events")
    internal_key = env("INTERNAL_API_KEY", "change-me-internal-key")
    mt5_login = env("MT5_LOGIN")
    mt5_password = env("MT5_PASSWORD")
    mt5_server = env("MT5_SERVER")
    mt5_path = env("MT5_PATH")                                  # Windows: path to terminal64.exe (optional)
    mt5_rpyc_host = env("MT5_RPYC_HOST", "mt5")                 # Linux/Docker: host of the Wine MT5 container
    mt5_rpyc_port = int(env("MT5_RPYC_PORT", "8001"))
    symbol_suffix = env("SYMBOL_SUFFIX", "")                    # e.g. "m" for EURUSDm
    magic = int(env("MAGIC_NUMBER", "26101801"))
    paper_balance = float(env("PAPER_BALANCE", "12"))
    paper_speed = float(env("PAPER_SPEED", "1"))
    paper_commission_per_lot = float(env("PAPER_COMMISSION_PER_LOT", "6"))
    loop_seconds = float(env("LOOP_SECONDS", "2"))
    scan_seconds_running = float(env("SCAN_SECONDS", "5"))
    scan_seconds_idle = float(env("SCAN_SECONDS_IDLE", "20"))


@dataclass
class RiskConfig:
    risk_per_trade_pct: float = 2.0         # % of equity risked per trade
    micro_max_risk_pct: float = 7.0         # hard cap when the broker's minimum lot forces more risk
    max_total_open_risk_pct: float = 8.0    # sum of risk of all open trades
    max_positions: int = 3
    max_same_usd_direction: int = 2         # correlation guard (EURUSD/GBPUSD/XAUUSD all share USD)
    daily_loss_limit_pct: float = 8.0       # halts trading until next UTC day
    max_drawdown_pct: float = 25.0          # from session peak equity -> kill switch
    max_consecutive_losses: int = 3
    cooldown_minutes: int = 15
    symbol_cooldown_minutes: int = 5
    min_score: float = 62.0                 # minimum opportunity score (0-100)
    min_rr: float = 1.5                     # minimum net reward:risk
    max_spread_to_sl: float = 0.25          # spread must be <= 25% of the stop distance
    news_before_min: int = 30
    news_after_min: int = 15
    break_even_r: float = 0.8
    trail_start_r: float = 1.2
    max_trade_minutes: int = 45
    trade_start_utc: int = 6
    trade_end_utc: int = 20
    close_before_news: bool = True
    min_entry_gap_seconds: int = 20
    allowed_symbols: list = field(default_factory=lambda: list(SYMBOLS))


class ConfigStore:
    path = os.path.join(DATA_DIR, "risk_config.json")

    def __init__(self):
        self._lock = threading.Lock()
        self.cfg = RiskConfig()
        try:
            with open(self.path) as f:
                self.update(json.load(f), persist=False)
        except Exception:
            pass

    def update(self, data: dict, persist=True):
        with self._lock:
            kinds = {f.name: f.type for f in fields(RiskConfig)}
            for k, v in (data or {}).items():
                if k not in kinds:
                    continue
                cur = getattr(self.cfg, k)
                try:
                    if isinstance(cur, bool):
                        v = bool(v)
                    elif isinstance(cur, int):
                        v = int(float(v))
                    elif isinstance(cur, float):
                        v = float(v)
                    elif isinstance(cur, list):
                        v = [s for s in v if s in SYMBOLS]
                except Exception:
                    continue
                setattr(self.cfg, k, v)
            if persist:
                try:
                    with open(self.path, "w") as f:
                        json.dump(asdict(self.cfg), f, indent=2)
                except Exception:
                    pass
        return asdict(self.cfg)

    def as_dict(self):
        return asdict(self.cfg)


config_store = ConfigStore()
