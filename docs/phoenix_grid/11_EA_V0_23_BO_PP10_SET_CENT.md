# EA Phoenix Grid V0.23 TEST — bỏ PP10 (Fibo) + dò set cho tài khoản cent

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: TEST.**
>
> - File: [`EA_PHOENIX_GRID_V0_23_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_23_TEST.mq5), dựng
>   từ V0.21. [`EA_PHOENIX_GRID_V0_21_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5) giữ
>   nguyên để quay lại.
> - **V0.23 CHƯA compile.** Môi trường của tôi không có MetaEditor. Kiểm tra tĩnh đạt (Mục 2.3); cần bạn compile (F7).
> - **V0.22 (hedge) không phát hành**: xem [`luu_tru_khong_phat_hanh/`](../../research/phoenix_grid/luu_tru_khong_phat_hanh/)
>   và Mục 8.
> - **Chưa backtest MT5.** Số liệu ở Mục 3–8 là **mô phỏng Python** trên nến M1 (không có tick thật). Không cam kết lợi
>   nhuận.
> - **Set chọn cho tài khoản cent: [`PG_V023_CENT_500USD.set`](../../MQL5/Presets/PhoenixGrid/PG_V023_CENT_500USD.set)**
>   (500 USD = 50.000 USC, lot 0,01). Đạt DEV / VAL / TEST theo luật đăng ký trước (Mục 6). Kết luận cao nhất: **đạt sơ
>   bộ, cần forward**. Lãi mô phỏng khoảng 0,6–2 USD / ngày. **Mục tiêu 10–30 USD / ngày với DD dưới 35% cần khoảng
>   3.000–9.000 USD vốn** (Mục 6.5). Với 100 USD có đường giá cháy trước khi gấp đôi.

## 1. Yêu cầu của bạn ngày 30/09/2026

| Nội dung bạn viết | Ghi nhận |
|---|---|
| "Hãy dùng data hiện có, test mọi loại input, hệ số để tìm ra Set tốt nhất trên tài khoản cent" | Dò trên mô phỏng Python theo kế hoạch §13.9 và §14 Phương án 2: DEV → đăng ký trước → VAL → đăng ký → TEST một lần (Mục 3–7) |
| "Nếu như vậy thì phương pháp fibo vừa mang vào không có tác dụng có thể xóa đi" | Đồng ý. PP10 (Fib + Bollinger theo SET M2) chỉ có 3 tín hiệu trong 9 tháng ([`tan_suat_vao_lenh_V0_20.md`](../../research/phoenix_grid/results_mi/tan_suat_vao_lenh_V0_20.md)). Từ V0.21, PP0 mở basket 10 giây sau mỗi lần clear, nên PP10 gần như không còn lúc được xét. Đã xóa trong bản mới V0.23 (Mục 2) |
| "Hay gui toi khi chac chan khong con loi nao ca" (về V0.22) | V0.22 không gửi. Mô phỏng cho thấy hedge như thiết kế làm drawdown tệ hơn (Mục 8) |
| "Quan trong khong chay la duoc, co the tai khoan 100$-200$ va co the 500$ mien la tim ra set DD thap, tu duy thoat lenh nhanh, nhieu lenh va lai cao" | Dò lại với vốn 10.000 USC (100 USD), rồi 50.000 USC (500 USD). Thêm các chỉ số: giờ giữ basket, số basket / ngày, số lệnh (Mục 5–6) |
| "còn phải xem đc nó kiếm đc bao nhiêu tiền mỗi ngày", "bao nhiêu lot giao dịch" | Thêm: lãi trung bình / trung vị mỗi ngày, % ngày lỗ, ngày xấu nhất, tổng lot và lot mỗi ngày (Mục 6–7) |
| "trung bình kiếm 10-30$ 1 ngày và phải x 2 trước khi cháy dd dưới 35% là đạt, tối ưu thêm càng tốt" | Lần dò 500 USD dùng ngưỡng đạt DD ≤ 35%, thêm bước tối ưu lot trước TEST, chỉ số số ngày tới khi gấp đôi / tới lần cháy đầu (Mục 6–7) |

## 2. V0.23 — bỏ PP10

### 2.1 Thay đổi so với V0.21

