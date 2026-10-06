# DAVID MULTI V1.04

File: `MQL5/Experts/DAVID_MULTI_V1_04.mq5`. File này là một EA duy nhất, không cần file `.mqh` đi kèm.

Liên hệ: **0941920986 – Davidhunter – Telegram @adsmmo8386**

> **CHƯA XÁC NHẬN COMPILE BẰNG METAEDITOR. CHƯA BACKTEST.** Hãy compile (F7), gửi lại nguyên văn Errors/Warnings, rồi chạy demo hoặc Strategy Tester trước khi dùng tài khoản thật.

## 1. Các chiến lược được giữ (đơn lệnh, không DCA)

| PP | Magic | Nguồn | Comment mặc định |
|---|---|---|---|
| CRT | 71001 | DAVID CRT V1.03, logic giữ nguyên | `CRT\|0941920986\|@adsmmo8386` |
| SAR | 71002 | Scalping M1 2.1 | `SAR\|0941920986\|@adsmmo8386` |
| BRK | 71003 | Máy in tiền 1.40 | `BRK\|0941920986\|@adsmmo8386` |
| ICT | 71004 | OptimusPrime 2.20 | `ICT\|0941920986\|@adsmmo8386` |

**Không đưa vào EA:**

| EA | Lý do |
|---|---|
| Thần Tài | DCA |
| Hedge chỉ số | 2 chân trên 2 mã |
| Scalping 2.0 ảnh nền | Trùng 2.1 và lỗi compile |
| Precise Pair | Chỉ có EX5 |

**Về comment lệnh:**
- MT5 giới hạn comment lệnh ở 31 ký tự, nên comment chỉ chứa SĐT + Tele.
- Dòng đầy đủ `0941920986-Davidhunter-Tele @adsmmo8386` được ghi trong tradelog và chân bảng.
- Nếu bạn nhập comment dài hơn 31 ký tự, EA tự cắt và ghi cảnh báo vào log.

**Mặc định bật:** chỉ CRT. SAR, BRK và ICT mặc định TẮT. Bật bằng Input hoặc nút trên bảng.

## 2. Thay đổi so với bản gốc (để thành đơn lệnh và an toàn hơn)

**SAR (Scalping M1 2.1):**
- Tối đa 1 position.
- Đã bỏ chế độ hai chiều và nhân lot Recovery/Aggressive.
- SAR tính trên khung `SAR_Khung_thời_gian_tín_hiệu` (mặc định M1), không phụ thuộc chart.
- **Sửa lỗi gốc:** quản lý TP/SL ẩn theo tiền **luôn chạy trước** mọi bộ lọc. Bản gốc có thể không đóng lệnh khi spread giãn hoặc ra ngoài giờ.
- Lọc giờ dùng một khoảng giờ server.
- Bỏ lọc tin (lịch kinh tế không chạy trong Tester) và cơ chế cấp quyền.

**BRK (Máy in tiền):**
- Đặt Buy Stop và Sell Stop theo kiểu **OCO**: khi một phía khớp, EA xóa phía còn lại và không đặt lệnh chờ mới cho tới khi position đóng.
- Khoảng cách, SL, TP và trailing nhập theo **đơn vị giá**. Mặc định 1.0 / 1.0 / 0 / 0.5, bằng giá trị gốc trên XAUUSD.
- Trailing vẫn chạy ngoài giờ.
- Spread cao hoặc ngoài giờ thì EA hủy lệnh chờ.
- Lọc giờ theo **giờ server** (bản gốc dùng giờ máy tính).
- Không dùng `Sleep`.

