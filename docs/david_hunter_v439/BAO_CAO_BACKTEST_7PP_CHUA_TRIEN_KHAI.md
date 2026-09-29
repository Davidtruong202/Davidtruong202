# Backtest 7 phương pháp chưa triển khai của David Hunter V4.39 MATRIX (XAUUSD)

Ngày: 29/09/2026 · Nguồn logic: `EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2.mq5` (repo EA-PRO)
Dữ liệu: tick thật Exness **XAUUSDm**, 01/01/2026 23:05 → 12/01/2026 13:03 (~6,5 ngày giao dịch)
Trạng thái: **SƠ BỘ.** Dữ liệu quá ngắn để chọn cấu hình chạy tiền thật (xem mục 7).

Mã nguồn và dữ liệu thô: `research/david_hunter_v439/` (chạy lại được bằng một lệnh, mục 10).

---

## Tóm tắt

1. Đã backtest **7 PP bị gỡ khỏi bản live ở V4.49**: EMA, ICT, MM, SMC, PVEMA, PIN, LQ. Quét
   **4.276 bộ input** gồm cả khung thời gian (TF). Mỗi bộ tách thành 12 tài khoản ảo (3 hướng × 4 phiên)
   giống hệt Matrix V4.39, tổng cộng **51.312 tài khoản**.
2. Bộ backtest là bản chuyển từng dòng logic V4.39 sang Python, chạy trên **từng tick** Bid/Ask thật.
   Đã đối chiếu với một bản dịch nguyên văn MQL5 viết riêng: 20 cấu hình cho ra **đúng từng tín hiệu**
   (tick, hướng, giá vào, SL, TP), 15 cấu hình khác khớp từng mẫu hình/setup, và 354 lệnh cho ra **đúng tick
   thoát lệnh**.
3. **Cấu hình có lãi, WR cao nhất của từng PP** (lot 0,02, tiền USD, mục 6):

| PP | Khung | Hướng / phiên | Lệnh | WR | PF | Net | Input chính |
|---|---|---|---|---|---|---|---|
| EMA | M1 | Cả 2 / cả ngày | 31 | 67,7% | 2,41 | +141,6 | EMA 12/34, lọc M15 |
| ICT | M1 | Cả 2 / phiên Âu | 11 | 81,8% | 3,99 | +79,9 | Bias M30, Disp 0,9, Unicorn |
| SMC | M1 | BUY / phiên Âu | 10 | 90,0% | 11,2 | +102,3 | Bias cấu trúc M15, Disp 1,2 |
| PVEMA | M6 | Cả 2 / phiên Á | 12 | 91,7% | 24,5 | +246,5 | Xu hướng M30, ADX 14, SL 10 nến |
| PIN | M1 | Cả 2 / cả ngày | 44 | 65,9% | 2,17 | +199,0 | Râu/thân 3,4, quét 3 nến |
| LQ | M4 | Cả 2 / phiên Âu | 17 | 82,4% | 5,19 | +146,5 | Xuyên 0,7–2,0, râu/thân 3,0 |
| MM | – | – | – | – | – | – | **Không có cấu hình nào có lãi** (0/384) |

4. **Không nên đưa các cấu hình trên lên tài khoản thật.** Kiểm định “giải đấu ngẫu nhiên” (mục 7)
   cho thấy: nếu vào lệnh ở thời điểm ngẫu nhiên rồi chọn lọc y hệt, “cấu hình WR tốt nhất” vẫn đạt mức
   tương đương. Nghĩa là WR 80–90% ở trên **chưa phân biệt được với may mắn** khi chỉ có 6,5 ngày.
5. Tín hiệu đáng tin nhất là ở **cấp toàn phương pháp**:
   - **MM** thua ở mọi TF và mọi input, tệ hơn cả vào lệnh ngẫu nhiên → **loại** với logic hiện tại.
   - **EMA M1** và **PIN M1** có số cấu hình đạt lọc gấp 3–4 lần mức ngẫu nhiên (p ≈ 0,06–0,10)
     → **ưu tiên kiểm chứng đầu tiên**.
   - **PVEMA** và **SMC** lãi chủ yếu nhờ lệnh BUY trong nhịp tăng 4.328 → 4.595. Vào BUY ngẫu nhiên cũng lãi
     tương đương → chưa chứng minh được lợi thế về điểm vào.
