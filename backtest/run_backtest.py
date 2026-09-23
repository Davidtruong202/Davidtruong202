"""ICT Bot - backtest the XAUUSD_ICT_M5 EA logic on data exported from your broker.

Examples
--------
  # file nen/tick xuat tu MT5 (tu nhan dang dinh dang)
  python run_backtest.py data/XAUUSD_M5.csv

  # doi von, rui ro, spread, khoang thoi gian
  python run_backtest.py data/XAUUSD_ticks.csv --balance 5000 --risk 1 --from 2025-01-01 --to 2025-07-01

  # broker GMT+0 co dinh (vd Exness) thay vi server = NY+7
  python run_backtest.py data/XAUUSD_M5.csv --gmt-offset 0

  # chay thu voi du lieu gia lap
  python make_demo_data.py && python run_backtest.py data/DEMO_XAUUSD_M5.csv --demo
"""

import argparse
import os
import sys
import time
import webbrowser
from dataclasses import fields
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ict_bot.data import load_bars, fmt_time  # noqa: E402
from ict_bot.report import write_report, compute_stats  # noqa: E402
from ict_bot.strategy import ICTBacktest, Params, Account  # noqa: E402


def _epoch(s):
    return int(datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp())


def main():
    ap = argparse.ArgumentParser(description="ICT Bot backtest (port Python cua XAUUSD_ICT_M5.mq5)",
                                 formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument("data", help="File CSV xuat tu san: nen M1/M5 hoac tick")
    ap.add_argument("--symbol", default=None, help="Ten hien thi (mac dinh lay tu ten file)")
    ap.add_argument("--out", default=None, help="File HTML bao cao (mac dinh reports/<ten>_report.html)")
    ap.add_argument("--balance", type=float, default=10000.0, help="Von ban dau (USD)")
    ap.add_argument("--risk", type=float, default=None, help="%% rui ro moi lenh (InpRiskPercent)")
    ap.add_argument("--from", dest="t_from", default=None, help="Chi vao lenh tu ngay YYYY-MM-DD")
    ap.add_argument("--to", dest="t_to", default=None, help="Chi vao lenh truoc ngay YYYY-MM-DD")
    ap.add_argument("--point", type=float, default=0.01, help="Gia tri 1 point (XAUUSD 2 so le = 0.01)")
    ap.add_argument("--spread", type=float, default=25, help="Spread (points) khi file khong co spread")
    ap.add_argument("--contract", type=float, default=100.0, help="Contract size (XAUUSD = 100 oz/lot)")
    ap.add_argument("--commission", type=float, default=0.0, help="Phi hoa hong USD/lot (khu hoi)")
    ap.add_argument("--gmt-offset", type=float, default=None,
                    help="Broker dung GMT co dinh: nhap offset (vd 0 cho Exness). Bo trong = server luon NY+7")
    ap.add_argument("--ny-offset", type=float, default=None, help="So gio server di truoc NY (mac dinh 7)")
    ap.add_argument("--set", action="append", default=[], metavar="TEN=GIATRI",
                    help="Doi bat ky tham so EA nao, vd --set piv_len=6 --set enable_setup_d=false")
    ap.add_argument("--demo", action="store_true", help="Danh dau bao cao la du lieu gia lap")
    ap.add_argument("--no-open", action="store_true", help="Khong tu mo trinh duyet")
    args = ap.parse_args()

    params = Params()
    if args.risk is not None:
        params.risk_percent = args.risk
    if args.gmt_offset is not None:
        params.broker_fixed_ny_offset = False
        params.server_gmt_offset_hours = args.gmt_offset
    if args.ny_offset is not None:
        params.server_to_ny_hours = args.ny_offset
    types = {f.name: f.type for f in fields(Params)}
    for kv in args.set:
        k, _, v = kv.partition("=")
        k = k.strip()
        if k not in types:
            ap.error("Khong co tham so '%s'. Cac tham so: %s" % (k, ", ".join(types)))
        tp = types[k]
        if tp in (bool, "bool"):
            val = v.strip().lower() in ("1", "true", "yes", "on")
        elif tp in (int, "int"):
            val = int(v)
        else:
            val = float(v)
        setattr(params, k, val)

    account = Account(initial_balance=args.balance, contract_size=args.contract,
                      tick_size=args.point, tick_value=args.point * args.contract,
                      commission_per_lot=args.commission, point=args.point)

    t0 = time.time()
    bars = load_bars(args.data, point=args.point, default_spread_points=args.spread)
    base = os.path.splitext(os.path.basename(args.data))[0]
    symbol = args.symbol or ("XAUUSD" if "XAU" in base.upper() or "GOLD" in base.upper() else base)

    print("Dang chay backtest %d nen M5 ..." % len(bars), file=sys.stderr)
    bt = ICTBacktest(bars, params, account,
                     trade_from=_epoch(args.t_from) if args.t_from else None,
                     trade_to=_epoch(args.t_to) if args.t_to else None)
    bt.run(progress=lambda j, n: print("  %3d%%" % (j * 100 // n), file=sys.stderr))

    out = args.out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports", base + "_report.html")
    meta = dict(symbol=symbol, source=os.path.basename(args.data), demo=bool(args.demo or "DEMO" in base.upper()))
    write_report(bt, out, meta)
    s = compute_stats(bt)["summary"]
    c = bt.cnt

    line = "-" * 60
    print(line)
    print(" ICT Bot · %s · %s -> %s" % (symbol, fmt_time(bars.t[0]), fmt_time(bars.t[-1])))
    print(line)
    print(" Von dau        : $%s" % format(s["initial"], ",.2f"))
    print(" Von cuoi       : $%s  (%+.2f%%)" % (format(s["final"], ",.2f"), s["ret_pct"]))
    print(" So lenh        : %d  (thang %.1f%%)" % (s["trades"], s["win_rate"]))
    print(" Profit factor  : %s" % ("inf" if s["pf"] == float("inf") else "%.2f" % s["pf"]))
    print(" Max drawdown   : %.2f%%  ($%s)" % (s["max_dd_pct"], format(s["max_dd"], ",.2f")))
    print(" Ky vong        : %+.2fR / lenh" % s["avg_r"])
    print(" [ICT-EA Summary] bars=%d sweeps=%d zones=%d BOS=%d CHoCH=%d tradesA=%d tradesB=%d tradesC=%d tradesD=%d"
          % (c["bars"], c["sweeps"], c["zones"], c["bos"], c["choch"], c["A"], c["B"], c["C"], c["D"]))
    print(line)
    print(" Bao cao: %s   (%.1fs)" % (out, time.time() - t0))
    if not args.no_open:
        try:
            webbrowser.open("file://" + os.path.abspath(out))
        except Exception:
            pass


if __name__ == "__main__":
    main()
