"""Quy đổi set đã chọn sang vốn khác (thông tin, không dùng để chọn set): cùng cấu hình, đổi vốn và lot tầng 0 / trần lot
theo cùng tỷ lệ, chạy mô phỏng trên DEV, VAL, TEST và cả 9 tháng (đường giá gốc + 4 đường nhiễu).

Ví dụ: set dò ở 10.000 USC với lot 0,01 -> 20.000 USC với lot 0,01 (rủi ro một nửa) hoặc 0,02 (rủi ro như cũ), 50.000
USC với lot 0,02 / 0,05. KHÔNG phải backtest MT5.

Chạy:  python3 quy_doi_von_set.py --m1 <nen_M1.csv> --out <thư mục kết quả có chon_sau_val.json> [--hang 1]
"""
import argparse
import json
import os
import sys
import time
from multiprocessing import Pool

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do_tim_set_cent as ds  # noqa: E402
import mo_phong_phoenix as mp  # noqa: E402

# (vốn USC, lot tầng 0): hệ số lot = lot tầng 0 / 0,01, trần lot mỗi tầng nhân cùng hệ số
PHUONG_AN = [(10000.0, 0.01), (20000.0, 0.01), (20000.0, 0.02), (50000.0, 0.02), (50000.0, 0.03), (50000.0, 0.05)]
KHOANG = {"DEV": ds.DEV, "VAL": ds.VAL, "TEST": ds.TEST, "CA_9_THANG": (ds.DEV[0], ds.TEST[1])}

_M1 = None


def _khoi(m1_csv):
    global _M1
    _M1 = mp.chuan_bi(m1_csv)


def _chay(viec):
    c, von, lot0, ten_k, hat = viec
    ts = ds.tham_so(c, von=von)
    hs = lot0 / 0.01
    ts.lot0 = lot0
    ts.lot_max = round(float(c["lot_max"]) * hs, 2)
    t = time.time()
    sim, eq = mp.chay(_M1, ts, *KHOANG[ten_k], hat)
    r = mp.tom_tat(sim, eq, ts)
    return dict(von=von, lot0=lot0, tran_lot=ts.lot_max, khoang=ten_k, hat="" if hat is None else hat,
                giay=round(time.time() - t, 1), **{k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--hang", type=int, default=1)
    ap.add_argument("--json", default="chon_sau_val.json", help="file chọn set trong thư mục --out")
    ap.add_argument("--phuong-an", help="danh sách vốn:lot, ví dụ 10000:0.01,50000:0.05 (mặc định PHUONG_AN)")
    ap.add_argument("--khoang", help="danh sách khoảng, ví dụ CA_9_THANG (mặc định cả 4)")
    ap.add_argument("--ten", default="", help="hậu tố tên file kết quả")
    a = ap.parse_args()
    global PHUONG_AN, KHOANG
    if a.phuong_an:
        PHUONG_AN = [(float(x.split(":")[0]), float(x.split(":")[1])) for x in a.phuong_an.split(",")]
    if a.khoang:
        KHOANG = {k: v for k, v in KHOANG.items() if k in a.khoang.split(",")}
    with open(os.path.join(a.out, a.json), encoding="utf-8") as f:
        ch = json.load(f)
    u = [x for x in ch["chon"] if x["hang"] == a.hang][0]
    viec = [(u["cau_hinh"], von, lot0, k, hat) for von, lot0 in PHUONG_AN for k in KHOANG
            for hat in [None] + [n["hat"] for n in ds.NHIEU_VT]]
    with Pool(4, initializer=_khoi, initargs=(a.m1,)) as p:
        kq = p.map(_chay, viec)
    df = pd.DataFrame(kq)
    df.to_csv(os.path.join(a.out, f"quy_doi_von_hang{a.hang}{a.ten}.csv"), index=False)
    g = df.groupby(["von", "lot0", "khoang"]).agg(
        so_duong=("net", "size"), so_duong_chay=("chay", lambda x: int((x > 0).sum())), dd_lon_nhat=("dd_pt", "max"),
        dd_goc=("dd_pt", "first"), lai_goc=("net", "first"), lai_thap_nhat=("net", "min"),
        gio_p95=("gio_p95", "first"), basket_ngay=("basket_ngay", "first"), lai_ngay_tb=("lai_ngay_tb", "first"),
        lai_ngay_tv=("lai_ngay_tv", "first"), ngay_lo_pt=("ngay_lo_pt", "first"), ngay_xau=("ngay_xau", "first"),
        lot_ngay=("lot_ngay", "first"), lot_gd=("lot_gd", "first"), tran_lot=("tran_lot", "first"),
        lot_ro_max=("lot_max", "first"), ngay_x2_goc=("ngay_x2", "first"),
        so_duong_x2=("ngay_x2", lambda x: int(pd.to_numeric(x, errors="coerce").notna().sum())),
        ngay_chay_dau_som_nhat=("ngay_chay_dau", lambda x: pd.to_numeric(x, errors="coerce").min())).reset_index()
    g.to_csv(os.path.join(a.out, f"quy_doi_von_hang{a.hang}{a.ten}_tom_tat.csv"), index=False)
    print(g.to_string())
    return 0


if __name__ == "__main__":
    sys.exit(main())
