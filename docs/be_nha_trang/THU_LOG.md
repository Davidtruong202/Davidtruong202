# Thu log bot BE Nha Trang bằng TradeLogger 2.00

Mục tiêu: ghi lại **hành vi thật** của bot gốc để sửa các giả định trong EA viết lại
(`MQL5/Experts/BE_NhaTrang_DCA.mq5`), thay vì đoán từ tên tham số.

| File | Vai trò |
|---|---|
| [`../../MQL5/Experts/TradeLogger/TradeLogger.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger.mq5) | EA ghi log, không đặt lệnh (chưa compile) |
| [`../../research/be_nha_trang/phan_tich_log.py`](../../research/be_nha_trang/phan_tich_log.py) | Đọc file deals, đo các thông số của bot |

## Nâng cấp so với TradeLogger 1.00

Bản 1.00 ghi đủ lệnh nhưng các đặc trưng thị trường là loại chung chung (ATR, RSI, EMA20/50/200 trên M5/H1),
**không trùng** với các chỉ báo bot DCA dùng. Vì vậy từ log đó không đo được ngưỡng của bot. Bản 2.00 bổ sung:

| # | Bổ sung | Để trả lời câu hỏi |
|---|---|---|
| 1 | **Đặc trưng riêng bot** (`b_*`): EMA34/89 M6, EMA10/20 M12, EMA34/89 M6 thứ hai, CCI14 M1, nến M1 vừa đóng, thân nến M10, giờ server, số giây kể từ lúc mở nến M1 và nến M6. Tất cả lấy trên nến **đã đóng**, khung và chu kỳ chỉnh được theo file .set | Ngưỡng A%/B% thật là bao nhiêu? Bot vào lệnh lúc mở nến hay giữa nến? |
| 2 | **Bối cảnh rổ lệnh** (`k_*`): phát lại deal theo thứ tự thời gian, gom theo (symbol, magic, chiều). Mỗi deal có: số thứ tự lệnh trong rổ, số lệnh đang có, giá trung bình, giá và lot lệnh trước, khoảng cách tới lệnh trước (pip), tỉ lệ lot, pip lúc đóng | Khoảng cách và hệ số DCA theo từng bậc; TP tính từ giá trung bình bao nhiêu pip |
| 3 | **OnTradeTransaction**: ghi deal và thay đổi SL/TP ngay khi xảy ra, kèm bid/ask/spread và EMA của nến đang chạy (`live_*`) | Bản cũ quét 5 giây một lần, nên bỏ sót SL/TP đổi rồi đổi lại trong vài giây và không có giá tức thời |
| 4 | **Lọc magic/symbol** (`InpMagicFilter`, `InpSymbolFilter`) | Không lẫn lệnh tay hoặc bot khác |
| 5 | **Magic lấy theo vị thế**: deal đóng bởi TP/SL server có thể không mang magic | Bản cũ có thể lọc mất deal đóng rổ |
| 6 | **File nến bot** `botbars_<symbol>_M1.csv`: mỗi nến M1 kèm cùng đặc trưng `b_*`, ghi nối thêm liên tục | So sánh "lúc bot vào lệnh" với "lúc đủ điều kiện nhưng bot không vào" |
| 7 | File `events_v2.csv` có thêm `time_msc` và `magic` | Tách sự kiện theo bot, thứ tự chính xác đến mili giây |
| 8 | Orders/symbols ghi lại theo nhịp timer thay vì sau mỗi deal | Rổ 20 lệnh đóng cùng lúc không làm ghi lại toàn bộ lịch sử 20 lần |
| 9 | Sửa lỗi: deal bị lọc ở lần xuất đầu nay được đánh dấu đã xử lý | Tránh phát lại 2 lần làm sai trạng thái rổ |

Các file cũ (`deals`, `orders`, `symbols`, `bars_*`) giữ nguyên tên. File `deals` chỉ **thêm cột ở cuối**, nên script cũ
đọc theo tên cột vẫn chạy.

## Cách chạy

1. Compile `TradeLogger.mq5` trong MetaEditor (F7). Môi trường của tôi không có MetaTrader nên chưa compile được;
   nếu có lỗi, gửi nguyên văn thông báo lỗi để tôi sửa.
2. Mở MT5 đăng nhập **tài khoản đang chạy bot gốc**. Nếu chỉ có mật khẩu xem (investor/Passview) cũng được.
3. Gắn TradeLogger lên một chart XAUUSD bất kỳ (chart khác chart của bot, hoặc terminal khác). Đặt:
   - `InpMagicFilter = 967488838`
   - `InpSymbolFilter` = đúng tên symbol (ví dụ `XAUUSDc`)
   - Tools → Options → Charts → **Max bars in chart** thật lớn (ví dụ 5 000 000), để đủ nến M1 cho cả lịch sử.
4. Lần đầu logger sẽ xuất toàn bộ lịch sử, gồm cả đặc trưng tính lại từ nến lịch sử. Sau đó để chạy cùng bot để ghi
   thêm dữ liệu tức thời.
5. Lấy file trong `MQL5/Files/` (hoặc `Common/Files` nếu bật `InpUseCommonFolder`): `tradelog_deals.csv`,
   `tradelog_events_v2.csv`, `tradelog_botbars_<symbol>_M1.csv`, `tradelog_symbols.csv`.
6. Chạy phân tích:

   ```
   python3 research/be_nha_trang/phan_tich_log.py tradelog_deals.csv --magic 967488838 --out bao_cao.md
   ```

## Giới hạn cần biết

- **Không chạy song song trong Strategy Tester**: Tester chỉ chạy một EA, nên logger không thấy lệnh của bot gốc
  trong backtest. Cần log từ tài khoản demo/thật đang chạy bot. Nếu chỉ có backtest, gửi report XML của Tester;
  cột `k_*` và `b_*` có thể tính lại bằng Python từ report cộng với dữ liệu nến.
- Cột `live_*` chỉ có với deal xảy ra **trong lúc logger đang chạy**. Với lịch sử cũ, các cột này để trống.
- Đặc trưng `b_*` tính lại từ nến lịch sử của sàn đang đăng nhập. Nếu bot chạy ở sàn khác, giá có thể lệch vài điểm.
- `k_lot_ratio` bị nhiễu khi lot nhỏ, vì làm tròn tới 0.01 (0.034 thành 0.03). Nên đọc cột "Lot" theo bậc trong báo
  cáo, và tách riêng giờ thường với giờ giảm lot.

## Đã kiểm thử

Tôi chạy `phan_tich_log.py` trên log giả lập, sinh từ một bot có tham số đã biết (tham số lấy từ file .set). Báo cáo
tìm lại được:
- khoảng cách từng bậc 150 / 250 / 350 / 200 pip;
- chuỗi lot 0.02 → 0.03 → 0.06 → 0.10 → 0.17 → 0.28 → 0.48 → 0.82 → 1.07 → 1.39;
- TP 150 pip, đóng bằng TP server;
- khung giảm lot 11h–5h;
- DCA đúng lúc mở nến.

Phần MQL5 của logger **chưa** được kiểm thử.

Cần tối thiểu khoảng 1–3 tháng log, có nhiều rổ sâu từ 8 lệnh trở lên, thì mới thấy đủ các bậc.
