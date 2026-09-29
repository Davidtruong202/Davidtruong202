"""Rebuild the trade list of MT5 wallets from the 9-month nen_M1.csv, then check it against MT5 month by month.

MT5 did not export per-wallet trades for this run (lenh_mo_phong.csv is 632 MB and was not uploaded), so the
Python port is replayed on ticks made from the M1 bars: each bar walks O -> L -> H -> C (bullish) or
O -> H -> L -> C (bearish) in steps of --step price, with the bar's spread. Real ticks move differently inside
the minute, so single trades differ; the check below says how far the monthly totals can be trusted.
Usage: python3 dung_lai_lenh_m1.py --run /path/RUN_folder --family EMA --wallets 166
"""
import argparse
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from analyze_mt5 import AXES, HERE, RUN_DEFAULT, parse_inputs  # noqa: E402
from dh import config as C  # noqa: E402
from dh.data import CACHE, Market, Ticks  # noqa: E402
from dh.engine import Runner  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator  # noqa: E402

TF_NAME = {1: "M1", 2: "M2", 3: "M3", 4: "M4", 5: "M5", 6: "M6", 10: "M10", 12: "M12", 15: "M15", 20: "M20",
           30: "M30", 16385: "H1", 16388: "H4"}
EXIT = {0: "SL", 1: "TP2", 2: "HET_DU_LIEU"}


