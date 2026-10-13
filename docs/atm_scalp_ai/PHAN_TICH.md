# DTRADE$ – ATM SCALP AI: phân tích buffer

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

## Lần 2 — thêm dữ liệu M1 tài khoản demo

Dữ liệu: `ATM Demo_ctxbars_XAUUSDm_M1.csv` (Exness-MT5Trial7, XAUUSDm M1, 2024-10-04 → 2026-10-13, 712 648 nến;
logger bản cũ nên chỉ có b0–b15). Script mới: `m1_overview.py`, `trigger_hunt.py`, `trigger2.py`
(file M1 lớn: đọc bằng `load_m1.py`).

- **Mọi công thức trên M5 đều đúng y hệt trên M1**: EMA 9/14/21/34/55, ATR(14) Wilder, SL = 3×ATR,
  TP = 1R/2R/3R, ENTRY = close. → công thức không phụ thuộc khung.
- **Chỉ báo chỉ ghi tín hiệu vào buffer cho ≈ 7 500 nến gần nhất** trên mọi khung và cả demo lẫn real
  (M5: 26 ngày, M1: 5.6 ngày). "52 013 lệnh / từ 2014" trên bảng là backtest nội bộ, không xuất ra buffer.
  Tổng hiện có: 143 tín hiệu (M1 67 + M5 76).
- Điều kiện cần thứ 6 (100% tín hiệu ở cả M1 và M5, nền khác ≈ 51%): **close vượt đỉnh nến trước** (BUY) /
  **close thủng đáy nến trước** (SELL).
- 6 điều kiện bao 143/143 tín hiệu. Khi đang không có lệnh, còn 79 (M1) / 92 (M5) nến thỏa 6 điều kiện mà
  không có tín hiệu → độ chính xác ≈ 40–45%, vẫn thiếu điều kiện. Dấu hiệu: các nến bị bỏ qua thường liền nhau
  (ví dụ 05:21–05:30), ADX và thân nến không giải thích được → nghi có điểm số tổng hợp ("AI score"),
  bộ lọc giờ/khối lượng (b17/b18) hoặc khoảng nghỉ.
- 16/67 (M1) và 8/76 (M5) tín hiệu xuất hiện khi đang có lệnh, phần lớn là **đảo chiều** (đang BUY → SELL).
- Hướng lấy thêm tín hiệu ngay: vì công thức không phụ thuộc khung, gắn chỉ báo trên nhiều khung
  (M1, M2, M3, M5, M10, M15…) — mỗi khung cho thêm ≈ 70 tín hiệu trong 7 500 nến cuối.

## Việc tiếp theo

- Ảnh tab Inputs của chỉ báo (có thể có sẵn: ADX tối thiểu, hệ số ATR cho SL, R:R, số nến lịch sử…).
- Tìm điều kiện kích hoạt còn thiếu và công thức b17/b18; kiểm tra lại trên M1 (cùng công thức phải đúng).
- Kiểm tra repaint (file `repaint_summary.csv` sau 2–3 ngày chạy).
