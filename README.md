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

# DTC - v1.38 (port từ Pine Script "DTC - v1.35" sang MT5)

Bản chuyển đổi indicator TradingView **"DTC - v1.35"** (hệ thống 6 đường
EMA 30/35/40/45/50/60 xác định xu hướng, đổi màu theo trend, dashboard đa
khung thời gian, vẽ Entry/SL/TP, và cảnh báo Telegram) sang MetaTrader 5.
Toàn bộ giao diện (Inputs, dashboard, bảng, tin nhắn Telegram, log) đã
được Việt hoá có dấu. Có 2 file, dùng độc lập với bộ EA ICT/SMC ở trên:

- `MQL5/Indicators/DTC_v138.mq5` — **Custom Indicator**, bám sát bản Pine
  Script gốc nhất có thể: 6 đường EMA đổi màu xanh/đỏ/xám theo trend, nhãn
  mũi tên MUA/BÁN tại mọi điểm tín hiệu lịch sử, đường + nhãn "VÀO LỆNH"/
  SL/TP1/TP2 cho tín hiệu gần nhất, dashboard 15M/30M/1H/4H/D ở góc
  trên-trái, và gửi cảnh báo Telegram (gọi thẳng Telegram Bot API bằng
  `WebRequest`, không cần `alert()` + webhook như trên TradingView), cùng
  bảng **Thống Kê Tỷ Lệ Thắng** (xem mục riêng bên dưới). **Không tự vào
  lệnh.**
- `MQL5/Experts/DTC_v138_EA.mq5` — **Expert Advisor** tự động giao dịch dựa
  trên đúng tín hiệu cắt/thẳng hàng EMA của indicator trên. Vì bản Pine Script
  gốc chỉ vẽ chart chứ không tự quản lý lệnh, EA bổ sung phần quản lý vị thế:
  - Vào lệnh Mua/Bán khi 6 EMA vừa thẳng hàng (giống hệt điều kiện
    `bullish_trend`/`bearish_trend` trong Pine Script), tính trên nến vừa
    đóng cửa (không dùng nến đang chạy, tránh repaint) — vào lệnh ngay tick
    đầu tiên của nến mới, không có độ trễ nhân tạo.
  - SL = `InpStopLossPercent` % giá vào lệnh; **chỉ dùng TP1 và TP2**
    (= SL × `InpTP1Multiplier`/`InpTP2Multiplier`, mặc định 1x/2x).
  - **Bộ lọc giảm nhiễu**: `InpMinRibbonWidthATR` (mặc định 0.3) — bỏ qua
    tín hiệu nếu độ rộng ribbon (khoảng cách giữa EMA1 và EMA6) tại nến xác
    nhận nhỏ hơn `InpMinRibbonWidthATR` × ATR(14). Mục đích là lọc bớt tín
    hiệu sinh ra khi 6 EMA vừa mới tách nhau rất mảnh lúc giá đi ngang (dễ
    quay đầu ngay sau đó/whipsaw), chỉ vào lệnh khi xu hướng đã thật sự rõ
    ràng. Đặt về `0` để tắt hẳn bộ lọc (dùng lại đúng hành vi gốc). Bộ lọc
    này áp dụng **giống hệt trên cả indicator lẫn EA** để tín hiệu hiển thị
    trên chart và tín hiệu EA thực sự trade luôn khớp nhau.
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
  - **Test kênh Telegram**: bật `InpTestTelegramOnStart` rồi gắn lại EA —
    nó gửi ngay 1 tin MUA [TEST] + 1 tin BÁN [TEST] (giá giả, không phải
    lệnh thật) để bạn kiểm tra Bot Token/Chat ID đã đúng chưa, khỏi phải
    đợi tín hiệu thật xuất hiện.
  - **Bảng lịch sử vào/ra lệnh**: góc dưới-phải (`InpTradeLogCorner`), hiện
    tối đa `InpTradeLogRows` dòng gần nhất (mặc định 8, tối đa 15) — mỗi
    dòng là 1 lệnh thật đã đóng của đúng EA này (lọc theo `InpMagicNumber`,
    lấy từ deal history thật), gồm **Giờ / Loại (MUA-BÁN) / Kết quả
    (TP1-TP2-SL-Đóng tay) / Lãi-Lỗ**, vẽ dạng bảng có khung nền xen kẽ màu
    (giống kiểu bảng của các indicator MIK/EMACrossClone khác trong
    Navigator) thay vì chỉ chữ chạy dài như bảng P&L. Vì mỗi tín hiệu mở 2
    lệnh (TP1 + TP2) nên mỗi tín hiệu sẽ chiếm 2 dòng trong bảng khi cả 2
    đã đóng. Tắt bằng `InpShowTradeLog`.
  - **Bảng trạng thái + nút bấm test**: góc trên-phải (`InpButtonCorner`),
    hiện tên EA/symbol, P&L hôm nay, lệnh đang giữ (nếu có), trạng thái
    "Đang chạy", và **3 nút bấm** giống kiểu `EMACrossCloneEA`: **Test TG**
    (bấm là gửi ngay 2 tin MUA+BÁN thử vào Telegram — không cần đợi tín
    hiệu thật hay khởi động lại EA), **Test BUY** / **Test SELL**. Mặc định
    2 nút BUY/SELL chỉ gửi tin Telegram thử (an toàn, không đụng tiền
    thật); bật `InpAllowTestButtonRealOrder = true` nếu muốn bấm nút là mở
    **lệnh thật** ngay lập tức theo đúng risk/SL/TP1/TP2 đang cấu hình, để
    kiểm tra trọn vẹn luồng vào lệnh mà không cần chờ tín hiệu EMA thật.
    Tắt cả bảng này bằng `InpShowTestButtons`.

