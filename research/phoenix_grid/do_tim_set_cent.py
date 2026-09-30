"""Dò set Phoenix Grid cho tài khoản cent bằng mô phỏng Python mo_phong_phoenix.py — KHÔNG phải backtest MT5.

Vốn: VON USC trên lot tầng 0 = 0,01 (mặc định 10.000 USC = 100 USD; bạn cho biết 30/09/2026 vốn có thể 100–200 USD,
có thể 500 USD). Mục tiêu theo lời bạn: "quan trọng không cháy", "set DD thấp, tư duy thoát lệnh nhanh, nhiều lệnh và
lãi cao". Lần dò trước với 5.000 USC nằm trong results_mi/do_tim_set_cent/von_5000/ (chỉ DEV).

Quy trình (kế hoạch §13.9, §14 Phương án 2 — chỉ dữ liệu 2026, giá XAUUSDm M1, spread cố định 0,26 như XAUUSDc):
  DEV   01/01–30/04/2026  dò ngẫu nhiên trên các input của EA; độ bền trên 5 đường giá; láng giềng một bước (vùng
                          phẳng); đăng ký trước (commit) tối đa SO_DANG_KY ứng viên;
  VAL   08/05–30/06/2026  chạy các ứng viên đã đăng ký, chọn tối đa SO_CHON theo luật ghi sẵn, đăng ký (commit);
  TEST  08/07–27/09/2026  chạy MỘT lần các ứng viên đã chọn; set chính là hạng 1 sau VAL — TEST chỉ xác nhận
                          đạt / không đạt, không dùng TEST để đổi set.
Giữa các giai đoạn có khoảng đệm một tuần. Mọi biến thể (kể cả cháy tài khoản) đều ghi ra CSV.

Luật (cố định trong mã này, trước khi chạy):
  đường giá = đường gốc (cực trị gần giá mở đi trước) và NHIEU_VT đường có thứ tự đỉnh / đáy trong từng nến M1 ngẫu
              nhiên — phần mô phỏng không biết chắc khi không có tick thật;
  điểm      = lãi / DD lớn nhất (tiền); cháy tài khoản thì điểm = −1;
  DEV       = bước 1: SO_NGAU_NHIEN cấu hình ngẫu nhiên (lot tầng 0 cố định 0,01) + cấu hình tham chiếu, đường gốc;
              bước 2: mọi cấu hình không cháy và có lãi ở đường gốc chạy thêm NHIEU_VT đường; "bền" = không cháy trên
              cả 5 đường; mức theo DD lớn nhất của 5 đường: A ≤ DD_TOI_DA %, B ≤ DD_MUC_B %, C còn lại; xếp theo mức
              rồi trung vị điểm 5 đường;
              bước 3: SO_DANG_KY cấu hình bền đứng đầu chạy mọi láng giềng một bước (đường gốc, gồm lot tầng 0 0,02);
              điểm vùng = trung vị điểm của (láng giềng + 5 đường); đăng ký theo mức rồi điểm vùng;
  VAL       = chạy đường gốc + NHIEU_VT; chọn các ứng viên không cháy và DD ≤ DD_TOI_DA trên mọi đường, lãi > 0 ở
              đường gốc (không ứng viên nào đạt thì dùng DD ≤ DD_MUC_B và ghi rõ mức B); xếp theo trung vị điểm; tối đa
              SO_CHON;
  TEST      = đạt khi: không cháy và DD ≤ ngưỡng đã dùng ở VAL trên mọi đường, lãi > 0 và bỏ tháng tốt nhất vẫn ≥ 0 ở
              đường gốc.
Chỉ số thoát lệnh (báo cáo, không dùng để xếp hạng): giờ giữ basket trung vị / phân vị 95 / lớn nhất, số basket mỗi
ngày, số lệnh.
Kết luận cao nhất có thể: "đạt sơ bộ, cần forward dài hơn".

Chạy:
  python3 do_tim_set_cent.py dev  --m1 <nen_M1.csv> --out <thư mục> [--von 10000]
  python3 do_tim_set_cent.py dev-them --m1 <nen_M1.csv> --out <thư mục>  (thông tin: ứng viên trên 16 đường giá DEV nữa)
  python3 do_tim_set_cent.py val  --m1 <nen_M1.csv> --out <thư mục>      (đọc ung_vien_dang_ky.json)
  python3 do_tim_set_cent.py test --m1 <nen_M1.csv> --out <thư mục>      (đọc chon_sau_val.json)
  python3 do_tim_set_cent.py bao-cao --out <thư mục>                      (BAO_CAO_DO_TIM.md từ mọi CSV đã có)
  python3 do_tim_set_cent.py --tu-kiem-tra
Mã của lần dò với 5.000 USC (có thêm bước hạt giống / láng giềng / nhiễu cũ): xem lịch sử git của file này.
"""
import argparse
import csv
import json
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mo_phong_phoenix as mp  # noqa: E402

DEV = ("2026-01-01", "2026-05-01")
VAL = ("2026-05-08", "2026-07-01")
TEST = ("2026-07-08", "2026-09-28")
VON = 10000.0
DD_TOI_DA = 20.0
DD_MUC_B = 35.0
SO_NGAU_NHIEN = 360
SO_DANG_KY = 5
SO_CHON = 3
HAT_NGAU_NHIEN = 20260930
NHIEU_VT = [dict(hat=11), dict(hat=12), dict(hat=13), dict(hat=14)]
SO_DUONG_THEM = 16

