"""Build EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5: a copy of V4.39 MATRIX RECONCILE 2 whose new input
"InpMatrixBoCaiSan" carries the 13 test presets that used to be .set files (candidate base inputs,
neighbourhood grids, full grids). Choosing "BO_THEO_INPUT" gives exactly the original behaviour.
Trading logic, trade management, wallets and exported files are untouched; only the Matrix set-up
(which families run, their base inputs, their grid, limits and log folder) reads the preset.
Preset BO_HIEU_QUA_NHAT (the default) runs ONE input set: rank 1 of sang_loc_mt5.py on the 9-month MT5 run.
Its wallet is also the native reference, so the Tester report, graph and deals are exactly that input.

Usage: python3 make_ea_7pp.py [--ea path/to/EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5] [--out path]
Every text patch must match exactly once, otherwise the script stops.
"""
import argparse
import os
import sys

import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from grids import GRIDS, mql_grid_string  # noqa: E402
from make_sets import DIR_ID, NEIGHBOUR, SES_ID  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FAM_ID = {"EMA": 0, "ICT": 1, "MM": 2, "SMC": 3, "PVEMA": 4, "ENG": 5, "PIN": 6, "BRK": 7, "LQ": 8, "PVT": 9}
CHECK = ["EMA", "ICT", "SMC", "PVEMA", "PIN", "LQ"]          # families with a candidate (MM has none)
FULL = ["EMA", "ICT", "MM", "SMC", "PVEMA", "PIN", "LQ"]


def n_sets(grid):
    n = 1
    for v in grid.values():
        n *= len(v)
    return n


def patch(src, old, new):
    if src.count(old) != 1:
        raise SystemExit(f"patch target found {src.count(old)} times: {old[:80]!r}")
    return src.replace(old, new)


def best_input(base_text):
    """Rank 1 of results_mt5/sang_loc_9_thang.csv: (family, dir, ses, full base text, row)."""
    s = pd.read_csv(os.path.join(HERE, "results_mt5", "sang_loc_9_thang.csv.gz"))
    r = s[s.hang == 1].iloc[0]
    kv = dict(item.split("=", 1) for item in base_text(r.phuong_phap).split("|"))
    for item in r.cau_hinh.split(" | "):
        k, v = item.split("=", 1)
        kv[k] = v
    return r.phuong_phap, DIR_ID[r.huong], SES_ID[r.phien], "|".join(f"{k}={v}" for k, v in kv.items()), r


