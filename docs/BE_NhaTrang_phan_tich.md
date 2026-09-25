# Phân tích bot "BE Nha Trang" (XAUUSD) – cập nhật 23/09/2026

Nguồn dữ liệu: tài khoản Passview Exness 425402441 (TradeLogger), ảnh lịch sử
lệnh, tin nhắn của admin. Mẫu: **10 tín hiệu / 12 vị thế, 22/09 13:18 → 23/09 10:50**
(tài khoản bắt đầu chạy bot từ 22/09; trước đó chỉ có nạp/rút).

Mức độ chắc chắn: ✅ chắc chắn · 🟡 khá chắc · ❓ giả thuyết, cần thêm dữ liệu.

## 1. Tổng quan
- EA đa chiến lược, comment `BE Nha Trang-<SETUP>`; lệnh tầng 2 có hậu tố `-L2`. ✅
- 7 setup: ENG, RSI, BRK, PVT, SMC, EMA, LQ. ✅
- 2 bộ cấu hình: magic **79** (lướt, TP 10$) và magic **78** (ăn dài, TP 30$). SMC xuất hiện ở cả hai. ✅
- Có thể giữ BUY và SELL cùng lúc (các setup độc lập) → cần tài khoản Hedge. ✅
- Lệnh vào đúng giây :00/:01, phút chia hết cho 6 (9/10 lệnh) → quét tín hiệu chu kỳ 6 phút? ❓

## 2. Quản lý vốn
- Lot = tiền rủi ro / (khoảng SL × giá trị 1 lot), làm tròn xuống. ✅
- Admin: "1% thì max 30u, 2% thì max 60u; 1 lệnh 20u 1 lệnh 10u" (tk 2000$). ✅
- Magic 79: rủi ro lệnh chính ≈ 40$ (2% của ~2000$) – khớp công thức cho cả 5 lệnh. ✅
- Magic 78: rủi ro lệnh chính ≈ 53–59$. 🟡
- Tầng 2 dùng **cùng lot** với lệnh chính; SL chung → rủi ro tầng 2 nhỏ hơn. ✅

## 3. Vào lệnh 2 tầng
| | Magic 79 | Magic 78 |
|---|---|---|
| Lệnh chính | market | market |
| Tầng 2 | Limit cách **1.8$** (cùng hướng có lợi) | Limit cách **5$** |
| SL tầng 2 | chung SL lệnh chính | chung SL |
| TP tầng 2 | giá tầng 2 ± 10$ | giá tầng 2 ± 30$ |
| Đặt tầng 2 | 0–2 giây sau lệnh chính | 0–2 giây sau |
| Huỷ tầng 2 | khi lệnh chính chốt phần / BE / SL | như trái |
✅

## 4. Stop loss
- Magic 79 (RSI, PVT, LQ, BRK): **SL = đỉnh/đáy gần nhất (trong ngày / 20 nến M5) ± 1.50$**
  (4 lệnh khớp đúng 1.50; BRK = +0.50). ✅
- Magic 78 (EMA, SMC): **SL ≈ 2.5–2.6 × ATR(14) M5** (2.44 / 2.60 / 2.62 / 2.59). 🟡
- ENG: SL ≈ đỉnh 20 nến + 1.78$. ❓

## 5. Chốt lời & quản lý lệnh
**Magic 79 (TP +10$):** ✅
1. Lãi +5$ → chốt 50% khối lượng, dời SL về hoà vốn (±0.1).
2. Trailing SL cách giá ~5$.
3. Phần còn lại chạm TP +10$ (hoặc SL trailing).

**Magic 78 (TP +30$):** 🟡
- EMA: chưa dời BE khi lãi 7.7$; khi lãi ~+10$ → bot chốt **50%** (làm tròn lên), cùng giây
  huỷ lệnh chờ tầng 2 và kéo SL vào vùng lãi; phần còn lại trailing cách đỉnh/đáy ~5$.
  (Lệnh 10:50: lần chốt 0.04 lúc 11:33 là **chủ tài khoản đóng tay trên điện thoại**
  – DEAL_REASON_MOBILE, magic 0 – không phải bot; bot chốt 0.02/0.03 lúc 11:36:55.)
- ⚠️ Chủ tài khoản có can thiệp tay → khi suy luận phải bỏ các thao tác magic 0 / MOBILE.
- SMC: dời SL về giá vào +0.32$ khá sớm (lãi ~3–5$).
- TP 30$ gần như chỉ là trần; lệnh thường đóng bằng chốt phần + trailing.

