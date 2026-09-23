"""DCA / grid basket simulator for XAUUSD on M1 bars.

A basket opens one position, then adds a new one every ``step_atr`` x ATR(H1)
against it (lot x ``mult`` each level, at most ``max_levels``). The whole basket
closes at ``tp_atr`` x ATR(H1) beyond its average price, or is cut when its
floating loss reaches ``basket_sl_pct`` % of the balance it started with.

Conservative bar model: inside every M1 bar the ADVERSE extreme is visited before
the favourable one, so new levels and the basket stop are hit before the take
profit. Spread is paid on every fill (buys at ask = bid + spread), swap is
charged per lot for every position held over the server-day rollover (x3 on
Wednesday). Equity drawdown includes the floating loss at each bar's worst price.
"""

from dataclasses import dataclass, asdict

from .common import H1, ema, sma_atr, HTF, DAY


@dataclass
class DCAParams:
    direction: str = "trend"      # "trend" (H1 EMA filter) or "long" (buy only)
    step_atr: float = 1.0         # distance between levels, x ATR(H1) at basket open
    mult: float = 1.5             # lot multiplier per level (1.0 = fixed lot, 2.0 = martingale x2)
    max_levels: int = 6           # positions per basket, including the first
    tp_atr: float = 0.5           # basket take profit beyond the average price, x ATR(H1)
    basket_sl_pct: float = 10.0   # cut the basket when its loss reaches this % of balance (100 = never)
    lot_per_1k: float = 0.01      # first-level lot per 1000 of balance (compounding)
    trend_ema: int = 50
    trend_slope_bars: int = 3
    atr_period: int = 14
    swap_long: float = -40.0      # per lot per night (check your broker's symbol specification)
    swap_short: float = -10.0
    contract: float = 100.0
    lot_step: float = 0.01
    min_lot: float = 0.01


class Basket:
    __slots__ = ("buy", "fills", "lots", "avg", "next_px", "step", "tp_dist", "open_t", "open_bal",
                 "levels", "swap", "max_lots", "worst")


