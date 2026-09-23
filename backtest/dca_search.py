"""Tim cau hinh DCA dat x2 tai khoan voi sut giam (DD) thap nhat - chon tren du lieu cu, kiem tra tren phan giu lai.

    python dca_search.py data/XAUUSDc_M1_....csv

Moi bien the chay tu 10.000 tren toan bo du lieu (lai kep). Tieu chi chon (chi dung
phan NGHIEN CUU, 80% dau): dat x2 truoc khi het phan nghien cuu, khong chay tai
khoan, va DD toi da tinh den luc x2 la thap nhat. Sau do xem bien the do song
the nao o phan GIU LAI (20% cuoi) ma no chua tung "thay".
"""

import argparse
import itertools
import json
import os
import pickle
import sys
import tempfile
import time
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.data import load_bars, fmt_time  # noqa: E402
from goldbot.dca import DCAParams, DCASim, segment_stats  # noqa: E402

GRID = dict(
    direction=["trend", "long"],
    step_atr=[0.5, 1.0, 2.0],
    mult=[1.0, 1.5, 2.0],
    max_levels=[5, 8],
    tp_atr=[0.5, 1.0],
    basket_sl_pct=[10.0, 30.0, 100.0],
    lot_per_1k=[0.002, 0.005, 0.01, 0.02],
)

_M1 = None
_T_HOLD = None


def _init(pkl, t_hold):
    global _M1, _T_HOLD
    with open(pkl, "rb") as f:
        _M1 = pickle.load(f)
    _T_HOLD = t_hold


def _run(combo):
    sim = DCASim(_M1, DCAParams(**combo))
    r = sim.run()
    t0, t1 = _M1.t[0], _M1.t[-1] + 60
    research = segment_stats(r["curve"], r["baskets"], t0, _T_HOLD)
    hold = segment_stats(r["curve"], r["baskets"], _T_HOLD, t1)
    # drawdown until the account first doubled (inside the research part only counts for selection)
    bs = r["baskets"]
    return dict(combo=combo, mult=r["mult"], max_dd=r["max_dd"], blown=r["blown"], double_t=r["double_t"],
                dd_at_double=r["dd_at_double"], research=research, hold=hold, n=len(bs),
                sl=sum(1 for x in bs if x[5] != "TP"), win=(sum(1 for x in bs if x[3] > 0) / len(bs) * 100) if bs else 0,
                max_lots=max((x[6] for x in bs), default=0), levels=max((x[4] for x in bs), default=0))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("data")
    ap.add_argument("--holdout", type=float, default=0.2)
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports", "dca_search.json"))
    args = ap.parse_args()

    m1 = load_bars(args.data, tf=60)
    t0, t1 = m1.t[0], m1.t[-1] + 60
    t_hold = t1 - int((t1 - t0) * args.holdout)
    keys = list(GRID)
    combos = [dict(zip(keys, v)) for v in itertools.product(*(GRID[k] for k in keys))]
    fd, pkl = tempfile.mkstemp(suffix=".pkl")
    with os.fdopen(fd, "wb") as f:
        pickle.dump(m1, f, protocol=pickle.HIGHEST_PROTOCOL)
    start = time.time()
    print("%d bien the DCA, %d tien trinh..." % (len(combos), args.workers), file=sys.stderr)
    try:
        with Pool(args.workers, initializer=_init, initargs=(pkl, t_hold)) as pool:
            res = pool.map(_run, combos, chunksize=4)
    finally:
        os.remove(pkl)
    print("Xong sau %.0fs" % (time.time() - start), file=sys.stderr)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(dict(t0=t0, t1=t1, t_hold=t_hold, results=res), f)

    blown = sum(1 for r in res if r["blown"])
    doubled = [r for r in res if r["double_t"] and r["double_t"] < t_hold and not r["blown"]]
    doubled_any = [r for r in res if r["double_t"] and r["double_t"] < t_hold]
    line = "-" * 118
    print(line)
    print(" %d bien the | chay tai khoan: %d | x2 trong phan nghien cuu: %d (khong chay ca giai doan: %d)" % (
        len(res), blown, len(doubled_any), len(doubled)))
    print(" Phan nghien cuu %s -> %s | giu lai %s -> %s" % (fmt_time(t0)[:10], fmt_time(t_hold)[:10],
                                                          fmt_time(t_hold)[:10], fmt_time(t1)[:10]))
    print(line)
    print(" %-62s %8s %7s %9s | %8s %7s | %6s %6s" % ("Bien the (x2 som nhat trong nghien cuu, DD thap nhat)", "x2 luc",
                                                   "DD@x2", "ca ky", "giu lai", "DD", "gio", "cat"))
    for r in sorted(doubled_any, key=lambda r: r["dd_at_double"])[:15]:
        c = r["combo"]
        name = "%s step%.1f x%.1f L%d tp%.1f sl%d%% lot%.3f" % (c["direction"], c["step_atr"], c["mult"], c["max_levels"],
                                                              c["tp_atr"], c["basket_sl_pct"], c["lot_per_1k"])
        print(" %-62s %8s %6.1f%% %8s | %+7.1f%% %6.1f%% | %6d %6d" % (
            name, fmt_time(r["double_t"])[:10], r["dd_at_double"],
            "CHAY" if r["blown"] else "x%.2f" % r["mult"], r["hold"]["ret"], r["hold"]["dd"], r["n"], r["sl"]))
    print(line)
    print(" Ket qua day du: %s" % args.out)


if __name__ == "__main__":
    main()