6. **Việc cần làm tiếp**: tải đủ 14 phần còn lại của file tick (hiện GitHub chỉ có
   `XAUUSDm_…zip.part001`, khoảng 1/15 dữ liệu tháng 1–4/2026). Hoặc chạy các file SET kiểm chứng
   (mục 9) trong MT5 trên ít nhất 3–6 tháng tick thật.

---

## 1. Phạm vi

| Nhóm | Phương pháp | Ghi chú |
|---|---|---|
| **Chưa triển khai (đối tượng nghiên cứu)** | EMA (family 0), ICT (1), MM (2), SMC (3), PVEMA (4), PIN (6), LQ (8) | V4.49 đã gỡ khỏi bản live (README EA-PRO) |
| Đang chạy live (đối chứng) | BRK758, PVT880, ENG626, ENG636 | Cấu hình lấy từ `set4pp_v452.set`, chạy cùng kỳ dữ liệu |

## 2. Dữ liệu ✅

| Mục | Giá trị |
|---|---|
| File | `EA-PRO/data/XAUUSDm_202601012305_202604301458.zip.part001` (24.000.000 byte) |
| Độ phủ | File nén đầy đủ là 359 MB (1,86 GB CSV). Trên GitHub **chỉ có phần 1**, giải nén được 128 MB đầu = **2.733.021 tick** |
| Khoảng thời gian | 01/01/2026 23:05 → 12/01/2026 13:03 (02/01, 05–09/01, sáng 12/01) |
| Spread | 0,16 giá ở 99,98% số tick. Thỉnh thoảng 0,24–0,48 |
| Thị trường | **Tăng mạnh**: 4.328 → 4.595 (+6,2%). Biên độ ngày 64–93 giá. ATR14 trung vị: M1 1,8 · M5 4,1 · M15 7,4 · H1 16,3 |
| Nguồn bổ sung | Đã thử tải dữ liệu XAUUSD công khai (Dukascopy…) nhưng mạng của môi trường chạy **chặn** các nguồn này |

## 3. Cách backtest

Bộ mô phỏng làm đúng những gì V4.39 MATRIX làm trong Strategy Tester:

- **Tín hiệu:** mọi hàm tín hiệu được chuyển nguyên văn: `PVEMASignal`, `PVPinBarSignal`, `PVLiquiditySignal`,
  `BuildICTSetup`/`DetectSweepMSSFVG`, `BuildMMSetup`, `BuildSMCSetup`, `TryEnterSetup`, module EMA
  (giao cắt và retest theo tick, `WaveIsStrongEnough`). Công thức chỉ báo giống MT5: EMA, ATR (SMA của TR),
  RSI (Wilder), ADX (EMA). Nến dựng từ giá Bid như chart MT5.
- **Thời điểm:** nhóm PV (PVEMA/PIN/LQ) xét nến vừa đóng và vào lệnh ở tick đầu nến mới. ICT/MM/SMC dựng
  setup ở nến mới, vào lệnh khi tick chạm vùng. EMA xét từng tick.
- **Quản lý lệnh (LAB V4.39, cố định):** SL phải nằm trong 5–20 giá (nhỏ hơn 5 thì nới ra 5). TP2 = RR × rủi ro,
  với RR = PV 2,0 · ICT 2,0 · MM 2,5 · SMC 2,3 · EMA 1,5 phiên Á / 2,0 phiên Âu–Mỹ. TP1 = 1R chốt 50% rồi dời
  SL về hòa vốn. Trailing 1R bước 0,01. Kiểm tra theo thứ tự SL → TP2 → TP1 → trailing ở mỗi tick.
