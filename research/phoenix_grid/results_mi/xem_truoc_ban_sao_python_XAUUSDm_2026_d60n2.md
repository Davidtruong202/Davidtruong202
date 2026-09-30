# Xem trước logic Shadow Breakout Detection — bản sao Python, XAUUSDm M5, 02/01–27/09/2026

> **Không phải kết quả của EA, không phải backtest giao dịch.** `ban_sao_python_mi.py` chạy lại các công thức nhận
> diện của `PHOENIX_MI_V0_01.mqh` trên nến M5 dựng từ nến M1 XAUUSDm
> (`EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv`).
>
> - Chỉ báo tính theo cách của MT5, nhưng ADX có thể lệch MT5 ở phần khởi tạo.
> - Basket được giả lập ngược mỗi breakout xác nhận (như input `InpGiaLapBasket`).
> - Bản sao chưa có ngữ cảnh Fib / nến, nên không bao giờ có DEF_GIAM_CAP.
> - Cấu hình: điểm xác nhận 60, số nến xác nhận 2, range 48 nến, ADX < 22, range ≤ 6 ATR, giữ hedge 30 phút, cooldown
>   60 phút.


229 file, 52031 nến.

## 1. Thời gian ở mỗi trạng thái (% số nến)

| market_state | pt |
|---|---|
| NORMAL | 92.60 |
| BREAKOUT_CONFIRMED | 4.90 |
| SIDEWAY | 2.10 |
| BREAKOUT_SUSPECTED | 0.20 |
| RECLAIM | 0.10 |

## 2. Các đợt breakout (H = 48 nến, đi tiếp = đóng cách biên ≥ 1 × độ rộng range)

| ket_cuc | danh_gia | so |
|---|---|---|
| HET_HAN | BO_LO | 1 |
| HET_HAN | LOAI_DUNG | 1 |
| THAT_BAI | BO_LO | 2 |
| THAT_BAI | LOAI_DUNG | 12 |
| XAC_NHAN | DI_TIEP | 13 |
| XAC_NHAN | KHONG_DI_TIEP | 28 |

- Xác nhận: 41 đợt; đi tiếp 31.7% (trên 41 đợt đủ 48 nến)
- Thất bại / hết hạn: 16 đợt; loại đúng 81.2% (trên 16 đợt đủ 48 nến)

Chi tiết:

