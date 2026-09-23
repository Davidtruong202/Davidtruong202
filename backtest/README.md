# Gold Bot — bot giao dịch vàng MT5 + backtest

Bộ công cụ Python cho XAUUSD khung M5 (viết cho sàn **HFM**, dùng được với sàn
MT5 khác):

| File | Việc nó làm |
|---|---|
| `live_bot.py` | **Bot giao dịch tự động** trên MT5 (mặc định chỉ tài khoản demo) |
| `run_backtest.py` | Backtest trên dữ liệu tick/nến của sàn, xuất **báo cáo HTML** |
| `optimize.py` | Tối ưu tham số kiểu **walk-forward** (chống overfitting) |
| `download_mt5.py` | Tải tick/nến trực tiếp từ MT5 |
| `compare_ea.py` | So lệnh của EA MT5 với backtest Python |
| `../MQL5/Experts/GoldBot_SessionBreakout.mq5` | **EA MT5** cùng chiến lược (cách B) |
| `config.example.json` | Cấu hình **dùng chung** cho backtest và bot live |

Bot live và backtest chạy **cùng một đoạn code chiến lược**
(`goldbot/strategies/`). Bài test `tests/test_live_vs_backtest.py` cho bot live
chạy trên một MT5 giả lập rồi so với backtest trên cùng dữ liệu: 26/26 lệnh
trùng khớp.

## Cách B: chạy bằng EA MT5 (không cần Python trên máy giao dịch)

File EA: `MQL5/Experts/GoldBot_SessionBreakout.mq5`. Đây là bản MQL5 của
đúng chiến lược Python, với tham số trùng tên (`InpTP_R` ↔ `tp_r`...).

1. Copy file vào `MQL5/Experts/` (MT5: File → Open Data Folder), mở
   MetaEditor và bấm **F7** để biên dịch.
2. **Kiểm chứng EA trong Strategy Tester** (Ctrl+R): chọn EA, symbol
   `XAUUSDr`, khung M5, Modelling = **Every tick based on real ticks**, và
   khoảng thời gian trùng với dữ liệu đã backtest. Nhập tham số giống
   `config.json`.
3. EA ghi mọi lệnh vào file `GoldBot_<symbol>_<magic>.csv` trong thư mục
   **Common\Files** (File → Open Data Folder → lùi lên 2 cấp → Common → Files).
   Gửi file này cho Claude, hoặc tự so bằng:
   ```
   python compare_ea.py GoldBot_XAUUSDr_26092301.csv data/XAUUSDr_ticks.csv --config config.json
   ```
   Nếu khớp khoảng 90% lệnh trở lên (cùng nến, cùng chiều) thì EA chạy đúng
   chiến lược đã kiểm chứng. Hãy xoá file CSV cũ trước mỗi lần chạy tester.
4. **Demo**: kéo EA vào chart XAUUSDr M5 trên tài khoản demo và bật Algo
   Trading. EA vẽ range phiên Á lên chart và hiện trạng thái ở góc trái.
   Muốn chạy 24/7 thì dùng VPS của HFM.
5. EA từ chối chạy trên tài khoản thật cho tới khi bạn bật
   `InpAllowRealAccount = true`.

## Chiến lược: Session Breakout

Vàng thường đi ngang trong phiên Á, rồi phá range khi London/New York mở cửa.

1. **Range**: đỉnh/đáy từ 19:00 → 02:00 giờ New York (phiên Á).
2. **Lọc range**: chiều cao range phải nằm trong 1–5 × ATR(H1). Ngày quá lặng
   hoặc đã chạy quá xa từ đêm thì bỏ.
3. **Tín hiệu**: từ 02:00 → 11:00 NY, một nến M5 **đóng cửa** vượt range
   (+0.1 ATR), nến trước còn trong range, thân nến ≥ 50% chiều dài nến.
4. **Xu hướng**: chỉ Mua khi giá trên EMA50 H1 đang dốc lên, chỉ Bán khi ngược lại.
5. **SL** ở giữa range (giới hạn 1.5–5 × ATR M5). **TP1** = 1R: chốt 50%, dời SL
   về hoà vốn. Phần còn lại nhắm **2R**, trailing 3 × ATR. Đến 15:00 NY đóng hết.
6. Tối đa 2 lệnh/ngày, mỗi chiều 1 lệnh.

Mọi con số trên đều là tham số trong `config.json`. **Chưa ai kiểm chứng
chiến lược này trên dữ liệu thật**: cần chạy `optimize.py` trên tick data HFM,
và chỉ giao dịch nếu kết quả *ngoài mẫu* tốt.

## Quy trình đề xuất

```
pip install MetaTrader5            # chỉ cần cho live_bot.py và download_mt5.py (Windows)
cd backtest
copy config.example.json config.json
```

