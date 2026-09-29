# Phoenix Grid — Nghiên cứu

**DAVID HUNTER – PHOENIX GRID – 0941920986**

EA MT5 mới cho XAUUSD (Exness Standard Cent, tài khoản riêng), theo chu trình: Sideways → DCA thông minh → cảnh báo
Breakout → Hedge → giao dịch vùng mới và tỉa lệnh → chu kỳ mới.

> **Trạng thái:**
>
> - Kế hoạch PG-R0.0 **đã được duyệt ngày 29/09/2026** (commit `47480fe`).
> - Đang ở **PG-R0.1**: đọc thông số MT5 và kiểm tra dữ liệu. Lần chạy 1 (29/09/2026) được làm trên tài
>   khoản demo **Pro** (XAUUSD, USD), chưa phải Standard Cent. Cần chạy lại trên tài khoản XAUUSDc.
>
> Chưa có EA giao dịch, chưa chạy backtest nào. Không có con số hiệu suất nào trong thư mục này.

| File | Nội dung |
|---|---|
| [`01_KE_HOACH_NGHIEN_CUU.md`](01_KE_HOACH_NGHIEN_CUU.md) | Kế hoạch đầy đủ (đã duyệt): phân tích ảnh, kiến trúc, công thức, PP1–PP9, lot/rủi ro/stress, DCA, Hedge, Recovery, state machine, ma trận A–G, chia dữ liệu, tiêu chí nghiệm thu, dữ liệu còn thiếu, lộ trình phiên bản |
| [`02_PHU_LUC_THONG_KE_DU_LIEU.md`](02_PHU_LUC_THONG_KE_DU_LIEU.md) | Thống kê mô tả 9 tháng nến M1 XAUUSDm. Không phải backtest |
| [`03_R01_THONG_SO_VA_DU_LIEU.md`](03_R01_THONG_SO_VA_DU_LIEU.md) | PG-R0.1: hướng dẫn chạy script đọc thông số, đo margin hedge trên demo, xuất tick XAUUSDc; kết quả kiểm tra tick hiện có |
| [`../../MQL5/Scripts/PhoenixGrid/`](../../MQL5/Scripts/PhoenixGrid/) | Script MT5 chỉ đọc `PG_R01_DocThongSo.mq5` (chưa compile) |
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

### PG-R0.1 — Đọc thông số MT5 và kiểm tra dữ liệu tick

**Ngày:** 29/09/2026
**Phiên bản gốc:** PG-R0.0 (đã duyệt)
**Mục tiêu:** có bảng thông số XAUUSDc thật, xác minh giả định H_K, và có công cụ kiểm tra dữ liệu tick trước khi
nghiên cứu
**Trạng thái:** TEST. Lần chạy 1 trên demo Pro (XAUUSD, USD): K = 1 USD mỗi 0,01 lot mỗi 1 USD/oz, nhất quán giữa 3 cách tính; H_K chưa kiểm chứng được vì không phải tài khoản Cent. Chờ chạy lại trên XAUUSDc

**Thay đổi:**

- Script MT5 chỉ đọc `MQL5/Scripts/PhoenixGrid/PG_R01_DocThongSo.mq5`.
- `research/phoenix_grid/pg_data.py`: bộ đọc tick (chép từ V4.39) và làm sạch có đếm bất thường.
- `research/phoenix_grid/kiem_tra_tick.py`: báo cáo chất lượng tick.
- `research/phoenix_grid/doc_thong_so.py`: đọc thông số, xác minh H_K.
- Báo cáo `03_R01_THONG_SO_VA_DU_LIEU.md`. Kết quả kiểm tra tick XAUUSDm 01–12/01/2026 nằm trong
  `research/phoenix_grid/results_r01/`.
- Lần chạy 1 của script (demo Pro): file gốc ở `research/phoenix_grid/du_lieu_r01/`, báo cáo ở
  `research/phoenix_grid/results_r01/thong_so_XAUUSD_20260929_2107.md`.

**Kiểm tra kỹ thuật:**

- Compile MQL5: bản 0.10 đã compile và chạy được trên MT5 build 6230 của bạn. Bản 0.11 (đổi `;` thành `,` trong
  ghi chú, vì bản 0.10 làm lệch cột CSV) chưa compile lại.
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
