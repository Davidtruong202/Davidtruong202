"""Walk-forward research shared by optimize.py and tournament.py.

Every grid combination is backtested ONCE over the whole data set. Because the
score uses R multiples (profit / initial risk), which do not depend on the
account balance, any time window can then be scored from that single run:

  * walk-forward: pick the best combination on blocks [0..k-1], score it on
    block k (never seen while choosing), stitch the k blocks together;
  * hold-out   : the last part of the data is kept aside and only scored once,
    with the combination chosen on everything before it.
"""

import itertools
import os
import pickle
import tempfile
from multiprocessing import Pool

from .config import Config
from .data import load_bars, resample
from .engine import Backtester

_BARS = None


def load_research_bars(path, point=0.01, verbose=True):
    """{60: M1 bars or None, 300: M5 bars}. M1 only when the file is ticks or M1 bars."""
    try:
        m1 = load_bars(path, point=point, tf=60, verbose=verbose)
        return {60: m1, 300: resample(m1, 300)}
    except ValueError as e:
        if "khung lon hon" not in str(e):
            raise
        return {60: None, 300: load_bars(path, point=point, tf=300, verbose=verbose)}


def dump_bars(bars_by_tf):
    fd, path = tempfile.mkstemp(suffix=".pkl")
    with os.fdopen(fd, "wb") as f:
        pickle.dump(bars_by_tf, f, protocol=pickle.HIGHEST_PROTOCOL)
    return path


def _init(pkl):
    global _BARS
    with open(pkl, "rb") as f:
        _BARS = pickle.load(f)


def _run(job):
    base, combo = job
    cfg = Config(base)
    for k, v in combo.items():
        cfg.set_param(k, v)
    strat = cfg.make_strategy()
    bt = Backtester(_BARS[strat.timeframe], strat, risk=cfg.risk).run()
    return combo, [(p.open_t, p.pnl / p.risk_money if p.risk_money else 0.0) for p in bt.trades]


def grid_combos(grid):
    keys = list(grid)
    return [dict(zip(keys, vals)) for vals in itertools.product(*(grid[k] for k in keys))]


def run_grid(jobs, pkl, workers):
    """jobs = [(base_config_dict, combo), ...] -> [(combo, [(open_t, R), ...]), ...] in order."""
    if workers <= 1:
        _init(pkl)
        return [_run(j) for j in jobs]
    with Pool(workers, initializer=_init, initargs=(pkl,)) as pool:
        return pool.map(_run, jobs, chunksize=1)


def score(trs, lo, hi, min_trades=0):
    rs = [r for t, r in trs if lo <= t < hi]
    n = len(rs)
    tot = sum(rs)
    peak = cur = dd = 0.0
    curve = []
    for r in rs:
        cur += r
        curve.append(cur)
        peak = max(peak, cur)
        dd = max(dd, peak - cur)
    gw = sum(r for r in rs if r > 0)
    gl = -sum(r for r in rs if r < 0)
    pf = gw / gl if gl > 0 else (99.0 if gw > 0 else 0.0)
    fit = (tot / max(dd, 1.0)) if n >= min_trades else -1e9
    # t-statistic of the mean R: how unlikely the result is if the true edge were zero
    if n > 1:
        mu = tot / n
        sd = (sum((r - mu) ** 2 for r in rs) / (n - 1)) ** 0.5
        tstat = mu / (sd / n ** 0.5) if sd > 0 else 0.0
    else:
        tstat = 0.0
    return dict(n=n, r=tot, dd=dd, pf=pf, win=(sum(1 for r in rs if r > 0) / n * 100 if n else 0.0),
                fit=fit, curve=curve, t=tstat)


def walk_forward(results, edges, min_trades):
    """edges = block boundaries of the research period. Returns folds, stitched OOS trades, last choice."""
    folds, oos = [], []
    for k in range(1, len(edges) - 1):
        is_lo, is_hi, os_lo, os_hi = edges[0], edges[k], edges[k], edges[k + 1]
        best = max(results, key=lambda cr: score(cr[1], is_lo, is_hi, min_trades)["fit"])
        folds.append(dict(combo=best[0], is_=score(best[1], is_lo, is_hi), oos=score(best[1], os_lo, os_hi),
                          span=(is_lo, is_hi, os_lo, os_hi)))
        oos += [(t, r) for t, r in best[1] if os_lo <= t < os_hi]
    return folds, oos


def verdict(s_oos, s_hold):
    """Strict on purpose: testing several methods on one data set makes lucky winners likely.

    CÓ LỢI THẾ needs >= 30 out-of-sample trades, PF >= 1.15, a t-statistic >= 2
    (roughly: under a 1-in-40 chance of a zero-edge method looking this good) and a
    profitable hold-out."""
    if s_oos["n"] < 30:
        return "ÍT LỆNH", "Quá ít lệnh ngoài mẫu để kết luận"
    if s_oos["r"] <= 0:
        return "KHÔNG", "Lỗ ngoài mẫu, không nên giao dịch"
    if s_oos["pf"] >= 1.15 and s_oos["t"] >= 2.0 and s_hold["r"] > 0:
        return "CÓ LỢI THẾ", "Lãi ngoài mẫu có ý nghĩa thống kê và lãi cả phần giữ lại: đáng chạy demo"
    if s_hold["r"] <= 0:
        return "CHƯA CHẮC", "Lãi ngoài mẫu nhưng lỗ ở phần giữ lại: nhiều khả năng do may mắn"
    return "CHƯA CHẮC", "Lãi nhưng chưa đủ mạnh về thống kê (t = %.1f < 2): có thể chỉ là may mắn" % s_oos["t"]
