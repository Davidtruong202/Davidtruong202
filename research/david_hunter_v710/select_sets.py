"""Chọn ứng viên từ kết quả giả lập và sinh biến thể quanh ứng viên tốt (vòng tinh chỉnh).

python3 select_sets.py rank   kq.csv [maxdd_abs]       -> in bảng xếp hạng
python3 select_sets.py top    kq.csv sets.csv N out.csv -> lấy N set tốt nhất (theo điểm) ra file set mới
python3 select_sets.py mutate kq.csv sets.csv K M seed out.csv -> K set tốt nhất, mỗi set M biến thể
"""
import random
import sys

import pandas as pd

from gen_sets import COLS, rnd, write

STEPS = {
    "Hand_FirstDist": 10, "Hand_MinDist1": 10, "Hand_AddGap1": 10, "Hand_MinDist2": 20, "Hand_AddGap2": 20,
    "Hand_OrderThresh": 1, "Hand_MoveStep": 10, "Hand_SideTP": 25, "Hand_SideSL": 100, "Hand_AllStopLoss": 25,
    "Hand_PauseLoss": 100, "NetClosePL": 25, "InpBasketMaxLoss": 100, "InpDailyLossLimit": 100,
    "DailyProfitTarget": 100,
}


def score(df, maxdd_abs=3000.0):
    """Điểm = lãi ròng / max DD, chỉ xét bộ không cháy, đủ lệnh, DD ≤ ngưỡng, PF > 1."""
    d = df.copy()
    ok = (d.blown == 0) & (d.trades >= 200) & (d.maxdd <= maxdd_abs) & (d.pf > 1.0) & (d.net > 0)
    d["rf"] = d.net / d.maxdd.clip(lower=1)
    d["score"] = d.rf.where(ok, -1e9)
    return d.sort_values("score", ascending=False)


def load_sets(path):
    s = pd.read_csv(path, dtype=str)
    return s.set_index("name")


def mutate(row, r, k=3):
    d = dict(row)
    keys = r.sample(list(STEPS) + ["Hand_AddLotMult", "EA_StartTime", "EA_StopTime", "InpHardSLATR", "InpMaxLayers",
                                   "InpMaxTotalLots", "InpPeakRetracePct", "MaxLot", "InpSpikeEnable"], k)
    alt = rnd(r)
    for key in keys:
        if key in STEPS:
            v = float(d[key])
            if v == 0 and key in ("NetClosePL", "InpBasketMaxLoss", "InpDailyLossLimit", "DailyProfitTarget"):
                d[key] = alt[key]
                continue
            v = v + STEPS[key] * r.choice([-2, -1, 1, 2])
            v = max(STEPS[key], v)
            d[key] = int(v) if float(v).is_integer() else v
        elif key in ("EA_StartTime", "EA_StopTime"):
            h = int(str(d[key])[:2]) + r.choice([-1, 1])
            h = max(0, min(10, h)) if key == "EA_StartTime" else max(11, min(23, h))
            d[key] = "%02d:00" % h
        else:
            d[key] = alt[key]
    return d


def main():
    cmd = sys.argv[1]
    df = pd.read_csv(sys.argv[2])
    if cmd == "rank":
        mdd = float(sys.argv[3]) if len(sys.argv) > 3 else 3000
        d = score(df, mdd)
        pd.set_option("display.width", 250)
        cols = ["name", "net", "pf", "trades", "win_pct", "maxdd", "maxdd_pct", "worst_day", "win_days_pct", "rf"]
        cols += [c for c in d.columns if c.startswith("m_")]
        print(d[cols].head(40).to_string(index=False))
        print("đạt điều kiện:", int((d.score > -1e9).sum()), "/", len(d))
        return
    sets = load_sets(sys.argv[3])
    if cmd == "top":
        n, out = int(sys.argv[4]), sys.argv[5]
        names = list(score(df).name.head(n))
        rows = [dict(sets.loc[nm], name=nm) for nm in names]
        with open(out, "w") as f:
            write(rows, f)
    elif cmd == "mutate":
        k, m, seed, out = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), sys.argv[7]
        r = random.Random(seed)
        names = list(score(df).name.head(k))
        rows = []
        for nm in names:
            base = dict(sets.loc[nm], name=nm)
            rows.append(base)
            for j in range(m):
                d = mutate(base, r)
                d["name"] = "%s_m%d_%02d" % (nm, seed, j)
                rows.append(d)
        with open(out, "w") as f:
            write(rows, f)


if __name__ == "__main__":
    main()
