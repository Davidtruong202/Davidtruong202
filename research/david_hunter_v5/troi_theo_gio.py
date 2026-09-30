"""Gia thuyet H-GIO: do troi gia trung binh theo gio (gio server GMT+0) co on dinh giua T1-T6 va T7-T9 khong."""
import numpy as np, pandas as pd
import os
P = os.environ.get("DH_M1", "../../../ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")  # nen M1 cua EA-PRO
m = pd.read_csv(P, sep=";"); m["time"] = pd.to_datetime(m["time"], format="%Y.%m.%d %H:%M:%S"); m = m.set_index("time")
h = m["close"].resample("1h").last().dropna()
o = m["open"].resample("1h").first().dropna()
r = (h - o).dropna()                      # thay doi gia trong tung gio (USD/oz), theo gio mo cua cua nen
df = pd.DataFrame({"r": r})
df["gio"] = df.index.hour
df["nua"] = np.where(df.index < "2026-07-01", "T1-T6", "T7-T9")
g = df.groupby(["gio", "nua"])["r"]
t = pd.DataFrame({"n": g.size(), "tb": g.mean(), "t_stat": g.mean() / (g.std() / np.sqrt(g.size()))}).unstack("nua")
print(t.round(2).to_string())
# Theo phien
df["phien"] = pd.cut(df["gio"], [-1, 6, 12, 16, 20, 23], labels=["A_0-7", "AU_7-13", "MY1_13-17", "MY2_17-21", "DEM_21-24"])
g = df.groupby(["phien", "nua"], observed=True)["r"]
print("\n" + pd.DataFrame({"n": g.size(), "tong": g.sum(), "tb": g.mean(), "t_stat": g.mean() / (g.std() / np.sqrt(g.size()))}).round(2).to_string())
