# Dò set Phoenix Grid cho tài khoản cent 10.000 USC — kết quả mô phỏng

> Mô phỏng Python `mo_phong_phoenix.py` (đường giá nội suy ≤ 0,5 USD trong nến M1, spread 0,26, swap, margin
> level 500%), KHÔNG phải backtest MT5. Chỉ dùng để so sánh cấu hình với nhau. Luật chọn ghi trong
> `do_tim_set_cent.py` trước khi chạy.

## 1. DEV 01/01–30/04/2026: mọi biến thể

- Biến thể (cấu hình khác nhau, đường giá gốc): **487** (ngẫu nhiên + tham chiếu: 363; láng giềng: 124).
- Cháy tài khoản ít nhất một lần: **216** (44%).
- Ở đường giá gốc: không cháy, DD ≤ 20%, lãi > 0, bỏ 2 tháng tốt nhất ≥ 0: **0**; không cháy, DD ≤ 35%, lãi > 0: **43**; không cháy, lãi > 0, DD lớn hơn: **148**.

### 1.1 Tham chiếu

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| V0.21 set hệ số 1,2 đã gửi | 8842 | 1 | 100.00 | 0.78 | -3077 | 2304 | 22.59 | 5185 | 0.31 | 2.80 | 158.90 | 18 | 1.43 | -8471.40 | 8622 | 224 | -55 |
| Gần Hydra: bảng lot, bước nhỏ | 544 | 2 | 100.20 | 0.03 | -23208 | 7331 | 71.87 | 24344 | 0.11 | 0.80 | 100.90 | 29 | 3.62 | -13634.60 | 4556 | 8320 | -244 |
| V0.21 mặc định (lot đều) | -16424 | 2 | 100.10 | -1.51 | -24530 | 552 | 5.41 | 2128 | 0.25 | 6.00 | 868.30 | 39 | 0.35 | -19110.70 | -9812 | -6130 | -20 |

### 1.2 Tỷ lệ cháy theo từng input (bước 1, mẫu ngẫu nhiên)

Mỗi dòng: một giá trị của input; số cấu hình có giá trị đó, % cháy ít nhất một lần, trung vị DD, số cấu hình không cháy.

- **InpHeSoLot / InpDungBangLot** — 1.0: 55 cấu hình, cháy 40%, DD trung vị 84%, không cháy 33; 1.05: 57 cấu hình, cháy 47%, DD trung vị 87%, không cháy 30; 1.1: 47 cấu hình, cháy 47%, DD trung vị 99%, không cháy 25; 1.15: 50 cấu hình, cháy 52%, DD trung vị 100%, không cháy 24; bang: 58 cấu hình, cháy 59%, DD trung vị 100%, không cháy 24; 1.2: 42 cấu hình, cháy 64%, DD trung vị 100%, không cháy 15; 1.3: 51 cấu hình, cháy 57%, DD trung vị 100%, không cháy 22
- **InpLotTangToiDa** — 0.02: 61 cấu hình, cháy 46%, DD trung vị 98%, không cháy 33; 0.03: 49 cấu hình, cháy 61%, DD trung vị 100%, không cháy 19; 0.05: 62 cấu hình, cháy 56%, DD trung vị 100%, không cháy 27; 0.1: 72 cấu hình, cháy 40%, DD trung vị 87%, không cháy 43; 0.2: 60 cấu hình, cháy 57%, DD trung vị 100%, không cháy 26; 0.5: 56 cấu hình, cháy 55%, DD trung vị 100%, không cháy 25
- **InpBuocMinUSD** — 1.5: 36 cấu hình, cháy 44%, DD trung vị 94%, không cháy 20; 3.0: 36 cấu hình, cháy 53%, DD trung vị 100%, không cháy 17; 4.5: 31 cấu hình, cháy 48%, DD trung vị 99%, không cháy 16; 6.0: 38 cấu hình, cháy 66%, DD trung vị 100%, không cháy 13; 8.0: 39 cấu hình, cháy 49%, DD trung vị 100%, không cháy 20; 10.0: 44 cấu hình, cháy 45%, DD trung vị 89%, không cháy 24; 12.0: 26 cấu hình, cháy 54%, DD trung vị 100%, không cháy 12; 15.0: 40 cấu hình, cháy 42%, DD trung vị 94%, không cháy 23; 20.0: 39 cấu hình, cháy 51%, DD trung vị 100%, không cháy 19; 25.0: 31 cấu hình, cháy 71%, DD trung vị 100%, không cháy 9
- **InpBuocATR** — 0.5: 50 cấu hình, cháy 48%, DD trung vị 99%, không cháy 26; 0.8: 47 cấu hình, cháy 40%, DD trung vị 92%, không cháy 28; 1.15: 63 cấu hình, cháy 52%, DD trung vị 100%, không cháy 30; 1.5: 36 cấu hình, cháy 64%, DD trung vị 100%, không cháy 13; 2.0: 59 cấu hình, cháy 53%, DD trung vị 100%, không cháy 28; 3.0: 50 cấu hình, cháy 48%, DD trung vị 95%, không cháy 26; 4.0: 55 cấu hình, cháy 60%, DD trung vị 100%, không cháy 22
- **InpSoTangToiDa** — 5: 52 cấu hình, cháy 2%, DD trung vị 57%, không cháy 51; 8: 59 cấu hình, cháy 37%, DD trung vị 87%, không cháy 37; 12: 48 cấu hình, cháy 54%, DD trung vị 100%, không cháy 22; 16: 45 cấu hình, cháy 64%, DD trung vị 100%, không cháy 16; 20: 48 cấu hình, cháy 60%, DD trung vị 100%, không cháy 19; 30: 54 cấu hình, cháy 70%, DD trung vị 100%, không cháy 16; 40: 54 cấu hình, cháy 78%, DD trung vị 100%, không cháy 12
- **InpTiaTPBuoc** — 0.5: 79 cấu hình, cháy 43%, DD trung vị 85%, không cháy 45; 0.75: 58 cấu hình, cháy 33%, DD trung vị 86%, không cháy 39; 1.0: 61 cấu hình, cháy 61%, DD trung vị 100%, không cháy 24; 1.5: 83 cấu hình, cháy 65%, DD trung vị 100%, không cháy 29; 2.0: 79 cấu hình, cháy 54%, DD trung vị 100%, không cháy 36
- **InpGioTPATR** — 0.5: 67 cấu hình, cháy 39%, DD trung vị 91%, không cháy 41; 1.0: 78 cấu hình, cháy 63%, DD trung vị 100%, không cháy 29; 1.5: 77 cấu hình, cháy 48%, DD trung vị 99%, không cháy 40; 2.0: 69 cấu hình, cháy 52%, DD trung vị 100%, không cháy 33; 3.0: 69 cấu hình, cháy 57%, DD trung vị 100%, không cháy 30
- **InpTrailClear / InpTrailGiuPT** — tat: 103 cấu hình, cháy 51%, DD trung vị 100%, không cháy 50; 40: 85 cấu hình, cháy 53%, DD trung vị 100%, không cháy 40; 60: 88 cấu hình, cháy 47%, DD trung vị 95%, không cháy 47; 80: 84 cấu hình, cháy 57%, DD trung vị 100%, không cháy 36
- **InpHoaVonTuTang** — 0: 48 cấu hình, cháy 44%, DD trung vị 84%, không cháy 27; 2: 49 cấu hình, cháy 55%, DD trung vị 100%, không cháy 22; 3: 51 cấu hình, cháy 51%, DD trung vị 100%, không cháy 25; 4: 47 cấu hình, cháy 45%, DD trung vị 87%, không cháy 26; 6: 60 cấu hình, cháy 62%, DD trung vị 100%, không cháy 23; 8: 57 cấu hình, cháy 47%, DD trung vị 99%, không cháy 30; 12: 48 cấu hình, cháy 58%, DD trung vị 100%, không cháy 20
- **InpXoaTangLo / InpXoaGomLai** — tat: 55 cấu hình, cháy 47%, DD trung vị 98%, không cháy 29; 0: 57 cấu hình, cháy 56%, DD trung vị 100%, không cháy 25; 1: 62 cấu hình, cháy 58%, DD trung vị 100%, không cháy 26; 2: 61 cấu hình, cháy 48%, DD trung vị 93%, không cháy 32; 4: 60 cấu hình, cháy 55%, DD trung vị 100%, không cháy 27; 6: 65 cấu hình, cháy 48%, DD trung vị 99%, không cháy 34
- **InpXoaTuSoTang** — 2: 79 cấu hình, cháy 48%, DD trung vị 99%, không cháy 41; 3: 84 cấu hình, cháy 49%, DD trung vị 94%, không cháy 43; 4: 109 cấu hình, cháy 50%, DD trung vị 100%, không cháy 55; 6: 88 cấu hình, cháy 61%, DD trung vị 100%, không cháy 34
- **InpChanNguocXH** — True: 186 cấu hình, cháy 52%, DD trung vị 100%, không cháy 90; False: 174 cấu hình, cháy 52%, DD trung vị 100%, không cháy 83
- **InpPP0MA** — 20: 98 cấu hình, cháy 66%, DD trung vị 100%, không cháy 33; 50: 79 cấu hình, cháy 59%, DD trung vị 100%, không cháy 32; 100: 107 cấu hình, cháy 57%, DD trung vị 100%, không cháy 46; 200: 76 cấu hình, cháy 18%, DD trung vị 64%, không cháy 62
- **InpGiayGiuaDCA** — 20: 104 cấu hình, cháy 53%, DD trung vị 100%, không cháy 49; 60: 149 cấu hình, cháy 48%, DD trung vị 99%, không cháy 78; 180: 107 cấu hình, cháy 57%, DD trung vị 100%, không cháy 46
- **InpTiaLapLai** — True: 162 cấu hình, cháy 63%, DD trung vị 100%, không cháy 60; False: 198 cấu hình, cháy 43%, DD trung vị 92%, không cháy 113
- **InpGiayChoSauClear** — 10: 169 cấu hình, cháy 50%, DD trung vị 100%, không cháy 85; 60: 191 cấu hình, cháy 54%, DD trung vị 100%, không cháy 88

