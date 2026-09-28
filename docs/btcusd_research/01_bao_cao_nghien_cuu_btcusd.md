# Báo cáo nghiên cứu BTCUSD – Vòng 1

Ngày: 28/09/2026 · Dữ liệu: Exness **BTCUSDc** (tài khoản Cent, Hedge, server GMT+0)
Mã nguồn tái lập: `research/btc/` · Kết quả thô: `research/btc/results/`

> **Kết luận ngắn:** Chưa có phương pháp nào đạt **đủ** bộ tiêu chí (PF mục tiêu 1,5).
> Ứng viên tốt nhất là **Momentum M15 + bộ lọc xu hướng H1**: dương trên cả 3 tập dữ liệu, walk-forward
> và tick data; PF ngoài mẫu khoảng **1,2–1,3**; DD 13–20% ở mức rủi ro 1%/lệnh. Mức này chỉ đủ để
> **chạy demo kiểm chứng**, **chưa đủ để chạy tiền thật**. Các phương pháp đảo chiều (RSI, PVT, ENG,
> Sweep) và mọi thứ trên **M1** đều thua lỗ sau chi phí.

Ký hiệu độ chắc chắn: ✅ tính từ dữ liệu / mã nguồn · 🟡 suy luận · ❓ chưa đủ dữ liệu.

---

## 0. Dữ liệu đã dùng và kiểm tra chất lượng ✅

| Mục | Giá trị |
|---|---|
| Nến M1 | 1.962.122 nến, 01/01/2023 → 28/09/2026 (xuất từ MT5, giá **Bid**) |
| Tick | 2.206.084 tick, 16/08 → 31/08/2026 (bid/ask) |
| Trùng lặp / OHLC sai / giá ≤ 0 | 0 / 0 / 0 |
| Độ phủ thời gian | 99,75% số phút. Thiếu 3 đoạn do khoảng ngày xuất: 31/12/2023 (từ 20:48), 31/12/2024, 31/12/2025. Còn 256 khoảng trống nhỏ (trung vị 4 phút, dài nhất 292 phút ngày 22/11/2025) |
| Giao dịch cuối tuần | Có. Số nến Thứ 7/CN bằng ngày thường → sàn báo giá BTC 24/7 |
| Spread | Tick data: **cố định đúng 10,00$** (100% số tick). Cột spread của nến M1 cũng là 10$ trong cùng giai đoạn → cột spread của nến **đáng tin** |
| Lịch sử spread | Giảm theo từng bậc: ~17–23$ (2023) → 30–64$ (đầu 2024) → 29$ → 21,6$ → 18$ → 14$ → **10$ (từ 06/2026)** |
| Commission / swap | ❓ Chưa có ảnh Specification. Backtest giả định commission = 0 (tài khoản Standard Cent thường chỉ tính spread) và **chưa tính swap** |

### Chia dữ liệu theo thời gian (cố định trước khi chạy)

| Tập | Khoảng | Dùng để |
|---|---|---|
| Nghiên cứu (60%) | 01/01/2023 → 30/03/2025 | Chọn tham số |
| Xác thực (20%) | 30/03/2025 → 28/12/2025 | Loại cấu hình quá khớp |
| **Kiểm tra cuối (20%)** | 28/12/2025 → 28/09/2026 | Chạy **một lần duy nhất** cho cấu hình đã chốt |

---

## Phần A – Giải mã EA David Hunter

**Chưa làm được.** Chưa có `tradelog_*.csv` hoặc mã nguồn của EA (xem `00_kiem_ke_du_lieu.md`).
Vì vậy trong báo cáo này:
- **Không có Baseline chính thức** của David Hunter trên BTC.
- Các chiến lược `H_RSI`, `H_PVT`, `H_EMA`, `H_ENG` chỉ là **giả thuyết mô phỏng** theo bối cảnh vào lệnh
  quan sát được ở bot "BE Nha Trang" (1–3 lệnh/setup). Chúng **không phải** logic gốc, và ngưỡng được dò
  trên tập nghiên cứu. Kết quả xấu của chúng **không chứng minh** EA gốc xấu trên BTC. Nó chỉ cho thấy
  tư duy "đảo chiều tại cực trị" với các ngưỡng hợp lý không có lợi thế trên BTC trong dữ liệu này.

---

## Phần B – So sánh XAUUSD và BTCUSD, và kết quả từng phương pháp

### B.1. Đặc điểm BTCUSDc ✅ (XAUUSD: ❓ cần file `tradelog_bars_XAUUSD_M5.csv` để so sánh bằng số)

