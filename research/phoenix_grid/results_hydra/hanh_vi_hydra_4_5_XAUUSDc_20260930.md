# Hành vi Hydra (magic 20260826 DCA, 20260827 pyramid) dựng lại từ lịch sử deal

Nguồn: `PG_lich_su_deal_Exness-MT5Real20_20260101_20261001.csv` (chỉ các deal của hai magic trên). Không có số tài khoản, ticket, nạp / rút hay lệnh của EA khác. Chỉ mô tả cái đã xảy ra, không phải backtest.

## 1. Tổng quan

- Khoảng dữ liệu: 2026-09-30 03:50:47 → 2026-09-30 07:01:46 (giờ server), 3.18 giờ; 130 deal.
- Giá trị 1 lot khi giá đi 1 đơn vị: **100.1** tiền tài khoản (trung vị từ 53 lần đóng).
- Basket đã đóng hết: 25 / 25; hướng: 25 BUY, 0 SELL.
- Lãi đã chốt: **83.20** (26.14 mỗi giờ); basket lãi 25, lỗ 0.
- Lý do đóng: EXPERT.

## 2. Đối chiếu file set đang chạy với lịch sử

Quy đổi "điểm" của Hydra = 0.01 USD. Kiểm tra: bước DCA trong set / khoảng tầng thật ≈ 0.0103 USD mỗi điểm.

| Cơ chế | Input | Giá trị trong set | Lịch sử | Nhận xét |
|---|---|---|---|---|
| Bước DCA | InpGridStepPoints | 150 = 1.50 USD | trung vị 1.55, 10% 1.34 USD (giá khớp, gồm spread) | khớp |
| Lot từng tầng | InpBaseLot + bảng InpTier* | ×1,2 tới cấp 6, ×1,05 tới 14, ×1,5 tới 18, ×1,05 tới 26, ×1,3 tới 30 | 53/53 lệnh DCA đúng lot tính từ bảng (tầng N dùng cấp N − 1) | khớp |
| Giãn cách hai lệnh DCA | InpDCAMinSecsApart | 20 giây | giữa hai lệnh DCA thêm vào: ngắn nhất 21 giây (n = 14); lệnh đầu → DCA đầu tiên: ngắn nhất 18 giây | khớp (không áp dụng từ lệnh đầu sang DCA đầu tiên) |
| Chờ sau khi đóng basket | InpReentryCooldownSec | 10 giây | ngắn nhất 10 giây, trung vị 74 giây | khớp |
| Vào lại cách giá đóng trước | InpReentryMinPoints | 150 = 1.50 USD | |giá lệnh đầu − giá đóng trước|: nhỏ nhất 1.02, trung vị 1.50 USD | gần khớp (một bên là Ask, một bên là Bid: lệch cỡ spread) |
| Pyramid cách tầng 1 | InpPyramidStepPoints | 150 = 1.50 USD | nhỏ nhất 1.49, trung vị 1.84 USD (Ask − Ask) | khớp (điều kiện theo Bid, khớp lệnh ở Ask) |
| Pyramid không đóng một mình | InpPyramidNeverExitAlone | true | 12/12 lệnh pyramid đóng cùng đợt với lệnh DCA | khớp |
| Hòa vốn chung (SL ẩn) | InpCombinedBEArmPoints / FloorPoints | kích hoạt +0.80, sàn +0.15 USD trên giá trung bình | basket ≥ 2 tầng không pyramid: 8/13 đóng ở +0.15…+0.80 trên giá TB, 5 đóng cao hơn (trailing) | khớp với cách đóng sát hòa vốn |
| Trailing rổ DCA | InpHiddenTrailStart / Step (+ mỗi tầng) | bắt đầu +2.50 (+0.02/tầng), bước 1.80 (+0.01/tầng); khóa 40% đỉnh | các basket đóng trên mốc hòa vốn chung: +1.84, +1.92, +3.88, +4.48, +1.29 | không kiểm được nếu không có tick |
| Cắt lỗ | InpStopLossPoints | 0 | mọi lần đóng do EA (EXPERT), không SL / TP trên server | khớp |
| Số tầng tối đa | InpMaxDCALevels | 1000 | sâu nhất đã thấy: 9 tầng | chưa chạm |


## 3. Số tầng DCA và lot từng tầng

| Số tầng DCA | Số basket |
|---|---|
| 1 | 11 |
| 2 | 8 |
| 3 | 4 |
| 5 | 1 |
| 9 | 1 |


| Tầng | Lot đã thấy | Lot theo bảng trong set |
|---|---|---|
| 1 | 0.01 | 0.01 |
| 2 | 0.01 | 0.01 |
| 3 | 0.01 | 0.01 |
| 4 | 0.02 | 0.02 |
| 5 | 0.02 | 0.02 |
| 6 | 0.02 | 0.02 |
| 7 | 0.03 | 0.03 |
| 8 | 0.03 | 0.03 |
| 9 | 0.03 | 0.03 |