## 6. Điều kiện vào lệnh từng setup ❓ (1–3 mẫu mỗi setup)
Phân vị so với 706 nến M5 (99% = cực đoan cao).
| Setup | Hướng | Bối cảnh lúc vào (nến M5 vừa đóng) |
|---|---|---|
| RSI | SELL | RSI 77 (99%), Stoch 92 (95%), %B 0.94, giá > EMA20 2.8 ATR (97%), đỉnh ngày (99%) |
| PVT | BUY | RSI 22 (0%), Stoch 4 (1%), vừa phá đáy 20 nến, giá < EMA50 4.5 ATR, đáy ngày |
| LQ | BUY | vừa phá đáy 20 nến, %B < 0 (2%), sát đáy ngày (1%), nến đỏ dài −0.9 ATR |
| EMA ×2 | SELL | EMA20<50<200, RSI ~41, Stoch 66–69 (vừa hồi), nến vừa đóng đỏ −0.5..−0.8 ATR, dưới EMA20 |
| SMC ×3 | SELL | dưới EMA50 3–3.7 ATR, RSI 30–36, sát đáy ngày, nến trước xanh nhỏ (hồi nhẹ) |
| ENG | SELL | RSI 64, 3 nến xanh liên tiếp, vùng cao ngày (84%) |
| BRK | SELL | sát đỉnh ngày (95%), nến đỏ nhỏ – có thể bán phá vỡ giả |

Nhóm: đảo chiều tại cực trị (RSI, PVT, LQ) · thuận xu hướng (EMA, SMC) · mô hình/phá vỡ (ENG, BRK).

Bối cảnh khung H1 lúc vào lệnh (RSI H1 / giá so EMA50 H1 theo ATR H1 / độ dốc EMA50 H1):
| Lệnh | H1 | Cùng/ngược xu hướng H1 | Kết quả |
|---|---|---|---|
| ENG SELL | 47.6 / −0.50 / giảm | cùng | + |
| RSI SELL | 56.5 / +0.47 / phẳng | trung tính | + |
| BRK SELL | 59.2 / +0.91 / tăng | **ngược** | − |
| PVT BUY | 47.6 / −0.32 / tăng nhẹ | trung tính | + |
| SMC SELL 02:30 | 47.6 / −0.32 / tăng nhẹ | trung tính | + nhỏ |
| EMA SELL 07:00 | 43.7 / −1.02 / giảm | cùng | + |
| SMC SELL 07:42 | 43.7 / −1.02 / giảm | cùng | + nhỏ |
| LQ BUY | 38.2 / −2.09 / giảm | **ngược** | − |
| SMC SELL 09:42 | 38.2 / −2.09 / giảm | cùng | + nhỏ |
| EMA SELL 10:50 | 36.5 / −2.36 / giảm | cùng | + |
❓ Cả 2 lệnh thua đều **ngược xu hướng H1** → ứng viên bộ lọc H1 (cần thêm mẫu).

## 7. Kết quả quan sát
| Tín hiệu | Kết quả |
|---|---|
| ENG SELL 22/09 13:18 | +24.72 |
| RSI SELL 22/09 19:54 | +60.08 |
| BRK SELL 22/09 23:18 (+L2) | −55.16 (giật quét cả 2 tầng trong 4 giây) |
| PVT BUY 23/09 02:24 (+L2) | +121.21 |
| SMC SELL 23/09 02:30 | +5.70 |
| EMA SELL 23/09 07:00 | +52.02 |
| SMC SELL 23/09 07:42 | +1.91 |
| LQ BUY 23/09 09:36 (+L2) | −54.64 |
| SMC SELL 23/09 09:42 | +1.92 |
| EMA SELL 23/09 10:50 | +81.29 |
Tổng ≈ +249$ trong ~1.5 ngày trên ~2000$. Admin thừa nhận có chuỗi thua ("xui vào trúng chuỗi thua trước").

## 8. Còn thiếu
- Ngưỡng chính xác của từng setup (RSI > ?, Stoch > ?, khoảng cách EMA...).
- Xu hướng khung H1 (dữ liệu đầu bị ghi nhầm khung M5; đã sửa).
- Ngưỡng dời BE / chốt phần chính xác của magic 78; SL của ENG, BRK.
- Hành vi khi ra tin, phiên Á/Âu/Mỹ, giới hạn số lệnh/ngày, lỗ tối đa/ngày.
Cần ~20–30 lệnh mỗi setup (2–4 tuần dữ liệu).
