"""Portfolio hypothesis: MOM-M15-H1 (round-1 finalist) + H1 trend following (Donchian 55,
trailing stop) run side by side, each with its own position and half the risk budget.

The H1 component's config is picked by the same dev-only rule as before (highest dev
t-stat on H1 N3_DONCH trailing, $10 spread); it did NOT pass validation on its own
(val PF ~1.07), so this is an explicit hypothesis about diversification, not a standalone
strategy. BTC data has now been used in two research rounds: treat results as weak evidence.

Equity: each closed trade changes equity by r x risk% of equity at its exit time
(trades of both strategies merged by exit time).
"""
import json
import os

import numpy as np
import pandas as pd

import data
import engine
import indicators as ind
import metrics as M
from run_final import locked_signals
from run_hypotheses import h1_filter_factory
from run_research import OUT, splits
from strategies2 import HOLD, build


def equity_stats(trades, risk_pct, a, b):
    t = trades[(trades.entry_time >= a) & (trades.entry_time < b)].sort_values("exit_time")
    if len(t) == 0:
        return {}
    eq = np.cumprod(1 + t.r.values * t.risk_pct.values / 100.0) if "risk_pct" in t else \
        np.cumprod(1 + t.r.values * risk_pct / 100.0)
    curve = pd.Series(np.concatenate([[1.0], eq]))
    dd = ((curve.cummax() - curve) / curve.cummax()).max() * 100
    years = max((b - a).days / 365.25, 1e-9)
    total = (eq[-1] - 1) * 100
    cagr = (eq[-1] ** (1 / years) - 1) * 100
    return {"trades": len(t), "total_pct": total, "cagr_pct": cagr, "max_dd_pct": dd,
            "cagr_over_dd": cagr / dd if dd > 0 else np.inf}


def main():
    m1 = data.load_m1()
    sp = splits(m1)
    t0, dev_end, val_end = m1.index[0], pd.Timestamp(sp["dev_end"]), pd.Timestamp(sp["val_end"])
    t_end = m1.index[-1] + pd.Timedelta(minutes=1)
    book = engine.M1Book(m1, spread_override=10.0)

    # Strategy A: locked MOM-M15-H1
    _, sig_a = locked_signals(m1, h1_filter_factory(m1))
    tr_a = engine.run(book, sig_a, 15)

    # Strategy B: H1 Donchian trailing, config chosen on dev only
    g = pd.read_csv(os.path.join(OUT, "round2_grid_dev_val.csv"))
    cand = g[(g.strategy == "N3_DONCH") & (g.tf == "H1") & (g.exit == "trail") & (g.cost == "spread10")
             & (g.dev_trades >= 100)]
    best = cand.sort_values("dev_t_stat", ascending=False).iloc[0]
    ex_b = {"sl_atr": best.sl_atr, "rr": 0.0, "trail": best.trail}
    f_h1 = ind.add_features(data.resample(m1, "1h"))
    sig_b = build(f_h1, "N3_DONCH", json.loads(best.params), ex_b, 60, HOLD["trail"])
    tr_b = engine.run(book, sig_b, 60)
    print("H1 component (dev-selected):", best.params, ex_b)

    # Daily R correlation
    da = tr_a.groupby(tr_a.exit_time.dt.normalize()).r.sum()
    db = tr_b.groupby(tr_b.exit_time.dt.normalize()).r.sum()
    idx = pd.date_range(min(da.index.min(), db.index.min()), max(da.index.max(), db.index.max()))
    corr = da.reindex(idx, fill_value=0).corr(db.reindex(idx, fill_value=0))
    print(f"daily R correlation A vs B: {corr:.3f}")

    rows = []
    a = tr_a.assign(risk_pct=1.0, strat="A")
    b = tr_b.assign(risk_pct=1.0, strat="B")
    port = pd.concat([tr_a.assign(risk_pct=0.5), tr_b.assign(risk_pct=0.5)])
    for label, tr in (("A: MOM-M15-H1 @1%", a), ("B: H1 Donchian trail @1%", b),
                      ("A+B @0.5% each", port)):
        for name, s, e in (("dev", t0, dev_end), ("val", dev_end, val_end), ("TEST", val_end, t_end),
                           ("all", t0, t_end)):
            st = equity_stats(tr, None, s, e)
            ms = M.summarize(tr[(tr.entry_time >= s) & (tr.entry_time < e)])
            rows.append({"portfolio": label, "split": name, "pf": ms.get("pf"), **st})
    res = pd.DataFrame(rows)
    res.to_csv(os.path.join(OUT, "portfolio_btc.csv"), index=False)
    print(res.round(3).to_string(index=False))
    yearly = []
    for y in range(2023, 2027):
        s, e = pd.Timestamp(f"{y}-01-01"), pd.Timestamp(f"{y + 1}-01-01")
        for label, tr in (("A", a), ("B", b), ("A+B", port)):
            st = equity_stats(tr, None, s, min(e, t_end))
            yearly.append({"year": y, "portfolio": label, **st})
    yr = pd.DataFrame(yearly)
    yr.to_csv(os.path.join(OUT, "portfolio_btc_yearly.csv"), index=False)
    print(yr.round(2).to_string(index=False))


if __name__ == "__main__":
    main()
