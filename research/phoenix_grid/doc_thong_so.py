"""Phoenix Grid – Bước R0.1: đọc file thông số do script MT5 `PG_R01_DocThongSo.mq5` xuất ra.

Việc làm:
  - Lập bảng thông số tài khoản/symbol.
  - Xác minh giả định H_K (0,01 lot XAUUSDc lãi/lỗ 1 USC cho mỗi 1 USD/oz) bằng hai cách độc lập:
    tick value và OrderCalcProfit.
  - Tính lại các con số nền của kế hoạch với thông số thật: lỗ của lot tối thiểu khi giá đi ngược 20/50/100 USD,
    swap mỗi đêm, margin từng chân, dự trữ margin phòng thủ.
  - Kiểm tra các điều kiện kế hoạch cần: tài khoản hedging, Close By, SL/TP phía server, tài khoản riêng còn trống.

Không phải backtest. Không bịa thông số: mọi giá trị lấy từ file CSV của MT5.

Chạy:
  python3 doc_thong_so.py --file PG_R01_thong_so_XAUUSDc_<ngày>.csv \
      [--spread-gio PG_R01_spread_theo_gio_XAUUSDc_<ngày>.csv] [--von 5000] [--out results_r01]
  python3 doc_thong_so.py --tu-kiem-tra      # tự kiểm tra code bằng dữ liệu giả lập trong bộ nhớ (không ghi file)
"""
import argparse
import io
import os

import pandas as pd

VON_MAC_DINH = 5000.0   # vốn nghiên cứu (đơn vị tiền tài khoản)
KAPPA = 1.5             # hệ số dự trữ margin phòng thủ (Mục 8.2 d của kế hoạch)


def read_spec(text):
    df = pd.read_csv(io.StringIO(text), sep=";", dtype=str, keep_default_na=False)
    return dict(zip(df["khoa"], df["gia_tri"])), dict(zip(df["khoa"], df["ghi_chu"]))


def num(spec, key):
    try:
        return float(spec[key])
    except (KeyError, ValueError):
        return None