- **Tài khoản ảo:** mỗi bộ input có 12 tài khoản (hướng BUY_SELL/BUY/SELL × phiên TẤT CẢ/Á 0–8h/Âu 8–16h/Mỹ 16–24h
  giờ server). Mỗi tài khoản giữ tối đa 1 lệnh của PP, giống `InpMatrixLenhMoiPP = 1`.
- **Chi phí:** spread thật trong từng tick; commission 0; lot cố định 0,02 (contract 100 → 2 USD cho mỗi 1 giá).
  Trượt giá vào lệnh 0 như mặc định LAB. Mục 6 thử thêm 0,3 như set live.

**Kiểm tra độ khớp ✅** (`tests/test_crosscheck.py`, `tests/test_engines.py`): bản nhanh và bản dịch nguyên văn
MQL5 cho kết quả giống nhau ở 12 cấu hình PV, 3 cấu hình dò cấu trúc (≈13.600 lần phát hiện), 13 cấu hình
EMA/ICT/MM/SMC chạy theo tick, 7 cấu hình PV đầy đủ SL/TP, và 354 lệnh BRK (tick thoát lệnh, lãi/lỗ).

**Khác biệt còn lại so với MT5** (🟡 ảnh hưởng nhỏ nhưng cần biết):
- MT5 có lịch sử trước ngày bắt đầu test để “làm nóng” chỉ báo, còn ở đây EMA bắt đầu từ nến đầu tiên.
  Với EMA200 H1 (SMC lọc H1) và EMA150 H1 (PVEMA), giá trị chưa hội tụ hết trong 6,5 ngày.
- Chưa tính swap. Chưa mô phỏng margin/stop-out (lot 0,02 với vốn 1.000 USD thì không chạm tới).

## 4. Lưới quét (input × TF)

| PP | Trục quét | Số bộ |
|---|---|---|
| EMA | TF M1/M2/M3/M5 · EMA nhanh 7/12 · EMA chậm 21/34/50 · TF lọc M5/M15 · khoảng chạy xa 0,35/1,0 ATR · hiệu suất sóng 0,10/0,22 · retest EMA nhanh/chậm | 384 |
| ICT | TF vào M1/M2/M3/M5/M15 · TF bias M15/M30/H1 · Displacement 0,6/0,9/1,2 · FVG 0,05/0,10 · ưu tiên Unicorn/OTE/Inversion/2022 · hạn setup 12/24 | 720 |
| MM | TF vào M1/M3/M5/M15 · TF range M30/H1 · Displacement 0,7/1,0/1,3 · FVG 0,03/0,08 · Premium 0,62/0,70 · Discount 0,30/0,38 · Leg1 bật/tắt | 384 |
| SMC | TF vào M1/M2/M3/M5/M15 · TF bias M15/M30/H1 · Displacement 0,6/0,9/1,2 · FVG 0,03/0,08 · lọc EMA H1 · lọc EMA M5 · lọc RSI (bật/tắt) | 720 |
| PVEMA | TF vào M3/M4/M5/M6/M10/M15 · TF xu hướng M15/M30/H1 · ADX 14/20/25 · nến SL 5/10 · dung sai hồi 0,25/0,5 · thân nến 0,3/0,5 | 432 |
| PIN | TF M1/M2/M3/M4/M5/M6/M10/M15 · râu/thân 1,8/2,2/2,8/3,4 · quét 3/6/10 nến · biên độ min 1,0/1,3 · max 1,8/2,5 ATR · nến SL 5/10 | 768 |
| LQ | TF M1/M2/M3/M4/M5/M6/M10/M15 · xuyên min 0,3/0,5/0,7 · max 1/2/3 giá · 6/12 nến · râu/thân 1,5/2/3 · nến SL 5/10 | 864 |

Các input không có trong bảng giữ đúng mặc định V4.39.

## 5. Kết quả theo phương pháp và theo TF ✅

Số liệu ở tài khoản “cả 2 hướng / cả ngày” (cách chạy EA thông thường); tiền tính bằng USD, lot 0,02.

