"""Statistics + a single self-contained HTML report (no internet needed to open it)."""

import bisect
import json
import math
import os
from collections import OrderedDict
from datetime import datetime, timezone


TEMPLATE = os.path.join(os.path.dirname(__file__), "report_template.html")


def _dt(t):
    return datetime.fromtimestamp(t, tz=timezone.utc)


def _pf(wins, losses):
    return (wins / -losses) if losses < 0 else (float("inf") if wins > 0 else 0.0)


def _group_stats(trades):
    n = len(trades)
    wins = [t.pnl for t in trades if t.pnl > 0]
    losses = [t.pnl for t in trades if t.pnl <= 0]
    gross_w, gross_l = sum(wins), sum(losses)
    rs = [t.pnl / t.risk_money for t in trades if t.risk_money > 0]
    return dict(
        trades=n,
        wins=len(wins),
        win_rate=(len(wins) / n * 100) if n else 0.0,
        net=gross_w + gross_l,
        gross_win=gross_w,
        gross_loss=gross_l,
        pf=_pf(gross_w, gross_l),
        avg_r=(sum(rs) / len(rs)) if rs else 0.0,
        avg_win=(gross_w / len(wins)) if wins else 0.0,
        avg_loss=(gross_l / len(losses)) if losses else 0.0,
    )


