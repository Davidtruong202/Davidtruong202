# EA BTC_MOM_M15_H1 – Hướng dẫn kiểm tra và chạy demo

File EA: `MQL5/Experts/BTC_MOM_M15_H1.mq5`
Cấu hình: `MQL5/Presets/BTC_MOM_M15_H1_research_compare.set` (đối chiếu) · `MQL5/Presets/BTC_MOM_M15_H1_demo.set` (demo)

> ⚠️ **Chưa chạy tài khoản thật.** Lợi thế đo được là mỏng (PF khoảng 1,2–1,3, chưa đạt mục tiêu 1,5).
> Xem `01_bao_cao_nghien_cuu_btcusd.md`.

## 1. EA làm gì (đúng cấu hình đã kiểm chứng)

| | |
|---|---|
| H1 | Xu hướng: nến H1 **đã đóng** có EMA50 > EMA200 và ADX14 ≥ 20 → chỉ BUY; ngược lại → chỉ SELL |
| M15 | Tín hiệu khi nến M15 **đóng cửa**: range ≥ 2 × ATR14, thân ≥ 60% range, đóng vượt đỉnh (đáy) 20 nến trước, EMA50/EMA200 M15 cùng chiều |
| Vào lệnh | Lệnh thị trường ngay đầu nến M15 kế tiếp |
| Thoát lệnh | SL = 2 × ATR14 (M15) tính từ giá khớp, TP = 2R, tự đóng sau 720 phút |
| Không có | Lệnh tầng 2, DCA, martingale, dời BE, trailing |
| Bảo vệ (bản demo) | Rủi ro 0,5%/lệnh · bỏ lệnh nếu spread > 20$ hoặc > 5% khoảng SL · dừng trong ngày khi lỗ 2% · nghỉ 24h sau 8 lệnh thua liên tiếp · **dừng hẳn khi DD từ đỉnh ≥ 15%** · bỏ lệnh nếu lot tối thiểu vượt 1,5 lần mức rủi ro cho phép |
| Log | `MQL5/Files/MOM15H1_<symbol>_<magic>.csv`: mỗi lệnh ghi ATR, EMA, ADX H1, spread, SL/TP, lot, lợi nhuận, R |

EA tự tính ATR/EMA/ADX bằng đúng công thức của bản nghiên cứu, không dùng iATR/iADX (vì chúng làm mượt khác).
Đã kiểm tra bằng `research/btc/verify_ea_logic.py`: quyết định BUY/SELL của EA trùng với bản nghiên cứu
**528/528 tín hiệu** (06/2023 → 09/2026).

Giới hạn: môi trường nghiên cứu không có MetaTrader nên **EA chưa được biên dịch**. Nếu MetaEditor báo lỗi,
hãy chụp màn hình tab Errors gửi lại, tôi sẽ sửa.

## 2. Bước 1 – Biên dịch

1. Copy `BTC_MOM_M15_H1.mq5` vào `File → Open Data Folder → MQL5/Experts/`.
2. Copy 2 file `.set` vào `MQL5/Presets/`.
3. Mở file bằng MetaEditor và nhấn **F7**. Kết quả phải là `0 errors`.

## 3. Bước 2 – Strategy Tester (đối chiếu với nghiên cứu)

| Mục | Cài đặt |
|---|---|
| Expert | BTC_MOM_M15_H1 |
| Symbol / Timeframe | **BTCUSDc**, **M15** |
| Mô hình | **Every tick based on real ticks** |
| Khoảng ngày | Lần 1: **2025.12.28 → 2026.09.28** (tập kiểm tra cuối) · Lần 2: 2023.03.01 → 2026.09.28 |
| Nạp tiền | **1.000.000 USC** (số dư lớn để lot không bị làm tròn lên lot tối thiểu, giữ đúng số lệnh) |
| Inputs | Nút **Load** → `BTC_MOM_M15_H1_research_compare.set` |

**Kết quả mong đợi** (bản nghiên cứu, dùng spread thực tế từng thời điểm, như Tester dùng tick thật):

| Giai đoạn | Số lệnh | Win % | Profit Factor |
|---|---|---|---|
| 28/12/2025 → 28/09/2026 | ~128 | ~39% | ~1,25 |
| Toàn bộ | ~527 | ~37% | ~1,16 |

Chênh lệch nhỏ (±5% số lệnh, PF ±0,1) là bình thường, do Tester khớp lệnh theo tick còn nghiên cứu theo nến M1.
Chênh lệch lớn hơn thì cần tìm nguyên nhân trước khi chạy demo.

**Gửi lại cho tôi:** file báo cáo Tester (chuột phải vào tab Backtest → Report → HTML) và file
`MOM15H1_BTCUSDc_20260928.csv`, nằm trong thư mục agent của Tester:
`...\Tester\Agent-127.0.0.1-3000\MQL5\Files\`.

## 4. Bước 3 – Demo (khoảng 3 tháng)

1. Mở tài khoản **demo** Exness cùng loại (Cent, Hedge) và gắn EA vào chart **BTCUSDc M15**.
2. Inputs → Load `BTC_MOM_M15_H1_demo.set`. Bật **Algo Trading**.
3. Máy (hoặc VPS) phải chạy liên tục. EA cần khoảng 1.500 nến M15 và H1 lịch sử (MT5 tự tải).
4. Mỗi 2–4 tuần gửi file log CSV và lịch sử lệnh (hoặc chạy TradeLogger).

**Tiêu chí đánh giá sau khoảng 35–45 lệnh:**
- Tiếp tục nếu R trung bình > 0 **và** DD < 10%.
- Dừng và phân tích lại nếu R trung bình < −0,1 hoặc chạm kill-switch.
- Kết quả demo được dùng để kiểm chứng các giả thuyết chưa được phép áp dụng (bỏ phiên 17–24h UTC, bỏ cuối tuần).

## 5. Lưu ý

- **Tài khoản nhỏ:** với số dư khoảng 8.800 USC (~88 USD), rủi ro 0,5% khoảng 44 USC, trong khi SL khoảng 400–600$
  mỗi 1 BTC. Nếu lot tối thiểu vẫn vượt 1,5 lần mức rủi ro cho phép, EA sẽ **bỏ lệnh** và ghi
  `[SKIP] min lot ... account too small` trong tab Experts. Cần ảnh Specification (contract size, lot tối thiểu)
  để tính chính xác.
- **Swap:** khoảng 11% số lệnh giữ qua 00:00 server. Backtest chưa tính swap.
- **Kill-switch** lưu trong Global Variables của terminal (`MOM15H1_..._kill`). Muốn bật lại EA sau khi dừng
  thì xóa biến đó (F3), **sau khi** đã phân tích nguyên nhân.
- **Rollback:** mọi tham số đều là input; phiên bản gốc được giữ trong git. Mỗi thay đổi tham số phải được
  kiểm lại bằng `research/btc` trước khi đưa vào demo.
