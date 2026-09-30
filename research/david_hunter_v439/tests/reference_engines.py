"""Literal tick-by-tick re-translation of Step()/ScheduledStep()/TryEnterSetup(), the EMA module and
MXUpdatePositions(). Pure Python and slow; only used to cross-check dh/*.
"""
import math

import numpy as np

import reference as R
from dh.config import session_table


def price_down(v, tick):
    return round(math.floor(v / tick + 1e-9) * tick, 6)


def price_up(v, tick):
    return round(math.ceil(v / tick - 1e-9) * tick, 6)


def normalize_sl(buy, entry, sl, cfg, tick):
    if entry <= 0 or sl <= 0 or (buy and sl >= entry) or (not buy and sl <= entry):
        return None
    risk = abs(entry - sl)
    if risk < cfg["InpMinSLPriceDistance"]:
        sl = price_down(entry - cfg["InpMinSLPriceDistance"], tick) if buy else price_up(entry + cfg["InpMinSLPriceDistance"], tick)
        risk = abs(entry - sl)
    if risk > cfg["InpMaxSLPriceDistance"] + tick * 0.5 or risk < tick:
        return None
    return sl


class TickClock:
    """Maps a tick to the forming bar index of any timeframe (bars must come from the same ticks)."""

    def __init__(self, m):
        self.m = m

    def cur(self, tf, i):
        return int(self.m.tick_bar(tf)[i])


def matrix_ok(buy, entry, sl, tp, bid, ask, cfg, tick, safety):
    risk = abs(entry - sl)
    if risk < cfg["InpMinSLPriceDistance"] - tick * 0.5 or risk > cfg["InpMaxSLPriceDistance"] + tick * 0.5:
        return False
    if buy and (sl >= bid - safety or tp <= ask + safety):
        return False
    if (not buy) and (sl <= ask + safety or tp >= bid - safety):
        return False
    return not (cfg["InpSpreadToiDaGia"] > 0 and ask - bid > cfg["InpSpreadToiDaGia"])


