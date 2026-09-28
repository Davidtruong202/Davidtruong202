"""Stage 2 hypotheses on the trend/momentum family (one logic change per hypothesis).

H-A  H1 trend filter: trade only in the direction of the last COMPLETED H1 bar's
     EMA50 vs EMA200 with H1 ADX >= 20.  Roles: H1 = direction/regime,
     M5/M15 = entry trigger, M1 = execution.
H-B  Let winners run: max hold 192 signal bars instead of 48, TP 3R/5R.
Baseline for comparison = the same strategies from run_research.py.
Both cost models are evaluated (historical per-bar spread, fixed $10 spread).
The final test split is not touched.
"""
import json
import os

import pandas as pd

import data
import engine
import indicators as ind
from run_research import OUT, report, search, splits
from strategies import EXIT_GRID, STRATEGIES

FAMILY = ["G1_TREND", "G2_MOM", "H_EMA"]
TFS = {"M5": 5, "M15": 15}


def h1_filter_factory(m1):
    h1 = ind.add_features(data.resample(m1, "1h"))
    h1 = h1[["ema50", "ema200", "adx"]].copy()
    h1["avail"] = h1.index + pd.Timedelta(hours=1)  # H1 bar is known only after it closes
    trend = pd.Series(0, index=h1.index)
    trend[(h1.ema50 > h1.ema200) & (h1.adx >= 20)] = 1
    trend[(h1.ema50 < h1.ema200) & (h1.adx >= 20)] = -1
    h1["trend"] = trend
    h1 = h1.set_index("avail")[["trend"]].sort_index()

    def filt(f, d, mins):
        close_t = pd.DataFrame(index=f.index + pd.Timedelta(minutes=mins))
        mapped = pd.merge_asof(close_t, h1, left_index=True, right_index=True, direction="backward")
        tr = mapped["trend"].fillna(0).values
        return d.where(d.values == tr, 0)

    return filt


def main():
    m1 = data.load_m1()
    sp = splits(m1)
    dev_end, val_end = pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    h1f = h1_filter_factory(m1)
    rows = []
    for cost_tag, spread in (("hist", None), ("spread10", 10.0)):
        book = engine.M1Book(m1, spread_override=spread)
        for tf, mins in TFS.items():
            f = ind.add_features(data.resample(m1, f"{mins}min"))
            f = f[f.index < val_end]
            for name in FAMILY:
                pgrid = STRATEGIES[name][1]
                variants = {
                    "H-A_H1filter": dict(exit_grid=EXIT_GRID,
                                          sig_filter=lambda ff, d, m=mins: h1f(ff, d, m)),
                    "H-B_longhold": dict(exit_grid={"sl_atr": [1.0, 2.0], "rr": [3.0, 5.0]},
                                          hold_bars=192),
                }
                for vname, kw in variants.items():
                    _, b = search(book, f, name, pgrid, kw.pop("exit_grid"), mins, dev_end, val_end, **kw)
                    b.update({"tf": tf, "variant": vname, "cost": cost_tag})
                    print(f"[{cost_tag:8s} {vname:13s}] ", end="")
                    report(tf, name, b)
                    rows.append(b)
    pd.DataFrame(rows).to_csv(os.path.join(OUT, "hypotheses_dev_val.csv"), index=False)


if __name__ == "__main__":
    main()
