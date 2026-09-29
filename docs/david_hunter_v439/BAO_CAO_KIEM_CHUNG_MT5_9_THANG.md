# Kiểm chứng MT5 9 tháng: 6 phương pháp chưa triển khai của V4.39 MATRIX (XAUUSD)

Ngày: 29/09/2026 · EA: `MQL5/Experts/EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5`, bộ cài sẵn `BO_KIEM_CHUNG_6PP`
Dữ liệu: MT5 Strategy Tester, **Every tick based on real ticks**, Exness **XAUUSDm**, 01/01/2026 23:05 → 27/09/2026
File gốc: `EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/` · Phân tích: `research/david_hunter_v439/analyze_mt5.py`,
`compare_mt5.py` → `research/david_hunter_v439/results_mt5/`

Tiếp nối báo cáo sơ bộ [`BAO_CAO_BACKTEST_7PP_CHUA_TRIEN_KHAI.md`](BAO_CAO_BACKTEST_7PP_CHUA_TRIEN_KHAI.md) (Python, 6,5 ngày).

---

## Tóm tắt

1. **Cả 6 ứng viên chọn từ 6,5 ngày đều lỗ sau 9 tháng.** WR giảm từ 66–92% xuống còn 44–51%, PF chỉ còn
   0,81–0,99. Không bộ nào đạt yêu cầu để đưa lên live.
2. **Bản Python khớp MT5.** Sau khi chỉ báo ổn định (từ 06/01), Python tìm thấy đủ **164/164 lệnh thật**
   của MT5, trùng giây vào lệnh, hướng và giá. Vì vậy kết quả 6,5 ngày tốt không phải do lỗi chuyển mã. Nguyên
   nhân là mẫu quá ngắn, đúng như kiểm định "giải đấu ngẫu nhiên" đã cảnh báo.
3. **Không tìm được bộ input nào có lãi ổn định.** 871/2.568 ví (34%) có lãi sau 9 tháng. Nếu chọn ví tốt nhất theo
   T1–T6 rồi kiểm tra trên T7–T9, tương quan hạng xấp xỉ 0. Số ví lãi ở cả hai nửa là 393, chỉ cao hơn một chút
   so với mức 364 nếu hai nửa hoàn toàn độc lập.
4. **Các ví lãi nhiều nhất cả kỳ đều chỉ đánh SELL.** Từ một nửa đến toàn bộ tiền lãi của chúng đến từ hai tháng
   vàng giảm mạnh là T3 (−11,7%) và T6 (−11,8%). Đây là lãi nhờ hướng thị trường, chưa phải lợi thế của điểm vào.
5. **Bộ có WR cao nhất mà vẫn lãi ở cả hai nửa: EMA chỉ SELL trong phiên Á, vào M1, EMA 7/50, lọc M15.**
   Hai ví 346 và 166 đạt WR 63–67%, PF 1,7–2,0, lãi 7–9/9 tháng. Cả 8 biến thể "EMA M1, EMA nhanh 7, SELL phiên Á"
   đều lãi sau 9 tháng (mục 6). Tuy vậy, bộ này được tìm ra sau khi đã nhìn cả 9 tháng.
6. Có vài quy luật lặp lại ở **cả hai nửa**. Đây mới là giả thuyết, chưa phải kết luận:
   - **PIN và LQ** lỗ ở gần như mọi input và mọi TF → **loại**. MM đã bị loại từ báo cáo trước.
   - **BUY trong phiên Á (0–8h) và phiên Âu (8–16h)** lỗ ở cả 6 PP. Lệnh thật của MT5 cũng cùng chiều.
   - **PVEMA SELL phiên Mỹ** và **ICT BUY phiên Mỹ** có lãi ở 76–88% biến thể input, trong cả hai nửa.
7. **Đề xuất:** chưa đưa PP nào trong số này lên live. Chốt các giả thuyết ở mục 8 **ngay bây giờ**, rồi kiểm tra
   trên dữ liệu T10–T12/2026, tức dữ liệu chưa ai nhìn thấy.

