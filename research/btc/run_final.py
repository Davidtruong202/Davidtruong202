"""Stage 3b/4/5: locked finalist -> final test (run once), stress tests, walk-forward.

Finalist chosen by run_hypotheses.py on dev+validation only:
  G2_MOM on M15 (displacement candle >= 2.0 ATR, body >= 60% of range, close beyond
  20-bar extreme, EMA50/EMA200 trend filter) + H1 trend filter (H-A),
  SL = 2.0 x ATR14(M15), TP = 2R, max hold 48 M15 bars, execution on M1.
Nothing in this script feeds back into parameter choice.
"""
import json
import os

import numpy as np
import pandas as pd

import data
import engine
import indicators as ind
import metrics as M
from run_hypotheses import h1_filter_factory
from run_research import OUT, search, splits
from strategies import EXIT_GRID, STRATEGIES, build_signals

LOCKED = {"name": "G2_MOM", "params": {"rng_atr": 2.0, "trend_filter": 1},
          "sl_atr": 2.0, "rr": 2.0, "tf_min": 15}
KEYS = ["trades", "trades_per_month", "win_rate", "pf", "exp_r", "avg_win_r", "avg_loss_r",
        "net_pct", "max_dd_pct", "max_consec_loss", "max_consec_win", "avg_hold_min", "spread_over_risk"]


def locked_signals(m1, h1f):
    mins = LOCKED["tf_min"]
    f = ind.add_features(data.resample(m1, f"{mins}min"))
    sig = build_signals(f, LOCKED["name"], LOCKED["params"], LOCKED["sl_atr"], LOCKED["rr"], mins)
    sig["dir"] = h1f(f, sig["dir"], mins)
    return f, sig


def seg(tr, a, b):
    return tr[(tr.entry_time >= a) & (tr.entry_time < b)]


def mc_drawdown(r, n=5000, risk_pct=1.0, seed=1):
    """Bootstrap trade order to see drawdown / losing-streak distribution."""
    rng = np.random.default_rng(seed)
    dds, streaks = [], []
    for _ in range(n):
        s = rng.choice(r, size=len(r), replace=True)
        dds.append(M.max_dd_pct(s, risk_pct))
        streaks.append(M.max_streak(s <= 0))
    return {"dd_p50": np.percentile(dds, 50), "dd_p95": np.percentile(dds, 95),
            "dd_p99": np.percentile(dds, 99), "loss_streak_p95": np.percentile(streaks, 95)}


def walk_forward(m1, h1f, spread, train_months=12, test_months=3):
    """Re-select the G2_MOM+H1 config on each trailing window, trade the next window."""
    mins = LOCKED["tf_min"]
    f_all = ind.add_features(data.resample(m1, f"{mins}min"))
    book = engine.M1Book(m1, spread_override=spread)
    pgrid = STRATEGIES["G2_MOM"][1]
    start = m1.index[0] + pd.DateOffset(months=train_months)
    rows, oos = [], []
    while start + pd.DateOffset(months=test_months) <= m1.index[-1] + pd.Timedelta(days=1):
        tr_a, tr_b = start - pd.DateOffset(months=train_months), start
        te_b = start + pd.DateOffset(months=test_months)
        f = f_all[f_all.index < tr_b]
        # dev = training window, val slot unused (set to training end)
        df, _ = search(book, f[f.index >= tr_a - pd.Timedelta(days=10)], "G2_MOM", pgrid, EXIT_GRID,
                       mins, tr_b, tr_b, sig_filter=lambda ff, d: h1f(ff, d, mins))
        ok = df[df.dev_trades >= 40]
        if len(ok) == 0:
            start = te_b
            continue
        best = ok.sort_values("dev_t_stat", ascending=False).iloc[0]
        p = json.loads(best.params)
        sig = build_signals(f_all, "G2_MOM", p, best.sl_atr, best.rr, mins)
        sig["dir"] = h1f(f_all, sig["dir"], mins)
        sig = sig[(sig.index >= tr_b) & (sig.index < te_b)]
        tr = engine.run(book, sig, mins)
        s = M.summarize(tr)
        rows.append({"test_from": tr_b.date(), "test_to": te_b.date(), "params": best.params,
                     "sl_atr": best.sl_atr, "rr": best.rr, "train_pf": best.dev_pf,
                     **{k: s.get(k) for k in ("trades", "win_rate", "pf", "exp_r", "net_pct", "max_dd_pct")}})
        if len(tr):
            oos.append(tr)
        start = te_b
    oos = pd.concat(oos) if oos else pd.DataFrame()
    return pd.DataFrame(rows), oos


