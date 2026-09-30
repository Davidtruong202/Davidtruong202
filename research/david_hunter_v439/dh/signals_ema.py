"""Family 0 (EMA): tick-driven cross + retest, port of Step()/ProcessEMARetestSetup()/EnterOnCross().

EMA values of the forming bar are recomputed on every tick with close = current Bid (MT5 iMA,
shift 0), crosses are detected tick-to-tick, one cross is accepted per bar, and the retest entry
(or the direct cross entry) goes through the wave filter, the M5 bias filter, sessions and SL rules.
"""
import numpy as np
from numba import njit

from .config import session_table
from .mt5ind import IndCache


@njit(cache=True)
def _wave_ok(buy, mid, ignore_recent, b, fast, slow, EF, ES, H, L, C, ATR, use_wave, recent_cross, wave_bars,
             min_wave, min_move, min_eff, outer, max_opp, tick):
    if not use_wave:
        return True
    if b < 1 or ATR[b - 1] <= 0.0:
        return False
    atr = ATR[b - 1]
    if (not ignore_recent) and recent_cross > 0:
        if b - (recent_cross + 1) < 0:
            return False
        for k in range(recent_cross):
            old = EF[b - 2 - k] - ES[b - 2 - k]
            new = EF[b - 1 - k] - ES[b - 1 - k]
            if (old <= 0.0 and new > 0.0) or (old >= 0.0 and new < 0.0):
                return False
    W = wave_bars
    if b - W < 0:
        return False
    hi = mid
    lo = mid
    for s in range(1, W + 1):
        hi = max(hi, H[b - s])
        lo = min(lo, L[b - s])
    signed = mid - C[b - W]
    dmove = (signed if buy else -signed) / atr
    wave = (hi - lo) / atr
    if wave < min_wave or dmove < min_move:
        return False
    path = abs(mid - C[b - 1])
    for s in range(1, W):
        path += abs(C[b - s] - C[b - s - 1])
    eff = abs(signed) / path if path > tick else 0.0
    if min_eff > 0.0 and eff < min_eff:
        return False
    rmid = (hi + lo) * 0.5
    if outer and ((buy and mid <= rmid) or ((not buy) and mid >= rmid)):
        return False
    sb = min(4, W - 1)
    if b - sb < 0:
        return False
    fd = fast - EF[b - sb] if buy else EF[b - sb] - fast
    sd = slow - ES[b - sb] if buy else ES[b - sb] - slow
    if fd <= 0.0 or sd < -max_opp * atr:
        return False
    return True


