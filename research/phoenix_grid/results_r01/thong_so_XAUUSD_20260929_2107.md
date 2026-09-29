## Thông số XAUUSD — Exness-MT5Trial17 (ACCOUNT_TRADE_MODE_DEMO)

### Nhận định tự động

- Tiền tài khoản là **USD**, không phải USC → đây không phải tài khoản Standard Cent. Symbol `XAUUSD` (đường dẫn `Pro\Forex\XAUUSD`).
- Đòn bẩy 2,000,000,000 (không giới hạn): `OrderCalcMargin` gần như bằng 0, nên điều kiện margin của RiskGate (Mục 8.2 d) luôn đạt và không còn tác dụng bảo vệ.
- Stop out 0%, margin call 30.00%: sàn gần như không cắt lỗ trước khi Equity về 0 → giới hạn của EA là lớp bảo vệ duy nhất.
- Chỉ hỗ trợ khớp **FOK** → module khớp lệnh phải dùng ORDER_FILLING_FOK (tự nhận diện).
- MARGIN_HEDGED = 0: theo quy tắc cơ bản của MT5, phần khối lượng đã cặp hóa BUY/SELL không tính margin. Cần xác nhận bằng số đo tay trên demo (Bước B).
- ACCOUNT_TRADE_EXPERT = false: tài khoản đang báo EA không được phép giao dịch. Bật nút Algo Trading rồi chạy lại script; nếu vẫn false thì tài khoản không cho EA giao dịch.
- Tài khoản chưa trống: 0 vị thế, 6 lệnh chờ.
- Tài khoản đã có 1,632 deal trên symbol trong 365 ngày → không phải tài khoản mới dành riêng cho Phoenix Grid.

| Nhóm | Khóa | Giá trị |
|---|---|---|
| Tài khoản | `account_currency` | USD |
| Tài khoản | `account_trade_mode` | ACCOUNT_TRADE_MODE_DEMO |
| Tài khoản | `account_leverage` | 2000000000 |
| Tài khoản | `account_margin_mode` | ACCOUNT_MARGIN_MODE_RETAIL_HEDGING |
| Tài khoản | `account_margin_so_mode` | ACCOUNT_STOPOUT_MODE_PERCENT |
| Tài khoản | `account_margin_so_call` | 30.00 |
| Tài khoản | `account_margin_so_so` | 0.00 |
| Tài khoản | `account_limit_orders` | 1024 |
| Tài khoản | `account_trade_allowed` | true |
| Tài khoản | `account_trade_expert` | false |
| Tài khoản | `so_vi_the_dang_mo` | 0 |
| Tài khoản | `so_lenh_cho` | 6 |
| Tài khoản | `lich_su_deal_so_deal` | 1632 |
| Hợp đồng | `symbol_path` | Pro\Forex\XAUUSD |
| Hợp đồng | `trade_calc_mode` | SYMBOL_CALC_MODE_FOREX |
| Hợp đồng | `digits` | 3 |
| Hợp đồng | `point` | 0.00100000 |
| Hợp đồng | `trade_contract_size` | 100.00000000 |
| Hợp đồng | `trade_tick_size` | 0.00100000 |
| Hợp đồng | `trade_tick_value` | 0.10000000 |
| Hợp đồng | `trade_tick_value_profit` | 0.10000000 |
| Hợp đồng | `trade_tick_value_loss` | 0.10000000 |
| Hợp đồng | `currency_profit` | USD |
| Hợp đồng | `currency_margin` | XAU |
| Khối lượng | `volume_min` | 0.0100 |
| Khối lượng | `volume_step` | 0.0100 |
| Khối lượng | `volume_max` | 200.0000 |
| Khối lượng | `volume_limit` | 0.0000 |
| Khớp lệnh | `trade_exemode` | SYMBOL_TRADE_EXECUTION_MARKET |
| Khớp lệnh | `filling_mode_flags` | 1 |
| Khớp lệnh | `cho_phep_close_by` | true |
| Khớp lệnh | `cho_phep_sl_tp` | SL=true TP=true |
| Khớp lệnh | `trade_stops_level` | 0 |
| Khớp lệnh | `trade_freeze_level` | 0 |
| Margin | `margin_initial` | 0.00000000 |
| Margin | `margin_maintenance` | 0.00000000 |
| Margin | `margin_hedged` | 0.00000000 |
| Margin | `margin_hedged_use_leg` | false |
| Margin | `margin_rate_buy_initial` | 1.000000 |
| Margin | `margin_rate_sell_initial` | 1.000000 |
| Margin | `margin_buy_001` | 0.0000 |
| Margin | `margin_sell_001` | 0.0000 |
| Margin | `margin_buy_1_lot` | 0.0000 |
| Swap | `swap_mode` | SYMBOL_SWAP_MODE_POINTS |
| Swap | `swap_long` | -560.0000 |
| Swap | `swap_short` | 0.0000 |
| Swap | `swap_rollover3days` | WEDNESDAY |
| Swap | `swap_long_tien_1_lot_1_dem` | -56.0000 |
| Swap | `swap_short_tien_1_lot_1_dem` | 0.0000 |
| Chi phí | `spread_hien_tai_point` | 168 |
| Chi phí | `spread_float` | true |
| Chi phí | `commission_fee_moi_lot_khu_hoi` | 0.0000 |
| Terminal | `terminal_build` | 6230 |
| Terminal | `thoi_gian_server` | 2026.09.29 14:07:15 |
| Terminal | `lech_gio_server_gmt` | 0 |
| Terminal | `ping_lan_cuoi_ms` | 46.3 |

