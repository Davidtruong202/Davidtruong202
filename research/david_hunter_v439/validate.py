"""Stress tests for the recommended settings (results/de_xuat_moi_pp.csv) and the live benchmark:

1. entry slippage 0.30 (InpMatrixTruotGiaVao of the live SET) instead of 0;
2. random-timing null test: the same number of trades, the same BUY/SELL mix, SL distances and RR,
   but entered at random times of the same session. p_wr / p_net = share of random replicas that
   do at least as well. A small p means the entry timing adds something beyond "buying an uptrend";
   it is NOT corrected for the thousands of wallets searched, so treat it as a sanity check only.
3. full trade list of every recommended wallet (lenh_de_xuat.csv).
"""
import argparse
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dh import config as C  # noqa: E402
from dh.config import session_table  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.engine import Runner  # noqa: E402
from dh.matrix import DIR_NAMES, SES_NAMES  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator, simulate_many  # noqa: E402
from grids import GRIDS  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DIR_ID = {v: k for k, v in DIR_NAMES.items()}
SES_ID = {v: k for k, v in SES_NAMES.items()}


def parse_cfg(family, text):
    ov = {}
    types = {k: type(v[0]) for k, v in GRIDS[family].items()}
    for part in text.split(" | "):
        k, v = part.split("=", 1)
        t = types[k]
        if t is bool:
            ov[k] = v.lower() == "true"
        elif t is int:
            ov[k] = int(float(v))
        elif t is float:
            ov[k] = float(v)
        else:
            ov[k] = v
    return ov


