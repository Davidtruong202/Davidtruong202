"""Đếm tần suất tín hiệu PP10 (Fib + Bollinger theo SET M2) trên nến lịch sử — trả lời "bao lâu Phoenix mới vào lệnh".

Chạy lại đúng các điều kiện của XetPP10 / TimSetupPP10 trong EA_PHOENIX_GRID_V0_20_TEST.mq5 trên nến M2 dựng từ M1,
đếm số nến qua từng bước lọc (phễu) và số tín hiệu mỗi ngày. Chưa tính các chặn của Phoenix (sideway, ngược breakout /
xu hướng M5, spread, phiên, tin, đang có basket), nên đây là **cận trên** số lần mở basket bằng PP10.
Không phải EA, không phải backtest giao dịch.

Chạy:  python3 tan_suat_pp10.py --m1 <nen_M1.csv> [--out <thư mục>]
"""
import argparse
import os
import sys

import numpy as np
import pandas as pd

# tham số mặc định của V0.20 (SET M2_FIBO)
P = dict(ema=53, doc=12, adx_min=27.0, atr_min=0.30, atr_ck=14, adx_ck=14, W=52, hoi_min=4, hoi_max=9, nhip_atr=3.0,
         fib_min=0.5, fib_max=0.618, fib_tol=0.05, fib_hl=0.786, bb_ck=11, bb_lech=2.4, cham_atr=0.15, pin=0.77)


def chi_bao(df):
    h, l, c = df["high"].values, df["low"].values, df["close"].values
    n = len(df)
    pc = np.r_[c[0], c[:-1]]
    tr = np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))
    atr = pd.Series(tr).rolling(P["atr_ck"]).mean().values
    up = h - np.r_[h[0], h[:-1]]
    dn = np.r_[l[0], l[:-1]] - l
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    mdm = np.where((dn > up) & (dn > 0), dn, 0.0)
    a = 2.0 / (P["adx_ck"] + 1)
    adx = np.zeros(n)
    sp = sm = sadx = 0.0
    for i in range(1, n):
        trr = tr[i] if tr[i] > 0 else 1e-9
        sp += a * (100.0 * pdm[i] / trr - sp)
        sm += a * (100.0 * mdm[i] / trr - sm)
        s = sp + sm
        sadx += a * ((100.0 * abs(sp - sm) / s if s > 0 else 0.0) - sadx)
        adx[i] = sadx
    ema = pd.Series(c).ewm(span=P["ema"], adjust=False).mean().values
    ma = pd.Series(c).rolling(P["bb_ck"]).mean()
    sd = pd.Series(c).rolling(P["bb_ck"]).std(ddof=0)
    return atr, adx, ema, (ma - P["bb_lech"] * sd).values, (ma + P["bb_lech"] * sd).values


