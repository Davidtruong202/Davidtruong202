"""Slow, literal re-translation of the V4.39 MQL5 signal functions, used only to cross-check the
fast numba implementation. Works with MqlRates-like series arrays built at each evaluation tick:
r[0] is the forming bar (only its first tick known), r[1] the last closed bar.
"""
import numpy as np


class Rates:
    """Series view: r.o[s], r.h[s], r.l[s], r.c[s], r.t[s] for s = 0 .. count-1."""

    def __init__(self, bars, cur, count, tick_bid):
        idx = np.arange(cur, cur - count, -1)
        self.ok = idx[-1] >= 0 and count <= cur + 1
        idx = np.clip(idx, 0, None)
        self.o = bars.open[idx].copy()
        self.h = bars.high[idx].copy()
        self.l = bars.low[idx].copy()
        self.c = bars.close[idx].copy()
        self.t = bars.time[idx].copy()
        # forming bar: only the first tick is known
        self.o[0] = self.h[0] = self.l[0] = self.c[0] = tick_bid


def copy_rates(bars, cur, count, bid):
    r = Rates(bars, cur, count, bid)
    return r if r.ok else None


def buf(arr, cur, shift):
    k = cur - shift
    return arr[k] if k >= 0 else None


# ---------------- PV families -----------------
def eng(r, atr, tick, cfg):
    rng = r.h[1] - r.l[1]
    body = abs(r.c[1] - r.o[1])
    prev = abs(r.c[2] - r.o[2])
    if (rng <= tick or rng / atr < cfg["InpPVNhanChimMinATR"] or rng / atr > cfg["InpPVNhanChimMaxATR"] or
            body + tick * 0.1 < prev * cfg["InpPVThanNhanChimSoVoiThanTruoc"]):
        return 0
    bull = (r.c[2] < r.o[2] and r.c[1] > r.o[1] and r.o[1] <= r.c[2] and r.c[1] >= r.o[2] and
            (r.c[1] - r.l[1]) / rng >= cfg["InpPVDongCuaManhNhanChim"])
    bear = (r.c[2] > r.o[2] and r.c[1] < r.o[1] and r.o[1] >= r.c[2] and r.c[1] <= r.o[2] and
            (r.h[1] - r.c[1]) / rng >= cfg["InpPVDongCuaManhNhanChim"])
    return 0 if bull == bear else (1 if bull else -1)


def pin(r, atr, tick, cfg):
    need = cfg["InpPVPinQuetSoNen"] + 2
    rng = r.h[1] - r.l[1]
    body = max(tick, abs(r.c[1] - r.o[1]))
    if rng <= tick or rng / atr < cfg["InpPVPinMinATR"] or rng / atr > cfg["InpPVPinMaxATR"]:
        return 0
    upper = r.h[1] - max(r.o[1], r.c[1])
    lower = min(r.o[1], r.c[1]) - r.l[1]
    ph, pl = r.h[2], r.l[2]
    for i in range(3, need):
        ph = max(ph, r.h[i]); pl = min(pl, r.l[i])
    bull = (lower / body >= cfg["InpPVRauChinhTrenThan"] and upper / body <= cfg["InpPVRauDoiDienTrenThan"] and
            (r.c[1] - r.l[1]) / rng >= cfg["InpPVDongCuaPinTrongBien"] and r.l[1] < pl)
    bear = (upper / body >= cfg["InpPVRauChinhTrenThan"] and lower / body <= cfg["InpPVRauDoiDienTrenThan"] and
            (r.h[1] - r.c[1]) / rng >= cfg["InpPVDongCuaPinTrongBien"] and r.h[1] > ph)
    return 0 if bull == bear else (1 if bull else -1)


