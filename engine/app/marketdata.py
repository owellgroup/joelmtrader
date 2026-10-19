"""Cached multi-timeframe frames with indicators and structure pre-computed."""
import threading
import time

from .config import TIMEFRAMES
from .indicators import add_indicators
from . import structure as st

TTL = {"M1": 3, "M5": 8, "M15": 20, "M30": 45, "H1": 120, "H4": 420, "D1": 1800}
COUNT = {"M1": 300, "M5": 300, "M15": 250, "M30": 200, "H1": 250, "H4": 200, "D1": 150}
FULL_DETAIL = {"M5", "M15", "H1", "M1"}


class Frame:
    def __init__(self, tf, raw, detail=True):
        self.tf = tf
        self.raw = raw                                   # includes the forming bar
        closed = raw.iloc[:-1] if len(raw) > 30 else raw
        self.df = add_indicators(closed, intraday=tf not in ("D1", "H4"))
        n = 3 if tf in ("M1", "M5", "M15") else 2
        self.highs, self.lows = st.swings(self.df, n)
        self.struct = st.market_structure(self.df, self.highs, self.lows)
        self.obs = st.order_blocks(self.df) if (detail and tf in FULL_DETAIL) else []
        self.ts = time.time()

    @property
    def atr(self):
        return float(self.df["atr"].iloc[-1])


class MarketData:
    def __init__(self, broker):
        self.broker = broker
        self.cache = {}
        self.lock = threading.RLock()

    def frame(self, symbol, tf, force=False) -> Frame | None:
        key = (symbol, tf)
        with self.lock:
            f = self.cache.get(key)
            if f and not force and time.time() - f.ts < TTL[tf]:
                return f
        raw = self.broker.rates(symbol, tf, COUNT[tf])
        if raw is None or len(raw) < 40:
            return f
        f = Frame(tf, raw)
        with self.lock:
            self.cache[key] = f
        return f

    def frames(self, symbol):
        out = {}
        for tf in TIMEFRAMES:
            f = self.frame(symbol, tf)
            if f is None:
                return None
            out[tf] = f
        return out