---

## 1. Lượt chạy

| Mục | Giá trị |
|---|---|
| Bộ input | 214 bộ: bộ gốc của mỗi PP (ứng viên hạng 1 của nghiên cứu Python) cùng lưới lân cận (EMA 32, ICT 54, SMC 48, PVEMA 24, PIN 24, LQ 32) |
| Ví | 2.568 ví ảo (mỗi bộ input tách 3 hướng × 4 phiên) và ví 0. Ví 0 đặt lệnh thật trong Tester cho 6 bộ gốc |
| Lệnh | Lot 0,02 cố định · SL 5–20 giá · TP1 1R chốt 50% rồi dời SL về hòa vốn · trailing 1R · TP2 theo RR · tối đa 1 lệnh mỗi PP mỗi ví |
| Chi phí | Spread thật · commission 0 · trượt giá 0 · **swap theo sàn** (BUY −560 point/lot/đêm, tức −1,12 USD/đêm với 0,02 lot; SELL 0) |
| Tách dữ liệu | Lượt chạy không đặt holdout, nên tách theo tháng chốt lệnh: **T1–T6** (01–06) để chọn, **T7–T9** (07–27/09) để kiểm |

Thị trường trong kỳ, nhìn ở mức tháng, dao động hai chiều rất mạnh (`results_mt5/thi_truong_theo_thang.csv`):

| Tháng | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 |
|---|---|---|---|---|---|---|---|---|---|
| Thay đổi giá | +13,0% | +10,1% | **−11,7%** | −1,5% | −1,9% | **−11,8%** | +1,0% | +9,3% | −4,3% |
| Biên độ ngày (trung vị) | 80 | 124 | 137 | 99 | 83 | 83 | 84 | 84 | 93 |

## 2. Sáu ứng viên: Python 6,5 ngày so với MT5 9 tháng

| PP | Ví | Hướng / phiên | Python 01–12/01 | MT5: lệnh | WR | PF | Net | T1–T6 | T7–T9 | Tháng lãi |
|---|---|---|---|---|---|---|---|---|---|---|
| EMA | 1 | Cả 2 / cả ngày | 31 lệnh · 67,7% · +141,6 | 603 | 48,9% | 0,97 | −95,5 | −58,2 | −37,3 | 3/9 |
| ICT | 387 | Cả 2 / Âu | 11 · 81,8% · +79,9 | 525 | 48,6% | 0,99 | −39,8 | +252,4 | −292,1 | 5/9 |
| SMC | 1039 | BUY / Âu | 10 · 90,0% · +102,3 | 260 | 44,2% | 0,81 | −501,5 | −587,6 | +86,1 | 3/9 |
| PVEMA | 1610 | Cả 2 / Á | 12 · 91,7% · +246,5 | 297 | 50,5% | 0,95 | −168,3 | −230,7 | +62,5 | 5/9 |
| PIN | 1897 | Cả 2 / cả ngày | 44 · 65,9% · +199,0 | 1.432 | 46,9% | 0,92 | −738,4 | −213,9 | −524,5 | 3/9 |
| LQ | 2187 | Cả 2 / Âu | 17 · 82,4% · +146,5 | 488 | 47,1% | 0,90 | −304,0 | −201,7 | −102,3 | 3/9 |

Tiền tính bằng USD với lot 0,02. Chi tiết theo tháng: `results_mt5/ung_vien_6_5_ngay_qua_9_thang.csv`.

## 3. Bản Python có khớp MT5 không?

Ví 0 đặt lệnh thật trong Tester cho 6 bộ gốc. Chiều Python lấy ví "Cả 2 / cả ngày" của cùng bộ input, trên
đoạn tick Python đang có (01/01 → 12/01). Hai lệnh được coi là khớp khi trùng PP, hướng và **giây vào lệnh**
(`results_mt5/doi_chieu_python_mt5*.csv`):

