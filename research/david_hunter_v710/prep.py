"""David Hunter V710 – chuẩn bị dữ liệu cho bộ giả lập C++ (dh710sim).

Đầu vào:
  - nến M1 XAUUSDm Exness 01/01 → 27/09/2026 (EA-PRO/data/backtest_mt5/.../nen_M1.csv, giờ server GMT+0);
  - tick thật XAUUSDm 01/01 → 12/01/2026 (EA-PRO/data/tick/...zip.part001) để đối chiếu tick dựng.

Đầu ra (thư mục `du_lieu/`, không commit vì nặng – chạy lại script để tạo):
  - bars_m1.bin : mỗi nến M1 [t_sec, open, high, low, close, spread_pts, atr_m1, atr_m15, trend_neu]
  - bars_m5.bin : nến M5 [t_sec, open, high, low, close] (dùng khi giả định chart M5 cho trailing)
  - ticks_syn.bin : tick dựng từ nến M1 [t_ms, bid, ask]
  - ticks_real.bin : tick thật [t_ms, bid, ask]

Quy ước "không nhìn trước": atr_m1/atr_m15/trend_neu của nến M1 thứ k chỉ dùng các nến đã ĐÓNG trước nến k
(EA gốc dùng cả nến đang chạy – xem README phần sai khác).
"""
import os
import sys

import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
EA_PRO = os.environ.get("EA_PRO", os.path.join(HERE, "..", "..", "..", "ea-pro"))
M1_CSV = os.path.join(EA_PRO, "data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")
TICK_ZIP = os.path.join(EA_PRO, "data/tick/XAUUSDm_2026-01-01_2026-04-30/XAUUSDm_*.zip.part*")
OUT = os.path.join(HERE, "du_lieu")
POINT = 0.001

sys.path.insert(0, os.path.join(HERE, "..", "phoenix_grid"))


# ----------------------------------------------------------------------------- chỉ báo kiểu MT5
def ema(x, n):
    a = 2.0 / (n + 1.0)
    out = np.empty_like(x)
    out[0] = x[0]
    for i in range(1, len(x)):
        out[i] = out[i - 1] + a * (x[i] - out[i - 1])
    return out


def sma(x, n):
    s = pd.Series(x).rolling(n, min_periods=1).mean().to_numpy()
    return s


def true_range(h, l, c):
    pc = np.r_[c[0], c[:-1]]
    return np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))


def atr_mt5(h, l, c, n=14):
    return sma(true_range(h, l, c), n)


def adx_di(h, l, c, n=14):
    """+DI/-DI giống ADX.mq5 của MT5: DI từng nến rồi làm mượt EMA(n)."""
    ph = np.r_[h[0], h[:-1]]
    pl = np.r_[l[0], l[:-1]]
    up = h - ph
    dn = pl - l
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    ndm = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr = true_range(h, l, c)
    with np.errstate(divide="ignore", invalid="ignore"):
        psdi = np.where(tr > 0, 100.0 * pdm / tr, 0.0)
        nsdi = np.where(tr > 0, 100.0 * ndm / tr, 0.0)
    return ema(psdi, n), ema(nsdi, n)


def clip_scale(x, pos, neg):
    x = np.asarray(x, dtype=float)
    return np.where(x < -1.0, neg, np.minimum(x, 1.0) * pos)


