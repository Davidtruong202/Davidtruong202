## Thông số XAUUSDc — Exness-MT5Real20 (ACCOUNT_TRADE_MODE_REAL)

### Nhận định tự động

- Stop out 0%, margin call 60.00%: sàn gần như không cắt lỗ trước khi Equity về 0 → giới hạn của EA là lớp bảo vệ duy nhất.
- MARGIN_HEDGED = 0: theo quy tắc cơ bản của MT5, phần khối lượng đã cặp hóa BUY/SELL không tính margin. Cần xác nhận bằng số đo tay trên demo (Bước B).
- Tài khoản chưa trống: 3 vị thế, 0 lệnh chờ.
- Tài khoản đã có 908 deal trên symbol trong 365 ngày → không phải tài khoản mới dành riêng cho Phoenix Grid.

| Nhóm | Khóa | Giá trị |
|---|---|---|
| Tài khoản | `account_currency` | USC |
| Tài khoản | `account_trade_mode` | ACCOUNT_TRADE_MODE_REAL |
| Tài khoản | `account_leverage` | 2000 |
| Tài khoản | `account_margin_mode` | ACCOUNT_MARGIN_MODE_RETAIL_HEDGING |
| Tài khoản | `account_margin_so_mode` | ACCOUNT_STOPOUT_MODE_PERCENT |
| Tài khoản | `account_margin_so_call` | 60.00 |
| Tài khoản | `account_margin_so_so` | 0.00 |
| Tài khoản | `account_limit_orders` | 200 |
| Tài khoản | `account_trade_allowed` | true |
| Tài khoản | `account_trade_expert` | true |
| Tài khoản | `so_vi_the_dang_mo` | 3 |
| Tài khoản | `so_lenh_cho` | 0 |
| Tài khoản | `lich_su_deal_so_deal` | 908 |
| Hợp đồng | `symbol_path` | Cent\Forex\XAUUSDc |
| Hợp đồng | `trade_calc_mode` | SYMBOL_CALC_MODE_FOREX |
| Hợp đồng | `digits` | 3 |
| Hợp đồng | `point` | 0.00100000 |
| Hợp đồng | `trade_contract_size` | 1.00000000 |
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
| Khớp lệnh | `filling_mode_flags` | 3 |
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
| Margin | `margin_buy_001` | 2.0800 |
| Margin | `margin_sell_001` | 2.0800 |
| Margin | `margin_buy_1_lot` | 208.4800 |
| Swap | `swap_mode` | SYMBOL_SWAP_MODE_POINTS |
| Swap | `swap_long` | -560.0000 |
| Swap | `swap_short` | 0.0000 |
| Swap | `swap_rollover3days` | WEDNESDAY |
| Swap | `swap_long_tien_1_lot_1_dem` | -56.0000 |
| Swap | `swap_short_tien_1_lot_1_dem` | 0.0000 |
| Chi phí | `spread_hien_tai_point` | 240 |
| Chi phí | `spread_float` | true |
| Chi phí | `commission_fee_moi_lot_khu_hoi` | 0.0000 |
| Terminal | `terminal_build` | 6230 |
| Terminal | `thoi_gian_server` | 2026.09.30 01:27:54 |
| Terminal | `lech_gio_server_gmt` | 0 |
| Terminal | `ping_lan_cuoi_ms` | 55.6 |

## Xác minh giả định H_K

- VPP (tiền tài khoản khi 1 lot đi 1 USD/oz) = 100.000000 USC
- K theo tick value = 1.000000 USC
- K theo OrderCalcProfit: BUY 1.0, SELL 1.0
- Ba cách tính **nhất quán**
- Kết luận H_K: **ĐẠT**

## Lỗ khi giá đi ngược (thông số thật)

| Lot | Đi ngược | Lỗ (USC) | % vốn 5,000 USC |
|---|---|---|---|
| 0.01 | 20 USD | 20.00 | 0.4% |
| 0.01 | 50 USD | 50.00 | 1.0% |
| 0.01 | 100 USD | 100.00 | 2.0% |
| 0.02 | 20 USD | 40.00 | 0.8% |
| 0.02 | 50 USD | 100.00 | 2.0% |
| 0.02 | 100 USD | 200.00 | 4.0% |
| 0.05 | 20 USD | 100.00 | 2.0% |
| 0.05 | 50 USD | 250.00 | 5.0% |
| 0.05 | 100 USD | 500.00 | 10.0% |
| 0.1 | 20 USD | 200.00 | 4.0% |
| 0.1 | 50 USD | 500.00 | 10.0% |
| 0.1 | 100 USD | 1,000.00 | 20.0% |


