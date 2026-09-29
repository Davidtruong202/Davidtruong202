"""Phoenix Grid – Bước R0.0: thống kê mô tả nến M1 XAUUSDm. KHÔNG PHẢI BACKTEST.

Mục đích: lấy số liệu thực tế để đặt kịch bản stress, ngưỡng spread và đơn vị ATR cho kế hoạch nghiên cứu.
Script không mô phỏng lệnh, không tính lợi nhuận của bất kỳ chiến lược nào.

Đầu vào : nen_M1.csv trong EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/
          (nến M1 theo Bid, cột spread_points; Exness XAUUSDm, giờ server GMT+0, 31/12/2025 → 27/09/2026).
Đầu ra  : in bảng ra màn hình và ghi CSV vào thư mục --out.

Chạy:  pip install numpy pandas
       python3 thong_ke_mo_ta.py --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv --out results

Giới hạn đã biết:
- Cột spread của nến M1 là một giá trị đại diện cho cả nến, không phải spread tại từng tick.
- Symbol là XAUUSDm (tài khoản Standard, tiền USD), không phải XAUUSDc (Standard Cent).
- Biến động ngược chiều được đo từ giá mở cửa (Bid) của mọi nến M1 tới đáy/đỉnh trong khung thời gian sau đó,
  tính theo thời gian lịch (khung 3 và 5 ngày có bao gồm cuối tuần).
"""
import argparse
import os

import numpy as np
import pandas as pd

POINT = 0.001  # XAUUSDm: point = tick_size = 0.001 (thong_tin_run.csv). Chỉ dùng để đổi spread point → USD/oz.


def load(path):
    df = pd.read_csv(path, sep=";")
    df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M:%S")
    df = df.sort_values("time").reset_index(drop=True)
    df["t"] = df["time"].values.astype("datetime64[s]").astype(np.int64)
    df["spread_usd"] = df["spread_points"] * POINT
    return df


class SparseRMQ:
    """Truy vấn min/max trên đoạn trong O(1) sau khi dựng bảng O(n log n)."""

    def __init__(self, a, op):
        self.op = op
        n = len(a)
        self.tab = [np.asarray(a, dtype=np.float64)]
        j = 1
        while (1 << j) <= n:
            prev = self.tab[-1]
            half = 1 << (j - 1)
            self.tab.append(op(prev[:-half], prev[half:]))
            j += 1
        self.log = np.zeros(n + 2, dtype=np.int64)
        for i in range(2, n + 2):
            self.log[i] = self.log[i // 2] + 1

    def query(self, lo, hi):
        """Giá trị op trên đoạn [lo, hi) cho mảng chỉ số (hi > lo)."""
        k = self.log[hi - lo]
        out = np.empty(len(lo))
        for kk in np.unique(k):
            m = k == kk
            tab = self.tab[kk]
            out[m] = self.op(tab[lo[m]], tab[hi[m] - (1 << kk)])
        return out


def coverage(df):
    d = np.diff(df["t"].values)
    gaps = pd.DataFrame({"start": df["time"].values[:-1], "end": df["time"].values[1:], "phut": d / 60})
    gaps = gaps[gaps["phut"] > 5]
    weekend = gaps[gaps["phut"] >= 24 * 60]
    daily = gaps[(gaps["phut"] >= 30) & (gaps["phut"] < 24 * 60)]
    return {
        "nen_dau": str(df["time"].iloc[0]),
        "nen_cuoi": str(df["time"].iloc[-1]),
        "so_nen": len(df),
        "so_ngay_co_giao_dich": df["time"].dt.normalize().nunique(),
        "so_lan_nghi_trong_ngay": len(daily),
        "gio_bat_dau_nghi_pho_bien": daily["start"].dt.strftime("%H:%M").value_counts().head(3).to_dict(),
        "gio_mo_lai_pho_bien": daily["end"].dt.strftime("%H:%M").value_counts().head(4).to_dict(),
        "so_lan_nghi_cuoi_tuan_le": len(weekend),
        "khoang_trong_bat_thuong_5_30_phut": int(((gaps["phut"] > 5) & (gaps["phut"] < 30)).sum()),
    }


def spread_stats(df):
    s = df["spread_usd"]
    overall = s.quantile([0.5, 0.75, 0.9, 0.99]).to_dict()
    overall["max"] = s.max()
    by_hour = df.groupby(df["time"].dt.hour)["spread_usd"].quantile([0.5, 0.9]).unstack()
    by_hour.columns = ["trung_vi", "p90"]
    by_month = df.groupby(df["time"].dt.to_period("M"))["spread_usd"].quantile([0.5, 0.9]).unstack()
    by_month.columns = ["trung_vi", "p90"]
    return overall, by_hour, by_month


def daily_range(df):
    day = df.groupby(df["time"].dt.normalize()).agg(high=("high", "max"), low=("low", "min"),
                                                    open=("open", "first"), close=("close", "last"),
                                                    n=("open", "size"))
    day = day[day["n"] >= 600]  # bỏ ngày thiếu dữ liệu (tối Chủ nhật, ngày lễ)
    day["range"] = day["high"] - day["low"]
    day["range_pct"] = day["range"] / day["open"] * 100
    by_m = day.groupby(day.index.to_period("M"))["range"].describe(percentiles=[0.5, 0.9])[["count", "50%", "90%", "max"]]
    return day, by_m


def atr_stats(df, minutes, period=14):
    g = df.set_index("time").resample(f"{minutes}min", label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}).dropna()
    pc = g["close"].shift(1)
    tr = pd.concat([g["high"] - g["low"], (g["high"] - pc).abs(), (g["low"] - pc).abs()], axis=1).max(axis=1)
    atr = tr.rolling(period).mean().iloc[period:]  # iATR của MT5 = trung bình cộng TR
    return atr.quantile([0.1, 0.5, 0.9]).to_dict()