| Đặc điểm | BTCUSDc (đo từ dữ liệu) | Ý nghĩa cho EA |
|---|---|---|
| Biến động (ATR14 trung vị 2026) | M1 45$ · M5 110$ · M15 206$ · H1 443$ (≈0,06% / 0,15% / 0,28% / 0,59% giá) | Mọi tham số tính theo $ của vàng (SL +1,5$, TP 10$…) **vô nghĩa** trên BTC → phải dùng bội số ATR |
| Spread / ATR (2026) | **M1 29%** · M5 12% · M15 6% · H1 3% | M1 bị chi phí "ăn" gần hết lợi nhuận |
| Spread / ATR (2023) | M1 98% · M5 40% · M15 22% | Dữ liệu cũ đắt hơn hiện nay rất nhiều |
| Biến động theo giờ (range H1, UTC) | Thấp nhất 04–06h (~0,40%), **cao nhất 13–16h (0,72–0,89%)** khi Mỹ mở cửa | Phiên Mỹ có biên độ gấp đôi phiên Á |
| Cuối tuần | Range H1 T7 0,33%, CN 0,39% so với ~0,60% ngày thường | Cuối tuần yên hơn nhưng vẫn giao dịch |
| Gap M1 | 99,9% số nến có gap < 0,025% | Rủi ro gap thấp vì giao dịch 24/7 |
| Tự tương quan lợi nhuận | M1 −0,028 · M5 −0,010 · M15 +0,001 · H1 −0,016 | Rất gần 0 → thị trường gần hiệu quả, lợi thế (nếu có) rất mỏng |
| Trạng thái (H1) | Trending (ADX≥25) 50% · Ranging (ADX<20) 32% | |

### B.2. Kết quả từng phương pháp ✅

Khung thoát lệnh chung cho mọi chiến lược (để so sánh công bằng phần vào lệnh): SL = {1; 2} × ATR14,
TP = {1; 2; 3} × SL, giữ tối đa 48 nến. Vào lệnh ở giá mở của nến M1 kế tiếp; có spread; nếu SL và TP
cùng chạm trong một nến M1 thì tính là SL. Mỗi dòng dưới đây là cấu hình tốt nhất trên tập nghiên cứu
(xếp theo t-stat), kèm kết quả trên tập xác thực. Tập kiểm tra cuối **chưa được mở** cho các dòng này.

**Chi phí = spread thực tế từng thời điểm (lịch sử):**

| TF | Chiến lược | Nghiên cứu: lệnh / PF / R TB | Xác thực: lệnh / PF / R TB | % cấu hình dương |
|---|---|---|---|---|
| M1 | Tất cả 8 chiến lược | 1.452–34.664 / **0,38–0,60** / −0,30…−0,52 | PF 0,72–0,80 | **0%** |
| M5 | H_RSI | 1214 / 0,80 / −0,13 | 401 / 0,82 / −0,12 | 0% |
| M5 | H_PVT | 357 / 1,00 / 0,00 | 141 / 0,75 / −0,14 | 2% |
| M5 | H_EMA | 5065 / 0,73 / −0,19 | 1668 / 0,82 / −0,12 | 0% |
| M5 | H_ENG | 1724 / 0,78 / −0,14 | 638 / 0,83 / −0,11 | 0% |
| M5 | G1 Trend | 2226 / 0,76 / −0,17 | 771 / 1,04 / +0,03 | 0% |
| M5 | G2 Momentum | 1664 / 0,81 / −0,13 | 530 / 0,97 / −0,02 | 0% |
| M5 | G3 Sweep | 2358 / 0,67 / −0,24 | 848 / 0,95 / −0,03 | 0% |
| M5 | G4 Squeeze | 2604 / 0,70 / −0,22 | 876 / 0,88 / −0,08 | 0% |
| M15 | H_RSI | 485 / 0,77 / −0,16 | 146 / 0,69 / −0,22 | 0% |
| M15 | H_PVT | 153 / 0,98 / −0,01 | 66 / 0,77 / −0,18 | 0% |
| M15 | H_EMA | 2083 / 0,92 / −0,05 | 713 / 0,91 / −0,06 | 0% |
| M15 | H_ENG | 710 / 0,74 / −0,15 | 280 / 0,86 / −0,07 | 0% |
| M15 | **G1 Trend** | 808 / 1,07 / +0,04 | 299 / 0,93 / −0,04 | 22% |
| M15 | **G2 Momentum** | 929 / 1,07 / +0,05 | 297 / 1,02 / +0,01 | 17% |
| M15 | G3 Sweep | 1254 / 0,74 / −0,18 | 423 / 0,84 / −0,11 | 0% |
| M15 | G4 Squeeze | 874 / 0,80 / −0,14 | 278 / 0,80 / −0,14 | 0% |

