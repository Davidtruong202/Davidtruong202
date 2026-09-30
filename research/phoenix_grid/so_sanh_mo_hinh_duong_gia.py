"""So sánh ba mô hình đường giá của mo_phong_phoenix.py trên DEV (01/01–30/04/2026) — để biết sai lệch của mô hình cũ.

  (a) 4 điểm / nến M1, TP khớp ở giá hiện tại (vượt TP)      — mô hình của lượt dò đầu tiên (đã dừng, không dùng);
  (b) 4 điểm / nến M1, TP khớp đúng giá TP;
  (c) nội suy từng bước ≤ 0,5 USD, TP khớp đúng giá TP         — mô hình dùng để dò set.
Cấu hình so sánh: 3 cấu hình tham chiếu và 4 cấu hình tốt nhất của lượt dò đầu tiên (ghi thẳng trong mã).
Vốn 5.000 USC, lot tầng 0 như cấu hình. KHÔNG phải backtest MT5.

Chạy:  python3 so_sanh_mo_hinh_duong_gia.py --m1 <nen_M1.csv> --out <thư mục>
"""
import argparse
import os
import sys
import time
from multiprocessing import Pool

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import do_tim_set_cent as ds  # noqa: E402
import mo_phong_phoenix as mp  # noqa: E402

# 4 cấu hình có lãi / DD cao nhất trong lượt dò đầu tiên (mô hình a), chép nguyên từ CSV của lượt đó;
# kết quả mô hình a lúc dò: N085 lãi 102.246 DD 19,1%; N140 48.957 / 16,8%; N171 57.359 / 27,2%; N010 52.374 / 14,9%; không cháy
TOT_MO_HINH_A = {
    "N085": {'lot0': 0.02, 'kieu_lot': '1.2', 'lot_max': 0.2, 'buoc_min': 10.0, 'buoc_atr': 0.5, 'so_tang': 20,
             'tia_tp': 0.5, 'tp_atr': 3.0, 'trail': 60, 'hoa_von_tang': 2, 'xoa': 'tat', 'xoa_tu': 3, 'loc_xh': True,
             'ma_h1': 100, 'giay_dca': 60, 'tia_lap_lai': True, 'cho_clear': 60},
    "N140": {'lot0': 0.01, 'kieu_lot': '1.05', 'lot_max': 0.2, 'buoc_min': 6.0, 'buoc_atr': 0.5, 'so_tang': 40,
             'tia_tp': 0.5, 'tp_atr': 1.5, 'trail': 60, 'hoa_von_tang': 12, 'xoa': 4, 'xoa_tu': 2, 'loc_xh': True,
             'ma_h1': 100, 'giay_dca': 180, 'tia_lap_lai': True, 'cho_clear': 10},
    "N171": {'lot0': 0.01, 'kieu_lot': '1.15', 'lot_max': 0.2, 'buoc_min': 1.5, 'buoc_atr': 0.8, 'so_tang': 40,
             'tia_tp': 0.5, 'tp_atr': 2.0, 'trail': 'tat', 'hoa_von_tang': 2, 'xoa': 2, 'xoa_tu': 2, 'loc_xh': False,
             'ma_h1': 20, 'giay_dca': 60, 'tia_lap_lai': True, 'cho_clear': 60},
    "N010": {'lot0': 0.01, 'kieu_lot': '1.3', 'lot_max': 0.05, 'buoc_min': 6.0, 'buoc_atr': 0.5, 'so_tang': 16,
             'tia_tp': 1.0, 'tp_atr': 0.5, 'trail': 60, 'hoa_von_tang': 6, 'xoa': 4, 'xoa_tu': 6, 'loc_xh': False,
             'ma_h1': 100, 'giay_dca': 20, 'tia_lap_lai': False, 'cho_clear': 10},
}
CAC = [("V0.21 mặc định (lot đều)", ds.V021_MAC_DINH), ("V0.21 hệ số 1,2", dict(ds.V021_MAC_DINH, kieu_lot="1.2")),
       ("hệ số 1,2 + SMA200", dict(ds.V021_MAC_DINH, kieu_lot="1.2", ma_h1=200))]

_M1 = None


def _khoi(m1_csv):
    global _M1
    _M1 = mp.chuan_bi(m1_csv)


def _chay(viec):
    ten, c, mo_hinh = viec
    ts = ds.tham_so(c, von=5000.0)            # cùng vốn với lượt dò đầu tiên
    ts.duong_gia = 0.0 if mo_hinh in ("a", "b") else 0.5
    goc = mp.MoPhong.dong
    if mo_hinh == "a":
        mp.MoPhong.dong = lambda self, v, lot=None, gia=None: goc(self, v, lot, None)
    try:
        t = time.time()
        sim, eq = mp.chay(_M1, ts, *ds.DEV)
        r = mp.tom_tat(sim, eq, ts)
    finally:
        mp.MoPhong.dong = goc
    return dict(cau_hinh=ten, mo_hinh=mo_hinh, giay=round(time.time() - t, 1),
                **{k: (r[k].item() if hasattr(r[k], "item") else r[k])
                   for k in ("net", "chay", "dd_pt", "net_dd", "basket", "sau_max", "lot_max", "gio_max")})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    cac = list(CAC) + [(f"{k} (tốt nhất mô hình a)", v) for k, v in TOT_MO_HINH_A.items()]
    viec = [(t, c, m) for t, c in cac for m in ("a", "b", "c")]
    with Pool(4, initializer=_khoi, initargs=(a.m1,)) as p:
        kq = p.map(_chay, viec)
    df = pd.DataFrame(kq)
    os.makedirs(a.out, exist_ok=True)
    df.to_csv(os.path.join(a.out, "so_sanh_mo_hinh_duong_gia.csv"), index=False)
    print(df.to_string())
    return 0


if __name__ == "__main__":
    sys.exit(main())
