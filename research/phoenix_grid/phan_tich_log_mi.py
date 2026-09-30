"""Đọc log TEST 1 (Shadow Breakout Detection) của Phoenix Market Intelligence và đánh giá khả năng nhận diện.

Log: <Common>\\Files\\PhoenixGrid\\PMI_V001_<symbol>_d<điểm>n<số nến>[_tester]_<YYYYMMDD>.csv, mỗi nến đóng một dòng
(phân cách ';'). Nhãn d<điểm>n<số nến> là cấu hình xác nhận; chạy nhiều cấu hình song song thì lọc bằng --nhan.

Đánh giá (mọi ngưỡng ghi rõ, đo bằng giá đóng cửa trong chính log):
- Tỷ lệ thời gian ở mỗi trạng thái thị trường.
- Mỗi lần BREAKOUT SUSPECTED → kết cục: XÁC NHẬN / THẤT BẠI (reclaim) / HẾT HẠN.
- Breakout xác nhận là "đi tiếp" nếu trong H nến sau xác nhận, giá đóng cách biên bị phá ≥ 1 × độ rộng range
  trước khi có RECLAIM_BAT_DAU; ngược lại là "không đi tiếp".
- Breakout thất bại / hết hạn là "loại đúng" nếu trong H nến sau đó giá KHÔNG đóng cách biên ≥ 1 × độ rộng range
  theo hướng đó; ngược lại là "bỏ lỡ".
- Phòng thủ (shadow): số lần bắt đầu, lên cấp 2, giảm cấp, phục hồi, kích hoạt lại, bị chặn do cooldown,
  thời gian mỗi đợt; số lần bắt đầu lại trong vòng 2 giờ sau khi kết thúc (dấu hiệu bật / tắt liên tục).

Chạy:
  python3 phan_tich_log_mi.py --thu-muc <thư mục log> [--symbol XAUUSDc] [--nhan d60n2] [--tester] [--h 48] [--out <thư mục>]
  python3 phan_tich_log_mi.py --tu-kiem-tra
"""
import argparse
import glob
import os
import re
import sys
import tempfile

import pandas as pd

MQH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "MQL5", "Experts", "PhoenixGrid", "PHOENIX_MI_V0_01.mqh")


def doc_log(thu_muc, symbol=None, tester=False, nhan=None):
    files = []
    for f in sorted(glob.glob(os.path.join(thu_muc, "PMI_V001_*.csv"))):
        ten = os.path.basename(f)
        if ("_tester_" in ten) != tester or (symbol and not ten.startswith(f"PMI_V001_{symbol}_")):
            continue
        if nhan and f"_{nhan}_" not in ten:
            continue
        files.append(f)
    dfs = [pd.read_csv(f, sep=";", encoding="utf-8", dtype=str, keep_default_na=False) for f in files]
    if not dfs:
        return pd.DataFrame(), files
    df = pd.concat(dfs, ignore_index=True)
    df["t"] = pd.to_datetime(df["thoi_gian"], format="%Y.%m.%d %H:%M")
    for c in ("close", "atr", "range_high", "range_low", "breakout_score"):
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df = df.sort_values("t").drop_duplicates("t", keep="last").reset_index(drop=True)
    return df, files


def co(su_kien, ten):
    return ten in str(su_kien).split("+")


def md_bang(df):
    if df is None or len(df) == 0:
        return "_(không có dữ liệu)_\n"
    dong = ["| " + " | ".join(str(c) for c in df.columns) + " |", "|" + "---|" * len(df.columns)]
    for r in df.itertuples(index=False):
        dong.append("| " + " | ".join(f"{v:.2f}" if isinstance(v, float) else str(v) for v in r) + " |")
    return "\n".join(dong) + "\n"


