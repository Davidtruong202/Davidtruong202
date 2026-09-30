# EA Phoenix Grid V0.20 TEST — DCA + tỉa lệnh tuần hoàn + clear chu kỳ, không cắt lỗ

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: TEST.**
>
> - File: [`EA_PHOENIX_GRID_V0_20_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_20_TEST.mq5). Đây là bản
>   đầu tiên **có gửi lệnh**. V0.11 và V0.10 (quan sát) giữ nguyên để rollback.
> - **Chưa compile.** Môi trường của tôi không có MetaEditor. Kiểm tra tĩnh đạt (Mục 10), nhưng kiểm tra tĩnh không
>   thay được compile.
> - **Chưa backtest.** Không có con số hiệu suất nào trong tài liệu này. Các con số ở Mục 3 và Mục 9 là phép tính số
>   học từ giả định, không phải kết quả giao dịch.
> - Không cam kết lợi nhuận. Không có SL: nếu giá đi ngược đủ xa, tài khoản cháy (Mục 9).

## 1. Quyết định của bạn ngày 30/09/2026

| Nội dung bạn viết | Ghi nhận |
|---|---|
| "tôi duyệt và chuyển thành EA chạy real ngay" | Bỏ qua cổng nghiên cứu A và forward demo G3 của kế hoạch PG-R0.0 (Mục 13, Mục 18) cho riêng bản này. Tiêu chí nghiệm thu đã đóng băng không đổi; V0.20 **chưa** qua tiêu chí nào |
| "Phoenix là DCA và tỉa lệnh tuần hoàn tới khi nào bị cháy tài khoản thì nạp lại, không cắt lỗ" | Không SL. Thay điểm 2 Mục 21 (lỗ ngày 10%, tầng DD) và ngân sách r_b = 1% của kế hoạch cho bản này. Chấp nhận khả năng cháy tài khoản |
| "Tôi cho phép thiết lập trên mọi loại tài khoản Real, Demo" | EA gửi lệnh trên tài khoản thật, demo và Strategy Tester. Input `InpChoPhepTKThat = true` ghi lại quyết định; đặt `false` để chặn tài khoản thật |
| "tối ưu entry lệnh đầu và bộ pp + kiểm soát volume"; SET M2_FIBO | PP10 dựng lại từ tham số SET (Mục 5); PP1 theo hộp sideways của Phoenix; kiểm soát volume ở Mục 4 |
| "Quan trọng nhất là tư duy clear lệnh để bắt đầu chu kỳ mới, sao cho DD chuỗi DCA thấp nhất. Có thể mặc định lot nhỏ nhất 0,01" | Bốn cơ chế clear (Mục 3); lot mặc định 0,01 đều |
| Ảnh input Hydra 4.5 VIP, "Tham khảo thêm và hoàn thiện EA" | Lấy các ý phù hợp (Mục 6). Không có mã nguồn Hydra, chỉ có ảnh input |

Giữ nguyên: không dùng backcom trong mọi quyết định và phép tính; thông số hợp đồng, tick value, bước lot, margin đọc
trực tiếp từ MT5; không martingale không trần (lot đều mặc định; bảng hệ số có trần lot mỗi tầng và trần số tầng).

## 2. Luồng hoạt động

```
Tick ─► nạp mọi tick mới ─► nhận diện Phoenix (hộp M5, breakout theo tick) ─► QUẢN LÝ BASKET ─► PP10 (nến M2) ─► PP1 (nến M1)
Mỗi giây ─► spread, bộ lọc, tài khoản, quyền gửi lệnh, rủi ro, đối chiếu basket, lịch tin, bảng
```

1. **Lệnh đầu basket (tầng 0).** Chỉ khi chưa có basket. Có hai phương pháp:
   - **PP10:** Fib + Bollinger hồi thuận xu hướng trên M2, theo SET M2_FIBO (Mục 5). Mặc định không vào khi Phoenix
     nhận SIDEWAYS / VÙNG MỚI.
   - **PP1:** vào gần biên hộp khi Phoenix nhận SIDEWAYS / VÙNG MỚI và chưa có breakout. Cần một nến M1 từ chối:
     chạm vùng biên, rồi đóng cửa ở 40% phía ngược lại của biên độ nến.

   Cả hai chịu bộ lọc Phoenix: không vào ngược breakout đang cảnh báo / xác nhận, không vào ngược xu hướng M5.
   Ngoài ra chịu các bộ lọc chung: spread, phiên, mất tick, tin USD quan trọng, số lệnh trong ngày, margin.
2. **DCA.** Khoảng tầng = max(6 USD, 1,15 × ATR M5 lúc mở basket), cố định suốt basket. Tầng i nằm ở giá
   P0 − hướng × i × khoảng tầng. Mỗi lần giá vượt qua một hoặc nhiều mức tầng theo chiều ngược, EA chỉ mở **một**
   lệnh, ở tầng sâu nhất vừa vượt. Không mở dồn nhiều tầng cùng lúc.

   Điều kiện để mở tầng:
   - cách lệnh DCA trước ít nhất 20 giây;
   - spread đạt;
   - margin level sau lệnh ≥ 500%.

   EA hoãn DCA khi Phoenix báo breakout ngược basket. Tầng đang chờ được giữ trong lúc giá còn ở ngoài mức tầng; giá
   quay lại phía có lời thì bỏ chờ.
3. **Tỉa tuần hoàn.** Mỗi tầng có TP phía server tại mức của tầng liền trên (1 khoảng tầng). Giá quay lại là tầng
   được chốt; giá xuống lại qua mức tầng thì tầng được mở lại.
4. **Clear** (Mục 3).
5. **Không SL.** Basket kết thúc bằng một trong các cách:
   - clear;
   - nút bấm;
   - hết tầng do TP;
   - stop out của sàn.

## 3. Tư duy clear chu kỳ — DD chuỗi DCA thấp nhất

### 3.1. Vì sao lot đều khó clear sớm, và vì sao vẫn chọn lot đều làm mặc định

Phép tính dưới đây giả định: khoảng tầng 6 USD, lot gốc 0,01, 1 lot = 100 USC / 1 USD, vốn 5.000 USC, stop out 0%.
Bỏ qua spread và phần lãi tỉa.

| Cách chia lot | Sâu 24 USD (5 tầng): giá phải hồi | Sâu 66 USD (12 tầng): giá phải hồi | Lỗ thả nổi tại đáy (12 tầng) | Giá ngược tới cháy |
|---|---|---|---|---|
| **Lot đều 0,01 (mặc định)** | 12,0 USD (50%) | 33,0 USD (50%) | 396 USC | **242 USD** |
| × 1,1 tới tầng 10 | 12,0 USD (50%) | 25,1 USD (38%) | 528 USC | 166 USD |
| Bảng Hydra (1,2 / 1,05 / 1,5 / 1,05 / 1,3) | 9,4 USD (39%) | 24,4 USD (37%) | 708 USC | 127 USD |
| × 1,2 mỗi tầng | 9,4 USD (39%) | 20,7 USD (31%) | 786 USC | 115 USD |

Nhận xét của bạn đúng: với lot đều, giá phải hồi **một nửa độ sâu chuỗi** mới hòa vốn. Hệ số lot kéo điểm hòa vốn
lại gần, nhưng làm DD ở mọi độ sâu lớn hơn và **cháy sớm gấp đôi**. Hệ số lot không bớt rủi ro, chỉ đổi dạng rủi ro.

Vì mục tiêu là "DD chuỗi DCA thấp nhất", mặc định giữ lot đều 0,01. Việc clear sớm được giao cho các cơ chế dưới đây,
vì chúng không đòi giá hồi sâu. Bảng hệ số theo cấp kiểu Hydra có sẵn để thử (`InpDungBangLot`), mặc định tắt.

### 3.2. Bốn cơ chế clear (theo thứ tự xét mỗi tick)

| # | Cơ chế | Khi nào | Input |
|---|---|---|---|
| 1 | **Trailing clear** | Lãi ròng basket (đã chốt + thả nổi) đạt mốc = 1,0 × ATR M5 × giá trị 1 USD của lot tầng 0 thì kích hoạt, để lãi chạy tiếp. Đóng cả basket khi lãi ròng tụt về 60% đỉnh | `InpGioTPATR`, `InpTrailClear`, `InpTrailGiuPT` |
| 2 | **Hòa vốn khi sâu** | Basket đã xuống tới tầng 4: đóng cả basket ngay khi lãi ròng ≥ 0 | `InpHoaVonTuTang` |
| 3 | **Clear khi rất sâu** (tùy chọn) | Xuống tới tầng N: đóng khi lãi ròng ≥ mức bạn đặt, có thể âm | `InpSauTuTang` (0 = tắt), `InpSauMucRong` |
| 4 | **Clear từng phần** | Basket có ≥ 3 tầng mở. Quỹ = lãi tỉa đã chốt + tối đa 4 tầng đang lãi nhiều nhất (dùng ít tầng nhất). Quỹ đủ trả lỗ tầng đang lỗ nhiều nhất thì đóng cả nhóm. Lot mở giảm, lãi ròng basket không đổi. Tầng sâu nhất luôn được giữ | `InpXoaTangLo`, `InpXoaTuSoTang`, `InpXoaGomLai`, `InpXoaLaiToiThieu` |

Ví dụ cơ chế 4: basket BUY có 4 tầng. Tầng 3 đã tỉa hai lần, tổng +12 USC. Tầng 0 đang −12 USC. Quỹ 12 − 12 ≥ 0, nên
EA đóng tầng 0. Lot mở giảm từ 0,03 xuống 0,02, và từ đây mỗi USD giá đi ngược lỗ ít hơn 1/3.

Clear xong, EA chờ 10 giây rồi mới mở basket mới (`InpGiayChoSauClear`).

## 4. Kiểm soát volume

| Lớp | Mặc định |
|---|---|
| Lot tầng 0 | 0,01. Nếu symbol có lot tối thiểu lớn hơn, EA dùng lot tối thiểu và báo trên bảng |
| Hệ số lot | 1,0 (lot đều). Bảng hệ số theo cấp tắt |
| Lot tối đa một tầng | 0,50 |
| Số tầng tối đa | 40 (tầng 0 là lệnh đầu) |
| Margin level sau lệnh | ≥ 500%, còn free margin, không vượt `SYMBOL_VOLUME_LIMIT` |
| Giãn cách DCA | 20 giây |
| Hoãn DCA | Khi Phoenix báo breakout ngược basket |
| Số lệnh mở mỗi ngày | 200 |
| Không mở basket mới khi DD ≥ % | Tắt (0) |
| Bảo vệ vốn: đóng hết và tạm dừng khi DD ≥ % | Tắt (0), đúng ý "không cắt lỗ". Hydra đặt 20% |
| Sau stop out | Không mở basket / tầng mới tới khi nạp tiền (tự mở khóa) hoặc bấm TIẾP TỤC |

## 5. PP10 — cách hiểu SET M2_FIBO

Không có mã nguồn VuTru_Fibo_BB_Pullback. Dưới đây là cách tôi hiểu từng tham số. Mọi mục có thể sai so với EA gốc.

| Tham số SET | Giá trị | Cách hiểu trong V0.20 |
|---|---|---|
| InpTrendEMA / InpUseEMASlope / InpSlopeBars | 53 / bật / 12 | BUY khi Close[1] > EMA53[1] và EMA53[1] > EMA53[13]; SELL ngược lại |
| InpADXMin | 27 | ADX14[1] ≥ 27 |
| InpMinATRPips | 30 | ATR14[1] ≥ 0,30 USD, **giả định 1 pip = 0,01 USD** (XAUUSDc 3 chữ số). Nếu EA gốc hiểu 1 pip = 0,1 USD thì ngưỡng là 3,0 USD, và bộ lọc này chặn khoảng một nửa số nến M2 |
| InpImpulseBars | 52 | Cửa sổ 52 nến. Điểm cuối nhịp = đỉnh cao nhất (BUY) trong cửa sổ; điểm đầu = đáy thấp nhất trước đỉnh |
| InpMinPullbackBars / InpMaxPullbackBars | 4 / 9 | Số nến từ điểm cuối nhịp tới nến tín hiệu nằm trong 4…9 |
| InpMinImpulseATR | 3 | Nhịp ≥ 3 × ATR |
| InpFibZoneMin / Max / Tolerance | 0,5 / 0,618 / 0,05 | Độ hồi của giá đóng nến tín hiệu nằm trong 0,45…0,668 (InpCloseBackZone = true: xét giá đóng) |
| InpFibInvalid | 0,786 | Điểm hồi sâu nhất kể từ điểm cuối nhịp vượt 0,786 thì nhịp mất hiệu lực |
| InpBBPeriod / Deviation / TouchBars / TouchTolATR | 11 / 2,4 / 1 / 0,15 | Low[1] ≤ dải dưới + 0,15 × ATR (BUY) |
| InpPinWickPct | 0,77 | Pin bar: bấc ≥ 77% biên độ nến |
| Engulfing / Star | bật | Engulfing: thân nến 1 nuốt thân nến 2. Star: nến 3 thân ≥ 0,6 ATR, nến 2 thân ≤ 0,3 ATR, nến 1 đóng quá giữa thân nến 3 |
| SL / TP / BE / quản trị vốn của SET | — | Không dùng. Phoenix thoát bằng tỉa và clear |

PP10 xét một lần mỗi nến M2 vừa đóng. Mỗi lần xét được ghi một dòng log tín hiệu, gồm lý do không vào. Như vậy có
thể đếm từng điều kiện chặn bao nhiêu lần.

## 6. Tham khảo Hydra 4.5 VIP (từ ảnh input)

| Ý của Hydra | V0.20 |
|---|---|
| Bảng hệ số lot 5 nhóm theo cấp | Có, tắt mặc định; giá trị mặc định chép từ ảnh |
| Trailing ẩn cho rổ DCA, khóa theo % lãi đỉnh (giữ 40%) | Có: trailing clear, giữ 60% đỉnh |
| GD2: rổ phình to thì ưu tiên hòa vốn | Có: hòa vốn từ tầng 4 |
| GD3: đóng rổ rất sâu ở mức chấp nhận (có thể âm) | Có, tắt mặc định |
| Gộp tối đa N lệnh lãi để bù MỘT lệnh lỗ, lệnh lãi nhiều nhất trước | Có: gộp tối đa 4, cộng thêm lãi tỉa đã chốt |
| Giây tối thiểu giữa 2 lệnh DCA (20) | Có, 20 giây |
| Giây chờ sau khi đóng trước khi mở seed mới (10) | Có, 10 giây |
| Bảo vệ vốn 20% | Có, tắt mặc định |
| Gửi thông báo về app MT5 | Có |
| Lọc tin 30/30 phút, mức HIGH | Có sẵn từ trước |
| Hedge cứu rổ (GD1 15% / GD2 25%), Pyramid, trailing rổ Pyramid | **Không có** trong V0.20 |
| Khoảng lưới cố định 150 điểm | Khác: Phoenix dùng max(6 USD; 1,15 × ATR M5) |

## 7. Nút, tạm dừng, khởi động lại

- Mọi nút đều cần bấm hai lần trong 5 giây.
  - TIẾP TỤC bỏ các trạng thái: tạm dừng bằng nút, lỗi thực thi, khóa sau stop out.
  - TẠM DỪNG ngừng mở basket / tầng mới. Lệnh đang mở vẫn giữ TP.
  - ĐÓNG BASKET đóng mọi tầng của basket.
  - ĐÓNG TẤT CẢ đóng mọi vị thế Phoenix của symbol và tạm dừng.
- Tạm dừng tự động xảy ra khi có một trong các điều kiện:
  - 3 lần gửi lệnh lỗi liên tiếp, hoặc một lỗi nghiêm trọng;
  - có vị thế / lệnh chờ không thuộc Phoenix (`InpTamDungViTheLa`);
  - có vị thế Phoenix nằm ngoài basket.
- Trạng thái basket được lưu trong GlobalVariables của terminal. Khi gắn lại EA (đổi tham số, khởi động lại MT5 /
  VPS), EA nhận lại basket và cộng các tầng đã đóng trong lúc EA tắt.
  - Nếu mất GlobalVariables (ví dụ chuyển sang VPS khác), EA dựng lại basket từ comment
    `PG|<basket>|<tầng>|<khoảng tầng>` và TP của lệnh. Phần lãi đã chốt trước đó không được tính.
- EA chỉ chạy trên **tài khoản hedging**.

## 8. Log mỗi ngày để tối ưu

Log ghi trong `%APPDATA%\MetaQuotes\Terminal\Common\Files\PhoenixGrid\`. Mở nhanh bằng MT5: File → Open Data
Folder, lùi lên 2 cấp, rồi vào `Common\Files\PhoenixGrid`.

| File | Kỳ | Một dòng là |
|---|---|---|
| `PG_V020_tin_hieu_<symbol>_<YYYYMMDD>.csv` | ngày | một lần PP10 / PP1 xét: kết quả (VAO_LENH / BI_CHAN / KHONG / LOI_GUI), lý do, số đo Fib / BB / nến, trạng thái Phoenix |
| `PG_V020_giao_dich_<symbol>_<YYYYMMDD>.csv` | ngày | một tầng đã đóng: giờ / giá vào ra, lot, TP, lý do (TP, XOA, GOM, TRAIL_CLEAR, HOA_VON, SO…), lãi ròng |
| `PG_V020_basket_<symbol>_<YYYYMMDD>.csv` | ngày | một basket kết thúc: PP, khoảng tầng, cách clear, lãi ròng, số lệnh / tỉa / xóa, tầng sâu nhất, lỗ thả nổi lớn nhất (tiền và % equity), thời gian giữ |
| `PG_V020_thuc_thi_<symbol>_<YYYYMMDD>.csv` | ngày | một lần gửi lệnh: giá yêu cầu / khớp, retcode, phân loại lỗi, độ trễ ms, bid / ask |
| `PG_V020_tong_ket_ngay_<symbol>_<YYYYMM>.csv` | tháng | một ngày giao dịch: equity đầu / cuối, nạp, rút, thay đổi bỏ nạp rút, số basket / lệnh / tỉa, DD lớn nhất, stop out |
| `PG_V020_trang_thai_<symbol>_<YYYYMM>.csv` | tháng | nến M5 và sự kiện Phoenix (như V0.11), thêm MO_BASKET, KET_THUC_BASKET, NAP_TIEN… |

Mỗi ngày, gửi tôi các file của ngày hôm trước và file tháng. Tôi đọc bằng
[`research/phoenix_grid/phan_tich_log_v020.py`](../../research/phoenix_grid/phan_tich_log_v020.py):

```bash
python3 research/phoenix_grid/phan_tich_log_v020.py --thu-muc <thư mục log> --symbol XAUUSDc --out <thư mục kết quả>
```

Dòng tổng kết của một ngày được ghi ở tick đầu tiên của ngày giao dịch kế tiếp.

## 9. Rủi ro cháy tài khoản

Phép tính: lot đều 0,01, 40 tầng, 1 lot = 100 USC / 1 USD, stop out 0%. Không tính phần lãi tỉa và clear từng phần.

| Khoảng tầng | Vốn 5.000 USC | Vốn 10.000 USC |
|---|---|---|
| 6 USD | cháy khi giá ngược **242 USD** | 367 USD |
| 8 USD | 279 USD | 406 USD |
| 10 USD | 311 USD | 445 USD |
| 12 USD | 340 USD | 484 USD |

Vàng từng đi hơn 100 USD trong một ngày. Bảng điều khiển hiện dòng "Giá ngược tới cháy", tính theo equity, lot đang mở
và các tầng sẽ mở thêm. Khi chưa có basket, dòng này giả định một basket mở ngay tại giá hiện tại.

## 10. Kiểm tra kỹ thuật

- **Compile MQL5: chưa làm được** (không có MetaEditor).
- Kiểm tra tĩnh (`kiem_tra_tinh_mq5.py`): đạt.
  - Ngoặc cân bằng.
  - 139 hàm, mọi lời gọi có nguồn, không hàm trùng, không biến `g_` thiếu khai báo.
  - 113 input có nhãn tiếng Việt.
  - Từ khóa giao dịch: `OrderSend`, đúng cho bản giao dịch.
- Công cụ log: `phan_tich_log_v020.py --tu-kiem-tra` đạt. Số cột tiêu đề đọc thẳng từ file `.mq5`.
- Backtest: **chưa chạy**.

## 11. Chạy trên demo 24/7 giống real nhất

Hướng dẫn từng bước và file SET: [`08_HUONG_DAN_CHAY_DEMO_5000USD.md`](08_HUONG_DAN_CHAY_DEMO_5000USD.md).

1. Tài khoản:
   - Tốt nhất: demo **Standard Cent**, XAUUSDc, 5.000 USC, đòn bẩy 1:2000, **hedging**.
   - Nếu Personal Area không cho mở demo Standard Cent, dùng demo **Standard**, XAUUSDm, **5.000 USD**. Với 0,01 lot,
     1 USD giá = 1 USD, nên tỷ lệ lot / vốn giống hệt tài khoản Cent 5.000 USC. Khác biệt: spread XAUUSDm thấp hơn
     (0,16 so với 0,26 USD/oz khi đo tick tháng 1 và tháng 9/2026).
2. VPS Windows chạy MT5 24/7. Nếu dùng MQL5 VPS, trạng thái lưu trong GlobalVariables có thể không đi theo khi di
   chuyển. Khi đó EA dựng lại từ comment (Mục 7).
3. Tools → Options → Expert Advisors: bật Algo Trading. Tools → Options → Notifications: nhập MetaQuotes ID để nhận
   thông báo.
4. Gắn EA vào chart XAUUSDc (khung nào cũng được). Tick "Allow Algo Trading". Giữ các input mặc định.
5. Tài khoản phải **không có vị thế / lệnh chờ lạ**, vì EA mặc định tạm dừng khi thấy. Nếu buộc phải chạy chung với EA
   khác (ví dụ Hydra), đặt `InpTamDungViTheLa = false`. Khi đó dòng "Giá ngược tới cháy" dùng equity chung, nên không
   còn đúng.
6. Compile trước (F7), gửi tôi toàn bộ lỗi / cảnh báo.

## 12. Giới hạn đã biết

- Lịch kinh tế không có trong Strategy Tester, nên bộ lọc tin không hoạt động khi backtest.
- Cách hiểu SET M2 và đơn vị "pip" là giả định (Mục 5).
- Mỗi symbol chỉ có một basket tại một thời điểm. Chưa có hedge, chưa có pyramid.
- Mốc clear tính theo ATR M5 lúc mở basket. Basket dựng lại từ comment tính lại mốc theo ATR hiện tại.
- Log trạng thái Phoenix dùng giờ server.
