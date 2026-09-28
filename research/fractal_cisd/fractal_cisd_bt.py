#!/usr/bin/env python3
"""
Backtest tham chiếu (Python) cho chiến lược "HTF Candle-2 Sweep -> LTF CISD".
Logic phải khớp 1-1 với EA MQL5/Experts/FractalCISD_Research.mq5.

Nguyên tắc chống nhìn trước (look-ahead):
  * Nến HTF chỉ được dùng sau khi đã ĐÓNG (thời điểm đóng <= thời điểm quyết định).
  * Fractal (swing) HTF chỉ được coi là xác nhận sau khi đủ `pivot` nến bên phải đã đóng.
  * Tín hiệu LTF xét tại lúc nến LTF đóng; lệnh khớp tại giá mở của nến M1 kế tiếp
    (+ spread của chính nến M1 đó + slippage).
  * Thoát lệnh mô phỏng trên nến M1; nếu cùng một nến M1 chạm cả SL và TP thì tính SL
    (giả định bất lợi). Nến MT5 là giá BID; ASK = BID + spread.

Đầu vào: file xuất nến M1 từ MT5 (tab-separated, có cột <SPREAD> theo point),
có thể là .csv hoặc .zip chứa .csv.

Ví dụ:
  python3 fractal_cisd_bt.py --data XAUUSD_M1.csv --point 0.01 --contract 100 \
      --commission 7 --htf 60 --ltf 5 --gmt-offset 3
"""
import argparse
import io
import json
import sys
import zipfile
from dataclasses import dataclass, asdict, field

import numpy as np
import pandas as pd


# ----------------------------------------------------------------------------
# Dữ liệu
# ----------------------------------------------------------------------------
def load_mt5_m1(paths):
    frames = []
    for p in paths:
        if p.endswith(".zip"):
            with zipfile.ZipFile(p) as z:
                name = [n for n in z.namelist() if n.lower().endswith(".csv")][0]
                raw = z.read(name)
        else:
            with open(p, "rb") as f:
                raw = f.read()
        df = pd.read_csv(io.BytesIO(raw), sep="\t")
        df.columns = [c.strip("<>").lower() for c in df.columns]
        df["time"] = pd.to_datetime(df["date"] + " " + df["time"], format="%Y.%m.%d %H:%M:%S")
        frames.append(df[["time", "open", "high", "low", "close", "spread"]])
    df = pd.concat(frames).drop_duplicates("time").sort_values("time").reset_index(drop=True)
    return df


def resample(m1, minutes):
    """Gộp nến M1 thành khung `minutes` (nhãn = thời điểm mở, theo giờ server)."""
    if minutes == 1:
        out = m1.copy()
    else:
        g = m1.set_index("time").resample(f"{minutes}min", label="left", closed="left")
        out = g.agg({"open": "first", "high": "max", "low": "min", "close": "last",
                     "spread": "max"}).dropna().reset_index()
    out["end"] = out["time"] + pd.Timedelta(minutes=minutes)
    return out


def atr(df, n=14):
    h, l, c = df["high"].values, df["low"].values, df["close"].values
    pc = np.roll(c, 1)
    pc[0] = c[0]
    tr = np.maximum(h - l, np.maximum(abs(h - pc), abs(l - pc)))
    return pd.Series(tr).rolling(n, min_periods=n).mean().values


# ----------------------------------------------------------------------------
# Tham số
# ----------------------------------------------------------------------------
@dataclass
class Params:
    htf: int = 60            # phút, khung bối cảnh (Candle 1/2/3)
    ltf: int = 5             # phút, khung vào lệnh (CISD)
    liq_mode: int = 1        # 0 = đáy/đỉnh nến C1; 1 = fractal swing HTF chưa bị quét;
                             # 2 = ĐỐI CHỨNG: bỏ điều kiện quét HTF (mọi nến HTF đều là "C2")
    pivot: int = 2           # số nến mỗi bên của fractal HTF
    swing_lookback: int = 48 # số nến HTF tối đa tính từ swing tới C2
    valid_htf: int = 1       # số nến HTF (sau C2) cho phép tìm CISD
    exit_htf: int = 2        # đóng lệnh khi hết N nến HTF sau C2 nếu chưa chạm SL/TP
    require_fvg: bool = False # chân CISD phải để lại FVG cùng chiều
    min_rr: float = 1.5      # RR tối thiểu tới mục tiêu thanh khoản
    tp_mode: int = 1         # 0 = đỉnh/đáy của C2 (thanh khoản đối diện); 1 = RR cố định
    fixed_rr: float = 2.0
    sl_buf_atr: float = 0.10 # đệm SL theo ATR LTF
    min_sl_atr: float = 0.5
    max_sl_atr: float = 4.0
    use_session: bool = True
    gmt_offset: int = 0      # giờ server - UTC
    sessions_utc: tuple = ((7, 10), (12, 16))  # [bắt đầu, kết thúc) theo giờ UTC
    max_trades_day: int = 3
    max_spread_pts: float = 0   # 0 = không lọc tuyệt đối
    max_spread_sl: float = 0.20 # spread / khoảng SL tối đa
    # chi phí
    point: float = 0.01
    contract: float = 100.0
    commission_per_lot: float = 7.0  # USD round-turn / 1 lot
    slippage_pts: float = 0.0
    spread_mult: float = 1.0
    long_only: bool = False
    short_only: bool = False