| Phần | V0.21 | V0.23 |
|---|---|---|
| Input nhóm 3 | `InpDungPP10`, `InpPP10TF` | bỏ |
| Input nhóm 4 "PP10 — XU HƯỚNG" | `InpDungEMA`, `InpEMA`, `InpDungDocEMA`, `InpSoNenDoc`, `InpDungADX`, `InpADXChuKy`, `InpADXMin`, `InpATRMinUSD`, `InpATRChuKy` | bỏ cả nhóm |
| Input nhóm 5 "PP10 — FIBONACCI" | `InpNenHoiMax`, `InpNenHoiMin`, `InpNenNhipDay`, `InpNhipDayMinATR`, `InpFibMin`, `InpFibMax`, `InpFibDungSai`, `InpFibMatHieuLuc` | bỏ cả nhóm |
| Input nhóm 6 "PP10 — BOLLINGER VÀ NẾN XÁC NHẬN" | `InpBBChuKy`, `InpBBDoLech`, `InpNenCham`, `InpChamDungSaiATR`, `InpPinBar`, `InpEngulfing`, `InpStar`, `InpBacPinMin` | bỏ cả nhóm |
| Input nhóm 8 | `InpChanSideways` (chỉ dùng cho PP10) | bỏ |
| Chỉ báo khung M2 | EMA, ADX, ATR, Bollinger (4 handle) | bỏ |
| Hàm | `KiemTraNenPP10`, `ChiBaoPP10DaCapNhat`, `XetPP10`, `TimSetupPP10`, `NenXacNhan` | bỏ |
| `ChanTheoPhoenix` | có nhánh "sideways dành cho PP1" riêng cho PP10 | bỏ nhánh đó; chặn ngược breakout và ngược xu hướng M5 giữ nguyên |
| Log tín hiệu `tin_hieu` | 23 cột | **giữ 23 cột**; 9 cột của PP10 (`dau_nhip` … `adx_pp10`) để trống, công cụ phân tích log đọc được như cũ |
| Tên file log | `PG_V021_…` | `PG_V023_…` |

Tổng: bỏ 28 input (117 → 89), 5 hàm (140 → 135), 4 chỉ báo.

Giữ nguyên toàn bộ phần xử lý lệnh của V0.21:

- PP0 và PP1;
- DCA, tỉa, 4 cơ chế clear, không SL;
- bộ lọc Phoenix, kiểm soát volume, bảng điều khiển, trạng thái lưu.

Nhóm input đánh số 1, 2, 3, 7, 7b, 7c, 8–12. Số 4–6 bỏ trống để khớp các tài liệu cũ.

### 2.2 Nâng cấp từ V0.21 trên cùng chart

- Cùng magic 20260930, cùng khóa GlobalVariables (theo số tài khoản + magic). Basket V0.21 đang mở được V0.23 nhận lại.
- Basket mở bằng PP10 ở V0.21 (hiếm) vẫn hiện nguồn "PP10" sau khi nhận lại.
- File set của V0.21 nạp vào V0.23: MT5 bỏ qua các input không còn. Nên dùng file set V0.23 ở Mục 9.

### 2.3 Kiểm tra

- Dựng bằng script: mỗi thay thế phải khớp đúng số lần mong đợi. Sau khi dựng, không còn tên nào của PP10 trong mã.
- [`kiem_tra_tinh_mq5.py`](../../research/phoenix_grid/cong_cu_ea/kiem_tra_tinh_mq5.py) cho V0.23:
  - ngoặc cân bằng;
  - 135 hàm; không có lời gọi chưa rõ nguồn, không có hàm định nghĩa mà không gọi, không có hàm trùng;
  - không có biến dùng mà không khai báo (toàn cục và theo từng hàm);
  - không có lời gọi sai số tham số;
  - 89 input.
- **Chưa compile.** Kiểm tra tĩnh không thay được compiler. Nếu MetaEditor báo lỗi, gửi ảnh tab Errors.

## 3. Cách dò set

### 3.1 Công cụ

- [`mo_phong_phoenix.py`](../../research/phoenix_grid/mo_phong_phoenix.py): mô phỏng Python phần xử lý lệnh của EA,
  chép theo mã nguồn và theo cùng thứ tự trong một tick:
  - TP từng tầng;
  - clear cả basket: trailing clear, hòa vốn khi xuống sâu;
  - clear từng phần;
  - DCA, với giãn cách, margin level sau lệnh ≥ 500%, tối đa 1000 lệnh mỗi ngày, `InpTiaLapLai`;
  - PP0: SMA H1, chờ sau clear, chặn ngược xu hướng M5 Phoenix, không mở 15 phút trước giờ nghỉ.
