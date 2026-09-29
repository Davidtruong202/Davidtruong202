# Phụ lục — Thống kê mô tả dữ liệu XAUUSDm M1 (PG-R0.0)

> **Đây không phải backtest.** Không mô phỏng lệnh, không tính lợi nhuận của bất kỳ chiến lược nào. Các số liệu dưới
> đây chỉ dùng để đặt kịch bản stress, ngưỡng spread và đơn vị ATR cho kế hoạch nghiên cứu
> ([`01_KE_HOACH_NGHIEN_CUU.md`](01_KE_HOACH_NGHIEN_CUU.md)).

| Mục | Giá trị |
|---|---|
| Nguồn | `EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv` (SHA-256 trong `EA-PRO/data/MANIFEST_SHA256.txt`) |
| Symbol / sàn | XAUUSDm, Exness (tài khoản Standard, tiền USD). **Không phải XAUUSDc** |
| Dữ liệu | Nến M1 theo Bid, kèm cột `spread_points` (point = 0,001) |
| Script | `research/phoenix_grid/thong_ke_mo_ta.py` |
| Kết quả CSV | `research/phoenix_grid/results/` |

## A.1. Độ phủ dữ liệu ✅

| Chỉ số | Giá trị |
|---|---|
| Nến đầu / nến cuối | 31/12/2025 21:57 → 27/09/2026 23:58 (giờ server GMT+0) |
| Số nến M1 | 260.662 |
| Số ngày có giao dịch | 231. Có 190 ngày đủ ≥ 600 nến, dùng để tính biên độ ngày |
| Nghỉ trong ngày | 151 lần. Nến cuối trước nghỉ: 20:57 (113 lần), 21:57 (34 lần). Mở lại: 22:00–22:01 (110 lần), 23:00–23:01 (27 lần). Tức nghỉ khoảng 1 giờ, lệch 1 giờ theo mùa |
| Nghỉ cuối tuần / lễ | 40 lần |
| Khoảng trống bất thường 5–30 phút | 2 |

## A.2. Spread (USD/oz) ✅

Nguồn là cột spread của nến M1. Đây là giá trị đại diện cho cả nến, không phải spread tại từng tick.

| Trung vị | p75 | p90 | p99 | Lớn nhất |
|---|---|---|---|---|
| 0,260 | 0,280 | 0,280 | 0,364 | 1,440 |

**Theo giờ server.**

| Giờ | Trung vị | p90 |
|---|---|---|
| 00 | 0,26 | 0,308 |
| 01 → 19 | 0,26 | 0,28 |
| 20 | 0,26 | 0,308 |
| 21 | 0,16 | 0,36 |
| 22 | 0,28 | 0,36 |
| 23 | 0,26 | 0,36 |

Giờ 21 chỉ có dữ liệu trong các tháng mùa đông (mùa hè đang nghỉ). Tháng 01/2026 có spread thấp (0,16), nên trung vị
của giờ 21 bị kéo xuống. p90 cao hơn rõ rệt ở các giờ 21–23, quanh lúc mở lại sau giờ nghỉ.

**Theo tháng.**

| Tháng | 12/2025 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 |
|---|---|---|---|---|---|---|---|---|---|---|
| Trung vị | 0,16 | 0,16 | 0,24 | 0,28 | 0,28 | 0,28 | 0,26 | 0,24 | 0,26 | 0,26 |
| p90 | 0,16 | 0,16 | 0,36 | 0,36 | 0,28 | 0,28 | 0,28 | 0,24 | 0,26 | 0,26 |

## A.3. Biên độ ngày (High − Low theo ngày server, USD/oz) ✅

| Tháng | Số ngày | Trung vị | p90 | Lớn nhất |
|---|---|---|---|---|
| 01/2026 | 21 | 90,3 | 413,0 | 768,4 |
| 02 | 20 | 129,8 | 316,4 | 482,9 |
| 03 | 22 | 151,6 | 353,7 | 414,4 |
| 04 | 21 | 101,3 | 162,4 | 245,0 |
| 05 | 21 | 100,5 | 135,7 | 150,3 |
| 06 | 22 | 91,8 | 164,2 | 210,2 |
| 07 | 23 | 86,4 | 118,5 | 155,7 |
| 08 | 21 | 88,7 | 186,7 | 211,8 |
| 09 | 19 | 98,0 | 129,3 | 138,8 |
| **Toàn kỳ** | **190** | **100,4** (p75 136,6) | **205,9** | **768,4** |