# (khóa, input của EA, các giá trị theo thứ tự — láng giềng là giá trị liền kề)
KG = [
    ("lot0", "InpLotCoSo", [0.01, 0.02]),
    ("kieu_lot", "InpHeSoLot / InpDungBangLot", ["1.0", "1.05", "1.1", "1.15", "bang", "1.2", "1.3"]),
    ("lot_max", "InpLotTangToiDa", [0.02, 0.03, 0.05, 0.1, 0.2, 0.5]),
    ("buoc_min", "InpBuocMinUSD", [1.5, 3.0, 4.5, 6.0, 8.0, 10.0, 12.0, 15.0, 20.0, 25.0]),
    ("buoc_atr", "InpBuocATR", [0.5, 0.8, 1.15, 1.5, 2.0, 3.0, 4.0]),
    ("so_tang", "InpSoTangToiDa", [5, 8, 12, 16, 20, 30, 40]),
    ("tia_tp", "InpTiaTPBuoc", [0.5, 0.75, 1.0, 1.5, 2.0]),
    ("tp_atr", "InpGioTPATR", [0.5, 1.0, 1.5, 2.0, 3.0]),
    ("trail", "InpTrailClear / InpTrailGiuPT", ["tat", 40, 60, 80]),
    ("hoa_von_tang", "InpHoaVonTuTang", [0, 2, 3, 4, 6, 8, 12]),
    ("xoa", "InpXoaTangLo / InpXoaGomLai", ["tat", 0, 1, 2, 4, 6]),
    ("xoa_tu", "InpXoaTuSoTang", [2, 3, 4, 6]),
    ("loc_xh", "InpChanNguocXH", [True, False]),
    ("ma_h1", "InpPP0MA", [20, 50, 100, 200]),
    ("giay_dca", "InpGiayGiuaDCA", [20, 60, 180]),
    ("tia_lap_lai", "InpTiaLapLai", [True, False]),
    ("cho_clear", "InpGiayChoSauClear", [10, 60]),
]
KHOA = [k for k, _, _ in KG]

V021_MAC_DINH = dict(lot0=0.01, kieu_lot="1.0", lot_max=0.5, buoc_min=6.0, buoc_atr=1.15, so_tang=40, tia_tp=1.0,
                     tp_atr=1.0, trail=60, hoa_von_tang=4, xoa=4, xoa_tu=3, loc_xh=True, ma_h1=50, giay_dca=20,
                     tia_lap_lai=True, cho_clear=10)
THAM_CHIEU = [
    ("V0.21 mặc định (lot đều)", V021_MAC_DINH),
    ("V0.21 set hệ số 1,2 đã gửi", dict(V021_MAC_DINH, kieu_lot="1.2")),
    ("Gần Hydra: bảng lot, bước nhỏ", dict(V021_MAC_DINH, kieu_lot="bang", buoc_min=1.5, buoc_atr=0.5, so_tang=30)),
]

COT_KQ = ["net", "chay", "dd_pt", "dd_tien", "net_dd", "basket", "vi_pham", "swap", "thang_am", "bo1thang", "bo2thang",
          "gio_max", "sau_max", "lot_max", "buy", "sell", "gio_chan_ml", "chan_ml_dau", "lenh_max_ngay", "chan_ngay",
          "co_hd", "gio_khoa", "gio_tv", "gio_p95", "so_lenh", "basket_ngay", "von_thap", "so_ngay", "lai_ngay_tb",
          "lai_ngay_tv", "ngay_lo_pt", "ngay_xau", "ngay_tot", "chot_ngay_tb", "lot_gd", "lot_ngay"]
COT = ["giai_doan", "nhom", "ten", "tu", "den", "hat", "von", "giay"] + ["p_" + k for k in KHOA] + ["hedge"] + COT_KQ


def tham_so(c, hedge="", von=None):
    ts = mp.ThamSo()
    ts.von = VON if von is None else float(von)
    ts.lot0 = float(c["lot0"])
    if c["kieu_lot"] == "bang":
        ts.bang_lot, ts.he_so = True, 1.0
    else:
        ts.bang_lot, ts.he_so = False, float(c["kieu_lot"])
    ts.lot_max = float(c["lot_max"])
    ts.buoc_min = float(c["buoc_min"])
    ts.buoc_atr = float(c["buoc_atr"])
    ts.so_tang = int(c["so_tang"])
    ts.tia_tp = float(c["tia_tp"])
    ts.tp_atr = float(c["tp_atr"])
    ts.trail = c["trail"] != "tat"
    ts.trail_giu = 60.0 if c["trail"] == "tat" else float(c["trail"])
    ts.hoa_von_tang = int(c["hoa_von_tang"])
    ts.xoa = c["xoa"] != "tat"
    ts.xoa_gom = 4 if c["xoa"] == "tat" else int(c["xoa"])
    ts.xoa_tu = int(c["xoa_tu"])
    ts.loc_xh = bool(c["loc_xh"])
    ts.ma_h1 = int(c["ma_h1"])
    ts.giay_dca = int(c["giay_dca"])
    ts.tia_lap_lai = bool(c["tia_lap_lai"])
    ts.cho_clear = int(c["cho_clear"])
    if hedge == "v022":
        ts.hedge = True
    elif hedge == "sau15_khoa":
        ts.hedge, ts.hd_tu_buoc, ts.hd_giam, ts.khoa_dca_sau_hd = True, 15.0, "khong", True
    return ts


def khoa_ch(c):
    return json.dumps({k: c[k] for k in KHOA}, sort_keys=True)


def ngau_nhien(n, hat):
    """n cấu hình ngẫu nhiên, không trùng. Lot tầng 0 cố định 0,01 (lot nhỏ nhất, vốn 5000 USC); 0,02 chỉ thử ở bước
    láng giềng."""
    rng = np.random.default_rng(hat)
    ra, da = [], set()
    while len(ra) < n:
        c = {k: v[int(rng.integers(len(v)))] for k, _, v in KG}
        c["lot0"] = 0.01
        c = {k: (x.item() if hasattr(x, "item") else x) for k, x in c.items()}
        if khoa_ch(c) not in da:
            da.add(khoa_ch(c))
            ra.append(c)
    return ra


def lang_gieng(c):
    ra = []
    for k, _, v in KG:
        i = v.index(c[k])
        for j in (i - 1, i + 1):
            if 0 <= j < len(v):
                ra.append((k, v[j], dict(c, **{k: v[j]})))
    return ra


def dat(r, dd=DD_TOI_DA):
    return (r["chay"] == 0 and r["vi_pham"] == 0 and r["dd_pt"] <= dd and r["net"] > 0 and r["bo2thang"] >= 0)


def dat_b(r):
    """Mức B (chỉ dùng khi không đủ cấu hình đạt): không cháy, DD ≤ DD_MUC_B %, lãi > 0."""
    return r["chay"] == 0 and r["vi_pham"] == 0 and r["dd_pt"] <= DD_MUC_B and r["net"] > 0