## Xác minh giả định H_K

- VPP (tiền tài khoản khi 1 lot đi 1 USD/oz) = 100.000000 USD
- K theo tick value = 1.000000 USD
- K theo OrderCalcProfit: BUY 1.0, SELL 1.0
- Ba cách tính **nhất quán**
- Kết luận H_K: **CHƯA KIỂM CHỨNG ĐƯỢC** — K = 1 USD (không phải USC) vì file lấy từ tài khoản USD. Cấu trúc hợp đồng giống giả định (0,01 lot = 1 đơn vị tiền tài khoản mỗi 1 USD/oz); cần chạy lại trên tài khoản Standard Cent (XAUUSDc) để xác nhận

## Lỗ khi giá đi ngược (thông số thật)

| Lot | Đi ngược | Lỗ (USD) | % vốn 5,000 USD | % vốn 50 USD |
|---|---|---|---|---|
| 0.01 | 20 USD | 20.00 | 0.4% | 40.0% |
| 0.01 | 50 USD | 50.00 | 1.0% | 100.0% |
| 0.01 | 100 USD | 100.00 | 2.0% | 200.0% |
| 0.02 | 20 USD | 40.00 | 0.8% | 80.0% |
| 0.02 | 50 USD | 100.00 | 2.0% | 200.0% |
| 0.02 | 100 USD | 200.00 | 4.0% | 400.0% |
| 0.05 | 20 USD | 100.00 | 2.0% | 200.0% |
| 0.05 | 50 USD | 250.00 | 5.0% | 500.0% |
| 0.05 | 100 USD | 500.00 | 10.0% | 1000.0% |
| 0.1 | 20 USD | 200.00 | 4.0% | 400.0% |
| 0.1 | 50 USD | 500.00 | 10.0% | 1000.0% |
| 0.1 | 100 USD | 1,000.00 | 20.0% | 2000.0% |

> ⚠️ Với vốn 50 USD, lot tối thiểu mất 200% vốn khi giá đi ngược 100 USD → theo Mục 8.5 kế hoạch: không giao dịch với cấu hình vốn này.

## Margin

- Margin một chân 0,01 lot: BUY 0.0000, SELL 0.0000 USD
- Dự trữ margin phòng thủ cho basket 0,03 lot (κ = 1.5, không tính ưu đãi hedge): 0.0000 USD
- Margin thực tế của cặp BUY + SELL 0,01: cần đo tay trên DEMO (hướng dẫn R0.1, Bước B)