def score_tf(o, h, l, c, r12):
    """ScoreOneTF của V710 cho từng nến (nến i đóng vai rates[0]); vector hoá."""
    n = len(c)
    trv = true_range(h, l, c)
    # ATR14PrevClose: trung bình TR của 14 nến gần nhất (rates[0..13]) – chính là SMA14 của TR
    atr = sma(trv, 14)
    winA = 20 if r12 == 0 else (18 if r12 == 1 else 14)
    winB = 30 if r12 == 0 else (24 if r12 == 1 else 20)
    # hồi quy tuyến tính close theo thời gian trên winA nến
    cs = pd.Series(c)
    x = np.arange(winA, dtype=float)
    sx, sxx = x.sum(), (x * x).sum()
    sy = cs.rolling(winA).sum().to_numpy()
    syy = (cs * cs).rolling(winA).sum().to_numpy()
    # sxy = sum_{i} i*y_{t-winA+1+i}
    w = np.arange(winA, dtype=float)
    sxy = np.convolve(c, w[::-1], mode="full")[: n]
    sxy[: winA - 1] = np.nan
    nw = float(winA)
    den = nw * sxx - sx * sx
    num = nw * sxy - sx * sy
    yden = nw * syy - sy * sy
    with np.errstate(divide="ignore", invalid="ignore"):
        r2 = np.where((yden > 0), (num * num) / (den * yden), 0.0)
    r2 = np.clip(np.nan_to_num(r2), 0.0, 1.0)
    slope = np.nan_to_num(num / den)
    with np.errstate(divide="ignore", invalid="ignore"):
        slope_n = np.where(atr > 0, slope / atr, 0.0)
    sl_c = np.clip(slope_n / 0.06, -1, 1)
    sc = (r2 * 0.5 + 0.5) * sl_c

    m8, m21, m55 = ema(c, 8), ema(c, 21), ema(c, 55)
    e = np.where((m8 > m21) & (m21 > m55), 0.55,
                 np.where((m21 > m8) & (m55 > m21), -0.55, clip_scale((m8 - m55) / atr, 0.55, -0.55)))
    back = 3 if r12 == 0 else 2

    def lagd(v):
        return (v - np.r_[np.full(back, v[0]), v[:-back]]) / atr

    mom = lagd(m8) * 0.5 + lagd(m21) * 0.35 + lagd(m55) * 0.15
    e = (e + clip_scale(mom, 0.45, -0.45)) * 0.18

    macd_m = ema(c, 12) - ema(c, 26)
    macd_s = sma(macd_m, 9)
    macd = clip_scale((macd_m - macd_s) / atr / 0.3, 0.12, -0.12)

    pdi, mdi = adx_di(h, l, c, 14)
    adx = clip_scale((pdi - mdi) / 40.0, 0.06, -0.06)

    netp = c - np.r_[np.full(winB, c[0]), c[:-winB]]
    path = pd.Series(np.abs(np.diff(c, prepend=c[0]))).rolling(winB).sum().to_numpy()
    with np.errstate(divide="ignore", invalid="ignore"):
        pe = np.where(path > 0, np.minimum(np.abs(netp) / path, 1.0), 0.0)
    pe = np.nan_to_num(pe)
    spe = np.sign(netp) * pe

    dc = 24 if r12 == 0 else 20
    hh = pd.Series(h).shift(1).rolling(dc).max().to_numpy()
    ll = pd.Series(l).shift(1).rolling(dc).min().to_numpy()
    up = np.maximum((c - hh) / atr, 0.0)
    dn = np.maximum((ll - c) / atr, 0.0)
    donch = clip_scale(np.nan_to_num(up - dn), 0.1, -0.1)

    s = spe * 0.2 + sc * 0.34 + e + macd + adx + donch
    absn = np.minimum(np.abs(slope_n) / 0.06, 1.0)
    gate = np.minimum(absn * 0.3 + r2 * 0.3 + pe * 0.4, 1.0)
    s = np.clip(s, -1, 1)
    score = np.clip(s * 100.0 * gate, -100, 100)
    score[: 70] = 0.0
    return np.nan_to_num(score)


def resample(df, rule):
    g = df.set_index("time").resample(rule, label="left", closed="left")
    r = pd.DataFrame({"open": g["open"].first(), "high": g["high"].max(), "low": g["low"].min(),
                      "close": g["close"].last()}).dropna()
    return r.reset_index()


def map_closed(t_m1, t_tf, values, tf_sec):
    """Giá trị của nến khung lớn ĐÃ ĐÓNG gần nhất tại thời điểm mở nến M1."""
    close_time = t_tf + tf_sec
    idx = np.searchsorted(close_time, t_m1, side="right") - 1
    out = np.where(idx >= 0, values[np.clip(idx, 0, None)], 0.0)
    return out


