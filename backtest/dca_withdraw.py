"""DCA vong lap lien tuc: nap 5.000 USC, khong cat lo, nhoi den khi chuoi lai, RUT LAI moi khi so du
cham moc, chay tai khoan thi nap lai 5.000. Tim cau hinh + moc rut cho tien mat ve tay nhieu nhat.

    python dca_withdraw.py data/XAUUSDc_M1_....csv
"""

import collections
import itertools
import os
import pickle
import sys
import tempfile
from datetime import datetime, timezone
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.data import load_bars  # noqa: E402
from goldbot.dca import DCAParams, DCASim  # noqa: E402

DEPOSIT = 5000.0
_M1 = None


def _init(pkl):
    global _M1
    with open(pkl, "rb") as f:
        _M1 = pickle.load(f)


def _year(t):
    return datetime.fromtimestamp(t, tz=timezone.utc).year


def _job(args):
    (direction, step, tp), mult_at = args
    p = DCAParams(direction=direction, step_atr=step, tp_atr=tp, base_lot=0.01, mult=1.3, mult2=1.2, mult2_after=5,
                  max_levels=500, basket_sl_pct=100.0, rebate_per_lot=11.0)
    t = _M1.t[0]
    flows = []                      # (time, +cash in hand / -deposit)
    blows, final = 0, 0.0
    while True:
        bars = _M1.slice_time(t, None)
        if len(bars) < 5000:
            break
        flows.append((t, -DEPOSIT))
        r = DCASim(bars, p, initial=DEPOSIT).run(withdraw_at=DEPOSIT * mult_at, withdraw_to=DEPOSIT)
        flows += r["withdrawals"]
        if r["blown"]:
            blows += 1
            t = r["end_t"] + 3600
            continue
        final = r["final"]
        break
    by_year = collections.OrderedDict()
    for tt, v in flows:
        by_year[_year(tt)] = by_year.get(_year(tt), 0.0) + v
    cash = sum(v for _, v in flows)
    return dict(cfg=(direction, step, tp), mult_at=mult_at, blows=blows, deposits=DEPOSIT * (blows + 1),
                cash=cash, final=final, net=cash + final, by_year=dict(by_year))


def main():
    m1 = load_bars(sys.argv[1], tf=60, verbose=False)
    fd, pkl = tempfile.mkstemp(suffix=".pkl")
    with os.fdopen(fd, "wb") as f:
        pickle.dump(m1, f, protocol=pickle.HIGHEST_PROTOCOL)
    cfgs = list(itertools.product(("trend", "long"), (1.0, 1.5, 2.0, 3.0), (0.1, 0.3, 0.5)))
    jobs = [(c, m) for c in cfgs for m in (1.2, 1.5, 2.0, 3.0)]
    try:
        with Pool(os.cpu_count() or 2, initializer=_init, initargs=(pkl,)) as pool:
            res = pool.map(_job, jobs, chunksize=2)
    finally:
        os.remove(pkl)
    years = sorted({y for r in res for y in r["by_year"]})
    print("Nap 5.000 USC/lan, x1.3->x1.2, khong cat lo, chot khi chuoi lai tp, hoan 11 USC/lot, chay thi nap lai")
    print("Tien mat rong = tong rut - tong nap (chua tinh so du con trong tai khoan)\n")
    hdr = "%-24s %-6s %4s %8s %10s " % ("Cau hinh", "rut khi", "chay", "nap", "TIEN MAT") + " ".join("%8s" % y for y in years) + "  con TK"
    print(hdr)
    for r in sorted(res, key=lambda r: r["cash"], reverse=True)[:20]:
        d, s, t = r["cfg"]
        print("%-24s x%-5.1f %4d %8.0f %+10.0f " % ("%s buoc%.1f tp%.1f" % (d, s, t), r["mult_at"], r["blows"], r["deposits"], r["cash"])
              + " ".join("%+8.0f" % r["by_year"].get(y, 0) for y in years) + "  %6.0f" % r["final"])
    pos = [r for r in res if r["cash"] > 0]
    allyears = [r for r in res if all(r["by_year"].get(y, 0) > 0 for y in years)]
    print("\nTien mat rong duong: %d/%d | duong o CA %d nam: %d" % (len(pos), len(res), len(years), len(allyears)))
    for m in (1.2, 1.5, 2.0, 3.0):
        rs = [r for r in res if r["mult_at"] == m]
        print("  rut khi x%.1f: trung binh %+.0f USC, %d/%d duong" % (m, sum(r["cash"] for r in rs) / len(rs), sum(r["cash"] > 0 for r in rs), len(rs)))


if __name__ == "__main__":
    main()
