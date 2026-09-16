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

# XAUUSD Mean Reversion EA (MT5, khung M5)

EA thứ hai trong repo, theo đúng SPEC "Mean Reversion (Stoch + MACD + ADX
+ ATR + EMA + M1 Confirm)": chiến lược **bắt đảo chiều** tại vùng cực trị
Stochastic — khác hẳn logic thuận xu hướng của EA ICT ở trên. File EA:
`MQL5/Experts/XAUUSD_MeanReversion_M5.mq5`.

## Logic tóm tắt

- **Trigger M5**: Stochastic(100,3,3, SMA, Low/High) chạm vùng cực trị
  (≥85 Sell / ≤15 Buy) **và** MACD(12,26,9) cắt Signal cùng chiều, đánh
  giá trên nến M5 vừa đóng cửa (không repaint).
- **Gate điều kiện** (kiểm tra cả lúc arm tín hiệu lẫn lúc M1 xác nhận):
  ADX(14) phải ≤ ngưỡng (ADX cao = chặn, vì đây là chiến lược đảo chiều),
  ATR(14) phải nằm trong khoảng Min–Max (đơn vị giá), EMA filter M15/M30
  (tuỳ chọn bật/tắt) không cho lệnh đi ngược hẳn trend lớn, ngoài khung
  giờ chặn 00:00–02:00 giờ server, không có tin High impact (Economic
  Calendar built-in, lọc theo currency USD), và chưa có lệnh nào đang mở.
- **Xác nhận M1**: sau khi trigger M5 thoả, EA "arm" tín hiệu và chờ tối
  đa `InpM1_ConfirmMaxMinutes` phút (mặc định 15) để xuất hiện Pin Bar
  hoặc Engulfing đúng chiều trên M1; hết hạn thì huỷ tín hiệu. Khi mẫu
  hình xuất hiện, gate điều kiện được kiểm tra lại lần nữa trước khi vào
  lệnh thật (phòng trường hợp tin tức/giờ giao dịch thay đổi trong lúc
  chờ).
- **Quản lý lệnh**: SL/TP cố định theo đơn vị giá (`InpSL_Price`,
  `InpTP_Price` — mặc định 5/10, tương ứng "50/100 pip" theo cách quy đổi
  1 giá = 10 pip trong tài liệu gốc), dời SL về hoà vốn khi lời đạt
  `InpSLBE_TriggerPrice`, và đóng sớm nếu MACD trên khung `InpEarlyClose_Timeframe`
  (mặc định M15) cắt ngược hướng lệnh đang mở. Không nhồi lệnh — chỉ 1
  lệnh/lúc theo magic number.
- **Dashboard**: panel text trên chart (góc trên-trái) hiển thị từng điều
  kiện + giá trị hiện tại + trạng thái, đổi màu xanh (đạt)/đỏ (chặn)/vàng
  (đang chờ M1) theo đúng mẫu trong SPEC.

## Diễn giải các điểm SPEC còn mơ hồ (đọc trước khi tin tưởng số liệu)

1. **EMA filter "không chặn cứng 100%"**: SPEC mô tả bộ lọc EMA là "lọc
   bớt" chứ không chặn tuyệt đối, nhưng chỉ cho 3 input
   (`UseEMAFilter`, `EMA_Period`, `EMA_Timeframe`) mà không có ngưỡng dung
   sai nào khác. Cách hiểu đã lập trình: khi bật, đây **là** một chặn có
   điều kiện theo hướng (chặn BUY nếu giá M5 đang dưới EMA khung lớn =
   ngược hẳn downtrend; chặn SELL nếu giá đang trên EMA = ngược hẳn
   uptrend) — tính "không chặn cứng 100%" nằm ở chỗ toàn bộ bộ lọc có thể
   tắt hẳn qua input để so sánh có/không dùng, đúng như SPEC yêu cầu "bật
   tắt được qua input để tự test". Nếu bạn muốn một vùng đệm mềm hơn
   (theo ATR chẳng hạn) thay vì so sánh giá đóng cửa trực tiếp với EMA,
   cần bổ sung thêm input riêng.
2. **Đơn vị "giá" trong SL/TP/SLBE/ATR**: SPEC ghi rõ ATR_MinPoints/
   MaxPoints "theo đơn vị giá" (ví dụ 1.5–15.0), và SL "5 giá (50 pip)"
   / TP "10 giá (100 pip)" ngụ ý 1 "giá" = 10 "pip" (tức 1 giá = $1 đối
   với Gold nếu 1 pip công cộng đồng vàng = $0.10). Vì vậy toàn bộ các
   input này (`InpSL_Price`, `InpTP_Price`, `InpSLBE_TriggerPrice`,
   `InpATR_MinPoints`, `InpATR_MaxPoints`) được lập trình là **đơn vị giá
   trực tiếp** (cộng/trừ thẳng vào price, không nhân với `_Point`) —
   không phải "points" theo nghĩa kỹ thuật MQL5 (`_Point`). Kiểm tra lại
   kỹ trên tài khoản/broker của bạn trước khi live vì số digit giá Gold
   khác nhau giữa các sàn.
3. **`Server_GMT_Offset`**: chỉ mang tính hiển thị/tham khảo — điều kiện
   giờ chặn (`BlockStartHour`/`BlockEndHour`) so sánh trực tiếp với giờ
   server hiện tại (`TimeCurrent()`), không cần quy đổi qua offset vì
   SPEC đã cho khung giờ chặn ở dạng giờ server sẵn.
4. **News filter**: dùng `CalendarValueHistory(..., NULL, "USD")` — lọc
   theo currency USD (đồng tiền định giá của XAUUSD) thay vì theo country,
   vì tin ảnh hưởng Gold chủ yếu là tin kinh tế Mỹ. Nếu `CalendarValueHistory`
   trả về 0 hoặc lỗi (dữ liệu lịch kinh tế chưa đồng bộ trong terminal),
   EA **fail-open** (không chặn) — cần đảm bảo lịch kinh tế đã được tải
   (mở MT5, kết nối tài khoản có hỗ trợ Calendar) trước khi tin vào bộ
   lọc này, đặc biệt khi backtest.
5. **Pin Bar / Engulfing**: dùng ngưỡng tỷ lệ phổ biến (wick ≥ 2× body và
   ≥ 60% range, wick đối diện ≤ 25% range cho Pin Bar; body nến sau bao
   trọn body nến trước cho Engulfing) — đây là công thức heuristic tự
   xây, SPEC không cho công thức chính xác.

## Cài đặt & backtest

1. Copy file vào `MQL5/Experts/`, mở MetaEditor, biên dịch (F7). Môi
   trường này không có MetaTrader để compile/test — kiểm tra kỹ lỗi cú
   pháp nếu có trước khi chạy thật.
2. Gắn EA vào chart **XAUUSD, khung M5**.
3. Backtest trong Strategy Tester với **Every tick based on real ticks**;
   nếu bật `InpUseNewsFilter`, đảm bảo lịch kinh tế lịch sử đã có trong
   Tester (MT5 hỗ trợ mô phỏng Calendar trong Tester từ các build gần
   đây). EA cần dữ liệu M1 (cho xác nhận mẫu hình) và M15/M30 (cho EMA
   filter/early close) — Tester sẽ tự tải khi cần.
4. Backtest/demo nhiều tuần, nhiều điều kiện thị trường trước khi cân
   nhắc live, và tinh chỉnh lại các ngưỡng (ADX threshold, ATR band, EMA
   period, ngưỡng Pin Bar/Engulfing) theo dữ liệu thực tế.
