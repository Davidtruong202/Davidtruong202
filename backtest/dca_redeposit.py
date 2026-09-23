"""DCA khong cat lo, nhoi den khi chuoi duong. Chay tai khoan thi nap lai 5.000 USC va chay tiep.

    python dca_redeposit.py data/XAUUSDc_M1_....csv

In ra, cho moi cau hinh: so lan chay (= so lan nap), tong nap, tong rut, von con lai, loi/lo rong.
A = khong rut lai; B = moi khi len 10.000 thi rut 5.000.
"""

import itertools
import os
import pickle
import sys
import tempfile
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.data import load_bars, fmt_time  # noqa: E402
from goldbot.dca import DCAParams, DCASim  # noqa: E402

DEPOSIT = 5000.0
_M1 = None


def _init(pkl):
    global _M1
    with open(pkl, "rb") as f:
        _M1 = pickle.load(f)


def simulate(combo, policy):
    direction, step, tp = combo
    p = DCAParams(direction=direction, step_atr=step, tp_atr=tp, base_lot=0.01, mult=1.3, mult2=1.2, mult2_after=5,
                  max_levels=500, basket_sl_pct=100.0, rebate_per_lot=11.0)
    t = _M1.t[0]
    deposits, withdrawn, blowups, final = 0.0, 0.0, [], 0.0
    while True:
        bars = _M1.slice_time(t, None)
        if len(bars) < 5000:
            break
        deposits += DEPOSIT
        kw = dict(withdraw_at=2 * DEPOSIT, withdraw_to=DEPOSIT) if policy == "B" else {}
        r = DCASim(bars, p, initial=DEPOSIT).run(**kw)
        withdrawn += r["withdrawn"]
        if r["blown"]:
            blowups.append(r["end_t"])
            t = r["end_t"] + 3600          # re-deposit an hour later
            continue
        final = r["final"]
        break
    return dict(combo=combo, policy=policy, deposits=deposits, withdrawn=withdrawn, final=final,
                net=withdrawn + final - deposits, blowups=blowups)


def _job(args):
    return simulate(*args)


def main():
    m1 = load_bars(sys.argv[1], tf=60, verbose=False)
    fd, pkl = tempfile.mkstemp(suffix=".pkl")
    with os.fdopen(fd, "wb") as f:
        pickle.dump(m1, f, protocol=pickle.HIGHEST_PROTOCOL)
    combos = list(itertools.product(("trend", "long"), (0.5, 1.0, 2.0), (0.05, 0.1, 0.3)))
    jobs = [(c, pol) for c in combos for pol in ("A", "B")]
    try:
        with Pool(os.cpu_count() or 2, initializer=_init, initargs=(pkl,)) as pool:
            res = pool.map(_job, jobs)
    finally:
        os.remove(pkl)
    print("Nap %.0f USC moi lan, x1.3 -> x1.2 sau 5 lenh, khong cat lo, chot khi chuoi duong, hoan 11 USC/lot" % DEPOSIT)
    print("%-26s %-3s %5s %9s %10s %9s %11s  %s" % ("Cau hinh", "", "chay", "tong nap", "tong rut", "con lai", "LOI/LO rong", "cac lan chay"))
    for r in sorted(res, key=lambda r: r["net"], reverse=True):
        d, s, t = r["combo"]
        print("%-26s %-3s %5d %9.0f %10.0f %9.0f %+11.0f  %s" % (
            "%s buoc %.1fATR tp %.2fATR" % (d, s, t), r["policy"], len(r["blowups"]), r["deposits"], r["withdrawn"],
            r["final"], r["net"], ", ".join(fmt_time(x)[:7] for x in r["blowups"][:8]) + (" ..." if len(r["blowups"]) > 8 else "")))
    pos = [r for r in res if r["net"] > 0]
    print("\nCo loi rong: %d/%d cau hinh" % (len(pos), len(res)))


if __name__ == "__main__":
    main()
