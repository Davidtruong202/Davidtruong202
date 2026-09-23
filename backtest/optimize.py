"""Walk-forward optimisation: pick parameters on the past, judge them on the future.

The data is cut into ``--folds + 1`` equal time blocks. For fold k the best
grid combination on blocks [0..k-1] (in-sample) is traded on block k
(out-of-sample, never seen while choosing). Only the stitched out-of-sample
result tells whether the strategy has an edge; the in-sample best is always
flattering.

    python optimize.py data/XAUUSDr_ticks.csv
    python optimize.py data/XAUUSDr_M1.csv --grid tp_r=1.5,2,3 --grid use_trend=true,false --folds 4

Writes reports/optimize_<data>.csv and config.optimized.json (ready for
run_backtest.py --config / live_bot.py --config).
"""

import argparse
import csv
import itertools
import json
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.config import Config  # noqa: E402
from goldbot.data import load_bars, fmt_time  # noqa: E402
from goldbot.engine import Backtester  # noqa: E402

DEFAULT_GRID = {
    "tp_r": ["1.5", "2", "3"],
    "buffer_atr": ["0.05", "0.2"],
    "min_body": ["0.3", "0.5"],
    "use_trend": ["true", "false"],
    "trail_atr": ["0", "3"],
    "min_range_h1atr": ["0.5", "1.0"],
}

_BARS = None
_BASE = None


def _init(path, point, base_cfg):
    global _BARS, _BASE
    _BARS = load_bars(path, point=point, verbose=False)
    _BASE = base_cfg


def _run(combo):
    cfg = Config(_BASE)
    for k, v in combo.items():
        cfg.set_param(k, v)
    bt = Backtester(_BARS, cfg.make_strategy(), risk=cfg.risk).run()
    # R multiples are balance-independent, so any time slice can be scored from one run
    return combo, [(p.open_t, p.pnl / p.risk_money if p.risk_money else 0.0) for p in bt.trades]


def score(trs, lo, hi, min_trades):
    rs = [r for t, r in trs if lo <= t < hi]
    n = len(rs)
    tot = sum(rs)
    peak = cur = dd = 0.0
    for r in rs:
        cur += r
        peak = max(peak, cur)
        dd = max(dd, peak - cur)
    gw = sum(r for r in rs if r > 0)
    gl = -sum(r for r in rs if r < 0)
    pf = gw / gl if gl > 0 else (99.0 if gw > 0 else 0.0)
    fitness = (tot / max(dd, 1.0)) if n >= min_trades else -1e9
    return dict(n=n, r=tot, dd=dd, pf=pf, win=(sum(1 for r in rs if r > 0) / n * 100 if n else 0.0), fit=fitness)


