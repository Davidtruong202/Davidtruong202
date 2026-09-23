"""Bar-by-bar Python port of MQL5/Experts/XAUUSD_ICT_M5.mq5.

The simulation reproduces how the MT5 Strategy Tester drives the EA:

  * The EA only acts on the FIRST tick of each new M5 bar (``CacheBar1IfNew``),
    reading the bar that just closed ("bar1"). Here that tick is modelled as
    the open of bar j; orders fill at open[j] (bid) or open[j] + spread (ask).
  * SL and TP2 are resting broker orders, checked inside every bar using its
    high/low. When one bar touches both, the SL is assumed to fill first
    (conservative). A gap through a level fills at the open.
  * Buy positions close on the bid, sell positions close on the ask
    (bid + that bar's spread), like MT5.
  * H4 / D1 / W1 bars are built from the M5 data by server time, W1 starting
    on Sunday like MT5. The still-forming bar (shift 0) only knows its open
    price, as on the first tick in the tester.

Function names mirror the MQL5 source so the two can be compared side by side.
"""

from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone

M5 = 300
H4 = 4 * 3600
DAY = 86400

# Level types
LVL_PDH, LVL_PDL, LVL_PWH, LVL_PWL = "PDH", "PDL", "PWH", "PWL"
LVL_ASIAN_H, LVL_ASIAN_L, LVL_LONDON_H, LVL_LONDON_L = "AsiaH", "AsiaL", "LonH", "LonL"
LVL_SWING_BSL, LVL_SWING_SSL, LVL_EQH, LVL_EQL = "BSL", "SSL", "EQH", "EQL"
SINGLETONS = {LVL_PDH, LVL_PDL, LVL_PWH, LVL_PWL, LVL_ASIAN_H, LVL_ASIAN_L, LVL_LONDON_H, LVL_LONDON_L}

# Killzones
KZ_NONE, KZ_ASIAN, KZ_LONDON, KZ_NYAM, KZ_LCLOSE, KZ_NYPM = 0, 1, 2, 3, 4, 5
KZ_NAMES = {KZ_NONE: "-", KZ_ASIAN: "Asian", KZ_LONDON: "London", KZ_NYAM: "NY AM",
            KZ_LCLOSE: "London Close", KZ_NYPM: "NY PM"}

SETUP_NAMES = {"A": "A · London Judas", "B": "B · NY AM Continuation",
               "C": "C · PDH/PDL Reversal", "D": "D · Turtle Soup"}

FRESH, MITIGATED, VOID = 0, 1, 2


@dataclass
class Params:
    # Timezone (NY)
    broker_fixed_ny_offset: bool = True
    server_to_ny_hours: float = 7.0
    server_gmt_offset_hours: float = 0.0
    # Killzones (NY time, decimal hours)
    enable_asian: bool = True
    asian_start: float = 20.0
    asian_end: float = 0.0
    enable_london: bool = True
    london_start: float = 2.0
    london_end: float = 5.0
    enable_nyam: bool = True
    nyam_start: float = 7.0
    nyam_end: float = 10.0
    enable_lclose: bool = True
    lclose_start: float = 10.0
    lclose_end: float = 12.0
    enable_nypm: bool = False
    nypm_start: float = 13.5
    nypm_end: float = 16.0
    # Structure & liquidity
    piv_len: int = 8
    eq_tol_atr: float = 0.25
    h4_piv_len: int = 3
    # Displacement / OB / FVG
    disp_atr: float = 1.5
    disp_body: float = 0.6
    fvg_min_atr: float = 0.2
    ob_require_fvg: bool = True
    ob_use_wick: bool = False
    # ICT score
    score_buy_threshold: float = 60
    score_sell_threshold: float = 40
    # Setups
    enable_setup_a: bool = True
    enable_setup_b: bool = True
    enable_setup_c: bool = True
    enable_setup_d: bool = True
    setup_a_max_bars_since_sweep: int = 16
    setup_b_max_bars_lookback: int = 30
    setup_b_cutoff_hour: float = 11.0
    setup_c_max_bars: int = 10
    setup_d_max_bars: int = 6
    # Risk
    risk_percent: float = 0.75
    min_rr_tp1: float = 1.5
    min_rr_tp2: float = 2.0
    max_trades_per_kz: int = 2
    max_daily_loss_percent: float = 3.0
    max_consec_losses: int = 3
    pause_minutes: int = 60
    sweep_sl_buffer_atr: float = 0.35
    zone_sl_buffer_atr: float = 0.3
    # News
    news_hour_ny: float = 8.5
    news_blackout_min_before: float = 15
    atr_period: int = 14


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


# ---------------------------------------------------------------------------
# Small records (plain classes with __slots__ are much faster than dicts here)
# ---------------------------------------------------------------------------
class Swing:
    __slots__ = ("t", "price", "broken", "used_in_eq")

    def __init__(self, t, price):
        self.t, self.price, self.broken, self.used_in_eq = t, price, False, False


