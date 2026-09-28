"""Entry rules. Every rule reads only columns computed at the signal bar's close.

Group H* = research hypotheses modelled on the setups observed in the XAUUSD log
(RSI / PVT / EMA / ENG). They are NOT the original EA logic (no source or trade log
available yet); thresholds are searched on the development set only.
Group 1-4 = independent BTC hypotheses (trend, momentum, reversal, volatility breakout).
"""
import itertools

import numpy as np
import pandas as pd


def _dir(buy, sell):
    d = np.where(buy.fillna(False), 1, 0) - np.where(sell.fillna(False), 1, 0)
    return pd.Series(d, index=buy.index)


def h_rsi_rev(f, rsi_th, ext):
    sell = (f.rsi >= rsi_th) & (f.close > f.ema20 + ext * f.atr)
    buy = (f.rsi <= 100 - rsi_th) & (f.close < f.ema20 - ext * f.atr)
    return _dir(buy, sell)


def h_pvt_rev(f, rsi_th, dist, confirm):
    buy = (f.low < f.ll20) & (f.rsi <= rsi_th) & (f.close < f.ema50 - dist * f.atr)
    sell = (f.high > f.hh20) & (f.rsi >= 100 - rsi_th) & (f.close > f.ema50 + dist * f.atr)
    if confirm:
        buy &= f.close > f.open
        sell &= f.close < f.open
    return _dir(buy, sell)


def h_ema_pull(f, body, full_stack):
    up = (f.ema50 > f.ema200) & ((f.ema20 > f.ema50) if full_stack else True)
    dn = (f.ema50 < f.ema200) & ((f.ema20 < f.ema50) if full_stack else True)
    touched_up = (f.low <= f.ema20).rolling(3).max().astype(bool)
    touched_dn = (f.high >= f.ema20).rolling(3).max().astype(bool)
    buy = up & touched_up & (f.close > f.ema20) & (f.body >= body * f.atr)
    sell = dn & touched_dn & (f.close < f.ema20) & (-f.body >= body * f.atr)
    return _dir(buy, sell)


def h_eng(f, streak, pos):
    prev_body = f.body.shift(1)
    bear_eng = (prev_body > 0) & (f.body < 0) & (f.open >= f.close.shift(1)) & (f.close <= f.open.shift(1))
    bull_eng = (prev_body < 0) & (f.body > 0) & (f.open <= f.close.shift(1)) & (f.close >= f.open.shift(1))
    sell = bear_eng & (f.streak.shift(1) >= streak) & (f.pos_day.shift(1) >= pos)
    buy = bull_eng & (f.streak.shift(1) <= -streak) & (f.pos_day.shift(1) <= 1 - pos)
    return _dir(buy, sell)


def g1_trend_bo(f, adx_min):
    buy = (f.close > f.hh55) & (f.ema50 > f.ema200) & (f.adx >= adx_min)
    sell = (f.close < f.ll55) & (f.ema50 < f.ema200) & (f.adx >= adx_min)
    return _dir(buy, sell)


def g2_momentum(f, rng_atr, trend_filter):
    disp = (f.rng >= rng_atr * f.atr) & (f.body.abs() >= 0.6 * f.rng)
    buy = disp & (f.body > 0) & (f.close > f.hh20)
    sell = disp & (f.body < 0) & (f.close < f.ll20)
    if trend_filter:
        buy &= f.ema50 > f.ema200
        sell &= f.ema50 < f.ema200
    return _dir(buy, sell)


def g3_sweep_rev(f, wick, adx_max):
    upw = f.high - f[["open", "close"]].max(axis=1)
    loww = f[["open", "close"]].min(axis=1) - f.low
    sell = (f.high > f.hh20) & (f.close < f.hh20) & (upw >= wick * f.rng) & (f.adx <= adx_max)
    buy = (f.low < f.ll20) & (f.close > f.ll20) & (loww >= wick * f.rng) & (f.adx <= adx_max)
    return _dir(buy, sell)


def g4_squeeze_bo(f, q):
    sq = f.bbw_pct.shift(1) <= q
    buy = sq & (f.close > f.bb_up)
    sell = sq & (f.close < f.bb_lo)
    return _dir(buy, sell)


STRATEGIES = {
    "H_RSI": (h_rsi_rev, {"rsi_th": [70, 75, 80], "ext": [1.5, 2.5]}),
    "H_PVT": (h_pvt_rev, {"rsi_th": [25, 30], "dist": [2.0, 3.0], "confirm": [0, 1]}),
    "H_EMA": (h_ema_pull, {"body": [0.3, 0.5], "full_stack": [0, 1]}),
    "H_ENG": (h_eng, {"streak": [2, 3], "pos": [0.7, 0.85]}),
    "G1_TREND": (g1_trend_bo, {"adx_min": [0, 20, 25]}),
    "G2_MOM": (g2_momentum, {"rng_atr": [1.5, 2.0], "trend_filter": [0, 1]}),
    "G3_SWEEP": (g3_sweep_rev, {"wick": [0.4, 0.6], "adx_max": [100, 25]}),
    "G4_SQZ": (g4_squeeze_bo, {"q": [0.1, 0.2]}),
}

EXIT_GRID = {"sl_atr": [1.0, 2.0], "rr": [1.0, 2.0, 3.0]}
HOLD_BARS = 48  # max holding time in signal-timeframe bars


def grid(d):
    keys = list(d)
    for vals in itertools.product(*[d[k] for k in keys]):
        yield dict(zip(keys, vals))


def build_signals(f, name, params, sl_atr, rr, tf_minutes, hold_bars=HOLD_BARS):
    fn, _ = STRATEGIES[name]
    d = fn(f, **params)
    # Signals need warm indicators
    d[f.ema200.isna() | f.atr.isna() | f.atr_pct.isna()] = 0
    sig = pd.DataFrame({"dir": d})
    sig["sl"] = sl_atr * f.atr
    sig["tp"] = rr * sig["sl"]
    sig["max_bars"] = hold_bars * tf_minutes
    sig["tag_adx"] = f.adx
    sig["tag_atr_pct"] = f.atr_pct
    sig["tag_er"] = f.er20
    return sig
