"""Families 4-9 (PVEMA, ENG, PIN, BRK, LQ, PVT) exactly as ProcessAdditionalSignals()/EnterPVSignal().

The engine wakes on the first tick of every new bar of the family timeframe, evaluates the
pattern on closed bars (shift 1 = last closed bar), and enters immediately at that tick
(Ask for BUY, Bid for SELL). SL = extreme of the last InpPVSoNenTimSL closed bars of the
signal timeframe +/- InpPVDemSLGia, widened to the 5.0 minimum, rejected above 20.0.
TP2 = entry +/- InpPVTP2R x risk.
"""
import numpy as np
from numba import njit

from .mt5ind import IndCache


@njit(cache=True)
def _dir_eng(o, h, l, c, atr, tick, mn, mx, ratio, strong):
    n = len(c)
    d = np.zeros(n, np.int8)
    for b in range(3, n):
        r1, r2 = b - 1, b - 2
        a = atr[r1]
        if a <= 0.0:
            continue
        rng = h[r1] - l[r1]
        body = abs(c[r1] - o[r1])
        pbody = abs(c[r2] - o[r2])
        if rng <= tick or rng / a < mn or rng / a > mx or body + tick * 0.1 < pbody * ratio:
            continue
        bull = (c[r2] < o[r2] and c[r1] > o[r1] and o[r1] <= c[r2] and c[r1] >= o[r2]
                and (c[r1] - l[r1]) / rng >= strong)
        bear = (c[r2] > o[r2] and c[r1] < o[r1] and o[r1] >= c[r2] and c[r1] <= o[r2]
                and (h[r1] - c[r1]) / rng >= strong)
        if bull != bear:
            d[b] = 1 if bull else -1
    return d


@njit(cache=True)
def _dir_pin(o, h, l, c, atr, tick, mn, mx, main_w, opp_w, close_pos, sweep_n):
    n = len(c)
    d = np.zeros(n, np.int8)
    need = sweep_n + 2
    for b in range(need - 1, n):
        r1 = b - 1
        a = atr[r1]
        if a <= 0.0:
            continue
        rng = h[r1] - l[r1]
        body = max(tick, abs(c[r1] - o[r1]))
        if rng <= tick or rng / a < mn or rng / a > mx:
            continue
        upper = h[r1] - max(o[r1], c[r1])
        lower = min(o[r1], c[r1]) - l[r1]
        ph = h[b - 2]
        pl = l[b - 2]
        for s in range(3, need):
            ph = max(ph, h[b - s])
            pl = min(pl, l[b - s])
        bull = (lower / body >= main_w and upper / body <= opp_w and (c[r1] - l[r1]) / rng >= close_pos
                and l[r1] < pl)
        bear = (upper / body >= main_w and lower / body <= opp_w and (h[r1] - c[r1]) / rng >= close_pos
                and h[r1] > ph)
        if bull != bear:
            d[b] = 1 if bull else -1
    return d


@njit(cache=True)
def _dir_brk(o, h, l, c, tick, nzone, min_body, buf, retest, tol):
    n = len(c)
    d = np.zeros(n, np.int8)
    need = nzone + 5
    bs = 2 if retest else 1
    fl = bs + 1
    for b in range(need - 1, n):
        hi = h[b - fl]
        lo = l[b - fl]
        for s in range(fl + 1, fl + nzone):
            hi = max(hi, h[b - s])
            lo = min(lo, l[b - s])
        k = b - bs
        rng = h[k] - l[k]
        body = abs(c[k] - o[k])
        if rng <= tick or body / rng < min_body:
            continue
        up = c[k] > hi + buf
        dn = c[k] < lo - buf
        if not retest:
            if up != dn:
                d[b] = 1 if up else -1
            continue
        r1 = b - 1
        buy = up and l[r1] <= hi + tol and c[r1] > hi and c[r1] > o[r1]
        sell = dn and h[r1] >= lo - tol and c[r1] < lo and c[r1] < o[r1]
        if buy != sell:
            d[b] = 1 if buy else -1
    return d


