"""Read the MT5 output of EA 7PP (preset BO_KIEM_CHUNG_6PP) and answer three questions:

1. Did the 6 candidates chosen on 6.5 days of ticks (results/de_xuat_moi_pp.csv) hold up over 9 months?
2. Across all 2568 wallets (6 families x neighbour grid x 3 directions x 4 sessions), does choosing on
   months 1-6 (T1-T6) pick wallets that also win in months 7-9 (T7-T9)?  Money per month is by closing date.
3. Which input values, directions and sessions are better or worse in both halves?

Writes results_mt5/*.csv and tom_tat.json. Usage: python3 analyze_mt5.py --run /path/to/RUN_folder
"""
import argparse
import json
import os
import re

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
RUN_DEFAULT = "/home/user/ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP"
SPLIT_MONTH = 202607  # T7-T9 = out-of-sample
MIN_TRAIN_TRADES = 30
# grid axes of the verification preset (make_ea_7pp.py / make_sets.NEIGHBOUR); TF inputs are MT5 enum codes
AXES = {
    "EMA": ["InpTimeframe", "InpFastEMA", "InpSlowEMA", "InpEMAKhungLoc", "InpMinDirectionEfficiency"],
    "ICT": ["InpICTEntryTF", "InpICTBiasTF", "InpICTDisplacementATR", "InpICTPriority"],
    "SMC": ["InpSMCEntryTF", "InpSMCBiasTF", "InpSMCDisplacementATR", "InpSMCDungLocEMAH1", "InpSMCDungLocRSI"],
    "PVEMA": ["InpPVKhungVaoLenh", "InpPVKhungXuHuong", "InpPVADXToiThieu", "InpPVSoNenTimSL"],
    "PIN": ["InpPVKhungPinBar", "InpPVRauChinhTrenThan", "InpPVPinQuetSoNen", "InpPVSoNenTimSL"],
    "LQ": ["InpPVKhungQuetThanhKhoan", "InpPVDoXuyenToiThieuGia", "InpPVDoXuyenToiDaGia", "InpPVSoNenThanhKhoan",
           "InpPVRauQuetTrenThan"],
}
TF_NAME = {"1": "M1", "2": "M2", "3": "M3", "4": "M4", "5": "M5", "6": "M6", "10": "M10", "12": "M12", "15": "M15",
           "20": "M20", "30": "M30", "16385": "H1", "16388": "H4"}
TF_AXES = {"InpTimeframe", "InpEMAKhungLoc", "InpICTEntryTF", "InpICTBiasTF", "InpSMCEntryTF", "InpSMCBiasTF",
           "InpPVKhungVaoLenh", "InpPVKhungXuHuong", "InpPVKhungPinBar", "InpPVKhungQuetThanhKhoan"}


def read(run, name):
    return pd.read_csv(os.path.join(run, name + ".csv"), sep=";")


def parse_inputs(text):
    """'InpA=1|InpB=x|y|InpC=2' -> dict; values may contain '|' (grid strings)."""
    kv, last = {}, None
    for tok in text.split("|"):
        m = re.match(r"^(Inp\w+)=(.*)$", tok)
        if m:
            last = m.group(1)
            kv[last] = m.group(2)
        elif last:
            kv[last] += "|" + tok
    return kv


def nice(axis, value):
    if axis in TF_AXES:
        return TF_NAME.get(value, value)
    try:
        f = float(value)
        return str(int(f)) if f == int(f) else f"{f:g}"
    except ValueError:
        return value


def spearman(a, b):
    a, b = pd.Series(a).rank(), pd.Series(b).rank()
    return float(np.corrcoef(a, b)[0, 1]) if len(a) > 2 else float("nan")