def analyse(spec, von=VON_MAC_DINH, spread_gio=None):
    """Trả về (danh sách dòng Markdown, bảng kiểm tra điều kiện)."""
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

    out = [f"## Thông số {spec.get('symbol', '?')} — {spec.get('account_server', '?')} "
           f"({spec.get('account_trade_mode', '?')})", ""]
    out += ["| Nhóm | Khóa | Giá trị |", "|---|---|---|"]
    groups = {
        "Tài khoản": ["account_currency", "account_leverage", "account_margin_mode", "account_margin_so_mode",
                      "account_margin_so_call", "account_margin_so_so", "account_limit_orders", "so_vi_the_dang_mo",
                      "so_lenh_cho"],
        "Hợp đồng": ["trade_calc_mode", "digits", "point", "trade_contract_size", "trade_tick_size",
                     "trade_tick_value", "trade_tick_value_profit", "trade_tick_value_loss", "currency_profit",
                     "currency_margin"],
        "Khối lượng": ["volume_min", "volume_step", "volume_max", "volume_limit"],
        "Khớp lệnh": ["trade_exemode", "filling_mode_flags", "cho_phep_close_by", "cho_phep_sl_tp",
                      "trade_stops_level", "trade_freeze_level"],
        "Margin": ["margin_initial", "margin_maintenance", "margin_hedged", "margin_hedged_use_leg",
                   "margin_buy_001", "margin_sell_001", "margin_buy_1_lot"],
        "Swap": ["swap_mode", "swap_long", "swap_short", "swap_rollover3days", "swap_long_tien_1_lot_1_dem",
                 "swap_short_tien_1_lot_1_dem"],
        "Chi phí": ["spread_hien_tai_point", "spread_float", "commission_fee_moi_lot_khu_hoi"],
        "Terminal": ["terminal_build", "lech_gio_server_gmt", "ping_lan_cuoi_ms"],
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
    out.append(f"- Kết luận H_K: **{'ĐẠT' if h_k else 'KHÔNG ĐẠT'}**"
               + ("" if h_k else " → mọi ví dụ 🧮 trong kế hoạch phải nhân với K thật"))
    out.append("")

    # --- Con số nền với thông số thật ---
    k_real = ks[0] if ks else None
    if k_real is not None and vmin:
        out += [f"## Lỗ khi giá đi ngược (thông số thật, vốn {von:,.0f} {cur})", "",
                "| Lot | 20 USD | 50 USD | 100 USD |", "|---|---|---|---|"]
        for lot in sorted({vmin, 0.01, 0.02, 0.05, 0.10}):
            cells = []
            for x in (20, 50, 100):
                loss = lot / 0.01 * k_real * x
                cells.append(f"{loss:,.1f} ({loss / von:.1%})")
            out.append(f"| {lot:g} | " + " | ".join(cells) + " |")
        out.append("")
        if vmin / 0.01 * k_real * 100 > 0.02 * von:
            out.append("> ⚠️ Lot tối thiểu mất hơn 2% vốn khi giá đi ngược 100 USD → xem lại tính khả thi (Mục 8.5).")
            out.append("")

    m_buy = num(spec, "margin_buy_001")
    m_sell = num(spec, "margin_sell_001")
    if m_buy is not None and m_sell is not None:
        leg = max(m_buy, m_sell)
        out += ["## Margin", "",
                f"- Margin một chân 0,01 lot: BUY {m_buy:,.2f}, SELL {m_sell:,.2f} {cur}",
                f"- Dự trữ margin phòng thủ cho basket 0,03 lot (κ = {KAPPA}, không tính ưu đãi hedge): "
                f"{KAPPA * 3 * leg:,.2f} {cur} = {KAPPA * 3 * leg / von:.2%} vốn",
                "- Margin thực tế của cặp BUY + SELL 0,01: cần đo tay trên DEMO (hướng dẫn R0.1)", ""]

    sl = num(spec, "swap_long_tien_1_lot_1_dem")
    ss = num(spec, "swap_short_tien_1_lot_1_dem")
    if sl is not None and ss is not None:
        out += ["## Swap", "",
                f"- 1 lot mỗi đêm: BUY {sl:,.2f}, SELL {ss:,.2f} {cur}; 0,01 lot: BUY {sl / 100:,.4f}, SELL {ss / 100:,.4f}",
                f"- Ngày tính ×3: {spec.get('swap_rollover3days', '?')}", ""]

    # --- Spread theo tick ---
    if "spread_tick_trung_vi_point" in spec and point:
        out += ["## Spread theo tick", "", "| Chỉ số | Point | USD/oz |", "|---|---|---|"]
        for k in ("trung_vi", "p90", "p99", "p999", "lon_nhat"):
            v = num(spec, f"spread_tick_{k}_point")
            if v is not None:
                out.append(f"| {k} | {v:g} | {v * point:.3f} |")
        out.append("")
        p99 = num(spec, "spread_tick_p99_point")
        if p99 is not None:
            out.append(f"- Đề xuất s_abs (ngưỡng spread tuyệt đối, Mục 7.1) = p99 = {p99 * point:.3f} USD/oz")
            out.append("")
    if spread_gio is not None and point:
        sg = spread_gio.copy()
        for c in ("trung_vi_point", "p90_point", "p99_point", "lon_nhat_point"):
            sg[c.replace("_point", "_usd")] = sg[c] * point
        cols = list(sg.columns)
        out += ["### Theo giờ server", "", "| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
        out += ["| " + " | ".join(f"{v:.3f}" if isinstance(v, float) else str(v) for v in row) + " |"
                for row in sg.itertuples(index=False)]
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
        "account_currency;USC;", "account_trade_mode;ACCOUNT_TRADE_MODE_DEMO;",
        "account_margin_mode;ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;", "account_trade_expert;true;",
        "so_vi_the_dang_mo;0;", "so_lenh_cho;0;",
        "point;0.00100000;", "volume_min;0.0100;", "volume_step;0.0100;",
        "trade_tick_size;0.00100000;", "trade_tick_value_loss;0.10000000;",
        "K_theo_OrderCalcProfit_buy;1.000000;", "K_theo_OrderCalcProfit_sell;1.000000;",
        "cho_phep_close_by;true;", "cho_phep_sl_tp;SL=true TP=true;",
        "margin_buy_001;20.0000;", "margin_sell_001;20.0000;",
        "swap_long_tien_1_lot_1_dem;-56.0000;", "swap_short_tien_1_lot_1_dem;0.0000;",
        "spread_tick_trung_vi_point;160;", "spread_tick_p99_point;240;",
        "phien_giao_dich_MONDAY;00:00-20:58,22:00-24:00;",
    ])
    spec, _ = read_spec(fake)
    sg = pd.DataFrame({"gio_server": [0, 1], "so_tick": [100, 200], "trung_vi_point": [160, 160],
                       "p90_point": [160, 200], "p99_point": [240, 240], "lon_nhat_point": [480, 400]})
    lines, checks = analyse(spec, 5000.0, sg)
    text = "\n".join(lines)
    assert "### Theo giờ server" in text and "| 1 | 200 | 160 | 200 | 240 | 400 | 0.160 | 0.200 | 0.240 | 0.400 |" in text, text
    assert "Kết luận H_K: **ĐẠT**" in text, text
    assert all(ok for _, ok in checks), checks
    assert "| 0.01 | 20.0 (0.4%) | 50.0 (1.0%) | 100.0 (2.0%) |" in text, text
    spec["K_theo_OrderCalcProfit_buy"] = "100.000000"   # K sai lệch → phải báo không nhất quán
    text2 = "\n".join(analyse(spec, 5000.0)[0])
    assert "KHÔNG nhất quán" in text2 and "KHÔNG ĐẠT" in text2
    print("Tự kiểm tra: ĐẠT (dữ liệu giả lập, không phải thông số thật)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="PG_R01_thong_so_<symbol>_<ngày>.csv")
    ap.add_argument("--spread-gio", help="PG_R01_spread_theo_gio_<symbol>_<ngày>.csv")
    ap.add_argument("--von", type=float, default=VON_MAC_DINH, help="vốn nghiên cứu, đơn vị tiền tài khoản")
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
    path = os.path.join(a.out, f"thong_so_{spec.get('symbol', 'symbol')}.md")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nĐã ghi {path}")


if __name__ == "__main__":
    main()