def dat_c(r):
    """Mức C (bù khi vẫn thiếu): không cháy, lãi > 0, DD bất kỳ dưới 100%."""
    return r["chay"] == 0 and r["vi_pham"] == 0 and r["net"] > 0


def muc_cua(r):
    return "A" if dat(r) else ("B" if dat_b(r) else ("C" if dat_c(r) else ""))


def diem(r):
    return -1.0 if (r["chay"] > 0 or r["vi_pham"] > 0) else float(r["net_dd"])


# ------------------------------------------------------------------ chạy song song
_M1 = None


def _khoi(m1_csv):
    global _M1
    _M1 = mp.chuan_bi(m1_csv)


def _chay(viec):
    c = viec["c"]
    ts = tham_so(c, viec.get("hedge", ""), viec.get("von"))
    t = time.time()
    sim, eq = mp.chay(_M1, ts, viec["tu"], viec["den"], viec.get("hat"))
    r = mp.tom_tat(sim, eq, ts)
    ra = {k: None for k in COT}
    for k in COT_KQ:
        v = r.get(k, 0)
        ra[k] = v.item() if hasattr(v, "item") else v
    ra.update(giai_doan=viec["giai_doan"], nhom=viec["nhom"], ten=viec.get("ten", ""), tu=viec["tu"], den=viec["den"],
              von=ts.von,
              hat="" if viec.get("hat") is None else viec["hat"], giay=round(time.time() - t, 1),
              hedge=viec.get("hedge", ""))
    for k in KHOA:
        ra["p_" + k] = c[k]
    return ra


def chay_ds(pool, ds, duong_csv, nhan):
    for v in ds:
        v.setdefault("von", VON)
    moi = not os.path.exists(duong_csv)
    ra = []
    t0 = time.time()
    with open(duong_csv, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COT)
        if moi:
            w.writeheader()
        for n, r in enumerate(pool.imap_unordered(_chay, ds), 1):
            w.writerow(r)
            f.flush()
            ra.append(r)
            if n % 20 == 0 or n == len(ds):
                print(f"[{nhan}] {n}/{len(ds)} — {time.time() - t0:.0f} s", flush=True)
    return ra


def cau_hinh_tu_dong(r):
    c = {}
    for k, _, v in KG:
        x = r["p_" + k]
        for y in v:                      # đọc lại từ CSV: đưa về đúng kiểu trong danh sách giá trị
            if str(y) == str(x) or (not isinstance(y, (bool, str)) and not isinstance(x, (bool, str)) and float(y) == float(x)):
                c[k] = y
                break
        else:
            raise ValueError(f"{k}={x!r} không có trong không gian dò")
    return c


# ------------------------------------------------------------------ các giai đoạn
def doc_lai(duong_csv, ds):
    """Đọc lại kết quả đã chạy nếu CSV có đúng các việc trong ds (cùng tên, cùng cấu hình); không thì None."""
    if not os.path.exists(duong_csv):
        return None
    d = pd.read_csv(duong_csv, keep_default_na=False, na_values=[""])
    ra = [{k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()} for r in d.to_dict("records")]
    can = {v["ten"]: khoa_ch(v["c"]) for v in ds}
    co = {r["ten"]: khoa_ch(cau_hinh_tu_dong(r)) for r in ra}
    return ra if (len(ra) == len(ds) and co == can) else None


def giai_doan_dev(pool, out):
    """DEV bước 1 (ngẫu nhiên + tham chiếu, đường gốc), rồi bước 2–3 (giai_doan_dev_ben)."""
    tu, den = DEV
    csv1 = os.path.join(out, "dev_1_ngau_nhien.csv")
    ds = [dict(giai_doan="DEV", nhom="tham_chieu", ten=ten, c=c, tu=tu, den=den) for ten, c in THAM_CHIEU]
    ds += [dict(giai_doan="DEV", nhom="ngau_nhien", ten=f"N{i:03d}", c=c, tu=tu, den=den)
           for i, c in enumerate(ngau_nhien(SO_NGAU_NHIEN, HAT_NGAU_NHIEN))]
    kq1 = doc_lai(csv1, ds)                 # bước 1 đã chạy đủ (cùng mẫu ngẫu nhiên, cùng vốn) thì dùng lại
    if kq1 is not None and any(float(r["von"]) != VON for r in kq1):
        kq1 = None
    if kq1 is None:
        if os.path.exists(csv1):
            os.remove(csv1)
        kq1 = chay_ds(pool, ds, csv1, "DEV ngẫu nhiên")
    else:
        print(f"DEV: dùng lại {len(kq1)} kết quả bước 1 trong {csv1}", flush=True)
    print(f"DEV bước 1: {len(kq1)} cấu hình, cháy {sum(r['chay'] > 0 for r in kq1)}, không cháy và có lãi "
          f"{sum(r['chay'] == 0 and r['net'] > 0 for r in kq1)}", flush=True)
    giai_doan_dev_ben(pool, out)


def chay_vt(pool, out, ten_gd, khoang, ung_vien, ten_csv):
    tu, den = khoang
    ds = []
    for u in ung_vien:
        ds.append(dict(giai_doan=ten_gd, nhom="goc", ten=u["hat"], c=u["cau_hinh"], tu=tu, den=den))
        for nh in NHIEU_VT:
            ds.append(dict(giai_doan=ten_gd, nhom="nhieu", ten=u["hat"], c=u["cau_hinh"], tu=tu, den=den,
                           hat=nh["hat"]))
    p = os.path.join(out, ten_csv)
    if os.path.exists(p):
        os.remove(p)
    return chay_ds(pool, ds, p, ten_gd)