def load(run):
    engines = read(run, "bo_cau_hinh")
    rows = []
    for _, r in engines.iterrows():
        kv = parse_inputs(r.toan_bo_input)
        row = {"engine_id": r.engine_id, "loai": r.loai}
        for ax in AXES[r.phuong_phap]:
            row[ax] = nice(ax, kv[ax])
        row["cau_hinh"] = " | ".join(f"{ax}={row[ax]}" for ax in AXES[r.phuong_phap])
        rows.append(row)
    eng = pd.DataFrame(rows)
    rank = read(run, "xep_hang")
    month = read(run, "ket_qua_thang")
    net_m = month.pivot_table(index="wallet_id", columns="thang", values="net_da_chot", aggfunc="sum").fillna(0.0)
    n_m = month.pivot_table(index="wallet_id", columns="thang", values="lenh_dong", aggfunc="sum").fillna(0)
    w_m = month.pivot_table(index="wallet_id", columns="thang", values="lenh_thang", aggfunc="sum").fillna(0)
    tr = [c for c in net_m.columns if c < SPLIT_MONTH]
    te = [c for c in net_m.columns if c >= SPLIT_MONTH]
    d = rank.set_index("wallet_id")[["engine_id", "phuong_phap", "huong", "phien", "lenh_dong", "winrate_pct",
                                     "profit_factor", "net", "dd_equity_pct", "thua_lien_tiep", "swap_uoc_tinh",
                                     "danh_gia"]].copy()
    d["lenh_T1_T6"], d["lenh_T7_T9"] = n_m[tr].sum(axis=1), n_m[te].sum(axis=1)
    d["wr_T1_T6"] = 100 * w_m[tr].sum(axis=1) / d.lenh_T1_T6.clip(lower=1)
    d["wr_T7_T9"] = 100 * w_m[te].sum(axis=1) / d.lenh_T7_T9.clip(lower=1)
    d["net_T1_T6"], d["net_T7_T9"] = net_m[tr].sum(axis=1), net_m[te].sum(axis=1)
    d["thang_lai"] = (net_m > 0).sum(axis=1)
    for c in net_m.columns:
        d[f"net_{c}"] = net_m[c]
    d = d.reset_index()
    port = d[d.phuong_phap == "PORTFOLIO_GOC"]
    d = d[d.phuong_phap != "PORTFOLIO_GOC"].merge(eng, on="engine_id")
    return d, port, list(net_m.columns)


def market_months(run):
    b = read(run, "nen_M1")
    b["time"] = pd.to_datetime(b.time, format="%Y.%m.%d %H:%M:%S")
    b = b[b.time >= "2026-01-01"]
    b["thang"] = b.time.dt.strftime("%Y%m").astype(int)
    b["ngay"] = b.time.dt.date
    day = b.groupby("ngay").agg(h=("high", "max"), l=("low", "min"), thang=("thang", "first"))
    g = b.groupby("thang").agg(mo_cua=("open", "first"), cao=("high", "max"), thap=("low", "min"),
                               dong_cua=("close", "last"), spread_tv_point=("spread_points", "median"))
    g["thay_doi_pct"] = 100 * (g.dong_cua / g.mo_cua - 1)
    g["bien_do_ngay_tv"] = (day.h - day.l).groupby(day.thang).median()
    return g.reset_index().round(2)


def per_trade(q, part):
    return q[f"net_{part}"].sum() / max(q[f"lenh_{part}"].sum(), 1)