def build(ea_path, out_path):
    src = open(ea_path, encoding="utf-8-sig").read()
    rec = pd.read_csv(os.path.join(HERE, "results", "de_xuat_moi_pp.csv"))
    rec = rec[rec.hang == 1].set_index("pp")
    chk = pd.read_csv(os.path.join(HERE, "results", "kiem_dinh_ung_vien.csv")).set_index("ma")

    near_n = {f: n_sets(NEIGHBOUR[f]) for f in CHECK}
    full_n = {f: n_sets(GRIDS[f]) for f in FULL}
    members = [("BO_THEO_INPUT", "Thủ công: dùng các input bên dưới (y hệt V4.39 gốc)"),
               ("BO_KIEM_CHUNG_6PP", f"Kiểm chứng 6 PP cùng lúc: {', '.join(CHECK)} ({sum(near_n.values())} bộ)")]
    members += [(f"BO_KIEM_CHUNG_{f}", f"Kiểm chứng riêng {f} ({near_n[f]} bộ)") for f in CHECK]
    members += [(f"BO_LUOI_DAY_DU_{f}", f"Lưới đầy đủ {f} ({full_n[f]} bộ, chạy rất lâu)") for f in FULL]

    def base_text(f):
        return rec.loc[f, "cau_hinh_ngan"].replace(" | ", "|")

    best_f, best_d, best_s, best_text, best = best_input(base_text)
    best_wallet = 1 + best_d * 4 + best_s  # the preset has one engine: wallets 1..12 after portfolio wallet 0
    members.append(("BO_HIEU_QUA_NHAT", f"Bộ hiệu quả nhất 9 tháng: {best_f} {best.huong}/{best.phien}, "
                                        f"{best.cau_hinh.replace(' | ', ', ')} (ví {best_wallet} = Graph)"))
    enum_lines = [f"   {name} = {i}{',' if i < len(members) - 1 else ''} // {text}" for i, (name, text) in enumerate(members)]
    enum = ("\nenum ENUM_MATRIX_BO_CAI_SAN\n{\n" + "\n".join(enum_lines) + "\n};\n")

    lines = ["// ---------- V4.39 MATRIX 7PP: bộ cài sẵn thay cho 13 file SET ----------",
             "// Ứng viên hạng 1 và lưới lấy từ nghiên cứu Python (docs/david_hunter_v439 trong repo Davidtruong202).",
             "bool MXPresetActive() { return InpMatrixBoCaiSan!=BO_THEO_INPUT; }",
             "bool MXPresetFull() { return InpMatrixBoCaiSan>=BO_LUOI_DAY_DU_EMA && InpMatrixBoCaiSan<=BO_LUOI_DAY_DU_LQ; }",
             "bool MXPresetBest() { return InpMatrixBoCaiSan==BO_HIEU_QUA_NHAT; }",
             "int MXPresetFamily()",
             "{",
             "   switch(InpMatrixBoCaiSan)",
             "   {",
             f"      case BO_HIEU_QUA_NHAT: return {FAM_ID[best_f]};"]
    for f in FULL:
        labels = ([f"case BO_KIEM_CHUNG_{f}:"] if f in CHECK else []) + [f"case BO_LUOI_DAY_DU_{f}:"]
        lines.append(f"      {' '.join(labels)} return {FAM_ID[f]};")
    lines += ["   }", "   return -1;", "}",
              "bool MXPresetUses(const int f)",
              "{",
              "   if(InpMatrixBoCaiSan==BO_KIEM_CHUNG_6PP)",
              "      return " + " || ".join(f"f=={FAM_ID[f]}" for f in CHECK) + ";",
              "   return f==MXPresetFamily();",
              "}",
              "// Input gốc của từng PP khi kiểm chứng = ứng viên hạng 1; lưới đầy đủ giữ input mặc định V4.39.",
              "string MXPresetBase(const int f)",
              "{",
              "   if(!MXPresetActive() || MXPresetFull()) return \"\";",
              f"   if(MXPresetBest()) return f=={FAM_ID[best_f]}?\"{best_text}\":\"\"; // {best_f} bộ hiệu quả nhất"]
    for f in CHECK:
        lines.append(f"   if(f=={FAM_ID[f]}) return \"{base_text(f)}\"; // {f}")
    lines += ["   return \"\";", "}",
              "string MXPresetGrid(const int f)",
              "{",
              "   if(!MXPresetUses(f) || MXPresetBest()) return \"\"; // bộ hiệu quả nhất: 1 bộ, không lưới",
              "   if(MXPresetFull())",
              "   {"]
    for f in FULL:
        lines.append(f"      if(f=={FAM_ID[f]}) return \"{mql_grid_string(f)}\"; // {f}")
    lines += ["      return \"\";", "   }"]
    for f in CHECK:
        lines.append(f"   if(f=={FAM_ID[f]}) return \"{mql_grid_string(f, NEIGHBOUR[f])}\"; // {f}")
    lines += ["   return \"\";", "}",
              "// Ví của ứng viên trong 12 ví của bộ gốc: d = 0 cả 2 hướng / 1 BUY / 2 SELL; s = 0 cả ngày / 1 Á / 2 Âu / 3 Mỹ.",
              "bool MXPresetWallet(const int f,int &d,int &s)",
              "{",
              "   d=0; s=0;",
              "   if(!MXPresetActive() || MXPresetFull()) return false;",
              f"   if(MXPresetBest()) {{ d={best_d}; s={best_s}; return f=={FAM_ID[best_f]}; }} // {best.huong}/{best.phien}"]
    for f in CHECK:
        d, s = DIR_ID[rec.loc[f, "huong"]], SES_ID[rec.loc[f, "phien"]]
        lines.append(f"   if(f=={FAM_ID[f]}) {{ d={d}; s={s}; return true; }} // {f} {rec.loc[f, 'huong']}/{rec.loc[f, 'phien']}")
    lines += ["   return false;", "}",
              "string MXPresetPython(const int f)",
              "{",
              f"   if(MXPresetBest()) return \"MT5 01/01-27/09/2026 vi {int(best.wallet_id)}: {int(best.lenh)} lenh, "
              f"WR {best.wr:.1f}%, PF {best.profit_factor:.2f}, net {best.net:+.1f} USD lot 0.02, lai {int(best.thang_lai)}/9 thang\";"]
    for f in CHECK:
        r = chk.loc[f"{f}#1"]
        lines.append(f"   if(f=={FAM_ID[f]}) return \"Python 01-12/01/2026: {int(r.lenh)} lenh, WR {r.wr:.1f}%, PF {r.pf:.2f}, "
                     f"net {r.net:+.1f} USD lot 0.02\"; // {f}")
    lines += ["   return \"\";", "}",
              "string MXPresetFolder()",
              "{",
              "   switch(InpMatrixBoCaiSan)",
              "   {",
              "      case BO_KIEM_CHUNG_6PP: return \"DH_V439_7PP_KiemChung_6PP\";",
              "      case BO_HIEU_QUA_NHAT: return \"DH_V439_7PP_HieuQuaNhat\";"]
    for f in CHECK:
        lines.append(f"      case BO_KIEM_CHUNG_{f}: return \"DH_V439_7PP_KiemChung_{f}\";")
    for f in FULL:
        lines.append(f"      case BO_LUOI_DAY_DU_{f}: return \"DH_V439_7PP_LuoiDayDu_{f}\";")
    lines += ["   }", "   return InpMatrixThuMuc;", "}",
              "int MXMaxBo() { return MXPresetActive()?1024:InpMatrixToiDaBo; }",
              "int MXMaxVi() { return MXPresetActive()?12289:InpMatrixToiDaVi; }",
              "bool MXQuetLuoi() { return MXPresetActive() || InpMatrixQuetLuoi; }",
              "bool MXTachHuongPhien() { return MXPresetActive() || InpMatrixTachHuongPhien; }",
              "// Ghi input gốc của bộ cài sẵn vào cấu hình gốc của PP, cùng bộ đọc với lưới (MXNumber + MatrixSetValue).",
              "bool MXApplyPresetBase(MatrixConfig &c,const int family)",
              "{",
              "   string text=MXTrim(MXPresetBase(family));",
              "   if(text==\"\") return true;",
              "   string items[]; int count=StringSplit(text,'|',items);",
              "   for(int i=0;i<count;i++)",
              "   {",
              "      string kv[]; double v=0.0;",
              "      if(StringSplit(items[i],'=',kv)!=2 || !MXNumber(kv[1],v) || !MatrixSetValue(c,MXTrim(kv[0]),v))",
              "         {MXFail(\"Bộ cài sẵn có input không hợp lệ: \"+items[i]);return false;}",
              "   }",
              "   return true;",
              "}",
              ""]
    preset_funcs = "\n".join(lines) + "\n"

    summary = '''   if(MXPresetActive() && !MXPresetFull())
   {
      // V4.39 MATRIX 7PP: một dòng cho ví ứng viên của mỗi PP, để đọc nhanh không cần lọc xep_hang.
      int hc=MXFile("ket_qua_ung_vien","phuong_phap;wallet_id;huong;phien;input_goc_ung_vien;lenh_dong;lenh_thang;winrate_pct;profit_factor;net;dd_equity_pct;thua_lien_tiep;thang_lai;so_thang;holdout_n;holdout_net;danh_gia;so_sanh_python;tien_te");
      if(hc!=INVALID_HANDLE)
      {
         for(int e=0;e<ArraySize(g_engines);e++)
         {
            int d=0,s=0,f=g_engines[e].family;
            if(!g_engines[e].isBase || !MXPresetWallet(f,d,s)) continue;
            int w=g_walletStart[e]+(MXTachHuongPhien()?d*4+s:0);
            if(w<0 || w>=ArraySize(g_wallets)) continue;
            MXWallet p=g_wallets[w];
            FileWrite(hc,MXFamily(f),w,MXDirection(p.direction),MXSession(p.session),MXPresetBase(f),
               p.all.trades,p.all.wins,MXMoney(MXWR(p.all)),MXMoney(MXPF(p.all)),MXMoney(p.all.net),MXMoney(p.ddPct),
               p.all.maxStreak,MXPositiveMonths(w),ArraySize(g_monthKeys),p.holdout.trades,MXMoney(p.holdout.net),
               MXQualification(w),MXPresetPython(f),g_currency);
         }
         FileClose(hc);
      }
   }
'''

    header_old = ("// David Hunter V4.39 MATRIX - research only, Strategy Tester only.\n"
                  "// Independent entry engines, independent wallets, ONE fixed native reference.\n"
                  "// No live trading. No hindsight switching. No artificial SL slippage cap.\n")
    header_new = ("// David Hunter V4.39 MATRIX 7PP - research only, Strategy Tester only.\n"
                  "// Independent entry engines, independent wallets, ONE fixed native reference.\n"
                  "// No live trading. No hindsight switching. No artificial SL slippage cap.\n"
                  "// V4.39 MATRIX 7PP = bản sao V4.39 MATRIX RECONCILE 2 + input \"0. BỘ CÀI SẴN\" chứa sẵn 13 bộ test\n"
                  "// (kiểm chứng ứng viên + lưới đầy đủ) của 7 PP chưa triển khai: EMA, ICT, MM, SMC, PVEMA, PIN, LQ.\n"
                  f"// Mặc định: BỘ HIỆU QUẢ NHẤT ({best_f} {best.huong}/{best.phien}, sàng lọc 2.568 ví MT5 9 tháng), bấm Start là chạy;\n"
                  "// Graph và lệnh Tester = đúng bộ đó. Kiểm chứng 6 PP / lưới đầy đủ: chọn trong input 0. \"Thủ công\" = y hệt bản gốc.\n"
                  "// Không đổi thuật toán vào lệnh, quản lý lệnh, mô phỏng ví hay định dạng file xuất.\n")
    src = patch(src, header_old, header_new)
    src = patch(src, "   SETUP_ENGINE_SMC = 2\n};\n", "   SETUP_ENGINE_SMC = 2\n};\n" + enum)
    src = patch(src, 'input group "A. ĐIỀU KIỆN GỐC VÀ QUẢN LÝ VỐN"\n',
                'input group "0. BỘ CÀI SẴN: CHỌN LÀ CHẠY, KHÔNG CẦN FILE SET"\n'
                'input ENUM_MATRIX_BO_CAI_SAN InpMatrixBoCaiSan = BO_HIEU_QUA_NHAT; '
                '// Bộ cài sẵn (khác Thủ công: bỏ qua input bật PP, lưới, giới hạn và thư mục log bên dưới)\n'
                'input group "A. ĐIỀU KIỆN GỐC VÀ QUẢN LÝ VỐN"\n')
    src = patch(src, "void MXOneFamily(MatrixConfig &c,const int family)\n",
                preset_funcs + "void MXOneFamily(MatrixConfig &c,const int family)\n")
    src = patch(src, "bool MXEnabled(const int f)\n{\n",
                "bool MXEnabled(const int f)\n{\n   if(MXPresetActive()) return MXPresetUses(f);\n")
    src = patch(src, "string MXGrid(const int f)\n{\n",
                "string MXGrid(const int f)\n{\n   if(MXPresetActive()) return MXPresetGrid(f);\n")
    src = patch(src, "if(w>=InpMatrixToiDaVi)", "if(w>=MXMaxVi())")
    src = patch(src, "if(n>=InpMatrixToiDaBo)", "if(n>=MXMaxBo())")
    src = patch(src, "for(int d=0;d<(InpMatrixTachHuongPhien?3:1);d++)", "for(int d=0;d<(MXTachHuongPhien()?3:1);d++)")
    src = patch(src, "for(int s=0;s<(InpMatrixTachHuongPhien?4:1);s++)", "for(int s=0;s<(MXTachHuongPhien()?4:1);s++)")
    src = patch(src, "   MatrixConfig base=g_base; MXOneFamily(base,family);\n",
                "   MatrixConfig base=g_base; MXOneFamily(base,family);\n"
                "   if(!MXApplyPresetBase(base,family)) return false;\n")
    src = patch(src, "if(!InpMatrixQuetLuoi || MXTrim(MXGrid(family))==\"\") return true;",
                "if(!MXQuetLuoi() || MXTrim(MXGrid(family))==\"\") return true;")
    src = patch(src, "if(combinations>InpMatrixToiDaBo)", "if(combinations>MXMaxBo())")
    src = patch(src, '      FileClose(h);\n   }\n   h=MXFile("lenh_tham_chieu_MT5",',
                '      FileClose(h);\n   }\n' + summary + '   h=MXFile("lenh_tham_chieu_MT5",')
    src = patch(src, 'FileWrite(h,"version","4.39");',
                'FileWrite(h,"version","4.39 MATRIX 7PP"); FileWrite(h,"preset",EnumToString(InpMatrixBoCaiSan));')
    src = patch(src, 'FileWrite(h,"split_direction_session",InpMatrixTachHuongPhien);',
                'FileWrite(h,"split_direction_session",MXTachHuongPhien());')
    src = patch(src, 'FileWrite(h,"grid_enabled",InpMatrixQuetLuoi);', 'FileWrite(h,"grid_enabled",MXQuetLuoi());')
    src = patch(src, "string parent=MXTrim(InpMatrixThuMuc);",
                "string parent=MXTrim(MXPresetActive()?MXPresetFolder():InpMatrixThuMuc);")
    src = patch(src, '   Print("V4.39 MATRIX | ",ArraySize(g_engines)',
                '   Print("V4.39 MATRIX 7PP | Bộ cài sẵn: ",EnumToString(InpMatrixBoCaiSan),\n'
                '         MXPresetActive()?" | bỏ qua input bật PP/lưới/giới hạn/thư mục":" | theo input thủ công");\n'
                '   Print("V4.39 MATRIX | ",ArraySize(g_engines)')
    # native reference wallet: the chosen wallet for BO_HIEU_QUA_NHAT, else the input (0 = portfolio of base engines)
    decl = "input int InpMatrixViThamChieu = 0; // ID tài khoản vẽ Graph; 0=bộ gốc gộp các PP, không đổi giữa lượt\n"
    head, tail = src.split(decl)
    if "InpMatrixViThamChieu" in head:
        raise SystemExit("InpMatrixViThamChieu used before its declaration")
    n_use = tail.count("InpMatrixViThamChieu")
    tail = tail.replace("InpMatrixViThamChieu", "MXViThamChieu()")
    src = head + decl.replace("không đổi giữa lượt", f"không đổi giữa lượt; Bộ hiệu quả nhất tự dùng ví {best_wallet}") + tail
    last_input = "input bool InpMatrixBangNhe = true; // Bảng trạng thái nhỏ, chỉ trong Visual Tester\n"
    src = patch(src, last_input, last_input + "\n// V4.39 MATRIX 7PP: ví đặt lệnh tham chiếu thật (Graph). Bộ hiệu quả nhất = ví của đúng bộ đó.\n"
                f"int MXViThamChieu() {{ return InpMatrixBoCaiSan==BO_HIEU_QUA_NHAT?{best_wallet}:InpMatrixViThamChieu; }}\n")
    print(f"bo hieu qua nhat: {best_f} {best.huong}/{best.phien} {best_text} | vi tham chieu {best_wallet} | "
          f"{n_use} cho dung vi tham chieu")
    with open(out_path, "w", encoding="utf-8-sig", newline="\n") as f:
        f.write(src)
    return src


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ea", default="/home/user/ea-pro/EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5")
    ap.add_argument("--out", default=os.path.join(REPO, "MQL5", "Experts", "EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5"))
    a = ap.parse_args()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    build(a.ea, a.out)
    print("written", a.out)


if __name__ == "__main__":
    main()
