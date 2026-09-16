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

## Thông báo Telegram (EA)

EA giờ tự bắn Telegram ở các mốc quan trọng (không chỉ indicator vẽ vùng
mới có, để "hoàn toàn" cả EA lẫn indicator đều báo được):

- Vào lệnh: tên setup, hướng BUY/SELL, entry/SL/TP1/TP2, khối lượng.
- Đóng lệnh: kết quả lãi/lỗ của deal vừa đóng.
- Bị tạm khoá sau `InpMaxConsecLosses` lệnh thua liên tiếp: thời điểm mở
  khoá lại.

Bật bằng `InpEnableTelegram = true` + `InpTelegramToken` + `InpTelegramChatID`
(cùng cách lấy token/chat id và whitelist `https://api.telegram.org` trong
Tools → Options → Expert Advisors, xem chi tiết ở mục Telegram của
indicator bên dưới — dùng chung 1 bot cho cả EA và indicator cũng được,
chỉ cần dùng cùng token/chat id). `InpTelegramTestOnInit = true` sẽ gửi
1 tin xác nhận ngay khi gắn EA vào chart.

## Những đơn giản hoá so với tài liệu gốc (đọc kỹ trước khi tin tưởng số liệu)

Tài liệu bạn gửi mô tả một **indicator/dashboard** trực quan (không phải
EA tự vào lệnh sẵn). Để tự động hoá, mình đã lược bỏ/đơn giản hoá:

1. **Không vẽ chart, không dashboard** — các tham số thuần thị giác trong
   tài liệu (MaxSwingLiq, MaxOB/MaxFVG, HideFilled, ExtendBars, Theme, vị
   trí dashboard...) không ảnh hưởng tới quyết định giao dịch nên bị loại
   khỏi EA. Phần vẽ vùng + báo Telegram nay có ở indicator riêng
   `MQL5/Indicators/XAUUSD_Entry_Zones.mq5` (xem mục bên dưới) — EA vẫn
   tự vào lệnh độc lập, không phụ thuộc indicator này.
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

## Indicator khoanh vùng Buy/Sell + báo Telegram (MQL5/Indicators/XAUUSD_Entry_Zones.mq5)

Đây là **indicator riêng, không tự vào lệnh** — chỉ vẽ vùng Order Block/FVG
(dùng đúng logic displacement như EA ở trên) lên chart và bắn thông báo
Telegram khi có vùng mới hoặc khi giá quay lại phản ứng trong vùng. Gắn
được lên **bất kỳ symbol/khung thời gian nào** đang mở (ví dụ XAUUSD H1
như ảnh bạn gửi), không giới hạn M5 như EA.

- Vùng **xanh (Buy)**: Order Block/FVG tăng — khoanh vùng để tìm entry BUY.
- Vùng **đỏ (Sell)**: Order Block/FVG giảm — khoanh vùng để tìm entry SELL.
- Khi nến đóng cửa tạo vùng mới → bắn Telegram "New zone" (nếu bật).
- Khi giá quay lại chạm vùng còn "fresh" lần đầu → bắn Telegram gợi ý
  BUY/SELL kèm SL nên đặt ngoài mép vùng (nếu bật).
- Load lại `InpHistoryBars` (mặc định 500) nến lịch sử ngay khi gắn vào
  chart để thấy vùng cũ luôn, không phải đợi vùng mới hình thành.

### Cài đặt Telegram

1. Tạo bot: chat với `@BotFather` trên Telegram, gõ `/newbot`, lấy **token**
   dạng `123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.
2. Lấy **chat id**: nhắn thử một tin bất kỳ cho bot vừa tạo, sau đó mở
   `https://api.telegram.org/bot<TOKEN>/getUpdates` trên trình duyệt, tìm
   trường `"chat":{"id":...}` — đó là chat id (số, có thể âm nếu là group).
3. Trong MT5: **Tools → Options → Expert Advisors** → tick "Allow WebRequest
   for listed URL" → thêm `https://api.telegram.org`. Bắt buộc, nếu không
   indicator sẽ log lỗi `WebRequest failed` và không gửi được gì.
4. Gắn indicator vào chart, nhập `InpTelegramToken`, `InpTelegramChatID`,
   bật `InpEnableTelegram = true`. Để `InpTelegramTestOnInit = true` để
   nhận ngay 1 tin nhắn test xác nhận đã kết nối đúng.

Lưu ý: nội dung tin nhắn chỉ dùng tiếng Anh/ASCII thuần (không dấu) vì
việc mã hoá URL cho ký tự tiếng Việt có dấu trong MQL5 phức tạp hơn nhiều
so với ASCII — mình đã cố tình bỏ qua để tránh gửi tin bị lỗi ký tự.

Đây cũng chỉ là bản đơn giản hoá (cùng các giới hạn như EA ở mục "Những
đơn giản hoá" phía trên): không có cấu trúc/BOS/CHoCH, không lọc killzone
hay ICT Score — thuần vẽ vùng entry từ displacement + OB/FVG và báo động.
Test kỹ trên demo trước khi dùng để ra quyết định giao dịch thật.

## Cảnh báo rủi ro

Đây là bản tự động hoá theo tài liệu, không phải bản sao chính xác của
indicator ICT Full Suite gốc — có nhiều điểm đã đơn giản hoá như liệt kê
ở trên. EA không đảm bảo lợi nhuận; luôn kiểm thử kỹ trên demo và chỉ
giao dịch với số vốn bạn chấp nhận rủi ro mất.
