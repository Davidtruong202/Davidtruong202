"""Phoenix Grid – Bước R0.1: đọc file thông số do script MT5 `PG_R01_DocThongSo.mq5` xuất ra.

Việc làm:
  - Lập bảng thông số tài khoản/symbol.
  - Xác minh giả định H_K (0,01 lot XAUUSDc lãi/lỗ 1 USC cho mỗi 1 USD/oz) bằng hai cách độc lập:
    tick value và OrderCalcProfit.
  - Tính lại các con số nền của kế hoạch với thông số thật: lỗ của lot tối thiểu khi giá đi ngược 20/50/100 USD
    (theo một hoặc nhiều mức vốn), swap mỗi đêm, margin từng chân, dự trữ margin phòng thủ.
  - Kiểm tra các điều kiện kế hoạch cần và in nhận định tự động (đòn bẩy, stop out, chế độ khớp…).

Không phải backtest. Không bịa thông số: mọi giá trị lấy từ file CSV của MT5.

Chạy:
  python3 doc_thong_so.py --file PG_R01_thong_so_XAUUSDc_<ngày>.csv \
      [--spread-gio PG_R01_spread_theo_gio_XAUUSDc_<ngày>.csv] [--von 5000 50] [--out results_r01]
  python3 doc_thong_so.py --tu-kiem-tra      # tự kiểm tra code bằng dữ liệu giả lập trong bộ nhớ (không ghi file)
"""
import argparse
import os

import pandas as pd

VON_MAC_DINH = [5000.0]  # vốn nghiên cứu (đơn vị tiền tài khoản)
KAPPA = 1.5              # hệ số dự trữ margin phòng thủ (Mục 8.2 d của kế hoạch)
DON_BAY_KHONG_GIOI_HAN = 100_000_000


def read_spec(text):
    """Đọc CSV khoa;gia_tri;ghi_chu. Tách tối đa 2 lần ở ';' để chịu được ghi chú có dấu ';'
    (script 0.10 ghi một số ghi chú có ';' — đã sửa ở script 0.11)."""
    spec, notes = {}, {}
    lines = text.splitlines()
    if not lines or not lines[0].startswith("khoa;"):
        raise ValueError("không phải file thông số PG-R0.1 (dòng đầu phải là 'khoa;gia_tri;ghi_chu')")
    for line in lines[1:]:
        if not line.strip():
            continue
        parts = line.split(";", 2)
        key = parts[0].strip()
        spec[key] = parts[1].strip() if len(parts) > 1 else ""
        notes[key] = parts[2].strip() if len(parts) > 2 else ""
    return spec, notes


def num(spec, key):
    try:
        return float(spec[key])
    except (KeyError, ValueError):
        return None


def auto_notes(spec, deals):
    """Nhận định tự động từ thông số — mỗi dòng là một điểm cần lưu ý cho kế hoạch."""
    out = []
    cur = spec.get("account_currency", "?")
    if cur != "USC":
        out.append(f"Tiền tài khoản là **{cur}**, không phải USC → đây không phải tài khoản Standard Cent. "
                   f"Symbol `{spec.get('symbol', '?')}` (đường dẫn `{spec.get('symbol_path', '?')}`).")
    lev = num(spec, "account_leverage")
    if lev is not None and lev >= DON_BAY_KHONG_GIOI_HAN:
        out.append(f"Đòn bẩy {lev:,.0f} (không giới hạn): `OrderCalcMargin` gần như bằng 0, nên điều kiện margin "
                   "của RiskGate (Mục 8.2 d) luôn đạt và không còn tác dụng bảo vệ.")
    so = num(spec, "account_margin_so_so")
    if so is not None and so <= 0:
        out.append(f"Stop out {so:g}%, margin call {spec.get('account_margin_so_call', '?')}%: sàn gần như không cắt "
                   "lỗ trước khi Equity về 0 → giới hạn của EA là lớp bảo vệ duy nhất.")
    fill = num(spec, "filling_mode_flags")
    if fill is not None:
        modes = [n for n, bit in (("FOK", 1), ("IOC", 2)) if int(fill) & bit]
        if modes == ["FOK"]:
            out.append("Chỉ hỗ trợ khớp **FOK** → module khớp lệnh phải dùng ORDER_FILLING_FOK (tự nhận diện).")
    if num(spec, "margin_hedged") == 0 and spec.get("margin_hedged_use_leg") == "false":
        out.append("MARGIN_HEDGED = 0: theo quy tắc cơ bản của MT5, phần khối lượng đã cặp hóa BUY/SELL không "
                   "tính margin. Cần xác nhận bằng số đo tay trên demo (Bước B).")
    if spec.get("account_trade_expert") == "false":
        out.append("ACCOUNT_TRADE_EXPERT = false: tài khoản đang báo EA không được phép giao dịch. Bật nút Algo "
                   "Trading rồi chạy lại script; nếu vẫn false thì tài khoản không cho EA giao dịch.")
    pos, pend = spec.get("so_vi_the_dang_mo"), spec.get("so_lenh_cho")
    if pos != "0" or pend != "0":
        out.append(f"Tài khoản chưa trống: {pos} vị thế, {pend} lệnh chờ.")
    if deals and deals > 0:
        out.append(f"Tài khoản đã có {deals:,} deal trên symbol trong 365 ngày → không phải tài khoản mới dành "
                   "riêng cho Phoenix Grid.")
    return out


