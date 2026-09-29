# research/phoenix_grid

Bộ công cụ nghiên cứu Phoenix Grid. Kế hoạch: [`docs/phoenix_grid/`](../../docs/phoenix_grid/).

## Hiện có: PG-R0.0 — thống kê mô tả (không phải backtest)

`thong_ke_mo_ta.py` đọc nến M1 XAUUSDm và tính các chỉ số sau:

- độ phủ dữ liệu và giờ nghỉ;
- spread theo giờ và theo tháng;
- biên độ ngày;
- ATR14 các khung;
- biến động ngược chiều tối đa từ một điểm vào bất kỳ;
- variance ratio Lo–MacKinlay;
- gap cuối tuần.

Script **không** mô phỏng lệnh và **không** tính lợi nhuận của chiến lược nào. Bộ kiểm định chiến lược chỉ được viết
sau khi kế hoạch được phê duyệt.

```bash
pip install numpy pandas
python3 thong_ke_mo_ta.py \
  --m1 /duong_dan/EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv \
  --out results
```

| File trong `results/` | Nội dung |
|---|---|
| `spread_theo_gio.csv`, `spread_theo_thang.csv` | Trung vị và p90 của spread (USD/oz) |
| `bien_do_ngay.csv`, `bien_do_ngay_theo_thang.csv` | High − Low theo ngày server |
| `atr14.csv` | p10 / trung vị / p90 của ATR14 các khung M1, M5, M15, H1 |
| `bien_dong_nguoc.csv` | Phân phối và xác suất giá đi ngược ≥ X USD trong 15 phút → 5 ngày |
| `bien_dong_nguoc_24h_theo_thang.csv` | Như trên cho khung 24 giờ, theo từng tháng |
| `variance_ratio.csv` | VR(q) và z* chịu phương sai thay đổi |
| `gap_cuoi_tuan.csv` | Gap mở cửa sau cuối tuần / ngày lễ |

Môi trường đã chạy: Python 3, numpy 2.4, pandas 3.0. Thời gian chạy khoảng 2 giây.
