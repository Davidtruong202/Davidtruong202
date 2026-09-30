# Phoenix Grid — Nghiên cứu

**DAVID HUNTER – PHOENIX GRID – 0941920986**

EA MT5 mới cho XAUUSD (Exness Standard Cent, tài khoản riêng), theo chu trình: Sideways → DCA thông minh → cảnh báo
Breakout → Hedge → giao dịch vùng mới và tỉa lệnh → chu kỳ mới.

> **Trạng thái:**
>
> - Kế hoạch PG-R0.0 **đã được duyệt ngày 29/09/2026** (commit `47480fe`).
> - **PG-R0.1**: thông số XAUUSDc trên tài khoản thật Standard Cent đã được bạn xác nhận ngày 30/09/2026 (**H_K
>   đạt**). Exness-MT5Real20 là tài khoản Phoenix.
> - **Dữ liệu tick**: trên EA-PRO mới có file mẫu 300 tick; 20 file zip chưa được tải lên (báo cáo R0.1, Mục 10).
> - **EA V0.11 TEST (30/09/2026)**: chế độ quan sát, **không gửi lệnh**. Bảng ở góc trái chart, không còn biểu tượng.
>   Chưa có kết quả compile.
>
> Chưa có EA giao dịch, chưa chạy backtest nào. Không có con số hiệu suất nào trong thư mục này.

| File | Nội dung |
|---|---|
| [`01_KE_HOACH_NGHIEN_CUU.md`](01_KE_HOACH_NGHIEN_CUU.md) | Kế hoạch đầy đủ (đã duyệt): phân tích ảnh, kiến trúc, công thức, PP1–PP9, lot/rủi ro/stress, DCA, Hedge, Recovery, state machine, ma trận A–G, chia dữ liệu, tiêu chí nghiệm thu, dữ liệu còn thiếu, lộ trình phiên bản |
| [`02_PHU_LUC_THONG_KE_DU_LIEU.md`](02_PHU_LUC_THONG_KE_DU_LIEU.md) | Thống kê mô tả 9 tháng nến M1 XAUUSDm. Không phải backtest |
| [`03_R01_THONG_SO_VA_DU_LIEU.md`](03_R01_THONG_SO_VA_DU_LIEU.md) | PG-R0.1: hướng dẫn chạy script đọc thông số, đo margin hedge trên demo, xuất tick XAUUSDc; kết quả kiểm tra tick hiện có |
| [`04_EA_V0_10_QUAN_SAT.md`](04_EA_V0_10_QUAN_SAT.md) | EA quan sát V0.10 / V0.11 TEST: lộ trình EA, cách chạy, đặc tả thuật toán cho bộ Python R0.2, chi tiết cần duyệt |
| [`../../MQL5/Scripts/PhoenixGrid/`](../../MQL5/Scripts/PhoenixGrid/) | Script MT5 chỉ đọc `PG_R01_DocThongSo.mq5` (đã compile và chạy trên máy bạn) |
| [`../../MQL5/Experts/PhoenixGrid/`](../../MQL5/Experts/PhoenixGrid/) | `EA_PHOENIX_GRID_V0_11_TEST.mq5` (hiện hành) và `EA_PHOENIX_GRID_V0_10_TEST.mq5` (rollback): EA quan sát, không gửi lệnh |
| [`../../research/phoenix_grid/`](../../research/phoenix_grid/) | Công cụ Python và kết quả CSV |

## Kết quả bàn giao theo Phần 10 của yêu cầu

| # | Kết quả bàn giao | Vị trí trong `01_KE_HOACH_NGHIEN_CUU.md` |
|---|---|---|
| 1 | Danh sách phương pháp đề xuất nghiên cứu | Mục 7 (PP1–PP9, 185 biến thể đăng ký trước) |
| 2 | Ma trận các thử nghiệm cần chạy | Mục 13 (Giai đoạn A–G) |
| 3 | Công thức tính lot và rủi ro | Mục 5 và Mục 8 (gồm ma trận stress S1–S12, ví dụ số học) |
| 4 | Sơ đồ vận hành các trạng thái | Mục 12 |
| 5 | Kế hoạch chia dữ liệu | Mục 14 |
| 6 | Tiêu chí nghiệm thu đề xuất | Mục 16 (NT-A0, cổng A, NT-01…NT-30), đóng băng tại commit `47480fe` |
| 7 | Danh sách dữ liệu và thông số MT5 còn thiếu | Mục 17 (DL-01…DL-09, TS-01…TS-12) |
| 8 | Kế hoạch triển khai theo từng phiên bản nghiên cứu | Mục 18 (PG-R0.0 → PG-R1.0 → EA V1.00 TEST) |

