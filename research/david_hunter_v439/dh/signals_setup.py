"""Families 1-3 (ICT, MM, SMC): zone setups built on new entry-TF bars, entered on ticks.

Faithful port of StructuralBias(), DetectSweepMSSFVG(), BuildICTSetup(), HTFDealingRange(),
DetectMMContinuation(), BuildMMSetup(), ReadSMCBias(), SMCEntryFiltersAllow(),
DetectSMCStructure(), BuildSMCSetup() and TryEnterSetup().

Series convention of the EA: r[s] with s=0 the forming bar, s=1 the last closed bar.
Here bar index c is the forming bar, so r[s] == bar c - s.
"""
import numpy as np
from numba import njit

from .mt5ind import IndCache

EXPIRED, INVALID, TOUCH, BIAS_CHANGED, END = 0, 1, 2, 3, 4


@njit(cache=True)
def _is_pivot(H, L, c, total, s, wing, high):
    if s - wing < 1 or s + wing >= total:
        return False
    for k in range(1, wing + 1):
        if high:
            if H[c - s] <= H[c - s + k] or H[c - s] < H[c - s - k]:
                return False
        else:
            if L[c - s] >= L[c - s + k] or L[c - s] > L[c - s - k]:
                return False
    return True


@njit(cache=True)
def _find_pivot(H, L, c, total, high, first_shift, last_shift, wing):
    first = max(first_shift, wing + 1)
    last = min(last_shift, total - wing - 1)
    for s in range(first, last + 1):
        if _is_pivot(H, L, c, total, s, wing, high):
            return s
    return -1


@njit(cache=True)
def structural_bias_series(H, L, C, lookback, wing):
    """StructuralBias() for every forming-bar index cb of the bias timeframe."""
    n = len(C)
    out = np.zeros(n, np.int8)
    need = max(lookback, 24) + wing + 5
    for cb in range(need - 1, n):
        h1 = _find_pivot(H, L, cb, need, True, wing + 1, need - wing - 1, wing)
        l1 = _find_pivot(H, L, cb, need, False, wing + 1, need - wing - 1, wing)
        if h1 < 0 or l1 < 0:
            continue
        h2 = _find_pivot(H, L, cb, need, True, h1 + wing + 1, need - wing - 1, wing)
        l2 = _find_pivot(H, L, cb, need, False, l1 + wing + 1, need - wing - 1, wing)
        if h2 >= 0 and l2 >= 0:
            if H[cb - h1] > H[cb - h2] and L[cb - l1] > L[cb - l2]:
                out[cb] = 1
                continue
            if H[cb - h1] < H[cb - h2] and L[cb - l1] < L[cb - l2]:
                out[cb] = -1
                continue
        mid = (H[cb - h1] + L[cb - l1]) * 0.5
        if C[cb - 1] > mid:
            out[cb] = 1
        elif C[cb - 1] < mid:
            out[cb] = -1
    return out


@njit(cache=True)
def _intersect(al, ah, bl, bh, tick):
    lo = max(min(al, ah), min(bl, bh))
    hi = min(max(al, ah), max(bl, bh))
    return hi > lo + tick * 0.25, lo, hi


