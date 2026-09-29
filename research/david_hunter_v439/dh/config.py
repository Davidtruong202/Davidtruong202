"""V4.39 MATRIX default inputs (values copied from the MQL5 source) and LAB constants."""
import copy

FAMILIES = ["EMA", "ICT", "MM", "SMC", "PVEMA", "ENG", "PIN", "BRK", "LQ", "PVT"]
DEPLOYED = {"ENG", "BRK", "PVT"}  # V4.48/V4.52 live: BRK758, PVT880, ENG626, ENG636
NOT_DEPLOYED = ["EMA", "ICT", "MM", "SMC", "PVEMA", "PIN", "LQ"]

BASE = {
    # --- EMA (family 0), tick based cross + retest on InpTimeframe
    "InpTimeframe": "M1", "InpFastEMA": 7, "InpSlowEMA": 34, "InpSLLookbackBars": 5, "InpSLBufferGia": 0.0,
    "InpEMAVaoSauRetest": True, "InpEMAMucRetest": 0, "InpEMAKhoangDiXaToiThieuATR": 0.35,
    "InpEMADungSaiRetestGia": 0.20, "InpEMASoNenChoToiThieu": 0, "InpEMAHetHanRetestBars": 24,
    "InpEMADungLocM5": True, "InpEMAKhungLoc": "M5", "InpEMANhanhLoc": 34, "InpEMAChamLoc": 89,
    "InpUseWaveFilter": True, "InpWaveBars": 12, "InpATRPeriod": 14, "InpMinWaveATR": 2.0, "InpMinMoveATR": 0.65,
    "InpRecentCrossBars": 8, "InpMinDirectionEfficiency": 0.22, "InpRequireOuterHalf": True,
    "InpMaxOpposingSlowSlopeATR": 0.08,
    # --- ICT (family 1)
    "InpICTEntryTF": "M5", "InpICTBiasTF": "M15", "InpICTUse2022": True, "InpICTUseOTE": True,
    "InpICTUseUnicorn": True, "InpICTUseInversion": True, "InpICTPriority": 0, "InpICTLookback": 80,
    "InpICTPivotBars": 2, "InpICTSetupExpiryBars": 12, "InpICTMinFVG_ATR": 0.05, "InpICTDisplacementATR": 0.60,
    "InpICTMinImpulseATR": 1.0, "InpICTOTEHigh": 0.62, "InpICTOTELow": 0.79, "InpICTRR": 2.0,
    "InpICTSLBufferGia": 0.02,
    # --- Market Maker (family 2)
    "InpMMEntryTF": "M15", "InpMMBiasTF": "H1", "InpMMLookback": 96, "InpMMPivotBars": 2, "InpMMRangeBars": 36,
    "InpMMPremiumLevel": 0.62, "InpMMDiscountLevel": 0.38, "InpMMDisplacementATR": 0.70, "InpMMMinFVG_ATR": 0.03,
    "InpMMMaxConsolidationATR": 3.0, "InpMMConsolidationBars": 6, "InpMMModelExpiryBars": 48,
    "InpMMLegSetupExpiryBars": 10, "InpMMLowRiskExpiryBars": 14, "InpMMUseLowRisk": True, "InpMMUseLeg1": True,
    "InpMMUseLeg2": True, "InpMMRR": 2.5, "InpMMSLBufferGia": 0.03,
    # --- SMC (family 3)
    "InpSMCEntryTF": "M5", "InpSMCBiasTF": "H1", "InpSMCLookback": 80, "InpSMCPivotBars": 2,
    "InpSMCSetupExpiryBars": 12, "InpSMCDisplacementATR": 0.60, "InpSMCBatBuocFVG": False,
    "InpSMCUuTienVungFVG": True, "InpSMCMinFVGATR": 0.03, "InpSMCDungLocEMAH1": True, "InpSMCEMANhanhH1": 50,
    "InpSMCEMAChamH1": 200, "InpSMCYeuCauThuTuEMAH1": False, "InpSMCDungLocEMAM5": True, "InpSMCEMANhanhM5": 20,
    "InpSMCEMAChamM5": 50, "InpSMCYeuCauDoDocEMAM5": True, "InpSMCSoNenDoDocEMA": 3, "InpSMCDungLocRSI": True,
    "InpSMCRSIPeriod": 14, "InpSMCRSIMuaToiThieu": 50.0, "InpSMCRSIBanToiDa": 50.0, "InpSMCRR": 2.30,
    "InpSMCSLBufferGia": 0.02,
    # --- EMA/PA/LQ/PVT common (families 4-9)
    "InpPVHuongGiaoDich": 0, "InpPVSoNenTimSL": 5, "InpPVDemSLGia": 1.50, "InpPVTP2R": 2.0, "InpPVRRToiThieu": 1.0,
    "InpPVKhungXuHuong": "H1", "InpPVKhungVaoLenh": "M6", "InpPVEMANhanhXuHuong": 95, "InpPVEMAChamXuHuong": 150,
    "InpPVEMANhanhVaoLenh": 26, "InpPVEMAChamVaoLenh": 29, "InpPVChuKyATR": 30, "InpPVChuKyADX": 21,
    "InpPVADXToiThieu": 14.0, "InpPVSoNenKiemTraNhipHoi": 6, "InpPVDungSaiHoiATR": 0.25,
    "InpPVThanNenToiThieu": 0.30, "InpPVDoDaiNenToiDaATR": 1.80,
    "InpPVKhungNhanChim": "M4", "InpPVATRNhanChim": 13, "InpPVNhanChimMinATR": 1.10, "InpPVNhanChimMaxATR": 1.90,
    "InpPVThanNhanChimSoVoiThanTruoc": 1.0, "InpPVDongCuaManhNhanChim": 0.50,
    "InpPVKhungPinBar": "M4", "InpPVATRPinBar": 10, "InpPVPinMinATR": 1.30, "InpPVPinMaxATR": 1.80,
    "InpPVRauChinhTrenThan": 2.20, "InpPVRauDoiDienTrenThan": 0.70, "InpPVDongCuaPinTrongBien": 0.60,
    "InpPVPinQuetSoNen": 6,
    "InpPVKhungBreakout": "M4", "InpPVThanBreakoutToiThieu": 0.50, "InpPVSoNenVungBreakout": 2,
    "InpPVDemBreakoutGia": 1.00, "InpPVChoRetest": False, "InpPVDungSaiRetestGia": 0.20,
    "InpPVKhungQuetThanhKhoan": "M3", "InpPVSoNenThanhKhoan": 6, "InpPVDoXuyenToiThieuGia": 0.70,
    "InpPVDoXuyenToiDaGia": 1.00, "InpPVDongLaiVaoVungGia": 0.45, "InpPVRauQuetTrenThan": 3.0,
    "InpPVKhungTinhPivot": "M15", "InpPVKhungXacNhanPivot": "M6", "InpPVBKPVungPivotGia": 1.00,
    "InpPVYeuCauNenDungHuong": True, "InpPVMucPivot": 0,
    "InpPVChiTradeTrongGio": False, "InpPVGioBatDau": 7, "InpPVGioKetThuc": 20, "InpPVNgayGiaoDich": 0,
    # --- common money / LAB constants
    "InpSpreadToiDaGia": 0.50, "InpMinSLPriceDistance": 5.0, "InpMaxSLPriceDistance": 20.0,
    "InpUseTP1Partial": True, "InpTP1AtR": 1.0, "InpTP1ClosePct": 50.0, "InpUseTrailing": True,
    "InpTrailStartR": 1.0, "InpTrailDistanceR": 1.0, "InpTrailStepGia": 0.01,
    "InpUseEMASessionFilter": True, "InpUseICTSessionFilter": True, "InpUseMMSessionFilter": True,
    "InpUseSMCSessionFilter": True, "InpEMAOutsideSessionRR": 2.0,
    "InpUseAsia": True, "InpAsiaStart": 0, "InpAsiaEnd": 8, "InpAsiaRR": 1.5,
    "InpUseEurope": True, "InpEuropeStart": 8, "InpEuropeEnd": 16, "InpEuropeRR": 2.0,
    "InpUseAmerica": True, "InpAmericaStart": 16, "InpAmericaEnd": 24, "InpAmericaRR": 2.0,
    "InpGiaTriKhoiLuong": 0.02, "InpMatrixTruotGiaVao": 0.0,
}