| Giai đoạn | Lệnh MT5 | Python tìm thấy | Ghi chú |
|---|---|---|---|
| 01/01 → 05/01 | 77 | 52 (68%) | Python tính chỉ báo từ tick đầu tiên, còn MT5 có lịch sử trước đó. EMA/ADX H1–M30 cần vài ngày để hội tụ |
| **06/01 → 12/01** | **164** | **164 (100%)** | Python dư 4 lệnh, đều lúc 21:00–21:59: MT5 từ chối vì "market closed" (có trong `su_kien.csv`) |

Trong 164 lệnh khớp, giá vào trùng tuyệt đối. Có 4 lệnh lệch tiền quá 0,5 USD, vì hai lý do: vị thế thật
không sửa hoặc đóng được trong khung 21:00–23:00, hoặc TP được khớp tại giá mở cửa sau gap. Kết luận: logic
Python đúng như V4.39. Kết quả 6,5 ngày tốt là do chọn lọc trên mẫu quá nhỏ.

## 4. Toàn bộ 2.568 ví sau 9 tháng

| PP | Ví | Ví lãi | Net trung vị | WR trung vị | PF trung vị | USD/lệnh | Tương quan hạng T1–T6 → T7–T9 |
|---|---|---|---|---|---|---|---|
| PVEMA | 288 | 160 (56%) | +45,3 | 49,2% | 1,02 | +0,06 | −0,11 |
| EMA | 384 | 154 (40%) | −15,4 | 49,2% | 0,97 | −0,20 | 0,06 |
| ICT | 648 | 250 (39%) | −94,1 | 47,8% | 0,97 | −0,27 | 0,05 |
| SMC | 576 | 199 (35%) | −126,5 | 47,5% | 0,94 | −0,52 | −0,07 |
| LQ | 384 | 82 (21%) | −217,7 | 47,4% | 0,91 | −0,58 | 0,46 (theo USD/lệnh: 0,10) |
| PIN | 288 | 26 (9%) | −246,8 | 45,9% | 0,86 | −0,94 | 0,40 (theo USD/lệnh: 0,19) |

Tương quan của LQ và PIN trông cao là do số lệnh. Ở hai PP này bộ nào cũng lỗ, nên bộ nào vào nhiều lệnh thì lỗ
nhiều ở cả hai nửa. Tính theo USD mỗi lệnh thì tương quan chỉ còn 0,10–0,19.

WR cao nhất của mỗi PP sau 9 tháng là 52–59%, riêng EMA có một ví đạt 66,7% (99 lệnh, xem mục 6). Mức WR 80–90%
của 6,5 ngày không lặp lại ở bất kỳ đâu.

## 5. Chọn trên T1–T6, kiểm trên T7–T9

Lấy 5 ví có net T1–T6 cao nhất của mỗi PP (tối thiểu 30 lệnh), rồi xem kết quả T7–T9 của chúng
(`results_mt5/chon_T1_T6_kiem_T7_T9.csv`):

| PP | Net T7–T9 của 5 ví (xếp theo hạng T1–T6) | TB top 5 | Trung vị cả PP | Lãi T7–T9 nếu lãi T1–T6 / nếu lỗ T1–T6 |
|---|---|---|---|---|
| EMA | +46 · +1 · −50 · +85 · +100 | +36 | −14 | 44% / 43% |
| ICT | −346 · −217 · −187 · −69 · −146 | −193 | −39 | 46% / 35% |
| SMC | −46 · −60 · +89 · +67 · +92 | +28 | −40 | 37% / 44% |
| PVEMA | **+259** · +86 · −50 · −26 · −78 | +38 | −37 | 37% / 46% |
| PIN | −231 · −143 · −173 · −217 · −144 | −182 | −129 | 20% / 15% |
| LQ | −3 · −24 · +117 · −109 · +43 | +5 | −78 | 31% / 22% |

Kết quả khi gộp theo ô hướng × phiên của từng PP (gộp mọi input, `results_mt5/o_huong_phien.csv`):