@dataclass
class Trade:
    side: int
    signal_time: str
    entry_time: str
    entry: float
    sl: float
    tp: float
    exit_time: str = ""
    exit: float = 0.0
    reason: str = ""
    r: float = 0.0          # kết quả theo R (đã trừ spread, slippage, commission)
    risk_price: float = 0.0
    spread_pts: float = 0.0
    htf_c2: str = ""
    level: float = 0.0


def in_session(ts, p):
    if not p.use_session:
        return True
    h = (ts.hour - p.gmt_offset) % 24 + ts.minute / 60.0
    return any(a <= h < b for a, b in p.sessions_utc)


# ----------------------------------------------------------------------------
# Phát hiện bối cảnh HTF
# ----------------------------------------------------------------------------
def htf_setups(h, p):
    """Trả về danh sách setup: mỗi setup gắn với nến HTF C2 đã đóng.
    side=+1: C2 quét thanh khoản bên dưới rồi đóng lại phía trên mức bị quét (bullish C2 closure).
    side=-1: đối xứng."""
    H, L, C = h["high"].values, h["low"].values, h["close"].values
    n = len(h)
    setups = []
    k0 = max(p.pivot * 2 + 2, 2)
    for k in range(k0, n):
        for side in (1, -1):
            level = None
            if p.liq_mode == 2:
                level = L[k] if side == 1 else H[k]
            elif p.liq_mode == 0:
                lv = L[k - 1] if side == 1 else H[k - 1]
                if side == 1 and L[k] < lv < C[k]:
                    level = lv
                if side == -1 and H[k] > lv > C[k]:
                    level = lv
            else:
                # fractal đã xác nhận trước C2: pivot tại q, cần q+pivot <= k-1
                best = None
                for q in range(k - 1 - p.pivot, max(p.pivot, k - p.swing_lookback) - 1, -1):
                    if side == 1:
                        v = L[q]
                        if all(v < L[q - i] for i in range(1, p.pivot + 1)) and \
                           all(v < L[q + i] for i in range(1, p.pivot + 1)):
                            # chưa bị quét bởi các nến q+1..k-1
                            if L[q + 1:k].min() > v and L[k] < v < C[k]:
                                if best is None or v < best:
                                    best = v
                    else:
                        v = H[q]
                        if all(v > H[q - i] for i in range(1, p.pivot + 1)) and \
                           all(v > H[q + i] for i in range(1, p.pivot + 1)):
                            if H[q + 1:k].max() < v and H[k] > v > C[k]:
                                if best is None or v > best:
                                    best = v
                level = best
            if level is not None:
                setups.append(dict(k=k, side=side, level=level,
                                   c2_high=H[k], c2_low=L[k],
                                   c2_start=h["time"].iloc[k], c2_end=h["end"].iloc[k]))
    return setups


