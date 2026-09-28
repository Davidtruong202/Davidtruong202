"""Stage 2/3a: parameter search on the development split, evaluation on validation.

The final test split (last 20% of M1 bars) is NOT evaluated here. Trades that
fall into it are discarded before any statistic is computed.

Selection rule (fixed before running):
- per (strategy, timeframe) keep configs with >= MIN_DEV_TRADES trades on dev
- pick the config with the highest t-statistic of R on dev
- finalist if: dev PF >= 1.10, val PF >= 1.20, val expectancy > 0, val trades >= 30
"""
import argparse
import json
import os

import pandas as pd

import data
import engine
import indicators as ind
import metrics as M
from strategies import EXIT_GRID, HOLD_BARS, STRATEGIES, build_signals, grid

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
TFS = {"M1": 1, "M5": 5, "M15": 15}
MIN_DEV_TRADES = 100
KEYS = ["trades", "trades_per_month", "win_rate", "pf", "exp_r", "t_stat", "max_dd_pct",
        "max_consec_loss", "avg_hold_min", "spread_over_risk"]


def splits(m1):
    t = m1.index
    return {"start": str(t[0]), "dev_end": str(t[int(len(t) * 0.6)]),
            "val_end": str(t[int(len(t) * 0.8)]), "end": str(t[-1])}


def search(book, f, name, pgrid, exit_grid, mins, dev_end, val_end,
           hold_bars=HOLD_BARS, sig_filter=None):
    """Grid-search one strategy on one timeframe. Returns (all configs, selected config)."""
    rows = []
    for p in grid(pgrid):
        for ex in grid(exit_grid):
            sig = build_signals(f, name, p, ex["sl_atr"], ex["rr"], mins, hold_bars)
            if sig_filter is not None:
                sig["dir"] = sig_filter(f, sig["dir"])
            tr = engine.run(book, sig, mins)
            if len(tr):
                tr = tr[tr.exit_time < val_end]
            dev = tr[tr.entry_time < dev_end] if len(tr) else tr
            val = tr[tr.entry_time >= dev_end] if len(tr) else tr
            sd, sv = M.summarize(dev), M.summarize(val)
            row = {"strategy": name, "params": json.dumps(p), **ex}
            row.update({f"dev_{k}": sd.get(k) for k in KEYS})
            row.update({f"val_{k}": sv.get(k) for k in KEYS})
            rows.append(row)
    df = pd.DataFrame(rows)
    ok = df[df.dev_trades >= MIN_DEV_TRADES]
    share_pos = (ok.dev_exp_r > 0).mean() if len(ok) else 0
    if len(ok):
        b = ok.sort_values("dev_t_stat", ascending=False).iloc[0].to_dict()
    else:
        b = df.sort_values("dev_trades", ascending=False).iloc[0].to_dict()
        b["note"] = "not enough dev trades"
    b["grid_share_dev_positive"] = share_pos
    b["n_configs"] = len(df)
    b["finalist"] = bool(
        len(ok) and b["dev_pf"] >= 1.10 and (b["val_pf"] or 0) >= 1.20
        and (b["val_exp_r"] or 0) > 0 and (b["val_trades"] or 0) >= 30)
    return df, b


def report(tf, name, b):
    print(f"{tf:4s} {name:9s} dev PF {b['dev_pf'] or 0:.2f} exp {b['dev_exp_r'] or 0:+.3f} n {b['dev_trades'] or 0:5.0f} | "
          f"val PF {b['val_pf'] or 0:.2f} exp {b['val_exp_r'] or 0:+.3f} n {b['val_trades'] or 0:4.0f} | "
          f"grid+ {b['grid_share_dev_positive']:.0%} {'FINALIST' if b['finalist'] else ''}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--spread", type=float, default=None,
                    help="fixed spread in USD instead of the historical per-bar spread")
    ap.add_argument("--tag", default="hist")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    m1 = data.load_m1()
    sp = splits(m1)
    with open(os.path.join(OUT, "splits.json"), "w") as fh:
        json.dump(sp, fh, indent=2)
    dev_end, val_end = pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    book = engine.M1Book(m1, spread_override=args.spread)

    all_rows, best_rows = [], []
    for tf, mins in TFS.items():
        f = ind.add_features(m1 if mins == 1 else data.resample(m1, f"{mins}min"))
        f = f[f.index < val_end]  # never build signals on the final test period
        for name, (_, pgrid) in STRATEGIES.items():
            df, b = search(book, f, name, pgrid, EXIT_GRID, mins, dev_end, val_end)
            b["tf"] = tf
            df["tf"] = tf
            all_rows.append(df)
            best_rows.append(b)
            report(tf, name, b)

    pd.concat(all_rows).to_csv(os.path.join(OUT, f"grid_dev_val_{args.tag}.csv"), index=False)
    pd.DataFrame(best_rows).to_csv(os.path.join(OUT, f"selected_dev_val_{args.tag}.csv"), index=False)


if __name__ == "__main__":
    main()
