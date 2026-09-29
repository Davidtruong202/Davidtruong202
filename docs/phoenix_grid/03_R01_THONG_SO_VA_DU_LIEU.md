# PG-R0.1 — Đọc thông số MT5 và kiểm tra chất lượng dữ liệu tick

**DAVID HUNTER – PHOENIX GRID – 0941920986**

| Mục | Giá trị |
|---|---|
| Phiên bản | **PG-R0.1** (bước đầu tiên của lộ trình, Mục 18 kế hoạch) |
| Ngày | 29/09/2026 |
| Trạng thái | **TEST — lần chạy 1 xong (29/09/2026) nhưng trên tài khoản demo Pro (XAUUSD, USD), chưa phải Standard Cent.** Kết quả ở Mục 7. Script 0.10 đã compile và chạy được trên MT5 build 6230 của bạn; bản 0.11 sửa lỗi ghi chú, chưa compile lại |
| Phạm vi | Chỉ đọc thông số và kiểm tra dữ liệu. Không có EA giao dịch, không có mô phỏng lệnh, không có backtest |
| Cổng duyệt | Bạn xác nhận bảng thông số XAUUSDc (kết quả của Phần A) |

Kế hoạch gốc: [`01_KE_HOACH_NGHIEN_CUU.md`](01_KE_HOACH_NGHIEN_CUU.md), đã duyệt ngày 29/09/2026.

## 1. Việc bạn cần làm

Làm trên **tài khoản riêng của Phoenix Grid** (Exness Standard Cent, symbol XAUUSDc).

| Bước | Việc | Ghi chú |
|---|---|---|
| A | Chạy script `PG_R01_DocThongSo.mq5` trên chart XAUUSDc, gửi lại 2 file CSV | Script chỉ đọc, chạy được cả trên tài khoản thật. Mục 2 |
| B | Đo margin thực tế của một cặp BUY + SELL 0,01 | **Chỉ làm trên tài khoản DEMO**, ưu tiên cùng loại với tài khoản sẽ chạy thật. Mục 3 |
| C | Xuất tick XAUUSDc càng dài càng tốt (tối thiểu 18 tháng) | Mục 4 |

## 2. Bước A — Script chỉ đọc `PG_R01_DocThongSo.mq5`

File: `MQL5/Scripts/PhoenixGrid/PG_R01_DocThongSo.mq5` (repo `Davidtruong202`, nhánh `claude/relaxed-johnson-r2gkat`).

**Script làm gì:**

- Đọc thông số tài khoản: tiền tệ, đòn bẩy, chế độ margin (hedging hay netting), mức margin call / stop out.
- Đọc toàn bộ thông số XAUUSDc:
  - hợp đồng, tick size/value, lot min/bước/max;
  - chế độ khớp, Close By, SL/TP;
  - stops level, swap;
  - margin và hedged margin;
  - phiên giao dịch từng ngày.
- Tính K theo hai cách độc lập (tick value và `OrderCalcProfit`) để xác minh giả định H_K.
- Tính margin từng chân 0,01 lot (`OrderCalcMargin`) và swap mỗi đêm quy ra tiền.
- Ước tính commission/phí từ lịch sử deal 365 ngày (nếu có).
- Thống kê spread theo **từng tick** trong N ngày gần nhất (mặc định 30), theo giờ server.

**Script không làm gì:**

- Không có `OrderSend`, không mở/đóng/sửa lệnh.
- Không ghi số tài khoản, tên chủ tài khoản, Balance hay Equity.

**Cài đặt và chạy:**

