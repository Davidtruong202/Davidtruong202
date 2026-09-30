"""MT5 built-in indicator formulas (values per closed bar, chronological order).

iMA MODE_EMA : EMA[0]=close[0], then EMA[i]=a*close[i]+(1-a)*EMA[i-1], a=2/(n+1)
iATR         : TR[0]=0, ATR[i<n]=0, ATR[n]=mean(TR[1..n]), then running SMA of TR
iRSI         : Wilder smoothing seeded with the simple mean of the first n diffs
iADX         : +DI/-DI/ADX smoothed with EMA (a=2/(n+1)), all buffers start at 0
A value of 0 means "not calculated yet"; the EA treats atr<=0 as missing data.
"""
import numpy as np
from numba import njit


@njit(cache=True)
def ema(x, n):
    out = np.empty(len(x))
    if len(x) == 0:
        return out
    a = 2.0 / (n + 1.0)
    out[0] = x[0]
    for i in range(1, len(x)):
        out[i] = x[i] * a + out[i - 1] * (1.0 - a)
    return out


@njit(cache=True)
def atr(h, l, c, n):
    m = len(c)
    tr = np.zeros(m)
    out = np.zeros(m)
    for i in range(1, m):
        tr[i] = max(h[i], c[i - 1]) - min(l[i], c[i - 1])
    if m <= n:
        return out
    s = 0.0
    for i in range(1, n + 1):
        s += tr[i]
    out[n] = s / n
    for i in range(n + 1, m):
        out[i] = out[i - 1] + (tr[i] - tr[i - n]) / n
    return out


@njit(cache=True)
def rsi(c, n):
    m = len(c)
    out = np.zeros(m)
    pos = np.zeros(m)
    neg = np.zeros(m)
    if m <= n:
        return out
    sp = 0.0
    sn = 0.0
    for i in range(1, n + 1):
        d = c[i] - c[i - 1]
        if d > 0:
            sp += d
        else:
            sn -= d
    pos[n] = sp / n
    neg[n] = sn / n
    out[n] = 100.0 - 100.0 / (1.0 + pos[n] / neg[n]) if neg[n] != 0.0 else (100.0 if pos[n] != 0.0 else 50.0)
    for i in range(n + 1, m):
        d = c[i] - c[i - 1]
        pos[i] = (pos[i - 1] * (n - 1) + (d if d > 0.0 else 0.0)) / n
        neg[i] = (neg[i - 1] * (n - 1) + (-d if d < 0.0 else 0.0)) / n
        if neg[i] != 0.0:
            out[i] = 100.0 - 100.0 / (1.0 + pos[i] / neg[i])
        else:
            out[i] = 100.0 if pos[i] != 0.0 else 50.0
    return out


@njit(cache=True)
def adx(h, l, c, n):
    m = len(c)
    pdi = np.zeros(m)
    ndi = np.zeros(m)
    out = np.zeros(m)
    a = 2.0 / (n + 1.0)
    for i in range(1, m):
        tp = h[i] - h[i - 1]
        tn = l[i - 1] - l[i]
        if tp < 0.0:
            tp = 0.0
        if tn < 0.0:
            tn = 0.0
        if tp > tn:
            tn = 0.0
        elif tp < tn:
            tp = 0.0
        else:
            tp = 0.0
            tn = 0.0
        tr = max(max(abs(h[i] - l[i]), abs(h[i] - c[i - 1])), abs(l[i] - c[i - 1]))
        pd_ = 100.0 * tp / tr if tr != 0.0 else 0.0
        nd_ = 100.0 * tn / tr if tr != 0.0 else 0.0
        pdi[i] = pd_ * a + pdi[i - 1] * (1.0 - a)
        ndi[i] = nd_ * a + ndi[i - 1] * (1.0 - a)
        s = pdi[i] + ndi[i]
        tmp = 100.0 * abs((pdi[i] - ndi[i]) / s) if s != 0.0 else 0.0
        out[i] = tmp * a + out[i - 1] * (1.0 - a)
    return out


class IndCache:
    """Memoised indicators per (market, timeframe, params)."""

    def __init__(self, market):
        self.m = market
        self.c = {}

    def get(self, kind, tf, n):
        key = (kind, tf, n)
        if key not in self.c:
            b = self.m.bars(tf)
            if kind == "ema":
                v = ema(b.close, n)
            elif kind == "atr":
                v = atr(b.high, b.low, b.close, n)
            elif kind == "rsi":
                v = rsi(b.close, n)
            elif kind == "adx":
                v = adx(b.high, b.low, b.close, n)
            else:
                raise KeyError(kind)
            self.c[key] = v
        return self.c[key]