@njit(cache=True)
def detect_sweep_mss_fvg(O, H, L, C, c, total, buy, wing, lookback, atr, disp, minfvg):
    """Returns (found, fvgLow, fvgHigh, sweepExt, bbLow, bbHigh, invLow, invHigh, hasInv, mss_shift)."""
    max_shift = min(lookback, total - wing - 2)
    for sw in range(wing + 3, max_shift + 1):
        liq = _find_pivot(H, L, c, total, not buy, sw + wing, min(max_shift + wing, total - wing - 1), wing)
        if liq < 0:
            continue
        level = L[c - liq] if buy else H[c - liq]
        if buy:
            swept = L[c - sw] < level and C[c - sw] > level
        else:
            swept = H[c - sw] > level and C[c - sw] < level
        if not swept:
            continue
        structure = -1.0e100 if buy else 1.0e100
        s_end = min(sw + 16, total - 1)
        for j in range(sw + 1, s_end + 1):
            if buy:
                structure = max(structure, H[c - j])
            else:
                structure = min(structure, L[c - j])
        mss = -1
        for j in range(sw - 1, 0, -1):
            body = abs(C[c - j] - O[c - j])
            broken = C[c - j] > structure if buy else C[c - j] < structure
            if broken and body >= disp * atr:
                mss = j
                break
        if mss < 1:
            continue
        fvg = -1
        for k in range(mss, 0, -1):
            if k + 2 > sw:
                continue
            gap = L[c - k] - H[c - k - 2] if buy else L[c - k - 2] - H[c - k]
            if gap >= minfvg * atr:
                fvg = k
                break
        if fvg < 1:
            continue
        if buy:
            zl, zh = H[c - fvg - 2], L[c - fvg]
        else:
            zl, zh = H[c - fvg], L[c - fvg - 2]
        opp = -1
        for j in range(mss + 1, sw + 1):
            if (buy and C[c - j] < O[c - j]) or ((not buy) and C[c - j] > O[c - j]):
                opp = j
                break
        if opp < 0:
            opp = sw
        bbl, bbh = L[c - opp], H[c - opp]
        has_inv = False
        il, ih = 0.0, 0.0
        k = mss + 1
        while k + 2 <= sw:
            if buy and L[c - k - 2] > H[c - k]:
                lo, hi = H[c - k], L[c - k - 2]
                if C[c - mss] > hi:
                    il, ih, has_inv = lo, hi, True
                    break
            if (not buy) and L[c - k] > H[c - k - 2]:
                lo, hi = H[c - k - 2], L[c - k]
                if C[c - mss] < lo:
                    il, ih, has_inv = lo, hi, True
                    break
            k += 1
        sweep_ext = L[c - sw] if buy else H[c - sw]
        return True, zl, zh, sweep_ext, bbl, bbh, il, ih, has_inv, mss
    return False, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, False, -1


@njit(cache=True)
def detect_smc_structure(O, H, L, C, c, total, buy, wing, lookback, atr, disp, minfvg, need_fvg, prefer_fvg, tick):
    """Returns (found, zoneLow, zoneHigh, sweepExt, hasFVG, zone_src(0=OB,1=OB_FVG,2=FVG), disp_shift)."""
    max_shift = min(lookback, total - wing - 2)
    for sw in range(wing + 3, max_shift + 1):
        liq = _find_pivot(H, L, c, total, not buy, sw + wing, min(max_shift + wing, total - wing - 1), wing)
        if liq < 0:
            continue
        level = L[c - liq] if buy else H[c - liq]
        if buy:
            swept = L[c - sw] < level and C[c - sw] > level
        else:
            swept = H[c - sw] > level and C[c - sw] < level
        if not swept:
            continue
        structure = -1.0e100 if buy else 1.0e100
        s_end = min(sw + 16, total - 1)
        for j in range(sw + 1, s_end + 1):
            if buy:
                structure = max(structure, H[c - j])
            else:
                structure = min(structure, L[c - j])
        dsp = -1
        for j in range(sw - 1, 0, -1):
            body = abs(C[c - j] - O[c - j])
            broke = C[c - j] > structure if buy else C[c - j] < structure
            if broke and body >= disp * atr:
                dsp = j
                break
        if dsp < 1:
            continue
        ob = -1
        for j in range(dsp + 1, sw + 1):
            opposite = C[c - j] < O[c - j] if buy else C[c - j] > O[c - j]
            if opposite:
                ob = j
                break
        if ob < 0:
            ob = sw
        obl, obh = L[c - ob], H[c - ob]
        has_fvg = False
        fl, fh = 0.0, 0.0
        for k in range(dsp, 0, -1):
            if k + 2 > sw:
                continue
            gap = L[c - k] - H[c - k - 2] if buy else L[c - k - 2] - H[c - k]
            if gap < minfvg * atr:
                continue
            if buy:
                fl, fh = H[c - k - 2], L[c - k]
            else:
                fl, fh = H[c - k], L[c - k - 2]
            has_fvg = True
            break
        if need_fvg and not has_fvg:
            continue
        zl, zh = min(obl, obh), max(obl, obh)
        src = 0
        if has_fvg and prefer_fvg:
            ok, il, ih = _intersect(obl, obh, fl, fh, tick)
            if ok:
                zl, zh, src = il, ih, 1
            else:
                zl, zh, src = min(fl, fh), max(fl, fh), 2
        sweep_ext = L[c - sw] if buy else H[c - sw]
        invalid = False
        for j in range(dsp - 1, 0, -1):
            if (buy and L[c - j] <= sweep_ext) or ((not buy) and H[c - j] >= sweep_ext):
                invalid = True
                break
        if invalid:
            continue
        return True, zl, zh, sweep_ext, has_fvg, src, dsp
    return False, 0.0, 0.0, 0.0, False, 0, -1