- Tài khoản cent theo thông số XAUUSDc đo ở R0.1, vốn theo từng lần dò (5.000 / 10.000 / 50.000 USC):
  - spread cố định 0,26 USD;
  - swap BUY −56 USC / lot / đêm, thứ Tư ×3;
  - margin 1 lot = giá × 100 / 2000;
  - stop out 0%: vốn về 0 là **cháy**. Mô phỏng đóng hết, nạp lại đúng số vốn ban đầu và chạy tiếp để đếm số lần cháy. Lãi ròng báo cáo **đã trừ** phần mất khi cháy.
- Giá: nến M1 XAUUSDm từ 01/01 tới 27/09/2026. Chưa có tick XAUUSDc.
- Đường giá trong mỗi nến M1: mở → cực trị gần giá mở → cực trị còn lại → đóng. Mỗi đoạn được nội suy thành các bước ≤ 0,5 USD. TP khớp đúng giá TP.
- Mô phỏng **không có**: PP1, chặn và hoãn DCA theo breakout, lọc tin, lọc spread, trượt giá. Vì vậy file set tắt PP1 (`InpDungPP1=false`) để EA chạy giống phần đã mô phỏng. Các bộ lọc breakout và tin vẫn bật: chúng chỉ làm EA mở ít lệnh hơn so với mô phỏng.
- [`do_tim_set_cent.py`](../../research/phoenix_grid/do_tim_set_cent.py): dò ngẫu nhiên, láng giềng, nhiễu đường giá, VAL, TEST. Luật được ghi trong mã trước khi chạy.

### 3.2 Lượt dò đầu tiên bị dừng vì mô hình cũ lạc quan

Lượt đầu tiên dùng 4 điểm mỗi nến M1 và cho TP khớp ở giá hiện tại. Mô hình này có hai sai lệch:

- khi giá nhảy xa trong một phút, nó bỏ qua các tầng DCA ở giữa, nên giữ ít vị thế hơn EA thật;
- nó chốt TP ở giá đã vượt TP.

Hai sai lệch đều làm kết quả đẹp hơn thực tế. Lượt đó đã dừng sau 295 biến thể và không dùng kết quả. So sánh trên cùng cấu hình ở Mục 3.4.

### 3.3 Giai đoạn và luật (kế hoạch §13.9, §14 Phương án 2)

| Giai đoạn | Thời gian | Việc |
|---|---|---|
| DEV | 01/01–30/04/2026 | Dò, chọn ứng viên. Có phiên 30/01/2026 biên độ 768 USD và nhiều phiên 300–500 USD |
| (đệm) | 01–07/05 | không dùng |
| VAL | 08/05–30/06/2026 | Chạy các ứng viên đã đăng ký (commit trước), chọn tối đa 3 |
| (đệm) | 01–07/07 | không dùng |
| TEST | 08/07–27/09/2026 | Chạy **một lần** các set đã chọn (commit trước). Set chính là hạng 1 sau VAL; TEST chỉ xác nhận đạt / không đạt |

Luật đặt trước khi chạy (trong `do_tim_set_cent.py`):

- **Đạt (mức A):**
  - không cháy;
  - DD lớn nhất ≤ 30%;
  - lãi > 0;
  - bỏ 2 tháng tốt nhất vẫn ≥ 0.
- **Mức B:** không cháy, DD ≤ 50%, lãi > 0.
- **Mức C:** không cháy, lãi > 0.
- **Điểm:** lãi / DD lớn nhất (tiền). Cấu hình cháy tài khoản có điểm −1.
- **Vùng phẳng:** lấy trung vị điểm của các láng giềng một bước (đổi một input sang giá trị liền kề), không chọn đỉnh đơn lẻ.
- **Nhiễu đường giá:** chạy lại cùng cấu hình với thứ tự đỉnh / đáy trong nến M1 chọn ngẫu nhiên. Đây là phần mô phỏng không biết chắc khi không có tick thật.

### 3.4 So sánh ba mô hình đường giá (DEV, vốn 5.000 USC)

Nguồn: [`so_sanh_mo_hinh_duong_gia.csv`](../../research/phoenix_grid/results_mi/do_tim_set_cent/so_sanh_mo_hinh_duong_gia.csv).

