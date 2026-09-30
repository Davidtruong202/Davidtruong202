# Dò set Phoenix Grid cho tài khoản cent 5000 USC — kết quả mô phỏng

> Mô phỏng Python `mo_phong_phoenix.py` (đường giá nội suy ≤ 0,5 USD trong nến M1, spread 0,26, swap, margin
> level 500%), KHÔNG phải backtest MT5. Chỉ dùng để so sánh cấu hình với nhau. Luật chọn ghi trong
> `do_tim_set_cent.py` trước khi chạy.

## 1. DEV 01/01–30/04/2026: mọi biến thể

- Biến thể: **557** (bước 1 ngẫu nhiên + tham chiếu: 363; bước 2 láng giềng: 194).
- Cháy tài khoản ít nhất một lần: **358** (64%).
- Mức A (không cháy, DD ≤ 30%, lãi > 0, bỏ 2 tháng tốt nhất ≥ 0): **0**; mức B (DD ≤ 50%): **81**; mức C (không cháy, lãi > 0): **79**.

### 1.1 Tham chiếu

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | sau_max | lot_max | gio_max | buy | sell | swap | gio_chan_ml |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| V0.21 set hệ số 1,2 đã gửi | 6445 | 2 | 100.60 | 0.85 | -5474 | 2318 | 17 | 1.13 | 158.90 | 1135 | 5314 | -55 | 0.20 |
| Gần Hydra: bảng lot, bước nhỏ | 10299 | 2 | 100.40 | 0.52 | -13453 | 7367 | 29 | 3.62 | 93.00 | 9567 | 13066 | -245 | 0.10 |
| V0.21 mặc định (lot đều) | -18185 | 4 | 110.70 | -2.71 | -16036 | 692 | 39 | 0.34 | 868.30 | -9823 | -7879 | -9 | 0.30 |

### 1.2 Tỷ lệ cháy theo từng input (bước 1, mẫu ngẫu nhiên)

Mỗi dòng: một giá trị của input; số cấu hình có giá trị đó, % cháy ít nhất một lần, trung vị DD, số cấu hình không cháy.

- **InpHeSoLot / InpDungBangLot** — 1.0: 55 cấu hình, cháy 82%, DD trung vị 100%, không cháy 10; 1.05: 57 cấu hình, cháy 77%, DD trung vị 100%, không cháy 13; 1.1: 47 cấu hình, cháy 85%, DD trung vị 100%, không cháy 7; 1.15: 50 cấu hình, cháy 80%, DD trung vị 100%, không cháy 10; bang: 58 cấu hình, cháy 88%, DD trung vị 100%, không cháy 7; 1.2: 42 cấu hình, cháy 86%, DD trung vị 100%, không cháy 6; 1.3: 51 cấu hình, cháy 80%, DD trung vị 100%, không cháy 10
- **InpLotTangToiDa** — 0.02: 61 cấu hình, cháy 72%, DD trung vị 100%, không cháy 17; 0.03: 49 cấu hình, cháy 88%, DD trung vị 100%, không cháy 6; 0.05: 62 cấu hình, cháy 84%, DD trung vị 100%, không cháy 10; 0.1: 72 cấu hình, cháy 82%, DD trung vị 100%, không cháy 13; 0.2: 60 cấu hình, cháy 85%, DD trung vị 100%, không cháy 9; 0.5: 56 cấu hình, cháy 86%, DD trung vị 100%, không cháy 8
- **InpBuocMinUSD** — 1.5: 36 cấu hình, cháy 75%, DD trung vị 100%, không cháy 9; 3.0: 36 cấu hình, cháy 81%, DD trung vị 100%, không cháy 7; 4.5: 31 cấu hình, cháy 84%, DD trung vị 100%, không cháy 5; 6.0: 38 cấu hình, cháy 82%, DD trung vị 100%, không cháy 7; 8.0: 39 cấu hình, cháy 77%, DD trung vị 100%, không cháy 9; 10.0: 44 cấu hình, cháy 82%, DD trung vị 100%, không cháy 8; 12.0: 26 cấu hình, cháy 81%, DD trung vị 100%, không cháy 5; 15.0: 40 cấu hình, cháy 88%, DD trung vị 100%, không cháy 5; 20.0: 39 cấu hình, cháy 82%, DD trung vị 100%, không cháy 7; 25.0: 31 cấu hình, cháy 97%, DD trung vị 100%, không cháy 1
- **InpBuocATR** — 0.5: 50 cấu hình, cháy 78%, DD trung vị 100%, không cháy 11; 0.8: 47 cấu hình, cháy 83%, DD trung vị 100%, không cháy 8; 1.15: 63 cấu hình, cháy 86%, DD trung vị 100%, không cháy 9; 1.5: 36 cấu hình, cháy 81%, DD trung vị 100%, không cháy 7; 2.0: 59 cấu hình, cháy 85%, DD trung vị 100%, không cháy 9; 3.0: 50 cấu hình, cháy 78%, DD trung vị 100%, không cháy 11; 4.0: 55 cấu hình, cháy 85%, DD trung vị 100%, không cháy 8
- **InpSoTangToiDa** — 5: 52 cấu hình, cháy 58%, DD trung vị 100%, không cháy 22; 8: 59 cấu hình, cháy 85%, DD trung vị 100%, không cháy 9; 12: 48 cấu hình, cháy 88%, DD trung vị 100%, không cháy 6; 16: 45 cấu hình, cháy 89%, DD trung vị 100%, không cháy 5; 20: 48 cấu hình, cháy 81%, DD trung vị 100%, không cháy 9; 30: 54 cấu hình, cháy 87%, DD trung vị 100%, không cháy 7; 40: 54 cấu hình, cháy 91%, DD trung vị 100%, không cháy 5
- **InpTiaTPBuoc** — 0.5: 79 cấu hình, cháy 75%, DD trung vị 100%, không cháy 20; 0.75: 58 cấu hình, cháy 74%, DD trung vị 100%, không cháy 15; 1.0: 61 cấu hình, cháy 84%, DD trung vị 100%, không cháy 10; 1.5: 83 cấu hình, cháy 89%, DD trung vị 100%, không cháy 9; 2.0: 79 cấu hình, cháy 89%, DD trung vị 100%, không cháy 9
- **InpGioTPATR** — 0.5: 67 cấu hình, cháy 79%, DD trung vị 100%, không cháy 14; 1.0: 78 cấu hình, cháy 90%, DD trung vị 100%, không cháy 8; 1.5: 77 cấu hình, cháy 74%, DD trung vị 100%, không cháy 20; 2.0: 69 cấu hình, cháy 87%, DD trung vị 100%, không cháy 9; 3.0: 69 cấu hình, cháy 83%, DD trung vị 100%, không cháy 12
- **InpTrailClear / InpTrailGiuPT** — tat: 103 cấu hình, cháy 82%, DD trung vị 100%, không cháy 19; 40: 85 cấu hình, cháy 81%, DD trung vị 100%, không cháy 16; 60: 88 cấu hình, cháy 80%, DD trung vị 100%, không cháy 18; 80: 84 cấu hình, cháy 88%, DD trung vị 100%, không cháy 10
- **InpHoaVonTuTang** — 0: 48 cấu hình, cháy 77%, DD trung vị 100%, không cháy 11; 2: 49 cấu hình, cháy 78%, DD trung vị 100%, không cháy 11; 3: 51 cấu hình, cháy 84%, DD trung vị 100%, không cháy 8; 4: 47 cấu hình, cháy 70%, DD trung vị 100%, không cháy 14; 6: 60 cấu hình, cháy 88%, DD trung vị 100%, không cháy 7; 8: 57 cấu hình, cháy 91%, DD trung vị 100%, không cháy 5; 12: 48 cấu hình, cháy 85%, DD trung vị 100%, không cháy 7
- **InpXoaTangLo / InpXoaGomLai** — tat: 55 cấu hình, cháy 80%, DD trung vị 100%, không cháy 11; 0: 57 cấu hình, cháy 82%, DD trung vị 100%, không cháy 10; 1: 62 cấu hình, cháy 85%, DD trung vị 100%, không cháy 9; 2: 61 cấu hình, cháy 87%, DD trung vị 100%, không cháy 8; 4: 60 cấu hình, cháy 82%, DD trung vị 100%, không cháy 11; 6: 65 cấu hình, cháy 78%, DD trung vị 100%, không cháy 14
- **InpXoaTuSoTang** — 2: 79 cấu hình, cháy 82%, DD trung vị 100%, không cháy 14; 3: 84 cấu hình, cháy 79%, DD trung vị 100%, không cháy 18; 4: 109 cấu hình, cháy 80%, DD trung vị 100%, không cháy 22; 6: 88 cấu hình, cháy 90%, DD trung vị 100%, không cháy 9
- **InpChanNguocXH** — True: 186 cấu hình, cháy 84%, DD trung vị 100%, không cháy 30; False: 174 cấu hình, cháy 81%, DD trung vị 100%, không cháy 33
- **InpPP0MA** — 20: 98 cấu hình, cháy 95%, DD trung vị 100%, không cháy 5; 50: 79 cấu hình, cháy 91%, DD trung vị 100%, không cháy 7; 100: 107 cấu hình, cháy 86%, DD trung vị 100%, không cháy 15; 200: 76 cấu hình, cháy 53%, DD trung vị 100%, không cháy 36
- **InpGiayGiuaDCA** — 20: 104 cấu hình, cháy 83%, DD trung vị 100%, không cháy 18; 60: 149 cấu hình, cháy 82%, DD trung vị 100%, không cháy 27; 180: 107 cấu hình, cháy 83%, DD trung vị 100%, không cháy 18
- **InpTiaLapLai** — True: 162 cấu hình, cháy 91%, DD trung vị 100%, không cháy 14; False: 198 cấu hình, cháy 75%, DD trung vị 100%, không cháy 49
- **InpGiayChoSauClear** — 10: 169 cấu hình, cháy 83%, DD trung vị 100%, không cháy 28; 60: 191 cấu hình, cháy 82%, DD trung vị 100%, không cháy 35