def main():
    ap = argparse.ArgumentParser(description="Walk-forward optimisation", epilog=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("data")
    ap.add_argument("--config", default=None, help="Cau hinh goc (mac dinh: tham so mac dinh)")
    ap.add_argument("--grid", action="append", default=[], metavar="TEN=v1,v2,...")
    ap.add_argument("--folds", type=int, default=4)
    ap.add_argument("--min-trades", type=int, default=15, help="So lenh toi thieu trong mau de chap nhan")
    ap.add_argument("--point", type=float, default=0.01)
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 2)
    args = ap.parse_args()

    base = Config.load(args.config).to_dict() if args.config else Config().to_dict()
    grid = dict(DEFAULT_GRID) if not args.grid else {}
    for g in args.grid:
        k, _, v = g.partition("=")
        grid[k.strip()] = [x.strip() for x in v.split(",") if x.strip()]
    keys = list(grid)
    combos = [dict(zip(keys, vals)) for vals in itertools.product(*(grid[k] for k in keys))]
    Config(base).set_param  # validate names early
    for k in keys:
        Config(base).set_param(k, grid[k][0])

    bars = load_bars(args.data, point=args.point)
    t0, t1 = bars.t[0], bars.t[-1] + 300
    edges = [t0 + (t1 - t0) * k // (args.folds + 1) for k in range(args.folds + 2)]
    print("%d to hop tham so x 1 backtest, %d fold walk-forward, %d tien trinh..." % (
        len(combos), args.folds, args.workers), file=sys.stderr)

    start = time.time()
    with Pool(args.workers, initializer=_init, initargs=(args.data, args.point, base)) as pool:
        results = pool.map(_run, combos)
    print("Xong backtest sau %.0fs" % (time.time() - start), file=sys.stderr)

    line = "-" * 96
    print(line)
    print(" WALK-FORWARD  (chon tham so tren qua khu -> kiem tra tren doan tiep theo chua thay)")
    print(line)
    oos = []
    chosen = []
    for k in range(1, args.folds + 1):
        is_lo, is_hi, os_lo, os_hi = edges[0], edges[k], edges[k], edges[k + 1]
        best = max(results, key=lambda cr: score(cr[1], is_lo, is_hi, args.min_trades)["fit"])
        s_in = score(best[1], is_lo, is_hi, 0)
        s_out = score(best[1], os_lo, os_hi, 0)
        oos += [(t, r) for t, r in best[1] if os_lo <= t < os_hi]
        chosen.append(best[0])
        print(" Fold %d  trong mau %s->%s: %3d lenh %+7.1fR | NGOAI MAU %s->%s: %3d lenh %+7.1fR PF %.2f DD %.1fR" % (
            k, fmt_time(is_lo)[:10], fmt_time(is_hi)[:10], s_in["n"], s_in["r"],
            fmt_time(os_lo)[:10], fmt_time(os_hi)[:10], s_out["n"], s_out["r"], s_out["pf"], s_out["dd"]))
        print("         tham so: " + ", ".join("%s=%s" % kv for kv in best[0].items()))
    tot = score(oos, 0, 1 << 62, 0)
    print(line)
    print(" TONG NGOAI MAU: %d lenh, %+.1fR, PF %.2f, thang %.0f%%, DD %.1fR" % (
        tot["n"], tot["r"], tot["pf"], tot["win"], tot["dd"]))
    verdict = ("CO DAU HIEU LOI THE - nen chay demo tiep" if tot["r"] > 0 and tot["pf"] >= 1.15 and tot["n"] >= 30
               else "CHUA CO LOI THE RO RANG - khong nen giao dich that voi cau hinh nay")
    print(" Danh gia: " + verdict)
    print(line)

    # full-sample ranking (for information only - this is the flattering view)
    ranked = sorted(results, key=lambda cr: score(cr[1], t0, t1, args.min_trades)["fit"], reverse=True)
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports")
    os.makedirs(out_dir, exist_ok=True)
    name = os.path.splitext(os.path.basename(args.data))[0]
    csv_path = os.path.join(out_dir, "optimize_%s.csv" % name)
    with open(csv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(keys + ["trades", "total_R", "pf", "win_pct", "max_dd_R"])
        for combo, trs in ranked:
            s = score(trs, t0, t1, 0)
            w.writerow([combo[k] for k in keys] + [s["n"], round(s["r"], 2), round(s["pf"], 2),
                                                    round(s["win"], 1), round(s["dd"], 2)])
    print(" Top 5 toan bo du lieu (chi tham khao, luon dep hon thuc te):")
    for combo, trs in ranked[:5]:
        s = score(trs, t0, t1, 0)
        print("   %+7.1fR PF %.2f %3d lenh DD %.1fR | %s" % (s["r"], s["pf"], s["n"], s["dd"],
                                                         ", ".join("%s=%s" % kv for kv in combo.items())))

    # the most recent fold's choice is what we would trade next
    cfg = Config(base)
    for k, v in chosen[-1].items():
        cfg.set_param(k, v)
    cfg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.optimized.json")
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(dict(cfg.to_dict(), _walk_forward=dict(oos_trades=tot["n"], oos_R=round(tot["r"], 2),
                                                         oos_pf=round(tot["pf"], 2), verdict=verdict)),
                  f, indent=2, ensure_ascii=False)
    print(line)
    print(" Bang day du: %s" % csv_path)
    print(" Cau hinh chon (fold gan nhat): %s" % cfg_path)


if __name__ == "__main__":
    main()