# ----------------------------------------------------------------------------
# Mô phỏng
# ----------------------------------------------------------------------------
def run(m1, p: Params, log_rejects=False):
    h = resample(m1, p.htf)
    l = resample(m1, p.ltf)
    la = atr(l, 14)
    LO, LH, LL, LC = l["open"].values, l["high"].values, l["low"].values, l["close"].values
    lt = l["time"].values
    lend = l["end"].values

    m1t = m1["time"].values
    mO, mH, mL = m1["open"].values, m1["high"].values, m1["low"].values
    mS = m1["spread"].values.astype(float) * p.spread_mult

    setups = htf_setups(h, p)
    htf_td = np.timedelta64(p.htf, "m")
    trades, rejects = [], {}
    busy_until = np.datetime64("1970-01-01")
    day_count = {}

    def rej(reason):
        rejects[reason] = rejects.get(reason, 0) + 1

    for s in setups:
        if (p.long_only and s["side"] == -1) or (p.short_only and s["side"] == 1):
            continue
        side = s["side"]
        w_start = np.datetime64(s["c2_end"])
        w_end = w_start + htf_td * p.valid_htf
        exit_deadline = w_start + htf_td * p.exit_htf
        j0 = np.searchsorted(lt, w_start)
        # Quét nến LTF trong cửa sổ C3. "Chuỗi ngược chiều" = các nến đóng cửa ngược hướng
        # setup liên tiếp nhau (nến giảm cho setup mua). Chuỗi tham chiếu = chuỗi gần nhất
        # kết thúc tại/ trước nến tạo cực trị của nhịp hồi (đáy thấp nhất tính từ đầu cửa sổ).
        # CISD = nến đóng cửa VƯỢT qua giá mở của chuỗi tham chiếu (nến trước chưa vượt).
        fired = False
        used_run = -1
        j = j0
        while j < len(l) and lend[j] <= w_end:
            o, hi, lo, c = LO[j], LH[j], LL[j], LC[j]
            # huỷ: nến LTF đóng vượt qua cực trị của C2 (mức quét thanh khoản thất bại)
            if (side == 1 and c < s["c2_low"]) or (side == -1 and c > s["c2_high"]):
                rej("huy_dong_qua_cuc_tri_C2")
                fired = True
                break
            ref = cisd_ref(LO, LH, LL, LC, j0, j, side)
            if ref is not None:
                ext, ext_idx, run_start, run_end, run_open = ref
                with_candle = (c > o) if side == 1 else (c < o)
                first_cross = all((LC[x] <= run_open) if side == 1 else (LC[x] >= run_open)
                                  for x in range(run_end + 1, j))
                crossed = (c > run_open) if side == 1 else (c < run_open)
                if with_candle and crossed and first_cross and j > run_end and run_start != used_run:
                    used_run = run_start
                    ok = True
                    if p.require_fvg:
                        has = False
                        for x in range(max(ext_idx + 2, j0 + 2), j + 1):
                            if side == 1 and LL[x] > LH[x - 2]:
                                has = True
                            if side == -1 and LH[x] < LL[x - 2]:
                                has = True
                        if not has:
                            rej("khong_co_FVG")
                            ok = False
                    if ok:
                        tr = try_enter(s, j, l, la, lend, ext, p, m1t, mO, mS,
                                       busy_until, day_count, rej)
                        if tr is not None:
                            simulate_exit(tr, m1t, mO, mH, mL, mS, exit_deadline, p)
                            trades.append(tr)
                            busy_until = np.datetime64(pd.Timestamp(tr.exit_time))
                            fired = True
                            break
            j += 1
        if not fired:
            rej("het_han_khong_CISD")
    return trades, rejects


def cisd_ref(O, H, L, C, j0, j, side):
    """Chuỗi tham chiếu cho CISD trong đoạn nến [j0..j].
    ext_idx  = nến có đáy thấp nhất (mua) / đỉnh cao nhất (bán) của đoạn.
    run      = chuỗi nến đóng cửa ngược hướng (giảm với mua) liên tiếp, kết thúc tại nến
               ngược hướng gần nhất có chỉ số <= ext_idx (chuỗi "đưa giá vào" cực trị).
    run_open = giá mở của nến đầu chuỗi. Trả về None nếu không có chuỗi."""
    seg = L[j0:j + 1] if side == 1 else H[j0:j + 1]
    ext_idx = j0 + (int(np.argmin(seg)) if side == 1 else int(np.argmax(seg)))
    a = ext_idx
    while a >= j0 and not ((C[a] < O[a]) if side == 1 else (C[a] > O[a])):
        a -= 1
    if a < j0:
        return None
    r = a
    while r - 1 >= j0 and ((C[r - 1] < O[r - 1]) if side == 1 else (C[r - 1] > O[r - 1])):
        r -= 1
    return (seg.min() if side == 1 else seg.max()), ext_idx, r, a, O[r]


