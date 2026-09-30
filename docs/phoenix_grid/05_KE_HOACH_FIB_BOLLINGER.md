# Phoenix Market Intelligence — Kế hoạch nghiên cứu Fibonacci + Bollinger Bands

**DAVID HUNTER – PHOENIX GRID – 0941920986**

| Mục | Giá trị |
|---|---|
| Phiên bản tài liệu | PG-MI-0.1, đề xuất |
| Ngày | 30/09/2026 |
| Trạng thái | **CHỜ DUYỆT.** Chưa sửa mã nguồn. Chưa chạy kiểm định nào |
| Nguồn yêu cầu | Tin nhắn "BỔ SUNG TƯ DUY FIBONACCI + BOLLINGER BANDS" (30/09/2026), 8 ảnh tài liệu, file `M2_FIBO.set` |
| Quan hệ với kế hoạch PG-R0.0 | Bổ sung. Không đổi tiêu chí nghiệm thu đã đóng băng (commit `47480fe`) |

Tài liệu đi theo đúng 10 việc ở mục XXIII của yêu cầu. Mỗi mục dưới đây ứng với một việc.

## Trọng tâm theo phản hồi ngày 30/09/2026

Bạn nhắn: "Đây là tài liệu tham khảo, suy cho cùng sẽ là tối ưu entry đầu vào lệnh, bộ pp riêng và kiểm soát
volume." Vì vậy Fib + Bollinger chỉ là **một nguồn ứng viên**, phục vụ ba mục tiêu theo thứ tự ưu tiên:

| Ưu tiên | Mục tiêu | Fib + Bollinger đóng góp gì | Phần kiểm định |
|---|---|---|---|
| 1 | **Tối ưu lệnh vào đầu tiên** của basket | Bộ lọc "không bắt dao rơi" cho entry baseline PP1; entry thuận xu hướng sau breakout | T1 (có thông tin không), T2-1, T2-2 |
| 2 | **Bộ PP riêng của Phoenix** | PP10 (Fib + Bollinger pullback) là một ứng viên, kiểm cùng luật Cổng A với PP1–PP9. Bộ PP cuối cùng gồm các PP qua Cổng A, định tuyến theo trạng thái thị trường (Mục 7.1, điểm 8 của kế hoạch) | T2-2, Cổng A |
| 3 | **Kiểm soát volume** | Bỏ hoặc hoãn bậc DCA, tỉa x% khi bối cảnh xấu: giảm số tầng, giảm exposure lớn nhất. Không bao giờ tăng lot | T3-G, T3-F |

Hạ xuống **làm sau, không bắt buộc**:

- mức thoát 127,2% / 161,8%;
- các tổ hợp H, I, J;
- học trọng số cho điểm số.

Lot theo độ mạnh tín hiệu (chỉ được **giảm** lot) là một mục riêng. Nó cần kiểm định riêng và bạn duyệt riêng, như
mục XVI của yêu cầu.

## 0. Tóm tắt

1. **Phoenix chưa có baseline giao dịch để so sánh.** Mã nguồn hiện có là EA quan sát V0.10/V0.11, không gửi lệnh.
   Lot, DCA, basket TP, hedge, tỉa lệnh và recovery mới là thiết kế đã duyệt trong kế hoạch. Chúng chưa được lập trình
   và chưa được kiểm định. Biến thể A ("Phoenix Baseline") vì vậy phải được dựng trước. Nó là điều kiện tiên quyết
   của mọi so sánh F–J.
2. **`M2_FIBO.set` thuộc một EA khác:** `VuTru_Fibo_BB_Pullback` (Magic 20260921). Mã nguồn EA này không có trong repo
   nào tôi đọc được. SET được chọn từ tối ưu hóa 16 tham số, không gian khoảng 1,16 × 10¹⁸ tổ hợp, và 5 giá trị nằm
   sát biên khoảng tối ưu. Vì vậy "khá hiệu quả" nhiều khả năng là kết quả trong mẫu. Cần báo cáo tester và mã nguồn
   để đánh giá ngoài mẫu (Mục 2).
3. **Phương pháp trong ảnh là giao dịch thuận xu hướng khi giá hồi, và ảnh ghi "không vào lệnh khi thị trường đi
   ngang".** Điều này ngược với lõi Phoenix (vào lệnh trong hộp sideways). Chỗ hợp lý của Fib + Bollinger trong Phoenix
   là bốn vai trò:
   - Hiểu nhịp sau breakout và vùng mới.
   - Chặn "bắt dao rơi" khi vào lệnh và khi DCA.
   - Chọn vùng giảm exposure (tỉa).
   - Chọn vùng cảnh báo hoặc thoát.

   Fib + Bollinger không thay entry sideways của Phoenix.
4. **Nhiều thành phần đã có trong kế hoạch:**
   - Bollinger là cùng một đại lượng với độ lệch z của PP2.
   - Độ rộng Bollinger có ở PP8a.
   - Nến xác nhận là PP3; bằng chứng V4.39: PIN lỗ ở gần như mọi input.
   - Nhịp hồi sau breakout là PP6. Mức S/R là PP7.

   Đề xuất gom thành một lớp **Market Intelligence (MI)** dùng chung, thay vì thêm nhiều phương pháp rời.