def cell_table(d, keys):
    rows = []
    for k, q in d.groupby(keys):
        rows.append(dict(zip(keys, k if isinstance(k, tuple) else (k,)),
                         vi=len(q), lenh_tb=round(q.lenh_dong.mean(), 1),
                         usd_moi_lenh_T1_T6=per_trade(q, "T1_T6"), usd_moi_lenh_T7_T9=per_trade(q, "T7_T9"),
                         vi_lai_T1_T6_pct=100 * (q.net_T1_T6 > 0).mean(), vi_lai_T7_T9_pct=100 * (q.net_T7_T9 > 0).mean(),
                         vi_lai_9_thang_pct=100 * (q.net > 0).mean()))
    return pd.DataFrame(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", default=RUN_DEFAULT)
    ap.add_argument("--out", default=os.path.join(HERE, "results_mt5"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.run, "thong_tin_run.csv"), encoding="utf-8") as f:  # free text may contain ';'
        info = dict(line.rstrip("\r\n").split(";", 1) for line in f.readlines()[1:] if ";" in line)
    d, port, months = load(a.run)
    mcols = [f"net_{c}" for c in months]

    # 0. market by month
    market_months(a.run).to_csv(os.path.join(a.out, "thi_truong_theo_thang.csv"), index=False)

    # 1. the 6 candidates: Python 6.5 days vs MT5 9 months
    cand = read(a.run, "ket_qua_ung_vien")
    c = cand[["phuong_phap", "wallet_id", "huong", "phien", "input_goc_ung_vien", "so_sanh_python"]].merge(
        d[["wallet_id", "lenh_dong", "winrate_pct", "profit_factor", "net", "dd_equity_pct", "thang_lai",
           "net_T1_T6", "net_T7_T9", "lenh_T7_T9", "wr_T7_T9"] + mcols], on="wallet_id")
    c.round(2).to_csv(os.path.join(a.out, "ung_vien_6_5_ngay_qua_9_thang.csv"), index=False)

    # 2. every wallet with decoded inputs
    keep = ["wallet_id", "engine_id", "loai", "phuong_phap", "huong", "phien", "cau_hinh", "lenh_dong", "winrate_pct",
            "profit_factor", "net", "dd_equity_pct", "thua_lien_tiep", "thang_lai", "lenh_T1_T6", "wr_T1_T6",
            "net_T1_T6", "lenh_T7_T9", "wr_T7_T9", "net_T7_T9", "swap_uoc_tinh", "danh_gia"] + mcols
    d.sort_values("net", ascending=False)[keep].round(3).to_csv(
        os.path.join(a.out, "tat_ca_vi_9_thang.csv.gz"), index=False, compression="gzip")

    # 3. per family: overall, and does T1-T6 predict T7-T9?
    fam_rows, pick_rows = [], []
    for fam, q in d.groupby("phuong_phap"):
        s = q[q.lenh_T1_T6 >= MIN_TRAIN_TRADES]
        win_tr, lose_tr = s[s.net_T1_T6 > 0], s[s.net_T1_T6 <= 0]
        top = s.sort_values("net_T1_T6", ascending=False).head(5)
        best = q.loc[q.net.idxmax()]
        fam_rows.append({
            "pp": fam, "vi": len(q), "vi_lai_9_thang": int((q.net > 0).sum()),
            "vi_lai_9_thang_pct": 100 * (q.net > 0).mean(), "net_trung_vi": q.net.median(),
            "wr_trung_vi": q.winrate_pct.median(), "pf_trung_vi": q.profit_factor.median(),
            "lenh_trung_vi": q.lenh_dong.median(), "usd_moi_lenh": q.net.sum() / q.lenh_dong.sum(),
            "vi_tot_nhat": int(best.wallet_id), "vi_tot_nhat_net": best.net, "vi_tot_nhat_wr": best.winrate_pct,
            "vi_tot_nhat_huong_phien": f"{best.huong}/{best.phien}",
            "tuong_quan_hang_T1T6_T7T9": spearman(s.net_T1_T6, s.net_T7_T9),
            # net also ranks trade count (more trades = bigger loss when every setting loses); per trade does not
            "tuong_quan_hang_usd_moi_lenh": spearman(s.net_T1_T6 / s.lenh_T1_T6,
                                                     s.net_T7_T9 / s.lenh_T7_T9.clip(lower=1)),
            "lai_T7T9_khi_lai_T1T6_pct": 100 * (win_tr.net_T7_T9 > 0).mean() if len(win_tr) else np.nan,
            "lai_T7T9_khi_lo_T1T6_pct": 100 * (lose_tr.net_T7_T9 > 0).mean() if len(lose_tr) else np.nan,
            "net_T7T9_trung_vi_ca_pp": s.net_T7_T9.median(), "net_T7T9_tb_top5_T1T6": top.net_T7_T9.mean()})
        for i, (_, r) in enumerate(top.iterrows(), 1):
            pick_rows.append({"pp": fam, "hang_T1_T6": i, "wallet_id": r.wallet_id, "huong": r.huong, "phien": r.phien,
                              "cau_hinh": r.cau_hinh, "lenh_T1_T6": r.lenh_T1_T6, "wr_T1_T6": r.wr_T1_T6,
                              "net_T1_T6": r.net_T1_T6, "lenh_T7_T9": r.lenh_T7_T9, "wr_T7_T9": r.wr_T7_T9,
                              "net_T7_T9": r.net_T7_T9,
                              "phan_vi_T7_T9_trong_pp": 100 * (s.net_T7_T9 < r.net_T7_T9).mean()})
    pd.DataFrame(fam_rows).round(2).to_csv(os.path.join(a.out, "tong_quan_pp_9_thang.csv"), index=False)
    pd.DataFrame(pick_rows).round(2).to_csv(os.path.join(a.out, "chon_T1_T6_kiem_T7_T9.csv"), index=False)

    # 4. direction x session cells, pooled over the input grid; ranked on T1-T6 only
    cells = cell_table(d, ["phuong_phap", "huong", "phien"]).sort_values("usd_moi_lenh_T1_T6", ascending=False)
    cells.insert(3, "hang_T1_T6", np.arange(1, len(cells) + 1))
    cells.round(2).to_csv(os.path.join(a.out, "o_huong_phien.csv"), index=False)

    # 5. one input axis at a time (all other axes, directions and sessions pooled)
    ax_rows = []
    for fam, axes in AXES.items():
        q = d[d.phuong_phap == fam]
        for ax in axes + ["huong", "phien"]:
            t = cell_table(q, [ax]).rename(columns={ax: "gia_tri"})
            t.insert(0, "truc", ax)
            t.insert(0, "pp", fam)
            ax_rows.append(t)
    pd.concat(ax_rows).round(2).to_csv(os.path.join(a.out, "truc_input.csv"), index=False)

    # 6. top 30 over 9 months (in-sample: for reference only)
    d.sort_values("net", ascending=False).head(30)[keep].round(2).to_csv(
        os.path.join(a.out, "top30_9_thang_tham_khao.csv"), index=False)

    split_cells = cells[(cells.huong != "BUY_SELL") & (cells.phien != "TAT_CA")]
    summary = {
        "run": {k: info.get(k) for k in ("version", "preset", "status", "symbol", "server", "first_tick", "last_tick",
                                         "engines", "wallets", "holdout_entry_date", "reference_quality",
                                         "native_operation_errors", "native_request_count", "native_net_minus_shadow_net",
                                         "swap_model", "entry_slippage_price")},
        "chia_du_lieu": {"T1_T6": f"{months[0]}-{SPLIT_MONTH - 1}", "T7_T9": f"{SPLIT_MONTH}-{months[-1]}",
                         "lenh_T1_T6_toi_thieu": MIN_TRAIN_TRADES},
        "vi": int(len(d)), "vi_lai_9_thang": int((d.net > 0).sum()),
        "vi_lai_ca_hai_nua": int(((d.net_T1_T6 > 0) & (d.net_T7_T9 > 0)).sum()),
        "danh_gia_EA": d.danh_gia.value_counts().to_dict(),
        "ung_vien_lai_9_thang": int((c.net > 0).sum()),
        "o_huong_phien_tach": int(len(split_cells)),
        "o_lai_T1_T6": int((split_cells.usd_moi_lenh_T1_T6 > 0).sum()),
        "o_lai_T7_T9": int((split_cells.usd_moi_lenh_T7_T9 > 0).sum()),
        "o_lai_ca_hai": int(((split_cells.usd_moi_lenh_T1_T6 > 0) & (split_cells.usd_moi_lenh_T7_T9 > 0)).sum()),
        "danh_muc_goc_net": float(port.net.iloc[0]) if len(port) else None,
    }
    with open(os.path.join(a.out, "tom_tat.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2, default=str)

    pd.set_option("display.width", 250)
    print(c[["phuong_phap", "huong", "phien", "lenh_dong", "winrate_pct", "profit_factor", "net", "net_T1_T6",
             "net_T7_T9", "thang_lai"]].round(2).to_string(index=False))
    print(pd.DataFrame(fam_rows).drop(columns=["vi_tot_nhat_huong_phien"]).round(2).to_string(index=False))
    print(json.dumps(summary, ensure_ascii=False, indent=1, default=str))


if __name__ == "__main__":
    main()