## Swap

- 1 lot mỗi đêm: BUY -56.00, SELL 0.00 USD; 0,01 lot: BUY -0.5600, SELL 0.0000
- Ngày tính ×3: WEDNESDAY

## Spread theo tick (27 ngày có tick, 6553916 tick)

| Chỉ số | Point | USD/oz |
|---|---|---|
| trung_vi | 182 | 0.182 |
| p90 | 182 | 0.182 |
| p99 | 182 | 0.182 |
| p999 | 238 | 0.238 |
| lon_nhat | 1400 | 1.400 |

- Ứng viên s_abs (ngưỡng spread tuyệt đối, Mục 7.1) = p99 = 0.182 USD/oz

### Theo giờ server (USD/oz; — = không có tick)

| Giờ | Số tick | Trung vị | p90 | p99 | Lớn nhất |
|---|---|---|---|---|---|
| 0 | 292,069 | 0.182 | 0.182 | 0.182 | 0.406 |
| 1 | 440,039 | 0.182 | 0.182 | 0.182 | 0.238 |
| 2 | 290,537 | 0.182 | 0.182 | 0.182 | 0.336 |
| 3 | 208,966 | 0.182 | 0.182 | 0.182 | 0.238 |
| 4 | 158,942 | 0.182 | 0.182 | 0.182 | 0.238 |
| 5 | 263,823 | 0.182 | 0.182 | 0.182 | 0.238 |
| 6 | 273,517 | 0.182 | 0.182 | 0.182 | 0.336 |
| 7 | 268,834 | 0.182 | 0.182 | 0.182 | 0.238 |
| 8 | 292,447 | 0.182 | 0.182 | 0.182 | 0.238 |
| 9 | 248,267 | 0.182 | 0.182 | 0.182 | 0.336 |
| 10 | 215,863 | 0.182 | 0.182 | 0.182 | 0.238 |
| 11 | 248,756 | 0.182 | 0.182 | 0.182 | 0.336 |
| 12 | 457,617 | 0.182 | 0.182 | 0.238 | 1.400 |
| 13 | 593,699 | 0.182 | 0.182 | 0.182 | 0.336 |
| 14 | 489,241 | 0.182 | 0.182 | 0.182 | 0.406 |
| 15 | 377,787 | 0.182 | 0.182 | 0.182 | 0.336 |
| 16 | 307,395 | 0.182 | 0.182 | 0.182 | 0.336 |
| 17 | 239,001 | 0.182 | 0.182 | 0.182 | 0.406 |
| 18 | 298,828 | 0.182 | 0.182 | 0.238 | 0.406 |
| 19 | 250,824 | 0.182 | 0.182 | 0.182 | 0.336 |
| 20 | 111,009 | 0.182 | 0.182 | 0.182 | 0.406 |
| 21 | 0 | — | — | — | — |
| 22 | 102,390 | 0.182 | 0.182 | 0.238 | 0.406 |
| 23 | 124,065 | 0.182 | 0.182 | 0.182 | 0.238 |

## Phiên giao dịch (giờ server)

| Ngày | Phiên |
|---|---|
| SUNDAY | 22:01-24:00 |
| MONDAY | 00:00-20:58,22:00-24:00 |
| TUESDAY | 00:00-20:58,22:00-24:00 |
| WEDNESDAY | 00:00-20:58,22:00-24:00 |
| THURSDAY | 00:00-20:58,22:00-24:00 |
| FRIDAY | 00:00-20:58 |
| SATURDAY | khong_co |

## Điều kiện kế hoạch cần

| Điều kiện | Kết quả |
|---|---|
| Tài khoản hedging | ✅ |
| Tiền tài khoản USC (Standard Cent) | ❌ |
| Cho phép Close By | ✅ |
| Cho phép SL/TP phía server | ✅ |
| Bước lot ≤ 0,01 | ✅ |
| Tài khoản riêng đang trống (0 vị thế, 0 lệnh chờ) | ❌ |
| Cho phép EA giao dịch | ❌ |
| H_K đạt | ❌ |