def random_timing(m, sim, cfg, trades, ses, n_rep, rng, split_t=None):
    """trades: DataFrame with buy, risk, rr. Returns arrays (wr, net) of the random replicas."""
    tk = m.ticks
    ses_tab, _ = session_table(cfg)
    t0, t1 = int(tk.t[0]) + 3600, int(tk.t[-1]) - 4 * 3600
    n = len(trades)
    need = n * n_rep
    picks = []
    while len(picks) < need:
        ts = rng.integers(t0, t1, size=need * 3)
        idx = np.searchsorted(tk.t, ts, side="left")
        idx = idx[idx < len(tk.t) - 1]
        gap_ok = tk.t[idx] - ts[: len(idx)] <= 300
        hours = (tk.t[idx] % 86400) // 3600
        dow = (tk.t[idx] // 86400 + 4) % 7
        ok = gap_ok & (dow != 0) & (dow != 6)
        if ses != 0:
            ok &= np.array([ses_tab[h] for h in hours]) == ses
        picks.extend(idx[ok].tolist())
    i0 = np.array(picks[:need], np.int64)
    k = rng.integers(0, n, size=need)
    buy = trades.buy.to_numpy()[k].astype(np.bool_)
    risk = trades.risk.to_numpy()[k]
    rr = trades.rr.to_numpy()[k]
    tick = m.tick_size
    entry = np.where(buy, tk.ask[i0], tk.bid[i0])
    sgn = np.where(buy, 1.0, -1.0)
    sl = np.round(entry - sgn * risk, 3)
    tp2 = np.round(entry + sgn * rr * risk, 3)
    tp1 = np.round(entry + sgn * risk, 3)
    res = simulate_many(tk.bid, tk.ask, i0, buy, entry, sl, tp1, tp2, np.abs(entry - sl), tick,
                        sim.safety, sim.use_tp1, sim.part_frac, sim.use_trail, *sim.trail)
    net = res[1].reshape(n_rep, n) * sim.lot * m.contract
    return 100.0 * (net > 1e-8).mean(axis=1), net.sum(axis=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ticks", default="/home/user/ea-pro/data/XAUUSDm_202601012305_202604301458.zip.part*")
    ap.add_argument("--cache-name", default="xauusdm_2026")
    ap.add_argument("--res", default=os.path.join(HERE, "results"))
    ap.add_argument("--split", default="2026-01-08")
    ap.add_argument("--reps", type=int, default=1000)
    a = ap.parse_args()

    ticks, _ = load_ticks(a.ticks, a.cache_name)
    m = Market(ticks)
    ind = IndCache(m)
    base = C.make()
    split_t = int(pd.Timestamp(a.split).timestamp())
    sim0 = TradeSimulator(m, base, slippage=0.0)
    sim3 = TradeSimulator(m, base, slippage=0.30)
    r0 = Runner(m, ind, sim0, split_t=split_t)
    r3 = Runner(m, ind, sim3, split_t=split_t)
    rng = np.random.default_rng(20260929)

    rec = pd.read_csv(os.path.join(a.res, "de_xuat_moi_pp.csv"))
    items = []
    for _, r in rec[rec.hang > 0].iterrows():
        items.append((f"{r.pp}#{int(r.hang)}", r.pp, parse_cfg(r.pp, r.cau_hinh_ngan), DIR_ID[r.huong], SES_ID[r.phien],
                      r.cau_hinh_ngan))
    for name, (fam, ov, d, s) in C.LIVE_PROFILES.items():
        items.append(("LIVE_" + name, fam, ov, d, s, "|".join(f"{k}={v}" for k, v in ov.items())))

    rows, trade_rows = [], []
    for name, fam, ov, d, s, text in items:
        cfg = C.make(ov)
        w = d * 4 + s
        st0, sig, res, wallets = r0.run(fam, cfg, text)
        st3, *_ = r3.run(fam, cfg, text)
        idx = wallets[w]["idx"]
        tr = pd.DataFrame({
            "vao_luc": pd.to_datetime(m.ticks.t_ms[sig["i0"][idx]], unit="ms"),
            "ra_luc": pd.to_datetime(m.ticks.t_ms[res["exit_i"][idx]], unit="ms"),
            "buy": sig["buy"][idx], "gia_vao": res["p_entry"][idx], "sl": sig["sl"][idx], "tp1": res["tp1"][idx],
            "tp2": res["tp2"][idx], "risk": res["risk"][idx],
            "rr": np.abs(sig["tp"][idx] - sig["entry"][idx]) / np.abs(sig["entry"][idx] - sig["sl"][idx]),
            "ket_thuc": pd.Series(res["reason"][idx]).map({0: "SL", 1: "TP2", 2: "HET_DU_LIEU"}).to_numpy(),
            "da_chot_tp1": res["partial"][idx],
            "net_usd_0_02lot": res["net"][idx] * sim0.lot * m.contract})
        tr.insert(0, "ma", name)
        tr.insert(1, "pp", fam)
        trade_rows.append(tr)
        a0, a3 = st0[w], st3[w]
        wr_r, net_r = random_timing(m, sim0, cfg, tr, s, a.reps, rng) if len(tr) else (np.zeros(1), np.zeros(1))
        rows.append({"ma": name, "pp": fam, "huong": DIR_NAMES[d], "phien": SES_NAMES[s], "khung": a0["khung"],
                     "lenh": a0["lenh"], "wr": a0["wr"], "pf": a0["pf"], "net": a0["net"], "dd_tien": a0["dd_tien"],
                     "net_a": a0["net_a"], "net_b": a0["net_b"],
                     "lenh_truot_0_3": a3["lenh"], "wr_truot_0_3": a3["wr"], "pf_truot_0_3": a3["pf"],
                     "net_truot_0_3": a3["net"],
                     "ngau_nhien_wr_tv": float(np.median(wr_r)), "ngau_nhien_net_tv": float(np.median(net_r)),
                     "p_wr": float((wr_r >= a0["wr"] - 1e-9).mean()), "p_net": float((net_r >= a0["net"] - 1e-9).mean()),
                     "so_lan_ngau_nhien": a.reps, "cau_hinh": text})
    out = pd.DataFrame(rows)
    out.round(3).to_csv(os.path.join(a.res, "kiem_dinh_ung_vien.csv"), index=False)
    trades = pd.concat(trade_rows)
    num = trades.select_dtypes("number").columns
    trades[num] = trades[num].round(3)
    trades.to_csv(os.path.join(a.res, "lenh_de_xuat.csv"), index=False)
    pd.set_option("display.width", 250)
    print(out.drop(columns=["cau_hinh"]).round(2).to_string(index=False))


if __name__ == "__main__":
    main()
