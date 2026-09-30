"""Bản sao Python của logic trạng thái trong PHOENIX_MI_V0_01.mqh (TEST 1), để xem trước trên nến lịch sử.

KHÔNG phải EA, KHÔNG phải backtest giao dịch. Chỉ chạy lại cùng các công thức nhận diện trên nến M5 dựng từ M1,
rồi ghi log cùng định dạng PMI_V001 để đọc bằng phan_tich_log_mi.py. Chỉ báo tính theo cách của MT5:
ATR = SMA(TR, 14); ADX theo EMA như iADX; Bollinger = SMA20 ± 2 × độ lệch chuẩn tổng thể; EMA50.
Kết quả có thể lệch EA một chút ở những nến mà chỉ báo lệch (ADX của MT5 khởi tạo khác).

Chạy:
  python3 ban_sao_python_mi.py --m1 <nen_M1.csv> --out <thư mục> [--tf 5] [--gia-lap-basket]
"""
import argparse
import os
import re
import sys

import numpy as np
import pandas as pd

MQH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "MQL5", "Experts", "PhoenixGrid", "PHOENIX_MI_V0_01.mqh")


def hang_so():
    src = open(MQH, encoding="utf-8-sig").read()
    d = {k: float(v) for k, v in re.findall(r"#define\s+(PMI_\w+)\s+([-\d.]+)", src)}
    td = re.search(r'#define PMI_TIEU_DE "([^"]+)"', src).group(1).split(";")
    return d, td


def chi_bao(df):
    h, l, c = df["high"].values, df["low"].values, df["close"].values
    n = len(df)
    pc = np.r_[c[0], c[:-1]]
    tr = np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))
    atr = pd.Series(tr).rolling(14).mean().values
    # ADX kiểu MT5 (iADX): +DM / −DM theo quy tắc chuẩn, làm trơn EMA(14), DX, ADX = EMA(DX)
    up = h - np.r_[h[0], h[:-1]]
    dn = np.r_[l[0], l[:-1]] - l
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    mdm = np.where((dn > up) & (dn > 0), dn, 0.0)
    a = 2.0 / 15.0
    pdi = np.zeros(n); mdi = np.zeros(n); adx = np.zeros(n)
    sp = sm = st = 0.0
    sadx = 0.0
    for i in range(1, n):
        trr = tr[i] if tr[i] > 0 else 1e-9
        p = 100.0 * pdm[i] / trr
        m = 100.0 * mdm[i] / trr
        sp = sp + a * (p - sp)
        sm = sm + a * (m - sm)
        pdi[i], mdi[i] = sp, sm
        s = sp + sm
        dx = 100.0 * abs(sp - sm) / s if s > 0 else 0.0
        sadx = sadx + a * (dx - sadx)
        adx[i] = sadx
    ema = pd.Series(c).ewm(span=50, adjust=False).mean().values
    ma = pd.Series(c).rolling(20).mean()
    sd = pd.Series(c).rolling(20).std(ddof=0)
    return atr, adx, pdi, mdi, ema, ma.values, (ma + 2 * sd).values, (ma - 2 * sd).values


