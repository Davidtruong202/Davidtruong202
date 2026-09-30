"""Phoenix Grid – Bước R0.1: kiểm tra chất lượng dữ liệu tick. KHÔNG PHẢI BACKTEST.

Việc làm:
  1. Đọc file tick MT5 (một zip có thể chia phần, nhiều zip độc lập, hoặc CSV) và đếm bất thường: giá trống/không
     hợp lệ, Ask < Bid, thời gian lùi, tick trùng.
  2. Độ phủ: tick đầu/cuối, số ngày, số tick mỗi ngày.
  3. Khoảng trống > 60 giây, phân loại: cuối tuần/ngày lễ, giờ nghỉ hằng ngày, hay bất thường trong phiên.
  4. Spread theo tick: tổng thể, theo giờ server, theo ngày.
  5. Bước nhảy giá lớn nhất giữa hai tick liên tiếp trong phiên (để soi tick lỗi).
  6. (--m1) Dựng nến M1 theo Bid từ tick rồi đối chiếu với nến M1 xuất từ MT5: khớp OHLC, và cột spread của MT5
     ứng với cách đo nào (nhỏ nhất / lớn nhất / đầu nến / cuối nến).
  7. (--ticks2) So spread của bộ tick thứ hai (ví dụ XAUUSDc với XAUUSDm) trên phần thời gian trùng nhau.

Chạy:
  python3 kiem_tra_tick.py --ticks "/duong_dan/XAUUSDm_*.zip.part*" --nhan XAUUSDm \
      --m1 /duong_dan/nen_M1.csv --out results_r01
"""
import argparse
import os

import numpy as np
import pandas as pd

from pg_data import build_m1, clean_ticks, read_tick_zip

GAP_S = 60  # khoảng trống tối thiểu cần báo cáo (giây)


def load(pattern):
    df, info = read_tick_zip(pattern)
    t_ms, bid, ask, counts = clean_ticks(df)
    return t_ms, bid, ask, counts, info


def classify_gaps(t_ms):
    t = t_ms / 1000.0
    d = np.diff(t)
    idx = np.flatnonzero(d > GAP_S)
    start = pd.to_datetime(t_ms[idx], unit="ms")
    end = pd.to_datetime(t_ms[idx + 1], unit="ms")
    minutes = d[idx] / 60.0
    kind = np.where(minutes >= 24 * 60, "cuoi_tuan_hoac_le",
                    np.where((minutes >= 45) & (minutes < 180) & np.isin(start.hour, [20, 21]),
                             "nghi_hang_ngay", "trong_phien"))
    return pd.DataFrame({"tu": start, "den": end, "phut": np.round(minutes, 2), "loai": kind})


def quantiles(x, qs=(0.5, 0.9, 0.99)):
    return {f"p{int(q * 100)}": float(np.quantile(x, q)) for q in qs}


def spread_tables(t_ms, bid, ask, point):
    sp = np.rint((ask - bid) / point).astype(np.int64)
    ts = pd.to_datetime(t_ms, unit="ms")
    frame = pd.DataFrame({"gio": ts.hour, "ngay": ts.normalize(), "spread_points": sp})
    agg = {"so_tick": ("spread_points", "size"),
           "trung_vi": ("spread_points", "median"),
           "p90": ("spread_points", lambda s: s.quantile(0.9)),
           "p99": ("spread_points", lambda s: s.quantile(0.99)),
           "lon_nhat": ("spread_points", "max")}
    by_hour = frame.groupby("gio").agg(**agg)
    by_day = frame.groupby("ngay").agg(**agg)
    overall = {"so_tick": int(len(sp)), "trung_vi": float(np.median(sp)), **quantiles(sp),
               "p999": float(np.quantile(sp, 0.999)), "lon_nhat": int(sp.max()), "nho_nhat": int(sp.min())}
    return overall, by_hour, by_day


def jumps(t_ms, bid, top=10):
    dt = np.diff(t_ms) / 1000.0
    db = np.diff(bid)
    in_session = dt <= GAP_S
    absdb = np.where(in_session, np.abs(db), 0.0)
    order = np.argsort(absdb)[::-1][:top]
    table = pd.DataFrame({"thoi_diem": pd.to_datetime(t_ms[order + 1], unit="ms"),
                          "bid_truoc": bid[order], "bid_sau": bid[order + 1],
                          "buoc_nhay_usd": np.round(db[order], 3), "cach_tick_truoc_giay": np.round(dt[order], 3)})
    counts = {f"so_buoc_nhay_ge_{x}_usd": int((absdb >= x).sum()) for x in (1, 2, 5)}
    return table, counts