**ICT (OptimusPrime):**
- **1 lệnh/setup**, TP = `ICT_TP_theo_R` × R (mặc định 3R, tương ứng nhánh TP2 gốc).
- Tự chạy, không cần bấm nút Run.
- Chỉ dùng nến đã đóng.
- Đếm cả lệnh chờ để không đặt trùng.
- R tính theo SL ban đầu.
- Lot tính ra nhỏ hơn Volume Min thì bỏ setup.
- Ngân sách rủi ro ngày tính cả lệnh mới.
- Chuỗi thua được reset sau thời gian nghỉ.
- Swing [0] là swing gần nhất.
- Điểm "swing chạm ≥2" của bản gốc không bao giờ kích hoạt nên đã bỏ.
- Spread và SL tối đa nhập theo đơn vị giá.
- Killzone tính theo giờ UTC = giờ server − `ICT_Giờ_server_lệch_UTC` (Exness = 0).

**CRT:** logic V1.03 giữ nguyên. Chỉ đổi comment lệnh và thêm kiểm tra chế độ "1 lệnh toàn EA".

**Chung:** `Chỉ_1_lệnh_cho_toàn_EA` (mặc định tắt). Khi bật, toàn EA chỉ được có một lệnh, dù thuộc chiến lược nào.

## 3. Bảng Board (theo mẫu David Multi Method Board)

- Có 4 thẻ tổng: vị thế đã đóng, winrate, lãi/lỗ đã đóng, thả nổi.
- Bảng hiệu suất từng phương pháp gồm Đóng / Thắng / Thua / Hòa / Winrate / Lãi-lỗ / Mở-Chờ, tính theo Magic.
- **Nút ● BẬT / ○ TẮT** trên từng dòng phương pháp. Khi tắt:
  - Phương pháp đó ngừng vào lệnh mới và hủy lệnh chờ.
  - Lệnh đang mở vẫn được quản lý tiếp.
  - Trạng thái nút được giữ khi đổi TF hoặc restart. Khi bạn đổi Input bật/tắt, giá trị Input được ưu tiên.
- Mỗi phương pháp có 2 dòng trạng thái chi tiết. Dòng CRT gồm Ref/Active/High/Low/Bias/Sweep/M15/Entry/SL/TP/RR.
- Có danh sách vị thế đang mở (PP, ticket, Entry, SL, TP, thả nổi) và chia trang khi nhiều lệnh.
- **Nút "−"** thu gọn bảng thành một thanh nhỏ; **nút "+"** mở lại.
- Nút Hôm nay / Tháng này / Toàn bộ chọn kỳ thống kê.
- Trong Strategy Tester, bảng chỉ hiện ở Visual mode.

## 4. Tradelog CSV

**Vị trí file:** `MQL5\Files` trong thư mục Common (File → Open Data Folder → lùi lên → Common\Files).
- Live: `DAVID_MULTI_TradeLog_<Symbol>.csv`
- Tester: `DAVID_MULTI_TradeLog_<Symbol>_TESTER.csv`

**Cách ghi:**
- Mỗi vị thế đã đóng ghi đúng 1 dòng, phân tách bằng dấu phẩy.
- Khi chạy live, lúc khởi động EA tự bù những vị thế đã đóng trong lúc EA offline, và không ghi trùng.
- Mỗi lần khởi động có một RunID riêng, dùng để tách các lần backtest.

**Các cột:** `RunID, Mode, Account, Symbol, Strategy, Magic, PositionID, Side, Lots, OpenTime, OpenPrice, InitialSL, InitialTP, CloseTime, ClosePrice, CloseReason (SL/TP/EXPERT/MANUAL…), DurationMin, PriceMove, Profit, Swap, Commission, Fee, NetProfit, Result (WIN/LOSS/BE), PlannedRR, RMultiple, OpenComment, Contact`

SAR đóng lệnh bằng TP/SL ẩn theo tiền, nên cột InitialSL/TP của SAR bằng 0 và RMultiple bằng 0.

## 5. Gợi ý kiểm thử

1. Compile, sau đó backtest **từng phương pháp riêng** (chỉ bật 1 PP) với Every tick based on real ticks.
2. Lọc file CSV theo cột Strategy để so sánh Profit Factor, Expectancy, Winrate và RMultiple.
3. Chỉ chạy nhiều PP cùng lúc sau khi từng PP đã đạt yêu cầu. Cân nhắc bật `Chỉ_1_lệnh_cho_toàn_EA`.