## 4. Khoảng giữa hai tầng DCA liên tiếp

- Theo giá khớp, hướng bất lợi: n = 28; nhỏ nhất 0.81 USD; 10% 1.34; trung vị 1.55; 90% 1.77; lớn nhất 2.26 USD
- Dưới 1,2 USD: 2 lần (tầng sau mở khi giá chưa đi đủ một bước tính từ giá khớp tầng trước).
- Thời gian giữa hai lệnh DCA thêm vào (tầng 2 → 3 trở đi): n = 14; nhỏ nhất 21.16 giây; 10% 38.30; trung vị 64.06; 90% 211.79; lớn nhất 237.53 giây
- Thời gian từ lệnh đầu tới lệnh DCA đầu tiên: n = 14; nhỏ nhất 18.22 giây; 10% 29.80; trung vị 77.11; 90% 250.56; lớn nhất 532.78 giây

## 5. Lệnh pyramid

- Basket có pyramid: 12 / 25; số pyramid mỗi basket lớn nhất: 1; số tầng DCA của các basket có pyramid: [1, 2].
- Giá khớp pyramid cách giá khớp tầng 1 (theo hướng có lợi): n = 12; nhỏ nhất 1.49 USD; 10% 1.75; trung vị 1.84; 90% 2.03; lớn nhất 2.06 USD
- Từ lúc mở pyramid tới lúc đóng hết basket: n = 12; nhỏ nhất 0.00 giây; 10% 0.10; trung vị 2.00; 90% 6.90; lớn nhất 9.00 giây
- Pyramid đóng cùng đợt với lệnh DCA: 12 / 12.

## 6. Đóng basket

- Đóng một đợt (các lệnh cách nhau ≤ 2 giây): 24; nhiều đợt: 1.
- Lãi mỗi basket: n = 25; nhỏ nhất 0.40; 10% 0.60; trung vị 1.20; 90% 6.28; lớn nhất 34.60
- Lãi trên mỗi 0,01 lot DCA: n = 25; nhỏ nhất 0.20; 10% 0.30; trung vị 0.90; 90% 2.48; lớn nhất 4.50
- Giá đóng trừ giá trung bình DCA: n = 25; nhỏ nhất 0.17 USD; 10% 0.28; trung vị 1.29; 90% 2.32; lớn nhất 4.48 USD
- Giá đóng trừ giá tầng 1: n = 25; nhỏ nhất -6.82 USD; 10% -1.17; trung vị 1.22; 90% 2.15; lớn nhất 3.69 USD
- Thời gian giữ basket: n = 25; nhỏ nhất 0.23 phút; 10% 0.60; trung vị 4.23; 90% 14.25; lớn nhất 23.90 phút
- Thả nổi lúc mở tầng sâu nhất (định giá bằng giá khớp tầng đó, chưa gồm spread, không phải đáy thật): n = 25; nhỏ nhất -88.68; 10% -4.87; trung vị -1.50; 90% 0.00; lớn nhất 0.00

## 7. Từ lúc đóng basket tới lệnh tầng 1 kế tiếp

- Thời gian: n = 24; nhỏ nhất 10.00 giây; 10% 20.90; trung vị 74.50; 90% 202.00; lớn nhất 507.00 giây
- |Giá lệnh đầu mới − giá đóng basket trước|: n = 24; nhỏ nhất 1.02 USD; 10% 1.08; trung vị 1.50; 90% 1.88; lớn nhất 2.08 USD

## 8. Lệnh gửi lên server

- Loại lệnh: ORDER_TYPE_BUY 65, ORDER_TYPE_SELL 65.
- SL / TP khác 0: 0 lệnh.
- Từ lúc đặt tới lúc khớp: n = 130; nhỏ nhất 0.00 giây; 10% 0.00; trung vị 0.00; 90% 1.00; lớn nhất 2.00 giây (MT5 chỉ lưu tới giây).

## 9. Từng basket

