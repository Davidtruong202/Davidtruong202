"""Run the V4.39 MATRIX grid for the not-yet-deployed methods on real ticks.

Usage:
  python3 run_matrix.py --ticks "/path/XAUUSDm_*.zip.part*" [--split 2026-01-08] [--families EMA,ICT]
Outputs (results/):
  wallets_all.csv.gz  one row per (configuration x direction x session) wallet
  run_info.json       data coverage and run parameters
"""
import argparse
import itertools
import json
import os
import sys
import time

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dh import config as C  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.engine import Runner  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator  # noqa: E402
from grids import GRIDS, valid  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def iter_grid(family):
    g = GRIDS[family]
    keys = list(g)
    for vals in itertools.product(*[g[k] for k in keys]):
        ov = dict(zip(keys, vals))
        cfg = C.make(ov)
        if valid(family, cfg):
            yield ov, cfg


def label(ov):
    return "|".join(f"{k}={v}" for k, v in ov.items())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ticks", default="/home/user/ea-pro/data/XAUUSDm_202601012305_202604301458.zip.part*")
    ap.add_argument("--cache-name", default="xauusdm_2026")
    ap.add_argument("--split", default="2026-01-08", help="dev/validation boundary (entry time)")
    ap.add_argument("--families", default=",".join(GRIDS))
    ap.add_argument("--capital", type=float, default=1000.0)
    ap.add_argument("--slippage", type=float, default=0.0, help="InpMatrixTruotGiaVao (0-0.30)")
    ap.add_argument("--out", default=os.path.join(HERE, "results"))
    a = ap.parse_args()

    os.makedirs(a.out, exist_ok=True)
    ticks, info = load_ticks(a.ticks, a.cache_name)
    m = Market(ticks)
    ind = IndCache(m)
    base = C.make()
    sim = TradeSimulator(m, base, slippage=a.slippage)
    split_t = int(pd.Timestamp(a.split).timestamp())
    runner = Runner(m, ind, sim, capital=a.capital, split_t=split_t)

    rows = []
    t0 = time.time()
    # benchmark: current live profiles (V4.52)
    for name, (fam, ov, d, s) in C.LIVE_PROFILES.items():
        r, *_ = runner.run(fam, C.make(ov), label(ov))
        for x in r:
            x["nhom"] = "LIVE_" + name if (x["vi"] == d * 4 + s) else "LIVE_KHAC"
            x["cau_hinh_id"] = name
        rows += r
    for fam in a.families.split(","):
        n = 0
        for ov, cfg in iter_grid(fam):
            r, *_ = runner.run(fam, cfg, label(ov))
            cid = f"{fam}{n:04d}"
            for x in r:
                x["nhom"] = "GRID"
                x["cau_hinh_id"] = cid
                for k, v in ov.items():
                    x[k] = v
            rows += r
            n += 1
        print(f"{fam}: {n} cau hinh x 12 vi, {time.time() - t0:.0f}s", flush=True)
    df = pd.DataFrame(rows)
    df.to_csv(os.path.join(a.out, "wallets_all.csv.gz"), index=False, compression="gzip")
    run_info = {"data": info, "split": a.split, "capital": a.capital, "slippage": a.slippage,
                "lot": base["InpGiaTriKhoiLuong"], "families": a.families, "configs": int(df["cau_hinh_id"].nunique()),
                "wallets": int(len(df)), "seconds": round(time.time() - t0, 1),
                "unique_trades_simulated": len(sim.cache)}
    with open(os.path.join(a.out, "run_info.json"), "w") as f:
        json.dump(run_info, f, indent=2, ensure_ascii=False)
    print(json.dumps(run_info, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
