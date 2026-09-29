"""Write MT5 .set files (UTF-16LE, CRLF, like set4pp_v452.set) for EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.

Every file lists ALL inputs of the EA in declaration order (defaults parsed from the .mq5 source), so loading
it never inherits values left over from an earlier test. Two kinds of files:
  V439_KIEM_CHUNG_<PP>.set   base inputs = rank-1 candidate of results/de_xuat_moi_pp.csv, grid = a small
                             neighbourhood around it (entry TF included); quick to run on months of real ticks
  V439_LUOI_DAY_DU_<PP>.set  the full grid of this study (384-864 input sets); slow
Usage: python3 make_sets.py [--ea /path/EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5]
"""
import argparse
import os
import re
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from grids import GRIDS, mql_grid_string  # noqa: E402
from validate import parse_cfg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "mt5_sets")
EA_DEFAULT = "/home/user/ea-pro/EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5"
TF_CODE = {"CURRENT": 0, "M1": 1, "M2": 2, "M3": 3, "M4": 4, "M5": 5, "M6": 6, "M10": 10, "M12": 12, "M15": 15,
           "M20": 20, "M30": 30, "H1": 16385, "H2": 16386, "H3": 16387, "H4": 16388, "H6": 16390, "H8": 16392,
           "H12": 16396, "D1": 16408, "W1": 32769, "MN1": 49153}
MODULE = {"EMA": "InpUseEMAModule", "ICT": "InpUseICTModule", "MM": "InpUseMMModule", "SMC": "InpUseSMCModule",
          "PVEMA": "InpUsePVEMAModule", "ENG": "InpUseENGModule", "PIN": "InpUsePINModule", "BRK": "InpUseBRKModule",
          "LQ": "InpUseLQModule", "PVT": "InpUsePVTModule"}
GRID_INPUT = {"EMA": "InpLuoiEMA", "ICT": "InpLuoiICT", "MM": "InpLuoiMM", "SMC": "InpLuoiSMC", "PVEMA": "InpLuoiPVEMA",
              "ENG": "InpLuoiENG", "PIN": "InpLuoiPIN", "BRK": "InpLuoiBRK", "LQ": "InpLuoiLQ", "PVT": "InpLuoiPVT"}
# wallet id of the candidate inside xep_hang.csv: wallet 0 = portfolio, base engine = wallets 1..12 (1 + dir*4 + ses)
DIR_ID = {"BUY_SELL": 0, "BUY": 1, "SELL": 2}
SES_ID = {"TAT_CA": 0, "A": 1, "AU": 2, "MY": 3}

# neighbourhood grids around the rank-1 candidate (checked on longer data in MT5)
NEIGHBOUR = {
    "EMA": {"InpTimeframe": ["M1", "M2"], "InpFastEMA": [7, 12], "InpSlowEMA": [34, 50],
            "InpEMAKhungLoc": ["M5", "M15"], "InpMinDirectionEfficiency": [0.10, 0.22]},
    "ICT": {"InpICTEntryTF": ["M1", "M2"], "InpICTBiasTF": ["M15", "M30", "H1"],
            "InpICTDisplacementATR": [0.60, 0.90, 1.20], "InpICTPriority": [0, 2, 3]},
    "SMC": {"InpSMCEntryTF": ["M1", "M2", "M3"], "InpSMCBiasTF": ["M15", "M30"], "InpSMCDisplacementATR": [0.90, 1.20],
            "InpSMCDungLocEMAH1": [True, False], "InpSMCDungLocRSI": [True, False]},
    "PVEMA": {"InpPVKhungVaoLenh": ["M5", "M6", "M10"], "InpPVKhungXuHuong": ["M30", "H1"],
              "InpPVADXToiThieu": [14, 20], "InpPVSoNenTimSL": [5, 10]},
    "PIN": {"InpPVKhungPinBar": ["M1", "M2"], "InpPVRauChinhTrenThan": [2.8, 3.4, 4.0], "InpPVPinQuetSoNen": [3, 6],
            "InpPVSoNenTimSL": [5, 10]},
    "LQ": {"InpPVKhungQuetThanhKhoan": ["M1", "M4"], "InpPVDoXuyenToiThieuGia": [0.5, 0.7],
           "InpPVDoXuyenToiDaGia": [1.0, 2.0], "InpPVSoNenThanhKhoan": [6, 12], "InpPVRauQuetTrenThan": [2.0, 3.0]},
}


