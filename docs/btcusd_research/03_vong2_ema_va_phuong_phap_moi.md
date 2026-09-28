# Vòng 2 – EMA và các phương pháp mới trên BTCUSDc

Ngày: 28/09/2026 · Mã: `research/btc/strategies2.py`, `run_round2.py`, `run_final2.py`
Quy trình giữ nguyên vòng 1: cùng cách chia 60/20/20, cùng luật chọn tham số (t-stat trên tập nghiên cứu)
và luật vào vòng cuối (PF nghiên cứu ≥ 1,10, PF xác thực ≥ 1,20, R xác thực > 0, ≥ 30 lệnh).

> **Kết luận:** Không có phương pháp mới nào dùng được. Ứng viên EMA duy nhất lọt qua tập xác thực đã
> **thua trên tập kiểm tra cuối (PF 0,83)** và **thua trong walk-forward (PF 0,84)** → **loại**.
> **MOM-M15-H1 (vòng 1) vẫn là ứng viên duy nhất.**

## 1. Những gì đã thử

| Mã | Phương pháp | Khung tín hiệu |
|---|---|---|
| E1_CROSS | Giao cắt EMA nhanh/chậm (9/20/50 × 21/50/200) | M5, M15, H1 |
| E2_CROSS_H1 | E1 + chỉ vào lệnh cùng chiều xu hướng H1 (nến H1 đã đóng: EMA50/EMA200, ADX ≥ 20) | M5, M15 |
| N1_NYORB | Phá vùng giá 09:30–10:30 giờ New York (có tính giờ mùa hè), 1 lệnh/ngày | M5, M15 |
| N2_PDBO | Phá đỉnh/đáy ngày hôm trước, có/không lọc EMA50/200 | M5, M15, H1 |
| N3_DONCH | Phá kênh Donchian 55 nến + lọc EMA50/200 | M5, M15, H1 |

Hai kiểu thoát lệnh cho mỗi phương pháp: **cố định** (SL 1–2 ATR, TP 1–3R) và **trailing stop mới**
(SL ban đầu 2–3 ATR, trailing 2–4 ATR, không TP, giữ tối đa 192 nến). Trailing chỉ được dời sau khi nến M1
đóng (không nhìn trước). Đã kiểm tra: kết quả vòng 1 giữ nguyên, lệnh ngẫu nhiên với trailing và spread 0 cho ≈ 0R.

M1 không thử lại vì vòng 1 đã cho thấy chi phí lớn hơn mọi lợi thế ở khung này.

## 2. Kết quả trên tập nghiên cứu và tập xác thực (tóm tắt, chi tiết: `results/round2_selected_dev_val.csv`)

| Nhóm | Nghiên cứu (2023 → 03/2025) | Xác thực (04 → 12/2025) | Nhận xét |
|---|---|---|---|
| Mọi phương pháp trên **M5** | PF 0,75–1,10 | PF 0,76–1,19 | Không có lợi thế ổn định |
| NY Opening Range (M5/M15) | PF 0,91–1,10 | PF 0,76–1,09 | Không có lợi thế |
| Phá đỉnh/đáy ngày (M5/M15) | PF 0,91–1,06 | PF 0,92–1,17 | Không có lợi thế |
| **Theo xu hướng trên H1** (EMA cross, Donchian, phá đỉnh/đáy ngày, có trailing) | **PF 1,31–1,47**, 60–100% cấu hình dương | **PF 0,99–1,08** | Rất tốt khi BTC tăng mạnh (2023–2024), gần như hòa vốn sau đó |
| **EMA20/50 cắt nhau, M15 + lọc H1 + trailing** (spread 10$) | PF 1,15 (330 lệnh) | **PF 1,43** (121 lệnh) | **Ứng viên duy nhất** |

## 3. Tập kiểm tra cuối và walk-forward của ứng viên EMA ❌

Cấu hình đã chốt: EMA20 cắt EMA50 (M15), cùng chiều xu hướng H1, SL ban đầu 3 ATR, trailing 4 ATR,
giữ tối đa 48 giờ.

| Tập | Lệnh | Win % | PF | R TB | Lãi | Max DD |
|---|---|---|---|---|---|---|
| Nghiên cứu | 330 | 35,8 | 1,15 | +0,074 | +23,2% | 12,5% |
| Xác thực | 121 | 42,1 | 1,43 | +0,189 | +24,0% | 9,5% |
| **KIỂM TRA CUỐI** | **113** | **28,3** | **0,83** | **−0,092** | **−10,6%** | **20,8%** |
| Walk-forward (329 lệnh ngoài mẫu) | 329 | 31,6 | **0,84** | −0,076 | **−24,0%** | 29,2% |

Theo năm: 2023 PF 1,14 · 2024 1,19 · 2025 1,32 · **2026 0,83**. Chỉ cần spread 30$ (không trượt giá)
thì toàn giai đoạn đã hết lợi nhuận (PF 0,99).

**Bài học:** tập xác thực có PF 1,43 nhưng tập kiểm tra cuối lại thua. Đây đúng là trường hợp mà quy trình
chia dữ liệu được thiết kế để phát hiện. Nếu chỉ nhìn giai đoạn 2023–2025, EMA trông rất hứa hẹn.

⚠️ Lưu ý về quy trình: tập kiểm tra cuối đã được mở một lần ở vòng 1 (cho MOM-M15-H1). Với EMA, tập này vẫn
không được dùng để chọn tham số, nhưng không còn "sạch" tuyệt đối. Kết quả âm thì không bị ảnh hưởng bởi
vấn đề này. Kết quả dương về sau sẽ cần demo để xác nhận.

## 4. So sánh các ứng viên

| | MOM-M15-H1 (vòng 1) | EMA20/50-M15-H1 (vòng 2) |
|---|---|---|
| Kiểm tra cuối | **PF 1,28, +21,6%** | PF 0,83, −10,6% |
| Walk-forward | **PF 1,19, +62%**, 7/10 quý dương | PF 0,84, −24%, 5/10 quý dương |
| Toàn giai đoạn | PF 1,22 | PF 1,13 |
| Chịu spread 30$ | PF 1,07 | PF 0,99 |
| Kết luận | **Giữ, chạy demo** | **Loại** |

## 5. Hướng tiếp theo đề xuất

1. **Không tối ưu thêm trên dữ liệu 2023–2026.** Đã thử khoảng 120 tổ hợp qua 2 vòng. Thử thêm nhiều nữa thì
   xác suất tìm ra một chiến lược "đẹp nhờ may mắn" càng cao.
2. **Demo MOM-M15-H1** là bước kiểm chứng tiếp theo, trên dữ liệu thật chưa từng dùng.
3. Nếu muốn nghiên cứu thêm, hướng có cơ sở nhất là **bộ lọc trạng thái thị trường cho nhóm theo xu hướng H1**
   (nhóm này rất mạnh khi BTC có xu hướng rõ và hòa vốn khi đi ngang). Nhưng bộ lọc đó phải được kiểm chứng
   bằng dữ liệu mới, chưa từng dùng, chẳng hạn các tháng demo tiếp theo.
4. Log thật của David Hunter (`tradelog_*.csv`) vẫn là nguồn ý tưởng tốt nhất mà chưa khai thác được.
