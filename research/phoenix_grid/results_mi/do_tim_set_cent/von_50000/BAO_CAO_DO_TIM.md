# Dò set Phoenix Grid cho tài khoản cent 50.000 USC — kết quả mô phỏng

> Mô phỏng Python `mo_phong_phoenix.py` (đường giá nội suy ≤ 0,5 USD trong nến M1, spread 0,26, swap, margin
> level 500%), KHÔNG phải backtest MT5. Chỉ dùng để so sánh cấu hình với nhau. Luật chọn ghi trong
> `do_tim_set_cent.py` trước khi chạy.

## 1. DEV 01/01–30/04/2026: mọi biến thể

- Biến thể (cấu hình khác nhau, đường giá gốc): **612** (ngẫu nhiên + tham chiếu: 363; láng giềng: 249).
- Cháy tài khoản ít nhất một lần: **30** (5%).
- Ở đường giá gốc: không cháy, DD ≤ 35%, lãi > 0, bỏ 2 tháng tốt nhất ≥ 0: **187**; không cháy, DD ≤ 50%, lãi > 0: **230**; không cháy, lãi > 0, DD lớn hơn: **62**.

### 1.1 Tham chiếu

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| V0.21 set hệ số 1,2 đã gửi | 19885 | 0 | 47.10 | 0.82 | 7966 | 2274 | 22.29 | 5120 | 0.31 | 2.80 | 158.90 | 23 | 3.59 | 27130.40 | 8387 | 11502 | -49 |
| Gần Hydra: bảng lot, bước nhỏ | -79762 | 2 | 100.30 | -1.52 | -103514 | 6656 | 65.25 | 22306 | 0.11 | 0.80 | 290.30 | 29 | 3.62 | -53940.80 | -35545 | -31884 | -138 |
| V0.21 mặc định (lot đều) | 4197 | 0 | 50.00 | 0.17 | -3910 | 492 | 4.82 | 1919 | 0.23 | 7.60 | 868.30 | 39 | 0.35 | 25122.40 | 192 | 4487 | -1 |

### 1.2 Tỷ lệ cháy theo từng input (bước 1, mẫu ngẫu nhiên)

Mỗi dòng: một giá trị của input; số cấu hình có giá trị đó, % cháy ít nhất một lần, trung vị DD, số cấu hình không cháy.

- **InpHeSoLot / InpDungBangLot** — 1.0: 55 cấu hình, cháy 0%, DD trung vị 18%, không cháy 55; 1.05: 57 cấu hình, cháy 7%, DD trung vị 18%, không cháy 53; 1.1: 47 cấu hình, cháy 4%, DD trung vị 21%, không cháy 45; 1.15: 50 cấu hình, cháy 6%, DD trung vị 25%, không cháy 47; bang: 58 cấu hình, cháy 3%, DD trung vị 29%, không cháy 56; 1.2: 42 cấu hình, cháy 10%, DD trung vị 30%, không cháy 38; 1.3: 51 cấu hình, cháy 10%, DD trung vị 25%, không cháy 46
- **InpLotTangToiDa** — 0.02: 61 cấu hình, cháy 0%, DD trung vị 20%, không cháy 61; 0.03: 49 cấu hình, cháy 0%, DD trung vị 28%, không cháy 49; 0.05: 62 cấu hình, cháy 8%, DD trung vị 26%, không cháy 57; 0.1: 72 cấu hình, cháy 11%, DD trung vị 19%, không cháy 64; 0.2: 60 cấu hình, cháy 5%, DD trung vị 24%, không cháy 57; 0.5: 56 cấu hình, cháy 7%, DD trung vị 25%, không cháy 52
- **InpBuocMinUSD** — 1.5: 36 cấu hình, cháy 3%, DD trung vị 20%, không cháy 35; 3.0: 36 cấu hình, cháy 11%, DD trung vị 27%, không cháy 32; 4.5: 31 cấu hình, cháy 0%, DD trung vị 21%, không cháy 31; 6.0: 38 cấu hình, cháy 3%, DD trung vị 29%, không cháy 37; 8.0: 39 cấu hình, cháy 5%, DD trung vị 24%, không cháy 37; 10.0: 44 cấu hình, cháy 5%, DD trung vị 20%, không cháy 42; 12.0: 26 cấu hình, cháy 12%, DD trung vị 27%, không cháy 23; 15.0: 40 cấu hình, cháy 8%, DD trung vị 20%, không cháy 37; 20.0: 39 cấu hình, cháy 5%, DD trung vị 21%, không cháy 37; 25.0: 31 cấu hình, cháy 6%, DD trung vị 30%, không cháy 29
- **InpBuocATR** — 0.5: 50 cấu hình, cháy 8%, DD trung vị 23%, không cháy 46; 0.8: 47 cấu hình, cháy 4%, DD trung vị 20%, không cháy 45; 1.15: 63 cấu hình, cháy 5%, DD trung vị 22%, không cháy 60; 1.5: 36 cấu hình, cháy 14%, DD trung vị 32%, không cháy 31; 2.0: 59 cấu hình, cháy 3%, DD trung vị 26%, không cháy 57; 3.0: 50 cấu hình, cháy 2%, DD trung vị 20%, không cháy 49; 4.0: 55 cấu hình, cháy 5%, DD trung vị 24%, không cháy 52
- **InpSoTangToiDa** — 5: 52 cấu hình, cháy 0%, DD trung vị 11%, không cháy 52; 8: 59 cấu hình, cháy 0%, DD trung vị 19%, không cháy 59; 12: 48 cấu hình, cháy 0%, DD trung vị 21%, không cháy 48; 16: 45 cấu hình, cháy 0%, DD trung vị 30%, không cháy 45; 20: 48 cấu hình, cháy 4%, DD trung vị 32%, không cháy 46; 30: 54 cấu hình, cháy 7%, DD trung vị 33%, không cháy 50; 40: 54 cấu hình, cháy 26%, DD trung vị 48%, không cháy 40
- **InpTiaTPBuoc** — 0.5: 79 cấu hình, cháy 6%, DD trung vị 19%, không cháy 74; 0.75: 58 cấu hình, cháy 2%, DD trung vị 18%, không cháy 57; 1.0: 61 cấu hình, cháy 7%, DD trung vị 26%, không cháy 57; 1.5: 83 cấu hình, cháy 4%, DD trung vị 30%, không cháy 80; 2.0: 79 cấu hình, cháy 9%, DD trung vị 25%, không cháy 72
- **InpGioTPATR** — 0.5: 67 cấu hình, cháy 3%, DD trung vị 20%, không cháy 65; 1.0: 78 cấu hình, cháy 6%, DD trung vị 27%, không cháy 73; 1.5: 77 cấu hình, cháy 9%, DD trung vị 21%, không cháy 70; 2.0: 69 cấu hình, cháy 3%, DD trung vị 24%, không cháy 67; 3.0: 69 cấu hình, cháy 6%, DD trung vị 26%, không cháy 65
- **InpTrailClear / InpTrailGiuPT** — tat: 103 cấu hình, cháy 3%, DD trung vị 23%, không cháy 100; 40: 85 cấu hình, cháy 6%, DD trung vị 26%, không cháy 80; 60: 88 cấu hình, cháy 3%, DD trung vị 21%, không cháy 85; 80: 84 cấu hình, cháy 11%, DD trung vị 26%, không cháy 75
- **InpHoaVonTuTang** — 0: 48 cấu hình, cháy 4%, DD trung vị 20%, không cháy 46; 2: 49 cấu hình, cháy 6%, DD trung vị 24%, không cháy 46; 3: 51 cấu hình, cháy 6%, DD trung vị 22%, không cháy 48; 4: 47 cấu hình, cháy 4%, DD trung vị 19%, không cháy 45; 6: 60 cấu hình, cháy 7%, DD trung vị 28%, không cháy 56; 8: 57 cấu hình, cháy 5%, DD trung vị 22%, không cháy 54; 12: 48 cấu hình, cháy 6%, DD trung vị 23%, không cháy 45
- **InpXoaTangLo / InpXoaGomLai** — tat: 55 cấu hình, cháy 5%, DD trung vị 22%, không cháy 52; 0: 57 cấu hình, cháy 5%, DD trung vị 22%, không cháy 54; 1: 62 cấu hình, cháy 8%, DD trung vị 26%, không cháy 57; 2: 61 cấu hình, cháy 2%, DD trung vị 22%, không cháy 60; 4: 60 cấu hình, cháy 7%, DD trung vị 24%, không cháy 56; 6: 65 cấu hình, cháy 6%, DD trung vị 21%, không cháy 61
- **InpXoaTuSoTang** — 2: 79 cấu hình, cháy 4%, DD trung vị 21%, không cháy 76; 3: 84 cấu hình, cháy 4%, DD trung vị 21%, không cháy 81; 4: 109 cấu hình, cháy 6%, DD trung vị 21%, không cháy 103; 6: 88 cấu hình, cháy 9%, DD trung vị 29%, không cháy 80
- **InpChanNguocXH** — True: 186 cấu hình, cháy 5%, DD trung vị 23%, không cháy 176; False: 174 cấu hình, cháy 6%, DD trung vị 23%, không cháy 164
- **InpPP0MA** — 20: 98 cấu hình, cháy 8%, DD trung vị 33%, không cháy 90; 50: 79 cấu hình, cháy 5%, DD trung vị 28%, không cháy 75; 100: 107 cấu hình, cháy 7%, DD trung vị 24%, không cháy 99; 200: 76 cấu hình, cháy 0%, DD trung vị 15%, không cháy 76
- **InpGiayGiuaDCA** — 20: 104 cấu hình, cháy 6%, DD trung vị 22%, không cháy 98; 60: 149 cấu hình, cháy 3%, DD trung vị 22%, không cháy 144; 180: 107 cấu hình, cháy 8%, DD trung vị 26%, không cháy 98
- **InpTiaLapLai** — True: 162 cấu hình, cháy 7%, DD trung vị 32%, không cháy 150; False: 198 cấu hình, cháy 4%, DD trung vị 20%, không cháy 190
- **InpGiayChoSauClear** — 10: 169 cấu hình, cháy 7%, DD trung vị 24%, không cháy 157; 60: 191 cấu hình, cháy 4%, DD trung vị 22%, không cháy 183

### 1.3 Các cấu hình không cháy (bước 1 + 2), xếp theo mức rồi lãi / DD

