# EA EURUSD Trend Pullback (MT5)

File: `MQL5/Experts/EURUSD_TrendPullback_H1.mq5`

## Chiến lược

1. **Xu hướng (H4):** EMA50 > EMA200 và giá đóng cửa > EMA200 → chỉ Buy.
   Ngược lại → chỉ Sell. Không rõ xu hướng → không giao dịch.
2. **Vào lệnh (H1, nến đã đóng):**
   - Buy: EMA20 > EMA50, râu nến hồi về chạm EMA20 (± 0.25 ATR), nến đóng
     tăng trên EMA20, không phá sâu dưới EMA50, RSI ≥ 50, ADX ≥ 20.
   - Sell: đối xứng.
3. **SL:** ngoài đáy/đỉnh 5 nến gần nhất + 0.5 ATR, giới hạn 10–40 pip
   (SL > 40 pip thì bỏ lệnh). **TP:** 2R.
4. **Quản lý lệnh:** hoà vốn (+1 pip) khi lãi 1R, trailing 1.5 ATR khi lãi
   1.5R, đóng lệnh nếu xu hướng H4 đảo chiều, đóng hết tối thứ Sáu.

## Quản lý vốn & bộ lọc

- Rủi ro 1%/lệnh (lot tính bằng `OrderCalcProfit`, đúng theo tiền tệ tài
  khoản), hoặc lot cố định qua `InpFixedLot`.
- Lỗ tối đa 3%/ngày → đóng lệnh và dừng tới hôm sau.
- Tối đa 2 lệnh mới/ngày, 1 vị thế cùng lúc.
- Spread tối đa 1.5 pip.
- Chỉ nhận lệnh 07:00–17:00 GMT (London + New York).
  **Quan trọng:** đặt `InpServerGMTOffset` đúng giờ server của sàn
  (vd. Exness = 0, IC Markets/Pepperstone = 2 mùa đông / 3 mùa hè).

## Cài đặt

1. Copy file vào `MQL5/Experts/`, mở MetaEditor, biên dịch (F7).
   (Môi trường tạo EA không có MetaTrader nên chưa compile thử — nếu có
   lỗi cú pháp hãy báo lại.)
2. Gắn vào chart EURUSD (khung nào cũng được; EA tự đọc H1/H4).
   Tên symbol có hậu tố (EURUSDm, EURUSD.r...) vẫn chạy được.
3. Backtest trong Strategy Tester với "Every tick based on real ticks",
   tối thiểu 2–3 năm dữ liệu. Tab Experts in dòng
   `[EURUSD-EA Summary]` khi kết thúc để thấy số tín hiệu/lệnh.

## Cảnh báo

Đây là chiến lược trend-pullback phổ biến, **chưa được backtest**. Các
tham số là mặc định hợp lý, không phải đã tối ưu. Không đảm bảo lợi nhuận —
hãy backtest và chạy demo nhiều tuần trước khi dùng tiền thật.