def chay(m5, K, cfg, gia_lap=False):
    o, h, l, c = (m5[x].values for x in ("open", "high", "low", "close"))
    t = m5.index
    n = len(m5)
    atr, adx, dip, dim, ema, bbm, bbu, bbl = chi_bao(m5)
    nb = cfg["so_nen_range"]
    N = max(2 * nb, 100) + 6
    # fractal 2 nến mỗi bên (xác nhận khi có đủ 2 nến sau)
    dinh = np.zeros(n, bool); day = np.zeros(n, bool)
    for i in range(2, n - 2):
        dinh[i] = h[i] > h[i - 1] and h[i] > h[i - 2] and h[i] >= h[i + 1] and h[i] >= h[i + 2]
        day[i] = l[i] < l[i - 1] and l[i] < l[i - 2] and l[i] <= l[i + 1] and l[i] <= l[i + 2]
    S = {"tt": "NORMAL", "rU": 0.0, "rL": 0.0, "rW": 0.0, "swDem": 0, "saiDem": 0, "bo": 0, "boSoNen": 0, "ngoai": 0,
         "reclaim": 0, "boT": None, "than": False, "diem": 0, "bc": "", "pt": "IDLE", "ptT": None, "capT": None,
         "ptGia": 0.0, "cool": None, "baoCool": False, "tiep": 0, "giam": 0, "phuc": 0, "glap": 0}
    rows = []
    CLOSE_ATR, RECL = K["PMI_CLOSE_ATR"], K["PMI_RECLAIM_W"]

    def ngoai(k, d):
        return c[k] > S["rU"] + CLOSE_ATR * atr[k] if d > 0 else c[k] < S["rL"] - CLOSE_ATR * atr[k]

    def than_manh(k, d):
        R = h[k] - l[k]; B = (c[k] - o[k]) * d
        return R > 0 and B >= K["PMI_THAN_R"] * R and B >= K["PMI_THAN_ATR"] * atr[k]

    def ket_thuc():
        S.update(bo=0, boSoNen=0, ngoai=0, reclaim=0, than=False, boT=None, diem=0, bc="")

    def diem_bo(k, d, sws):
        dm = tong = 0; bc = []
        tong += 20
        if ngoai(k, d): dm += 20; bc.append("CLOSE_NGOAI")
        sw = S["rU"] if d > 0 else S["rL"]
        for (ts, p, loai) in sws:
            if S["boT"] is not None and ts < S["boT"] and loai == d:
                sw = max(sw, p) if d > 0 else min(sw, p)
        tong += 15
        if (d > 0 and c[k] > sw) or (d < 0 and c[k] < sw): dm += 15; bc.append("PHA_SWING")
        if cfg["bb"]:
            tong += 25
            bw, bw3 = bbu[k] - bbl[k], bbu[k - 3] - bbl[k - 3]
            if bw3 > 0 and bw >= K["PMI_BW_TANG"] * bw3: dm += 15; bc.append("BW_TANG")
            mo = bbu[k] > bbu[k - 1] and bbl[k] < bbl[k - 1]
            ng = 1 if c[k] > bbu[k] else (-1 if c[k] < bbl[k] else 0)
            if mo and ng == d: dm += 10; bc.append("BAND_MO")
        tong += 15
        mom = (c[k] - c[k - 3]) / atr[k]
        if mom * d >= K["PMI_MOM_ATR"] and ((dip[k] > dim[k]) if d > 0 else (dim[k] > dip[k])): dm += 15; bc.append("MOMENTUM")
        tong += 10
        if S["than"]: dm += 10; bc.append("THAN_MANH")
        tong += 15
        if S["ngoai"] >= cfg["so_nen_xn"]: dm += 15; bc.append("KHONG_RECLAIM")
        return int(round(dm * 100.0 / tong)), " ".join(bc)

    for k in range(N + 100, n):
        if not (atr[k] > 0):
            continue
        dau = k - nb + 1
        U, L = h[dau:k + 1].max(), l[dau:k + 1].min()
        W = U - L
        idx = [i for i in range(k - N + 1 + 2, k - 1) if dinh[i] or day[i]]
        sws = []
        tU = tL = 0
        for i in idx:
            if dinh[i]:
                sws.append((t[i], h[i], 1))
                if i >= dau and h[i] >= U - K["PMI_TAU"] * W: tU += 1
            if day[i]:
                sws.append((t[i], l[i], -1))
                if i >= dau and l[i] <= L + K["PMI_TAU"] * W: tL += 1
        ne = int(K["PMI_ER_NEN"])
        er_ms = np.abs(np.diff(c[k - ne:k + 1])).sum()
        er = abs(c[k] - c[k - ne]) / er_ms if er_ms > 0 else 0.0
        y = c[k - ne + 1:k + 1]
        beta = np.polyfit(np.arange(ne), y, 1)[0] / atr[k]
        wA = W / atr[k]
        sideway = (K["PMI_RANGE_MIN_ATR"] <= wA <= cfg["range_max_atr"] and adx[k] < cfg["range_adx_max"] and
                   er < K["PMI_ER_MAX"] and tU >= K["PMI_CHAM_MIN"] and tL >= K["PMI_CHAM_MIN"] and abs(beta) < K["PMI_DOC_MAX"])
        ev = []
        HT = int(K["PMI_H_TRANG_THAI"])
        tt = S["tt"]
        if tt == "NORMAL":
            S["swDem"] = S["swDem"] + 1 if sideway else 0
            if S["swDem"] >= HT:
                S.update(tt="SIDEWAY", rU=U, rL=L, rW=W, saiDem=0); ev.append("SIDEWAY_BAT_DAU")
        elif tt == "SIDEWAY":
            d = 1 if ngoai(k, 1) else (-1 if ngoai(k, -1) else 0)
            if d:
                S.update(tt="BO_NGHI", bo=d, boT=t[k], boSoNen=1, ngoai=1, than=than_manh(k, d)); ev.append("BO_NGHI_VAN")
            elif sideway:
                S.update(rU=U, rL=L, rW=W, saiDem=0)
            else:
                S["saiDem"] += 1
                if S["saiDem"] >= HT:
                    S.update(tt="NORMAL", swDem=0); ev.append("SIDEWAY_KET_THUC")
        elif tt == "BO_NGHI":
            d = S["bo"]
            S["boSoNen"] += 1
            S["ngoai"] = S["ngoai"] + 1 if ngoai(k, d) else 0
            if ngoai(k, d) and than_manh(k, d): S["than"] = True
            recl = c[k] <= S["rU"] - RECL * S["rW"] if d > 0 else c[k] >= S["rL"] + RECL * S["rW"]
            if recl:
                S.update(tt="SIDEWAY", saiDem=0); ev.append("BO_THAT_BAI"); ket_thuc()
            else:
                S["diem"], S["bc"] = diem_bo(k, d, sws)
                if S["diem"] >= cfg["diem_xn"] and S["ngoai"] >= cfg["so_nen_xn"]:
                    S.update(tt="BO_XN", tiep=0); ev.append("BO_XAC_NHAN")
                elif S["boSoNen"] >= K["PMI_HET_HAN_NGHI"]:
                    trong = S["rL"] <= c[k] <= S["rU"]
                    S["tt"] = "SIDEWAY" if trong else "NORMAL"
                    ev.append("BO_HET_HAN_VE_RANGE" if trong else "BO_HET_HAN"); ket_thuc()
                    if not trong: S["swDem"] = 0
        elif tt == "BO_XN":
            d = S["bo"]
            S["boSoNen"] += 1
            S["ngoai"] = S["ngoai"] + 1 if ngoai(k, d) else 0
            S["diem"], S["bc"] = diem_bo(k, d, sws)
            recl = c[k] <= S["rU"] - RECL * S["rW"] if d > 0 else c[k] >= S["rL"] + RECL * S["rW"]
            if recl:
                S.update(tt="RECLAIM", reclaim=1); ev.append("RECLAIM_BAT_DAU")
            elif sideway and t[dau] >= S["boT"]:
                S.update(tt="SIDEWAY", rU=U, rL=L, rW=W, saiDem=0); ev.append("VUNG_MOI"); ket_thuc()
            elif S["boSoNen"] >= K["PMI_THEO_DOI_MAX"]:
                S.update(tt="NORMAL", swDem=0); ev.append("BO_HET_THEO_DOI"); ket_thuc()
        elif tt == "RECLAIM":
            d = S["bo"]
            S["boSoNen"] += 1
            if ngoai(k, d):
                S.update(tt="BO_XN", ngoai=1); ev.append("RECLAIM_THAT_BAI")
                S["diem"], S["bc"] = diem_bo(k, d, sws)
            elif ngoai(k, -d):
                ev.append("RECLAIM_XAC_NHAN"); ket_thuc()
                S.update(tt="BO_NGHI", bo=-d, boT=t[k], boSoNen=1, ngoai=1, than=than_manh(k, -d)); ev.append("BO_NGHI_VAN")
            else:
                if S["rL"] <= c[k] <= S["rU"]: S["reclaim"] += 1
                if S["reclaim"] >= cfg["so_nen_xn"] + 1:
                    S.update(tt="SIDEWAY", saiDem=0); ev.append("RECLAIM_XAC_NHAN"); ket_thuc()
                elif S["boSoNen"] >= K["PMI_THEO_DOI_MAX"]:
                    S.update(tt="NORMAL", swDem=0); ev.append("BO_HET_THEO_DOI"); ket_thuc()
        # phòng thủ với basket giả lập (ngược mỗi breakout xác nhận), như InpGiaLapBasket của EA
        bk = 0
        if gia_lap:
            if S["pt"] == "IDLE":
                S["glap"] = -S["bo"] if S["tt"] == "BO_XN" else 0
            bk = S["glap"]
        nguoc = bk != 0 and S["bo"] == -bk
        giu = cfg["giu_phut"] * 60
        pt = S["pt"]
        if pt == "IDLE":
            if S["tt"] == "BO_XN" and nguoc:
                if S["cool"] is not None and t[k] < S["cool"]:
                    if not S["baoCool"]:
                        ev.append("DEF_CHAN_COOLDOWN"); S["baoCool"] = True
                else:
                    S.update(pt="DEF1", ptT=t[k], capT=t[k], ptGia=c[k], giam=0); ev.append("DEF_BAT_DAU")
        elif pt in ("DEF1", "DEF2"):
            if bk == 0:
                S["pt"] = "IDLE"; ev.append("DEF_HUY")
            elif S["tt"] in ("SIDEWAY", "NORMAL") or (S["bo"] != 0 and S["bo"] == bk):
                if (t[k] - S["ptT"]).total_seconds() >= giu:
                    S.update(pt="PHUC_HOI", phuc=0); ev.append("DEF_PHUC_HOI")
            else:
                xa = abs(c[k] - S["ptGia"]) >= K["PMI_KHOANG_ATR"] * atr[k]
                du = (t[k] - S["capT"]).total_seconds() >= giu
                if pt == "DEF1":
                    bien = S["rU"] if S["bo"] > 0 else S["rL"]
                    tiep = (S["tt"] == "BO_XN" and (c[k] - bien) * S["bo"] >= max(K["PMI_TIEP_W"] * S["rW"], K["PMI_TIEP_ATR"] * atr[k])
                            and S["diem"] >= cfg["diem_xn"])
                    S["tiep"] = S["tiep"] + 1 if tiep else 0
                    if S["tiep"] >= cfg["so_nen_xn"] and du and xa:
                        S.update(pt="DEF2", capT=t[k], ptGia=c[k], giam=0); ev.append("DEF_CAP_2")
        elif pt == "PHUC_HOI":
            if S["tt"] == "BO_XN" and nguoc:
                S.update(pt="DEF1", ptT=t[k], capT=t[k], ptGia=c[k]); ev.append("DEF_TAI_KICH_HOAT")
            else:
                S["phuc"] += 1
                if bk == 0 or S["phuc"] >= cfg["so_nen_xn"]:
                    S.update(pt="IDLE", cool=t[k] + pd.Timedelta(minutes=cfg["cooldown_phut"]), baoCool=False)
                    ev.append("DEF_KET_THUC")
        ten_tt = {"NORMAL": "NORMAL", "SIDEWAY": "SIDEWAY", "BO_NGHI": "BREAKOUT_SUSPECTED", "BO_XN": "BREAKOUT_CONFIRMED",
                  "RECLAIM": "RECLAIM"}[S["tt"]]
        co_range = S["tt"] != "NORMAL"
        rows.append({"thoi_gian": t[k].strftime("%Y.%m.%d %H:%M"), "su_kien": "+".join(ev) if ev else "NEN",
                     "market_state": ten_tt, "range_high": f"{S['rU']:.3f}" if co_range else "",
                     "range_low": f"{S['rL']:.3f}" if co_range else "", "range_w_atr": f"{S['rW'] / atr[k]:.2f}" if co_range else "",
                     "breakout_direction": "TANG" if S["bo"] > 0 else ("GIAM" if S["bo"] < 0 else ""),
                     "breakout_score": str(S["diem"]), "bang_chung": S["bc"], "so_nen_ngoai": str(S["ngoai"]),
                     "so_nen_tu_breakout": str(S["boSoNen"]), "close": f"{c[k]:.3f}", "atr": f"{atr[k]:.3f}",
                     "adx": f"{adx[k]:.2f}", "defense_state": {"IDLE": "IDLE", "DEF1": "DEFENSE_1", "DEF2": "DEFENSE_2",
                                                                "PHUC_HOI": "RECOVERY"}[S["pt"]],
                     "basket_direction": "BUY" if bk > 0 else ("SELL" if bk < 0 else "")})
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tf", type=int, default=5, help="khung phút (mặc định 5)")
    ap.add_argument("--gia-lap-basket", action="store_true")
    ap.add_argument("--diem", type=int, default=60)
    ap.add_argument("--so-nen", type=int, default=2)
    a = ap.parse_args()
    K, td = hang_so()
    m1 = pd.read_csv(a.m1, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m1 = m1.set_index("time").sort_index()
    m5 = m1.resample(f"{a.tf}min", label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}).dropna()
    cfg = {"so_nen_range": 48, "range_max_atr": 6.0, "range_adx_max": 22.0, "diem_xn": a.diem, "so_nen_xn": a.so_nen,
           "bb": True, "giu_phut": 30, "cooldown_phut": 60}
    rows = chay(m5, K, cfg, a.gia_lap_basket)
    os.makedirs(a.out, exist_ok=True)
    df = pd.DataFrame(rows)
    for col in td:
        if col not in df.columns:
            df[col] = ""
    df = df[td]
    df["ngay"] = df["thoi_gian"].str[:10].str.replace(".", "", regex=False)
    for ngay, g in df.groupby("ngay"):
        g.drop(columns="ngay").to_csv(os.path.join(a.out, f"PMI_V001_XAUUSDm_d{a.diem}n{a.so_nen}_tester_{ngay}.csv"),
                                      sep=";", index=False)
    print(f"{len(m5)} nến M{a.tf}, ghi {len(rows)} dòng vào {a.out}")


if __name__ == "__main__":
    sys.exit(main())
