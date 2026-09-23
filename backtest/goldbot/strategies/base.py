"""Shared plumbing for strategies: broker clock, trading-day minutes, sessions, HTF lookups."""

from dataclasses import dataclass

from ..common import HTF, NYClock

DAY_MIN = 24 * 60


@dataclass
class ClockParams:
    # broker clock (HFM: server GMT+2/+3 on the EU calendar)
    broker_eu_dst: bool = True
    broker_fixed_ny_offset: bool = True
    server_to_ny_hours: float = 7.0
    server_gmt_offset_hours: float = 0.0
    day_start_ny: float = 17.0


class BaseStrategy:
    """Subclasses set: name, key, Params, setup_names, diag_labels, GRID and implement
    ``_prepare(bars)`` + ``on_bar(i, pos, acct)``. Params need trade_start/trade_end/flat_hour."""

    timeframe = 300
    kz_names = {0: "Ngoài giờ", 2: "Giờ vào lệnh"}
    GRID = {}

    def __init__(self, params=None):
        self.p = params or self.Params()
        p = self.p
        self.clock = NYClock(p.broker_fixed_ny_offset, p.server_to_ny_hours, p.server_gmt_offset_hours,
                             p.broker_eu_dst)
        engine_keys = {"entries", "skipped_spread", "days_blocked", "skipped_risk"}
        self.diag = {k: 0 for k, _ in self.diag_labels if k not in engine_keys}
        self.session_codes = []

    # minutes since the trading-day start (17:00 NY)
    def rel(self, srv):
        ny = self.clock.ny(srv)
        return ((ny % 86400) // 60 - int(self.p.day_start_ny * 60)) % DAY_MIN

    def relh(self, hour):
        return int(round((hour - self.p.day_start_ny) * 60)) % DAY_MIN

    def day(self, srv):
        return (self.clock.ny(srv) - int(self.p.day_start_ny * 3600)) // 86400

    def session_name(self, srv):
        return self.kz_names[self._code(self.rel(srv))]

    def _code(self, m):
        return 2 if self.ts <= m < self.te else 0

    def prepare(self, bars):
        p = self.p
        self.b = bars
        self.tf = bars.tf
        self.ts, self.te, self.fl = self.relh(p.trade_start), self.relh(p.trade_end), self.relh(p.flat_hour)
        n = len(bars)
        self.rel_close = [0] * n
        codes = [0] * n
        for i in range(n):
            m = self.rel(bars.t[i])
            self.rel_close[i] = m + bars.tf // 60
            codes[i] = self._code(m)
        self.session_codes = codes
        self._prepare(bars)

    def in_trade_window(self, i):
        return self.ts <= self.rel_close[i] <= self.te

    def past_flat(self, i):
        return self.rel_close[i] >= self.fl

    def htf_closed_index(self, bars, seconds):
        """HTF bars + for every bar i the index of the last HTF bar fully closed at bar i's close."""
        h = HTF(bars, lambda t: t // seconds)
        idx = [0] * len(bars)
        for i in range(len(bars)):
            k = h.bucket_of[i]
            idx[i] = k if (bars.t[i] + bars.tf) % seconds == 0 else k - 1
        return h, idx


def rolling_mean_std(values, period):
    n = len(values)
    mean, std = [0.0] * n, [0.0] * n
    s = s2 = 0.0
    for i, v in enumerate(values):
        s += v
        s2 += v * v
        if i >= period:
            o = values[i - period]
            s -= o
            s2 -= o * o
        if i >= period - 1:
            m = s / period
            mean[i] = m
            std[i] = max(0.0, s2 / period - m * m) ** 0.5
    return mean, std


def rsi(closes, period):
    """Wilder RSI (as MT5 iRSI). 50 until enough data."""
    n = len(closes)
    out = [50.0] * n
    ag = al = 0.0
    for i in range(1, n):
        ch = closes[i] - closes[i - 1]
        g, l = max(ch, 0.0), max(-ch, 0.0)
        if i <= period:
            ag += g / period
            al += l / period
            if i < period:
                continue
        else:
            ag = (ag * (period - 1) + g) / period
            al = (al * (period - 1) + l) / period
        out[i] = 100.0 if al == 0 else 100.0 - 100.0 / (1.0 + ag / al)
    return out