def trend_neu(m1):
    t = m1["time"].values.astype("datetime64[s]").astype(np.int64)
    k = [0.3, 0.36, 0.34]
    lv = []
    for r12, (rule, sec) in enumerate([("1min", 60), ("5min", 300), ("15min", 900)]):
        b = m1 if r12 == 0 else resample(m1, rule)
        sc = score_tf(b["open"].to_numpy(), b["high"].to_numpy(), b["low"].to_numpy(), b["close"].to_numpy(), r12)
        tb = b["time"].values.astype("datetime64[s]").astype(np.int64)
        lv.append(map_closed(t, tb, sc, sec))
    lv = np.vstack(lv)
    kk = np.array(k)[:, None]
    neu = np.clip((lv * kk).sum(0) / kk.sum(), -100, 100)
    # phạt bất đồng: tổng trọng số các khung ngược dấu |lv|>=15 chia tổng >= 0.4 -> *0.72
    sgn_neu = np.where(neu > 0, 1, np.where(neu < 0, -1, 0))
    agree = np.where(neu[None, :] > 0, lv > 0, np.sign(lv) == np.where(sgn_neu < 0, -1, 0)[None, :])
    wpen = ((~agree) & (np.abs(lv) >= 15.0)) * kk
    neu = np.where(wpen.sum(0) / kk.sum() >= 0.4, neu * 0.72, neu)
    return np.clip(neu, -100, 100)


# ----------------------------------------------------------------------------- tick dựng từ nến M1
def synth_ticks(m1, step=0.05):
    """Đường giá trong nến theo MT5 (nến tăng O→L→H→C, nến giảm O→H→L→C), mỗi bước `step` giá, dàn đều 60 giây."""
    t0 = m1["time"].values.astype("datetime64[ms]").astype(np.int64)
    o, h, l, c = (m1[x].to_numpy() for x in ("open", "high", "low", "close"))
    spr = m1["spread_points"].to_numpy() * POINT
    ts, bs, as_ = [], [], []
    for i in range(len(m1)):
        if c[i] >= o[i]:
            pts = [o[i], l[i], h[i], c[i]]
        else:
            pts = [o[i], h[i], l[i], c[i]]
        seg = [np.array([pts[0]])]
        for a, b in zip(pts[:-1], pts[1:]):
            n = max(1, int(np.ceil(abs(b - a) / step)))
            seg.append(a + (b - a) * np.arange(1, n + 1) / n)
        p = np.concatenate(seg)
        p = np.round(p, 3)
        keep = np.r_[True, np.diff(p) != 0]
        keep[-1] = True
        p = p[keep]
        m = len(p)
        tt = t0[i] + (np.arange(m) * 59000) // max(m - 1, 1)
        ts.append(tt)
        bs.append(p)
        as_.append(np.round(p + spr[i], 3))
    return np.concatenate(ts), np.concatenate(bs), np.concatenate(as_)


def write_ticks(path, t_ms, bid, ask):
    arr = np.empty(len(t_ms), dtype=[("t", "<i8"), ("b", "<f8"), ("a", "<f8")])
    arr["t"], arr["b"], arr["a"] = t_ms, bid, ask
    arr.tofile(path)
    return len(arr)


