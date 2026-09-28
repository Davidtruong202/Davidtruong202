# Tái dựng bot DCA Passview: báo cáo dữ liệu, đặc tả và EA khung V1.00

Ngày lập: 28/09/2026 · EA: `MQL5/Experts/Passview_DCA_Replica_V1_00.mq5` · SET mẫu: `MQL5/Presets/Passview_DCA_Replica_V1_00_mau.set`

> **Tóm tắt trung thực:** chưa có dòng log Passview nào trong môi trường làm việc, nên **chưa suy ra được
> quy tắc nào của Passview**. EA V1.00 là **khung DCA hoàn chỉnh về vận hành** (quản lý basket, khôi phục,
> giới hạn rủi ro, log quyết định). Các quy tắc giao dịch (tín hiệu lệnh đầu, bước DCA, lot, TP/SL) là
> **tham số chưa kiểm chứng** với giá trị mặc định chỉ để minh họa. EA **chưa được compile, chưa backtest**.

Ký hiệu: ✅ đã kiểm tra trực tiếp · 🟡 suy luận có căn cứ · ❓ chưa xác định

---

## 1. Báo cáo chất lượng dữ liệu

### 1.1. Các file được nêu trong yêu cầu

| File | Tình trạng |
|---|---|
| `tradelog_deals.csv` | ❌ Không tìm thấy |
| `tradelog_orders.csv` | ❌ Không tìm thấy |
| `tradelog_events.csv` | ❌ Không tìm thấy |
| `tradelog_symbols.csv` | ❌ Không tìm thấy |
| `tradelog_bars_XAUUSD_M5.csv` | ❌ Không tìm thấy |
| `tradelog_bars_XAUUSD_CURRENT.csv` | ❌ Không tìm thấy |
| Mã nguồn / SET của bot Passview | ❌ Không có (và không cần: mục tiêu là tái dựng từ log, không sao chép EX5) |

Phạm vi đã rà soát ✅:
- Cả 12 branch của `Davidtruong202/Davidtruong202` (tìm theo tên file, nội dung "passview", "tradelog_").
- Repo `Davidtruong202/EA-PRO`: chỉ có EA David Hunter V4.48/V4.52, SET và tick `XAUUSDm` 01–04/2026 (dạng `.zip.part001`).
- Toàn bộ hệ thống file của phiên làm việc.

Dữ liệu có sẵn nhưng **không dùng được để suy ra Passview**: tick/M1 `BTCUSDc` (khác symbol, không có lệnh), tick
`XAUUSDm` (không có lệnh; có thể dùng làm dữ liệu giá cho backtest nếu bot Passview chạy cùng sàn).

**Hệ quả:** không thể báo khoảng thời gian, số dòng, dữ liệu trùng/thiếu, múi giờ, digits, contract size, spread
hay commission của tài khoản Passview. Mọi số liệu này sẽ được lập khi có file.

### 1.2. Schema dự kiến (✅ đọc từ mã nguồn `TradeLogger.mq5` v1.00, branch `claude/compassionate-pasteur-t6m0nj`)

| File | Trường chính | Ghi chú |
|---|---|---|
| deals | `deal_ticket, order_ticket, position_id, time, time_msc, symbol, type, entry, volume, price, sl, tp, profit, commission, swap, fee, magic, reason, comment` + 38 cột đặc trưng `f_*` | Đặc trưng tính trên **nến đã đóng** trước lúc khớp (`iBarShift+1`) → không nhìn trước |
| orders | `order_ticket, position_id, time_setup, time_done, symbol, type, state, reason, volume_initial, volume_current, price_open, sl, tp, price_current, magic, comment` | Cho biết leg là lệnh market hay lệnh chờ limit/stop |
| events | `time, kind, event(EXISTING/NEW/MODIFY/GONE), ticket, symbol, type, volume, price, sl, tp, bid, ask` | Quét mỗi 5 giây; là nguồn duy nhất có bid/ask (spread) |
| symbols | `digits, point, contract_size, tick_size, tick_value, volume_min, volume_step, feature_tf, bias_tf, account_currency, account_leverage, server` | |
| bars | `symbol` + các cột đặc trưng | Không có OHLC gốc, nhưng dựng lại được: `open = close − body_atr·atr`, `high = max(o,c) + upwick_atr·atr`, `low = min(o,c) − lowwick_atr·atr` |

### 1.3. Rủi ro dữ liệu đã biết trước từ thiết kế logger

