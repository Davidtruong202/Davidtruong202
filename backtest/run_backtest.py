"""Gold Bot - backtest a strategy on data exported from your broker and write an HTML report.

Examples
--------
  # chien luoc Session Breakout (mac dinh), du lieu tick/nen xuat tu MT5
  python run_backtest.py data/XAUUSDr_ticks.csv

  # dung dung file cau hinh cua bot live -> backtest giong het cach bot se giao dich
  python run_backtest.py data/XAUUSDr_ticks.csv --config config.json

  # doi tham so nhanh, gioi han thoi gian
  python run_backtest.py data/XAUUSDr_M1.csv --set tp_r=2.5 --set use_trend=false --from 2025-01-01

  # chien luoc ICT cu (port tu EA XAUUSD_ICT_M5.mq5)
  python run_backtest.py data/XAUUSDr_M1.csv --strategy ict

  # chay thu voi du lieu gia lap
  python make_demo_data.py && python run_backtest.py data/DEMO_XAUUSD_M5.csv
"""

import argparse
import os
import sys
import time
import webbrowser
from dataclasses import fields
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.common import Account  # noqa: E402
from goldbot.config import Config, convert  # noqa: E402
from goldbot.data import load_bars, fmt_time  # noqa: E402
from goldbot.engine import Backtester  # noqa: E402
from goldbot.report import write_report, compute_stats  # noqa: E402


def _epoch(s):
    return int(datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp())


def build_parser():
    ap = argparse.ArgumentParser(description="Gold Bot backtest", formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__)
    ap.add_argument("data", help="File CSV xuat tu san: tick hoac nen M1/M5")
    ap.add_argument("--config", default=None, help="File cau hinh JSON (dung chung voi live_bot.py)")
    ap.add_argument("--strategy", default=None, help="breakout (mac dinh) | ict")
    ap.add_argument("--symbol", default=None, help="Ten hien thi")
    ap.add_argument("--out", default=None, help="File HTML bao cao (mac dinh reports/<ten>_<chien luoc>.html)")
    ap.add_argument("--balance", type=float, default=10000.0, help="Von ban dau (USD)")
    ap.add_argument("--risk", type=float, default=None, help="%% rui ro moi lenh")
    ap.add_argument("--from", dest="t_from", default=None, help="Chi vao lenh tu ngay YYYY-MM-DD")
    ap.add_argument("--to", dest="t_to", default=None, help="Chi vao lenh truoc ngay YYYY-MM-DD")
    ap.add_argument("--point", type=float, default=0.01, help="Gia tri 1 point (XAUUSD 2 so le = 0.01)")
    ap.add_argument("--spread", type=float, default=25, help="Spread (points) khi file khong co spread")
    ap.add_argument("--contract", type=float, default=100.0, help="Contract size (XAUUSD = 100 oz/lot)")
    ap.add_argument("--commission", type=float, default=0.0, help="Phi hoa hong USD/lot (khu hoi)")
    ap.add_argument("--set", action="append", default=[], metavar="TEN=GIATRI", help="Doi tham so chien luoc/rui ro")
    ap.add_argument("--demo", action="store_true", help="Danh dau bao cao la du lieu gia lap")
    ap.add_argument("--no-open", action="store_true", help="Khong tu mo trinh duyet")
    return ap


def make_account(args):
    return Account(initial_balance=args.balance, contract_size=args.contract, tick_size=args.point,
                   tick_value=args.point * args.contract, commission_per_lot=args.commission, point=args.point)


def run_ict(args, bars, account):
    from goldbot.ict import ICTBacktest, Params
    params = Params()
    if args.risk is not None:
        params.risk_percent = args.risk
    types = {f.name: f.type for f in fields(Params)}
    for kv in args.set:
        k, _, v = kv.partition("=")
        if k.strip() not in types:
            raise SystemExit("Khong co tham so '%s'" % k)
        setattr(params, k.strip(), convert(types[k.strip()], v))
    bt = ICTBacktest(bars, params, account,
                     trade_from=_epoch(args.t_from) if args.t_from else None,
                     trade_to=_epoch(args.t_to) if args.t_to else None)
    return bt.run()


def run_strategy(cfg, args, bars, account):
    bt = Backtester(bars, cfg.make_strategy(), account, cfg.risk,
                    trade_from=_epoch(args.t_from) if args.t_from else None,
                    trade_to=_epoch(args.t_to) if args.t_to else None)
    return bt.run()


def main():
    args = build_parser().parse_args()
    cfg = Config.load(args.config) if args.config else Config()
    key = args.strategy or (cfg.strategy_key if args.config else "breakout")

    account = make_account(args)
    t0 = time.time()
    bars = load_bars(args.data, point=args.point, default_spread_points=args.spread)
    base = os.path.splitext(os.path.basename(args.data))[0]
    symbol = args.symbol or (cfg.symbol if args.config else ("XAUUSD" if "XAU" in base.upper() or "GOLD" in base.upper() else base))
    print("Dang chay backtest %d nen M5 ..." % len(bars), file=sys.stderr)

    if key == "ict":
        bt = run_ict(args, bars, account)
    else:
        if key != cfg.strategy_key:
            cfg = Config(dict(cfg.to_dict(), strategy=key, strategy_params={}))
        if args.risk is not None:
            cfg.risk.risk_percent = args.risk
        for kv in args.set:
            k, _, v = kv.partition("=")
            try:
                cfg.set_param(k.strip(), v)
            except ValueError as e:
                raise SystemExit(str(e))
        bt = run_strategy(cfg, args, bars, account)

    out = args.out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports", "%s_%s.html" % (base, key))
    meta = dict(symbol=symbol, source=os.path.basename(args.data), demo=bool(args.demo or "DEMO" in base.upper()))
    write_report(bt, out, meta)
    s = compute_stats(bt)["summary"]

    line = "-" * 64
    print(line)
    print(" Gold Bot · %s · %s" % (bt.strategy_name, symbol))
    print(" %s -> %s" % (fmt_time(bars.t[0]), fmt_time(bars.t[-1])))
    print(line)
    print(" Von dau        : $%s" % format(s["initial"], ",.2f"))
    print(" Von cuoi       : $%s  (%+.2f%%)" % (format(s["final"], ",.2f"), s["ret_pct"]))
    print(" So lenh        : %d  (thang %.1f%%)" % (s["trades"], s["win_rate"]))
    print(" Profit factor  : %s" % ("inf" if s["pf"] == float("inf") else "%.2f" % s["pf"]))
    print(" Max drawdown   : %.2f%%  ($%s)" % (s["max_dd_pct"], format(s["max_dd"], ",.2f")))
    print(" Ky vong        : %+.2fR / lenh" % s["avg_r"])
    print(" Chan doan      : " + ", ".join("%s=%s" % (k, bt.cnt.get(k, 0)) for k, _ in bt.diag_labels))
    print(line)
    print(" Bao cao: %s   (%.1fs)" % (out, time.time() - t0))
    if not args.no_open:
        try:
            webbrowser.open("file://" + os.path.abspath(out))
        except Exception:
            pass


if __name__ == "__main__":
    main()