- Hai ô tốt nhất T1–T6 là **PVEMA BUY / Mỹ** (92% biến thể lãi) và **PVEMA SELL / Âu** (92%).
  Sang T7–T9, tỷ lệ lãi của chúng tụt còn **21% và 0%**.
- Trong 36 ô tách riêng hướng và phiên, 15 ô lãi ở T1–T6 và 9 ô lãi ở T7–T9. Chỉ 5 ô lãi ở cả hai nửa.

→ Tối ưu input trên quá khứ **không mang lại lợi thế** ở giai đoạn sau, với cả 6 PP. Ngoại lệ đáng chú ý duy nhất
là ví PVEMA 1629. Ví này đứng hạng 1 T1–T6 và vẫn nằm ở phân vị 98% của T7–T9. Tuy vậy, 1 trên 6 lần chọn
đúng vẫn phù hợp với mức may mắn.

## 6. Top ví 9 tháng (chỉ để tham khảo, đây là kết quả trong mẫu)

| Ví | PP | Hướng / phiên | Input | Lệnh | WR | PF | Net | Phần lãi từ T3 + T6 | Tháng lãi |
|---|---|---|---|---|---|---|---|---|---|
| 1629 | PVEMA | SELL / cả ngày | Vào M5 · xu hướng M30 · ADX 14 · SL 5 nến | 605 | 54,5% | 1,21 | +1.182,6 | 50% | **9/9** |
| 1199 | SMC | SELL / Âu | Vào M1 · bias M15 · Disp 0,9 · RSI | 368 | 56,2% | 1,38 | +1.019,6 | 96% | 6/9 |
| 1773 | PVEMA | SELL / cả ngày | Vào M5 · M30 · ADX 14 · SL 10 nến | 497 | 53,5% | 1,18 | +912,1 | 70% | 5/9 |
| 1091 | SMC | SELL / Âu | Vào M1 · bias M30 · Disp 0,9 · EMA H1 + RSI | 247 | 57,5% | 1,51 | +910,2 | 79% | 7/9 |
| 1055 | SMC | SELL / Âu | Vào M1 · bias M15 · Disp 0,9 · EMA H1 + RSI | 276 | 58,0% | 1,43 | +884,1 | 96% | 5/9 |

Cả 10 ví đứng đầu đều chỉ đánh SELL. Riêng ví 1629 có lãi đều ở cả 9 tháng
(+4 · +24 · +281 · +282 · +20 · +312 · +60 · +31 · +168). Ví này chỉ bán khi xu hướng M30 đang giảm. Ở hai tháng
vàng tăng mạnh là T1 và T8, nó gần như không vào lệnh (lần lượt 4 và 20 lệnh), nên thực chất là một chiến lược bán
theo xu hướng giảm. Danh sách đầy đủ: `results_mt5/top30_9_thang_tham_khao.csv` và `tat_ca_vi_9_thang.csv.gz`.

**Bộ có WR cao nhất mà vẫn lãi ở cả hai nửa.** Có 319 ví đạt từ 100 lệnh trở lên và lãi ở cả hai nửa. Ba ví có WR
cao nhất trong số đó đều là EMA, chỉ SELL, phiên Á. Ví 346 thuộc cùng vùng này (99 lệnh) và có WR cao nhất trong
toàn bộ lượt chạy.

| Ví | Input (EMA, SELL, phiên Á 0–8h) | Lệnh | WR | PF | Net | T1–T6 | T7–T9 | Tháng lãi |
|---|---|---|---|---|---|---|---|---|
| 346 | M1 · EMA 7/50 · lọc M15 · DirEff 0,22 | 99 | **66,7%** | 2,0 | +374,4 | +237,3 (WR 65,3%) | +137,2 (WR 70,4%) | 7/9 |
| 166 | M1 · EMA 7/50 · lọc M15 · DirEff 0,10 | 116 | **62,9%** | 1,7 | +349,0 | +248,9 | +100,1 | **9/9** |
| 262 | M1 · EMA 7/50 · lọc M5 · DirEff 0,22 | 90 | 62,2% | 1,6 | +223,2 | +104,2 | +118,9 | 7/9 |
| 118 | M1 · EMA 7/34 · lọc M15 · DirEff 0,10 | 136 | 60,3% | 1,4 | +245,5 | +84,3 | +161,3 | 7/9 |

