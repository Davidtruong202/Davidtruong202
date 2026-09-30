"""Gia thuyet H-D1: lenh cung chieu xu huong ngay (dong luc chuoi thoi gian) tot hon lenh nguoc chieu.
Dinh nghia chot TRUOC khi xem ket qua (khong nhin tuong lai: chi dung nen D1 da dong truoc ngay vao lenh):
  D1a: dong cua hom truoc > EMA20 D1 -> xu huong tang, nguoc lai giam
  D1b: dong cua hom truoc so voi dong cua 20 phien truoc (dong luc 20 ngay)
  D1c: dong cua hom truoc so voi dong cua 5 phien truoc (dong luc 1 tuan)
"""
import glob, sys
import numpy as np, pandas as pd
import os
P = os.environ.get("DH_M1", "../../../ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")  # nen M1 cua EA-PRO
m = pd.read_csv(P, sep=";"); m["time"] = pd.to_datetime(m["time"], format="%Y.%m.%d %H:%M:%S"); m = m.set_index("time")
d1 = m["close"].resample("1D").last().dropna()
ema20 = d1.ewm(span=20, adjust=False).mean()
sig = pd.DataFrame({"a": np.sign(d1 - ema20), "b": np.sign(d1 - d1.shift(20)), "c": np.sign(d1 - d1.shift(5))})
sig = sig.shift(1)             # chi dung ngay da dong truoc ngay vao lenh
sig.index = sig.index.normalize()
f = sorted(glob.glob(sys.argv[1] + "/*_lenh_ao.csv"))
a = pd.concat([pd.read_csv(x, sep=";") for x in f], ignore_index=True)
a["t_dong"] = pd.to_datetime(a["thoi_gian_dong"], format="%Y.%m.%d %H:%M:%S")
a["t_vao"] = a["t_dong"] - pd.to_timedelta(a["giu_phut"], unit="m")
a["ngay"] = a["t_vao"].dt.normalize()
a = a.merge(sig, left_on="ngay", right_index=True, how="left")
a["h"] = np.where(a["huong"] == "BUY", 1, -1)
a["nua"] = np.where(a["t_dong"] < "2026-07-01", "T1-T6", "T7-T9")
for k in "abc":
    a["cung_" + k] = np.where(a[k] == a["h"], "CUNG_CHIEU", "NGUOC_CHIEU")
    g = a.dropna(subset=[k]).groupby(["cung_" + k, "nua"])["ket_qua_R"]
    t = pd.DataFrame({"n": g.size(), "kyvong_R": g.mean(), "se": g.std() / np.sqrt(g.size()), "WR": g.apply(lambda x: (x > 0).mean())})
    print(f"\n== D1{k} ==\n" + t.round(3).to_string())
g = a.dropna(subset=["a"]).groupby(["pp", "cung_a", "nua"])["ket_qua_R"]
print("\n== D1a theo PP ==\n" + pd.DataFrame({"n": g.size(), "kyvong_R": g.mean(), "se": g.std() / np.sqrt(g.size())}).round(3).to_string())
