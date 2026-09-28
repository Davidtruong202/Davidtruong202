"""Round 2 entry rules: EMA family + new methods. Same no-look-ahead rule as round 1:
every signal uses only the bar that just closed (and earlier bars).

E1_CROSS   EMA fast/slow crossover (trend following)
E2_CROSS_H1  E1 + only in the direction of the last closed H1 bar's EMA50/EMA200 and ADX>=20
N1_NYORB   New York opening-range breakout: range = 09:30-10:30 New York time (DST handled),
           first close outside the range between 10:30 and 15:00 NY, one trade per day
N2_PDBO    Previous-day high/low breakout: first close beyond yesterday's UTC high/low,
           optional EMA50/EMA200 trend filter, one trade per side per day
N3_DONCH   Donchian 55 breakout with EMA50/EMA200 trend filter (round-1 G1 entry) - tested
           here with the new trailing-stop exit
Exits: "fixed" = SL k*ATR, TP rr*SL (as round 1); "trail" = initial SL k*ATR, trailing stop
k*ATR, no TP, longer max hold.
"""
import numpy as np
import pandas as pd

from strategies import _dir, grid  # noqa: F401  (grid re-exported for runners)


def _cross_up(a, b):
    return (a > b) & (a.shift(1) <= b.shift(1))


def e1_cross(f, fast, slow, **_):
    ef = f.close.ewm(span=fast, adjust=False).mean()
    es = f.close.ewm(span=slow, adjust=False).mean()
    return _dir(_cross_up(ef, es), _cross_up(es, ef))


def n1_nyorb(f, **_):
    ny = f.index.tz_localize("UTC").tz_convert("America/New_York")
    hm = ny.hour * 60 + ny.minute
    day = pd.Index(ny.date)
    in_rng = (hm >= 9 * 60 + 30) & (hm < 10 * 60 + 30)
    rh = f.high.where(in_rng).groupby(day).transform("max")
    rl = f.low.where(in_rng).groupby(day).transform("min")
    # bar is "after range" if it starts at/after 10:30 NY and before 15:00 NY
    after = (hm >= 10 * 60 + 30) & (hm < 15 * 60)
    buy = after & (f.close > rh)
    sell = after & (f.close < rl)
    d = _dir(buy, sell)
    # one trade per day: keep only the first non-zero signal of each NY day
    first = (d != 0).groupby(day).cumsum()
    d[(first > 1) | (d == 0)] = 0
    return d


def n2_pdbo(f, trend, **_):
    day = f.index.normalize()
    dh = f.high.groupby(day).max()
    dl = f.low.groupby(day).min()
    pdh = pd.Series(dh.shift(1).reindex(day).values, index=f.index)
    pdl = pd.Series(dl.shift(1).reindex(day).values, index=f.index)
    buy = (f.close > pdh) & (f.close.shift(1) <= pdh)
    sell = (f.close < pdl) & (f.close.shift(1) >= pdl)
    if trend:
        buy &= f.ema50 > f.ema200
        sell &= f.ema50 < f.ema200
    d = _dir(buy, sell)
    for side in (1, -1):
        m = d == side
        n = m.groupby(day).cumsum()
        d[m & (n > 1)] = 0
    return d


def n3_donch(f, **_):
    buy = (f.close > f.hh55) & (f.ema50 > f.ema200)
    sell = (f.close < f.ll55) & (f.ema50 < f.ema200)
    return _dir(buy, sell)


STRATEGIES2 = {
    "E1_CROSS": (e1_cross, {"fast": [9, 20, 50], "slow": [21, 50, 200]}),
    "E2_CROSS_H1": (e1_cross, {"fast": [9, 20, 50], "slow": [21, 50, 200]}),
    "N1_NYORB": (n1_nyorb, {"x": [0]}),
    "N2_PDBO": (n2_pdbo, {"trend": [0, 1]}),
    "N3_DONCH": (n3_donch, {"x": [0]}),
}
USES_H1_FILTER = {"E2_CROSS_H1"}

EXITS2 = {
    "fixed": {"sl_atr": [1.0, 2.0], "rr": [1.0, 2.0, 3.0], "trail": [0.0]},
    "trail": {"sl_atr": [2.0, 3.0], "rr": [0.0], "trail": [2.0, 3.0, 4.0]},
}
HOLD = {"fixed": 48, "trail": 192}


def valid_params(name, p):
    return not (name.startswith("E") and p["fast"] >= p["slow"])


def build(f, name, p, ex, mins, hold_bars):
    fn, _ = STRATEGIES2[name]
    d = fn(f, **p)
    d[f.ema200.isna() | f.atr.isna() | f.atr_pct.isna()] = 0
    sig = pd.DataFrame({"dir": d})
    sig["sl"] = ex["sl_atr"] * f.atr
    sig["tp"] = ex["rr"] * sig["sl"] if ex["rr"] > 0 else 1e12
    sig["trail"] = ex["trail"] * f.atr
    sig["max_bars"] = hold_bars * mins
    sig["tag_adx"] = f.adx
    sig["tag_atr_pct"] = f.atr_pct
    sig["tag_er"] = f.er20
    return sig