def parse_ea_inputs(path):
    """[(kind, name, value_text)] in declaration order; kind 'group' for input groups. Enums -> integers."""
    src = open(path, encoding="utf-8", errors="replace").read()
    enum_vals = {}
    for block in re.finditer(r"enum\s+\w+\s*\{(.*?)\};", src, re.S):
        for mem, num in re.findall(r"(\w+)\s*=\s*(-?\d+)", block.group(1)):
            enum_vals[mem] = int(num)
    items = []
    for line in src.splitlines():
        s = line.strip()
        m = re.match(r'input\s+group\s+"(.*)"', s)
        if m:
            items.append(("group", m.group(1), ""))
            continue
        m = re.match(r"input\s+(\w+)\s+(\w+)\s*=\s*(.*)$", s)
        if not m:
            continue
        typ, name, rest = m.groups()
        if rest.startswith('"'):
            value = rest[1:rest.index('"', 1)]
        else:
            value = rest.split(";", 1)[0].strip()
            if value.startswith("PERIOD_"):
                value = str(TF_CODE[value[len("PERIOD_"):]])
            elif value in enum_vals:
                value = str(enum_vals[value])
        items.append((typ, name, value))
    return items


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str) and v in TF_CODE:
        return str(TF_CODE[v])
    return str(v)


def write_set(path, items, overrides, header):
    names = {n for k, n, _ in items if k != "group"}
    unknown = set(overrides) - names
    if unknown:
        raise KeyError(f"inputs not in the EA: {sorted(unknown)}")
    lines = ["; " + h for h in header]
    for kind, name, value in items:
        if kind == "group":
            lines.append("; " + name)
            continue
        lines.append(f"{name}={val(overrides[name]) if name in overrides else value}")
    with open(path, "w", encoding="utf-16", newline="") as f:
        f.write("\r\n".join(lines) + "\r\n")


def common_overrides(family, grid_text, folder):
    o = {key: fam == family for fam, key in MODULE.items()}
    o.update({key: (grid_text if fam == family else "") for fam, key in GRID_INPUT.items()})
    o.update({"InpMatrixQuetLuoi": True, "InpMatrixTachHuongPhien": True, "InpMatrixToiDaBo": 1024,
              "InpMatrixToiDaVi": 12289, "InpMatrixLenhMoiPP": 1, "InpMatrixThuMuc": folder})
    return o


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ea", default=EA_DEFAULT)
    a = ap.parse_args()
    items = parse_ea_inputs(a.ea)
    os.makedirs(OUT, exist_ok=True)
    tester = ["EA: EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2 (chỉ chạy trong Strategy Tester)",
              "Tester: XAUUSD của sàn đang dùng, Every tick based on real ticks, Execution = No Delay,",
              "tài khoản Hedging, Optimization = Disabled. Kết quả: Common\\Files\\<InpMatrixThuMuc>\\RUN_...\\xep_hang.csv"]
    rec = pd.read_csv(os.path.join(HERE, "results", "de_xuat_moi_pp.csv"))
    for _, r in rec[rec.hang == 1].iterrows():
        fam = r.pp
        if fam not in NEIGHBOUR:
            continue
        n = 1
        for v in NEIGHBOUR[fam].values():
            n *= len(v)
        wallet = 1 + DIR_ID[r.huong] * 4 + SES_ID[r.phien]
        o = common_overrides(fam, mql_grid_string(fam, NEIGHBOUR[fam]), f"DH_V439_KiemChung_{fam}")
        o.update(parse_cfg(fam, r.cau_hinh_ngan))
        write_set(os.path.join(OUT, f"V439_KIEM_CHUNG_{fam}.set"), items, o,
                  [f"KIỂM CHỨNG {fam}: gốc = ứng viên hạng 1 ({r.khung}, {r.huong}/{r.phien}) = ví {wallet} trong "
                   f"xep_hang.csv; lưới lân cận {n} bộ"] + tester)
        print(f"V439_KIEM_CHUNG_{fam}.set: {n} bo, vi ung vien = {wallet}")
    for fam in GRIDS:
        n = 1
        for v in GRIDS[fam].values():
            n *= len(v)
        o = common_overrides(fam, mql_grid_string(fam), f"DH_V439_LuoiDayDu_{fam}")
        write_set(os.path.join(OUT, f"V439_LUOI_DAY_DU_{fam}.set"), items, o,
                  [f"LƯỚI ĐẦY ĐỦ {fam}: {n} bộ, giống nghiên cứu Python; chạy rất lâu"] + tester)
        print(f"V439_LUOI_DAY_DU_{fam}.set: {n} bo")


if __name__ == "__main__":
    main()
