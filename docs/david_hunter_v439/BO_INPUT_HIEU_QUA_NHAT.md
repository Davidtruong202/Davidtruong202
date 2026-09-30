# Bộ input hiệu quả nhất theo dữ liệu hiện có (29/09/2026)

Nguồn: lượt MT5 9 tháng `EA-PRO/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/` (tick thật Exness XAUUSDm,
01/01 → 27/09/2026, 2.568 ví). Sàng lọc: `research/david_hunter_v439/sang_loc_mt5.py` →
`results_mt5/sang_loc_9_thang.csv.gz` và `sang_loc_walk_forward.csv`.

## 1. Bộ input

**EMA · chỉ SELL · chỉ phiên Á (0–8h giờ server) · vào lệnh M1 · EMA 7/50 · lọc xu hướng M15**

| Input | Giá trị | Ý nghĩa |
|---|---|---|
| `InpTimeframe` | **M1** | Khung vào lệnh |
| `InpFastEMA` / `InpSlowEMA` | **7 / 50** | Giao cắt EMA trên M1 |
| `InpEMAKhungLoc` | **M15** | Khung lọc hướng: EMA 34/89 M15 (`InpEMADungLocM5 = true`) |
| `InpEMAMucRetest` | 0 = EMA nhanh | Sau giao cắt, chờ giá hồi về EMA 7 rồi mới vào |
| `InpEMAKhoangDiXaToiThieuATR` | 0,35 | Giá phải chạy xa EMA tối thiểu 0,35 ATR trước khi hồi |
| `InpMinDirectionEfficiency` | **0,10** | Hiệu suất hướng tối thiểu của sóng |
| Hướng / phiên | **SELL / Á** | Ví "SELL – A" của MATRIX: bỏ mọi BUY, chỉ vào lệnh 0:00–7:59 |
| Các input EMA khác | mặc định V4.39 | Dung sai retest 0,20 · hết hạn 24 nến · SL theo đỉnh 5 nến · lọc sóng 12 nến (2,0 ATR, 0,65 ATR) · bỏ giao cắt mới trong 8 nến · nửa ngoài biên · dốc EMA chậm ngược ≤ 0,08 ATR |
| Quản lý lệnh (LAB, cố định) | – | SL 5–20 giá · TP1 = 1R chốt 50%, dời SL về hòa vốn · trailing 1R · TP2 = 1,5R (RR phiên Á) · lot 0,02 · spread ≤ 0,5 · mỗi lúc 1 lệnh |

## 2. Kết quả MT5 9 tháng (lot 0,02, USD)

116 lệnh · thắng 73 / thua 43 · **WR 62,9%** (cận dưới 95%: 53,9%) · **PF 1,69** · **net +349,0** ·
sụt vốn lớn nhất 87,1 · chuỗi thua dài nhất 3 · swap 0 (lệnh SELL) · **lãi cả 9/9 tháng**.

| Tháng | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 |
|---|---|---|---|---|---|---|---|---|---|
| Lệnh | 10 | 6 | 22 | 17 | 13 | 18 | 11 | 8 | 11 |
| WR | 60% | 50% | 64% | 76% | 54% | 61% | 64% | 63% | 64% |
| Net | +12,5 | +2,8 | +83,4 | +91,6 | +17,9 | +40,7 | +35,3 | +28,9 | +36,0 |
| Giá vàng trong tháng | +13,0% | +10,1% | −11,7% | −1,5% | −1,9% | −11,8% | +1,0% | +9,3% | −4,3% |

Ở ba tháng vàng tăng mạnh (T1, T2, T8), bộ này vào ít lệnh (6–10 lệnh) nhưng vẫn lãi nhẹ. Lý do là bộ lọc M15
chặn lệnh SELL khi xu hướng đang tăng. Bộ này lãi nhiều nhất ở các tháng giảm hoặc đi ngang.

**Các bộ lân cận** (đổi 1 input, cùng SELL / Á) cũng có lãi, trừ bộ dùng EMA nhanh 12:

| Đổi input | Lệnh | WR | PF | Net 9 tháng |
|---|---|---|---|---|
| DirEff 0,22 | 99 | 66,7% | 1,98 | +374,4 |
| EMA chậm 34 | 136 | 60,3% | 1,37 | +245,5 |
| Lọc M5 | 105 | 59,0% | 1,39 | +196,5 |
| Vào M2 | 45 | 53,3% | 1,32 | +87,7 |
| EMA nhanh 12 | 126 | 50,0% | 0,95 | −34,7 |

## 3. Cách chọn

Chỉ dùng **một quy tắc cố định** cho cả 2.568 ví, không chọn tay:

1. Ít nhất 100 lệnh trong 9 tháng (đây là ngưỡng của chính EA).
2. Có lãi, và vẫn còn lãi sau khi bỏ tháng tốt nhất.
3. Ít nhất 2/3 số tháng có lãi.
4. Ít nhất 60% bộ lân cận có lãi. Bộ lân cận là bộ đổi 1 input 1 nấc, cùng hướng và cùng phiên.
5. Xếp theo **cận dưới 95% của WR** (Wilson), rồi đến USD mỗi lệnh.