def compare_m1(t_ms, bid, ask, point, m1_path):
    mine = build_m1(t_ms, bid, ask, point)
    mt5 = pd.read_csv(m1_path, sep=";")
    mt5["time"] = pd.to_datetime(mt5["time"], format="%Y.%m.%d %H:%M:%S")
    lo, hi = mine["time"].min(), mine["time"].max()
    mt5 = mt5[(mt5["time"] >= lo) & (mt5["time"] <= hi)]
    m = mine.merge(mt5, on="time", how="outer", suffixes=("_tick", "_mt5"), indicator=True)
    both = m[m["_merge"] == "both"]
    res = {"so_nen_tu_tick": int(len(mine)), "so_nen_mt5_cung_ky": int(len(mt5)), "so_nen_trung_gio": int(len(both)),
           "chi_co_tu_tick": int((m["_merge"] == "left_only").sum()),
           "chi_co_trong_mt5": int((m["_merge"] == "right_only").sum())}
    for col in ("open", "high", "low", "close"):
        res[f"khop_{col}"] = float((np.abs(both[f"{col}_tick"] - both[f"{col}_mt5"]) <= point / 2).mean())
    for col in ("spread_min", "spread_max", "spread_open", "spread_close"):
        res[f"spread_mt5_bang_{col}"] = float((both["spread_points"] == both[col]).mean())
    return res, m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ticks", required=True, help="mẫu đường dẫn file tick: zip chia phần, nhiều zip độc lập, hoặc CSV")
    ap.add_argument("--nhan", default="tick", help="nhãn bộ dữ liệu, ví dụ XAUUSDc")
    ap.add_argument("--point", type=float, default=0.001, help="giá trị point của symbol (SYMBOL_POINT)")
    ap.add_argument("--m1", help="file nến M1 xuất từ MT5 (time;open;high;low;close;tick_volume;spread_points)")
    ap.add_argument("--ticks2", help="bộ tick thứ hai để so spread")
    ap.add_argument("--nhan2", default="tick2")
    ap.add_argument("--out", default="results_r01")
    a = ap.parse_args()
    out = os.path.join(a.out, a.nhan)
    os.makedirs(out, exist_ok=True)

    t_ms, bid, ask, counts, info = load(a.ticks)
    days = pd.to_datetime(t_ms, unit="ms").normalize()
    per_day = pd.Series(1, index=days).groupby(level=0).size()
    summary = {"nhan": a.nhan, "file": info["member"], "cac_phan": ",".join(info["parts"]),
               "doc_du_file": info["complete"],
               "ty_le_da_giai_nen": round(info["uncompressed_read"] / max(info["uncompressed_expected"], 1), 4),
               "tick_dau": str(pd.to_datetime(t_ms[0], unit="ms")), "tick_cuoi": str(pd.to_datetime(t_ms[-1], unit="ms")),
               "so_ngay_co_tick": int(len(per_day)), "tick_moi_ngay_trung_vi": int(per_day.median()),
               "tick_moi_ngay_it_nhat": int(per_day.min()), **counts}

    gaps = classify_gaps(t_ms)
    for k, v in gaps["loai"].value_counts().items():
        summary[f"khoang_trong_{k}"] = int(v)
    gaps.to_csv(os.path.join(out, "khoang_trong.csv"), index=False)

    overall, by_hour, by_day = spread_tables(t_ms, bid, ask, a.point)
    for k, v in overall.items():
        summary[f"spread_points_{k}"] = v
    by_hour.to_csv(os.path.join(out, "spread_tick_theo_gio.csv"))
    by_day.to_csv(os.path.join(out, "spread_tick_theo_ngay.csv"))

    jt, jc = jumps(t_ms, bid)
    summary.update(jc)
    jt.to_csv(os.path.join(out, "buoc_nhay_lon_nhat.csv"), index=False)

    if a.m1:
        res, merged = compare_m1(t_ms, bid, ask, a.point, a.m1)
        summary.update({f"doi_chieu_m1_{k}": v for k, v in res.items()})
        merged[merged["_merge"] != "both"].to_csv(os.path.join(out, "doi_chieu_m1_nen_lech.csv"), index=False)

    if a.ticks2:
        t2, b2, k2, c2, i2 = load(a.ticks2)
        lo, hi = max(t_ms[0], t2[0]), min(t_ms[-1], t2[-1])
        if lo < hi:
            s1 = (t_ms >= lo) & (t_ms <= hi)
            s2 = (t2 >= lo) & (t2 <= hi)
            _, h1, _ = spread_tables(t_ms[s1], bid[s1], ask[s1], a.point)
            _, h2, _ = spread_tables(t2[s2], b2[s2], k2[s2], a.point)
            cmp_ = h1[["trung_vi", "p90", "p99"]].join(h2[["trung_vi", "p90", "p99"]], lsuffix=f"_{a.nhan}",
                                                       rsuffix=f"_{a.nhan2}", how="outer")
            cmp_.to_csv(os.path.join(out, f"so_sanh_spread_{a.nhan}_{a.nhan2}.csv"))
            summary["so_sanh_spread_tu"] = str(pd.to_datetime(lo, unit="ms"))
            summary["so_sanh_spread_den"] = str(pd.to_datetime(hi, unit="ms"))
        else:
            summary["so_sanh_spread"] = "hai bộ tick không trùng thời gian"

    pd.Series(summary, name="gia_tri").rename_axis("khoa").to_csv(os.path.join(out, "tong_quan.csv"), sep=";")
    for k, v in summary.items():
        print(f"{k}: {v}")
    print("\nSpread theo giờ server (point):")
    print(by_hour.round(1).to_string())
    print("\nKhoảng trống bất thường trong phiên (> 60 giây):")
    print(gaps[gaps["loai"] == "trong_phien"].to_string(index=False))
    print("\nBước nhảy giá lớn nhất giữa hai tick liên tiếp:")
    print(jt.to_string(index=False))


if __name__ == "__main__":
    main()
