"""Momentum Scalper for XAUUSD M1: quick trades with the M15 trend in liquid hours.

Scalping gold lives or dies on costs: a 25-point spread is 0.25 USD, often a
big slice of a 1-2 USD stop. The engine charges the real spread of every bar
(from tick data), and ``risk.max_spread_points`` skips wide-spread moments.

1. Trend  : M15 close above a rising M15 EMA(``trend_ema``) = up (mirror for down).
2. Signal : M1 EMA(``fast``) crosses EMA(``slow``) in the trend direction and the
            bar closes beyond both, while ATR(M1) >= ``min_atr_points``.
3. Stop   : ``sl_atr`` x ATR(M1), at least ``min_sl_points``.
4. Exits  : target ``tp_r`` R; stop to breakeven at ``be_r`` R (0 = off);
            closed after ``max_hold_bars`` minutes or at ``flat_hour``.
5. Limits : ``max_trades_per_day``; one position at a time. The strategy keeps no
            memory between bars, so the live bot and the backtest decide identically.
"""

from dataclasses import dataclass

from ..common import ema, sma_atr
from ..engine import Close, Enter, MoveSL
from .base import BaseStrategy, ClockParams

M15 = 900


@dataclass
class ScalperParams(ClockParams):
    trade_start: float = 2.0
    trade_end: float = 11.0
    flat_hour: float = 11.5
    atr_period: int = 14
    fast: int = 9
    slow: int = 21
    trend_ema: int = 50
    trend_slope_bars: int = 2
    min_atr_points: float = 40
    sl_atr: float = 1.5
    min_sl_points: float = 150
    tp_r: float = 1.5
    be_r: float = 0.0
    max_hold_bars: int = 30
    max_trades_per_day: int = 8
    point: float = 0.01


class Scalper(BaseStrategy):
    name = "Scalper M1"
    key = "scalper"
    timeframe = 60
    Params = ScalperParams
    setup_names = {"SC": "Scalp EMA cắt theo xu hướng M15"}
    diag_labels = [
        ("entries", "Lệnh đã vào"), ("crosses", "EMA cắt nhau"), ("f_trend", "Bỏ: ngược xu hướng M15"),
        ("f_atr", "Bỏ: thị trường quá lặng"),
        ("skipped_spread", "Bỏ: spread rộng"), ("days_blocked", "Ngày bị khoá"),
    ]
    GRID = {
        "tp_r": ["1", "1.5", "2"],
        "sl_atr": ["1.0", "2.0"],
        "max_hold_bars": ["15", "45"],
        "be_r": ["0", "1"],
    }

    def _prepare(self, b):
        p = self.p
        self.atr = sma_atr(b.h, b.l, b.c, p.atr_period)
        self.ef, self.es = ema(b.c, p.fast), ema(b.c, p.slow)
        m15, self.k15 = self.htf_closed_index(b, M15)
        self.m15c, self.m15e = m15.c, ema(m15.c, p.trend_ema)

    def _trend(self, i):
        p, k = self.p, self.k15[i]
        if k < p.trend_ema + p.trend_slope_bars:
            return 0
        e, ep, c = self.m15e[k], self.m15e[k - p.trend_slope_bars], self.m15c[k]
        return 1 if (c > e and e > ep) else (-1 if (c < e and e < ep) else 0)

    def on_bar(self, i, pos, acct):
        p, b = self.p, self.b
        if pos is not None:
            if i - pos.open_i >= p.max_hold_bars:
                return [Close("Hết thời gian giữ")]
            if self.past_flat(i):
                return [Close("Hết giờ")]
            if p.be_r > 0:
                r = abs(pos.open_price - pos.init_sl)
                reached = (pos.best - pos.open_price) if pos.buy else (pos.open_price - pos.best)
                be_needed = (pos.buy and pos.sl < pos.open_price) or (not pos.buy and pos.sl > pos.open_price)
                if r > 0 and reached >= p.be_r * r and be_needed:
                    return [MoveSL(pos.open_price)]
            return []
        a = self.atr[i]
        if i < p.slow + 2 or a <= 0 or not self.in_trade_window(i):
            return []
        if acct.trades_today_buy + acct.trades_today_sell >= p.max_trades_per_day:
            return []
        up = self.ef[i] > self.es[i] and self.ef[i - 1] <= self.es[i - 1]
        dn = self.ef[i] < self.es[i] and self.ef[i - 1] >= self.es[i - 1]
        if not up and not dn:
            return []
        self.diag["crosses"] += 1
        c = b.c[i]
        if (up and c <= max(self.ef[i], self.es[i])) or (dn and c >= min(self.ef[i], self.es[i])):
            return []
        tr = self._trend(i)
        if (up and tr != 1) or (dn and tr != -1):
            self.diag["f_trend"] += 1
            return []
        if a < p.min_atr_points * p.point:
            self.diag["f_atr"] += 1
            return []
        dist = max(p.sl_atr * a, p.min_sl_points * p.point)
        sl = c - dist if up else c + dist
        return [Enter(up, sl, p.tp_r, 0.0, 0.5, "SC")]