| PP | % bộ input có lãi | Lệnh TV | Net TV | TF tốt | TF kém |
|---|---|---|---|---|---|
| EMA | 68% | 5 | +14 | **M1** (82% lãi, 19 lệnh) | M5 (2 lệnh) |
| ICT | 46% | 14 | 0 | **M1–M2** (69–88% lãi) | M5 (28%). M15 không có lệnh (xem dưới bảng) |
| MM | **0%** | 11 | **−96** | – | Mọi TF đều lỗ. M15 không có lệnh |
| SMC | 59% | 16 | +27 | **M2–M3** (74–79%) | M5 (11%) |
| PVEMA | 78% | 28 | +72 | **M4–M10** (96–100%) | M15 (19%) |
| PIN | 58% | 11 | +8 | **M1** (98%), M4–M5 (92–94%) | M6, M15 |
| LQ | 41% | 44 | −15 | **M1** (94%, 98 lệnh), M15 (94%, ít lệnh) | M2–M10 (3–40%) |

Chi tiết theo từng TF: `results/theo_khung_tf.csv`.

Quy luật TF: với dải SL cố định **5–20 giá**, khung càng lớn thì SL cấu trúc càng hay vượt 20 và bị loại.
Ở M15, ICT/MM/SMC gần như không có lệnh: setup hay hết hạn trước khi giá hồi về vùng, còn khi chạm vùng thì SL
tới điểm quét thường > 20 giá nên bị loại (ví dụ MM M15 gốc: 17 setup, 4 lần chạm, cả 4 bị loại vì SL).
Khung phù hợp với LAB V4.39 là **M1–M6**.

## 6. Cấu hình có lãi, WR cao nhất của từng PP

**Bộ lọc** (để không chọn nhầm cấu hình ăn may): ≥10 lệnh · Net > 0 · PF ≥ 1,3 · có lãi ở **cả hai nửa dữ liệu**
(02–07/01 và 08–12/01, mỗi nửa ≥3 lệnh) · ≥60% “hàng xóm” (đổi 1 input sang giá trị liền kề) cũng lãi.
**Xếp hạng** theo cận dưới khoảng tin cậy 95% của WR (Wilson). Cách này phạt WR cao nhưng ít lệnh.