Ba mô hình được so:

- **(a)** 4 điểm mỗi nến, TP khớp ở giá hiện tại. Đây là mô hình của lượt dò đầu, đã dừng.
- **(b)** 4 điểm mỗi nến, TP khớp đúng giá TP.
- **(c)** nội suy từng bước ≤ 0,5 USD, TP khớp đúng giá TP. Đây là mô hình dùng để dò.

| Cấu hình | Lãi (a) | Lãi (b) | Lãi (c) | DD (a) | DD (b) | DD (c) | Số lần cháy a / b / c |
|---|---|---|---|---|---|---|---|
| V0.21 mặc định (lot đều) | +8.953 | −9.079 | −18.185 | 107,8% | 114,7% | 110,7% | 1 / 3 / 4 |
| V0.21 hệ số 1,2 (set đã gửi) | +21.563 | +7.195 | +6.445 | 101,6% | 109,3% | 100,6% | 1 / 2 / 2 |
| Hệ số 1,2 + SMA200 | +27.740 | +12.793 | +5.490 | 18,4% | 101,9% | 100,5% | 0 / 1 / 2 |
| N085 (tốt nhất của lượt đầu) | +102.246 | +65.260 | +41.695 | 19,1% | 63,7% | 86,2% | 0 / 0 / 0 |
| N140 | +48.957 | +25.759 | −3.523 | 16,8% | 34,0% | 100,3% | 0 / 0 / 2 |
| N171 | +57.359 | +34.744 | +12.408 | 27,2% | 30,0% | 100,1% | 0 / 0 / 1 |
| N010 | +52.374 | +31.973 | −4.065 | 14,9% | 21,8% | 100,0% | 0 / 0 / 2 |

Các cấu hình "tốt nhất" theo mô hình cũ đều giảm lãi mạnh, và phần lớn cháy khi dùng mô hình đúng hơn. Vì vậy lượt dò đầu không được dùng.

## 4. Vốn 5.000 USC (~50 USD) / lot 0,01 — không có set an toàn (chỉ DEV)

Chi tiết: [`results_mi/do_tim_set_cent/von_5000/`](../../research/phoenix_grid/results_mi/do_tim_set_cent/von_5000/).

| Bước | Kết quả |
|---|---|
| 363 cấu hình ngẫu nhiên + tham chiếu (đường gốc) | **300 cháy** ít nhất một lần (83%). 0 cấu hình DD ≤ 30%; 6 DD ≤ 50%; 26 không cháy nhưng DD lớn hơn |
| 8 hạt giống + 194 láng giềng + 48 lần nhiễu | **0 ứng viên**. Chỉ đổi thứ tự đỉnh / đáy trong nến M1 là cùng một cấu hình lúc cháy lúc không |
| 160 cấu hình không cháy ở đường gốc × 4 đường nữa | 37 không cháy trên cả 5 đường. DD lớn nhất thấp nhất **41,9%**; không cấu hình nào ≤ 30% |
| Tham chiếu: V0.21 mặc định (lot đều) | cháy 4 lần trong DEV |
| Tham chiếu: V0.21 hệ số 1,2 (set đã gửi) | cháy 2 lần trong DEV |
| Tham chiếu: gần Hydra (bảng lot, bước nhỏ) | cháy 2 lần trong DEV |

**Kết luận:** với 5.000 USC trên mỗi 0,01 lot, không có set nào vừa không cháy vừa có DD thấp trong giai đoạn 01–04/2026.

Input làm giảm tỷ lệ cháy rõ nhất:

| Input | Tỷ lệ cháy |
|---|---|
| `InpPP0MA` = 200 | 53% (các giá trị khác 86–95%) |
| `InpSoTangToiDa` = 5 | 58% |
| `InpTiaLapLai` = false | 75% (true: 91%) |
| `InpLotTangToiDa` = 0,02 | 72% |

Ngày 30/09/2026 bạn cho biết vốn có thể 100–200 USD, hoặc 500 USD. Vì vậy các ứng viên 5.000 USC không được chạy VAL / TEST.

## 5. Vốn 10.000 USC (100 USD) / lot 0,01

