"""Hieu chinh nguong soc gia theo tan suat tren tick that: dem su kien bien dong 5 giay (cum cach nhau >= 300 giay,
giong co che tam dung 300 giay cua EA) theo nguong tuyet doi va theo boi so RMS 1 gio."""
import os, numpy as np, pandas as pd
z = np.load(os.environ.get("DH_TICKS", "ticks_xau_2026_01.npz"))
mid = (z["bid"] + z["ask"]) / 2
idx = pd.to_datetime(z["t_ms"], unit="ms")
s = pd.Series(mid, index=idx).resample("1s").last().ffill()
live = pd.Series(1, index=idx).resample("1s").count() > 0
mv = (s - s.shift(5)).abs()[live]
days = mv.index.normalize().nunique()
def dem(mask_index):
    n, last = 0, None
    for t in mask_index:
        if last is None or (t - last).total_seconds() >= 300: n += 1
        last = t
    return n
for thr in [2.5, 3, 4, 5, 6, 8, 10]:
    n = dem(mv[mv >= thr].index); print(f"bien dong 5 giay >= {thr:>4}$: {n:>4} su kien ({n/days:.1f}/ngay)")
rms = np.sqrt((s.diff() ** 2).rolling(3600, min_periods=600).mean())
ratio = (mv / (rms * np.sqrt(5)).reindex(mv.index)).dropna()
for k in [6, 8, 10, 12]:
    n = dem(ratio[ratio >= k].index); print(f"bien dong 5 giay >= {k} lan RMS 1 gio: {n} su kien ({n/days:.1f}/ngay)")
