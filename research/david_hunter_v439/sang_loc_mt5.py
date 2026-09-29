"""Screen the 2568 MT5 wallets with one fixed rule and pick ONE input set; test the rule itself walk-forward.

Rule (applied to a window of m months, all numbers from ket_qua_thang.csv):
  1. trades >= 100 * m / 9            (the EA's own minimum: 100 trades over the 9-month run)
  2. net > 0, and net without the best month > 0   (not carried by one month)
  3. profitable months >= 2/3 of the window
  4. plateau: >= 60% of grid neighbours (same method, direction, session; one input one step away) net > 0
  5. rank by the 95% Wilson lower bound of the win rate, then by USD per trade
Walk-forward: choose with the rule on months A, look at months B the rule never saw.
Usage: python3 sang_loc_mt5.py --run /path/RUN_folder
"""
import argparse
import math
import os

import numpy as np
import pandas as pd

from analyze_mt5 import AXES, HERE, RUN_DEFAULT, load

MIN_TRADES_9M = 100
PLATEAU = 0.60
FOLDS = [("T1-T3", [202601, 202602, 202603], "T4-T6", [202604, 202605, 202606]),
         ("T4-T6", [202604, 202605, 202606], "T7-T9", [202607, 202608, 202609]),
         ("T1-T6", [202601, 202602, 202603, 202604, 202605, 202606], "T7-T9", [202607, 202608, 202609]),
         ("T1-T3", [202601, 202602, 202603], "T4-T9", [202604, 202605, 202606, 202607, 202608, 202609])]


def wilson_lb(wins, n, z=1.96):
    if n <= 0:
        return 0.0
    p = wins / n
    den = 1 + z * z / n
    return 100 * (p + z * z / (2 * n) - z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))) / den


def window(d, net_m, n_m, w_m, months):
    """Per-wallet stats over the given months."""
    ids = d.wallet_id.to_numpy()
    net = net_m.loc[ids, months]
    out = pd.DataFrame({"wallet_id": ids,
                        "lenh": n_m.loc[ids, months].sum(axis=1).to_numpy(),
                        "thang_loi": w_m.loc[ids, months].sum(axis=1).to_numpy(),
                        "net": net.sum(axis=1).to_numpy(),
                        "net_bo_thang_tot_nhat": (net.sum(axis=1) - net.max(axis=1)).to_numpy(),
                        "thang_lai": (net > 0).sum(axis=1).to_numpy()})
    out["wr"] = 100 * out.thang_loi / out.lenh.clip(lower=1)
    out["wr_lb"] = [wilson_lb(w, n) for w, n in zip(out.thang_loi, out.lenh)]
    out["usd_moi_lenh"] = out.net / out.lenh.clip(lower=1)
    return out


def neighbours(d):
    """wallet_id -> list of neighbour wallet_ids (one grid axis moved one step, same direction and session)."""
    res = {}
    for fam, axes in AXES.items():
        q = d[d.phuong_phap == fam]
        levels = {}
        for ax in axes:
            vals = q[ax].unique().tolist()
            try:
                vals = sorted(vals, key=float)
            except ValueError:
                order = ["M1", "M2", "M3", "M4", "M5", "M6", "M10", "M12", "M15", "M20", "M30", "H1", "H4"]
                vals = sorted(vals, key=lambda v: order.index(v) if v in order else v)
            levels[ax] = {v: i for i, v in enumerate(vals)}
        key = {r.wallet_id: (r.huong, r.phien, tuple(levels[ax][r[ax]] for ax in axes)) for _, r in q.iterrows()}
        index = {v: k for k, v in key.items()}
        for wid, (h, p, pos) in key.items():
            nb = []
            for i in range(len(axes)):
                for step in (-1, 1):
                    other = list(pos)
                    other[i] += step
                    k = (h, p, tuple(other))
                    if k in index:
                        nb.append(index[k])
            res[wid] = nb
    return res


