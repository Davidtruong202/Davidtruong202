# research/phoenix_grid

Bộ công cụ nghiên cứu Phoenix Grid. Kế hoạch (đã duyệt 29/09/2026): [`docs/phoenix_grid/`](../../docs/phoenix_grid/).

Không có công cụ nào ở đây mô phỏng lệnh hay tính lợi nhuận chiến lược (`phan_tich_log_v020.py` chỉ cộng số liệu EA đã ghi). Bộ mô phỏng chỉ được viết ở các phiên bản
R0.3 trở đi, theo lộ trình đã duyệt.

```bash
pip install numpy pandas
```

## EA quan sát — công cụ phụ trợ (`cong_cu_ea/`)

| File | Việc làm |
|---|---|
| `kiem_tra_tinh_mq5.py` | Kiểm tra tĩnh file MQL5: ngoặc, lời gọi hàm, hàm trùng, biến `g_`, từ khóa giao dịch trong mã, nhãn input. Không thay được compile |
| `dong_goi_cai_dat.py` | Đóng gói `goi_cai_dat/<tên>.zip`: thư mục MQL5 sắp sẵn cho MT5 + hướng dẫn từng bước; kiểm tra include, BOM, file SET khớp input |
| `tao_file_set.py` | Sinh file `.set` (UTF-16, như MT5 lưu) từ input trong mã nguồn EA vào `MQL5/Presets/PhoenixGrid/`; `--kiem-tra` đối chiếu lại từng input |

## Market Intelligence — TEST 1 shadow

| File | Việc làm |
|---|---|
| `phan_tich_log_mi.py` | Đánh giá log `PMI_V001_*`: thời gian ở mỗi trạng thái; mỗi đợt breakout (xác nhận → đi tiếp ≥ 1 độ rộng range trong H nến?; thất bại → loại đúng?); đợt phòng thủ, thời lượng, bật lại trong 2 giờ. `--tu-kiem-tra` đọc tiêu đề 48 cột từ file `.mqh` |
| `ban_sao_python_mi.py` | Bản sao Python của logic nhận diện trong `PHOENIX_MI_V0_01.mqh`, chạy trên nến M1 lịch sử (dựng M5), ghi log cùng định dạng. Chỉ để bắt lỗi logic và xem trước. **Không phải EA, không phải backtest giao dịch** |
| `results_mi/` | Kết quả xem trước (bản sao Python), XAUUSDm 2026 |

```bash
python3 ban_sao_python_mi.py --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv \
  --out /tmp/mi --gia-lap-basket --diem 60 --so-nen 2
python3 phan_tich_log_mi.py --thu-muc /tmp/mi --symbol XAUUSDm --nhan d60n2 --tester --out results_mi
python3 phan_tich_log_mi.py --tu-kiem-tra
```

## EA V0.20 — đọc log hằng ngày

| File | Việc làm |
|---|---|
| `phan_tich_log_v020.py` | Tóm tắt log `PG_V020_*.csv`: tổng kết ngày, basket (theo PP, hướng, cách clear, độ sâu), lệnh theo lý do đóng, lý do không vào lệnh, trượt giá và độ trễ gửi lệnh. `--tu-kiem-tra` đọc tiêu đề log thẳng từ file `.mq5` |

```bash
python3 phan_tich_log_v020.py --thu-muc <thư mục Common\Files\PhoenixGrid> --symbol XAUUSDc --out results_v020
python3 phan_tich_log_v020.py --tu-kiem-tra
```

```bash
python3 cong_cu_ea/kiem_tra_tinh_mq5.py ../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_11_TEST.mq5
```

Biểu tượng phượng hoàng của V0.10 đã bỏ từ V0.11 theo yêu cầu 30/09/2026; script vẽ biểu tượng còn trong lịch sử git
(commit `61bab04`).

## PG-R0.1 — thông số MT5 và chất lượng dữ liệu tick

| File | Việc làm |
|---|---|
| `pg_data.py` | Đọc tick MT5, tự nhận ba dạng:<br>- một zip có thể chia phần (thiếu phần cuối vẫn đọc được)<br>- nhiều zip độc lập (ví dụ `XAUUSD_01.zip` … `XAUUSD_20.zip`)<br>- CSV không nén<br>Mỗi phần có hoặc không có dòng tiêu đề. Làm sạch có đếm bất thường, dựng nến M1 theo Bid như MT5. `python3 pg_data.py --tu-kiem-tra` chạy 6 phép thử trên dữ liệu giả |
| `kiem_tra_tick.py` | Báo cáo chất lượng tick: độ phủ, bất thường, khoảng trống, spread theo tick, bước nhảy giá, đối chiếu nến M1 của MT5, so spread hai bộ tick |
| `doc_thong_so.py` | Đọc CSV của script MT5 `PG_R01_DocThongSo.mq5`, xác minh H_K, kiểm tra điều kiện kế hoạch, in nhận định tự động (đòn bẩy, stop out, chế độ khớp…). `--von` nhận nhiều mức vốn |
| `du_lieu_r01/<server>_<symbol>_<thời điểm>/` | File CSV gốc do script MT5 xuất ra, lưu nguyên văn |