def danh_gia(df, H=48):
    kq = {"so_nen": len(df)}
    out = []
    if len(df) == 0:
        return "_(không có dữ liệu)_", kq
    tt = df["market_state"].value_counts(normalize=True).mul(100).round(1)
    out.append("## 1. Thời gian ở mỗi trạng thái (% số nến)\n")
    out.append(md_bang(tt.rename("pt").reset_index()))
    kq["tt"] = tt.to_dict()

    # 2. các đợt breakout
    dot = []
    cur = None
    for i, r in df.iterrows():
        sk = r["su_kien"]
        if co(sk, "BO_NGHI_VAN"):
            d = 1 if r["breakout_direction"] == "TANG" else -1
            cur = {"bat_dau": r["t"], "i0": i, "huong": d, "tren": r["range_high"], "duoi": r["range_low"],
                   "ket_cuc": "DANG_MO", "i_kc": None, "diem_xn": None}
            dot.append(cur)
        if cur is None:
            continue
        for ev, kc in (("BO_XAC_NHAN", "XAC_NHAN"), ("BO_THAT_BAI", "THAT_BAI"), ("BO_HET_HAN", "HET_HAN"),
                       ("BO_HET_HAN_VE_RANGE", "HET_HAN")):
            if co(sk, ev) and cur["ket_cuc"] == "DANG_MO":
                cur["ket_cuc"], cur["i_kc"] = kc, i
                if kc == "XAC_NHAN":
                    cur["diem_xn"] = r["breakout_score"]
                else:
                    cur = None
                break
        if cur is not None and cur["ket_cuc"] == "XAC_NHAN" and cur.get("reclaim") is None and co(sk, "RECLAIM_BAT_DAU"):
            cur["reclaim"] = i
        if cur is not None and any(co(sk, e) for e in ("RECLAIM_XAC_NHAN", "VUNG_MOI", "BO_HET_THEO_DOI")):
            cur = None
    c = df["close"].values
    rows = []
    for e in dot:
        if e["i_kc"] is None:
            continue
        w = e["tren"] - e["duoi"]
        bien = e["tren"] if e["huong"] > 0 else e["duoi"]
        j0 = e["i_kc"] + 1
        j1 = min(len(df), j0 + H)
        di_tiep = None
        for j in range(j0, j1):
            if e["ket_cuc"] == "XAC_NHAN" and e.get("reclaim") is not None and j >= e["reclaim"]:
                break
            if (c[j] - bien) * e["huong"] >= w:
                di_tiep = j
                break
        du = (j1 - j0) >= H
        if e["ket_cuc"] == "XAC_NHAN":
            nhan = "DI_TIEP" if di_tiep is not None else ("KHONG_DI_TIEP" if du else "CHUA_DU_NEN")
        else:
            nhan = "BO_LO" if di_tiep is not None else ("LOAI_DUNG" if du else "CHUA_DU_NEN")
        rows.append({"bat_dau": e["bat_dau"], "huong": "TANG" if e["huong"] > 0 else "GIAM", "ket_cuc": e["ket_cuc"],
                     "so_nen_toi_ket_cuc": e["i_kc"] - e["i0"], "diem_xn": e["diem_xn"], "danh_gia": nhan})
    ep = pd.DataFrame(rows)
    out.append(f"## 2. Các đợt breakout (H = {H} nến, đi tiếp = đóng cách biên ≥ 1 × độ rộng range)\n")
    if len(ep):
        t = ep.groupby(["ket_cuc", "danh_gia"]).size().rename("so").reset_index()
        out.append(md_bang(t))
        xn = ep[ep["ket_cuc"] == "XAC_NHAN"]
        xn_du = xn[xn["danh_gia"] != "CHUA_DU_NEN"]
        loai = ep[ep["ket_cuc"] != "XAC_NHAN"]
        loai_du = loai[loai["danh_gia"] != "CHUA_DU_NEN"]
        kq["xac_nhan"] = len(xn)
        kq["xac_nhan_di_tiep_pt"] = round(100.0 * (xn_du["danh_gia"] == "DI_TIEP").mean(), 1) if len(xn_du) else None
        kq["loai"] = len(loai)
        kq["loai_dung_pt"] = round(100.0 * (loai_du["danh_gia"] == "LOAI_DUNG").mean(), 1) if len(loai_du) else None
        out.append(f"- Xác nhận: {len(xn)} đợt; đi tiếp {kq['xac_nhan_di_tiep_pt']}% (trên {len(xn_du)} đợt đủ {H} nến)")
        out.append(f"- Thất bại / hết hạn: {len(loai)} đợt; loại đúng {kq['loai_dung_pt']}% (trên {len(loai_du)} đợt đủ {H} nến)\n")
        out.append("Chi tiết:\n")
        out.append(md_bang(ep.assign(bat_dau=ep["bat_dau"].dt.strftime("%Y-%m-%d %H:%M"))))
    else:
        out.append("_(chưa có đợt breakout nào)_\n")

    # 3. phòng thủ (shadow)
    out.append("## 3. Phòng thủ (shadow — quyết định sẽ làm, không có lệnh thật)\n")
    ten_ev = ["DEF_BAT_DAU", "DEF_CAP_2", "DEF_GIAM_CAP", "DEF_PHUC_HOI", "DEF_TAI_KICH_HOAT", "DEF_KET_THUC",
              "DEF_HUY", "DEF_CHAN_COOLDOWN"]
    dem = {e: int(df["su_kien"].map(lambda s, e=e: co(s, e)).sum()) for e in ten_ev}
    out.append(md_bang(pd.DataFrame({"su_kien": list(dem), "so": list(dem.values())})))
    kq["def"] = dem
    bd, dai, lai = None, [], 0
    ket_thuc_cuoi = None
    for _, r in df.iterrows():
        if co(r["su_kien"], "DEF_BAT_DAU"):
            if ket_thuc_cuoi is not None and (r["t"] - ket_thuc_cuoi) <= pd.Timedelta(hours=2):
                lai += 1
            bd = r["t"]
        if bd is not None and (co(r["su_kien"], "DEF_KET_THUC") or co(r["su_kien"], "DEF_HUY")):
            dai.append((r["t"] - bd).total_seconds() / 60.0)
            ket_thuc_cuoi = r["t"]
            bd = None
    kq["def_bat_lai_2h"] = lai
    if dai:
        out.append(f"- Thời gian mỗi đợt phòng thủ (phút): trung vị {pd.Series(dai).median():.0f}, lớn nhất {max(dai):.0f}")
    out.append(f"- Bắt đầu lại trong vòng 2 giờ sau khi kết thúc: {lai} lần\n")
    return "\n".join(out), kq