| # | PP | Input (tên đúng như EA) | Khung | Hướng / phiên | Lệnh | WR | PF | Net | DD | Nửa 1 / nửa 2 | Trượt 0,3: WR / Net | Vào lệnh ngẫu nhiên: WR TV / p |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **EMA** | `InpTimeframe=M1, InpFastEMA=12, InpSlowEMA=34, InpEMAKhungLoc=M15, InpEMAKhoangDiXaToiThieuATR=0.35, InpMinDirectionEfficiency=0.22, InpEMAMucRetest=0` | M1 | Cả 2 / cả ngày | 31 | 67,7% | 2,41 | +141,6 | 30,2 | +92 / +49 | 64,5% / +127 | 48% / 0,03 |
| 2 | **ICT** | `InpICTEntryTF=M1, InpICTBiasTF=M30, InpICTDisplacementATR=0.9, InpICTMinFVG_ATR=0.05, InpICTPriority=0, InpICTSetupExpiryBars=12` | M1 | Cả 2 / Âu | 11 | 81,8% | 3,99 | +79,9 | 16,6 | +27 / +53 | 81,8% / +91 | 45% / 0,01 |
| 2b | ICT (nhiều lệnh hơn) | như trên nhưng `InpICTDisplacementATR=0.6, InpICTPriority=3` | M1 | Cả 2 / cả ngày | 42 | 64,3% | 1,68 | +137,8 | 69,5 | +45 / +93 | 61,9% / +127 | 50% / 0,04 |
| 3 | **SMC** | `InpSMCEntryTF=M1, InpSMCBiasTF=M15, InpSMCDisplacementATR=1.2, InpSMCMinFVGATR=0.03, InpSMCDungLocEMAH1=false, InpSMCDungLocEMAM5=false, InpSMCDungLocRSI=true` | M1 | BUY / Âu | 10 | 90,0% | 11,2 | +102,3 | 10,0 | +37 / +66 | 77,8% / +82 | 50% / 0,00 |
| 4 | **PVEMA** | `InpPVKhungVaoLenh=M6, InpPVKhungXuHuong=M30, InpPVADXToiThieu=14, InpPVSoNenTimSL=10, InpPVDungSaiHoiATR=0.25, InpPVThanNenToiThieu=0.3` | M6 | Cả 2 / Á (thực tế 12/12 lệnh BUY) | 12 | 91,7% | 24,5 | +246,5 | 10,5 | +134 / +113 | 91,7% / +247 | 58% / 0,01 |
| 5 | **PIN** | `InpPVKhungPinBar=M1, InpPVRauChinhTrenThan=3.4, InpPVPinQuetSoNen=3, InpPVPinMinATR=1.0, InpPVPinMaxATR=2.5, InpPVSoNenTimSL=10` | M1 | Cả 2 / cả ngày | 44 | 65,9% | 2,17 | +199,0 | 43,1 | +169 / +30 | 61,4% / +155 | 48% / 0,02 |
| 6 | **LQ** | `InpPVKhungQuetThanhKhoan=M4, InpPVDoXuyenToiThieuGia=0.7, InpPVDoXuyenToiDaGia=2.0, InpPVSoNenThanhKhoan=6, InpPVRauQuetTrenThan=3.0, InpPVSoNenTimSL=5` | M4 | Cả 2 / Âu | 17 | 82,4% | 5,19 | +146,5 | 20,1 | +122 / +24 | 82,4% / +144 | 47% / 0,00 |
| 6b | LQ (cả ngày) | `InpPVKhungQuetThanhKhoan=M1, …ToiThieu=0.7, …ToiDa=1.0, InpPVSoNenThanhKhoan=12, InpPVRauQuetTrenThan=2.0, InpPVSoNenTimSL=5` | M1 | Cả 2 / cả ngày | 32 | 75,0% | 2,88 | +155,6 | 14,7 | +114 / +41 | 71,0% / +146 | 47% / 0,00 |
| – | **MM** | Không có bộ nào qua bộ lọc (0/384 bộ lãi ở tài khoản gốc) | | | | | | | | | | |

Chú thích:
- *Vào lệnh ngẫu nhiên*: giữ nguyên số lệnh, tỷ lệ BUY/SELL, khoảng SL và RR, nhưng vào ở thời điểm ngẫu
  nhiên trong cùng phiên (1.000 lần). p = tỷ lệ số lần ngẫu nhiên đạt WR ≥ cấu hình.
- *DD*: sụt giảm lớn nhất tính trên số dư đã chốt, USD, lot 0,02.

Top 3 của mỗi PP: `results/de_xuat_moi_pp.csv`. Toàn bộ ứng viên qua lọc: `results/ung_vien_dat_loc.csv`.
Danh sách từng lệnh của các ứng viên: `results/lenh_de_xuat.csv`.

## 7. Kiểm định: WR cao có phải do may mắn? ⚠️

Mỗi cấu hình ở mục 6 là cấu hình tốt nhất trong hàng nghìn tài khoản. Vì vậy p nhỏ ở mục 6 là điều gần như
chắc chắn, dù PP không có lợi thế. Để kiểm tra đúng, mình chạy **“giải đấu ngẫu nhiên”**
(`null_tournament.py`) 100 lần. Mỗi lần dịch toàn bộ tín hiệu sang một thời điểm ngẫu nhiên (giữ nguyên hướng,
SL, RR), chạy lại đủ 12 tài khoản/bộ, rồi lọc và chọn **y hệt**:

| PP | WR (cận dưới) tốt nhất thật | Tốt nhất khi ngẫu nhiên (trung vị) | p | Số tài khoản qua lọc: thật / ngẫu nhiên | p |
|---|---|---|---|---|---|
| EMA | 50,1 | 52,3 | 0,53 | 118 / 30 | **0,10** |
| ICT | 52,3 | 52,4 | 0,58 | 264 / 115 | 0,24 |
| MM | – | 38,1 | 1,00 | 0 / 8 | 1,00 (tệ hơn ngẫu nhiên) |
| SMC | 59,6 | 53,5 | 0,30 | 480 / 207 | 0,23 |
| PVEMA | 64,6 | 56,0 | 0,19 | 754 / 478 | 0,29 |
| PIN | 51,1 | 52,4 | 0,57 | 318 / 111 | **0,06** |
| LQ | 59,0 | 60,4 | 0,66 | 914 / 648 | 0,16 |

