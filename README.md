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

# DTC - v1.35 (port từ Pine Script sang MT5)

Bản chuyển đổi indicator TradingView **"DTC - v1.35"** (hệ thống 6 đường
EMA 30/35/40/45/50/60 xác định xu hướng, đổi màu theo trend, dashboard đa
khung thời gian, vẽ Entry/SL/TP1-4, và cảnh báo Telegram) sang MetaTrader 5.
Có 2 file, dùng độc lập với bộ EA ICT/SMC ở trên:

- `MQL5/Indicators/DTC_v135.mq5` — **Custom Indicator**, bám sát bản Pine
  Script gốc nhất có thể: 6 đường EMA đổi màu xanh/đỏ/xám theo trend, nhãn
  mũi tên BUY/SELL tại mọi điểm tín hiệu lịch sử, đường + nhãn Entry/SL/TP1-4
  cho tín hiệu gần nhất, dashboard 15M/30M/1H/4H/D ở góc trên-phải, và gửi
  cảnh báo Telegram (gọi thẳng Telegram Bot API bằng `WebRequest`, không cần
  `alert()` + webhook như trên TradingView), và bảng **thống kê Win Rate**
  (xem mục riêng bên dưới). **Không tự vào lệnh.**
- `MQL5/Experts/DTC_v135_EA.mq5` — **Expert Advisor** tự động giao dịch dựa
  trên đúng tín hiệu cắt/thẳng hàng EMA của indicator trên. Vì bản Pine Script
  gốc chỉ vẽ chart chứ không tự quản lý lệnh, EA bổ sung phần quản lý vị thế:
  - Vào lệnh Buy/Sell khi 6 EMA vừa thẳng hàng (giống hệt điều kiện
    `bullish_trend`/`bearish_trend` trong Pine Script), tính trên nến vừa
    đóng cửa (không dùng nến đang chạy, tránh repaint) — vào lệnh ngay tick
    đầu tiên của nến mới, không có độ trễ nhân tạo.
  - SL = `InpStopLossPercent` % giá vào lệnh; **chỉ dùng TP1 và TP2**
    (= SL × `InpTP1Multiplier`/`InpTP2Multiplier`, mặc định 1x/2x).
  - Mỗi tín hiệu mở **2 lệnh riêng biệt, khối lượng chia đều làm đôi**: 1 lệnh
    chốt tại TP1, 1 lệnh chốt tại TP2 (cùng SL ban đầu) — thay vì 1 lệnh rồi
    tự đóng từng phần, để sàn tự khớp TP cho từng lệnh, ổn định hơn khi mất
    kết nối/khởi động lại EA. Ngay khi giá chạm TP1, EA dời SL của lệnh TP2
    về giá vào lệnh (hoà vốn) — bật/tắt qua `InpBreakevenAfterTP1`.
  - Khi có tín hiệu ngược chiều, EA **luôn** đóng toàn bộ lệnh đang giữ và
    đảo chiều ngay trong cùng tick (không có tuỳ chọn tắt).
  - Khối lượng lệnh tính theo `InpRiskPercent` % số dư tài khoản trên
    khoảng cách SL (tính trên tổng 2 lệnh), chuẩn hoá theo bước khối lượng
    của sàn.
  - **Buffer vào lệnh**: `InpSlippagePoints` (mặc định 20 điểm) là độ trượt
    giá tối đa EA chấp nhận khi khớp lệnh thị trường, để lệnh không bị từ
    chối (invalid price) khi giá chạy nhanh đúng lúc EA đặt lệnh.
    `InpMaxSpreadPoints` (mặc định 0 = không giới hạn) cho phép bỏ qua tín
    hiệu nếu spread hiện tại quá rộng, tránh vào lệnh với giá xấu.
  - Dashboard đa khung thời gian trong script gốc **chỉ mang tính hiển thị**,
    không dùng làm bộ lọc vào lệnh — EA giữ đúng hành vi này (đúng theo yêu
    cầu "giống chỉ báo gốc nhất có thể"), không bắt buộc các khung MTF phải
    đồng thuận mới vào lệnh.
  - **Bảng lợi nhuận (P&L) trên chart**: góc dưới-trái (`InpPnLCorner`) hiện
    lợi nhuận **hôm nay** và **tháng này** (tính từ deal history thật của
    tài khoản, chỉ lọc theo `InpMagicNumber` của EA này — không tính lệnh
    của EA/indicator khác trên cùng tài khoản), tự cập nhật mỗi 20 giây.
    Tắt bằng `InpShowPnLTable`.
  - **Thông báo Telegram theo ngày/tháng**: khi `InpTelegramDayMonthSummary`
    bật (mặc định bật, cần `InpTelegramEnabled` + Bot Token/Chat ID đã cấu
    hình), ngay khi một ngày/tháng vừa kết thúc, EA tự gửi 1 tin nhắn tổng
    kết lời/lỗ **của đúng ngày/tháng vừa qua** — độc lập với thông báo mỗi
    lần vào lệnh.