@njit(cache=True)
def scan_setup(t, bid, ask, i_start, buy, zlo, zhi, stop, expire_t, tick, smc, b_first, b_bias, e_first, e_fb, e_fs):
    """TryEnterSetup() on every tick while the setup is active. Returns (tick_index, reason)."""
    n = len(t)
    cb = 0
    ce = 0
    if smc:
        cb = np.searchsorted(b_first, i_start, side="right") - 1
        ce = np.searchsorted(e_first, i_start, side="right") - 1
    want = 1 if buy else -1
    for i in range(i_start, n):
        if t[i] > expire_t:
            return i, EXPIRED
        if buy:
            if bid[i] <= stop:
                return i, INVALID
            entry = ask[i]
        else:
            if ask[i] >= stop:
                return i, INVALID
            entry = bid[i]
        if entry < zlo - tick or entry > zhi + tick:
            continue
        if smc:
            while cb + 1 < len(b_first) and b_first[cb + 1] <= i:
                cb += 1
            while ce + 1 < len(e_first) and e_first[ce + 1] <= i:
                ce += 1
            if b_bias[cb] != want:
                return i, BIAS_CHANGED
            if not (e_fb[ce] if buy else e_fs[ce]):
                continue
        return i, TOUCH
    return n - 1, END


def _price_down(v, tick, digits=3):
    return round(float(np.floor(v / tick + 1e-9) * tick), digits)


def _price_up(v, tick, digits=3):
    return round(float(np.ceil(v / tick - 1e-9) * tick), digits)


class _Emitter:
    """Collects entries after TryEnterSetup's SL normalisation and MatrixSignal's checks."""

    def __init__(self, market, cfg):
        self.m = market
        self.cfg = cfg
        self.tick = market.tick_size
        self.safety = (market.stops_level + 1) * market.point
        self.rows = {"i0": [], "buy": [], "entry": [], "sl": [], "tp": [], "model": []}
        self.stats = {"setups": 0, "touch": 0, "expired": 0, "invalid": 0, "bias_changed": 0, "sl_reject": 0,
                      "matrix_reject": 0, "signals": 0}

    def touch(self, i, buy, stop, rr, model):
        """Returns True if the setup is consumed (always, once touched), and records a signal if valid."""
        tk = self.m.ticks
        c = self.cfg
        tick = self.tick
        entry = tk.ask[i] if buy else tk.bid[i]
        d = self.m.digits
        sl = _price_down(stop, tick, d) if buy else _price_up(stop, tick, d)
        if entry <= 0 or sl <= 0 or (buy and sl >= entry) or ((not buy) and sl <= entry):
            self.stats["sl_reject"] += 1
            return False
        risk = abs(entry - sl)
        if risk < c["InpMinSLPriceDistance"]:
            sl = _price_down(entry - c["InpMinSLPriceDistance"], tick, d) if buy else _price_up(entry + c["InpMinSLPriceDistance"], tick, d)
            risk = abs(entry - sl)
        if risk > c["InpMaxSLPriceDistance"] + tick * 0.5 or risk < tick:
            self.stats["sl_reject"] += 1
            return False
        tp = _price_up(entry + rr * risk, tick, d) if buy else _price_down(entry - rr * risk, tick, d)
        b, a = tk.bid[i], tk.ask[i]
        ok = c["InpMinSLPriceDistance"] - tick * 0.5 <= risk <= c["InpMaxSLPriceDistance"] + tick * 0.5
        ok &= (sl < b - self.safety and tp > a + self.safety) if buy else (sl > a + self.safety and tp < b - self.safety)
        ok &= not (c["InpSpreadToiDaGia"] > 0 and a - b > c["InpSpreadToiDaGia"])
        if ok:
            r = self.rows
            r["i0"].append(i); r["buy"].append(buy); r["entry"].append(entry); r["sl"].append(sl)
            r["tp"].append(tp); r["model"].append(model)
            self.stats["signals"] += 1
        else:
            self.stats["matrix_reject"] += 1
        return True

    def result(self):
        r = self.rows
        out = {"i0": np.array(r["i0"], np.int64), "buy": np.array(r["buy"], bool),
               "entry": np.array(r["entry"], float), "sl": np.array(r["sl"], float),
               "tp": np.array(r["tp"], float), "model": np.array(r["model"], object)}
        out.update(self.stats)
        return out