Vùng này không phải một điểm lẻ. Cả 8 biến thể "M1, EMA nhanh 7, SELL phiên Á" đều lãi sau 9 tháng và đều lãi ở
T7–T9. 6/8 biến thể lãi ở cả hai nửa. Ngược lại, cùng ô đó nhưng dùng EMA nhanh 12 thì âm ở T1–T6. Hạn chế: khoảng
100 lệnh trong 9 tháng (2–3 lệnh mỗi tuần), và vùng này được tìm ra sau khi đã nhìn cả 9 tháng.

## 7. Các quy luật lặp lại ở cả hai nửa (giả thuyết cần kiểm tiếp)

Tính bằng USD mỗi lệnh (lot 0,02), gộp mọi input của PP. Chi tiết: `results_mt5/truc_input.csv` và `o_huong_phien.csv`.

**a) BUY trong phiên Á và phiên Âu lỗ ở cả 6 PP.** 11/12 ô âm ở cả hai nửa. Ô còn lại là EMA BUY phiên Á: xấp xỉ 0
ở T1–T6 và −0,42 ở T7–T9. Lệnh thật của ví 0 (6.698 lệnh, không phụ thuộc cách tính ví ảo) cũng cùng chiều, dù yếu
hơn ở T7–T9:

| Lệnh thật ví 0 | BUY Á | BUY Âu | BUY Mỹ | SELL Á | SELL Âu | SELL Mỹ |
|---|---|---|---|---|---|---|
| T1–T6 (USD/lệnh) | −1,74 | −2,02 | +0,20 | −0,27 | +1,15 | +0,30 |
| T7–T9 (USD/lệnh) | −0,06 | −0,72 | +0,27 | +0,38 | −0,65 | −0,36 |

**b) Ô dương ở cả hai nửa:**

| Ô | Biến thể input | USD/lệnh T1–T6 | USD/lệnh T7–T9 | % biến thể lãi T1–T6 / T7–T9 |
|---|---|---|---|---|
| PVEMA SELL / Mỹ | 24 | +1,43 | +1,61 | 79% / 88% |
| ICT BUY / Mỹ | 54 | +1,73 | +0,95 | 78% / 76% |
| PVEMA SELL / Á | 24 | +1,04 | +0,55 | 75% / 62% |
| SMC BUY / Mỹ | 48 | +1,25 | +0,22 | 71% / 62% |
| EMA SELL / Á | 32 | +0,21 | +1,92 | 47% / 78% |

Mức lãi này nhỏ: khoảng +1 USD mỗi lệnh, trong khi mức rủi ro mỗi lệnh là 10–40 USD. Ngoài ra, 5 ô này được chọn
**sau khi đã nhìn cả hai nửa**, nên vẫn phải kiểm tra lại trên dữ liệu mới.

**c) TF vào lệnh:** khi gộp mọi hướng và phiên, không TF nào dương ở cả hai nửa.

| PP | TF: USD/lệnh T1–T6 → T7–T9 | Nhận xét |
|---|---|---|
| EMA | M1: −0,28 → −0,30 · M2: −0,19 → +0,42 | M2 nhỉnh hơn ở cả hai nửa, nhưng M1 lại tốt nhất trong ô SELL phiên Á (mục 6) |
| ICT | M1: −0,32 → −0,12 · M2: −0,07 → −0,74 | Thứ hạng đảo giữa hai nửa |
| SMC | M1: −0,85 → +0,01 · M2: +0,03 → −0,24 · M3: −0,26 → −2,38 | Thứ hạng đảo; M3 tệ nhất |
| PVEMA | M5: +0,21 → −0,87 · M6: −0,11 → −0,03 · M10: +1,55 → −1,02 | M10 dẫn đầu T1–T6 rồi tụt xuống cuối ở T7–T9 |
| PIN | M1: −0,65 → −1,18 · M2: −1,04 → −1,53 | Âm ở mọi TF |
| LQ | M1: −0,64 → −0,58 · M4: −0,44 → −0,50 | Âm ở mọi TF |