## Bảng thống kê Win Rate (indicator)

`DTC_v135.mq5` hiển thị thêm một bảng nhỏ ngay dưới dashboard MTF (bật/tắt
bằng `InpShowStatsTable`), liệt kê % tín hiệu lịch sử đã chạm từng mốc:

```
Win Rate (n=42)
TP1  71.4%  (30)
TP2  47.6%  (20)
TP3  28.6%  (12)
TP4  16.7%  (7)
SL   28.6%  (12)
```

Cách tính: với mỗi tín hiệu Long/Short trong lịch sử, indicator tự mô
phỏng tiến về sau trên đúng dữ liệu giá của chart (dùng high/low từng nến)
để xem giá chạm SL hay TP1 trước; nếu chạm TP1 trước, SL giả định được dời
về hoà vốn rồi tiếp tục xét TP2, v.v. Một tín hiệu được tính là **thắng ở
mức TPx** nếu giá từng chạm tới đó, bất kể sau đó lệnh dừng ở hoà vốn hay đi
tiếp; **SL** chỉ tính khi giá chạm SL gốc *trước khi* từng chạm TP1 (thua
toàn bộ). Bảng này vẫn thống kê đủ TP1-TP4 để bám sát 4 mốc mà bản Pine
Script gốc vẽ ra — bản EA (bên dưới) chỉ thực sự giao dịch TP1/TP2 nên số
liệu TP3/TP4 ở đây mang tính tham khảo xu hướng đi xa của giá, không phản
ánh lệnh thật của EA. Tín hiệu quá mới, giá chưa kịp đi đến đâu, sẽ tạm
không được tính vào `n` cho tới khi có đủ nến để phân định
kết quả. Đây là thống kê dựa trên đúng lịch sử giá của chart đang mở —
không phải kết quả backtest chính thức của Strategy Tester, và nếu SL/TP
chạm cùng một nến thì mặc định coi SL chạm trước (giả định an toàn/thận
trọng vì không có dữ liệu tick trong lịch sử OHLC).

## Những khác biệt so với script Pine gốc

1. Input `Stop-Loss Lookback` (Tiny/Small/Mid/Large) trong script gốc tính
   ra `sl_length` nhưng **không được dùng ở đâu khác** trong code Pine (biến
   `lowest_low`/`highest_high` tính ra rồi bỏ không) — coi như dead code nên
   không port sang, không ảnh hưởng gì đến hành vi hiển thị hay giao dịch.
2. TradingView gửi Telegram qua cơ chế `alert()` + webhook URL (đã chứa sẵn
   Bot Token) do người dùng dán vào ô Alert; MT5 không có khái niệm này nên
   indicator/EA gọi thẳng Telegram Bot API bằng `WebRequest`, cần thêm input
   **Bot Token** (lấy từ @BotFather) chứ không chỉ Chat ID.
3. Script gốc chỉ vẽ Entry/SL/TP1-4 — không tự đóng/chốt lệnh, không đảo
   chiều. EA chỉ giao dịch **TP1 và TP2** (bỏ TP3/TP4), mở 2 lệnh riêng biệt
   khối lượng chia đều thay vì 1 lệnh rồi tự chốt từng phần, tự dời SL về
   hoà vốn sau TP1, và luôn đảo chiều khi có tín hiệu ngược — toàn bộ phần
   quản lý vị thế này hoàn toàn mới so với bản Pine Script (theo yêu cầu khi
   tạo EA).

## Cài đặt

1. Copy `DTC_v135.mq5` vào `MQL5/Indicators/` và/hoặc `DTC_v135_EA.mq5` vào
   `MQL5/Experts/`, mở MetaEditor, biên dịch (F7). Môi trường này không có
   MetaTrader để compile/test — kiểm tra kỹ lỗi cú pháp trước khi chạy thật.
2. Nếu bật Telegram Alert: vào **Tools → Options → Expert Advisors**, tick
   "Allow WebRequest for listed URL" và thêm
   `https://api.telegram.org` vào danh sách, rồi điền Bot Token + Chat ID
   vào input của indicator/EA.
3. Gắn EA/indicator lên đúng symbol + khung thời gian bạn muốn giao dịch
   (không cố định XAUUSD như bộ EA ICT — hệ EMA này dùng được trên mọi
   symbol/khung giống bản Pine Script gốc `overlay=true`).
4. Backtest EA trong Strategy Tester (Every tick based on real ticks) và
   chạy demo nhiều tuần trước khi cân nhắc live; không có gì đảm bảo lợi
   nhuận, tự chịu trách nhiệm rủi ro khi giao dịch thật.