@njit(cache=True)
def ema_kernel(t, bid, ask, e_first, e_time, H, L, C, EF, ES, ATR, af, as_, b_first, BF, BS, use_bias,
               sl_lb, sl_buf, retest, mode, away_atr, tol, min_wait, expiry, use_wave, recent_cross, wave_bars,
               min_wave, min_move, min_eff, outer, max_opp, sec, ses_tab, rr_tab, outside_rr, use_ses,
               spread_max, min_sl, max_sl, tick, safety, digits):
    n = len(t)
    nb = len(e_first)
    cap = nb + 16
    o_i = np.empty(cap, np.int64)
    o_b = np.empty(cap, np.bool_)
    o_e = np.empty(cap)
    o_sl = np.empty(cap)
    o_tp = np.empty(cap)
    m = 0
    b = 0
    cb = 0
    nbb = len(b_first)
    have_prev = False
    prev = 0.0
    last_sig_t = 0
    s_active = False
    s_buy = True
    s_armed = False
    s_bar_t = 0
    s_max_away = 0.0
    s_last = 0.0
    n_cross = 0
    for i in range(n):
        while b + 1 < nb and e_first[b + 1] <= i:
            b += 1
        while cb + 1 < nbb and b_first[cb + 1] <= i:
            cb += 1
        px = bid[i]
        if b >= 1:
            fast = af * px + (1.0 - af) * EF[b - 1]
            slow = as_ * px + (1.0 - as_) * ES[b - 1]
        else:
            fast = px
            slow = px
        diff = fast - slow
        bias = 0
        bias_ready = cb >= 1
        if bias_ready:
            if BF[cb - 1] > BS[cb - 1]:
                bias = 1
            elif BF[cb - 1] < BS[cb - 1]:
                bias = -1
        hour = (t[i] % 86400) // 3600
        session = ses_tab[hour]
        # ---- cross detection (tick to tick)
        if not have_prev:
            prev = diff
            have_prev = True
        else:
            pdiff = prev
            bx = pdiff <= 0.0 and diff > 0.0
            sx = pdiff >= 0.0 and diff < 0.0
            prev = diff
            if (bx or sx) and last_sig_t != e_time[b]:
                n_cross += 1
                buy = bx
                recent = use_wave and recent_cross > 0 and last_sig_t > 0 and (e_time[b] - last_sig_t) < recent_cross * sec
                bias_ok = True
                if use_bias:
                    bias_ok = bias_ready and ((bias > 0) if buy else (bias < 0))
                if recent or (not bias_ok):
                    s_active = False
                elif retest:
                    s_active = True
                    s_buy = buy
                    s_armed = False
                    s_bar_t = e_time[b]
                    s_max_away = 0.0
                    s_last = bid[i] if buy else ask[i]
                else:
                    # EnterOnCross(buy, false)
                    ok = True
                    if use_ses and session == 0:
                        ok = False
                    if ok and spread_max > 0.0 and ask[i] - bid[i] > spread_max:
                        ok = False
                    if ok and not _wave_ok(buy, (ask[i] + bid[i]) * 0.5, False, b, fast, slow, EF, ES, H, L, C, ATR,
                                           use_wave, recent_cross, wave_bars, min_wave, min_move, min_eff, outer,
                                           max_opp, tick):
                        ok = False
                    if ok and b >= sl_lb:
                        ext = L[b - 1] if buy else H[b - 1]
                        for s in range(2, sl_lb + 1):
                            ext = min(ext, L[b - s]) if buy else max(ext, H[b - s])
                        entry = ask[i] if buy else bid[i]
                        sl = round(np.floor((ext - sl_buf) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((ext + sl_buf) / tick - 1e-9) * tick, digits)
                        good = not ((buy and sl >= entry) or ((not buy) and sl <= entry) or sl <= 0.0)
                        if good:
                            risk = abs(entry - sl)
                            if risk < min_sl:
                                sl = round(np.floor((entry - min_sl) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((entry + min_sl) / tick - 1e-9) * tick, digits)
                                risk = abs(entry - sl)
                            if risk > max_sl + tick * 0.5 or risk < tick:
                                good = False
                        if good and ((buy and sl >= bid[i] - safety) or ((not buy) and sl <= ask[i] + safety)):
                            good = False
                        if good:
                            rr = rr_tab[hour] if session > 0 else outside_rr
                            tp = round(np.ceil((entry + rr * risk) / tick - 1e-9) * tick, digits) if buy else round(np.floor((entry - rr * risk) / tick + 1e-9) * tick, digits)
                            if (buy and tp <= bid[i] + safety) or ((not buy) and tp >= ask[i] - safety):
                                good = False
                            if good and ((buy and tp <= ask[i] + safety) or ((not buy) and tp >= bid[i] - safety)):
                                good = False
                            if good and m < cap:
                                o_i[m] = i
                                o_b[m] = buy
                                o_e[m] = entry
                                o_sl[m] = sl
                                o_tp[m] = tp
                                m += 1
                last_sig_t = e_time[b]
        # ---- retest processing (every tick)
        if retest and s_active:
            buy = s_buy
            if expiry > 0 and t[i] >= s_bar_t + expiry * sec:
                s_active = False
                continue
            intact = fast > slow if buy else fast < slow
            if not intact:
                s_active = False
                continue
            if use_bias:
                if not bias_ready:
                    continue
                if not ((bias > 0) if buy else (bias < 0)):
                    s_active = False
                    continue
            ref = bid[i] if buy else ask[i]
            atr = 1.0
            if away_atr > 0.0:
                if b < 1 or ATR[b - 1] <= 0.0:
                    continue
                atr = ATR[b - 1]
            away = ref - fast if buy else fast - ref
            if away > s_max_away:
                s_max_away = away
            if not s_armed:
                correct = ref > fast if buy else ref < fast
                if correct and away >= away_atr * atr:
                    s_armed = True
                s_last = ref
                continue
            if min_wait > 0 and t[i] < s_bar_t + min_wait * sec:
                s_last = ref
                continue
            if (buy and ref < slow - tol) or ((not buy) and ref > slow + tol):
                s_active = False
                continue
            target = slow if mode == 1 else fast
            tl = abs(ref - target) <= tol
            crossed = False
            if s_last > 0.0:
                if buy:
                    crossed = s_last > target + tol and ref <= target + tol
                else:
                    crossed = s_last < target - tol and ref >= target - tol
            inside = ref >= min(fast, slow) - tol and ref <= max(fast, slow) + tol
            touched = (inside and (tl or crossed)) if mode == 2 else (tl or crossed)
            s_last = ref
            if not touched:
                continue
            # PrepareEMARetestCandidate(): needs SL bars and a valid SL, otherwise keep waiting
            if b < sl_lb:
                continue
            ext = L[b - 1] if buy else H[b - 1]
            for s in range(2, sl_lb + 1):
                ext = min(ext, L[b - s]) if buy else max(ext, H[b - s])
            entry = ask[i] if buy else bid[i]
            sl = round(np.floor((ext - sl_buf) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((ext + sl_buf) / tick - 1e-9) * tick, digits)
            if sl <= 0.0 or (buy and sl >= entry) or ((not buy) and sl <= entry):
                continue
            risk = abs(entry - sl)
            if risk < min_sl:
                sl = round(np.floor((entry - min_sl) / tick + 1e-9) * tick, digits) if buy else round(np.ceil((entry + min_sl) / tick - 1e-9) * tick, digits)
                risk = abs(entry - sl)
            if risk > max_sl + tick * 0.5 or risk < tick:
                continue
            # EnterOnCross(buy, true): bias, session, spread, wave (recent-cross check skipped)
            ok = True
            if use_bias and not (bias_ready and ((bias > 0) if buy else (bias < 0))):
                ok = False
            if ok and use_ses and session == 0:
                ok = False
            if ok and spread_max > 0.0 and ask[i] - bid[i] > spread_max:
                ok = False
            if ok and not _wave_ok(buy, (ask[i] + bid[i]) * 0.5, True, b, fast, slow, EF, ES, H, L, C, ATR, use_wave,
                                   recent_cross, wave_bars, min_wave, min_move, min_eff, outer, max_opp, tick):
                ok = False
            if ok and ((buy and sl >= bid[i] - safety) or ((not buy) and sl <= ask[i] + safety)):
                ok = False
            if ok:
                rr = rr_tab[hour] if session > 0 else outside_rr
                tp = round(np.ceil((entry + rr * risk) / tick - 1e-9) * tick, digits) if buy else round(np.floor((entry - rr * risk) / tick + 1e-9) * tick, digits)
                if (buy and tp <= bid[i] + safety) or ((not buy) and tp >= ask[i] - safety):
                    ok = False
                if ok and ((buy and tp <= ask[i] + safety) or ((not buy) and tp >= bid[i] - safety)):
                    ok = False
                if ok and m < cap:
                    o_i[m] = i
                    o_b[m] = buy
                    o_e[m] = entry
                    o_sl[m] = sl
                    o_tp[m] = tp
                    m += 1
            s_active = False
    return o_i[:m], o_b[:m], o_e[:m], o_sl[:m], o_tp[:m], n_cross


def ema_signals(market, ind: IndCache, cfg):
    tf = cfg["InpTimeframe"]
    btf = cfg["InpEMAKhungLoc"]
    B = market.bars(tf)
    BB = market.bars(btf)
    tk = market.ticks
    ses, rr = session_table(cfg)
    EF = ind.get("ema", tf, cfg["InpFastEMA"])
    ES = ind.get("ema", tf, cfg["InpSlowEMA"])
    ATR = ind.get("atr", tf, cfg["InpATRPeriod"])
    BF = ind.get("ema", btf, cfg["InpEMANhanhLoc"])
    BS = ind.get("ema", btf, cfg["InpEMAChamLoc"])
    i0, buy, entry, sl, tp, n_cross = ema_kernel(
        tk.t, tk.bid, tk.ask, B.first, B.time, B.high, B.low, B.close, EF, ES, ATR,
        2.0 / (cfg["InpFastEMA"] + 1.0), 2.0 / (cfg["InpSlowEMA"] + 1.0), BB.first, BF, BS, bool(cfg["InpEMADungLocM5"]),
        int(cfg["InpSLLookbackBars"]), float(cfg["InpSLBufferGia"]), bool(cfg["InpEMAVaoSauRetest"]),
        int(cfg["InpEMAMucRetest"]), float(cfg["InpEMAKhoangDiXaToiThieuATR"]), float(cfg["InpEMADungSaiRetestGia"]),
        int(cfg["InpEMASoNenChoToiThieu"]), int(cfg["InpEMAHetHanRetestBars"]), bool(cfg["InpUseWaveFilter"]),
        int(cfg["InpRecentCrossBars"]), int(cfg["InpWaveBars"]), float(cfg["InpMinWaveATR"]), float(cfg["InpMinMoveATR"]),
        float(cfg["InpMinDirectionEfficiency"]), bool(cfg["InpRequireOuterHalf"]), float(cfg["InpMaxOpposingSlowSlopeATR"]),
        B.sec, np.array(ses, np.int64), np.array(rr, np.float64), float(cfg["InpEMAOutsideSessionRR"]),
        bool(cfg["InpUseEMASessionFilter"]), float(cfg["InpSpreadToiDaGia"]), float(cfg["InpMinSLPriceDistance"]),
        float(cfg["InpMaxSLPriceDistance"]), market.tick_size, (market.stops_level + 1) * market.point, market.digits)
    return {"i0": i0, "buy": buy, "entry": entry, "sl": sl, "tp": tp, "crosses": int(n_cross)}
