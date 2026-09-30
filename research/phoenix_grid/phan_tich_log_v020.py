"""Đọc log hằng ngày của EA Phoenix Grid V0.20 / V0.21 / V0.23 TEST và tóm tắt để tối ưu dần.

Log do EA ghi trong <Common>\\Files\\PhoenixGrid\\ (phân cách ';', UTF-8), tiền tố PG_V020_, PG_V021_ hoặc PG_V023_:
  PG_V02x_basket_<symbol>_<YYYYMMDD>.csv         mỗi basket đã kết thúc một dòng
  PG_V02x_giao_dich_<symbol>_<YYYYMMDD>.csv      mỗi tầng (lệnh) đã đóng một dòng
  PG_V02x_tin_hieu_<symbol>_<YYYYMMDD>.csv       mỗi lần bộ PP xét tín hiệu một dòng (V0.21 thêm cột ma_pp0; V0.23 bỏ PP10, 9 cột của PP10 để trống)
  PG_V02x_thuc_thi_<symbol>_<YYYYMMDD>.csv       mỗi lần gửi lệnh một dòng (giá yêu cầu / khớp, retcode, độ trễ)
  PG_V02x_tong_ket_ngay_<symbol>_<YYYYMM>.csv    mỗi ngày giao dịch một dòng (gồm nạp / rút)
  PG_V02x_trang_thai_<symbol>_<YYYYMM>.csv       trạng thái thị trường Phoenix theo nến M5 (không tóm tắt ở đây)
Chạy trong Strategy Tester, tên file có thêm "_tester". Mặc định đọc mọi phiên bản V0.2x; --phien-ban để chỉ đọc một bản.
V0.22 (hedge) không phát hành nên không có log PG_V022_.

Chạy:
  python3 phan_tich_log_v020.py --thu-muc <thư mục chứa log> [--symbol XAUUSDc] [--tester] [--phien-ban V023]
                                [--out results_v021]
  python3 phan_tich_log_v020.py --tu-kiem-tra

Chỉ tóm tắt số liệu EA đã ghi. Không phải backtest, không suy ra hiệu suất tương lai.
"""
import argparse
import glob
import os
import re
import sys
import tempfile

import pandas as pd

LOAI = ["basket", "giao_dich", "tin_hieu", "thuc_thi", "tong_ket_ngay"]
EA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "MQL5", "Experts", "PhoenixGrid",
                  "EA_PHOENIX_GRID_V0_23_TEST.mq5")


def doc_loai(thu_muc, loai, symbol=None, tester=False, phien_ban=None):
    mau = os.path.join(thu_muc, f"PG_{phien_ban or 'V02?'}_{loai}_*.csv")
    files = []
    for f in sorted(glob.glob(mau)):
        ten = os.path.basename(f)
        if ("_tester_" in ten) != tester:
            continue
        if symbol and f"_{loai}_{symbol}_" not in ten:
            continue
        files.append(f)
    if not files:
        return pd.DataFrame(), []
    dfs = []
    for f in files:
        try:
            df = pd.read_csv(f, sep=";", encoding="utf-8", dtype=str, keep_default_na=False)
        except pd.errors.EmptyDataError:
            continue
        df["_file"] = os.path.basename(f)
        dfs.append(df)
    if not dfs:
        return pd.DataFrame(), files
    return pd.concat(dfs, ignore_index=True), files


def so(df, cot):
    return pd.to_numeric(df[cot].str.replace(",", ".", regex=False), errors="coerce")


def bang(df, **kw):
    """Bảng markdown (không cần thư viện tabulate)."""
    if df is None or len(df) == 0:
        return "_(không có dữ liệu)_\n"
    def o(v):
        if isinstance(v, float):
            return "" if v != v else f"{v:.2f}"
        return str(v)
    cot = [str(c) for c in df.columns]
    dong = ["| " + " | ".join(cot) + " |", "|" + "---|" * len(cot)]
    for r in df.itertuples(index=False):
        dong.append("| " + " | ".join(o(v) for v in r) + " |")
    return "\n".join(dong) + "\n"


