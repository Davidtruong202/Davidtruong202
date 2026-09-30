"""Tick-level trade management identical to MXUpdatePositions() in V4.39.

Per tick, for an open position (price = Bid for BUY, Ask for SELL):
  1. price beyond current SL  -> close everything at that price ("SL", gaps are real)
  2. price beyond TP2         -> close everything at that price ("TP2")
  3. TP1 (1R) not yet taken   -> close 50% at that price, SL = entry (break-even)
  4. favourable >= 1R          -> trail SL to max(entry, price - 1R) if it improves by > 0.01
A position opened on tick i is first managed on tick i+1 (management runs before signals).
Results are in price units per 1 lot-equivalent (sum of lot fraction x move); money for the
V4.39 default fixed lot 0.02 on XAUUSD (contract 100) is net_pts * 0.02 * 100.
"""
import numpy as np
from numba import njit, prange

EXIT_SL, EXIT_TP2, EXIT_END = 0, 1, 2


@njit(cache=True)
def _floor_tick(v, tick):
    return round(np.floor(v / tick + 1e-8) * tick, 8)


@njit(cache=True)
def _ceil_tick(v, tick):
    return round(np.ceil(v / tick - 1e-8) * tick, 8)


@njit(cache=True)
def simulate_one(bid, ask, i0, buy, entry, sl0, tp1, tp2, risk, tick, safety,
                 use_tp1, part_frac, use_trail, trail_start, trail_dist, trail_step):
    sl = sl0
    left = 1.0
    net = 0.0
    partial = False
    mfe = 0.0
    mae = 0.0
    mae_full = 0.0  # adverse excursion while the full lot is open (for equity DD)
    n = len(bid)
    for i in range(i0 + 1, n):
        price = bid[i] if buy else ask[i]
        fav = price - entry if buy else entry - price
        if fav > mfe:
            mfe = fav
        if -fav > mae:
            mae = -fav
            if not partial:
                mae_full = mae
        if (buy and price <= sl) or ((not buy) and price >= sl):
            net += left * fav
            return i, net, EXIT_SL, partial, mfe, mae, mae_full
        if (buy and price >= tp2) or ((not buy) and price <= tp2):
            net += left * fav
            return i, net, EXIT_TP2, partial, mfe, mae, mae_full
        if use_tp1 and (not partial) and ((buy and price >= tp1) or ((not buy) and price <= tp1)):
            net += part_frac * fav
            left -= part_frac
            partial = True
            sl = entry
        if use_trail and fav >= trail_start * risk:
            if buy:
                nxt = _floor_tick(max(entry, price - trail_dist * risk), tick)
                if nxt > sl + trail_step and nxt < price - safety and nxt < tp2:
                    sl = nxt
            else:
                nxt = _ceil_tick(min(entry, price + trail_dist * risk), tick)
                if nxt < sl - trail_step and nxt > price + safety and nxt > tp2:
                    sl = nxt
    price = bid[n - 1] if buy else ask[n - 1]
    fav = price - entry if buy else entry - price
    net += left * fav
    return n - 1, net, EXIT_END, partial, mfe, mae, mae_full


@njit(parallel=True, cache=True)
def simulate_many(bid, ask, i0, buy, entry, sl, tp1, tp2, risk, tick, safety,
                  use_tp1, part_frac, use_trail, trail_start, trail_dist, trail_step):
    m = len(i0)
    exit_i = np.empty(m, np.int64)
    net = np.empty(m)
    reason = np.empty(m, np.int8)
    partial = np.empty(m, np.bool_)
    mfe = np.empty(m)
    mae = np.empty(m)
    mae_full = np.empty(m)
    for k in prange(m):
        r = simulate_one(bid, ask, i0[k], buy[k], entry[k], sl[k], tp1[k], tp2[k], risk[k], tick, safety,
                         use_tp1, part_frac, use_trail, trail_start, trail_dist, trail_step)
        exit_i[k], net[k], reason[k], partial[k], mfe[k], mae[k], mae_full[k] = r
    return exit_i, net, reason, partial, mfe, mae, mae_full


