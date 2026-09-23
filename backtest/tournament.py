"""Dau loai cac phuong phap tren cung mot file du lieu cua san, xep hang theo ket qua NGOAI MAU.

    python tournament.py data/XAUUSDr_ticks.csv
    python tournament.py data/XAUUSDr_ticks.csv --strategies breakout,scalper --holdout 0.25

Quy trinh cho moi phuong phap:
  1. Chia du lieu: phan NGHIEN CUU (dau) + phan GIU LAI (cuoi, mac dinh 20%).
  2. Walk-forward trong phan nghien cuu: chon tham so tren qua khu, cham diem
     tren doan ke tiep chua thay -> ghep lai = ket qua ngoai mau.
  3. Tham so chon tren toan bo phan nghien cuu duoc thu DUY NHAT MOT LAN tren
     phan giu lai (khong dung de chon gi ca).
Xep hang theo ket qua ngoai mau (R / drawdown). Scalper can file tick hoac nen M1.

Ket qua: reports/tournament/index.html (bang xep hang) + bao cao HTML tung
phuong phap + config_<phuong phap>.json san sang cho run_backtest/live_bot.
"""

import argparse
import json
import os
import sys
import time
import webbrowser
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.common import Account  # noqa: E402
from goldbot.config import Config  # noqa: E402
from goldbot.data import fmt_time  # noqa: E402
from goldbot.engine import Backtester  # noqa: E402
from goldbot.report import compute_stats, write_report  # noqa: E402
from goldbot.research import (dump_bars, grid_combos, load_research_bars, run_grid, score,  # noqa: E402
                              verdict, walk_forward)
from goldbot.strategies import STRATEGIES  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "goldbot", "tournament_template.html")