def _bias_tf_cur(market, tf, btf):
    return market.tick_bar(btf)[market.bars(tf).first]


def _run_setup_engine(market, cfg, tf, rr, build, smc_ctx=None):
    """Generic Step()/TryEnterSetup() loop. build(c) -> setup dict or None."""
    B = market.bars(tf)
    tk = market.ticks
    em = _Emitter(market, cfg)
    empty_i = np.zeros(1, np.int64)
    empty_b = np.zeros(1, np.int8)
    empty_f = np.zeros(1, np.bool_)
    c = 1
    nb = len(B)
    while c < nb:
        s = build(c)
        if s is None:
            c += 1
            continue
        em.stats["setups"] += 1
        i = int(B.first[c])
        expire_t = s["created"] + s["expiry"] * B.sec
        if smc_ctx is not None:
            j, reason = scan_setup(tk.t, tk.bid, tk.ask, i, s["buy"], s["zlo"], s["zhi"], s["stop"], expire_t,
                                   market.tick_size, True, smc_ctx[0], smc_ctx[1], smc_ctx[2], smc_ctx[3], smc_ctx[4])
        else:
            j, reason = scan_setup(tk.t, tk.bid, tk.ask, i, s["buy"], s["zlo"], s["zhi"], s["stop"], expire_t,
                                   market.tick_size, False, empty_i, empty_b, empty_i, empty_f, empty_f)
        if reason == END:
            break
        if reason == TOUCH:
            em.stats["touch"] += 1
            if em.touch(j, s["buy"], s["stop"], rr, s["model"]):
                s["on_taken"]()
        elif reason == EXPIRED:
            em.stats["expired"] += 1
        elif reason == INVALID:
            em.stats["invalid"] += 1
        else:
            em.stats["bias_changed"] += 1
        # Next Step() that can build: an expiry detected on the first tick of a new bar rebuilds on
        # that same tick (Step sees new bar + expired setup); any other ending waits for the next bar.
        side = "left" if reason == EXPIRED else "right"
        c = max(c + 1, int(np.searchsorted(B.first, j, side=side)))
    return em.result()


def _select_ict_model(cfg, buy, O, H, L, C, T, c, need, atr, det, tick):
    found, fl, fh, sweep, bbl, bbh, il, ih, has_inv, mss = det
    sig_t = T[c - mss]
    uni_ok, ul, uh = _intersect(fl, fh, bbl, bbh, tick)
    unicorn = cfg["InpICTUseUnicorn"] and uni_ok
    ihigh, ilow = H[c - 1], L[c - 1]
    s = 1
    while s < need and T[c - s] >= sig_t:
        ihigh = max(ihigh, H[c - s])
        ilow = min(ilow, L[c - s])
        s += 1
    if buy:
        ilow = min(ilow, sweep)
    else:
        ihigh = max(ihigh, sweep)
    rng = ihigh - ilow
    if buy:
        ro_l, ro_h = ihigh - rng * cfg["InpICTOTELow"], ihigh - rng * cfg["InpICTOTEHigh"]
    else:
        ro_l, ro_h = ilow + rng * cfg["InpICTOTEHigh"], ilow + rng * cfg["InpICTOTELow"]
    ote_ok, ol, oh = _intersect(fl, fh, ro_l, ro_h, tick)
    ote = cfg["InpICTUseOTE"] and rng >= cfg["InpICTMinImpulseATR"] * atr and ote_ok
    inversion = cfg["InpICTUseInversion"] and has_inv
    pr = int(cfg["InpICTPriority"])
    zone, model = (fl, fh), "ICT-2022"
    selected = False
    if pr == 0 and unicorn:
        zone, model, selected = (ul, uh), "ICT-UNICORN", True
    if pr == 1 and ote:
        zone, model, selected = (ol, oh), "ICT-OTE", True
    if pr == 2 and inversion:
        zone, model, selected = (il, ih), "ICT-INV", True
    if pr == 3 and cfg["InpICTUse2022"]:
        selected = True
    if not selected and unicorn:
        zone, model, selected = (ul, uh), "ICT-UNICORN", True
    if not selected and ote:
        zone, model, selected = (ol, oh), "ICT-OTE", True
    if not selected and inversion:
        zone, model, selected = (il, ih), "ICT-INV", True
    if not selected and cfg["InpICTUse2022"]:
        selected = True
    if not selected:
        return None
    return min(zone), max(zone), model, sig_t


