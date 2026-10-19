"""Builds chart payloads (candles + indicators + drawn analysis objects) for the Flutter app."""
import math

from . import structure as st
from .config import TF_SECONDS


def _clean(x, nd=5):
    return None if x is None or (isinstance(x, float) and math.isnan(x)) else round(float(x), nd)


def chart_payload(symbol, tf, bars, md, broker, scan_data):
    fr = md.frame(symbol, tf)
    frames = md.frames(symbol)
    info = broker.symbol_info(symbol)
    nd = info["digits"]
    df, raw = fr.df, fr.raw
    k = min(bars, len(df))
    tail = df.iloc[-k:]
    off = len(df) - k                                  # index offset of the visible window
    candles = [[int(r.time), _clean(r.open, nd), _clean(r.high, nd), _clean(r.low, nd), _clean(r.close, nd), int(r.volume)]
               for r in raw.iloc[-(k + 1):].itertuples()]
    ind = {name: [_clean(v, nd) for v in tail[col].tolist()] + [None] for name, col in
           (("ema20", "ema20"), ("ema50", "ema50"), ("ema200", "ema200"), ("bbUp", "bb_up"), ("bbLo", "bb_lo"), ("vwap", "vwap"))}
    ind["rsi"] = [_clean(v, 1) for v in tail["rsi"].tolist()] + [None]
    atr_v = fr.atr
    tick = broker.tick(symbol)
    price = (tick["ask"] + tick["bid"]) / 2
    zones = st.sr_zones(frames, price, frames["H1"].atr)
    t_at = lambda i: int(df["time"].iloc[min(max(i, 0), len(df) - 1)])
    tls = []
    for tl in st.trendlines(df, fr.highs, fr.lows, atr_v):
        tls.append({"kind": tl["kind"], "t1": t_at(tl["i1"]), "p1": _clean(tl["p1"], nd), "t2": int(df["time"].iloc[-1]),
                    "p2": _clean(tl["price_now"], nd), "touches": tl["touches"]})
    obs = [{"type": o["type"], "t": t_at(o["idx"]), "low": _clean(o["low"], nd), "high": _clean(o["high"], nd)}
           for o in (st.order_blocks(df) if tf != "D1" else [])]
    fvgs = [{"type": g["type"], "t": t_at(g["idx"]), "low": _clean(g["low"], nd), "high": _clean(g["high"], nd)}
            for g in st.fair_value_gaps(df)]
    swings = [{"t": t_at(i), "p": _clean(p, nd), "kind": "high"} for i, p in fr.highs if i >= off] + \
             [{"t": t_at(i), "p": _clean(p, nd), "kind": "low"} for i, p in fr.lows if i >= off]
    bo = st.breakout_state(frames["M5"].df, zones, frames["M5"].atr)
    markers = []
    if bo["false_breakout"]:
        markers.append({"label": "False breakout " + ("↑" if bo["false_breakout"]["direction"] == 1 else "↓"), "t": int(candles[-1][0]), "p": candles[-1][4]})
    if bo["retest"]:
        markers.append({"label": "Breakout retest", "t": int(candles[-1][0]), "p": candles[-1][4]})
    plan, rank = None, None
    if scan_data:
        rank = next((r for r in scan_data["rankings"] if r["symbol"] == symbol), None)
        if rank:
            plan = {"side": rank["side"], "entry": rank["plan"]["entry"], "sl": rank["plan"]["sl"], "tp": rank["plan"]["tp"],
                    "rr": rank["rr"], "score": rank["score"], "tradable": rank["tradable"]}
    positions = [{"side": p["side"], "entry": p["price_open"], "sl": p["sl"], "tp": p["tp"], "profit": p["profit"], "ticket": p["ticket"]}
                 for p in broker.positions() if p["symbol"] == symbol]
    return {"symbol": symbol, "tf": tf, "tfSeconds": TF_SECONDS[tf], "digits": nd, "candles": candles, "indicators": ind,
            "zones": [{"low": _clean(z["low"], nd), "high": _clean(z["high"], nd), "kind": z["kind"], "strength": z["strength"],
                       "touches": z["touches"], "tfs": z["tfs"]} for z in zones],
            "trendlines": tls, "orderBlocks": obs, "fvgs": fvgs, "swings": swings, "markers": markers,
            "structure": {"label": fr.struct["label"], "bos": fr.struct["bos"], "choch": fr.struct["choch"]},
            "plan": plan, "positions": positions, "bid": tick["bid"], "ask": tick["ask"]}