@njit(cache=True)
def _dir_lq(o, h, l, c, tick, nliq, pmin, pmax, close_in, wick_ratio):
    n = len(c)
    d = np.zeros(n, np.int8)
    need = nliq + 2
    lo_pen = min(pmin, pmax)
    hi_pen = max(pmin, pmax)
    for b in range(need - 1, n):
        r1 = b - 1
        ph = h[b - 2]
        pl = l[b - 2]
        for s in range(3, need):
            ph = max(ph, h[b - s])
            pl = min(pl, l[b - s])
        body = max(tick, abs(c[r1] - o[r1]))
        lw = min(o[r1], c[r1]) - l[r1]
        uw = h[r1] - max(o[r1], c[r1])
        dp = pl - l[r1]
        up = h[r1] - ph
        buy = dp >= lo_pen and dp <= hi_pen and c[r1] >= pl + close_in and lw / body >= wick_ratio
        sell = up >= lo_pen and up <= hi_pen and c[r1] <= ph - close_in and uw / body >= wick_ratio
        if buy != sell:
            d[b] = 1 if buy else -1
    return d


@njit(cache=True)
def _dir_pvt(o, h, l, c, src_cur, sh, sl_, sc, radius, need_dir, levels):
    """src_cur[b] = index of the source-TF bar forming at the first tick of confirm bar b."""
    n = len(c)
    d = np.zeros(n, np.int8)
    for b in range(2, n):
        sb = src_cur[b]
        if sb < 2:
            continue
        s1 = sb - 1
        pp = (sh[s1] + sl_[s1] + sc[s1]) / 3.0
        rng = sh[s1] - sl_[s1]
        r1 = 2.0 * pp - sl_[s1]
        s1v = 2.0 * pp - sh[s1]
        r2 = pp + rng
        s2 = pp - rng
        k = b - 1
        bull = c[k] > o[k]
        bear = c[k] < o[k]
        bt = l[k] <= s2 + radius and h[k] >= s2 - radius
        st = l[k] <= r2 + radius and h[k] >= r2 - radius
        if levels >= 1:
            bt = bt or (l[k] <= s1v + radius and h[k] >= s1v - radius)
            st = st or (l[k] <= r1 + radius and h[k] >= r1 - radius)
        if levels == 2:
            bt = bt or (l[k] <= pp + radius and h[k] >= pp - radius)
            st = st or (l[k] <= pp + radius and h[k] >= pp - radius)
        buy = bt and ((not need_dir) or bull)
        sell = st and ((not need_dir) or bear)
        if buy != sell:
            d[b] = 1 if buy else -1
    return d


@njit(cache=True)
def _dir_pvema(o, h, l, c, ef, es, atr, trend_cur, tf_fast, tf_slow, adx, tick, need, nchk, tol_atr,
               min_body, max_len_atr, adx_min):
    n = len(c)
    d = np.zeros(n, np.int8)
    last = min(need - 1, nchk + 1)
    for b in range(need - 1, n):
        tb = trend_cur[b]
        if tb < 1:
            continue
        tfast = tf_fast[tb - 1]
        tslow = tf_slow[tb - 1]
        ax = adx[tb - 1]
        a1 = atr[b - 1]
        if a1 <= 0.0:
            continue
        k = b - 1
        rng = h[k] - l[k]
        body = abs(c[k] - o[k])
        if rng <= tick or body / rng < min_body or rng > max_len_atr * a1 or ax < adx_min:
            continue
        pull = False
        for s in range(2, last + 1):
            ai = atr[b - s]
            if ai <= 0.0:
                continue
            zl = min(ef[b - s], es[b - s]) - tol_atr * ai
            zh = max(ef[b - s], es[b - s]) + tol_atr * ai
            if l[b - s] <= zh and h[b - s] >= zl:
                pull = True
                break
        if not pull:
            continue
        bull = c[k] > o[k]
        bear = c[k] < o[k]
        buy = tfast > tslow and ef[k] > es[k] and bull and c[k] > max(ef[k], es[k])
        sell = tfast < tslow and ef[k] < es[k] and bear and c[k] < min(ef[k], es[k])
        if buy != sell:
            d[b] = 1 if buy else -1
    return d


