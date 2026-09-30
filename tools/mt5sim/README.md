# mt5sim — bộ giả lập MT5 tối thiểu để kiểm tra EA MQL5 ngoài MetaTrader

Công cụ này **không thay thế MetaEditor hay Strategy Tester**. Nó dùng khi không có MT5, để:

1. **Kiểm tra cú pháp và kiểu:**
   - dịch mã `.mq5` sang C++ (`mq5_to_cpp.py`);
   - biên dịch bằng g++ `-Wall -Wextra` cùng lớp giả lập API MQL5 (`mql5.h`).

   Cách này bắt được lỗi định danh, sai số tham số, sai kiểu và gọi hàm chưa khai báo. Nó không kiểm tra được các quy tắc riêng của trình biên dịch MQL5.
2. **Chạy chính mã EA trên tick thật hoặc tick sinh từ nến M1** và kiểm toán rủi ro độc lập với EA:
   - rủi ro dự kiến mỗi lệnh (% của min(Balance, Equity) trước lệnh);
   - lỗ trong ngày;
   - vị thế thiếu SL/TP;
   - vị thế còn mở sau giờ đóng cuối ngày hoặc qua cuối tuần;
   - số vị thế đồng thời.

## Mô phỏng những gì

| Thành phần | Cách mô phỏng |
|---|---|
| Tài khoản | Hedging, USD, đòn bẩy cấu hình được, ký quỹ CFD = lot × contract × giá / đòn bẩy, stop-out |
| Khớp lệnh | Lệnh thị trường khớp tại Ask/Bid, cộng trượt giá bất lợi ngẫu nhiên (`slip_max`). Có kiểm tra khối lượng, stop level, ký quỹ |
| SL/TP | Kiểm tra mỗi tick trước `OnTick`, khớp tại giá tick (gồm cả gap) |
| Lịch sử | Deal IN/OUT, deal nạp/rút (`cash_at`); `HistorySelect`, `HistorySelectByPosition` |
| Nến | M1, M5, M15, M30, H1, H4, D1 dựng từ tick theo Bid; nạp sẵn lịch sử từ file nến M1 |
| File, GlobalVariable | Ghi vào `<out>/Common/Files/`; GlobalVariable giữ trong bộ nhớ và xuất `global_variables.txt` |
| Lỗi runtime | Kiểm tra chỉ số mảng; bẫy chia cho 0 và phép tính không hợp lệ (như lỗi "zero divide" của MQL5) |
| Khởi động lại | `restart_at=`: gọi OnDeinit(REASON_CHARTCHANGE) rồi OnInit() khi đang chạy |
| LIVE / tài khoản thật | `tester=0` bật nhánh LIVE của EA (timer, lưu dữ liệu học); `trade_mode=2` giả lập tài khoản REAL |

**Không mô phỏng:** requote/từ chối lệnh, thị trường đóng, commission/swap thật theo từng sàn, độ trễ mạng. Chế độ tick sinh chỉ gần đúng: số tick mỗi phút = tick_volume, đường giá trong phút là cầu Brown qua O–H–L–C.

## Cách dùng

```bash
# 1. Build (dich EA + bien dich)
tools/mt5sim/build.sh MQL5/Experts/DavidHunterV5/EA_DAVID_HUNTER_V5_00_TICK_AI_TEST.mq5 /duong_dan/build

# 2. (Tick that) giai nen zip tick MT5 -> npz -> nhi phan
python3 research/david_hunter_v5/load_ticks.py "/duong_dan/EA-PRO/data/tick/XAUUSDm_2026-01-01_2026-04-30/*.zip.part*" ticks.npz
python3 tools/mt5sim/npz_to_bin.py ticks.npz ticks.bin

# 3. Chay voi file cau hinh (key=value); co the ghi de tren dong lenh, ke ca Input cua EA
/duong_dan/build/mt5sim cau_hinh.cfg InpCheDoHoc=1 spread_add=0.10 slip_max=0.30
```

Ví dụ `cau_hinh.cfg`:

```
mode=real                 # real = tick that (ticks=), gen = sinh tick tu nen M1
ticks=/duong_dan/ticks.bin
m1=/duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv
out=/duong_dan/ket_qua/lan_chay_1
start=2026.01.01 23:05:00
end=2026.01.12 13:00:00
deposit=10000
leverage=200
# tuy chon: tester=0, trade_mode=2, spread_mult=, spread_add=, slip_max=, commission_side=, stops_level=,
#           restart_at=YYYY.MM.DD HH:MM:SS (lap lai duoc), cash_at=YYYY.MM.DD HH:MM:SS,-3000, seed=, quiet=1
```

Kết quả nằm trong thư mục `out`:

| File | Nội dung |
|---|---|
| `bao_cao.txt` | Chỉ số tổng, kiểm toán rủi ro, theo PP (comment), theo tháng |
| `lenh.csv` | Từng vị thế: giá mở/đóng, SL/TP ban đầu, rủi ro dự kiến, R, lý do đóng |
| `ngay.csv` | Balance đầu ngày, Equity thấp nhất, lỗ trong ngày (%) |
| `journal.txt` | Nội dung các lệnh `Print` của EA |
| `Common/Files/...` | Log do chính EA ghi |

## Tạo file SET

```bash
python3 tools/mt5sim/tao_set.py EA.mq5 ten.set   # UTF-16LE co BOM, enum ghi bang so, giong SET MT5 xuat ra
```
