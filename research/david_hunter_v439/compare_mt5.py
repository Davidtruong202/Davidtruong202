"""Check the Python port against MT5: trades of the native reference account (wallet 0) versus Python.

In the MT5 run (EA 7PP, preset BO_KIEM_CHUNG_6PP) wallet 0 opens a real Tester order for every signal of the
6 base engines (= the rank-1 candidates), BUY_SELL, all sessions, 1 position per method. Python does the same
with wallet BUY_SELL/TAT_CA of each candidate, over the ticks it has (01/01 23:05 - 12/01/2026).
A trade matches when method, direction and entry second are equal. Money excludes swap (Python has no swap).
Writes results_mt5/doi_chieu_python_mt5.csv (per trade) and prints a summary per method.
Usage: python3 compare_mt5.py --mt5 /path/lenh_tham_chieu_MT5.csv
"""
import argparse
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dh import config as C  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.engine import Runner  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator  # noqa: E402
from validate import parse_cfg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def family_of(label):
    for fam in ("PVEMA", "EMA", "ICT", "SMC", "PIN", "LQ"):
        if label.startswith(fam):
            return fam
    return "?"


def mt5_positions(path):
    d = pd.read_csv(path, sep=";")
    d["time"] = pd.to_datetime(d.time, format="%Y.%m.%d %H:%M:%S")
    ins = d[d.entry_type == "DEAL_ENTRY_IN"].set_index("position_id")
    outs = d[d.entry_type == "DEAL_ENTRY_OUT"].groupby("position_id")
    pos = pd.DataFrame({
        "vao_luc": ins.time, "buy": ins.type == "DEAL_TYPE_BUY", "gia_vao": ins.price,
        "pp": ins.comment.str.split("|").str[2].map(family_of), "nhan": ins.comment.str.split("|").str[2]})
    pos["ra_luc"] = outs.time.max()
    pos["net_mt5"] = outs.profit.sum() + outs.commission.sum()
    pos["swap_mt5"] = outs.swap.sum()
    pos["ly_do_cuoi"] = outs.reason.last()
    return pos.reset_index()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mt5", default="/home/user/ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/lenh_tham_chieu_MT5.csv")
    ap.add_argument("--ticks", default="/home/user/ea-pro/data/tick/XAUUSDm_2026-01-01_2026-04-30/XAUUSDm_202601012305_202604301458.zip.part*")
    ap.add_argument("--cache-name", default="xauusdm_2026")
    ap.add_argument("--out", default=os.path.join(HERE, "results_mt5"))
    ap.add_argument("--warmup-end", default="2026-01-06")
    a = ap.parse_args()

    ticks, _ = load_ticks(a.ticks, a.cache_name)
    m = Market(ticks)
    runner = Runner(m, IndCache(m), TradeSimulator(m, C.make(), slippage=0.0))
    t_last = pd.to_datetime(m.ticks.t_ms[-1], unit="ms")
    rec = pd.read_csv(os.path.join(HERE, "results", "de_xuat_moi_pp.csv"))
    rec = rec[rec.hang == 1]

    py_rows = []
    for _, r in rec.iterrows():
        if r.pp == "MM":
            continue
        cfg = C.make(parse_cfg(r.pp, r.cau_hinh_ngan))
        _, sig, res, wallets = runner.run(r.pp, cfg, r.cau_hinh_ngan)
        idx = wallets[0]["idx"]  # BUY_SELL / TAT_CA
        py_rows.append(pd.DataFrame({
            "pp": r.pp, "vao_luc": pd.to_datetime(m.ticks.t_ms[sig["i0"][idx]], unit="ms").floor("s"),
            "buy": sig["buy"][idx].astype(bool), "gia_vao_py": res["p_entry"][idx],
            "ra_luc_py": pd.to_datetime(m.ticks.t_ms[res["exit_i"][idx]], unit="ms").floor("s"),
            "ket_thuc_py": pd.Series(res["reason"][idx]).map({0: "SL", 1: "TP2", 2: "HET_DU_LIEU"}).to_numpy(),
            "net_py": res["net"][idx] * runner.money_per_pt}))
    py = pd.concat(py_rows, ignore_index=True)
    py = py[py.ket_thuc_py != "HET_DU_LIEU"]

    mt = mt5_positions(a.mt5)
    mt = mt[(mt.vao_luc <= t_last) & (mt.ra_luc <= t_last)]
    both = mt.merge(py, on=["pp", "vao_luc", "buy"], how="outer", indicator=True)
    both["khop"] = both["_merge"].map({"both": "CA_HAI", "left_only": "CHI_MT5", "right_only": "CHI_PYTHON"})
    both = both.drop(columns="_merge").sort_values(["pp", "vao_luc"])
    both["lech_gia_vao"] = (both.gia_vao_py - both.gia_vao).round(3)
    both["lech_net"] = (both.net_py - both.net_mt5).round(2)
    os.makedirs(a.out, exist_ok=True)
    num = both.select_dtypes("number").columns
    both[num] = both[num].round(3)
    both.to_csv(os.path.join(a.out, "doi_chieu_python_mt5.csv"), index=False)

    # Python starts its indicators at the first tick, MT5 has earlier history: compare also after warm-up
    rows = []
    for part, sel in (("toan_bo", both), ("tu_" + a.warmup_end, both[both.vao_luc >= a.warmup_end])):
        for fam, g in sel.groupby("pp"):
            k = g[g.khop == "CA_HAI"]
            only_py = g[g.khop == "CHI_PYTHON"]
            rows.append({"giai_doan": part, "pp": fam, "lenh_mt5": int(g.net_mt5.notna().sum()),
                         "lenh_python": int(g.net_py.notna().sum()), "khop": len(k),
                         "ty_le_khop_pct": round(100 * len(k) / max(g.net_mt5.notna().sum(), 1), 1),
                         "chi_python_luc_21h": int((only_py.vao_luc.dt.hour == 21).sum()),
                         "net_mt5": round(g.net_mt5.sum(), 2), "net_python": round(g.net_py.sum(), 2),
                         "lenh_khop_lech_net_lon_hon_0_5": int((k.lech_net.abs() > 0.5).sum())})
    out = pd.DataFrame(rows)
    out.to_csv(os.path.join(a.out, "doi_chieu_python_mt5_tong.csv"), index=False)
    print(f"du lieu tick Python den {t_last}")
    print(out.to_string(index=False))


if __name__ == "__main__":
    main()
