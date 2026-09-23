"""Trend Pullback for XAUUSD M5: buy dips in an H1 uptrend, sell rallies in a downtrend.

1. Trend  : H1 close above a rising H1 EMA(``trend_ema``) = up (mirror for down).
2. Dip    : within the last ``touch_bars`` M5 bars price came back to the M5
            EMA(``ema_fast``) (within ``touch_atr`` x ATR).
3. Resume : the M5 bar closes back beyond the EMA, in the trend direction, and
            above the highs (below the lows) of the previous ``confirm_bars`` bars.
4. Stop   : beyond the swing of the last ``sl_lookback`` bars (+0.2 ATR), clamped
            to ``min_sl_atr``..``max_sl_atr`` x ATR(M5).
5. Exits  : ``tp1_frac`` at ``tp1_r`` R + breakeven, rest at ``tp_r`` R, flat at ``flat_hour``.
"""

from dataclasses import dataclass

from ..common import H1, ema, sma_atr
from ..engine import Close, Enter, MoveSL
from .base import BaseStrategy, ClockParams


@dataclass
class PullbackParams(ClockParams):
    trade_start: float = 2.0
    trade_end: float = 12.0
    flat_hour: float = 15.5
    atr_period: int = 14
    trend_ema: int = 50
    trend_slope_bars: int = 3
    ema_fast: int = 20
    touch_bars: int = 6
    touch_atr: float = 0.3
    confirm_bars: int = 2
    sl_lookback: int = 10
    min_sl_atr: float = 1.0
    max_sl_atr: float = 4.0
    tp_r: float = 2.0
    tp1_r: float = 1.0
    tp1_frac: float = 0.5
    trail_atr: float = 0.0
    max_trades_per_day: int = 3


class TrendPullback(BaseStrategy):
    name = "Trend Pullback"
    key = "pullback"
    Params = PullbackParams
    setup_names = {"PB": "Pullback theo xu hướng H1"}
    diag_labels = [
        ("entries", "Lệnh đã vào"), ("signals", "Tín hiệu pullback"), ("f_sl", "Bỏ: SL quá xa"),
        ("skipped_spread", "Bỏ: spread rộng"), ("days_blocked", "Ngày bị khoá"),
    ]
    GRID = {
        "tp_r": ["1.5", "2", "3"],
        "ema_fast": ["20", "34"],
        "touch_atr": ["0.2", "0.5"],
        "trail_atr": ["0", "3"],
    }

    def _prepare(self, b):
        p = self.p
        self.atr = sma_atr(b.h, b.l, b.c, p.atr_period)
        self.ema_f = ema(b.c, p.ema_fast)
        h1, self.k1 = self.htf_closed_index(b, H1)
        self.h1c = h1.c
        self.h1e = ema(h1.c, p.trend_ema)

    def _trend(self, i):
        p, k = self.p, self.k1[i]
        if k < p.trend_ema + p.trend_slope_bars:
            return 0
        e, ep, c = self.h1e[k], self.h1e[k - p.trend_slope_bars], self.h1c[k]
        if c > e and e > ep:
            return 1
        if c < e and e < ep:
            return -1
        return 0

    def on_bar(self, i, pos, acct):
        p, b = self.p, self.b
        a = self.atr[i]
        if pos is not None:
            if self.past_flat(i):
                return [Close("Hết giờ")]
            if pos.tp1_done and p.trail_atr > 0 and a > 0:
                sl = pos.best - p.trail_atr * a if pos.buy else pos.best + p.trail_atr * a
                if (pos.buy and sl > pos.sl) or (not pos.buy and sl < pos.sl):
                    return [MoveSL(sl)]
            return []
        n = max(p.touch_bars, p.sl_lookback, p.confirm_bars) + 1
        if i < n or a <= 0 or not self.in_trade_window(i):
            return []
        if acct.trades_today_buy + acct.trades_today_sell >= p.max_trades_per_day:
            return []
        tr = self._trend(i)
        if tr == 0:
            return []
        c, e = b.c[i], self.ema_f[i]
        tol = p.touch_atr * a
        if tr > 0:
            touched = any(b.l[k] <= self.ema_f[k] + tol for k in range(i - p.touch_bars, i))
            resume = c > e and c > b.o[i] and c > max(b.h[k] for k in range(i - p.confirm_bars, i))
        else:
            touched = any(b.h[k] >= self.ema_f[k] - tol for k in range(i - p.touch_bars, i))
            resume = c < e and c < b.o[i] and c < min(b.l[k] for k in range(i - p.confirm_bars, i))
        if not (touched and resume):
            return []
        self.diag["signals"] += 1
        if tr > 0:
            dist = c - (min(b.l[k] for k in range(i - p.sl_lookback + 1, i + 1)) - 0.2 * a)
        else:
            dist = (max(b.h[k] for k in range(i - p.sl_lookback + 1, i + 1)) + 0.2 * a) - c
        if dist > p.max_sl_atr * a:
            self.diag["f_sl"] += 1
            return []
        dist = max(dist, p.min_sl_atr * a)
        sl = c - dist if tr > 0 else c + dist
        return [Enter(tr > 0, sl, p.tp_r, p.tp1_r, p.tp1_frac, "PB")]