def synthetic_ticks(run, step, cache_name):
    path = os.path.join(CACHE, f"{cache_name}.npz")
    if os.path.exists(path):
        z = np.load(path)
        return Ticks(z["t_ms"], z["bid"], z["ask"], cache_name)
    b = pd.read_csv(os.path.join(run, "nen_M1.csv"), sep=";")
    # explicit unit: pandas may parse to datetime64[us] or [s], so a plain astype("int64") is not always ns
    t0 = pd.to_datetime(b.time, format="%Y.%m.%d %H:%M:%S").to_numpy().astype("datetime64[ms]").astype(np.int64)
    o, h, lo, c = (b[k].to_numpy() for k in ("open", "high", "low", "close"))
    spread = b.spread_points.to_numpy() * 0.001
    t_all, bid_all, ask_all = [], [], []
    for i in range(len(b)):
        path_pts = [o[i], lo[i], h[i], c[i]] if c[i] >= o[i] else [o[i], h[i], lo[i], c[i]]
        seg = [np.array([path_pts[0]])]
        for a, z in zip(path_pts[:-1], path_pts[1:]):
            k = max(1, int(np.ceil(abs(z - a) / step)))
            seg.append(a + (z - a) * np.arange(1, k + 1) / k)
        p = np.round(np.concatenate(seg), 3)
        keep = np.r_[True, p[1:] != p[:-1]]
        p = p[keep]
        t_all.append(t0[i] + (np.arange(len(p)) * 59000) // max(len(p) - 1, 1))
        bid_all.append(p)
        ask_all.append(np.round(p + spread[i], 3))
    t_ms, bid, ask = np.concatenate(t_all), np.concatenate(bid_all), np.concatenate(ask_all)
    os.makedirs(CACHE, exist_ok=True)
    np.savez(path, t_ms=t_ms, bid=bid, ask=ask)
    return Ticks(t_ms, bid, ask, cache_name)


def engine_overrides(text, family):
    """Python overrides for one MT5 engine: every input of the family that Python knows, from toan_bo_input."""
    kv = parse_inputs(text)
    ov = {}
    for k, v in C.BASE.items():
        if k not in kv:
            continue
        raw = kv[k]
        if isinstance(v, bool):
            ov[k] = raw.lower() == "true" or raw == "1"
        elif isinstance(v, str) and (v in TF_NAME.values() or v == "CURRENT"):
            ov[k] = TF_NAME.get(int(float(raw)), v)
        elif isinstance(v, int):
            ov[k] = int(float(raw))
        elif isinstance(v, float):
            ov[k] = float(raw)
        else:
            ov[k] = raw
    return ov


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", default=RUN_DEFAULT)
    ap.add_argument("--family", default="EMA")
    ap.add_argument("--wallets", default="166", help="MT5 wallet ids whose trades are written out")
    ap.add_argument("--step", type=float, default=0.2)
    ap.add_argument("--out", default=os.path.join(HERE, "results_mt5"))
    a = ap.parse_args()

    ticks = synthetic_ticks(a.run, a.step, f"nen_m1_tick_gia_lap_{str(a.step).replace('.', '_')}")
    m = Market(ticks)
    sim = TradeSimulator(m, C.make(), slippage=0.0)
    runner = Runner(m, IndCache(m), sim)
    months_t = pd.to_datetime(m.ticks.t_ms, unit="ms")

    engines = pd.read_csv(os.path.join(a.run, "bo_cau_hinh.csv"), sep=";")
    engines = engines[engines.phuong_phap == a.family]
    want = {int(x) for x in a.wallets.split(",") if x}
    rows, trades = [], []
    for _, e in engines.iterrows():
        cfg = C.make(engine_overrides(e.toan_bo_input, a.family))
        _, sig, res, wallets = runner.run(a.family, cfg)
        for w in wallets:
            wid = 1 + int(e.engine_id) * 12 + w["dir"] * 4 + w["ses"]
            idx = w["idx"]
            net = res["net"][idx] * runner.money_per_pt
            exit_month = months_t[res["exit_i"][idx]].strftime("%Y%m").astype(int) if len(idx) else []
            per_m = pd.Series(net).groupby(np.asarray(exit_month)).sum() if len(idx) else pd.Series(dtype=float)
            n_m = pd.Series(np.ones(len(idx))).groupby(np.asarray(exit_month)).sum() if len(idx) else pd.Series(dtype=float)
            for mo in range(202601, 202610):
                rows.append({"wallet_id": wid, "thang": mo, "net_py": float(per_m.get(mo, 0.0)),
                             "lenh_py": int(n_m.get(mo, 0))})
            if wid in want and len(idx):
                t = pd.DataFrame({
                    "wallet_id": wid, "vao_luc": months_t[sig["i0"][idx]], "ra_luc": months_t[res["exit_i"][idx]],
                    "buy": sig["buy"][idx].astype(bool), "gia_vao": res["p_entry"][idx], "sl": sig["sl"][idx],
                    "risk": res["risk"][idx], "tp2": res["tp2"][idx],
                    "ket_thuc": pd.Series(res["reason"][idx]).map(EXIT).to_numpy(),
                    "da_chot_tp1": res["partial"][idx], "net_usd": net})
                trades.append(t)
    py = pd.DataFrame(rows)
    mt = pd.read_csv(os.path.join(a.run, "ket_qua_thang.csv"), sep=";")
    cmp_ = py.merge(mt[["wallet_id", "thang", "net_da_chot", "lenh_dong"]], on=["wallet_id", "thang"], how="left").fillna(0)
    cmp_ = cmp_.rename(columns={"net_da_chot": "net_mt5", "lenh_dong": "lenh_mt5"})
    os.makedirs(a.out, exist_ok=True)
    cmp_.round(3).to_csv(os.path.join(a.out, f"dung_lai_m1_{a.family}_theo_thang.csv"), index=False)
    tot = cmp_.groupby("wallet_id")[["net_py", "net_mt5", "lenh_py", "lenh_mt5"]].sum()
    print(f"{a.family}: {len(tot)} vi, tick gia lap {len(ticks):,}")
    print("tuong quan net thang (vi x thang):", round(np.corrcoef(cmp_.net_py, cmp_.net_mt5)[0, 1], 3))
    print("tuong quan net 9 thang (theo vi):", round(np.corrcoef(tot.net_py, tot.net_mt5)[0, 1], 3))
    print("cung dau net 9 thang:", round(100 * np.mean(np.sign(tot.net_py) == np.sign(tot.net_mt5)), 1), "%")
    print("lenh Python / MT5:", round(tot.lenh_py.sum() / max(tot.lenh_mt5.sum(), 1), 3))
    if trades:
        tr = pd.concat(trades)
        num = tr.select_dtypes("number").columns
        tr[num] = tr[num].round(3)
        tr.to_csv(os.path.join(a.out, f"dung_lai_m1_lenh_{a.family}.csv"), index=False)
        for wid in sorted(want):
            c = cmp_[cmp_.wallet_id == wid]
            print(f"vi {wid}: net Python {c.net_py.sum():.1f} ({int(c.lenh_py.sum())} lenh) | MT5 {c.net_mt5.sum():.1f} "
                  f"({int(c.lenh_mt5.sum())} lenh)")
            print("  thang Python:", c.net_py.round(0).astype(int).tolist())
            print("  thang MT5   :", c.net_mt5.round(0).astype(int).tolist())


if __name__ == "__main__":
    main()
