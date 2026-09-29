"""Selection-aware null test ("random tournament").

Question: if the entry signals had no timing edge, how good would the BEST wallet found by the same
grid search + filters look? Each replicate shifts every configuration's signal times by one random
offset (circularly over the data), keeps direction, SL distance and RR, re-simulates the trades,
rebuilds the 12 wallets per configuration and applies the same filters (>= min trades, net > 0,
PF >= 1.3, profitable in both halves). The best Wilson lower bound of WR per method is recorded.

p_chon_loc = share of replicates whose best-of-grid is at least as good as the real best-of-grid.
Usage: python3 null_tournament.py [--reps 40] [--families EMA,ICT,...]
"""
import argparse
import json
import os
import sys
import time

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dh import config as C  # noqa: E402
from dh.config import session_table  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.engine import family_signals  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator  # noqa: E402
from analyze import wilson_lb  # noqa: E402
from run_matrix import iter_grid  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def wallet_best(sig, res, sessions, money, split_t, t_entry, min_trades, min_half, min_pf):
    """Best Wilson-LB WR over the 12 wallets of one configuration that pass the filters (or -1)."""
    order = np.argsort(sig["i0"], kind="stable")
    best = -1.0
    passed = 0
    nets = []
    for d in range(3):
        for s in range(4):
            busy = -1
            take = []
            for k in order:
                if not res["ok"][k]:
                    continue
                b = sig["buy"][k]
                if (d == 1 and not b) or (d == 2 and b) or (s != 0 and sessions[k] != s) or sig["i0"][k] < busy:
                    continue
                take.append(k)
                busy = res["exit_i"][k]
            n = len(take)
            if n < min_trades:
                continue
            net = res["net"][take] * money
            nets.append(net.sum())
            if net.sum() <= 0:
                continue
            gl = -net[net < -1e-8].sum()
            gw = net[net > 1e-8].sum()
            if gl > 0 and gw / gl < min_pf:
                continue
            a = t_entry[take] < split_t
            if a.sum() < min_half or (~a).sum() < min_half or net[a].sum() <= 0 or net[~a].sum() <= 0:
                continue
            passed += 1
            best = max(best, float(wilson_lb(np.array([(net > 1e-8).sum()]), np.array([n]))[0]))
    return best, passed, nets


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ticks", default="/home/user/ea-pro/data/XAUUSDm_202601012305_202604301458.zip.part*")
    ap.add_argument("--cache-name", default="xauusdm_2026")
    ap.add_argument("--res", default=os.path.join(HERE, "results"))
    ap.add_argument("--split", default="2026-01-08")
    ap.add_argument("--reps", type=int, default=40)
    ap.add_argument("--families", default="EMA,ICT,MM,SMC,PVEMA,PIN,LQ")
    ap.add_argument("--min-trades", type=int, default=10)
    ap.add_argument("--min-half", type=int, default=3)
    ap.add_argument("--min-pf", type=float, default=1.3)
    a = ap.parse_args()

    ticks, _ = load_ticks(a.ticks, a.cache_name)
    m = Market(ticks)
    ind = IndCache(m)
    base = C.make()
    sim = TradeSimulator(m, base)
    money = sim.lot * m.contract
    split_t = int(pd.Timestamp(a.split).timestamp())
    ses_tab, _ = session_table(base)
    tk = m.ticks
    span0, span1 = int(tk.t[0]), int(tk.t[-1])
    rng = np.random.default_rng(7)

    fams = a.families.split(",")
    store = {f: [] for f in fams}
    for f in fams:
        for ov, cfg in iter_grid(f):
            s = family_signals(m, ind, cfg, f)
            if len(s["i0"]):
                store[f].append({k: s[k] for k in ("i0", "buy", "entry", "sl", "tp")})
    print("signals ready", {f: len(v) for f, v in store.items()}, flush=True)

    def evaluate(shift):
        out = {}
        for f in fams:
            best, passed, nets = -1.0, 0, []
            for s in store[f]:
                if shift is None:
                    sig = s
                else:
                    t_new = tk.t[s["i0"]] + shift
                    t_new = span0 + (t_new - span0) % (span1 - span0)
                    i0 = np.minimum(np.searchsorted(tk.t, t_new, side="left"), len(tk.t) - 2)
                    buy = s["buy"]
                    entry = np.where(buy, tk.ask[i0], tk.bid[i0])
                    risk = np.abs(s["entry"] - s["sl"])
                    rr = np.abs(s["tp"] - s["entry"]) / risk
                    sgn = np.where(buy, 1.0, -1.0)
                    sig = {"i0": i0, "buy": buy, "entry": entry, "sl": np.round(entry - sgn * risk, 3),
                           "tp": np.round(entry + sgn * rr * risk, 3)}
                res = sim.run(sig)
                t_entry = tk.t[sig["i0"]]
                sessions = np.array([ses_tab[h] for h in (t_entry % 86400) // 3600])
                b, p, nt = wallet_best(sig, res, sessions, money, split_t, t_entry, a.min_trades, a.min_half, a.min_pf)
                best = max(best, b)
                passed += p
                nets += nt
            nets = np.array(nets) if nets else np.zeros(1)
            out[f] = (best, passed, 100.0 * float((nets > 0).mean()), float(np.median(nets)))
        return out

    t0 = time.time()
    real = evaluate(None)
    print("real", real, f"{time.time() - t0:.0f}s", flush=True)
    null = {f: [] for f in fams}
    for r in range(a.reps):
        shift = int(rng.integers(6 * 3600, span1 - span0 - 6 * 3600))
        sim.cache.clear()
        o = evaluate(shift)
        for f in fams:
            null[f].append(o[f])
        print(f"rep {r + 1}/{a.reps} {time.time() - t0:.0f}s", flush=True)
    rows = []
    for f in fams:
        nb = np.array([x[0] for x in null[f]])
        npass = np.array([x[1] for x in null[f]])
        nprof = np.array([x[2] for x in null[f]])
        nmed = np.array([x[3] for x in null[f]])
        rows.append({"pp": f,
                     # best single wallet (what a pure "highest WR" search would pick)
                     "wr_lb_tot_nhat_thuc": round(real[f][0], 2),
                     "wr_lb_tot_nhat_ngau_nhien_tv": round(float(np.median(nb)), 2),
                     "wr_lb_tot_nhat_ngau_nhien_p90": round(float(np.percentile(nb, 90)), 2),
                     "p_chon_loc": round(float((nb >= real[f][0] - 1e-9).mean()), 3),
                     # whole method: how many wallets pass / are profitable versus random timing
                     "so_vi_dat_loc_thuc": real[f][1], "so_vi_dat_loc_ngau_nhien_tv": float(np.median(npass)),
                     "p_so_vi_dat_loc": round(float((npass >= real[f][1]).mean()), 3),
                     "vi_lai_pct_thuc": round(real[f][2], 1), "vi_lai_pct_ngau_nhien_tv": round(float(np.median(nprof)), 1),
                     "p_vi_lai_pct": round(float((nprof >= real[f][2] - 1e-9).mean()), 3),
                     "net_tv_thuc": round(real[f][3], 2), "net_tv_ngau_nhien_tv": round(float(np.median(nmed)), 2),
                     "p_net_tv": round(float((nmed >= real[f][3] - 1e-9).mean()), 3),
                     "so_lan": a.reps})
    out = pd.DataFrame(rows)
    out.to_csv(os.path.join(a.res, "kiem_dinh_chon_loc_ngau_nhien.csv"), index=False)
    print(out.to_string(index=False))


if __name__ == "__main__":
    main()
