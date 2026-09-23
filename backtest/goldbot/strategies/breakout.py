"""Session Breakout for XAUUSD M5.

Idea: gold coils in a range during the Asian session, then London / New York
volume breaks it. The bot trades the first decisive M5 close outside that range
in the direction of the H1 trend, and manages the trade in R multiples.

Rules (all times New York; a trading day starts at 17:00 NY like the gold market)
------------------------------------------------------------------------------
1. Range   : high/low of the bars between ``range_start`` and ``range_end``
             (default 19:00 -> 02:00 NY = the Asian session).
2. Filter  : range height must be between ``min_range_h1atr`` and
             ``max_range_h1atr`` x ATR(H1) - skips dead days and days that
             already exploded overnight.
3. Signal  : inside ``trade_start``..``trade_end`` an M5 bar CLOSES beyond the
             range by ``buffer_atr`` x ATR(M5), the previous close was still
             inside (fresh break), and the bar has a real body
             (body >= ``min_body`` x its range).
4. Trend   : longs only above a rising H1 EMA(``trend_ema``), shorts only below
             a falling one (``use_trend``).
5. Stop    : range midpoint, clamped to ``min_sl_atr``..``max_sl_atr`` x ATR(M5).
6. Exits   : ``tp1_frac`` closed at ``tp1_r`` R and stop to breakeven, rest
             targets ``tp_r`` R, trailed ``trail_atr`` x ATR(M5) behind the best
             close after TP1. Everything is flat by ``flat_hour``.
7. Limits  : at most ``max_trades_per_day``, one per direction.

Every value used at bar i is computed from bars <= i only, so the live bot and
the backtest see the same numbers.
"""

from dataclasses import dataclass

from ..common import HTF, H1, M5, NYClock, ema, sma_atr
from ..engine import Close, Enter, MoveSL

DAY_MIN = 24 * 60


@dataclass
class BreakoutParams:
    # broker clock (HFM: server = New York + 7h all year)
    broker_fixed_ny_offset: bool = True
    server_to_ny_hours: float = 7.0
    server_gmt_offset_hours: float = 0.0
    day_start_ny: float = 17.0
    # sessions (NY hours)
    range_start: float = 19.0
    range_end: float = 2.0
    trade_start: float = 2.0
    trade_end: float = 11.0
    flat_hour: float = 15.0
    # filters
    atr_period: int = 14
    h1_atr_period: int = 14
    min_range_h1atr: float = 1.0
    max_range_h1atr: float = 5.0
    buffer_atr: float = 0.1
    min_body: float = 0.5
    use_trend: bool = True
    trend_ema: int = 50
    trend_slope_bars: int = 3
    # trade management
    min_sl_atr: float = 1.5
    max_sl_atr: float = 5.0
    tp_r: float = 2.0
    tp1_r: float = 1.0
    tp1_frac: float = 0.5
    trail_atr: float = 3.0
    max_trades_per_day: int = 2