class Level:
    __slots__ = ("type", "price", "is_buy_side", "swept", "formed")

    def __init__(self, type_, price, is_buy_side, swept, formed):
        self.type, self.price, self.is_buy_side, self.swept, self.formed = type_, price, is_buy_side, swept, formed


class Zone:
    __slots__ = ("bullish", "is_ob", "top", "bottom", "state", "has_fvg_pair", "reacted", "formed")


class Sweep:
    __slots__ = ("src", "bullish", "level", "extreme", "opposite", "t", "judas", "used")


class Struct:
    __slots__ = ("choch", "bullish", "t")

    def __init__(self, choch, bullish, t):
        self.choch, self.bullish, self.t = choch, bullish, t


class Position:
    __slots__ = ("id", "buy", "lots", "open_price", "sl", "tp", "tp1", "setup", "comment",
                 "open_t", "open_i", "risk_money", "init_sl", "init_lots", "pnl", "exits", "kz")


# ---------------------------------------------------------------------------
# Timezone helpers (port of NthSundayOfMonth / IsUSDaylightSaving / GetNYTime)
# ---------------------------------------------------------------------------
def _nth_sunday(year, month, n):
    first = datetime(year, month, 1, tzinfo=timezone.utc)
    days_to_sunday = (6 - first.weekday()) % 7  # python: Monday=0 .. Sunday=6
    return int(first.timestamp()) + (days_to_sunday + (n - 1) * 7) * DAY


_dst_cache = {}


def _is_us_dst(gmt):
    y = datetime.fromtimestamp(gmt, tz=timezone.utc).year
    rng = _dst_cache.get(y)
    if rng is None:
        rng = _dst_cache[y] = (_nth_sunday(y, 3, 2), _nth_sunday(y, 11, 1))
    return rng[0] <= gmt < rng[1]


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