1. Chép file vào `<thư mục dữ liệu MT5>\MQL5\Scripts\PhoenixGrid\`. Mở thư mục này bằng File → Open Data Folder.
2. Mở file trong MetaEditor và bấm **Compile (F7)**. Nếu có lỗi hoặc cảnh báo, gửi tôi nguyên văn thông báo.
3. Trên MT5, mở chart **XAUUSDc** (khung nào cũng được), khi thị trường đang mở.
4. Kéo script từ Navigator → Scripts → PhoenixGrid vào chart, giữ các giá trị mặc định rồi bấm OK.
5. Đợi tab Experts in dòng `PG-R0.1: đã ghi ...`. Lần đầu có thể mất vài phút, vì MT5 phải tải lịch sử tick.
6. Lấy 2 file trong `<Common>\Files\PhoenixGrid\`. Đường dẫn Common được in ở dòng cuối tab Experts.
   - `PG_R01_thong_so_XAUUSDc_<ngày_giờ>.csv`
   - `PG_R01_spread_theo_gio_XAUUSDc_<ngày_giờ>.csv`
7. Gửi 2 file cho tôi, hoặc tải lên `EA-PRO/data/thong_so/XAUUSDc_<ngày>/`.

| Input | Mặc định | Ý nghĩa |
|---|---|---|
| Symbol cần đọc | (trống) | Để trống = symbol của chart |
| Số ngày tick để thống kê spread | 30 | 0 = bỏ qua phần spread |
| Thư mục con trong Common\Files | PhoenixGrid | Nơi ghi 2 file CSV |
| Đọc lịch sử deal 365 ngày | true | Chỉ để ước tính commission/phí; tài khoản mới sẽ ghi `chua_co_deal` |

**Sau khi nhận file**, tôi chạy `research/phoenix_grid/doc_thong_so.py` để:

- lập bảng thông số;
- kết luận H_K ĐẠT / KHÔNG ĐẠT;
- tính lại các con số nền của kế hoạch (Bảng A, margin, swap) với thông số thật;
- kiểm tra 8 điều kiện kế hoạch cần: tài khoản hedging, tiền USC, Close By, SL/TP phía server, bước lot 0,01,
  tài khoản riêng đang trống, cho phép EA giao dịch, H_K.

## 3. Bước B — Đo margin thực tế của cặp hedge (chỉ trên DEMO)

Script không gửi lệnh, nên phần này phải làm tay. Mục đích là biết sàn tính margin cho cặp BUY/SELL đối ứng như thế
nào (TS-04). Kế hoạch vẫn dùng cách tính thận trọng (không trừ ưu đãi hedge); số đo này chỉ để đối chiếu.

1. Mở tài khoản **DEMO** Standard Cent. Không làm trên tài khoản thật.
2. Ghi lại ô **Margin** (tab Trade) khi chưa có lệnh nào: M0.
3. Mở BUY 0,01 XAUUSDc. Ghi Margin: M1.
4. Mở SELL 0,01 XAUUSDc. Ghi Margin: M2.
5. Đóng cả hai lệnh.
6. Gửi tôi M0, M1, M2 và giờ làm (giờ server).

## 4. Bước C — Xuất tick XAUUSDc (DL-01)

1. MT5: View → Symbols (Ctrl+U) → tab **Ticks** → chọn XAUUSDc.
2. Chọn khoảng thời gian dài nhất có thể: khuyến nghị 01/01/2024 → nay, tối thiểu 18 tháng. Bấm **Request**.
3. Bấm **Export Ticks**, giữ nguyên tên file MT5 đặt.
4. Nén zip. Nếu lớn hơn 25 MB, chia thành các phần 24 MB (`.zip.part001`, `.zip.part002`…) như bộ XAUUSDm hiện có.
5. Tải vào `EA-PRO/data/tick/XAUUSDc_<từ ngày>_<đến ngày>/`.

Nếu MT5 không cho tải đủ lịch sử XAUUSDc, xuất thêm tick XAUUSDm cùng khoảng (phương án DL-02 của kế hoạch).

## 5. Kết quả kiểm tra dữ liệu tick hiện có ✅

Tôi chạy `kiem_tra_tick.py` trên bộ tick XAUUSDm duy nhất đang có (`EA-PRO/data/tick/XAUUSDm_2026-01-01_2026-04-30/`,
chỉ có phần 1/15). Mục đích là kiểm tra bộ đọc tick trước khi dùng cho XAUUSDc. Kết quả chi tiết:
`research/phoenix_grid/results_r01/XAUUSDm_2026-01-01_2026-01-12/`.

| Hạng mục | Kết quả |
|---|---|
| Dữ liệu đọc được | 01/01/2026 23:05 → 12/01/2026 13:03, 10 ngày, 2.733.021 tick (6,9% của file gốc; phần còn lại nằm ở các phần chưa tải lên) |
| Số tick mỗi ngày | Trung vị 376.424 (khoảng 4,4 tick/giây) |
| Giá trống | 63 dòng thiếu Ask. MT5 chỉ ghi phía thay đổi, nên điền tiếp giá trước. Đây không phải lỗi |
| Giá không hợp lệ, Ask < Bid, thời gian lùi, tick trùng | 0 / 0 / 0 / 0 |
| Khoảng trống > 60 giây | 4 lần nghỉ hằng ngày (tick cuối 21:57:58, mở lại 23:01–23:04 giờ server, mùa đông) và 2 lần nghỉ cuối tuần/ngày lễ. **0 khoảng trống bất thường trong phiên** |
| Spread theo tick | 160 point (0,16 USD/oz) ở trung vị, p90, p99 và p99,9. Lớn nhất 480 point, lúc mở lại sau giờ nghỉ (23h) |
| Bước nhảy giá lớn nhất | 2,59 USD giữa hai tick cách nhau 23 ms, lúc 13:30:01 ngày 09/01/2026 (giờ công bố số liệu Mỹ). Có 6 bước nhảy ≥ 2 USD, không có bước nào ≥ 5 USD |
| Đối chiếu nến M1 tự dựng từ tick với nến M1 của MT5 | Trùng 9.090/9.090 phút. Open, Low khớp 100%. High, Close lệch đúng 1 nến: phút cuối 13:03, vì file tick bị cắt giữa phút đó. Các phút đầy đủ khớp 100% |

**Phát hiện mới.** Cột spread trong nến M1 mà MT5 xuất ra **nhiều khả năng là spread nhỏ nhất trong phút**.

- Trong 10 ngày này chỉ có 6 phút spread thay đổi trong phút.
- Ở cả 6 phút, cột spread của MT5 bằng spread nhỏ nhất tính từ tick. So với spread lớn nhất: khớp 0/6. So với spread
  đầu nến và cuối nến: khớp 4/6.
- Mẫu này nhỏ, nên cần kiểm lại trên dữ liệu có spread biến động nhiều hơn.

Nếu đúng như vậy thì:

- Các thống kê spread ở Phụ lục (A.2) được tính từ cột này, nên là **cận dưới** của spread thật.
- Ngưỡng spread và chi phí của kế hoạch phải lấy từ spread theo tick. Đó là lý do script R0.1 đọc spread theo tick.

**Nhận xét.** Trong 10 ngày này, spread XAUUSDm gần như cố định ở 0,16 USD/oz, chỉ giãn lúc mở lại sau giờ nghỉ và lúc có tin.
Theo nến M1, các tháng sau tăng lên 0,24–0,28 (Phụ lục A.2). Cần đo spread XAUUSDc theo tick (Bước A) trước khi đặt
s_abs.

## 6. Công cụ R0.1

| File | Việc làm |
|---|---|
| `MQL5/Scripts/PhoenixGrid/PG_R01_DocThongSo.mq5` | Script MT5 chỉ đọc (Mục 2). Bản 0.10 đã compile và chạy trên MT5 build 6230 của bạn. Bản 0.11 (sửa ghi chú có `;`) chưa compile lại |
| `research/phoenix_grid/pg_data.py` | Đọc file tick zip của MT5 (chép bộ đọc đã đối chiếu của V4.39), làm sạch có đếm bất thường, dựng nến M1 theo Bid |
| `research/phoenix_grid/kiem_tra_tick.py` | Báo cáo chất lượng tick (Mục 5); `--ticks2` so spread hai bộ tick, ví dụ XAUUSDc với XAUUSDm |
| `research/phoenix_grid/doc_thong_so.py` | Đọc CSV của script MT5, xác minh H_K, kiểm tra điều kiện kế hoạch. `--tu-kiem-tra` đạt (dữ liệu giả lập trong bộ nhớ, không ghi file) |

**Kiểm tra kỹ thuật đã làm:**

- Script MQL5:
  - Kiểm tra tĩnh: ngoặc cân bằng; mọi hàm được gọi đều có định nghĩa; không có lời gọi lệnh giao dịch.
  - Lưu UTF-8 có BOM, giống các EA hiện có trong EA-PRO.
  - Bản 0.10: đã compile và chạy được trên MT5 build 6230 của bạn (lần chạy 1). Tôi không thấy được cảnh báo compile,
    nếu có.
  - Bản 0.11: chỉ sửa nội dung ghi chú, chưa compile lại.
- Python: đã chạy `kiem_tra_tick.py` trên dữ liệu thật và `doc_thong_so.py --tu-kiem-tra`.

## 7. Kết quả lần chạy 1 — Exness-MT5Trial17, demo Pro, XAUUSD (29/09/2026, 14:07 giờ server)

- File gốc (2 CSV bạn gửi): `research/phoenix_grid/du_lieu_r01/Exness-MT5Trial17_XAUUSD_20260929_2107/`.
- Báo cáo đầy đủ do `doc_thong_so.py` sinh ra: `research/phoenix_grid/results_r01/thong_so_XAUUSD_20260929_2107.md`.

**Kết luận chính:** đây là tài khoản **demo Pro**, không phải Standard Cent (XAUUSDc, USC).

- Symbol là `XAUUSD`, đường dẫn `Pro\Forex\XAUUSD`, tiền tài khoản USD.
- Vì vậy **H_K chưa kiểm chứng được**, dù cấu trúc hợp đồng khớp với giả định.

| Hạng mục | Giá trị đo được | Ý nghĩa cho kế hoạch |
|---|---|---|
| K (0,01 lot, 1 USD/oz) | 1,000000 USD, giống nhau ở cả 3 cách tính (tick value, OrderCalcProfit BUY và SELL) | Cách tính nhất quán. Trên tài khoản USD, 0,01 lot = 1 USD mỗi 1 USD/oz, tức cùng con số nhưng lớn gấp 100 lần so với tài khoản Cent |
| Hợp đồng | 100 oz; digits 3; point 0,001; lot 0,01–200; bước 0,01; không giới hạn tổng lot | Như giả định |
| Đòn bẩy | 2.000.000.000 (không giới hạn). `OrderCalcMargin` = 0 | Điều kiện margin của RiskGate (Mục 8.2 d) luôn đạt, nên không còn tác dụng bảo vệ. Xem đề xuất Đ1 |
| Stop out / margin call | 0% / 30% | Sàn gần như không cắt lỗ trước khi Equity về 0. Giới hạn của EA là lớp bảo vệ duy nhất, đúng như kế hoạch đã đặt |
| Hedged margin | MARGIN_HEDGED = 0, USE_LEG = false | Phần BUY/SELL đã cặp hóa không tính margin. Cần xác nhận bằng Bước B |
| Khớp lệnh | Market execution; chỉ FOK; Close By ✅; SL/TP ✅; stops/freeze level = 0 | Module khớp lệnh phải dùng FOK. Close By dùng được để đóng cặp (Mục 10, 11 kế hoạch) |
| Swap | BUY −560 point/lot/đêm (−56 USD/lot, −0,56 USD/0,01 lot); SELL 0; thứ Tư ×3 | Trùng số liệu XAUUSDm đã dùng trong kế hoạch (S10) |
| Commission | 0 (tính từ 1.632 deal trong 365 ngày) | Chi phí chỉ gồm spread + trượt giá + swap |
| Spread theo tick (27 ngày, 6,55 triệu tick) | 0,182 USD/oz ở trung vị, p90 và p99; p99,9 = 0,238; lớn nhất 1,40 lúc 12h server (giờ công bố số liệu Mỹ) | Spread gần như cố định và thấp hơn cận dưới 0,26 của XAUUSDm tháng 9. Spread XAUUSDc vẫn phải đo riêng |
| Phiên giao dịch (giờ server = GMT) | CN 22:01–24:00; T2–T5 00:00–20:58 và 22:00–24:00; T6 00:00–20:58 | Khớp giờ nghỉ đã thấy trong dữ liệu (nến cuối 20:57). Giờ nghỉ lệch 1 giờ khi Mỹ đổi giờ, nên EA phải đọc phiên trực tiếp, không cố định |
| Ping | 46 ms | Đủ cho hedge. Cần tính đến khi đánh giá PP4 (tick momentum) |

**Tài khoản này chưa đạt 3 điều kiện kế hoạch cần:**

1. Tiền tài khoản không phải USC (không phải Standard Cent).
2. Chưa trống: 6 lệnh chờ, và đã có 1.632 deal XAUUSD trong 365 ngày. Như vậy đây không phải tài khoản mới dành
   riêng cho Phoenix Grid.
3. ACCOUNT_TRADE_EXPERT = false: EA đang không được phép giao dịch, có thể do nút Algo Trading đang tắt.

**Cảnh báo về vốn:**

- Nếu chạy Phoenix Grid trên tài khoản USD với 50 USD, một lệnh 0,01 lot mất 100 USD = 200% vốn khi vàng đi ngược
  100 USD. Theo Mục 8.5 kế hoạch: không giao dịch với cấu hình vốn này.
- Trên demo USD, muốn giữ đúng tỷ lệ rủi ro của kế hoạch (5.000 USC) thì đặt số dư demo là 5.000 USD.

**Lỗi script được phát hiện nhờ lần chạy này:**

- 3 dòng ghi chú chứa dấu `;`, trùng ký tự phân cách, làm lệch cột CSV.
- `doc_thong_so.py` đã được sửa để đọc được file hiện có.
- Script bản 0.11 đổi `;` thành `,` trước khi ghi.

### Đề xuất điều chỉnh (cần bạn duyệt; chưa đưa vào kế hoạch)

| Mã | Đề xuất | Lý do |
|---|---|---|
| Đ1 | Khi đòn bẩy tài khoản lớn hơn một mức L_cap (đề xuất 1:200), tính dự trữ margin phòng thủ (Mục 8.2 d) theo L_cap. Ví dụ 0,01 lot ở giá 4.166: 0,01 × 100 × 4.166 / 200 ≈ 20,8 đơn vị tiền tài khoản | Với đòn bẩy không giới hạn, điều kiện hiện tại luôn đạt. Sàn có thể hạ đòn bẩy quanh tin tức/cuối tuần (cần xác minh quy định Exness) |
| Đ2 (kỹ thuật) | Module khớp lệnh tự nhận diện chế độ khớp (FOK/IOC) từ SYMBOL_FILLING_MODE | Symbol này chỉ nhận FOK; gửi sai chế độ sẽ bị từ chối |

## 8. Bước tiếp theo

1. **Bạn cho biết tài khoản thật chạy Phoenix Grid là loại nào:**
   - Standard Cent (XAUUSDc, USC) như kế hoạch: chạy script 0.11 trên chính tài khoản đó rồi gửi lại 2 file CSV.
     Script chỉ đọc nên an toàn trên tài khoản thật.
   - Hoặc đổi sang loại khác (ví dụ Pro, tiền USD): khi đó cần xem lại vốn và chi phí trong kế hoạch.
2. **Cho forward test sau này:** dùng một tài khoản demo mới, trống, số dư theo đúng tỷ lệ của kế hoạch, và bật
   Algo Trading.
3. Bước B (đo margin cặp hedge trên demo) và Bước C (xuất tick XAUUSDc) giữ nguyên.
4. Khi có file của XAUUSDc: lập bảng thông số, kết luận H_K → bạn xác nhận → sang **PG-R0.2** (bộ phân loại trạng
   thái thị trường và đánh giá A0).