```bash
# Kiểm tra tick (đã chạy trên XAUUSDm 01–12/01/2026 → results_r01/)
python3 kiem_tra_tick.py \
  --ticks "/duong_dan/EA-PRO/data/tick/XAUUSDm_2026-01-01_2026-04-30/*.zip.part*" \
  --nhan XAUUSDm_2026-01-01_2026-01-12 \
  --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv \
  --out results_r01

# Khi có tick XAUUSDc: so spread với XAUUSDm trên phần thời gian trùng nhau
python3 kiem_tra_tick.py --ticks "<XAUUSDc>/*.zip*" --nhan XAUUSDc --ticks2 "<XAUUSDm>/*.zip*" --nhan2 XAUUSDm
# Nhiều zip độc lập (XAUUSD_01.zip … XAUUSD_20.zip) hoặc CSV: cùng lệnh, đổi mẫu đường dẫn
python3 kiem_tra_tick.py --ticks "/duong_dan/EA-PRO/data/tick/XAUUSDc_<từ>_<đến>/XAUUSD_*.zip" --nhan XAUUSDc
python3 pg_data.py --tu-kiem-tra

# Đọc thông số do script MT5 xuất ra
python3 doc_thong_so.py --file PG_R01_thong_so_XAUUSDc_<ngày>.csv --spread-gio PG_R01_spread_theo_gio_XAUUSDc_<ngày>.csv \
  --von 5000 --out results_r01
python3 doc_thong_so.py --tu-kiem-tra
```

| File trong `results_r01/<nhãn>/` | Nội dung |
|---|---|
| `tong_quan.csv` | Độ phủ, số bất thường, spread tổng thể, kết quả đối chiếu nến M1 |
| `spread_tick_theo_gio.csv`, `spread_tick_theo_ngay.csv` | Spread theo tick (point) |
| `khoang_trong.csv` | Khoảng trống > 60 giây và loại (nghỉ hằng ngày / cuối tuần / trong phiên) |
| `buoc_nhay_lon_nhat.csv` | 10 bước nhảy Bid lớn nhất giữa hai tick liên tiếp trong phiên |
| `doi_chieu_m1_nen_lech.csv` | Nến chỉ có ở một phía khi đối chiếu với MT5 |
| `results_r01/thong_so_<symbol>_<thời điểm>.md` | Báo cáo thông số do `doc_thong_so.py` sinh ra |

## PG-R0.0 — thống kê mô tả nến M1 (không phải backtest)

`thong_ke_mo_ta.py` đọc nến M1 XAUUSDm và tính các chỉ số sau:

- độ phủ dữ liệu và giờ nghỉ;
- spread theo giờ và theo tháng;
- biên độ ngày;
- ATR14 các khung;
- biến động ngược chiều tối đa từ một điểm vào bất kỳ;
- variance ratio Lo–MacKinlay;
- gap cuối tuần.

```bash
python3 thong_ke_mo_ta.py \
  --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv \
  --out results
```

| File trong `results/` | Nội dung |
|---|---|
| `spread_theo_gio.csv`, `spread_theo_thang.csv` | Trung vị và p90 của cột spread nến M1 (USD/oz). Cột này nhiều khả năng là spread nhỏ nhất trong phút (R0.1) |
| `bien_do_ngay.csv`, `bien_do_ngay_theo_thang.csv` | High − Low theo ngày server |
| `atr14.csv` | p10 / trung vị / p90 của ATR14 các khung M1, M5, M15, H1 |
| `bien_dong_nguoc.csv` | Phân phối và xác suất giá đi ngược ≥ X USD trong 15 phút → 5 ngày |
| `bien_dong_nguoc_24h_theo_thang.csv` | Như trên cho khung 24 giờ, theo từng tháng |
| `variance_ratio.csv` | VR(q) và z* chịu phương sai thay đổi |
| `gap_cuoi_tuan.csv` | Gap mở cửa sau cuối tuần / ngày lễ |

Môi trường đã chạy: Python 3, numpy 2.4, pandas 3.0.