| bat_dau | huong | ket_cuc | so_nen_toi_ket_cuc | diem_xn | danh_gia |
|---|---|---|---|---|---|
| 2026-01-07 16:20 | TANG | XAC_NHAN | 1 | 75.00 | KHONG_DI_TIEP |
| 2026-01-13 12:20 | GIAM | THAT_BAI | 4 | nan | LOAI_DUNG |
| 2026-01-19 15:50 | TANG | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-01-19 17:40 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-01-30 08:30 | GIAM | XAC_NHAN | 1 | 100.00 | DI_TIEP |
| 2026-02-02 23:05 | TANG | XAC_NHAN | 1 | 75.00 | DI_TIEP |
| 2026-02-11 23:00 | TANG | THAT_BAI | 1 | nan | LOAI_DUNG |
| 2026-02-11 23:10 | GIAM | HET_HAN | 11 | nan | LOAI_DUNG |
| 2026-03-11 07:35 | GIAM | THAT_BAI | 3 | nan | LOAI_DUNG |
| 2026-04-21 11:45 | TANG | THAT_BAI | 6 | nan | LOAI_DUNG |
| 2026-04-24 14:05 | TANG | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-04-27 12:40 | GIAM | THAT_BAI | 1 | nan | BO_LO |
| 2026-04-27 13:00 | GIAM | XAC_NHAN | 1 | 80.00 | DI_TIEP |
| 2026-05-05 22:05 | GIAM | XAC_NHAN | 1 | 90.00 | KHONG_DI_TIEP |
| 2026-05-08 13:30 | TANG | XAC_NHAN | 1 | 90.00 | KHONG_DI_TIEP |
| 2026-05-14 03:40 | GIAM | XAC_NHAN | 1 | 90.00 | KHONG_DI_TIEP |
| 2026-05-19 07:55 | TANG | THAT_BAI | 2 | nan | LOAI_DUNG |
| 2026-05-19 13:00 | GIAM | XAC_NHAN | 1 | 100.00 | DI_TIEP |
| 2026-05-20 01:25 | GIAM | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-05-20 07:05 | TANG | XAC_NHAN | 1 | 75.00 | KHONG_DI_TIEP |
| 2026-05-22 05:35 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-05-28 10:05 | TANG | THAT_BAI | 7 | nan | BO_LO |
| 2026-05-28 23:40 | GIAM | THAT_BAI | 3 | nan | LOAI_DUNG |
| 2026-05-29 01:05 | TANG | XAC_NHAN | 1 | 85.00 | DI_TIEP |
| 2026-06-02 00:05 | GIAM | THAT_BAI | 2 | nan | LOAI_DUNG |
| 2026-06-02 00:20 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-06-05 11:50 | TANG | XAC_NHAN | 1 | 80.00 | KHONG_DI_TIEP |
| 2026-06-05 12:15 | TANG | THAT_BAI | 2 | nan | LOAI_DUNG |
| 2026-06-05 12:30 | GIAM | XAC_NHAN | 1 | 85.00 | DI_TIEP |
| 2026-06-07 23:35 | TANG | XAC_NHAN | 2 | 65.00 | KHONG_DI_TIEP |
| 2026-06-12 15:20 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-06-16 12:50 | TANG | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-06-23 13:50 | TANG | XAC_NHAN | 3 | 85.00 | KHONG_DI_TIEP |
| 2026-07-01 06:05 | GIAM | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-07-03 05:45 | GIAM | XAC_NHAN | 1 | 60.00 | KHONG_DI_TIEP |
| 2026-07-08 00:35 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-07-14 01:55 | TANG | XAC_NHAN | 1 | 75.00 | DI_TIEP |
| 2026-07-15 11:40 | TANG | XAC_NHAN | 1 | 80.00 | DI_TIEP |
| 2026-07-24 02:45 | GIAM | XAC_NHAN | 1 | 100.00 | DI_TIEP |
| 2026-07-30 13:35 | TANG | XAC_NHAN | 1 | 85.00 | DI_TIEP |
| 2026-08-03 09:30 | GIAM | HET_HAN | 11 | nan | BO_LO |
| 2026-08-10 13:50 | GIAM | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-08-10 14:30 | TANG | XAC_NHAN | 1 | 65.00 | DI_TIEP |
| 2026-08-11 10:20 | TANG | XAC_NHAN | 1 | 85.00 | DI_TIEP |
| 2026-08-11 15:50 | TANG | XAC_NHAN | 1 | 60.00 | KHONG_DI_TIEP |
| 2026-08-12 16:45 | GIAM | XAC_NHAN | 1 | 75.00 | KHONG_DI_TIEP |
| 2026-08-14 00:25 | GIAM | XAC_NHAN | 1 | 60.00 | DI_TIEP |
| 2026-08-17 06:50 | TANG | XAC_NHAN | 1 | 60.00 | KHONG_DI_TIEP |
| 2026-08-17 07:25 | TANG | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |
| 2026-08-18 13:35 | TANG | THAT_BAI | 2 | nan | LOAI_DUNG |
| 2026-08-24 02:05 | TANG | XAC_NHAN | 1 | 100.00 | KHONG_DI_TIEP |
| 2026-08-24 08:40 | TANG | XAC_NHAN | 1 | 60.00 | KHONG_DI_TIEP |
| 2026-08-26 13:05 | GIAM | THAT_BAI | 7 | nan | LOAI_DUNG |
| 2026-08-31 00:35 | TANG | THAT_BAI | 4 | nan | LOAI_DUNG |
| 2026-09-08 16:05 | GIAM | THAT_BAI | 3 | nan | LOAI_DUNG |
| 2026-09-24 00:55 | TANG | XAC_NHAN | 3 | 85.00 | KHONG_DI_TIEP |
| 2026-09-24 01:55 | GIAM | XAC_NHAN | 1 | 85.00 | KHONG_DI_TIEP |

## 3. Phòng thủ (shadow — quyết định sẽ làm, không có lệnh thật)

| su_kien | so |
|---|---|
| DEF_BAT_DAU | 36 |
| DEF_CAP_2 | 13 |
| DEF_GIAM_CAP | 0 |
| DEF_PHUC_HOI | 40 |
| DEF_TAI_KICH_HOAT | 4 |
| DEF_KET_THUC | 36 |
| DEF_HUY | 0 |
| DEF_CHAN_COOLDOWN | 7 |

- Thời gian mỗi đợt phòng thủ (phút): trung vị 138, lớn nhất 3460
- Bắt đầu lại trong vòng 2 giờ sau khi kết thúc: 6 lần

