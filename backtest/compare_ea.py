"""So lenh cua EA GoldBot_SessionBreakout (MT5 Strategy Tester / demo) voi backtest Python.

EA ghi moi deal vao  <MT5 Common>\\Files\\GoldBot_<symbol>_<magic>.csv
(MT5: File > Open Data Folder > len 2 cap > Common > Files).

    python compare_ea.py GoldBot_XAUUSDr_26092301.csv data/XAUUSDr_ticks.csv --config config.json

Neu hai ben vao lenh cung nen, cung chieu -> EA dang chay dung chien luoc da kiem chung.
Xoa file CSV cu truoc moi lan chay Strategy Tester (EA ghi noi tiep).
"""

import argparse
import csv
import os
import sys
from collections import OrderedDict
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.config import Config  # noqa: E402
from goldbot.data import load_bars, fmt_time  # noqa: E402
from goldbot.engine import Backtester  # noqa: E402


def _t(s):
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return int(datetime.strptime(s.strip(), fmt).replace(tzinfo=timezone.utc).timestamp())
        except ValueError:
            pass
    raise ValueError(s)


def read_ea(path):
    pos = OrderedDict()
    with open(path, encoding="utf-8", errors="replace", newline="") as f:
        for r in csv.DictReader(f):
            pid = r["position"]
            p = pos.setdefault(pid, dict(t=None, side=None, pnl=0.0))
            if r["entry"] == "in":
                t = _t(r["time"])
                p["t"], p["side"] = t - t % 300, r["type"]
            else:
                p["pnl"] += float(r["profit"])
    return [p for p in pos.values() if p["t"] is not None]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ea_csv")
    ap.add_argument("data")
    ap.add_argument("--config", default=None)
    ap.add_argument("--balance", type=float, default=10000.0)
    args = ap.parse_args()

    ea = read_ea(args.ea_csv)
    if not ea:
        sys.exit("File EA khong co lenh nao.")
    cfg = Config.load(args.config) if args.config else Config()
    bars = load_bars(args.data)
    lo, hi = ea[0]["t"], ea[-1]["t"] + 86400  # the tester period, as seen from the EA log
    from goldbot.common import Account
    bt = Backtester(bars, cfg.make_strategy(), Account(initial_balance=args.balance), cfg.risk,
                    trade_from=lo, trade_to=hi).run()
    py = [dict(t=p.open_t, side="buy" if p.buy else "sell", pnl=p.pnl) for p in bt.trades]

    key = lambda p: (p["t"], p["side"])  # noqa: E731
    ek, pk = {key(p): p for p in ea}, {key(p): p for p in py}
    both = [k for k in ek if k in pk]
    print("-" * 70)
    print(" Lenh EA: %d | lenh Python: %d | trung (cung nen, cung chieu): %d" % (len(ek), len(pk), len(both)))
    print(" Ty le khop: %.1f%%" % (100.0 * len(both) / max(1, len(set(ek) | set(pk)))))
    print(" Lai/lo EA: $%.2f | Python: $%.2f" % (sum(p["pnl"] for p in ea), sum(p["pnl"] for p in py)))
    same_sign = sum(1 for k in both if (ek[k]["pnl"] >= 0) == (pk[k]["pnl"] >= 0))
    if both:
        print(" Cung ket qua thang/thua tren lenh trung: %d/%d" % (same_sign, len(both)))
    for name, only in (("Chi EA co", sorted(set(ek) - set(pk))), ("Chi Python co", sorted(set(pk) - set(ek)))):
        if only:
            print(" %s (%d): %s" % (name, len(only), ", ".join("%s %s" % (fmt_time(t), s) for t, s in only[:8])))
    print("-" * 70)
    ok = len(both) >= 0.9 * max(len(ek), len(pk))
    print(" KET LUAN: " + ("EA chay dung chien luoc da backtest." if ok else
                           "Lech nhieu - gui file CSV nay cho Claude de kiem tra (co the do gio server/ du lieu khac)."))


if __name__ == "__main__":
    main()