5. **Nguyên tắc an toàn đề xuất: MI chỉ được làm giảm rủi ro.** MI được phép bỏ hoặc hoãn một bậc DCA, tỉa bớt, hoặc
   phòng thủ **sớm hơn**. MI không được thêm lệnh, tăng lot, hay làm phòng thủ **muộn hơn** các mốc cứng
   D_h / D_stop đã duyệt.
6. **Kiểm định 4 tầng, dừng sớm nếu tầng trước âm** (Mục 7–8):

   | Tầng | Nội dung |
   |---|---|
   | T0 | Ghi đặc trưng MI "bóng", không tác động quyết định |
   | T1 | Nghiên cứu sự kiện: giá có phản ứng tại vùng Fib / Band **hơn hẳn** mức ngẫu nhiên không |
   | T2 | Entry dạng lệnh đơn (luật Cổng A) |
   | T3 | DCA / tỉa / thoát trên basket baseline |

   Tổng ngân sách **≤ 96 biến thể đăng ký trước**. Không tối ưu di truyền trên không gian lớn.
7. **Cần bạn quyết định** (Mục 10):
   - Duyệt kế hoạch.
   - Gửi mã nguồn `VuTru_Fibo_BB_Pullback` và báo cáo tester của SET M2.
   - Xuất nến M1 XAUUSDc 01/2024 → nay (file nhỏ, đủ cho T1).
   - Cho biết có tiếp tục V0.20 (hạ tầng lệnh + LAB, không có Fib) song song hay chờ.

## 1. Hiện trạng Phoenix — đọc từ mã nguồn, không suy đoán

Mã nguồn đã đọc:

- `MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_10_TEST.mq5` và `EA_PHOENIX_GRID_V0_11_TEST.mq5` (bản hiện hành).
- Script `MQL5/Scripts/PhoenixGrid/PG_R01_DocThongSo.mq5`.
- Toàn bộ `docs/phoenix_grid/` và `research/phoenix_grid/`.
- `README.md` của Phoenix (`docs/phoenix_grid/README.md`). README ở gốc repo thuộc một dự án khác (EA ICT).
- Repo này không có `AGENTS.md`. Quy tắc làm việc lấy theo `AGENTS.md` của EA-PRO, đã đọc lại ngày 30/09/2026.

| Hạng mục (mục I.4 của yêu cầu) | Trong mã nguồn hiện tại | Trong kế hoạch đã duyệt (chưa lập trình) |
|---|---|---|
| Mở basket, lệnh đầu | **Chưa có.** V0.11 không gửi lệnh | PP đã qua Cổng A; trạng thái NORMAL (Mục 7, 12.2) |
| DCA / Grid, khoảng cách tầng | **Chưa có** | DCA-1…6; k_d = 0,6–1,5 × ATR5; tối đa 4 bậc ở 5.000 USC (Mục 9) |
| Lot progression | **Chưa có** | PB-1…4; lot tính từ R_b (Mục 8.2 (2), 9.4) |
| TP/SL lệnh | **Chưa có** | SL thảm họa phía server tại D_stop |
| Basket TP/SL | **Chưa có** | TP ròng 0,5–1,5 × ATR5; mức phòng thủ D_h / D_stop |
| Trailing | **Không có**, cả trong kế hoạch | — |
| Break Even | **Không có**, cả trong kế hoạch | — (SET VuTru có BE sau TP1) |
| Tỉa lệnh | **Chưa có** | C6 tỉa cặp trong chu kỳ thường; RC-3 tỉa bằng quỹ Π; RC-4 tháo hedge (Mục 9.5, 11) |
| Quản trị vốn | Chỉ **hiển thị ước tính** (V0.11) | E_ref, α = 0,5; r_b = 1% mỗi basket (Mục 8.6, 21) |
| Giới hạn Drawdown | Chỉ **hiển thị** DD (V0.11) | Tầng 5 / 8 / 12%; lỗ ngày 10% (Mục 8.2 (5)) |
| Logging | **Có:** CSV trạng thái thị trường theo tháng | CSV lệnh / basket / sự kiện |
| Recovery / khởi động lại | **Có:** dựng lại trạng thái cấu trúc từ 24 nến M5. Chưa có khôi phục lệnh | RC-0a…RC-5; file trạng thái + đối chiếu vị thế (Mục 4.3, 11) |
| Chạy REAL | **Không.** V0.11 không gửi lệnh | Chỉ sau G3 và quyết định LIVE_REAL |
| Nhận diện thị trường | **Có** (Mục 6): hộp M5, ATR, ADX, ER, độ dốc, chạm biên; cảnh báo, xác nhận, breakout giả, vùng mới theo tick | A0 đánh giá bộ phân loại |

Hệ quả: câu "không được tự ý thay đổi BUY/SELL, Lot, Risk, Grid, DCA, SL/TP, BE, Trailing hiện tại" áp dụng cho
**baseline sau khi được dựng và duyệt**. Hiện chưa có giá trị "hiện tại" nào cho các mục này để giữ nguyên.

Về V0.20: bản nháp V0.20 (hạ tầng lệnh + LAB lệnh đơn PP1) **đã dừng** theo yêu cầu "BÂY GIỜ CHƯA SỬA CODE". Bản
nháp chưa được đưa vào repo và không chứa logic Fib / Bollinger.