@njit(cache=True)
def _finalize(dirs, first, t, bid, ask, bl, bh, nsl, buf, tp2r, min_sl, max_sl, tick, safety, spread_max,
              allow_dir, weekday_mode, hours_on, h_start, h_end, digits):
    """EnterPVSignal() for every bar with a pattern. Returns arrays of accepted signals."""
    n = len(dirs)
    i0 = np.empty(n, np.int64)
    buy_o = np.empty(n, np.bool_)
    ent = np.empty(n)
    slo = np.empty(n)
    tpo = np.empty(n)
    m = 0
    for b in range(1, n):
        dd = dirs[b]
        if dd == 0:
            continue
        buy = dd > 0
        i = first[b]
        entry = ask[i] if buy else bid[i]
        if b < nsl:
            continue
        ext = bl[b - 1] if buy else bh[b - 1]
        for s in range(2, nsl + 1):
            if buy:
                ext = min(ext, bl[b - s])
            else:
                ext = max(ext, bh[b - s])
        sl = round(np.floor((ext - buf) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((ext + buf) / tick - 1e-9) * tick, digits)
        if sl <= 0.0 or (buy and sl >= entry) or ((not buy) and sl <= entry):
            continue
        risk = abs(entry - sl)
        if risk < min_sl:
            sl = round(np.floor((entry - min_sl) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((entry + min_sl) / tick - 1e-9) * tick, digits)
            risk = abs(entry - sl)
        if risk > max_sl + tick * 0.5 or risk < tick:
            continue
        tp2 = round(np.ceil((entry + tp2r * risk) / tick - 1e-9) * tick, digits) if buy else round(np.floor((entry - tp2r * risk) / tick + 1e-9) * tick, digits)
        if allow_dir == 1 and not buy:
            continue
        if allow_dir == 2 and buy:
            continue
        tt = t[i]
        dow = (tt // 86400 + 4) % 7
        if weekday_mode == 0 and (dow == 0 or dow == 6):
            continue
        if weekday_mode == 1 and dow == 0:
            continue
        if hours_on:
            hr = (tt % 86400) // 3600
            if h_start < h_end:
                if not (hr >= h_start and hr < h_end):
                    continue
            elif h_start > h_end:
                if not (hr >= h_start or hr < h_end):
                    continue
            else:
                continue
        spread = ask[i] - bid[i]
        if spread_max > 0.0 and spread > spread_max:
            continue
        if (buy and sl >= bid[i] - safety) or ((not buy) and sl <= ask[i] + safety):
            continue
        if (buy and tp2 <= ask[i] + safety) or ((not buy) and tp2 >= bid[i] - safety):
            continue
        # MatrixSignal(): SL band 5-20 and quote safety again
        if risk < min_sl - tick * 0.5 or risk > max_sl + tick * 0.5:
            continue
        i0[m] = i
        buy_o[m] = buy
        ent[m] = entry
        slo[m] = sl
        tpo[m] = tp2
        m += 1
    return i0[:m], buy_o[:m], ent[:m], slo[:m], tpo[:m]


def _src_cur(market, tf_main, tf_src):
    """For each bar of tf_main: index of the tf_src bar containing its first tick."""
    b = market.bars(tf_main)
    return market.tick_bar(tf_src)[b.first]


def pv_signals(market, ind: IndCache, cfg, family):
    tick = market.tick_size
    safety = (market.stops_level + 1) * market.point
    if family == "ENG":
        tf = cfg["InpPVKhungNhanChim"]
        b = market.bars(tf)
        d = _dir_eng(b.open, b.high, b.low, b.close, ind.get("atr", tf, cfg["InpPVATRNhanChim"]), tick,
                     cfg["InpPVNhanChimMinATR"], cfg["InpPVNhanChimMaxATR"], cfg["InpPVThanNhanChimSoVoiThanTruoc"],
                     cfg["InpPVDongCuaManhNhanChim"])
    elif family == "PIN":
        tf = cfg["InpPVKhungPinBar"]
        b = market.bars(tf)
        d = _dir_pin(b.open, b.high, b.low, b.close, ind.get("atr", tf, cfg["InpPVATRPinBar"]), tick,
                     cfg["InpPVPinMinATR"], cfg["InpPVPinMaxATR"], cfg["InpPVRauChinhTrenThan"],
                     cfg["InpPVRauDoiDienTrenThan"], cfg["InpPVDongCuaPinTrongBien"], int(cfg["InpPVPinQuetSoNen"]))
    elif family == "BRK":
        tf = cfg["InpPVKhungBreakout"]
        b = market.bars(tf)
        d = _dir_brk(b.open, b.high, b.low, b.close, tick, int(cfg["InpPVSoNenVungBreakout"]),
                     cfg["InpPVThanBreakoutToiThieu"], cfg["InpPVDemBreakoutGia"], bool(cfg["InpPVChoRetest"]),
                     cfg["InpPVDungSaiRetestGia"])
    elif family == "LQ":
        tf = cfg["InpPVKhungQuetThanhKhoan"]
        b = market.bars(tf)
        d = _dir_lq(b.open, b.high, b.low, b.close, tick, int(cfg["InpPVSoNenThanhKhoan"]),
                    cfg["InpPVDoXuyenToiThieuGia"], cfg["InpPVDoXuyenToiDaGia"], cfg["InpPVDongLaiVaoVungGia"],
                    cfg["InpPVRauQuetTrenThan"])
    elif family == "PVT":
        tf = cfg["InpPVKhungXacNhanPivot"]
        src = cfg["InpPVKhungTinhPivot"]
        b = market.bars(tf)
        s = market.bars(src)
        d = _dir_pvt(b.open, b.high, b.low, b.close, _src_cur(market, tf, src), s.high, s.low, s.close,
                     cfg["InpPVBKPVungPivotGia"], bool(cfg["InpPVYeuCauNenDungHuong"]), int(cfg["InpPVMucPivot"]))
    elif family == "PVEMA":
        tf = cfg["InpPVKhungVaoLenh"]
        ttf = cfg["InpPVKhungXuHuong"]
        b = market.bars(tf)
        need = max(12, int(cfg["InpPVSoNenKiemTraNhipHoi"]) + 4)
        d = _dir_pvema(b.open, b.high, b.low, b.close, ind.get("ema", tf, cfg["InpPVEMANhanhVaoLenh"]),
                       ind.get("ema", tf, cfg["InpPVEMAChamVaoLenh"]), ind.get("atr", tf, cfg["InpPVChuKyATR"]),
                       _src_cur(market, tf, ttf), ind.get("ema", ttf, cfg["InpPVEMANhanhXuHuong"]),
                       ind.get("ema", ttf, cfg["InpPVEMAChamXuHuong"]), ind.get("adx", ttf, cfg["InpPVChuKyADX"]),
                       tick, need, int(cfg["InpPVSoNenKiemTraNhipHoi"]), cfg["InpPVDungSaiHoiATR"],
                       cfg["InpPVThanNenToiThieu"], cfg["InpPVDoDaiNenToiDaATR"], cfg["InpPVADXToiThieu"])
    else:
        raise KeyError(family)
    tk = market.ticks
    i0, buy, entry, sl, tp = _finalize(d, b.first, tk.t, tk.bid, tk.ask, b.low, b.high, int(cfg["InpPVSoNenTimSL"]),
                                       cfg["InpPVDemSLGia"], cfg["InpPVTP2R"], cfg["InpMinSLPriceDistance"],
                                       cfg["InpMaxSLPriceDistance"], tick, safety, cfg["InpSpreadToiDaGia"],
                                       int(cfg["InpPVHuongGiaoDich"]), int(cfg["InpPVNgayGiaoDich"]),
                                       bool(cfg["InpPVChiTradeTrongGio"]), int(cfg["InpPVGioBatDau"]),
                                       int(cfg["InpPVGioKetThuc"]), market.digits)
    return {"i0": i0, "buy": buy, "entry": entry, "sl": sl, "tp": tp, "raw_patterns": int(np.count_nonzero(d))}
