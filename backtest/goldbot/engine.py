"""Strategy API shared by the backtester and the live MT5 bot.

A strategy never touches orders directly. On every CLOSED bar (M5, or M1 for scalping) it receives
the bar index, a read-only view of the open position and account facts, and
returns a list of actions. The backtester (``Backtester``) and the live bot
(``goldbot.live.LiveTrader``) both execute those actions, so the logic that
was backtested is exactly the logic that trades.

Execution model of the backtester
---------------------------------
* Decisions are made at the close of bar i and executed at the open of bar i+1
  (buy at ask = bid + spread, sell at bid), as a live bot that reacts to a new
  bar would.
* Inside each bar, SL / TP1 / TP are resolved along the bar's price path. With
  tick data the path is known (high first or low first); otherwise the adverse
  extreme is assumed to come first (conservative).
* TP1 closes ``tp1_frac`` of the position and moves the stop to breakeven.
"""

from dataclasses import dataclass, asdict

from .common import Account, DAY, lot_size

# ---------------------------------------------------------------------------
# Actions a strategy can return
# ---------------------------------------------------------------------------


@dataclass
class Enter:
    buy: bool
    sl: float                 # absolute stop price
    tp_r: float               # final target in R (distance to SL) from the real fill
    tp1_r: float = 0.0        # partial target in R; 0 = no partial
    tp1_frac: float = 0.5     # fraction closed at TP1
    tag: str = ""             # setup id shown in the report


@dataclass
class Close:
    reason: str


@dataclass
class MoveSL:
    sl: float


@dataclass
class RiskParams:
    risk_percent: float = 0.5          # % of balance risked per trade
    max_daily_loss_percent: float = 2.0
    max_consec_losses: int = 3         # then stop until the next trading day
    max_spread_points: float = 60      # skip entries when spread is wider
    day_start_ny_hour: float = 17.0    # gold trading day rolls at 17:00 New York


class PositionView:
    """What a strategy may know about the open position."""

    __slots__ = ("buy", "open_price", "sl", "init_sl", "tp", "tp1", "tp1_done", "open_t", "open_i",
                 "best", "tag", "lots")


class AccountView:
    __slots__ = ("balance", "trades_today_buy", "trades_today_sell", "blocked", "spread")


# ---------------------------------------------------------------------------
# Risk gate - identical rules in backtest and live
# ---------------------------------------------------------------------------
class RiskGate:
    def __init__(self, risk, clock):
        self.r, self.clock = risk, clock

    def trading_day(self, srv):
        ny = self.clock.ny(srv)
        return (ny - int(self.r.day_start_ny_hour * 3600)) // DAY

    def blocked(self, day_pnl, day_start_balance, consec_losses_today):
        """Reason string when no new trade may open today, else ''."""
        if day_start_balance > 0 and -day_pnl >= day_start_balance * self.r.max_daily_loss_percent / 100.0:
            return "daily_loss"
        if self.r.max_consec_losses and consec_losses_today >= self.r.max_consec_losses:
            return "consec_losses"
        return ""


# ---------------------------------------------------------------------------
# Backtester
# ---------------------------------------------------------------------------
class _Pos:
    __slots__ = ("id", "buy", "lots", "init_lots", "open_price", "sl", "init_sl", "tp", "tp1", "tp1_frac",
                 "tp1_done", "setup", "comment", "open_t", "open_i", "risk_money", "pnl", "exits", "kz", "best")