**Chi phí = spread cố định 10$ (mức hiện tại):** M1 vẫn thua toàn bộ (PF 0,60–0,92). M5 không có chiến lược
nào đạt PF > 1,1 trên cả hai tập. M15 G1 Trend (1,16 / 1,04) và G2 Momentum (1,18 / 1,03) dương nhẹ, với
**54–56% số cấu hình dương**. Các chiến lược đảo chiều vẫn âm. Chi tiết: `results/selected_dev_val_spread10.csv`.

### B.3. Nhận định

1. **M1 bị loại** trên mọi chiến lược và mọi mô hình chi phí.
2. **Tư duy đảo chiều tại cực trị** (RSI, PVT, ENG, Sweep) **không có lợi thế** trên BTC ở M5/M15.
3. **Tư duy thuận xu hướng / động lượng** là nhóm duy nhất có tín hiệu dương, và chỉ ở **M15**.

---

## Phần C – Giả thuyết cải tiến (mỗi lần thay đổi một nhóm logic)

| Giả thuyết | Thay đổi | Kết quả chính (M15, spread 10$) | Kết luận |
|---|---|---|---|
| C1. Mô hình chi phí | Spread lịch sử → 10$ cố định | Nhóm trend/momentum M15 từ PF ~1,07 lên ~1,17 trên tập nghiên cứu | Chi phí quyết định sống còn. Spread hiện tại (10$) có lợi hơn quá khứ |
| C2. Bộ lọc xu hướng H1 (H-A) | Chỉ vào lệnh cùng chiều EMA50/EMA200 **H1 đã đóng** và ADX H1 ≥ 20 | G2 Momentum: nghiên cứu PF 1,13 (313 lệnh) → xác thực **PF 1,51** (87 lệnh). G1 Trend: 100% cấu hình dương trên tập nghiên cứu nhưng xác thực chỉ PF 1,04 | **Có cải thiện** → 1 ứng viên vào vòng cuối |
| C3. Cho lệnh chạy dài (H-B) | Giữ tối đa 192 nến, TP 3R/5R | G1: 1,18 → 1,11; G2: 1,20 → 0,94 | Không ổn định, loại |
| C4. Lệnh tầng 2 / DCA | — | **Không thử**, theo nguyên tắc cấm Martingale/DCA che giấu tỷ lệ thua | — |

⚠️ **Rủi ro chọn nhầm do may mắn:** tổng cộng khoảng 70 tổ hợp (chiến lược × khung × chi phí × giả
thuyết) đã được đánh giá trên tập xác thực, và **chỉ 1** tổ hợp đạt ngưỡng. Hàng xóm tham số của nó trên
tập nghiên cứu chỉ có PF 1,0–1,1. Vì vậy kết quả tập kiểm tra cuối và walk-forward dưới đây quan trọng
hơn nhiều so với con số 1,51.

---

## Phần D – Lựa chọn phương pháp

### D.1. Cấu hình đã chốt trước khi mở tập kiểm tra cuối

**MOM-M15-H1:** trên nến M15 đã đóng:
- Nến "dịch chuyển mạnh": range ≥ **2,0 × ATR14**, thân ≥ 60% range
- BUY: nến xanh đóng **trên đỉnh 20 nến trước**, EMA50 > EMA200 (M15), **và** xu hướng H1 tăng
  (EMA50 > EMA200 trên nến H1 đã đóng, ADX H1 ≥ 20). SELL ngược lại.
- SL = **2,0 × ATR14 (M15)**, TP = **2R**, đóng lệnh sau tối đa 48 nến M15 (12 giờ). Mỗi lúc chỉ 1 lệnh.

### D.2. Kết quả ✅ (rủi ro cố định 1% vốn/lệnh, lãi kép)