def xet(o, h, l, c, atr, bbL, bbU, k, d):
    """Setup PP10 hướng d tại nến đã đóng k (nến 1 của EA). Trả về lý do trượt hoặc ''."""
    W, a = P["W"], atr[k]
    idx = lambda s: k - (s - 1)          # chỉ số chuỗi s (1 = nến tín hiệu) -> chỉ số mảng
    iC = 1
    for s in range(2, W + 1):
        if (d > 0 and h[idx(s)] > h[idx(iC)]) or (d < 0 and l[idx(s)] < l[idx(iC)]):
            iC = s
    hoi_nen = iC - 1
    if hoi_nen < P["hoi_min"]:
        return "hoi_chua_du_nen"
    if hoi_nen > P["hoi_max"]:
        return "hoi_qua_so_nen"
    if iC >= W:
        return "khong_co_nhip"
    iD = iC + 1
    for s in range(iC + 2, W + 1):
        if (d > 0 and l[idx(s)] < l[idx(iD)]) or (d < 0 and h[idx(s)] > h[idx(iD)]):
            iD = s
    cuoi = h[idx(iC)] if d > 0 else l[idx(iC)]
    dau = l[idx(iD)] if d > 0 else h[idx(iD)]
    nhip = abs(cuoi - dau)
    if nhip <= 0 or nhip < P["nhip_atr"] * a:
        return "nhip_nho"
    seg = range(1, iC)
    cuc = min(l[idx(s)] for s in seg) if d > 0 else max(h[idx(s)] for s in seg)
    hoi_sau = (cuoi - cuc) / nhip if d > 0 else (cuc - cuoi) / nhip
    hoi = (cuoi - c[k]) / nhip if d > 0 else (c[k] - cuoi) / nhip
    if hoi_sau > P["fib_hl"]:
        return "hoi_qua_0786"
    if hoi < P["fib_min"] - P["fib_tol"] or hoi > P["fib_max"] + P["fib_tol"]:
        return "ngoai_vung_fib"
    cham = (l[k] <= bbL[k] + P["cham_atr"] * a) if d > 0 else (h[k] >= bbU[k] - P["cham_atr"] * a)
    if not cham:
        return "khong_cham_bb"
    o1, c1, rg = o[k], c[k], h[k] - l[k]
    if rg > 0:
        bac = (min(o1, c1) - l[k]) if d > 0 else (h[k] - max(o1, c1))
        if bac >= P["pin"] * rg:
            return ""
    o2, c2 = o[k - 1], c[k - 1]
    if d > 0 and c1 > o1 and c2 < o2 and c1 >= o2 and o1 <= c2:
        return ""
    if d < 0 and c1 < o1 and c2 > o2 and c1 <= o2 and o1 >= c2:
        return ""
    o3, c3 = o[k - 2], c[k - 2]
    nen3 = (c3 < o3) if d > 0 else (c3 > o3)
    nen1 = (c1 > o1 and c1 > (o3 + c3) / 2) if d > 0 else (c1 < o1 and c1 < (o3 + c3) / 2)
    if nen3 and abs(c3 - o3) >= 0.6 * a and abs(c2 - o2) <= 0.3 * a and nen1:
        return ""
    return "khong_co_nen_xac_nhan"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1", required=True)
    ap.add_argument("--out")
    a = ap.parse_args()
    m1 = pd.read_csv(a.m1, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m2 = (m1.set_index("time").sort_index()
          .resample("2min", label="left", closed="left")
          .agg({"open": "first", "high": "max", "low": "min", "close": "last"}).dropna())
    o, h, l, c = (m2[x].values for x in ("open", "high", "low", "close"))
    atr, adx, ema, bbL, bbU = chi_bao(m2)
    t = m2.index
    phieu = {"tong_nen": 0, "co_huong_ema": 0, "qua_adx": 0, "qua_atr": 0}
    ly = {}
    tin = []
    for k in range(max(P["W"], P["doc"]) + 60, len(m2)):
        phieu["tong_nen"] += 1
        mua = c[k] > ema[k] and ema[k] > ema[k - P["doc"]]
        ban = c[k] < ema[k] and ema[k] < ema[k - P["doc"]]
        if not (mua or ban):
            continue
        phieu["co_huong_ema"] += 1
        if adx[k] < P["adx_min"]:
            continue
        phieu["qua_adx"] += 1
        if not atr[k] >= P["atr_min"]:
            continue
        phieu["qua_atr"] += 1
        d = 1 if mua else -1
        r = xet(o, h, l, c, atr, bbL, bbU, k, d)
        if r:
            ly[r] = ly.get(r, 0) + 1
        else:
            tin.append((t[k], "BUY" if d > 0 else "SELL"))
    ngay = pd.Series(t.normalize()).nunique()
    df = pd.DataFrame(tin, columns=["thoi_gian", "huong"])
    kc = df["thoi_gian"].diff().dt.total_seconds().div(3600).dropna()
    out = ["# Tần suất tín hiệu PP10 (SET M2) — nến M2 dựng từ M1, cận trên (chưa tính các chặn của Phoenix)", "",
           f"Dữ liệu: {t[0]} → {t[-1]}, {len(m2)} nến M2, {ngay} ngày có nến.", "",
           "| Bước lọc | Số nến M2 | % tổng |", "|---|---|---|"]
    for kq, v in phieu.items():
        out.append(f"| {kq} | {v} | {100.0 * v / phieu['tong_nen']:.1f}% |")
    out.append(f"| **tín hiệu PP10** | **{len(df)}** | {100.0 * len(df) / phieu['tong_nen']:.3f}% |")
    out += ["", "Nến đã qua ADX / ATR nhưng trượt ở bước setup:", "", "| Lý do | Số nến |", "|---|---|"]
    for r, v in sorted(ly.items(), key=lambda x: -x[1]):
        out.append(f"| {r} | {v} |")
    out += ["", f"- Tín hiệu: {len(df)} ({(df['huong'] == 'BUY').sum()} BUY, {(df['huong'] == 'SELL').sum()} SELL), "
                f"trung bình {len(df) / ngay:.2f} tín hiệu / ngày có nến.",
            f"- Khoảng cách giữa hai tín hiệu liên tiếp: trung vị {kc.median():.1f} giờ, 75% dưới {kc.quantile(0.75):.1f} giờ, "
            f"lớn nhất {kc.max():.0f} giờ." if len(kc) else "- Không đủ tín hiệu để đo khoảng cách."]
    if len(df):
        g = df.groupby(df["thoi_gian"].dt.hour).size().reindex(range(24), fill_value=0)
        out += ["", "Số tín hiệu theo giờ (giờ server):", "", "| Giờ | " + " | ".join(str(x) for x in range(24)) + " |",
                "|" + "---|" * 25, "| Số | " + " | ".join(str(v) for v in g.values) + " |"]
    md = "\n".join(out)
    print(md)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        with open(os.path.join(a.out, "tan_suat_pp10_XAUUSDm_2026.md"), "w", encoding="utf-8") as f:
            f.write(md + "\n")


if __name__ == "__main__":
    sys.exit(main())