def giai_doan_dev_ben(pool, out):
    """DEV bước 4–5 (thêm sau khi luật DEV ban đầu cho 0 ứng viên; VAL / TEST chưa chạy):
    bước 4: mọi cấu hình không cháy và có lãi ở đường giá gốc (bước 1 + 2) chạy thêm NHIEU_VT đường giá (thứ tự cực
            trị ngẫu nhiên); "bền" = không cháy trên cả 5 đường; mức theo DD lớn nhất của 5 đường (A ≤ DD_TOI_DA,
            B ≤ DD_MUC_B, C < 100%); xếp theo mức rồi trung vị điểm 5 đường;
    bước 5: SO_DANG_KY cấu hình bền đứng đầu chạy mọi láng giềng một bước (đường gốc); điểm vùng = trung vị điểm của
            (láng giềng + 5 đường); đăng ký theo mức rồi điểm vùng."""
    tu, den = DEV
    goc = {}
    for ten in ("dev_1_ngau_nhien.csv", "dev_2_lang_gieng.csv"):
        if not os.path.exists(os.path.join(out, ten)):
            continue
        for r in pd.read_csv(os.path.join(out, ten), keep_default_na=False, na_values=[""]).to_dict("records"):
            r = {k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()}
            goc.setdefault(khoa_ch(cau_hinh_tu_dong(r)), r)
    da_co = {}                                             # (cấu hình, hạt) -> kết quả (dùng lại bước 3)
    p3 = os.path.join(out, "dev_3_nhieu.csv")
    if os.path.exists(p3):
        for r in pd.read_csv(p3, keep_default_na=False, na_values=[""]).to_dict("records"):
            r = {k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()}
            if r["tu"] == DEV[0] and r["hat"] == r["hat"]:  # bỏ các lần lệch giờ bắt đầu (trùng đường gốc)
                da_co[(khoa_ch(cau_hinh_tu_dong(r)), int(r["hat"]))] = r
    p5 = os.path.join(out, "dev_5_ben.csv")
    if os.path.exists(p5):                                   # dùng lại các lần đã chạy (cùng cấu hình, cùng hạt)
        for r in pd.read_csv(p5, keep_default_na=False, na_values=[""]).to_dict("records"):
            r = {k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()}
            da_co[(khoa_ch(cau_hinh_tu_dong(r)), int(r["hat"]))] = r
    chon = [k for k, r in goc.items() if r["chay"] == 0 and r["vi_pham"] == 0 and r["net"] > 0]
    ds5 = []
    for k in chon:
        c = cau_hinh_tu_dong(goc[k])
        for nh in NHIEU_VT:
            if (k, nh["hat"]) not in da_co:
                ds5.append(dict(giai_doan="DEV", nhom="ben", ten=goc[k]["ten"], c=c, tu=tu, den=den, hat=nh["hat"]))
    print(f"DEV bền: {len(chon)} cấu hình không cháy và có lãi ở đường gốc; chạy {len(ds5)} lần", flush=True)
    for r in chay_ds(pool, ds5, p5, "DEV bền"):
        da_co[(khoa_ch(cau_hinh_tu_dong(r)), int(r["hat"]))] = r
    bang = []
    for k in chon:
        duong = [goc[k]] + [da_co[(k, nh["hat"])] for nh in NHIEU_VT]
        ben = all(r["chay"] == 0 and r["vi_pham"] == 0 for r in duong)
        dd = max(r["dd_pt"] for r in duong)
        muc = "" if not ben else ("A" if dd <= DD_TOI_DA else ("B" if dd <= DD_MUC_B else "C"))
        bang.append(dict(k=k, ten=goc[k]["ten"], muc=muc, ben=ben, so_chay=sum(r["chay"] > 0 for r in duong),
                         dd_max_duong=dd, dd_goc=goc[k]["dd_pt"], net_goc=goc[k]["net"],
                         net_tv=float(np.median([r["net"] for r in duong])),
                         diem_tv_duong=float(np.median([diem(r) for r in duong])), duong=duong))
    bang.sort(key=lambda h: (not h["ben"], h["muc"], -h["diem_tv_duong"]))
    dau = [h for h in bang if h["ben"]][:SO_DANG_KY]
    # bước 5: láng giềng của các cấu hình bền đứng đầu
    p6 = os.path.join(out, "dev_6_lang_gieng_ben.csv")
    if os.path.exists(p6):
        for r in pd.read_csv(p6, keep_default_na=False, na_values=[""]).to_dict("records"):
            r = {k: (v.item() if hasattr(v, "item") else v) for k, v in r.items()}
            goc.setdefault(khoa_ch(cau_hinh_tu_dong(r)), r)
    ds6, da = [], set(goc)
    for h in dau:
        for kk, v, d in lang_gieng(cau_hinh_tu_dong(goc[h["k"]])):
            if khoa_ch(d) not in da:
                da.add(khoa_ch(d))
                ds6.append(dict(giai_doan="DEV", nhom="lang_gieng_ben", ten=f"{h['ten']}:{kk}={v}", c=d, tu=tu, den=den))
    for r in chay_ds(pool, ds6, p6, "DEV láng giềng bền"):
        goc[khoa_ch(cau_hinh_tu_dong(r))] = r
    for h in dau:
        lg = [goc[khoa_ch(d)] for _, _, d in lang_gieng(cau_hinh_tu_dong(goc[h["k"]]))]
        h["trung_vi_diem_lang_gieng"] = float(np.median([diem(r) for r in lg]))
        h["lang_gieng_chay"] = sum(r["chay"] > 0 for r in lg)
        h["so_lang_gieng"] = len(lg)
        h["diem_vung"] = float(np.median([diem(r) for r in lg + h["duong"]]))
    dau.sort(key=lambda h: (h["muc"], -h["diem_vung"]))
    cot = ["ten", "muc", "ben", "so_chay", "dd_max_duong", "dd_goc", "net_goc", "net_tv", "diem_tv_duong",
           "trung_vi_diem_lang_gieng", "lang_gieng_chay", "so_lang_gieng", "diem_vung"]
    ung = {id(h): f"U{i + 1}" for i, h in enumerate(dau)}
    pd.DataFrame([dict({c: h.get(c) for c in cot}, ung_vien=ung.get(id(h), ""),
                       **{"p_" + x: cau_hinh_tu_dong(goc[h["k"]])[x] for x in KHOA})
                  for h in bang]).to_csv(os.path.join(out, "dev_ben_xep_hang.csv"), index=False)
    with open(os.path.join(out, "ung_vien_dang_ky.json"), "w", encoding="utf-8") as f:
        json.dump(dict(luat=dict(DD_TOI_DA=DD_TOI_DA, VAL=VAL, TEST=TEST, NHIEU_VT=NHIEU_VT, SO_CHON=SO_CHON,
                                 chon_dev="bền trên 5 đường giá (gốc + NHIEU_VT), xếp theo mức rồi điểm vùng"),
                       ung_vien=[dict(hat=f"U{i + 1}", nguon=h["ten"], muc=h["muc"],
                                      cau_hinh=cau_hinh_tu_dong(goc[h["k"]]), diem_vung=h["diem_vung"],
                                      dd_max_duong=h["dd_max_duong"]) for i, h in enumerate(dau)]),
                  f, ensure_ascii=False, indent=1)
    ds4 = []
    for i, h in enumerate(dau[:3]):
        for hd in ("v022", "sau15_khoa"):
            ds4.append(dict(giai_doan="DEV", nhom="hedge_tham_khao", ten=f"U{i + 1}", c=cau_hinh_tu_dong(goc[h["k"]]),
                            tu=tu, den=den, hedge=hd))
    p4 = os.path.join(out, "dev_4_hedge_tham_khao.csv")
    if os.path.exists(p4):
        os.remove(p4)
    if ds4:
        chay_ds(pool, ds4, p4, "DEV hedge tham khảo")
    print(f"DEV bền xong: {sum(h['ben'] for h in bang)}/{len(bang)} cấu hình bền (mức A "
          f"{sum(h['muc'] == 'A' for h in bang)}, B {sum(h['muc'] == 'B' for h in bang)}, C "
          f"{sum(h['muc'] == 'C' for h in bang)}); {len(ds6)} láng giềng mới; đăng ký {len(dau)} ứng viên", flush=True)