Đọc bảng:
- **Cột WR tốt nhất:** p từ 0,19 đến 0,66. Nếu chỉ chọn “bộ có WR cao nhất” trên 6,5 ngày, kết quả **không hơn
  vào lệnh ngẫu nhiên**. Đây là lý do chưa nên dùng ngay các cấu hình ở mục 6.
- **Cột số tài khoản qua lọc** (đo cả phương pháp): EMA và PIN có số tài khoản tốt nhiều gấp 3–4 lần mức
  ngẫu nhiên. Đây là dấu hiệu tốt nhất hiện có, nhưng vẫn chưa đạt ngưỡng p < 0,05.
- **MM** tệ hơn ngẫu nhiên ở mọi thước đo. Trong kỳ này MM chủ yếu vào SELL ở vùng premium, tức ngược một
  nhịp tăng mạnh.
- **PVEMA/SMC**: vào lệnh ngẫu nhiên với cùng tỷ lệ BUY còn lãi hơn (PVEMA: 75% tài khoản lãi khi ngẫu nhiên
  so với 64% thật). Lợi nhuận đến từ **hướng BUY trong nhịp tăng**, chưa phải từ điểm vào.

## 8. Đối chứng: 4 PP đang chạy live, cùng kỳ dữ liệu

| Cấu hình | Khung | Hướng / phiên | Lệnh | WR | PF | Net | Nửa 1 / nửa 2 | Vào lệnh ngẫu nhiên p |
|---|---|---|---|---|---|---|---|---|
| ENG626 | M4 | Cả 2 / Á | 29 | 34,5% | 0,56 | −129,3 | −60 / −69 | 0,95 |
| ENG636 | M4 | SELL / Mỹ | 10 | 70,0% | 2,12 | +54,1 | +58 / −4 | 0,08 |
| BRK758 | M4 | Cả 2 / Á | 20 | 60,0% | 1,58 | +107,3 | +121 / −13 | 0,29 |
| PVT880 | M6 | Cả 2 / Mỹ | 12 | 50,0% | 1,33 | +22,0 | −4 / +26 | 0,45 |

Trong cùng 6,5 ngày, chính 4 PP live cũng cho kết quả lẫn lộn (ENG626 lỗ nặng). Điều này nhắc lại: một tuần
dữ liệu không đủ để khẳng định PP nào tốt hay xấu (AGENTS.md mục 4.8).

## 9. Kết luận và đề xuất

1. **Chưa có cấu hình nào đạt tiêu chí đưa lên live.** Theo AGENTS.md (mục 4, 7.3), cần kiểm chứng ngoài mẫu
   trên nhiều tháng.
2. **Thứ tự ưu tiên kiểm chứng:**
   (1) **EMA M1** (12/34, lọc M15) · (2) **PIN M1** (râu/thân 3,4, quét 3) · (3) **LQ M1/M4** ·
   (4) **ICT M1–M2** (bias M30) · (5) SMC M1–M3, PVEMA M4–M10 (cần kiểm tra thêm ở giai đoạn giảm/đi ngang).
