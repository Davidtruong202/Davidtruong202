"""Check BTC_DONCH_H1_TRAIL.mq5 signal logic against the research signals (N3_DONCH, H1).
Re-implements the EA's per-bar computation (EMA on a trailing window of CALC_BARS closed
H1 bars, 55-bar breakout) and compares BUY/SELL decisions bar by bar."""
import numpy as np
import pandas as pd
from numba import njit

import data
import indicators as ind
from strategies2 import HOLD, build
from verify_ea_logic import CALC_BARS, ema_last


@njit(cache=True)
def ea_signals(h, l, c, calc, brk):
    n = len(c)
    out = np.zeros(n, np.int64)
    for k in range(calc - 1, n):
        hi = -1e18
        lo = 1e18
        for i in range(k - brk, k):
            hi = max(hi, h[i])
            lo = min(lo, l[i])
        d = 1 if c[k] > hi else (-1 if c[k] < lo else 0)
        if d == 0:
            continue
        cc = c[k - calc + 1:k + 1]
        e50 = ema_last(cc, 50)
        e200 = ema_last(cc, 200)
        if (d == 1 and e50 <= e200) or (d == -1 and e50 >= e200):
            continue
        out[k] = d
    return out


def main():
    m1 = data.load_m1()
    h1 = data.resample(m1, "1h")
    ea = pd.Series(ea_signals(h1.high.values, h1.low.values, h1.close.values, CALC_BARS, 55), index=h1.index)
    f = ind.add_features(h1)
    res = build(f, "N3_DONCH", {"x": 0}, {"sl_atr": 2.0, "rr": 0.0, "trail": 2.0}, 60, HOLD["trail"])["dir"]
    sel = h1.index >= h1.index[CALC_BARS + 500]
    a, b = ea[sel], res[sel]
    both = (a != 0) | (b != 0)
    print(f"H1 bars {sel.sum()}, EA signals {int((a != 0).sum())}, research {int((b != 0).sum())}, "
          f"identical {int((a == b)[both].sum())}/{int(both.sum())}")
    d = pd.DataFrame({"ea": a, "research": b})[a != b]
    if len(d):
        print(d.head(20))


if __name__ == "__main__":
    main()