def compute_stats(bt):
    trades, eq, init = bt.trades, bt.equity, bt.a.initial_balance
    s = _group_stats(trades)
    final = bt.balance
    s.update(initial=init, final=final, ret_pct=(final - init) / init * 100)

    # drawdown on bar-close equity
    peak, max_dd, max_dd_pct, dd_start, max_dd_len = init, 0.0, 0.0, None, 0
    for t, bal, e in eq:
        if e > peak:
            peak = e
            if dd_start is not None:
                max_dd_len = max(max_dd_len, t - dd_start)
            dd_start = None
        else:
            if dd_start is None:
                dd_start = t
            dd = peak - e
            if dd > max_dd:
                max_dd = dd
            if peak > 0 and dd / peak * 100 > max_dd_pct:
                max_dd_pct = dd / peak * 100
    if dd_start is not None and eq:
        max_dd_len = max(max_dd_len, eq[-1][0] - dd_start)
    s.update(max_dd=max_dd, max_dd_pct=max_dd_pct, max_dd_days=max_dd_len / 86400.0,
             recovery=(s["net"] / max_dd) if max_dd > 0 else 0.0)

    # daily returns -> Sharpe (annualised, 252 trading days)
    daily = OrderedDict()
    for t, bal, e in eq:
        daily[t // 86400] = e
    vals = list(daily.values())
    rets = [(vals[i] - vals[i - 1]) / vals[i - 1] for i in range(1, len(vals)) if vals[i - 1] > 0]
    if len(rets) > 1:
        mu = sum(rets) / len(rets)
        sd = math.sqrt(sum((r - mu) ** 2 for r in rets) / (len(rets) - 1))
        s["sharpe"] = (mu / sd * math.sqrt(252)) if sd > 0 else 0.0
    else:
        s["sharpe"] = 0.0

    # streaks, holding time, best/worst
    streak = best_streak = worst_streak = 0
    for t in trades:
        if t.pnl > 0:
            streak = streak + 1 if streak > 0 else 1
        else:
            streak = streak - 1 if streak < 0 else -1
        best_streak, worst_streak = max(best_streak, streak), min(worst_streak, streak)
    holds = [t.exits[-1]["t"] - t.open_t for t in trades]
    s.update(max_win_streak=best_streak, max_loss_streak=-worst_streak,
             avg_hold_min=(sum(holds) / len(holds) / 60.0) if holds else 0.0,
             best=max((t.pnl for t in trades), default=0.0),
             worst=min((t.pnl for t in trades), default=0.0),
             expectancy=(s["net"] / len(trades)) if trades else 0.0)

    by_setup = OrderedDict()
    for k, name in bt.setup_names.items():
        by_setup[k] = dict(_group_stats([t for t in trades if t.setup == k]), name=name)
    by_dir = OrderedDict([("BUY", _group_stats([t for t in trades if t.buy])),
                          ("SELL", _group_stats([t for t in trades if not t.buy]))])
    by_kz = OrderedDict()
    for t in trades:
        by_kz.setdefault(t.kz, []).append(t)
    by_kz = OrderedDict((k, _group_stats(v)) for k, v in by_kz.items())

    # monthly returns on month-start equity
    months = OrderedDict()
    for t, bal, e in eq:
        d = _dt(t)
        key = (d.year, d.month)
        if key not in months:
            months[key] = [e, e]
        months[key][1] = e
    keys = list(months.keys())
    monthly = []
    for i, k in enumerate(keys):
        start = months[keys[i - 1]][1] if i > 0 else init
        end = months[k][1]
        monthly.append(dict(y=k[0], m=k[1], pct=(end - start) / start * 100 if start else 0.0, pnl=end - start))

    exits = OrderedDict()
    for t in trades:
        r = t.exits[-1]["reason"]
        exits[r] = exits.get(r, 0) + 1

    return dict(summary=s, by_setup=by_setup, by_dir=by_dir, by_kz=by_kz, monthly=monthly, exits=exits)


def _downsample_equity(eq, max_points=3000):
    if len(eq) <= max_points:
        return [[t, round(b, 2), round(e, 2)] for t, b, e in eq]
    step = len(eq) / max_points
    out, i = [], 0.0
    while int(i) < len(eq):
        lo = int(i)
        hi = min(len(eq), int(i + step))
        chunk = eq[lo:hi]
        worst = min(chunk, key=lambda x: x[2])  # keep dips so drawdown is not hidden
        last = chunk[-1]
        for p in sorted({worst, last}, key=lambda x: x[0]):
            out.append([p[0], round(p[1], 2), round(p[2], 2)])
        i += step
    return out


def build_payload(bt, meta):
    b, point = bt.b, bt.a.point
    stats = compute_stats(bt)
    inv = 1.0 / point
    bars = dict(
        t=b.t,
        o=[round(x * inv) for x in b.o],
        h=[round(x * inv) for x in b.h],
        l=[round(x * inv) for x in b.l],
        c=[round(x * inv) for x in b.c],
        kz="".join(str(k) for k in bt.kz_by_bar),
    )

    def idx(t):
        return max(0, min(len(b.t) - 1, bisect.bisect_right(b.t, t) - 1))

    trades = []
    for p in bt.trades:
        trades.append(dict(
            id=p.id, setup=p.setup, buy=p.buy, comment=p.comment, kz=p.kz,
            t=p.open_t, i=p.open_i, price=p.open_price, sl=p.init_sl, tp1=p.tp1, tp2=p.tp,
            lots=p.init_lots, pnl=round(p.pnl, 2), r=round(p.pnl / p.risk_money, 2) if p.risk_money else 0,
            exits=[dict(t=e["t"], i=idx(e["t"]), price=e["price"], lots=e["lots"], pnl=round(e["pnl"], 2),
                        reason=e["reason"]) for e in p.exits],
        ))
    return dict(
        meta=dict(meta, point=point, kz_names=bt.kz_names, setup_names=bt.setup_names,
                  strategy=bt.strategy_name, diag=bt.diag_labels, risk_percent=bt.risk_percent,
                  first=b.t[0], last=b.t[-1], generated=datetime.now().strftime("%Y-%m-%d %H:%M")),
        stats=stats, counters=bt.cnt, params=bt.params_dict(),
        bars=bars, trades=trades, equity=_downsample_equity(bt.equity),
        events=[[t, m] for t, m in getattr(bt, "events", [])[-200:]],
    )


class _Enc(json.JSONEncoder):
    def iterencode(self, o, _one_shot=False):
        return super().iterencode(_clean(o), _one_shot)


def _clean(o):
    if isinstance(o, float):
        if math.isinf(o):
            return 999.0
        if math.isnan(o):
            return 0.0
        return round(o, 4)
    if isinstance(o, dict):
        return {str(k): _clean(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_clean(v) for v in o]
    return o


def write_report(bt, path, meta):
    payload = build_payload(bt, meta)
    with open(TEMPLATE, encoding="utf-8") as f:
        html = f.read()
    data = json.dumps(payload, cls=_Enc, separators=(",", ":")).replace("</", "<\\/")
    html = html.replace("/*__DATA__*/null", data)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    return payload