## 2. File SET `M2_FIBO.set`

SET lưu ngày 22/09/2026, cho EA `VuTru_Fibo_BB_Pullback`, Magic 20260921. Mã nguồn EA này không có trong repo
Davidtruong202 (mọi nhánh) hay EA-PRO (mọi nhánh, Releases). Nhánh `claude/new-session-qtvl95` có một EA khác cùng ý
tưởng (`FiboBB_Swing_EA.mq5`, Magic 20260922), không phải EA của SET này.

Các tham số dưới đây đọc từ SET. Cột "Tối ưu" = cờ `Y` trong SET: tham số đó có khoảng quét trong lần tối ưu hóa.

| Nhóm | Giá trị trong SET | Tối ưu (khoảng quét) |
|---|---|---|
| Xu hướng | EMA 53 trên khung hiện tại; độ dốc EMA trên 12 nến; ADX(14) ≥ 27; ATR tối thiểu 30 "pips" | EMA 50–200; độ dốc 5–15; ADX 15–30; ATR 15–30 |
| Fibonacci | Nhịp đẩy trong 52 nến, dài ≥ 3 × ATR; nhịp hồi 4–9 nến; vùng 0,5–0,618 ± 0,05; mất hiệu lực tại 0,786; `CloseBackZone` = true | Nhịp đẩy 30–60; nhịp hồi tối đa 5–30, tối thiểu 2–5 |
| Bollinger | BB(11; 2,4); chạm trong 1 nến; dung sai chạm 0,15 × ATR | Chu kỳ 10–25; độ lệch 1–3; số nến 1–5; dung sai 0,10–0,30 |
| Nến xác nhận | Pin bar (bấc ≥ 77%), engulfing, star | Bấc 0,60–0,80 |
| SL | Chế độ 0; SL = 1,1 × ATR(14), kẹp trong [0,29; 2,4] × ATR; đệm 0,2 × ATR | Chế độ 0–2; hệ số 0,5–1,5; min 0,2–0,3; max 2–3 |
| TP | Chia lệnh 50% / 30% / phần còn lại; mở rộng 1,272 / 1,618; RR TP1 tối thiểu 0,5; dời BE sau TP1 (+5 "pips") | — |
| Vốn | Chế độ lot 0; lot cố định 0,05; `InpRiskPct` = 1 | — |
| Lọc giờ, tin | Tắt cả hai | — |

**Nhận định về SET:**

- **Không gian tối ưu rất lớn.** 16 tham số, khoảng 1,16 × 10¹⁸ tổ hợp. Trình tối ưu di truyền của MT5 chỉ thử một
  phần rất nhỏ rồi chọn kết quả tốt nhất trên cùng dữ liệu. Kết quả tốt nhất của một tìm kiếm lớn như vậy thường lệch
  lên cao so với hiệu suất thật (lỗi chọn lọc).
- **Năm giá trị nằm sát biên khoảng quét:**
  - EMA 53 (biên dưới 50);
  - ATR tối thiểu 30 (đúng biên trên);
  - BB 11 (biên dưới 10);
  - số nến chạm 1 (biên dưới);
  - chế độ SL 0 (biên dưới).

  Giá trị tốt nhất nằm ở biên thường nghĩa là tối ưu thật có thể ở ngoài khoảng đã quét, hoặc tham số đang bắt nhiễu.
- **Chưa xác định được nếu không có mã nguồn:**
  - "pips" = 0,01 hay 0,1 USD;
  - chế độ lot 0 là lot cố định (lúc đó `InpRiskPct` = 1 không có tác dụng) hay theo rủi ro;
  - chế độ SL 0 là gì;
  - `CloseBackZone` hoạt động thế nào.
- **Chi phí trên M2 với tài khoản Cent.** Đo trên nến M1 XAUUSDm 2026: ATR14 trên M2 có trung vị 3,24 USD (p10 1,93;
  p90 6,76). Với c_rt ≈ 0,36 USD (spread 0,26 + trượt 0,05 × 2):
  - SL 1,1 × ATR trung vị = 3,56 USD → chi phí bằng **10% SL**, đúng giới hạn của kế hoạch (Mục 7.1).
  - SL chạm mức kẹp dưới 0,29 × ATR → chi phí khoảng **38% SL**.

  Nhiều lệnh M2 vì vậy có thể bị chi phí ăn phần lớn lợi thế.
- **Lot cố định 0,05 trên tài khoản 5.000 USC.** 100 USD giá đi ngược = 500 USC = 10% tài khoản với một lệnh. Nếu chế
  độ lot 0 là lot cố định, SET này không tuân theo ngân sách 1% của Phoenix.

**Cách đánh giá SET một cách công bằng:** đóng băng nguyên SET, rồi chạy trên dữ liệu **chưa dùng để tối ưu**. Cùng
symbol XAUUSDc, cùng chế độ tick, cùng spread, cùng vốn. So với chính nó trên đoạn đã tối ưu. Đây là 1 cấu hình, không
tối ưu lại. Việc này cần:

- báo cáo tester gốc: symbol, khoảng ngày, chế độ tick, spread, vốn, đòn bẩy, kết quả;
- khoảng ngày và tiêu chí đã dùng khi tối ưu;
- mã nguồn EA, hoặc bạn tự chạy tester theo khoảng ngày tôi đề xuất.

## 3. Phân tích tài liệu ảnh

Nội dung 8 ảnh, chép lại để định lượng. Các câu như "xác suất cao", "đặc biệt hiệu quả với XAUUSD" là **nhận định
của tài liệu, không phải bằng chứng**.

| Chủ đề | Nội dung trong ảnh |
|---|---|
| BUY, 5 bước | (1) Xu hướng chính tăng. (2) Giá hồi về Fib 50%–61,8%. (3) Giá chạm hoặc xuyên nhẹ Band dưới. (4) Nến xác nhận tăng: pin bar, bullish engulfing, morning star. (5) Vào BUY khi nến xác nhận đóng cửa |
| SELL, 5 bước | Đối xứng. Nến xác nhận giảm: shooting star, bearish engulfing, evening star |
| Stop loss | BUY: dưới đáy gần nhất hoặc dưới Band dưới. SELL: trên đỉnh gần nhất hoặc trên Band trên. "SL hợp lý: 0,5–1 ATR" |
| Take profit | TP1 đỉnh / đáy gần nhất; TP2 Extension 127,2%; TP3 Extension 161,8%. Chốt từng phần 50% / 30% / 20% |
| Vai trò Fibonacci | 38,2% hồi nông, tiếp tục xu hướng; 50% vùng cân bằng; 61,8% "vùng hồi đẹp nhất"; 78,6% hồi sâu; 100% mức xa nhất. Xu hướng tăng: Fib từ đáy lên đỉnh; giảm: từ đỉnh xuống đáy |
| Vai trò Bollinger | Band trên: dễ bị từ chối. Band dưới: dễ bật lên. Band giữa (MA20): giá thường quay về kiểm tra. Co hẹp: tích lũy, sắp bùng nổ. Mở rộng: xu hướng mạnh, biến động cao |
| Quản trị vốn | Rủi ro 1–2% mỗi lệnh; khối lượng theo SL; không gồng lệnh |
| Tránh giao dịch | Tin mạnh (NFP, CPI, FOMC); thị trường đi ngang; biến động quá thấp; tín hiệu không rõ |

**Điểm mâu thuẫn và rủi ro trong chính tài liệu:**

- "Band dưới: dễ bật lên" và "Band mở rộng: xu hướng mạnh" có thể xảy ra cùng lúc. Trong xu hướng giảm mạnh, giá
  chạy dọc Band dưới. Đúng như yêu cầu của bạn: không dùng "chạm Band = vào lệnh".
- "SL dưới đáy gần nhất" và "SL 0,5–1 ATR" không phải lúc nào cũng khớp nhau. Cần quy tắc kẹp SL rõ ràng.
- Rủi ro 1–2% mỗi lệnh khác ngân sách đã duyệt của Phoenix (r_b = 1% mỗi basket). Phoenix giữ mức 1% của mình.

## 4. Đối chiếu với kiến trúc Phoenix

| Thành phần của phương pháp | Đã có trong Phoenix (mã hoặc kế hoạch) | Phần mới cần thêm |
|---|---|---|
| Xu hướng chính | Bộ phân loại TĂNG/GIẢM: ADX, DI, ER, độ dốc (mã V0.11) | Xu hướng theo cấu trúc swing (HH/HL, LH/LL); EMA + độ dốc như SET |
| Swing hợp lệ | Fractal 2 nến khi đếm chạm biên (mã); swing PP3 (kế hoạch) | Swing theo ATR (zigzag có ngưỡng), độ dài nhịp tối thiểu |
| Vùng Fib | Không có | Mức hồi 38,2 / 50 / 61,8 / 78,6 của nhịp đẩy đang hiệu lực; mở rộng 127,2 / 161,8 |
| Bollinger | PP2: z = (giá − EMA) / σ, cùng bản chất với %b của Bollinger; PP8a: phân vị độ rộng Bollinger(20) | %b, độ rộng (BBW), phân vị BBW, tốc độ mở rộng, "chạy dọc band" |
| Nến xác nhận | PP1 (b): nến M1 từ chối; PP3; bằng chứng V4.39: PIN lỗ | Engulfing, morning/evening star, định nghĩa định lượng |
| Pullback thuận xu hướng | PP6: pullback sau breakout (vùng mới) | Pullback về Fib của nhịp breakout |
| Vùng S/R cho DCA, tháo hedge | PP7 → DCA-3, TH-1 | Fib như một loại mức S/R thứ 5 |
| Thời điểm tránh | Bộ lọc spread, phiên, giờ nghỉ (mã); tin tức DL-05 (thiếu dữ liệu) | Chưa có lịch tin |

**Kết luận đối chiếu.** Phương pháp trong ảnh là tổ hợp của các phần Phoenix đã có kế hoạch (PP2, PP3, PP6, PP7,
PP8a) cộng với hai phần mới: **swing theo cấu trúc** và **vùng Fib**. Kiến trúc MI ở Mục 6 xây hai phần mới và dùng
lại các phần cũ.

## 5. Fib + Bollinger có thể tác động ở đâu

