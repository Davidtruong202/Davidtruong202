"""Xuất một dòng trong sets.csv thành file .set MT5 cho V710 (đủ 34 input, đúng thứ tự trong mã nguồn).

python3 write_set.py sets.csv ten_set file_ra.set [Hand_InitLot]
Input không có trong dòng CSV lấy giá trị mặc định của V710 (CHINH_CHU/David_Hunter_EA_V710.mq5).
"""
import sys

import pandas as pd

# (tên, mặc định V710) – đúng thứ tự khai báo input trong mã nguồn
V710_INPUTS = [
    ("InpMagic", "71020001"), ("Hand_FirstDist", "70"), ("Hand_MinDist1", "100"), ("Hand_AddGap1", "110"),
    ("Hand_MinDist2", "140"), ("Hand_AddGap2", "160"), ("Hand_OrderThresh", "6"), ("Hand_MoveStep", "50"),
    ("InpGridAutoScale", "true"), ("Hand_InitLot", "0.01"), ("Hand_AddLotMult", "1.15"), ("Hand_SideTP", "250.0"),
    ("Hand_SideSL", "1000.0"), ("Hand_AllStopLoss", "150.0"), ("Hand_PauseLoss", "1500.0"), ("NetClosePL", "250.0"),
    ("EA_StartTime", "03:00"), ("EA_StopTime", "15:00"), ("InpBasketMaxLoss", "1500.0"), ("InpHardSLATR", "2.5"),
    ("InpHardSLPts", "0"), ("InpFlattenOnClose", "true"), ("InpMaxLayers", "7"), ("InpMaxTotalLots", "0.12"),
    ("InpDailyLossLimit", "1500.0"), ("InpPeakRetracePct", "20.0"), ("InpPreOpenLevels", "true"),
    ("InpSpikeEnable", "true"), ("InpSpikeUSD", "3.0"), ("InpSpikePauseMin", "30"), ("InpSpikeRemovePend", "true"),
    ("EnableCloseButtons", "true"), ("MaxLot", "0.05"), ("DailyProfitTarget", "300.0"),
]
INT_KEYS = {"InpMagic", "Hand_FirstDist", "Hand_MinDist1", "Hand_AddGap1", "Hand_MinDist2", "Hand_AddGap2",
            "Hand_OrderThresh", "Hand_MoveStep", "InpHardSLPts", "InpMaxLayers", "InpSpikePauseMin"}
BOOL_KEYS = {"InpGridAutoScale", "InpFlattenOnClose", "InpPreOpenLevels", "InpSpikeEnable", "InpSpikeRemovePend",
             "EnableCloseButtons"}


def fmt(k, v):
    v = str(v)
    if k in INT_KEYS:
        return str(int(float(v)))
    if k in BOOL_KEYS:
        return "true" if v.lower() in ("true", "1") else "false"
    if k in ("EA_StartTime", "EA_StopTime"):
        return v
    x = float(v)
    return ("%.2f" % x).rstrip("0").rstrip(".") if not x.is_integer() else "%.1f" % x


def write_set(row, path, overrides=None):
    row = dict(row)
    row.update(overrides or {})
    lines = []
    for k, d in V710_INPUTS:
        v = row.get(k, d)
        if v is None or (isinstance(v, float) and pd.isna(v)):
            v = d
        lines.append("%s=%s" % (k, fmt(k, v)))
    with open(path, "w", newline="\r\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    s = pd.read_csv(sys.argv[1], dtype=str).set_index("name")
    ov = {"Hand_InitLot": sys.argv[4]} if len(sys.argv) > 4 else None
    write_set(s.loc[sys.argv[2]].to_dict(), sys.argv[3], ov)