| # | Vấn đề | Cách xử lý khi có dữ liệu |
|---|---|---|
| 1 | Nhiều Logger trên nhiều chart cùng tiền tố `tradelog` sẽ cùng ghi vào một file → **trùng dòng** deals/events, và cột `f_*` của cùng một deal có thể tính trên **khung khác nhau** | Khử trùng deals theo `deal_ticket`; events theo `(ticket, event, volume, price, sl, tp)` trong cửa sổ 10 giây; đánh dấu deal có đặc trưng mâu thuẫn |
| 2 | File `_CURRENT` do **bản Logger cũ** tạo (bản hiện tại ghi tên khung thật) → không biết là khung nào | Suy ra khung từ khoảng cách `feat_bar_time`; không trộn với file M5 |
| 3 | Deals **bỏ qua nạp/rút** → không dựng lại được balance tuyệt đối | Cần thêm báo cáo lịch sử tài khoản (mục 5) để kiểm tra giả thuyết "lot theo balance" |
| 4 | Deals không có spread; events chỉ có bid/ask khi có thay đổi | Cần tick data của đúng sàn (mục 5) |
| 5 | Events không có magic/comment | Nối với deals qua `ticket = position_id` |
| 6 | Giờ là **giờ server** | Xác định múi giờ qua tên server và khoảng nghỉ hằng ngày của XAUUSD trên dữ liệu nến |
| 7 | Comment của deal OUT bị sàn ghi đè (`[tp …]`, `[sl …]`) | Lấy nhãn từ deal IN cùng `position_id` |
| 8 | Có thể có lệnh tay (`magic = 0`, `reason = CLIENT/MOBILE/WEB`) | Tách riêng, không tính vào bot |

---

## 2. Phương pháp Giai đoạn 1–2 (sẽ áp dụng khi có log)

1. **Tách chiến lược:** nhóm theo `(symbol, magic)`, rồi theo mẫu comment. Nhóm là **DCA** nếu thường xuyên có
   ≥ 2 vị thế cùng chiều mở chồng thời gian và leg sau có giá bất lợi hơn leg trước; nhóm **đơn lệnh** nếu hầu như
   chỉ có 1 vị thế tại một thời điểm. Lệnh tay tách riêng. Logger không đặt lệnh nên không tạo deal.
2. **Dựng basket:** trong mỗi nhóm DCA, basket bắt đầu khi không còn vị thế mở cùng `(magic, symbol, chiều)` và
   kết thúc khi vị thế cuối đóng. Mỗi leg: thứ tự, thời gian, giá, lot, khoảng cách tới leg trước (giá và theo ATR
   của nến đã đóng), thời gian từ leg trước, giá vốn bình quân sau leg. Mỗi basket: cách đóng (`reason` TP/SL/EXPERT/SO),
   các leg đóng cùng lúc hay lẻ, khoảng cách giá đóng tới giá bình quân, P&L ròng (profit + commission + swap + fee),
   thời gian giữ, mức lỗ nổi lớn nhất ước tính từ nến/tick.
3. **Chống nhìn trước:** mọi đặc trưng dùng cho quyết định lấy từ nến **đóng trước** thời điểm khớp; kiểm tra thêm
   giây khớp trong nến (khớp sát giây :00 của nến mới → quyết định theo nến; khớp rải rác → theo giá chạm).
4. **Chia thời gian:** 70% đầu dùng suy luận, 30% cuối giữ kín để kiểm tra độc lập (chạy một lần).

---

## 3. Bảng giả thuyết

Tất cả ở trạng thái **❓ chưa kiểm định — 0 mẫu**. Cột "Tiêu chí chấp nhận" được chốt **trước** khi xem dữ liệu để
tránh chọn ngưỡng theo kết quả.