## Nhật ký phiên bản

### EA V0.11 TEST — Bảng bên trái, bỏ biểu tượng; bộ đọc tick nhiều dạng

**Ngày:** 30/09/2026
**Phiên bản gốc:** EA V0.10 TEST (commit `61bab04`)
**Mục tiêu:**

- Đổi giao diện theo yêu cầu 30/09/2026: bảng ở góc trái chart, bỏ biểu tượng phượng hoàng.
- Kiểm tra dữ liệu tick trên EA-PRO.

**Trạng thái:** TEST, không gửi lệnh.

**Thay đổi:**

- `EA_PHOENIX_GRID_V0_11_TEST.mq5` (file mới; V0.10 giữ nguyên để rollback):
  - Bảng neo góc trái trên.
  - Bỏ mảng biểu tượng và các hàm vẽ biểu tượng.
  - Bỏ input "Dịch chart" và phần dựng lại bảng khi đổi độ rộng chart.
  - Log ghi `PG_V011_…`, cột giữ nguyên.
  - Thuật toán nhận diện không đổi.
- Xóa `cong_cu_ea/bieu_tuong_phuong_hoang.py` (còn trong lịch sử git, commit `61bab04`).
- `pg_data.py`: đọc thêm được nhiều zip độc lập và CSV, có hoặc không có tiêu đề, kể cả khi bị cắt giữa dòng. Thêm
  `--tu-kiem-tra` (8 phép thử).
- Báo cáo R0.1, Mục 10: kết quả kiểm tra thư mục `data` trên EA-PRO.

**Kiểm tra kỹ thuật:**

- Compile MQL5: chưa làm được (không có MetaEditor).
- Kiểm tra tĩnh V0.11: đạt (63 hàm; 44 input; không có từ khóa giao dịch).
- `pg_data.py --tu-kiem-tra`: 8/8 đạt. File XAUUSDm cũ đọc ra đúng 2.733.021 tick như trước.

**Backtest:** không áp dụng.
**Rollback:** V0.10 (commit `61bab04`).

### EA V0.10 TEST — Chế độ quan sát

**Ngày:** 30/09/2026
**Phiên bản gốc:** không có (EA đầu tiên của Phoenix Grid). Trước bản này repo ở commit `40a11a4`
**Mục tiêu:**

- Có EA chạy được trên chart để quan sát trạng thái thị trường theo Mục 6.
- Có bảng điều khiển Phoenix Grid và ước tính rủi ro bằng thông số thật.
- Ghi log để đối chiếu với bộ phân loại Python ở R0.2.

**Trạng thái:** TEST, **chưa compile**, **không gửi lệnh**.

**Thay đổi:**

- `MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_10_TEST.mq5`:
  - Nhận diện SIDEWAYS / TĂNG / GIẢM, có chống nhấp nháy.
  - Cảnh báo, xác nhận, breakout giả và vùng mới theo tick.
  - Bộ lọc vào lệnh (chỉ hiển thị).
  - Bảng điều khiển có biểu tượng phượng hoàng nhúng trong mã.
  - Ước tính D phòng thủ tối đa theo Mục 8.2.
  - Log CSV.
- `research/phoenix_grid/cong_cu_ea/bieu_tuong_phuong_hoang.py`: vẽ biểu tượng và nhúng mảng ARGB vào file `.mq5`.
- `04_EA_V0_10_QUAN_SAT.md`: lộ trình EA, hướng dẫn chạy, đặc tả thuật toán, 12 chi tiết cài đặt cần bạn duyệt
  (Mục 8 của tài liệu).
- Kế hoạch: ghi nhận quyết định 30/09/2026 (Mục 21), lộ trình EA song song (Mục 18), thông số đã xác nhận
  (Mục 17.2). Mục 16 (tiêu chí nghiệm thu) không đổi so với `47480fe`.

**Kiểm tra kỹ thuật:**

- Compile MQL5: **chưa làm**, vì môi trường này không có MetaEditor. Cần bạn compile và gửi lỗi/cảnh báo.
- Kiểm tra tĩnh: đạt. Ngoặc cân bằng; mọi lời gọi hàm có định nghĩa; không có từ khóa giao dịch; mảng biểu tượng đủ
  4.096 phần tử; 45 input có nhãn tiếng Việt.