def _adverse(df, h):
    t = df["t"].values
    lows = SparseRMQ(df["low"].values, np.minimum)
    highs = SparseRMQ(df["high"].values, np.maximum)
    lo = np.arange(len(t))
    hi = np.searchsorted(t, t + h * 60, side="right")
    ok = (hi > lo) & (t + h * 60 <= t[-1])  # chỉ lấy điểm vào có đủ dữ liệu tương lai
    lo, hi = lo[ok], hi[ok]
    e = df["open"].values[ok]
    return ok, e - lows.query(lo, hi), highs.query(lo, hi) - e


def excursions(df, horizons_min, thresholds):
    rows = []
    for h in horizons_min:
        _, adv_buy, adv_sell = _adverse(df, h)
        for side, adv in (("BUY", adv_buy), ("SELL", adv_sell)):
            row = {"khung_phut": h, "huong": side, "trung_vi_usd": np.median(adv), "p90_usd": np.quantile(adv, 0.9),
                   "p99_usd": np.quantile(adv, 0.99), "max_usd": adv.max()}
            for x in thresholds:
                row[f"P_nguoc_ge_{x}"] = (adv >= x).mean()
            rows.append(row)
    return pd.DataFrame(rows)


def excursions_by_month(df, h, thresholds):
    ok, adv_buy, adv_sell = _adverse(df, h)
    res = pd.DataFrame({"thang": df["time"].dt.to_period("M").values[ok], "buy": adv_buy, "sell": adv_sell})
    res = res[res["thang"] >= pd.Period("2026-01", "M")]  # tháng 12/2025 chỉ có 1 nến
    out = {}
    for x in thresholds:
        out[f"BUY_ge_{x}"] = res.groupby("thang")["buy"].apply(lambda s: (s >= x).mean())
        out[f"SELL_ge_{x}"] = res.groupby("thang")["sell"].apply(lambda s: (s >= x).mean())
    return pd.DataFrame(out)


def variance_ratio_lo_mackinlay(df, qs):
    """VR chồng lấp (Lo–MacKinlay 1988) trên log return M1 + thống kê z* chịu được phương sai thay đổi.

    Chỉ dùng cặp nến cách nhau đúng 1 phút để không trộn gap giờ nghỉ/cuối tuần vào return 1 phút.
    VR < 1: có xu hướng hồi về; VR > 1: có quán tính. |z*| < 1,96: không có ý nghĩa thống kê ở mức 5%.
    """
    t = df["t"].values
    r = np.diff(np.log(df["close"].values))[np.diff(t) == 60]
    n = len(r)
    mu = r.mean()
    e2 = (r - mu) ** 2
    s_a = e2.sum() / (n - 1)
    denom = e2.sum() ** 2
    cs = np.r_[0.0, np.cumsum(r)]
    out = []
    for q in qs:
        rq = cs[q:] - cs[:-q]
        m = q * (n - q + 1) * (1 - q / n)
        vr = ((rq - q * mu) ** 2).sum() / m / s_a
        theta = sum((2.0 * (q - j) / q) ** 2 * (e2[j:] * e2[:-j]).sum() / denom * n for j in range(1, q))
        out.append({"q_phut": q, "so_return_1_phut": n, "VR": vr, "z_robust": (vr - 1.0) / np.sqrt(theta / n)})
    return pd.DataFrame(out)


