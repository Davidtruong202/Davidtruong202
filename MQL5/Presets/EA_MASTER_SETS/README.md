# 10 SET chạy song song EA MASTER 4PP v1.10 + Dashboard V3.40

| SET | Magic_Goc | Magic lệnh | Nội dung |
|---|---|---|---|
| S01 | 301 | 3011 | PP1 RSI M1 (gốc) |
| S02 | 302 | 3021 | PP1 RSI M5 |
| S03 | 303 | 3032 | PP2 SMC M15 |
| S04 | 304 | 3042 | PP2 SMC H1 + lọc HTF H4 |
| S05 | 305 | 3053 | PP3 Pivot bật lại M15 |
| S06 | 306 | 3063 | PP3 Pivot phá vỡ M15 |
| S07 | 307 | 3074 | PP4 QM M15 |
| S08 | 308 | 3084 | PP4 QM H1 |
| S09 | 309 | 3091-3094 | Cả 4 PP, BALANCED, độc lập |
| S10 | 310 | 3101-3104 | Cả 4 PP, SAFE, không đối nghịch, chặn ngược chiều |

Mọi SET: vốn ảo 5000 USD từ 2026.10.01 00:00 (trùng Dashboard), rủi ro 0.5%/lệnh
trên vốn ảo, nhật ký lệnh ghi vào `Common\Files\EAM_<SET>_<Magic>.csv`.

Cách chạy: mở 11 chart XAUUSD (khung chart bất kỳ). 10 chart gắn `EA_MASTER_4PP`,
tab Inputs -> Load -> chọn 1 file `EAM_Sxx_*.set` cho mỗi chart. Chart thứ 11 gắn
`EA_MAGIC_DASHBOARD_V3_40` với `EA_MAGIC_DASHBOARD_V3_40.set`.

## Backtest 22 SET dựng sẵn cùng lúc (EA v1.20, input `ChonSet`)

1. Strategy Tester: Expert `EA_MASTER_4PP`, XAUUSD, khung bất kỳ (M15),
   Modelling = Every tick based on real ticks, khoảng thời gian 2024.01.01 - 2026.09.30,
   Deposit 10000 USD.
2. Optimization = **Slow complete algorithm**, Criterion = **Custom max**.
3. Tab Inputs -> Load -> `EAM_TESTER_OPTIMIZE_22SET.set` (chỉ ChonSet = 1..22 được tối ưu).
4. Start. MT5 chạy 22 lượt song song trên các core.
5. Kết quả: tab Optimization Results (chuột phải -> Export to XML) **và** file
   `Common\Files\EAM_BACKTEST_KET_QUA.csv` (mỗi lượt 1 dòng, có tách lệnh/thắng %/lợi nhuận PP1-PP4).
   Gửi lại file CSV này để chọn SET cho bản "1 chart - SET ảo".

| ChonSet | SET |
|---|---|
| 1-4 | PP1 RSI: M1 gốc / M5 / M15 / RSI(14) 75-25 M5 |
| 5-9 | PP2 SMC: M15 / H1 / H1 + HTF H4 / M15 + Premium-Discount / M15 chỉ OB swing |
| 10-13 | PP3 Pivot: bật lại M15 / bật lại M5 / bật lại M15 TP R:R / phá vỡ M15 |
| 14-18 | PP4 QM: M15 / H1 / M5 / M15 chờ nến từ chối / M15 trailing ATR |
| 19 | PP2 SMC M15 trailing ATR |
| 20-22 | Cả 4 PP: BALANCED độc lập / SAFE không đối nghịch / BALANCED đa số thắng |

## Vòng 2 (EA v1.30): ChonSet 23-40, KHÔNG GIỚI HẠN

Kết quả vòng 1 (2026.01-2026.10): chỉ có lời ở #9 PP2 M15 OB swing, #6 PP2 H1, #15 PP4 H1.
Vòng 2 đào sâu PP2/PP4 quanh các set đó. File `EAM_TESTER_VONG2_LOT003_SPREAD50.set`
(chỉ 23-40) hoặc `EAM_TESTER_TATCA40_LOT003_SPREAD50.set` (1-40) tắt: lọc spread, DD ngày,
DD tài khoản, lỗ ngày, chuỗi thua, lọc giờ/phiên/tin. Vẫn giữ SL mỗi lệnh và rủi ro 0.5%/lệnh.

| ChonSet | SET |
|---|---|
| 23-27 | PP2 H1: chỉ OB swing / OB swing R:R 3 / R:R 3 / R:R 1.5 / không hòa vốn |
| 28-30 | PP2: M30 / M30 chỉ OB swing / H4 |
| 31-32 | PP2 M15 OB swing: R:R 3 / không hòa vốn |
| 33-34 | PP2 H1: swing 30 / không cần nến xác nhận |
| 35-38 | PP4: H1 R:R 3 / H1 TP cấu trúc / H4 / H1 không hòa vốn |
| 39-40 | PP2 H1 + PP4 H1 / PP2 H1 OB swing + PP4 H1 |

## v1.31: lot cố định 0.03, spread tối đa 50 pip, chốt chặn 5%/lệnh

Trong Tester, XAUUSDm là symbol chuẩn (1 lot = 100 oz) nên "3 lot" là 3 lot đô la thật
(gấp 100 lần 3 lot Cent) -> các lượt cũ cháy tài khoản sau vài lệnh. File set mới dùng
lot cố định 0.03. EA in dòng "HỢP ĐỒNG ..." và "KIỂM TRA LOT ..." trong Journal khi khởi động
để kiểm tra giá trị 1 lot, và bỏ mọi lệnh có lỗ tại SL > RuiRoToiDaMoiLenh_PT (5%) Balance.
