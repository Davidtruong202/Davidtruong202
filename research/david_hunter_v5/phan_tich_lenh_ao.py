"""Phan tich lenh ao (moi tin hieu) cua EA V5 tu log mt5sim: diem chat luong co du bao ket qua khong, on dinh giua 2 nua?"""
import glob, sys
import numpy as np, pandas as pd
d = sys.argv[1]
f = sorted(glob.glob(d + "/*_lenh_ao.csv"))
a = pd.concat([pd.read_csv(x, sep=";") for x in f], ignore_index=True)
a["t"] = pd.to_datetime(a["thoi_gian_dong"], format="%Y.%m.%d %H:%M:%S")
a["nua"] = np.where(a["t"] < "2026-07-01", "T1-T6", "T7-T9")
print("so lenh ao:", len(a), " | vao that:", int(a["vao_that"].sum()))
def tk(g):
    return pd.Series({"n": len(g), "kyvong_R": g["ket_qua_R"].mean(), "se": g["ket_qua_R"].std() / np.sqrt(max(len(g), 1)),
                      "WR": (g["ket_qua_R"] > 0).mean()})
print("\n== Theo nua va PP ==")
print(a.groupby(["pp", "nua"]).apply(tk, include_groups=False).round(3).to_string())
a["nhom_diem"] = pd.cut(a["diem"], [0, 45, 55, 65, 75, 101])
print("\n== Theo nhom diem (tat ca PP) ==")
print(a.groupby(["nhom_diem", "nua"], observed=True).apply(tk, include_groups=False).round(3).to_string())
print("\n== Theo huong va nua ==")
print(a.groupby(["huong", "nua"]).apply(tk, include_groups=False).round(3).to_string())
print("\n== Theo trang thai va nua ==")
print(a.groupby(["trang_thai", "nua"]).apply(tk, include_groups=False).round(3).to_string())
print("\n== Vao that vs bo qua ==")
print(a.groupby(["vao_that", "nua"]).apply(tk, include_groups=False).round(3).to_string())
