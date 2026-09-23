# ICT Bot — backtest demo cho EA XAUUSD_ICT_M5

Bot Python chạy lại **đúng logic** của `MQL5/Experts/XAUUSD_ICT_M5.mq5` (4 setup
A/B/C/D, killzone, sweep, BOS/CHoCH, OB/FVG, ICT Score, chốt 50% ở TP1, dời SL
hoà vốn, lọc tin, giới hạn lỗ ngày...) trên dữ liệu bạn tải từ sàn về, rồi
xuất **một file HTML báo cáo** mở bằng trình duyệt, không cần mạng:

- Biểu đồ nến M5 có zoom/kéo, tô màu killzone, vùng SL/TP của từng lệnh
- **Replay**: bấm ▶ để "chơi lại" thị trường từng nến, xem bot vào/thoát lệnh
  và số dư thay đổi theo thời gian thực (phím Space = chạy/dừng, ←/→ = từng nến)
- Equity + drawdown, heatmap lợi nhuận theo tháng, phân bố R-multiple
- Thống kê theo setup, theo hướng, theo killzone; bảng lệnh lọc/sắp xếp được,
  bấm một dòng để nhảy tới lệnh trên biểu đồ
- Bảng chẩn đoán giống dòng `[ICT-EA Summary]` của EA

Chỉ cần **Python 3.8+**, không phải cài thư viện nào.

## 1. Lấy dữ liệu từ sàn

**Cách A — xuất bằng tay trong MT5** (dễ nhất):
1. MT5 → `View > Symbols` (Ctrl+U) → chọn XAUUSD (hoặc XAUUSDr/XAUUSDm…).
2. Tab **Bars**: chọn khung **M1** hoặc **M5**, chọn khoảng ngày → *Request* → *Export Bars*.
   Hoặc tab **Ticks** → *Request* → *Export Ticks* (chính xác nhất, file nặng).
3. Lưu file vào thư mục `backtest/data/`.

**Cách B — script tự tải** (Windows, MT5 đang mở và đã đăng nhập):
```
pip install MetaTrader5
python download_mt5.py --symbol XAUUSD --days 180          # nến M1
python download_mt5.py --symbol XAUUSD --days 30 --ticks   # tick thật
```

Bot tự nhận dạng: file nến MT5, file tick MT5 (UTF-16), CSV có cột
time/open/high/low/close. Nến M1 và tick được gộp thành M5.

## 2. Chạy backtest

```
cd backtest
python run_backtest.py data/XAUUSD_M1.csv
```
Báo cáo được lưu ở `backtest/reports/` và tự mở trong trình duyệt.

Tuỳ chọn hay dùng:

| Tuỳ chọn | Ý nghĩa |
|---|---|
| `--balance 5000` | Vốn ban đầu (mặc định 10 000 USD) |
| `--risk 1` | % rủi ro mỗi lệnh (mặc định 0.75 như EA) |
| `--from 2025-01-01 --to 2025-07-01` | Chỉ vào lệnh trong khoảng này |
| `--spread 25` | Spread (points) khi file không có cột spread |
| `--commission 7` | Phí hoa hồng USD/lot khứ hồi |
| `--gmt-offset 0` | Broker giờ GMT cố định (vd Exness). Bỏ trống = server luôn đi trước NY 7 giờ (ICMarkets, Pepperstone…) |
| `--set piv_len=6 --set enable_setup_d=false` | Đổi bất kỳ input nào của EA (tên xem trong `ict_bot/strategy.py` → `Params`) |

## Chưa có dữ liệu? Chạy thử với dữ liệu giả lập

```
python make_demo_data.py
python run_backtest.py data/DEMO_XAUUSD_M5.csv
```
Giá do máy tạo ngẫu nhiên — chỉ để xem bot và báo cáo hoạt động, kết quả không
có ý nghĩa về thị trường thật (báo cáo có dán nhãn cảnh báo).

## Khác biệt so với Strategy Tester của MT5

- Mô phỏng trên nến M5, không từng tick: SL/TP kiểm tra bằng high/low của nến;
  nếu một nến chạm cả SL lẫn TP thì tính **SL trước** (thận trọng). Với dữ liệu
  tick, spread thật của từng nến được dùng.
- EA chỉ ra quyết định ở tick đầu tiên của nến mới → bot khớp lệnh ở giá mở
  nến kế tiếp (Bid, hoặc Ask = Bid + spread), đúng như tester.
- Không tính swap qua đêm; lệnh chờ/stop level của broker không mô phỏng.
- Vì vậy số liệu sẽ gần nhưng **không trùng khít** với MT5. Hãy dùng bot để
  thử ý tưởng/tham số nhanh, rồi xác nhận lại trong MT5 (Every tick based on
  real ticks) và trên tài khoản demo trước khi nghĩ tới tiền thật.