def giai_doan_dev_them(pool, out):
    """Chỉ để thông tin (không dùng để chọn): các ứng viên đã đăng ký chạy thêm SO_DUONG_THEM đường giá DEV (thứ tự
    cực trị ngẫu nhiên, hạt 101…) để ước lượng tỷ lệ cháy trên nhiều đường giá hơn."""
    with open(os.path.join(out, "ung_vien_dang_ky.json"), encoding="utf-8") as f:
        dk = json.load(f)
    ds = [dict(giai_doan="DEV", nhom="nhieu_them", ten=u["hat"], c=u["cau_hinh"], tu=DEV[0], den=DEV[1], hat=100 + i)
          for u in dk["ung_vien"] for i in range(1, SO_DUONG_THEM + 1)]
    p = os.path.join(out, "dev_7_nhieu_them.csv")
    if os.path.exists(p):
        os.remove(p)
    kq = chay_ds(pool, ds, p, "DEV thêm đường giá")
    for u in dk["ung_vien"]:
        rr = [r for r in kq if r["ten"] == u["hat"]]
        print(f"{u['hat']}: cháy trên {sum(r['chay'] > 0 for r in rr)}/{len(rr)} đường thêm; DD trung vị "
              f"{np.median([r['dd_pt'] for r in rr]):.1f}%, lớn nhất {max(r['dd_pt'] for r in rr):.1f}%; lãi trung vị "
              f"{np.median([r['net'] for r in rr]):.0f}", flush=True)


def giai_doan_val(pool, out):
    with open(os.path.join(out, "ung_vien_dang_ky.json"), encoding="utf-8") as f:
        dk = json.load(f)
    kq = chay_vt(pool, out, "VAL", VAL, dk["ung_vien"], "val.csv")
    hang = []
    for u in dk["ung_vien"]:
        rr = [r for r in kq if r["ten"] == u["hat"]]
        r0 = [r for r in rr if r["nhom"] == "goc"][0]
        khong_chay = all(r["chay"] == 0 and r["vi_pham"] == 0 for r in rr) and r0["net"] > 0
        dd = max(r["dd_pt"] for r in rr)
        hang.append(dict(hat=u["hat"], cau_hinh=u["cau_hinh"], dat_val=khong_chay and dd <= DD_TOI_DA,
                         dat_val_b=khong_chay and dd <= DD_MUC_B,
                         trung_vi_diem=float(np.median([diem(r) for r in rr])), net_goc=r0["net"], dd_goc=r0["dd_pt"],
                         dd_max=dd))
    # không ứng viên nào đạt DD ≤ DD_TOI_DA thì chọn theo DD ≤ DD_MUC_B (mức B) và TEST dùng cùng ngưỡng đó
    muc_val = "A" if any(h["dat_val"] for h in hang) else "B"
    khoa = "dat_val" if muc_val == "A" else "dat_val_b"
    nguong_test = DD_TOI_DA if muc_val == "A" else DD_MUC_B
    hang.sort(key=lambda h: (not h[khoa], -h["trung_vi_diem"]))
    chon = [h for h in hang if h[khoa]][:SO_CHON]
    with open(os.path.join(out, "chon_sau_val.json"), "w", encoding="utf-8") as f:
        json.dump(dict(muc_val=muc_val, nguong_dd_test=nguong_test,
                       luat_test="không cháy và DD ≤ %.0f%% trên mọi đường, lãi > 0 ở đường gốc, bỏ tháng tốt nhất vẫn ≥ 0; "
                                 "set chính = hạng 1, TEST không dùng để đổi set" % nguong_test,
                       xep_hang_val=[{k: v for k, v in h.items() if k != "cau_hinh"} for h in hang],
                       chon=[dict(hat=h["hat"], cau_hinh=h["cau_hinh"], hang=i + 1) for i, h in enumerate(chon)]),
                  f, ensure_ascii=False, indent=1)
    for h in hang:
        print({k: v for k, v in h.items() if k != "cau_hinh"}, flush=True)