| # | Thành phần | Giả thuyết cần kiểm | Cách đo | Tiêu chí chấp nhận | Tham số EA tương ứng |
|---|---|---|---|---|---|
| H1 | Bước DCA | Cố định theo giá | Hệ số biến thiên (CV) của khoảng cách giữa các leg | ≥ 90% leg nằm trong ±10% trung vị | `InpStepMode=0`, `InpStepPrice` |
| H2 | Bước DCA | Theo ATR | CV của khoảng cách/ATR so với CV khoảng cách giá | CV(ATR) thấp hơn rõ rệt CV(giá), và đạt ±15% | `InpStepMode=1`, `InpStepATRMult`, `InpATRTF` |
| H3 | Bước DCA | Nới dần theo leg | Tỷ lệ khoảng cách leg k / leg k−1 | Tỷ lệ ổn định ≠ 1 trên ≥ 80% cặp | `InpStepGrowth` |
| H4 | Bước DCA | Đo từ leg trước (không phải từ leg đầu / giá TB) | So độ ổn định của 3 cách đo | Cách đo có CV thấp nhất | EA V1.00 chỉ hỗ trợ "từ leg trước" |
| H5 | Lot | Nhân hệ số / cộng dồn / cố định | Tỷ lệ và hiệu lot liên tiếp, có tính làm tròn bước lot | Sai khác ≤ 1 bước lot trên ≥ 95% leg | `InpLotMultiplier`, `InpLotAdd` |
| H6 | Lot | Lot đầu theo balance | Lot leg 1 so với balance lúc mở | Tương quan cao và bậc thang rõ ràng | Chưa hỗ trợ; **cần báo cáo balance** |
| H7 | Số leg | Có trần cứng | Phân phối số leg; basket chạm trần có ngừng thêm dù giá tiếp tục bất lợi | Có ≥ 3 basket chạm cùng trần | `InpMaxLegs` |
| H8 | Chốt basket | Giá bình quân ± khoảng cố định (TP server) | `reason = TP`, TP của mọi leg bằng nhau, cách giá TB | ≥ 90% basket, ±10% | `InpTPMode=0/1`, `InpSetServerTP` |
| H9 | Chốt basket | Lãi ròng theo tiền | `reason = EXPERT`, P&L ròng lúc đóng | Ổn định ±15% (hoặc tỷ lệ với tổng lot) | `InpTPMode=2`, `InpTPMoney`, `InpTPMoneyPerLot` |
| H10 | Cắt lỗ | SL basket / theo thời gian / stop-out | Basket đóng lỗ: mức lỗ, thời gian giữ, `reason = SO` | Mức cắt lặp lại ở ≥ 3 basket | `InpBasketSLMoney`, `InpMaxBasketHours` |
| H11 | Lệnh đầu | Theo chỉ báo trên nến đã đóng (EMA, RSI, màu nến…) | So phân phối đặc trưng lúc mở lệnh đầu với toàn bộ nến; kiểm tra quy tắc đơn giản | Khớp chiều ≥ 80% trên tập kiểm tra, có phản ví dụ được liệt kê | `InpEntryMode`, `InpSignalTF`, các chu kỳ |
| H12 | Lệnh đầu | Mở lại ngay sau khi đóng basket | Độ trễ đóng → mở | Trung vị ≤ 1 nến | `InpCooldownSeconds` |
| H13 | Số basket | 1 basket hay cả BUY và SELL cùng lúc | Chồng thời gian giữa basket 2 chiều | Có ≥ 1 lần chồng → cho phép hedge | `InpAllowHedge` |
| H14 | Phiên | Lệnh đầu chỉ trong một khung giờ; leg thêm thì mọi lúc | Phân phối giờ lệnh đầu so với giờ có giá hoạt động | Khoảng giờ trống lặp lại qua các tuần | `InpUseSession`, giờ bắt đầu/kết thúc |
| H15 | Spread | Không vào lệnh khi spread cao | Spread lúc vào (từ tick) so với phân phối spread chung | Ngưỡng trên rõ ràng | `InpMaxSpreadPrice` |
| H16 | Chế độ | Bot có nhiều chế độ (đổi bước/lot theo biến động hoặc số leg) | Phân cụm tham số basket theo thời gian/biến động | Cụm tách biệt và ổn định | Chưa hỗ trợ; tạo version mới nếu được xác nhận |

Nguyên tắc: một quy tắc chỉ được đưa vào SET "Passview" khi đạt tiêu chí **trên tập suy luận và giữ được trên tập
kiểm tra**. Quy tắc không đạt được ghi là "chưa xác định", không thay bằng điều kiện tự chọn.

---

## 4. Đặc tả EA V1.00

### 4.1. Đã lập trình (độc lập với logic Passview)