- Công thức D phòng thủ: khớp Bảng C của kế hoạch (49,7 / 27,7 / 22,4 USD).

**Backtest:** không áp dụng (EA không giao dịch).
**Rollback:** commit `40a11a4`.

### PG-R0.1 — Đọc thông số MT5 và kiểm tra dữ liệu tick

**Ngày:** 29/09/2026
**Phiên bản gốc:** PG-R0.0 (đã duyệt)
**Mục tiêu:** có bảng thông số XAUUSDc thật, xác minh giả định H_K, và có công cụ kiểm tra dữ liệu tick trước khi
nghiên cứu
**Trạng thái:** TEST.

- Lần chạy 1 (29/09/2026, demo Pro, XAUUSD, USD): K = 1 USD mỗi 0,01 lot mỗi 1 USD/oz, nhất quán giữa 3 cách
  tính. H_K chưa kiểm chứng được vì không phải tài khoản Cent.
- Lần chạy 2 (30/09/2026, tài khoản thật Standard Cent, XAUUSDc): **H_K đạt**; spread theo tick 0,26 USD/oz (trùng
  giả định); đòn bẩy 1:2000; stop out 0%. Tài khoản đang có 3 vị thế mở.
- Chờ: bạn xác nhận thông số, làm rõ tài khoản riêng, xuất tick XAUUSDc.

**Thay đổi:**

- Script MT5 chỉ đọc `MQL5/Scripts/PhoenixGrid/PG_R01_DocThongSo.mq5`.
- `research/phoenix_grid/pg_data.py`: bộ đọc tick (chép từ V4.39) và làm sạch có đếm bất thường.
- `research/phoenix_grid/kiem_tra_tick.py`: báo cáo chất lượng tick.
- `research/phoenix_grid/doc_thong_so.py`: đọc thông số, xác minh H_K.
- Báo cáo `03_R01_THONG_SO_VA_DU_LIEU.md`. Kết quả kiểm tra tick XAUUSDm 01–12/01/2026 nằm trong
  `research/phoenix_grid/results_r01/`.
- Hai lần chạy script: file gốc ở `research/phoenix_grid/du_lieu_r01/` (kèm SHA-256), báo cáo ở
  `research/phoenix_grid/results_r01/thong_so_XAUUSD_20260929_2107.md` (demo Pro) và
  `research/phoenix_grid/results_r01/thong_so_XAUUSDc_20260930_0827.md` (tài khoản thật Standard Cent).

**Kiểm tra kỹ thuật:**

- Compile MQL5: bản 0.10 và bản 0.11 (đổi `;` thành `,` trong ghi chú, vì bản 0.10 làm lệch cột CSV) đều đã
  compile và chạy được trên MT5 build 6230 của bạn.
- Kiểm tra tĩnh script: đạt (ngoặc cân bằng, mọi hàm có định nghĩa, không có lời gọi lệnh giao dịch).
- Python:
  - Kiểm tra tick chạy trên dữ liệu thật: nến M1 dựng từ tick khớp MT5 ở mọi phút đầy đủ.
  - `doc_thong_so.py --tu-kiem-tra` đạt.

**Backtest:** không áp dụng.
**Rollback:** PG-R0.0 (commit `47480fe`).

### PG-R0.0 — Kế hoạch nghiên cứu

**Ngày:** 29/09/2026
**Phiên bản gốc:** không có (dự án mới, không dùng mã nguồn EA cũ)
**Mục tiêu:** trình bày kế hoạch nghiên cứu và kiến trúc để phê duyệt trước khi lập trình
**Trạng thái:** **ĐÃ DUYỆT 29/09/2026**. Tài khoản riêng. Chi tiết ở Mục 21 của kế hoạch

**Thay đổi:**

- Tạo kế hoạch nghiên cứu `01_KE_HOACH_NGHIEN_CUU.md`.
- Tạo phụ lục thống kê mô tả, script `research/phoenix_grid/thong_ke_mo_ta.py` và kết quả CSV.

**Kiểm tra kỹ thuật:**

- Mã MQL5: không có, nên không áp dụng compile.
- Script Python: đã chạy trên `EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv`
  (numpy 2.4, pandas 3.0).

**Backtest:** chưa chạy.
**Kết luận:** đã duyệt; tiêu chí nghiệm thu đóng băng tại commit `47480fe`.
**Rollback:** không áp dụng.