def try_enter(s, j, l, la, lend, leg_extreme, p, m1t, mO, mS, busy_until, day_count, rej):
    side = s["side"]
    t_sig = lend[j]
    if t_sig < busy_until:
        rej("dang_co_lenh")
        return None
    ts = pd.Timestamp(t_sig)
    if not in_session(ts, p):
        rej("ngoai_phien")
        return None
    day = ts.date()
    if day_count.get(day, 0) >= p.max_trades_day:
        rej("du_so_lenh_ngay")
        return None
    a = la[j]
    if np.isnan(a):
        rej("chua_du_ATR")
        return None
    i = np.searchsorted(m1t, t_sig)
    if i >= len(m1t):
        return None
    spr = mS[i] * p.point
    slip = p.slippage_pts * p.point
    bid = mO[i]
    entry = (bid + spr + slip) if side == 1 else (bid - slip)
    buf = p.sl_buf_atr * a
    if side == 1:
        sl = leg_extreme - buf
        risk = entry - sl
    else:
        sl = leg_extreme + buf + spr  # SL lệnh bán khớp ở giá ASK
        risk = sl - entry
    if risk <= 0:
        rej("SL_khong_hop_le")
        return None
    if risk < p.min_sl_atr * a:
        rej("SL_qua_hep")
        return None
    if risk > p.max_sl_atr * a:
        rej("SL_qua_rong")
        return None
    if p.max_spread_pts > 0 and mS[i] > p.max_spread_pts:
        rej("spread_tuyet_doi")
        return None
    if spr / risk > p.max_spread_sl:
        rej("spread_so_voi_SL")
        return None
    if p.tp_mode == 0:
        tp = s["c2_high"] if side == 1 else s["c2_low"]
        rr = (tp - entry) / risk if side == 1 else (entry - tp) / risk
        if rr < p.min_rr:
            rej("RR_muc_tieu_thap")
            return None
    else:
        tp = entry + side * p.fixed_rr * risk
    day_count[day] = day_count.get(day, 0) + 1
    return Trade(side=side, signal_time=str(ts), entry_time=str(pd.Timestamp(m1t[i])),
                 entry=entry, sl=sl, tp=tp, risk_price=risk, spread_pts=mS[i],
                 htf_c2=str(s["c2_start"]), level=s["level"])


def simulate_exit(tr, m1t, mO, mH, mL, mS, deadline, p):
    i = np.searchsorted(m1t, np.datetime64(pd.Timestamp(tr.entry_time)))
    n = len(m1t)
    slip = p.slippage_pts * p.point
    k = i
    while k < n:
        spr = mS[k] * p.point
        if m1t[k] >= deadline:
            px = mO[k] - slip if tr.side == 1 else mO[k] + spr + slip
            tr.exit, tr.reason, tr.exit_time = px, "het_gio", str(pd.Timestamp(m1t[k]))
            break
        if tr.side == 1:
            hit_sl = mL[k] <= tr.sl
            hit_tp = mH[k] >= tr.tp
            if hit_sl:
                tr.exit, tr.reason = min(tr.sl, mO[k]) - slip, "SL"
            elif hit_tp:
                tr.exit, tr.reason = tr.tp, "TP"
        else:
            hit_sl = mH[k] + spr >= tr.sl
            hit_tp = mL[k] + spr <= tr.tp
            if hit_sl:
                tr.exit, tr.reason = max(tr.sl, mO[k] + spr) + slip, "SL"
            elif hit_tp:
                tr.exit, tr.reason = tr.tp, "TP"
        if hit_sl or hit_tp:
            tr.exit_time = str(pd.Timestamp(m1t[k]))
            break
        k += 1
    if not tr.reason:
        tr.exit, tr.reason, tr.exit_time = mO[n - 1], "het_du_lieu", str(pd.Timestamp(m1t[n - 1]))
    pnl_price = (tr.exit - tr.entry) * tr.side
    # commission quy về giá: commission_per_lot / contract (USD trên mỗi đơn vị giá của 1 lot)
    comm_price = p.commission_per_lot / p.contract
    tr.r = (pnl_price - comm_price) / tr.risk_price


# ----------------------------------------------------------------------------
# Thống kê
# ----------------------------------------------------------------------------
def stats(trades, risk_usd=100.0):
    if not trades:
        return dict(trades=0)
    r = np.array([t.r for t in trades])
    wins, losses = r[r > 0], r[r <= 0]
    eq = np.cumsum(r)
    peak = np.maximum.accumulate(np.concatenate([[0], eq]))[1:]
    dd = (peak - eq).max()
    streak = cur = 0
    for x in r:
        cur = cur + 1 if x <= 0 else 0
        streak = max(streak, cur)
    return dict(
        trades=len(r),
        net_R=round(r.sum(), 2),
        profit_usd_at_risk=round(r.sum() * risk_usd, 2),
        max_dd_R=round(dd, 2),
        win_rate=round(len(wins) / len(r) * 100, 1),
        profit_factor=round(wins.sum() / -losses.sum(), 2) if losses.sum() < 0 else float("inf"),
        expectancy_R=round(r.mean(), 3),
        avg_win_R=round(wins.mean(), 2) if len(wins) else 0,
        avg_loss_R=round(losses.mean(), 2) if len(losses) else 0,
        realized_RR=round(wins.mean() / -losses.mean(), 2) if len(wins) and len(losses) and losses.mean() < 0 else None,
        max_losing_streak=streak,
        exits={k: int(v) for k, v in pd.Series([t.reason for t in trades]).value_counts().items()},
    )


