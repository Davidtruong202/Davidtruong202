"""Mean Reversion for XAUUSD M5: fade stretched moves back to the Bollinger middle band.

Works only when there is no strong trend, so it trades the quiet Asian session
by default and skips when the H1 EMA is sloping hard.

1. Filter : |H1 EMA slope over ``slope_bars``| < ``max_slope_h1atr`` x ATR(H1).
2. Signal : the previous M5 bar closed OUTSIDE Bollinger(``bb_period``, ``bb_dev``)
            with RSI(``rsi_period``) beyond ``rsi_extreme`` / 100 - it, and this bar
            closes back INSIDE the band.
3. Stop   : beyond the extreme of the last 3 bars (+``sl_buffer_atr`` ATR),
            clamped to ``min_sl_atr``..``max_sl_atr`` x ATR.
4. Target : the middle band, as R: skipped when it is closer than ``min_tp_r``,
            capped at ``max_tp_r``.
5. Time   : closed after ``max_hold_bars`` bars, or at ``flat_hour``.
"""

from dataclasses import dataclass

from ..common import H1, ema, sma_atr
from ..engine import Close, Enter
from .base import BaseStrategy, ClockParams, rolling_mean_std, rsi


@dataclass
class MeanRevParams(ClockParams):
    trade_start: float = 19.0
    trade_end: float = 3.0
    flat_hour: float = 5.0
    atr_period: int = 14
    bb_period: int = 20
    bb_dev: float = 2.0
    rsi_period: int = 14
    rsi_extreme: float = 30.0   # buy under it, sell above 100 - it
    trend_ema: int = 50
    slope_bars: int = 3
    max_slope_h1atr: float = 0.5
    h1_atr_period: int = 14
    sl_buffer_atr: float = 0.3
    min_sl_atr: float = 1.0
    max_sl_atr: float = 3.0
    min_tp_r: float = 0.8
    max_tp_r: float = 3.0
    max_hold_bars: int = 24
    max_trades_per_day: int = 4


class MeanReversion(BaseStrategy):
    name = "Mean Reversion"
    key = "meanrev"
    Params = MeanRevParams
    setup_names = {"MR": "Đảo chiều về dải giữa Bollinger"}
    diag_labels = [
        ("entries", "Lệnh đã vào"), ("signals", "Tín hiệu quay lại dải"), ("f_trend", "Bỏ: xu hướng H1 mạnh"),
        ("f_target", "Bỏ: dải giữa quá gần"), ("skipped_spread", "Bỏ: spread rộng"), ("days_blocked", "Ngày bị khoá"),
    ]
    GRID = {
        "bb_dev": ["2.0", "2.5"],
        "rsi_extreme": ["25", "30"],
        "max_slope_h1atr": ["0.3", "0.6"],
        "max_hold_bars": ["12", "36"],
    }

    def _prepare(self, b):
        p = self.p
        self.atr = sma_atr(b.h, b.l, b.c, p.atr_period)
        self.mid, sd = rolling_mean_std(b.c, p.bb_period)
        self.up = [m + p.bb_dev * s for m, s in zip(self.mid, sd)]
        self.dn = [m - p.bb_dev * s for m, s in zip(self.mid, sd)]
        self.rsi = rsi(b.c, p.rsi_period)
        h1, self.k1 = self.htf_closed_index(b, H1)
        self.h1e = ema(h1.c, p.trend_ema)
        self.h1a = sma_atr(h1.h, h1.l, h1.c, p.h1_atr_period)

    def on_bar(self, i, pos, acct):
        p, b = self.p, self.b
        if pos is not None:
            if i - pos.open_i >= p.max_hold_bars:
                return [Close("Hết thời gian giữ")]
            if self.past_flat(i):
                return [Close("Hết giờ")]
            return []
        a = self.atr[i]
        if i < p.bb_period + 3 or a <= 0 or not self.in_trade_window(i):
            return []
        if acct.trades_today_buy + acct.trades_today_sell >= p.max_trades_per_day:
            return []
        c, pc = b.c[i], b.c[i - 1]
        lo_x, hi_x = p.rsi_extreme, 100.0 - p.rsi_extreme
        buy = pc < self.dn[i - 1] and self.rsi[i - 1] <= lo_x and c > self.dn[i]
        sell = pc > self.up[i - 1] and self.rsi[i - 1] >= hi_x and c < self.up[i]
        if not buy and not sell:
            return []
        self.diag["signals"] += 1
        k = self.k1[i]
        if k < max(p.trend_ema, p.h1_atr_period) + p.slope_bars or self.h1a[k] <= 0:
            return []
        if abs(self.h1e[k] - self.h1e[k - p.slope_bars]) > p.max_slope_h1atr * self.h1a[k]:
            self.diag["f_trend"] += 1
            return []
        if buy:
            dist = c - (min(b.l[i - 2:i + 1]) - p.sl_buffer_atr * a)
        else:
            dist = (max(b.h[i - 2:i + 1]) + p.sl_buffer_atr * a) - c
        dist = min(max(dist, p.min_sl_atr * a), p.max_sl_atr * a)
        tp_r = ((self.mid[i] - c) if buy else (c - self.mid[i])) / dist
        if tp_r < p.min_tp_r:
            self.diag["f_target"] += 1
            return []
        sl = c - dist if buy else c + dist
        return [Enter(buy, sl, min(tp_r, p.max_tp_r), 0.0, 0.5, "MR")]
