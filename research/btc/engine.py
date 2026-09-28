"""Bar-level backtest engine executed on M1 bid bars.

Execution model (no look-ahead):
- A signal is evaluated on the CLOSE of a signal-timeframe bar (M1/M5/M15...).
- Entry happens at the OPEN of the first M1 bar starting at/after that close.
  BUY fills at ask = bid open + spread, SELL fills at bid open.
- SL/TP are fixed distances from the fill price. Exits are checked on every M1 bar:
  BUY exits on bid (low/high), SELL exits on ask (bid + spread of that bar).
- If SL and TP are both touched inside the same M1 bar, SL is assumed first (pessimistic).
- A gap through the SL fills at the bar open (worse than SL).
- `slip` (price units) is added against the trader on entry and on stop exits.
- Optional break-even: once price moves `be_r` x risk in favour, SL moves to entry + `be_lock` x risk.
- Optional trailing stop (column `trail` > 0, price units): after each M1 bar CLOSES the stop is
  raised to (highest bid high since entry - trail) for BUY / lowered to (lowest ask low + trail)
  for SELL. The new stop only applies from the next bar (no intrabar look-ahead).
- One position at a time per strategy: signals arriving while a trade is open are skipped.
"""
import numpy as np
import pandas as pd
from numba import njit

from data import POINT


@njit(cache=True)
def _simulate(o, h, l, c, sp, ent_idx, dirs, sl_d, tp_d, max_bars, slip, be_r, be_lock, trail_d):
    n = len(ent_idx)
    nb = len(o)
    out_entry = np.full(n, -1, np.int64)
    out_exit = np.full(n, -1, np.int64)
    out_pnl = np.zeros(n)
    out_risk = np.zeros(n)
    out_reason = np.zeros(n, np.int64)  # 1 SL, 2 TP, 3 time, 4 BE/trailing stop
    busy_until = -1
    for k in range(n):
        i = ent_idx[k]
        if i < 0 or i >= nb or i <= busy_until:
            continue
        d = dirs[k]
        risk = sl_d[k]
        if d == 1:
            px = o[i] + sp[i] + slip
            sl = px - risk
            tp = px + tp_d[k]
        else:
            px = o[i] - slip
            sl = px + risk
            tp = px - tp_d[k]
        be_done = False
        j = i
        last = min(nb - 1, i + max_bars[k])
        exit_px = 0.0
        reason = 3
        while True:
            s = sp[j]
            if d == 1:
                if o[j] <= sl and j > i:
                    exit_px = o[j] - slip
                    reason = 4 if be_done else 1
                    break
                if l[j] <= sl:
                    exit_px = sl - slip
                    reason = 4 if be_done else 1
                    break
                if h[j] >= tp:
                    exit_px = tp
                    reason = 2
                    break
                if be_r > 0 and not be_done and h[j] - px >= be_r * risk:
                    sl = px + be_lock * risk
                    be_done = True
            else:
                if o[j] + s >= sl and j > i:
                    exit_px = o[j] + s + slip
                    reason = 4 if be_done else 1
                    break
                if h[j] + s >= sl:
                    exit_px = sl + slip
                    reason = 4 if be_done else 1
                    break
                if l[j] + s <= tp:
                    exit_px = tp
                    reason = 2
                    break
                if be_r > 0 and not be_done and px - (l[j] + s) >= be_r * risk:
                    sl = px - be_lock * risk
                    be_done = True
            tr_ = trail_d[k]
            if tr_ > 0:
                if d == 1:
                    ns = h[j] - tr_
                    if ns > sl:
                        sl = ns
                        be_done = True
                else:
                    ns = l[j] + s + tr_
                    if ns < sl:
                        sl = ns
                        be_done = True
            if j >= last:
                exit_px = c[j] if d == 1 else c[j] + s
                reason = 3
                break
            j += 1
        out_entry[k] = i
        out_exit[k] = j
        out_pnl[k] = (exit_px - px) if d == 1 else (px - exit_px)
        out_risk[k] = risk
        out_reason[k] = reason
        busy_until = j
    return out_entry, out_exit, out_pnl, out_risk, out_reason


class M1Book:
    """Holds M1 arrays once so many strategies can be simulated quickly."""

    def __init__(self, m1, spread_mult=1.0, spread_override=None):
        self.index = m1.index
        self.t = m1.index.values
        self.o = m1.open.values.astype(np.float64)
        self.h = m1.high.values.astype(np.float64)
        self.l = m1.low.values.astype(np.float64)
        self.c = m1.close.values.astype(np.float64)
        sp = m1.spread.values.astype(np.float64) * POINT
        if spread_override is not None:
            sp = np.full_like(sp, spread_override)
        self.sp = sp * spread_mult


def run(book, sig, tf_minutes, slip=0.0, be_r=0.0, be_lock=0.0):
    """sig: DataFrame indexed by signal-bar OPEN time with columns dir, sl, tp, max_bars (in M1 bars).
    Returns a trade DataFrame."""
    sig = sig[sig["dir"] != 0]
    if len(sig) == 0:
        return pd.DataFrame()
    close_t = (sig.index + pd.Timedelta(minutes=tf_minutes)).values
    ent = np.searchsorted(book.t, close_t, side="left").astype(np.int64)
    e, x, pnl, risk, reason = _simulate(
        book.o, book.h, book.l, book.c, book.sp, ent,
        sig["dir"].values.astype(np.int64), sig["sl"].values.astype(np.float64),
        sig["tp"].values.astype(np.float64), sig["max_bars"].values.astype(np.int64),
        float(slip), float(be_r), float(be_lock),
        (sig["trail"].values if "trail" in sig else np.zeros(len(sig))).astype(np.float64))
    ok = e >= 0
    tr = pd.DataFrame({
        "signal_time": sig.index[ok],
        "entry_time": book.index[e[ok]],
        "exit_time": book.index[x[ok]],
        "dir": sig["dir"].values[ok],
        "risk": risk[ok],
        "pnl": pnl[ok],
        "reason": reason[ok],
        "spread_at_entry": book.sp[e[ok]],
    })
    tr["r"] = tr.pnl / tr.risk
    for col in sig.columns:
        if col.startswith("tag_"):
            tr[col] = sig[col].values[ok]
    return tr
