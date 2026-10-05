# DAVID CRT V1 BASELINE

File EA: `MQL5/Experts/DAVID_CRT_V1_BASELINE.mq5`. Đây là bản Baseline dùng để backtest và làm chuẩn so sánh.

Bản này **không có**: FVG, OB, EMA, RSI, MACD, ADX, MSS/CHOCH, Session, News, BE, Trailing, Partial TP, DCA, Grid, Martingale, Hedge.

> **CHƯA XÁC NHẬN COMPILE BẰNG METAEDITOR.** Môi trường viết code không có MetaEditor. Hãy compile trong MetaEditor và báo lại số Errors/Warnings thực tế.

## Báo cáo logic (A–T)

**A. Cách lấy H4[0], H4[1], H4[2]:** `CopyRates(_Symbol, PERIOD_H4, 0, 3, rates)` với mảng dạng series. Khi đó `rates[0]` = H4[0] (đang chạy), `rates[1]` = H4[1] (vừa đóng), `rates[2]` = H4[2]. Code luôn dùng `PERIOD_H4`/`PERIOD_M15`/`PERIOD_M1`, không dùng `_Period`. Thời gian là timestamp nến của broker, không đổi múi giờ.

**B. Reference H4:** chính là H4[1]. `refTime` = open time của H4[1], `refEnd` = refTime + 4h.

**C. Active H4:** chính là H4[0]. `activeStart` = open time của H4[0], `activeEnd` = activeStart + 4h.

**D. Lúc khóa CRT Range:** Range chỉ được tạo khi `iTime(_Symbol, PERIOD_H4, 0)` đổi sang giá trị mới, tức có cây H4 mới và H4[1] đã đóng. Khi đó CRT High = High H4[1], CRT Low = Low H4[1]. Hai giá trị này không đổi trong suốt Active H4. Ngay trước khi gửi lệnh, EA đọc lại để kiểm tra (`ValidateCRTRangeBeforeTrade`).

**E. Bias BUY:** High H4[1] > High H4[2] (so sánh nghiêm ngặt).

**F. Bias SELL:** Low H4[1] < Low H4[2]. Nếu cả E và F cùng đúng thì Bias = BOTH.

**G. Sweep Low:**
- Nhận diện khi giá < CRT Low (nghiêm ngặt; chạm đúng biên không tính). Nguồn giá:
  - Bid của từng tick trong Active H4.
  - Low của các nến M1 **đã đóng** trong Active, dùng để bù tick bị lỡ hoặc phục hồi sau restart.
- Lần đầu xuyên: `lowSwept = true`, `sweepLow` = giá đó.
- Sau đó chỉ cập nhật khi xuyên sâu hơn. Thời điểm cập nhật được lưu lại để vẽ marker.

**H. Sweep High:** đối xứng với G, điều kiện giá > CRT High.

**I. Nến M15 Confirmation:** M15[1], tức nến vừa đóng (`CopyRates(PERIOD_M15, 1, 1)`). Mỗi nến chỉ được xét một lần (`lastM15Processed`).
- BUY: Low đã bị sweep, High chưa bị sweep, BUY được phép, và CRT Low < Close < CRT High.
- SELL: đối xứng.
- Nến xác nhận phải nằm trong Active và **đóng trước** Active End.

**J. Thời điểm Entry:** tại tick đầu tiên EA thấy M15[1] mới, tức tick đầu tiên sau khi nến xác nhận đóng. Lệnh là market order.

**K. Actual Entry:** lấy theo thứ tự ưu tiên: `DEAL_PRICE` của deal khớp, rồi `POSITION_PRICE_OPEN`. Ở các tick sau, EA tiếp tục làm mới giá này từ position. Dashboard và marker hiển thị giá khớp thật.

**L. SL:**
- BUY: Sweep Low − Khoảng_đệm_SL.
- SELL: Sweep High + Khoảng_đệm_SL.

**M. TP:**
- BUY: CRT High.
- SELL: CRT Low.

**N. RR:**
- BUY: (TP − Entry) / (Entry − SL).
- SELL: (Entry − TP) / (SL − Entry).
- Trước khi gửi lệnh, RR dự kiến được tính theo Ask/Bid để lọc (RR_tối_thiểu = 0 nghĩa là không lọc). Sau khi khớp, RR được tính lại theo giá khớp thật.

**O. Rectangle CRT:** từ (Active Start, CRT High) đến (Active End, CRT Low). Đường CRT High/Low là `OBJ_TREND` không kéo ray, chạy từ Active Start đến Active End. Khung Reference vẽ riêng từ refTime đến refEnd, nét chấm, có nhãn "CRT REFERENCE - REFERENCE ONLY".

