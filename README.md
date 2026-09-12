# XAUUSD M1 Price-Action Scalper (MT5)

EA scalping XAUUSD trên khung M1 cho MetaTrader 5, dùng chiến lược
price-action (mẫu nến) kết hợp lọc xu hướng đa khung và quản lý vốn
theo % rủi ro cố định. File EA: `MQL5/Experts/XAUUSD_M1_PA_Scalper.mq5`.

## Ý tưởng chiến lược

1. **Lọc xu hướng (bias):** so sánh giá đóng cửa khung `InpTrendTF`
   (mặc định M15) với EMA200 trên khung đó. Giá trên EMA200 → chỉ tìm
   lệnh mua; giá dưới EMA200 → chỉ tìm lệnh bán. Mục đích: tránh đánh
   ngược xu hướng lớn trong lúc M1 nhiễu.
2. **Vùng vào lệnh (pullback):** trên M1, giá phải kéo về gần EMA20
   (`InpFastEMA`) trong phạm vi `InpPullbackATRMult × ATR`.
3. **Tín hiệu vào lệnh (mẫu nến):** tại vùng pullback đó, nến đóng cửa
   gần nhất (nến vừa đóng) phải là pin bar hoặc engulfing đúng hướng
   xu hướng (bullish cho lệnh mua, bearish cho lệnh bán).
4. **Vào lệnh** khi nến M1 mới đóng cửa và đủ điều kiện — mỗi nến chỉ
   xét tín hiệu một lần.

## Quản lý vốn (quan trọng với tài khoản $1000)

- `InpRiskPercent` (mặc định 1%): số tiền rủi ro mỗi lệnh = % số dư.
  Khối lượng lệnh (lot) được tính tự động từ khoảng cách SL và risk
  này — **không** dùng lot cố định.
- SL = `ATR(14) × InpATR_SL_Multiplier`, nới thêm nếu đáy/đỉnh nến tín
  hiệu xa hơn, và không nhỏ hơn stop level của sàn.
- TP = SL × `InpRiskRewardRatio` (mặc định 1.5R).
- Trailing stop kích hoạt sau khi lệnh đạt `InpTrailingStartR × R`,
  kéo theo `InpTrailingStepATR × ATR`.
- **Giới hạn lỗ ngày:** `InpMaxDailyLossPercent` (mặc định 3%) — chạm
  mức này thì EA ngừng vào lệnh mới đến hết ngày (giờ server).
- **Khóa sau chuỗi thua:** `InpMaxConsecLosses` lệnh thua liên tiếp →
  tạm dừng `InpPauseMinutes` phút.
- **Lọc spread:** `InpMaxSpreadPoints` — bỏ qua tín hiệu nếu spread
  hiện tại quá rộng (gold hay giãn spread lúc tin tức/đầu phiên).
- **Lọc phiên:** chỉ giao dịch trong khung giờ `InpSessionStartHour`–
  `InpSessionEndHour` (giờ server của sàn), mặc định set quanh phiên
  giao Âu–Mỹ vì thanh khoản tốt hơn cho scalp M1.
- Luôn chỉ giữ **1 lệnh** (theo magic number) — không nhồi lệnh, không
  martingale/grid.

## Cài đặt

1. Mở MetaEditor trong MT5 → copy file `.mq5` vào thư mục
   `MQL5/Experts/` của terminal (hoặc mở trực tiếp file này qua
   MetaEditor rồi Compile — F7).
2. Kéo EA vào chart **XAUUSDr, khung M1** (EA dùng `_Symbol` nên tự
   chạy đúng theo tên symbol của sàn bạn, kể cả có hậu tố "r").
3. Bật "Algo Trading". Kiểm tra lại toàn bộ input trước khi chạy thật.

## Trước khi chạy thật — bắt buộc backtest/demo

- Mình không có MetaTrader trong môi trường này để compile/backtest,
  nên **bạn cần tự kiểm tra trong Strategy Tester** với:
  - Model "Every tick based on real ticks" (M1 rất nhạy với chất
    lượng dữ liệu tick).
  - Dữ liệu lịch sử của đúng symbol `XAUUSDr` từ sàn của bạn.
  - Bật spread/commission thực tế của tài khoản (hậu tố "r" thường là
    tài khoản Raw Spread có commission riêng — nhớ cộng vào test).
- Chạy demo tối thiểu vài tuần trước khi chuyển sang tài khoản thật.
- Với vốn $1000 và scalp M1, chi phí spread + commission chiếm tương
  đối lớn trên mỗi lệnh nhỏ — nên tinh chỉnh `InpMaxSpreadPoints` và
  `InpRiskPercent` sát với điều kiện sàn thực tế trước khi tăng rủi ro.

## Cảnh báo rủi ro

EA này không đảm bảo lợi nhuận. Mẫu nến/EMA là công cụ thống kê, không
phải quy luật chắc chắn; hiệu suất quá khứ (kể cả backtest) không đảm
bảo kết quả tương lai. Luôn kiểm thử kỹ và chỉ giao dịch với số vốn bạn
chấp nhận được rủi ro mất.
