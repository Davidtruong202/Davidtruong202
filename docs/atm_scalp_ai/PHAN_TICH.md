# DTRADE$ – ATM SCALP AI: phân tích buffer (lần 1)

Dữ liệu: `ATM Scalping2_ctxbars_XAUUSDc_M5.csv` (TradeLogger 3.31, Exness Real20, XAUUSDc M5,
2025-09-12 → 2026-10-13, 76 468 nến, 21 buffer). Script: `research/atm_scalp_ai/`
(chạy `python3 <script>.py "<file ctxbars M5>"`).

## Ý nghĩa 21 buffer (M5)

| Buffer | Ý nghĩa | Bằng chứng |
|---|---|---|
| b0 | Mũi tên BUY (giá đặt mũi tên) | chỉ có ở nến tín hiệu mua |
| b1 | Mũi tên SELL | chỉ có ở nến tín hiệu bán |
| b2 | Trạng thái lệnh: 1 = đang BUY, −1 = đang SELL, 0 = không có lệnh | |
| b3 | Giá ENTRY = giá đóng cửa nến tín hiệu | b3 = close |
| b4 | SL = ENTRY ∓ **3 × ATR(14)** | tỉ lệ đúng 3.000 ở cả 76 tín hiệu |
| b5 / b6 / b7 | TP1 / TP2 / TP3 = **1R / 2R / 3R** (R = khoảng SL) | đúng 1.00 / 2.00 / 3.00 ở cả 76 tín hiệu |
| b8 = b10 | **EMA(close, 9)** | khớp đến 0.0000003 |
| b11 | **EMA(close, 14)** | khớp chính xác |
| b12 | **EMA(close, 21)** | khớp chính xác |
| b13 | **EMA(close, 34)** | khớp chính xác |
| b14 | **EMA(close, 55)** | khớp chính xác |
| b15 = b16 | **ATR(14) kiểu Wilder** (ATR chuẩn của MT5 dùng SMA, chỗ này khác) | khớp chính xác |
| b19 | **ADX(14) kiểu Wilder** | khớp chính xác |
| b20 | Xu hướng ±1 ≈ **EMA21 > EMA55** | trùng 99.8% số nến (chưa khớp tuyệt đối) |
| b9 | 1 khi b20 = −1 (cờ xu hướng giảm) | trùng 100% |
| b17, b18 | Chưa rõ (giá trị quanh 1, dao động 0.06–30) | không khớp ATR/khối lượng/khoảng cách EMA đã thử |

## Tín hiệu

- Tín hiệu chỉ có từ **2026-09-17** (≈ 26 ngày, 76 tín hiệu: 36 BUY, 40 SELL). Các đường EMA/ATR/ADX có đủ cả
  năm → bản trial chỉ cho tín hiệu trên khoảng 1 tháng gần nhất.
- Điều kiện **cần** (đúng ở 76/76 tín hiệu), BUY (SELL ngược lại):
  1. Xu hướng b20 = +1 (≈ EMA21 > EMA55)
  2. ADX(14) Wilder > 20 (nhỏ nhất thấy được: 20.1)
  3. Giá đóng cửa > EMA9
  4. EMA9 > EMA21
  5. Nến tăng (close > open)
- **Chưa đủ**: trong giai đoạn có tín hiệu, 317 nến thỏa cả 5 điều kiện lúc không có lệnh nhưng chỉ 68 nến có
  tín hiệu → còn ít nhất một điều kiện kích hoạt chưa tìm ra (ứng viên: b17/b18, khoảng nghỉ giữa 2 lệnh,
  vị trí giá so với EMA, giờ giao dịch). 8/76 tín hiệu xuất hiện khi đang có lệnh (đảo chiều / vào lại).

## Việc tiếp theo

- Ảnh tab Inputs của chỉ báo (có thể có sẵn: ADX tối thiểu, hệ số ATR cho SL, R:R, số nến lịch sử…).
- Tìm điều kiện kích hoạt còn thiếu và công thức b17/b18; kiểm tra lại trên M1 (cùng công thức phải đúng).
- Kiểm tra repaint (file `repaint_summary.csv` sau 2–3 ngày chạy).