def tom_tat(thu_muc, symbol=None, tester=False, phien_ban=None):
    d = {}
    nguon = {}
    for loai in LOAI:
        d[loai], nguon[loai] = doc_loai(thu_muc, loai, symbol, tester, phien_ban)
    out = [f"# Tóm tắt log Phoenix Grid {phien_ban or 'V0.20 / V0.21 / V0.23'}", "",
           f"Thư mục: `{thu_muc}`" + (f", symbol `{symbol}`" if symbol else "") + (", log Strategy Tester" if tester else ""), ""]
    out.append("| Loại log | Số file | Số dòng |")
    out.append("|---|---|---|")
    for loai in LOAI:
        out.append(f"| {loai} | {len(nguon[loai])} | {len(d[loai])} |")
    out.append("")
    kq = {}

    # 1. tổng kết ngày
    tk = d["tong_ket_ngay"]
    out.append("## 1. Tổng kết ngày")
    if len(tk):
        t = pd.DataFrame({"ngày": tk["ngay"], "equity đầu": so(tk, "equity_dau_ngay"), "equity cuối": so(tk, "equity_cuoi_ngay"),
                          "nạp": so(tk, "nap"), "rút": so(tk, "rut"), "thay đổi bỏ nạp/rút": so(tk, "thay_doi_bo_nap_rut"),
                          "basket đóng": so(tk, "so_basket_dong"), "lệnh mở": so(tk, "so_lenh_mo"), "tỉa": so(tk, "so_lan_tia"),
                          "DD lớn nhất %": so(tk, "dd_lon_nhat_pt"), "stop out": so(tk, "stop_out")})
        out.append(bang(t, index=False))
        kq["ngay"] = len(t)
        kq["thay_doi_bo_nap_rut"] = float(t["thay đổi bỏ nạp/rút"].sum())
    else:
        out.append("_(chưa có dòng tổng kết: EA ghi dòng của một ngày ở tick đầu tiên của ngày giao dịch kế tiếp)_\n")

    # 2. basket
    bk = d["basket"]
    out.append("## 2. Basket đã kết thúc")
    if len(bk):
        b = pd.DataFrame({"pp": bk["pp"], "huong": bk["huong"], "ly_do": bk["ly_do_dong"], "ln": so(bk, "loi_nhuan"),
                          "sau": so(bk, "tang_sau_nhat"), "lenh": so(bk, "so_lenh"), "tia": so(bk, "so_tia"),
                          "xoa": so(bk, "so_xoa"), "dd": so(bk, "lo_tha_noi_lon_nhat"),
                          "dd_pt": so(bk, "lo_tha_noi_lon_nhat_pt_equity"), "phut": so(bk, "phut_giu")})
        kq["basket"] = len(b)
        kq["basket_ln"] = float(b["ln"].sum())
        kq["basket_am"] = int((b["ln"] < 0).sum())
        out.append(f"- Số basket: **{len(b)}**, lãi ròng cộng dồn **{b['ln'].sum():.2f}**, basket âm: **{kq['basket_am']}**")
        out.append(f"- Lỗ thả nổi lớn nhất trong một basket: **{b['dd'].max():.2f}** ({b['dd_pt'].max():.2f}% equity lúc mở)")
        out.append(f"- Tầng sâu nhất: trung vị {b['sau'].median():.0f}, lớn nhất {b['sau'].max():.0f}; "
                   f"thời gian giữ trung vị {b['phut'].median():.1f} phút, lớn nhất {b['phut'].max():.1f} phút\n")
        g = b.groupby(["pp", "huong"]).agg(so=("ln", "size"), lai_rong=("ln", "sum"), tb=("ln", "mean"),
                                           sau_tb=("sau", "mean"), dd_max=("dd", "max")).round(2).reset_index()
        out.append("Theo bộ PP và hướng:\n")
        out.append(bang(g, index=False))
        g = b.groupby("ly_do").agg(so=("ln", "size"), lai_rong=("ln", "sum"), sau_tb=("sau", "mean")).round(2).reset_index()
        out.append("Theo cách clear:\n")
        out.append(bang(g, index=False))
        bins = [-1, 0, 1, 3, 5, 9, 19, 1000]
        nhan = ["0", "1", "2–3", "4–5", "6–9", "10–19", "≥20"]
        c = pd.cut(b["sau"], bins=bins, labels=nhan).value_counts().reindex(nhan, fill_value=0)
        out.append("Phân bố tầng sâu nhất của basket:\n")
        out.append(bang(pd.DataFrame({"tầng sâu nhất": nhan, "số basket": c.values}), index=False))
    else:
        out.append("_(chưa có basket kết thúc)_\n")

    # 3. lệnh
    gd = d["giao_dich"]
    out.append("## 3. Lệnh đã đóng theo lý do")
    if len(gd):
        g = pd.DataFrame({"ly_do": gd["ly_do_ra"], "ln": so(gd, "loi_nhuan"), "phut": so(gd, "phut_giu")})
        t = g.groupby("ly_do").agg(so=("ln", "size"), tong=("ln", "sum"), tb=("ln", "mean"), phut_tb=("phut", "mean"))
        out.append(bang(t.round(2).reset_index(), index=False))
        kq["lenh"] = len(g)
    else:
        out.append("_(chưa có lệnh đóng)_\n")

    # 4. tín hiệu
    ts = d["tin_hieu"]
    out.append("## 4. Tín hiệu bộ PP")
    if len(ts):
        t = ts.groupby(["pp", "ket_qua"]).size().rename("so").reset_index()
        out.append(bang(t, index=False))
        khong = ts[ts["ket_qua"].isin(["KHONG", "BI_CHAN", "LOI_GUI"])]
        t = khong.groupby(["pp", "ket_qua", "ly_do"]).size().rename("so").reset_index().sort_values("so", ascending=False).head(20)
        out.append("Lý do không vào lệnh (20 dòng nhiều nhất):\n")
        out.append(bang(t, index=False))
        kq["tin_hieu"] = len(ts)
    else:
        out.append("_(chưa có tín hiệu)_\n")

    # 5. thực thi
    th = d["thuc_thi"]
    out.append("## 5. Thực thi lệnh")
    if len(th):
        x = pd.DataFrame({"hanh_dong": th["hanh_dong"], "loai": th["loai"], "phan_loai": th["phan_loai"],
                          "yc": so(th, "gia_yeu_cau"), "khop": so(th, "gia_khop"), "tre": so(th, "tre_ms")})
        t = x.groupby(["hanh_dong", "phan_loai"]).size().rename("so").reset_index()
        out.append(bang(t, index=False))
        ok = x[(x["phan_loai"] == "OK") & (x["loai"].isin(["BUY", "SELL"])) & (x["khop"] > 0) & (x["yc"] > 0)].copy()
        if len(ok):
            # trượt giá bất lợi > 0: BUY khớp cao hơn giá yêu cầu, SELL khớp thấp hơn (đơn vị giá, USD/oz)
            ok["truot"] = (ok["khop"] - ok["yc"]).where(ok["loai"] == "BUY", ok["yc"] - ok["khop"])
            out.append(f"- Trượt giá bất lợi (USD/oz): trung bình {ok['truot'].mean():.3f}, lớn nhất {ok['truot'].max():.3f}; "
                       f"lệnh bị trượt bất lợi: {int((ok['truot'] > 0).sum())}/{len(ok)}")
            out.append(f"- Độ trễ gửi lệnh (ms): trung vị {ok['tre'].median():.0f}, p95 {ok['tre'].quantile(0.95):.0f}, "
                       f"lớn nhất {ok['tre'].max():.0f}\n")
            kq["truot_tb"] = float(ok["truot"].mean())
        loi = x[x["phan_loai"] != "OK"]
        kq["gui_loi"] = len(loi)
    else:
        out.append("_(chưa có lệnh gửi)_\n")
    return "\n".join(out), kq