class TradeSimulator:
    """Caches outcomes of identical signals (same tick, side, SL, TP) across configurations."""

    def __init__(self, market, cfg_common, slippage=0.0):
        self.m = market
        self.tick = market.tick_size
        self.safety = (market.stops_level + 1) * market.point
        c = cfg_common
        self.min_sl, self.max_sl = c["InpMinSLPriceDistance"], c["InpMaxSLPriceDistance"]
        self.use_tp1 = bool(c["InpUseTP1Partial"])
        self.tp1_r = c["InpTP1AtR"]
        lot = c["InpGiaTriKhoiLuong"]
        step = 0.01
        part = np.floor(lot * c["InpTP1ClosePct"] / 100.0 / step + 1e-8) * step
        self.part_frac = part / lot if self.use_tp1 else 0.0
        self.lot = lot
        self.use_trail = bool(c["InpUseTrailing"])
        self.trail = (c["InpTrailStartR"], c["InpTrailDistanceR"], c["InpTrailStepGia"])
        self.slip = slippage
        self.cache = {}

    def prepare(self, i0, buy, entry, sl, tp):
        """MXOpen(): apply entry slippage, re-check SL band and RR>=1, build TP1/TP2."""
        tick = self.tick
        sgn = np.where(buy, 1.0, -1.0)
        p_entry = entry + sgn * self.slip
        dg = self.m.digits
        p_entry = np.round(np.where(buy, np.ceil(p_entry / tick - 1e-8) * tick, np.floor(p_entry / tick + 1e-8) * tick), dg)
        risk = np.abs(p_entry - sl)
        ok = (risk >= self.min_sl - tick * 0.5) & (risk <= self.max_sl + tick * 0.5)
        rr = np.abs(tp - entry) / np.abs(entry - sl)
        ok &= rr >= 1.0 - 1e-8
        tp2 = p_entry + sgn * rr * risk
        tp2 = np.round(np.where(buy, np.ceil(tp2 / tick - 1e-8) * tick, np.floor(tp2 / tick + 1e-8) * tick), dg)
        tp1 = p_entry + sgn * self.tp1_r * risk
        tp1 = np.round(np.where(buy, np.ceil(tp1 / tick - 1e-8) * tick, np.floor(tp1 / tick + 1e-8) * tick), dg)
        return ok, p_entry, risk, tp1, tp2

    def run(self, sig):
        """sig: dict of arrays i0, buy, entry, sl, tp. Returns dict with per-signal outcome arrays."""
        n = len(sig["i0"])
        out = {k: np.zeros(n) for k in ("net", "mfe", "mae", "mae_full", "risk", "p_entry", "tp1", "tp2")}
        out["exit_i"] = np.full(n, -1, np.int64)
        out["reason"] = np.full(n, -1, np.int8)
        out["partial"] = np.zeros(n, bool)
        if n == 0:
            out["ok"] = np.zeros(0, bool)
            return out
        ok, p_entry, risk, tp1, tp2 = self.prepare(sig["i0"], sig["buy"], sig["entry"], sig["sl"], sig["tp"])
        out["ok"] = ok
        out["risk"], out["p_entry"], out["tp1"], out["tp2"] = risk, p_entry, tp1, tp2
        todo = []
        for k in np.flatnonzero(ok):
            key = (int(sig["i0"][k]), bool(sig["buy"][k]), round(float(p_entry[k]), 6), round(float(sig["sl"][k]), 6),
                   round(float(tp2[k]), 6))
            if key in self.cache:
                r = self.cache[key]
                (out["exit_i"][k], out["net"][k], out["reason"][k], out["partial"][k], out["mfe"][k],
                 out["mae"][k], out["mae_full"][k]) = r
            else:
                todo.append((k, key))
        if todo:
            idx = np.array([k for k, _ in todo], np.int64)
            res = simulate_many(self.m.ticks.bid, self.m.ticks.ask, sig["i0"][idx].astype(np.int64),
                                sig["buy"][idx].astype(np.bool_), p_entry[idx], sig["sl"][idx].astype(np.float64),
                                tp1[idx], tp2[idx], risk[idx], self.tick, self.safety, self.use_tp1,
                                self.part_frac, self.use_trail, self.trail[0], self.trail[1], self.trail[2])
            for j, (k, key) in enumerate(todo):
                r = tuple(a[j] for a in res)
                self.cache[key] = r
                (out["exit_i"][k], out["net"][k], out["reason"][k], out["partial"][k], out["mfe"][k],
                 out["mae"][k], out["mae_full"][k]) = r
        return out