def fmt_spread(v, point):
    return "—" if v is None or v < 0 else f"{v * point:.3f}"


def analyse(spec, vons=None, spread_gio=None):
    """Trả về (danh sách dòng Markdown, bảng kiểm tra điều kiện)."""
    vons = vons or VON_MAC_DINH
    cur = spec.get("account_currency", "?")
    point = num(spec, "point")
    vmin = num(spec, "volume_min")
    vstep = num(spec, "volume_step")
    tick_size = num(spec, "trade_tick_size")
    tv_loss = num(spec, "trade_tick_value_loss")
    vpp = tv_loss / tick_size if tv_loss and tick_size else None
    k_tick = 0.01 * vpp if vpp else None
    k_buy = num(spec, "K_theo_OrderCalcProfit_buy")
    k_sell = num(spec, "K_theo_OrderCalcProfit_sell")
    deals = num(spec, "lich_su_deal_so_deal")
    deals = int(deals) if deals is not None else None

    out = [f"## Thông số {spec.get('symbol', '?')} — {spec.get('account_server', '?')} "
           f"({spec.get('account_trade_mode', '?')})", ""]
    notes = auto_notes(spec, deals)
    if notes:
        out += ["### Nhận định tự động", ""] + [f"- {n}" for n in notes] + [""]
    out += ["| Nhóm | Khóa | Giá trị |", "|---|---|---|"]
    groups = {
        "Tài khoản": ["account_currency", "account_trade_mode", "account_leverage", "account_margin_mode",
                      "account_margin_so_mode", "account_margin_so_call", "account_margin_so_so",
                      "account_limit_orders", "account_trade_allowed", "account_trade_expert", "so_vi_the_dang_mo",
                      "so_lenh_cho", "lich_su_deal_so_deal"],
        "Hợp đồng": ["symbol_path", "trade_calc_mode", "digits", "point", "trade_contract_size", "trade_tick_size",
                     "trade_tick_value", "trade_tick_value_profit", "trade_tick_value_loss", "currency_profit",
                     "currency_margin"],
        "Khối lượng": ["volume_min", "volume_step", "volume_max", "volume_limit"],
        "Khớp lệnh": ["trade_exemode", "filling_mode_flags", "cho_phep_close_by", "cho_phep_sl_tp",
                      "trade_stops_level", "trade_freeze_level"],
        "Margin": ["margin_initial", "margin_maintenance", "margin_hedged", "margin_hedged_use_leg",
                   "margin_rate_buy_initial", "margin_rate_sell_initial", "margin_buy_001", "margin_sell_001",
                   "margin_buy_1_lot"],
        "Swap": ["swap_mode", "swap_long", "swap_short", "swap_rollover3days", "swap_long_tien_1_lot_1_dem",
                 "swap_short_tien_1_lot_1_dem"],
        "Chi phí": ["spread_hien_tai_point", "spread_float", "commission_fee_moi_lot_khu_hoi"],
        "Terminal": ["terminal_build", "thoi_gian_server", "lech_gio_server_gmt", "ping_lan_cuoi_ms"],
    }
    for g, keys in groups.items():
        for k in keys:
            if k in spec:
                out.append(f"| {g} | `{k}` | {spec[k]} |")
    out.append("")

    # --- Xác minh H_K ---
    out += ["## Xác minh giả định H_K", ""]
    out.append(f"- VPP (tiền tài khoản khi 1 lot đi 1 USD/oz) = {vpp:.6f} {cur}" if vpp else "- VPP: thiếu tick value/size")
    out.append(f"- K theo tick value = {k_tick:.6f} {cur}" if k_tick is not None else "- K theo tick value: không tính được")
    out.append(f"- K theo OrderCalcProfit: BUY {k_buy}, SELL {k_sell}")
    ks = [k for k in (k_tick, k_buy, k_sell) if k is not None]
    nhat_quan = bool(ks) and (max(ks) - min(ks)) <= 0.01 * max(abs(max(ks)), 1e-9)
    h_k = bool(ks) and cur == "USC" and all(abs(k - 1.0) <= 0.02 for k in ks)
    out.append(f"- Ba cách tính {'**nhất quán**' if nhat_quan else '**KHÔNG nhất quán** — cần kiểm tra lại'}")
    if h_k:
        out.append("- Kết luận H_K: **ĐẠT**")
    elif cur != "USC" and ks and all(abs(k - 1.0) <= 0.02 for k in ks):
        out.append(f"- Kết luận H_K: **CHƯA KIỂM CHỨNG ĐƯỢC** — K = 1 {cur} (không phải USC) vì file lấy từ tài khoản "
                   f"{cur}. Cấu trúc hợp đồng giống giả định (0,01 lot = 1 đơn vị tiền tài khoản mỗi 1 USD/oz); "
                   "cần chạy lại trên tài khoản Standard Cent (XAUUSDc) để xác nhận")
    else:
        out.append("- Kết luận H_K: **KHÔNG ĐẠT** → mọi ví dụ 🧮 trong kế hoạch phải nhân với K thật")
    out.append("")

    # --- Con số nền với thông số thật ---
    k_real = ks[0] if ks else None
    if k_real is not None and vmin:
        head = " | ".join(f"% vốn {v:,.0f} {cur}" for v in vons)
        out += ["## Lỗ khi giá đi ngược (thông số thật)", "",
                f"| Lot | Đi ngược | Lỗ ({cur}) | {head} |", "|---|---|---|" + "---|" * len(vons)]
        for lot in sorted({vmin, 0.01, 0.02, 0.05, 0.10}):
            for x in (20, 50, 100):
                loss = lot / 0.01 * k_real * x
                pct = " | ".join(f"{loss / v:.1%}" for v in vons)
                out.append(f"| {lot:g} | {x} USD | {loss:,.2f} | {pct} |")
        out.append("")
        for v in vons:
            if vmin / 0.01 * k_real * 100 > 0.02 * v:
                out.append(f"> ⚠️ Với vốn {v:,.0f} {cur}, lot tối thiểu mất {vmin / 0.01 * k_real * 100 / v:.0%} vốn "
                           "khi giá đi ngược 100 USD → theo Mục 8.5 kế hoạch: không giao dịch với cấu hình vốn này.")
        out.append("")

    m_buy = num(spec, "margin_buy_001")
    m_sell = num(spec, "margin_sell_001")
    if m_buy is not None and m_sell is not None:
        leg = max(m_buy, m_sell)
        out += ["## Margin", "",
                f"- Margin một chân 0,01 lot: BUY {m_buy:,.4f}, SELL {m_sell:,.4f} {cur}",
                f"- Dự trữ margin phòng thủ cho basket 0,03 lot (κ = {KAPPA}, không tính ưu đãi hedge): "
                f"{KAPPA * 3 * leg:,.4f} {cur}",
                "- Margin thực tế của cặp BUY + SELL 0,01: cần đo tay trên DEMO (hướng dẫn R0.1, Bước B)", ""]

    sl = num(spec, "swap_long_tien_1_lot_1_dem")
    ss = num(spec, "swap_short_tien_1_lot_1_dem")
    if sl is not None and ss is not None:
        out += ["## Swap", "",
                f"- 1 lot mỗi đêm: BUY {sl:,.2f}, SELL {ss:,.2f} {cur}; 0,01 lot: BUY {sl / 100:,.4f}, SELL {ss / 100:,.4f}",
                f"- Ngày tính ×3: {spec.get('swap_rollover3days', '?')}", ""]

    # --- Spread theo tick ---
    if "spread_tick_trung_vi_point" in spec and point:
        out += [f"## Spread theo tick ({spec.get('spread_tick_so_ngay_co_tick', '?')} ngày có tick, "
                f"{spec.get('spread_tick_tong_so_tick', '?')} tick)", "",
                "| Chỉ số | Point | USD/oz |", "|---|---|---|"]
        for k in ("trung_vi", "p90", "p99", "p999", "lon_nhat"):
            v = num(spec, f"spread_tick_{k}_point")
            if v is not None:
                out.append(f"| {k} | {v:g} | {fmt_spread(v, point)} |")
        out.append("")
        p99 = num(spec, "spread_tick_p99_point")
        if p99 is not None and p99 >= 0:
            out.append(f"- Ứng viên s_abs (ngưỡng spread tuyệt đối, Mục 7.1) = p99 = {p99 * point:.3f} USD/oz")
            out.append("")
    if spread_gio is not None and point:
        cols = ["gio_server", "so_tick", "trung_vi_point", "p90_point", "p99_point", "lon_nhat_point"]
        out += ["### Theo giờ server (USD/oz; — = không có tick)", "",
                "| Giờ | Số tick | Trung vị | p90 | p99 | Lớn nhất |", "|---|---|---|---|---|---|"]
        for row in spread_gio[cols].itertuples(index=False):
            h, n, med, p90, p99h, mx = row
            out.append(f"| {h} | {n:,} | {fmt_spread(med, point)} | {fmt_spread(p90, point)} | "
                       f"{fmt_spread(p99h, point)} | {fmt_spread(mx, point)} |")
        out.append("")

    # --- Phiên giao dịch ---
    phien = [(k.replace("phien_giao_dich_", ""), v) for k, v in spec.items() if k.startswith("phien_giao_dich_")]
    if phien:
        out += ["## Phiên giao dịch (giờ server)", "", "| Ngày | Phiên |", "|---|---|"]
        out += [f"| {d} | {v} |" for d, v in phien]
        out.append("")

    # --- Điều kiện kế hoạch ---
    checks = [
        ("Tài khoản hedging", spec.get("account_margin_mode") == "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING"),
        ("Tiền tài khoản USC (Standard Cent)", cur == "USC"),
        ("Cho phép Close By", spec.get("cho_phep_close_by") == "true"),
        ("Cho phép SL/TP phía server", spec.get("cho_phep_sl_tp", "").count("true") == 2),
        ("Bước lot ≤ 0,01", vstep is not None and vstep <= 0.01 + 1e-12),
        ("Tài khoản riêng đang trống (0 vị thế, 0 lệnh chờ)",
         spec.get("so_vi_the_dang_mo") == "0" and spec.get("so_lenh_cho") == "0"),
        ("Cho phép EA giao dịch", spec.get("account_trade_expert") == "true"),
        ("H_K đạt", h_k),
    ]
    out += ["## Điều kiện kế hoạch cần", "", "| Điều kiện | Kết quả |", "|---|---|"]
    out += [f"| {name} | {'✅' if ok else '❌'} |" for name, ok in checks]
    out.append("")
    return out, checks