Có 170/2.568 ví qua cả 4 điều kiện lọc. Bộ trên đứng hạng 1. Hạng 2–5 lần lượt là EMA SELL Á với EMA 7/34;
SMC SELL phiên Âu với bias M15; SMC SELL phiên Âu với bias M30; và SMC SELL phiên Á M2.

## 4. Quy tắc này có đáng tin không?

Để kiểm tra, áp đúng quy tắc trên cho các tháng đầu rồi xem kết quả ở các tháng sau, là những tháng quy tắc chưa
nhìn thấy:

| Chọn trên | Kiểm trên | Hạng 1: net | Top 5: net TB (% ví lãi) | Top 10: net TB (% ví lãi) | Ví trung vị |
|---|---|---|---|---|---|
| T1–T3 | T4–T6 | −25 | +184 (80%) | +201 (90%) | −34 (40%) |
| T4–T6 | T7–T9 | −136 | −11 (40%) | +5 (50%) | −43 (36%) |
| T1–T6 | T7–T9 | **+137** (chính là vùng bộ này, ví 346) | −24 (40%) | −4 (50%) | −43 (36%) |
| T1–T3 | T4–T9 | −154 | +17 (40%) | +117 (70%) | −76 (34%) |

- Các ví do quy tắc chọn ra luôn tốt hơn ví trung bình, nhưng **một ví đơn lẻ vẫn là canh bạc**: hạng 1 chỉ có lãi
  ở 1/4 lần thử.
- Lần có lãi đó lại chính là vùng "EMA 7/50, SELL, phiên Á". Bộ 166 đứng hạng 20 khi chọn trên T4–T6, hạng 5 khi
  chọn trên T1–T6, và hạng 1 khi chọn trên cả 9 tháng.
- Kết luận: đây là **bộ tốt nhất mà dữ liệu hiện có chỉ ra được**. Tuy vậy, chưa đủ bằng chứng để coi là lợi thế
  chắc chắn.

## 5. Lịch sử từng lệnh

Lượt MT5 này không có file lệnh riêng của ví 166. File `lenh_mo_phong.csv` nặng 632 MB và chưa được tải lên.
Mình đã thử dựng lại lệnh bằng bản Python chạy trên nến M1 của MT5 (`dung_lai_lenh_m1.py`), nhưng cách này
không đủ chính xác cho từng lệnh:

- Tương quan net theo tháng với MT5 chỉ đạt 0,77.
- Số lệnh gấp 1,6 lần MT5.
- Trên cùng đoạn tick thật 06–12/01, bản dựng lại tìm được 19/20 lệnh thật nhưng sinh thêm 8 lệnh ảo.

Vì vậy **chưa thêm bộ lọc giờ hay ngày nào**. Lịch sử lệnh thật sẽ có sau khi chạy mục 6.

## 6. Chạy trong MT5

EA `MQL5/Experts/EA_DAVID_HUNTER_V4_39_MATRIX_7PP.mq5`, bản mới. Bộ cài sẵn mặc định giờ là
**`BO_HIEU_QUA_NHAT`**, nên chỉ cần bấm Start:

- Chỉ chạy đúng 1 bộ input này, gồm 12 ví hướng × phiên. **Ví 10 = SELL/Á = bộ được chọn**, đồng thời là ví
  đặt lệnh thật trong Tester. Vì vậy Graph, tab Deals và báo cáo Tester là **đúng lịch sử lệnh của bộ này**.
- Cài đặt Tester như lần trước: XAUUSDm, Every tick based on real ticks, Execution No Delay.
  Nên đặt `InpMatrixTuNgayKiemChung = 2026.07.01`.
- Kết quả nằm ở `Common\Files\DH_V439_7PP_HieuQuaNhat\RUN_…`. Nếu chạy cùng khoảng ngày như lần trước
  (01/01–27/09/2026), ví 10 phải ra đúng 116 lệnh và +349,0 USD. Nếu khớp, bạn tải lên `lenh_tham_chieu_MT5.csv`,
  `ket_qua_thang.csv`, `xep_hang.csv` và `thong_tin_run.csv` (đều nhỏ) để phân tích từng lệnh theo giờ, chuỗi thua
  và kiểu thoát lệnh.
- Muốn chạy lại kiểm chứng 6 PP thì chọn `BO_KIEM_CHUNG_6PP` trong input "0. BỘ CÀI SẴN".

## 7. Giới hạn

- Bộ này được chọn trên chính 9 tháng dữ liệu (trong mẫu). Cần kiểm lại trên dữ liệu T10–T12/2026 trước khi
  dùng tiền thật.
- Khoảng 13 lệnh mỗi tháng. Lợi nhuận nhỏ: +349 USD với lot 0,02 trong 9 tháng.
- Kết quả phụ thuộc hướng SELL. Nếu vàng tăng mạnh kéo dài, bộ này sẽ ít lệnh hoặc lỗ.
- Bản live V4.52 không còn module EMA. Muốn chạy live phải đưa module EMA trở lại theo quy trình trong `AGENTS.md`
  của EA-PRO: bản mới, backtest, so với Baseline, không đưa thẳng lên Real.
