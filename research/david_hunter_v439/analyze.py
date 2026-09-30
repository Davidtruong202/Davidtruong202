"""Rank the grid wallets: profitable, highest win rate, stable across the dev/validation halves and
surrounded by profitable neighbouring inputs (plateau), per method and per timeframe.

Usage: python3 analyze.py [--res results] [--min-trades 10]
"""
import argparse
import json
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from grids import GRIDS  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def load(res):
    df = pd.read_csv(os.path.join(res, "wallets_all.csv.gz"), low_memory=False)
    for fam, g in GRIDS.items():
        for k, vals in g.items():
            if isinstance(vals[0], bool):
                df[k] = df[k].map({"True": True, "False": False, True: True, False: False})
    return df


def neighbours(df_fam, family):
    """Plateau score: share of 1-step neighbours (one axis moved to the adjacent grid value, same wallet)
    that are profitable, and their median net."""
    axes = list(GRIDS[family])
    pos = {k: {v: i for i, v in enumerate(GRIDS[family][k])} for k in axes}
    key_cols = axes + ["vi"]
    idx = {}
    for r in df_fam[key_cols + ["net"]].itertuples(index=False):
        key = tuple(pos[a][getattr(r, a)] for a in axes) + (r.vi,)
        idx[key] = r.net
    share, med, cnt = [], [], []
    for r in df_fam[key_cols].itertuples(index=False):
        base = [pos[a][getattr(r, a)] for a in axes]
        nets = []
        for j, a in enumerate(axes):
            for step in (-1, 1):
                nb = list(base)
                nb[j] += step
                if 0 <= nb[j] < len(GRIDS[family][a]):
                    v = idx.get(tuple(nb) + (r.vi,))
                    if v is not None:
                        nets.append(v)
        cnt.append(len(nets))
        share.append(100.0 * np.mean([x > 0 for x in nets]) if nets else np.nan)
        med.append(float(np.median(nets)) if nets else np.nan)
    out = df_fam.copy()
    out["hang_xom"] = cnt
    out["hang_xom_lai_pct"] = share
    out["hang_xom_net_tv"] = med
    return out


def fmt(v):
    if isinstance(v, (bool, np.bool_)):
        return "true" if v else "false"
    if isinstance(v, (float, np.floating)) and float(v).is_integer():
        return str(int(v))
    return str(v)


def short_cfg(row, family):
    return " | ".join(f"{k}={fmt(row[k])}" for k in GRIDS[family])