## Bảng Thống Kê Tỷ Lệ Thắng (indicator)

`DTC_v138.mq5` hiển thị thêm một bảng nhỏ ngay dưới dashboard MTF (bật/tắt
bằng `InpShowStatsTable`), liệt kê % tín hiệu lịch sử đã chạm từng mốc —
**chỉ TP1/TP2, khớp đúng với những gì EA thực sự giao dịch**:

```
Tỷ Lệ Thắng (n=42)
TP1  71.4%  (30)
TP2  47.6%  (20)
SL   28.6%  (12)
```

Cách tính: với mỗi tín hiệu Mua/Bán trong lịch sử, indicator tự mô
phỏng tiến về sau trên đúng dữ liệu giá của chart (dùng high/low từng nến)
để xem giá chạm SL hay TP1 trước; nếu chạm TP1 trước, SL giả định được dời
về hoà vốn rồi tiếp tục xét TP2. Một tín hiệu được tính là **thắng ở mức
TPx** nếu giá từng chạm tới đó, bất kể sau đó lệnh dừng ở hoà vốn hay đi
tiếp; **SL** chỉ tính khi giá chạm SL gốc *trước khi* từng chạm TP1 (thua
toàn bộ). Tín hiệu quá mới, giá chưa kịp đi đến đâu, sẽ tạm không được
tính vào `n` cho tới khi có đủ nến để phân định kết quả. Đây là thống kê
dựa trên đúng lịch sử giá của chart đang mở — không phải kết quả backtest
chính thức của Strategy Tester, và nếu SL/TP chạm cùng một nến thì mặc
định coi SL chạm trước (giả định an toàn/thận trọng vì không có dữ liệu
tick trong lịch sử OHLC).

## Những khác biệt so với script Pine gốc

1. Input `Stop-Loss Lookback` (Tiny/Small/Mid/Large) trong script gốc tính
   ra `sl_length` nhưng **không được dùng ở đâu khác** trong code Pine (biến
   `lowest_low`/`highest_high` tính ra rồi bỏ không) — coi như dead code nên
   không port sang, không ảnh hưởng gì đến hành vi hiển thị hay giao dịch.
2. Script gốc có 4 mốc TP (TP1-TP4); bản MT5 (cả indicator lẫn EA) **chỉ
   dùng TP1/TP2** theo đúng yêu cầu khi làm việc — TP3/TP4 đã bỏ hẳn khỏi
   cả phần vẽ chart lẫn phần giao dịch, không còn xuất hiện ở đâu nữa.
3. TradingView gửi Telegram qua cơ chế `alert()` + webhook URL (đã chứa sẵn
   Bot Token) do người dùng dán vào ô Alert; MT5 không có khái niệm này nên
   indicator/EA gọi thẳng Telegram Bot API bằng `WebRequest`, cần thêm input
   **Bot Token** (lấy từ @BotFather) chứ không chỉ Chat ID.
4. Script gốc chỉ vẽ Entry/SL/TP — không tự đóng/chốt lệnh, không đảo
   chiều. EA thêm: mở 2 lệnh riêng biệt khối lượng chia đều (1 lệnh/TP) thay
   vì 1 lệnh rồi tự chốt từng phần, tự dời SL về hoà vốn sau TP1, luôn đảo
   chiều khi có tín hiệu ngược, cộng thêm bảng lợi nhuận theo ngày/tháng và
   thông báo Telegram tổng kết — toàn bộ phần này hoàn toàn mới so với bản
   Pine Script (theo yêu cầu khi tạo EA).

## Đổi tên file: DTC_v135 → DTC_v136 → DTC_v137 → DTC_v138