### 1.3 Các cấu hình không cháy (bước 1 + 2), xếp theo mức rồi lãi / DD

| ten | nhom | muc | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N049:buoc_min=12.0 | lang_gieng_ben | B | 27864 | 0 | 32.40 | 5.33 | 9505 | 3726 | 36.53 | 5996 | 0.11 | 1.80 | 158.70 | 26 | 0.71 | 9723.40 | 11029 | 17209 | -69 | lot 0.01 ×1.15 trần 0.1; tầng max(12.0; 0.5×ATR) × 30; TP tỉa 2.0; clear 0.5×ATR trail 80; HV 8; xóa 4/4; SMA200 H1; DCA 60s; lặp không; chờ 60s |
| N044 | ngau_nhien | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:kieu_lot=1.15 | lang_gieng_ben | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 ×1.15 trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:kieu_lot=1.2 | lang_gieng_ben | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 ×1.2 trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:so_tang=30 | lang_gieng_ben | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:xoa_tu=3 | lang_gieng_ben | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:xoa_tu=6 | lang_gieng_ben | B | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/6; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:loc_xh=True | lang_gieng_ben | B | 12984 | 0 | 32.10 | 3.33 | 4889 | 1345 | 13.19 | 2087 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6278 | 6960 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
| N044:trail=80 | lang_gieng_ben | B | 15116 | 0 | 34.50 | 3.24 | 5588 | 1380 | 13.53 | 2161 | 0.32 | 5.60 | 160.10 | 13 | 0.25 | 8089.90 | 6888 | 8521 | -67 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:tia_tp=2.0 | lang_gieng_ben | B | 13086 | 0 | 33.70 | 3.16 | 5086 | 1300 | 12.75 | 1996 | 0.42 | 5.90 | 159.00 | 11 | 0.19 | 8141.70 | 6445 | 6926 | -69 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 2.0; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:giay_dca=60 | lang_gieng_ben | B | 12853 | 0 | 34.00 | 3.11 | 4844 | 1341 | 13.15 | 2066 | 0.39 | 5.60 | 159.00 | 12 | 0.23 | 8026.00 | 6115 | 6992 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 60s; lặp có; chờ 10s |
| N044:hoa_von_tang=2 | lang_gieng_ben | B | 12034 | 0 | 32.60 | 3.08 | 4452 | 1474 | 14.45 | 2282 | 0.41 | 5.40 | 75.50 | 12 | 0.19 | 8087.20 | 6201 | 6121 | -74 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 2; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N311 | ngau_nhien | B | 12910 | 0 | 32.20 | 2.76 | 5231 | 1569 | 15.38 | 2629 | 0.34 | 4.80 | 159.90 | 13 | 0.39 | 8626.70 | 6611 | 6767 | -75 | lot 0.01 ×1.15 trần 0.2; tầng max(8.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 4; xóa 4/2; SMA100 H1; DCA 60s; lặp có; chờ 60s |
| N033 | ngau_nhien | B | 9616 | 0 | 33.50 | 2.33 | 1280 | 319 | 3.13 | 872 | 1.77 | 23.60 | 684.00 | 11 | 0.19 | 8183.10 | 5218 | 4765 | -61 | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 12; xóa 6/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
| N282 | ngau_nhien | B | 6509 | 0 | 22.30 | 2.32 | 1102 | 453 | 4.44 | 661 | 0.89 | 21.90 | 332.10 | 7 | 0.15 | 9021.20 | 2948 | 3757 | -32 | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| N024 | ngau_nhien | B | 8550 | 0 | 31.10 | 2.30 | 1417 | 938 | 9.20 | 1311 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 8242.80 | 4330 | 4722 | -39 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N208 | ngau_nhien | B | 10093 | 0 | 31.90 | 2.13 | 1676 | 482 | 4.73 | 1091 | 1.36 | 14.10 | 159.30 | 7 | 0.23 | 9549.50 | 6442 | 6537 | -164 | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
| N280 | ngau_nhien | B | 7093 | 0 | 26.90 | 2.03 | 1108 | 362 | 3.55 | 549 | 1.20 | 37.30 | 332.70 | 8 | 0.16 | 8792.60 | 3274 | 4066 | -37 | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N340:tp_atr=2.0 | lang_gieng_ben | B | 5919 | 0 | 27.40 | 1.83 | 1785 | 435 | 4.26 | 728 | 1.22 | 18.90 | 590.80 | 4 | 0.09 | 8588.80 | 3740 | 2603 | -101 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 2.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:tia_tp=1.0 | lang_gieng_ben | B | 5909 | 0 | 28.20 | 1.70 | -93 | 290 | 2.84 | 537 | 2.22 | 49.60 | 336.20 | 4 | 0.09 | 8672.80 | 2774 | 3613 | -35 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 1.0; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:giay_dca=180 | lang_gieng_ben | B | 5232 | 0 | 30.10 | 1.37 | -508 | 298 | 2.92 | 506 | 1.42 | 29.20 | 693.70 | 4 | 0.09 | 8703.70 | 2755 | 2941 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
| N340:buoc_min=8.0 | lang_gieng_ben | B | 4983 | 0 | 30.00 | 1.32 | -702 | 281 | 2.75 | 486 | 1.51 | 29.20 | 990.40 | 4 | 0.09 | 8586.30 | 2679 | 2769 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(8.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340 | ngau_nhien | B | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:lot_max=0.2 | lang_gieng_ben | B | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 | lot 0.01 ×1.3 trần 0.2; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:buoc_min=12.0 | lang_gieng_ben | B | 4968 | 0 | 30.00 | 1.31 | -700 | 275 | 2.70 | 470 | 1.51 | 29.20 | 990.40 | 4 | 0.09 | 8568.70 | 2669 | 2753 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(12.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:xoa=4 | lang_gieng_ben | B | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 4/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:giay_dca=20 | lang_gieng_ben | B | 4944 | 0 | 30.00 | 1.31 | -726 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2664 | 2744 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
| N340:xoa_tu=6 | lang_gieng_ben | B | 4954 | 0 | 30.80 | 1.30 | -535 | 291 | 2.85 | 499 | 1.45 | 29.30 | 693.70 | 4 | 0.09 | 8571.00 | 2665 | 2753 | -31 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/6; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:trail=tat | lang_gieng_ben | B | 4916 | 0 | 30.50 | 1.29 | -663 | 297 | 2.91 | 516 | 1.39 | 29.20 | 693.70 | 4 | 0.09 | 8693.20 | 2651 | 2765 | -34 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail tat; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N299 | ngau_nhien | B | 4122 | 0 | 31.20 | 1.09 | 1428 | 380 | 3.73 | 739 | 0.70 | 8.40 | 576.10 | 19 | 0.17 | 8372.60 | 2992 | 1893 | -128 | lot 0.01 ×1.05 trần 0.1; tầng max(6.0; 2.0×ATR) × 20; TP tỉa 1.0; clear 1.5×ATR trail 80; HV 6; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
| N340:trail=60 | lang_gieng_ben | B | 3839 | 0 | 30.50 | 1.01 | -1707 | 240 | 2.35 | 415 | 1.43 | 35.70 | 693.70 | 4 | 0.09 | 8687.40 | 2838 | 2120 | -77 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 60; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N211 | ngau_nhien | B | 3470 | 0 | 30.90 | 0.97 | 305 | 682 | 6.69 | 788 | 0.11 | 4.90 | 742.80 | 4 | 0.09 | 7971.40 | 1827 | 2018 | -83 | lot 0.01 ×1.3 trần 0.05; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 4; xóa 2/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
| N097 | ngau_nhien | B | 2712 | 0 | 24.40 | 0.96 | 219 | 130 | 1.27 | 202 | 1.07 | 33.10 | 1063.30 | 15 | 0.15 | 8725.70 | 1533 | 1420 | -17 | lot 0.01 bảng Hydra trần 0.05; tầng max(3.0; 4.0×ATR) × 40; TP tỉa 0.5; clear 3.0×ATR trail 40; HV 0; xóa 6/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
| N340:tia_lap_lai=True | lang_gieng_ben | B | 3334 | 0 | 27.50 | 0.95 | -2688 | 204 | 2.00 | 392 | 1.42 | 36.30 | 974.30 | 4 | 0.09 | 8984.80 | 2550 | 2412 | -90 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| N340:loc_xh=False | lang_gieng_ben | B | 3348 | 0 | 29.90 | 0.88 | -2351 | 224 | 2.20 | 382 | 1.44 | 34.70 | 990.40 | 4 | 0.09 | 8599.80 | 2667 | 2137 | -81 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1; DCA 60s; lặp không; chờ 60s |
| N243 | ngau_nhien | B | 3014 | 0 | 32.20 | 0.82 | 7 | 207 | 2.03 | 346 | 0.63 | 25.10 | 614.50 | 14 | 0.22 | 7744.30 | 1541 | 2091 | -14 | lot 0.01 ×1.15 trần 0.1; tầng max(12.0; 3.0×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 8; xóa 0/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
| N340:xoa_tu=3 | lang_gieng_ben | B | 2796 | 0 | 30.10 | 0.73 | -1390 | 146 | 1.43 | 235 | 1.09 | 28.50 | 693.70 | 4 | 0.09 | 8571.00 | 1419 | 2290 | -12 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/3; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| N340:cho_clear=10 | lang_gieng_ben | B | 2753 | 0 | 31.30 | 0.72 | -2816 | 207 | 2.03 | 363 | 1.42 | 44.80 | 990.40 | 4 | 0.09 | 8355.00 | 2571 | 1646 | -94 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
| N082 | ngau_nhien | B | 2134 | 0 | 31.90 | 0.59 | 212 | 155 | 1.52 | 267 | 0.53 | 22.30 | 970.80 | 28 | 0.17 | 7692.10 | 1291 | 1496 | -21 | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
| N141 | ngau_nhien | B | 2281 | 0 | 34.20 | 0.59 | -1 | 145 | 1.42 | 236 | 0.48 | 26.10 | 1083.90 | 15 | 0.22 | 7443.40 | 1427 | 1354 | -12 | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 3.0×ATR) × 16; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 8; xóa 6/3; SMA200 H1; DCA 60s; lặp không; chờ 60s |

## 2b. Độ bền trên 5 đường giá (gốc + 4 thứ tự cực trị ngẫu nhiên)

Mọi cấu hình không cháy và có lãi ở đường giá gốc chạy thêm trên 4 đường giá khác (chỉ đổi thứ tự đỉnh / đáy trong từng nến M1). Bền = không cháy trên cả 5 đường; mức theo DD lớn nhất của 5 đường (A ≤ 20%, B ≤ 35%, C còn lại).

- Cấu hình xét: **97**; bền: **75** (mức A 0, B 1, C 74); cháy trên ít nhất một đường khác: **22**.

### 2b.1 Các cấu hình bền (xếp theo mức rồi trung vị điểm 5 đường)

| ung_vien | ten | muc | dd_max_duong | dd_goc | net_goc | net_tv | diem_tv_duong | trung_vi_diem_lang_gieng | lang_gieng_chay | so_lang_gieng | diem_vung | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U1 | N340 | B | 31.10 | 30.00 | 4942.90 | 3752.60 | 0.97 | 0.99 | 0.00 | 24.00 | 0.97 | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
| U5 | N171 | C | 81.40 | 70.40 | 21354.00 | 26105.70 | 4.71 | 1.28 | 10.00 | 24.00 | 1.29 | lot 0.01 ×1.15 trần 0.1; tầng max(1.5; 0.8×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 2; xóa 2/2; SMA20 H1; DCA 60s; lặp có; chờ 60s |
| U3 | N044 | C | 86.40 | 32.10 | 13030.40 | 13131.20 | 2.53 | 1.45 | 5.00 | 24.00 | 1.97 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| U2 | N029 | C | 72.90 | 54.20 | 21838.30 | 21404.90 | 2.14 | 2.32 | 5.00 | 27.00 | 2.31 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| U4 | N049 | C | 99.30 | 98.00 | 22250.50 | 22250.50 | 1.75 | 1.65 | 6.00 | 25.00 | 1.70 | lot 0.01 ×1.15 trần 0.1; tầng max(15.0; 0.5×ATR) × 30; TP tỉa 2.0; clear 0.5×ATR trail 80; HV 8; xóa 4/4; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N306 | C | 94.40 | 82.20 | 20001.30 | 18941.00 | 1.69 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(10.0; 1.15×ATR) × 16; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 12; xóa 6/3; SMA200 H1; DCA 60s; lặp có; chờ 10s |
|  | N309 | C | 39.10 | 38.50 | 8238.50 | 7784.80 | 1.55 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(10.0; 3.0×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 0; xóa 4/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
|  | N094 | C | 49.50 | 42.80 | 10521.20 | 9361.30 | 1.52 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(12.0; 1.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 0; xóa 0/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N218 | C | 94.60 | 86.20 | 15865.80 | 15865.80 | 1.47 |  |  |  |  | lot 0.01 ×1.3 trần 0.1; tầng max(10.0; 2.0×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail tat; HV 6; xóa 2/3; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N052 | C | 94.20 | 94.20 | 12052.30 | 13408.60 | 1.46 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(15.0; 0.5×ATR) × 20; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 2; xóa tat/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N304 | C | 91.50 | 91.50 | 15773.40 | 15625.20 | 1.46 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(12.0; 1.15×ATR) × 16; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 3; xóa 4/3; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N139 | C | 92.80 | 92.80 | 10134.40 | 10134.40 | 1.44 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(15.0; 2.0×ATR) × 20; TP tỉa 0.75; clear 1.0×ATR trail 40; HV 6; xóa 2/6; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N024 | C | 60.30 | 31.10 | 8550.00 | 8676.70 | 1.31 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N074 | C | 62.20 | 46.00 | 7675.60 | 7637.40 | 1.24 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(1.5; 1.5×ATR) × 40; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 2; xóa 0/3; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N343 | C | 78.50 | 44.80 | 9898.90 | 8033.70 | 1.24 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 6; xóa 4/2; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N079 | C | 90.50 | 81.50 | 9559.30 | 10540.90 | 1.16 |  |  |  |  | lot 0.01 ×1.05 trần 0.02; tầng max(1.5; 0.8×ATR) × 12; TP tỉa 1.5; clear 2.0×ATR trail 40; HV 8; xóa tat/4; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N308 | C | 85.30 | 85.30 | 10650.70 | 7852.50 | 1.12 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(1.5; 1.5×ATR) × 8; TP tỉa 0.5; clear 0.5×ATR trail 80; HV 4; xóa 2/2; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N086 | C | 99.40 | 99.40 | 5184.80 | 7324.30 | 1.05 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(6.0; 1.15×ATR) × 8; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 12; xóa 6/6; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N238 | C | 96.50 | 96.50 | 9348.30 | 11165.30 | 1.05 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(4.5; 0.8×ATR) × 12; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 2; xóa tat/2; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N294 | C | 71.30 | 70.80 | 5758.00 | 6160.50 | 1.01 |  |  |  |  | lot 0.01 ×1.2 trần 0.2; tầng max(15.0; 4.0×ATR) × 12; TP tỉa 1.5; clear 1.0×ATR trail 40; HV 12; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 10s |
|  | N211 | C | 45.30 | 30.90 | 3469.50 | 4241.30 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 4; xóa 2/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N033 | C | 56.90 | 33.50 | 9615.70 | 6378.90 | 0.95 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 12; xóa 6/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N208 | C | 80.20 | 31.90 | 10092.80 | 10051.70 | 0.92 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | N012 | C | 93.80 | 92.50 | 12797.20 | 13138.50 | 0.91 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(10.0; 1.15×ATR) × 30; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 2; xóa 1/6; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N282 | C | 93.00 | 22.30 | 6509.40 | 5527.90 | 0.88 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N046 | C | 80.10 | 70.20 | 7531.20 | 8835.70 | 0.85 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(20.0; 3.0×ATR) × 40; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 0; xóa 1/3; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N303 | C | 79.00 | 65.30 | 2562.10 | 7153.70 | 0.85 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(3.0; 0.8×ATR) × 30; TP tỉa 1.0; clear 2.0×ATR trail 40; HV 3; xóa 2/2; SMA50 H1; DCA 20s; lặp không; chờ 10s |
|  | N141 | C | 42.00 | 34.20 | 2281.10 | 2681.50 | 0.80 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 3.0×ATR) × 16; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 8; xóa 6/3; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N299 | C | 45.30 | 31.20 | 4121.60 | 3981.30 | 0.76 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(6.0; 2.0×ATR) × 20; TP tỉa 1.0; clear 1.5×ATR trail 80; HV 6; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N243 | C | 39.40 | 32.20 | 3013.70 | 3002.20 | 0.74 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(12.0; 3.0×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 8; xóa 0/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N066 | C | 90.80 | 90.80 | 7607.90 | 7607.90 | 0.70 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(3.0; 1.15×ATR) × 8; TP tỉa 2.0; clear 0.5×ATR trail 80; HV 0; xóa 6/6; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N082 | C | 42.30 | 31.90 | 2133.80 | 2134.00 | 0.70 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N143 | C | 77.20 | 68.20 | 5111.30 | 5492.30 | 0.70 |  |  |  |  | lot 0.01 ×1.0 trần 0.03; tầng max(10.0; 3.0×ATR) × 20; TP tỉa 0.5; clear 0.5×ATR trail tat; HV 3; xóa tat/2; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N278 | C | 65.40 | 60.10 | 4549.90 | 4549.90 | 0.65 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(10.0; 4.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 3; xóa 0/3; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N101 | C | 53.90 | 49.50 | 3868.50 | 3868.50 | 0.64 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 0.75; clear 1.5×ATR trail 80; HV 6; xóa 0/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N348 | C | 69.60 | 52.40 | 4285.10 | 3890.30 | 0.63 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(3.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 1.5×ATR trail 60; HV 2; xóa 6/3; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N064 | C | 75.30 | 75.30 | 4459.00 | 4822.20 | 0.56 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(20.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 12; xóa 2/2; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N323 | C | 80.30 | 73.70 | 1140.80 | 4024.30 | 0.56 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 1.15×ATR) × 12; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 12; xóa 2/6; SMA100 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N048 | C | 83.00 | 82.70 | 5267.90 | 5267.90 | 0.54 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(15.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 6; xóa 1/4; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N321 | C | 51.50 | 40.60 | 3185.00 | 2754.10 | 0.50 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(20.0; 4.0×ATR) × 8; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 4; xóa 2/2; SMA200 H1; DCA 20s; lặp không; chờ 60s |
|  | N313 | C | 78.40 | 78.40 | 913.00 | 2837.70 | 0.49 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(3.0; 3.0×ATR) × 5; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 3; xóa tat/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N035 | C | 90.70 | 82.20 | 4612.60 | 4906.90 | 0.48 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 0.75; clear 3.0×ATR trail 80; HV 12; xóa 2/2; SMA200 H1; DCA 60s; lặp có; chờ 60s |
|  | N119 | C | 98.20 | 72.20 | 5010.20 | 3888.90 | 0.47 |  |  |  |  | lot 0.01 ×1.3 trần 0.1; tầng max(15.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 2; xóa 1/6; SMA50 H1; DCA 20s; lặp có; chờ 60s |
|  | N330 | C | 93.40 | 89.90 | 6240.60 | 4363.00 | 0.46 |  |  |  |  | lot 0.01 ×1.1 trần 0.02; tầng max(25.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 3; xóa tat/4; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N326 | C | 99.70 | 99.60 | 2938.20 | 3987.70 | 0.45 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(25.0; 3.0×ATR) × 5; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 2; xóa 4/4; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N092 | C | 78.60 | 78.30 | 3631.80 | 3521.30 | 0.44 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(20.0; 2.0×ATR) × 5; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 2; xóa 1/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N260 | C | 79.30 | 76.40 | 2921.90 | 3119.70 | 0.40 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 3.0×ATR) × 5; TP tỉa 2.0; clear 0.5×ATR trail 60; HV 8; xóa 6/2; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N342 | C | 56.20 | 56.20 | 2264.70 | 2264.70 | 0.40 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 4.0×ATR) × 5; TP tỉa 1.0; clear 0.5×ATR trail 60; HV 0; xóa 6/4; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N244 | C | 97.50 | 88.80 | 4017.50 | 4202.50 | 0.39 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(4.5; 4.0×ATR) × 20; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 0; xóa 6/6; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N020 | C | 86.30 | 86.20 | 2210.40 | 2210.40 | 0.26 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(20.0; 3.0×ATR) × 5; TP tỉa 1.0; clear 1.5×ATR trail 60; HV 6; xóa 6/3; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N316 | C | 97.70 | 97.70 | 529.30 | 2299.90 | 0.24 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(25.0; 1.5×ATR) × 16; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 6; xóa 4/6; SMA20 H1; DCA 60s; lặp không; chờ 60s |
|  | N217 | C | 80.90 | 64.10 | 1.60 | 873.20 | 0.22 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(8.0; 1.15×ATR) × 30; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 12; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N283 | C | 87.00 | 87.00 | 1502.10 | 1957.10 | 0.22 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(20.0; 4.0×ATR) × 8; TP tỉa 1.0; clear 1.0×ATR trail 80; HV 4; xóa 0/3; SMA100 H1; DCA 60s; lặp có; chờ 10s |
|  | N257 | C | 85.50 | 85.50 | 914.20 | 1658.90 | 0.19 |  |  |  |  | lot 0.01 ×1.0 trần 0.5; tầng max(3.0; 1.15×ATR) × 12; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa 1/6; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N103 | C | 56.90 | 56.90 | 1431.90 | 988.70 | 0.18 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(6.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 1.5×ATR trail tat; HV 6; xóa tat/3; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N277 | C | 79.80 | 79.80 | 113.00 | 1287.80 | 0.18 |  |  |  |  | lot 0.01 ×1.1 trần 0.05; tầng max(1.5; 1.15×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail 60; HV 8; xóa tat/4; SMA100 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N153 | C | 91.80 | 55.80 | 2067.00 | 1293.60 | 0.17 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(25.0; 0.8×ATR) × 12; TP tỉa 1.0; clear 1.0×ATR trail 40; HV 2; xóa 6/3; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N159 | C | 57.50 | 57.50 | 933.30 | 933.30 | 0.16 |  |  |  |  | lot 0.01 ×1.0 trần 0.1; tầng max(3.0; 4.0×ATR) × 5; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 6; xóa tat/2; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | N116 | C | 56.10 | 56.00 | 757.90 | 757.90 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(25.0; 4.0×ATR) × 5; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 6; xóa 4/3; SMA100 H1; DCA 180s; lặp không; chờ 10s |
|  | N177 | C | 44.20 | 43.90 | 33.10 | 456.60 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 20; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 12; xóa 1/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | N040 | C | 87.50 | 69.50 | 1345.80 | 1117.20 | 0.12 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(25.0; 4.0×ATR) × 12; TP tỉa 0.75; clear 1.0×ATR trail 40; HV 8; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N209 | C | 78.00 | 78.00 | 776.40 | 929.80 | 0.12 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 3.0×ATR trail 80; HV 8; xóa tat/2; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N099 | C | 90.40 | 85.40 | 956.50 | 956.50 | 0.11 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 8; xóa 4/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N022 | C | 85.60 | 85.60 | 1735.00 | 744.40 | 0.09 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(4.5; 2.0×ATR) × 20; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 3; xóa 1/2; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N213 | C | 52.80 | 32.50 | 318.40 | 318.40 | 0.08 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(1.5; 0.5×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail 40; HV 2; xóa tat/6; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N285 | C | 85.00 | 84.90 | 72.10 | 620.00 | 0.07 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(20.0; 2.0×ATR) × 20; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 2; xóa 0/3; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N312 | C | 94.30 | 83.20 | 579.90 | 579.90 | 0.06 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 0.8×ATR) × 8; TP tỉa 2.0; clear 1.0×ATR trail 80; HV 12; xóa 0/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N070 | C | 56.30 | 37.20 | 105.40 | 139.10 | 0.03 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 8; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 4; xóa 0/2; SMA100 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N124 | C | 71.90 | 55.60 | 164.60 | 164.60 | 0.03 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(6.0; 0.8×ATR) × 8; TP tỉa 0.75; clear 3.0×ATR trail tat; HV 8; xóa 2/2; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N205 | C | 78.50 | 78.50 | 129.30 | 227.20 | 0.03 |  |  |  |  | lot 0.01 ×1.05 trần 0.5; tầng max(8.0; 2.0×ATR) × 8; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 6; xóa 2/6; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N062 | C | 88.50 | 55.80 | 649.60 | 11.80 | 0.00 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(12.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 0; xóa 4/4; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N350 | C | 66.90 | 23.20 | 852.20 | -22.10 | 0.00 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(8.0; 1.15×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa tat/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N296 | C | 99.80 | 99.80 | 1934.90 | -539.70 | -0.05 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 0.8×ATR) × 8; TP tỉa 0.75; clear 0.5×ATR trail 80; HV 3; xóa 0/6; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N136 | C | 48.30 | 33.10 | 80.50 | -199.10 | -0.11 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(1.5; 1.5×ATR) × 5; TP tỉa 0.5; clear 1.5×ATR trail 80; HV 3; xóa 1/2; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N189 | C | 74.90 | 63.00 | 2068.70 | -1868.00 | -0.30 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(1.5; 2.0×ATR) × 5; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 12; xóa 0/4; SMA20 H1 lọc M5; DCA 180s; lặp không; chờ 10s |

### 2b.2 Số cấu hình bền theo từng input (trong các cấu hình đã xét)

- **InpLotCoSo** — 0.01: bền 75/97
- **InpHeSoLot / InpDungBangLot** — 1.0: bền 8/8; 1.05: bền 10/12; 1.1: bền 9/14; 1.15: bền 11/15; bang: bền 15/18; 1.2: bền 10/13; 1.3: bền 12/17
- **InpLotTangToiDa** — 0.02: bền 16/20; 0.03: bền 5/9; 0.05: bền 11/15; 0.1: bền 18/21; 0.2: bền 15/18; 0.5: bền 10/14
- **InpBuocMinUSD** — 1.5: bền 9/12; 3.0: bền 6/9; 4.5: bền 7/10; 6.0: bền 7/7; 8.0: bền 10/13; 10.0: bền 8/15; 12.0: bền 5/5; 15.0: bền 8/10; 20.0: bền 9/10; 25.0: bền 6/6
- **InpBuocATR** — 0.5: bền 4/6; 0.8: bền 8/14; 1.15: bền 13/16; 1.5: bền 6/7; 2.0: bền 16/18; 3.0: bền 15/18; 4.0: bền 13/18
- **InpSoTangToiDa** — 5: bền 18/19; 8: bền 17/20; 12: bền 8/12; 16: bền 4/7; 20: bền 14/15; 30: bền 7/13; 40: bền 7/11
- **InpTiaTPBuoc** — 0.5: bền 18/22; 0.75: bền 18/18; 1.0: bền 9/11; 1.5: bền 11/21; 2.0: bền 19/25
- **InpGioTPATR** — 0.5: bền 19/22; 1.0: bền 9/15; 1.5: bền 18/24; 2.0: bền 15/19; 3.0: bền 14/17
- **InpTrailClear / InpTrailGiuPT** — tat: bền 18/28; 40: bền 18/24; 60: bền 23/26; 80: bền 16/19
- **InpHoaVonTuTang** — 0: bền 10/17; 2: bền 14/16; 3: bền 10/14; 4: bền 8/12; 6: bền 12/13; 8: bền 10/13; 12: bền 11/12
- **InpXoaTangLo / InpXoaGomLai** — tat: bền 14/19; 0: bền 12/12; 1: bền 9/14; 2: bền 14/21; 4: bền 11/13; 6: bền 15/18
- **InpXoaTuSoTang** — 2: bền 21/26; 3: bền 19/25; 4: bền 15/23; 6: bền 20/23
- **InpChanNguocXH** — True: bền 37/45; False: bền 38/52
- **InpPP0MA** — 20: bền 7/8; 50: bền 15/21; 100: bền 18/26; 200: bền 35/42
- **InpGiayGiuaDCA** — 20: bền 20/26; 60: bền 37/46; 180: bền 18/25
- **InpTiaLapLai** — True: bền 30/41; False: bền 45/56
- **InpGiayChoSauClear** — 10: bền 35/46; 60: bền 40/51

### 2b.3 Láng giềng một bước của các ứng viên bền (đường gốc)

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N340:lot0=0.02 | 6378 | 0 | 48.60 | 0.97 | 1410 | 233 | 2.28 | 377 | 1.23 | 21.70 | 594.60 | 4 | 0.18 | 6928.40 | 4518 | 4129 | -151 |
| N340:lot_max=0.2 | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 |
| N340:buoc_min=8.0 | 4983 | 0 | 30.00 | 1.32 | -702 | 281 | 2.75 | 486 | 1.51 | 29.20 | 990.40 | 4 | 0.09 | 8586.30 | 2679 | 2769 | -31 |
| N340:kieu_lot=1.2 | -3975 | 0 | 74.00 | -0.47 | -5678 | 93 | 0.91 | 144 | 1.17 | 11.50 | 54.80 | 3 | 0.05 | 2991.80 | 1486 | 0 | -320 |
| N340:buoc_min=12.0 | 4968 | 0 | 30.00 | 1.31 | -700 | 275 | 2.70 | 470 | 1.51 | 29.20 | 990.40 | 4 | 0.09 | 8568.70 | 2669 | 2753 | -31 |
| N340:buoc_atr=2.0 | 2999 | 0 | 43.00 | 0.58 | 224 | 374 | 3.67 | 667 | 0.66 | 7.60 | 741.40 | 4 | 0.09 | 6862.50 | 2360 | 2773 | -111 |
| N340:so_tang=8 | 5655 | 0 | 40.80 | 1.09 | -1022 | 319 | 3.13 | 555 | 1.43 | 26.20 | 633.30 | 7 | 0.24 | 7348.00 | 2728 | 3334 | -34 |
| N340:buoc_atr=4.0 | 4526 | 0 | 45.70 | 0.87 | -7 | 207 | 2.03 | 346 | 2.95 | 52.60 | 742.80 | 4 | 0.09 | 6176.10 | 2613 | 2177 | -129 |
| N340:tia_tp=0.5 | -2215 | 0 | 49.70 | -0.39 | -3350 | 124 | 1.22 | 182 | 0.82 | 7.60 | 55.00 | 4 | 0.09 | 5762.90 | 1456 | 0 | -222 |
| N340:tp_atr=2.0 | 5919 | 0 | 27.40 | 1.83 | 1785 | 435 | 4.26 | 728 | 1.22 | 18.90 | 590.80 | 4 | 0.09 | 8588.80 | 3740 | 2603 | -101 |
| N340:tia_tp=1.0 | 5909 | 0 | 28.20 | 1.70 | -93 | 290 | 2.84 | 537 | 2.22 | 49.60 | 336.20 | 4 | 0.09 | 8672.80 | 2774 | 3613 | -35 |
| N340:trail=tat | 4916 | 0 | 30.50 | 1.29 | -663 | 297 | 2.91 | 516 | 1.39 | 29.20 | 693.70 | 4 | 0.09 | 8693.20 | 2651 | 2765 | -34 |
| N340:trail=60 | 3839 | 0 | 30.50 | 1.01 | -1707 | 240 | 2.35 | 415 | 1.43 | 35.70 | 693.70 | 4 | 0.09 | 8687.40 | 2838 | 2120 | -77 |
| N340:xoa=4 | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 |
| N340:hoa_von_tang=3 | -4718 | 0 | 84.90 | -0.48 | -6705 | 89 | 0.87 | 139 | 1.42 | 16.60 | 55.20 | 3 | 0.06 | 1743.00 | 1565 | 0 | -368 |
| N340:hoa_von_tang=0 | -4663 | 0 | 84.50 | -0.47 | -6650 | 91 | 0.89 | 145 | 1.42 | 15.20 | 55.10 | 3 | 0.06 | 1797.90 | 1620 | 0 | -373 |
| N340:xoa_tu=3 | 2796 | 0 | 30.10 | 0.73 | -1390 | 146 | 1.43 | 235 | 1.09 | 28.50 | 693.70 | 4 | 0.09 | 8571.00 | 1419 | 2290 | -12 |
| N340:xoa_tu=6 | 4954 | 0 | 30.80 | 1.30 | -535 | 291 | 2.85 | 499 | 1.45 | 29.30 | 693.70 | 4 | 0.09 | 8571.00 | 2665 | 2753 | -31 |
| N340:loc_xh=False | 3348 | 0 | 29.90 | 0.88 | -2351 | 224 | 2.20 | 382 | 1.44 | 34.70 | 990.40 | 4 | 0.09 | 8599.80 | 2667 | 2137 | -81 |
| N340:ma_h1=100 | 3389 | 0 | 64.30 | 0.50 | -1858 | 220 | 2.16 | 394 | 1.62 | 35.70 | 990.40 | 4 | 0.09 | 3729.10 | 1521 | 2332 | -26 |
| N340:giay_dca=20 | 4944 | 0 | 30.00 | 1.31 | -726 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2664 | 2744 | -31 |
| N340:giay_dca=180 | 5232 | 0 | 30.10 | 1.37 | -508 | 298 | 2.92 | 506 | 1.42 | 29.20 | 693.70 | 4 | 0.09 | 8703.70 | 2755 | 2941 | -31 |
| N340:tia_lap_lai=True | 3334 | 0 | 27.50 | 0.95 | -2688 | 204 | 2.00 | 392 | 1.42 | 36.30 | 974.30 | 4 | 0.09 | 8984.80 | 2550 | 2412 | -90 |
| N340:cho_clear=10 | 2753 | 0 | 31.30 | 0.72 | -2816 | 207 | 2.03 | 363 | 1.42 | 44.80 | 990.40 | 4 | 0.09 | 8355.00 | 2571 | 1646 | -94 |
| N171:lot0=0.02 | 353 | 3 | 100.80 | 0.02 | -23993 | 6010 | 58.92 | 16306 | 0.08 | 1.00 | 112.90 | 39 | 2.23 | -21371.70 | 3153 | -572 | -166 |
| N171:kieu_lot=bang | 20634 | 0 | 67.70 | 1.47 | 8226 | 6355 | 62.30 | 16514 | 0.08 | 1.00 | 155.40 | 39 | 1.86 | 4525.90 | 9312 | 11337 | -76 |
| N171:kieu_lot=1.1 | 18068 | 0 | 97.00 | 1.41 | 6762 | 5509 | 54.01 | 15720 | 0.08 | 1.10 | 133.90 | 39 | 1.74 | 390.60 | 8025 | 10057 | -57 |
| N171:lot_max=0.05 | 10352 | 1 | 100.20 | 0.86 | -2068 | 6242 | 61.20 | 16678 | 0.08 | 1.00 | 132.10 | 39 | 1.31 | -4560.20 | 9086 | 1282 | -100 |
| N171:lot_max=0.2 | 21431 | 0 | 77.30 | 1.98 | 8381 | 6655 | 65.25 | 17058 | 0.08 | 1.00 | 110.20 | 39 | 2.70 | 3164.80 | 9852 | 11594 | -100 |
| N171:buoc_min=3.0 | 21223 | 0 | 70.90 | 1.28 | 8149 | 6376 | 62.51 | 16540 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4048.50 | 9755 | 11479 | -94 |
| N171:buoc_atr=0.5 | -9899 | 3 | 106.10 | -0.47 | -26365 | 12051 | 118.15 | 31516 | 0.04 | 0.40 | 217.80 | 39 | 1.79 | -23571.30 | 481 | -9152 | -74 |
| N171:buoc_atr=1.15 | -277 | 1 | 131.80 | -0.02 | -9554 | 3354 | 32.88 | 8927 | 0.14 | 1.90 | 151.20 | 34 | 1.52 | -11365.30 | 6385 | -6651 | -49 |
| N171:so_tang=30 | 21374 | 0 | 70.40 | 1.65 | 8327 | 6606 | 64.76 | 16927 | 0.08 | 1.00 | 110.20 | 29 | 1.41 | 4135.10 | 9822 | 11568 | -88 |
| N171:tia_tp=0.75 | 23890 | 0 | 87.30 | 1.92 | 9734 | 5343 | 52.38 | 13430 | 0.14 | 1.20 | 81.10 | 37 | 1.72 | 1808.30 | 10930 | 12970 | -72 |
| N171:tp_atr=1.5 | 21354 | 0 | 70.40 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4135.10 | 9822 | 11547 | -88 |
| N171:tp_atr=3.0 | 21354 | 0 | 70.40 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4135.10 | 9822 | 11547 | -88 |
| N171:trail=40 | 21354 | 0 | 70.40 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4135.10 | 9822 | 11547 | -88 |
| N171:hoa_von_tang=0 | 10092 | 1 | 100.10 | 0.69 | -4723 | 5434 | 53.27 | 15990 | 0.08 | 1.40 | 95.70 | 34 | 1.90 | -580.30 | -3478 | 13585 | -88 |
| N171:hoa_von_tang=3 | 7628 | 1 | 100.20 | 0.54 | -5110 | 6077 | 59.58 | 16313 | 0.08 | 1.10 | 110.20 | 35 | 1.77 | -599.30 | -4288 | 11930 | -62 |
| N171:xoa=1 | 21354 | 0 | 70.40 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4135.10 | 9822 | 11547 | -88 |
| N171:xoa=4 | 21354 | 0 | 70.40 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4135.10 | 9822 | 11547 | -88 |
| N171:xoa_tu=3 | 22058 | 0 | 70.10 | 1.33 | 9102 | 6346 | 62.22 | 16944 | 0.08 | 1.10 | 110.10 | 39 | 2.04 | 4204.10 | 10238 | 11837 | -81 |
| N171:loc_xh=True | 21283 | 0 | 70.10 | 1.28 | 8329 | 6577 | 64.48 | 16959 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4192.00 | 9850 | 11448 | -88 |
| N171:ma_h1=50 | 20683 | 0 | 70.70 | 1.25 | 7904 | 6397 | 62.72 | 16719 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 4079.40 | 9448 | 11250 | -91 |
| N171:giay_dca=20 | -2296 | 2 | 100.60 | -0.12 | -15610 | 6730 | 65.98 | 17739 | 0.08 | 1.00 | 110.10 | 39 | 2.31 | -15081.50 | -3968 | 1685 | -72 |
| N171:giay_dca=180 | 10223 | 1 | 100.20 | 0.83 | -2366 | 6193 | 60.72 | 14877 | 0.08 | 1.00 | 110.10 | 39 | 2.18 | -4724.10 | 9089 | 1146 | -71 |
| N171:tia_lap_lai=False | -33762 | 4 | 100.20 | -3.26 | -38623 | 2170 | 21.27 | 4643 | 0.08 | 1.60 | 522.60 | 39 | 0.93 | -33659.00 | -7997 | -25361 | -58 |
| N044:lot0=0.02 | -15564 | 2 | 102.60 | -1.08 | -19643 | 565 | 5.54 | 979 | 0.38 | 5.90 | 287.30 | 24 | 0.48 | -16081.70 | -9433 | -4545 | -66 |
| N171:cho_clear=10 | 11291 | 1 | 100.10 | 0.88 | -949 | 6594 | 64.65 | 18032 | 0.09 | 1.00 | 134.00 | 39 | 2.17 | -9145.40 | 9512 | 1789 | -73 |
| N044:kieu_lot=1.15 | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 |
| N044:kieu_lot=1.2 | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 |
| N044:lot_max=0.03 | 12609 | 0 | 36.10 | 2.87 | 4673 | 1322 | 12.96 | 2041 | 0.39 | 5.80 | 158.90 | 16 | 0.42 | 7761.40 | 5931 | 6882 | -66 |
| N044:buoc_min=12.0 | 11837 | 0 | 87.90 | 0.88 | -2382 | 1185 | 11.62 | 1935 | 0.39 | 5.70 | 323.60 | 29 | 0.55 | 1856.70 | 5137 | 7089 | -57 |
| N044:buoc_min=20.0 | 10924 | 0 | 86.00 | 0.85 | -2302 | 1022 | 10.02 | 1568 | 0.39 | 6.90 | 323.60 | 28 | 0.53 | 2082.50 | 4451 | 6800 | -48 |
| N044:buoc_atr=1.5 | -12013 | 2 | 100.20 | -0.92 | -15990 | 1279 | 12.54 | 2226 | 0.40 | 5.50 | 287.20 | 31 | 0.59 | -10936.20 | -7082 | -4677 | -53 |
| N044:buoc_atr=3.0 | -4549 | 1 | 100.10 | -0.38 | -11494 | 819 | 8.03 | 1165 | 0.38 | 8.20 | 332.70 | 16 | 0.31 | -3549.00 | -8442 | 4147 | -58 |
| N044:so_tang=30 | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 |
| N044:tia_tp=1.0 | 11763 | 0 | 84.10 | 0.93 | -1887 | 1125 | 11.03 | 1912 | 0.38 | 6.40 | 323.60 | 28 | 0.53 | 2395.20 | 4761 | 7285 | -53 |
| N044:tia_tp=2.0 | 13086 | 0 | 33.70 | 3.16 | 5086 | 1300 | 12.75 | 1996 | 0.42 | 5.90 | 159.00 | 11 | 0.19 | 8141.70 | 6445 | 6926 | -69 |
| N044:tp_atr=0.5 | 11907 | 0 | 92.00 | 0.88 | -2883 | 2097 | 20.56 | 2804 | 0.11 | 2.80 | 323.60 | 29 | 0.55 | 1174.50 | 5264 | 6897 | -59 |
| N044:tp_atr=1.5 | 11892 | 0 | 87.20 | 0.91 | -2235 | 759 | 7.44 | 1408 | 0.74 | 9.50 | 323.60 | 28 | 0.53 | 1910.90 | 4796 | 7374 | -47 |
| N044:trail=40 | 10398 | 0 | 80.30 | 0.89 | -2009 | 1102 | 10.80 | 1748 | 0.48 | 5.50 | 323.50 | 26 | 0.49 | 2848.40 | 4545 | 6116 | -49 |
| N044:trail=80 | 15116 | 0 | 34.50 | 3.24 | 5588 | 1380 | 13.53 | 2161 | 0.32 | 5.60 | 160.10 | 13 | 0.25 | 8089.90 | 6888 | 8521 | -67 |
| N044:hoa_von_tang=2 | 12034 | 0 | 32.60 | 3.08 | 4452 | 1474 | 14.45 | 2282 | 0.41 | 5.40 | 75.50 | 12 | 0.19 | 8087.20 | 6201 | 6121 | -74 |
| N044:xoa_tu=3 | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 |
| N044:xoa=0 | -570 | 1 | 100.10 | -0.05 | -7313 | 1286 | 12.61 | 2027 | 0.40 | 5.80 | 159.00 | 23 | 0.36 | -1007.50 | -6657 | 6323 | -80 |
| N044:xoa_tu=6 | 13030 | 0 | 32.10 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6287 | 6997 | -65 |
| N044:loc_xh=True | 12984 | 0 | 32.10 | 3.33 | 4889 | 1345 | 13.19 | 2087 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 8248.60 | 6278 | 6960 | -65 |
| N044:ma_h1=100 | 2222 | 1 | 100.00 | 0.22 | -5360 | 1194 | 11.71 | 1926 | 0.37 | 6.90 | 304.30 | 28 | 0.49 | -2211.60 | 5294 | -2819 | -55 |
| N044:giay_dca=60 | 12853 | 0 | 34.00 | 3.11 | 4844 | 1341 | 13.15 | 2066 | 0.39 | 5.60 | 159.00 | 12 | 0.23 | 8026.00 | 6115 | 6992 | -65 |
| N044:tia_lap_lai=False | 11533 | 0 | 38.50 | 1.97 | 1150 | 1137 | 11.15 | 1768 | 0.41 | 5.80 | 311.70 | 34 | 0.29 | 8283.70 | 4916 | 6882 | -58 |
| N044:cho_clear=60 | 10912 | 0 | 89.80 | 0.82 | -2584 | 1055 | 10.34 | 1698 | 0.42 | 6.20 | 323.60 | 29 | 0.55 | 1506.90 | 4516 | 6662 | -58 |
| N029:lot0=0.02 | 11369 | 1 | 100.00 | 0.43 | -3635 | 2138 | 20.96 | 5164 | 0.33 | 2.40 | 295.40 | 19 | 0.82 | -2799.80 | 14412 | -2135 | -130 |
| N029:kieu_lot=1.1 | 19307 | 0 | 44.40 | 2.52 | 6718 | 2202 | 21.59 | 5347 | 0.36 | 2.60 | 159.10 | 19 | 0.53 | 9260.20 | 8137 | 11450 | -66 |
| N029:kieu_lot=bang | 21085 | 0 | 53.00 | 2.32 | 7234 | 2387 | 23.40 | 5563 | 0.34 | 2.40 | 159.00 | 19 | 0.54 | 7100.60 | 8538 | 12901 | -68 |
| N029:lot_max=0.03 | 6786 | 1 | 100.00 | 0.52 | -6855 | 2291 | 22.46 | 5396 | 0.36 | 2.50 | 159.10 | 19 | 0.42 | -5776.40 | -5044 | 12242 | -69 |
| N029:lot_max=0.1 | 22097 | 0 | 57.80 | 2.58 | 7138 | 2524 | 24.75 | 5934 | 0.36 | 2.40 | 74.80 | 19 | 0.71 | 6258.60 | 9409 | 12986 | -81 |
| N029:buoc_min=6.0 | 2441 | 1 | 100.00 | 0.12 | -10817 | 2942 | 28.84 | 7244 | 0.29 | 1.70 | 237.80 | 19 | 0.65 | -1048.40 | 9302 | -6372 | -100 |
| N029:buoc_min=10.0 | 19120 | 0 | 55.00 | 2.39 | 6144 | 1986 | 19.47 | 4532 | 0.41 | 3.10 | 74.40 | 19 | 0.65 | 6559.20 | 8063 | 11416 | -71 |
| N029:buoc_atr=0.8 | 5071 | 1 | 100.10 | 0.38 | -6727 | 1963 | 19.25 | 4447 | 0.45 | 2.80 | 158.90 | 19 | 0.48 | -2903.30 | -5175 | 10543 | -68 |
| N029:so_tang=16 | 21526 | 0 | 52.90 | 2.78 | 6775 | 2476 | 24.27 | 5809 | 0.36 | 2.40 | 74.80 | 15 | 0.46 | 6119.90 | 9079 | 12744 | -81 |
| N029:so_tang=30 | 21801 | 0 | 59.10 | 2.72 | 6954 | 2494 | 24.45 | 5917 | 0.36 | 2.40 | 74.10 | 29 | 0.88 | 5318.00 | 9264 | 12834 | -82 |
| N029:tia_tp=1.0 | 3670 | 1 | 100.00 | 0.28 | -11068 | 2351 | 23.05 | 5437 | 0.24 | 2.10 | 623.50 | 19 | 0.62 | -5850.70 | -5662 | 9657 | -74 |
| N029:tia_tp=2.0 | 17671 | 0 | 80.80 | 1.14 | -1802 | 1838 | 18.02 | 4391 | 0.38 | 2.40 | 623.50 | 19 | 0.61 | 3678.30 | 7612 | 10405 | -70 |
| N029:tp_atr=1.0 | 22094 | 0 | 51.40 | 2.34 | 7595 | 3004 | 29.45 | 6304 | 0.26 | 1.90 | 159.00 | 19 | 0.57 | 8908.40 | 9309 | 13146 | -73 |
| N029:tp_atr=2.0 | 21919 | 0 | 54.00 | 2.73 | 7017 | 2257 | 22.13 | 5571 | 0.38 | 2.80 | 74.80 | 19 | 0.56 | 6823.30 | 9171 | 13094 | -89 |
| N029:trail=40 | 16304 | 0 | 73.80 | 1.23 | -1774 | 1790 | 17.55 | 4238 | 0.35 | 2.40 | 623.50 | 19 | 0.62 | 4726.40 | 6192 | 10411 | -58 |
| N029:trail=80 | 18510 | 0 | 66.80 | 1.39 | 291 | 2011 | 19.72 | 4751 | 0.33 | 2.50 | 623.50 | 19 | 0.62 | 6605.90 | 7729 | 11143 | -77 |
| N029:hoa_von_tang=3 | 23820 | 0 | 63.80 | 2.84 | 7853 | 2229 | 21.85 | 5553 | 0.40 | 2.80 | 74.10 | 19 | 0.56 | 4768.50 | 10159 | 13958 | -90 |
| N029:hoa_von_tang=0 | 23481 | 0 | 69.50 | 1.45 | 514 | 1553 | 15.23 | 4124 | 0.41 | 3.10 | 623.50 | 19 | 0.67 | 7099.90 | 10052 | 13789 | -74 |
| N029:xoa=tat | 22329 | 0 | 58.80 | 2.55 | 7370 | 2527 | 24.77 | 5896 | 0.36 | 2.40 | 74.10 | 19 | 0.62 | 6133.80 | 9134 | 13199 | -84 |
| N029:xoa=1 | 17946 | 0 | 57.00 | 1.61 | 1080 | 1970 | 19.31 | 4764 | 0.34 | 2.30 | 623.50 | 19 | 0.62 | 6946.30 | 7561 | 10642 | -74 |
| N029:xoa_tu=6 | 21819 | 0 | 53.80 | 2.73 | 6964 | 2485 | 24.36 | 5849 | 0.36 | 2.40 | 74.10 | 19 | 0.56 | 6885.80 | 9178 | 12938 | -83 |
| N029:xoa_tu=3 | 21878 | 0 | 53.80 | 2.73 | 7001 | 2492 | 24.43 | 5870 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 6861.30 | 9348 | 12827 | -81 |
| N029:loc_xh=True | 21672 | 0 | 54.10 | 2.71 | 6914 | 2480 | 24.31 | 5829 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 6795.60 | 9298 | 12671 | -81 |
| N029:ma_h1=100 | 22707 | 0 | 51.00 | 2.84 | 7634 | 2604 | 25.53 | 6066 | 0.36 | 2.50 | 74.80 | 19 | 0.56 | 7676.80 | 10586 | 12418 | -124 |
| N029:giay_dca=60 | 18659 | 0 | 65.40 | 1.41 | 116 | 2097 | 20.56 | 5181 | 0.32 | 2.20 | 623.50 | 19 | 0.62 | 7002.30 | 8422 | 10505 | -85 |
| N029:tia_lap_lai=False | 15524 | 0 | 52.00 | 2.29 | 5554 | 1734 | 17.00 | 3937 | 0.33 | 2.30 | 611.60 | 19 | 0.51 | 6272.90 | 6202 | 9883 | -80 |
| N029:cho_clear=10 | 17927 | 0 | 71.60 | 1.29 | -1113 | 2013 | 19.74 | 4925 | 0.35 | 2.30 | 623.50 | 19 | 0.62 | 5487.20 | 8144 | 10142 | -81 |
| N049:lot0=0.02 | 9739 | 2 | 100.30 | 0.58 | -16075 | 2436 | 23.88 | 3727 | 0.12 | 2.10 | 326.90 | 29 | 1.22 | -15056.10 | -13841 | 24099 | -91 |
| N049:kieu_lot=1.1 | 17684 | 0 | 57.30 | 2.41 | 4746 | 2303 | 22.58 | 3629 | 0.12 | 2.50 | 323.70 | 29 | 0.76 | 5469.50 | 5564 | 12300 | -50 |
| N049:kieu_lot=bang | 13930 | 0 | 80.30 | 1.32 | 2408 | 2277 | 22.32 | 3311 | 0.12 | 2.30 | 693.60 | 29 | 0.99 | 2578.40 | 6793 | 7384 | -227 |
| N049:lot_max=0.05 | 15056 | 0 | 74.10 | 1.55 | 3948 | 2529 | 24.79 | 3665 | 0.12 | 2.30 | 589.60 | 29 | 0.61 | 3395.20 | 7542 | 7764 | -112 |
| N049:lot_max=0.2 | 23137 | 0 | 96.90 | 1.82 | 7726 | 3087 | 30.26 | 4726 | 0.12 | 2.20 | 158.10 | 27 | 1.57 | 403.40 | 8972 | 14416 | -57 |
| N049:buoc_min=12.0 | 27864 | 0 | 32.40 | 5.33 | 9505 | 3726 | 36.53 | 5996 | 0.11 | 1.80 | 158.70 | 26 | 0.71 | 9723.40 | 11029 | 17209 | -69 |
| N049:buoc_min=20.0 | 17951 | 0 | 77.50 | 1.82 | 3768 | 2294 | 22.49 | 3297 | 0.11 | 2.70 | 321.50 | 28 | 0.80 | 2836.70 | 6335 | 11844 | -50 |
| N049:buoc_atr=0.8 | 14571 | 0 | 99.20 | 1.09 | 2038 | 2353 | 23.07 | 3384 | 0.12 | 2.20 | 693.50 | 29 | 0.90 | 113.90 | 7128 | 7694 | -263 |
| N049:so_tang=20 | 15457 | 0 | 91.20 | 1.30 | 3552 | 2411 | 23.64 | 3522 | 0.12 | 2.20 | 690.60 | 19 | 0.61 | 1154.60 | 7146 | 8562 | -153 |
| N049:so_tang=40 | 22250 | 0 | 98.00 | 1.73 | 7836 | 2957 | 28.99 | 4536 | 0.12 | 2.20 | 158.90 | 27 | 1.07 | 258.30 | 8521 | 13981 | -51 |
| N049:tia_tp=1.5 | 14743 | 0 | 77.70 | 1.41 | 1853 | 2341 | 22.95 | 3440 | 0.11 | 2.20 | 743.00 | 29 | 0.99 | 3000.00 | 6828 | 8124 | -228 |
| N049:tp_atr=1.0 | 21122 | 0 | 98.90 | 1.65 | 7660 | 1642 | 16.10 | 3077 | 0.33 | 4.10 | 158.90 | 26 | 1.07 | 142.30 | 8344 | 13094 | -54 |
| N049:trail=60 | 7176 | 1 | 100.10 | 0.57 | -5652 | 2984 | 29.25 | 4543 | 0.14 | 2.30 | 158.30 | 26 | 1.07 | -4298.90 | -4854 | 12369 | -52 |
| N049:hoa_von_tang=12 | 16124 | 0 | 98.00 | 1.26 | 3126 | 2566 | 25.16 | 3744 | 0.12 | 2.30 | 598.90 | 29 | 1.04 | 258.30 | 7786 | 8589 | -175 |
| N049:hoa_von_tang=6 | 21726 | 0 | 98.20 | 1.69 | 7712 | 2964 | 29.06 | 4543 | 0.12 | 2.20 | 158.70 | 27 | 1.07 | 231.10 | 8341 | 13636 | -51 |
| N049:xoa=2 | 22250 | 0 | 98.00 | 1.73 | 7836 | 2957 | 28.99 | 4536 | 0.12 | 2.20 | 158.90 | 27 | 1.07 | 258.30 | 8521 | 13981 | -51 |
| N049:xoa=6 | 22250 | 0 | 98.00 | 1.73 | 7836 | 2957 | 28.99 | 4536 | 0.12 | 2.20 | 158.90 | 27 | 1.07 | 258.30 | 8521 | 13981 | -51 |
| N049:xoa_tu=6 | 21497 | 0 | 98.00 | 1.68 | 3626 | 2716 | 26.63 | 4197 | 0.12 | 2.20 | 323.60 | 29 | 0.98 | 267.20 | 7295 | 14453 | -46 |
| N049:xoa_tu=3 | 21987 | 0 | 98.10 | 1.71 | 7769 | 2959 | 29.01 | 4543 | 0.12 | 2.20 | 158.90 | 27 | 1.07 | 248.30 | 8515 | 13723 | -49 |
| N049:loc_xh=True | 22084 | 0 | 98.00 | 1.72 | 7796 | 2940 | 28.82 | 4507 | 0.12 | 2.20 | 158.90 | 27 | 1.07 | 258.30 | 8496 | 13839 | -51 |
| N049:ma_h1=100 | -1493 | 2 | 100.30 | -0.12 | -15605 | 2675 | 26.23 | 4232 | 0.12 | 2.30 | 193.20 | 26 | 1.07 | -13218.20 | -5976 | 4735 | -60 |
| N049:giay_dca=20 | 10020 | 1 | 100.30 | 0.76 | -4446 | 2998 | 29.39 | 4617 | 0.11 | 2.20 | 158.90 | 26 | 1.07 | -4352.30 | -3758 | 14030 | -49 |
| N049:giay_dca=180 | 21477 | 0 | 51.40 | 2.16 | 7560 | 2902 | 28.45 | 4333 | 0.12 | 2.20 | 159.00 | 27 | 1.07 | 9401.60 | 8805 | 12923 | -49 |
| N049:tia_lap_lai=True | 12107 | 1 | 100.20 | 0.92 | -4630 | 3272 | 32.08 | 5068 | 0.12 | 2.20 | 110.30 | 26 | 1.07 | -3891.30 | -3046 | 15404 | -59 |
| N049:cho_clear=10 | 11619 | 1 | 100.20 | 0.88 | -3432 | 3145 | 30.83 | 4799 | 0.10 | 2.20 | 159.10 | 29 | 1.07 | -3998.20 | -3269 | 15226 | -45 |

### 2b.4 Thông tin: ứng viên trên 16 đường giá DEV nữa (không dùng để chọn)

| ten | so_duong | so_duong_chay | dd_trung_vi | dd_lon_nhat | lai_trung_vi | lai_thap_nhat | lai_ngay_tv | lot_ngay_tv |
|---|---|---|---|---|---|---|---|---|
| U1 | 16 | 0 | 28.65 | 72.40 | 4058.00 | -3786.10 | 39.78 | 0.05 |
| U2 | 16 | 0 | 65.30 | 77.00 | 18668.05 | 17242.20 | 183.02 | 0.66 |
| U3 | 16 | 3 | 82.15 | 100.10 | 13298.90 | -12461.70 | 130.38 | 0.24 |
| U4 | 16 | 3 | 83.30 | 100.20 | 22243.55 | 8102.70 | 218.07 | 0.55 |
| U5 | 16 | 2 | 25.15 | 100.10 | 26192.05 | -950.80 | 256.78 | 2.96 |

## 3. Tham khảo: hedge V0.22 (không phát hành) trên các ứng viên đầu

`v022` = hedge như V0.22 đã dựng; `sau15_khoa` = hedge từ 15 khoảng tầng, không giảm cấp, khóa DCA sau khi đã hedge.

| ten | hedge | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap | co_hd | gio_khoa |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U1 | v022 | -344 | 0 | 22.90 | -0.13 | -1094 | 89 | 0.87 | 165 | 1.32 | 19.20 | 55.20 | 3 | 0.06 | 8813.90 | 1416 | 0 | -113 | 0 | 0.00 |
| U2 | sau15_khoa | 4980 | 0 | 29.30 | 1.31 | -88 | 985 | 9.66 | 2222 | 0.35 | 2.30 | 741.20 | 14 | 0.27 | 9195.10 | 602 | 4865 | -140 | 2 | 1951.20 |
| U2 | v022 | 8901 | 0 | 34.80 | 1.65 | 485 | 1178 | 11.55 | 3308 | 0.36 | 2.80 | 972.50 | 19 | 0.40 | 9871.10 | 4859 | 4478 | -132 | 38 | 633.80 |
| U1 | sau15_khoa | 4943 | 0 | 30.00 | 1.31 | -727 | 284 | 2.78 | 483 | 1.48 | 29.10 | 990.40 | 4 | 0.09 | 8571.00 | 2663 | 2744 | -31 | 0 | 0.00 |
| U3 | v022 | 7045 | 0 | 54.20 | 1.07 | -1732 | 946 | 9.27 | 1826 | 0.41 | 5.80 | 311.30 | 33 | 0.38 | 5561.00 | 4372 | 4484 | -211 | 7 | 119.50 |
| U3 | sau15_khoa | 11220 | 0 | 32.10 | 2.88 | 3078 | 1299 | 12.74 | 2008 | 0.40 | 5.60 | 159.00 | 14 | 0.27 | 8248.60 | 4476 | 6997 | -85 | 1 | 0.00 |