def ict_signals(market, ind: IndCache, cfg):
    tf, btf = cfg["InpICTEntryTF"], cfg["InpICTBiasTF"]
    B = market.bars(tf)
    BB = market.bars(btf)
    O, H, L, C, T = B.open, B.high, B.low, B.close, B.time
    atr = ind.get("atr", tf, cfg["InpATRPeriod"])
    wing, lb = int(cfg["InpICTPivotBars"]), int(cfg["InpICTLookback"])
    bias_all = structural_bias_series(BB.high, BB.low, BB.close, lb, wing)
    bcur = _bias_tf_cur(market, tf, btf)
    need = lb + wing * 2 + 12
    st = {"taken": -1, "setup_t": -1}
    tick = market.tick_size

    def build(c):
        bias = bias_all[bcur[c]]
        if bias == 0 or c + 1 < need or atr[c - 1] <= 0.0:
            return None
        buy = bias > 0
        det = detect_sweep_mss_fvg(O, H, L, C, c, need, buy, wing, lb, atr[c - 1],
                                   cfg["InpICTDisplacementATR"], cfg["InpICTMinFVG_ATR"])
        if not det[0]:
            return None
        sig_t = int(T[c - det[9]])
        if sig_t <= st["taken"] or sig_t <= st["setup_t"]:
            return None
        sel = _select_ict_model(cfg, buy, O, H, L, C, T, c, need, atr[c - 1], det, tick)
        if sel is None:
            return None
        zl, zh, model, _ = sel
        st["setup_t"] = sig_t
        stop = det[3] - cfg["InpICTSLBufferGia"] if buy else det[3] + cfg["InpICTSLBufferGia"]

        def taken():
            st["taken"] = sig_t
        return {"buy": buy, "zlo": zl, "zhi": zh, "stop": stop, "created": sig_t,
                "expiry": int(cfg["InpICTSetupExpiryBars"]), "model": model, "on_taken": taken}

    return _run_setup_engine(market, cfg, tf, cfg["InpICTRR"], build)


@njit(cache=True)
def _mm_continuation(O, H, L, C, c, total, atr, buy, ncons, max_cons_atr, disp):
    if total < ncons + 5:
        return False, 0.0, 0.0, 0.0
    hi, lo = H[c - 2], L[c - 2]
    for s in range(3, ncons + 2):
        hi = max(hi, H[c - s])
        lo = min(lo, L[c - s])
    if hi - lo > max_cons_atr * atr:
        return False, 0.0, 0.0, 0.0
    body = abs(C[c - 1] - O[c - 1])
    brk = C[c - 1] > hi if buy else C[c - 1] < lo
    if (not brk) or body < disp * atr:
        return False, 0.0, 0.0, 0.0
    if buy and L[c - 1] > H[c - 3]:
        return True, H[c - 3], L[c - 1], lo
    if (not buy) and L[c - 3] > H[c - 1]:
        return True, H[c - 1], L[c - 3], hi
    return False, 0.0, 0.0, 0.0


