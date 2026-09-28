# Kết quả chạy thử công cụ trên BTCUSDc: chỉ để kiểm tra code

> **Không phải bằng chứng về XAUUSD.** Đây là dữ liệu BTCUSDc (tài khoản cent, Exness) có sẵn
> trong repo, dùng để xác nhận backtester chạy đúng quy trình: không nhìn trước, có chi phí,
> tách IS/OOS và làm ablation. Thiết lập: spread theo từng nến M1, commission 0, slippage 0,
> phiên 07–10 và 12–16 UTC (GMT offset 0), RR 2, rủi ro tính theo R.
>
> Lệnh tạo lại: `python3 fractal_cisd_bt.py --data ../../BTCUSDc_M1_20*.zip --point 0.01 --contract 1 --commission 0 --gmt-offset 0 --out btc_pipeline_check.json --trades-csv btc_pipeline_trades_H1_M5.csv`

Dữ liệu 2023-01-01 00:00:00 → 2026-09-28 00:00:00; tách IS/OOS tại 2025-03-30 14:24:00

### Cặp khung thời gian (phút HTF->LTF)

| Biến thể | Tập | Lệnh | Net R | MaxDD R | Win % | PF | Exp R | RR thực | Chuỗi thua |
|---|---|---|---|---|---|---|---|---|---|
| 15->1 | IS | 290 | -43.84 | 45.15 | 37.6 | 0.7 | -0.151 | 1.16 | 9 |
| 15->1 | OOS | 576 | -56.91 | 64.2 | 37.0 | 0.82 | -0.099 | 1.39 | 13 |
| 60->5 | IS | 231 | -49.33 | 52.81 | 35.1 | 0.61 | -0.214 | 1.13 | 10 |
| 60->5 | OOS | 210 | -19.17 | 33.0 | 35.7 | 0.84 | -0.091 | 1.51 | 8 |
| 240->15 | IS | 65 | -10.77 | 12.77 | 32.3 | 0.73 | -0.166 | 1.53 | 8 |
| 240->15 | OOS | 41 | -6.12 | 15.22 | 29.3 | 0.76 | -0.149 | 1.83 | 7 |

### Ablation trên H1->M5 (mỗi dòng đổi 1 yếu tố so với mặc định)

| Biến thể | Tập | Lệnh | Net R | MaxDD R | Win % | PF | Exp R | RR thực | Chuỗi thua |
|---|---|---|---|---|---|---|---|---|---|
| mac_dinh(fractal,phien,2R) | IS | 231 | -49.33 | 52.81 | 35.1 | 0.61 | -0.214 | 1.13 | 10 |
| mac_dinh(fractal,phien,2R) | OOS | 210 | -19.17 | 33.0 | 35.7 | 0.84 | -0.091 | 1.51 | 8 |
| doi_chung_khong_HTF_sweep | IS | 1731 | -174.84 | 192.1 | 36.7 | 0.81 | -0.101 | 1.4 | 11 |
| doi_chung_khong_HTF_sweep | OOS | 1548 | -36.5 | 89.79 | 38.6 | 0.96 | -0.024 | 1.53 | 17 |
| liq=C1_thay_fractal | IS | 829 | -135.13 | 137.13 | 34.3 | 0.72 | -0.163 | 1.37 | 18 |
| liq=C1_thay_fractal | OOS | 789 | -47.51 | 92.4 | 37.1 | 0.89 | -0.06 | 1.51 | 10 |
| them_FVG | IS | 31 | -4.98 | 7.27 | 45.2 | 0.6 | -0.161 | 0.73 | 3 |
| them_FVG | OOS | 25 | -2.5 | 3.51 | 32.0 | 0.81 | -0.1 | 1.73 | 4 |
| bo_loc_phien | IS | 580 | -83.47 | 88.62 | 38.8 | 0.71 | -0.144 | 1.12 | 18 |
| bo_loc_phien | OOS | 539 | -85.06 | 91.92 | 34.9 | 0.73 | -0.158 | 1.36 | 11 |
| TP=cuc_tri_C2(minRR1.5) | IS | 34 | -12.07 | 15.51 | 32.4 | 0.45 | -0.355 | 0.95 | 15 |
| TP=cuc_tri_C2(minRR1.5) | OOS | 46 | 7.48 | 10.94 | 34.8 | 1.27 | 0.163 | 2.38 | 9 |
| cua_so_2_nen_HTF | IS | 278 | -63.48 | 65.65 | 31.7 | 0.63 | -0.228 | 1.35 | 14 |
| cua_so_2_nen_HTF | OOS | 253 | -30.36 | 48.78 | 31.6 | 0.81 | -0.12 | 1.76 | 12 |

### Stress spread trên H1->M5

| Biến thể | Tập | Lệnh | Net R | MaxDD R | Win % | PF | Exp R | RR thực | Chuỗi thua |
|---|---|---|---|---|---|---|---|---|---|
| x1.0 | IS | 231 | -49.33 | 52.81 | 35.1 | 0.61 | -0.214 | 1.13 | 10 |
| x1.0 | OOS | 210 | -19.17 | 33.0 | 35.7 | 0.84 | -0.091 | 1.51 | 8 |
| x1.5 | IS | 171 | -43.93 | 47.18 | 35.1 | 0.54 | -0.257 | 1.0 | 9 |
| x1.5 | OOS | 191 | -26.06 | 33.2 | 34.0 | 0.76 | -0.136 | 1.48 | 11 |
| x2.0 | IS | 121 | -34.63 | 39.49 | 33.1 | 0.47 | -0.286 | 0.96 | 9 |
| x2.0 | OOS | 176 | -22.61 | 29.5 | 34.7 | 0.78 | -0.128 | 1.47 | 10 |
| x3.0 | IS | 51 | -14.86 | 15.4 | 31.4 | 0.42 | -0.291 | 0.91 | 7 |
| x3.0 | OOS | 136 | -14.22 | 18.33 | 35.3 | 0.81 | -0.105 | 1.49 | 9 |

## Nhận xét (chỉ cho BTCUSDc)

- **Mọi biến thể đều âm trên IS.** Cặp H1→M5 mặc định có expectancy −0,21R (IS) và −0,09R (OOS). Trên BTCUSDc, chiến lược **không có lợi thế** sau chi phí.
- Biến thể mặc định còn **kém hơn đối chứng không có điều kiện quét HTF** (IS −0,21R so với −0,10R). Như vậy, trên BTC, giả thuyết H1 ("bối cảnh C2 quét thanh khoản có giá trị") **không được ủng hộ**.
- Spread chiếm trung bình khoảng 9,5% khoảng SL (từ 1% đến 20%). Riêng chi phí này đã làm mất khoảng −0,1R mỗi lệnh.
- RR thực tế (1,1–1,5) thấp hơn nhiều so với RR mục tiêu 2 vì khoảng 35% số lệnh bị đóng theo giờ. Win rate khoảng 35% thấp hơn ngưỡng hoà vốn ~40% của lệnh RR 1,5.
- Biến thể "TP = cực trị C2" dương trên OOS (+0,16R) nhưng âm trên IS (−0,36R), và chỉ có 34/46 lệnh. Đây là dấu hiệu nhiễu, **không** phải lợi thế. Không chọn tham số theo kết quả OOS.
- Cặp khung, bộ lọc phiên và FVG đều không có biến thể nào dương trên cả IS lẫn OOS.
- Kết luận nghiên cứu: logic này cần được kiểm lại trên **dữ liệu XAUUSD thật**. Nếu vàng cũng cho kết quả tương tự, nên dừng hoặc thiết kế lại thay vì tối ưu tham số.
