"""Walk-forward optimisation of ONE strategy: pick parameters on the past, judge them on the future.

    python optimize.py data/XAUUSDr_ticks.csv                       # Session Breakout
    python optimize.py data/XAUUSDr_ticks.csv --strategy scalper    # M1 scalper (needs ticks/M1)
    python optimize.py data/XAUUSDr_M1.csv --grid tp_r=1.5,2,3 --grid use_trend=true,false

To compare several strategies at once use tournament.py. Writes
reports/optimize_<data>_<strategy>.csv and config.optimized.json (ready for
run_backtest.py --config / live_bot.py --config).
"""

import argparse
import csv
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.config import Config  # noqa: E402
from goldbot.data import fmt_time  # noqa: E402
from goldbot.research import (dump_bars, grid_combos, load_research_bars, run_grid, score,  # noqa: E402
                              verdict, walk_forward)
from goldbot.strategies import STRATEGIES  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser(description="Walk-forward optimisation", epilog=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("data")
    ap.add_argument("--config", default=None, help="Cau hinh goc (mac dinh: tham so mac dinh)")
    ap.add_argument("--strategy", default=None, help=", ".join(STRATEGIES))
    ap.add_argument("--grid", action="append", default=[], metavar="TEN=v1,v2,...")
    ap.add_argument("--folds", type=int, default=4)
    ap.add_argument("--holdout", type=float, default=0.2, help="Ti le du lieu cuoi giu lai")
    ap.add_argument("--min-trades", type=int, default=15, help="So lenh toi thieu trong mau de chap nhan")
    ap.add_argument("--point", type=float, default=0.01)
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 2)
    args = ap.parse_args()

    base_cfg = Config.load(args.config) if args.config else Config()
    key = args.strategy or base_cfg.strategy_key
    if key not in STRATEGIES:
        sys.exit("Phuong phap phai la: %s" % ", ".join(STRATEGIES))
    S = STRATEGIES[key]
    base = dict(base_cfg.to_dict(), strategy=key,
                strategy_params=base_cfg.to_dict()["strategy_params"] if key == base_cfg.strategy_key else {})
    grid = dict(S.GRID) if not args.grid else {}
    for g in args.grid:
        k, _, v = g.partition("=")
        grid[k.strip()] = [x.strip() for x in v.split(",") if x.strip()]
    for k, vals in grid.items():
        Config(base).set_param(k, vals[0])  # validate names early
    combos = grid_combos(grid) or [{}]

    bars = load_research_bars(args.data, point=args.point)
    if bars.get(S.timeframe) is None:
        sys.exit("%s can file tick hoac nen M1." % S.name)
    t0, t1 = bars[300].t[0], bars[300].t[-1] + 300
    t_hold = t1 - int((t1 - t0) * args.holdout)
    edges = [t0 + (t_hold - t0) * k // (args.folds + 1) for k in range(args.folds + 2)]
    print("%s: %d to hop tham so, %d fold walk-forward, %d tien trinh..." % (
        S.name, len(combos), args.folds, args.workers), file=sys.stderr)

    start = time.time()
    pkl = dump_bars(bars)
    try:
        results = run_grid([(base, c) for c in combos], pkl, args.workers)
    finally:
        os.remove(pkl)
    print("Xong backtest sau %.0fs" % (time.time() - start), file=sys.stderr)

    folds, oos = walk_forward(results, edges, args.min_trades)
    line = "-" * 100
    print(line)
    print(" WALK-FORWARD %s  (chon tham so tren qua khu -> kiem tra tren doan tiep theo chua thay)" % S.name)
    print(line)
    for n, f in enumerate(folds, 1):
        is_lo, is_hi, os_lo, os_hi = f["span"]
        print(" Fold %d  trong mau %s->%s: %3d lenh %+7.1fR | NGOAI MAU %s->%s: %3d lenh %+7.1fR PF %.2f" % (
            n, fmt_time(is_lo)[:10], fmt_time(is_hi)[:10], f["is_"]["n"], f["is_"]["r"],
            fmt_time(os_lo)[:10], fmt_time(os_hi)[:10], f["oos"]["n"], f["oos"]["r"], f["oos"]["pf"]))
        print("         tham so: " + (", ".join("%s=%s" % kv for kv in f["combo"].items()) or "mac dinh"))
    s_oos = score(oos, 0, 1 << 62)
    final = max(results, key=lambda cr: score(cr[1], t0, t_hold, args.min_trades)["fit"])
    s_hold = score(final[1], t_hold, t1)
    tag, why = verdict(s_oos, s_hold)
    print(line)
    print(" TONG NGOAI MAU : %d lenh, %+.1fR, PF %.2f, t = %.1f, thang %.0f%%, DD %.1fR" % (
        s_oos["n"], s_oos["r"], s_oos["pf"], s_oos["t"], s_oos["win"], s_oos["dd"]))
    print(" PHAN GIU LAI   : %s -> %s: %d lenh, %+.1fR, PF %.2f" % (
        fmt_time(t_hold)[:10], fmt_time(t1)[:10], s_hold["n"], s_hold["r"], s_hold["pf"]))
    print(" Danh gia: %s - %s" % (tag, why))
    print(line)

    ranked = sorted(results, key=lambda cr: score(cr[1], t0, t_hold, args.min_trades)["fit"], reverse=True)
    out_dir = os.path.join(HERE, "reports")
    os.makedirs(out_dir, exist_ok=True)
    name = os.path.splitext(os.path.basename(args.data))[0]
    csv_path = os.path.join(out_dir, "optimize_%s_%s.csv" % (name, key))
    keys = list(grid)
    with open(csv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(keys + ["trades", "total_R", "pf", "t", "win_pct", "max_dd_R"])
        for combo, trs in ranked:
            s = score(trs, t0, t_hold)
            w.writerow([combo.get(k) for k in keys] + [s["n"], round(s["r"], 2), round(s["pf"], 2), round(s["t"], 2),
                                                       round(s["win"], 1), round(s["dd"], 2)])
    print(" Top 5 tren phan nghien cuu (chi tham khao, luon dep hon thuc te):")
    for combo, trs in ranked[:5]:
        s = score(trs, t0, t_hold)
        print("   %+7.1fR PF %.2f %4d lenh DD %.1fR | %s" % (s["r"], s["pf"], s["n"], s["dd"],
                                                          ", ".join("%s=%s" % kv for kv in combo.items())))

    cfg = Config(base)
    for k, v in final[0].items():
        cfg.set_param(k, v)
    cfg_path = os.path.join(HERE, "config.optimized.json")
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(dict(cfg.to_dict(), _walk_forward=dict(oos_trades=s_oos["n"], oos_R=round(s_oos["r"], 2),
                                                         oos_pf=round(s_oos["pf"], 2), oos_t=round(s_oos["t"], 2),
                                                         holdout_R=round(s_hold["r"], 2), verdict=tag)),
                  f, indent=2, ensure_ascii=False)
    print(line)
    print(" Bang day du: %s" % csv_path)
    print(" Cau hinh chon: %s" % cfg_path)


if __name__ == "__main__":
    main()
