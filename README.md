# XAUUSD ICT/SMC EA (MT5, khung M5)

EA tự động hoá phương pháp ICT (Inner Circle Trader / Smart Money Concepts)
theo đúng tài liệu bạn cung cấp: killzone, liquidity sweep, Judas Swing, cấu
trúc thị trường (BOS/CHoCH), Order Block + FVG, Premium/Discount/OTE, ICT
Score, và 4 setup giao dịch cụ thể (A/B/C/D). File EA:
`MQL5/Experts/XAUUSD_ICT_M5.mq5`.

Khung giao dịch chính: **M5** (theo yêu cầu của bạn). Bias lớn: **H4**.
Thanh khoản ngày/tuần lấy từ **D1/W1**.

## Bốn setup đã lập trình

- **Setup A — London Judas Reversal**: mua khi có sweep Asian Low + Judas
  trong killzone London, xác nhận bằng CHoCH tăng + vùng +OB/+FVG phản ứng,
  chỉ vào khi vẫn đang ở discount (<50%).
- **Setup B — NY AM Continuation**: đánh tiếp xu hướng đã hình thành ở
  London (Score ≥60/≤40 + cùng chiều cấu trúc) khi giá pullback về vùng
  +OB/+FVG của leg BOS gần nhất, hoặc khi có Judas quét range London rồi
  quay lại. Tự đóng lệnh nếu chưa đạt mục tiêu trước giờ cắt (mặc định
  11:00 NY).
- **Setup C — PDH/PDL Sweep Reversal**: đảo chiều khi giá quét PDH (ở
  premium ≥70%) hoặc PDL (ở discount ≤30%), xác nhận CHoCH ngược + ICT
  Score cực đoan.
- **Setup D — Turtle Soup**: bẫy tại EQH/EQL — vào lệnh khi giá đóng cửa
  phá ngược lại đúng hướng cây nến vừa quét mức đó.

Toàn bộ tín hiệu và lệnh được đánh giá **khi nến M5 đóng cửa** (không dùng
dữ liệu intrabar), đảm bảo tính xác định (deterministic) và không repaint —
tránh lặp lại vấn đề "backtest chạy xong nhưng không rõ vì sao 0 lệnh" mà
bạn gặp với bản EA trước.

## Quản lý vốn & rủi ro (theo đúng bảng "Quản lý lệnh, rủi ro" trong tài liệu)

- Rủi ro mỗi lệnh: `InpRiskPercent` (mặc định 0.75%, trong khoảng 0.5-1%
  khuyến nghị).
- R:R tối thiểu: `InpMinRR_TP1` (1.5) và `InpMinRR_TP2` (2.0) — lệnh bị
  huỷ nếu không đạt.
- Tối đa `InpMaxTradesPerKZ` (2) lệnh mỗi killzone.
- Chốt 50% khối lượng tại TP1 (thanh khoản gần nhất), dời SL về hoà vốn,
  phần còn lại chạy tới TP2 (PDH/PWH hoặc PDL/PWL).
- Thoát ngay nếu xuất hiện CHoCH ngược hướng lệnh đang giữ.
- Giới hạn lỗ ngày `InpMaxDailyLossPercent` (3%) và khoá sau
  `InpMaxConsecLosses` lệnh thua liên tiếp (`InpPauseMinutes` phút).
- Lọc tin: không vào lệnh trong `InpNewsBlackoutMinBefore` phút trước
  `InpNewsHourNY` (mặc định 08:30 NY).

## Những đơn giản hoá so với tài liệu gốc (đọc kỹ trước khi tin tưởng số liệu)

Tài liệu bạn gửi mô tả một **indicator/dashboard** trực quan (không phải
EA tự vào lệnh sẵn). Để tự động hoá, mình đã lược bỏ/đơn giản hoá:

1. **Không vẽ chart, không dashboard, không Telegram** — các tham số thuần
   thị giác trong tài liệu (MaxSwingLiq, MaxOB/MaxFVG, HideFilled,
   ExtendBars, Theme, vị trí dashboard, TgEnable...) không ảnh hưởng tới
   quyết định giao dịch nên bị loại khỏi EA. Có thể bổ sung cảnh báo
   Telegram sau nếu bạn cần.
2. **H4 bias** chỉ tính cấu trúc (BOS/CHoCH) + Premium/Discount đơn giản,
   không dựng OB/FVG riêng trên H4 như bản gốc.
3. **ICT Score** là công thức heuristic tự xây (cấu trúc + vị trí P/D +
   có vùng entry tươi hay không + đang trong killzone), **không phải**
   công thức độc quyền của indicator gốc — chỉ dùng làm bộ lọc phụ theo
   đúng ngưỡng ≥60/≤40 mà tài liệu mô tả.
4. **Setup D** (Turtle Soup) đáng lẽ xác nhận bằng CHoCH ở khung nhỏ hơn
   M5; vì M5 đã là khung nền của EA nên mình dùng chính cây nến vừa quét
   phá ngược lại làm xác nhận, thay vì mở thêm một khung M1 phụ.