| Giai đoạn | Câu hỏi MI trả lời | Ví dụ quy tắc cần kiểm định | Giới hạn an toàn |
|---|---|---|---|
| PHÂN TÍCH | Thị trường đang tích lũy, xu hướng, hay hồi trong xu hướng? | Phân vị BBW < p20 là tích lũy, > p80 là mở rộng. Vị trí giá so với nhịp đẩy gần nhất (độ sâu hồi r) | Chỉ bổ sung đặc trưng cho bộ phân loại. Không thay định nghĩa Mục 6 trước A0 |
| ENTRY lệnh đầu basket | Vào lúc này có phải "bắt dao rơi" không? Hướng nào hợp lý? | Bỏ BUY của PP1 khi BBW mở rộng mạnh xuống, giá đóng dưới Band dưới ≥ 2 nến, cấu trúc giảm | Chỉ được **bỏ** lệnh, không thêm lệnh ngoài PP đã duyệt |
| ENTRY vùng mới / sau breakout | Nhịp hồi sau breakout đã về vùng hợp lý chưa? | Sau breakout ↑: giá hồi về Fib 50–61,8% của nhịp breakout và chạm Band dưới, có nến xác nhận → ứng viên PP10 (hoặc biến thể của PP6) | Qua Cổng A như mọi PP |
| DCA | Có nên thêm bậc ngay, chờ, hay bỏ bậc? | Bỏ hoặc hoãn bậc khi: cấu trúc ngược bị phá, BBW mở rộng về phía ngược basket, không có phản ứng tại vùng. Ưu tiên bậc tại hợp lưu Fib / biên hộp có nến từ chối | Chỉ **bỏ hoặc hoãn**. Không thêm bậc, không tăng lot, không vượt n_max và R_b |
| HOLD / phòng thủ | Basket đang lỗ là nhịp hồi hay đổi xu hướng? | Phá cấu trúc + BBW mở rộng ngược → phòng thủ **sớm hơn** D_h | Không được hoãn phòng thủ quá D_h / D_stop |
| TỈA | Khi nào giảm exposure? | Basket BUY: giá lên tới Band trên + vùng Fib / kháng cự + nến từ chối → tỉa x% | Chỉ giảm exposure |
| EXIT | Mức 127,2% / 161,8% có giá trị không? | Dùng làm vùng cảnh báo, tỉa hoặc thoát, so với basket TP baseline | Không thay basket TP trước khi có kết quả |

**Một điểm quan trọng về tỉa lệnh**, suy ra từ đẳng thức kế toán ở Mục 5 của kế hoạch:

- Đóng lệnh không làm Equity thay đổi tại thời điểm đóng. Tỉa chỉ đổi **exposure còn lại** và chi phí về sau.
- Với basket lot bằng nhau (PB-1, phương án khả thi ở 5.000 USC), các kiểu tỉa A (lệnh lời nhất), B (entry xấu nhất),
  C (tầng ngoài cùng) và E (theo tầng) để lại **cùng một exposure** khi tỉa cùng khối lượng. Chúng chỉ khác nhau ở:
  - cách chia lãi đã thực hiện và lãi/lỗ thả nổi;
  - giá vốn của phần còn lại, tức mức TP basket;
  - swap của từng chân.
- Kiểu F (Pair Close) chỉ có nghĩa khi basket có cả BUY và SELL, tức sau khi hedge hoặc ở lưới hai chiều (C5).

Vì vậy ma trận tỉa có thể thu gọn: câu hỏi chính là **tỉa bao nhiêu và lúc nào**, không phải tỉa ticket nào.

## 6. Kiến trúc module Market Intelligence (đề xuất)

MI là một lớp **chỉ đọc**: tính đặc trưng và điểm số, không gửi lệnh. Có hai bản hiện thực với cùng định nghĩa:

- Python `research/phoenix_grid/mi.py` để nghiên cứu.
- MQL5 trong EA (sau khi được duyệt) để chạy ở chế độ bóng, rồi mới đến chế độ ra quyết định.

| Khối | Tính gì | Tham số (khoảng để kiểm định) |
|---|---|---|
| MI.Swing | Đỉnh/đáy xác nhận theo zigzag ATR: đảo chiều ≥ k_sw × ATR thì chốt swing. Nhịp đẩy hợp lệ: dài ≥ k_imp × ATR, trong ≤ N_imp nến. Chuỗi HH/HL → cấu trúc tăng. Đóng cửa vượt swing gần nhất = phá cấu trúc (BOS) | k_sw ∈ {2; 3}; k_imp ∈ {3; 5}; N_imp ∈ {30; 60} nến |
| MI.Fib | Trên nhịp đẩy đang hiệu lực: mức hồi 38,2 / 50 / 61,8 / 78,6; độ sâu hồi r hiện tại; mở rộng 127,2 / 161,8 | Vùng ∈ {38,2–50; 50–61,8; 61,8–78,6}; dung sai ∈ {0; 0,05}. Mất hiệu lực khi r > 0,786, khi có đỉnh/đáy mới vượt nhịp, hoặc sau T_set nến |
| MI.BB | BB(n, k) → %b, BBW = (trên − dưới) / giữa, phân vị BBW trong cửa sổ, tốc độ mở rộng, "chạy dọc band" (đóng ngoài/tại band m trong n nến gần nhất) | n ∈ {11; 20}; k ∈ {2,0; 2,4}; cửa sổ phân vị 1 và 5 ngày |
| MI.Nến | Pin bar, engulfing, morning/evening star, nến từ chối. Định nghĩa bằng tỷ lệ thân/bấc (Mục 9) | Bấc pin ∈ {0,6; 0,75} |
| MI.Động lượng | Dùng lại: tốc độ tick v, ADX/DI và độ dốc ADX, ER, độ dốc β (có sẵn trong V0.11) | — |
| MI.Điểm số | BUY / SELL / DCA / TRIM / EXIT score từ các thành phần. Bản đầu: cộng điểm có dấu {−1; 0; +1}, trọng số bằng nhau, **đăng ký trước**, không học trọng số | Ngưỡng ∈ {2; 3} thành phần đồng thuận |
| MI.Nhật ký bóng | Ghi toàn bộ đặc trưng và "quyết định MI sẽ làm" tại mỗi điểm quyết định của Phoenix, không tác động | — |