def brk(r, tick, cfg):
    bs = 2 if cfg["InpPVChoRetest"] else 1
    fl = bs + 1
    hi, lo = r.h[fl], r.l[fl]
    for i in range(fl + 1, fl + cfg["InpPVSoNenVungBreakout"]):
        hi = max(hi, r.h[i]); lo = min(lo, r.l[i])
    rng = r.h[bs] - r.l[bs]
    body = abs(r.c[bs] - r.o[bs])
    if rng <= tick or body / rng < cfg["InpPVThanBreakoutToiThieu"]:
        return 0
    up = r.c[bs] > hi + cfg["InpPVDemBreakoutGia"]
    dn = r.c[bs] < lo - cfg["InpPVDemBreakoutGia"]
    if not cfg["InpPVChoRetest"]:
        return 0 if up == dn else (1 if up else -1)
    tol = cfg["InpPVDungSaiRetestGia"]
    buy = up and r.l[1] <= hi + tol and r.c[1] > hi and r.c[1] > r.o[1]
    sell = dn and r.h[1] >= lo - tol and r.c[1] < lo and r.c[1] < r.o[1]
    return 0 if buy == sell else (1 if buy else -1)


def lq(r, tick, cfg):
    need = cfg["InpPVSoNenThanhKhoan"] + 2
    ph, pl = r.h[2], r.l[2]
    for i in range(3, need):
        ph = max(ph, r.h[i]); pl = min(pl, r.l[i])
    mn = min(cfg["InpPVDoXuyenToiThieuGia"], cfg["InpPVDoXuyenToiDaGia"])
    mx = max(cfg["InpPVDoXuyenToiThieuGia"], cfg["InpPVDoXuyenToiDaGia"])
    body = max(tick, abs(r.c[1] - r.o[1]))
    lw = min(r.o[1], r.c[1]) - r.l[1]
    uw = r.h[1] - max(r.o[1], r.c[1])
    dp = pl - r.l[1]
    up = r.h[1] - ph
    buy = mn <= dp <= mx and r.c[1] >= pl + cfg["InpPVDongLaiVaoVungGia"] and lw / body >= cfg["InpPVRauQuetTrenThan"]
    sell = mn <= up <= mx and r.c[1] <= ph - cfg["InpPVDongLaiVaoVungGia"] and uw / body >= cfg["InpPVRauQuetTrenThan"]
    return 0 if buy == sell else (1 if buy else -1)


def pvt(src, conf, cfg):
    pp = (src.h[1] + src.l[1] + src.c[1]) / 3.0
    rng = src.h[1] - src.l[1]
    r1 = 2 * pp - src.l[1]; s1 = 2 * pp - src.h[1]; r2 = pp + rng; s2 = pp - rng
    rad = cfg["InpPVBKPVungPivotGia"]

    def touch(lv):
        return conf.l[1] <= lv + rad and conf.h[1] >= lv - rad
    bull = conf.c[1] > conf.o[1]
    bear = conf.c[1] < conf.o[1]
    bt, st = touch(s2), touch(r2)
    if cfg["InpPVMucPivot"] >= 1:
        bt = bt or touch(s1); st = st or touch(r1)
    if cfg["InpPVMucPivot"] == 2:
        bt = bt or touch(pp); st = st or touch(pp)
    buy = bt and (not cfg["InpPVYeuCauNenDungHuong"] or bull)
    sell = st and (not cfg["InpPVYeuCauNenDungHuong"] or bear)
    return 0 if buy == sell else (1 if buy else -1)


def pvema(r, ef, es, atr, tf_fast, tf_slow, adx, tick, cfg):
    need = max(12, cfg["InpPVSoNenKiemTraNhipHoi"] + 4)
    rng = r.h[1] - r.l[1]
    body = abs(r.c[1] - r.o[1])
    if (rng <= tick or body / rng < cfg["InpPVThanNenToiThieu"] or rng > cfg["InpPVDoDaiNenToiDaATR"] * atr[1] or
            adx < cfg["InpPVADXToiThieu"]):
        return 0
    pull = False
    last = min(need - 1, cfg["InpPVSoNenKiemTraNhipHoi"] + 1)
    for i in range(2, last + 1):
        if atr[i] <= 0:
            continue
        zl = min(ef[i], es[i]) - cfg["InpPVDungSaiHoiATR"] * atr[i]
        zh = max(ef[i], es[i]) + cfg["InpPVDungSaiHoiATR"] * atr[i]
        if r.l[i] <= zh and r.h[i] >= zl:
            pull = True
            break
    if not pull:
        return 0
    bull = r.c[1] > r.o[1]; bear = r.c[1] < r.o[1]
    buy = tf_fast > tf_slow and ef[1] > es[1] and bull and r.c[1] > max(ef[1], es[1])
    sell = tf_fast < tf_slow and ef[1] < es[1] and bear and r.c[1] < min(ef[1], es[1])
    return 0 if buy == sell else (1 if buy else -1)