def doc_tieu_de_ea():
    src = open(EA, encoding="utf-8-sig").read()
    td = dict(re.findall(r'#define\s+PG_TD_(\w+)\s+"([^"]+)"', src))
    return {"basket": td["GI"], "giao_dich": td["GD"], "tin_hieu": td["TS"], "thuc_thi": td["TH"], "tong_ket_ngay": td["TK"]}


def tu_kiem_tra():
    """Dựng log giả đúng tiêu đề EA (đọc từ file .mq5), chạy tóm tắt, kiểm tra các con số."""
    td = doc_tieu_de_ea()
    so_cot = {k: len(v.split(";")) for k, v in td.items()}
    assert so_cot == {"basket": 19, "giao_dich": 13, "tin_hieu": 23, "thuc_thi": 19, "tong_ket_ngay": 15}, so_cot
    with tempfile.TemporaryDirectory() as tmp:
        def ghi(loai, ky, dong, tester=False, pb="V023"):
            ten = os.path.join(tmp, f"PG_{pb}_{loai}_XAUUSDc_{'tester_' if tester else ''}{ky}.csv")
            with open(ten, "w", encoding="utf-8", newline="") as f:
                f.write(td[loai] + "\r\n")
                for r in dong:
                    assert len(r) == so_cot[loai], (loai, len(r))
                    f.write(";".join(str(v) for v in r) + "\r\n")

        ghi("basket", "20261001", [
            ["2026.10.01 08:00:00", "2026.10.01 08:20:00", 1, "PP10", "BUY", "4150.000", "6.00", "3.20", "TRAIL_CLEAR", "4.10",
             1, 0, 0, 0, "0.01", "2.00", "0.04", "20.0", "5004.10"],
            ["2026.10.01 09:00:00", "2026.10.01 12:00:00", 2, "PP1", "SELL", "4160.000", "6.00", "3.00", "HOA_VON", "0.20",
             9, 6, 2, 5, "0.04", "58.00", "1.16", "180.0", "5004.30"]])
        ghi("basket", "20261002", [
            ["2026.10.02 10:00:00", "2026.10.02 10:05:00", 3, "PP10", "SELL", "4170.000", "6.00", "3.10", "GIO_TP", "3.50",
             1, 0, 0, 0, "0.01", "1.00", "0.02", "5.0", "5007.80"]], pb="V020")
        ghi("basket", "20261002", [["2026.10.02 10:00:00", "", 9, "PP10", "BUY", "1", "1", "1", "X", "999", 1, 0, 0, 0,
                                     "0.01", "0", "0", "0", "0"]], tester=True)
        ghi("giao_dich", "20261001", [
            ["2026.10.01 08:00:00", "2026.10.01 08:20:00", 1, 0, "BUY", "0.01", "4150.000", "4154.100", "4156.000", "TRAIL_CLEAR", "4.10", "20.0", 11],
            ["2026.10.01 09:10:00", "2026.10.01 09:30:00", 2, 1, "SELL", "0.01", "4166.000", "4160.000", "4160.000", "TP", "6.00", "20.0", 12],
            ["2026.10.01 09:00:00", "2026.10.01 10:00:00", 2, 0, "SELL", "0.01", "4160.000", "4172.000", "4154.000", "XOA", "-12.00", "60.0", 13]])
        ghi("tin_hieu", "20261001", [
            ["2026.10.01 08:00:00", "PP10", "BUY", "4150.000", "VAO_LENH", "Mở basket #1", "4130.000", "4155.000", "4.10", 5, "0.520", 1,
             "PIN", "3.100", "30.1", "", "", "4.200", "TANG", "TANG", "OK", 26, ""],
            ["2026.10.01 08:02:00", "PP10", "BUY", "4151.000", "KHONG", "ADX thấp", "", "", "", "", "", 0, "", "3.000", "20.0",
             "", "", "4.100", "TANG", "TANG", "OK", 25, ""],
            ["2026.10.01 08:04:00", "PP10", "BUY", "4151.000", "BI_CHAN", "Đang có basket", "", "", "", "", "", 0, "", "3.000", "28.0",
             "", "", "4.100", "TANG", "TANG", "OK", 25, ""],
            ["2026.10.01 09:00:10", "PP0", "SELL", "4160.000", "BI_CHAN", "Chờ sau clear basket", "", "", "", "", "", "", "", "",
             "", "", "", "4.100", "GIAM", "GIAM", "OK", 26, "4171.250"]])
        ghi("thuc_thi", "20261001", [
            ["2026.10.01 08:00:00", 1, "MO_BASKET", 1, "BUY", "0.01", "4150.000", "4150.020", "0.000", "4156.000", 0, 10009, "OK", 45,
             "4149.740", "4150.000", "PG|1|0|6000", 11, 101],
            ["2026.10.01 09:00:00", 2, "DCA", 1, "SELL", "0.01", "4166.000", "4165.990", "0.000", "4160.000", 0, 10009, "OK", 55,
             "4166.000", "4166.260", "PG|2|1|6000", 12, 102],
            ["2026.10.01 09:05:00", 3, "DCA", 1, "SELL", "0.01", "4172.000", "0.000", "0.000", "4166.000", 0, 10004, "GIA_DOI", 80,
             "4172.000", "4172.260", "PG|2|2|6000", 0, 0]])
        ghi("tong_ket_ngay", "202610", [
            ["2026.10.01", "5000.00", "5004.30", "4.30", "0.00", "0.00", "4.30", 2, 5, 6, "4.30", "1.20", 0, "", "0.00"]])
        md, kq = tom_tat(tmp, "XAUUSDc")
        assert kq["basket"] == 3 and abs(kq["basket_ln"] - 7.80) < 1e-9 and kq["basket_am"] == 0, kq
        assert kq["lenh"] == 3 and kq["tin_hieu"] == 4 and kq["gui_loi"] == 1, kq
        assert abs(kq["truot_tb"] - (0.02 + 0.01) / 2) < 1e-9, kq
        assert kq["ngay"] == 1 and abs(kq["thay_doi_bo_nap_rut"] - 4.30) < 1e-9, kq
        md_t, kq_t = tom_tat(tmp, "XAUUSDc", tester=True)
        assert kq_t["basket"] == 1, kq_t
        assert "TRAIL_CLEAR" in md and "HOA_VON" in md and "ADX thấp" in md and "Chờ sau clear basket" in md
        md_23, kq_23 = tom_tat(tmp, "XAUUSDc", phien_ban="V023")
        assert kq_23["basket"] == 2, kq_23            # chỉ V0.23: bỏ file basket V0.20
    print("tự kiểm tra: đạt (tiêu đề khớp EA V0.23: basket 19, giao_dich 13, tin_hieu 23, thuc_thi 19, tong_ket_ngay 15 cột;"
          " đọc được nhiều tiền tố PG_V02x_)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--thu-muc", help="thư mục chứa các file PG_V02x_*.csv")
    ap.add_argument("--symbol", help="lọc theo symbol, ví dụ XAUUSDc")
    ap.add_argument("--tester", action="store_true", help="đọc log Strategy Tester (tên có _tester_)")
    ap.add_argument("--phien-ban", choices=["V020", "V021", "V023"], help="chỉ đọc log của một phiên bản (mặc định: mọi V0.2x)")
    ap.add_argument("--out", help="thư mục ghi tom_tat_log.md")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        tu_kiem_tra()
        return
    if not a.thu_muc:
        ap.error("cần --thu-muc hoặc --tu-kiem-tra")
    md, _ = tom_tat(a.thu_muc, a.symbol, a.tester, a.phien_ban)
    print(md)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        with open(os.path.join(a.out, "tom_tat_log.md"), "w", encoding="utf-8") as f:
            f.write(md + "\n")


if __name__ == "__main__":
    sys.exit(main())