def screen(d, net_m, n_m, w_m, months, nb):
    s = window(d, net_m, n_m, w_m, months).merge(
        d[["wallet_id", "phuong_phap", "huong", "phien", "cau_hinh"]], on="wallet_id")
    ok = s.set_index("wallet_id").net > 0
    s["hang_xom"] = s.wallet_id.map(lambda w: len(nb.get(w, [])))
    s["hang_xom_lai_pct"] = s.wallet_id.map(
        lambda w: 100 * float(np.mean([ok[x] for x in nb[w]])) if nb.get(w) else 0.0)
    m = len(months)
    s["dat_loc"] = ((s.lenh >= MIN_TRADES_9M * m / 9) & (s.net > 0) & (s.net_bo_thang_tot_nhat > 0)
                    & (s.thang_lai >= math.ceil(2 * m / 3)) & (s.hang_xom_lai_pct >= 100 * PLATEAU))
    s = s.sort_values(["dat_loc", "wr_lb", "usd_moi_lenh"], ascending=[False, False, False]).reset_index(drop=True)
    s.insert(0, "hang", np.where(s.dat_loc, np.arange(1, len(s) + 1), 0))
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", default=RUN_DEFAULT)
    ap.add_argument("--out", default=os.path.join(HERE, "results_mt5"))
    a = ap.parse_args()
    d, _, months = load(a.run)
    month = pd.read_csv(os.path.join(a.run, "ket_qua_thang.csv"), sep=";")
    net_m = month.pivot_table(index="wallet_id", columns="thang", values="net_da_chot", aggfunc="sum").fillna(0.0)
    n_m = month.pivot_table(index="wallet_id", columns="thang", values="lenh_dong", aggfunc="sum").fillna(0)
    w_m = month.pivot_table(index="wallet_id", columns="thang", values="lenh_thang", aggfunc="sum").fillna(0)
    nb = neighbours(d)

    # 1. does the rule work on months it did not see?
    rows = []
    for train_name, train, test_name, test in FOLDS:
        s = screen(d, net_m, n_m, w_m, train, nb)
        t = window(d, net_m, n_m, w_m, test).set_index("wallet_id")
        picked = s[s.dat_loc]
        all_test = t.net
        for k in (1, 5, 10):
            top = picked.head(k).wallet_id
            if not len(top):
                continue
            tt = t.loc[top]
            rows.append({"chon_tren": train_name, "kiem_tren": test_name, "so_vi_dat_loc": len(picked), "top": k,
                         "vi": " ".join(str(x) for x in top),
                         "net_kiem_tb": tt.net.mean(), "lai_kiem_pct": 100 * (tt.net > 0).mean(),
                         "wr_kiem_gop": 100 * tt.thang_loi.sum() / max(tt.lenh.sum(), 1),
                         "usd_moi_lenh_kiem": tt.net.sum() / max(tt.lenh.sum(), 1),
                         "net_kiem_trung_vi_moi_vi": all_test.median(),
                         "lai_kiem_pct_moi_vi": 100 * (all_test > 0).mean(),
                         "phan_vi_tb": float(np.mean([100 * (all_test < v).mean() for v in tt.net]))})
    wf = pd.DataFrame(rows).round(2)
    wf.to_csv(os.path.join(a.out, "sang_loc_walk_forward.csv"), index=False)

    # 2. the rule on all 9 months
    s = screen(d, net_m, n_m, w_m, months, nb)
    extra = d.set_index("wallet_id")[["engine_id", "profit_factor", "dd_equity_pct", "thua_lien_tiep",
                                      "net_T1_T6", "net_T7_T9", "wr_T1_T6", "wr_T7_T9"]]
    s = s.join(extra, on="wallet_id")
    s.round(3).to_csv(os.path.join(a.out, "sang_loc_9_thang.csv.gz"), index=False, compression="gzip")
    pd.set_option("display.width", 250)
    pd.set_option("display.max_colwidth", 110)
    print(wf.to_string(index=False))
    print("dat loc 9 thang:", int(s.dat_loc.sum()))
    cols = ["hang", "wallet_id", "phuong_phap", "huong", "phien", "lenh", "wr", "wr_lb", "profit_factor", "net",
            "thang_lai", "hang_xom_lai_pct", "net_T1_T6", "net_T7_T9", "cau_hinh"]
    print(s[s.dat_loc][cols].head(15).round(2).to_string(index=False))


if __name__ == "__main__":
    main()