**Khung thời gian:** Phoenix dùng M5 cho cấu trúc và M1 cho thực thi. SET dùng M2. Đề xuất đăng ký trước hai lựa chọn
M5 và M2 cho MI, rồi so sánh.

**Điểm số (Market Score)** chỉ được giữ nếu tốt hơn quy tắc đơn giản ở VAL. Học trọng số (ví dụ hồi quy logistic có
điều chuẩn) chỉ làm khi bản cộng điểm đơn giản đã cho thấy giá trị. Khi đó mô hình học trên DEV, kiểm trên VAL.

## 7. Kế hoạch kiểm định: Backtest và Shadow Test

Mọi so sánh chạy trên **cùng** symbol, dữ liệu, khoảng ngày, spread, commission, vốn, đòn bẩy, khung thời gian và
điều kiện tester, đúng mục XVII của yêu cầu. Chia dữ liệu DEV / VAL / TEST theo Mục 14 của kế hoạch. Tiêu chí thống kê
dùng lại Mục 13.9 và 16.

### T0 — Chế độ bóng (không tác động)

- Tính đặc trưng MI tại mọi nến M2/M5 và tại mọi điểm quyết định của Phoenix: tín hiệu Entry, ứng viên DCA, ứng viên
  tỉa, thoát.
- Ghi vào log. Quyết định của Phoenix không đổi.
- Dùng cho T1–T3, và để đối chiếu Python với MQL5 như đã làm với bộ phân loại.

### T1 — Nghiên cứu sự kiện (không có chiến lược, không có lot)

| Mã | Câu hỏi | Cách đo | Mốc so sánh (null) | Lưới |
|---|---|---|---|---|
| T1a | Giá có phản ứng tại mức Fib hơn các mức khác không? | Với mỗi nhịp đẩy hợp lệ: lần đầu giá hồi chạm mỗi mức. "Bật" = đi tiếp ≥ 1 × ATR theo xu hướng trước khi xuyên thêm ≥ 1 × ATR | 12 mức đối chứng r ∈ [0,30; 0,85] không trùng mức Fib (± 0,02). Kiểm định hoán vị | Khung {M2; M5} × k_sw {2; 3} × k_imp {3; 5} = **8** |
| T1b | Chạm Band có phải điểm đảo chiều không, và khi nào là "chạy dọc band"? | Lợi nhuận tương lai 5/15/60 phút (đơn vị ATR), tách theo bối cảnh: hồi ngược xu hướng; chạm theo chiều xu hướng; SIDEWAYS; phân vị BBW | Thời điểm ngẫu nhiên trong cùng bối cảnh | Khung {M2; M5} × BB {(11; 2,4); (20; 2,0)} = **4** |
| T1c | BBW có dự báo biến động và breakout tốt hơn đặc trưng hiện có không? | AUC dự báo "breakout trong 60 phút" và biên độ 60 phút | Đặc trưng hiện có: W/ATR5, ADX, ER, cảnh báo tick | **4** |

Kết luận T1 đi tiếp như sau:

- **T1a không vượt null** (sau hiệu chỉnh Holm): Fib không mang thông tin về phản ứng giá trên dữ liệu này. Fib bị
  loại khỏi mọi vai trò ở T2–T3.
- **T1b cho thấy chạm Band trong xu hướng mở rộng là tiếp diễn**: đây là bằng chứng cho bộ lọc "không bắt dao rơi".

### T2 — Entry dạng lệnh đơn (luật Cổng A, Mục 7.1 và 16.1)