def wilson_lb(wins, n, z=1.96):
    """Lower bound of the 95% Wilson interval of the win rate (in %): high WR on few trades is penalised."""
    n = np.maximum(np.asarray(n, float), 1e-12)
    p = np.clip(np.asarray(wins, float) / n, 0.0, 1.0)
    lb = (p + z * z / (2 * n) - z * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n))) / (1 + z * z / n)
    return np.where(n >= 1, 100.0 * lb, 0.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", default=os.path.join(HERE, "results"))
    ap.add_argument("--min-trades", type=int, default=10)
    ap.add_argument("--min-half", type=int, default=3)
    ap.add_argument("--min-pf", type=float, default=1.3)
    a = ap.parse_args()
    df = load(a.res)
    grid = df[df.nhom == "GRID"].copy()
    fams = [f for f in GRIDS if f in set(grid.pp)]

    # ---------- per family overview (wallet BUY_SELL / all sessions, i.e. the plain EA setting)
    over = []
    for fam in fams:
        d = grid[grid.pp == fam]
        d0 = d[d.vi == 0]
        over.append({"pp": fam, "so_cau_hinh": d.cau_hinh_id.nunique(), "so_vi": len(d),
                     "lenh_tv_vi0": d0.lenh.median(), "cau_hinh_lai_pct_vi0": 100 * (d0.net > 0).mean(),
                     "net_tv_vi0": d0.net.median(), "wr_tv_vi0": d0.wr.median(),
                     "vi_lai_pct_moi_huong_phien": 100 * (d[d.lenh >= a.min_trades].net > 0).mean()})
    pd.DataFrame(over).round(2).to_csv(os.path.join(a.res, "tong_quan_pp.csv"), index=False)

    # ---------- plateau + robust filters
    parts = []
    for fam in fams:
        parts.append(neighbours(grid[grid.pp == fam], fam))
    g2 = pd.concat(parts)
    g2["wr_lb"] = wilson_lb(g2.thang, g2.lenh)
    ok = ((g2.lenh >= a.min_trades) & (g2.net > 0) & (g2.pf >= a.min_pf) &
          (g2.lenh_a >= a.min_half) & (g2.lenh_b >= a.min_half) & (g2.net_a > 0) & (g2.net_b > 0))
    g2["dat_loc"] = ok
    g2["cau_hinh_ngan"] = [short_cfg(r, r.pp) for _, r in g2.iterrows()]
    # identical trade sets (inputs that changed nothing, or a BUY-only wallet equal to BUY_SELL) are
    # collapsed into one row; sorting by wallet id first keeps the more general BUY_SELL wallet
    g2 = g2.sort_values("vi", kind="stable")
    g2["_sig"] = (g2.pp + "|" + g2.phien + "|" + g2.lenh.astype(str) + "|" +
                  g2.thang.astype(str) + "|" + g2.net.round(4).astype(str))
    g2["so_bo_trung_ket_qua"] = g2.groupby("_sig")["_sig"].transform("size")
    cols = ["pp", "cau_hinh_id", "khung", "huong", "phien", "lenh", "thang", "thua", "wr", "wr_lb", "pf", "net",
            "avg_r", "dd_tien", "thua_lien_tiep", "lenh_a", "wr_a", "net_a", "lenh_b", "wr_b", "net_b", "tp2",
            "be_trail", "sl_goc", "hang_xom", "hang_xom_lai_pct", "hang_xom_net_tv", "so_bo_trung_ket_qua",
            "cau_hinh_ngan"]
    cand = g2[g2.dat_loc].sort_values(["pp", "wr_lb", "net", "vi"], ascending=[True, False, False, True])
    cand = cand.drop_duplicates("_sig")
    cand[cols].round(3).to_csv(os.path.join(a.res, "ung_vien_dat_loc.csv"), index=False)

    # ---------- recommendation per family: best Wilson lower bound of WR among filtered wallets whose
    # 1-step neighbourhood is mostly profitable (plateau), so a lucky isolated input is not picked
    rec = []
    for fam in fams:
        c = cand[cand.pp == fam]
        c_plateau = c[c.hang_xom_lai_pct >= 60]
        pick = c_plateau if len(c_plateau) else c
        if len(pick):
            top = pick.sort_values(["wr_lb", "net"], ascending=False).head(3)
            for rank, (_, r) in enumerate(top.iterrows(), 1):
                rec.append({**{k: r[k] for k in cols}, "hang": rank,
                            "tieu_chi": "plateau>=60%" if len(c_plateau) else "khong co plateau"})
        else:
            rec.append({"pp": fam, "hang": 0, "tieu_chi": "KHONG CO CAU HINH DAT LOC"})
    pd.DataFrame(rec).round(3).to_csv(os.path.join(a.res, "de_xuat_moi_pp.csv"), index=False)

    # ---------- per family x timeframe
    tf_rows = []
    for fam in fams:
        d = g2[g2.pp == fam]
        for tf, dt in d.groupby("khung"):
            d0 = dt[dt.vi == 0]
            ct = dt[dt.dat_loc]
            best = ct.sort_values(["wr_lb", "net"], ascending=False).head(1)
            tf_rows.append({
                "pp": fam, "khung": tf, "so_cau_hinh": dt.cau_hinh_id.nunique(),
                "vi0_lai_pct": round(100 * (d0.net > 0).mean(), 1), "vi0_net_tv": round(d0.net.median(), 2),
                "vi0_wr_tv": round(d0.wr.median(), 1), "vi0_lenh_tv": d0.lenh.median(), "so_vi_dat_loc": len(ct),
                "tot_nhat_wr": None if best.empty else round(best.wr.iloc[0], 1),
                "tot_nhat_wr_lb": None if best.empty else round(best.wr_lb.iloc[0], 1),
                "tot_nhat_pf": None if best.empty else round(best.pf.iloc[0], 2),
                "tot_nhat_net": None if best.empty else round(best.net.iloc[0], 2),
                "tot_nhat_lenh": None if best.empty else int(best.lenh.iloc[0]),
                "tot_nhat_vi": None if best.empty else f"{best.huong.iloc[0]}/{best.phien.iloc[0]}",
                "tot_nhat_cau_hinh": None if best.empty else best.cau_hinh_ngan.iloc[0]})
    order = {tf: i for i, tf in enumerate(["M1", "M2", "M3", "M4", "M5", "M6", "M10", "M12", "M15", "M20", "M30", "H1"])}
    tfd = pd.DataFrame(tf_rows)
    tfd["_o"] = tfd.khung.map(order)
    tfd.sort_values(["pp", "_o"]).drop(columns="_o").to_csv(os.path.join(a.res, "theo_khung_tf.csv"), index=False)

    # ---------- live benchmark
    live = df[df.nhom.str.startswith("LIVE_") & (df.nhom != "LIVE_KHAC")]
    live[["nhom", "pp", "khung", "huong", "phien", "lenh", "thang", "thua", "wr", "pf", "net", "dd_tien", "lenh_a",
          "net_a", "lenh_b", "net_b"]].round(3).to_csv(os.path.join(a.res, "doi_chung_4pp_live.csv"), index=False)

    summary = {"so_vi_dat_loc": int(g2.dat_loc.sum()), "theo_pp": cand.groupby("pp").size().to_dict(),
               "tieu_chi": {"lenh_toi_thieu": a.min_trades, "pf_toi_thieu": a.min_pf,
                            "lenh_toi_thieu_moi_nua": a.min_half, "lai_ca_2_nua": True}}
    with open(os.path.join(a.res, "tom_tat_loc.json"), "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
