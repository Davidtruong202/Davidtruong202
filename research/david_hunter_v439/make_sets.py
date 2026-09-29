"""Write MT5 .set files (UTF-16LE, CRLF, like set4pp_v452.set) for EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2:
one file per method; the base inputs are the rank-1 candidate of results/de_xuat_moi_pp.csv and the grid
is a small neighbourhood around it (entry TF included), so it can be re-checked on months of real ticks.
Also writes the full Python grid of each method (same axes as this study) for a complete MT5 re-run.
"""
import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from grids import GRIDS, mql_grid_string  # noqa: E402
from validate import parse_cfg  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "mt5_sets")
TF_CODE = {"M1": 1, "M2": 2, "M3": 3, "M4": 4, "M5": 5, "M6": 6, "M10": 10, "M12": 12, "M15": 15, "M20": 20,
           "M30": 30, "H1": 16385, "H2": 16386, "H4": 16388}
MODULE = {"EMA": "InpUseEMAModule", "ICT": "InpUseICTModule", "MM": "InpUseMMModule", "SMC": "InpUseSMCModule",
          "PVEMA": "InpUsePVEMAModule", "ENG": "InpUseENGModule", "PIN": "InpUsePINModule", "BRK": "InpUseBRKModule",
          "LQ": "InpUseLQModule", "PVT": "InpUsePVTModule"}
GRID_INPUT = {"EMA": "InpLuoiEMA", "ICT": "InpLuoiICT", "MM": "InpLuoiMM", "SMC": "InpLuoiSMC", "PVEMA": "InpLuoiPVEMA",
              "ENG": "InpLuoiENG", "PIN": "InpLuoiPIN", "BRK": "InpLuoiBRK", "LQ": "InpLuoiLQ", "PVT": "InpLuoiPVT"}

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


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str) and v in TF_CODE:
        return str(TF_CODE[v])
    return str(v)


def write_set(path, family, base_inputs, grid_text, folder, title):
    lines = [f"; {title}",
             "; EA: EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2 (chi chay trong Strategy Tester)",
             "; Tester: XAUUSD (sàn Exness), Every tick based on real ticks, Execution = No Delay, tài khoản Hedging",
             "; A. PHƯƠNG PHÁP"]
    for fam, key in MODULE.items():
        lines.append(f"{key}={'true' if fam == family else 'false'}")
    lines.append("InpMaxIndependentPositions=10")
    lines.append("; A. INPUT CỦA PHƯƠNG PHÁP (cấu hình gốc = ứng viên hạng 1)")
    for k, v in base_inputs.items():
        lines.append(f"{k}={val(v)}")
    lines += ["; A. VỐN (giữ như LAB V4.39)", "InpVolumeMode=0", "InpGiaTriKhoiLuong=0.02", "InpSoLenhToiDaMoiNgay=0",
              "InpDailyLossPct=0.0", "InpSpreadToiDaGia=0.5",
              "InpUseAsia=true", "InpAsiaStart=0", "InpAsiaEnd=8", "InpUseEurope=true", "InpEuropeStart=8",
              "InpEuropeEnd=16", "InpUseAmerica=true", "InpAmericaStart=16", "InpAmericaEnd=24",
              "; B. QUÉT LƯỚI", "InpMatrixQuetLuoi=true", "InpMatrixTachHuongPhien=true", "InpMatrixToiDaBo=1024",
              "InpMatrixToiDaVi=12289", "InpMatrixLenhMoiPP=1"]
    for fam, key in GRID_INPUT.items():
        lines.append(f"{key}={grid_text if fam == family else ''}")
    lines += ["; C. VỐN, CHI PHÍ", "InpMatrixLenhTester=true", "InpMatrixViThamChieu=0", "InpMatrixVonMoiVi=0.0",
              "InpMatrixHeSoTienThat=0.0", "InpMatrixPhiKhuHoiLot=0.0", "InpMatrixSwap=0", "InpMatrixSwapBuy=0.0",
              "InpMatrixSwapSell=0.0", "InpMatrixTruotGiaVao=0.0",
              "; D. ĐÁNH GIÁ (đặt InpMatrixTuNgayKiemChung = ngày tách dữ liệu kiểm chứng trong Tester)",
              "InpMatrixSoLenhTinCay=100", "InpMatrixSoThangTinCay=3", "InpMatrixTuNgayKiemChung=0",
              f"InpMatrixThuMuc={folder}", "InpMatrixGhiNenM1=false", "InpMatrixGhiEquityPhut=60",
              "InpMatrixBangNhe=true", "InpGhiTinHieuBiLoai=false"]
    with open(path, "w", encoding="utf-16", newline="") as f:
        f.write("\r\n".join(lines) + "\r\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    rec = pd.read_csv(os.path.join(HERE, "results", "de_xuat_moi_pp.csv"))
    top = rec[rec.hang == 1]
    for _, r in top.iterrows():
        fam = r.pp
        if fam not in NEIGHBOUR:
            continue
        base = parse_cfg(fam, r.cau_hinh_ngan)
        grid = mql_grid_string(fam, NEIGHBOUR[fam])
        n = 1
        for v in NEIGHBOUR[fam].values():
            n *= len(v)
        write_set(os.path.join(OUT, f"V439_KIEM_CHUNG_{fam}.set"), fam, base, grid,
                  f"DH_V439_KiemChung_{fam}",
                  f"KIỂM CHỨNG {fam}: gốc = ứng viên hạng 1 ({r.khung} {r.huong}/{r.phien}), lưới lân cận {n} bộ")
    for fam in GRIDS:
        from dh.config import BASE
        base = {k: BASE[k] for k in GRIDS[fam]}
        n = 1
        for v in GRIDS[fam].values():
            n *= len(v)
        write_set(os.path.join(OUT, f"V439_LUOI_DAY_DU_{fam}.set"), fam, base, mql_grid_string(fam),
                  f"DH_V439_LuoiDayDu_{fam}", f"LƯỚI ĐẦY ĐỦ {fam}: {n} bộ (giống nghiên cứu Python) - chạy rất lâu")
    for fn in sorted(os.listdir(OUT)):
        print(fn)


if __name__ == "__main__":
    main()