Chi tiết: [`results_mi/do_tim_set_cent/von_10000/`](../../research/phoenix_grid/results_mi/do_tim_set_cent/von_10000/). Các lần đăng ký trước: commit `be553dc` (ứng viên, luật VAL / TEST), `6683600` (kết quả VAL, luật vốn cao), `d4cfe60` (kết quả vốn cao).

### 5.1 DEV

- **363 cấu hình** ngẫu nhiên và tham chiếu: **190 cháy**. 97 không cháy và có lãi.
- **97 × 4 đường giá nữa:** 75 không cháy trên cả 5 đường.
  - DD lớn nhất ≤ 20%: 0.
  - DD lớn nhất ≤ 35%: 1 (U1, 31,1%).
- **Đăng ký 5 ứng viên:**
  - U1 (N340): ít lệnh, khoảng 2,8 basket / ngày, basket giữ lâu nhất 41 ngày.
  - U2 (N029): nhiều lệnh, khoảng 24 basket / ngày, 95% basket đóng trong 2,4 giờ.
  - U3 (N044), U4 (N049), U5 (N171).
- **Thông tin, không dùng để chọn** — 16 đường giá DEV nữa:
  - U1, U2: không cháy đường nào.
  - U3, U4: cháy 3/16.
  - U5: cháy 2/16.

### 5.2 VAL (08/05–30/06/2026) — không set nào đạt

| Ứng viên | Lãi đường gốc (USC) | DD lớn nhất 5 đường | Kết quả |
|---|---|---|---|
| U4 | +3.432 | 41,6% | không đạt (> 35%) |
| U2 | +5.320 | 66,3% | không đạt |
| U1 | −3.636 | 48,6% | không đạt (lỗ) |
| U3 | −1.691 | 58,3% | không đạt (lỗ) |
| U5 | −6.131 | 100,7% | **cháy** |

Theo luật đã đăng ký, không set nào được chạy TEST ở vốn 100 USD.

### 5.3 Cùng 5 ứng viên ở vốn 200 / 500 USD (lot 0,01) — không set nào đạt

Luật đặt trước: không cháy trên 21 đường DEV và 5 đường VAL, DD ≤ 20%, lãi > 0 ở đường gốc của cả DEV và VAL.

| Ứng viên | 200 USD: DD lớn nhất / số đường cháy | 500 USD: DD lớn nhất / số đường cháy |
|---|---|---|
| U1 | 38,7% / 0 | 16,2% / 0 — nhưng lỗ ở VAL |
| U2 | 51,4% / 0 | 25,7% / 0 |
| U3 | 100% / 3 | 48,3% / 0 |
| U4 | 66,7% / 0 | 29,0% / 0 |
| U5 | 100% / 4 | 100% / 1 |

Vốn lớn hơn làm margin level ít chặn DCA hơn, nên EA mở thêm lot khi giá đi ngược. Vì vậy DD tính bằng tiền **không** giữ nguyên khi tăng vốn, và DD % giảm ít hơn tỷ lệ tăng vốn.

## 6. Vốn 50.000 USC (500 USD) / lot 0,01 — theo tiêu chí của bạn

Chi tiết: [`results_mi/do_tim_set_cent/von_50000/`](../../research/phoenix_grid/results_mi/do_tim_set_cent/von_50000/).

Các commit đăng ký trước:

| Commit | Nội dung |
|---|---|
| `769335c` | Tiêu chí mới: đạt = DD ≤ 35%, bước tối ưu lot, chỉ số gấp đôi / cháy. Ghi trước khi xem xếp hạng |
| `b9a976a` | Ứng viên sau DEV |
| `4ffd349` | Kết quả VAL, set chọn |

### 6.1 DEV

- **363 cấu hình (đường gốc):** 21 cháy; 239 không cháy và có lãi.
- **239 × 4 đường nữa:** 223 không cháy trên cả 5 đường.
  - DD lớn nhất ≤ 35%: 130 cấu hình.
  - DD lớn nhất ≤ 50%: 32.
  - DD lớn nhất cao hơn: 61.
- **5 ứng viên:** đứng đầu theo điểm vùng. Điểm vùng là trung vị lãi / DD của 5 đường giá và 23–27 láng giềng.

