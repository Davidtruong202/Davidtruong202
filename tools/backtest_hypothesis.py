#!/usr/bin/env python3
"""Backtest cac quy tac SUY RA cua bot "BE Nha Trang" tren file nen cua TradeLogger.

Dung lai nen OHLC tu cac cot dac trung (close, atr, body, upwick, lowwick), chay
5 setup (RSI, PVT, LQ = kieu magic 79; EMA, SMC = kieu magic 78) voi quan ly lenh
2 tang / chot tung phan / trailing nhu da quan sat, roi so voi lenh that cua bot.

    python tools/backtest_hypothesis.py --bars tradelog_bars_XAUUSD_M5.csv --deals tradelog_deals.csv
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

BALANCE0 = 2000.0
RISK_PCT = 2.0          # % rui ro lenh chinh (tai khoan nguon dang de 2%)
CONTRACT = 100.0        # 1 lot vang = 100 oz -> 1$ gia = 100$/lot

# ---------------------------------------------------------------------------
# Quy tac vao lenh (gia thuyet). Tat ca tinh tren nen VUA DONG, vao lenh o gia
# mo cua nen ke tiep.
# ---------------------------------------------------------------------------
SETUPS = {
    # ten: (kieu quan ly, ham tin hieu -> +1 BUY / -1 SELL / 0)
    "RSI": ("79", lambda r: -1 if (r.f_rsi >= 72 and r.f_stoch_k >= 85 and r.f_pos_day_range >= 0.85)
            else (1 if (r.f_rsi <= 28 and r.f_stoch_k <= 15 and r.f_pos_day_range <= 0.15) else 0)),
    "PVT": ("79", lambda r: 1 if (r.f_rsi <= 25 and r.f_break_ll20 == 1)
            else (-1 if (r.f_rsi >= 75 and r.f_break_hh20 == 1) else 0)),
    "LQ": ("79", lambda r: 1 if (r.f_break_ll20 == 1 and r.f_bb_pctb < 0 and r.f_pos_day_range <= 0.05 and r.f_body_atr <= -0.5)
           else (-1 if (r.f_break_hh20 == 1 and r.f_bb_pctb > 1 and r.f_pos_day_range >= 0.95 and r.f_body_atr >= 0.5) else 0)),
    "EMA": ("78", lambda r: -1 if (r.f_ema_stack == -1 and r.f_body_atr <= -0.4 and r.f_dist_ema20_atr < 0
                                   and r.f_stoch_k >= 55 and 35 <= r.f_rsi <= 50)
            else (1 if (r.f_ema_stack == 1 and r.f_body_atr >= 0.4 and r.f_dist_ema20_atr > 0
                        and r.f_stoch_k <= 45 and 50 <= r.f_rsi <= 65) else 0)),
    "SMC": ("78", lambda r: -1 if (r.f_dist_ema50_atr <= -2.5 and 0 < r.f_body_atr < 0.4 and r.f_rsi < 40 and r.f_pos_day_range <= 0.25)
            else (1 if (r.f_dist_ema50_atr >= 2.5 and -0.4 < r.f_body_atr < 0 and r.f_rsi > 60 and r.f_pos_day_range >= 0.75) else 0)),
}

# Tham so quan ly lenh theo kieu magic
MGMT = {
    "79": dict(l2=1.8, tp=10.0, partial_at=5.0, partial_frac=0.5, be_at=5.0, be_off=0.1, trail=5.0),
    "78": dict(l2=5.0, tp=30.0, partial_at=10.0, partial_frac=0.57, be_at=10.0, be_off=0.3, trail=5.0),
}
SMC_BE_AT = 3.5  # SMC doi hoa von som


@dataclass
class Leg:
    entry: float
    lot: float
    tp: float
    open: bool = True
    filled: bool = True
    pnl: float = 0.0


@dataclass
class Trade:
    setup: str
    kind: str
    d: int
    t_open: pd.Timestamp
    sl: float
    legs: list = field(default_factory=list)
    best: float = 0.0
    partial_done: bool = False
    be_done: bool = False
    t_close: pd.Timestamp | None = None

    @property
    def pnl(self):
        return sum(l.pnl for l in self.legs)


def rebuild_ohlc(b: pd.DataFrame) -> pd.DataFrame:
    b = b.copy()
    b["t"] = pd.to_datetime(b.feat_bar_time, format="%Y.%m.%d %H:%M:%S")
    b["c"] = b.f_close
    b["o"] = b.c - b.f_body_atr * b.f_atr
    b["h"] = np.maximum(b.o, b.c) + b.f_upwick_atr * b.f_atr
    b["l"] = np.minimum(b.o, b.c) - b.f_lowwick_atr * b.f_atr
    b["day"] = b.t.dt.date
    b["day_lo"] = b.groupby("day").l.cummin()
    b["day_hi"] = b.groupby("day").h.cummax()
    b["lo20"] = b.l.rolling(20, min_periods=1).min()
    b["hi20"] = b.h.rolling(20, min_periods=1).max()
    return b.reset_index(drop=True)


def close_leg(leg: Leg, price: float, frac: float, d: int):
    vol = leg.lot * frac
    leg.pnl += (price - leg.entry) * d * vol * CONTRACT
    leg.lot -= vol
    if leg.lot <= 1e-9:
        leg.open = False


def run(b: pd.DataFrame):
    balance = BALANCE0
    trades: list[Trade] = []
    active: dict[str, Trade] = {}
    for i in range(len(b) - 1):
        r, nb = b.iloc[i], b.iloc[i + 1]
        # 1) quan ly lenh dang mo tren nen i+1
        for name, tr in list(active.items()):
            m = MGMT[tr.kind]
            d = tr.d
            hi, lo = nb.h, nb.l
            adverse = lo if d > 0 else hi
            favor = hi if d > 0 else lo
            # tang 2 khop?
            for leg in tr.legs:
                if not leg.filled and ((d > 0 and lo <= leg.entry) or (d < 0 and hi >= leg.entry)):
                    leg.filled = True
            # SL truoc (bao thu)
            if (d > 0 and adverse <= tr.sl) or (d < 0 and adverse >= tr.sl):
                for leg in tr.legs:
                    if leg.filled and leg.open:
                        close_leg(leg, tr.sl, 1.0, d)
                    leg.open = False
                tr.t_close = nb.t
            else:
                # TP tung tang
                for leg in tr.legs:
                    if leg.filled and leg.open and ((d > 0 and favor >= leg.tp) or (d < 0 and favor <= leg.tp)):
                        close_leg(leg, leg.tp, 1.0, d)
                main = tr.legs[0]
                move = (favor - main.entry) * d
                tr.best = max(tr.best, move)
                # chot tung phan + huy tang 2 chua khop
                if not tr.partial_done and move >= m["partial_at"]:
                    px = main.entry + d * m["partial_at"]
                    for leg in tr.legs:
                        if leg.filled and leg.open:
                            close_leg(leg, px, m["partial_frac"], d)
                        elif not leg.filled:
                            leg.open = False
                    tr.partial_done = True
                be_at = SMC_BE_AT if tr.setup == "SMC" else m["be_at"]
                if not tr.be_done and move >= be_at:
                    tr.sl = main.entry + d * m["be_off"]
                    tr.be_done = True
                    for leg in tr.legs:
                        if not leg.filled:
                            leg.open = False
                if tr.be_done:
                    trail = favor - d * m["trail"]
                    tr.sl = max(tr.sl, trail) if d > 0 else min(tr.sl, trail)
                if not any(l.open for l in tr.legs):
                    tr.t_close = nb.t
            if tr.t_close is not None:
                balance += tr.pnl
                del active[name]
        # 2) tin hieu moi tren nen i -> vao o gia mo nen i+1
        for name, (kind, fn) in SETUPS.items():
            if name in active:
                continue
            try:
                d = fn(r)
            except (TypeError, ValueError):
                d = 0
            if d == 0 or np.isnan(r.f_atr):
                continue
            m = MGMT[kind]
            entry = nb.o
            if kind == "79":
                sl = (min(r.lo20, r.day_lo) - 1.5) if d > 0 else (max(r.hi20, r.day_hi) + 1.5)
            else:
                sl = entry - d * 2.5 * r.f_atr
            dist = (entry - sl) * d
            if dist <= 0.3:
                continue
            lot = max(0.01, np.floor(balance * RISK_PCT / 100 / (dist * CONTRACT) * 100) / 100)
            l2 = entry - d * m["l2"]
            tr = Trade(name, kind, d, nb.t, sl,
                       [Leg(entry, lot, entry + d * m["tp"]),
                        Leg(l2, lot, l2 + d * m["tp"], filled=False)])
            active[name] = tr
            trades.append(tr)
    return trades, balance


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bars", required=True)
    ap.add_argument("--deals", required=True)
    a = ap.parse_args()
    b = rebuild_ohlc(pd.read_csv(a.bars))
    trades, bal = run(b)

    rows = [dict(setup=t.setup, dir="BUY" if t.d > 0 else "SELL", open=t.t_open, close=t.t_close,
                 entry=round(t.legs[0].entry, 2), l2_khop=t.legs[1].filled, pnl=round(t.pnl, 2)) for t in trades]
    df = pd.DataFrame(rows)
    print(f"Du lieu: {b.t.iloc[0]} -> {b.t.iloc[-1]} ({len(b)} nen M5)\n")
    if df.empty:
        print("Khong co tin hieu nao.")
        return
    print(df.to_string(index=False))
    print("\nTheo setup:")
    g = df.groupby("setup").pnl.agg(so_lenh="count", thang=lambda s: (s > 0).sum(), tong="sum")
    print(g.to_string())
    print(f"\nTong: {df.pnl.sum():.2f}$  | balance {BALANCE0:.0f} -> {bal:.2f}")

    # So voi lenh that cua bot
    d = pd.read_csv(a.deals)
    real = d[(d.entry == "IN") & d.comment.astype(str).str.startswith("BE Nha Trang") & ~d.comment.str.contains("L2")].copy()
    real["t"] = pd.to_datetime(real.time, format="%Y.%m.%d %H:%M:%S")
    real["setup"] = real.comment.str.replace("BE Nha Trang-", "", regex=False)
    print("\nDoi chieu voi lenh that (khop neu cung setup, cung chieu, lech <= 15 phut):")
    for _, r in real.iterrows():
        m = df[(df.setup == r.setup) & (df.dir == r.type) & ((df.open - r.t).abs() <= pd.Timedelta(minutes=15))]
        print(f"  {r.time}  {r.setup:4s} {r.type:4s} -> {'KHOP' if len(m) else 'khong bat duoc'}")
    print(f"\nLai that cua bot trong file: {d[d.magic > 0].profit.sum():.2f}$")


if __name__ == "__main__":
    main()