def split_trades(trades, cut):
    a = [t for t in trades if pd.Timestamp(t.entry_time) < cut]
    b = [t for t in trades if pd.Timestamp(t.entry_time) >= cut]
    return a, b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", nargs="+", required=True)
    ap.add_argument("--point", type=float, default=0.01)
    ap.add_argument("--contract", type=float, default=100.0)
    ap.add_argument("--commission", type=float, default=7.0)
    ap.add_argument("--slippage", type=float, default=0.0, help="point")
    ap.add_argument("--gmt-offset", type=int, default=0)
    ap.add_argument("--is-frac", type=float, default=0.6, help="tỷ lệ thời gian dùng để xây dựng")
    ap.add_argument("--out", default="results.json")
    ap.add_argument("--no-session", action="store_true")
    ap.add_argument("--trades-csv", default="")
    args = ap.parse_args()

    m1 = load_mt5_m1(args.data)
    t0, t1 = m1["time"].iloc[0], m1["time"].iloc[-1]
    cut = t0 + (t1 - t0) * args.is_frac
    print(f"Dữ liệu: {len(m1)} nến M1, {t0} -> {t1}; mốc tách IS/OOS: {cut}", file=sys.stderr)

    base = dict(point=args.point, contract=args.contract, commission_per_lot=args.commission,
                slippage_pts=args.slippage, gmt_offset=args.gmt_offset,
                use_session=not args.no_session)

    # 1) Phối hợp khung thời gian (cùng logic, mặc định đầy đủ bộ lọc)
    tf_pairs = [(15, 1), (60, 5), (240, 15)]
    # 2) Ablation: bật/tắt từng bộ lọc trên cặp mặc định H1->M5
    variants = {
        "mac_dinh(fractal,phien,2R)": {},
        "doi_chung_khong_HTF_sweep": dict(liq_mode=2),
        "liq=C1_thay_fractal": dict(liq_mode=0),
        "them_FVG": dict(require_fvg=True),
        "bo_loc_phien": dict(use_session=False),
        "TP=cuc_tri_C2(minRR1.5)": dict(tp_mode=0, min_rr=1.5),
        "cua_so_2_nen_HTF": dict(valid_htf=2, exit_htf=3),
    }
    out = {"data": [str(t0), str(t1)], "cut": str(cut), "tf_pairs": {}, "ablation_H1_M5": {},
           "spread_stress_H1_M5": {}}

    for htf, ltf in tf_pairs:
        p = Params(htf=htf, ltf=ltf, **base)
        tr, rj = run(m1, p)
        a, b = split_trades(tr, cut)
        out["tf_pairs"][f"{htf}->{ltf}"] = dict(IS=stats(a), OOS=stats(b), rejects=rj)
        print(f"TF {htf}->{ltf}: IS {stats(a).get('trades')} OOS {stats(b).get('trades')}", file=sys.stderr)
        if (htf, ltf) == (60, 5) and args.trades_csv:
            pd.DataFrame([asdict(t) for t in tr]).to_csv(args.trades_csv, index=False)

    for name, kw in variants.items():
        p = Params(htf=60, ltf=5, **{**base, **kw})
        tr, rj = run(m1, p)
        a, b = split_trades(tr, cut)
        out["ablation_H1_M5"][name] = dict(IS=stats(a), OOS=stats(b), rejects=rj)
        print(f"Ablation {name}: IS {stats(a).get('trades')}", file=sys.stderr)

    for mult in (1.0, 1.5, 2.0, 3.0):
        p = Params(htf=60, ltf=5, spread_mult=mult, **base)
        tr, _ = run(m1, p)
        a, b = split_trades(tr, cut)
        out["spread_stress_H1_M5"][f"x{mult}"] = dict(IS=stats(a), OOS=stats(b))

    with open(args.out, "w") as f:
        json.dump(out, f, indent=2, ensure_ascii=False, default=str)
    print(json.dumps(out, indent=1, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