## 8. Kết luận và đề xuất

1. **Không đưa ứng viên nào trong 6 ứng viên** lên live, và cũng không đưa các "ví tốt nhất 9 tháng" lên live.
2. **Loại PIN, LQ, MM** với logic và cách quản lý lệnh LAB hiện tại.
3. **Chốt ngay các giả thuyết sau**, chưa sửa gì thêm, rồi kiểm tra trên dữ liệu T10–T12/2026:
   - H1: ví PVEMA 1629 (SELL, vào M5, xu hướng M30, ADX 14, SL 5 nến) vẫn có PF > 1.
   - H2: ô PVEMA SELL / Mỹ và ô ICT BUY / Mỹ vẫn có USD/lệnh > 0 ở đa số biến thể.
   - H3: BUY trong phiên Á và phiên Âu vẫn âm.
   - H4: EMA SELL phiên Á, M1, EMA 7/50, lọc M15 (ví 346 và 166) vẫn có WR ≥ 55% và PF > 1.
   Cách kiểm tra: chạy lại đúng bộ `BO_KIEM_CHUNG_6PP` từ 01/10/2026 rồi dùng `analyze_mt5.py`. Số ví giữ nguyên
   giữa các lần chạy cùng bộ cài sẵn. Giả thuyết nào không đạt thì bỏ, không chỉnh input để "cứu".
4. Muốn biết 4 PP đang live có thực sự tốt hơn không, cần chạy BRK758, PVT880, ENG626, ENG636 trên đúng 9 tháng
   này, với cùng cách tính.

## 9. Chạy lại

```bash
cd research/david_hunter_v439
python3 analyze_mt5.py --run <thư mục chứa xep_hang.csv, ket_qua_thang.csv, bo_cau_hinh.csv, …>
python3 compare_mt5.py --mt5 <…/lenh_tham_chieu_MT5.csv>   # cần tick 01–12/01 (cache $DH_CACHE)
```

| File `results_mt5/` | Nội dung |
|---|---|
| `ung_vien_6_5_ngay_qua_9_thang.csv` | 6 ứng viên: Python và MT5, net theo tháng |
| `tong_quan_pp_9_thang.csv` | Tổng quan từng PP, tương quan T1–T6 → T7–T9 |
| `chon_T1_T6_kiem_T7_T9.csv` | Top 5 theo T1–T6 và kết quả T7–T9 |
| `o_huong_phien.csv` | 72 ô PP × hướng × phiên: USD/lệnh và % biến thể lãi ở từng nửa |
| `truc_input.csv` | Từng giá trị input (gồm TF): USD/lệnh ở từng nửa |
| `top30_9_thang_tham_khao.csv` · `tat_ca_vi_9_thang.csv.gz` | Top 30 và toàn bộ ví, kèm input và net theo tháng |
| `doi_chieu_python_mt5.csv` · `doi_chieu_python_mt5_tong.csv` | Đối chiếu từng lệnh Python và MT5 |
| `thi_truong_theo_thang.csv` · `tom_tat.json` | Diễn biến giá theo tháng và tóm tắt lượt chạy |

Lưu ý chất lượng lượt chạy: `reference_quality = REVIEW_REQUIRED`. Có 25.655/201.240 yêu cầu lệnh thật của ví 0
bị lỗi. Trong đó 62 lỗi mở lệnh đều là "market closed" lúc 21:00–21:59. Các lỗi sửa SL và chốt một phần chưa
xác nhận được giờ vì chưa có `doi_chieu_khop_lenh.csv`. Ví ảo trong `xep_hang.csv` không bị ảnh hưởng. Tuy vậy, ví
ảo vẫn vào lệnh trong khung 21:00–21:59, là khung giờ Tester không cho đặt lệnh thật.