def mm_signals(market, ind: IndCache, cfg):
    tf, btf = cfg["InpMMEntryTF"], cfg["InpMMBiasTF"]
    B = market.bars(tf)
    BB = market.bars(btf)
    O, H, L, C, T = B.open, B.high, B.low, B.close, B.time
    atr = ind.get("atr", tf, cfg["InpATRPeriod"])
    wing, lb = int(cfg["InpMMPivotBars"]), int(cfg["InpMMLookback"])
    need = lb + wing * 2 + 12
    bcur = _bias_tf_cur(market, tf, btf)
    nr = int(cfg["InpMMRangeBars"])
    tick = market.tick_size
    st = {"taken": -1, "setup_t": -1}
    ctx = {"active": False, "buy": True, "leg": 0, "rev_t": 0, "inv": 0.0}

    def build(c):
        if c + 1 < need or atr[c - 1] <= 0.0:
            return None
        a = atr[c - 1]
        now_t = int(market.ticks.t[B.first[c]])
        if ctx["active"]:
            if (ctx["buy"] and L[c - 1] <= ctx["inv"]) or ((not ctx["buy"]) and H[c - 1] >= ctx["inv"]):
                ctx["active"] = False
            if ctx["active"] and now_t > ctx["rev_t"] + int(cfg["InpMMModelExpiryBars"]) * B.sec:
                ctx["active"] = False
            elif ctx["active"] and ctx["leg"] <= 2 and ((ctx["leg"] == 1 and cfg["InpMMUseLeg1"]) or
                                                         (ctx["leg"] == 2 and cfg["InpMMUseLeg2"])):
                ok, zl, zh, stp = _mm_continuation(O, H, L, C, c, need, a, ctx["buy"], int(cfg["InpMMConsolidationBars"]),
                                                   cfg["InpMMMaxConsolidationATR"], cfg["InpMMDisplacementATR"])
                if ok:
                    ct = int(T[c - 1])
                    if ct <= st["setup_t"]:
                        return None
                    st["setup_t"] = ct
                    buy = ctx["buy"]
                    stop = stp - cfg["InpMMSLBufferGia"] if buy else stp + cfg["InpMMSLBufferGia"]

                    def taken_leg(ct=ct):
                        st["taken"] = ct  # TryEnterSetup sets g_lastMMTaken for every MM model
                    # nextLeg is never advanced in V4.39, so continuation setups stay "LEG1".
                    return {"buy": buy, "zlo": min(zl, zh), "zhi": max(zl, zh), "stop": stop, "created": ct,
                            "expiry": int(cfg["InpMMLegSetupExpiryBars"]),
                            "model": "MM-LEG1" if ctx["leg"] == 1 else "MM-LEG2", "on_taken": taken_leg}
        if not cfg["InpMMUseLowRisk"]:
            return None
        cb = bcur[c]
        if cb + 1 < nr + 2:
            return None
        lo = BB.low[cb - nr:cb].min()
        hi = BB.high[cb - nr:cb].max()
        if not hi > lo:
            return None
        premium = lo + (hi - lo) * cfg["InpMMPremiumLevel"]
        discount = lo + (hi - lo) * cfg["InpMMDiscountLevel"]
        for buy in (True, False):
            det = detect_sweep_mss_fvg(O, H, L, C, c, need, buy, wing, lb, a, cfg["InpMMDisplacementATR"],
                                       cfg["InpMMMinFVG_ATR"])
            if not det[0]:
                continue
            sig_t = int(T[c - det[9]])
            if sig_t <= st["taken"] or sig_t <= st["setup_t"]:
                continue
            sweep = det[3]
            if (buy and sweep > discount) or ((not buy) and sweep < premium):
                continue
            ok, zl, zh = _intersect(det[1], det[2], det[4], det[5], tick)
            if not ok:
                zl, zh = det[1], det[2]
            stop = sweep - cfg["InpMMSLBufferGia"] if buy else sweep + cfg["InpMMSLBufferGia"]
            st["setup_t"] = sig_t
            ctx.update({"active": True, "buy": buy, "leg": 1, "rev_t": sig_t, "inv": stop})

            def taken(sig_t=sig_t):
                st["taken"] = sig_t
            return {"buy": buy, "zlo": min(zl, zh), "zhi": max(zl, zh), "stop": stop, "created": sig_t,
                    "expiry": int(cfg["InpMMLowRiskExpiryBars"]), "model": "MM-LOWRISK", "on_taken": taken}
        return None

    return _run_setup_engine(market, cfg, tf, cfg["InpMMRR"], build)


def _smc_bias_by_bar(market, ind, cfg):
    """ReadSMCBias() for every forming bar of the bias timeframe (uses the last closed bar)."""
    btf = cfg["InpSMCBiasTF"]
    BB = market.bars(btf)
    n = len(BB)
    if not cfg["InpSMCDungLocEMAH1"]:
        return structural_bias_series(BB.high, BB.low, BB.close, int(cfg["InpSMCLookback"]), int(cfg["InpSMCPivotBars"]))
    f = ind.get("ema", btf, cfg["InpSMCEMANhanhH1"])
    s = ind.get("ema", btf, cfg["InpSMCEMAChamH1"])
    out = np.zeros(n, np.int8)
    close = BB.close
    for cb in range(1, n):
        k = cb - 1
        buy = close[k] > max(f[k], s[k])
        sell = close[k] < min(f[k], s[k])
        if cfg["InpSMCYeuCauThuTuEMAH1"]:
            buy = buy and f[k] > s[k]
            sell = sell and f[k] < s[k]
        out[cb] = 0 if buy == sell else (1 if buy else -1)
    return out