| # | Bắt đầu | Hướng | Tầng | Py | Lot tầng | Giá tầng 1 | Giá TB | Giá đóng | Đóng − TB | Đóng − tầng 1 | Lãi | Đợt đóng | Phút |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 09-30 03:50:47 | BUY | 2 | 0 | 0.01/0.01 | 4173.52 | 4172.77 | 4173.18 | 0.41 | -0.34 | 0.90 | 1 | 6.55 |
| 2 | 09-30 04:02:22 | BUY | 2 | 1 | 0.01/0.01 | 4174.97 | 4174.13 | 4176.42 | 2.29 | 1.45 | 4.00 | 2 | 14.47 |
| 3 | 09-30 04:25:17 | BUY | 1 | 1 | 0.01 | 4178.17 | 4178.17 | 4180.51 | 2.34 | 2.34 | 2.80 | 1 | 10.17 |
| 4 | 09-30 04:35:52 | BUY | 2 | 0 | 0.01/0.01 | 4182.26 | 4181.45 | 4183.29 | 1.84 | 1.03 | 3.70 | 1 | 5.02 |
| 5 | 09-30 04:44:15 | BUY | 3 | 0 | 0.01/0.01/0.01 | 4181.98 | 4180.49 | 4180.95 | 0.46 | -1.03 | 1.50 | 1 | 17.40 |
| 6 | 09-30 05:03:00 | BUY | 1 | 1 | 0.01 | 4179.52 | 4179.52 | 4180.77 | 1.25 | 1.25 | 0.80 | 1 | 1.10 |
| 7 | 09-30 05:06:07 | BUY | 9 | 0 | 0.01/0.01/0.01/0.02/0.02/0.02/0.03/0.03/0.03 | 4179.69 | 4170.94 | 4172.86 | 1.92 | -6.82 | 34.60 | 1 | 23.90 |
| 8 | 09-30 05:30:11 | BUY | 2 | 0 | 0.01/0.01 | 4174.82 | 4174.40 | 4178.28 | 3.88 | 3.46 | 7.80 | 1 | 3.93 |
| 9 | 09-30 05:36:09 | BUY | 5 | 0 | 0.01/0.01/0.01/0.02/0.02 | 4179.79 | 4176.32 | 4176.56 | 0.24 | -3.23 | 1.80 | 1 | 8.50 |
| 10 | 09-30 05:45:47 | BUY | 1 | 1 | 0.01 | 4175.40 | 4175.40 | 4176.61 | 1.21 | 1.21 | 0.40 | 1 | 0.72 |
| 11 | 09-30 05:47:15 | BUY | 2 | 0 | 0.01/0.01 | 4175.53 | 4174.73 | 4179.21 | 4.48 | 3.69 | 9.00 | 1 | 12.02 |
| 12 | 09-30 05:59:36 | BUY | 1 | 1 | 0.01 | 4178.17 | 4178.17 | 4179.39 | 1.22 | 1.22 | 0.60 | 1 | 1.28 |
| 13 | 09-30 06:01:52 | BUY | 2 | 0 | 0.01/0.01 | 4178.11 | 4177.35 | 4178.64 | 1.29 | 0.53 | 2.50 | 1 | 1.17 |
| 14 | 09-30 06:04:26 | BUY | 1 | 1 | 0.01 | 4180.22 | 4180.22 | 4181.61 | 1.39 | 1.39 | 1.00 | 1 | 0.57 |
| 15 | 09-30 06:08:22 | BUY | 1 | 1 | 0.01 | 4180.59 | 4180.59 | 4182.04 | 1.45 | 1.45 | 1.00 | 1 | 1.77 |
| 16 | 09-30 06:12:05 | BUY | 2 | 0 | 0.01/0.01 | 4184.12 | 4183.30 | 4183.58 | 0.27 | -0.54 | 0.60 | 1 | 4.23 |
| 17 | 09-30 06:18:03 | BUY | 3 | 0 | 0.01/0.01/0.01 | 4182.27 | 4180.70 | 4181.36 | 0.66 | -0.91 | 2.10 | 1 | 4.45 |
| 18 | 09-30 06:24:24 | BUY | 3 | 0 | 0.01/0.01/0.01 | 4182.85 | 4181.29 | 4181.58 | 0.30 | -1.27 | 0.90 | 1 | 13.93 |
| 19 | 09-30 06:39:09 | BUY | 1 | 1 | 0.01 | 4180.48 | 4180.48 | 4181.96 | 1.48 | 1.48 | 0.90 | 1 | 5.40 |
| 20 | 09-30 06:46:23 | BUY | 1 | 1 | 0.01 | 4180.24 | 4180.24 | 4181.49 | 1.25 | 1.25 | 0.80 | 1 | 3.30 |
| 21 | 09-30 06:50:46 | BUY | 1 | 1 | 0.01 | 4183.32 | 4183.32 | 4184.66 | 1.34 | 1.34 | 1.00 | 1 | 0.52 |
| 22 | 09-30 06:51:40 | BUY | 1 | 1 | 0.01 | 4186.56 | 4186.56 | 4188.43 | 1.87 | 1.87 | 1.60 | 1 | 0.23 |
| 23 | 09-30 06:52:37 | BUY | 1 | 1 | 0.01 | 4189.99 | 4189.99 | 4191.35 | 1.36 | 1.36 | 1.30 | 1 | 0.65 |
| 24 | 09-30 06:53:30 | BUY | 2 | 0 | 0.01/0.01 | 4193.16 | 4192.39 | 4192.56 | 0.17 | -0.59 | 0.40 | 1 | 2.32 |
| 25 | 09-30 06:56:16 | BUY | 3 | 0 | 0.01/0.01/0.01 | 4193.74 | 4192.30 | 4192.70 | 0.40 | -1.03 | 1.20 | 1 | 5.50 |