**1. Lấy dữ liệu HFM**: mở MT5 → Ctrl+U → chọn `XAUUSDr` (hoặc tên vàng trên
tài khoản của bạn) → tab **Ticks** → chọn khoảng ngày (≥ 6 tháng) → Request →
**Export Ticks**, lưu vào `backtest/data/`. Hoặc dùng lệnh:
```
python download_mt5.py --symbol XAUUSDr --days 180 --ticks
```

**2. Backtest** (tự mở báo cáo trong trình duyệt):
```
python run_backtest.py data/XAUUSDr_ticks.csv --config config.json
```

**3. Tối ưu walk-forward**: chọn tham số trên quá khứ, kiểm tra trên đoạn
chưa thấy:
```
python optimize.py data/XAUUSDr_ticks.csv --config config.json
```
Kết quả cuối có dòng *Đánh giá*. Nếu là "CHƯA CÓ LỢI THẾ" thì **đừng** chạy
tiền thật. File `config.optimized.json` chứa bộ tham số được chọn.

**4. Chạy demo** ít nhất vài tuần:
```
python live_bot.py --config config.json --dry-run   # chỉ ghi log tín hiệu, không đặt lệnh
python live_bot.py --config config.json             # đặt lệnh trên tài khoản demo
```
MT5 phải đang mở và đăng nhập, bật nút **Algo Trading**. Log nằm ở
`logs/bot_<symbol>.log`, nhật ký lệnh ở `logs/journal_<symbol>.csv`. Dừng bot
bằng Ctrl+C: lệnh đang mở vẫn giữ SL/TP trên sàn. Khởi động lại bot vẫn nhớ
trạng thái TP1 (`logs/state_*.json`).

**5. Tài khoản thật**: chỉ khi demo khớp với backtest. Phải tự đặt
`"allow_real_account": true` trong `config.json`. Nếu không, bot sẽ từ chối.

## Cấu hình (`config.json`)

- `symbol`: tên vàng trên sàn (HFM thường là `XAUUSDr` hoặc `XAUUSD`).
- `strategy_params`: tham số chiến lược. `server_to_ny_hours = 7` đúng cho
  HFM (giờ server GMT+2/+3 theo DST Mỹ). Sàn GMT cố định: đặt
  `broker_fixed_ny_offset=false` và `server_gmt_offset_hours`.
- `risk`: `risk_percent` (% vốn mỗi lệnh), `max_daily_loss_percent` (lỗ ngày
  tối đa rồi nghỉ tới hôm sau), `max_consec_losses`, `max_spread_points`.
- `live`: `magic`, `dry_run`, `allow_real_account`, `poll_seconds`,
  `mt5_path`/`login`/`password`/`server` (để trống = dùng MT5 đang mở).

Đổi nhanh khi backtest: `--set tp_r=2.5 --set use_trend=false --set risk_percent=1`.

## Báo cáo backtest

Một file HTML tự chứa, mở offline được:
- **Replay**: bấm ▶ để xem bot giao dịch lại từng nến (Space = chạy/dừng, ←/→ = từng nến)
- Biểu đồ nến zoom/kéo được, tô màu phiên, vùng SL/TP của từng lệnh
- Equity + drawdown, lợi nhuận theo tháng, phân bố R, cách thoát lệnh
- Bảng lệnh lọc/sắp xếp được, bấm vào dòng để nhảy tới biểu đồ
- Bảng chẩn đoán: bộ lọc nào đã chặn bao nhiêu tín hiệu

Chưa có dữ liệu thì chạy thử với giá giả lập:
`python make_demo_data.py && python run_backtest.py data/DEMO_XAUUSD_M5.csv`.

Chiến lược ICT cũ (port từ `XAUUSD_ICT_M5.mq5`) vẫn backtest được:
`--strategy ict` (chỉ backtest, không có bản live).

## Độ chính xác của backtest

- Với **tick data**, bot biết trong mỗi nến M5 đỉnh hay đáy đến trước, nên
  xác định được SL hay TP khớp trước. Spread thật của từng nến cũng được dùng.
  Với dữ liệu nến, nếu một nến chạm cả SL lẫn TP thì bot giả định giá chạm
  hướng bất lợi trước (thận trọng).
- Lệnh vào ở giá mở nến kế tiếp sau tín hiệu, đúng như bot live.
- Chưa tính swap qua đêm (bot đóng lệnh trong ngày nên ảnh hưởng nhỏ), cũng
  chưa tính trượt giá khi tin mạnh. Nên đặt `--commission` đúng loại tài khoản HFM.

## Cảnh báo

Không có bot nào đảm bảo lợi nhuận. Kết quả quá khứ, kể cả ngoài mẫu, không
bảo đảm tương lai. Luôn chạy demo trước và chỉ dùng số vốn bạn chấp nhận mất.
