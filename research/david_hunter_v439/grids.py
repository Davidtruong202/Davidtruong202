"""Input x timeframe grids for the methods NOT deployed in V4.48/V4.52 (EMA, ICT, MM, SMC, PVEMA, PIN, LQ),
plus the four live profiles as the benchmark. Axis names are the exact V4.39 input names, so every
grid maps 1:1 onto an InpLuoi... string of EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5.
"""
from dh.data import TF_SECONDS

GRIDS = {
    "EMA": {
        "InpTimeframe": ["M1", "M2", "M3", "M5"],
        "InpFastEMA": [7, 12],
        "InpSlowEMA": [21, 34, 50],
        "InpEMAKhungLoc": ["M5", "M15"],
        "InpEMAKhoangDiXaToiThieuATR": [0.35, 1.0],
        "InpMinDirectionEfficiency": [0.10, 0.22],
        "InpEMAMucRetest": [0, 1],
    },
    "ICT": {
        "InpICTEntryTF": ["M1", "M2", "M3", "M5", "M15"],
        "InpICTBiasTF": ["M15", "M30", "H1"],
        "InpICTDisplacementATR": [0.60, 0.90, 1.20],
        "InpICTMinFVG_ATR": [0.05, 0.10],
        "InpICTPriority": [0, 1, 2, 3],
        "InpICTSetupExpiryBars": [12, 24],
    },
    "MM": {
        "InpMMEntryTF": ["M1", "M3", "M5", "M15"],
        "InpMMBiasTF": ["M30", "H1"],
        "InpMMDisplacementATR": [0.70, 1.00, 1.30],
        "InpMMMinFVG_ATR": [0.03, 0.08],
        "InpMMPremiumLevel": [0.62, 0.70],
        "InpMMDiscountLevel": [0.30, 0.38],
        "InpMMUseLeg1": [True, False],
    },
    "SMC": {
        "InpSMCEntryTF": ["M1", "M2", "M3", "M5", "M15"],
        "InpSMCBiasTF": ["M15", "M30", "H1"],
        "InpSMCDisplacementATR": [0.60, 0.90, 1.20],
        "InpSMCMinFVGATR": [0.03, 0.08],
        "InpSMCDungLocEMAH1": [True, False],
        "InpSMCDungLocEMAM5": [True, False],
        "InpSMCDungLocRSI": [True, False],
    },
    "PVEMA": {
        "InpPVKhungVaoLenh": ["M3", "M4", "M5", "M6", "M10", "M15"],
        "InpPVKhungXuHuong": ["M15", "M30", "H1"],
        "InpPVADXToiThieu": [14, 20, 25],
        "InpPVSoNenTimSL": [5, 10],
        "InpPVDungSaiHoiATR": [0.25, 0.50],
        "InpPVThanNenToiThieu": [0.30, 0.50],
    },
    "PIN": {
        "InpPVKhungPinBar": ["M1", "M2", "M3", "M4", "M5", "M6", "M10", "M15"],
        "InpPVRauChinhTrenThan": [1.8, 2.2, 2.8, 3.4],
        "InpPVPinQuetSoNen": [3, 6, 10],
        "InpPVPinMinATR": [1.0, 1.3],
        "InpPVPinMaxATR": [1.8, 2.5],
        "InpPVSoNenTimSL": [5, 10],
    },
    "LQ": {
        "InpPVKhungQuetThanhKhoan": ["M1", "M2", "M3", "M4", "M5", "M6", "M10", "M15"],
        "InpPVDoXuyenToiThieuGia": [0.3, 0.5, 0.7],
        "InpPVDoXuyenToiDaGia": [1.0, 2.0, 3.0],
        "InpPVSoNenThanhKhoan": [6, 12],
        "InpPVRauQuetTrenThan": [1.5, 2.0, 3.0],
        "InpPVSoNenTimSL": [5, 10],
    },
}

# Combinations that make no sense are skipped (the MQL grid would still run them).
BIAS_KEYS = {"ICT": ("InpICTEntryTF", "InpICTBiasTF"), "MM": ("InpMMEntryTF", "InpMMBiasTF"),
             "SMC": ("InpSMCEntryTF", "InpSMCBiasTF"), "PVEMA": ("InpPVKhungVaoLenh", "InpPVKhungXuHuong"),
             "EMA": ("InpTimeframe", "InpEMAKhungLoc")}


def valid(family, cfg):
    if family == "EMA" and cfg["InpFastEMA"] >= cfg["InpSlowEMA"]:
        return False
    if family in BIAS_KEYS:
        e, b = BIAS_KEYS[family]
        if TF_SECONDS[cfg[b]] < TF_SECONDS[cfg[e]]:
            return False
    if family == "LQ" and cfg["InpPVDoXuyenToiThieuGia"] >= cfg["InpPVDoXuyenToiDaGia"]:
        return False
    if family == "PIN" and cfg["InpPVPinMinATR"] >= cfg["InpPVPinMaxATR"]:
        return False
    return True


def mql_grid_string(family, grid=None):
    """InpLuoi<family> string for the V4.39 MATRIX EA (axes joined by |, values by ,)."""
    g = grid or GRIDS[family]
    parts = []
    for k, vals in g.items():
        txt = []
        for v in vals:
            if isinstance(v, bool):
                txt.append("true" if v else "false")
            elif isinstance(v, float):
                txt.append(("%.2f" % v).rstrip("0").rstrip(".") if v != int(v) else "%.1f" % v)
            else:
                txt.append(str(v))
        parts.append(k + "=" + ",".join(txt))
    return "|".join(parts)