5. **Timezone NY**: mặc định dùng offset cố định `InpServerToNY_Hours=7`
   (đúng cho các sàn dịch giờ server theo DST Mỹ, giữ cách NY 7 tiếng
   quanh năm — ví dụ ICMarkets, Pepperstone). Nếu broker của bạn dùng GMT
   cố định (như Exness GMT+0), đặt `InpBrokerFixedNYOffset=false` và khai
   `InpServerGMTOffsetHours`; EA sẽ tự tính DST Mỹ (độ chính xác theo
   ngày, không theo giờ chính xác 2h sáng — sai số tối đa vài giờ đúng
   vào ngày chuyển DST, không đáng kể với khung M5).
6. **Lọc tin tức** là một khung giờ cố định thủ công (mặc định quanh 08:30
   NY), không phải lịch kinh tế trực tiếp.
7. **Entry giá**: vào lệnh market tại giá hiện tại khi nến xác nhận vừa
   đóng cửa, thay vì đặt lệnh chờ (limit) đúng biên vùng như mô tả — đơn
   giản hoá để tránh phải quản lý vòng đời lệnh chờ/hết hạn.

## Cài đặt & bắt buộc backtest trước khi chạy thật

1. Copy file vào `MQL5/Experts/`, mở MetaEditor, biên dịch (F7). Mình
   không có MetaTrader trong môi trường này để compile/test — bạn cần tự
   sửa nếu trình biên dịch báo lỗi cú pháp.
2. Gắn EA vào chart **XAUUSDr, khung M5** (EA dùng `_Symbol` nên chạy
   đúng theo symbol của sàn bạn).
3. Backtest trong Strategy Tester với **Every tick based on real ticks**,
   dữ liệu lịch sử đủ dài cho D1/W1/H4 (Tester tự tải các khung phụ khi
   cần). EA có in tổng kết ở tab Experts khi kết thúc chạy
   (`[ICT-EA Summary] bars=... sweeps=... zones=... trades...`) để bạn
   nhanh chóng thấy được có tín hiệu phát sinh hay không, tránh lặp lại
   tình huống "0 lệnh không rõ lý do".
4. Backtest/demo nhiều tuần trước khi cân nhắc live, và tinh chỉnh lại
   các ngưỡng (PivLen, DispATR, EqTolATR, ICT Score threshold...) theo dữ
   liệu thực tế của Gold M5 trên tài khoản của bạn.

## Cảnh báo rủi ro

Đây là bản tự động hoá theo tài liệu, không phải bản sao chính xác của
indicator ICT Full Suite gốc — có nhiều điểm đã đơn giản hoá như liệt kê
ở trên. EA không đảm bảo lợi nhuận; luôn kiểm thử kỹ trên demo và chỉ
giao dịch với số vốn bạn chấp nhận rủi ro mất.

---

# Fibonacci + Bollinger Bands Swing EA (MT5, mọi symbol/timeframe)

EA tự động hoá chiến lược "Vào lệnh BUY/SELL kết hợp Fibonacci + Bollinger
Bands" theo đúng 5 bước trong tài liệu bạn gửi (xu hướng → giá hồi về vùng
Fib 50%–61.8% → chạm Band trên/dưới → nến xác nhận đảo chiều → vào lệnh).
File EA: `MQL5/Experts/FiboBB_Swing_EA.mq5`.

Không giới hạn theo một symbol/khung giờ cố định — gắn EA vào chart nào
cũng được, chọn khung làm việc qua input `InpTimeframe` (mặc định M15).

## Logic chính

- **Xu hướng**: xác định qua cấu trúc swing high/low (break of structure) —
  tăng khi giá đóng cửa phá swing high gần nhất chưa bị phá, giảm khi phá
  swing low gần nhất.
- **Leg Fibonacci**: lấy cặp swing gần nhất theo đúng chiều xu hướng (tăng:
  swing low → swing high gần nhất; giảm: swing high → swing low gần nhất)
  làm gốc 0%–100% để tính các mức 38.2/50/61.8/78.6% giống hệt cách vẽ
  trong tài liệu (0% tại đỉnh leg, 100% tại đáy leg).
- **Vùng hồi đẹp**: `InpFiboZoneNear` (0.5) – `InpFiboZoneFar` (0.618).
  Nến xác nhận phải có đuôi chạm vào vùng này (và chạm/xuyên Band
  trên/dưới) rồi đóng cửa trở lại phía trong/ngoài vùng theo đúng hướng
  xu hướng.
- **Nến xác nhận đảo chiều**: Pin Bar, Engulfing, Morning/Evening Star
  (bật/tắt riêng từng loại qua input). Chỉ vào lệnh khi nến đóng cửa.