class DCASim:
    def __init__(self, m1, params=None, initial=10000.0):
        self.b, self.p, self.initial = m1, params or DCAParams(), initial
        p = self.p
        h1 = HTF(m1, lambda t: t // H1)
        self.h1_atr = sma_atr(h1.h, h1.l, h1.c, p.atr_period)
        self.h1_ema = ema(h1.c, p.trend_ema)
        self.h1_c = h1.c
        self.k_of = [(k if (m1.t[i] + 60) % H1 == 0 else k - 1) for i, k in enumerate(h1.bucket_of)]

    def _lots(self, base, level):
        p = self.p
        v = base * (p.mult ** level)
        return max(p.min_lot, round(int(v / p.lot_step + 1e-9) * p.lot_step, 2))

    def _dir(self, i):
        p = self.p
        if p.direction == "long":
            return 1
        k = self.k_of[i]
        if k < p.trend_ema + p.trend_slope_bars:
            return 0
        e, ep, c = self.h1_ema[k], self.h1_ema[k - p.trend_slope_bars], self.h1_c[k]
        if c > e and e > ep:
            return 1
        if c < e and e < ep:
            return -1
        return 0

    def run(self, t_stop_new=None, lot_scale=1.0, stop_at_double=False):
        b, p = self.b, self.p
        C = p.contract
        bal = self.initial
        peak = bal
        max_dd = 0.0
        bk = None
        baskets = []
        curve = []                    # (t, balance, equity) every 5 minutes
        blown = False
        double_t, dd_at_double = None, None
        last_day = b.t[0] // DAY
        n = len(b)
        for i in range(n):
            t, o, h, l, c, spr = b.t[i], b.o[i], b.h[i], b.l[i], b.c[i], b.spread[i]
            day = t // DAY
            if bk is not None and day != last_day:
                nights = 3 if day % 7 == 0 else 1                 # rollover into Thursday = Wednesday x3
                s = (p.swap_long if bk.buy else p.swap_short) * bk.lots * nights
                bal += s
                bk.swap += s
            last_day = day

            if bk is not None:
                if bk.buy:
                    adverse_bid = l
                    # add levels (buy limit at next_px, filled when ask <= next_px)
                    while bk.levels < p.max_levels and l + spr <= bk.next_px:
                        lots = self._lots(bk.fills[0][1], bk.levels)
                        px = min(bk.next_px, o + spr)
                        bk.fills.append((px, lots))
                        bk.lots = round(bk.lots + lots, 2)
                        bk.avg = sum(f[0] * f[1] for f in bk.fills) / bk.lots
                        bk.next_px -= bk.step
                        bk.levels += 1
                    loss_lim = bk.open_bal * p.basket_sl_pct / 100.0
                    stop_px = bk.avg - loss_lim / (bk.lots * C)
                    worst = (adverse_bid - bk.avg) * bk.lots * C
                    bk.worst = min(bk.worst, worst)
                    eq_low = bal + worst
                    if p.basket_sl_pct < 100 and adverse_bid <= stop_px:
                        px = min(stop_px, o)
                        pnl = (px - bk.avg) * bk.lots * C
                        bal += pnl
                        baskets.append((bk.open_t, t, True, pnl + bk.swap, bk.levels, "SL", bk.max_lots))
                        eq_low = bal
                        bk = None
                    elif h >= bk.avg + bk.tp_dist:
                        pnl = bk.tp_dist * bk.lots * C
                        bal += pnl
                        baskets.append((bk.open_t, t, True, pnl + bk.swap, bk.levels, "TP", bk.max_lots))
                        bk = None
                else:
                    adverse_ask = h + spr
                    while bk.levels < p.max_levels and h >= bk.next_px:
                        lots = self._lots(bk.fills[0][1], bk.levels)
                        px = max(bk.next_px, o)
                        bk.fills.append((px, lots))
                        bk.lots = round(bk.lots + lots, 2)
                        bk.avg = sum(f[0] * f[1] for f in bk.fills) / bk.lots
                        bk.next_px += bk.step
                        bk.levels += 1
                    loss_lim = bk.open_bal * p.basket_sl_pct / 100.0
                    stop_px = bk.avg + loss_lim / (bk.lots * C)
                    worst = (bk.avg - adverse_ask) * bk.lots * C
                    bk.worst = min(bk.worst, worst)
                    eq_low = bal + worst
                    if p.basket_sl_pct < 100 and adverse_ask >= stop_px:
                        px = max(stop_px, o + spr)
                        pnl = (bk.avg - px) * bk.lots * C
                        bal += pnl
                        baskets.append((bk.open_t, t, False, pnl + bk.swap, bk.levels, "SL", bk.max_lots))
                        eq_low = bal
                        bk = None
                    elif l + spr <= bk.avg - bk.tp_dist:
                        pnl = bk.tp_dist * bk.lots * C
                        bal += pnl
                        baskets.append((bk.open_t, t, False, pnl + bk.swap, bk.levels, "TP", bk.max_lots))
                        bk = None
                if bk is not None:
                    bk.max_lots = max(bk.max_lots, bk.lots)
            else:
                eq_low = bal

            if peak > 0:
                max_dd = max(max_dd, (peak - eq_low) / peak)
            if eq_low <= self.initial * 0.02:
                blown = True
                if bk is not None:
                    baskets.append((bk.open_t, t, bk.buy, eq_low - bal, bk.levels, "CHAY TK", bk.max_lots))
                bal, bk = max(eq_low, 0.0), None
                curve.append((t, bal, bal))
                break

            # close-of-bar equity; new basket decision at the close
            if bk is not None:
                eq = bal + ((c - bk.avg) if bk.buy else (bk.avg - c - spr)) * bk.lots * C
            else:
                eq = bal
                if t_stop_new is None or t < t_stop_new:
                    d = self._dir(i)
                    k = self.k_of[i]
                    atr = self.h1_atr[k] if k >= p.atr_period else 0.0
                    if d != 0 and atr > 0:
                        base = max(p.min_lot, int(bal / 1000.0 * p.lot_per_1k * lot_scale / p.lot_step + 1e-9) * p.lot_step)
                        bk = Basket()
                        bk.buy = d > 0
                        px = c + spr if bk.buy else c
                        bk.fills = [(px, round(base, 2))]
                        bk.lots = round(base, 2)
                        bk.avg = px
                        bk.step = p.step_atr * atr
                        bk.tp_dist = p.tp_atr * atr
                        bk.next_px = px - bk.step if bk.buy else px + bk.step
                        bk.open_t, bk.open_bal, bk.levels, bk.swap = t, bal, 1, 0.0
                        bk.max_lots, bk.worst = bk.lots, 0.0
            peak = max(peak, eq)
            if double_t is None and eq >= 2 * self.initial:
                double_t, dd_at_double = t, max_dd
                if stop_at_double:
                    curve.append((t, bal, eq))
                    break
            if t % 300 == 240:
                curve.append((t, bal, eq))
        if bk is not None and not blown:
            c = b.c[-1]
            pnl = ((c - bk.avg) if bk.buy else (bk.avg - c - b.spread[-1])) * bk.lots * C
            bal += pnl
            baskets.append((bk.open_t, b.t[-1], bk.buy, pnl + bk.swap, bk.levels, "Ket thuc", bk.max_lots))
        return dict(final=bal, mult=bal / self.initial, max_dd=max_dd * 100, blown=blown, baskets=baskets,
                    curve=curve, double_t=double_t, dd_at_double=None if dd_at_double is None else dd_at_double * 100,
                    params=asdict(p))


def segment_stats(curve, baskets, lo, hi):
    """Return and max drawdown of the equity curve between lo and hi (fresh peak at lo)."""
    pts = [(t, e) for t, _, e in curve if lo <= t < hi]
    if not pts:
        return dict(ret=0.0, dd=0.0, n=0, sl=0, win=0.0)
    start, end = pts[0][1], pts[-1][1]
    peak, dd = start, 0.0
    for _, e in pts:
        peak = max(peak, e)
        if peak > 0:
            dd = max(dd, (peak - e) / peak)
    bs = [x for x in baskets if lo <= x[1] < hi]
    return dict(ret=(end / start - 1) * 100 if start > 0 else -100.0, dd=dd * 100, n=len(bs),
                sl=sum(1 for x in bs if x[5] != "TP"), win=(sum(1 for x in bs if x[3] > 0) / len(bs) * 100) if bs else 0.0)