def ict_trades(bars, account, risk_percent):
    from goldbot.ict import ICTBacktest, Params
    p = Params()
    p.risk_percent = risk_percent
    bt = ICTBacktest(bars, p, account).run()
    return bt, [(t.open_t, t.pnl / t.risk_money if t.risk_money else 0.0) for t in bt.trades]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("data")
    ap.add_argument("--config", default=None, help="Lay symbol va phan rui ro tu file nay")
    ap.add_argument("--strategies", default="breakout,pullback,meanrev,scalper,ict")
    ap.add_argument("--folds", type=int, default=4)
    ap.add_argument("--holdout", type=float, default=0.2, help="Ti le du lieu cuoi giu lai (0.2 = 20%%)")
    ap.add_argument("--min-trades", type=int, default=15)
    ap.add_argument("--balance", type=float, default=10000.0)
    ap.add_argument("--point", type=float, default=0.01)
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--out", default=os.path.join(HERE, "reports", "tournament"))
    ap.add_argument("--demo", action="store_true")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    started = time.time()
    base_cfg = Config.load(args.config) if args.config else Config()
    keys = [k.strip() for k in args.strategies.split(",") if k.strip()]
    bars = load_research_bars(args.data, point=args.point)
    m5 = bars[300]
    t0, t1 = m5.t[0], m5.t[-1] + 300
    t_hold = t1 - int((t1 - t0) * args.holdout)
    edges = [t0 + (t_hold - t0) * k // (args.folds + 1) for k in range(args.folds + 2)]
    account = Account(initial_balance=args.balance, point=args.point, tick_size=args.point,
                      tick_value=args.point * 100)
    name = os.path.splitext(os.path.basename(args.data))[0]
    demo = args.demo or "DEMO" in name.upper()
    os.makedirs(args.out, exist_ok=True)

    # ---- one backtest per (strategy, grid combination), all in one pool
    jobs, owners, skipped = [], [], []
    for k in keys:
        if k == "ict":
            continue
        if k not in STRATEGIES:
            sys.exit("Khong co phuong phap '%s'. Co: %s, ict" % (k, ", ".join(STRATEGIES)))
        S = STRATEGIES[k]
        if bars.get(S.timeframe) is None:
            skipped.append((k, "can file tick hoac nen M1"))
            continue
        base = dict(base_cfg.to_dict(), strategy=k, strategy_params={})
        for combo in grid_combos(S.GRID) or [{}]:
            jobs.append((base, combo))
            owners.append(k)
    print("Dang chay %d backtest (%d phuong phap) tren %d tien trinh..." % (
        len(jobs), len(set(owners)), args.workers), file=sys.stderr)
    pkl = dump_bars(bars)
    try:
        results = run_grid(jobs, pkl, args.workers)
    finally:
        os.remove(pkl)
    by_key = {}
    for k, res in zip(owners, results):
        by_key.setdefault(k, []).append(res)

    rows = []
    for k in keys:
        if k == "ict":
            print("Chay ICT (tham so mac dinh cua EA, khong toi uu)...", file=sys.stderr)
            bt, trs = ict_trades(m5, account, base_cfg.risk.risk_percent)
            res = [({}, trs)]
            title, tf = "ICT / SMC (EA cũ)", 300
        elif k in by_key:
            res = by_key[k]
            S = STRATEGIES[k]
            title, tf = S.name, S.timeframe
        else:
            continue
        folds, oos = walk_forward(res, edges, args.min_trades)
        s_oos = score(oos, 0, 1 << 62)
        final = max(res, key=lambda cr: score(cr[1], t0, t_hold, args.min_trades)["fit"])
        s_hold = score(final[1], t_hold, t1)
        s_full = score(final[1], t0, t1)
        tag, why = verdict(s_oos, s_hold)

        # full-period HTML report + ready-to-use config with the final parameters
        report = "%s.html" % k
        if k == "ict":
            rep_bt = bt
            cfg_file = None
        else:
            cfg = Config(dict(base_cfg.to_dict(), strategy=k, strategy_params={}))
            for pk, pv in final[0].items():
                cfg.set_param(pk, pv)
            rep_bt = Backtester(bars[tf], cfg.make_strategy(), account, cfg.risk).run()
            cfg_file = "config_%s.json" % k
            with open(os.path.join(args.out, cfg_file), "w", encoding="utf-8") as f:
                json.dump(dict(cfg.to_dict(), _tournament=dict(oos_R=round(s_oos["r"], 2), oos_pf=round(s_oos["pf"], 2),
                                                               holdout_R=round(s_hold["r"], 2), verdict=tag)),
                          f, indent=2, ensure_ascii=False)
        write_report(rep_bt, os.path.join(args.out, report),
                     dict(symbol=base_cfg.symbol, source=os.path.basename(args.data), demo=demo))
        st = compute_stats(rep_bt)["summary"]
        rows.append(dict(
            key=k, title=title, tf=tf, combos=len(res), params=final[0], verdict=tag, why=why,
            oos=dict((x, s_oos[x]) for x in ("n", "r", "pf", "win", "dd", "fit", "t")), oos_curve=s_oos["curve"],
            hold=dict((x, s_hold[x]) for x in ("n", "r", "pf", "win", "dd")), hold_curve=s_hold["curve"],
            full=dict(n=s_full["n"], r=s_full["r"], ret=st["ret_pct"], maxdd=st["max_dd_pct"]),
            folds=[dict(combo=f["combo"], oos_n=f["oos"]["n"], oos_r=f["oos"]["r"], is_r=f["is_"]["r"]) for f in folds],
            report=report, config=cfg_file,
        ))
        print("  %-18s ngoai mau %4d lenh %+7.1fR PF %.2f | giu lai %+6.1fR | %s" % (
            title, s_oos["n"], s_oos["r"], s_oos["pf"], s_hold["r"], tag), file=sys.stderr)

    rows.sort(key=lambda r: (r["oos"]["n"] >= 30, r["oos"]["fit"]), reverse=True)
    payload = dict(
        meta=dict(symbol=base_cfg.symbol, source=os.path.basename(args.data), demo=demo, first=t0, last=t1,
                  hold=t_hold, edges=edges, folds=args.folds, holdout=args.holdout, has_m1=bars.get(60) is not None,
                  generated=datetime.now().strftime("%Y-%m-%d %H:%M"), risk=base_cfg.risk.risk_percent,
                  seconds=round(time.time() - started)),
        rows=rows, skipped=skipped,
    )
    with open(TEMPLATE, encoding="utf-8") as f:
        html = f.read().replace("/*__DATA__*/null", json.dumps(payload, ensure_ascii=False).replace("</", "<\\/"))
    index = os.path.join(args.out, "index.html")
    with open(index, "w", encoding="utf-8") as f:
        f.write(html)

    line = "-" * 92
    print(line)
    print(" BANG XEP HANG  %s  %s -> %s   (giu lai tu %s)" % (base_cfg.symbol, fmt_time(t0)[:10], fmt_time(t1)[:10],
                                                                fmt_time(t_hold)[:10]))
    print(line)
    print(" #  %-20s %-4s %6s %8s %6s %5s %6s %9s  %s" % ("Phuong phap", "TF", "Lenh", "R ngoai", "PF", "t", "DD R",
                                                        "R giu lai", "Danh gia"))
    for n, r in enumerate(rows, 1):
        print(" %d  %-20s M%-3d %6d %+8.1f %6.2f %5.1f %6.1f %+9.1f  %s" % (
            n, r["title"][:20], r["tf"] // 60, r["oos"]["n"], r["oos"]["r"], r["oos"]["pf"], r["oos"]["t"],
            r["oos"]["dd"], r["hold"]["r"], r["verdict"]))
    for k, why in skipped:
        print(" -  %-20s bo qua: %s" % (k, why))
    print(line)
    print(" Bang xep hang: %s   (%.0fs)" % (index, time.time() - started))
    if not args.no_open:
        try:
            webbrowser.open("file://" + os.path.abspath(index))
        except Exception:
            pass


if __name__ == "__main__":
    main()
