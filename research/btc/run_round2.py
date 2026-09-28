"""Round 2 search (EMA family + new methods) on dev, checked on validation.

Protocol identical to run_research.py (same splits, same selection and finalist rule).
Signal timeframes: M5, M15, H1 (M1 dropped: round 1 showed costs exceed any edge).
H1 as a SIGNAL timeframe is new; the H1 trend filter (E2) uses the last closed H1 bar.
Cost model: historical per-bar spread AND fixed $10 spread.
The final test split is not touched.
"""
import os

import pandas as pd

import data
import engine
import indicators as ind
from run_hypotheses import h1_filter_factory
from run_research import OUT, report, search, splits
from strategies2 import EXITS2, HOLD, STRATEGIES2, USES_H1_FILTER, build, valid_params

TFS = {"M5": 5, "M15": 15, "H1": 60}


def main():
    m1 = data.load_m1()
    sp = splits(m1)
    dev_end, val_end = pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    h1f = h1_filter_factory(m1)
    feats = {}
    for tf, mins in TFS.items():
        f = ind.add_features(data.resample(m1, f"{mins}min"))
        feats[tf] = f[f.index < val_end]
    rows, grids = [], []
    for cost, spread in (("hist", None), ("spread10", 10.0)):
        book = engine.M1Book(m1, spread_override=spread)
        for tf, mins in TFS.items():
            f = feats[tf]
            for name, (_, pgrid) in STRATEGIES2.items():
                if name == "N1_NYORB" and tf == "H1":
                    continue  # 09:30 NY range is not aligned to H1 bars
                if name in USES_H1_FILTER and tf == "H1":
                    continue  # filter on its own timeframe is redundant
                filt = (lambda ff, d, m=mins: h1f(ff, d, m)) if name in USES_H1_FILTER else None
                for exname, exgrid in EXITS2.items():
                    df, b = search(book, f, name, pgrid, exgrid, mins, dev_end, val_end,
                                   hold_bars=HOLD[exname], sig_filter=filt, builder=build,
                                   param_ok=valid_params)
                    for x in (b,):
                        x.update({"tf": tf, "exit": exname, "cost": cost})
                    df["tf"], df["exit"], df["cost"] = tf, exname, cost
                    grids.append(df)
                    rows.append(b)
                    print(f"[{cost:8s} {exname:5s}] ", end="")
                    report(tf, name, b)
    pd.concat(grids).to_csv(os.path.join(OUT, "round2_grid_dev_val.csv"), index=False)
    pd.DataFrame(rows).to_csv(os.path.join(OUT, "round2_selected_dev_val.csv"), index=False)


if __name__ == "__main__":
    main()