def run_setup_family(m, ind, cfg, family, max_ticks=None):
    """Literal ICT / MM / SMC engine. Returns list of (tick, buy, entry, sl, tp)."""
    tk = m.ticks
    tick = m.tick_size
    safety = (m.stops_level + 1) * m.point
    clock = TickClock(m)
    key = {"ICT": ("InpICTEntryTF", "InpICTBiasTF"), "MM": ("InpMMEntryTF", "InpMMBiasTF"),
           "SMC": ("InpSMCEntryTF", "InpSMCBiasTF")}[family]
    tf, btf = cfg[key[0]], cfg[key[1]]
    B = m.bars(tf)
    BB = m.bars(btf)
    sec = B.sec
    atr = ind.get("atr", tf, cfg["InpATRPeriod"])
    rr = {"ICT": cfg["InpICTRR"], "MM": cfg["InpMMRR"], "SMC": cfg["InpSMCRR"]}[family]
    n = len(tk) if max_ticks is None else min(max_ticks, len(tk))
    setup = None
    last_taken = -1
    last_setup_t = -1
    ctx = {"active": False, "buy": True, "leg": 0, "rev": 0, "inv": 0.0}
    last_bar = int(B.time[clock.cur(tf, 0)])
    next_wake = 0
    out = []

    def smc_bias(i):
        cb = clock.cur(btf, i)
        if not cfg["InpSMCDungLocEMAH1"]:
            return R.structural_bias(BB, cb, cfg["InpSMCLookback"], cfg["InpSMCPivotBars"], tk.bid[i])
        if cb < 1:
            return 0
        f = ind.get("ema", btf, cfg["InpSMCEMANhanhH1"])[cb - 1]
        s = ind.get("ema", btf, cfg["InpSMCEMAChamH1"])[cb - 1]
        close = BB.close[cb - 1]
        buy = close > max(f, s)
        sell = close < min(f, s)
        if cfg["InpSMCYeuCauThuTuEMAH1"]:
            buy = buy and f > s
            sell = sell and f < s
        return 0 if buy == sell else (1 if buy else -1)

    def smc_filter(buy, i):
        c = clock.cur(tf, i)
        if c < 1:
            return False
        close = B.close[c - 1]
        if cfg["InpSMCDungLocEMAM5"]:
            sb = max(1, cfg["InpSMCSoNenDoDocEMA"])
            if c - 1 - sb < 0:
                return False
            f = ind.get("ema", tf, cfg["InpSMCEMANhanhM5"])
            s = ind.get("ema", tf, cfg["InpSMCEMAChamM5"])
            fn, sn, fo, so = f[c - 1], s[c - 1], f[c - 1 - sb], s[c - 1 - sb]
            side = close > max(fn, sn) if buy else close < min(fn, sn)
            slope = (fn > fo and sn > so) if buy else (fn < fo and sn < so)
            if not side or (cfg["InpSMCYeuCauDoDocEMAM5"] and not slope):
                return False
        if cfg["InpSMCDungLocRSI"]:
            v = ind.get("rsi", tf, cfg["InpSMCRSIPeriod"])[c - 1]
            if (buy and v < cfg["InpSMCRSIMuaToiThieu"]) or (not buy and v > cfg["InpSMCRSIBanToiDa"]):
                return False
        return True

    def build(i):
        nonlocal last_setup_t
        c = clock.cur(tf, i)
        bid = tk.bid[i]
        now = int(tk.t[i])
        if family == "ICT":
            bias = R.structural_bias(BB, clock.cur(btf, i), cfg["InpICTLookback"], cfg["InpICTPivotBars"], bid)
            if bias == 0:
                return None
            need = cfg["InpICTLookback"] + cfg["InpICTPivotBars"] * 2 + 12
            r = R.copy_rates(B, c, need, bid)
            if r is None or c < 1 or atr[c - 1] <= 0:
                return None
            buy = bias > 0
            d = R.detect_sweep_mss_fvg(r, need, buy, cfg["InpICTPivotBars"], cfg["InpICTLookback"], atr[c - 1],
                                       cfg["InpICTDisplacementATR"], cfg["InpICTMinFVG_ATR"])
            if d is None or d["sig_t"] <= last_taken or d["sig_t"] <= last_setup_t:
                return None
            from dh.signals_setup import _select_ict_model, detect_sweep_mss_fvg
            det = detect_sweep_mss_fvg(B.open, B.high, B.low, B.close, c, need, buy, cfg["InpICTPivotBars"],
                                       cfg["InpICTLookback"], atr[c - 1], cfg["InpICTDisplacementATR"], cfg["InpICTMinFVG_ATR"])
            sel = _select_ict_model(cfg, buy, B.open, B.high, B.low, B.close, B.time, c, need, atr[c - 1], det, tick)
            if sel is None:
                return None
            last_setup_t = d["sig_t"]
            stop = d["sweep"] - cfg["InpICTSLBufferGia"] if buy else d["sweep"] + cfg["InpICTSLBufferGia"]
            return dict(buy=buy, zl=sel[0], zh=sel[1], stop=stop, created=d["sig_t"], exp=cfg["InpICTSetupExpiryBars"])
        if family == "SMC":
            bias = smc_bias(i)
            if bias == 0:
                return None
            buy = bias > 0
            if not smc_filter(buy, i):
                return None
            need = cfg["InpSMCLookback"] + cfg["InpSMCPivotBars"] * 2 + 20
            if c + 1 < need or atr[c - 1] <= 0:
                return None
            from dh.signals_setup import detect_smc_structure
            d = detect_smc_structure(B.open, B.high, B.low, B.close, c, need, buy, cfg["InpSMCPivotBars"],
                                     cfg["InpSMCLookback"], atr[c - 1], cfg["InpSMCDisplacementATR"], cfg["InpSMCMinFVGATR"],
                                     cfg["InpSMCBatBuocFVG"], cfg["InpSMCUuTienVungFVG"], tick)
            if not d[0]:
                return None
            sig_t = int(B.time[c - d[6]])
            if sig_t <= last_taken or sig_t <= last_setup_t:
                return None
            last_setup_t = sig_t
            stop = d[3] - cfg["InpSMCSLBufferGia"] if buy else d[3] + cfg["InpSMCSLBufferGia"]
            return dict(buy=buy, zl=d[1], zh=d[2], stop=stop, created=sig_t, exp=cfg["InpSMCSetupExpiryBars"])
        # MM
        need = cfg["InpMMLookback"] + cfg["InpMMPivotBars"] * 2 + 12
        r = R.copy_rates(B, c, need, bid)
        if r is None or c < 1 or atr[c - 1] <= 0:
            return None
        a = atr[c - 1]
        if ctx["active"]:
            if (ctx["buy"] and r.l[1] <= ctx["inv"]) or (not ctx["buy"] and r.h[1] >= ctx["inv"]):
                ctx["active"] = False
            if ctx["active"] and now > ctx["rev"] + cfg["InpMMModelExpiryBars"] * sec:
                ctx["active"] = False
            elif ctx["active"] and ctx["leg"] <= 2 and ((ctx["leg"] == 1 and cfg["InpMMUseLeg1"]) or (ctx["leg"] == 2 and cfg["InpMMUseLeg2"])):
                nc = cfg["InpMMConsolidationBars"]
                hi, lo = r.h[2], r.l[2]
                for s in range(3, nc + 2):
                    hi = max(hi, r.h[s]); lo = min(lo, r.l[s])
                okc = hi - lo <= cfg["InpMMMaxConsolidationATR"] * a
                body = abs(r.c[1] - r.o[1])
                buy = ctx["buy"]
                brk = r.c[1] > hi if buy else r.c[1] < lo
                res = None
                if okc and brk and body >= cfg["InpMMDisplacementATR"] * a:
                    if buy and r.l[1] > r.h[3]:
                        res = (r.h[3], r.l[1], lo)
                    if (not buy) and r.l[3] > r.h[1]:
                        res = (r.h[1], r.l[3], hi)
                if res is not None:
                    if int(r.t[1]) <= last_setup_t:
                        return None
                    last_setup_t = int(r.t[1])
                    stop = res[2] - cfg["InpMMSLBufferGia"] if buy else res[2] + cfg["InpMMSLBufferGia"]
                    return dict(buy=buy, zl=min(res[0], res[1]), zh=max(res[0], res[1]), stop=stop,
                                created=int(r.t[1]), exp=cfg["InpMMLegSetupExpiryBars"])
        if not cfg["InpMMUseLowRisk"]:
            return None
        hr = R.copy_rates(BB, clock.cur(btf, i), cfg["InpMMRangeBars"] + 2, bid)
        if hr is None:
            return None
        lo = min(hr.l[1:cfg["InpMMRangeBars"] + 1]); hi = max(hr.h[1:cfg["InpMMRangeBars"] + 1])
        if not hi > lo:
            return None
        prem = lo + (hi - lo) * cfg["InpMMPremiumLevel"]
        disc = lo + (hi - lo) * cfg["InpMMDiscountLevel"]
        for buy in (True, False):
            d = R.detect_sweep_mss_fvg(r, need, buy, cfg["InpMMPivotBars"], cfg["InpMMLookback"], a,
                                       cfg["InpMMDisplacementATR"], cfg["InpMMMinFVG_ATR"])
            if d is None or d["sig_t"] <= last_taken or d["sig_t"] <= last_setup_t:
                continue
            if (buy and d["sweep"] > disc) or (not buy and d["sweep"] < prem):
                continue
            zl = max(min(d["zl"], d["zh"]), min(d["bbl"], d["bbh"]))
            zh = min(max(d["zl"], d["zh"]), max(d["bbl"], d["bbh"]))
            if not zh > zl + tick * 0.25:
                zl, zh = d["zl"], d["zh"]
            stop = d["sweep"] - cfg["InpMMSLBufferGia"] if buy else d["sweep"] + cfg["InpMMSLBufferGia"]
            last_setup_t = d["sig_t"]
            ctx.update(active=True, buy=buy, leg=1, rev=d["sig_t"], inv=stop)
            return dict(buy=buy, zl=min(zl, zh), zh=max(zl, zh), stop=stop, created=d["sig_t"], exp=cfg["InpMMLowRiskExpiryBars"])
        return None

    for i in range(n):
        now = int(tk.t[i])
        active = setup is not None
        if not active and now < next_wake:
            continue
        # ---- Step()
        c = clock.cur(tf, i)
        bar_t = int(B.time[c])
        if bar_t != last_bar:
            last_bar = bar_t
            if setup is None or now > setup["created"] + setup["exp"] * sec:
                s = build(i)
                if s is not None:
                    setup = s
        if setup is not None:
            s = setup
            if now > s["created"] + s["exp"] * sec:
                setup = None
            elif (s["buy"] and tk.bid[i] <= s["stop"]) or ((not s["buy"]) and tk.ask[i] >= s["stop"]):
                setup = None
            else:
                entry = tk.ask[i] if s["buy"] else tk.bid[i]
                if s["zl"] - tick <= entry <= s["zh"] + tick:
                    proceed = True
                    if family == "SMC":
                        if smc_bias(i) != (1 if s["buy"] else -1):
                            setup = None
                            proceed = False
                        elif not smc_filter(s["buy"], i):
                            proceed = False
                    if proceed:
                        sl = price_down(s["stop"], tick) if s["buy"] else price_up(s["stop"], tick)
                        sl = normalize_sl(s["buy"], entry, sl, cfg, tick)
                        if sl is None:
                            setup = None
                        else:
                            risk = abs(entry - sl)
                            tp = price_up(entry + rr * risk, tick) if s["buy"] else price_down(entry - rr * risk, tick)
                            if matrix_ok(s["buy"], entry, sl, tp, tk.bid[i], tk.ask[i], cfg, tick, safety):
                                out.append((i, s["buy"], entry, sl, tp))
                            last_taken = s["created"]
                            setup = None
        next_wake = bar_t + sec
    return out


