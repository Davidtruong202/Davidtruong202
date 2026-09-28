"""Round 2 finalist: locked config -> final test, stress, Monte Carlo, walk-forward.

Chosen by run_round2.py on dev+validation only:
  E2_CROSS_H1 on M15: EMA20 crosses EMA50 (close basis), only in the direction of the
  last closed H1 bar (EMA50 vs EMA200, ADX14 >= 20); initial SL 3 x ATR14(M15),
  trailing stop 4 x ATR14(M15) (fixed at entry), no TP, max hold 192 M15 bars (48h).
NOTE: the final test split was already opened once in round 1 (for a different strategy).
It is still unused for THIS strategy's parameter choice, but it is no longer pristine;
walk-forward and forward demo carry more weight.
"""
import json
import os

import pandas as pd

import data
import engine
import indicators as ind
import metrics as M
from run_final import KEYS, mc_drawdown, seg
from run_hypotheses import h1_filter_factory
from run_research import OUT, search, splits
from strategies2 import EXITS2, HOLD, STRATEGIES2, build, valid_params

NAME, TF = "E2_CROSS_H1", 15
LOCKED = {"params": {"fast": 20, "slow": 50}, "ex": {"sl_atr": 3.0, "rr": 0.0, "trail": 4.0}}


def signals(f, h1f, params, ex):
    sig = build(f, NAME, params, ex, TF, HOLD["trail"])
    sig["dir"] = h1f(f, sig["dir"], TF)
    return sig


def walk_forward(m1, f_all, h1f, spread, train_months=12, test_months=3):
    book = engine.M1Book(m1, spread_override=spread)
    pgrid = STRATEGIES2[NAME][1]
    start = m1.index[0] + pd.DateOffset(months=train_months)
    rows, oos = [], []
    while start + pd.DateOffset(months=test_months) <= m1.index[-1] + pd.Timedelta(days=1):
        tr_a, tr_b, te_b = start - pd.DateOffset(months=train_months), start, start + pd.DateOffset(months=test_months)
        f = f_all[(f_all.index >= tr_a - pd.Timedelta(days=10)) & (f_all.index < tr_b)]
        df, _ = search(book, f, NAME, pgrid, EXITS2["trail"], TF, tr_b, tr_b, hold_bars=HOLD["trail"],
                       sig_filter=lambda ff, d: h1f(ff, d, TF), builder=build, param_ok=valid_params)
        ok = df[df.dev_trades >= 40]
        if len(ok):
            best = ok.sort_values("dev_t_stat", ascending=False).iloc[0]
            ex = {"sl_atr": best.sl_atr, "rr": 0.0, "trail": best.trail}
            sig = signals(f_all, h1f, json.loads(best.params), ex)
            sig = sig[(sig.index >= tr_b) & (sig.index < te_b)]
            tr = engine.run(book, sig, TF)
            s = M.summarize(tr)
            rows.append({"test_from": tr_b.date(), "test_to": te_b.date(), "params": best.params,
                         "sl_atr": best.sl_atr, "trail": best.trail, "train_pf": best.dev_pf,
                         **{k: s.get(k) for k in ("trades", "win_rate", "pf", "exp_r", "net_pct", "max_dd_pct")}})
            if len(tr):
                oos.append(tr)
        start = te_b
    return pd.DataFrame(rows), (pd.concat(oos) if oos else pd.DataFrame())


def main():
    m1 = data.load_m1()
    sp = splits(m1)
    t0, dev_end, val_end = m1.index[0], pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    t_end = m1.index[-1] + pd.Timedelta(minutes=1)
    h1f = h1_filter_factory(m1)
    f = ind.add_features(data.resample(m1, f"{TF}min"))
    sig = signals(f, h1f, LOCKED["params"], LOCKED["ex"])

    rows = []
    for cost, spread in (("spread $10", 10.0), ("historical spread", None)):
        tr = engine.run(engine.M1Book(m1, spread_override=spread), sig, TF)
        if spread == 10.0:
            main_tr = tr
        for name, a, b in (("dev", t0, dev_end), ("val", dev_end, val_end), ("TEST", val_end, t_end), ("all", t0, t_end)):
            s = M.summarize(seg(tr, a, b))
            rows.append({"cost": cost, "split": name, **{k: s.get(k) for k in KEYS}})
    final = pd.DataFrame(rows)
    final.to_csv(os.path.join(OUT, "round2_final_locked.csv"), index=False)
    print(final.round(3).to_string(index=False))

    rows = []
    for label, spread, slip in (("base $10", 10.0, 0), ("spread $20", 20.0, 0), ("spread $30", 30.0, 0),
                                ("spread $10 + slip $10", 10.0, 10.0), ("spread $20 + slip $20", 20.0, 20.0)):
        tr = engine.run(engine.M1Book(m1, spread_override=spread), sig, TF, slip=slip)
        for name, a, b in (("TEST", val_end, t_end), ("all", t0, t_end)):
            s = M.summarize(seg(tr, a, b))
            rows.append({"stress": label, "split": name,
                         **{k: s.get(k) for k in ("trades", "pf", "exp_r", "net_pct", "max_dd_pct")}})
    stress = pd.DataFrame(rows)
    stress.to_csv(os.path.join(OUT, "round2_final_stress.csv"), index=False)
    print(stress.round(3).to_string(index=False))

    mc = {k: mc_drawdown(seg(main_tr, a, b).r.values) for k, a, b in (("TEST", val_end, t_end), ("all", t0, t_end))}
    mc05 = {k + "_risk0.5": mc_drawdown(seg(main_tr, a, b).r.values, risk_pct=0.5)
            for k, a, b in (("all", t0, t_end),)}
    mcd = pd.DataFrame({**mc, **mc05})
    mcd.to_csv(os.path.join(OUT, "round2_final_montecarlo.csv"))
    print(mcd.round(2))
    sess, reg = M.by_session(main_tr), M.by_regime(main_tr)
    print(sess.round(3).to_string(index=False))
    print(reg.round(3).to_string(index=False))
    yearly = main_tr.groupby(main_tr.entry_time.dt.year).apply(
        lambda g: pd.Series({k: M.summarize(g)[k] for k in ("trades", "win_rate", "pf", "exp_r", "net_pct", "max_dd_pct")}))
    print(yearly.round(3))
    yearly.to_csv(os.path.join(OUT, "round2_final_yearly.csv"))
    sess.to_csv(os.path.join(OUT, "round2_final_sessions_all.csv"), index=False)
    reg.to_csv(os.path.join(OUT, "round2_final_regimes_all.csv"), index=False)
    main_tr.to_csv(os.path.join(OUT, "round2_final_trades_spread10.csv"), index=False)

    wf, oos = walk_forward(m1, f, h1f, 10.0)
    wf.to_csv(os.path.join(OUT, "round2_walkforward.csv"), index=False)
    print(wf.round(3).to_string(index=False))
    s = M.summarize(oos)
    print("WF out-of-sample combined:", {k: round(float(s[k]), 3) for k in KEYS if k in s})
    pd.DataFrame([s]).to_csv(os.path.join(OUT, "round2_walkforward_combined.csv"), index=False)


if __name__ == "__main__":
    main()
