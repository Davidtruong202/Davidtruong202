"""Performance statistics on a trade list (R multiples, fixed-fractional equity)."""
import numpy as np
import pandas as pd


def max_streak(mask):
    best = cur = 0
    for m in mask:
        cur = cur + 1 if m else 0
        best = max(best, cur)
    return best


def equity(r, risk_pct=1.0):
    return np.cumprod(1 + np.asarray(r) * risk_pct / 100.0)


def max_dd_pct(r, risk_pct=1.0):
    if len(r) == 0:
        return 0.0
    eq = np.concatenate([[1.0], equity(r, risk_pct)])
    peak = np.maximum.accumulate(eq)
    return float(((peak - eq) / peak).max() * 100)


def summarize(tr, risk_pct=1.0):
    if tr is None or len(tr) == 0:
        return {"trades": 0}
    r = tr.r.values
    wins, losses = r[r > 0], r[r <= 0]
    gross_w, gross_l = wins.sum(), -losses.sum()
    months = max((tr.entry_time.max() - tr.entry_time.min()).days / 30.44, 1e-9)
    hold = (tr.exit_time - tr.entry_time).dt.total_seconds() / 60
    eq = equity(r, risk_pct)
    return {
        "trades": len(r),
        "trades_per_month": len(r) / months,
        "win_rate": len(wins) / len(r) * 100,
        "pf": gross_w / gross_l if gross_l > 0 else np.inf,
        "exp_r": r.mean(),
        "t_stat": r.mean() / r.std(ddof=1) * np.sqrt(len(r)) if len(r) > 1 and r.std() > 0 else 0,
        "avg_win_r": wins.mean() if len(wins) else 0,
        "avg_loss_r": losses.mean() if len(losses) else 0,
        "net_r": r.sum(),
        "net_pct": (eq[-1] - 1) * 100,
        "max_dd_pct": max_dd_pct(r, risk_pct),
        "max_consec_loss": max_streak(r <= 0),
        "max_consec_win": max_streak(r > 0),
        "avg_hold_min": hold.mean(),
        "spread_over_risk": (tr.spread_at_entry / tr.risk).median(),
    }


SESSIONS = [("Asia 00-07", 0, 7), ("London 07-12", 7, 12), ("NY 12-17", 12, 17), ("Late 17-24", 17, 24)]


def by_session(tr):
    h = tr.entry_time.dt.hour
    rows = []
    for name, a, b in SESSIONS:
        s = summarize(tr[(h >= a) & (h < b)])
        rows.append({"session": name, **{k: s.get(k) for k in ("trades", "win_rate", "pf", "exp_r")}})
    wk = tr.entry_time.dt.dayofweek >= 5
    for name, m in (("Weekend (Sat-Sun)", wk), ("Weekday", ~wk)):
        s = summarize(tr[m])
        rows.append({"session": name, **{k: s.get(k) for k in ("trades", "win_rate", "pf", "exp_r")}})
    return pd.DataFrame(rows)


def by_regime(tr):
    rows = []
    trend = tr.tag_adx >= 25
    rng = tr.tag_adx < 20
    hv = tr.tag_atr_pct >= 0.7
    lv = tr.tag_atr_pct <= 0.3
    for name, m in (("Trending (ADX>=25)", trend), ("Ranging (ADX<20)", rng),
                    ("High vol (ATR pct>=70)", hv), ("Low vol (ATR pct<=30)", lv)):
        s = summarize(tr[m])
        rows.append({"regime": name, **{k: s.get(k) for k in ("trades", "win_rate", "pf", "exp_r")}})
    return pd.DataFrame(rows)