def run_ema(m, ind, cfg, max_ticks=None):
    """Literal EMA module (Step + ProcessEMARetestSetup + EnterOnCross + WaveIsStrongEnough)."""
    tk = m.ticks
    tick = m.tick_size
    safety = (m.stops_level + 1) * m.point
    tf, btf = cfg["InpTimeframe"], cfg["InpEMAKhungLoc"]
    B = m.bars(tf)
    sec = B.sec
    EF = ind.get("ema", tf, cfg["InpFastEMA"]); ES = ind.get("ema", tf, cfg["InpSlowEMA"])
    ATR = ind.get("atr", tf, cfg["InpATRPeriod"])
    BF = ind.get("ema", btf, cfg["InpEMANhanhLoc"]); BS = ind.get("ema", btf, cfg["InpEMAChamLoc"])
    af = 2.0 / (cfg["InpFastEMA"] + 1.0); as_ = 2.0 / (cfg["InpSlowEMA"] + 1.0)
    ses, rrt = session_table(cfg)
    tb = m.tick_bar(tf); tbb = m.tick_bar(btf)
    n = len(tk) if max_ticks is None else min(max_ticks, len(tk))
    out = []
    st = dict(have=False, prev=0.0, last_sig=0)
    S = dict(active=False)

    def cur_ema(b, px):
        if b >= 1:
            return af * px + (1 - af) * EF[b - 1], as_ * px + (1 - as_) * ES[b - 1]
        return px, px

    def bias_allows(buy, i):
        if not cfg["InpEMADungLocM5"]:
            return True
        cb = int(tbb[i])
        if cb < 1:
            return False
        f, s = BF[cb - 1], BS[cb - 1]
        bias = 1 if f > s else (-1 if f < s else 0)
        return bias > 0 if buy else bias < 0

    def wave(buy, mid, ignore_recent, b, fast, slow):
        if not cfg["InpUseWaveFilter"]:
            return True
        if b < 1 or ATR[b - 1] <= 0:
            return False
        a = ATR[b - 1]
        N = cfg["InpRecentCrossBars"]
        if not ignore_recent and N > 0:
            if b - (N + 1) < 0:
                return False
            fs = [EF[b - 1 - k] for k in range(N + 1)]
            ss = [ES[b - 1 - k] for k in range(N + 1)]
            for k in range(N):
                old = fs[k + 1] - ss[k + 1]; new = fs[k] - ss[k]
                if (old <= 0 and new > 0) or (old >= 0 and new < 0):
                    return False
        W = cfg["InpWaveBars"]
        if b - W < 0:
            return False
        r = [(B.high[b - 1 - k], B.low[b - 1 - k], B.close[b - 1 - k]) for k in range(W)]
        hi = mid; lo = mid
        for x in r:
            hi = max(hi, x[0]); lo = min(lo, x[1])
        signed = mid - r[W - 1][2]
        dm = (signed if buy else -signed) / a
        wv = (hi - lo) / a
        if wv < cfg["InpMinWaveATR"] or dm < cfg["InpMinMoveATR"]:
            return False
        path = abs(mid - r[0][2])
        for k in range(W - 1):
            path += abs(r[k][2] - r[k + 1][2])
        eff = abs(signed) / path if path > tick else 0.0
        if cfg["InpMinDirectionEfficiency"] > 0 and eff < cfg["InpMinDirectionEfficiency"]:
            return False
        rm = (hi + lo) * 0.5
        if cfg["InpRequireOuterHalf"] and ((buy and mid <= rm) or (not buy and mid >= rm)):
            return False
        sb = min(4, W - 1)
        if b - sb < 0:
            return False
        fsl = [fast] + [EF[b - k] for k in range(1, sb + 1)]
        ssl = [slow] + [ES[b - k] for k in range(1, sb + 1)]
        fd = fsl[0] - fsl[sb] if buy else fsl[sb] - fsl[0]
        sd = ssl[0] - ssl[sb] if buy else ssl[sb] - ssl[0]
        return not (fd <= 0 or sd < -cfg["InpMaxOpposingSlowSlopeATR"] * a)

    def enter(buy, retest, i, b, fast, slow):
        if not bias_allows(buy, i):
            return
        hour = (int(tk.t[i]) % 86400) // 3600
        session = ses[hour]
        if cfg["InpUseEMASessionFilter"] and session == 0:
            return
        if cfg["InpSpreadToiDaGia"] > 0 and tk.ask[i] - tk.bid[i] > cfg["InpSpreadToiDaGia"]:
            return
        if not wave(buy, (tk.ask[i] + tk.bid[i]) * 0.5, retest, b, fast, slow):
            return
        L = cfg["InpSLLookbackBars"]
        if b - L < 0:
            return
        ext = min(B.low[b - L:b]) if buy else max(B.high[b - L:b])
        entry = tk.ask[i] if buy else tk.bid[i]
        sl = price_down(ext - cfg["InpSLBufferGia"], tick) if buy else price_up(ext + cfg["InpSLBufferGia"], tick)
        sl = normalize_sl(buy, entry, sl, cfg, tick)
        if sl is None:
            return
        risk = abs(entry - sl)
        if (buy and sl >= tk.bid[i] - safety) or (not buy and sl <= tk.ask[i] + safety):
            return
        rr = rrt[hour] if session > 0 else cfg["InpEMAOutsideSessionRR"]
        tp = price_up(entry + rr * risk, tick) if buy else price_down(entry - rr * risk, tick)
        if (buy and tp <= tk.bid[i] + safety) or (not buy and tp >= tk.ask[i] - safety):
            return
        if matrix_ok(buy, entry, sl, tp, tk.bid[i], tk.ask[i], cfg, tick, safety):
            out.append((i, buy, entry, sl, tp))

    for i in range(n):
        b = int(tb[i])
        fast, slow = cur_ema(b, tk.bid[i])
        diff = fast - slow
        bar_t = int(B.time[b])
        if not st["have"]:
            st["prev"] = diff; st["have"] = True
        else:
            pdv = st["prev"]
            bx = pdv <= 0 and diff > 0
            sx = pdv >= 0 and diff < 0
            st["prev"] = diff
            if (bx or sx) and st["last_sig"] != bar_t:
                recent = (cfg["InpUseWaveFilter"] and cfg["InpRecentCrossBars"] > 0 and st["last_sig"] > 0 and
                          bar_t - st["last_sig"] < cfg["InpRecentCrossBars"] * sec)
                ok = bias_allows(bx, i)
                if recent or not ok:
                    S = dict(active=False)
                elif cfg["InpEMAVaoSauRetest"]:
                    S = dict(active=True, buy=bx, armed=False, bar_t=bar_t, max_away=0.0,
                             last=tk.bid[i] if bx else tk.ask[i])
                else:
                    enter(bx, False, i, b, fast, slow)
                st["last_sig"] = bar_t
        if cfg["InpEMAVaoSauRetest"] and S["active"]:
            buy = S["buy"]
            if cfg["InpEMAHetHanRetestBars"] > 0 and tk.t[i] >= S["bar_t"] + cfg["InpEMAHetHanRetestBars"] * sec:
                S = dict(active=False); continue
            if not (fast > slow if buy else fast < slow):
                S = dict(active=False); continue
            if cfg["InpEMADungLocM5"]:
                cb = int(tbb[i])
                if cb < 1:
                    continue
                f, s = BF[cb - 1], BS[cb - 1]
                bias = 1 if f > s else (-1 if f < s else 0)
                if not (bias > 0 if buy else bias < 0):
                    S = dict(active=False); continue
            ref = tk.bid[i] if buy else tk.ask[i]
            a = 1.0
            if cfg["InpEMAKhoangDiXaToiThieuATR"] > 0:
                if b < 1 or ATR[b - 1] <= 0:
                    continue
                a = ATR[b - 1]
            away = ref - fast if buy else fast - ref
            S["max_away"] = max(S["max_away"], away)
            if not S["armed"]:
                if (ref > fast if buy else ref < fast) and away >= cfg["InpEMAKhoangDiXaToiThieuATR"] * a:
                    S["armed"] = True
                S["last"] = ref
                continue
            if cfg["InpEMASoNenChoToiThieu"] > 0 and tk.t[i] < S["bar_t"] + cfg["InpEMASoNenChoToiThieu"] * sec:
                S["last"] = ref; continue
            tol = cfg["InpEMADungSaiRetestGia"]
            if (buy and ref < slow - tol) or (not buy and ref > slow + tol):
                S = dict(active=False); continue
            target = slow if cfg["InpEMAMucRetest"] == 1 else fast
            tl = abs(ref - target) <= tol
            cr = False
            if S["last"] > 0:
                cr = (S["last"] > target + tol and ref <= target + tol) if buy else (S["last"] < target - tol and ref >= target - tol)
            inside = min(fast, slow) - tol <= ref <= max(fast, slow) + tol
            touched = (inside and (tl or cr)) if cfg["InpEMAMucRetest"] == 2 else (tl or cr)
            S["last"] = ref
            if not touched:
                continue
            L = cfg["InpSLLookbackBars"]
            if b - L < 0:
                continue
            ext = min(B.low[b - L:b]) if buy else max(B.high[b - L:b])
            entry = tk.ask[i] if buy else tk.bid[i]
            sl = price_down(ext - cfg["InpSLBufferGia"], tick) if buy else price_up(ext + cfg["InpSLBufferGia"], tick)
            if normalize_sl(buy, entry, sl, cfg, tick) is None:
                continue
            enter(buy, True, i, b, fast, slow)
            S = dict(active=False)
    return out


