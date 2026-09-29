# research/phoenix_grid

Bộ công cụ nghiên cứu Phoenix Grid. Kế hoạch (đã duyệt 29/09/2026): [`docs/phoenix_grid/`](../../docs/phoenix_grid/).

Không có công cụ nào ở đây mô phỏng lệnh hay tính lợi nhuận chiến lược. Bộ mô phỏng chỉ được viết ở các phiên bản
R0.3 trở đi, theo lộ trình đã duyệt.

```bash
pip install numpy pandas
```

## PG-R0.1 — thông số MT5 và chất lượng dữ liệu tick

| File | Việc làm |
|---|---|
| `pg_data.py` | Đọc file tick zip của MT5 (có thể chia phần, thiếu phần cuối vẫn đọc được). Làm sạch có đếm bất thường. Dựng nến M1 theo Bid như MT5 |
| `kiem_tra_tick.py` | Báo cáo chất lượng tick: độ phủ, bất thường, khoảng trống, spread theo tick, bước nhảy giá, đối chiếu nến M1 của MT5, so spread hai bộ tick |
| `doc_thong_so.py` | Đọc CSV của script MT5 `PG_R01_DocThongSo.mq5`, xác minh H_K, kiểm tra điều kiện kế hoạch |

```bash
# Kiểm tra tick (đã chạy trên XAUUSDm 01–12/01/2026 → results_r01/)
python3 kiem_tra_tick.py \
  --ticks "/duong_dan/EA-PRO/data/tick/XAUUSDm_2026-01-01_2026-04-30/*.zip.part*" \
  --nhan XAUUSDm_2026-01-01_2026-01-12 \
  --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv \
  --out results_r01

# Khi có tick XAUUSDc: so spread với XAUUSDm trên phần thời gian trùng nhau
python3 kiem_tra_tick.py --ticks "<XAUUSDc>/*.zip*" --nhan XAUUSDc --ticks2 "<XAUUSDm>/*.zip*" --nhan2 XAUUSDm

# Đọc thông số do script MT5 xuất ra
python3 doc_thong_so.py --file PG_R01_thong_so_XAUUSDc_<ngày>.csv --spread-gio PG_R01_spread_theo_gio_XAUUSDc_<ngày>.csv
python3 doc_thong_so.py --tu-kiem-tra
```

| File trong `results_r01/<nhãn>/` | Nội dung |
|---|---|
| `tong_quan.csv` | Độ phủ, số bất thường, spread tổng thể, kết quả đối chiếu nến M1 |
| `spread_tick_theo_gio.csv`, `spread_tick_theo_ngay.csv` | Spread theo tick (point) |
| `khoang_trong.csv` | Khoảng trống > 60 giây và loại (nghỉ hằng ngày / cuối tuần / trong phiên) |
| `buoc_nhay_lon_nhat.csv` | 10 bước nhảy Bid lớn nhất giữa hai tick liên tiếp trong phiên |
| `doi_chieu_m1_nen_lech.csv` | Nến chỉ có ở một phía khi đối chiếu với MT5 |

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