- **Bộ lọc đi ngang**: bỏ qua tín hiệu khi độ rộng Band
  `(upper-lower)/middle*100` dưới `InpMinBandWidthPct`, hoặc leg Fibonacci
  quá ngắn so với ATR (`InpMinLegATR`) — tránh vào lệnh khi thị trường
  chưa có xu hướng rõ ràng.
- **Lọc tin tức**: hai khung giờ chặn theo giờ NY (mặc định quanh 08:30 NY
  cho NFP/CPI và 14:00 NY cho FOMC), có thể tắt/chỉnh qua input.

## Quản lý vốn & rủi ro (đúng bảng "Quản lý lệnh & chốt lời" trong tài liệu)

- Rủi ro mỗi lệnh: `InpRiskPercent` (mặc định 1.0%, trong khoảng 1-2%
  khuyến nghị).
- **Entry**: market tại giá hiện tại khi nến xác nhận vừa đóng cửa.
- **Stop Loss**: dưới đáy leg/Band dưới (BUY) hoặc trên đỉnh leg/Band trên
  (SELL), cộng thêm đệm `InpSLBufferATR × ATR` (mặc định 0.75, khuyến nghị
  0.5-1 ATR) — đúng như tài liệu "đặt SL dưới đáy/trên đỉnh gần nhất hoặc
  dưới/trên Band".
- **Take Profit 3 tầng, chốt từng phần TP1 (50%) – TP2 (30%) – TP3 (20%)**
  (đúng tỉ lệ trong tài liệu):
  - TP1 = đỉnh/đáy gần nhất của leg — đóng `InpTP1ClosePct`% khối lượng
    gốc (mặc định 50%), dời SL về hoà vốn.
  - TP2 = Fibonacci Extension 127.2% — đóng thêm `InpTP2ClosePct`% (mặc
    định 30%), dời SL lên/xuống TP1.
  - TP3 = Fibonacci Extension 161.8% — 20% khối lượng còn lại chạy tới
    đây (đặt sẵn làm TP của lệnh khi vào).
- Thoát sớm toàn bộ nếu xuất hiện nến xác nhận ngược hướng trước khi đạt
  TP1 (tránh giữ lệnh khi tín hiệu đã bị vô hiệu).
- Giới hạn lỗ ngày `InpMaxDailyLossPercent` (3%) và khoá sau
  `InpMaxConsecLosses` lệnh thua liên tiếp (`InpPauseMinutes` phút).

## 4 thời điểm tránh giao dịch (theo tài liệu) — cách EA xử lý

1. **Tin tức mạnh (NFP, CPI, FOMC...)** → hai khung giờ chặn
   `InpNewsHour1`/`InpNewsHour2` (NY time).
2. **Thị trường đi ngang** → bộ lọc độ rộng Band `InpMinBandWidthPct`.
3. **Biến động quá thấp** → bộ lọc leg tối thiểu theo ATR `InpMinLegATR`.
4. **Không có tín hiệu xác nhận rõ ràng** → chỉ vào lệnh khi có đủ nến xác
   nhận (Pin Bar/Engulfing/Star) đóng cửa đúng vùng Fib + chạm Band.

## Những đơn giản hoá so với tài liệu gốc

1. Tài liệu là một hướng dẫn thao tác tay (đọc chart, kẻ Fibonacci bằng
   tay); EA tự động kẻ Fibonacci dựa trên cặp swing high/low gần nhất
   theo đúng xu hướng — có thể lệch nhịp so với cách bạn tự kẻ bằng mắt
   trong vài tình huống cấu trúc phức tạp.
2. "Không vào lệnh khi thị trường đi ngang" được xử lý bằng bộ lọc độ
   rộng Band + độ dài leg tối thiểu, không phải nhận diện hình dạng
   sideway trực quan.
3. Lọc tin tức là khung giờ cố định thủ công (không phải lịch kinh tế
   trực tiếp) — cần tự chỉnh ngày/giờ theo lịch tin thực tế.
4. Mỗi thời điểm chỉ giữ tối đa 1 lệnh (theo `InpMagicNumber`) để đơn giản
   hoá quản lý TP1/TP2/TP3 theo % khối lượng gốc.

## Cài đặt & bắt buộc backtest trước khi chạy thật

1. Copy file vào `MQL5/Experts/`, mở MetaEditor, biên dịch (F7). Môi
   trường này không có MetaTrader để compile/test — tự sửa nếu trình
   biên dịch báo lỗi cú pháp.
2. Gắn EA vào chart symbol/khung bạn muốn giao dịch, chỉnh `InpTimeframe`
   nếu khung chart khác khung muốn phân tích.
3. Backtest trong Strategy Tester với **Every tick based on real ticks**
   trước khi demo/live, tinh chỉnh lại `InpPivLen`, vùng Fibonacci,
   `InpMinBandWidthPct`, `InpMinLegATR` theo đặc tính symbol bạn chạy.

## Cảnh báo rủi ro

EA không đảm bảo lợi nhuận; luôn kiểm thử kỹ trên demo và chỉ giao dịch
với số vốn bạn chấp nhận rủi ro mất.