| Ứng viên | Cấu hình (lot 0,01) | DD lớn nhất (5 đường) | Lãi / ngày (DEV, đường gốc) | Basket / ngày | 95% basket đóng trong | Lot giao dịch / ngày |
|---|---|---|---|---|---|---|
| U1 (N029) | ×1,15 trần 0,05; tầng max(8; 0,5×ATR) × 20; SMA200 | 23,5% | 214 USC ≈ 2,14 USD | 24 | 2,4 giờ | 0,76 |
| U2 (N188) | ×1,3 trần 0,1; tầng max(4,5; 0,5×ATR) × 30; SMA50 + lọc M5 | 30,7% | 367 USC ≈ 3,67 USD | 99 | 0,6 giờ | 4,48 |
| U3 (N044) | bảng Hydra trần 0,02; tầng max(15; 2×ATR) × 40; SMA200 | 24,2% | 128 USC | 13 | 5,6 giờ | 0,23 |
| U4 (N112) | ×1,2 trần 0,5; tầng max(20; 0,5×ATR) × 40; SMA100 | 26,3% | 196 USC ≈ 1,96 USD | 29 | 2,7 giờ | 0,51 |
| U5 (N171) | ×1,15 trần 0,1; tầng max(1,5; 0,8×ATR) × 40; SMA20 | 24,3% | 209 USC | 65 | 1,0 giờ | 3,02 |

**Thông tin, không dùng để chọn** — 16 đường giá DEV nữa:

| Ứng viên | Kết quả |
|---|---|
| U1 | DD lớn nhất 25,7% |
| U4 | DD lớn nhất 26,4% |
| U2 | DD lớn nhất 43,4% |
| U3 | DD lớn nhất 48,3% |
| U5 | cháy 1 đường |

### 6.2 VAL (08/05–30/06/2026)

| Ứng viên | Lãi đường gốc | DD lớn nhất 5 đường | Kết quả |
|---|---|---|---|
| **U4** | +3.311 USC | 4,8% | **đạt — hạng 1 (set chính)** |
| **U1** | +5.320 USC | 14,2% | **đạt — hạng 2** |
| U3 | −1.691 USC | 13,9% | không đạt (lỗ) |
| U5 | +5.998 USC | 98,8% | không đạt |
| U2 | −47.300 USC | 100% | **cháy** |

Set nhiều lệnh nhất và lãi DEV cao nhất (U2: 99 basket / ngày, 4,5 lot / ngày) lại cháy ngay ở VAL. Nhiều lệnh và thoát nhanh không có nghĩa là an toàn.

### 6.3 Tối ưu lot (DEV 21 đường + VAL 5 đường, vốn 500 USD)

Luật: tăng lot tầng 0 dần từ 0,01. Trần lot mỗi tầng nhân theo cùng hệ số. Lấy mức lot lớn nhất mà vẫn không cháy, DD ≤ 35% và có lãi.

| Set | Lot tầng 0 | Số đường cháy | DD lớn nhất | Lãi / ngày DEV (đường gốc) | Lãi / ngày VAL (đường gốc) | Kết quả |
|---|---|---|---|---|---|---|
| U4 | **0,01** | 0 / 26 | 26,4% | 196 USC | 72 USC | **đạt** |
| U4 | 0,02 | 0 / 26 | 51,4% | 385 USC | 150 USC | không đạt (DD) |
| U1 | 0,01 | 0 / 26 | 25,7% | 214 USC | 116 USC | đạt |
| U1 | 0,02 | **2** / 26 | 100% | 356 USC | 213 USC | không đạt (**cháy**) |

→ Ở vốn 500 USD, **lot 0,01** là mức lớn nhất đạt tiêu chí. Set chính cho TEST: U4 lot 0,01 (đăng ký ở commit `ead4a98`).

### 6.4 TEST (08/07–27/09/2026) — chạy **một lần**: ĐẠT

| Đường giá | Lãi (USC) | DD lớn nhất | Cháy | Lãi TB / ngày | % ngày lỗ | Lot / ngày | Basket / ngày | 95% basket đóng trong |
|---|---|---|---|---|---|---|---|---|
| gốc | +4.436 | 4,2% | 0 | 63 USC | 18,6% | 0,23 | 18 | 6,1 giờ |
| 4 đường nhiễu | +5.254 … +5.562 | 4,2% | 0 | 75–79 USC | 18,6–20% | 0,29–0,31 | 24–25 | 4,0–4,1 giờ |