File hiện tại (mới nhất) là `DTC_v138.mq5`/`DTC_v138_EA.mq5`. Mỗi lần đổi
tên là để MT5 chắc chắn nạp đúng bản mới (tránh tình trạng file `.ex5` cũ
vẫn được cache lại dưới tên cũ, khiến chart vẫn hiện hành vi cũ dù source
đã sửa). Nếu chart của bạn đang gắn bản `v135`/`v136`/`v137` cũ, hãy gỡ nó
ra và gắn lại bằng file `v138` mới; các object/đường kẻ của các bản cũ
(tiền tố `DTC135_`/`DTC136_`/`DTC137_`, `DTCEA135_`/`DTCEA136_`/
`DTCEA137_`) sẽ tự động được dọn sạch khi bản `v138` khởi động lần đầu
trên chart đó.

**Lưu ý quan trọng nếu chart bị rối/chữ đè lên nhau**: dấu hiệu là 2 con số
khác nhau hiện chồng lên đúng 1 chỗ (ví dụ "Hôm nay" hiện cả `-165 USC` lẫn
`+0 USC` cùng lúc) — đó là do đang có **≥2 bản EA/indicator gắn cùng lúc
trên cùng 1 chart** (thường là quên gỡ bản cũ trước khi gắn bản mới, hoặc
gắn cùng EA lên 2 chart `M3` khác nhau đang chồng cửa sổ lên nhau). Cách
sửa: vào từng tab chart, mở danh sách Expert/Indicator đang gắn (icon nhỏ
góc trên bên phải chart), gỡ hết bản cũ, chỉ giữ đúng 1 bản `v138` duy
nhất. Từ bản này, mọi bảng (dashboard, thống kê, P&L, lịch sử lệnh) đều có
khung nền riêng để không bị "nổi chữ" đè lên nến hay đè lên bảng khác.

## Kéo thả bảng + chữ không bao giờ lọt ra ngoài khung

Mọi bảng (dashboard+thống kê của indicator; P&L, lịch sử lệnh, trạng thái+
nút Test của EA) đều **kéo thả được bằng chuột**: bấm giữ ngay trên khung
nền của bảng rồi kéo tới vị trí bạn muốn trên chart, thả ra là xong — vị
trí mới được nhớ lại, không bị nhảy về chỗ cũ ở lần làm mới tiếp theo
(mỗi 20 giây với EA, mỗi khi có nến mới với indicator). Muốn đưa bảng về
lại góc mặc định thì đổi giá trị input góc tương ứng (`InpDashboardCorner`,
`InpPnLCorner`, `InpTradeLogCorner`, `InpButtonCorner`) rồi gắn lại
indicator/EA.

Bề rộng mỗi khung nền được **tự tính theo đúng độ dài chữ dài nhất** đang
hiển thị trong bảng đó (dùng `TextGetSize` đo pixel thật của font Consolas)
cộng thêm khoảng đệm, nên chữ luôn nằm gọn bên trong khung, không lọt ra
ngoài dù số tiền lời/lỗ dài hay ngắn.

## Cài đặt

1. Copy `DTC_v138.mq5` vào `MQL5/Indicators/` và/hoặc `DTC_v138_EA.mq5` vào
   `MQL5/Experts/`, mở MetaEditor, biên dịch (F7). Môi trường này không có
   MetaTrader để compile/test — kiểm tra kỹ lỗi cú pháp trước khi chạy thật.
   Nếu chữ tiếng Việt hiển thị lỗi font trong MetaEditor, vào **File → Save
   As**, chọn encoding UTF-8 rồi lưu lại trước khi biên dịch.
2. Nếu bật Telegram Alert: vào **Tools → Options → Expert Advisors**, tick
   "Allow WebRequest for listed URL" và thêm
   `https://api.telegram.org` vào danh sách, rồi điền Bot Token + Chat ID
   vào input của indicator/EA. **Muốn gửi vào nhiều nhóm/kênh cùng lúc**:
   điền nhiều Chat ID vào cùng ô `InpTelegramChatId`, cách nhau bởi dấu
   phẩy, ví dụ `111111,-100222222,-100333333`. **Muốn gửi vào đúng 1 Topic
   cụ thể** của một nhóm đang bật tính năng Forum/Topics (ví dụ kênh
   "Signal Gold" có nhiều topic con 1/2/3/4...): điền số Topic đó vào
   `InpTelegramThreadId` (giống ô `message_thread_id` trong các EA khác
   bạn đang dùng) — để `0` nếu gửi thẳng vào nhóm chính, không nhắm topic
   nào.
3. Gắn EA/indicator lên đúng symbol + khung thời gian bạn muốn giao dịch
   (không cố định XAUUSD như bộ EA ICT — hệ EMA này dùng được trên mọi
   symbol/khung giống bản Pine Script gốc `overlay=true`).
4. Backtest EA trong Strategy Tester (Every tick based on real ticks) và
   chạy demo nhiều tuần trước khi cân nhắc live; không có gì đảm bảo lợi
   nhuận, tự chịu trách nhiệm rủi ro khi giao dịch thật.
