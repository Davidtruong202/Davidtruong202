# David Hunter V4.39 MATRIX – bộ backtest Python theo tick

Bản chuyển sang Python của `EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5` (repo EA-PRO), dùng để quét input × khung
thời gian cho các phương pháp **chưa triển khai** (EMA, ICT, MM, SMC, PVEMA, PIN, LQ) trên tick thật, ngoài MT5.

Báo cáo kết quả:
- [`BAO_CAO_BACKTEST_7PP_CHUA_TRIEN_KHAI.md`](../../docs/david_hunter_v439/BAO_CAO_BACKTEST_7PP_CHUA_TRIEN_KHAI.md): quét Python trên 6,5 ngày (sơ bộ)
- [`BAO_CAO_KIEM_CHUNG_MT5_9_THANG.md`](../../docs/david_hunter_v439/BAO_CAO_KIEM_CHUNG_MT5_9_THANG.md): kiểm chứng trong MT5 trên 9 tháng. **Cả 6 ứng viên đều lỗ.**

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `dh/data.py` | Đọc file tick MT5 dạng zip (chia phần `*.zip.part001…`, thiếu phần vẫn đọc được phần đã có), dựng nến theo Bid như MT5 |
| `dh/mt5ind.py` | EMA, ATR, RSI, ADX đúng công thức MT5 |
| `dh/config.py` | Input mặc định V4.39 (chép từ mã nguồn), hằng số LAB, 4 cấu hình live V4.52 |
| `dh/signals_pv.py` | PVEMA, ENG, PIN, BRK, LQ, PVT (`ProcessAdditionalSignals` + `EnterPVSignal`) |
| `dh/signals_setup.py` | ICT, MM, SMC (dò Sweep/MSS/FVG/OB, vòng đời setup, `TryEnterSetup` theo tick) |
| `dh/signals_ema.py` | EMA: giao cắt/retest theo tick, lọc sóng |
| `dh/sim.py` | Quản lý lệnh LAB: SL 5–20, TP1 50% @1R + hòa vốn, trailing 1R, TP2 theo RR |
| `dh/matrix.py`, `dh/engine.py` | 12 tài khoản ảo (hướng × phiên) mỗi bộ input, thống kê |
| `grids.py` | Lưới input × TF của nghiên cứu (tên trục = tên input EA) |
| `run_matrix.py` → `analyze.py` → `validate.py` → `null_tournament.py` → `make_sets.py` | Quét → xếp hạng → kiểm định → giải đấu ngẫu nhiên → file SET MT5 |
| `tests/` | Bản dịch nguyên văn MQL5 (chậm) và bài đối chiếu với bản nhanh |
| `results/` | Kết quả lần chạy trên dữ liệu 01–12/01/2026 |
| `make_ea_7pp.py` | Tạo `MQL5/Experts/EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5`: bản V4.39 có sẵn 13 bộ test trong input "Bộ cài sẵn" (không cần file SET) |
| `mt5_sets/` | File SET cho EA V4.39 MATRIX gốc (ghi đủ 197 input) + `HUONG_DAN.txt`; bản 7PP ở trên thay thế các file này |
| `analyze_mt5.py` | Đọc kết quả MT5 của EA 7PP: 6 ứng viên, chọn trên T1–T6 rồi kiểm trên T7–T9, ô hướng × phiên, từng trục input |
| `compare_mt5.py` | Đối chiếu từng lệnh thật của ví 0 trong MT5 với bản Python (01–12/01/2026) |
| `results_mt5/` | Kết quả hai script trên cho lượt MT5 01/01–27/09/2026 (`EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/`) |

## Chạy

```bash
pip install numpy pandas numba
export DH_CACHE=/tmp/dh_cache          # nơi lưu cache tick (.npz), mặc định ./.cache
python3 run_matrix.py --ticks "/duong_dan/EA-PRO/data/tick/XAUUSDm_2026-01-01_2026-04-30/*.zip.part*" --split 2026-01-08 --out results
python3 analyze.py --res results
python3 validate.py --res results --reps 1000
python3 null_tournament.py --res results --reps 100
python3 make_sets.py
python3 tests/test_crosscheck.py && python3 tests/test_engines.py
# kết quả MT5 (thư mục RUN của EA 7PP)
python3 analyze_mt5.py --run /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP
python3 compare_mt5.py --mt5 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/lenh_tham_chieu_MT5.csv
```

Khi có thêm dữ liệu, xóa cache cũ (`$DH_CACHE/xauusdm_2026.npz`) hoặc đổi `--cache-name`, rồi đặt `--split` vào khoảng
60–70% thời gian dữ liệu để có tập kiểm chứng.

## Giả định và giới hạn

- Tiền tính bằng USD cho lot cố định 0,02 (mặc định LAB V4.39), contract 100. Commission 0, **chưa tính swap**,
  không mô phỏng margin/stop-out.
- Phiên theo giờ server (Exness GMT+0): Á 0–8, Âu 8–16, Mỹ 16–24.
- Chỉ báo bắt đầu từ nến đầu tiên của dữ liệu. MT5 thì có lịch sử trước đó, nên EMA dài trên H1 hội tụ chậm hơn ở đây.
- Bỏ qua tổ hợp vô nghĩa (TF bias nhỏ hơn TF vào lệnh, EMA nhanh ≥ chậm, min ≥ max). Lưới MQL vẫn sẽ chạy các tổ hợp đó.
