"""Shared building blocks: account spec, time zones, higher-timeframe bars, indicators."""

from dataclasses import dataclass
from datetime import datetime, timezone

M5 = 300
H1 = 3600
H4 = 4 * 3600
DAY = 86400


@dataclass
class Account:
    initial_balance: float = 10_000.0
    contract_size: float = 100.0      # XAUUSD: 1 lot = 100 oz
    tick_size: float = 0.01
    tick_value: float = 1.0           # USD per tick per lot (0.01 * 100)
    volume_min: float = 0.01
    volume_max: float = 100.0
    volume_step: float = 0.01
    commission_per_lot: float = 0.0   # round-turn USD per lot, charged on exit deals
    point: float = 0.01


def lot_size(balance, risk_percent, sl_dist, tick_size, tick_value, vmin, vmax, vstep):
    """Same sizing as the EA's CalculateLotSize (floored to the volume step)."""
    if tick_size <= 0 or tick_value <= 0 or sl_dist <= 0:
        return 0.0
    lots = balance * risk_percent / 100.0 / (sl_dist / tick_size * tick_value)
    step = vstep or 0.01
    lots = int(lots / step + 1e-9) * step
    return round(max(vmin, min(vmax, lots)), 2)


# ---------------------------------------------------------------------------
# Time zones. Broker server time is kept as naive epoch seconds.
# ---------------------------------------------------------------------------
def _nth_sunday(year, month, n):
    first = datetime(year, month, 1, tzinfo=timezone.utc)
    days_to_sunday = (6 - first.weekday()) % 7  # python: Monday=0 .. Sunday=6
    return int(first.timestamp()) + (days_to_sunday + (n - 1) * 7) * DAY


_dst_cache = {}
_eu_cache = {}


def _last_sunday(year, month):
    nxt = datetime(year + (month == 12), month % 12 + 1, 1, tzinfo=timezone.utc)
    last = int(nxt.timestamp()) - DAY
    wd = datetime.fromtimestamp(last, tz=timezone.utc).weekday()  # Monday=0 .. Sunday=6
    return last - ((wd + 1) % 7) * DAY


def is_eu_dst(gmt):
    """EU summer time: last Sunday of March 01:00 UTC -> last Sunday of October 01:00 UTC."""
    y = datetime.fromtimestamp(gmt, tz=timezone.utc).year
    rng = _eu_cache.get(y)
    if rng is None:
        rng = _eu_cache[y] = (_last_sunday(y, 3) + 3600, _last_sunday(y, 10) + 3600)
    return rng[0] <= gmt < rng[1]


def is_us_dst(gmt):
    y = datetime.fromtimestamp(gmt, tz=timezone.utc).year
    rng = _dst_cache.get(y)
    if rng is None:
        rng = _dst_cache[y] = (_nth_sunday(y, 3, 2), _nth_sunday(y, 11, 1))
    return rng[0] <= gmt < rng[1]


class NYClock:
    """Server time -> New York time.

    eu_dst=True       : server is GMT+2 in winter / GMT+3 in EU summer time (HFM and most
                        "GMT+2/+3" brokers). NY is then 7h behind, except ~3 weeks in March
                        and 1 week around November when the EU and US switch on different
                        dates (6h) - checked on HFM XAUUSDc data: the market reopens at
                        00:00 server instead of 01:00 in exactly those weeks.
    fixed_offset=True : server is always `server_to_ny` hours ahead of NY.
    fixed_offset=False: server runs a fixed GMT offset (e.g. Exness GMT+0);
                        US daylight saving is applied.
    """

    def __init__(self, fixed_offset=True, server_to_ny=7.0, server_gmt=0.0, eu_dst=False):
        self.fixed, self.to_ny, self.gmt, self.eu = fixed_offset, server_to_ny, server_gmt, eu_dst

    def ny(self, srv):
        if self.eu:
            g = srv - 2 * 3600
            g = srv - (3 if is_eu_dst(g) else 2) * 3600
            return g - (4 if is_us_dst(g) else 5) * 3600
        if self.fixed:
            return srv - int(self.to_ny * 3600)
        g = srv - int(self.gmt * 3600)
        return g - (4 if is_us_dst(g) else 5) * 3600

    def hour(self, srv):
        s = self.ny(srv) % DAY
        return s // 3600 + (s % 3600 // 60) / 60.0


def in_hours(h, start, end):
    if start == end:
        return True
    if start < end:
        return start <= h < end
    return h >= start or h < end


# ---------------------------------------------------------------------------
# Higher timeframe buckets built from M5
# ---------------------------------------------------------------------------
class HTF:
    """Completed + forming bars of a higher timeframe, indexed by bucket number."""

    def __init__(self, bars, key_fn):
        self.key, self.first, self.o, self.h, self.l, self.c = [], [], [], [], [], []
        self.bucket_of = [0] * len(bars)
        cur = None
        for i in range(len(bars)):
            k = key_fn(bars.t[i])
            if k != cur:
                cur = k
                self.key.append(k); self.first.append(i)
                self.o.append(bars.o[i]); self.h.append(bars.h[i]); self.l.append(bars.l[i]); self.c.append(bars.c[i])
            else:
                b = len(self.key) - 1
                if bars.h[i] > self.h[b]:
                    self.h[b] = bars.h[i]
                if bars.l[i] < self.l[b]:
                    self.l[b] = bars.l[i]
                self.c[b] = bars.c[i]
            self.bucket_of[i] = len(self.key) - 1


def week_key(t):
    # MT5 weekly bars open on Sunday 00:00. 1970-01-04 (epoch day 3) was a Sunday.
    return (t // DAY - 3) // 7


# ---------------------------------------------------------------------------
# Indicators (causal: value at i only uses data up to and including i)
# ---------------------------------------------------------------------------
def sma_atr(h, l, c, period):
    """MT5 iATR = simple moving average of True Range. 0 until enough data."""
    n = len(c)
    atr = [0.0] * n
    s = 0.0
    tr = [0.0] * n
    for i in range(n):
        tr[i] = h[i] - l[i] if i == 0 else max(h[i], c[i - 1]) - min(l[i], c[i - 1])
        s += tr[i]
        if i >= period:
            s -= tr[i - period]
        if i >= period - 1:
            atr[i] = s / period
    return atr


def ema(values, period):
    out = [0.0] * len(values)
    k = 2.0 / (period + 1)
    e = None
    for i, v in enumerate(values):
        e = v if e is None else e + k * (v - e)
        out[i] = e
    return out