| ten | nhom | muc | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N188:trail=60 | lang_gieng_ben | A | 36265 | 0 | 13.40 | 4.15 | 13120 | 10110 | 99.12 | 22626 | 0.06 | 0.60 | 53.80 | 29 | 1.82 | 49183.90 | 16950 | 19323 | -169 | lot 0.01 ×1.3 trần 0.1; tầng max(4.5; 0.5×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 4; xóa tat/4; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| N343:buoc_atr=1.5 | lang_gieng_ben | A | 14734 | 0 | 7.50 | 3.48 | 4881 | 2888 | 28.31 | 4307 | 0.19 | 1.90 | 167.60 | 19 | 0.61 | 48507.60 | 6341 | 9000 | -58 | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 1.5×ATR) × 20; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 6; xóa 4/2; SMA200 H1; DCA 180s; lặp không; chờ 60s |
| N044 | ngau_nhien | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:kieu_lot=1.15 | lang_gieng_ben | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 ×1.15 trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:kieu_lot=1.2 | lang_gieng_ben | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 ×1.2 trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:so_tang=30 | lang_gieng_ben | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:xoa_tu=3 | lang_gieng_ben | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:xoa_tu=6 | lang_gieng_ben | A | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/6; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:loc_xh=True | lang_gieng_ben | A | 12984 | 0 | 7.50 | 3.33 | 4889 | 1345 | 13.19 | 2087 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6278 | 6960 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
| N044:trail=80 | lang_gieng_ben | A | 15116 | 0 | 8.50 | 3.24 | 5588 | 1380 | 13.53 | 2161 | 0.32 | 5.60 | 160.10 | 13 | 0.25 | 48089.90 | 6888 | 8521 | -67 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:tia_tp=2.0 | lang_gieng_ben | A | 13086 | 0 | 7.90 | 3.16 | 5086 | 1300 | 12.75 | 1996 | 0.42 | 5.90 | 159.00 | 11 | 0.19 | 48141.70 | 6445 | 6926 | -69 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 2.0; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N188:kieu_lot=1.2 | lang_gieng_ben | A | 32615 | 0 | 17.90 | 3.13 | 12109 | 9081 | 89.03 | 22159 | 0.06 | 0.70 | 73.60 | 29 | 1.47 | 47657.10 | 15454 | 17170 | -179 | lot 0.01 ×1.2 trần 0.1; tầng max(4.5; 0.5×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 80; HV 4; xóa tat/4; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| N044:giay_dca=60 | lang_gieng_ben | A | 12853 | 0 | 7.90 | 3.11 | 4844 | 1341 | 13.15 | 2066 | 0.39 | 5.60 | 159.00 | 12 | 0.23 | 48026.00 | 6115 | 6992 | -65 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 60s; lặp có; chờ 10s |
| N044:hoa_von_tang=2 | lang_gieng_ben | A | 12034 | 0 | 7.50 | 3.08 | 4452 | 1474 | 14.45 | 2282 | 0.41 | 5.40 | 75.50 | 12 | 0.19 | 48087.20 | 6201 | 6121 | -74 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 2; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N044:lot_max=0.03 | lang_gieng_ben | A | 12609 | 0 | 8.40 | 2.87 | 4673 | 1322 | 12.96 | 2041 | 0.39 | 5.80 | 158.90 | 16 | 0.42 | 47761.40 | 5931 | 6882 | -66 | lot 0.01 bảng Hydra trần 0.03; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N024:buoc_atr=2.0 | lang_gieng_ben | A | 13187 | 0 | 8.90 | 2.85 | 5078 | 1485 | 14.56 | 2311 | 0.40 | 4.60 | 158.80 | 12 | 0.30 | 47597.10 | 6770 | 6908 | -69 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 2.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N029:hoa_von_tang=3 | lang_gieng_ben | A | 23820 | 0 | 15.80 | 2.84 | 7853 | 2229 | 21.85 | 5553 | 0.40 | 2.80 | 74.10 | 19 | 0.56 | 44768.50 | 10159 | 13958 | -90 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 3; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:ma_h1=100 | lang_gieng_ben | A | 22707 | 0 | 14.40 | 2.84 | 7634 | 2604 | 25.53 | 6066 | 0.36 | 2.50 | 74.80 | 19 | 0.56 | 47676.80 | 10586 | 12418 | -124 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA100 H1; DCA 180s; lặp có; chờ 60s |
| N029:so_tang=16 | lang_gieng_ben | A | 21526 | 0 | 14.20 | 2.78 | 6775 | 2476 | 24.27 | 5809 | 0.36 | 2.40 | 74.80 | 15 | 0.46 | 46119.90 | 9079 | 12744 | -81 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N311 | ngau_nhien | A | 12910 | 0 | 8.50 | 2.76 | 5231 | 1569 | 15.38 | 2629 | 0.34 | 4.80 | 159.90 | 13 | 0.39 | 48626.70 | 6611 | 6767 | -75 | lot 0.01 ×1.15 trần 0.2; tầng max(8.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 4; xóa 4/2; SMA100 H1; DCA 60s; lặp có; chờ 60s |
| N029 | ngau_nhien | A | 21838 | 0 | 14.60 | 2.73 | 6901 | 2489 | 24.40 | 5864 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 46760.60 | 9249 | 12886 | -81 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:tp_atr=2.0 | lang_gieng_ben | A | 21919 | 0 | 14.60 | 2.73 | 7017 | 2257 | 22.13 | 5571 | 0.38 | 2.80 | 74.80 | 19 | 0.56 | 46823.30 | 9171 | 13094 | -89 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:xoa_tu=3 | lang_gieng_ben | A | 21878 | 0 | 14.60 | 2.73 | 7001 | 2492 | 24.43 | 5870 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 46861.30 | 9348 | 12827 | -81 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/3; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:xoa_tu=6 | lang_gieng_ben | A | 21819 | 0 | 14.60 | 2.73 | 6964 | 2485 | 24.36 | 5849 | 0.36 | 2.40 | 74.10 | 19 | 0.56 | 46885.80 | 9178 | 12938 | -83 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/6; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:so_tang=30 | lang_gieng_ben | A | 21801 | 0 | 14.60 | 2.72 | 6954 | 2494 | 24.45 | 5917 | 0.36 | 2.40 | 74.10 | 29 | 0.88 | 45318.00 | 9264 | 12834 | -82 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:loc_xh=True | lang_gieng_ben | A | 21672 | 0 | 14.60 | 2.71 | 6914 | 2480 | 24.31 | 5829 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 46795.60 | 9298 | 12671 | -81 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
| N024:tp_atr=0.5 | lang_gieng_ben | A | 9901 | 0 | 7.10 | 2.66 | 2339 | 1957 | 19.19 | 2400 | 0.11 | 3.10 | 332.10 | 13 | 0.34 | 48373.80 | 4797 | 5563 | -48 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 0.5×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N029:lot_max=0.1 | lang_gieng_ben | A | 22097 | 0 | 15.60 | 2.58 | 7138 | 2524 | 24.75 | 5934 | 0.36 | 2.40 | 74.80 | 19 | 0.71 | 46258.60 | 9409 | 12986 | -81 | lot 0.01 ×1.15 trần 0.1; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:xoa=tat | lang_gieng_ben | A | 22329 | 0 | 16.00 | 2.55 | 7370 | 2527 | 24.77 | 5896 | 0.36 | 2.40 | 74.10 | 19 | 0.62 | 46133.80 | 9134 | 13199 | -84 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N029:kieu_lot=1.1 | lang_gieng_ben | A | 19307 | 0 | 13.40 | 2.52 | 6718 | 2202 | 21.59 | 5347 | 0.36 | 2.60 | 159.10 | 19 | 0.53 | 49260.20 | 8137 | 11450 | -66 | lot 0.01 ×1.1 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N117 | ngau_nhien | A | 15476 | 0 | 11.80 | 2.49 | 6323 | 2216 | 21.73 | 5180 | 0.31 | 2.60 | 158.90 | 24 | 0.82 | 46446.80 | 7583 | 7894 | -68 | lot 0.01 ×1.1 trần 0.5; tầng max(4.5; 1.15×ATR) × 30; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 2; xóa 2/3; SMA100 H1; DCA 20s; lặp có; chờ 60s |
| N024:xoa_tu=4 | lang_gieng_ben | A | 8440 | 0 | 6.80 | 2.39 | 1548 | 929 | 9.11 | 1303 | 0.41 | 7.00 | 332.70 | 9 | 0.23 | 48430.10 | 4282 | 4661 | -39 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 6/4; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N343:tia_tp=1.5 | lang_gieng_ben | A | 10593 | 0 | 8.10 | 2.39 | 4144 | 2212 | 21.69 | 3084 | 0.20 | 2.70 | 158.90 | 19 | 0.60 | 48233.20 | 5292 | 5936 | -56 | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 1.5; clear 0.5×ATR trail 40; HV 6; xóa 4/2; SMA200 H1; DCA 180s; lặp không; chờ 60s |
| N029:buoc_min=10.0 | lang_gieng_ben | A | 19120 | 0 | 14.70 | 2.39 | 6144 | 1986 | 19.47 | 4532 | 0.41 | 3.10 | 74.40 | 19 | 0.65 | 46559.20 | 8063 | 11416 | -71 | lot 0.01 ×1.15 trần 0.05; tầng max(10.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N024:trail=40 | lang_gieng_ben | A | 8635 | 0 | 7.00 | 2.37 | 3361 | 1007 | 9.87 | 1406 | 0.46 | 6.60 | 167.00 | 9 | 0.22 | 48094.50 | 4386 | 4750 | -36 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 40; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N024:tp_atr=1.5 | lang_gieng_ben | A | 8622 | 0 | 7.10 | 2.35 | 1750 | 643 | 6.30 | 1010 | 0.78 | 10.90 | 332.60 | 9 | 0.22 | 48234.10 | 4152 | 4929 | -63 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.5×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N309:buoc_atr=4.0 | lang_gieng_ben | A | 7258 | 0 | 6.00 | 2.34 | 2815 | 501 | 4.91 | 720 | 1.41 | 19.60 | 159.20 | 7 | 0.18 | 48390.70 | 3694 | 3773 | -43 | lot 0.01 ×1.3 trần 0.03; tầng max(10.0; 4.0×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 0; xóa 4/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| N024:hoa_von_tang=6 | lang_gieng_ben | A | 8702 | 0 | 7.20 | 2.34 | 1523 | 936 | 9.18 | 1309 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 48258.50 | 4370 | 4835 | -39 | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 6; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
| N029:tp_atr=1.0 | lang_gieng_ben | A | 22094 | 0 | 16.20 | 2.34 | 7595 | 3004 | 29.45 | 6304 | 0.26 | 1.90 | 159.00 | 19 | 0.57 | 48908.40 | 9309 | 13146 | -73 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| N033 | ngau_nhien | A | 9616 | 0 | 7.90 | 2.33 | 1280 | 319 | 3.13 | 872 | 1.77 | 23.60 | 684.00 | 11 | 0.19 | 48183.10 | 5218 | 4765 | -61 | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 12; xóa 6/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |

## 2b. Độ bền trên 5 đường giá (gốc + 4 thứ tự cực trị ngẫu nhiên)

Mọi cấu hình không cháy và có lãi ở đường giá gốc chạy thêm trên 4 đường giá khác (chỉ đổi thứ tự đỉnh / đáy trong từng nến M1). Bền = không cháy trên cả 5 đường; mức theo DD lớn nhất của 5 đường (A ≤ 35%, B ≤ 50%, C còn lại).

- Cấu hình xét: **239**; bền: **223** (mức A 130, B 32, C 61); cháy trên ít nhất một đường khác: **16**.

### 2b.1 Các cấu hình bền (xếp theo mức rồi trung vị điểm 5 đường)

| ung_vien | ten | muc | dd_max_duong | dd_goc | net_goc | net_tv | diem_tv_duong | trung_vi_diem_lang_gieng | lang_gieng_chay | so_lang_gieng | diem_vung | cau_hinh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U2 | N188 | A | 30.70 | 30.70 | 37478.20 | 44444.00 | 5.18 | 2.16 | 1.00 | 24.00 | 2.18 | lot 0.01 ×1.3 trần 0.1; tầng max(4.5; 0.5×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 80; HV 4; xóa tat/4; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
| U5 | N171 | A | 24.30 | 24.30 | 21354.00 | 26105.70 | 4.71 | 1.29 | 5.00 | 24.00 | 1.29 | lot 0.01 ×1.15 trần 0.1; tầng max(1.5; 0.8×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 2; xóa 2/2; SMA20 H1; DCA 60s; lặp có; chờ 60s |
| U3 | N044 | A | 24.20 | 7.50 | 13030.40 | 13131.20 | 2.53 | 1.45 | 1.00 | 24.00 | 1.97 | lot 0.01 bảng Hydra trần 0.02; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp có; chờ 10s |
| U1 | N029 | A | 23.50 | 14.60 | 21838.30 | 21404.90 | 2.14 | 2.32 | 0.00 | 27.00 | 2.31 | lot 0.01 ×1.15 trần 0.05; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 2; xóa 0/4; SMA200 H1; DCA 180s; lặp có; chờ 60s |
| U4 | N112 | A | 26.30 | 19.70 | 19948.70 | 23447.90 | 1.81 | 1.80 | 2.00 | 23.00 | 1.80 | lot 0.01 ×1.2 trần 0.5; tầng max(20.0; 0.5×ATR) × 40; TP tỉa 2.0; clear 0.5×ATR trail 60; HV 8; xóa 2/2; SMA100 H1; DCA 180s; lặp có; chờ 10s |
|  | N049 | A | 24.40 | 24.20 | 22250.50 | 22250.50 | 1.75 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(15.0; 0.5×ATR) × 30; TP tỉa 2.0; clear 0.5×ATR trail 80; HV 8; xóa 4/4; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N306 | A | 23.40 | 20.40 | 20001.30 | 18941.00 | 1.69 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(10.0; 1.15×ATR) × 16; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 12; xóa 6/3; SMA200 H1; DCA 60s; lặp có; chờ 10s |
|  | N309 | A | 10.00 | 9.70 | 8238.50 | 7784.80 | 1.55 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(10.0; 3.0×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 0; xóa 4/3; SMA200 H1; DCA 180s; lặp có; chờ 10s |
|  | N094 | A | 11.80 | 10.30 | 10521.20 | 9361.30 | 1.52 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(12.0; 1.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 0; xóa 0/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N218 | A | 22.70 | 20.50 | 15865.80 | 15865.80 | 1.47 |  |  |  |  | lot 0.01 ×1.3 trần 0.1; tầng max(10.0; 2.0×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail tat; HV 6; xóa 2/3; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N052 | A | 22.00 | 22.00 | 12052.30 | 13408.60 | 1.46 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(15.0; 0.5×ATR) × 20; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 2; xóa tat/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N304 | A | 21.70 | 21.70 | 15773.40 | 15625.20 | 1.46 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(12.0; 1.15×ATR) × 16; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 3; xóa 4/3; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N139 | A | 23.90 | 23.90 | 10134.40 | 10134.40 | 1.44 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(15.0; 2.0×ATR) × 20; TP tỉa 0.75; clear 1.0×ATR trail 40; HV 6; xóa 2/6; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N024 | A | 14.10 | 7.20 | 8550.00 | 8676.70 | 1.31 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(12.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N074 | A | 14.60 | 10.70 | 7675.60 | 7637.40 | 1.24 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(1.5; 1.5×ATR) × 40; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 2; xóa 0/3; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N343 | A | 17.70 | 11.80 | 9898.90 | 8033.70 | 1.24 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 6; xóa 4/2; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N079 | A | 19.70 | 17.70 | 9559.30 | 10540.90 | 1.16 |  |  |  |  | lot 0.01 ×1.05 trần 0.02; tầng max(1.5; 0.8×ATR) × 12; TP tỉa 1.5; clear 2.0×ATR trail 40; HV 8; xóa tat/4; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N308 | A | 18.60 | 18.60 | 10650.70 | 7852.50 | 1.12 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(1.5; 1.5×ATR) × 8; TP tỉa 0.5; clear 0.5×ATR trail 80; HV 4; xóa 2/2; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N086 | A | 23.80 | 21.50 | 5184.80 | 7324.30 | 1.05 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(6.0; 1.15×ATR) × 8; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 12; xóa 6/6; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N238 | A | 20.90 | 20.90 | 9348.30 | 11165.30 | 1.05 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(4.5; 0.8×ATR) × 12; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 2; xóa tat/2; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N294 | A | 16.00 | 16.00 | 5758.00 | 6160.50 | 1.01 |  |  |  |  | lot 0.01 ×1.2 trần 0.2; tầng max(15.0; 4.0×ATR) × 12; TP tỉa 1.5; clear 1.0×ATR trail 40; HV 12; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 10s |
|  | N211 | A | 10.30 | 6.90 | 3469.50 | 4241.30 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 4; xóa 2/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N340 | A | 7.40 | 7.20 | 4942.90 | 3752.60 | 0.97 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(10.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 2; xóa 6/4; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N289 | A | 29.90 | 28.80 | 13577.40 | 13904.40 | 0.96 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(3.0; 2.0×ATR) × 16; TP tỉa 0.5; clear 1.0×ATR trail 60; HV 12; xóa 0/3; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N033 | A | 13.30 | 7.90 | 9615.70 | 6378.90 | 0.95 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 12; xóa 6/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N208 | A | 20.30 | 8.40 | 10092.80 | 10051.70 | 0.92 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(1.5; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 4; xóa 4/3; SMA200 H1; DCA 20s; lặp không; chờ 10s |
|  | N012 | A | 26.20 | 26.00 | 12797.20 | 13138.50 | 0.91 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(10.0; 1.15×ATR) × 30; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 2; xóa 1/6; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N043 | A | 23.00 | 18.50 | 8470.80 | 9376.10 | 0.91 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(10.0; 0.8×ATR) × 12; TP tỉa 1.0; clear 1.0×ATR trail tat; HV 6; xóa 6/2; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N097 | A | 28.50 | 5.50 | 2712.20 | 2042.10 | 0.90 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(3.0; 4.0×ATR) × 40; TP tỉa 0.5; clear 3.0×ATR trail 40; HV 0; xóa 6/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | N282 | A | 20.90 | 5.30 | 6509.40 | 5527.90 | 0.88 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 3; xóa 4/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N046 | A | 20.00 | 17.40 | 7531.20 | 8835.70 | 0.85 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(20.0; 3.0×ATR) × 40; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 0; xóa 1/3; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N303 | A | 19.70 | 19.70 | 2562.10 | 7153.70 | 0.85 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(3.0; 0.8×ATR) × 30; TP tỉa 1.0; clear 2.0×ATR trail 40; HV 3; xóa 2/2; SMA50 H1; DCA 20s; lặp không; chờ 10s |
|  | N050 | A | 30.50 | 30.30 | 11715.80 | 12495.70 | 0.83 |  |  |  |  | lot 0.01 ×1.2 trần 0.03; tầng max(1.5; 1.15×ATR) × 12; TP tỉa 1.5; clear 3.0×ATR trail 40; HV 2; xóa 6/3; SMA50 H1; DCA 60s; lặp có; chờ 10s |
|  | N141 | A | 9.30 | 7.50 | 2281.10 | 2681.50 | 0.80 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 3.0×ATR) × 16; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 8; xóa 6/3; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N299 | A | 10.50 | 7.30 | 4121.60 | 3981.30 | 0.76 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(6.0; 2.0×ATR) × 20; TP tỉa 1.0; clear 1.5×ATR trail 80; HV 6; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N243 | A | 8.80 | 7.10 | 3013.70 | 3002.20 | 0.74 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(12.0; 3.0×ATR) × 40; TP tỉa 0.5; clear 2.0×ATR trail tat; HV 8; xóa 0/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N066 | A | 20.70 | 20.70 | 7607.90 | 7607.90 | 0.70 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(3.0; 1.15×ATR) × 8; TP tỉa 2.0; clear 0.5×ATR trail 80; HV 0; xóa 6/6; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N082 | A | 9.40 | 7.00 | 2133.80 | 2134.00 | 0.70 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 4; xóa 6/6; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N143 | A | 17.40 | 15.30 | 5111.30 | 5492.30 | 0.70 |  |  |  |  | lot 0.01 ×1.0 trần 0.03; tầng max(10.0; 3.0×ATR) × 20; TP tỉa 0.5; clear 0.5×ATR trail tat; HV 3; xóa tat/2; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N315 | A | 30.80 | 30.80 | 6361.90 | 7246.10 | 0.69 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(10.0; 1.15×ATR) × 40; TP tỉa 0.75; clear 3.0×ATR trail 40; HV 0; xóa 2/2; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N278 | A | 14.50 | 13.50 | 4549.90 | 4549.90 | 0.65 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(10.0; 4.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 3; xóa 0/3; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N101 | A | 12.50 | 11.50 | 3868.50 | 3868.50 | 0.64 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(8.0; 2.0×ATR) × 20; TP tỉa 0.75; clear 1.5×ATR trail 80; HV 6; xóa 0/2; SMA200 H1; DCA 60s; lặp không; chờ 60s |
|  | N348 | A | 15.60 | 11.80 | 4285.10 | 3890.30 | 0.63 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(3.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 1.5×ATR trail 60; HV 2; xóa 6/3; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N280 | A | 25.90 | 6.60 | 7093.20 | 7426.30 | 0.62 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail 80; HV 4; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
|  | N121 | A | 32.10 | 24.60 | 7629.70 | 7685.70 | 0.59 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(1.5; 1.15×ATR) × 12; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 2; xóa 1/2; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N064 | A | 16.80 | 16.80 | 4459.00 | 4822.20 | 0.56 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(20.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 12; xóa 2/2; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N323 | A | 17.00 | 15.50 | 1140.80 | 4024.30 | 0.56 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 1.15×ATR) × 12; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 12; xóa 2/6; SMA100 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N048 | A | 19.00 | 19.00 | 5267.90 | 5267.90 | 0.54 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(15.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 6; xóa 1/4; SMA200 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N321 | A | 11.50 | 9.00 | 3185.00 | 2754.10 | 0.50 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(20.0; 4.0×ATR) × 8; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 4; xóa 2/2; SMA200 H1; DCA 20s; lặp không; chờ 60s |
|  | N313 | A | 15.80 | 15.80 | 913.00 | 2837.70 | 0.49 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(3.0; 3.0×ATR) × 5; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 3; xóa tat/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N035 | A | 20.80 | 18.80 | 4612.60 | 4906.90 | 0.48 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(15.0; 2.0×ATR) × 40; TP tỉa 0.75; clear 3.0×ATR trail 80; HV 12; xóa 2/2; SMA200 H1; DCA 60s; lặp có; chờ 60s |
|  | N119 | A | 19.90 | 15.00 | 5010.20 | 3888.90 | 0.47 |  |  |  |  | lot 0.01 ×1.3 trần 0.1; tầng max(15.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 2; xóa 1/6; SMA50 H1; DCA 20s; lặp có; chờ 60s |
|  | N226 | A | 28.50 | 28.50 | 5614.60 | 6885.10 | 0.47 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(12.0; 1.15×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail 80; HV 2; xóa 2/2; SMA200 H1; DCA 180s; lặp có; chờ 10s |
|  | N271 | A | 24.50 | 21.00 | 4928.50 | 4992.80 | 0.46 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(1.5; 3.0×ATR) × 12; TP tỉa 2.0; clear 1.0×ATR trail tat; HV 3; xóa tat/4; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N330 | A | 18.90 | 18.70 | 6240.60 | 4363.00 | 0.46 |  |  |  |  | lot 0.01 ×1.1 trần 0.02; tầng max(25.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 3; xóa tat/4; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N326 | A | 20.00 | 20.00 | 2938.20 | 3987.70 | 0.45 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(25.0; 3.0×ATR) × 5; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 2; xóa 4/4; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N347 | A | 30.20 | 21.50 | 5871.00 | 5198.40 | 0.45 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(25.0; 3.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 8; xóa 4/2; SMA20 H1; DCA 180s; lặp không; chờ 60s |
|  | N092 | A | 15.90 | 15.80 | 3631.80 | 3521.30 | 0.44 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(20.0; 2.0×ATR) × 5; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 2; xóa 1/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N236 | A | 25.10 | 17.70 | 5391.50 | 5546.80 | 0.44 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(15.0; 1.5×ATR) × 16; TP tỉa 1.5; clear 0.5×ATR trail tat; HV 2; xóa 6/4; SMA200 H1; DCA 60s; lặp có; chờ 10s |
|  | N325 | A | 22.90 | 16.90 | 6525.60 | 4972.50 | 0.44 |  |  |  |  | lot 0.01 bảng Hydra trần 0.03; tầng max(10.0; 3.0×ATR) × 8; TP tỉa 1.5; clear 0.5×ATR trail 40; HV 3; xóa 2/3; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N067 | A | 30.50 | 30.50 | 5951.10 | 6253.50 | 0.41 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(3.0; 2.0×ATR) × 12; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 6; xóa 2/6; SMA100 H1; DCA 60s; lặp có; chờ 10s |
|  | N160 | A | 24.50 | 19.60 | 186.60 | 4071.70 | 0.41 |  |  |  |  | lot 0.01 ×1.1 trần 0.05; tầng max(15.0; 0.8×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 12; xóa 2/4; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | N230 | A | 33.60 | 31.80 | 6586.60 | 6586.60 | 0.41 |  |  |  |  | lot 0.01 ×1.1 trần 0.03; tầng max(3.0; 1.15×ATR) × 12; TP tỉa 1.5; clear 3.0×ATR trail 60; HV 8; xóa 6/6; SMA100 H1; DCA 60s; lặp có; chờ 60s |
|  | N260 | A | 16.10 | 15.50 | 2921.90 | 3119.70 | 0.40 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 3.0×ATR) × 5; TP tỉa 2.0; clear 0.5×ATR trail 60; HV 8; xóa 6/2; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N342 | A | 11.30 | 11.30 | 2264.70 | 2264.70 | 0.40 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 4.0×ATR) × 5; TP tỉa 1.0; clear 0.5×ATR trail 60; HV 0; xóa 6/4; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N127 | A | 28.30 | 28.20 | 3845.70 | 5452.00 | 0.39 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(20.0; 2.0×ATR) × 8; TP tỉa 0.5; clear 0.5×ATR trail 40; HV 6; xóa 4/4; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N244 | A | 22.20 | 20.00 | 4017.50 | 4202.50 | 0.39 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(4.5; 4.0×ATR) × 20; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 0; xóa 6/6; SMA200 H1; DCA 20s; lặp có; chờ 60s |
|  | N334 | A | 33.80 | 32.10 | 5364.40 | 6030.90 | 0.37 |  |  |  |  | lot 0.01 ×1.05 trần 0.02; tầng max(20.0; 1.15×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail tat; HV 3; xóa 1/3; SMA100 H1; DCA 60s; lặp có; chờ 60s |
|  | N354 | A | 29.60 | 28.50 | 5336.50 | 5373.90 | 0.37 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(6.0; 2.0×ATR) × 8; TP tỉa 1.5; clear 2.0×ATR trail tat; HV 3; xóa 2/4; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N089 | A | 33.80 | 33.10 | 6008.10 | 6008.10 | 0.36 |  |  |  |  | lot 0.01 ×1.3 trần 0.2; tầng max(10.0; 3.0×ATR) × 8; TP tỉa 0.75; clear 1.5×ATR trail 60; HV 12; xóa 0/6; SMA100 H1; DCA 180s; lặp có; chờ 60s |
|  | N014 | A | 23.30 | 23.30 | 1138.10 | 3754.40 | 0.34 |  |  |  |  | lot 0.01 ×1.1 trần 0.05; tầng max(1.5; 0.5×ATR) × 16; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 2; xóa 2/3; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N096 | A | 24.20 | 24.20 | 4005.70 | 4037.00 | 0.33 |  |  |  |  | lot 0.01 ×1.2 trần 0.2; tầng max(20.0; 3.0×ATR) × 12; TP tỉa 1.0; clear 1.5×ATR trail tat; HV 2; xóa 2/4; SMA20 H1; DCA 20s; lặp không; chờ 60s |
|  | N274 | A | 32.80 | 32.80 | 5141.90 | 5087.70 | 0.31 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(10.0; 3.0×ATR) × 8; TP tỉa 1.5; clear 2.0×ATR trail tat; HV 12; xóa 0/4; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N352 | A | 32.00 | 32.00 | 4561.30 | 4781.40 | 0.30 |  |  |  |  | lot 0.01 ×1.15 trần 0.05; tầng max(10.0; 1.5×ATR) × 8; TP tỉa 1.0; clear 0.5×ATR trail 80; HV 4; xóa 2/4; SMA20 H1; DCA 60s; lặp có; chờ 60s |
|  | N055 | A | 20.70 | 20.60 | 2952.20 | 2952.20 | 0.29 |  |  |  |  | lot 0.01 ×1.3 trần 0.2; tầng max(15.0; 3.0×ATR) × 5; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 3; xóa 0/4; SMA100 H1; DCA 60s; lặp không; chờ 60s |
|  | N020 | A | 17.30 | 17.30 | 2210.40 | 2210.40 | 0.26 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(20.0; 3.0×ATR) × 5; TP tỉa 1.0; clear 1.5×ATR trail 60; HV 6; xóa 6/3; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N293 | A | 32.10 | 13.00 | 2150.90 | 2596.60 | 0.26 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(1.5; 2.0×ATR) × 16; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 4; xóa 4/6; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N167 | A | 33.40 | 33.40 | 4088.40 | 3953.10 | 0.24 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(6.0; 4.0×ATR) × 8; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 0; xóa tat/6; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N237 | A | 27.10 | 26.40 | 3603.10 | 3204.40 | 0.24 |  |  |  |  | lot 0.01 ×1.0 trần 0.05; tầng max(6.0; 2.0×ATR) × 12; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 3; xóa tat/4; SMA100 H1; DCA 180s; lặp có; chờ 10s |
|  | N316 | A | 19.60 | 19.60 | 529.30 | 2299.90 | 0.24 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(25.0; 1.5×ATR) × 16; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 6; xóa 4/6; SMA20 H1; DCA 60s; lặp không; chờ 60s |
|  | N351 | A | 25.40 | 24.10 | 3172.00 | 2829.20 | 0.23 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(3.0; 4.0×ATR) × 8; TP tỉa 0.5; clear 1.0×ATR trail tat; HV 2; xóa 4/6; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N217 | A | 16.90 | 13.10 | 1.60 | 873.20 | 0.22 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(8.0; 1.15×ATR) × 30; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 12; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N283 | A | 17.40 | 17.40 | 1502.10 | 1957.10 | 0.22 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(20.0; 4.0×ATR) × 8; TP tỉa 1.0; clear 1.0×ATR trail 80; HV 4; xóa 0/3; SMA100 H1; DCA 60s; lặp có; chờ 10s |
|  | N252 | A | 31.90 | 31.90 | 1323.00 | 3301.00 | 0.21 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(12.0; 1.5×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 80; HV 3; xóa 1/3; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N307 | A | 21.60 | 21.60 | 2598.90 | 2102.10 | 0.21 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(10.0; 4.0×ATR) × 8; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 12; xóa 2/3; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N016 | A | 33.40 | 24.80 | 2446.90 | 2523.60 | 0.20 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(6.0; 4.0×ATR) × 16; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 12; xóa 6/6; SMA50 H1; DCA 180s; lặp không; chờ 60s |
|  | N011 | A | 20.90 | 20.90 | 1656.40 | 1656.40 | 0.19 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(4.5; 4.0×ATR) × 12; TP tỉa 1.0; clear 3.0×ATR trail 60; HV 0; xóa 1/3; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N257 | A | 17.60 | 17.60 | 914.20 | 1658.90 | 0.19 |  |  |  |  | lot 0.01 ×1.0 trần 0.5; tầng max(3.0; 1.15×ATR) × 12; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa 1/6; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N018 | A | 26.30 | 26.30 | 2558.40 | 2308.70 | 0.18 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(10.0; 4.0×ATR) × 8; TP tỉa 2.0; clear 1.5×ATR trail 80; HV 0; xóa 0/3; SMA20 H1; DCA 20s; lặp không; chờ 10s |
|  | N103 | A | 11.40 | 11.40 | 1431.90 | 988.70 | 0.18 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(6.0; 3.0×ATR) × 5; TP tỉa 0.75; clear 1.5×ATR trail tat; HV 6; xóa tat/3; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N198 | A | 22.40 | 22.40 | 567.50 | 1515.60 | 0.18 |  |  |  |  | lot 0.01 ×1.0 trần 0.1; tầng max(10.0; 1.5×ATR) × 12; TP tỉa 2.0; clear 1.0×ATR trail tat; HV 6; xóa tat/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N277 | A | 16.60 | 16.00 | 113.00 | 1287.80 | 0.18 |  |  |  |  | lot 0.01 ×1.1 trần 0.05; tầng max(1.5; 1.15×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail 60; HV 8; xóa tat/4; SMA100 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N032 | A | 34.00 | 34.00 | 2033.90 | 2415.00 | 0.17 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(6.0; 1.15×ATR) × 30; TP tỉa 1.0; clear 2.0×ATR trail 80; HV 8; xóa 0/6; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N153 | A | 18.40 | 11.20 | 2067.00 | 1293.60 | 0.17 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(25.0; 0.8×ATR) × 12; TP tỉa 1.0; clear 1.0×ATR trail 40; HV 2; xóa 6/3; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N030 | A | 28.90 | 28.80 | 2488.40 | 2371.40 | 0.16 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(20.0; 0.8×ATR) × 30; TP tỉa 0.75; clear 1.0×ATR trail 40; HV 2; xóa 0/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N159 | A | 11.50 | 11.50 | 933.30 | 933.30 | 0.16 |  |  |  |  | lot 0.01 ×1.0 trần 0.1; tầng max(3.0; 4.0×ATR) × 5; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 6; xóa tat/2; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | N000 | A | 35.00 | 26.00 | 2117.60 | 1579.80 | 0.15 |  |  |  |  | lot 0.01 ×1.1 trần 0.05; tầng max(6.0; 3.0×ATR) × 12; TP tỉa 1.5; clear 1.0×ATR trail 40; HV 2; xóa 1/3; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N146 | A | 23.50 | 23.50 | 736.00 | 1291.20 | 0.14 |  |  |  |  | lot 0.01 ×1.0 trần 0.1; tầng max(15.0; 4.0×ATR) × 20; TP tỉa 1.0; clear 3.0×ATR trail 80; HV 8; xóa 1/3; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N116 | A | 11.20 | 11.20 | 757.90 | 757.90 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(25.0; 4.0×ATR) × 5; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 6; xóa 4/3; SMA100 H1; DCA 180s; lặp không; chờ 10s |
|  | N177 | A | 9.10 | 9.10 | 33.10 | 456.60 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 20; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 12; xóa 1/3; SMA100 H1; DCA 60s; lặp không; chờ 10s |
|  | N201 | A | 22.10 | 21.10 | 1774.30 | 1423.50 | 0.13 |  |  |  |  | lot 0.01 ×1.0 trần 0.1; tầng max(4.5; 4.0×ATR) × 12; TP tỉa 2.0; clear 0.5×ATR trail 60; HV 2; xóa 0/4; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N228 | A | 24.50 | 20.00 | 1148.30 | 1390.80 | 0.13 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(10.0; 4.0×ATR) × 30; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 8; xóa 1/4; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N017 | A | 31.60 | 31.60 | 1616.20 | 1818.20 | 0.12 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(4.5; 3.0×ATR) × 8; TP tỉa 1.0; clear 2.0×ATR trail 40; HV 3; xóa tat/6; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N040 | A | 18.00 | 14.40 | 1345.80 | 1117.20 | 0.12 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(25.0; 4.0×ATR) × 12; TP tỉa 0.75; clear 1.0×ATR trail 40; HV 8; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N100 | A | 26.40 | 26.40 | 1120.00 | 1589.90 | 0.12 |  |  |  |  | lot 0.01 ×1.0 trần 0.5; tầng max(12.0; 1.5×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 4; xóa 4/4; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | N209 | A | 15.60 | 15.60 | 776.40 | 929.80 | 0.12 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(20.0; 4.0×ATR) × 5; TP tỉa 0.5; clear 3.0×ATR trail 80; HV 8; xóa tat/2; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N034 | A | 30.30 | 30.30 | 1532.90 | 1508.10 | 0.11 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(1.5; 1.15×ATR) × 30; TP tỉa 1.0; clear 3.0×ATR trail 80; HV 2; xóa 2/2; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | N099 | A | 19.40 | 17.50 | 956.50 | 956.50 | 0.11 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 8; xóa 4/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N223 | A | 29.90 | 29.90 | 2017.60 | 1624.80 | 0.11 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(1.5; 0.8×ATR) × 16; TP tỉa 0.5; clear 1.5×ATR trail 80; HV 6; xóa 4/6; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N002 | A | 23.40 | 19.50 | 898.50 | 898.50 | 0.09 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(1.5; 0.8×ATR) × 8; TP tỉa 1.5; clear 2.0×ATR trail tat; HV 3; xóa 2/4; SMA50 H1; DCA 20s; lặp không; chờ 60s |
|  | N022 | A | 17.10 | 17.10 | 1735.00 | 744.40 | 0.09 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(4.5; 2.0×ATR) × 20; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 3; xóa 1/2; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N168 | A | 20.50 | 20.50 | 965.90 | 965.90 | 0.09 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(25.0; 1.15×ATR) × 12; TP tỉa 2.0; clear 1.0×ATR trail 40; HV 3; xóa 1/2; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N213 | A | 13.00 | 8.00 | 318.40 | 318.40 | 0.08 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(1.5; 0.5×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail 40; HV 2; xóa tat/6; SMA200 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N285 | A | 17.50 | 17.50 | 72.10 | 620.00 | 0.07 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(20.0; 2.0×ATR) × 20; TP tỉa 0.5; clear 3.0×ATR trail 60; HV 2; xóa 0/3; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N312 | A | 21.60 | 19.20 | 579.90 | 579.90 | 0.06 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 0.8×ATR) × 8; TP tỉa 2.0; clear 1.0×ATR trail 80; HV 12; xóa 0/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N165 | A | 32.70 | 14.90 | 1666.90 | 309.40 | 0.04 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(3.0; 4.0×ATR) × 30; TP tỉa 0.5; clear 1.5×ATR trail tat; HV 4; xóa 1/3; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N070 | A | 11.90 | 7.80 | 105.40 | 139.10 | 0.03 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(6.0; 1.15×ATR) × 8; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 4; xóa 0/2; SMA100 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N124 | A | 16.00 | 11.90 | 164.60 | 164.60 | 0.03 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(6.0; 0.8×ATR) × 8; TP tỉa 0.75; clear 3.0×ATR trail tat; HV 8; xóa 2/2; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N186 | A | 27.60 | 27.60 | 1577.50 | 369.70 | 0.03 |  |  |  |  | lot 0.01 ×1.0 trần 0.2; tầng max(8.0; 3.0×ATR) × 20; TP tỉa 2.0; clear 1.0×ATR trail tat; HV 4; xóa 6/3; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N205 | A | 16.00 | 16.00 | 129.30 | 227.20 | 0.03 |  |  |  |  | lot 0.01 ×1.05 trần 0.5; tầng max(8.0; 2.0×ATR) × 8; TP tỉa 0.5; clear 2.0×ATR trail 80; HV 6; xóa 2/6; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N320 | A | 30.00 | 30.00 | 166.30 | 463.80 | 0.03 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(25.0; 1.5×ATR) × 30; TP tỉa 0.5; clear 0.5×ATR trail 40; HV 8; xóa 4/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | N180 | A | 34.60 | 34.60 | 237.70 | 304.90 | 0.02 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(12.0; 4.0×ATR) × 20; TP tỉa 1.5; clear 3.0×ATR trail 40; HV 12; xóa 1/2; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N062 | A | 17.80 | 11.20 | 649.60 | 11.80 | 0.00 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(12.0; 2.0×ATR) × 8; TP tỉa 2.0; clear 3.0×ATR trail 60; HV 0; xóa 4/4; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N063 | A | 20.70 | 18.00 | 39.10 | 39.10 | 0.00 |  |  |  |  | lot 0.01 ×1.3 trần 0.1; tầng max(8.0; 0.8×ATR) × 5; TP tỉa 2.0; clear 1.0×ATR trail 80; HV 0; xóa 2/6; SMA100 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N350 | A | 14.20 | 5.60 | 852.20 | -22.10 | 0.00 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(8.0; 1.15×ATR) × 5; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 0; xóa tat/6; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N296 | A | 20.00 | 20.00 | 1934.90 | -539.70 | -0.05 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 0.8×ATR) × 8; TP tỉa 0.75; clear 0.5×ATR trail 80; HV 3; xóa 0/6; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N136 | A | 11.10 | 7.10 | 80.50 | -199.10 | -0.11 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(1.5; 1.5×ATR) × 5; TP tỉa 0.5; clear 1.5×ATR trail 80; HV 3; xóa 1/2; SMA50 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N189 | A | 15.00 | 12.60 | 2068.70 | -1868.00 | -0.30 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(1.5; 2.0×ATR) × 5; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 12; xóa 0/4; SMA20 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N110 | A | 34.70 | 34.70 | 2783.50 | -4771.80 | -0.35 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(8.0; 0.5×ATR) × 8; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 8; xóa 1/4; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N005 | A | 25.00 | 14.00 | 5155.00 | -2687.10 | -0.39 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 3.0×ATR) × 8; TP tỉa 1.5; clear 3.0×ATR trail tat; HV 0; xóa 1/3; SMA200 H1 lọc M5; DCA 20s; lặp không; chờ 60s |
|  | N019 | B | 37.10 | 37.10 | 37363.10 | 37578.00 | 2.24 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(8.0; 0.5×ATR) × 40; TP tỉa 2.0; clear 1.0×ATR trail 40; HV 8; xóa 0/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N239 | B | 39.50 | 22.40 | 12154.00 | 13710.40 | 0.92 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(3.0; 1.15×ATR) × 12; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 0; xóa tat/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N225 | B | 44.90 | 44.90 | 17135.30 | 18838.40 | 0.88 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(12.0; 0.8×ATR) × 20; TP tỉa 1.0; clear 3.0×ATR trail 60; HV 3; xóa 4/6; SMA200 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N302 | B | 42.70 | 23.30 | 18173.10 | 17744.50 | 0.79 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(4.5; 0.8×ATR) × 20; TP tỉa 2.0; clear 3.0×ATR trail tat; HV 0; xóa tat/6; SMA200 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N233 | B | 41.30 | 40.30 | 15399.40 | 15399.40 | 0.75 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(4.5; 1.15×ATR) × 12; TP tỉa 2.0; clear 1.0×ATR trail 40; HV 0; xóa tat/3; SMA50 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N107 | B | 39.70 | 32.70 | 10529.80 | 10529.80 | 0.59 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(10.0; 0.5×ATR) × 16; TP tỉa 1.0; clear 0.5×ATR trail 40; HV 4; xóa 2/4; SMA200 H1; DCA 180s; lặp không; chờ 60s |
|  | N207 | B | 42.70 | 42.60 | 7274.40 | 9930.40 | 0.46 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(15.0; 0.8×ATR) × 20; TP tỉa 0.5; clear 2.0×ATR trail 40; HV 2; xóa 4/6; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N346 | B | 37.90 | 32.00 | 7092.80 | 7092.80 | 0.44 |  |  |  |  | lot 0.01 ×1.15 trần 0.02; tầng max(1.5; 0.5×ATR) × 40; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 6; xóa 1/3; SMA100 H1; DCA 20s; lặp không; chờ 60s |
|  | N088 | B | 43.10 | 43.10 | 7067.00 | 7288.80 | 0.38 |  |  |  |  | lot 0.01 ×1.2 trần 0.03; tầng max(20.0; 1.15×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 6; xóa 4/2; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N286 | B | 42.10 | 36.20 | 7368.80 | 7075.70 | 0.35 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(10.0; 1.5×ATR) × 16; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 3; xóa 6/2; SMA20 H1; DCA 60s; lặp có; chờ 60s |
|  | N265 | B | 46.60 | 46.00 | 7081.70 | 7542.50 | 0.32 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(25.0; 1.5×ATR) × 12; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 8; xóa tat/4; SMA20 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N254 | B | 46.20 | 39.50 | 5993.20 | 6235.20 | 0.30 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(25.0; 2.0×ATR) × 20; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 12; xóa tat/4; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N251 | B | 49.60 | 49.60 | 8489.00 | 6771.80 | 0.28 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(4.5; 0.8×ATR) × 12; TP tỉa 2.0; clear 1.5×ATR trail 60; HV 6; xóa 4/6; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N053 | B | 36.60 | 34.40 | 4116.90 | 5056.80 | 0.27 |  |  |  |  | lot 0.01 bảng Hydra trần 0.03; tầng max(25.0; 4.0×ATR) × 16; TP tỉa 1.0; clear 0.5×ATR trail 80; HV 6; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N031 | B | 43.60 | 43.60 | 5453.70 | 5261.20 | 0.25 |  |  |  |  | lot 0.01 ×1.0 trần 0.03; tầng max(25.0; 0.8×ATR) × 30; TP tỉa 1.5; clear 3.0×ATR trail 80; HV 2; xóa 4/3; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N329 | B | 43.50 | 25.10 | 2713.20 | 3011.40 | 0.22 |  |  |  |  | lot 0.01 ×1.3 trần 0.2; tầng max(1.5; 3.0×ATR) × 20; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 8; xóa 2/2; SMA20 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N013 | B | 39.20 | 32.10 | 2318.70 | 3973.10 | 0.21 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(4.5; 2.0×ATR) × 12; TP tỉa 1.0; clear 2.0×ATR trail tat; HV 8; xóa 2/4; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N039 | B | 38.60 | 38.20 | 3995.40 | 3666.30 | 0.20 |  |  |  |  | lot 0.01 bảng Hydra trần 0.2; tầng max(20.0; 4.0×ATR) × 12; TP tỉa 2.0; clear 1.0×ATR trail 40; HV 4; xóa 1/4; SMA100 H1; DCA 180s; lặp không; chờ 60s |
|  | N041 | B | 40.90 | 40.50 | 2580.70 | 2933.10 | 0.15 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(25.0; 4.0×ATR) × 12; TP tỉa 0.5; clear 3.0×ATR trail 40; HV 0; xóa 6/6; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N224 | B | 40.40 | 40.20 | 2567.60 | 2567.60 | 0.15 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(6.0; 1.15×ATR) × 30; TP tỉa 1.5; clear 1.0×ATR trail 60; HV 4; xóa 2/6; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N172 | B | 48.20 | 48.20 | 3398.40 | 3398.40 | 0.14 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 4.0×ATR) × 20; TP tỉa 1.5; clear 3.0×ATR trail tat; HV 4; xóa 1/4; SMA20 H1; DCA 60s; lặp không; chờ 60s |
|  | N145 | B | 49.10 | 49.10 | 3250.60 | 3250.60 | 0.13 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(10.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 2.0×ATR trail tat; HV 2; xóa 1/4; SMA20 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N202 | B | 36.20 | 25.50 | 453.10 | 1457.50 | 0.10 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(8.0; 1.15×ATR) × 30; TP tỉa 1.5; clear 0.5×ATR trail tat; HV 4; xóa 6/4; SMA100 H1 lọc M5; DCA 20s; lặp không; chờ 10s |
|  | N106 | B | 49.10 | 47.50 | 1414.60 | 1626.30 | 0.07 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(4.5; 4.0×ATR) × 40; TP tỉa 1.0; clear 0.5×ATR trail tat; HV 6; xóa 1/3; SMA20 H1; DCA 180s; lặp có; chờ 60s |
|  | N324 | B | 43.00 | 37.90 | 2086.20 | 1319.10 | 0.07 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(3.0; 3.0×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 3; xóa 2/2; SMA50 H1; DCA 60s; lặp không; chờ 60s |
|  | N327 | B | 42.50 | 42.50 | 1101.40 | 1369.40 | 0.07 |  |  |  |  | lot 0.01 ×1.3 trần 0.2; tầng max(3.0; 1.5×ATR) × 8; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 0; xóa 0/4; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N357 | B | 40.50 | 29.80 | 172.80 | 1445.90 | 0.07 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(6.0; 0.5×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 4; xóa 6/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N061 | B | 39.60 | 39.60 | 1268.90 | 592.70 | 0.04 |  |  |  |  | lot 0.01 ×1.05 trần 0.05; tầng max(15.0; 3.0×ATR) × 30; TP tỉa 1.0; clear 3.0×ATR trail 40; HV 8; xóa 4/3; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N242 | B | 39.50 | 33.00 | 454.80 | 758.30 | 0.04 |  |  |  |  | lot 0.01 ×1.05 trần 0.5; tầng max(6.0; 3.0×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 4; xóa 4/2; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N169 | B | 41.00 | 38.70 | 695.90 | 675.40 | 0.03 |  |  |  |  | lot 0.01 ×1.0 trần 0.02; tầng max(25.0; 3.0×ATR) × 40; TP tỉa 1.5; clear 1.5×ATR trail 80; HV 12; xóa tat/6; SMA20 H1; DCA 20s; lặp không; chờ 60s |
|  | N310 | B | 49.00 | 31.80 | 292.50 | 271.50 | 0.02 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(15.0; 3.0×ATR) × 30; TP tỉa 0.5; clear 1.5×ATR trail tat; HV 12; xóa 0/3; SMA100 H1; DCA 20s; lặp không; chờ 60s |
|  | N214 | B | 38.10 | 32.00 | 449.20 | 165.10 | 0.01 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(6.0; 4.0×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 6; xóa 0/3; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N204 | C | 50.60 | 45.40 | 18882.30 | 19512.00 | 0.83 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(15.0; 0.8×ATR) × 30; TP tỉa 1.0; clear 1.0×ATR trail tat; HV 0; xóa tat/6; SMA20 H1; DCA 180s; lặp có; chờ 60s |
|  | N037 | C | 66.70 | 20.10 | 17768.20 | 17768.20 | 0.68 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(10.0; 0.5×ATR) × 30; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 0; xóa 2/4; SMA20 H1; DCA 20s; lặp có; chờ 60s |
|  | N076 | C | 90.30 | 90.30 | 8314.00 | 8953.20 | 0.55 |  |  |  |  | lot 0.01 ×1.15 trần 0.2; tầng max(25.0; 2.0×ATR) × 40; TP tỉa 0.5; clear 0.5×ATR trail 60; HV 12; xóa tat/2; SMA200 H1; DCA 180s; lặp có; chờ 60s |
|  | N287 | C | 52.80 | 52.80 | 9433.90 | 9708.90 | 0.54 |  |  |  |  | lot 0.01 bảng Hydra trần 0.03; tầng max(4.5; 1.15×ATR) × 40; TP tỉa 1.0; clear 0.5×ATR trail 40; HV 2; xóa 2/2; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N135 | C | 93.10 | 78.80 | 19586.90 | 19586.90 | 0.48 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(10.0; 0.8×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail tat; HV 4; xóa 0/2; SMA20 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N184 | C | 64.60 | 39.50 | 8999.30 | 8610.60 | 0.45 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(3.0; 2.0×ATR) × 16; TP tỉa 2.0; clear 2.0×ATR trail 40; HV 6; xóa 6/6; SMA20 H1; DCA 180s; lặp không; chờ 60s |
|  | N300 | C | 95.30 | 95.30 | 17794.60 | 20843.20 | 0.45 |  |  |  |  | lot 0.01 ×1.1 trần 0.5; tầng max(8.0; 0.5×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 80; HV 12; xóa tat/2; SMA200 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N093 | C | 60.50 | 60.50 | 9633.20 | 12193.70 | 0.41 |  |  |  |  | lot 0.01 ×1.1 trần 0.03; tầng max(25.0; 0.5×ATR) × 20; TP tỉa 0.75; clear 0.5×ATR trail 60; HV 0; xóa 6/6; SMA50 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N009 | C | 64.70 | 21.30 | 8146.80 | 7494.40 | 0.40 |  |  |  |  | lot 0.01 ×1.2 trần 0.2; tầng max(20.0; 0.8×ATR) × 12; TP tỉa 1.5; clear 3.0×ATR trail tat; HV 12; xóa 0/3; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N281 | C | 76.10 | 70.90 | 13742.20 | 14267.60 | 0.39 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(12.0; 1.5×ATR) × 20; TP tỉa 2.0; clear 0.5×ATR trail 40; HV 6; xóa 0/6; SMA100 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N057 | C | 71.00 | 70.80 | 10131.50 | 13181.10 | 0.36 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(6.0; 2.0×ATR) × 16; TP tỉa 1.0; clear 1.0×ATR trail 80; HV 8; xóa tat/4; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N078 | C | 54.40 | 47.70 | 9568.50 | 8819.60 | 0.36 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(20.0; 0.5×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 3; xóa 6/4; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N240 | C | 82.60 | 55.90 | 9913.80 | 9721.60 | 0.35 |  |  |  |  | lot 0.01 ×1.15 trần 0.1; tầng max(25.0; 0.8×ATR) × 16; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 4; xóa tat/4; SMA20 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N007 | C | 68.20 | 68.20 | 8836.80 | 11039.30 | 0.34 |  |  |  |  | lot 0.01 bảng Hydra trần 0.1; tầng max(8.0; 1.5×ATR) × 16; TP tỉa 0.75; clear 1.0×ATR trail 60; HV 3; xóa 2/2; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N235 | C | 71.00 | 71.00 | 12237.20 | 11879.50 | 0.33 |  |  |  |  | lot 0.01 ×1.1 trần 0.02; tầng max(1.5; 1.15×ATR) × 30; TP tỉa 2.0; clear 1.5×ATR trail 80; HV 3; xóa 2/2; SMA50 H1; DCA 60s; lặp có; chờ 60s |
|  | N191 | C | 52.90 | 48.90 | 100.50 | 4910.90 | 0.31 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(6.0; 1.15×ATR) × 20; TP tỉa 0.75; clear 3.0×ATR trail 60; HV 0; xóa 4/3; SMA20 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N199 | C | 72.00 | 72.00 | 9243.10 | 10787.40 | 0.31 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(15.0; 1.15×ATR) × 16; TP tỉa 0.5; clear 1.0×ATR trail 40; HV 8; xóa 1/2; SMA50 H1; DCA 20s; lặp có; chờ 10s |
|  | N241 | C | 75.40 | 75.40 | 9446.00 | 10804.10 | 0.31 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(6.0; 1.5×ATR) × 40; TP tỉa 2.0; clear 3.0×ATR trail 80; HV 6; xóa 0/4; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N083 | C | 61.00 | 61.00 | 6021.20 | 6846.70 | 0.29 |  |  |  |  | lot 0.01 ×1.15 trần 0.05; tầng max(3.0; 2.0×ATR) × 16; TP tỉa 1.5; clear 2.0×ATR trail 40; HV 6; xóa tat/4; SMA50 H1 lọc M5; DCA 180s; lặp không; chờ 60s |
|  | N150 | C | 73.10 | 73.10 | 7804.50 | 8965.30 | 0.28 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(12.0; 1.5×ATR) × 30; TP tỉa 0.5; clear 3.0×ATR trail tat; HV 0; xóa 0/3; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N317 | C | 82.40 | 72.90 | 11179.30 | 11060.10 | 0.27 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(4.5; 2.0×ATR) × 20; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 4; xóa 0/6; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N081 | C | 52.90 | 46.20 | 6023.40 | 6023.40 | 0.26 |  |  |  |  | lot 0.01 bảng Hydra trần 0.05; tầng max(10.0; 1.5×ATR) × 20; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 3; xóa 1/2; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N137 | C | 82.40 | 82.40 | 6955.00 | 8358.90 | 0.25 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(10.0; 3.0×ATR) × 30; TP tỉa 2.0; clear 0.5×ATR trail 60; HV 3; xóa 0/4; SMA50 H1; DCA 180s; lặp có; chờ 10s |
|  | N142 | C | 76.40 | 49.70 | 7331.80 | 6823.90 | 0.25 |  |  |  |  | lot 0.01 ×1.3 trần 0.03; tầng max(8.0; 3.0×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 0; xóa 1/6; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N183 | C | 66.80 | 66.80 | 8576.50 | 8179.00 | 0.25 |  |  |  |  | lot 0.01 ×1.15 trần 0.5; tầng max(1.5; 2.0×ATR) × 16; TP tỉa 1.0; clear 1.0×ATR trail tat; HV 12; xóa 4/2; SMA20 H1; DCA 180s; lặp có; chờ 10s |
|  | N264 | C | 98.10 | 20.20 | 16371.40 | 12663.10 | 0.25 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(10.0; 1.15×ATR) × 40; TP tỉa 1.5; clear 2.0×ATR trail 40; HV 8; xóa 1/3; SMA50 H1; DCA 60s; lặp không; chờ 10s |
|  | N305 | C | 55.00 | 54.60 | 6789.40 | 6845.80 | 0.25 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(1.5; 2.0×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 6; xóa tat/6; SMA50 H1; DCA 60s; lặp có; chờ 10s |
|  | V0.21 mặc định (lot đều) | C | 51.40 | 50.00 | 4196.80 | 5987.10 | 0.24 |  |  |  |  | lot 0.01 ×1.0 trần 0.5; tầng max(6.0; 1.15×ATR) × 40; TP tỉa 1.0; clear 1.0×ATR trail 60; HV 4; xóa 4/3; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N331 | C | 51.20 | 51.20 | 3820.30 | 4770.30 | 0.21 |  |  |  |  | lot 0.01 ×1.15 trần 0.03; tầng max(8.0; 1.15×ATR) × 12; TP tỉa 0.5; clear 1.5×ATR trail 40; HV 0; xóa 1/6; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N114 | C | 83.60 | 48.10 | 4922.60 | 4599.90 | 0.20 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(20.0; 4.0×ATR) × 40; TP tỉa 0.75; clear 1.5×ATR trail 40; HV 12; xóa 1/6; SMA100 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N155 | C | 64.90 | 60.50 | 5870.10 | 6297.80 | 0.19 |  |  |  |  | lot 0.01 ×1.0 trần 0.05; tầng max(15.0; 0.5×ATR) × 40; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 0; xóa 6/2; SMA20 H1 lọc M5; DCA 60s; lặp có; chờ 60s |
|  | N268 | C | 92.60 | 88.20 | 8245.90 | 8245.90 | 0.19 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(12.0; 2.0×ATR) × 16; TP tỉa 1.5; clear 1.5×ATR trail tat; HV 6; xóa 2/3; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N353 | C | 50.80 | 11.20 | 5335.50 | 4315.80 | 0.19 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(10.0; 4.0×ATR) × 12; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 0; xóa 1/4; SMA100 H1; DCA 60s; lặp có; chờ 10s |
|  | N256 | C | 54.10 | 54.10 | 6470.70 | 4992.30 | 0.18 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(1.5; 1.15×ATR) × 16; TP tỉa 1.0; clear 2.0×ATR trail 80; HV 6; xóa 6/3; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N322 | C | 73.50 | 73.50 | 7415.20 | 6710.50 | 0.18 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(20.0; 1.5×ATR) × 30; TP tỉa 2.0; clear 1.0×ATR trail 80; HV 12; xóa 2/3; SMA50 H1; DCA 60s; lặp có; chờ 10s |
|  | N261 | C | 60.90 | 57.30 | 5289.60 | 4926.80 | 0.17 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(4.5; 4.0×ATR) × 12; TP tỉa 0.5; clear 1.5×ATR trail tat; HV 0; xóa 6/3; SMA50 H1 lọc M5; DCA 20s; lặp có; chờ 10s |
|  | N174 | C | 60.70 | 26.50 | 8971.30 | 4213.40 | 0.16 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(8.0; 0.8×ATR) × 40; TP tỉa 2.0; clear 1.5×ATR trail tat; HV 3; xóa tat/2; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N178 | C | 96.20 | 88.20 | 7060.80 | 7410.60 | 0.16 |  |  |  |  | lot 0.01 ×1.3 trần 0.05; tầng max(3.0; 3.0×ATR) × 20; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 6; xóa 1/3; SMA50 H1; DCA 60s; lặp có; chờ 60s |
|  | N147 | C | 75.00 | 67.30 | 6987.60 | 5527.20 | 0.15 |  |  |  |  | lot 0.01 ×1.3 trần 0.02; tầng max(4.5; 2.0×ATR) × 30; TP tỉa 0.75; clear 0.5×ATR trail tat; HV 6; xóa 6/4; SMA50 H1; DCA 60s; lặp có; chờ 10s |
|  | N098 | C | 93.00 | 24.60 | 7109.20 | 6554.10 | 0.14 |  |  |  |  | lot 0.01 ×1.3 trần 0.5; tầng max(1.5; 4.0×ATR) × 16; TP tỉa 2.0; clear 2.0×ATR trail tat; HV 12; xóa 6/3; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N118 | C | 92.30 | 86.80 | 5925.20 | 5925.20 | 0.14 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(20.0; 3.0×ATR) × 20; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 3; xóa 4/2; SMA20 H1; DCA 20s; lặp có; chờ 60s |
|  | N173 | C | 56.80 | 42.50 | 2287.50 | 3620.50 | 0.14 |  |  |  |  | lot 0.01 ×1.05 trần 0.02; tầng max(6.0; 2.0×ATR) × 30; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 2; xóa 2/3; SMA100 H1; DCA 20s; lặp không; chờ 10s |
|  | N084 | C | 56.40 | 38.40 | 2541.30 | 3327.20 | 0.13 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(3.0; 3.0×ATR) × 20; TP tỉa 1.0; clear 0.5×ATR trail 60; HV 4; xóa 6/6; SMA20 H1 lọc M5; DCA 60s; lặp có; chờ 10s |
|  | N042 | C | 84.40 | 84.10 | 4907.10 | 4693.10 | 0.12 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(20.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 40; HV 6; xóa 4/4; SMA100 H1; DCA 20s; lặp có; chờ 10s |
|  | N185 | C | 50.80 | 50.70 | 4118.50 | 2651.80 | 0.12 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(25.0; 4.0×ATR) × 20; TP tỉa 2.0; clear 1.5×ATR trail 40; HV 0; xóa 1/3; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 10s |
|  | N179 | C | 90.60 | 90.60 | 5318.00 | 4653.40 | 0.11 |  |  |  |  | lot 0.01 ×1.05 trần 0.1; tầng max(25.0; 1.15×ATR) × 30; TP tỉa 1.0; clear 2.0×ATR trail 60; HV 12; xóa 4/6; SMA20 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N006 | C | 52.00 | 51.90 | 2437.70 | 2496.40 | 0.10 |  |  |  |  | lot 0.01 ×1.0 trần 0.05; tầng max(12.0; 2.0×ATR) × 40; TP tỉa 0.75; clear 3.0×ATR trail tat; HV 6; xóa 6/6; SMA100 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N115 | C | 62.70 | 61.60 | 3137.60 | 3137.60 | 0.10 |  |  |  |  | lot 0.01 ×1.2 trần 0.05; tầng max(4.5; 4.0×ATR) × 16; TP tỉa 0.75; clear 1.0×ATR trail tat; HV 4; xóa 6/6; SMA50 H1 lọc M5; DCA 180s; lặp có; chờ 60s |
|  | N175 | C | 51.50 | 36.00 | 2195.40 | 2195.40 | 0.10 |  |  |  |  | lot 0.01 ×1.1 trần 0.03; tầng max(20.0; 1.15×ATR) × 40; TP tỉa 1.0; clear 1.5×ATR trail 80; HV 6; xóa 1/6; SMA50 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N196 | C | 56.00 | 45.10 | 7717.90 | 2433.60 | 0.10 |  |  |  |  | lot 0.01 ×1.2 trần 0.02; tầng max(3.0; 0.8×ATR) × 40; TP tỉa 1.5; clear 2.0×ATR trail 60; HV 3; xóa tat/2; SMA100 H1 lọc M5; DCA 60s; lặp không; chờ 60s |
|  | N227 | C | 61.10 | 61.00 | 2910.90 | 2910.90 | 0.10 |  |  |  |  | lot 0.01 bảng Hydra trần 0.5; tầng max(6.0; 4.0×ATR) × 16; TP tỉa 1.5; clear 2.0×ATR trail tat; HV 6; xóa 0/3; SMA20 H1 lọc M5; DCA 180s; lặp có; chờ 10s |
|  | N262 | C | 94.70 | 94.60 | 3684.70 | 4897.80 | 0.10 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(15.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 0.5×ATR trail 60; HV 8; xóa 1/6; SMA20 H1; DCA 60s; lặp có; chờ 10s |
|  | N113 | C | 96.70 | 81.10 | 4197.20 | 4197.20 | 0.09 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(1.5; 2.0×ATR) × 40; TP tỉa 1.5; clear 1.0×ATR trail 80; HV 4; xóa 0/6; SMA100 H1; DCA 180s; lặp có; chờ 60s |
|  | N156 | C | 78.60 | 78.60 | 3645.30 | 3645.30 | 0.09 |  |  |  |  | lot 0.01 ×1.05 trần 0.2; tầng max(3.0; 2.0×ATR) × 30; TP tỉa 1.5; clear 1.5×ATR trail 60; HV 8; xóa 1/4; SMA100 H1 lọc M5; DCA 20s; lặp có; chờ 60s |
|  | N197 | C | 58.20 | 55.30 | 2665.60 | 2125.90 | 0.09 |  |  |  |  | lot 0.01 ×1.1 trần 0.1; tầng max(10.0; 4.0×ATR) × 20; TP tỉa 0.75; clear 1.0×ATR trail 60; HV 3; xóa 2/4; SMA50 H1; DCA 60s; lặp có; chờ 60s |
|  | N028 | C | 87.70 | 66.00 | 2350.20 | 2350.20 | 0.07 |  |  |  |  | lot 0.01 ×1.2 trần 0.1; tầng max(6.0; 0.5×ATR) × 16; TP tỉa 0.75; clear 0.5×ATR trail 80; HV 6; xóa 6/4; SMA20 H1; DCA 20s; lặp không; chờ 60s |
|  | N333 | C | 57.50 | 57.50 | 2012.60 | 1512.20 | 0.06 |  |  |  |  | lot 0.01 ×1.1 trần 0.2; tầng max(15.0; 4.0×ATR) × 20; TP tỉa 1.5; clear 0.5×ATR trail 60; HV 6; xóa 4/3; SMA20 H1; DCA 60s; lặp không; chờ 60s |
|  | N345 | C | 75.80 | 61.80 | 1545.50 | 1787.10 | 0.05 |  |  |  |  | lot 0.01 bảng Hydra trần 0.02; tầng max(6.0; 3.0×ATR) × 40; TP tỉa 2.0; clear 0.5×ATR trail tat; HV 2; xóa 2/2; SMA20 H1 lọc M5; DCA 180s; lặp không; chờ 10s |
|  | N059 | C | 73.50 | 73.50 | 1029.40 | 1438.10 | 0.04 |  |  |  |  | lot 0.01 ×1.05 trần 0.03; tầng max(8.0; 4.0×ATR) × 30; TP tỉa 0.75; clear 3.0×ATR trail 80; HV 0; xóa 0/3; SMA100 H1; DCA 180s; lặp có; chờ 10s |
|  | N166 | C | 52.90 | 50.70 | 588.90 | 606.70 | 0.02 |  |  |  |  | lot 0.01 ×1.15 trần 0.05; tầng max(25.0; 2.0×ATR) × 40; TP tỉa 0.5; clear 1.0×ATR trail 60; HV 3; xóa 1/4; SMA20 H1; DCA 180s; lặp không; chờ 60s |
|  | N221 | C | 75.70 | 36.30 | 9238.40 | -5877.20 | -0.20 |  |  |  |  | lot 0.01 ×1.2 trần 0.5; tầng max(20.0; 0.5×ATR) × 16; TP tỉa 0.75; clear 2.0×ATR trail tat; HV 8; xóa 1/4; SMA100 H1; DCA 180s; lặp không; chờ 10s |

### 2b.2 Số cấu hình bền theo từng input (trong các cấu hình đã xét)

- **InpLotCoSo** — 0.01: bền 223/239
- **InpHeSoLot / InpDungBangLot** — 1.0: bền 24/24; 1.05: bền 30/31; 1.1: bền 28/31; 1.15: bền 31/34; bang: bền 42/45; 1.2: bền 32/35; 1.3: bền 36/39
- **InpLotTangToiDa** — 0.02: bền 44/44; 0.03: bền 31/32; 0.05: bền 39/39; 0.1: bền 38/41; 0.2: bền 39/45; 0.5: bền 32/38
- **InpBuocMinUSD** — 1.5: bền 25/26; 3.0: bền 21/22; 4.5: bền 22/23; 6.0: bền 25/29; 8.0: bền 22/27; 10.0: bền 29/29; 12.0: bền 14/15; 15.0: bền 20/22; 20.0: bền 24/24; 25.0: bền 21/22
- **InpBuocATR** — 0.5: bền 19/20; 0.8: bền 25/25; 1.15: bền 37/41; 1.5: bền 21/22; 2.0: bền 41/45; 3.0: bền 38/40; 4.0: bền 42/46
- **InpSoTangToiDa** — 5: bền 20/20; 8: bền 34/34; 12: bền 32/33; 16: bền 31/31; 20: bền 40/41; 30: bền 36/43; 40: bền 30/37
- **InpTiaTPBuoc** — 0.5: bền 40/44; 0.75: bền 34/35; 1.0: bền 37/44; 1.5: bền 60/62; 2.0: bền 52/54
- **InpGioTPATR** — 0.5: bền 42/44; 1.0: bền 49/56; 1.5: bền 50/50; 2.0: bền 42/45; 3.0: bền 40/44
- **InpTrailClear / InpTrailGiuPT** — tat: bền 66/70; 40: bền 55/59; 60: bền 53/59; 80: bền 49/51
- **InpHoaVonTuTang** — 0: bền 34/34; 2: bền 31/35; 3: bền 33/34; 4: bền 29/32; 6: bền 38/40; 8: bền 29/33; 12: bền 29/31
- **InpXoaTangLo / InpXoaGomLai** — tat: bền 36/37; 0: bền 34/36; 1: bền 40/44; 2: bền 43/44; 4: bền 32/37; 6: bền 38/41
- **InpXoaTuSoTang** — 2: bền 51/55; 3: bền 58/61; 4: bền 56/63; 6: bền 58/60
- **InpChanNguocXH** — True: bền 113/118; False: bền 110/121
- **InpPP0MA** — 20: bền 47/53; 50: bền 60/65; 100: bền 67/72; 200: bền 49/49
- **InpGiayGiuaDCA** — 20: bền 61/69; 60: bền 94/99; 180: bền 68/71
- **InpTiaLapLai** — True: bền 109/123; False: bền 114/116
- **InpGiayChoSauClear** — 10: bền 105/111; 60: bền 118/128

### 2b.3 Láng giềng một bước của các ứng viên bền (đường gốc)

| ten | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N309:lot_max=0.05 | 9185 | 0 | 11.20 | 1.57 | 4023 | 622 | 6.10 | 984 | 1.05 | 12.40 | 167.50 | 9 | 0.33 | 46177.10 | 4559 | 4639 | -36 |
| N309:kieu_lot=1.2 | 7588 | 0 | 7.90 | 1.81 | 1015 | 511 | 5.01 | 826 | 1.04 | 16.90 | 332.30 | 11 | 0.27 | 48048.30 | 3457 | 4363 | -33 |
| N309:lot_max=0.02 | 8347 | 0 | 7.90 | 1.96 | 1292 | 560 | 5.49 | 880 | 0.98 | 13.00 | 332.70 | 9 | 0.18 | 48025.00 | 3579 | 5032 | -30 |
| N309:lot0=0.02 | 15894 | 0 | 12.90 | 2.13 | 1646 | 547 | 5.36 | 861 | 1.00 | 13.10 | 332.50 | 14 | 0.42 | 47527.30 | 7478 | 9133 | -83 |
| N309:buoc_min=8.0 | 8247 | 0 | 9.70 | 1.58 | 822 | 568 | 5.57 | 891 | 1.00 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3761 | 4774 | -31 |
| N309:buoc_atr=4.0 | 7258 | 0 | 6.00 | 2.34 | 2815 | 501 | 4.91 | 720 | 1.41 | 19.60 | 159.20 | 7 | 0.18 | 48390.70 | 3694 | 3773 | -43 |
| N309:buoc_min=12.0 | 8083 | 0 | 9.70 | 1.55 | 658 | 546 | 5.35 | 852 | 1.04 | 13.20 | 332.40 | 9 | 0.24 | 47244.40 | 3720 | 4651 | -31 |
| N309:buoc_atr=2.0 | 11548 | 0 | 13.70 | 1.54 | 621 | 795 | 7.79 | 1437 | 0.87 | 7.60 | 332.50 | 12 | 0.31 | 46430.50 | 4751 | 7239 | -37 |
| N309:tia_tp=1.5 | 9438 | 0 | 8.00 | 2.27 | 4003 | 642 | 6.29 | 1014 | 1.07 | 11.10 | 269.00 | 9 | 0.22 | 47582.80 | 4623 | 5043 | -35 |
| N309:so_tang=30 | 8238 | 0 | 9.70 | 1.58 | 814 | 565 | 5.54 | 887 | 1.02 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3748 | 4779 | -31 |
| N309:tp_atr=1.0 | 8917 | 0 | 8.50 | 2.02 | 3322 | 982 | 9.63 | 1378 | 0.55 | 6.60 | 167.20 | 9 | 0.24 | 47365.30 | 4524 | 4766 | -41 |
| N309:tp_atr=2.0 | 8202 | 0 | 9.40 | 1.61 | 1044 | 397 | 3.89 | 676 | 1.61 | 23.80 | 332.30 | 9 | 0.24 | 47577.20 | 3771 | 4693 | -49 |
| N309:hoa_von_tang=2 | 7451 | 0 | 9.80 | 1.43 | 391 | 599 | 5.87 | 929 | 1.04 | 11.70 | 332.40 | 9 | 0.24 | 47257.90 | 3470 | 4269 | -30 |
| N309:trail=tat | 8029 | 0 | 11.40 | 1.32 | -480 | 585 | 5.74 | 944 | 0.71 | 13.40 | 332.60 | 11 | 0.30 | 46680.50 | 4094 | 4339 | -43 |
| N309:trail=60 | 9130 | 0 | 31.40 | 0.56 | 979 | 660 | 6.47 | 1054 | 0.80 | 10.90 | 332.70 | 18 | 0.42 | 35720.40 | 4170 | 5400 | -62 |
| N309:xoa=2 | 8238 | 0 | 9.70 | 1.58 | 814 | 565 | 5.54 | 887 | 1.02 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3748 | 4779 | -31 |
| N309:xoa=6 | 8238 | 0 | 9.70 | 1.58 | 814 | 565 | 5.54 | 887 | 1.02 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3748 | 4779 | -31 |
| N309:xoa_tu=4 | 8196 | 0 | 9.70 | 1.57 | 772 | 565 | 5.54 | 887 | 1.01 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3759 | 4725 | -31 |
| N309:loc_xh=True | 8460 | 0 | 9.70 | 1.62 | 930 | 569 | 5.58 | 889 | 0.99 | 12.70 | 332.40 | 9 | 0.24 | 47264.00 | 3704 | 5044 | -31 |
| N309:xoa_tu=2 | 8240 | 0 | 9.70 | 1.58 | 815 | 565 | 5.54 | 887 | 1.02 | 12.80 | 332.40 | 9 | 0.24 | 47264.00 | 3748 | 4779 | -31 |
| N309:giay_dca=60 | 8483 | 0 | 9.70 | 1.63 | 946 | 580 | 5.69 | 906 | 0.98 | 12.40 | 332.40 | 9 | 0.24 | 47113.20 | 3673 | 5098 | -31 |
| N309:tia_lap_lai=False | 8389 | 0 | 8.60 | 1.83 | 1140 | 576 | 5.65 | 892 | 1.02 | 12.50 | 332.80 | 9 | 0.24 | 47264.00 | 3617 | 5060 | -31 |
| N309:ma_h1=100 | 6529 | 0 | 71.00 | 0.18 | -58 | 446 | 4.37 | 772 | 1.08 | 19.30 | 336.80 | 29 | 0.79 | 14661.00 | 1725 | 5092 | -29 |
| N309:cho_clear=60 | 7507 | 0 | 9.60 | 1.52 | 552 | 509 | 4.99 | 807 | 1.18 | 13.80 | 332.60 | 9 | 0.24 | 46717.20 | 3537 | 4276 | -51 |
| N094:lot0=0.02 | 14052 | 0 | 22.90 | 1.10 | 5620 | 507 | 4.97 | 988 | 0.63 | 7.20 | 705.90 | 19 | 0.53 | 42876.00 | 6483 | 8159 | -126 |
| N094:kieu_lot=1.05 | 4688 | 0 | 8.30 | 1.08 | 2066 | 348 | 3.41 | 683 | 0.64 | 7.10 | 743.50 | 19 | 0.24 | 48140.40 | 2848 | 2299 | -99 |
| N094:lot_max=0.1 | 10521 | 0 | 10.30 | 1.95 | 3332 | 793 | 7.77 | 1581 | 0.68 | 7.70 | 575.50 | 19 | 0.41 | 47217.10 | 5920 | 4875 | -94 |
| N094:kieu_lot=1.15 | 12119 | 0 | 19.50 | 1.11 | -449 | 789 | 7.74 | 1527 | 0.62 | 7.60 | 326.90 | 19 | 0.61 | 45070.70 | 5383 | 7055 | -52 |
| N094:lot_max=0.5 | 10521 | 0 | 10.30 | 1.95 | 3332 | 793 | 7.77 | 1581 | 0.68 | 7.70 | 575.50 | 19 | 0.41 | 47217.10 | 5920 | 4875 | -94 |
| N094:buoc_min=10.0 | 10855 | 0 | 10.30 | 2.01 | 3505 | 822 | 8.06 | 1691 | 0.65 | 7.00 | 575.50 | 19 | 0.28 | 47305.30 | 6179 | 4998 | -99 |
| N094:buoc_min=15.0 | 9088 | 0 | 11.60 | 1.49 | 2828 | 683 | 6.70 | 1295 | 0.67 | 9.90 | 591.20 | 19 | 0.34 | 46284.70 | 4745 | 4582 | -102 |
| N094:buoc_atr=1.15 | 10721 | 0 | 11.60 | 1.76 | 2744 | 765 | 7.50 | 1637 | 0.68 | 7.40 | 745.30 | 19 | 0.41 | 46516.10 | 5596 | 5399 | -141 |
| N094:so_tang=16 | 9603 | 0 | 12.10 | 1.51 | 2588 | 695 | 6.81 | 1385 | 0.67 | 8.20 | 744.50 | 15 | 0.24 | 46287.50 | 5002 | 4875 | -130 |
| N094:buoc_atr=2.0 | 6202 | 0 | 9.00 | 1.32 | 1442 | 380 | 3.73 | 696 | 0.67 | 9.90 | 868.30 | 19 | 0.26 | 47645.40 | 2380 | 4096 | -26 |
| N094:so_tang=30 | 12260 | 0 | 13.40 | 1.65 | 2985 | 795 | 7.79 | 1602 | 0.63 | 9.40 | 323.60 | 29 | 0.76 | 45940.30 | 5229 | 7305 | -52 |
| N094:tia_tp=1.0 | 4635 | 0 | 14.00 | 0.63 | 814 | 341 | 3.34 | 703 | 0.56 | 8.60 | 743.10 | 19 | 0.29 | 44795.80 | 2405 | 2662 | -109 |
| N094:tia_tp=2.0 | 11191 | 0 | 16.80 | 1.26 | 3591 | 829 | 8.13 | 1622 | 0.66 | 7.30 | 575.60 | 19 | 0.35 | 43965.00 | 6711 | 4796 | -130 |
| N094:tp_atr=2.0 | 9927 | 0 | 11.80 | 1.60 | 3295 | 565 | 5.54 | 1264 | 1.01 | 11.40 | 592.30 | 19 | 0.43 | 46387.70 | 5707 | 4493 | -97 |
| N094:tp_atr=1.0 | 6635 | 0 | 21.50 | 0.59 | 1153 | 604 | 5.92 | 1047 | 0.37 | 4.40 | 893.60 | 19 | 0.28 | 41411.40 | 3387 | 3511 | -171 |
| N094:trail=60 | 8202 | 0 | 13.00 | 1.17 | -410 | 609 | 5.97 | 1235 | 0.73 | 8.70 | 683.20 | 19 | 0.33 | 46698.10 | 4580 | 3856 | -63 |
| N094:hoa_von_tang=2 | 9532 | 0 | 11.60 | 1.56 | 2852 | 959 | 9.40 | 1838 | 0.65 | 6.00 | 591.00 | 19 | 0.41 | 46264.00 | 5222 | 4585 | -86 |
| N094:xoa=tat | 11276 | 0 | 18.10 | 1.18 | -1326 | 776 | 7.61 | 1541 | 0.64 | 8.60 | 327.00 | 19 | 0.44 | 43207.50 | 5290 | 6279 | -75 |
| N094:xoa=1 | 10341 | 0 | 10.30 | 1.91 | 3296 | 789 | 7.74 | 1571 | 0.68 | 8.00 | 575.50 | 19 | 0.39 | 47197.60 | 5885 | 4735 | -94 |
| N094:xoa_tu=3 | 10307 | 0 | 10.30 | 1.91 | 3313 | 776 | 7.61 | 1549 | 0.70 | 8.20 | 575.50 | 19 | 0.41 | 47203.70 | 5792 | 4790 | -88 |
| N094:xoa_tu=6 | 10266 | 0 | 13.10 | 1.47 | -759 | 763 | 7.48 | 1530 | 0.65 | 8.10 | 327.40 | 19 | 0.42 | 46580.50 | 5539 | 5002 | -80 |
| N094:loc_xh=False | 10560 | 0 | 10.30 | 1.95 | 3332 | 794 | 7.78 | 1584 | 0.68 | 7.60 | 575.50 | 19 | 0.41 | 47217.10 | 5920 | 4914 | -94 |
| N094:giay_dca=20 | 10390 | 0 | 11.60 | 1.70 | 3123 | 785 | 7.70 | 1576 | 0.68 | 7.50 | 591.20 | 19 | 0.38 | 46458.40 | 5832 | 4834 | -92 |
| N094:ma_h1=100 | 6674 | 0 | 30.00 | 0.44 | -2097 | 407 | 3.99 | 919 | 0.58 | 13.70 | 683.20 | 19 | 0.52 | 35068.20 | 1632 | 5316 | -24 |
| N094:giay_dca=180 | 10099 | 0 | 15.10 | 1.28 | 2790 | 767 | 7.52 | 1525 | 0.71 | 7.50 | 599.30 | 19 | 0.44 | 44639.10 | 5537 | 4839 | -133 |
| N094:cho_clear=10 | 6470 | 0 | 15.10 | 0.81 | 2418 | 444 | 4.35 | 881 | 0.56 | 7.40 | 893.60 | 19 | 0.31 | 44711.20 | 3139 | 3606 | -113 |
| N094:tia_lap_lai=True | 12038 | 0 | 39.00 | 0.58 | -4287 | 808 | 7.92 | 1707 | 0.63 | 8.40 | 326.90 | 19 | 0.51 | 32169.00 | 5456 | 6856 | -92 |
| N024:lot0=0.02 | 14929 | 0 | 32.80 | 0.84 | 2352 | 948 | 9.29 | 1322 | 0.41 | 5.50 | 693.20 | 18 | 0.39 | 36588.70 | 8776 | 7103 | -319 |
| N024:kieu_lot=1.2 | 7390 | 0 | 15.80 | 0.90 | 1566 | 843 | 8.26 | 1207 | 0.40 | 8.40 | 332.50 | 18 | 0.29 | 43761.90 | 3606 | 4116 | -58 |
| N024:lot_max=0.03 | 8312 | 0 | 7.20 | 2.16 | 912 | 932 | 9.14 | 1307 | 0.41 | 7.00 | 335.90 | 9 | 0.18 | 48560.60 | 4276 | 4564 | -39 |
| N024:lot_max=0.1 | 8575 | 0 | 7.20 | 2.30 | 1468 | 935 | 9.17 | 1310 | 0.41 | 6.90 | 332.30 | 9 | 0.31 | 48242.80 | 4367 | 4651 | -39 |
| N024:buoc_min=10.0 | 8532 | 0 | 7.20 | 2.29 | 1409 | 943 | 9.25 | 1323 | 0.39 | 6.80 | 332.70 | 9 | 0.22 | 48231.20 | 4334 | 4720 | -39 |
| N024:buoc_min=15.0 | 8579 | 0 | 7.20 | 2.30 | 1498 | 909 | 8.91 | 1264 | 0.40 | 7.50 | 332.70 | 10 | 0.22 | 48193.70 | 4245 | 4650 | -46 |
| N024:buoc_atr=2.0 | 13187 | 0 | 8.90 | 2.85 | 5078 | 1485 | 14.56 | 2311 | 0.40 | 4.60 | 158.80 | 12 | 0.30 | 47597.10 | 6770 | 6908 | -69 |
| N024:buoc_atr=4.0 | 6681 | 0 | 11.30 | 1.14 | 1570 | 708 | 6.94 | 933 | 0.43 | 10.30 | 332.10 | 14 | 0.24 | 45881.30 | 3191 | 3719 | -50 |
| N024:so_tang=16 | 8550 | 0 | 7.20 | 2.30 | 1417 | 938 | 9.20 | 1311 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 48242.80 | 4330 | 4722 | -39 |
| N024:so_tang=30 | 8550 | 0 | 7.20 | 2.30 | 1417 | 938 | 9.20 | 1311 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 48242.80 | 4330 | 4722 | -39 |
| N024:tia_tp=0.75 | 7388 | 0 | 11.10 | 1.28 | 1757 | 879 | 8.62 | 1247 | 0.39 | 7.40 | 335.90 | 18 | 0.24 | 46271.80 | 3778 | 4006 | -64 |
| N024:tp_atr=0.5 | 9901 | 0 | 7.10 | 2.66 | 2339 | 1957 | 19.19 | 2400 | 0.11 | 3.10 | 332.10 | 13 | 0.34 | 48373.80 | 4797 | 5563 | -48 |
| N024:tia_tp=1.5 | 9668 | 0 | 9.50 | 1.88 | 1457 | 982 | 9.63 | 1372 | 0.41 | 7.40 | 332.30 | 9 | 0.28 | 47219.00 | 4265 | 5754 | -47 |
| N024:tp_atr=1.5 | 8622 | 0 | 7.10 | 2.35 | 1750 | 643 | 6.30 | 1010 | 0.78 | 10.90 | 332.60 | 9 | 0.22 | 48234.10 | 4152 | 4929 | -63 |
| N024:trail=40 | 8635 | 0 | 7.00 | 2.37 | 3361 | 1007 | 9.87 | 1406 | 0.46 | 6.60 | 167.00 | 9 | 0.22 | 48094.50 | 4386 | 4750 | -36 |
| N024:hoa_von_tang=3 | 8691 | 0 | 7.20 | 2.33 | 1335 | 980 | 9.61 | 1373 | 0.41 | 6.80 | 332.70 | 9 | 0.22 | 48220.70 | 4208 | 4986 | -39 |
| N024:trail=80 | 8366 | 0 | 13.90 | 1.15 | 1574 | 900 | 8.82 | 1273 | 0.37 | 7.10 | 332.70 | 18 | 0.34 | 44940.30 | 4227 | 4597 | -55 |
| N024:hoa_von_tang=6 | 8702 | 0 | 7.20 | 2.34 | 1523 | 936 | 9.18 | 1309 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 48258.50 | 4370 | 4835 | -39 |
| N024:xoa=4 | 8550 | 0 | 7.20 | 2.30 | 1417 | 938 | 9.20 | 1311 | 0.41 | 6.90 | 332.70 | 9 | 0.22 | 48242.80 | 4330 | 4722 | -39 |
| N024:loc_xh=False | 8576 | 0 | 7.20 | 2.30 | 1420 | 940 | 9.22 | 1314 | 0.41 | 6.80 | 332.70 | 9 | 0.22 | 48242.80 | 4334 | 4744 | -39 |
| N024:xoa_tu=4 | 8440 | 0 | 6.80 | 2.39 | 1548 | 929 | 9.11 | 1303 | 0.41 | 7.00 | 332.70 | 9 | 0.23 | 48430.10 | 4282 | 4661 | -39 |
| N024:ma_h1=100 | 6202 | 0 | 60.80 | 0.20 | 13 | 719 | 7.05 | 1049 | 0.39 | 9.90 | 338.90 | 19 | 0.56 | 19797.40 | 1899 | 4806 | -22 |
| N024:giay_dca=60 | 8466 | 0 | 8.20 | 1.98 | 1414 | 931 | 9.13 | 1301 | 0.41 | 7.00 | 332.70 | 9 | 0.24 | 47691.60 | 4332 | 4645 | -39 |
| N024:tia_lap_lai=True | 9098 | 0 | 9.10 | 1.90 | 1368 | 980 | 9.61 | 1387 | 0.39 | 6.80 | 332.30 | 9 | 0.28 | 47218.30 | 4398 | 5034 | -39 |
| N024:cho_clear=60 | 7645 | 0 | 9.00 | 1.59 | 280 | 826 | 8.10 | 1173 | 0.45 | 7.80 | 332.70 | 9 | 0.26 | 48193.60 | 4086 | 4048 | -41 |
| N074:lot0=0.02 | 12886 | 0 | 26.20 | 0.91 | 2193 | 748 | 7.33 | 1516 | 0.43 | 4.60 | 1062.00 | 26 | 1.04 | 40008.30 | 7064 | 7016 | -89 |
| N074:kieu_lot=1.1 | 4488 | 0 | 8.80 | 0.98 | 513 | 573 | 5.62 | 1287 | 0.42 | 7.10 | 1084.20 | 30 | 0.48 | 47331.80 | 3089 | 1889 | -52 |
| N074:kieu_lot=bang | 7987 | 0 | 10.50 | 1.46 | 2039 | 957 | 9.38 | 1989 | 0.42 | 4.80 | 704.60 | 25 | 0.64 | 46613.30 | 3784 | 4879 | -55 |
| N074:lot_max=0.1 | 7692 | 0 | 10.70 | 1.38 | 1949 | 914 | 8.96 | 1902 | 0.43 | 5.00 | 700.50 | 22 | 0.47 | 46543.60 | 3639 | 4668 | -48 |
| N074:lot_max=0.5 | 7676 | 0 | 10.70 | 1.38 | 1933 | 912 | 8.94 | 1901 | 0.43 | 5.00 | 700.50 | 22 | 0.53 | 46543.60 | 3640 | 4650 | -48 |
| N074:buoc_min=3.0 | 7676 | 0 | 10.70 | 1.38 | 1933 | 912 | 8.94 | 1901 | 0.43 | 5.00 | 700.50 | 22 | 0.53 | 46543.60 | 3641 | 4650 | -48 |
| N074:buoc_atr=1.15 | 8308 | 0 | 11.00 | 1.44 | 2076 | 1314 | 12.88 | 2782 | 0.27 | 2.90 | 681.40 | 30 | 0.93 | 46842.00 | 4630 | 4210 | -46 |
| N074:buoc_atr=2.0 | 4951 | 0 | 9.30 | 1.03 | 1510 | 441 | 4.32 | 890 | 0.72 | 8.40 | 336.10 | 18 | 0.33 | 46970.90 | 2248 | 3123 | -34 |
| N074:so_tang=30 | 7676 | 0 | 10.70 | 1.38 | 1933 | 912 | 8.94 | 1901 | 0.43 | 5.00 | 700.50 | 22 | 0.53 | 46543.60 | 3641 | 4650 | -48 |
| N074:tia_tp=0.5 | 3368 | 0 | 7.90 | 0.82 | -264 | 441 | 4.32 | 803 | 0.21 | 3.50 | 1082.10 | 18 | 0.31 | 47855.00 | 1970 | 1565 | -26 |
| N074:tia_tp=1.0 | 9014 | 0 | 12.20 | 1.42 | 2254 | 945 | 9.26 | 2047 | 0.59 | 5.30 | 666.40 | 19 | 0.60 | 45826.60 | 4555 | 5189 | -46 |
| N074:tp_atr=1.5 | 8924 | 0 | 10.70 | 1.60 | 2414 | 1112 | 10.90 | 2265 | 0.41 | 4.20 | 681.40 | 22 | 0.45 | 46626.50 | 3931 | 5101 | -49 |
| N074:tp_atr=3.0 | 8691 | 0 | 10.70 | 1.56 | 1100 | 963 | 9.44 | 2037 | 0.47 | 5.10 | 700.80 | 22 | 0.53 | 46507.70 | 3669 | 5131 | -50 |
| N074:trail=40 | 8674 | 0 | 10.70 | 1.56 | 1098 | 981 | 9.62 | 2059 | 0.45 | 4.90 | 700.80 | 22 | 0.53 | 46505.90 | 3645 | 5137 | -50 |
| N074:hoa_von_tang=0 | 8639 | 0 | 12.20 | 1.36 | 2421 | 617 | 6.05 | 1418 | 0.37 | 12.80 | 700.50 | 31 | 0.81 | 45902.60 | 3589 | 5294 | -49 |
| N074:hoa_von_tang=3 | 7885 | 0 | 12.00 | 1.26 | 1692 | 769 | 7.54 | 1705 | 0.42 | 7.50 | 681.40 | 23 | 0.80 | 45877.60 | 3368 | 5132 | -56 |
| N074:xoa=tat | 10006 | 0 | 11.70 | 1.64 | 1765 | 1199 | 11.75 | 2497 | 0.45 | 4.70 | 332.10 | 18 | 0.47 | 46103.70 | 5121 | 5327 | -69 |
| N074:xoa=1 | 7676 | 0 | 10.70 | 1.38 | 1933 | 912 | 8.94 | 1901 | 0.43 | 5.00 | 700.50 | 22 | 0.53 | 46543.60 | 3641 | 4650 | -48 |
| N074:xoa_tu=2 | 7925 | 0 | 10.70 | 1.42 | 2690 | 956 | 9.37 | 2021 | 0.44 | 5.20 | 666.40 | 22 | 0.53 | 46468.20 | 3812 | 4728 | -52 |
| N074:xoa_tu=4 | 8429 | 0 | 10.70 | 1.51 | 2193 | 949 | 9.30 | 1970 | 0.42 | 5.10 | 700.50 | 22 | 0.54 | 46535.80 | 3741 | 5106 | -49 |
| N074:loc_xh=False | 7603 | 0 | 10.70 | 1.36 | 1872 | 904 | 8.86 | 1884 | 0.43 | 5.10 | 700.50 | 22 | 0.53 | 46543.60 | 3580 | 4638 | -49 |
| N074:ma_h1=100 | 6840 | 0 | 71.70 | 0.19 | 640 | 822 | 8.06 | 1766 | 0.43 | 5.00 | 700.50 | 39 | 1.26 | 14311.00 | 2280 | 5175 | -50 |
| N074:giay_dca=20 | 8225 | 0 | 14.70 | 1.07 | 1953 | 918 | 9.00 | 1920 | 0.42 | 5.10 | 700.50 | 22 | 0.57 | 44419.30 | 3620 | 4713 | -48 |
| N074:giay_dca=180 | 7887 | 0 | 7.00 | 2.17 | 2184 | 964 | 9.45 | 1990 | 0.45 | 5.40 | 681.40 | 22 | 0.45 | 48446.80 | 3814 | 4434 | -36 |
| N074:tia_lap_lai=True | 13429 | 0 | 15.00 | 1.70 | 5576 | 1462 | 14.33 | 3552 | 0.42 | 4.30 | 167.40 | 21 | 1.01 | 44790.10 | 6310 | 7122 | -56 |
| N074:cho_clear=10 | 5545 | 0 | 19.80 | 0.54 | 2115 | 659 | 6.46 | 1456 | 0.43 | 5.00 | 765.10 | 34 | 0.88 | 41795.80 | 2284 | 3771 | -28 |
| N343:lot0=0.02 | 20224 | 0 | 22.50 | 1.53 | -223 | 2113 | 20.72 | 2931 | 0.20 | 2.60 | 326.90 | 19 | 0.97 | 45502.40 | 9012 | 12493 | -109 |
| N343:kieu_lot=1.15 | 10750 | 0 | 12.10 | 1.63 | 4032 | 2269 | 22.25 | 3149 | 0.20 | 2.70 | 158.90 | 19 | 0.70 | 47744.60 | 5101 | 6205 | -59 |
| N343:kieu_lot=1.2 | 9983 | 0 | 15.60 | 1.18 | 622 | 2056 | 20.16 | 2844 | 0.20 | 2.80 | 323.60 | 19 | 0.86 | 45795.60 | 4355 | 6151 | -54 |
| N343:lot_max=0.05 | 9780 | 0 | 11.10 | 1.62 | 117 | 2056 | 20.16 | 2844 | 0.20 | 2.80 | 326.90 | 19 | 0.47 | 48207.60 | 4354 | 6008 | -54 |
| N343:lot_max=0.2 | 10709 | 0 | 12.70 | 1.56 | 3994 | 2266 | 22.22 | 3148 | 0.20 | 2.70 | 158.90 | 19 | 0.92 | 47383.30 | 5125 | 6166 | -59 |
| N343:buoc_min=6.0 | 9902 | 0 | 11.80 | 1.55 | 785 | 2082 | 20.41 | 2900 | 0.20 | 2.70 | 323.60 | 19 | 0.67 | 47895.60 | 4398 | 6085 | -55 |
| N343:buoc_min=10.0 | 10039 | 0 | 11.80 | 1.57 | 959 | 1986 | 19.47 | 2731 | 0.20 | 3.00 | 323.60 | 19 | 0.67 | 47863.80 | 4348 | 6110 | -51 |
| N343:buoc_atr=1.5 | 14734 | 0 | 7.50 | 3.48 | 4881 | 2888 | 28.31 | 4307 | 0.19 | 1.90 | 167.60 | 19 | 0.61 | 48507.60 | 6341 | 9000 | -58 |
| N343:buoc_atr=3.0 | 6912 | 0 | 14.40 | 0.93 | 322 | 1548 | 15.18 | 1953 | 0.19 | 3.70 | 332.30 | 16 | 0.29 | 44245.70 | 3135 | 4124 | -53 |
| N343:so_tang=16 | 8619 | 0 | 13.60 | 1.17 | -801 | 1778 | 17.43 | 2459 | 0.21 | 2.80 | 623.50 | 15 | 0.34 | 46869.60 | 4303 | 4898 | -51 |
| N343:so_tang=30 | 9942 | 0 | 14.80 | 1.24 | 677 | 2064 | 20.24 | 2862 | 0.20 | 2.80 | 323.60 | 27 | 0.75 | 46251.00 | 4354 | 6170 | -54 |
| N343:tia_tp=1.5 | 10593 | 0 | 8.10 | 2.39 | 4144 | 2212 | 21.69 | 3084 | 0.20 | 2.70 | 158.90 | 19 | 0.60 | 48233.20 | 5292 | 5936 | -56 |
| N343:tp_atr=1.0 | 9672 | 0 | 11.10 | 1.60 | 1110 | 1034 | 10.14 | 1699 | 0.57 | 5.60 | 332.40 | 12 | 0.29 | 48206.90 | 4044 | 6114 | -50 |
| N343:trail=tat | 10368 | 0 | 17.50 | 1.13 | 1877 | 2259 | 22.15 | 3106 | 0.10 | 2.50 | 323.60 | 19 | 0.64 | 43320.90 | 4851 | 6027 | -63 |
| N343:trail=60 | 11168 | 0 | 13.30 | 1.52 | 1890 | 2144 | 21.02 | 2956 | 0.14 | 2.70 | 323.60 | 19 | 0.64 | 47179.50 | 4903 | 6839 | -59 |
| N343:hoa_von_tang=4 | 9748 | 0 | 11.80 | 1.53 | 693 | 2069 | 20.28 | 2866 | 0.20 | 2.70 | 323.60 | 19 | 0.67 | 47781.30 | 4271 | 6059 | -49 |
| N343:hoa_von_tang=8 | 9930 | 0 | 11.80 | 1.56 | 838 | 2084 | 20.43 | 2873 | 0.20 | 2.70 | 323.60 | 19 | 0.67 | 47911.20 | 4340 | 6172 | -54 |
| N343:xoa=2 | 9899 | 0 | 11.80 | 1.55 | 800 | 2064 | 20.24 | 2854 | 0.20 | 2.80 | 323.60 | 19 | 0.67 | 47873.20 | 4354 | 6127 | -54 |
| N343:xoa=6 | 9899 | 0 | 11.80 | 1.55 | 800 | 2064 | 20.24 | 2854 | 0.20 | 2.80 | 323.60 | 19 | 0.67 | 47873.20 | 4354 | 6127 | -54 |
| N343:xoa_tu=3 | 9789 | 0 | 11.80 | 1.53 | 798 | 2052 | 20.12 | 2833 | 0.20 | 2.80 | 323.60 | 19 | 0.67 | 47873.20 | 4354 | 6018 | -54 |
| N343:loc_xh=True | 9876 | 0 | 11.80 | 1.55 | 785 | 2054 | 20.14 | 2842 | 0.20 | 2.80 | 323.60 | 19 | 0.67 | 47898.30 | 4297 | 6161 | -54 |
| N343:ma_h1=100 | 9552 | 0 | 11.70 | 1.50 | 331 | 2068 | 20.27 | 2871 | 0.19 | 2.80 | 323.60 | 19 | 0.67 | 48279.30 | 4064 | 6069 | -53 |
| N343:giay_dca=60 | 10013 | 0 | 11.80 | 1.57 | 832 | 2109 | 20.68 | 2920 | 0.20 | 2.60 | 323.60 | 19 | 0.67 | 47902.40 | 4460 | 6135 | -50 |
| N343:tia_lap_lai=True | 10628 | 0 | 15.50 | 1.26 | 4129 | 2246 | 22.02 | 3153 | 0.20 | 2.70 | 189.00 | 19 | 0.82 | 45854.70 | 4941 | 6173 | -56 |
| N343:cho_clear=10 | 11410 | 0 | 11.20 | 1.85 | 2766 | 2450 | 24.02 | 3335 | 0.17 | 2.60 | 323.10 | 19 | 0.55 | 48315.30 | 5269 | 6684 | -50 |
| N188:lot0=0.02 | 72593 | 0 | 55.20 | 2.11 | 25062 | 10043 | 98.46 | 22871 | 0.06 | 0.60 | 53.80 | 29 | 2.15 | 27936.70 | 35347 | 40016 | -450 |
| N188:lot_max=0.05 | 34649 | 0 | 20.20 | 3.07 | 11639 | 9795 | 96.03 | 22700 | 0.06 | 0.60 | 54.50 | 29 | 0.98 | 44638.40 | 17549 | 18744 | -214 |
| N188:kieu_lot=1.2 | 32615 | 0 | 17.90 | 3.13 | 12109 | 9081 | 89.03 | 22159 | 0.06 | 0.70 | 73.60 | 29 | 1.47 | 47657.10 | 15454 | 17170 | -179 |
| N188:lot_max=0.2 | 38299 | 0 | 31.90 | 2.03 | 13942 | 10284 | 100.82 | 22887 | 0.06 | 0.60 | 53.50 | 29 | 2.95 | 40227.80 | 18322 | 19985 | -208 |
| N188:buoc_min=3.0 | 35250 | 0 | 30.40 | 2.05 | 10776 | 12287 | 120.46 | 28842 | 0.05 | 0.50 | 54.40 | 29 | 2.22 | 39409.50 | 19190 | 20353 | -239 |
| N188:buoc_min=6.0 | 34382 | 0 | 30.90 | 2.00 | 12540 | 8254 | 80.92 | 17816 | 0.07 | 0.80 | 53.80 | 29 | 1.22 | 38350.00 | 15942 | 18448 | -165 |
| N188:buoc_atr=0.8 | 30647 | 0 | 31.80 | 1.75 | 11861 | 7413 | 72.68 | 15773 | 0.09 | 0.90 | 73.60 | 29 | 1.72 | 37615.40 | 14599 | 16057 | -107 |
| N188:so_tang=20 | 34213 | 0 | 28.40 | 2.15 | 10916 | 9940 | 97.45 | 22209 | 0.06 | 0.60 | 54.70 | 19 | 1.42 | 40079.40 | 18029 | 18853 | -210 |
| N188:so_tang=40 | 37711 | 0 | 30.70 | 2.19 | 13722 | 10150 | 99.51 | 22762 | 0.06 | 0.60 | 54.10 | 39 | 1.72 | 38850.10 | 18094 | 19626 | -181 |
| N188:trail=60 | 36265 | 0 | 13.40 | 4.15 | 13120 | 10110 | 99.12 | 22626 | 0.06 | 0.60 | 53.80 | 29 | 1.82 | 49183.90 | 16950 | 19323 | -169 |
| N188:tia_tp=0.75 | 42621 | 0 | 59.40 | 1.27 | 15473 | 9033 | 88.56 | 19353 | 0.09 | 0.70 | 54.10 | 29 | 1.82 | 23033.20 | 20094 | 22536 | -203 |
| N188:tp_atr=1.0 | 38132 | 0 | 30.70 | 2.22 | 13928 | 8403 | 82.38 | 21579 | 0.06 | 0.80 | 73.70 | 29 | 1.92 | 38823.40 | 18122 | 20021 | -254 |
| N188:hoa_von_tang=3 | 35404 | 0 | 30.90 | 2.06 | 13042 | 10281 | 100.79 | 22912 | 0.06 | 0.60 | 54.10 | 29 | 1.72 | 38449.40 | 16950 | 18463 | -179 |
| N188:hoa_von_tang=6 | 39664 | 0 | 47.40 | 1.49 | 14775 | 9941 | 97.46 | 22646 | 0.06 | 0.60 | 54.10 | 29 | 1.72 | 29607.80 | 19091 | 20583 | -250 |
| N188:xoa_tu=3 | 37478 | 0 | 30.70 | 2.18 | 13720 | 10095 | 98.97 | 22704 | 0.06 | 0.60 | 54.10 | 29 | 1.72 | 38850.10 | 18110 | 19377 | -256 |
| N188:xoa=0 | -22831 | 1 | 100.10 | -0.41 | -44970 | 9563 | 93.75 | 22460 | 0.06 | 0.60 | 58.90 | 29 | 1.77 | -7948.50 | -38962 | 16900 | -209 |
| N188:xoa_tu=6 | 37478 | 0 | 30.70 | 2.18 | 13720 | 10095 | 98.97 | 22704 | 0.06 | 0.60 | 54.10 | 29 | 1.72 | 38850.10 | 18110 | 19377 | -256 |
| N188:loc_xh=False | 38123 | 0 | 30.70 | 2.22 | 13871 | 10249 | 100.48 | 23000 | 0.06 | 0.60 | 54.10 | 29 | 1.72 | 38874.30 | 18435 | 19697 | -256 |
| N188:ma_h1=20 | 38330 | 0 | 24.60 | 2.63 | 14147 | 10279 | 100.77 | 22930 | 0.06 | 0.60 | 54.10 | 29 | 1.77 | 44586.10 | 18276 | 20063 | -69 |
| N188:ma_h1=100 | 37319 | 0 | 30.90 | 2.17 | 13738 | 10053 | 98.56 | 22482 | 0.06 | 0.60 | 54.10 | 29 | 1.78 | 38475.90 | 18780 | 18538 | -195 |
| N188:giay_dca=20 | 39105 | 0 | 26.00 | 2.28 | 14136 | 10385 | 101.81 | 23961 | 0.06 | 0.60 | 73.70 | 29 | 2.04 | 48848.60 | 18716 | 20397 | -319 |
| N188:giay_dca=180 | 30420 | 0 | 20.40 | 2.48 | 10333 | 9243 | 90.62 | 19123 | 0.06 | 0.70 | 54.30 | 29 | 1.53 | 47070.00 | 15197 | 17324 | -147 |
| N188:tia_lap_lai=False | 15531 | 0 | 77.90 | 0.39 | 545 | 4847 | 47.52 | 9393 | 0.06 | 0.90 | 670.80 | 29 | 0.86 | 11393.70 | 7329 | 9575 | -108 |
| N188:cho_clear=10 | 41218 | 0 | 51.10 | 1.43 | 14981 | 10699 | 104.89 | 25336 | 0.06 | 0.60 | 53.80 | 29 | 1.72 | 27663.40 | 19074 | 22152 | -192 |
| N171:lot0=0.02 | -14906 | 1 | 100.00 | -0.30 | -39252 | 5350 | 52.45 | 14703 | 0.08 | 1.00 | 426.20 | 39 | 2.53 | -13298.60 | 16274 | -28952 | -146 |
| N171:kieu_lot=bang | 20634 | 0 | 20.80 | 1.47 | 8226 | 6355 | 62.30 | 16514 | 0.08 | 1.00 | 155.40 | 39 | 1.86 | 44525.90 | 9312 | 11337 | -76 |
| N171:kieu_lot=1.1 | 18068 | 0 | 24.00 | 1.41 | 6762 | 5509 | 54.01 | 15720 | 0.08 | 1.10 | 133.90 | 39 | 1.74 | 40390.60 | 8025 | 10057 | -57 |
| N171:lot_max=0.05 | -34025 | 1 | 104.40 | -0.65 | -46445 | 5133 | 50.32 | 14073 | 0.08 | 1.00 | 555.20 | 39 | 1.31 | -8937.80 | 7668 | -41679 | -94 |
| N171:lot_max=0.2 | 21431 | 0 | 20.00 | 1.98 | 8381 | 6655 | 65.25 | 17058 | 0.08 | 1.00 | 110.20 | 39 | 2.70 | 43164.80 | 9852 | 11594 | -100 |
| N171:buoc_min=3.0 | 21223 | 0 | 24.40 | 1.28 | 8149 | 6376 | 62.51 | 16540 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44048.50 | 9755 | 11479 | -94 |
| N171:buoc_atr=0.5 | -77746 | 2 | 100.10 | -1.55 | -94212 | 10676 | 104.67 | 28317 | 0.04 | 0.40 | 387.10 | 39 | 2.27 | -67173.40 | 11239 | -87757 | -59 |
| N171:buoc_atr=1.15 | 15413 | 0 | 73.30 | 0.40 | 6136 | 3308 | 32.43 | 8880 | 0.14 | 1.90 | 151.20 | 39 | 2.22 | 13932.20 | 6061 | 9363 | -48 |
| N171:so_tang=30 | 21374 | 0 | 19.00 | 1.65 | 8327 | 6606 | 64.76 | 16927 | 0.08 | 1.00 | 110.20 | 29 | 1.41 | 44135.10 | 9822 | 11568 | -88 |
| N171:tia_tp=0.75 | 23890 | 0 | 22.90 | 1.92 | 9734 | 5343 | 52.38 | 13430 | 0.14 | 1.20 | 81.10 | 37 | 1.72 | 41808.30 | 10930 | 12970 | -72 |
| N171:tp_atr=1.5 | 21354 | 0 | 24.30 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44135.10 | 9822 | 11547 | -88 |
| N171:tp_atr=3.0 | 21354 | 0 | 24.30 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44135.10 | 9822 | 11547 | -88 |
| N171:trail=40 | 21354 | 0 | 24.30 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44135.10 | 9822 | 11547 | -88 |
| N171:hoa_von_tang=0 | 24690 | 0 | 34.70 | 1.30 | 9874 | 5440 | 53.33 | 16086 | 0.08 | 1.40 | 95.70 | 34 | 1.90 | 35633.60 | 11159 | 13545 | -88 |
| N171:hoa_von_tang=3 | 21872 | 0 | 30.80 | 1.31 | 9134 | 6089 | 59.70 | 16401 | 0.08 | 1.10 | 110.20 | 35 | 1.77 | 37489.00 | 9935 | 11952 | -62 |
| N171:xoa=1 | 21354 | 0 | 24.30 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44135.10 | 9822 | 11547 | -88 |
| N171:xoa_tu=3 | 22058 | 0 | 24.10 | 1.33 | 9102 | 6346 | 62.22 | 16944 | 0.08 | 1.10 | 110.10 | 39 | 2.04 | 44204.10 | 10238 | 11837 | -81 |
| N171:xoa=4 | 21354 | 0 | 24.30 | 1.29 | 8307 | 6606 | 64.76 | 17078 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44135.10 | 9822 | 11547 | -88 |
| N171:loc_xh=True | 21283 | 0 | 24.30 | 1.28 | 8329 | 6577 | 64.48 | 16959 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44192.00 | 9850 | 11448 | -88 |
| N171:ma_h1=50 | 20683 | 0 | 24.50 | 1.25 | 7904 | 6397 | 62.72 | 16719 | 0.08 | 1.00 | 110.20 | 39 | 2.04 | 44079.40 | 9448 | 11250 | -91 |
| N171:giay_dca=180 | 19987 | 0 | 24.90 | 1.60 | 7398 | 6030 | 59.12 | 14609 | 0.08 | 1.00 | 136.40 | 39 | 2.18 | 37565.70 | 9009 | 10989 | -66 |
| N171:giay_dca=20 | -30700 | 1 | 100.00 | -0.61 | -44014 | 5521 | 54.13 | 14921 | 0.08 | 0.90 | 557.30 | 39 | 2.31 | -12421.70 | 8350 | -39036 | -67 |
| N171:tia_lap_lai=False | 3505 | 0 | 60.90 | 0.12 | -22527 | 1267 | 12.42 | 2725 | 0.08 | 1.70 | 1901.90 | 39 | 0.80 | 19564.50 | 1944 | 1965 | -25 |
| N171:cho_clear=10 | -30942 | 1 | 100.00 | -0.62 | -43181 | 5446 | 53.39 | 15081 | 0.08 | 1.00 | 556.30 | 39 | 2.17 | -11378.00 | 7988 | -38919 | -59 |
| N044:lot0=0.02 | 11648 | 0 | 30.80 | 0.70 | -712 | 563 | 5.52 | 959 | 0.39 | 5.80 | 323.70 | 28 | 0.56 | 37659.10 | 4373 | 8861 | -65 |
| N044:kieu_lot=1.15 | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 |
| N044:kieu_lot=1.2 | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 |
| N044:lot_max=0.03 | 12609 | 0 | 8.40 | 2.87 | 4673 | 1322 | 12.96 | 2041 | 0.39 | 5.80 | 158.90 | 16 | 0.42 | 47761.40 | 5931 | 6882 | -66 |
| N044:buoc_min=12.0 | 11837 | 0 | 24.30 | 0.88 | -2382 | 1185 | 11.62 | 1935 | 0.39 | 5.70 | 323.60 | 29 | 0.55 | 41856.70 | 5137 | 7089 | -57 |
| N044:buoc_min=20.0 | 10924 | 0 | 23.30 | 0.85 | -2302 | 1022 | 10.02 | 1568 | 0.39 | 6.90 | 323.60 | 28 | 0.53 | 42082.50 | 4451 | 6800 | -48 |
| N044:buoc_atr=3.0 | 8234 | 0 | 29.80 | 0.53 | 633 | 851 | 8.34 | 1217 | 0.38 | 8.30 | 332.70 | 18 | 0.35 | 36591.90 | 3709 | 4778 | -72 |
| N044:buoc_atr=1.5 | 12902 | 0 | 52.10 | 0.47 | -4033 | 1233 | 12.09 | 2194 | 0.40 | 5.30 | 323.60 | 37 | 0.71 | 25260.70 | 5307 | 7849 | -95 |
| N044:so_tang=30 | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 |
| N044:tia_tp=1.0 | 11763 | 0 | 23.00 | 0.93 | -1887 | 1125 | 11.03 | 1912 | 0.38 | 6.40 | 323.60 | 28 | 0.53 | 42395.20 | 4761 | 7285 | -53 |
| N044:tia_tp=2.0 | 13086 | 0 | 7.90 | 3.16 | 5086 | 1300 | 12.75 | 1996 | 0.42 | 5.90 | 159.00 | 11 | 0.19 | 48141.70 | 6445 | 6926 | -69 |
| N044:tp_atr=0.5 | 11907 | 0 | 24.60 | 0.88 | -2883 | 2097 | 20.56 | 2804 | 0.11 | 2.80 | 323.60 | 29 | 0.55 | 41174.50 | 5264 | 6897 | -59 |
| N044:tp_atr=1.5 | 11892 | 0 | 23.80 | 0.91 | -2235 | 759 | 7.44 | 1408 | 0.74 | 9.50 | 323.60 | 28 | 0.53 | 41910.90 | 4796 | 7374 | -47 |
| N044:trail=40 | 10398 | 0 | 21.30 | 0.89 | -2009 | 1102 | 10.80 | 1748 | 0.48 | 5.50 | 323.50 | 26 | 0.49 | 42848.40 | 4545 | 6116 | -49 |
| N044:trail=80 | 15116 | 0 | 8.50 | 3.24 | 5588 | 1380 | 13.53 | 2161 | 0.32 | 5.60 | 160.10 | 13 | 0.25 | 48089.90 | 6888 | 8521 | -67 |
| N044:hoa_von_tang=2 | 12034 | 0 | 7.50 | 3.08 | 4452 | 1474 | 14.45 | 2282 | 0.41 | 5.40 | 75.50 | 12 | 0.19 | 48087.20 | 6201 | 6121 | -74 |
| N044:xoa_tu=3 | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 |
| N044:xoa=0 | 11678 | 0 | 31.70 | 0.70 | 1068 | 1286 | 12.61 | 2028 | 0.39 | 5.80 | 159.00 | 26 | 0.42 | 35742.80 | 5753 | 6162 | -91 |
| N044:xoa_tu=6 | 13030 | 0 | 7.50 | 3.34 | 4889 | 1346 | 13.20 | 2088 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6287 | 6997 | -65 |
| N044:loc_xh=True | 12984 | 0 | 7.50 | 3.33 | 4889 | 1345 | 13.19 | 2087 | 0.40 | 5.60 | 159.00 | 16 | 0.31 | 48248.60 | 6278 | 6960 | -65 |
| N044:ma_h1=100 | -39131 | 1 | 100.00 | -0.78 | -46712 | 1025 | 10.05 | 1726 | 0.36 | 8.90 | 490.90 | 39 | 0.71 | -3564.00 | 3966 | -42843 | -45 |
| N044:giay_dca=60 | 12853 | 0 | 7.90 | 3.11 | 4844 | 1341 | 13.15 | 2066 | 0.39 | 5.60 | 159.00 | 12 | 0.23 | 48026.00 | 6115 | 6992 | -65 |
| N044:tia_lap_lai=False | 11533 | 0 | 10.60 | 1.97 | 1150 | 1137 | 11.15 | 1768 | 0.41 | 5.80 | 311.70 | 34 | 0.29 | 48283.70 | 4916 | 6882 | -58 |
| N044:cho_clear=60 | 10912 | 0 | 24.20 | 0.82 | -2584 | 1055 | 10.34 | 1698 | 0.42 | 6.20 | 323.60 | 29 | 0.55 | 41506.90 | 4516 | 6662 | -58 |
| N029:lot0=0.02 | 32607 | 0 | 41.00 | 1.20 | -3635 | 1807 | 17.72 | 4337 | 0.32 | 2.40 | 640.60 | 19 | 0.82 | 39283.70 | 13579 | 19936 | -127 |
| N029:kieu_lot=1.1 | 19307 | 0 | 13.40 | 2.52 | 6718 | 2202 | 21.59 | 5347 | 0.36 | 2.60 | 159.10 | 19 | 0.53 | 49260.20 | 8137 | 11450 | -66 |
| N029:kieu_lot=bang | 21085 | 0 | 15.70 | 2.32 | 7234 | 2387 | 23.40 | 5563 | 0.34 | 2.40 | 159.00 | 19 | 0.54 | 47100.60 | 8538 | 12901 | -68 |
| N029:lot_max=0.03 | 13977 | 0 | 55.10 | 0.48 | -7567 | 1716 | 16.82 | 3971 | 0.38 | 2.50 | 742.70 | 19 | 0.36 | 23852.70 | 6513 | 7876 | -581 |
| N029:lot_max=0.1 | 22097 | 0 | 15.60 | 2.58 | 7138 | 2524 | 24.75 | 5934 | 0.36 | 2.40 | 74.80 | 19 | 0.71 | 46258.60 | 9409 | 12986 | -81 |
| N029:buoc_min=6.0 | 18897 | 0 | 48.80 | 0.64 | -11404 | 2406 | 23.59 | 5906 | 0.28 | 1.70 | 684.20 | 19 | 0.65 | 30874.20 | 8520 | 10865 | -99 |
| N029:buoc_min=10.0 | 19120 | 0 | 14.70 | 2.39 | 6144 | 1986 | 19.47 | 4532 | 0.41 | 3.10 | 74.40 | 19 | 0.65 | 46559.20 | 8063 | 11416 | -71 |
| N029:so_tang=16 | 21526 | 0 | 14.20 | 2.78 | 6775 | 2476 | 24.27 | 5809 | 0.36 | 2.40 | 74.80 | 15 | 0.46 | 46119.90 | 9079 | 12744 | -81 |
| N029:buoc_atr=0.8 | 13902 | 0 | 59.00 | 0.44 | -5606 | 1627 | 15.95 | 3639 | 0.45 | 2.80 | 597.10 | 19 | 0.48 | 21801.60 | 7246 | 6953 | -561 |
| N029:so_tang=30 | 21801 | 0 | 14.60 | 2.72 | 6954 | 2494 | 24.45 | 5917 | 0.36 | 2.40 | 74.10 | 29 | 0.88 | 45318.00 | 9264 | 12834 | -82 |
| N029:tia_tp=1.0 | 14205 | 0 | 49.40 | 0.54 | -5582 | 2092 | 20.51 | 4711 | 0.27 | 2.20 | 742.40 | 19 | 0.48 | 26911.90 | 7010 | 7520 | -536 |
| N029:tp_atr=1.0 | 22094 | 0 | 16.20 | 2.34 | 7595 | 3004 | 29.45 | 6304 | 0.26 | 1.90 | 159.00 | 19 | 0.57 | 48908.40 | 9309 | 13146 | -73 |
| N029:tia_tp=2.0 | 17671 | 0 | 26.20 | 1.14 | -1802 | 1838 | 18.02 | 4391 | 0.38 | 2.40 | 623.50 | 19 | 0.61 | 43678.30 | 7612 | 10405 | -70 |
| N029:tp_atr=2.0 | 21919 | 0 | 14.60 | 2.73 | 7017 | 2257 | 22.13 | 5571 | 0.38 | 2.80 | 74.80 | 19 | 0.56 | 46823.30 | 9171 | 13094 | -89 |
| N029:trail=40 | 16304 | 0 | 22.90 | 1.23 | -1774 | 1790 | 17.55 | 4238 | 0.35 | 2.40 | 623.50 | 19 | 0.62 | 44726.40 | 6192 | 10411 | -58 |
| N029:trail=80 | 18510 | 0 | 22.20 | 1.39 | 291 | 2011 | 19.72 | 4751 | 0.33 | 2.50 | 623.50 | 19 | 0.62 | 46605.90 | 7729 | 11143 | -77 |
| N029:hoa_von_tang=0 | 23481 | 0 | 25.60 | 1.45 | 514 | 1553 | 15.23 | 4124 | 0.41 | 3.10 | 623.50 | 19 | 0.67 | 47099.90 | 10052 | 13789 | -74 |
| N029:hoa_von_tang=3 | 23820 | 0 | 15.80 | 2.84 | 7853 | 2229 | 21.85 | 5553 | 0.40 | 2.80 | 74.10 | 19 | 0.56 | 44768.50 | 10159 | 13958 | -90 |
| N029:xoa=tat | 22329 | 0 | 16.00 | 2.55 | 7370 | 2527 | 24.77 | 5896 | 0.36 | 2.40 | 74.10 | 19 | 0.62 | 46133.80 | 9134 | 13199 | -84 |
| N029:xoa_tu=3 | 21878 | 0 | 14.60 | 2.73 | 7001 | 2492 | 24.43 | 5870 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 46861.30 | 9348 | 12827 | -81 |
| N029:xoa_tu=6 | 21819 | 0 | 14.60 | 2.73 | 6964 | 2485 | 24.36 | 5849 | 0.36 | 2.40 | 74.10 | 19 | 0.56 | 46885.80 | 9178 | 12938 | -83 |
| N029:xoa=1 | 17946 | 0 | 18.70 | 1.61 | 1080 | 1970 | 19.31 | 4764 | 0.34 | 2.30 | 623.50 | 19 | 0.62 | 46946.30 | 7561 | 10642 | -74 |
| N029:loc_xh=True | 21672 | 0 | 14.60 | 2.71 | 6914 | 2480 | 24.31 | 5829 | 0.36 | 2.40 | 74.80 | 19 | 0.56 | 46795.60 | 9298 | 12671 | -81 |
| N029:ma_h1=100 | 22707 | 0 | 14.40 | 2.84 | 7634 | 2604 | 25.53 | 6066 | 0.36 | 2.50 | 74.80 | 19 | 0.56 | 47676.80 | 10586 | 12418 | -124 |
| N029:tia_lap_lai=False | 15524 | 0 | 12.80 | 2.29 | 5554 | 1734 | 17.00 | 3937 | 0.33 | 2.30 | 611.60 | 19 | 0.51 | 46272.90 | 6202 | 9883 | -80 |
| N029:giay_dca=60 | 18659 | 0 | 22.00 | 1.41 | 116 | 2097 | 20.56 | 5181 | 0.32 | 2.20 | 623.50 | 19 | 0.62 | 47002.30 | 8422 | 10505 | -85 |
| N029:cho_clear=10 | 17927 | 0 | 23.40 | 1.29 | -1113 | 2013 | 19.74 | 4925 | 0.35 | 2.30 | 623.50 | 19 | 0.62 | 45487.20 | 8144 | 10142 | -81 |
| N112:lot0=0.02 | 39960 | 0 | 41.50 | 1.71 | 12772 | 2858 | 28.02 | 4022 | 0.12 | 2.50 | 192.10 | 21 | 2.48 | 29346.40 | 14255 | 26142 | -153 |
| N112:kieu_lot=1.3 | 23256 | 0 | 42.90 | 0.96 | 7577 | 3285 | 32.21 | 4495 | 0.12 | 2.60 | 123.80 | 19 | 2.88 | 28846.40 | 8225 | 15042 | -87 |
| N112:kieu_lot=bang | -32950 | 1 | 100.10 | -0.65 | -45308 | 2577 | 25.26 | 3718 | 0.12 | 3.10 | 269.30 | 30 | 4.21 | -17467.80 | 5739 | -38472 | -58 |
| N112:lot_max=0.2 | 19943 | 0 | 19.70 | 1.81 | 6624 | 3000 | 29.41 | 4166 | 0.12 | 2.70 | 124.00 | 21 | 1.13 | 40949.40 | 7401 | 12758 | -64 |
| N112:buoc_min=15.0 | 24357 | 0 | 45.50 | 1.06 | 7824 | 3561 | 34.91 | 5349 | 0.13 | 2.20 | 123.70 | 27 | 3.10 | 27600.90 | 8964 | 15727 | -71 |
| N112:buoc_min=25.0 | 15584 | 0 | 17.10 | 1.65 | 5100 | 2139 | 20.97 | 2918 | 0.12 | 3.10 | 194.40 | 16 | 0.83 | 43753.80 | 4632 | 11115 | -50 |
| N112:buoc_atr=0.8 | 18624 | 0 | 19.50 | 1.82 | 6036 | 2941 | 28.83 | 4007 | 0.12 | 2.80 | 124.00 | 21 | 1.07 | 40949.40 | 7070 | 11770 | -64 |
| N112:so_tang=30 | 19949 | 0 | 19.70 | 1.81 | 6625 | 3000 | 29.41 | 4164 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7359 | 12806 | -64 |
| N112:tia_tp=1.5 | 19337 | 0 | 21.20 | 1.71 | 6561 | 2887 | 28.30 | 4076 | 0.12 | 2.80 | 124.20 | 21 | 1.22 | 39760.30 | 7162 | 12363 | -71 |
| N112:tp_atr=1.0 | 17936 | 0 | 19.80 | 1.63 | 5815 | 1477 | 14.48 | 2527 | 0.41 | 5.70 | 127.60 | 20 | 1.15 | 41202.40 | 6714 | 11558 | -68 |
| N112:trail=40 | 17278 | 0 | 19.70 | 1.58 | 5789 | 2826 | 27.71 | 3920 | 0.17 | 2.80 | 124.00 | 18 | 1.15 | 40906.00 | 6626 | 10868 | -68 |
| N112:trail=80 | 22001 | 0 | 20.30 | 2.14 | 7406 | 2829 | 27.74 | 4036 | 0.11 | 2.80 | 124.00 | 21 | 1.22 | 40279.50 | 7785 | 14432 | -67 |
| N112:hoa_von_tang=6 | 19862 | 0 | 19.70 | 1.80 | 6594 | 3001 | 29.42 | 4162 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7337 | 12741 | -64 |
| N112:xoa=1 | 19906 | 0 | 19.70 | 1.81 | 6625 | 2998 | 29.39 | 4161 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7353 | 12769 | -64 |
| N112:hoa_von_tang=12 | 20232 | 0 | 19.70 | 1.84 | 6728 | 2993 | 29.34 | 4158 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7386 | 13062 | -64 |
| N112:xoa=4 | 19949 | 0 | 19.70 | 1.81 | 6625 | 3000 | 29.41 | 4164 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7359 | 12806 | -64 |
| N112:xoa_tu=3 | 19856 | 0 | 19.70 | 1.80 | 6597 | 2992 | 29.33 | 4150 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40949.40 | 7369 | 12703 | -64 |
| N112:ma_h1=50 | 20001 | 0 | 19.70 | 1.81 | 6517 | 3008 | 29.49 | 4177 | 0.12 | 2.70 | 124.00 | 21 | 1.22 | 40670.00 | 7015 | 13202 | -65 |
| N112:loc_xh=True | 19800 | 0 | 19.70 | 1.80 | 6575 | 2979 | 29.21 | 4130 | 0.12 | 2.70 | 124.00 | 21 | 1.15 | 40945.50 | 7298 | 12718 | -64 |
| N112:ma_h1=200 | 20113 | 0 | 19.80 | 1.82 | 6522 | 3043 | 29.83 | 4210 | 0.12 | 2.60 | 75.50 | 21 | 1.15 | 42091.30 | 7775 | 12554 | -64 |
| N112:giay_dca=60 | 20404 | 0 | 23.20 | 1.68 | 6716 | 2990 | 29.31 | 4210 | 0.12 | 2.80 | 124.00 | 21 | 1.45 | 40253.60 | 7530 | 13090 | -63 |
| N112:tia_lap_lai=False | -32648 | 1 | 100.20 | -0.65 | -44958 | 2651 | 25.99 | 3717 | 0.12 | 3.00 | 270.20 | 31 | 4.35 | -9121.10 | 5894 | -38325 | -59 |
| N112:cho_clear=60 | 17799 | 0 | 19.20 | 1.68 | 5951 | 2553 | 25.03 | 3649 | 0.14 | 3.00 | 123.60 | 18 | 1.15 | 42721.40 | 6233 | 11778 | -73 |

### 2b.4 Thông tin: ứng viên trên 16 đường giá DEV nữa (không dùng để chọn)

| ten | so_duong | so_duong_chay | dd_trung_vi | dd_lon_nhat | lai_trung_vi | lai_thap_nhat | lai_ngay_tv | lot_ngay_tv |
|---|---|---|---|---|---|---|---|---|
| U1 | 16 | 0 | 19.25 | 25.70 | 18668.05 | 17242.20 | 183.02 | 0.66 |
| U2 | 16 | 0 | 10.95 | 43.40 | 44917.20 | 44044.20 | 440.37 | 4.45 |
| U3 | 16 | 0 | 22.90 | 48.30 | 13401.05 | 11641.80 | 131.38 | 0.24 |
| U4 | 16 | 0 | 20.15 | 26.40 | 23252.75 | 22679.20 | 227.97 | 0.59 |
| U5 | 16 | 1 | 8.90 | 100.10 | 26265.75 | -41280.90 | 257.50 | 2.96 |

## 3. Tham khảo: hedge V0.22 (không phát hành) trên các ứng viên đầu

`v022` = hedge như V0.22 đã dựng; `sau15_khoa` = hedge từ 15 khoảng tầng, không giảm cấp, khóa DCA sau khi đã hedge.

| ten | hedge | net | chay | dd_pt | net_dd | bo2thang | basket | basket_ngay | so_lenh | gio_tv | gio_p95 | gio_max | sau_max | lot_max | von_thap | buy | sell | swap | co_hd | gio_khoa |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| U1 | sau15_khoa | 4980 | 0 | 7.20 | 1.31 | -88 | 985 | 9.66 | 2222 | 0.35 | 2.30 | 741.20 | 14 | 0.27 | 49195.10 | 602 | 4865 | -140 | 2 | 1951.20 |
| U1 | v022 | 8901 | 0 | 9.70 | 1.65 | 485 | 1178 | 11.55 | 3308 | 0.36 | 2.80 | 972.50 | 19 | 0.40 | 49871.10 | 4859 | 4478 | -132 | 38 | 633.80 |
| U2 | v022 | -3671 | 0 | 20.90 | -0.33 | -5930 | 4927 | 48.30 | 13366 | 0.07 | 0.80 | 160.20 | 29 | 0.80 | 42132.60 | -2127 | 991 | -296 | 129 | 1542.60 |
| U2 | sau15_khoa | -9050 | 0 | 23.30 | -0.75 | -12268 | 2264 | 22.20 | 5007 | 0.06 | 0.70 | 1086.10 | 14 | 0.92 | 39973.80 | 2866 | -8952 | -488 | 6 | 4533.70 |
| U3 | v022 | 7045 | 0 | 12.60 | 1.07 | -1732 | 946 | 9.27 | 1826 | 0.41 | 5.80 | 311.30 | 33 | 0.38 | 45561.00 | 4372 | 4484 | -211 | 7 | 119.50 |
| U3 | sau15_khoa | 11220 | 0 | 7.50 | 2.88 | 3078 | 1299 | 12.74 | 2008 | 0.40 | 5.60 | 159.00 | 14 | 0.27 | 48248.60 | 4476 | 6997 | -85 | 1 | 0.00 |