def main():
    os.makedirs(OUT, exist_ok=True)
    m1 = pd.read_csv(M1_CSV, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m1 = m1.sort_values("time").drop_duplicates("time").reset_index(drop=True)
    t = m1["time"].values.astype("datetime64[s]").astype(np.int64)
    o, h, l, c = (m1[x].to_numpy() for x in ("open", "high", "low", "close"))

    # ATR M1 (đã đóng) tại nến k = ATR tính đến nến k-1
    atr1 = atr_mt5(h, l, c, 14)
    atr1 = np.r_[atr1[0], atr1[:-1]]
    m15 = resample(m1, "15min")
    a15 = atr_mt5(m15["high"].to_numpy(), m15["low"].to_numpy(), m15["close"].to_numpy(), 14)
    t15 = m15["time"].values.astype("datetime64[s]").astype(np.int64)
    atr15 = map_closed(t, t15, a15, 900)
    neu = trend_neu(m1)

    bars = np.column_stack([t.astype(float), o, h, l, c, m1["spread_points"].to_numpy(float), atr1, atr15, neu])
    bars.astype("<f8").tofile(os.path.join(OUT, "bars_m1.bin"))
    m5 = resample(m1, "5min")
    t5 = m5["time"].values.astype("datetime64[s]").astype(np.int64)
    np.column_stack([t5.astype(float), m5["open"], m5["high"], m5["low"], m5["close"]]).astype("<f8").tofile(
        os.path.join(OUT, "bars_m5.bin"))
    print("nến M1:", len(m1), m1["time"].iloc[0], "->", m1["time"].iloc[-1])
    print("trend |neu|>20: %.1f%%" % (100 * (np.abs(neu) > 20).mean()))

    ts, bs, as_ = synth_ticks(m1)
    n = write_ticks(os.path.join(OUT, "ticks_syn.bin"), ts, bs, as_)
    print("tick dựng:", n)

    try:
        from pg_data import read_tick_zip, clean_ticks
        df, info = read_tick_zip(TICK_ZIP)
        tm, b, a, cnt = clean_ticks(df)
        n = write_ticks(os.path.join(OUT, "ticks_real.bin"), tm, b, a)
        print("tick thật:", n, pd.to_datetime(tm[0], unit="ms"), "->", pd.to_datetime(tm[-1], unit="ms"))
    except Exception as e:  # thiếu file tick thì vẫn chạy được bằng tick dựng
        print("không đọc được tick thật:", e)


if __name__ == "__main__":
    main()


def synth_ticks_bridge(m1, seed=7, max_ticks=400, amp=0.45):
    """Tick dựng có nhiễu: O→L→H→C (nến tăng) hoặc O→H→L→C, mốc đỉnh/đáy ở thời điểm ngẫu nhiên, giữa các mốc là
    cầu Brown (Brownian bridge) bị kẹp trong [Low, High]; số tick mỗi nến = tick_volume (tối đa max_ticks)."""
    r = np.random.default_rng(seed)
    t0 = m1["time"].values.astype("datetime64[ms]").astype(np.int64)
    o, h, l, c = (m1[x].to_numpy() for x in ("open", "high", "low", "close"))
    vol = np.clip(m1["tick_volume"].to_numpy(), 4, max_ticks)
    spr = m1["spread_points"].to_numpy() * POINT
    ts, bs, as_ = [], [], []
    for i in range(len(m1)):
        n = int(vol[i])
        a, b = sorted(r.uniform(0.05, 0.95, 2))
        if c[i] >= o[i]:
            kp = [(0.0, o[i]), (a, l[i]), (b, h[i]), (1.0, c[i])]
        else:
            kp = [(0.0, o[i]), (a, h[i]), (b, l[i]), (1.0, c[i])]
        u = np.sort(r.uniform(0, 1, n - 2))
        u = np.r_[0.0, u, 1.0]
        # cầu Brown: W(u) - u*W(1) trên từng đoạn, biên độ theo độ rộng nến
        p = np.empty(n)
        rng_bar = max(h[i] - l[i], 0.01)
        for (ta, pa), (tb, pb) in zip(kp[:-1], kp[1:]):
            sel = (u >= ta) & (u <= tb)
            if not sel.any():
                continue
            uu = (u[sel] - ta) / max(tb - ta, 1e-9)
            w = np.cumsum(r.normal(0, 1, sel.sum()))
            w = w - uu * w[-1]
            w = w / max(np.sqrt(sel.sum()), 1.0) * rng_bar * amp * np.sqrt(tb - ta)
            p[sel] = pa + (pb - pa) * uu + w
        # đảm bảo chạm đúng mốc và nằm trong biên
        for tk, pk in kp:
            p[np.argmin(np.abs(u - tk))] = pk
        p = np.clip(p, l[i], h[i])
        p = np.round(p, 3)
        tt = t0[i] + (u * 59000).astype(np.int64)
        ts.append(tt); bs.append(p); as_.append(np.round(p + spr[i], 3))
    return np.concatenate(ts), np.concatenate(bs), np.concatenate(as_)


def main_bridge(to=None, amp=0.45, name=None):
    m1 = pd.read_csv(M1_CSV, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m1 = m1.sort_values("time").drop_duplicates("time").reset_index(drop=True)
    if to:
        m1 = m1[m1["time"] < to]
    ts, bs, as_ = synth_ticks_bridge(m1, amp=amp)
    name = name or ("ticks_bridge.bin" if not to else "ticks_bridge_test.bin")
    print("tick cầu Brown:", write_ticks(os.path.join(OUT, name), ts, bs, as_))


def main_bridge_seed(seed):
    m1 = pd.read_csv(M1_CSV, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m1 = m1.sort_values("time").drop_duplicates("time").reset_index(drop=True)
    ts, bs, as_ = synth_ticks_bridge(m1, seed=seed)
    print("tick cầu Brown seed", seed, write_ticks(os.path.join(OUT, "ticks_bridge_s%d.bin" % seed), ts, bs, as_))
