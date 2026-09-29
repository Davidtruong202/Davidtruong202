# Phoenix Grid — Nghiên cứu

**DAVID HUNTER – PHOENIX GRID – 0941920986**

EA MT5 mới cho XAUUSD (Exness Standard Cent), theo chu trình: Sideways → DCA thông minh → cảnh báo Breakout →
Hedge → giao dịch vùng mới và tỉa lệnh → chu kỳ mới.

> **Trạng thái: PG-R0.0, kế hoạch nghiên cứu, CHỜ PHÊ DUYỆT.**
> Chưa có EA giao dịch, chưa có bộ kiểm định, chưa chạy backtest nào. Không có con số hiệu suất nào trong thư mục
> này.

| File | Nội dung |
|---|---|
| [`01_KE_HOACH_NGHIEN_CUU.md`](01_KE_HOACH_NGHIEN_CUU.md) | Kế hoạch đầy đủ: phân tích ảnh, kiến trúc, công thức, PP1–PP9, lot/rủi ro/stress, DCA, Hedge, Recovery, state machine, ma trận A–G, chia dữ liệu, tiêu chí nghiệm thu, dữ liệu còn thiếu, lộ trình phiên bản |
| [`02_PHU_LUC_THONG_KE_DU_LIEU.md`](02_PHU_LUC_THONG_KE_DU_LIEU.md) | Thống kê mô tả 9 tháng nến M1 XAUUSDm (biên độ, spread, ATR, biến động ngược chiều, variance ratio, gap). Không phải backtest |
| [`../../research/phoenix_grid/`](../../research/phoenix_grid/) | Script tái lập số liệu phụ lục và các file CSV kết quả |

## Kết quả bàn giao theo Phần 10 của yêu cầu

| # | Kết quả bàn giao | Vị trí trong `01_KE_HOACH_NGHIEN_CUU.md` |
|---|---|---|
| 1 | Danh sách phương pháp đề xuất nghiên cứu | Mục 7 (PP1–PP9, 185 biến thể đăng ký trước) |
| 2 | Ma trận các thử nghiệm cần chạy | Mục 13 (Giai đoạn A–G) |
| 3 | Công thức tính lot và rủi ro | Mục 5 và Mục 8 (gồm ma trận stress S1–S12, ví dụ số học) |
| 4 | Sơ đồ vận hành các trạng thái | Mục 12 |
| 5 | Kế hoạch chia dữ liệu | Mục 14 |
| 6 | Tiêu chí nghiệm thu đề xuất | Mục 16 (NT-A0, cổng A, NT-01…NT-30) |
| 7 | Danh sách dữ liệu và thông số MT5 còn thiếu | Mục 17 (DL-01…DL-09, TS-01…TS-12) |
| 8 | Kế hoạch triển khai theo từng phiên bản nghiên cứu | Mục 18 (PG-R0.0 → PG-R1.0 → EA V1.00 TEST) |

Những điểm cần bạn phê duyệt: Mục 21.

## Nhật ký phiên bản

### PG-R0.0 — Kế hoạch nghiên cứu

**Ngày:** 29/09/2026
**Phiên bản gốc:** không có (dự án mới, không dùng mã nguồn EA cũ)
**Mục tiêu:** trình bày kế hoạch nghiên cứu và kiến trúc để phê duyệt trước khi lập trình
**Trạng thái:** CHỜ PHÊ DUYỆT

**Thay đổi:**

- Tạo kế hoạch nghiên cứu `01_KE_HOACH_NGHIEN_CUU.md`.
- Tạo phụ lục thống kê mô tả, script `research/phoenix_grid/thong_ke_mo_ta.py` và kết quả CSV.

**Kiểm tra kỹ thuật:**

- Mã MQL5: không có, nên không áp dụng compile.
- Script Python: đã chạy trên `EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv`
  (numpy 2.4, pandas 3.0).

**Backtest:** chưa chạy.
**Kết luận:** chờ phê duyệt.
**Rollback:** không áp dụng.