def manage_trade(bid, ask, i0, buy, entry, sl, tp1, tp2, risk, cfg, tick, safety):
    """Literal MXUpdatePositions() for one position (lot fractions: 0.5 at TP1)."""
    left = 1.0
    net = 0.0
    partial = False
    for i in range(i0 + 1, len(bid)):
        price = bid[i] if buy else ask[i]
        fav = price - entry if buy else entry - price
        if (price <= sl) if buy else (price >= sl):
            return i, net + left * fav, 0
        if (price >= tp2) if buy else (price <= tp2):
            return i, net + left * fav, 1
        if not partial and ((price >= tp1) if buy else (price <= tp1)):
            net += 0.5 * fav
            left -= 0.5
            partial = True
            sl = entry
        if fav >= cfg["InpTrailStartR"] * risk:
            nxt = max(entry, price - cfg["InpTrailDistanceR"] * risk) if buy else min(entry, price + cfg["InpTrailDistanceR"] * risk)
            nxt = math.floor(nxt / tick + 1e-8) * tick if buy else math.ceil(nxt / tick - 1e-8) * tick
            if buy and nxt > sl + cfg["InpTrailStepGia"] and nxt < price - safety and nxt < tp2:
                sl = nxt
            if (not buy) and nxt < sl - cfg["InpTrailStepGia"] and nxt > price + safety and nxt > tp2:
                sl = nxt
    price = bid[-1] if buy else ask[-1]
    return len(bid) - 1, net + left * ((price - entry) if buy else (entry - price)), 2