def _smc_filters_by_bar(market, ind, cfg):
    """SMCEntryFiltersAllow() for BUY and SELL for every forming bar of the entry timeframe."""
    tf = cfg["InpSMCEntryTF"]
    B = market.bars(tf)
    n = len(B)
    fb = np.zeros(n, bool)
    fs = np.zeros(n, bool)
    sb = max(1, int(cfg["InpSMCSoNenDoDocEMA"]))
    f = ind.get("ema", tf, cfg["InpSMCEMANhanhM5"])
    s = ind.get("ema", tf, cfg["InpSMCEMAChamM5"])
    rsi = ind.get("rsi", tf, cfg["InpSMCRSIPeriod"])
    for c in range(1, n):
        k = c - 1
        cl = B.close[k]
        okb, oks = True, True
        if cfg["InpSMCDungLocEMAM5"]:
            if k - sb < 0:
                continue
            fn, sn, fo, so = f[k], s[k], f[k - sb], s[k - sb]
            okb = cl > max(fn, sn) and (not cfg["InpSMCYeuCauDoDocEMAM5"] or (fn > fo and sn > so))
            oks = cl < min(fn, sn) and (not cfg["InpSMCYeuCauDoDocEMAM5"] or (fn < fo and sn < so))
        if cfg["InpSMCDungLocRSI"]:
            r = rsi[k]
            okb = okb and not (r < cfg["InpSMCRSIMuaToiThieu"])
            oks = oks and not (r > cfg["InpSMCRSIBanToiDa"])
        fb[c], fs[c] = okb, oks
    return fb, fs


def smc_signals(market, ind: IndCache, cfg):
    tf, btf = cfg["InpSMCEntryTF"], cfg["InpSMCBiasTF"]
    B = market.bars(tf)
    BB = market.bars(btf)
    O, H, L, C, T = B.open, B.high, B.low, B.close, B.time
    atr = ind.get("atr", tf, cfg["InpATRPeriod"])
    wing, lb = int(cfg["InpSMCPivotBars"]), int(cfg["InpSMCLookback"])
    need = lb + wing * 2 + 20
    bias_by_bar = _smc_bias_by_bar(market, ind, cfg)
    fb, fs = _smc_filters_by_bar(market, ind, cfg)
    bcur = _bias_tf_cur(market, tf, btf)
    tick = market.tick_size
    st = {"taken": -1, "setup_t": -1}

    def build(c):
        bias = bias_by_bar[bcur[c]]
        if bias == 0:
            return None
        buy = bias > 0
        if not (fb[c] if buy else fs[c]):
            return None
        if c + 1 < need or atr[c - 1] <= 0.0:
            return None
        det = detect_smc_structure(O, H, L, C, c, need, buy, wing, lb, atr[c - 1], cfg["InpSMCDisplacementATR"],
                                   cfg["InpSMCMinFVGATR"], bool(cfg["InpSMCBatBuocFVG"]),
                                   bool(cfg["InpSMCUuTienVungFVG"]), tick)
        if not det[0]:
            return None
        sig_t = int(T[c - det[6]])
        if sig_t <= st["taken"] or sig_t <= st["setup_t"]:
            return None
        st["setup_t"] = sig_t
        stop = det[3] - cfg["InpSMCSLBufferGia"] if buy else det[3] + cfg["InpSMCSLBufferGia"]

        def taken():
            st["taken"] = sig_t
        return {"buy": buy, "zlo": det[1], "zhi": det[2], "stop": stop, "created": sig_t,
                "expiry": int(cfg["InpSMCSetupExpiryBars"]), "model": "SMC-OB" if det[5] == 0 else "SMC-FVG",
                "on_taken": taken}

    ctx = (BB.first.astype(np.int64), bias_by_bar.astype(np.int8), B.first.astype(np.int64), fb, fs)
    return _run_setup_engine(market, cfg, tf, cfg["InpSMCRR"], build, smc_ctx=ctx)