- Theo % giá: trung vị 2,21%, p90 4,70%.
- Tỷ lệ ngày có biên độ ≥ 50 USD: 95,8%. ≥ 100: 51,6%. ≥ 150: 20,5%. ≥ 200: 11,6%. ≥ 300: 4,7%.
- Báo cáo V4.39 ghi biên độ ngày trung vị hơi khác (80–137 theo tháng), do cách gom ngày khác (ở đây bỏ các ngày có
  dưới 600 nến).

## A.4. ATR14 (USD/oz) ✅

ATR tính bằng trung bình cộng TR, giống iATR của MT5. Nến M5/M15/H1 được dựng lại từ M1.

| Khung | p10 | Trung vị | p90 | Spread trung vị / ATR trung vị |
|---|---|---|---|---|
| M1 | 1,32 | 2,24 | 4,73 | 11,6% |
| M5 | 3,18 | 5,24 | 10,68 | 5,0% |
| M15 | 6,02 | 9,36 | 18,41 | 2,8% |
| H1 | 14,20 | 19,72 | 34,65 | 1,3% |

## A.5. Biến động ngược chiều tối đa từ một điểm vào bất kỳ ✅

Cách đo:

- Điểm vào là giá mở cửa (Bid) của **mọi** nến M1.
- Mức ngược chiều = khoảng cách tới đáy thấp nhất (với BUY) hoặc đỉnh cao nhất (với SELL) trong khung thời gian sau
  đó, tính theo thời gian lịch. Khung 3 và 5 ngày có bao gồm cuối tuần.
- Đây là đặc tính của giá, **không có tín hiệu vào lệnh nào**.

| Khung | Hướng | Trung vị | p90 | p99 | Lớn nhất | P(≥10) | P(≥20) | P(≥50) | P(≥100) | P(≥150) | P(≥200) | P(≥300) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 phút | BUY | 3,9 | 13,0 | 39,0 | 332,4 | 16,0% | 4,2% | 0,5% | 0,1% | 0,0% | 0,0% | 0,0% |
| 15 phút | SELL | 3,8 | 12,4 | 32,6 | 205,2 | 14,9% | 3,5% | 0,3% | 0,0% | 0,0% | 0,0% | 0,0% |
| 1 giờ | BUY | 7,9 | 25,8 | 79,3 | 453,4 | 40,6% | 15,7% | 2,7% | 0,6% | 0,2% | 0,1% | 0,0% |
| 1 giờ | SELL | 7,3 | 24,0 | 61,7 | 229,0 | 38,4% | 14,4% | 1,8% | 0,2% | 0,0% | 0,0% | 0,0% |
| 4 giờ | BUY | 16,5 | 50,8 | 170,1 | 453,4 | 67,5% | 42,0% | 10,3% | 2,8% | 1,3% | 0,7% | 0,2% |
| 4 giờ | SELL | 14,9 | 47,7 | 112,1 | 361,1 | 63,5% | 38,8% | 8,9% | 1,4% | 0,4% | 0,2% | 0,0% |
| 24 giờ | BUY | 39,5 | 131,2 | 370,6 | 767,7 | 84,9% | 71,3% | 41,4% | 16,8% | 7,9% | 3,8% | 2,0% |
| 24 giờ | SELL | 37,4 | 118,4 | 255,5 | 479,1 | 82,7% | 68,6% | 38,2% | 14,1% | 5,9% | 2,2% | 0,7% |
| 3 ngày | BUY | 70,0 | 204,0 | 607,7 | 910,6 | 90,9% | 82,5% | 62,2% | 35,7% | 20,5% | 10,6% | 5,6% |
| 3 ngày | SELL | 58,6 | 194,5 | 494,5 | 686,1 | 90,2% | 81,5% | 55,6% | 29,7% | 16,0% | 9,4% | 2,4% |
| 5 ngày | BUY | 93,8 | 242,1 | 860,2 | 1.191,1 | 93,5% | 87,8% | 72,9% | 47,2% | 29,9% | 18,0% | 7,7% |
| 5 ngày | SELL | 74,5 | 247,7 | 501,6 | 686,1 | 92,7% | 85,8% | 64,1% | 39,3% | 27,0% | 17,5% | 5,2% |