def run_pv_family(m, ind, cfg, family):
    """Literal ProcessAdditionalSignals() + EnterPVSignal() for one PV family."""
    tk = m.ticks
    tick = m.tick_size
    safety = (m.stops_level + 1) * m.point
    tfkey = {"PVEMA": "InpPVKhungVaoLenh", "ENG": "InpPVKhungNhanChim", "PIN": "InpPVKhungPinBar",
             "BRK": "InpPVKhungBreakout", "LQ": "InpPVKhungQuetThanhKhoan", "PVT": "InpPVKhungXacNhanPivot"}[family]
    tf = cfg[tfkey]
    B = m.bars(tf)
    out = []
    for c in range(1, len(B)):
        i = int(B.first[c])
        bid = tk.bid[i]
        d = 0
        if family == "ENG":
            r = R.copy_rates(B, c, 4, bid); a = R.buf(ind.get("atr", tf, cfg["InpPVATRNhanChim"]), c, 1)
            d = 0 if (r is None or a is None or a <= 0) else R.eng(r, a, tick, cfg)
        elif family == "PIN":
            r = R.copy_rates(B, c, cfg["InpPVPinQuetSoNen"] + 2, bid); a = R.buf(ind.get("atr", tf, cfg["InpPVATRPinBar"]), c, 1)
            d = 0 if (r is None or a is None or a <= 0) else R.pin(r, a, tick, cfg)
        elif family == "BRK":
            r = R.copy_rates(B, c, cfg["InpPVSoNenVungBreakout"] + 5, bid)
            d = 0 if r is None else R.brk(r, tick, cfg)
        elif family == "LQ":
            r = R.copy_rates(B, c, cfg["InpPVSoNenThanhKhoan"] + 2, bid)
            d = 0 if r is None else R.lq(r, tick, cfg)
        elif family == "PVT":
            sb = m.bars(cfg["InpPVKhungTinhPivot"])
            s = R.copy_rates(sb, int(m.tick_bar(cfg["InpPVKhungTinhPivot"])[i]), 3, bid)
            conf = R.copy_rates(B, c, 3, bid)
            d = 0 if (s is None or conf is None) else R.pvt(s, conf, cfg)
        else:
            continue  # PVEMA direction is cross-checked in test_crosscheck.py
        if d == 0:
            continue
        buy = d > 0
        entry = tk.ask[i] if buy else tk.bid[i]
        L = cfg["InpPVSoNenTimSL"]
        if c - L < 0:
            continue
        ext = min(B.low[c - L:c]) if buy else max(B.high[c - L:c])
        sl = price_down(ext - cfg["InpPVDemSLGia"], tick) if buy else price_up(ext + cfg["InpPVDemSLGia"], tick)
        sl = normalize_sl(buy, entry, sl, cfg, tick)
        if sl is None:
            continue
        risk = abs(entry - sl)
        tp2 = price_up(entry + cfg["InpPVTP2R"] * risk, tick) if buy else price_down(entry - cfg["InpPVTP2R"] * risk, tick)
        dow = (int(tk.t[i]) // 86400 + 4) % 7
        if dow in (0, 6):
            continue
        if cfg["InpSpreadToiDaGia"] > 0 and tk.ask[i] - tk.bid[i] > cfg["InpSpreadToiDaGia"]:
            continue
        if risk < tick or risk > cfg["InpMaxSLPriceDistance"] or (buy and sl >= tk.bid[i] - safety) or (not buy and sl <= tk.ask[i] + safety):
            continue
        if (buy and tp2 <= tk.ask[i] + safety) or (not buy and tp2 >= tk.bid[i] - safety):
            continue
        if matrix_ok(buy, entry, sl, tp2, tk.bid[i], tk.ask[i], cfg, tick, safety):
            out.append((i, buy, entry, sl, tp2))
    return out