# ---------------- structure helpers -----------------
def is_pivot_high(r, total, s, w):
    if s - w < 1 or s + w >= total:
        return False
    for k in range(1, w + 1):
        if r.h[s] <= r.h[s - k] or r.h[s] < r.h[s + k]:
            return False
    return True


def is_pivot_low(r, total, s, w):
    if s - w < 1 or s + w >= total:
        return False
    for k in range(1, w + 1):
        if r.l[s] >= r.l[s - k] or r.l[s] > r.l[s + k]:
            return False
    return True


def find_pivot(r, total, high, first, last, w):
    first = max(first, w + 1)
    last = min(last, total - w - 1)
    for i in range(first, last + 1):
        if (is_pivot_high if high else is_pivot_low)(r, total, i, w):
            return i
    return -1


def structural_bias(bars, cur, lookback, w, bid):
    need = max(lookback, 24) + w + 5
    r = copy_rates(bars, cur, need, bid)
    if r is None:
        return 0
    h1 = find_pivot(r, need, True, w + 1, need - w - 1, w)
    l1 = find_pivot(r, need, False, w + 1, need - w - 1, w)
    if h1 < 0 or l1 < 0:
        return 0
    h2 = find_pivot(r, need, True, h1 + w + 1, need - w - 1, w)
    l2 = find_pivot(r, need, False, l1 + w + 1, need - w - 1, w)
    if h2 >= 0 and l2 >= 0:
        if r.h[h1] > r.h[h2] and r.l[l1] > r.l[l2]:
            return 1
        if r.h[h1] < r.h[h2] and r.l[l1] < r.l[l2]:
            return -1
    mid = (r.h[h1] + r.l[l1]) * 0.5
    return 1 if r.c[1] > mid else (-1 if r.c[1] < mid else 0)


def detect_sweep_mss_fvg(r, total, buy, w, lookback, atr, disp, minfvg):
    max_shift = min(lookback, total - w - 2)
    for sw in range(w + 3, max_shift + 1):
        liq = find_pivot(r, total, not buy, sw + w, min(max_shift + w, total - w - 1), w)
        if liq < 0:
            continue
        level = r.l[liq] if buy else r.h[liq]
        swept = (r.l[sw] < level and r.c[sw] > level) if buy else (r.h[sw] > level and r.c[sw] < level)
        if not swept:
            continue
        structure = -1e100 if buy else 1e100
        for j in range(sw + 1, min(sw + 16, total - 1) + 1):
            structure = max(structure, r.h[j]) if buy else min(structure, r.l[j])
        mss = -1
        for j in range(sw - 1, 0, -1):
            body = abs(r.c[j] - r.o[j])
            broken = r.c[j] > structure if buy else r.c[j] < structure
            if broken and body >= disp * atr:
                mss = j
                break
        if mss < 1:
            continue
        fvg = -1
        for k in range(mss, 0, -1):
            if k + 2 > sw:
                continue
            gap = r.l[k] - r.h[k + 2] if buy else r.l[k + 2] - r.h[k]
            if gap >= minfvg * atr:
                fvg = k
                break
        if fvg < 1:
            continue
        zl, zh = (r.h[fvg + 2], r.l[fvg]) if buy else (r.h[fvg], r.l[fvg + 2])
        opp = -1
        for j in range(mss + 1, sw + 1):
            if (buy and r.c[j] < r.o[j]) or (not buy and r.c[j] > r.o[j]):
                opp = j
                break
        if opp < 0:
            opp = sw
        return dict(zl=zl, zh=zh, sweep=r.l[sw] if buy else r.h[sw], bbl=r.l[opp], bbh=r.h[opp], sig_t=int(r.t[mss]))
    return None
