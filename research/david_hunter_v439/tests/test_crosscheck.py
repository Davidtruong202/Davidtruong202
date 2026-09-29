"""Cross-check fast signal code against the literal MQL translation in reference.py.

Run: python3 tests/test_crosscheck.py  (needs the tick cache, see README)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import reference as R  # noqa: E402
from dh import config as C  # noqa: E402
from dh import signals_pv as P  # noqa: E402
from dh import signals_setup as S  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402

TICKS = os.environ.get("DH_TICKS", "/home/user/ea-pro/data/tick/XAUUSDm_2026-01-01_2026-04-30/XAUUSDm_202601012305_202604301458.zip.part*")


def first_bid(m, bars, c):
    return m.ticks.bid[bars.first[c]]


def check_pv(m, ind, cfg, family):
    tick = m.tick_size
    mism = 0
    total = 0
    if family == "ENG":
        tf = cfg["InpPVKhungNhanChim"]; b = m.bars(tf); atr = ind.get("atr", tf, cfg["InpPVATRNhanChim"])
        fast = P._dir_eng(b.open, b.high, b.low, b.close, atr, tick, cfg["InpPVNhanChimMinATR"], cfg["InpPVNhanChimMaxATR"],
                          cfg["InpPVThanNhanChimSoVoiThanTruoc"], cfg["InpPVDongCuaManhNhanChim"])
        for c in range(1, len(b)):
            r = R.copy_rates(b, c, 4, first_bid(m, b, c))
            a = R.buf(atr, c, 1)
            ref = 0 if (r is None or a is None or a <= 0) else R.eng(r, a, tick, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    elif family == "PIN":
        tf = cfg["InpPVKhungPinBar"]; b = m.bars(tf); atr = ind.get("atr", tf, cfg["InpPVATRPinBar"])
        fast = P._dir_pin(b.open, b.high, b.low, b.close, atr, tick, cfg["InpPVPinMinATR"], cfg["InpPVPinMaxATR"],
                          cfg["InpPVRauChinhTrenThan"], cfg["InpPVRauDoiDienTrenThan"], cfg["InpPVDongCuaPinTrongBien"],
                          cfg["InpPVPinQuetSoNen"])
        for c in range(1, len(b)):
            r = R.copy_rates(b, c, cfg["InpPVPinQuetSoNen"] + 2, first_bid(m, b, c))
            a = R.buf(atr, c, 1)
            ref = 0 if (r is None or a is None or a <= 0) else R.pin(r, a, tick, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    elif family == "BRK":
        tf = cfg["InpPVKhungBreakout"]; b = m.bars(tf)
        fast = P._dir_brk(b.open, b.high, b.low, b.close, tick, cfg["InpPVSoNenVungBreakout"], cfg["InpPVThanBreakoutToiThieu"],
                          cfg["InpPVDemBreakoutGia"], cfg["InpPVChoRetest"], cfg["InpPVDungSaiRetestGia"])
        for c in range(1, len(b)):
            r = R.copy_rates(b, c, cfg["InpPVSoNenVungBreakout"] + 5, first_bid(m, b, c))
            ref = 0 if r is None else R.brk(r, tick, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    elif family == "LQ":
        tf = cfg["InpPVKhungQuetThanhKhoan"]; b = m.bars(tf)
        fast = P._dir_lq(b.open, b.high, b.low, b.close, tick, cfg["InpPVSoNenThanhKhoan"], cfg["InpPVDoXuyenToiThieuGia"],
                         cfg["InpPVDoXuyenToiDaGia"], cfg["InpPVDongLaiVaoVungGia"], cfg["InpPVRauQuetTrenThan"])
        for c in range(1, len(b)):
            r = R.copy_rates(b, c, cfg["InpPVSoNenThanhKhoan"] + 2, first_bid(m, b, c))
            ref = 0 if r is None else R.lq(r, tick, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    elif family == "PVT":
        tf = cfg["InpPVKhungXacNhanPivot"]; src = cfg["InpPVKhungTinhPivot"]; b = m.bars(tf); sb = m.bars(src)
        cur = P._src_cur(m, tf, src)
        fast = P._dir_pvt(b.open, b.high, b.low, b.close, cur, sb.high, sb.low, sb.close, cfg["InpPVBKPVungPivotGia"],
                          cfg["InpPVYeuCauNenDungHuong"], cfg["InpPVMucPivot"])
        for c in range(1, len(b)):
            bid = first_bid(m, b, c)
            conf = R.copy_rates(b, c, 3, bid)
            s = R.copy_rates(sb, int(cur[c]), 3, bid)
            ref = 0 if (conf is None or s is None) else R.pvt(s, conf, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    elif family == "PVEMA":
        tf = cfg["InpPVKhungVaoLenh"]; ttf = cfg["InpPVKhungXuHuong"]; b = m.bars(tf)
        ef = ind.get("ema", tf, cfg["InpPVEMANhanhVaoLenh"]); es = ind.get("ema", tf, cfg["InpPVEMAChamVaoLenh"])
        atr = ind.get("atr", tf, cfg["InpPVChuKyATR"])
        tfst = ind.get("ema", ttf, cfg["InpPVEMANhanhXuHuong"]); tslw = ind.get("ema", ttf, cfg["InpPVEMAChamXuHuong"])
        adx = ind.get("adx", ttf, cfg["InpPVChuKyADX"])
        cur = P._src_cur(m, tf, ttf)
        need = max(12, cfg["InpPVSoNenKiemTraNhipHoi"] + 4)
        fast = P._dir_pvema(b.open, b.high, b.low, b.close, ef, es, atr, cur, tfst, tslw, adx, tick, need,
                            cfg["InpPVSoNenKiemTraNhipHoi"], cfg["InpPVDungSaiHoiATR"], cfg["InpPVThanNenToiThieu"],
                            cfg["InpPVDoDaiNenToiDaATR"], cfg["InpPVADXToiThieu"])
        for c in range(1, len(b)):
            r = R.copy_rates(b, c, need, first_bid(m, b, c))
            tb = int(cur[c])
            if r is None or tb < 1:
                ref = 0
            else:
                efs = [ef[c - s] for s in range(need)]
                ess = [es[c - s] for s in range(need)]
                ats = [atr[c - s] for s in range(need)]
                ref = 0 if ats[1] <= 0 else R.pvema(r, efs, ess, ats, tfst[tb - 1], tslw[tb - 1], adx[tb - 1], tick, cfg)
            total += ref != 0
            mism += int(ref != fast[c])
    return total, mism


def check_structure(m, ind, cfg, tf, btf, lookback, wing, disp, minfvg):
    B = m.bars(tf)
    BB = m.bars(btf)
    atr = ind.get("atr", tf, cfg["InpATRPeriod"])
    bias_fast = S.structural_bias_series(BB.high, BB.low, BB.close, lookback, wing)
    bcur = m.tick_bar(btf)[B.first]
    need = lookback + wing * 2 + 12
    mism_b = mism_d = tot = 0
    for c in range(1, len(B)):
        bid = first_bid(m, B, c)
        rb = R.structural_bias(BB, int(bcur[c]), lookback, wing, bid)
        mism_b += int(rb != bias_fast[bcur[c]])
        if c + 1 < need or atr[c - 1] <= 0:
            continue
        for buy in (True, False):
            r = R.copy_rates(B, c, need, bid)
            ref = R.detect_sweep_mss_fvg(r, need, buy, wing, lookback, atr[c - 1], disp, minfvg)
            f = S.detect_sweep_mss_fvg(B.open, B.high, B.low, B.close, c, need, buy, wing, lookback, atr[c - 1], disp, minfvg)
            if ref is None:
                mism_d += int(f[0])
                continue
            tot += 1
            same = (f[0] and abs(f[1] - ref["zl"]) < 1e-9 and abs(f[2] - ref["zh"]) < 1e-9 and
                    abs(f[3] - ref["sweep"]) < 1e-9 and abs(f[4] - ref["bbl"]) < 1e-9 and
                    int(B.time[c - f[9]]) == ref["sig_t"])
            mism_d += int(not same)
    return tot, mism_b, mism_d


def main():
    t, _ = load_ticks(TICKS, "xauusdm_2026")
    m = Market(t)
    ind = IndCache(m)
    cases = [
        ("ENG", {}), ("ENG", {"InpPVNhanChimMinATR": 0.9, "InpPVThanNhanChimSoVoiThanTruoc": 1.3, "InpPVKhungNhanChim": "M5"}),
        ("PIN", {}), ("PIN", {"InpPVKhungPinBar": "M1", "InpPVPinMinATR": 1.0, "InpPVPinMaxATR": 3.0, "InpPVPinQuetSoNen": 10}),
        ("BRK", {}), ("BRK", {"InpPVSoNenVungBreakout": 8, "InpPVChoRetest": True}),
        ("LQ", {}), ("LQ", {"InpPVKhungQuetThanhKhoan": "M1", "InpPVDoXuyenToiThieuGia": 0.3, "InpPVDoXuyenToiDaGia": 2.0}),
        ("PVT", {}), ("PVT", {"InpPVKhungXacNhanPivot": "M15", "InpPVMucPivot": 2}),
        ("PVEMA", {}), ("PVEMA", {"InpPVKhungXuHuong": "M30", "InpPVKhungVaoLenh": "M3", "InpPVADXToiThieu": 20}),
    ]
    ok = True
    for fam, ov in cases:
        cfg = C.make(ov)
        total, mism = check_pv(m, ind, cfg, fam)
        print(f"{fam:6s} {ov}: patterns={total} mismatches={mism}")
        ok &= mism == 0
    for tf, btf, lb, w, d, f in [("M5", "M15", 80, 2, 0.6, 0.05), ("M1", "M15", 80, 2, 0.9, 0.10),
                                 ("M15", "H1", 96, 2, 0.7, 0.03)]:
        cfg = C.make()
        tot, mb, md = check_structure(m, ind, cfg, tf, btf, lb, w, d, f)
        print(f"STRUCT {tf}/{btf} lb={lb}: detections={tot} bias_mismatch={mb} detect_mismatch={md}")
        ok &= mb == 0 and md == 0
    print("ALL OK" if ok else "MISMATCH FOUND")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