def tu_kiem_tra():
    td = re.search(r'#define PMI_TIEU_DE "([^"]+)"', open(MQH, encoding="utf-8-sig").read()).group(1).split(";")
    assert len(td) == 48, len(td)
    with tempfile.TemporaryDirectory() as tmp:
        t0 = pd.Timestamp("2026-10-01 00:00")
        dong = []

        def them(i, close, state, su_kien="NEN", huong="", tren=4150.0, duoi=4140.0, diem=0):
            r = {c: "" for c in td}
            r.update({"thoi_gian": (t0 + pd.Timedelta(minutes=5 * i)).strftime("%Y.%m.%d %H:%M"), "su_kien": su_kien,
                      "market_state": state, "close": f"{close:.3f}", "atr": "2.000", "range_high": f"{tren:.3f}",
                      "range_low": f"{duoi:.3f}", "breakout_direction": huong, "breakout_score": str(diem)})
            dong.append(r)
        i = 0
        for _ in range(10):
            them(i, 4145.0, "SIDEWAY"); i += 1
        # đợt 1: breakout tăng xác nhận rồi đi tiếp (≥ 10 USD trên biên 4150)
        them(i, 4151.0, "BREAKOUT_SUSPECTED", "BO_NGHI_VAN", "TANG", diem=35); i += 1
        them(i, 4153.0, "BREAKOUT_CONFIRMED", "BO_XAC_NHAN+DEF_BAT_DAU", "TANG", diem=75); i += 1
        for k in range(5):
            them(i, 4155.0 + 2 * k, "BREAKOUT_CONFIRMED", "NEN", "TANG", diem=80); i += 1
        them(i, 4160.5, "BREAKOUT_CONFIRMED", "DEF_CAP_2", "TANG", diem=85); i += 1
        for _ in range(50):
            them(i, 4162.0, "BREAKOUT_CONFIRMED", "NEN", "TANG", diem=70); i += 1
        them(i, 4147.0, "RECLAIM", "RECLAIM_BAT_DAU", "TANG"); i += 1
        them(i, 4146.0, "RECLAIM", "NEN", "TANG"); i += 1
        them(i, 4145.0, "SIDEWAY", "RECLAIM_XAC_NHAN+DEF_PHUC_HOI"); i += 1
        them(i, 4145.0, "SIDEWAY", "DEF_KET_THUC"); i += 1
        # đợt 2: breakout giảm thất bại, sau đó giá không đi xuống xa -> loại đúng
        them(i, 4139.0, "BREAKOUT_SUSPECTED", "BO_NGHI_VAN", "GIAM", diem=30); i += 1
        them(i, 4146.0, "SIDEWAY", "BO_THAT_BAI"); i += 1
        for _ in range(60):
            them(i, 4144.0, "SIDEWAY"); i += 1
        # đợt 3: bắt đầu phòng thủ lại trong 2 giờ
        them(i, 4151.0, "BREAKOUT_SUSPECTED", "BO_NGHI_VAN", "TANG", diem=35); i += 1
        them(i, 4152.0, "BREAKOUT_CONFIRMED", "BO_XAC_NHAN", "TANG", diem=65); i += 1
        with open(os.path.join(tmp, "PMI_V001_XAUUSDc_d60n2_tester_20261001.csv"), "w", encoding="utf-8", newline="") as f:
            f.write(";".join(td) + "\r\n")
            for r in dong:
                f.write(";".join(r[c] for c in td) + "\r\n")
        df, files = doc_log(tmp, "XAUUSDc", tester=True, nhan="d60n2")
        assert len(files) == 1 and len(df) == len(dong)
        assert len(doc_log(tmp, "XAUUSDc", tester=True, nhan="d80n3")[1]) == 0
        md, kq = danh_gia(df, H=48)
        assert kq["xac_nhan"] == 2 and kq["xac_nhan_di_tiep_pt"] == 100.0, kq
        assert kq["loai"] == 1 and kq["loai_dung_pt"] == 100.0, kq
        assert kq["def"]["DEF_BAT_DAU"] == 1 and kq["def"]["DEF_CAP_2"] == 1 and kq["def"]["DEF_KET_THUC"] == 1, kq
        assert "CHUA_DU_NEN" in md
    print("tự kiểm tra: đạt (tiêu đề log 48 cột đọc từ PHOENIX_MI_V0_01.mqh)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--thu-muc")
    ap.add_argument("--symbol")
    ap.add_argument("--nhan", help="nhãn cấu hình trong tên file, ví dụ d60n2")
    ap.add_argument("--tester", action="store_true")
    ap.add_argument("--h", type=int, default=48, help="số nến xét diễn biến sau kết cục (mặc định 48)")
    ap.add_argument("--out")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        tu_kiem_tra()
        return
    if not a.thu_muc:
        ap.error("cần --thu-muc hoặc --tu-kiem-tra")
    df, files = doc_log(a.thu_muc, a.symbol, a.tester, a.nhan)
    md, _ = danh_gia(df, a.h)
    md = f"# Đánh giá log Shadow Breakout Detection\n\n{len(files)} file, {len(df)} nến.\n\n" + md
    print(md)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        with open(os.path.join(a.out, "danh_gia_mi.md"), "w", encoding="utf-8") as f:
            f.write(md + "\n")


if __name__ == "__main__":
    sys.exit(main())