| Mã | Nội dung | Lưới |
|---|---|---|
| T2-1 | **MI làm bộ lọc cho PP1** (entry baseline của Phoenix). So PP1 có lọc với PP1 không lọc trên cùng tín hiệu, cùng cách thoát. Lọc: (i) bối cảnh Bollinger (bỏ khi chạy dọc band ngược chiều); (ii) cấu trúc (bỏ khi vừa phá cấu trúc ngược); (iii) cả hai; (iv) thêm nến xác nhận | 4 bộ lọc × khung {M2; M5} = **8** |
| T2-2 | **PP10: Fib + Bollinger pullback thuận xu hướng**, gồm các bản cắt bỏ tương ứng biến thể B–E. Vùng Fib × Band (có/không) × nến xác nhận (có/không) × khung. Thoát: SL sau swing / band có kẹp 0,5–1,5 × ATR; một TP tại swing gần nhất. Chốt từng phần để sang T3 | 3 vùng × 2 × 2 × 2 = **24**, và mốc ngẫu nhiên cùng bối cảnh |
| T2-3 | **SET M2 đóng băng** trên dữ liệu ngoài mẫu (cần mã nguồn hoặc bạn chạy tester) | **1** |

PP10 là phương pháp **mới**. Đưa PP10 vào ma trận cần bạn duyệt (phiên bản kế hoạch mới), như đã ghi ở Mục 21.

### T3 — Basket (cần baseline chu trình Phoenix)

Chỉ chạy các thành phần đã qua T1–T2 ở mức tương ứng.

| Biến thể theo yêu cầu | Nội dung | Điều kiện chạy | Lưới |
|---|---|---|---|
| A | Phoenix Baseline: PP đã duyệt + DCA + basket TP + phòng thủ (sau Giai đoạn C, D) | Baseline đã dựng | 1 |
| B, C, D, E | Entry của basket thêm Fib / Bollinger / cả hai / thêm nến | Qua T2-1 | ≤ 4 |
| G | MI chỉ hỗ trợ DCA: bỏ hoặc hoãn bậc | T1a hoặc T1b dương | ≤ 6 |
| F | MI chỉ để tỉa: tỉa x% ∈ {33; 50}% khi điểm tỉa ≥ ngưỡng. Kiểu tỉa rút gọn theo Mục 5 | T1 dương | ≤ 8 |
| Thoát | Mức 127,2 / 161,8 làm vùng cảnh báo / tỉa / thoát, so với TP baseline | T1a dương | ≤ 4 |
| H, I, J | Tổ hợp: Entry + Tỉa; DCA + Tỉa; toàn bộ vòng đời | **Chỉ** khi từng thành phần qua riêng | ≤ 6 |

Mỗi biến thể báo **đủ 23 chỉ số ở mục XVIII của yêu cầu**, cộng các chỉ số basket của kế hoạch: Gross/Net lớn nhất,
CVaR95 basket, thời gian kẹt. Báo cả biến thể thất bại. Không kết luận biến thể phức tạp nhất là tốt nhất: khi hai
biến thể không khác nhau có ý nghĩa, chọn biến thể đơn giản hơn.

**Ngân sách:**

- Phần ưu tiên: T1 16 + T2 33 + T3-G 6 + T3-F 8 = **63 biến thể**.
- Phần làm sau (thoát 4, B–E 4, H–J 6): thêm 14, tổng **≤ 88 biến thể đăng ký trước**, dưới trần 96.
- Hiệu chỉnh Holm trong từng họ biến thể.

**Chống overfit (mục XX của yêu cầu):**

- Lưới đăng ký trước, 2–3 giá trị mỗi tham số.
- Không tối ưu di truyền trên không gian lớn.
- DEV → VAL → TEST chạy một lần.
- Walk-forward 6 tháng / 2 tháng.
- Kiểm tra độ nhạy với điểm lân cận: đổi một tham số một nấc mà kết quả sụp → đánh dấu quá khớp.
- PBO (CSCV) ở cấp tổ hợp.

## 8. Thứ tự kiểm định, từ đơn giản đến phức tạp

| # | Bước | Cần gì | Nếu âm thì |
|---|---|---|---|
| 1 | T0: viết `mi.py` (swing, Fib, BB, nến) và tự kiểm tra trên dữ liệu giả | Bạn duyệt kế hoạch | — |
| 2 | T1a: Fib so với mức ngẫu nhiên | Nến M1 XAUUSDc 2024–2025 (DEV) | Bỏ Fib khỏi T2–T3 |
| 3 | T1b, T1c: Bollinger và BBW | Như trên | Bỏ Bollinger khỏi vai trò tương ứng |
| 4 | T2-3: SET M2 đóng băng, ngoài mẫu | Mã nguồn VuTru hoặc bạn chạy tester | Ghi nhận SET không giữ được hiệu suất ngoài mẫu |
| 5 | T2-1: MI lọc PP1 | Kết quả Cổng A của PP1 | Không dùng MI cho Entry sideways |
| 6 | T2-2: PP10 | Bạn duyệt PP10 vào ma trận | Không có entry Fib + Bollinger |
| 7 | T3: G (DCA), F (tỉa) — **kiểm soát volume** | Baseline basket (Giai đoạn C, D) | Bỏ vai trò tương ứng |
| 8 | Làm sau, không bắt buộc: thoát 127,2 / 161,8; tổ hợp H, I, J | Các thành phần đã qua riêng | — |
| 9 | Báo cáo: logic nào hiệu quả, không hiệu quả, giảm DD, tăng / giảm lợi nhuận, giảm tầng DCA, kiểu tỉa tốt nhất, rủi ro, dấu hiệu quá khớp. **Sau đó dừng** | — | — |

