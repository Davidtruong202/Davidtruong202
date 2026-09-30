# Tần suất vào lệnh đầu của Phoenix V0.20 — nến XAUUSDm 02/01–27/09/2026 (231 ngày có nến)

> Đếm lại điều kiện PP10 / PP1 của `EA_PHOENIX_GRID_V0_20_TEST.mq5` trên nến dựng từ M1
> (`EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv`).
>
> - **Không phải EA, không phải backtest giao dịch.** Chỉ đếm số lần điều kiện vào lệnh thỏa.
> - Là cận trên: chưa tính các chặn của Phoenix (một basket một lúc, ngược xu hướng M5 / breakout, spread, phiên, tin).
> - Chưa đo tín hiệu tốt hay xấu.

## PP10 (Fib + Bollinger theo SET M2) — `research/phoenix_grid/tan_suat_pp10.py`

| Biến thể | Tín hiệu | Tín hiệu / ngày | Trung vị giờ giữa 2 tín hiệu |
|---|---|---|---|
| **A. V0.20 hiện tại**: giá đóng trong vùng Fib 0,45–0,668, chạm dải dưới BB(11; 2,4) ở nến tín hiệu, có nến xác nhận | **3** | **0,01** | 2.370 |
| B. = A, chạm dải dưới ở bất kỳ nến nào của nhịp hồi | 18 | 0,08 | 293 |
| C. = A, chạm dải giữa (MA11) thay dải dưới | 40 | 0,17 | 119 |
| D. = A, râu chạm vùng Fib, giá đóng bật ra khỏi vùng | 38 | 0,16 | 118 |
| E. = A, bỏ nến xác nhận | 93 | 0,40 | 47 |
| F. = C, chạm ở bất kỳ nến nào của nhịp hồi | 40 | 0,17 | 119 |
| G. = F, chỉ cần hồi tới vùng Fib (không xét giá đóng) | 268 | 1,16 | 12,9 |
| H. = G, ADX ≥ 20 | 509 | 2,20 | 5,8 |
| I. = G, nhịp hồi 2–15 nến | 492 | 2,13 | 6,2 |

Phễu của biến thể A (số nến M2):

| Bước | Số nến |
|---|---|
| Tổng | 130.265 |
| Có hướng EMA53 | 110.587 |
| Qua ADX ≥ 27 và ATR | 60.113 |
| Trượt: điểm cuối nhịp chưa đủ 4 nến | 29.016 |
| Trượt: điểm cuối nhịp quá 9 nến | 17.930 |
| Trượt: giá đóng ngoài vùng Fib | 12.370 |
| Trượt: không chạm dải dưới | 600 |
| Trượt: không có nến xác nhận | 90 |
| Còn lại (tín hiệu) | 3 |

Không có mã nguồn VuTru_Fibo_BB_Pullback, nên cách hiểu SET ở V0.20 có thể chặt hơn EA gốc.

## PP1 (biên hộp sideway + nến M1 từ chối)

Ước lượng bằng trạng thái SIDEWAY của bản sao MI, có cùng điều kiện hộp với bộ nhận diện V0.11 mà V0.20 dùng:

- SIDEWAY chiếm 2,1% thời gian (1.113 nến M5).
- 569 nến M1 thỏa điều kiện PP1 (2,46 / ngày), gom thành 154 đợt cách nhau > 30 phút, tức **0,67 đợt / ngày**.

## Kết luận

Với tham số mặc định, V0.20 gần như chỉ vào lệnh bằng PP1: khoảng một basket mỗi 1–2 ngày, và chỉ khi thị trường sideway.