| Chức năng | Cách làm |
|---|---|
| Nhận diện basket | Theo `Magic + symbol + chiều`; vị thế đang mở là nguồn dữ liệu chính, nên khôi phục đúng sau khi khởi động lại MT5, gắn lại EA hoặc đổi timeframe |
| Tham số basket | Bước và TP được chốt lúc mở lệnh đầu, lưu GlobalVariable theo ticket leg đầu. Nếu mất (đổi máy/VPS): tính lại từ dữ liệu hiện tại và ghi `RECOVER_PARAMS` vào log |
| Basket đóng khi EA tắt | Lúc khởi động phát hiện và ghi `BASKET_CLOSED … WHILE_EA_OFFLINE` |
| Hedging / netting | Chỉ hỗ trợ **hedging**. Netting/Exchange: EA báo lỗi và không chạy (netting gộp mọi leg thành một vị thế, không làm DCA nhiều leg được) |
| Giới hạn | Số leg, lot mỗi leg, tổng lot, spread, margin level sau lệnh, sụt giảm equity (đóng mọi basket; ngừng mở basket mới khi đạt nửa ngưỡng), 1 basket mỗi chiều, hedge tùy chọn |
| Xử lý lỗi | Thử lại với requote/giá đổi/timeout; timeout thì kiểm tra xem lệnh đã khớp chưa trước khi gửi lại (tránh leg trùng); lỗi nghiêm trọng hoặc lỗi liên tiếp thì khóa lệnh mới tới nến sau; đóng basket lỗi thì thử lại mỗi tick; sửa TP lỗi thì thử lại |
| Tài khoản thật | Mặc định từ chối; phải bật `InpAllowRealAccount` |
| Log quyết định | `PassviewDCA_<symbol>_<magic>_<YYYY_MM>.csv`. Sự kiện: `OPEN_FIRST, ADD_LEG, SKIP, CLOSE_REQUEST, BASKET_CLOSED, RECOVER, RECOVER_PARAMS, ERROR`. Cột: thời gian (ms), giá, bid/ask/spread, số leg, tổng lot, giá TB, lãi nổi ròng, balance/equity/margin level/DD, ATR/EMA/RSI của nến đã đóng, nến tín hiệu, retcode, lý do |

### 4.2. Tham số chưa kiểm chứng (giá trị mặc định chỉ để minh họa)

- Lệnh đầu: tắt / EMA / RSI / màu nến / chỉ BUY / chỉ SELL, **chỉ dùng nến đã đóng**, xét khi có nến mới.
- Thêm leg: khi giá bất lợi đi đủ khoảng cách **từ leg trước** (giá cố định hoặc ATR, có hệ số nới), khớp theo giá
  chạm hoặc chỉ khi có nến mới.
- Lot: `lot_k = lot_đầu × hệ_số^k + cộng_thêm × k`, giới hạn theo lot tối đa mỗi leg, làm tròn theo bước lot.
- Đóng: giá TB ± khoảng (TP server trên mọi leg + kiểm tra trong EA) hoặc lãi ròng theo tiền; tùy chọn cắt lỗ theo tiền
  và theo thời gian.

### 4.3. Chưa hỗ trợ (chỉ thêm ở version mới khi dữ liệu xác nhận)

Lot theo balance (H6), nhiều chế độ (H16), bước đo từ leg đầu hoặc giá TB (H4), trailing basket, đóng từng phần
kiểu "đóng cặp leg đầu và leg cuối", lệnh chờ limit cho leg.

---

## 5. Cần ghi thêm và trong bao lâu

| Dữ liệu | Để kiểm giả thuyết | Cách lấy |
|---|---|---|
| 6 file `tradelog_*.csv` đang có | H1–H14 | Nén zip, upload vào `data/passview/` (mỗi file ≤ 25 MB nếu upload qua web GitHub) |
| **Tick data XAUUSD của đúng sàn Passview** trong cùng giai đoạn | Spread (H15), giá chạm lúc thêm leg, lỗ nổi lớn nhất, backtest Every tick | MT5: *View → Symbols → Ticks → Export* (đã làm với BTCUSDc) |
| **Báo cáo lịch sử tài khoản** (có nạp/rút, cột balance) | Lot theo balance (H6), DD thực | MT5: *Toolbox → History → chuột phải → Report* |
| Nến M1 kèm cột spread | Kiểm tra khung tín hiệu | *Symbols → Bars → Export* |
| Thông tin tài khoản: loại tài khoản, hedging/netting, commission mỗi lot, swap, đòn bẩy | Chi phí, chế độ | Thông số symbol / hợp đồng của sàn |
| Ghi chú: các lần đổi cấu hình bot, can thiệp tay, VPS mất kết nối | Loại bỏ nhiễu | Bạn ghi lại theo ngày |

Chỉ chạy **một** TradeLogger trên tài khoản Passview (hoặc đặt tiền tố file khác nhau cho từng chart) để tránh trùng dòng.