Chiều BUY xấu hơn SELL ở các khung dài vì trong kỳ có những đợt giảm rất mạnh (tháng 3 và 6/2026 giảm khoảng 12%).
Tỷ lệ này thay đổi theo giai đoạn (bảng A.6), nên không được coi là đặc tính cố định.

## A.6. Xác suất ngược chiều trong 24 giờ, theo tháng ✅

| Tháng | BUY ≥ 50 | SELL ≥ 50 | BUY ≥ 100 | SELL ≥ 100 | BUY ≥ 200 | SELL ≥ 200 |
|---|---|---|---|---|---|---|
| 01/2026 | 33,5% | 42,0% | 13,4% | 21,0% | 9,4% | 7,9% |
| 02 | 41,8% | 56,3% | 24,6% | 23,9% | 8,7% | 5,7% |
| 03 | 61,6% | 43,7% | 34,8% | 23,4% | 13,4% | 3,4% |
| 04 | 42,4% | 37,6% | 14,7% | 11,4% | 1,9% | 2,4% |
| 05 | 38,4% | 33,9% | 11,8% | 9,9% | 0,0% | 0,0% |
| 06 | 54,4% | 27,1% | 29,3% | 5,1% | 0,7% | 0,1% |
| 07 | 29,7% | 34,2% | 4,0% | 7,7% | 0,0% | 0,0% |
| 08 | 29,4% | 41,4% | 7,0% | 18,5% | 0,0% | 0,6% |
| 09 | 40,6% | 28,2% | 10,9% | 6,6% | 0,0% | 0,0% |

## A.7. Variance ratio (Lo–MacKinlay 1988) ✅

Tính trên 260.462 log return M1 liên tiếp (bỏ các bước nhảy qua giờ nghỉ). z* là thống kê chịu được phương sai thay
đổi.

| q (phút) | VR(q) | z* |
|---|---|---|
| 5 | 0,993 | −0,43 |
| 15 | 0,971 | −0,98 |
| 30 | 0,973 | −0,68 |
| 60 | 0,962 | −0,74 |
| 240 | 0,911 | −1,04 |

**Diễn giải.**

- VR < 1 gợi ý một chút xu hướng hồi về trung bình, nhưng |z*| < 1,96 ở mọi khung. Vì vậy **không có ý nghĩa thống
  kê** ở mức 5%.
- Đây là kết quả **vô điều kiện** trên toàn kỳ. Nó không loại trừ khả năng có hồi quy **trong vùng sideways được
  nhận diện đúng**. Đó chính là giả thuyết H-A cần kiểm định ở Giai đoạn A0.

## A.8. Gap mở cửa sau cuối tuần / ngày lễ (USD/oz) ✅

| Số lần | Trung bình của trị tuyệt đối | Trung vị | p90 | Lớn nhất |
|---|---|---|---|---|
| 40 | 21,2 | 14,1 | 52,4 | 98,0 |

| Từ (nến cuối) | Đến (nến đầu) | Gap |
|---|---|---|
| 30/01/2026 21:57 | 01/02/2026 23:01 | −97,98 |
| 10/04/2026 20:57 | 12/04/2026 22:06 | −79,07 |
| 16/01/2026 21:57 | 18/01/2026 23:09 | +58,77 |
| 17/04/2026 20:57 | 19/04/2026 22:01 | −58,40 |
| 12/06/2026 20:57 | 14/06/2026 22:02 | +51,68 |

## A.9. Giới hạn

1. XAUUSDm (Standard) có thể khác XAUUSDc (Cent) về spread và swap. Phải đo lại khi có tick XAUUSDc (DL-01, TS-05).
2. Cột spread của nến M1 không thay thế được spread tại từng tick. Spread lúc tin tức có thể lớn hơn nhiều so với
   con số lớn nhất ở đây.
3. Chỉ có 9 tháng của một chế độ giá (vàng 4.000–5.400 USD). Biên độ tính bằng USD phụ thuộc mức giá, nên kế hoạch
   tham số hóa theo ATR.
4. Dữ liệu 2026 đã được dùng ở đây cho thống kê biến động/spread. Không tham số tín hiệu nào được chọn từ dữ liệu này.