def main():
    m1 = data.load_m1()
    sp = splits(m1)
    t0, dev_end, val_end = m1.index[0], pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    t_end = m1.index[-1] + pd.Timedelta(minutes=1)
    h1f = h1_filter_factory(m1)
    f, sig = locked_signals(m1, h1f)
    mins = LOCKED["tf_min"]
    out = {}

    # --- Final test (once) + same config on dev / val for context
    rows = []
    for cost, spread, slip in (("spread $10", 10.0, 0.0), ("historical spread", None, 0.0)):
        tr = engine.run(engine.M1Book(m1, spread_override=spread), sig, mins)
        for name, a, b in (("dev", t0, dev_end), ("val", dev_end, val_end), ("TEST", val_end, t_end),
                           ("all", t0, t_end)):
            s = M.summarize(seg(tr, a, b))
            rows.append({"cost": cost, "split": name, **{k: s.get(k) for k in KEYS}})
        if spread == 10.0:
            main_tr = tr
    final = pd.DataFrame(rows)
    final.to_csv(os.path.join(OUT, "final_locked.csv"), index=False)
    print(final.round(3).to_string(index=False))

    # --- Stress tests on the final test period and on the full period
    rows = []
    for label, spread, slip in (("base $10", 10.0, 0), ("spread $20", 20.0, 0), ("spread $30", 30.0, 0),
                                ("spread $10 + slip $10", 10.0, 10.0), ("spread $20 + slip $20", 20.0, 20.0)):
        tr = engine.run(engine.M1Book(m1, spread_override=spread), sig, mins, slip=slip)
        for name, a, b in (("TEST", val_end, t_end), ("all", t0, t_end)):
            s = M.summarize(seg(tr, a, b))
            rows.append({"stress": label, "split": name, **{k: s.get(k) for k in ("trades", "pf", "exp_r",
                                                                                  "net_pct", "max_dd_pct")}})
    stress = pd.DataFrame(rows)
    stress.to_csv(os.path.join(OUT, "final_stress.csv"), index=False)
    print(stress.round(3).to_string(index=False))

    mc = {k: mc_drawdown(seg(main_tr, a, b).r.values) for k, a, b in
          (("TEST", val_end, t_end), ("all", t0, t_end))}
    pd.DataFrame(mc).to_csv(os.path.join(OUT, "final_montecarlo.csv"))
    print(pd.DataFrame(mc).round(2))

    sess = M.by_session(main_tr)
    reg = M.by_regime(main_tr)
    sess.to_csv(os.path.join(OUT, "final_sessions_all.csv"), index=False)
    reg.to_csv(os.path.join(OUT, "final_regimes_all.csv"), index=False)
    print(sess.round(3).to_string(index=False))
    print(reg.round(3).to_string(index=False))
    yearly = main_tr.groupby(main_tr.entry_time.dt.year).apply(
        lambda g: pd.Series({k: M.summarize(g)[k] for k in ("trades", "win_rate", "pf", "exp_r", "net_pct",
                                                              "max_dd_pct")}))
    yearly.to_csv(os.path.join(OUT, "final_yearly.csv"))
    print(yearly.round(3))
    main_tr.to_csv(os.path.join(OUT, "final_trades_spread10.csv"), index=False)

    # --- Walk-forward (parameters re-selected on trailing 12 months, traded next 3 months)
    wf, oos = walk_forward(m1, h1f, 10.0)
    wf.to_csv(os.path.join(OUT, "walkforward.csv"), index=False)
    print(wf.round(3).to_string(index=False))
    s = M.summarize(oos)
    print("WF out-of-sample combined:", {k: round(float(s[k]), 3) for k in KEYS if k in s})
    pd.DataFrame([s]).to_csv(os.path.join(OUT, "walkforward_combined.csv"), index=False)


if __name__ == "__main__":
    main()