| Tập | Lệnh | Lệnh/tháng | Win % | PF | R TB | TB thắng / thua | Lãi ròng | Max DD | Chuỗi thua dài nhất |
|---|---|---|---|---|---|---|---|---|---|
| Nghiên cứu | 313 | 11,8 | 36,7 | 1,13 | +0,078 | 1,87 / −0,96 | +23,9% | 19,9% | 13 |
| Xác thực | 87 | 9,9 | 43,7 | 1,51 | +0,282 | 1,92 / −0,99 | +26,6% | 6,0% | 5 |
| **KIỂM TRA CUỐI** | **127** | 14,7 | 40,2 | **1,28** | **+0,164** | 1,86 / −0,97 | **+21,6%** | **13,0%** | 8 |
| Toàn bộ (3,7 năm) | 527 | 11,9 | 38,7 | 1,22 | +0,133 | 1,88 / −0,97 | +90,8% | 19,9% | 13 |
| Kiểm tra cuối, spread lịch sử | 128 | — | 39,1 | 1,25 | +0,147 | — | +19,2% | 13,0% | 8 |

**Theo năm (spread 10$):** 2023 PF 1,02 (hòa vốn) · 2024 PF 1,17 · 2025 PF 1,52 · 2026 PF 1,28.

**Walk-forward** (mỗi quý chọn lại tham số trên 12 tháng trước đó, rồi giao dịch 3 tháng tiếp theo):
tổng **432 lệnh ngoài mẫu, PF 1,19, R TB +0,125, lãi +62%, Max DD 19,6%**. **7/10 quý dương**; các quý âm:
Q2-2024 (−8,8%), Q4-2024 (−1,9%), Q1-2025 (−11,2%), Q2-2026 (−6,1%).

**Kiểm chứng bằng tick thật** (16–31/08/2026): **11/11 lệnh** cho cùng kết quả (SL/TP) giữa mô phỏng nến
M1 và tick bid/ask.

**Stress test:**

| Điều kiện | Kiểm tra cuối: PF / lãi | Toàn bộ: PF / Max DD |
|---|---|---|
| Spread 10$ (gốc) | 1,28 / +21,6% | 1,22 / 19,9% |
| Spread 20$ | 1,20 / +15,5% | 1,15 / 25,3% |
| Spread 30$ | 1,05 / +2,6% | 1,07 / 27,9% |
| Spread 10$ + trượt giá 10$ | 1,18 / +13,4% | 1,11 / 28,7% |
| Spread 20$ + trượt giá 20$ | **1,00 / −1,4%** | **0,97 / 40,2%** |

**Monte Carlo** (xáo thứ tự lệnh 5.000 lần, rủi ro 1%): Max DD trung vị 18%, **p95 = 31%**, p99 = 38%;
chuỗi thua p95 = 16 lệnh.

**Theo phiên / trạng thái (toàn bộ, chỉ để mô tả, không dùng để chọn):**
Á PF 1,33 · London 1,37 · NY 1,24 · **17–24h UTC PF 1,00** · **Cuối tuần PF 0,96** · Ngày thường 1,32 ·
Trending 1,42 · Ranging 1,09 · Biến động cao 1,45 · Biến động thấp 1,14.

### D.3. Đối chiếu tiêu chí

| Tiêu chí | Mục tiêu | Kết quả | Đạt? |
|---|---|---|---|
| Net Profit sau chi phí | Dương | +21,6% (test), +62% (walk-forward) | ✅ |
| Profit Factor | ≥ 1,5 | 1,28 (test), 1,19 (WF), 1,22 (toàn bộ) | ❌ |
| Max Drawdown | < 20% | 13–20% thực tế; Monte Carlo p95 = 31% ở rủi ro 1% | ⚠️ Chỉ đạt nếu rủi ro ≤ 0,5%/lệnh |
| Expectancy | Dương | +0,13 … +0,16R | ✅ |
| Số lệnh | Đủ thống kê | 527 lệnh (127 trong test) | ✅ |
| Ngoài mẫu | Duy trì lợi thế | Dương ở val, test, WF | ✅ (yếu) |
| Walk-forward | Ổn định | 7/10 quý dương, 1 quý −11% | ⚠️ |
| Chịu chi phí tăng | — | Chịu được spread gấp đôi; hòa vốn khi spread + trượt giá = 40$ | ⚠️ |

**Kết luận Phần D: chưa tìm được phương pháp đạt đủ điều kiện.** MOM-M15-H1 là ứng viên duy nhất có lợi thế
dương nhất quán, nhưng lợi thế mỏng (khoảng +0,13R/lệnh, win rate khoảng 39%). Nó phụ thuộc vào spread thấp
như hiện tại, và năm 2023 gần như hòa vốn.