def giai_doan_test(pool, out):
    with open(os.path.join(out, "chon_sau_val.json"), encoding="utf-8") as f:
        ch = json.load(f)
    if os.path.exists(os.path.join(out, "test.csv")):
        raise SystemExit("TEST đã chạy (test.csv đã có) — chỉ được chạy một lần")
    kq = chay_vt(pool, out, "TEST", TEST, ch["chon"], "test.csv")
    for u in ch["chon"]:
        rr = [r for r in kq if r["ten"] == u["hat"]]
        r0 = [r for r in rr if r["nhom"] == "goc"][0]
        nguong = float(ch.get("nguong_dd_test", DD_TOI_DA))
        ok = (all(r["chay"] == 0 and r["vi_pham"] == 0 and r["dd_pt"] <= nguong for r in rr) and r0["net"] > 0
              and r0["bo1thang"] >= 0)
        print(u["hat"], "hạng", u["hang"], "ĐẠT" if ok else "KHÔNG ĐẠT", {k: r0[k] for k in COT_KQ}, flush=True)
    # tham khảo: cả 9 tháng (lẫn dữ liệu DEV) cho các set đã chọn
    ds = [dict(giai_doan="CA_9_THANG", nhom="tham_khao", ten=u["hat"], c=u["cau_hinh"], tu=DEV[0], den=TEST[1])
          for u in ch["chon"]]
    p = os.path.join(out, "ca_9_thang_tham_khao.csv")
    if os.path.exists(p):
        os.remove(p)
    chay_ds(pool, ds, p, "9 tháng tham khảo")

# ------------------------------------------------------------------ báo cáo
TEN_P = {k: ten for k, ten, _ in KG}
COT_BANG = ["net", "chay", "dd_pt", "net_dd", "bo2thang", "basket", "basket_ngay", "so_lenh", "gio_tv", "gio_p95",
            "gio_max", "sau_max", "lot_max", "von_thap", "buy", "sell", "swap"]
COT_NGAY = ["lai_ngay_tb", "lai_ngay_tv", "ngay_lo_pt", "ngay_xau", "ngay_tot", "lot_gd", "lot_ngay"]


def _md(df):
    if df is None or not len(df):
        return "_(không có)_\n"
    cot = list(df.columns)
    dong = ["| " + " | ".join(str(c) for c in cot) + " |", "|" + "---|" * len(cot)]
    for _, r in df.iterrows():
        dong.append("| " + " | ".join("" if pd.isna(r[c]) else (f"{r[c]:.2f}" if isinstance(r[c], float) and c not in (
            "net", "bo2thang", "bo1thang", "buy", "sell", "swap") else (f"{r[c]:.0f}" if isinstance(r[c], float) else
                                                                        str(r[c]))) for c in cot) + " |")
    return "\n".join(dong) + "\n"


def _cau_hinh_ngan(r):
    c = cau_hinh_tu_dong(r)
    lot = "bảng Hydra" if c["kieu_lot"] == "bang" else "×" + c["kieu_lot"]
    return (f"lot {c['lot0']} {lot} trần {c['lot_max']}; tầng max({c['buoc_min']}; {c['buoc_atr']}×ATR) × {c['so_tang']}; "
            f"TP tỉa {c['tia_tp']}; clear {c['tp_atr']}×ATR trail {c['trail']}; HV {c['hoa_von_tang']}; "
            f"xóa {c['xoa']}/{c['xoa_tu']}; SMA{c['ma_h1']} H1{' lọc M5' if c['loc_xh'] else ''}; DCA {c['giay_dca']}s; "
            f"lặp {'có' if c['tia_lap_lai'] else 'không'}; chờ {c['cho_clear']}s")