**P. Sweep marker:** đặt tại (thời điểm, giá) của cực trị sweep thực tế. Marker di chuyển theo mỗi lần sweep sâu hơn.

**Q. Confirmation marker:** một đoạn ngang tại giá Close, kéo đúng từ open đến close của nến M15 xác nhận (ví dụ 12:30–12:45), nhãn "M15 CONFIRM BUY/SELL".

**R. Khôi phục sau restart:** state được ghi vào file `MQL5\Files\DAVIDCRT_<Symbol>_<Magic>.state`. Khi khởi động:
1. Tạo Range từ H4[1].
2. Chỉ nạp state nếu Reference time, High và Low trùng khớp.
3. Kiểm tra position và history deal (Symbol + Magic, deal IN trong Active) để nhận ra trạng thái TRADED/ACTIVE.
4. Quét lại các nến M1 đã đóng kể từ lần xử lý cuối.

Nếu có một Confirmation xảy ra trong lúc EA offline, Range được đánh dấu SIGNAL SKIPPED. EA không vào lệnh muộn.

**S. Tránh duplicate trade:**
- Mỗi Range chỉ có một lệnh. Cờ `traded` được bật và lưu vào file **trước khi** gửi `OrderSend`.
- Gửi lệnh thất bại thì Range bị bỏ (SIGNAL SKIPPED), EA không gửi lại.
- Mỗi nến M15 chỉ được xét một lần.
- Lúc restart, EA kiểm tra position và history để nhận ra Range đã trade.

**T. Tránh look-ahead:**
- Reference chỉ được tạo sau khi H4 đã đóng.
- Confirmation chỉ dùng nến M15 đã đóng.
- Sweep chỉ dùng giá đã thực sự xảy ra: tick hiện tại hoặc nến M1 đã đóng. EA không bao giờ dùng High/Low của toàn bộ cây H4 Active.

## Các điểm diễn giải (cần bạn xác nhận)

1. **Nến M15 cuối cùng của Active (15:45–16:00) không được dùng làm Confirmation.** Nến này đóng đúng lúc 16:00, tức Range đã EXPIRED (quy tắc 32: "chưa có Confirmation trước 16:00 → EXPIRED"). Hơn nữa Entry lúc 16:00 nằm ngoài Active, sẽ không qua được bước validate ở quy tắc 78. Vì vậy nến M15 cuối cùng được phép xác nhận là 15:30–15:45.
2. **Sweep vẫn được theo dõi ở cả hai phía, kể cả phía không có bias.** Ví dụ Bias chỉ SELL mà Low bị sweep thì status là LOW SWEPT (không BUY). Nếu sau đó High cũng bị sweep thì Range INVALID BOTH SIDES.
3. **Nguồn giá của sweep là Bid,** giống nến chart MT5.
4. **Bộ lọc khi đã có Confirmation:**
   - Sweep_tối_thiểu chưa đạt: bỏ qua Confirmation này và tiếp tục chờ.
   - Sweep_tối_đa bị vượt, Spread quá cao, RR quá thấp, lỗi Volume/StopsLevel/Margin, hoặc OrderSend thất bại: Range chuyển sang **SIGNAL SKIPPED** (đã dùng), ghi log lý do. Đây là status bổ sung ngoài danh sách gốc.
5. **Lot theo risk được làm tròn xuống theo Volume Step.** Nếu lot tính ra nhỏ hơn Volume Min thì bỏ lệnh và ghi log, không ép dùng lot tối thiểu.
6. **StopsLevel/FreezeLevel không đạt:** bỏ lệnh, không tự sửa SL. EA không có BE hay Trailing nên không có lệnh Modify nào.
7. **Spread_tối_đa mặc định = 0.50 (đơn vị giá).** Đặt 0 để tắt bộ lọc.
8. **Không giới hạn số position mở cùng lúc giữa các Range khác nhau,** vì chiến lược gốc không quy định.
9. **Trong Strategy Tester, EA không ghi state file** (Tester không có restart). Object chỉ được vẽ khi bật Visual mode.

## Đề xuất nghiên cứu sau (KHÔNG có trong Baseline)

- Cho phép nến M15 đóng đúng lúc Active End làm Confirmation, rồi so sánh kết quả.
- Giới hạn tối đa một position mở cùng lúc.
- Thử Sweep_tối_thiểu và RR_tối_thiểu khác 0.