## Margin

- Margin một chân 0,01 lot: BUY 2.0800, SELL 2.0800 USC
- Dự trữ margin phòng thủ cho basket 0,03 lot (κ = 1.5, không tính ưu đãi hedge): 9.3600 USC
- Margin thực tế của cặp BUY + SELL 0,01: cần đo tay trên DEMO (hướng dẫn R0.1, Bước B)

## Swap

- 1 lot mỗi đêm: BUY -56.00, SELL 0.00 USC; 0,01 lot: BUY -0.5600, SELL 0.0000
- Ngày tính ×3: WEDNESDAY

## Spread theo tick (27 ngày có tick, 6645236 tick)

| Chỉ số | Point | USD/oz |
|---|---|---|
| trung_vi | 260 | 0.260 |
| p90 | 260 | 0.260 |
| p99 | 260 | 0.260 |
| p999 | 340 | 0.340 |
| lon_nhat | 2000 | 2.000 |

- Ứng viên s_abs (ngưỡng spread tuyệt đối, Mục 7.1) = p99 = 0.260 USD/oz

### Theo giờ server (USD/oz; — = không có tick)

| Giờ | Số tick | Trung vị | p90 | p99 | Lớn nhất |
|---|---|---|---|---|---|
| 0 | 301,072 | 0.260 | 0.260 | 0.260 | 0.580 |
| 1 | 446,300 | 0.260 | 0.260 | 0.260 | 0.340 |
| 2 | 290,551 | 0.260 | 0.260 | 0.260 | 0.480 |
| 3 | 209,081 | 0.260 | 0.260 | 0.260 | 0.340 |
| 4 | 158,926 | 0.260 | 0.260 | 0.260 | 0.340 |
| 5 | 263,950 | 0.260 | 0.260 | 0.260 | 0.340 |
| 6 | 273,588 | 0.260 | 0.260 | 0.260 | 0.480 |
| 7 | 268,880 | 0.260 | 0.260 | 0.260 | 0.340 |
| 8 | 292,453 | 0.260 | 0.260 | 0.260 | 0.340 |
| 9 | 248,266 | 0.260 | 0.260 | 0.260 | 0.480 |
| 10 | 215,961 | 0.260 | 0.260 | 0.260 | 0.340 |
| 11 | 248,828 | 0.260 | 0.260 | 0.260 | 0.480 |
| 12 | 457,827 | 0.260 | 0.260 | 0.340 | 2.000 |
| 13 | 593,569 | 0.260 | 0.260 | 0.260 | 0.480 |
| 14 | 503,671 | 0.260 | 0.260 | 0.260 | 0.580 |
| 15 | 393,186 | 0.260 | 0.260 | 0.260 | 0.480 |
| 16 | 317,604 | 0.260 | 0.260 | 0.260 | 0.480 |
| 17 | 247,497 | 0.260 | 0.260 | 0.260 | 0.580 |
| 18 | 321,010 | 0.260 | 0.260 | 0.340 | 0.580 |
| 19 | 259,608 | 0.260 | 0.260 | 0.260 | 0.480 |
| 20 | 116,867 | 0.260 | 0.260 | 0.260 | 0.580 |
| 21 | 0 | — | — | — | — |
| 22 | 98,576 | 0.260 | 0.260 | 0.340 | 0.580 |
| 23 | 117,965 | 0.260 | 0.260 | 0.260 | 0.340 |

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
| Tiền tài khoản USC (Standard Cent) | ✅ |
| Cho phép Close By | ✅ |
| Cho phép SL/TP phía server | ✅ |
| Bước lot ≤ 0,01 | ✅ |
| Tài khoản riêng đang trống (0 vị thế, 0 lệnh chờ) | ❌ |
| Cho phép EA giao dịch | ✅ |
| H_K đạt | ✅ |

