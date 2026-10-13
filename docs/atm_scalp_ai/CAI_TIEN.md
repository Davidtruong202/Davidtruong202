# ATM SCALP AI (bản sao) — backtest và thử cải tiến

Backtest quy tắc bản sao (8 điều kiện, SL 3×ATR, TP 1R/2R/3R, sau TP1 dời SL về entry, chốt 1/3 ở mỗi TP)
bằng `research/atm_scalp_ai/bt_clone.py` / `bt_var.py`. Kết quả tính theo R/lệnh; "sau phí" trừ spread
(M5 XAUUSDc 0.24, M1 XAUUSDm 0.16). Lệnh vào tại close, SL và TP cùng chạm trong 1 nến tính là SL.
Mỗi bộ dữ liệu chia đôi theo thời gian: nửa đầu / nửa sau.

## Gốc

| Dữ liệu | Lệnh | WR (chạm TP1) | R/lệnh nửa đầu → nửa sau (sau phí) |
|---|---|---|---|
| M5 XAUUSDc, 1 năm | 1 181 | 50.8% | +0.061 → +0.006 |
| M1 XAUUSDm, 2 năm | 11 001 | 50.0% | −0.048 → +0.004 |

WR ≈ 50% khớp bảng thống kê của chỉ báo gốc (50–58%) → bản sao đúng; lợi thế rất mỏng, M1 gần như bị
spread ăn hết.

## Thử cải tiến

| Cách | Kết quả |
|---|---|
| SL hẹp hơn (2×, 1.5× ATR) | WR vẫn ≈ 50% (TP co theo SL), số lệnh tăng, sau phí **tệ hơn** → không nên |
| Lọc ADX, độ xa EMA9, thân nến, độ sâu nhịp hồi, tuổi xu hướng | Đẹp ở nửa đầu, **mất ở nửa sau** → không tin được |
| Tránh giờ 07–12 (server) | Kém ở cả 2 nửa, cả M1 và M5 → bỏ khung giờ này có ích nhẹ |
| **Chỉ giờ 00–06 (server)** | Tốt ở cả 2 nửa, cả M1 và M5 |
| Xu hướng khung lớn cùng chiều (M5→H1, M1→M15, EMA21>EMA55) | M1 ổn định cả 2 nửa; M5 không ổn định |
| **Giờ 00–06 + khung lớn cùng chiều** | M5: +0.124 → +0.086 R/lệnh sau phí (288 lệnh/năm); M1: +0.051 → +0.055 (1 994 lệnh/2 năm) |

Lưu ý:
- WR gần như không tăng (51–53%); phần cải thiện đến từ nhiều lệnh chạy tới TP2/TP3 hơn.
- Khung giờ 00–06 được chọn sau khi đã xem bảng theo giờ của cả dữ liệu → có thiên lệch chọn lựa; cần chạy
  thử tiếp (forward/demo) trước khi tin.
- Chưa tính trượt giá, phí hoa hồng; tài khoản cent spread có thể khác.

## Dùng trong chỉ báo `ATM_Scalp_Clone` (bản 0.20)

Hai bộ lọc trên có trong [`ATM_Scalp_Clone.mq5`](../../MQL5/Indicators/ATM_Clone/ATM_Scalp_Clone.mq5) dưới dạng
tùy chọn. Chỉ báo chỉ vẽ, không đặt lệnh.

| Input | Mặc định | Ý nghĩa |
|---|---|---|
| `InpHourFilter`, `InpHourStart`, `InpHourEnd` | true, 0, 7 | Chỉ nhận tín hiệu khi nến mở trong giờ server [0, 7), tức 00:00–06:59 |
| `InpHtfFilter`, `InpHtf` | true, CURRENT | Khung lớn phải cùng chiều (EMA21 vs EMA55, nến khung lớn đã đóng). CURRENT tự chọn: M1–M3 → M15, M4–M10 → H1, M12–M30 → H4, H1 trở lên → D1 |
| `InpShowFiltered` | true | Tín hiệu bị lọc vẽ mũi tên xám, không có đường ENTRY/SL/TP |
| `InpSpreadCost` | 0 | Spread trừ vào thống kê (đơn vị giá); 0 = spread hiện tại |
| `InpAlert` | true | Alert khi có tín hiệu mới đã qua lọc |

Khi gắn lên chart, tab Experts in 2 dòng "Lenh ao": KHONG loc và CO loc (số lệnh, WR(TP1), R/lệnh trước và sau
spread, tổng R) trên lịch sử đang có. Phần so sánh với chỉ báo gốc vẫn dùng bản KHÔNG lọc.