**Các đánh đổi:**
- Nâng PF bằng cách bỏ phiên 17–24h UTC và cuối tuần là **có thể**, nhưng những con số đó được quan sát trên
  toàn bộ dữ liệu, kể cả tập test. Áp dụng ngay sẽ là tối ưu trên tập test. Chỉ được đưa vào sau khi kiểm
  chứng bằng dữ liệu mới (demo).
- Tần suất khoảng 12 lệnh/tháng: đủ để đánh giá sau 3–6 tháng demo, nhưng mỗi tháng có thể âm.

---

## Phần E – Đề xuất cấu trúc EA BTCUSD (chưa viết mã, chờ bạn duyệt)

| Thành phần | Đề xuất |
|---|---|
| Timeframe | **H1** = hướng xu hướng · **M15** = tín hiệu · xử lý theo tick / M1 = khớp lệnh và quản lý SL/TP |
| BUY | Nến M15 đóng: range ≥ 2,0 ATR14, thân ≥ 60% range, nến xanh, close > đỉnh cao nhất 20 nến trước, EMA50 > EMA200 (M15), nến H1 đã đóng có EMA50 > EMA200 và ADX14 ≥ 20 |
| SELL | Đối xứng |
| SL / TP | SL = 2,0 × ATR14 M15 · TP = 2R · đóng sau 12 giờ nếu chưa chạm. **Không** lệnh tầng 2, **không** DCA, **không** Martingale |
| Khối lượng | Theo % rủi ro: lot = (vốn × rủi ro%) / (khoảng SL × giá trị 1 lot). Mặc định **0,5%/lệnh** (Monte Carlo: DD trung vị 9%, p95 17%, p99 21%; DD thực tế 10,5%) |
| Bộ lọc thị trường | Không vào lệnh nếu spread hiện tại > 20$, hoặc > 5% khoảng SL (ngưỡng stress đã kiểm tra) |
| Quản lý trạng thái | 1 vị thế / symbol / magic; đọc lại vị thế khi EA khởi động lại; tín hiệu chỉ xét khi đóng nến M15 (không repaint) |
| Bảo vệ tài khoản | Dừng trong ngày khi lỗ 2%; tạm dừng 24h sau 8 lệnh thua liên tiếp (dưới p95 chuỗi thua để không dừng quá sớm); dừng hẳn và báo cáo nếu DD từ đỉnh > 15% (với rủi ro 0,5%) |
| Ghi log | Mỗi lệnh ghi: thời điểm tín hiệu, giá trị ATR/EMA/ADX (M15, H1), spread lúc vào, SL/TP, lý do thoát, R thực tế. Dùng lại được TradeLogger để so sánh demo và backtest |
| Rollback | Toàn bộ tham số là input; phiên bản EA đánh số; mỗi thay đổi đi kèm một lần backtest lại bằng `research/btc` |

**Việc cần làm trước khi cân nhắc tiền thật:**
1. Bạn gửi ảnh **Specification BTCUSDc**, gồm contract size, lot tối thiểu, **swap** (10,8% số lệnh giữ qua 00:00).
   Cũng cần kiểm tra **tài khoản ~88 USD có đặt được lot đủ nhỏ** cho mức rủi ro 0,5% với SL khoảng 400–600$
   hay không.
2. Tôi viết EA (sau khi bạn duyệt), rồi bạn chạy Strategy Tester "Every tick based on real ticks" trên cùng
   giai đoạn để đối chiếu với bảng D.2.
3. Chạy **demo 3 tháng** (khoảng 35–45 lệnh). Tiêu chí tiếp tục: R TB > 0 và DD < 10%.
4. Song song: gửi `tradelog_*.csv` để giải mã David Hunter thật (Phần A) và so sánh công bằng.

---

## Phụ lục – Tái lập kết quả

```
pip install pandas numpy pyarrow numba
cd research/btc
python3 profile_market.py          # đặc điểm thị trường
python3 run_research.py --tag hist # 8 chiến lược × M1/M5/M15, spread lịch sử
python3 run_research.py --spread 10 --tag spread10
python3 run_hypotheses.py          # giả thuyết H1 filter / giữ lệnh dài
python3 run_final.py               # test cuối (cấu hình đã chốt), stress, Monte Carlo, walk-forward
```
Mô hình khớp lệnh và các giả định được mô tả ở đầu `engine.py`. Giới hạn: backtest trên nến M1
(tick chỉ có 2 tuần), commission = 0, chưa tính swap, giả định spread 10$ giữ nguyên trong tương lai.
