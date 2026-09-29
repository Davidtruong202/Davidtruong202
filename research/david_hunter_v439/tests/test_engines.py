"""Cross-check the fast EMA / ICT / MM / SMC engines and the trade simulator against the literal
tick-by-tick translation in reference_engines.py. Run: python3 tests/test_engines.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import reference_engines as RE  # noqa: E402
from dh import config as C  # noqa: E402
from dh.data import Market, load_ticks  # noqa: E402
from dh.engine import family_signals  # noqa: E402
from dh.mt5ind import IndCache  # noqa: E402
from dh.sim import TradeSimulator  # noqa: E402

TICKS = os.environ.get("DH_TICKS", "/home/user/ea-pro/data/tick/XAUUSDm_2026-01-01_2026-04-30/XAUUSDm_202601012305_202604301458.zip.part*")


def same_signals(fast, ref):
    a = [(int(i), bool(b), round(float(e), 3), round(float(s), 3), round(float(t), 3))
         for i, b, e, s, t in zip(fast["i0"], fast["buy"], fast["entry"], fast["sl"], fast["tp"])]
    b = [(int(i), bool(bb), round(float(e), 3), round(float(s), 3), round(float(t), 3)) for i, bb, e, s, t in ref]
    return a == b, len(a), len(b), [x for x in a if x not in b][:3], [x for x in b if x not in a][:3]


def main():
    t, _ = load_ticks(TICKS, "xauusdm_2026")
    m = Market(t)
    ind = IndCache(m)
    ok = True
    cases = [
        ("ICT", {}), ("ICT", {"InpICTEntryTF": "M1", "InpICTPriority": 1, "InpICTDisplacementATR": 0.9}),
        ("ICT", {"InpICTEntryTF": "M3", "InpICTBiasTF": "M30", "InpICTPriority": 2, "InpICTSetupExpiryBars": 24}),
        ("MM", {}), ("MM", {"InpMMEntryTF": "M5", "InpMMBiasTF": "M30"}),
        ("MM", {"InpMMEntryTF": "M3", "InpMMBiasTF": "H1", "InpMMDisplacementATR": 1.0}),
        ("SMC", {}), ("SMC", {"InpSMCEntryTF": "M1", "InpSMCBiasTF": "M15"}),
        ("SMC", {"InpSMCEntryTF": "M3", "InpSMCBiasTF": "M30", "InpSMCDungLocEMAH1": False, "InpSMCDungLocRSI": False}),
        ("EMA", {}), ("EMA", {"InpEMAVaoSauRetest": False}),
        ("EMA", {"InpTimeframe": "M3", "InpEMAMucRetest": 2, "InpEMAKhoangDiXaToiThieuATR": 1.0, "InpEMASoNenChoToiThieu": 2}),
        ("EMA", {"InpEMAMucRetest": 1, "InpMinDirectionEfficiency": 0.10, "InpEMADungLocM5": False}),
        ("ENG", {}), ("ENG", {"InpPVNhanChimMinATR": 0.9, "InpPVThanNhanChimSoVoiThanTruoc": 1.3}),
        ("PIN", {"InpPVKhungPinBar": "M1", "InpPVPinMinATR": 1.0, "InpPVPinMaxATR": 3.0}),
        ("BRK", {"InpPVSoNenVungBreakout": 8}), ("LQ", {"InpPVKhungQuetThanhKhoan": "M1", "InpPVDoXuyenToiThieuGia": 0.3}),
        ("PVT", {}), ("PVT", {"InpPVKhungXacNhanPivot": "M15", "InpPVMucPivot": 2}),
    ]
    for fam, ov in cases:
        cfg = C.make(ov)
        fast = family_signals(m, ind, cfg, fam)
        if fam == "EMA":
            ref = RE.run_ema(m, ind, cfg)
        elif fam in ("ICT", "MM", "SMC"):
            ref = RE.run_setup_family(m, ind, cfg, fam)
        else:
            ref = RE.run_pv_family(m, ind, cfg, fam)
        same, na, nb, only_a, only_b = same_signals(fast, ref)
        print(f"{fam:4s} {ov}: fast={na} ref={nb} {'OK' if same else 'MISMATCH'} {only_a} {only_b}")
        ok &= same
    # trade manager
    cfg = C.make()
    sim = TradeSimulator(m, cfg)
    sig = family_signals(m, ind, cfg, "BRK")
    res = sim.run(sig)
    tick = m.tick_size
    safety = (m.stops_level + 1) * m.point
    bad = 0
    for k in range(len(sig["i0"])):
        if not res["ok"][k]:
            continue
        j, net, reason = RE.manage_trade(m.ticks.bid, m.ticks.ask, int(sig["i0"][k]), bool(sig["buy"][k]),
                                         float(res["p_entry"][k]), float(sig["sl"][k]), float(res["tp1"][k]),
                                         float(res["tp2"][k]), float(res["risk"][k]), cfg, tick, safety)
        if j != res["exit_i"][k] or abs(net - res["net"][k]) > 1e-9 or reason != res["reason"][k]:
            bad += 1
    print(f"TRADES BRK: {int(res['ok'].sum())} simulated, mismatches={bad}")
    ok &= bad == 0
    print("ALL OK" if ok else "MISMATCH FOUND")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