def self_test():
    """Kiểm tra code bằng thông số GIẢ LẬP trong bộ nhớ. Không phải thông số thật, không ghi file."""
    fake = "\n".join([
        "khoa;gia_tri;ghi_chu",
        "symbol;TEST;",
        "account_currency;USC;", "account_trade_mode;ACCOUNT_TRADE_MODE_DEMO;", "account_leverage;500;",
        "account_margin_mode;ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;", "account_trade_expert;true;",
        "account_margin_so_so;20.00;", "so_vi_the_dang_mo;0;", "so_lenh_cho;0;", "lich_su_deal_so_deal;0;",
        "lech_gio_server_gmt;0;giờ; ghi chú có dấu chấm phẩy",
        "point;0.00100000;", "volume_min;0.0100;", "volume_step;0.0100;", "filling_mode_flags;3;",
        "trade_tick_size;0.00100000;", "trade_tick_value_loss;0.10000000;",
        "K_theo_OrderCalcProfit_buy;1.000000;", "K_theo_OrderCalcProfit_sell;1.000000;",
        "cho_phep_close_by;true;", "cho_phep_sl_tp;SL=true TP=true;",
        "margin_buy_001;20.0000;", "margin_sell_001;20.0000;",
        "swap_long_tien_1_lot_1_dem;-56.0000;", "swap_short_tien_1_lot_1_dem;0.0000;",
        "spread_tick_trung_vi_point;160;", "spread_tick_p99_point;240;",
        "phien_giao_dich_MONDAY;00:00-20:58,22:00-24:00;",
    ])
    spec, notes = read_spec(fake)
    assert spec["lech_gio_server_gmt"] == "0" and "chấm phẩy" in notes["lech_gio_server_gmt"]
    sg = pd.DataFrame({"gio_server": [0, 21], "so_tick": [100, 0], "trung_vi_point": [160, -1],
                       "p90_point": [160, -1], "p99_point": [240, -1], "lon_nhat_point": [480, -1]})
    lines, checks = analyse(spec, [5000.0, 50.0], sg)
    text = "\n".join(lines)
    assert "Kết luận H_K: **ĐẠT**" in text, text
    assert all(ok for _, ok in checks), checks
    assert "| 0.01 | 100 USD | 100.00 | 2.0% | 200.0% |" in text, text
    assert "Với vốn 50 USC, lot tối thiểu mất 200% vốn" in text, text
    assert "| 21 | 0 | — | — | — | — |" in text, text
    assert "Nhận định tự động" not in text, text  # tài khoản giả lập "sạch" → không có nhận định
    spec2 = dict(spec, account_currency="USD", account_leverage="2000000000", account_margin_so_so="0.00",
                 filling_mode_flags="1", so_lenh_cho="6", lich_su_deal_so_deal="1632")
    text2 = "\n".join(analyse(spec2)[0])
    for s in ("CHƯA KIỂM CHỨNG ĐƯỢC", "không giới hạn", "Stop out 0%", "FOK", "6 lệnh chờ", "1,632 deal"):
        assert s in text2, s
    spec["K_theo_OrderCalcProfit_buy"] = "100.000000"   # K sai lệch → phải báo không nhất quán
    text3 = "\n".join(analyse(spec)[0])
    assert "KHÔNG nhất quán" in text3 and "KHÔNG ĐẠT" in text3
    print("Tự kiểm tra: ĐẠT (dữ liệu giả lập, không phải thông số thật)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="PG_R01_thong_so_<symbol>_<ngày>.csv")
    ap.add_argument("--spread-gio", help="PG_R01_spread_theo_gio_<symbol>_<ngày>.csv")
    ap.add_argument("--von", type=float, nargs="+", default=VON_MAC_DINH,
                    help="một hoặc nhiều mức vốn, đơn vị tiền tài khoản")
    ap.add_argument("--out", default="results_r01")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        self_test()
        return
    if not a.file:
        ap.error("cần --file hoặc --tu-kiem-tra")
    spec, _ = read_spec(open(a.file, encoding="utf-8-sig").read())
    sg = pd.read_csv(a.spread_gio, sep=";", encoding="utf-8-sig") if a.spread_gio else None
    lines, _ = analyse(spec, a.von, sg)
    os.makedirs(a.out, exist_ok=True)
    name = os.path.splitext(os.path.basename(a.file))[0].replace("PG_R01_thong_so_", "thong_so_")
    path = os.path.join(a.out, f"{name}.md")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nĐã ghi {path}")


if __name__ == "__main__":
    main()