Ở đường gốc: không tháng nào lỗ; ngày xấu nhất −1.046 USC; ngày tốt nhất +1.274 USC. Trung vị một basket đóng sau khoảng 7 phút; basket giữ lâu nhất 78 giờ; tối đa 0,31 lot mở cùng lúc.

### 6.5 Tiền mỗi ngày, số lot, gấp đôi — cả 9 tháng, 5 đường giá (tham khảo)

Tham khảo, không dùng để chọn: cùng set U4, đổi vốn và lot (trần lot nhân cùng hệ số), cả 01/01–27/09/2026, 5 đường giá ([`quy_doi_von_hang1_9thang_tom_tat.csv`](../../research/phoenix_grid/results_mi/do_tim_set_cent/von_50000/quy_doi_von_hang1_9thang_tom_tat.csv)).

| Vốn | Lot tầng 0 | Đường cháy / 5 | DD lớn nhất | Lãi TB / ngày (đường gốc) | Lot / ngày | Gấp đôi sau (đường gốc) | Cháy sớm nhất |
|---|---|---|---|---|---|---|---|
| 100 USD | 0,01 | **2** | 100% | 1,23 USD | 0,36 | 44 ngày | **ngày 21** — cháy trước khi gấp đôi |
| 200 USD | 0,01 | 0 | 60,8% | 1,23 USD | 0,36 | 110 ngày | — |
| **500 USD** | **0,01** | **0** | **26,3%** | **1,23 USD** | **0,36** | chưa trong 9 tháng | — |
| 500 USD | 0,02 | 0 | 51,4% | 2,47 USD | 0,73 | 200 ngày | — |
| 500 USD | 0,05 | **1** | 100% | 6,42 USD | 1,94 | 43 ngày | ngày 21 |
| 500 USD | 0,08 | **4** | 100% | 7,87 USD | 3,14 | 61 ngày | ngày 13 |
| 3.000 USD | 0,08 | 0 | 30,3% | **10,2 USD** | 3,15 | — | — |
| 9.000 USD | 0,24 | 0 | 35,6% | **30,6 USD** | 9,27 | — | — |

Ghi chú:

- Lãi trung bình mỗi ngày tính theo Equity cuối ngày, tức đã gồm cả lệnh đang thả nổi. Lãi thay đổi mạnh theo giai đoạn: với lot 0,01 là khoảng 1,96 USD / ngày ở 01–04, 0,72 ở 05–06 và 0,63 ở 07–09.
- **Mục tiêu 10–30 USD / ngày với DD dưới 35%:** trong mô phỏng, set này cần khoảng **3.000 USD** (lot 0,08) cho 10 USD / ngày và khoảng **9.000 USD** (lot 0,24) cho 30 USD / ngày.
- **Với 100–500 USD:**
  - Muốn DD dưới 35% và không cháy thì chỉ khoảng 0,6–2 USD / ngày, ứng với 500 USD và lot 0,01.
  - Lấy lot lớn hơn thì có đường giá cháy **trước** khi gấp đôi, nên không đạt điều kiện "x2 trước khi cháy".
  - 100 USD, lot 0,01: có đường giá cháy ở ngày 21 (phiên sập 30/01/2026).

## 7. File set và cách dùng

| File | Dùng cho |
|---|---|
| [`PG_V023_CENT_500USD.set`](../../MQL5/Presets/PhoenixGrid/PG_V023_CENT_500USD.set) | EA V0.23 (chưa compile) |
| [`PG_V021_CENT_500USD.set`](../../MQL5/Presets/PhoenixGrid/PG_V021_CENT_500USD.set) | EA V0.21 (đã compile), cùng set, thêm `InpDungPP10=false` |
| [`goi_cai_dat/PhoenixGrid_V0_23_CENT_500USD.zip`](../../goi_cai_dat/PhoenixGrid_V0_23_CENT_500USD.zip) | Gói cài đặt: 2 EA + 2 set + hướng dẫn `HUONG_DAN_CENT_500USD.txt` |

Giá trị khác mặc định của V0.21 / V0.23:

| Input | Giá trị | Nghĩa |
|---|---|---|
| `InpLotCoSo` | 0,01 | lot tầng 0 |
| `InpHeSoLot` / `InpDungBangLot` | 1,2 / false | mỗi tầng nhân 1,2 |
| `InpLotTangToiDa` | 0,5 | trần lot một tầng |
| `InpBuocMinUSD` / `InpBuocATR` | 20 / 0,5 | khoảng tầng = max(20 USD; 0,5 × ATR M5) |
| `InpSoTangToiDa` | 40 | tối đa 40 tầng |
| `InpTiaTPBuoc` | 2,0 | TP tỉa mỗi tầng = 2 khoảng tầng |
| `InpGioTPATR` | 0,5 | mốc clear basket = 0,5 × ATR M5 × giá trị 1 USD của lot tầng 0 |
| `InpTrailClear` / `InpTrailGiuPT` | true / 60 | trailing clear, giữ 60% lãi đỉnh |
| `InpHoaVonTuTang` | 8 | từ tầng 8 clear khi hòa vốn |
| `InpXoaTangLo` / `InpXoaTuSoTang` / `InpXoaGomLai` | true / 2 / 2 | clear từng phần từ 2 tầng, gộp tối đa 2 tầng lãi |
| `InpChanNguocXH` | false | không chặn ngược xu hướng M5 |
| `InpPP0MA` | 100 | hướng lệnh đầu theo SMA100 H1 |
| `InpGiayGiuaDCA` | 180 | hai lệnh DCA cách nhau ít nhất 180 giây |
| `InpTiaLapLai` / `InpGiayChoSauClear` | true / 10 | như V0.21 |
| `InpDungPP1` | false | tắt PP1 để giống mô phỏng |
| `InpBaoVeVonPT`, `InpDDDungMoiPT`, `InpSauTuTang` | 0 | không cắt lệnh theo DD, không dừng lỗ |
| `InpChoPhepTKThat` | true | **gửi lệnh trên tài khoản thật** |

Cách chạy nên theo:

1. Compile V0.23 (F7). Nếu có lỗi thì dùng V0.21 với file `PG_V021_CENT_500USD.set` và gửi ảnh tab Errors.
2. **Chạy demo trước.** Exness Standard demo 50.000 USD với lot 0,01 có cùng tỷ lệ rủi ro như cent 500 USD.
3. Chạy trên tài khoản cent riêng cho Phoenix. Không chạy chung tài khoản với Hydra.

## 8. Tham khảo: hedge V0.22 (không phát hành)

Chạy trên DEV với vốn 500 USD, đường giá gốc, cho 3 ứng viên:

| Ứng viên | Không hedge | Hedge V0.22 | Hedge từ 15 tầng, không giảm cấp, khóa DCA |
|---|---|---|---|
| U1 | +21.838 USC, DD 14,6% | +8.901, DD 9,7% | +4.980, DD 7,2% (basket bị khóa 1.951 giờ) |
| U2 | +37.478, DD 30,7% | **−3.671**, DD 20,9% | **−9.050**, DD 23,3% |
| U3 | +13.030, DD 7,5% | +7.045, DD 12,6% | +11.220, DD 7,5% |

Hedge có khi giảm DD nhưng cắt lãi rất mạnh, có khi còn làm lỗ. V0.22 vì vậy không phát hành ([`luu_tru_khong_phat_hanh/`](../../research/phoenix_grid/luu_tru_khong_phat_hanh/)).

## 9. Giới hạn và việc tiếp theo

- **Đây là mô phỏng Python, chưa phải backtest MT5.**
  - Chưa có tick XAUUSDc; đường giá trong nến M1 được nội suy.
  - Không có PP1 (đã tắt trong set), chặn / hoãn DCA theo breakout, lọc tin, lọc spread, trượt giá.
  - Thứ tự đỉnh / đáy trong nến đổi là kết quả có thể lật từ không cháy sang cháy (Mục 4). Vì vậy set được chọn theo độ bền trên nhiều đường giá, không theo một đường.
- **Kết luận cao nhất: đạt sơ bộ, cần forward dài hơn.** VAL đã được xem ở lần dò 100 USD. TEST (07–09/2026) là kiểm định sạch duy nhất và chỉ chạy một lần.
- **Việc tiếp theo:**
  - chạy MT5 Strategy Tester với "Every tick based on real ticks" trên XAUUSDc cho V0.23 + set này;
  - chạy demo 50.000 USD ít nhất vài tuần;
  - gửi log `PG_V023_…` để so với mô phỏng.
- **Không cam kết lợi nhuận.** Trong mô phỏng, lot lớn hơn hoặc vốn nhỏ hơn làm tăng rõ rủi ro cháy (Mục 6.5).