def _week_key(t):
    # MT5 weekly bars open on Sunday 00:00. 1970-01-04 (epoch day 3) was a Sunday.
    return (t // DAY - 3) // 7


# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------
class ICTBacktest:
    def __init__(self, bars, params=None, account=None, trade_from=None, trade_to=None):
        self.b = bars
        self.p = params or Params()
        self.a = account or Account()
        self.trade_from, self.trade_to = trade_from, trade_to

        n = len(bars)
        self.atr = self._compute_atr()
        self.h4 = HTF(bars, lambda t: t // H4)
        self.d1 = HTF(bars, lambda t: t // DAY)
        self.w1 = HTF(bars, _week_key)
        self.kz_by_bar = [0] * n  # killzone for each bar (chart shading)

        # EA globals
        self.swing_highs, self.swing_lows = [], []
        self.h4_swing_highs, self.h4_swing_lows = [], []
        self.levels = []          # ordered like the EA's liqLevels[] (swept non-singletons pruned)
        self.singleton = {}       # type -> Level
        self.zones = []
        self.sweeps = []
        self.structs = []

        self.bar1 = None          # (t, o, h, l, c) of the closed bar
        self.atr_v = 0.0
        self.cur_kz = KZ_NONE
        self.run_asian_h = self.run_asian_l = self.run_lon_h = self.run_lon_l = -1.0
        self.judas_london_done = self.judas_ny_done = False
        self.trades_this_kz = 0
        self.struct_trend = 0
        self.h4_bias = 0
        self.h4_pd = 50.0
        self.pd_percent = 50.0
        self.deal_hi = self.deal_lo = 0.0
        self.ict_score = 50.0
        self.last_d1 = self.last_w1 = self.last_h4 = None

        self.balance = self.a.initial_balance
        self.day_start_balance = self.balance
        self.current_day = None
        self.consec_losses = 0
        self.paused_until = 0

        self.pos = None
        self.tp1_taken = False
        self.next_id = 1

        # outputs
        self.trades = []          # closed Position records
        self.equity = []          # (t, balance, equity) sampled at every bar close
        self.events = []          # log lines for the report
        self.cnt = dict(bars=0, sweeps=0, zones=0, bos=0, choch=0, A=0, B=0, C=0, D=0,
                        skipped_rr=0, blocked_news=0, blocked_daily=0, blocked_pause=0)

    # ------------------------------------------------------------------ utils
    def _compute_atr(self):
        """MT5 iATR = simple moving average of True Range."""
        b, per = self.b, self.p.atr_period
        n = len(b)
        tr = [0.0] * n
        for i in range(n):
            if i == 0:
                tr[i] = b.h[i] - b.l[i]
            else:
                pc = b.c[i - 1]
                tr[i] = max(b.h[i], pc) - min(b.l[i], pc)
        atr = [0.0] * n
        s = 0.0
        for i in range(n):
            s += tr[i]
            if i >= per:
                s -= tr[i - per]
            if i >= per - 1:
                atr[i] = s / per
        return atr

    def ny_time(self, srv):
        p = self.p
        if p.broker_fixed_ny_offset:
            return srv - int(p.server_to_ny_hours * 3600)
        gmt = srv - int(p.server_gmt_offset_hours * 3600)
        return gmt - (4 if _is_us_dst(gmt) else 5) * 3600

    def ny_hour(self, srv):
        ny = self.ny_time(srv) % DAY
        return ny // 3600 + (ny % 3600 // 60) / 60.0

    def _kz_at(self, srv):
        p, h = self.p, self.ny_hour(srv)
        if p.enable_asian and in_hours(h, p.asian_start, p.asian_end):
            return KZ_ASIAN
        if p.enable_london and in_hours(h, p.london_start, p.london_end):
            return KZ_LONDON
        if p.enable_nyam and in_hours(h, p.nyam_start, p.nyam_end):
            return KZ_NYAM
        if p.enable_lclose and in_hours(h, p.lclose_start, p.lclose_end):
            return KZ_LCLOSE
        if p.enable_nypm and in_hours(h, p.nypm_start, p.nypm_end):
            return KZ_NYPM
        return KZ_NONE

    # M5 series access with MT5 shift semantics relative to the current bar j
    def _hi(self, shift):
        return self.b.o[self.j] if shift == 0 else self.b.h[self.j - shift]

    def _lo(self, shift):
        return self.b.o[self.j] if shift == 0 else self.b.l[self.j - shift]

    # -------------------------------------------------------- liquidity levels
    def add_level(self, type_, price, is_buy_side, swept, formed):
        if type_ in SINGLETONS:
            lv = self.singleton.get(type_)
            if lv is not None:
                lv.price, lv.is_buy_side, lv.swept, lv.formed = price, is_buy_side, swept, formed
                return
            lv = Level(type_, price, is_buy_side, swept, formed)
            self.singleton[type_] = lv
            self.levels.append(lv)
            return
        self.levels.append(Level(type_, price, is_buy_side, swept, formed))

    def nearest_opposite_liquidity(self, bullish):
        best, found, c = 0.0, False, self.bar1[4]
        for lv in self.levels:
            if lv.swept or lv.is_buy_side != bullish:
                continue
            p = lv.price
            if bullish and p <= c:
                continue
            if not bullish and p >= c:
                continue
            if not found or (bullish and p < best) or (not bullish and p > best):
                best, found = p, True
        return best if found else 0.0

    def tp2(self, bullish):
        s, c = self.singleton, self.bar1[4]
        pdh = s[LVL_PDH].price if LVL_PDH in s else 0.0
        pdl = s[LVL_PDL].price if LVL_PDL in s else 0.0
        pwh = s[LVL_PWH].price if LVL_PWH in s else 0.0
        pwl = s[LVL_PWL].price if LVL_PWL in s else 0.0
        if bullish:
            if pdh > c:
                return pdh
            if pwh > c:
                return pwh
            return 0.0
        if 0 < pdl < c:
            return pdl
        if 0 < pwl < c:
            return pwl
        return 0.0

    def dealing_range_eq(self):
        return (self.deal_hi + self.deal_lo) / 2.0 if self.deal_hi > self.deal_lo else 0.0

    # ------------------------------------------------------------- swings
    def _check_equal_level(self, arr, is_high):
        new = arr[-1]
        tol = self.p.eq_tol_atr * self.atr_v
        for k in range(len(arr) - 2, -1, -1):
            s = arr[k]
            if s.used_in_eq:
                continue
            if abs(new.price - s.price) <= tol:
                new.used_in_eq = s.used_in_eq = True
                self.add_level(LVL_EQH if is_high else LVL_EQL, new.price, is_high, False, new.t)
                break

    def _append_swing(self, arr, t, price, is_high):
        arr.append(Swing(t, price))
        self.add_level(LVL_SWING_BSL if is_high else LVL_SWING_SSL, price, is_high, False, t)
        self._check_equal_level(arr, is_high)

    def update_swings(self):
        s = self.p.piv_len
        hi, lo = self._hi(s), self._lo(s)
        is_high = is_low = True
        for k in range(1, s + 1):
            if self._hi(s - k) > hi or self._hi(s + k) > hi:
                is_high = False
            if self._lo(s - k) < lo or self._lo(s + k) < lo:
                is_low = False
        t = self.b.t[self.j - s]
        if is_high:
            self._append_swing(self.swing_highs, t, hi, True)
        if is_low:
            self._append_swing(self.swing_lows, t, lo, False)

    def update_h4_swings(self, cur):
        """cur = index of the forming H4 bucket (shift 0)."""
        s, h4 = self.p.h4_piv_len, self.h4
        if cur - 2 * s < 0:
            return

        def hi(sh):
            return self.b.o[self.j] if sh == 0 else h4.h[cur - sh]

        def lo(sh):
            return self.b.o[self.j] if sh == 0 else h4.l[cur - sh]

        H, L = hi(s), lo(s)
        is_high = is_low = True
        for k in range(1, s + 1):
            if hi(s - k) > H or hi(s + k) > H:
                is_high = False
            if lo(s - k) < L or lo(s + k) < L:
                is_low = False
        t = h4.key[cur - s] * H4
        if is_high:
            self.h4_swing_highs.append(Swing(t, H))
        if is_low:
            self.h4_swing_lows.append(Swing(t, L))

    # ---------------------------------------------------------- structure
    @staticmethod
    def _update_trend(highs, lows, close, trend, t):
        hi_s = lo_s = None
        for k in range(len(highs) - 1, -1, -1):
            if not highs[k].broken:
                hi_s = highs[k]
                break
        for k in range(len(lows) - 1, -1, -1):
            if not lows[k].broken:
                lo_s = lows[k]
                break
        if hi_s is not None and close > hi_s.price:
            hi_s.broken = True
            return 1, Struct(trend == -1, True, t)
        if lo_s is not None and close < lo_s.price:
            lo_s.broken = True
            return -1, Struct(trend == 1, False, t)
        return trend, None

    def check_structure(self):
        self.struct_trend, evt = self._update_trend(self.swing_highs, self.swing_lows,
                                                    self.bar1[4], self.struct_trend, self.bar1[0])
        if evt:
            self.structs.append(evt)
            self.cnt["choch" if evt.choch else "bos"] += 1

    def update_h4_bias(self):
        cur = self.h4.bucket_of[self.j]
        key = self.h4.key[cur]
        if key == self.last_h4:
            return
        self.last_h4 = key
        self.update_h4_swings(cur)
        if cur < 1:
            return
        close1 = self.h4.c[cur - 1]
        self.h4_bias, _ = self._update_trend(self.h4_swing_highs, self.h4_swing_lows, close1, self.h4_bias, key * H4)
        if self.h4_swing_highs and self.h4_swing_lows:
            rh, rl = self.h4_swing_highs[-1].price, self.h4_swing_lows[-1].price
            if rh > rl:
                self.h4_pd = (close1 - rl) / (rh - rl) * 100.0

    # ------------------------------------------------------ sweeps & judas
    def _append_sweep(self, src, bullish, level, extreme, opposite, t):
        sw = Sweep()
        sw.src, sw.bullish, sw.level, sw.extreme, sw.opposite, sw.t = src, bullish, level, extreme, opposite, t
        sw.judas = sw.used = False
        self.sweeps.append(sw)
        self.cnt["sweeps"] += 1

    def check_sweeps_and_judas(self):
        t, o, h, l, c = self.bar1
        for lv in self.levels:
            if lv.swept:
                continue
            p = lv.price
            if lv.is_buy_side:
                if h > p and c < p:
                    lv.swept = True
                    self._append_sweep(lv.type, False, p, h, l, t)
                elif c > p:
                    lv.swept = True
            else:
                if l < p and c > p:
                    lv.swept = True
                    self._append_sweep(lv.type, True, p, l, h, t)
                elif c < p:
                    lv.swept = True
        # drop consumed non-singleton levels (they can never be used again)
        self.levels = [lv for lv in self.levels if not lv.swept or lv.type in SINGLETONS]

        if self.cur_kz == KZ_LONDON and not self.judas_london_done:
            for sw in reversed(self.sweeps):
                if sw.t != t:
                    break
                if sw.src in (LVL_ASIAN_H, LVL_ASIAN_L):
                    sw.judas = True
                    self.judas_london_done = True
        if self.cur_kz == KZ_NYAM and not self.judas_ny_done:
            for sw in reversed(self.sweeps):
                if sw.t != t:
                    break
                if sw.src in (LVL_LONDON_H, LVL_LONDON_L):
                    sw.judas = True
                    self.judas_ny_done = True
        if len(self.sweeps) > 400:
            self.sweeps = self.sweeps[-200:]

    def recent_sweep(self, max_bars, t1, t2, require_judas):
        cutoff = self.bar1[0] - max_bars * M5
        for sw in reversed(self.sweeps):
            if sw.t < cutoff:
                break
            if sw.used:
                continue
            if require_judas and not sw.judas:
                continue
            if sw.src != t1 and sw.src != t2:
                continue
            return sw
        return None

    def recent_struct(self, max_bars, require_choch, bullish):
        cutoff = self.bar1[0] - max_bars * M5
        for st in reversed(self.structs):
            if st.t < cutoff:
                break
            if require_choch and not st.choch:
                continue
            if st.bullish != bullish:
                continue
            return st
        return None

    # ----------------------------------------------------- OB / FVG zones
    def _add_zone(self, bullish, is_ob, top, bottom, has_fvg, formed):
        z = Zone()
        z.bullish, z.is_ob = bullish, is_ob
        z.top, z.bottom = max(top, bottom), min(top, bottom)
        z.state, z.has_fvg_pair, z.reacted, z.formed = FRESH, has_fvg, False, formed
        self.zones.append(z)
        self.cnt["zones"] += 1

    def check_displacement_and_zones(self):
        if self.atr_v <= 0:
            return
        t, o, h, l, c = self.bar1
        rng, body = h - l, abs(c - o)
        if rng < self.p.disp_atr * self.atr_v or body < self.p.disp_body * rng:
            return
        bull = c > o
        b, j = self.b, self.j

        ob_shift = -1
        for s in range(2, 7):
            bearish = b.c[j - s] < b.o[j - s]
            if (bull and bearish) or (not bull and not bearish):
                ob_shift = s
                break

        has_fvg, fvg_top, fvg_bot = False, 0.0, 0.0
        h3, l3 = b.h[j - 3], b.l[j - 3]
        if bull:
            if l > h3 and l - h3 >= self.p.fvg_min_atr * self.atr_v:
                has_fvg, fvg_bot, fvg_top = True, h3, l
        else:
            if h < l3 and l3 - h >= self.p.fvg_min_atr * self.atr_v:
                has_fvg, fvg_bot, fvg_top = True, h, l3

        if ob_shift >= 0:
            k = j - ob_shift
            if self.p.ob_use_wick:
                top, bot = b.h[k], b.l[k]
            else:
                top, bot = max(b.o[k], b.c[k]), min(b.o[k], b.c[k])
            if not self.p.ob_require_fvg or has_fvg:
                self._add_zone(bull, True, top, bot, has_fvg, t)
        if has_fvg:
            self._add_zone(bull, False, fvg_top, fvg_bot, True, t)

    def update_zone_mitigation(self):
        t, o, h, l, c = self.bar1
        # zones that are no longer fresh never matter again once their reaction bar passed
        self.zones = [z for z in self.zones if z.state == FRESH]
        for z in self.zones:
            z.reacted = False
            if not (l <= z.top and h >= z.bottom):
                continue
            if z.bullish:
                if c > z.top:
                    z.state, z.reacted = MITIGATED, True
                elif c < z.bottom:
                    z.state = VOID
                else:
                    z.state = MITIGATED
            else:
                if c < z.bottom:
                    z.state, z.reacted = MITIGATED, True
                elif c > z.top:
                    z.state = VOID
                else:
                    z.state = MITIGATED

    def find_reacted_zone(self, bullish):
        best = None
        for z in reversed(self.zones):
            if not z.reacted or z.bullish != bullish:
                continue
            if best is None or (z.has_fvg_pair and not best.has_fvg_pair):
                best = z
        return best

    def has_fresh_zone(self, bullish):
        for z in self.zones:
            if z.state == FRESH and z.bullish == bullish:
                return True
        return False

    # --------------------------------------------------- killzones/sessions
    def update_ny_and_kz(self, srv):
        kz = self._kz_at(srv)
        if kz != self.cur_kz:
            t1 = self.bar1[0]
            if self.cur_kz == KZ_ASIAN and self.run_asian_h > 0:
                self.add_level(LVL_ASIAN_H, self.run_asian_h, True, False, t1)
                self.add_level(LVL_ASIAN_L, self.run_asian_l, False, False, t1)
            if self.cur_kz == KZ_LONDON and self.run_lon_h > 0:
                self.add_level(LVL_LONDON_H, self.run_lon_h, True, False, t1)
                self.add_level(LVL_LONDON_L, self.run_lon_l, False, False, t1)
            if kz == KZ_ASIAN:
                self.run_asian_h = self.run_asian_l = -1.0
            if kz == KZ_LONDON:
                self.run_lon_h = self.run_lon_l = -1.0
                self.judas_london_done = False
            if kz == KZ_NYAM:
                self.judas_ny_done = False
            self.trades_this_kz = 0
            self.cur_kz = kz

    def update_session_ranges(self):
        _, _, h, l, _ = self.bar1
        if self.cur_kz == KZ_ASIAN:
            self.run_asian_h = h if self.run_asian_h < 0 else max(self.run_asian_h, h)
            self.run_asian_l = l if self.run_asian_l < 0 else min(self.run_asian_l, l)
        if self.cur_kz == KZ_LONDON:
            self.run_lon_h = h if self.run_lon_h < 0 else max(self.run_lon_h, h)
            self.run_lon_l = l if self.run_lon_l < 0 else min(self.run_lon_l, l)

    def update_daily_weekly(self):
        d = self.d1.bucket_of[self.j]
        if self.d1.key[d] != self.last_d1:
            self.last_d1 = self.d1.key[d]
            if d >= 1:
                t = self.d1.key[d] * DAY
                self.add_level(LVL_PDH, self.d1.h[d - 1], True, False, t)
                self.add_level(LVL_PDL, self.d1.l[d - 1], False, False, t)
        w = self.w1.bucket_of[self.j]
        if self.w1.key[w] != self.last_w1:
            self.last_w1 = self.w1.key[w]
            if w >= 1:
                t = (self.w1.key[w] * 7 + 3) * DAY
                self.add_level(LVL_PWH, self.w1.h[w - 1], True, False, t)
                self.add_level(LVL_PWL, self.w1.l[w - 1], False, False, t)

    def update_pd_and_score(self):
        if self.swing_highs and self.swing_lows:
            rh, rl = self.swing_highs[-1].price, self.swing_lows[-1].price
            if rh > rl:
                self.pd_percent = (self.bar1[4] - rl) / (rh - rl) * 100.0
                self.deal_hi, self.deal_lo = rh, rl
        st = self.struct_trend
        struct_c = 20 if st == 1 else (-20 if st == -1 else 0)
        pd_c = (50 - self.pd_percent) * 0.4
        zone_c = 0
        if st == 1 and self.has_fresh_zone(True):
            zone_c = 20
        if st == -1 and self.has_fresh_zone(False):
            zone_c = -20
        kz_c = 0
        if self.cur_kz != KZ_NONE:
            kz_c = 10 if struct_c > 0 else (-10 if struct_c < 0 else 0)
        self.ict_score = min(100.0, max(0.0, 50 + struct_c + pd_c + zone_c + kz_c))

    # ---------------------------------------------------------- execution
    def lot_size(self, sl_dist):
        a = self.a
        risk_money = self.balance * self.p.risk_percent / 100.0
        if a.tick_size <= 0 or a.tick_value <= 0 or sl_dist <= 0:
            return 0.0
        loss_per_lot = sl_dist / a.tick_size * a.tick_value
        lots = risk_money / loss_per_lot
        step = a.volume_step or 0.01
        lots = int(lots / step + 1e-9) * step
        lots = max(a.volume_min, min(a.volume_max, lots))
        return round(lots, 2)

    def _bid_ask(self):
        bid = self.b.o[self.j]
        return bid, bid + self.b.spread[self.j]

    def execute_entry(self, setup, bull, sl, tp1, tp2, comment):
        bid, ask = self._bid_ask()
        entry = ask if bull else bid
        if tp1 <= 0:
            tp1 = entry + (entry - sl) * self.p.min_rr_tp1 if bull else entry - (sl - entry) * self.p.min_rr_tp1
        if tp2 <= 0:
            tp2 = entry + (entry - sl) * self.p.min_rr_tp2 if bull else entry - (sl - entry) * self.p.min_rr_tp2
        risk = abs(entry - sl)
        if risk <= 0:
            return False
        if abs(tp1 - entry) / risk < self.p.min_rr_tp1 or abs(tp2 - entry) / risk < self.p.min_rr_tp2:
            self.cnt["skipped_rr"] += 1
            return False
        # MT5 rejects stops on the wrong side of the price (invalid stops)
        if (bull and (sl >= bid or tp2 <= ask)) or (not bull and (sl <= ask or tp2 >= bid)):
            self.cnt["skipped_rr"] += 1
            return False
        lots = self.lot_size(risk)
        if lots <= 0:
            return False

        p = Position()
        p.id = self.next_id; self.next_id += 1
        p.buy, p.lots, p.init_lots, p.open_price = bull, lots, lots, entry
        p.sl, p.init_sl, p.tp, p.tp1 = sl, sl, tp2, tp1
        p.setup, p.comment = setup, comment
        p.open_t, p.open_i = self.b.t[self.j], self.j
        p.risk_money = risk * lots * self.a.contract_size
        p.pnl, p.exits, p.kz = 0.0, [], KZ_NAMES[self.cur_kz]
        self.pos = p
        self.tp1_taken = False
        self.trades_this_kz += 1
        self.cnt[setup] += 1
        return True

    def _close(self, lots, price, reason, t):
        """Exit deal (full or partial) -> OnTradeTransaction bookkeeping."""
        p, a = self.pos, self.a
        lots = min(lots, p.lots)
        pnl = (price - p.open_price) * (1 if p.buy else -1) * lots * a.contract_size
        pnl -= a.commission_per_lot * lots
        self.balance += pnl
        p.pnl += pnl
        p.lots = round(p.lots - lots, 2)
        p.exits.append(dict(t=t, price=price, lots=lots, pnl=pnl, reason=reason))

        # OnTradeTransaction
        if pnl < 0:
            self.consec_losses += 1
        else:
            self.consec_losses = 0
        if self.consec_losses >= self.p.max_consec_losses:
            self.paused_until = t + self.p.pause_minutes * 60
            self.consec_losses = 0
            self.events.append((t, "Tạm dừng %d phút sau %d lệnh thua liên tiếp" % (
                self.p.pause_minutes, self.p.max_consec_losses)))
        if p.lots <= 1e-9:
            self.trades.append(p)
            self.pos = None
            self.tp1_taken = False

    def _exit_price(self, buy):
        bid, ask = self._bid_ask()
        return bid if buy else ask

    # ------------------------------------------------------------- setups
    def check_setup_a(self):
        p = self.p
        if not p.enable_setup_a or self.cur_kz != KZ_LONDON:
            return
        if not (self.h4_bias == 1 or self.h4_pd < 50):
            return
        sw = self.recent_sweep(p.setup_a_max_bars_since_sweep, LVL_ASIAN_L, LVL_ASIAN_L, True)
        if sw is None:
            return
        st = self.recent_struct(p.setup_a_max_bars_since_sweep, True, True)
        if st is None or st.t <= sw.t or self.pd_percent >= 50:
            return
        if self.find_reacted_zone(True) is None:
            return
        sl = sw.extreme - p.sweep_sl_buffer_atr * self.atr_v
        self.execute_entry("A", True, sl, self.nearest_opposite_liquidity(True), self.tp2(True), "SetupA-LondonJudas")
        sw.used = True

    def check_setup_b(self):
        p = self.p
        if not p.enable_setup_b or self.cur_kz != KZ_NYAM:
            return
        bull = self.ict_score >= p.score_buy_threshold and self.struct_trend == 1
        bear = self.ict_score <= p.score_sell_threshold and self.struct_trend == -1
        if not bull and not bear:
            return
        if self.recent_struct(p.setup_b_max_bars_lookback, False, bull) is None:
            return
        z = self.find_reacted_zone(bull)
        if z is not None:
            sl = z.bottom - p.zone_sl_buffer_atr * self.atr_v if bull else z.top + p.zone_sl_buffer_atr * self.atr_v
            self.execute_entry("B", bull, sl, self.nearest_opposite_liquidity(bull), self.tp2(bull), "SetupB-Continuation")
            return
        lt = LVL_LONDON_L if bull else LVL_LONDON_H
        sw = self.recent_sweep(3, lt, lt, True)
        if sw is None:
            return
        c = self.bar1[4]
        if not ((bull and c > sw.level) or (not bull and c < sw.level)):
            return
        buf = p.sweep_sl_buffer_atr * self.atr_v
        sl = sw.extreme - buf if bull else sw.extreme + buf
        self.execute_entry("B", bull, sl, self.nearest_opposite_liquidity(bull), self.tp2(bull), "SetupB-JudasNY")
        sw.used = True

    def check_setup_c(self):
        p = self.p
        if not p.enable_setup_c or self.cur_kz == KZ_NONE:
            return
        buf = p.sweep_sl_buffer_atr * self.atr_v
        sw = self.recent_sweep(p.setup_c_max_bars, LVL_PDH, LVL_PDH, False)
        if sw is not None and self.pd_percent >= 70:
            st = self.recent_struct(p.setup_c_max_bars, True, False)
            if st is not None and st.t > sw.t and self.ict_score <= 40 and self.find_reacted_zone(False):
                tp2 = self.dealing_range_eq() or self.tp2(False)
                self.execute_entry("C", False, sw.extreme + buf, self.nearest_opposite_liquidity(False), tp2,
                                   "SetupC-PDH-Reversal")
                sw.used = True
                return
        sw = self.recent_sweep(p.setup_c_max_bars, LVL_PDL, LVL_PDL, False)
        if sw is not None and self.pd_percent <= 30:
            st = self.recent_struct(p.setup_c_max_bars, True, True)
            if st is not None and st.t > sw.t and self.ict_score >= 60 and self.find_reacted_zone(True):
                tp2 = self.dealing_range_eq() or self.tp2(True)
                self.execute_entry("C", True, sw.extreme - buf, self.nearest_opposite_liquidity(True), tp2,
                                   "SetupC-PDL-Reversal")
                sw.used = True

    def check_setup_d(self):
        p = self.p
        if not p.enable_setup_d or self.cur_kz == KZ_NONE:
            return
        buf = p.sweep_sl_buffer_atr * self.atr_v
        c = self.bar1[4]
        sw = self.recent_sweep(p.setup_d_max_bars, LVL_EQH, LVL_EQH, False)
        if sw is not None and c < sw.opposite:
            self.execute_entry("D", False, sw.extreme + buf, self.nearest_opposite_liquidity(False), self.tp2(False),
                               "SetupD-TurtleSoup-EQH")
            sw.used = True
            return
        sw = self.recent_sweep(p.setup_d_max_bars, LVL_EQL, LVL_EQL, False)
        if sw is not None and c > sw.opposite:
            self.execute_entry("D", True, sw.extreme - buf, self.nearest_opposite_liquidity(True), self.tp2(True),
                               "SetupD-TurtleSoup-EQL")
            sw.used = True

    # ----------------------------------------------------- position mgmt
    def manage_open_position(self, srv):
        pos = self.pos
        if pos is None:
            return
        t = self.b.t[self.j]
        if not self.tp1_taken and pos.tp1 > 0:
            hit = self.bar1[2] >= pos.tp1 if pos.buy else self.bar1[3] <= pos.tp1
            if hit:
                a = self.a
                step = a.volume_step or 0.01
                close_vol = round(int(pos.lots * 0.5 / step + 1e-9) * step, 2)
                if a.volume_min <= close_vol < pos.lots:
                    self._close(close_vol, self._exit_price(pos.buy), "TP1 (50%)", t)
                pos.sl = pos.open_price  # breakeven
                self.tp1_taken = True
        if self.pos is None:
            return
        if not self.tp1_taken and self.recent_struct(1, True, not pos.buy) is not None:
            self._close(pos.lots, self._exit_price(pos.buy), "CHoCH ngược", t)
            return
        if pos.setup == "B" and self.ny_hour(srv) >= self.p.setup_b_cutoff_hour:
            self._close(pos.lots, self._exit_price(pos.buy), "Hết giờ Setup B", t)

    def can_trade_now(self, srv):
        if srv < self.paused_until:
            self.cnt["blocked_pause"] += 1
            return False
        if self.balance <= self.day_start_balance * (1 - self.p.max_daily_loss_percent / 100.0):
            self.cnt["blocked_daily"] += 1
            return False
        if self.trades_this_kz >= self.p.max_trades_per_kz or self.cur_kz == KZ_NONE:
            return False
        h = self.ny_hour(srv)
        if self.p.news_hour_ny - self.p.news_blackout_min_before / 60.0 <= h < self.p.news_hour_ny:
            self.cnt["blocked_news"] += 1
            return False
        if self.trade_from is not None and srv < self.trade_from:
            return False
        if self.trade_to is not None and srv >= self.trade_to:
            return False
        return True

    # ------------------------------------------------ intrabar SL / TP
    def _check_stops_at_open(self):
        pos = self.pos
        if pos is None:
            return
        j, b = self.j, self.b
        px = b.o[j] if pos.buy else b.o[j] + b.spread[j]
        if (pos.buy and px <= pos.sl) or (not pos.buy and px >= pos.sl):
            self._close(pos.lots, px, "SL (gap)" if pos.sl != pos.open_price else "Hoà vốn", b.t[j])
        elif (pos.buy and px >= pos.tp) or (not pos.buy and px <= pos.tp):
            self._close(pos.lots, px, "TP2 (gap)", b.t[j])

    def _check_stops_intrabar(self):
        pos = self.pos
        if pos is None:
            return
        j, b = self.j, self.b
        spr = 0.0 if pos.buy else b.spread[j]
        hi, lo = b.h[j] + spr, b.l[j] + spr
        sl_hit = lo <= pos.sl if pos.buy else hi >= pos.sl
        tp_hit = hi >= pos.tp if pos.buy else lo <= pos.tp
        t = b.t[j] + M5 - 1
        if sl_hit:
            reason = "Hoà vốn" if abs(pos.sl - pos.open_price) < 1e-9 else "SL"
            self._close(pos.lots, pos.sl, reason, t)
        elif tp_hit:
            self._close(pos.lots, pos.tp, "TP2", t)

    # ---------------------------------------------------------------- run
    def run(self, progress=None):
        b, p = self.b, self.p
        n = len(b)
        warm = max(p.atr_period + 1, 2 * p.piv_len + 1, 7)
        for j in range(n):
            self.j = j
            srv = b.t[j]
            self.kz_by_bar[j] = self._kz_at(srv)
            if j >= warm:
                self._check_stops_at_open()
                self._on_tick(srv)
                self._check_stops_intrabar()
            eq = self.balance
            if self.pos is not None:
                pos = self.pos
                px = b.c[j] if pos.buy else b.c[j] + b.spread[j]
                eq += (px - pos.open_price) * (1 if pos.buy else -1) * pos.lots * self.a.contract_size
            self.equity.append((srv, self.balance, eq))
            if progress and j % 20000 == 0:
                progress(j, n)
        # close anything still open at the end of the data
        if self.pos is not None:
            self.j = n - 1
            pos = self.pos
            px = b.c[-1] if pos.buy else b.c[-1] + b.spread[-1]
            self._close(pos.lots, px, "Kết thúc dữ liệu", b.t[-1] + M5)
        return self

    def _on_tick(self, srv):
        """OnTick() at the first tick of bar j."""
        b, j = self.b, self.j
        self.bar1 = (b.t[j - 1], b.o[j - 1], b.h[j - 1], b.l[j - 1], b.c[j - 1])
        self.atr_v = self.atr[j - 1]
        if self.atr_v <= 0:
            return
        if self.current_day is None:
            self.current_day = srv // DAY
            self.day_start_balance = self.balance

        self.update_ny_and_kz(srv)
        self.update_session_ranges()
        self.update_daily_weekly()
        self.update_swings()
        self.check_sweeps_and_judas()
        self.update_zone_mitigation()
        self.check_displacement_and_zones()
        self.check_structure()
        self.update_h4_bias()
        self.update_pd_and_score()

        self.manage_open_position(srv)

        today = srv // DAY
        if today != self.current_day:
            self.current_day = today
            self.day_start_balance = self.balance

        if self.pos is None and self.can_trade_now(srv):
            self.check_setup_a()
            if self.pos is None:
                self.check_setup_b()
            if self.pos is None:
                self.check_setup_c()
            if self.pos is None:
                self.check_setup_d()
        self.cnt["bars"] += 1

    def params_dict(self):
        return dict(strategy=asdict(self.p), account=asdict(self.a))