def weekend_gaps(df):
    d = np.diff(df["t"].values)
    idx = np.where(d >= 24 * 3600)[0]
    gap = df["open"].values[idx + 1] - df["close"].values[idx]
    return pd.DataFrame({"tu": df["time"].values[idx], "den": df["time"].values[idx + 1], "gap_usd": gap})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--m1", required=True)
    ap.add_argument("--out", default="results")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    df = load(a.m1)

    print("## Độ phủ dữ liệu")
    for k, v in coverage(df).items():
        print(f"- {k}: {v}")

    overall, by_hour, by_month = spread_stats(df)
    print("\n## Spread (USD/oz, từ cột spread của nến M1)")
    print({k: round(float(v), 3) for k, v in overall.items()})
    print(by_hour.round(3).T.to_string())
    print(by_month.round(3).to_string())
    by_hour.to_csv(os.path.join(a.out, "spread_theo_gio.csv"))
    by_month.to_csv(os.path.join(a.out, "spread_theo_thang.csv"))

    day, by_m = daily_range(df)
    print("\n## Biên độ ngày (USD/oz)")
    print(by_m.round(1).to_string())
    print("Toàn kỳ:", day["range"].describe(percentiles=[0.5, 0.75, 0.9]).round(1).to_dict())
    print("Biên độ ngày (% giá): trung vị", round(day["range_pct"].median(), 2), "p90", round(day["range_pct"].quantile(0.9), 2))
    for x in (50, 100, 150, 200, 300):
        print(f"Tỷ lệ ngày có biên độ >= {x} USD: {(day['range'] >= x).mean():.1%}")
    day.to_csv(os.path.join(a.out, "bien_do_ngay.csv"))
    by_m.to_csv(os.path.join(a.out, "bien_do_ngay_theo_thang.csv"))

    print("\n## ATR14 (USD/oz)")
    atrs = {f"M{m}": atr_stats(df, m) for m in (1, 5, 15, 60)}
    for k, v in atrs.items():
        print(k, {q: round(x, 2) for q, x in v.items()})
    med_spread = df["spread_usd"].median()
    print("Spread trung vị / ATR trung vị:", {k: f"{med_spread / v[0.5]:.1%}" for k, v in atrs.items()})
    pd.DataFrame(atrs).T.to_csv(os.path.join(a.out, "atr14.csv"))

    exc = excursions(df, [15, 60, 240, 1440, 3 * 1440, 5 * 1440], [10, 20, 50, 100, 150, 200, 300])
    print("\n## Biến động ngược chiều tối đa từ một điểm vào bất kỳ (USD/oz)")
    print(exc.round(3).to_string(index=False))
    exc.to_csv(os.path.join(a.out, "bien_dong_nguoc.csv"), index=False)

    em = excursions_by_month(df, 1440, [50, 100, 200])
    print("\n## Xác suất ngược chiều trong 24 giờ, theo tháng")
    print(em.round(3).to_string())
    em.to_csv(os.path.join(a.out, "bien_dong_nguoc_24h_theo_thang.csv"))

    vl = variance_ratio_lo_mackinlay(df, [5, 15, 30, 60, 240])
    print("\n## Variance ratio (Lo–MacKinlay, z* chịu phương sai thay đổi)")
    print(vl.round(3).to_string(index=False))
    vl.to_csv(os.path.join(a.out, "variance_ratio.csv"), index=False)

    wg = weekend_gaps(df)
    print("\n## Gap mở cửa sau cuối tuần/ngày lễ (USD/oz)")
    print(wg["gap_usd"].abs().describe(percentiles=[0.5, 0.9]).round(2).to_dict())
    print(wg.reindex(wg["gap_usd"].abs().sort_values(ascending=False).index).head(5).to_string(index=False))
    wg.to_csv(os.path.join(a.out, "gap_cuoi_tuan.csv"), index=False)


if __name__ == "__main__":
    main()