Bước 1–3 chỉ cần **nến M1**, không cần tick. File nến M1 của 2–3 năm nhỏ hơn nhiều so với file tick, nên có thể tải
lên GitHub ngay.

**Lưu ý chia dữ liệu:** dữ liệu 2026 hiện có thuộc tập TEST ở phương án 1 (Mục 14.3 kế hoạch). Nếu dùng nó cho T1 sẽ
làm bẩn tập TEST. Vì vậy T1 cần dữ liệu 2024–2025.

## 9. Phần trong tài liệu ảnh chưa đủ định lượng và cách định lượng

| Cụm từ trong ảnh | Định nghĩa đề xuất | Tham số / ghi chú |
|---|---|---|
| "Xu hướng chính tăng" | Ba định nghĩa, kiểm riêng từng cái: (a) cấu trúc swing HH + HL; (b) EMA(n) dốc lên và giá trên EMA (như SET); (c) TĂNG của bộ phân loại V0.11 | n ∈ {50; 100} |
| "Swing Low / Swing High hợp lệ" | Zigzag ATR (Mục 6), không lấy High/Low tùy ý của N nến | k_sw, k_imp, N_imp |
| "Giá hồi về 50–61,8%" | r = (đỉnh − giá) / (đỉnh − đáy) ∈ [0,5 − d; 0,618 + d] | d ∈ {0; 0,05} |
| "Chạm hoặc xuyên nhẹ Band dưới" | Low ≤ Band dưới + t × ATR và Close ≥ Band dưới − x × ATR | t ∈ {0; 0,15}; x = 0,5 |
| Pin bar tăng | Bấc dưới ≥ p × biên độ nến; thân ≤ 0,3 × biên độ; đóng ở 1/3 trên | p ∈ {0,6; 0,75} |
| Bullish engulfing | Nến trước giảm; nến này tăng; thân nến này bao trọn thân nến trước | — |
| Morning star | 3 nến: giảm thân lớn (≥ 0,6 × ATR); thân nhỏ (≤ 0,3 × nến 1); tăng, đóng trên giữa thân nến 1 | — |
| "Band co hẹp" / "mở rộng" | Phân vị BBW trong cửa sổ trượt: < p20 là co, > p80 là mở; tốc độ mở = BBW / BBW 10 nến trước | Cửa sổ 1 và 5 ngày |
| "Chạy dọc band" | ≥ m trong n nến gần nhất đóng ngoài hoặc tại band cùng phía | m / n ∈ {3/5} |
| "Không vào khi đi ngang" | SIDEWAYS của bộ phân loại, hoặc BBW < p20 và ADX < 20 | Đây là điều ngược với lõi Phoenix, chỉ áp cho PP10 |
| "Tránh tin mạnh" | Cần lịch tin (DL-05). Chưa có thì chỉ dùng khung giờ công bố cố định, ghi rõ là xấp xỉ | — |
| "SL dưới đáy gần nhất… 0,5–1 ATR" | SL = đáy swing − 0,2 × ATR, kẹp trong [0,5; 1,5] × ATR; kiểm c_rt ≤ 10% SL | Kẹp theo quy tắc chi phí của kế hoạch |
| "TP1 / TP2 / TP3, chốt 50 / 30 / 20" | T2 dùng một TP (để đo lợi thế Entry sạch). Chốt từng phần là lớp quản lý, kiểm ở T3 | — |
| "Rủi ro 1–2% mỗi lệnh" | **Không áp dụng.** Phoenix giữ r_b = 1% mỗi basket (đã duyệt) | Mục XVI của yêu cầu |
| "Đặc biệt hiệu quả với XAUUSD", "xác suất cao" | Nhận định, chưa có bằng chứng. Chính là điều T1–T2 kiểm | — |

## 10. Trạng thái và việc cần bạn quyết định

- **Chưa sửa mã nguồn nào** cho Fib + Bollinger.
- Bản nháp V0.20 đã dừng, chưa vào repo.
- Tài liệu này là thay đổi duy nhất.

| # | Việc | Đề xuất của tôi |
|---|---|---|
| 1 | Duyệt kế hoạch MI (Mục 5–8), hoặc sửa | Duyệt để bắt đầu bước 1 (T0: `mi.py`, chỉ Python) |
| 2 | Gửi mã nguồn `VuTru_Fibo_BB_Pullback.mq5`, báo cáo tester của SET M2 (khoảng ngày, chế độ tick, spread, vốn, kết quả), khoảng ngày và tiêu chí đã dùng khi tối ưu | Cần cho T2-3 |
| 3 | Xuất **nến M1 XAUUSDc** 01/01/2024 → nay (MT5: Symbols → Bars → Export), tải lên EA-PRO | Đủ để chạy T1 ngay, không phải chờ file tick lớn |
| 4 | V0.20 (hạ tầng lệnh, RiskGate, LAB lệnh đơn PP1; không có Fib; chỉ tester/demo): tiếp tục song song, hay chờ kế hoạch này được duyệt? | Tiếp tục. Mọi so sánh A–J đều cần baseline và công cụ chạy thử này. V0.20 là phiên bản mới, không sửa bản nào đang có |
| 5 | Khung thời gian của MI: M5 (khung cấu trúc của Phoenix) và M2 (khung của SET) | Đăng ký trước cả hai |
