"""Chan doan dong luong / hoi quy khung phut-gio tren nen M1 9 thang (Bid), tach T1-T6 va T7-T9."""
import numpy as np, pandas as pd
import os
P = os.environ.get("DH_M1", "../../../ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")  # nen M1 cua EA-PRO
m = pd.read_csv(P, sep=";"); m["time"] = pd.to_datetime(m["time"], format="%Y.%m.%d %H:%M:%S")
m = m.set_index("time").sort_index()
c = m["close"]
full = c.resample("1min").last().ffill()      # gia lien tuc theo phut (ffill qua gio nghi)
live = c.resample("1min").last().notna()
def er(x, n):
    num = (x - x.shift(n)).abs(); den = x.diff().abs().rolling(n).sum()
    return num / den
for half, (a, b) in {"T1-T6": ("2026-01-02", "2026-07-01"), "T7-T9": ("2026-07-01", "2026-09-28")}.items():
    print(f"\n==== {half} ====")
    x = full[a:b]; ok = live[a:b]
    for N, M in [(15, 15), (30, 30), (60, 60), (60, 30), (120, 60), (240, 120)]:
        past = x - x.shift(N); fut = x.shift(-M) - x
        e = er(x, N)
        idx = np.arange(N, len(x) - M, M)                 # mau khong chong lap theo M
        p = past.iloc[idx]; f = fut.iloc[idx]; ee = e.iloc[idx]; valid = ok.iloc[idx].values & ok.shift(-M).fillna(False).iloc[idx].values
        p, f, ee = p[valid], f[valid], ee[valid]
        corr = np.corrcoef(p, f)[0, 1]
        hi = ee > 0.45; lo = ee < 0.20
        def edge(mask):  # loi TB neu di theo huong past (USD/oz), so mau
            s = np.sign(p[mask]) * f[mask]
            return s.mean(), mask.sum()
        eh, nh = edge(hi); el, nl = edge(lo); ea, na = edge(np.ones(len(p), bool))
        print(f"qua {N:>3}p -> toi {M:>3}p | corr {corr:+.3f} | theo huong: tat ca {ea:+.2f}$ (n={na})  ER>0.45 {eh:+.2f}$ (n={nh})  ER<0.20 {el:+.2f}$ (n={nl})")