# Current live profiles (V4.52 set4pp_v452.set) used as the benchmark.
LIVE_PROFILES = {
    "ENG626": ("ENG", {"InpPVNhanChimMinATR": 0.9, "InpPVThanNhanChimSoVoiThanTruoc": 1.3}, 0, 1),
    "ENG636": ("ENG", {"InpPVNhanChimMinATR": 0.9, "InpPVThanNhanChimSoVoiThanTruoc": 1.3}, 2, 3),
    "BRK758": ("BRK", {"InpPVSoNenVungBreakout": 8, "InpPVChoRetest": False}, 0, 1),
    "PVT880": ("PVT", {"InpPVKhungXacNhanPivot": "M6", "InpPVBKPVungPivotGia": 1.0}, 0, 3),
}

FAMILY_TF_KEY = {"EMA": "InpTimeframe", "ICT": "InpICTEntryTF", "MM": "InpMMEntryTF", "SMC": "InpSMCEntryTF",
                 "PVEMA": "InpPVKhungVaoLenh", "ENG": "InpPVKhungNhanChim", "PIN": "InpPVKhungPinBar",
                 "BRK": "InpPVKhungBreakout", "LQ": "InpPVKhungQuetThanhKhoan", "PVT": "InpPVKhungXacNhanPivot"}


def make(overrides=None):
    c = copy.deepcopy(BASE)
    if overrides:
        for k, v in overrides.items():
            if k not in c:
                raise KeyError("unknown input " + k)
            c[k] = v
    return c


def session_of_hour(cfg, hour):
    """GetSession(): America checked first, then Europe, then Asia; 0 = outside enabled sessions."""
    def inside(h, s, e):
        if s < e:
            return s <= h < e
        if s > e:
            return h >= s or h < e
        return False
    if cfg["InpUseAmerica"] and inside(hour, cfg["InpAmericaStart"], cfg["InpAmericaEnd"]):
        return 3
    if cfg["InpUseEurope"] and inside(hour, cfg["InpEuropeStart"], cfg["InpEuropeEnd"]):
        return 2
    if cfg["InpUseAsia"] and inside(hour, cfg["InpAsiaStart"], cfg["InpAsiaEnd"]):
        return 1
    return 0


def session_table(cfg):
    """Session id (0..3) and session RR for each hour 0..23."""
    ses = [session_of_hour(cfg, h) for h in range(24)]
    rr = {1: cfg["InpAsiaRR"], 2: cfg["InpEuropeRR"], 3: cfg["InpAmericaRR"], 0: 0.0}
    return ses, [rr[s] for s in ses]
