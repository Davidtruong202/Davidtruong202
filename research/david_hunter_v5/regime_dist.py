"""Phan bo dac trung de dat nguong trang thai thi truong theo tan suat (khong theo loi nhuan)."""
import numpy as np, pandas as pd
import os
P = os.environ.get("DH_M1", "../../../ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")  # nen M1 cua EA-PRO
m = pd.read_csv(P, sep=";"); m["time"] = pd.to_datetime(m["time"], format="%Y.%m.%d %H:%M:%S"); m = m.set_index("time")
def ohlc(tf):
    return m.resample(tf, label="left", closed="left").agg({"open": "first", "high": "max", "low": "min", "close": "last", "spread_points": "median"}).dropna()
def atr(b, n=14):
    pc = b["close"].shift(1)
    tr = pd.concat([b["high"] - b["low"], (b["high"] - pc).abs(), (b["low"] - pc).abs()], axis=1).max(axis=1)
    return tr.rolling(n).mean()
m5, m15, h1 = ohlc("5min"), ohlc("15min"), ohlc("1h")
a5 = atr(m5); ah1 = atr(h1)
er = (m5["close"] - m5["close"].shift(12)).abs() / m5["close"].diff().abs().rolling(12).sum()
ema = lambda s, n: s.ewm(span=n, adjust=False).mean()
e50h = ema(h1["close"], 50); slope = (e50h - e50h.shift(3)) / 3 / ah1
e20, e50 = ema(m15["close"], 20), ema(m15["close"], 50)
q = [.1, .25, .5, .75, .9]
print("ATR M5 ($):", a5.quantile(q).round(2).to_dict())
print("ER M5(12):", er.quantile(q).round(3).to_dict())
print("|Doc EMA50 H1| / ATR H1 moi nen:", slope.abs().quantile(q).round(3).to_dict())
s = slope.shift(1).reindex(m5.index, method="ffill"); c = m5["close"]; eh = e50h.shift(1).reindex(m5.index, method="ffill")
f20 = e20.shift(1).reindex(m5.index, method="ffill"); f50 = e50.shift(1).reindex(m5.index, method="ffill")
for thr_er, thr_sl in [(0.30, 0.10), (0.30, 0.05), (0.25, 0.05), (0.25, 0.03)]:
    up = (s >= thr_sl) & (c > eh) & (f20 > f50) & (er >= thr_er)
    dn = (s <= -thr_sl) & (c < eh) & (f20 < f50) & (er >= thr_er)
    rg = (~up & ~dn) & (er <= 0.20)
    tot = er.notna() & s.notna()
    print(f"ER>={thr_er} doc>={thr_sl}: TANG {up[tot].mean()*100:.1f}%  GIAM {dn[tot].mean()*100:.1f}%  SIDEWAY {rg[tot].mean()*100:.1f}%  CHUYEN TIEP {(~up&~dn&~rg)[tot].mean()*100:.1f}%")
