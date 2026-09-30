# Nghiên cứu cho David Hunter V5.00 TICK AI

Báo cáo chính: [`docs/david_hunter_v5/BAO_CAO_V5_00.md`](../../docs/david_hunter_v5/BAO_CAO_V5_00.md).

Dữ liệu dùng:
- tick thật Exness XAUUSDm 01–12/01/2026 (`EA-PRO/data/tick/...zip.part001`, 2,73 triệu tick);
- nến M1 01/01–27/09/2026 (`EA-PRO/data/backtest_mt5/.../nen_M1.csv`).

Đặt biến môi trường `DH_M1` (đường dẫn nến M1) và `DH_TICKS` (file npz tick) nếu repo EA-PRO không nằm cạnh repo này.

| Script | Câu hỏi | Kết quả chính |
|---|---|---|
| `load_ticks.py` | Giải nén zip tick MT5 (chia phần, thiếu phần cuối vẫn đọc được) → npz | 2.733.021 tick, 01/01 23:05 → 12/01 13:03 |
| `tick_stats.py` | Hoạt động, spread và tự tương quan lợi suất theo khung 1 giây – 15 phút | Spread cố định 0,16; tự tương quan hơi âm ở mọi khung; sau cú đi mạnh không có lợi thế nào đủ bù spread |
| `m1_momentum.py` | Động lượng/hồi quy khung 15 phút – 4 giờ, T1–T6 so với T7–T9 | Tương quan ≈ 0; dấu đổi giữa hai nửa |
| `gia_thuyet_d1.py` | Lệnh cùng chiều xu hướng ngày có tốt hơn không (3 định nghĩa, chốt trước) | Không khác biệt ổn định |
| `troi_theo_gio.py` | Trôi giá theo giờ/phiên | Không giờ nào có ý nghĩa thống kê ổn định |
| `regime_dist.py` | Phân bố ER M5, độ dốc EMA50 H1, ATR M5 để đặt ngưỡng trạng thái theo tần suất | Độ dốc 0,05 và ER 0,30 → xu hướng ~23% thời gian |
| `soc_gia.py` | Tần suất biến động 5 giây để hiệu chỉnh ngưỡng sốc giá | ≥ 4,0 hoặc ≥ 10 lần RMS 1 giờ → ~1–3 sự kiện/ngày |
| `gap_stats.py` | Gap cuối tuần, giờ nghỉ hằng ngày, biên độ nến M1 | Gap cuối tuần trung vị 14,1, lớn nhất 98,0 |
| `phan_tich_lenh_ao.py` | Lệnh ảo của EA (mọi tín hiệu): theo PP, nhóm điểm, hướng, trạng thái, hai nửa | Không nhóm nào dương ổn định |

`ket_qua/`: kết quả các lượt chạy bộ giả lập `tools/mt5sim` trên bản EA cuối. Mỗi thư mục gồm:

| File | Nội dung |
|---|---|
| `MO_TA.txt` | Mô tả lượt chạy |
| `bao_cao_mt5sim.txt` | Báo cáo tổng và kiểm toán rủi ro của bộ giả lập |
| `lenh_mt5sim.csv` | Từng vị thế |
| `ngay.csv` | Lỗ trong ngày |
| `ket_qua_ea.csv` | Bảng kết quả do EA tự xuất |

Đây là mô phỏng, **không phải backtest MT5**.