class SessionBreakout:
    name = "Session Breakout"
    key = "breakout"
    Params = BreakoutParams
    setup_names = {"BO": "Breakout range phiên Á"}
    kz_names = {0: "Ngoài giờ", 1: "Range phiên Á", 2: "Giờ vào lệnh"}
    diag_labels = [
        ("entries", "Lệnh đã vào"), ("breaks", "Nến phá range"), ("f_range", "Bỏ: range không đạt"),
        ("f_trend", "Bỏ: ngược xu hướng H1"), ("f_body", "Bỏ: thân nến yếu"), ("f_side", "Bỏ: đã đánh chiều này"),
        ("skipped_spread", "Bỏ: spread rộng"), ("days_blocked", "Ngày bị khoá (lỗ ngày/thua liên tiếp)"),
        ("days", "Số ngày giao dịch"), ("days_range_ok", "Ngày có range hợp lệ"),
    ]

    def __init__(self, params=None):
        self.p = params or BreakoutParams()
        p = self.p
        self.clock = NYClock(p.broker_fixed_ny_offset, p.server_to_ny_hours, p.server_gmt_offset_hours)
        self.diag = dict(breaks=0, f_range=0, f_trend=0, f_body=0, f_side=0, days=0, days_range_ok=0)
        self.session_codes = []

    # minutes since the trading-day start (17:00 NY)
    def _rel(self, srv):
        ny = self.clock.ny(srv)
        return ((ny % 86400) // 60 - int(self.p.day_start_ny * 60)) % DAY_MIN

    def _relh(self, hour):
        return int(round((hour - self.p.day_start_ny) * 60)) % DAY_MIN

    def session_name(self, srv):
        return self.kz_names[self._code(self._rel(srv))]

    def _code(self, m):
        if self.rs <= m < self.re:
            return 1
        if self.ts <= m < self.te:
            return 2
        return 0

    # ------------------------------------------------------------------
    def prepare(self, bars):
        """Precompute causal indicators for every bar."""
        p, b = self.p, bars
        self.b = b
        n = len(b)
        self.rs, self.re = self._relh(p.range_start), self._relh(p.range_end)
        self.ts, self.te = self._relh(p.trade_start), self._relh(p.trade_end)
        self.fl = self._relh(p.flat_hour)
        self.atr = sma_atr(b.h, b.l, b.c, p.atr_period)

        h1 = HTF(b, lambda t: t // H1)
        h1_atr = sma_atr(h1.h, h1.l, h1.c, p.h1_atr_period)
        h1_ema = ema(h1.c, p.trend_ema)
        self.h1_atr, self.ema_now, self.ema_prev = [0.0] * n, [0.0] * n, [0.0] * n
        self.rng_hi, self.rng_lo = [None] * n, [None] * n
        self.rel_close = [0] * n
        codes = [0] * n

        day, rh, rl, days = None, None, None, set()
        for i in range(n):
            t = b.t[i]
            # last H1 bucket fully closed at the close of bar i
            k = h1.bucket_of[i] if (t + M5) % H1 == 0 else h1.bucket_of[i] - 1
            if k >= p.h1_atr_period:
                self.h1_atr[i] = h1_atr[k]
            if k >= p.trend_ema:
                self.ema_now[i] = h1_ema[k]
                self.ema_prev[i] = h1_ema[k - p.trend_slope_bars]

            m_open = self._rel(t)
            d = (self.clock.ny(t) - int(p.day_start_ny * 3600)) // 86400
            if d != day:
                day, rh, rl = d, None, None
                days.add(d)
            if self.rs <= m_open < self.re:
                rh = b.h[i] if rh is None else max(rh, b.h[i])
                rl = b.l[i] if rl is None else min(rl, b.l[i])
            m_close = m_open + 5
            self.rel_close[i] = m_close
            if rh is not None and m_close >= self.re:
                self.rng_hi[i], self.rng_lo[i] = rh, rl
            codes[i] = self._code(m_open)
        self.session_codes = codes
        self.diag["days"] = len(days)
        self._range_ok_days = set()

    # ------------------------------------------------------------------
    def on_bar(self, i, pos, acct):
        p, b = self.p, self.b
        m = self.rel_close[i]
        a = self.atr[i]

        if pos is not None:
            if m >= self.fl:
                return [Close("Hết giờ")]
            if pos.tp1_done and p.trail_atr > 0 and a > 0:
                if pos.buy:
                    sl = pos.best - p.trail_atr * a
                    if sl > pos.sl:
                        return [MoveSL(sl)]
                else:
                    sl = pos.best + p.trail_atr * a
                    if sl < pos.sl:
                        return [MoveSL(sl)]
            return []

        if not (self.ts <= m <= self.te) or i < 1 or a <= 0:
            return []
        rh, rl = self.rng_hi[i], self.rng_lo[i]
        ha = self.h1_atr[i]
        if rh is None or ha <= 0:
            return []
        if acct.trades_today_buy + acct.trades_today_sell >= p.max_trades_per_day:
            return []

        buf = p.buffer_atr * a
        c, prev = b.c[i], b.c[i - 1]
        up = c > rh + buf and prev <= rh + buf
        dn = c < rl - buf and prev >= rl - buf
        if not up and not dn:
            return []
        self.diag["breaks"] += 1

        height = rh - rl
        if not (p.min_range_h1atr * ha <= height <= p.max_range_h1atr * ha):
            self.diag["f_range"] += 1
            return []
        day = (self.clock.ny(b.t[i]) - int(p.day_start_ny * 3600)) // 86400
        if day not in self._range_ok_days:
            self._range_ok_days.add(day)
            self.diag["days_range_ok"] += 1

        rng = b.h[i] - b.l[i]
        if rng <= 0 or abs(c - b.o[i]) < p.min_body * rng or (up and c < b.o[i]) or (dn and c > b.o[i]):
            self.diag["f_body"] += 1
            return []
        if p.use_trend:
            en, ep = self.ema_now[i], self.ema_prev[i]
            if en <= 0 or (up and not (c > en and en > ep)) or (dn and not (c < en and en < ep)):
                self.diag["f_trend"] += 1
                return []
        if (up and acct.trades_today_buy) or (dn and acct.trades_today_sell):
            self.diag["f_side"] += 1
            return []

        mid = (rh + rl) / 2.0
        dist = abs(c - mid)
        dist = min(max(dist, p.min_sl_atr * a), p.max_sl_atr * a)
        sl = c - dist if up else c + dist
        return [Enter(up, sl, p.tp_r, p.tp1_r, p.tp1_frac, "BO")]