class Backtester:
    def __init__(self, bars, strategy, account=None, risk=None, trade_from=None, trade_to=None):
        self.b = bars
        self.s = strategy
        self.a = account or Account()
        self.r = risk or RiskParams()
        self.trade_from, self.trade_to = trade_from, trade_to
        self.gate = RiskGate(self.r, strategy.clock)
        self.balance = self.a.initial_balance
        self.pos = None
        self.trades, self.equity = [], []
        self.next_id = 1
        # per trading day bookkeeping
        self.day = None
        self.day_start_balance = self.balance
        self.day_pnl = 0.0
        self.day_consec = 0
        self.day_buys = self.day_sells = 0
        self.cnt = dict(entries=0, skipped_spread=0, skipped_risk=0, days_blocked=0)
        self._blocked_days = set()

    # -- reporting hooks (same attribute names the report reads from ICTBacktest)
    @property
    def kz_by_bar(self):
        return self.s.session_codes

    strategy_name = property(lambda self: self.s.name)
    setup_names = property(lambda self: self.s.setup_names)
    kz_names = property(lambda self: self.s.kz_names)
    diag_labels = property(lambda self: self.s.diag_labels)
    risk_percent = property(lambda self: self.r.risk_percent)

    def params_dict(self):
        return dict(strategy=asdict(self.s.p), risk=asdict(self.r), account=asdict(self.a))

    # -- helpers
    def _new_day_check(self, t):
        d = self.gate.trading_day(t)
        if d != self.day:
            self.day = d
            self.day_start_balance = self.balance
            self.day_pnl = 0.0
            self.day_consec = 0
            self.day_buys = self.day_sells = 0

    def _close(self, lots, price, reason, t, i):
        p, a = self.pos, self.a
        lots = min(lots, p.lots)
        pnl = (price - p.open_price) * (1 if p.buy else -1) * lots * a.contract_size - a.commission_per_lot * lots
        self.balance += pnl
        p.pnl += pnl
        p.lots = round(p.lots - lots, 2)
        p.exits.append(dict(t=t, price=price, lots=lots, pnl=pnl, reason=reason))
        if p.lots <= 1e-9:
            self.day_pnl += p.pnl
            self.day_consec = self.day_consec + 1 if p.pnl < 0 else 0
            self.trades.append(p)
            self.pos = None

    def _open(self, act, i):
        b, a = self.b, self.a
        bid = b.o[i]
        ask = bid + b.spread[i]
        fill = ask if act.buy else bid
        dist = (fill - act.sl) if act.buy else (act.sl - fill)
        if dist <= 0:
            self.cnt["skipped_risk"] += 1
            return
        lots = lot_size(self.balance, self.r.risk_percent, dist, a.tick_size, a.tick_value,
                        a.volume_min, a.volume_max, a.volume_step)
        if lots <= 0:
            return
        sgn = 1 if act.buy else -1
        p = _Pos()
        p.id = self.next_id; self.next_id += 1
        p.buy, p.lots, p.init_lots, p.open_price = act.buy, lots, lots, fill
        p.sl = p.init_sl = act.sl
        p.tp = fill + sgn * act.tp_r * dist
        p.tp1 = fill + sgn * act.tp1_r * dist if act.tp1_r > 0 else 0.0
        p.tp1_frac, p.tp1_done = act.tp1_frac, act.tp1_r <= 0
        p.setup, p.comment = act.tag, act.tag
        p.open_t, p.open_i = b.t[i], i
        p.risk_money = dist * lots * a.contract_size
        p.pnl, p.exits, p.best = 0.0, [], fill
        p.kz = self.s.session_name(b.t[i])
        self.pos = p
        if act.buy:
            self.day_buys += 1
        else:
            self.day_sells += 1
        self.cnt["entries"] += 1

    def _tp1(self, price, t, i):
        p, a = self.pos, self.a
        step = a.volume_step or 0.01
        vol = round(int(p.lots * p.tp1_frac / step + 1e-9) * step, 2)
        if a.volume_min <= vol < p.lots:
            self._close(vol, price, "TP1", t, i)
        p.tp1_done = True
        p.sl = p.open_price  # breakeven

    def _walk_bar(self, i):
        """Resolve SL / TP1 / TP inside bar i along its price path."""
        p, b = self.pos, self.b
        spr = 0.0 if p.buy else b.spread[i]
        o, h, l, c = b.o[i] + spr, b.h[i] + spr, b.l[i] + spr, b.c[i] + spr
        hf = b.hf[i]
        if hf == 0:
            hf = -1 if p.buy else 1  # adverse extreme first
        path = (o, h, l, c) if hf > 0 else (o, l, h, c)
        t = b.t[i]
        for k in range(3):
            a0, a1 = path[k], path[k + 1]
            tt = t + (k + 1) * b.tf // 4
            if a1 == a0:
                continue
            favourable = (a1 > a0) == p.buy
            if favourable:
                if not p.tp1_done and p.tp1 and ((p.buy and a1 >= p.tp1) or (not p.buy and a1 <= p.tp1)):
                    self._tp1(p.tp1, tt, i)
                    if self.pos is None:
                        return
                if (p.buy and a1 >= p.tp) or (not p.buy and a1 <= p.tp):
                    self._close(p.lots, p.tp, "TP", tt, i)
                    return
            else:
                if (p.buy and a1 <= p.sl) or (not p.buy and a1 >= p.sl):
                    be = abs(p.sl - p.open_price) < 1e-9
                    self._close(p.lots, p.sl, "Hoà vốn" if be else ("SL trailing" if p.tp1_done else "SL"), tt, i)
                    return

    def _gap_at_open(self, i):
        p, b = self.pos, self.b
        px = b.o[i] if p.buy else b.o[i] + b.spread[i]
        if (p.buy and px <= p.sl) or (not p.buy and px >= p.sl):
            self._close(p.lots, px, "SL (gap)", b.t[i], i)
        elif (p.buy and px >= p.tp) or (not p.buy and px <= p.tp):
            self._close(p.lots, px, "TP (gap)", b.t[i], i)

    def _view(self, i):
        pv = None
        if self.pos is not None:
            p = self.pos
            pv = PositionView()
            pv.buy, pv.open_price, pv.sl, pv.init_sl, pv.tp = p.buy, p.open_price, p.sl, p.init_sl, p.tp
            pv.tp1, pv.tp1_done, pv.open_t, pv.open_i, pv.best = p.tp1, p.tp1_done, p.open_t, p.open_i, p.best
            pv.tag, pv.lots = p.setup, p.lots
        av = AccountView()
        av.balance = self.balance
        av.trades_today_buy, av.trades_today_sell = self.day_buys, self.day_sells
        av.blocked = self.gate.blocked(self.day_pnl, self.day_start_balance, self.day_consec)
        av.spread = self.b.spread[i]
        return pv, av

    # -- main loop
    def run(self, progress=None):
        b, s = self.b, self.s
        n = len(b)
        s.prepare(b)
        pending = []
        for i in range(n):
            t = b.t[i]
            self._new_day_check(t)
            # 1) open of bar i: gaps, then orders decided at the previous close
            if self.pos is not None:
                self._gap_at_open(i)
            for act in pending:
                if isinstance(act, Enter):
                    if self.pos is None:
                        self._open(act, i)
                elif self.pos is not None:
                    if isinstance(act, Close):
                        px = b.o[i] if self.pos.buy else b.o[i] + b.spread[i]
                        self._close(self.pos.lots, px, act.reason, t, i)
                    elif isinstance(act, MoveSL):
                        better = act.sl > self.pos.sl if self.pos.buy else act.sl < self.pos.sl
                        if better:
                            self.pos.sl = act.sl
            pending = []
            # 2) inside bar i
            if self.pos is not None:
                self._walk_bar(i)
            if self.pos is not None:
                p = self.pos
                p.best = max(p.best, b.c[i]) if p.buy else min(p.best, b.c[i])
            # 3) close of bar i: strategy decides
            pv, av = self._view(i)
            dec_t = t + b.tf
            acts = s.on_bar(i, pv, av)
            for act in acts:
                if isinstance(act, Enter):
                    if av.blocked:
                        if self.day not in self._blocked_days:
                            self._blocked_days.add(self.day)
                            self.cnt["days_blocked"] += 1
                        continue
                    if (self.trade_from is not None and dec_t < self.trade_from) or \
                            (self.trade_to is not None and dec_t >= self.trade_to):
                        continue
                    if av.spread > self.r.max_spread_points * self.a.point:
                        self.cnt["skipped_spread"] += 1
                        continue
                pending.append(act)
            # equity at bar close
            eq = self.balance
            if self.pos is not None:
                p = self.pos
                px = b.c[i] if p.buy else b.c[i] + b.spread[i]
                eq += (px - p.open_price) * (1 if p.buy else -1) * p.lots * self.a.contract_size
            self.equity.append((t, self.balance, eq))
            if progress and i % 20000 == 0:
                progress(i, n)
        if self.pos is not None:
            p = self.pos
            px = b.c[-1] if p.buy else b.c[-1] + b.spread[-1]
            self._close(p.lots, px, "Kết thúc dữ liệu", b.t[-1] + b.tf, n - 1)
        self.cnt.update(s.diag)
        return self
