"""Test nhieu setup DCA theo cach van hanh: nap 5.000 USC, khong cat lo, nhoi den khi chuoi lai,
rut lai khi cham moc, chay thi nap lai. Chon setup tren 2024-2025, kiem tra tren 2026 (chua thay).

    python dca_setups.py data/XAUUSDc_M1_....csv
Ket qua: reports/dca_setups.json (+ bang in ra man hinh).
"""

import collections
import itertools
import json
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
MULTS = {"x1.2": dict(mult=1.2), "x1.3>1.2": dict(mult=1.3, mult2=1.2, mult2_after=5),
         "x1.3": dict(mult=1.3), "x1.5": dict(mult=1.5)}
GRID = dict(direction=["trend", "long"], step=[1.0, 1.5, 2.0, 2.5, 3.0], tp=[0.1, 0.2, 0.3, 0.5],
            mult=list(MULTS), withdraw=[1.2, 1.5, 2.0])
_M1 = None


def _init(pkl):
    global _M1
    with open(pkl, "rb") as f:
        _M1 = pickle.load(f)


def _year(t):
    return datetime.fromtimestamp(t, tz=timezone.utc).year


def run_setup(s):
    p = DCAParams(direction=s["direction"], step_atr=s["step"], tp_atr=s["tp"], base_lot=0.01, max_levels=500,
                  basket_sl_pct=100.0, rebate_per_lot=11.0, **MULTS[s["mult"]])
    t = _M1.t[0]
    flows, blow_t, final, max_levels, max_lots = [], [], 0.0, 0, 0.0
    while True:
        bars = _M1.slice_time(t, None)
        if len(bars) < 5000:
            break
        flows.append((t, -DEPOSIT))
        r = DCASim(bars, p, initial=DEPOSIT).run(withdraw_at=DEPOSIT * s["withdraw"], withdraw_to=DEPOSIT)
        flows += r["withdrawals"]
        max_levels = max([max_levels] + [x[4] for x in r["baskets"]])
        max_lots = max([max_lots] + [x[6] for x in r["baskets"]])
        if r["blown"]:
            blow_t.append(r["end_t"])
            t = r["end_t"] + 3600
            continue
        final = r["final"]
        break
    by_year = collections.defaultdict(float)
    for tt, v in flows:
        by_year[_year(tt)] += v
    return dict(setup=s, blows=len(blow_t), blow_t=blow_t, deposits=DEPOSIT * len([f for f in flows if f[1] < 0]),
                cash=sum(v for _, v in flows), final=final, by_year=dict(by_year), max_levels=max_levels, max_lots=max_lots)


def main():
    m1 = load_bars(sys.argv[1], tf=60, verbose=False)
    fd, pkl = tempfile.mkstemp(suffix=".pkl")
    with os.fdopen(fd, "wb") as f:
        pickle.dump(m1, f, protocol=pickle.HIGHEST_PROTOCOL)
    keys = list(GRID)
    setups = [dict(zip(keys, v)) for v in itertools.product(*(GRID[k] for k in keys))]
    print("%d setup..." % len(setups), file=sys.stderr)
    try:
        with Pool(os.cpu_count() or 2, initializer=_init, initargs=(pkl,)) as pool:
            res = pool.map(run_setup, setups, chunksize=2)
    finally:
        os.remove(pkl)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports", "dca_setups.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(res, f)
    for r in res:
        r["train"] = r["by_year"].get(2024, 0) + r["by_year"].get(2025, 0)
        r["test"] = r["by_year"].get(2026, 0)
    name = lambda s: "%-5s buoc%.1f tp%.1f %-8s rut x%.1f" % (s["direction"], s["step"], s["tp"], s["mult"], s["withdraw"])  # noqa: E731
    print("\nTOP 15 chon tren 2024-2025 -> ket qua 2026 (chua thay khi chon). Don vi USC (100 USC = 1$)")
    print("%-44s %5s %9s %9s %9s %6s %s" % ("Setup", "chay", "2024-25", "2026", "TONG", "lenh", "lot max"))
    top = sorted(res, key=lambda r: r["train"], reverse=True)[:15]
    for r in top:
        print("%-44s %5d %+9.0f %+9.0f %+9.0f %6d %6.2f" % (name(r["setup"]), r["blows"], r["train"], r["test"], r["cash"],
                                                          r["max_levels"], r["max_lots"]))
    print("\nTop 15 (2024-25) o nam 2026: %d/15 van lai, trung binh %+.0f USC" % (
        sum(r["test"] > 0 for r in top), sum(r["test"] for r in top) / 15))
    print("Tat ca %d setup: tien mat rong duong %d, duong ca 3 nam %d, khong chay lan nao %d" % (
        len(res), sum(r["cash"] > 0 for r in res),
        sum(all(r["by_year"].get(y, 0) > 0 for y in (2024, 2025, 2026)) for r in res), sum(r["blows"] == 0 for r in res)))
    for k in keys:
        g = collections.defaultdict(list)
        for r in res:
            g[r["setup"][k]].append(r)
        print("  %-9s " % k + " | ".join("%s: TB %+6.0f, chay TB %.1f" % (v, sum(x["cash"] for x in rs) / len(rs),
                                                                     sum(x["blows"] for x in rs) / len(rs)) for v, rs in g.items()))


if __name__ == "__main__":
    main()
