# Danh mục 2 EA trên BTCUSDc – kết quả và hướng dẫn

Ngày: 28/09/2026 · Mã: `research/btc/run_portfolio.py`, `verify_ea_donch.py`
EA: `MQL5/Experts/BTC_MOM_M15_H1.mq5` + `MQL5/Experts/BTC_DONCH_H1_TRAIL.mq5`
(bản dùng cho Strategy Tester: `*_TEST.mq5`)

> **Tóm tắt:** Ghép MOM-M15-H1 với một chiến lược theo xu hướng H1 (Donchian 55 + trailing stop), mỗi
> chiến lược chịu một nửa mức rủi ro. Kết quả: **tỷ lệ lãi/sụt vốn tăng từ 0,95 lên 1,55** và **năm nào cũng
> có lãi**. Lý do: hai chiến lược thắng vào những giai đoạn khác nhau (tương quan R theo ngày chỉ 0,37).
> ⚠️ Bằng chứng ở mức **trung bình–yếu**: dữ liệu BTC đã được dùng qua 2 vòng nghiên cứu, và chiến lược H1
> khi đứng một mình **không** qua được tập xác thực (PF 1,07). Cần demo để xác nhận.

## 1. Hai chiến lược

| | A: MOM-M15-H1 (vòng 1) | B: Donchian H1 + trailing (vòng 2) |
|---|---|---|
| Tín hiệu | Nến M15 dịch chuyển mạnh ≥ 2 ATR, phá đỉnh/đáy 20 nến, cùng chiều EMA50/200 M15 và xu hướng H1 | Nến H1 đóng vượt đỉnh/đáy 55 nến H1, cùng chiều EMA50/EMA200 H1 |
| Thoát | SL 2 ATR, TP 2R, tối đa 12 giờ | SL ban đầu 2 ATR(H1), trailing 2 ATR, không TP, tối đa 8 ngày |
| Win % / TB thắng / TB thua | 39% / +1,88R / −0,97R | 40% / +1,08R / −0,58R |
| Giữ lệnh trung bình | ~3 giờ | ~7 giờ (24% số lệnh qua đêm) |
| Magic | 20260928 | 20260929 |

Tham số của B được chọn chỉ trên tập nghiên cứu, theo cùng luật với các vòng trước (t-stat cao nhất).

## 2. Kết quả (spread 10$, lãi kép) ✅

| Giai đoạn | A một mình @1% | B một mình @1% | **A+B @0,5% mỗi EA** |
|---|---|---|---|
| Nghiên cứu (2023 → 03/2025) | +23,9% · DD 19,9% | +40,9% · DD 8,6% | +33,7% · DD 10,3% |
| Xác thực (04 → 12/2025) | +26,6% · DD 6,0% | +2,6% · DD 7,4% | +14,4% · DD 5,4% |
| **Kiểm tra cuối (01 → 09/2026)** | +21,6% · DD 13,0% | +5,4% · DD 9,1% | **+13,8% · DD 9,5%** |
| **Toàn bộ 3,7 năm** | 19%/năm · DD 19,9% | 12%/năm · DD 9,5% | **16%/năm · DD 10,3%** |
| Lãi/năm ÷ DD | 0,95 | 1,26 | **1,55** |

**Theo năm:**

| Năm | A @1% | B @1% | A+B @0,5% mỗi EA |
|---|---|---|---|
| 2023 | +0,2% | +27,2% | **+13,5%** |
| 2024 | +14,3% | +9,9% | **+12,7%** |
| 2025 | +37,0% | +3,4% | **+19,6%** |
| 2026 (đến 28/09) | +21,6% | +5,4% | **+13,8%** |

## 3. Chọn mức rủi ro

| Rủi ro mỗi EA | Lãi TB/năm | DD thực tế | DD Monte Carlo (trung vị / 5% xấu nhất) | 9 tháng 2026 |
|---|---|---|---|---|
| **0,5% (mặc định)** | ~16% | 10% | 10% / 16% | +13,8% |
| 0,75% | ~24% | 15% | 15% / 23% | +20,9% |
| 1,0% | ~33% | 20% | 20% / 30% | +28,2% |

Monte Carlo ở đây xáo ngẫu nhiên thứ tự **các tháng**, để giữ nguyên việc hai EA có thể mở lệnh cùng lúc.

## 4. Kiểm tra EA B ✅

- Logic tín hiệu của `BTC_DONCH_H1_TRAIL.mq5` trùng với bản nghiên cứu **922/922** tín hiệu H1 (`verify_ea_donch.py`).
- Trailing stop được dời sau mỗi nến M1 đóng, chỉ theo hướng có lợi, giống engine nghiên cứu. Khoảng cách
  trailing được lưu trong Global Variables nên không mất khi khởi động lại terminal.
- Phí swap: kể cả khi swap là 0,05% giá trị lệnh mỗi đêm, PF của B chỉ giảm từ 1,26 xuống 1,23.
- Chưa biên dịch được (môi trường nghiên cứu không có MetaTrader).

**Kết quả Strategy Tester mong đợi cho `BTC_DONCH_H1_TRAIL_TEST.mq5`** (BTCUSDc, chạy trên chart **H1**,
real ticks, nạp 1.000.000 USC):

| Khoảng ngày | Lệnh | Win % | PF | Lãi @1% | DD |
|---|---|---|---|---|---|
| 2025.12.28 → 2026.09.28 | ~101 | ~40% | ~1,15 | ~+5% | ~9% |
| 2023.03.01 → 2026.09.28 | ~490 | ~40% | ~1,19 | ~+37% | ~11% |

## 5. Chạy demo cả hai EA

1. Biên dịch 2 file bản chính (F7), không dùng bản `_TEST`.
2. Mở **2 chart BTCUSDc**: gắn `BTC_MOM_M15_H1` vào chart **M15**, và `BTC_DONCH_H1_TRAIL` vào chart **H1**.
   Hai EA dùng magic khác nhau nên không đụng lệnh của nhau (tài khoản phải là **Hedge**).
3. Giữ rủi ro mặc định 0,5% cho mỗi EA. Chỉ tăng lên 0,75% sau ít nhất 2–3 tháng demo có kết quả khớp với backtest.
4. Mỗi EA ghi log riêng: `MOM15H1_BTCUSDc_20260928.csv` và `DONCHH1_BTCUSDc_20260929.csv`.

## 6. Việc chưa làm được và lý do

- **Tìm chiến lược trên ETH/Vàng để đa dạng hóa thêm:** mạng của môi trường nghiên cứu chặn các nguồn dữ liệu
  công khai (Binance, Dukascopy). Cần xuất **XAUUSDc** và **ETHUSDc** M1 từ MT5 (giống lần xuất BTC), hoặc mở
  quyền mạng cho môi trường.
- **Demo** và **log David Hunter** cần bạn thực hiện.