**Thời gian ghi tối thiểu** (cái nào đến sau thì tính theo cái đó):
- ≥ **100 basket đã đóng** của bot DCA: đủ để ước lượng tỷ lệ khớp một quy tắc với sai số khoảng ±10% (độ tin cậy 95%).
- ≥ **30 basket có từ 3 leg trở lên** và ≥ 3 basket chạm số leg tối đa: không có các basket sâu thì không đo được bước,
  hệ số lot và trần leg.
- ≥ **4–6 tuần**, gồm cả tuần biến động mạnh (tin CPI/NFP/FOMC) và tuần đi ngang, để phát hiện nhiều chế độ.

---

## 6. Hướng dẫn kiểm thử

1. **Compile:** mở MetaEditor, biên dịch `Passview_DCA_Replica_V1_00.mq5` (F7), gửi lại toàn bộ lỗi/cảnh báo nếu có.
   Môi trường phát triển không có MetaEditor, nên **chưa compile**. Chỉ mới kiểm tra tĩnh: cặp ngoặc khớp, không có hàm
   gọi mà chưa định nghĩa, tên input trong SET khớp với EA.
2. **Strategy Tester:** XAUUSD, *Every tick based on real ticks*, tài khoản hedging, nạp SET mẫu. Xem tab Experts:
   dòng `[PVR Tester]` / `[PVR Summary]`. Mở file log trong `Common\Files` (tester: thư mục agent) để đối chiếu từng quyết định.
3. **Kiểm tra vận hành trên demo:** (a) đang có basket 3 leg thì đổi timeframe → phải thấy `RECOVER`, không mở basket
   mới trùng; (b) tắt MT5 khi basket đang mở, bật lại → như trên; (c) để TP server đóng basket khi EA tắt → lúc bật phải
   thấy `WHILE_EA_OFFLINE`; (d) gắn lên tài khoản netting → EA phải từ chối chạy; (e) đặt `InpMaxSpreadPrice` rất nhỏ →
   phải thấy `SKIP SPREAD`.
4. **Giai đoạn 4, khi có log Passview:** chạy EA với SET đã suy ra trên đúng giai đoạn dữ liệu, so từng basket theo bảng dưới.
   Tối ưu (nếu có) chỉ trên 70% đầu; 30% cuối chạy một lần.

Bảng so sánh (chưa có số liệu: sẽ điền khi có log và kết quả tester):

| Chỉ số | Passview | EA tái dựng | Sai lệch |
|---|---|---|---|
| Thời điểm / chiều lệnh đầu khớp (% basket) | – | – | – |
| Số leg mỗi basket (trung vị, lớn nhất) | – | – | – |
| Khoảng cách DCA (trung vị, sai lệch) | – | – | – |
| Lot từng leg | – | – | – |
| Thời điểm / giá thoát | – | – | – |
| Net Profit, Max DD, Win Rate, Profit Factor, Expectancy, số basket | – | – | – |
| Tác động spread, commission, swap, slippage | – | – | – |

---

## 7. Rủi ro khi chạy thật

- DCA nhân lot có **rủi ro đuôi**: Win Rate thường cao nhưng một basket không hồi có thể mất phần lớn tài khoản.
  Giới hạn leg/tổng lot/DD trong EA giúp **chặn** thua lỗ nhưng biến lỗ nổi thành **lỗ thực**.
- Tham số mặc định **không** phải của Passview; kết quả với SET mẫu không nói lên điều gì về bot gốc.
- Ngưỡng DD tính trên **toàn tài khoản** (gồm cả lệnh của bot khác nếu chạy chung).
- TP trên server đảm bảo chốt khi EA tắt, nhưng **không có SL trên server**: khi EA tắt, các giới hạn lỗ không hoạt động.
- Không có cam kết lợi nhuận hay tỷ lệ thắng.

## 8. Phiên bản và rollback

| Version | File | Trạng thái |
|---|---|---|
| V1.00 | `Passview_DCA_Replica_V1_00.mq5` + `Passview_DCA_Replica_V1_00_mau.set` | TEST: chưa compile, chưa backtest, tham số chưa kiểm chứng |

Mỗi lần sửa sẽ tạo `…_V1_01.mq5`, `…_V1_02.mq5` và giữ nguyên các bản cũ. Không có EA hiện tại nào bị sửa: `TradeLogger.mq5`,
`GoldBot_DCA.mq5` và các EA khác trong repo giữ nguyên.