### 1.3 Các cấu hình không cháy (bước 1 + 2), xếp theo mức rồi lãi / DD

| ten | nhom | muc | net | chay | dd_pt | net_dd | bo2thang | basket | sau_max | lot_max | gio_max | buy | sell | swap | gio_chan_ml | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| tp_atr=3.0 | lang_gieng | B | 7743 | 0 | 33.60 | 3.00 | 2543 | 277 | 6 | 0.12 | 160.10 | 4167 | 3899 | -44 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| so_tang=5 | lang_gieng | B | 5911 | 0 | 32.00 | 2.40 | 788 | 434 | 4 | 0.07 | 335.70 | 2635 | 3580 | -43 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 5; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| hoa_von_tang=4 | lang_gieng | B | 6523 | 0 | 39.10 | 2.33 | 1597 | 426 | 7 | 0.15 | 332.10 | 2866 | 3853 | -30 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 4; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| N282 | ngau_nhien | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| lot_max=0.1 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.1; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| lot_max=0.5 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| buoc_min=3.0 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(3.0; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| buoc_min=6.0 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(6.0; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| so_tang=12 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 12; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| xoa=2 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 2/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| xoa=6 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 6/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| xoa_tu=3 | lang_gieng | B | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/3; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| loc_xh=False | lang_gieng | B | 6494 | 0 | 39.20 | 2.32 | 1096 | 448 | 7 | 0.15 | 332.10 | 2924 | 3765 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1; DCA 60s; lặp có; chờ 60s |
| tia_lap_lai=False | lang_gieng | B | 6515 | 0 | 39.20 | 2.32 | 1108 | 453 | 7 | 0.15 | 332.10 | 2948 | 3763 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| kieu_lot=1.2 | lang_gieng | B | 6477 | 0 | 39.20 | 2.31 | 1052 | 454 | 7 | 0.16 | 332.10 | 2944 | 3728 | -32 | 0.00 | lot 0.01 ×1.2 trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| giay_dca=20 | lang_gieng | B | 6472 | 0 | 42.20 | 2.31 | 1049 | 454 | 7 | 0.15 | 332.10 | 2942 | 3728 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
| kieu_lot=1.15 | lang_gieng | B | 6334 | 0 | 38.30 | 2.30 | 1021 | 448 | 7 | 0.14 | 332.40 | 2819 | 3742 | -32 | 0.00 | lot 0.01 ×1.15 trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| tia_tp=1.5 | lang_gieng | B | 6404 | 0 | 39.40 | 2.29 | 930 | 451 | 7 | 0.15 | 332.40 | 2848 | 3782 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| giay_dca=180 | lang_gieng | B | 6371 | 0 | 38.60 | 2.27 | 900 | 448 | 7 | 0.15 | 332.10 | 2913 | 3656 | -33 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
| hoa_von_tang=2 | lang_gieng | B | 6165 | 0 | 40.30 | 2.20 | 889 | 469 | 7 | 0.15 | 332.10 | 2904 | 3466 | -32 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 2; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| cho_clear=10 | lang_gieng | B | 6022 | 0 | 41.10 | 2.16 | 1287 | 402 | 7 | 0.15 | 332.10 | 2668 | 3578 | -35 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
| N208 | ngau_nhien | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| buoc_min=3.0 | lang_gieng | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(3.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| xoa=2 | lang_gieng | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 2/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| xoa_tu=4 | lang_gieng | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/4; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| xoa=6 | lang_gieng | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 6/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| xoa_tu=2 | lang_gieng | B | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/2; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| trail=60 | lang_gieng | B | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N280 | ngau_nhien | B | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| buoc_min=8.0 | lang_gieng | B | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(8.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| buoc_min=12.0 | lang_gieng | B | 7101 | 0 | 43.70 | 2.03 | 1111 | 362 | 8 | 0.16 | 332.70 | 3282 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(12.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| so_tang=20 | lang_gieng | B | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 20; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| so_tang=40 | lang_gieng | B | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 40; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| hoa_von_tang=6 | lang_gieng | B | 7100 | 0 | 43.70 | 2.03 | 1111 | 362 | 8 | 0.16 | 332.70 | 3327 | 4020 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 6; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| xoa_tu=3 | lang_gieng | B | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| giay_dca=60 | lang_gieng | B | 7078 | 0 | 47.50 | 2.02 | 1098 | 362 | 8 | 0.16 | 332.70 | 3259 | 4066 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 60s; lặp có; chờ 10s |
| loc_xh=True | lang_gieng | B | 7046 | 0 | 43.80 | 2.01 | 1061 | 358 | 8 | 0.16 | 332.70 | 3248 | 4045 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
| tp_atr=2.0 | lang_gieng | B | 6194 | 0 | 42.30 | 1.89 | 675 | 337 | 7 | 0.15 | 332.30 | 2833 | 3566 | -38 | 0.00 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| hoa_von_tang=3 | lang_gieng | B | 6564 | 0 | 45.50 | 1.87 | 771 | 360 | 8 | 0.16 | 332.70 | 3046 | 3765 | -37 | 0.00 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 3; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| tp_atr=2.0 | lang_gieng | B | 5919 | 0 | 47.40 | 1.83 | 1785 | 435 | 4 | 0.09 | 590.80 | 3740 | 2603 | -101 | 0.00 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 2.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |

## 2. Hạt giống: vùng phẳng (láng giềng một bước) và nhiễu đường giá

| hat | muc | ben_duong_gia | diem_goc | trung_vi_diem_lang_gieng | trung_vi_diem_duong_gia | diem_vung | lang_gieng_dat | lang_gieng_chay | so_lang_gieng | dd_max_duong | net_goc | dd_goc | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H0 | B | False | 2.32 | 2.31 | 1.77 | 2.31 | 0 | 4 | 26 | 100.10 | 6509.40 | 39.20 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| H2 | B | False | 2.03 | 1.94 | -1.00 | 1.87 | 0 | 10 | 22 | 100.10 | 7093.20 | 43.70 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| H1 | B | False | 2.13 | 1.42 | 1.27 | 1.34 | 0 | 5 | 23 | 100.20 | 10092.80 | 48.80 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| H3 | B | False | 1.31 | 0.99 | 1.26 | 1.01 | 0 | 4 | 24 | 52.40 | 4942.90 | 49.70 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| H4 | B | False | 0.96 | 0.92 | 0.96 | 0.96 | 0 | 6 | 24 | 100.10 | 2712.20 | 43.00 | lot 0.01 bảng Hydra trần 0.05; tầng max(3.0; 4.0×ATR) × 40; TP tỉa 0.5; clear 3.0×ATR trail 40; HV 0; xóa 6/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
| H5 | B | False | 0.29 | 0.23 | 0.00 | 0.16 | 0 | 3 | 23 | 100.10 | 852.20 | 38.00 | lot 0.01 ×1.2 trần 0.1; tầng max(8.0; 1.15×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa tat/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
| H6 | C | False | 3.34 | 0.48 | 3.19 | 2.53 | 0 | 12 | 24 | 100.10 | 13030.40 | 54.60 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| H7 | C | False | 2.76 | 0.14 | 2.76 | 2.50 | 0 | 14 | 28 | 124.00 | 12909.60 | 53.00 | lot 0.01 ×1.15 trần 0.2; tầng max(8.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 4; xóa 4/2; SMA100 H1; DCA 60s; lặp có; chờ 60s |

### 2.1 Từng đường giá nhiễu

| ten | tu | hat | net | chay | dd_pt | net_dd | bo2thang | basket | sau_max | lot_max | gio_max | buy | sell | swap | gio_chan_ml |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H0 | 2026-01-01 | 11.00 | 5528 | 0 | 94.00 | 0.88 | 636 | 431 | 7 | 0.15 | 332.30 | 2672 | 3036 | -44 | 0.00 |
| H0 | 2026-01-01 | 13.00 | 5675 | 0 | 42.40 | 1.77 | 590 | 470 | 7 | 0.15 | 332.30 | 2579 | 3291 | -32 | 0.00 |
| H0 | 2026-01-01 | 14.00 | -1121 | 1 | 100.10 | -0.17 | -5891 | 454 | 7 | 0.15 | 332.30 | -3904 | 3081 | -39 | 0.00 |
| H0 | 2026-01-01 | 12.00 | -1192 | 1 | 100.00 | -0.18 | -6043 | 460 | 7 | 0.15 | 332.30 | -3806 | 2911 | -49 | 0.00 |
| H0 | 2026-01-01 07:00 |  | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 |
| H0 | 2026-01-02 13:00 |  | 6509 | 0 | 39.20 | 2.32 | 1102 | 453 | 7 | 0.15 | 332.10 | 2948 | 3757 | -32 | 0.00 |
| H1 | 2026-01-01 | 12.00 | 11238 | 0 | 92.40 | 1.27 | -1716 | 483 | 7 | 0.23 | 336.00 | 5108 | 7212 | -56 | 0.00 |
| H1 | 2026-01-01 | 11.00 | 1803 | 1 | 100.10 | 0.17 | -3092 | 507 | 7 | 0.23 | 283.40 | 5709 | -2907 | -55 | 0.00 |
| H1 | 2026-01-01 07:00 |  | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 |
| H1 | 2026-01-02 13:00 |  | 10093 | 0 | 48.80 | 2.13 | 1676 | 482 | 7 | 0.23 | 159.30 | 6442 | 6537 | -164 | 0.00 |
| H1 | 2026-01-01 | 14.00 | 2455 | 1 | 100.20 | 0.29 | -4096 | 486 | 7 | 0.23 | 287.10 | 5002 | -1459 | -65 | 0.00 |
| H1 | 2026-01-01 | 13.00 | 7712 | 0 | 96.40 | 0.88 | -4300 | 416 | 7 | 0.23 | 336.00 | 4721 | 5877 | -162 | 0.00 |
| H2 | 2026-01-01 | 11.00 | 775 | 1 | 100.10 | 0.11 | -5264 | 416 | 10 | 0.20 | 332.70 | -3613 | 4704 | -44 | 0.00 |
| H2 | 2026-01-01 | 12.00 | 707 | 1 | 100.10 | 0.11 | -5500 | 415 | 11 | 0.22 | 332.70 | -3568 | 4513 | -49 | 0.00 |
| H2 | 2026-01-01 | 13.00 | 914 | 1 | 100.10 | 0.13 | -5256 | 428 | 10 | 0.20 | 332.70 | -3449 | 4621 | -42 | 0.00 |
| H2 | 2026-01-01 | 14.00 | 1442 | 1 | 100.10 | 0.21 | -4862 | 414 | 10 | 0.20 | 332.70 | -3516 | 5197 | -34 | 0.00 |
| H2 | 2026-01-01 07:00 |  | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 |
| H2 | 2026-01-02 13:00 |  | 7093 | 0 | 43.70 | 2.03 | 1108 | 362 | 8 | 0.16 | 332.70 | 3274 | 4066 | -37 | 0.00 |
| H3 | 2026-01-01 | 12.00 | 3753 | 0 | 52.30 | 0.97 | -1869 | 242 | 4 | 0.09 | 990.50 | 2762 | 1911 | -66 | 0.00 |
| H3 | 2026-01-01 | 11.00 | 2892 | 0 | 52.40 | 0.76 | -2756 | 223 | 4 | 0.09 | 990.40 | 2910 | 1441 | -86 | 0.00 |
| H3 | 2026-01-01 | 13.00 | 4805 | 0 | 50.20 | 1.26 | -984 | 284 | 4 | 0.09 | 990.50 | 2766 | 2494 | -38 | 0.00 |
| H3 | 2026-01-01 | 14.00 | 3557 | 0 | 52.10 | 0.94 | -2206 | 216 | 4 | 0.09 | 990.40 | 2931 | 1539 | -68 | 0.00 |
| H3 | 2026-01-01 07:00 |  | 4943 | 0 | 49.70 | 1.31 | -727 | 284 | 4 | 0.09 | 990.40 | 2663 | 2744 | -31 | 0.00 |
| H3 | 2026-01-02 13:00 |  | 4943 | 0 | 49.70 | 1.31 | -727 | 284 | 4 | 0.09 | 990.40 | 2663 | 2744 | -31 | 0.00 |
| H4 | 2026-01-01 | 11.00 | 2042 | 0 | 35.30 | 0.90 | -160 | 99 | 23 | 0.13 | 1169.00 | 1424 | 1021 | -18 | 0.00 |
| H4 | 2026-01-01 | 12.00 | -3405 | 1 | 100.10 | -0.64 | -5394 | 89 | 23 | 0.22 | 333.50 | 690 | -3868 | -29 | 0.10 |
| H4 | 2026-01-01 | 13.00 | -3193 | 1 | 100.10 | -0.60 | -5231 | 104 | 15 | 0.23 | 591.80 | 900 | -3687 | -15 | 2.70 |
| H4 | 2026-01-01 | 14.00 | 3126 | 0 | 30.30 | 1.59 | 561 | 138 | 17 | 0.14 | 611.10 | 1485 | 1880 | -14 | 0.00 |
| H4 | 2026-01-01 07:00 |  | 2712 | 0 | 43.00 | 0.96 | 219 | 130 | 15 | 0.15 | 1063.30 | 1533 | 1420 | -17 | 0.00 |
| H4 | 2026-01-02 13:00 |  | 2712 | 0 | 43.00 | 0.96 | 219 | 130 | 15 | 0.15 | 1063.30 | 1533 | 1420 | -17 | 0.00 |
| H5 | 2026-01-01 | 11.00 | -22 | 0 | 98.60 | -0.00 | -3936 | 403 | 4 | 0.07 | 1086.40 | 644 | 1453 | -9 | 0.00 |
| H5 | 2026-01-01 | 12.00 | -941 | 0 | 74.50 | -0.16 | -2750 | 794 | 4 | 0.07 | 99.00 | 2926 | 61 | -233 | 0.00 |
| H5 | 2026-01-01 | 13.00 | -6632 | 1 | 100.10 | -1.15 | -7200 | 317 | 4 | 0.07 | 293.10 | 989 | -5662 | -113 | 0.00 |
| H5 | 2026-01-01 | 14.00 | -12 | 0 | 83.50 | -0.00 | -2478 | 444 | 4 | 0.07 | 1086.40 | 711 | 1420 | -10 | 0.00 |
| H5 | 2026-01-02 13:00 |  | 852 | 0 | 38.00 | 0.29 | -1375 | 748 | 4 | 0.07 | 99.00 | 2734 | 75 | -130 | 0.00 |
| H5 | 2026-01-01 07:00 |  | 852 | 0 | 38.00 | 0.29 | -1375 | 748 | 4 | 0.07 | 99.00 | 2734 | 75 | -130 | 0.00 |
| H6 | 2026-01-01 | 11.00 | 2521 | 1 | 100.10 | 0.25 | -2605 | 1431 | 25 | 0.47 | 287.40 | 5622 | -2807 | -60 | 0.20 |
| H6 | 2026-01-01 | 12.00 | 14012 | 0 | 61.20 | 3.19 | 5220 | 1646 | 13 | 0.23 | 159.10 | 6538 | 7761 | -64 | 0.00 |
| H6 | 2026-01-01 | 13.00 | 2666 | 1 | 100.10 | 0.25 | -2620 | 1504 | 25 | 0.47 | 287.60 | 5620 | -2665 | -61 | 0.10 |
| H6 | 2026-01-01 | 14.00 | 13832 | 0 | 75.90 | 2.53 | 5105 | 1607 | 15 | 0.25 | 159.10 | 6424 | 7703 | -68 | 0.00 |
| H6 | 2026-01-01 07:00 |  | 13030 | 0 | 54.60 | 3.34 | 4889 | 1346 | 16 | 0.31 | 159.00 | 6287 | 6997 | -65 | 0.00 |
| H6 | 2026-01-02 13:00 |  | 13030 | 0 | 54.60 | 3.34 | 4889 | 1346 | 16 | 0.31 | 159.00 | 6287 | 6997 | -65 | 0.00 |
| H7 | 2026-01-01 | 11.00 | 12107 | 0 | 67.40 | 2.84 | 4554 | 1415 | 13 | 0.41 | 159.90 | 5831 | 6552 | -78 | 0.00 |
| H7 | 2026-01-01 | 13.00 | 12546 | 0 | 64.80 | 2.59 | 4945 | 1444 | 13 | 0.39 | 159.90 | 6002 | 6832 | -69 | 0.00 |
| H7 | 2026-01-01 | 12.00 | 223 | 2 | 100.30 | 0.04 | -7318 | 1390 | 16 | 0.56 | 172.10 | -878 | 1446 | -52 | 0.00 |
| H7 | 2026-01-01 | 14.00 | 5018 | 1 | 124.00 | 0.72 | -2192 | 1324 | 15 | 0.47 | 223.20 | 5310 | -266 | -65 | 12.00 |
| H7 | 2026-01-01 07:00 |  | 12910 | 0 | 53.00 | 2.76 | 5231 | 1569 | 13 | 0.39 | 159.90 | 6611 | 6767 | -75 | 0.00 |
| H7 | 2026-01-02 13:00 |  | 12910 | 0 | 53.00 | 2.76 | 5231 | 1569 | 13 | 0.39 | 159.90 | 6611 | 6767 | -75 | 0.00 |

## 2b. Độ bền trên 5 đường giá (gốc + 4 thứ tự cực trị ngẫu nhiên)

Luật ban đầu cho 0 ứng viên. Bước này chạy lại mọi cấu hình không cháy và có lãi ở đường giá gốc trên 4 đường giá khác (chỉ đổi thứ tự đỉnh / đáy trong từng nến M1). Bền = không cháy trên cả 5 đường.

- Cấu hình xét: **160**; bền: **37** (mức A 0, B 1, C 36); cháy trên ít nhất một đường khác: **123**.

### 2b.1 Các cấu hình bền (xếp theo mức rồi trung vị điểm 5 đường)

| ung_vien | ten | muc | dd_max_duong | dd_goc | net_goc | net_tv | diem_tv_duong | trung_vi_diem_lang_gieng | lang_gieng_chay | so_lang_gieng | diem_vung | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U1 | trail=60 | B | 41.90 | 40.70 | 6434.50 | 6321.60 | 1.98 | 1.98 | 7.00 | 23.00 | 1.98 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| U2 | N029 | C | 99.00 | 82.00 | 21838.30 | 21404.90 | 2.14 | 2.29 | 8.00 | 27.00 | 2.21 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| U3 | tia_lap_lai=False | C | 75.20 | 57.20 | 11533.20 | 12379.30 | 2.12 | 1.97 | 4.00 | 24.00 | 1.97 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 10s |
| U4 | N309 | C | 66.40 | 66.40 | 8238.50 | 7784.80 | 1.55 | 1.58 | 2.00 | 24.00 | 1.58 | lot 0.01 ×1.3 trần 0.03; tầng max(10.0; 3.0×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 0; xóa 4/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| U5 | so_tang=12 | C | 79.60 | 77.20 | 11387.50 | 11227.60 | 1.53 | 1.44 | 6.00 | 23.00 | 1.46 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | N094 | C | 82.80 | 70.90 | 10521.20 | 9361.30 | 1.52 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(12.0; 1.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 0; xóa 0/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | buoc_atr=3.0 | C | 88.10 | 59.40 | 6823.00 | 8263.10 | 1.40 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 3.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | hoa_von_tang=6 | C | 94.20 | 65.00 | 10629.90 | 11418.20 | 1.35 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 6; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | loc_xh=True | C | 99.00 | 54.80 | 9048.50 | 10559.40 | 1.31 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | xoa_tu=6 | C | 52.90 | 51.60 | 4953.90 | 4041.40 | 1.27 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/6; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | so_tang=8 | C | 70.40 | 67.20 | 5654.60 | 5143.70 | 1.26 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 8; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | tia_lap_lai=True | C | 72.30 | 45.30 | 3334.30 | 5435.10 | 0.99 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | buoc_min=8.0 | C | 52.30 | 49.60 | 4983.40 | 3792.80 | 0.98 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(8.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | giay_dca=180 | C | 52.60 | 49.70 | 5231.80 | 3762.80 | 0.98 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N211 | C | 78.80 | 54.60 | 3469.50 | 4241.30 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 4; xóa 2/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N340 | C | 52.40 | 49.70 | 4942.90 | 3752.60 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | lot_max=0.2 | C | 52.40 | 49.70 | 4942.90 | 3752.60 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.2; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | xoa=4 | C | 52.40 | 49.70 | 4942.90 | 3752.60 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 4/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | giay_dca=20 | C | 52.20 | 49.70 | 4944.20 | 3728.10 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N033 | C | 96.20 | 56.50 | 9615.70 | 6378.90 | 0.95 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 12; xóa 6/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | buoc_min=12.0 | C | 52.40 | 49.70 | 4968.20 | 3632.50 | 0.94 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(12.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | loc_xh=False | C | 53.10 | 49.50 | 3348.00 | 3548.50 | 0.92 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | kieu_lot=1.2 | C | 93.50 | 91.50 | 6271.10 | 6271.10 | 0.91 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | N141 | C | 75.40 | 61.30 | 2281.10 | 2681.50 | 0.80 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 3.0×ATR) × 16; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 8; xóa 6/3; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | ma_h1=200 | C | 91.80 | 44.90 | 2435.00 | 2614.50 | 0.77 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(3.0; 4.0×ATR) × 40; TP tỉa 0.5; clear 3.0×ATR trail 40; HV 0; xóa 6/3; SMA200 H1; DCA 60s; lặp không; chờ 10s |
|  | N299 | C | 77.50 | 52.90 | 4121.60 | 3981.30 | 0.76 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(6.0; 2.0×ATR) × 20; TP tỉa 1.0; clear 1.5×ATR trail 80; HV 6; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N243 | C | 70.00 | 57.20 | 3013.70 | 3002.20 | 0.74 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(12.0; 3.0×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 8; xóa 0/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N082 | C | 75.30 | 57.20 | 2133.80 | 2134.00 | 0.70 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N101 | C | 92.10 | 84.40 | 3868.50 | 3868.50 | 0.64 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 0.75; clear 1.5×ATR trail 80; HV 6; xóa 0/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | xoa_tu=3 | C | 52.40 | 49.70 | 2796.30 | 2321.30 | 0.60 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/3; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N321 | C | 90.80 | 72.10 | 3185.00 | 2754.10 | 0.50 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(20.0; 4.0×ATR) × 8; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 4; xóa 2/2; SMA200 H1; DCA 20s; lặp không; chờ 60s |
|  | buoc_atr=4.0 | C | 83.90 | 81.50 | 4525.60 | 2358.70 | 0.45 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 4.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N177 | C | 85.10 | 84.30 | 33.10 | 456.60 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 20; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 12; xóa 1/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | ma_h1=200 | C | 80.10 | 41.10 | 259.10 | 259.10 | 0.09 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(8.0; 1.15×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa tat/6; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N213 | C | 85.40 | 52.70 | 318.40 | 318.40 | 0.08 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(1.5; 0.5×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail 40; HV 2; xóa tat/6; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | buoc_min=6.0 | C | 87.10 | 37.20 | 1017.20 | -101.10 | -0.02 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(6.0; 1.15×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa tat/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N136 | C | 83.30 | 61.30 | 80.50 | -199.10 | -0.11 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(1.5; 1.5×ATR) × 5; TP tỉa 0.5; clear 1.5×ATR trail 80; HV 3; xóa 1/2; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |

### 2b.2 Số cấu hình bền theo từng input (trong các cấu hình đã xét)

- **InpLotCoSo** — 0.01: bền 37/156; 0.02: bền 0/4
- **InpHeSoLot / InpDungBangLot** — 1.0: bền 1/2; 1.05: bền 3/4; 1.1: bền 1/2; 1.15: bền 3/22; bang: bền 2/53; 1.2: bền 5/20; 1.3: bền 22/57
- **InpLotTangToiDa** — 0.02: bền 6/31; 0.03: bền 2/6; 0.05: bền 10/40; 0.1: bền 5/22; 0.2: bền 2/39; 0.5: bền 12/22
- **InpBuocMinUSD** — 1.5: bền 7/22; 3.0: bền 1/23; 4.5: bền 0/23; 6.0: bền 3/5; 8.0: bền 6/35; 10.0: bền 14/32; 12.0: bền 3/5; 15.0: bền 1/13; 20.0: bền 2/2
- **InpBuocATR** — 0.5: bền 2/2; 0.8: bền 0/1; 1.15: bền 3/18; 1.5: bền 3/4; 2.0: bền 7/50; 3.0: bền 17/27; 4.0: bền 5/58
- **InpSoTangToiDa** — 5: bền 17/39; 8: bền 6/41; 12: bền 2/5; 16: bền 1/1; 20: bền 5/9; 30: bền 2/30; 40: bền 4/35
- **InpTiaTPBuoc** — 0.5: bền 7/27; 0.75: bền 17/37; 1.0: bền 1/6; 1.5: bền 5/44; 2.0: bền 7/46
- **InpGioTPATR** — 0.5: bền 4/16; 1.0: bền 1/31; 1.5: bền 7/34; 2.0: bền 3/20; 3.0: bền 22/59
- **InpTrailClear / InpTrailGiuPT** — tat: bền 9/53; 40: bền 17/45; 60: bền 6/44; 80: bền 5/18
- **InpHoaVonTuTang** — 0: bền 6/48; 2: bền 15/28; 3: bền 1/25; 4: bền 8/50; 6: bền 3/5; 8: bền 2/2; 12: bền 2/2
- **InpXoaTangLo / InpXoaGomLai** — tat: bền 6/42; 0: bền 4/7; 1: bền 2/4; 2: bền 2/7; 4: bền 7/55; 6: bền 16/45
- **InpXoaTuSoTang** — 2: bền 5/57; 3: bền 10/46; 4: bền 16/38; 6: bền 6/19
- **InpChanNguocXH** — True: bền 19/67; False: bền 18/93
- **InpPP0MA** — 50: bền 1/4; 100: bền 2/48; 200: bền 34/108
- **InpGiayGiuaDCA** — 20: bền 10/39; 60: bền 20/84; 180: bền 7/37
- **InpTiaLapLai** — True: bền 5/71; False: bền 32/89
- **InpGiayChoSauClear** — 10: bền 11/72; 60: bền 26/88

### 2b.3 Láng giềng một bước của các ứng viên bền (đường gốc)

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | sau_max | lot_max | gio_max | buy | sell | swap | gio_chan_ml |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| trail=60:kieu_lot=1.2 | -546 | 1 | 100.10 | -0.08 | -5450 | 319 | 11 | 0.21 | 332.50 | -3848 | 3530 | -33 | 0.00 |
| trail=60:lot_max=0.03 | 6908 | 0 | 46.50 | 1.98 | 881 | 367 | 7 | 0.18 | 332.10 | 3243 | 3932 | -35 | 0.00 |
| trail=60:buoc_min=8.0 | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 |
| trail=60:lot0=0.02 | -1002 | 1 | 100.00 | -0.12 | -5536 | 192 | 11 | 0.24 | 332.50 | -5003 | 5690 | -32 | 0.00 |
| trail=60:buoc_min=12.0 | 6389 | 0 | 40.80 | 2.04 | 967 | 349 | 7 | 0.14 | 332.50 | 3139 | 3517 | -37 | 0.00 |
| trail=60:buoc_atr=3.0 | 896 | 1 | 100.00 | 0.13 | -6201 | 426 | 13 | 0.26 | 332.70 | -3349 | 4665 | -41 | 0.00 |
| trail=60:so_tang=40 | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 |
| trail=60:so_tang=20 | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 |
| trail=60:tia_tp=1.0 | 70 | 1 | 100.10 | 0.01 | -3578 | 380 | 10 | 0.20 | 160.10 | -2921 | 3253 | -53 | 0.00 |
| trail=60:tia_tp=2.0 | 6549 | 0 | 43.70 | 1.89 | 1045 | 349 | 7 | 0.14 | 332.60 | 3099 | 3717 | -39 | 0.00 |
| trail=60:tp_atr=3.0 | 5728 | 0 | 46.40 | 1.74 | 409 | 205 | 7 | 0.14 | 332.40 | 2812 | 3220 | -36 | 0.00 |
| trail=60:tp_atr=1.5 | -459 | 1 | 100.10 | -0.07 | -6095 | 465 | 10 | 0.20 | 332.60 | -3664 | 3468 | -47 | 0.00 |
| trail=60:trail=40 | 5624 | 0 | 47.70 | 1.64 | 309 | 308 | 7 | 0.14 | 332.60 | 2620 | 3211 | -35 | 0.00 |
| trail=60:hoa_von_tang=3 | 5966 | 0 | 41.60 | 1.90 | 676 | 345 | 7 | 0.14 | 332.50 | 2882 | 3351 | -38 | 0.00 |
| trail=60:hoa_von_tang=6 | 6444 | 0 | 40.70 | 2.06 | 1006 | 355 | 7 | 0.14 | 332.50 | 3108 | 3603 | -38 | 0.00 |
| trail=60:xoa=0 | 6580 | 0 | 40.70 | 2.10 | 857 | 357 | 7 | 0.14 | 332.50 | 3202 | 3646 | -35 | 0.00 |
| trail=60:xoa_tu=3 | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 |
| trail=60:loc_xh=True | 6408 | 0 | 40.70 | 2.05 | 970 | 360 | 7 | 0.14 | 332.50 | 3088 | 3587 | -38 | 0.00 |
| trail=60:ma_h1=100 | 860 | 1 | 100.00 | 0.17 | -4300 | 314 | 16 | 0.28 | 332.50 | 2581 | -1454 | -36 | 0.00 |
| trail=60:giay_dca=60 | 6891 | 0 | 40.70 | 2.20 | 981 | 366 | 7 | 0.14 | 332.50 | 3211 | 3947 | -35 | 0.00 |
| trail=60:tia_lap_lai=False | 6751 | 0 | 40.70 | 2.15 | 864 | 366 | 7 | 0.14 | 332.50 | 3228 | 3790 | -35 | 0.00 |
| trail=60:cho_clear=60 | -472 | 1 | 100.00 | -0.07 | -5994 | 343 | 9 | 0.18 | 332.60 | -3640 | 3394 | -39 | 0.00 |
| N029:lot0=0.02 | 16178 | 1 | 102.50 | 0.73 | -3635 | 2160 | 19 | 0.82 | 287.20 | 14752 | 2335 | -130 | 0.00 |
| N029:kieu_lot=1.1 | 19307 | 0 | 62.40 | 2.52 | 6718 | 2202 | 19 | 0.53 | 159.10 | 8137 | 11450 | -66 | 0.00 |
| N029:kieu_lot=bang | 21085 | 0 | 79.20 | 2.32 | 7234 | 2387 | 19 | 0.54 | 159.00 | 8538 | 12901 | -68 | 0.00 |
| N029:lot_max=0.03 | 6135 | 2 | 100.10 | 0.76 | -4811 | 2340 | 19 | 0.41 | 159.10 | 101 | 6445 | -69 | 0.00 |
| N029:lot_max=0.1 | 22097 | 0 | 87.20 | 2.58 | 7138 | 2524 | 19 | 0.71 | 74.80 | 9409 | 12986 | -81 | 0.00 |
| N029:buoc_min=6.0 | 8407 | 1 | 100.10 | 0.55 | -4852 | 3098 | 19 | 0.65 | 134.90 | 10277 | -1381 | -106 | 0.00 |
| N029:buoc_min=10.0 | 19120 | 0 | 83.70 | 2.39 | 6144 | 1986 | 19 | 0.65 | 74.40 | 8063 | 11416 | -71 | 0.00 |
| N029:buoc_atr=0.8 | 10440 | 1 | 100.10 | 1.27 | -1555 | 1972 | 19 | 0.48 | 158.90 | -172 | 10909 | -68 | 0.00 |
| N029:so_tang=16 | 21526 | 0 | 86.00 | 2.78 | 6775 | 2476 | 15 | 0.46 | 74.80 | 9079 | 12744 | -81 | 0.00 |
| N029:so_tang=30 | 21801 | 0 | 96.00 | 2.72 | 6954 | 2494 | 29 | 0.88 | 74.10 | 9264 | 12834 | -82 | 0.00 |
| N029:tia_tp=1.0 | 2963 | 2 | 100.40 | 0.31 | -11775 | 2415 | 19 | 0.62 | 623.50 | -444 | 3732 | -74 | 0.00 |
| N029:tia_tp=2.0 | 6142 | 1 | 100.00 | 0.43 | -1802 | 2147 | 19 | 0.61 | 287.80 | 8178 | -1690 | -72 | 0.00 |
| N029:tp_atr=1.0 | 22094 | 0 | 70.70 | 2.34 | 7595 | 3004 | 19 | 0.57 | 159.00 | 9309 | 13146 | -73 | 0.00 |
| N029:tp_atr=2.0 | 21919 | 0 | 81.50 | 2.73 | 7017 | 2257 | 19 | 0.56 | 74.80 | 9171 | 13094 | -89 | 0.00 |
| N029:trail=40 | 1556 | 2 | 100.10 | 0.13 | -10159 | 2255 | 19 | 0.62 | 134.80 | 7697 | -5842 | -73 | 0.00 |
| N029:trail=80 | 18510 | 0 | 89.20 | 1.39 | 291 | 2011 | 19 | 0.62 | 623.50 | 7729 | 11143 | -77 | 0.00 |
| N029:hoa_von_tang=3 | 8996 | 2 | 100.20 | 1.10 | -3128 | 2268 | 19 | 0.51 | 74.10 | 2352 | 6941 | -90 | 0.00 |
| N029:hoa_von_tang=0 | 23481 | 0 | 88.50 | 1.45 | 514 | 1553 | 19 | 0.67 | 623.50 | 10052 | 13789 | -74 | 0.00 |
| N029:xoa=tat | 22329 | 0 | 88.50 | 2.55 | 7370 | 2527 | 19 | 0.62 | 74.10 | 9134 | 13199 | -84 | 0.00 |
| N029:xoa=1 | 17946 | 0 | 80.40 | 1.61 | 1080 | 1970 | 19 | 0.62 | 623.50 | 7561 | 10642 | -74 | 0.00 |
| N029:xoa_tu=3 | 21878 | 0 | 81.10 | 2.73 | 7001 | 2492 | 19 | 0.56 | 74.80 | 9348 | 12827 | -81 | 0.00 |
| N029:xoa_tu=6 | 21819 | 0 | 80.90 | 2.73 | 6964 | 2485 | 19 | 0.56 | 74.10 | 9178 | 12938 | -83 | 0.00 |
| N029:loc_xh=True | 21672 | 0 | 81.70 | 2.71 | 6914 | 2480 | 19 | 0.56 | 74.80 | 9298 | 12671 | -81 | 0.00 |
| N029:ma_h1=100 | 22707 | 0 | 74.90 | 2.84 | 7634 | 2604 | 19 | 0.56 | 74.80 | 10586 | 12418 | -124 | 0.00 |
| N029:tia_lap_lai=False | 15524 | 0 | 84.20 | 2.29 | 5554 | 1734 | 19 | 0.51 | 611.60 | 6202 | 9883 | -80 | 0.00 |
| N029:giay_dca=60 | 18659 | 0 | 86.90 | 1.41 | 116 | 2097 | 19 | 0.62 | 623.50 | 8422 | 10505 | -85 | 0.00 |
| N029:cho_clear=10 | 17927 | 0 | 96.60 | 1.29 | -1113 | 2013 | 19 | 0.62 | 623.50 | 8144 | 10142 | -81 | 0.00 |
| tia_lap_lai=False:lot0=0.02 | -14786 | 3 | 103.70 | -1.57 | -17424 | 390 | 31 | 0.30 | 369.10 | -10006 | -2511 | -175 | 0.30 |
| tia_lap_lai=False:kieu_lot=1.15 | 11533 | 0 | 57.20 | 1.97 | 1150 | 1137 | 34 | 0.29 | 311.70 | 4916 | 6882 | -58 | 0.00 |
| tia_lap_lai=False:kieu_lot=1.2 | 11533 | 0 | 57.20 | 1.97 | 1150 | 1137 | 34 | 0.29 | 311.70 | 4916 | 6882 | -58 | 0.00 |
| tia_lap_lai=False:lot_max=0.03 | 12792 | 0 | 60.40 | 2.96 | 4913 | 1308 | 16 | 0.34 | 158.90 | 6142 | 6869 | -64 | 0.00 |
| tia_lap_lai=False:buoc_min=12.0 | 11358 | 0 | 72.10 | 1.53 | 119 | 1142 | 29 | 0.29 | 326.90 | 4979 | 6766 | -58 | 0.00 |
| tia_lap_lai=False:buoc_min=20.0 | 10624 | 0 | 63.60 | 1.67 | 692 | 1005 | 28 | 0.27 | 323.60 | 4544 | 6406 | -48 | 0.00 |
| tia_lap_lai=False:buoc_atr=1.5 | -2221 | 2 | 100.10 | -0.28 | -7597 | 1265 | 32 | 0.31 | 287.60 | -2104 | 147 | -52 | 0.80 |
| tia_lap_lai=False:buoc_atr=3.0 | 385 | 1 | 100.10 | 0.05 | -6329 | 822 | 16 | 0.19 | 332.70 | -3428 | 4078 | -53 | 0.00 |
| tia_lap_lai=False:so_tang=30 | 11422 | 0 | 57.60 | 1.94 | 1150 | 1133 | 29 | 0.29 | 315.00 | 4916 | 6770 | -58 | 0.00 |
| tia_lap_lai=False:tia_tp=1.0 | 5546 | 0 | 94.80 | 0.80 | 266 | 604 | 28 | 0.25 | 327.00 | 2329 | 4057 | -32 | 0.00 |
| tia_lap_lai=False:tia_tp=2.0 | 13038 | 0 | 56.80 | 3.15 | 5093 | 1300 | 12 | 0.19 | 159.00 | 6436 | 6886 | -68 | 0.00 |
| tia_lap_lai=False:tp_atr=0.5 | 11371 | 0 | 78.30 | 1.53 | -463 | 2075 | 29 | 0.29 | 326.90 | 5144 | 6492 | -57 | 0.00 |
| tia_lap_lai=False:tp_atr=1.5 | 10937 | 0 | 63.10 | 1.76 | 736 | 738 | 28 | 0.27 | 323.70 | 4533 | 6696 | -48 | 0.00 |
| tia_lap_lai=False:trail=40 | 10854 | 0 | 54.00 | 2.88 | 4371 | 1238 | 15 | 0.23 | 159.30 | 5482 | 5634 | -57 | 0.00 |
| tia_lap_lai=False:trail=80 | 12614 | 0 | 56.30 | 2.16 | 1548 | 1097 | 34 | 0.29 | 311.70 | 5365 | 7554 | -58 | 0.00 |
| tia_lap_lai=False:hoa_von_tang=2 | 11744 | 0 | 54.80 | 3.07 | 4350 | 1448 | 12 | 0.17 | 75.50 | 5988 | 6042 | -76 | 0.00 |
| tia_lap_lai=False:xoa=0 | 9597 | 0 | 54.10 | 2.30 | 693 | 969 | 34 | 0.26 | 315.10 | 4344 | 5900 | -124 | 0.00 |
| tia_lap_lai=False:xoa_tu=3 | 11533 | 0 | 57.20 | 1.97 | 1150 | 1137 | 34 | 0.29 | 311.70 | 4916 | 6882 | -58 | 0.00 |
| tia_lap_lai=False:xoa_tu=6 | 11533 | 0 | 57.20 | 1.97 | 1150 | 1137 | 34 | 0.29 | 311.70 | 4916 | 6882 | -58 | 0.00 |
| tia_lap_lai=False:loc_xh=True | 11494 | 0 | 57.20 | 1.96 | 1147 | 1136 | 34 | 0.29 | 311.70 | 4916 | 6842 | -58 | 0.00 |
| tia_lap_lai=False:ma_h1=100 | 6009 | 1 | 100.30 | 1.03 | -3427 | 1018 | 34 | 0.29 | 311.70 | 3967 | 2307 | -45 | 0.10 |
| tia_lap_lai=False:giay_dca=60 | 11820 | 0 | 57.30 | 2.02 | 1310 | 1158 | 34 | 0.29 | 311.70 | 5103 | 6982 | -58 | 0.00 |
| tia_lap_lai=False:cho_clear=60 | 10586 | 0 | 63.00 | 1.69 | 443 | 1035 | 29 | 0.27 | 323.70 | 4638 | 6216 | -57 | 0.00 |
| N309:lot0=0.02 | 15894 | 0 | 71.60 | 2.13 | 1646 | 547 | 14 | 0.42 | 332.50 | 7478 | 9133 | -83 | 0.00 |
| N309:lot_max=0.02 | 8347 | 0 | 55.00 | 1.96 | 1292 | 560 | 9 | 0.18 | 332.70 | 3579 | 5032 | -30 | 0.00 |
| N309:kieu_lot=1.2 | 7588 | 0 | 54.20 | 1.81 | 1015 | 511 | 11 | 0.27 | 332.30 | 3457 | 4363 | -33 | 0.00 |
| N309:lot_max=0.05 | 9185 | 0 | 83.20 | 1.57 | 4023 | 622 | 9 | 0.33 | 167.50 | 4559 | 4639 | -36 | 0.00 |
| N309:buoc_min=8.0 | 8247 | 0 | 66.40 | 1.58 | 822 | 568 | 9 | 0.24 | 332.40 | 3761 | 4774 | -31 | 0.00 |
| N309:buoc_min=12.0 | 8083 | 0 | 66.60 | 1.55 | 658 | 546 | 9 | 0.24 | 332.40 | 3720 | 4651 | -31 | 0.00 |
| N309:buoc_atr=4.0 | 7258 | 0 | 47.80 | 2.34 | 2815 | 501 | 7 | 0.18 | 159.20 | 3694 | 3773 | -43 | 0.00 |
| N309:buoc_atr=2.0 | 11548 | 0 | 80.00 | 1.54 | 621 | 795 | 12 | 0.31 | 332.50 | 4751 | 7239 | -37 | 0.00 |
| N309:so_tang=30 | 8238 | 0 | 66.40 | 1.58 | 814 | 565 | 9 | 0.24 | 332.40 | 3748 | 4779 | -31 | 0.00 |
| N309:tia_tp=1.5 | 9438 | 0 | 61.50 | 2.27 | 4003 | 642 | 9 | 0.22 | 269.00 | 4623 | 5043 | -35 | 0.00 |
| N309:tp_atr=1.0 | 8917 | 0 | 65.20 | 2.02 | 3322 | 982 | 9 | 0.24 | 167.20 | 4524 | 4766 | -41 | 0.00 |
| N309:tp_atr=2.0 | 8202 | 0 | 61.60 | 1.61 | 1044 | 397 | 9 | 0.24 | 332.30 | 3771 | 4693 | -49 | 0.00 |
| N309:trail=tat | 8029 | 0 | 75.90 | 1.32 | -480 | 585 | 11 | 0.30 | 332.60 | 4094 | 4339 | -43 | 0.00 |
| N309:trail=60 | 2527 | 1 | 100.00 | 0.36 | -5610 | 664 | 11 | 0.27 | 332.70 | -2913 | 5879 | -36 | 0.00 |
| N309:xoa=2 | 8238 | 0 | 66.40 | 1.58 | 814 | 565 | 9 | 0.24 | 332.40 | 3748 | 4779 | -31 | 0.00 |
| N309:hoa_von_tang=2 | 7451 | 0 | 66.40 | 1.43 | 391 | 599 | 9 | 0.24 | 332.40 | 3470 | 4269 | -30 | 0.00 |
| N309:xoa=6 | 8238 | 0 | 66.40 | 1.58 | 814 | 565 | 9 | 0.24 | 332.40 | 3748 | 4779 | -31 | 0.00 |
| N309:xoa_tu=4 | 8196 | 0 | 66.40 | 1.57 | 772 | 565 | 9 | 0.24 | 332.40 | 3759 | 4725 | -31 | 0.00 |
| N309:loc_xh=True | 8460 | 0 | 66.40 | 1.62 | 930 | 569 | 9 | 0.24 | 332.40 | 3704 | 5044 | -31 | 0.00 |
| N309:xoa_tu=2 | 8240 | 0 | 66.40 | 1.58 | 815 | 565 | 9 | 0.24 | 332.40 | 3748 | 4779 | -31 | 0.00 |
| N309:ma_h1=100 | 2189 | 1 | 101.20 | 0.39 | -4399 | 516 | 12 | 0.28 | 332.40 | 2750 | -273 | -33 | 0.00 |
| N309:giay_dca=60 | 8483 | 0 | 68.50 | 1.63 | 946 | 580 | 9 | 0.24 | 332.40 | 3673 | 5098 | -31 | 0.00 |
| N309:tia_lap_lai=False | 8389 | 0 | 66.40 | 1.83 | 1140 | 576 | 9 | 0.24 | 332.80 | 3617 | 5060 | -31 | 0.00 |
| N309:cho_clear=60 | 7507 | 0 | 74.20 | 1.52 | 552 | 509 | 9 | 0.24 | 332.60 | 3537 | 4276 | -51 | 0.00 |
| so_tang=12:lot0=0.02 | -5748 | 4 | 100.10 | -0.56 | -18710 | 478 | 11 | 0.47 | 135.30 | -2644 | -1679 | -211 | 0.00 |
| so_tang=12:lot_max=0.03 | 9531 | 0 | 74.20 | 1.44 | -713 | 395 | 11 | 0.30 | 336.20 | 4418 | 5810 | -89 | 0.00 |
| so_tang=12:kieu_lot=1.2 | 8676 | 0 | 84.70 | 1.26 | 1463 | 393 | 11 | 0.35 | 332.50 | 4454 | 4979 | -60 | 0.00 |
| so_tang=12:lot_max=0.1 | 12506 | 0 | 69.80 | 1.76 | 4509 | 513 | 11 | 0.62 | 167.60 | 5988 | 7523 | -63 | 0.00 |
| so_tang=12:buoc_min=3.0 | 11388 | 0 | 77.20 | 1.46 | -380 | 479 | 11 | 0.43 | 336.10 | 4909 | 7517 | -59 | 0.00 |
| so_tang=12:buoc_atr=1.5 | 9477 | 1 | 100.00 | 1.16 | -2536 | 803 | 11 | 0.43 | 80.50 | 1157 | 10156 | -98 | 0.00 |
| so_tang=12:buoc_atr=3.0 | 9095 | 0 | 61.50 | 1.87 | 3747 | 355 | 8 | 0.28 | 160.00 | 5024 | 4588 | -44 | 0.00 |
| so_tang=12:so_tang=16 | 11642 | 0 | 89.40 | 1.29 | -350 | 483 | 15 | 0.43 | 332.90 | 4909 | 7734 | -59 | 0.00 |
| so_tang=12:tia_tp=1.5 | 10988 | 0 | 57.80 | 2.61 | 2700 | 472 | 10 | 0.31 | 153.30 | 5814 | 6040 | -102 | 0.00 |
| so_tang=12:tp_atr=2.0 | 6286 | 1 | 100.10 | 0.84 | -2270 | 851 | 11 | 0.36 | 159.20 | -337 | 7646 | -75 | 0.00 |
| so_tang=12:trail=40 | 5056 | 1 | 100.20 | 0.71 | -1827 | 455 | 11 | 0.36 | 159.20 | -1388 | 6448 | -55 | 0.00 |
| so_tang=12:hoa_von_tang=3 | 8532 | 0 | 80.90 | 1.16 | -1228 | 405 | 11 | 0.43 | 672.40 | 4589 | 4981 | -64 | 0.00 |
| so_tang=12:hoa_von_tang=6 | 12083 | 0 | 76.30 | 1.55 | 46 | 478 | 11 | 0.43 | 336.10 | 5262 | 7843 | -58 | 0.00 |
| so_tang=12:xoa=2 | 11388 | 0 | 77.20 | 1.46 | -380 | 479 | 11 | 0.43 | 336.10 | 4909 | 7517 | -59 | 0.00 |
| so_tang=12:xoa=6 | 11388 | 0 | 77.20 | 1.46 | -380 | 479 | 11 | 0.43 | 336.10 | 4909 | 7517 | -59 | 0.00 |
| so_tang=12:xoa_tu=2 | 11352 | 0 | 77.20 | 1.46 | -415 | 477 | 11 | 0.43 | 336.10 | 4874 | 7517 | -59 | 0.00 |
| so_tang=12:xoa_tu=4 | 11388 | 0 | 77.20 | 1.46 | -379 | 479 | 11 | 0.43 | 336.10 | 4909 | 7517 | -59 | 0.00 |
| so_tang=12:loc_xh=True | 10385 | 0 | 86.00 | 1.33 | -652 | 469 | 11 | 0.43 | 336.10 | 4388 | 7035 | -62 | 0.00 |
| so_tang=12:ma_h1=100 | 5255 | 1 | 100.10 | 0.67 | -5268 | 465 | 11 | 0.43 | 336.10 | 4985 | 1309 | -53 | 0.00 |
| so_tang=12:giay_dca=60 | 10492 | 0 | 85.80 | 1.35 | -627 | 476 | 11 | 0.43 | 336.10 | 4644 | 6887 | -67 | 0.00 |
| so_tang=12:tia_lap_lai=True | 13108 | 0 | 51.00 | 2.73 | 4391 | 551 | 9 | 0.33 | 159.20 | 6292 | 7889 | -67 | 0.00 |
| so_tang=12:cho_clear=60 | 5756 | 1 | 100.10 | 0.78 | -2862 | 537 | 11 | 0.33 | 88.20 | -577 | 7430 | -63 | 0.00 |

## 3. Tham khảo: hedge V0.22 (không phát hành) trên các ứng viên đầu

`v022` = hedge như V0.22 đã dựng; `sau15_khoa` = hedge từ 15 khoảng tầng, không giảm cấp, khóa DCA sau khi đã hedge.

| ten | hedge | net | chay | dd_pt | net_dd | bo2thang | basket | sau_max | lot_max | gio_max | buy | sell | swap | gio_chan_ml | co_hd | gio_khoa |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U1 | sau15_khoa | 6434 | 0 | 40.70 | 2.05 | 996 | 362 | 7 | 0.14 | 332.50 | 3113 | 3589 | -38 | 0.00 | 0 | 0.00 |
| U1 | v022 | -271 | 1 | 100.00 | -0.04 | -5671 | 363 | 9 | 0.17 | 332.50 | -3624 | 3620 | -43 | 0.00 | 3 | 0.00 |
| U2 | sau15_khoa | 4980 | 0 | 47.60 | 1.31 | -88 | 985 | 14 | 0.27 | 741.20 | 602 | 4865 | -140 | 0.00 | 2 | 1951.20 |
| U2 | v022 | 8901 | 0 | 51.40 | 1.65 | 485 | 1178 | 19 | 0.40 | 972.50 | 4859 | 4478 | -132 | 0.00 | 38 | 633.80 |
| U3 | sau15_khoa | 6081 | 0 | 54.10 | 1.57 | 870 | 920 | 14 | 0.21 | 671.20 | 3326 | 3019 | -142 | 0.00 | 2 | 1215.50 |
| U3 | v022 | 8247 | 0 | 46.80 | 2.47 | 1341 | 921 | 33 | 0.18 | 311.70 | 3945 | 5560 | -138 | 0.00 | 7 | 119.50 |