def bao_cao(out):
    """Tóm tắt mọi CSV đã có trong thư mục kết quả -> BAO_CAO_DO_TIM.md (mọi biến thể, kể cả cháy)."""
    def doc(ten):
        p = os.path.join(out, ten)
        return pd.read_csv(p, keep_default_na=False, na_values=[""]) if os.path.exists(p) else None
    d1, d2, d3, d4 = (doc(x) for x in ("dev_1_ngau_nhien.csv", "dev_2_lang_gieng.csv", "dev_3_nhieu.csv",
                                        "dev_4_hedge_tham_khao.csv"))
    xh, val, tst, ca = (doc(x) for x in ("dev_xep_hang.csv", "val.csv", "test.csv", "ca_9_thang_tham_khao.csv"))
    von = float(d1["von"].iloc[0]) if (d1 is not None and "von" in d1.columns) else 5000.0
    L = [f"# Dò set Phoenix Grid cho tài khoản cent {von:,.0f} USC — kết quả mô phỏng".replace(",", "."), "",
         "> Mô phỏng Python `mo_phong_phoenix.py` (đường giá nội suy ≤ 0,5 USD trong nến M1, spread 0,26, swap, margin",
         "> level 500%), KHÔNG phải backtest MT5. Chỉ dùng để so sánh cấu hình với nhau. Luật chọn ghi trong",
         "> `do_tim_set_cent.py` trước khi chạy.", ""]
    d6 = doc("dev_6_lang_gieng_ben.csv")
    dev = pd.concat([x for x in (d1, d2, d6) if x is not None], ignore_index=True) if d1 is not None else None
    if dev is not None:
        dev["muc"] = [muc_cua(r) for r in dev.to_dict("records")]
        L += ["## 1. DEV 01/01–30/04/2026: mọi biến thể", "",
              f"- Biến thể (cấu hình khác nhau, đường giá gốc): **{len(dev)}** (ngẫu nhiên + tham chiếu: {len(d1)}; "
              f"láng giềng: {(0 if d2 is None else len(d2)) + (0 if d6 is None else len(d6))}).",
              f"- Cháy tài khoản ít nhất một lần: **{int((dev.chay > 0).sum())}** ({(dev.chay > 0).mean() * 100:.0f}%).",
              f"- Ở đường giá gốc: không cháy, DD ≤ {DD_TOI_DA:.0f}%, lãi > 0, bỏ 2 tháng tốt nhất ≥ 0: "
              f"**{int((dev.muc == 'A').sum())}**; không cháy, DD ≤ {DD_MUC_B:.0f}%, lãi > 0: "
              f"**{int((dev.muc == 'B').sum())}**; không cháy, lãi > 0, DD lớn hơn: **{int((dev.muc == 'C').sum())}**.",
              ""]
        L += ["### 1.1 Tham chiếu", ""]
        t = d1[d1.nhom == "tham_chieu"][["ten"] + COT_BANG]
        L.append(_md(t))
        L += ["### 1.2 Tỷ lệ cháy theo từng input (bước 1, mẫu ngẫu nhiên)", "",
              "Mỗi dòng: một giá trị của input; số cấu hình có giá trị đó, % cháy ít nhất một lần, trung vị DD, số cấu "
              "hình không cháy.", ""]
        nn = d1[d1.nhom == "ngau_nhien"]
        for k, ten, v in KG:
            if k == "lot0":
                continue
            dong = []
            for x in v:
                m = nn[nn["p_" + k].astype(str) == str(x)]
                if len(m):
                    dong.append(f"{x}: {len(m)} cấu hình, cháy {(m.chay > 0).mean() * 100:.0f}%, DD trung vị "
                                f"{m.dd_pt.median():.0f}%, không cháy {int((m.chay == 0).sum())}")
            L.append(f"- **{ten}** — " + "; ".join(dong))
        L.append("")
        L += ["### 1.3 Các cấu hình không cháy (bước 1 + 2), xếp theo mức rồi lãi / DD", ""]
        kc = dev[dev.chay == 0].copy()
        kc["_m"] = kc.muc.replace("", "Z")
        kc = kc.sort_values(["_m", "net_dd"], ascending=[True, False])
        kc["cau_hinh"] = [_cau_hinh_ngan(r) for r in kc.to_dict("records")]
        L.append(_md(kc[["ten", "nhom", "muc"] + COT_BANG + ["cau_hinh"]].head(40)))
    if xh is not None:
        L += ["## 2. Hạt giống: vùng phẳng (láng giềng một bước) và nhiễu đường giá", ""]
        t = xh[["hat", "muc", "ben_duong_gia", "diem_goc", "trung_vi_diem_lang_gieng", "trung_vi_diem_duong_gia",
                "diem_vung", "lang_gieng_dat", "lang_gieng_chay", "so_lang_gieng", "dd_max_duong", "net_goc",
                "dd_goc"]].copy()
        t["cau_hinh"] = [_cau_hinh_ngan(r) for r in xh.to_dict("records")]
        L.append(_md(t))
    if d3 is not None:
        L += ["### 2.1 Từng đường giá nhiễu", ""]
        L.append(_md(d3[["ten", "tu", "hat"] + COT_BANG]))
    xb = doc("dev_ben_xep_hang.csv")
    if xb is not None:
        L += ["## 2b. Độ bền trên 5 đường giá (gốc + 4 thứ tự cực trị ngẫu nhiên)", "",
              "Mọi cấu hình không cháy và có lãi ở đường giá gốc chạy thêm trên 4 đường giá khác (chỉ đổi thứ tự "
              "đỉnh / đáy trong từng nến M1). Bền = không cháy trên cả 5 đường; mức theo DD lớn nhất của 5 đường "
              f"(A ≤ {DD_TOI_DA:.0f}%, B ≤ {DD_MUC_B:.0f}%, C còn lại).", "",
              f"- Cấu hình xét: **{len(xb)}**; bền: **{int(xb.ben.sum())}** (mức A {int((xb.muc == 'A').sum())}, "
              f"B {int((xb.muc == 'B').sum())}, C {int((xb.muc == 'C').sum())}); cháy trên ít nhất một đường khác: "
              f"**{int((~xb.ben.astype(bool)).sum())}**.", ""]
        t = xb.copy()
        t["cau_hinh"] = [_cau_hinh_ngan(r) for r in t.to_dict("records")]
        L += ["### 2b.1 Các cấu hình bền (xếp theo mức rồi trung vị điểm 5 đường)", ""]
        L.append(_md(t[t.ben.astype(bool)][(["ung_vien"] if "ung_vien" in t.columns else []) + ["ten", "muc", "dd_max_duong", "dd_goc", "net_goc", "net_tv", "diem_tv_duong",
                                           "trung_vi_diem_lang_gieng", "lang_gieng_chay", "so_lang_gieng", "diem_vung",
                                           "cau_hinh"]]))
        L += ["### 2b.2 Số cấu hình bền theo từng input (trong các cấu hình đã xét)", ""]
        for k, ten, v in KG:
            dong = []
            for x in v:
                m = xb[xb["p_" + k].astype(str) == str(x)]
                if len(m):
                    dong.append(f"{x}: bền {int(m.ben.sum())}/{len(m)}")
            L.append(f"- **{ten}** — " + "; ".join(dong))
        L.append("")
    if d6 is not None:
        L += ["### 2b.3 Láng giềng một bước của các ứng viên bền (đường gốc)", ""]
        L.append(_md(d6[["ten"] + COT_BANG]))
    d7 = doc("dev_7_nhieu_them.csv")
    if d7 is not None:
        L += ["### 2b.4 Thông tin: ứng viên trên 16 đường giá DEV nữa (không dùng để chọn)", ""]
        g = d7.groupby("ten").agg(so_duong=("net", "size"), so_duong_chay=("chay", lambda x: int((x > 0).sum())),
                                  dd_trung_vi=("dd_pt", "median"), dd_lon_nhat=("dd_pt", "max"),
                                  lai_trung_vi=("net", "median"), lai_thap_nhat=("net", "min"),
                                  **({"lai_ngay_tv": ("lai_ngay_tb", "median"), "lot_ngay_tv": ("lot_ngay", "median")}
                                     if "lai_ngay_tb" in d7.columns else {})).reset_index()
        L.append(_md(g))
    if d4 is not None:
        L += ["## 3. Tham khảo: hedge V0.22 (không phát hành) trên các ứng viên đầu", "",
              "`v022` = hedge như V0.22 đã dựng; `sau15_khoa` = hedge từ 15 khoảng tầng, không giảm cấp, khóa DCA sau "
              "khi đã hedge.", ""]
        L.append(_md(d4[["ten", "hedge"] + COT_BANG + ["co_hd", "gio_khoa"]]))
    for ten_gd, df in (("VAL 08/05–30/06/2026", val), ("TEST 08/07–27/09/2026 (chạy một lần)", tst),
                       ("Cả 01/01–27/09/2026 (tham khảo, lẫn dữ liệu DEV)", ca)):
        if df is not None:
            L += [f"## {ten_gd}", ""]
            L.append(_md(df[["ten", "nhom", "hat"] + COT_BANG + ["bo1thang", "thang_am"] +
                            [c for c in COT_NGAY if c in df.columns]]))
    with open(os.path.join(out, "BAO_CAO_DO_TIM.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("đã ghi", os.path.join(out, "BAO_CAO_DO_TIM.md"))
    dang_ky_md(out)


def dang_ky_md(out):
    """Bản đọc được của ung_vien_dang_ky.json và chon_sau_val.json (luật + cấu hình đầy đủ theo tên input EA)."""
    luat = __doc__[__doc__.index("Luật (cố định"):__doc__.index("Kết luận cao nhất")]
    for ten_json, ten_md, tieu_de, khoa in (
            ("ung_vien_dang_ky.json", "DANG_KY_TRUOC_VAL.md", "Đăng ký trước VAL — ứng viên sau DEV", "ung_vien"),
            ("chon_sau_val.json", "DANG_KY_TRUOC_TEST.md", "Đăng ký trước TEST — set chọn sau VAL", "chon")):
        p = os.path.join(out, ten_json)
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8") as f:
            j = json.load(f)
        L = [f"# {tieu_de}", "", "Ghi (commit) trước khi chạy giai đoạn kế tiếp; không sửa sau khi đã chạy.", "",
             "## Luật (trích `do_tim_set_cent.py`)", "", "```", luat.rstrip(), "```", ""]
        if khoa == "chon":
            L += ["Luật TEST: " + j["luat_test"], "", "## Xếp hạng VAL", ""]
            L += ["- " + ", ".join(f"{k}={v}" for k, v in h.items()) for h in j["xep_hang_val"]]
            L.append("")
        L += ["## " + ("Ứng viên" if khoa == "ung_vien" else "Set đã chọn (hạng 1 = set chính)"), ""]
        for u in j[khoa]:
            L.append(f"### {u['hat']}" + (f" (nguồn {u['nguon']})" if "nguon" in u else "") +
                     (f" — mức {u['muc']}" if "muc" in u else "") +
                     (f" — hạng {u['hang']}" if "hang" in u else ""))
            L.append("")
            L.append("| Khóa | Input EA | Giá trị |")
            L.append("|---|---|---|")
            for k in KHOA:
                L.append(f"| {k} | {TEN_P[k]} | {u['cau_hinh'][k]} |")
            L.append("")
        with open(os.path.join(out, ten_md), "w", encoding="utf-8") as f:
            f.write("\n".join(L) + "\n")
        print("đã ghi", os.path.join(out, ten_md))


def tu_kiem_tra():
    loi = []
    ds = ngau_nhien(50, 1)
    if len({khoa_ch(c) for c in ds}) != 50:
        loi.append("mẫu ngẫu nhiên bị trùng")
    for _, c in THAM_CHIEU:
        for k, _, v in KG:
            if c[k] not in v:
                loi.append(f"tham chiếu có {k}={c[k]} ngoài không gian dò")
    lg = lang_gieng(V021_MAC_DINH)
    if any(sum(d[k] != V021_MAC_DINH[k] for k in KHOA) != 1 for _, _, d in lg):
        loi.append("láng giềng khác cấu hình gốc ở nhiều hơn một tham số")
    ts = tham_so(dict(V021_MAC_DINH, kieu_lot="bang", trail="tat", xoa="tat"))
    if not (ts.bang_lot and not ts.trail and not ts.xoa):
        loi.append("đổi cấu hình sang ThamSo sai")
    ts = tham_so(V021_MAC_DINH)
    if (ts.he_so, ts.trail_giu, ts.xoa_gom, ts.ma_h1, ts.buoc_min) != (1.0, 60.0, 4, 50, 6.0):
        loi.append("V0.21 mặc định đổi sang ThamSo sai")
    r = {("p_" + k): str(v) for k, v in V021_MAC_DINH.items()}
    if khoa_ch(cau_hinh_tu_dong(r)) != khoa_ch(V021_MAC_DINH):
        loi.append("đọc lại cấu hình từ CSV sai")
    if dat(dict(chay=0, vi_pham=0, dd_pt=DD_TOI_DA, net=1.0, bo2thang=0.0)) is not True or dat(
            dict(chay=1, vi_pham=0, dd_pt=5.0, net=1.0, bo2thang=1.0)):
        loi.append("luật đạt sai")
    if [muc_cua(dict(chay=0, vi_pham=0, dd_pt=d, net=1.0, bo2thang=-1.0 if d > 20 else 1.0)) for d in (10, 30, 90)] != \
            ["A", "B", "C"] or muc_cua(dict(chay=1, vi_pham=0, dd_pt=10, net=5.0, bo2thang=1.0)) != "":
        loi.append("phân mức A / B / C sai")
    # ghi CSV rồi đọc lại đúng cấu hình (dùng lại bước 1)
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "x.csv")
        cac = [c for _, c in THAM_CHIEU] + ngau_nhien(20, 5)
        ds = [dict(ten=f"T{i}", c=c) for i, c in enumerate(cac)]
        with open(p, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=COT)
            w.writeheader()
            for v in ds:
                r = {k: 0 for k in COT}
                r.update(ten=v["ten"], hat="", **{"p_" + k: v["c"][k] for k in KHOA})
                w.writerow(r)
        if doc_lai(p, ds) is None:
            loi.append("đọc lại CSV bước 1 không khớp cấu hình")
        if doc_lai(p, ds[:-1]) is not None:
            loi.append("đọc lại CSV thiếu / thừa việc mà vẫn dùng")
    print("TỰ KIỂM TRA:", "ĐẠT" if not loi else "LỖI")
    for x in loi:
        print("  -", x)
    return 0 if not loi else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("giai_doan", nargs="?", choices=["dev", "dev-ben", "dev-them", "val", "test", "bao-cao"])
    ap.add_argument("--m1")
    ap.add_argument("--out")
    ap.add_argument("--luong", type=int, default=4)
    ap.add_argument("--von", type=float, default=VON, help="vốn USC cho lot tầng 0 = 0,01 (mặc định 10000)")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        return tu_kiem_tra()
    globals()["VON"] = a.von
    os.makedirs(a.out, exist_ok=True)
    if a.giai_doan == "bao-cao":
        bao_cao(a.out)
        return 0
    with Pool(a.luong, initializer=_khoi, initargs=(a.m1,)) as pool:
        {"dev": giai_doan_dev, "dev-ben": giai_doan_dev_ben, "dev-them": giai_doan_dev_them, "val": giai_doan_val,
         "test": giai_doan_test}[a.giai_doan](pool, a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