3. **MM:** không đề xuất dùng với logic V4.39. Mọi TF, mọi input đều thua, tệ hơn ngẫu nhiên.
4. **Cách nhanh nhất: EA `MQL5/Experts/EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5`.** Đây là bản sao V4.39 có
   thêm input `InpMatrixBoCaiSan` chứa sẵn cả 13 bộ test dưới đây. Mặc định là kiểm chứng 6 PP cùng lúc
   (214 bộ), chỉ cần bấm Start. Kết quả từng ứng viên nằm ở `ket_qua_ung_vien.csv`. Chọn "Thủ công" thì EA chạy
   y hệt V4.39 gốc. Logic vào lệnh và quản lý lệnh không đổi. **Chưa biên dịch thử bằng MetaEditor.**
   Cách tương đương, dùng file SET kiểm chứng cho MT5 (`research/david_hunter_v439/mt5_sets/`) với EA
   `EA_DAVID_HUNTER_V4_39_MATRIX_RECONCILE_2`:
   - `V439_KIEM_CHUNG_<PP>.set` (6 file): cấu hình gốc = ứng viên hạng 1, lưới nhỏ quanh ứng viên
     (24–54 bộ, có trục TF). Chạy nhanh, nên chạy trước.
   - `V439_LUOI_DAY_DU_<PP>.set` (7 file): đúng lưới của nghiên cứu này (384–864 bộ). Chạy rất lâu. Nên chạy
     “1 minute OHLC” trước, sau đó chạy lại “Every tick based on real ticks” cho các bộ tốt.
   - Thiết lập Tester: XAUUSD của sàn đang dùng · Every tick based on real ticks · **Execution = No Delay**
     (V4.39 bắt buộc) · tài khoản Hedging · ít nhất 3–6 tháng · đặt `InpMatrixTuNgayKiemChung` = mốc tách
     2–3 tháng cuối làm dữ liệu kiểm chứng.
   - Tiêu chí nghiệm thu đề xuất: ≥100 lệnh, ≥3 tháng, có lãi ở tập kiểm chứng (`danh_gia =
     UNG_VIEN_CAN_TEST_LAI` trong `xep_hang.csv`), PF ≥ 1,3, DD chấp nhận được.
5. **Dữ liệu:** upload đủ `XAUUSDm_202601012305_202604301458.zip.part002 … part015` vào `EA-PRO/data/`
   (mỗi phần ≤ 25 MB). Khi có đủ, chạy lại lệnh ở mục 10 sẽ cho kết quả trên cả 4 tháng.
   Muốn thời gian dài hơn nữa (1–2 năm) thì xuất tick theo từng tháng cũng được.

## 10. Chạy lại

```bash
cd research/david_hunter_v439
pip install numpy pandas numba
# 1) quét lưới (đọc tự động mọi phần *.zip.part* có mặt)
python3 run_matrix.py --ticks "/duong_dan/XAUUSDm_202601012305_202604301458.zip.part*" --split 2026-03-01
# 2) xếp hạng + 3) kiểm định + 4) giải đấu ngẫu nhiên + 5) file SET MT5
python3 analyze.py && python3 validate.py && python3 null_tournament.py --reps 100 && python3 make_sets.py
# kiểm tra độ khớp với bản dịch nguyên văn MQL5
python3 tests/test_crosscheck.py && python3 tests/test_engines.py
```

## Phụ lục: file kết quả (`research/david_hunter_v439/results/`)

| File | Nội dung |
|---|---|
| `wallets_all.csv.gz` | 51.312 dòng: mỗi bộ input × hướng × phiên, đủ chỉ số (lệnh, WR, PF, net, DD, chuỗi thua, hai nửa dữ liệu…) |
| `tong_quan_pp.csv` | Tổng quan từng PP |
| `theo_khung_tf.csv` | Từng PP × từng TF: % bộ lãi, lệnh/net trung vị, cấu hình tốt nhất của TF đó |
| `ung_vien_dat_loc.csv` | Mọi tài khoản qua bộ lọc (đã gộp các bộ cho kết quả trùng nhau) |
| `de_xuat_moi_pp.csv` | Top 3 mỗi PP |
| `kiem_dinh_ung_vien.csv` | Trượt giá 0,3 và vào lệnh ngẫu nhiên cho top 3 và 4 PP live |
| `kiem_dinh_chon_loc_ngau_nhien.csv` | Giải đấu ngẫu nhiên 100 lần |
| `lenh_de_xuat.csv` | Từng lệnh của các ứng viên và 4 PP live |
| `doi_chung_4pp_live.csv` | 4 PP live cùng kỳ |
| `run_info.json` | Độ phủ dữ liệu, tham số lần chạy |
