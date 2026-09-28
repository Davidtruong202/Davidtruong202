"""Check that the EA's signal logic (MQL5/Experts/BTC_MOM_M15_H1.mq5) reproduces the
research signals. This re-implements the EA's per-bar computation (indicators recomputed
on a trailing window of CALC_BARS closed bars, H1 = last closed H1 bar) and compares
its BUY/SELL decisions with run_final.locked_signals() bar by bar.
"""
import sys

import numpy as np
import pandas as pd
from numba import njit

import data
import indicators as ind
from run_final import LOCKED, locked_signals
from run_hypotheses import h1_filter_factory

CALC_BARS = 1500


@njit(cache=True)
def ema_last(c, n):
    a = 2.0 / (n + 1.0)
    e = c[0]
    for i in range(1, len(c)):
        e = a * c[i] + (1 - a) * e
    return e


@njit(cache=True)
def atr_last(h, l, c, n):
    a = 1.0 / n
    v = h[0] - l[0]
    for i in range(1, len(c)):
        pc = c[i - 1]
        tr = max(h[i] - l[i], abs(h[i] - pc), abs(l[i] - pc))
        v = a * tr + (1 - a) * v
    return v


@njit(cache=True)
def adx_last(h, l, c, n):
    a = 1.0 / n
    atr = h[0] - l[0]
    sp = 0.0
    sn = 0.0
    adx = 0.0
    init = False
    for i in range(1, len(c)):
        up = h[i] - h[i - 1]
        dn = l[i - 1] - l[i]
        pdm = up if (up > dn and up > 0) else 0.0
        ndm = dn if (dn > up and dn > 0) else 0.0
        pc = c[i - 1]
        tr = max(h[i] - l[i], abs(h[i] - pc), abs(l[i] - pc))
        atr = a * tr + (1 - a) * atr
        sp = a * pdm + (1 - a) * sp
        sn = a * ndm + (1 - a) * sn
        if atr <= 0:
            continue
        pdi = 100 * sp / atr
        ndi = 100 * sn / atr
        if pdi + ndi <= 0:
            continue
        dx = 100 * abs(pdi - ndi) / (pdi + ndi)
        if not init:
            adx = dx
            init = True
        else:
            adx = a * dx + (1 - a) * adx
    return adx


@njit(cache=True)
def ea_signals(o, h, l, c, h1o_close_idx, H, L, C, calc, disp, bodyf, brk, adxmin):
    n = len(c)
    out = np.zeros(n, np.int64)
    for k in range(calc - 1, n):
        s = k - calc + 1
        oo, hh_, ll_, cc = o[s:k + 1], h[s:k + 1], l[s:k + 1], c[s:k + 1]
        atr = atr_last(hh_, ll_, cc, 14)
        rng = h[k] - l[k]
        body = c[k] - o[k]
        if atr <= 0 or rng < disp * atr or abs(body) < bodyf * rng:
            continue
        hi = -1e18
        lo = 1e18
        for i in range(k - brk, k):
            hi = max(hi, h[i])
            lo = min(lo, l[i])
        d = 0
        if body > 0 and c[k] > hi:
            d = 1
        if body < 0 and c[k] < lo:
            d = -1
        if d == 0:
            continue
        e50 = ema_last(cc, 50)
        e200 = ema_last(cc, 200)
        if (d == 1 and e50 <= e200) or (d == -1 and e50 >= e200):
            continue
        j = h1o_close_idx[k]  # index of the last H1 bar closed at this M15 close
        if j < calc - 1:
            continue
        hs = j - calc + 1
        h50 = ema_last(C[hs:j + 1], 50)
        h200 = ema_last(C[hs:j + 1], 200)
        hadx = adx_last(H[hs:j + 1], L[hs:j + 1], C[hs:j + 1], 14)
        hd = 0
        if hadx >= adxmin:
            hd = 1 if h50 > h200 else (-1 if h50 < h200 else 0)
        if hd != d:
            continue
        out[k] = d
    return out


def main():
    start = pd.Timestamp(sys.argv[1]) if len(sys.argv) > 1 else pd.Timestamp("2025-12-28")
    m1 = data.load_m1()
    m15 = data.resample(m1, "15min")
    h1 = data.resample(m1, "1h")
    # last H1 bar whose close time (open + 1h) <= M15 close time (open + 15m)
    m15_close = (m15.index + pd.Timedelta(minutes=15)).values
    h1_close = (h1.index + pd.Timedelta(hours=1)).values
    idx = np.searchsorted(h1_close, m15_close, side="right") - 1
    p = LOCKED["params"]
    ea = ea_signals(m15.open.values, m15.high.values, m15.low.values, m15.close.values, idx.astype(np.int64),
                    h1.high.values, h1.low.values, h1.close.values, CALC_BARS, p["rng_atr"], 0.6, 20, 20.0)
    ea = pd.Series(ea, index=m15.index)
    _, sig = locked_signals(m1, h1_filter_factory(m1))
    res = sig["dir"].reindex(m15.index).fillna(0).astype(int)
    sel = m15.index >= start
    a, b = ea[sel], res[sel]
    both = ((a != 0) | (b != 0))
    print(f"period from {start.date()}: M15 bars {sel.sum()}, EA signals {int((a != 0).sum())}, "
          f"research signals {int((b != 0).sum())}, identical decisions on {int((a == b)[both].sum())}/{int(both.sum())}")
    diff = pd.DataFrame({"ea": a, "research": b})[(a != b)]
    if len(diff):
        print(diff.head(20))


if __name__ == "__main__":
    main()
