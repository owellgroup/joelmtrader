"""Technical indicators (pure pandas / numpy, no TA-lib dependency)."""
import numpy as np
import pandas as pd


def ema(s: pd.Series, n: int) -> pd.Series:
    return s.ewm(span=n, adjust=False).mean()


def rsi(close: pd.Series, n: int = 14) -> pd.Series:
    d = close.diff()
    up = d.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean()
    dn = (-d.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    rs = up / dn.replace(0, np.nan)
    return (100 - 100 / (1 + rs)).fillna(50)


def true_range(df: pd.DataFrame) -> pd.Series:
    pc = df["close"].shift(1)
    return pd.concat([df["high"] - df["low"], (df["high"] - pc).abs(), (df["low"] - pc).abs()], axis=1).max(axis=1)


def atr(df: pd.DataFrame, n: int = 14) -> pd.Series:
    return true_range(df).ewm(alpha=1 / n, adjust=False).mean()


def adx(df: pd.DataFrame, n: int = 14):
    up = df["high"].diff()
    dn = -df["low"].diff()
    plus = np.where((up > dn) & (up > 0), up, 0.0)
    minus = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr = true_range(df).ewm(alpha=1 / n, adjust=False).mean().replace(0, np.nan)
    pdi = 100 * pd.Series(plus, index=df.index).ewm(alpha=1 / n, adjust=False).mean() / tr
    mdi = 100 * pd.Series(minus, index=df.index).ewm(alpha=1 / n, adjust=False).mean() / tr
    dx = 100 * (pdi - mdi).abs() / (pdi + mdi).replace(0, np.nan)
    return dx.ewm(alpha=1 / n, adjust=False).mean().fillna(0), pdi.fillna(0), mdi.fillna(0)


def macd(close: pd.Series, fast=12, slow=26, sig=9):
    m = ema(close, fast) - ema(close, slow)
    s = ema(m, sig)
    return m, s, m - s


def bollinger(close: pd.Series, n=20, k=2.0):
    mid = close.rolling(n).mean()
    sd = close.rolling(n).std(ddof=0)
    up, lo = mid + k * sd, mid - k * sd
    bw = (up - lo) / mid.replace(0, np.nan)
    return mid, up, lo, bw


def stochastic(df: pd.DataFrame, n=14, d=3):
    ll, hh = df["low"].rolling(n).min(), df["high"].rolling(n).max()
    k = 100 * (df["close"] - ll) / (hh - ll).replace(0, np.nan)
    return k.fillna(50), k.rolling(d).mean().fillna(50)


def session_vwap(df: pd.DataFrame) -> pd.Series:
    """VWAP reset at 00:00 UTC, using tick volume."""
    day = pd.to_datetime(df["time"], unit="s", utc=True).dt.date
    tp = (df["high"] + df["low"] + df["close"]) / 3
    vol = df["volume"].replace(0, 1)
    return (tp * vol).groupby(day).cumsum() / vol.groupby(day).cumsum()


def add_indicators(df: pd.DataFrame, intraday=True) -> pd.DataFrame:
    d = df.copy().reset_index(drop=True)
    c = d["close"]
    d["ema9"], d["ema20"], d["ema50"], d["ema200"] = ema(c, 9), ema(c, 20), ema(c, 50), ema(c, 200)
    d["rsi"] = rsi(c)
    d["macd"], d["macd_sig"], d["macd_hist"] = macd(c)
    d["atr"] = atr(d)
    d["atr_ma"] = d["atr"].rolling(50, min_periods=10).mean()
    d["adx"], d["pdi"], d["mdi"] = adx(d)
    d["bb_mid"], d["bb_up"], d["bb_lo"], d["bb_bw"] = bollinger(c)
    d["stoch_k"], d["stoch_d"] = stochastic(d)
    d["vol_ma"] = d["volume"].rolling(20, min_periods=5).mean()
    d["vwap"] = session_vwap(d) if intraday else c
    return d
