# Tái dựng bot Passview từ log: báo cáo, quy tắc, EA V2.00

Ngày lập: 29/09/2026 · Dữ liệu: log TradeLogger trên tài khoản Passview (KVB, `XAUUSD.e`)
EA: `MQL5/Experts/Passview_DCA_Replica_V2_00.mq5` · SET: `MQL5/Presets/Passview_DCA_Replica_V2_00_khop_log.set`, `..._an_toan.set`
Tái lập mọi con số: `python3 tools/passview/phan_tich_passview.py`

> **Kết luận chính.** Bot này **không phải DCA trung bình giá**. Nó là **lưới lệnh chờ BUY STOP / SELL STOP hai chiều**:
> đặt 10 bậc mỗi phía cách nhau 0,21 USD, lot cố định 0,05, SL 0,50, không TP, hủy và đặt lại sau 5 giây.
> Bot ăn theo **đà giá (momentum)**: giá chạy mạnh một chiều thì các bậc khớp liên tiếp và SL được kéo theo.
> Mô hình V1.00 (thêm lệnh ngược giá, nhân lot) **bị dữ liệu bác bỏ**, nên V2.00 được viết lại theo cơ chế thật.
> Cơ chế lặp lại gần như tuyệt đối trên 2 phiên. Nhưng **hiệu suất chỉ dựa trên khoảng 5 giờ giao dịch**, chưa đủ để kết luận về lợi nhuận.

Ký hiệu: ✅ quan sát trực tiếp · 🟡 suy luận có căn cứ · ❓ chưa xác định · ❌ bị bác bỏ

---

## 1. Chất lượng dữ liệu

| Mục | Kết quả |
|---|---|
| File nhận | `deals` (14.122 dòng), `orders` (54.328), `bars_XAUUSD.e_M5` (1.260 nến), `symbols` (1). **Thiếu `events`** |
| Tài khoản / symbol | `KVBPrimeLimited-Real`, `XAUUSD.e`, digits 2, contract 100, bước lot 0,01, đòn bẩy 1:1000, USD |
| Khoảng thời gian | Deal đầu 25/09 16:36:33, cuối 28/09 18:32:23 (giờ server). Nến M5 từ 22/09 16:35 tới 29/09 06:55 |
| Trùng lặp | 0 deal trùng ticket, 0 order trùng ticket, 0 nến trùng |
| Thiếu | 7 comment trống, đều là deal đóng tay. Đặc trưng nến không có ô trống |
| Múi giờ server | **GMT+3**: nến nghỉ hằng ngày 23:55–01:00 giờ server, khớp giờ nghỉ 21:00–22:00 UTC của vàng |
| Thời gian bot thật sự chạy | **Chỉ 2 phiên, khoảng 5 giờ**: thứ Sáu 25/09 16:36:32–18:31:02 (975 chu kỳ lưới) và thứ Hai 28/09 15:23:00–18:32:05 (1.446 chu kỳ). Giờ Việt Nam: 20:36–22:31 và 19:23–22:32 (đầu phiên Mỹ). Trong phiên không có quãng ngưng > 15 giây |
| Phân loại lệnh | Magic 1234, comment `zalo:08…55`: 7.061/7.061 lệnh vào và 54.321/54.328 order. 7 lệnh đóng tay (magic 0, `CLIENT`) lúc 28/09 18:32. **Không có bot thứ hai** hay lệnh tay nào khác trong giai đoạn log |
| Chi phí | Hoa hồng 0,30 USD mỗi lệnh 0,05 lot, thu ở deal vào (tương đương 6 USD/lot, khứ hồi). Swap 0, fee 0 |
| Trượt giá | **0,00** trên cả 7.061 lần khớp stop và 7.054 lần khớp SL. Hiếm gặp; xem mục 8 |

---

## 2. Bot hoạt động thế nào

```
mỗi chu kỳ (7–8 giây):
  1. hủy mọi BUY STOP / SELL STOP chưa khớp
  2. đặt ngay 10 BUY STOP:  Ask + 0,21 × k (k = 1…10), SL = giá lệnh − 0,50, không TP, lot 0,05
     rồi 10 SELL STOP:      Bid − 0,21 × k,             SL = giá lệnh + 0,50
     (20 lệnh gửi liên tiếp, xong trong 1–2 giây)
  3. giữ nguyên lưới 5 giây rồi quay lại bước 1
mỗi tick, với từng vị thế:
  lãi < 0,50  → giữ SL gốc (lỗ tối đa 0,50)
  lãi ≥ 0,50  → SL = giá − 0,50 (luôn ≥ hòa vốn), kéo theo giá, không bao giờ lùi
```

Giá chạy mạnh 0,21 × n thì n lệnh cùng chiều khớp liên tiếp (**nhồi thuận xu hướng**), mỗi lệnh có trailing riêng.
Giá lình xình thì lệnh khớp rồi chạm SL gốc −0,50: đây là chi phí thường xuyên của bot.

### Vì sao làm mới sau 5 giây chứ không dưới 1 giây

| Đo trên 2.421 chu kỳ / 7.061 lần khớp | Kết quả | Ý nghĩa |
|---|---|---|
| Thời gian đặt xong cả lưới 20 lệnh | 1–2 giây | Đặt rất nhanh, không chờ giữa các lệnh |
| Từ lúc hủy lưới cũ tới lúc đặt lưới mới | 0 giây trong 2.294/2.420 lần | Đặt lại ngay |
| Lưới bị hủy sau khi đặt xong | đúng 5 giây ở 96–98% chu kỳ | Thời gian sống của lưới |
| Khớp sau khi lệnh được đặt > 2 giây | **72,9%** số lần khớp | Làm mới dưới 1 giây sẽ mất phần lớn các lần khớp này |
| Khớp sau > 4 giây | 38,3% | |
| Lúc hủy, bậc gần giá nhất cách giá | trung vị 0,44 (5%: 0,08; 95%: 1,49) | Lệnh **không** được dời theo giá (nếu dời thì phải luôn ≈ 0,2) |

Người xem thấy bot "đặt lệnh trong chưa đầy 1 giây" là đúng với **tốc độ đặt**. Nhưng **nhịp làm mới** là khoảng 5 giây.
Việc chặn lỗ khi giá quay đầu do SL gắn sẵn trên lệnh chờ (hiệu lực ngay khi khớp) và trailing theo từng tick đảm nhận.

---

## 3. Bảng quy tắc và bằng chứng

Kiểm tra độc lập theo thời gian: đo trên thứ Sáu (suy luận), đối chiếu thứ Hai (kiểm tra). Không có tham số nào được chỉnh sau khi xem thứ Hai.

| # | Quy tắc | Bằng chứng (thứ Sáu / thứ Hai) | Phản ví dụ | Độ tin | Còn thiếu |
|---|---|---|---|---|---|
| R1 | Lệnh của bot: magic 1234, comment Zalo, symbol `XAUUSD.e` | 100% lệnh vào | 7 deal đóng tay (magic 0) | ✅ | – |
| R2 | Chỉ vào bằng BUY STOP / SELL STOP, không lệnh market | 47.267/47.267 lệnh chờ | 0 | ✅ | – |
| R3 | Lưới 2 phía, bậc cách 0,21, tối đa 10 bậc/phía, BUY đặt trước SELL | bước 0,21: 99,97% / 99,97%; cả 2 phía: 99,9% / 100%; đủ 10 bậc BUY: 77,9% / 77,4% | 17–23% chu kỳ thiếu bậc, gần như luôn là **bậc sát giá nhất** | ✅ | Tick để biết vì sao thiếu |
| R4 | Bậc đầu cách Ask/Bid khoảng 1 bước (≈ 0,21) | Ước lượng từ giá lúc hủy: trung vị 0,20 (BUY), 0,23 (SELL); khe giữa 2 phía trung vị 0,52 ≈ 2 × 0,21 + spread ≈ 0,09 | Nhiễu lớn vì order chỉ có giây | 🟡 | **Tick KVB** |
| R5 | Mọi lệnh chờ: SL 0,50, TP 0, lot 0,05 | 100% / 100% | 0 | ✅ | – |
| R6 | Lưới sống 5 giây rồi hủy, đặt lại ngay | đúng 5 s: 97,8% / 96,0%; 4–6 s: 99,9% / 99,9% | 3 chu kỳ 7–13 s | ✅ | – |
| R7 | Lot không đổi (không gấp thếp) | 7.061/7.061 lệnh 0,05 | 0 | ✅ | Có thể lot theo vốn: **thiếu balance** |
| R8 | Thoát chỉ bằng SL; SL giữ nguyên tới khi lãi đủ lớn rồi nhảy lên ≥ hòa vốn | thoát bằng SL: 100% / 99,84%; **0/7.054** vị thế có SL cuối nằm giữa −0,50 và 0; SL giữ nguyên 51,1% / 50,8% | 7 lệnh đóng tay | ✅ | – |
| R9 | Khoảng trailing 0,50, kích hoạt khi lãi ≥ 0,50, theo từng tick | Cận dưới đo từ giá khớp mili-giây: 97,2% ≤ 0,50 (p95 = 0,47) | 2,8% vượt 0,50, có thể do sửa SL trễ lúc giá chạy nhanh | 🟡 | **File events** (thời điểm sửa SL) + tick |
| R10 | Không lọc chiều theo chỉ báo | Đặt cả 2 phía ở 99,9–100% chu kỳ | 0 | ✅ | – |
| R11 | Không giới hạn số vị thế thấp | Mở đồng thời tối đa 28 BUY / 32 SELL | – | ❓ | Chưa thấy trần |
| R12 | Chỉ chạy đầu phiên Mỹ (khoảng 15:23–18:32 giờ server) | Cả 2 phiên kết thúc 18:31–18:32 | Thứ Sáu bắt đầu 16:36 (có thể là ngày khởi chạy) | ❓ | 2 mẫu; có thể do chủ bật/tắt tay |

**Giả thuyết đã bị bác bỏ ❌**
- DCA ngược giá / nhân lot / TP basket: lệnh chỉ khớp theo chiều giá chạy, lot luôn 0,05, TP luôn 0.
- Tín hiệu vào lệnh từ chỉ báo (EMA, RSI…): lưới đặt cả 2 phía liên tục, không phụ thuộc nến.
- "Bỏ bậc đã có vị thế": bậc bị thiếu chỉ trùng vị thế đang mở ở 15,6% trường hợp, **thấp hơn** mức nền 30,9% ở chu kỳ đủ 10 bậc.

---

## 4. Hiệu suất quan sát (Passview, không phải EA)

| Nhóm | Vị thế | Lãi gộp | Hoa hồng | Lãi ròng | Win % | TB thắng | TB thua | PF | Kỳ vọng/lệnh | DD thực hiện max |
|---|---|---|---|---|---|---|---|---|---|---|
| Tất cả | 7.061 | 5.338,7 | −2.118,3 | **3.220,4** | 44,7 | 4,22 | −2,59 | 1,318 | 0,456 | 371,35 |
| Thứ Sáu 25/09 | 2.703 | 2.010,8 | −810,9 | 1.199,9 | 44,1 | 4,27 | −2,57 | 1,309 | 0,444 | 371,35 |
| Thứ Hai 28/09 | 4.358 | 3.327,9 | −1.307,4 | 2.020,5 | 45,2 | 4,19 | −2,60 | 1,325 | 0,464 | 252,65 |
| BUY | 3.761 | 2.048,5 | −1.128,3 | 920,2 | 43,6 | 3,95 | −2,62 | 1,166 | 0,245 | 494,50 |
| SELL | 3.300 | 3.290,2 | −990,0 | 2.300,2 | 46,1 | 4,51 | −2,56 | 1,505 | 0,697 | 205,20 |

Đơn vị USD. DD tính trên chuỗi lệnh đã đóng, không có lỗ nổi. Không có balance nên chưa quy ra %.

**Lãi đến từ đâu.** Gom vị thế cùng chiều mở liên tục thành "đợt" (tương đương basket): có 1.348 đợt, chỉ 20,9% đợt có lãi.

| Số lệnh trong đợt | Số đợt | Lãi TB/đợt | Tổng |
|---|---|---|---|
| 1 | 346 | −2,77 | −958,75 |
| 2–3 | 348 | −5,77 | −2.007,65 |
| 4–5 | 191 | −6,96 | −1.329,85 |
| 6–10 | 292 | +0,71 | +205,95 |
| 11–20 | 140 | +27,90 | +3.905,35 |
| > 20 | 31 | +109,85 | +3.405,35 |

- **Phụ thuộc biến động:** chia 63 nến M5 có giao dịch thành 4 nhóm theo biên độ, nhóm biên độ thấp nhất (3,5–5,0 USD) **lỗ** −493 USD, nhóm cao nhất lãi +1.896 USD (tương quan 0,44).
- **Chi phí lớn:** hoa hồng ăn **40%** lãi gộp.

Bot sống nhờ vài cú chạy mạnh. Trong giai đoạn đi ngang, nó lỗ đều đặn.

---

## 5. Đặc tả EA V2.00

| Quy tắc | Cách EA làm | Input mặc định |
|---|---|---|
| R3, R4, R5 | Mỗi chu kỳ đặt BUY STOP tại `Ask + offset + k·bước`, rồi SELL STOP tại `Bid − offset − k·bước`, SL gắn sẵn, không TP. Bậc đã bị giá chạy qua lúc đặt thì bỏ | `InpLevels = 10`, `InpStepPrice = 0,21`, `InpFirstOffset = 0,21`, `InpLot = 0,05`, `InpSLPrice = 0,50` |
| R6 | Đặt xong thì giữ lưới `InpRefreshMs`, rồi hủy lệnh chưa khớp và đặt lại ngay. Có timer 200 ms để vẫn làm mới khi không có tick | `InpRefreshMs = 5000` (thử được 1000, 500…) |
| R8, R9 | Mỗi tick: lãi ≥ `InpTrailStart` thì SL = giá − `InpTrailDist` (BUY theo Bid, SELL theo Ask), chỉ sửa khi SL cải thiện ≥ `InpTrailStep`; tôn trọng stops/freeze level | 0,50 / 0,50 / 0,01 |
| R12 | Chỉ đặt lưới trong khung giờ **server**; hết giờ thì hủy lệnh chờ, vị thế vẫn trailing tới SL | `15:23`–`18:32`; sàn GMT+0 dùng `12:23`–`15:32` |

**Bổ sung an toàn** (Passview không thể hiện; khi kích hoạt, EA sẽ **khác** Passview):
- Số vị thế tối đa mỗi chiều: 40.
- Spread tối đa: 0,50.
- Dừng khi lỗ trong ngày ≥ X% (tắt).
- Đóng hết khi DD ≥ Y% (tắt).
- Lệnh chờ tự hết hạn 60 giây nếu sàn cho, để không bị bỏ quên khi EA chết.
- Tạm dừng 30 giây sau 5 lỗi liên tiếp hoặc lỗi nghiêm trọng (hết tiền, thị trường đóng, quá nhiều yêu cầu…). Trong lúc dừng, lưới cũ vẫn bị hủy đúng hạn.
- Tháo EA thì lệnh chờ bị hủy. Đổi timeframe/tham số thì giữ nguyên và đặt lại ngay.

**Vận hành:**
- **Khôi phục:** không cần trạng thái riêng. Vị thế nhận diện theo Magic + symbol, SL nằm trên server, trailing tính lại từ giá. Lệnh chờ cũ được thay ở chu kỳ đầu.
- **Tài khoản netting / exchange:** EA báo lỗi và không chạy, vì bot cần giữ nhiều BUY và SELL cùng lúc.
- **Log:** `PassviewV2_<symbol>_<magic>_<YYYY_MM>.csv`. Các sự kiện: `START, RECOVER, GRID, GRID_CANCEL, FILL` (kèm giá stop và trượt giá), `CLOSE` (lý do, lãi/lỗ, comment `[sl …]`), `TRAIL` (tùy chọn), `PAUSE/RESUME, RISK_STOP, SESSION_CLOSE, ERROR, STOP`. Mỗi dòng có bid/ask/spread, số vị thế, số lệnh chờ, balance/equity, số chu kỳ, retcode.

Hai SET:
- **khop_log**: tái hiện Passview để so sánh.
- **an_toan**: lot 0,01, tối đa 15 vị thế/chiều, spread ≤ 0,30, dừng ngày khi lỗ 3%, đóng hết khi DD 10%, đóng khi hết giờ.

---

## 6. Hướng dẫn kiểm thử

1. **Compile:** MetaEditor → F7. Môi trường phát triển không có MetaEditor nên **chưa compile**. Mới kiểm tra tĩnh: ngoặc khớp, không gọi hàm chưa định nghĩa, 28 input khớp 2 file SET.
2. **Strategy Tester** trên tài khoản KVB (để có tick `XAUUSD.e` của sàn):
   - Chế độ *Every tick based on real ticks*, tài khoản hedging, SET `khop_log`.
   - Chạy 2 khoảng 25/09 và 28/09/2026.
   - Kiểm tra hoa hồng trong báo cáo tester có đúng khoảng 0,30 USD mỗi lệnh 0,05 lot không.
3. **So sánh từng lệnh** với Passview:
   `python3 tools/passview/so_sanh_ea_passview.py --ea <file PassviewV2_...csv>`
   Script tự cắt về khung thời gian chung của từng ngày, ghép lệnh cùng chiều lệch ≤ 1,5 giây và ≤ 0,10 giá, rồi in bảng dưới. Tự kiểm tra (`--tu-kiem-tra`): lệch 200 ms ghép được 100%, lệch 5 giây chỉ 3,3%, **đạt**.
4. **Demo** (không dùng tiền thật):
   - (a) đổi timeframe khi đang có vị thế → phải thấy `RECOVER`, SL vẫn trailing;
   - (b) gắn lên tài khoản netting → EA từ chối;
   - (c) đặt `InpMaxSpreadPrice` rất nhỏ → `PAUSE SPREAD_HIGH`, lưới bị hủy;
   - (d) ra ngoài khung giờ → `PAUSE OUT_OF_SESSION`.

| Chỉ số (khung thời gian chung) | Passview | EA tái dựng | Sai lệch |
|---|---|---|---|
| Số vị thế, BUY/SELL | 7.061, 3.761/3.300 | chưa chạy tester | – |
| % lệnh Passview ghép được với EA | – | – | – |
| Lệch thời điểm / giá vào (trung vị) | – | – | – |
| Lệch thời điểm / giá ra (trung vị) | – | – | – |
| Win %, PF, Expectancy | 44,7%, 1,318, 0,456 | – | – |
| Lãi ròng, DD thực hiện max | 3.220,4, 371,35 | – | – |
| % chạm SL gốc, thời gian giữ trung vị | 50,9%, 7,9 s | – | – |

---

## 7. EA mô phỏng được gì, còn lệch gì

- **Mô phỏng đúng theo dữ liệu (✅):** hình học lưới, SL, lot, không TP, nhịp 5 giây, thứ tự BUY rồi SELL, không lọc chiều, thoát bằng SL.
- **Mô phỏng theo suy luận (🟡):** bậc đầu cách giá 1 bước, trailing 0,50 kích hoạt ở lãi 0,50 theo từng tick.
- **Chưa biết (❓):** Passview tự dừng theo giờ hay chủ tắt tay; có giới hạn vị thế/lỗ ngày không; lot có đổi theo vốn không.
- **Chắc chắn sẽ lệch:** độ trễ mạng mỗi máy khác nhau, nên thời điểm đặt lưới lệch vài trăm ms và vị trí bậc lệch theo. Mức khớp hợp lý cần chờ tick và tester mới biết.

## 8. Rủi ro khi chạy thật

- **Trượt giá 0 là điều kiện sống còn.** Lãi TB mỗi lệnh chỉ khoảng 0,09 USD giá (0,456 USD/0,05 lot sau phí). Chỉ cần trượt trung bình khoảng 0,09 USD mỗi lệnh (vào + ra) là **mất toàn bộ lợi thế**. Sàn khác hoặc lúc tin mạnh gần như chắc chắn có trượt.
- **Chính sách sàn:** hơn 7.000 lệnh và hơn 40.000 lần hủy lệnh trong 5 giờ. Nhiều sàn coi đây là giao dịch tần suất cao hoặc "toxic flow", có thể giới hạn lệnh, giãn spread, hủy lợi nhuận hoặc đóng tài khoản.
- **Phụ thuộc biến động:** thị trường đi ngang thì lỗ đều. Dữ liệu chỉ có 2 phiên, nhiều khả năng là phiên biến động mạnh, nên chưa biết kết quả ngày yên ắng.
- **Rủi ro mỗi lệnh có giới hạn nhưng cộng dồn nhanh.**
  - Mỗi lệnh 0,05 lot lỗ tối đa khoảng 2,80 USD tính cả phí, nếu không trượt SL.
  - 32 lệnh cùng chiều chạm SL gốc khoảng 90 USD.
  - Gap giá (tin, đầu tuần) có thể vượt SL.
- **Trailing cần EA chạy liên tục.** EA tắt thì vị thế chỉ còn SL tại mức đã dời, không trailing tiếp.
- **Mẫu nhỏ:** 5 giờ, 2 phiên. Mọi con số hiệu suất ở mục 4 là mô tả, **không phải dự báo**. Không cam kết lợi nhuận hay tỷ lệ thắng.

## 9. Dữ liệu cần thêm

| Dữ liệu | Để làm gì | Cách lấy |
|---|---|---|
| `Tradelogdca_events.csv` | Thời điểm và mức SL mỗi lần sửa (xác nhận R9) | Cùng thư mục `MQL5\Files` của Logger |
| Tick `XAUUSD.e` KVB ngày 25/09 và 28/09 | Xác nhận R4, R9, spread thật; chạy tester | *View → Symbols → Ticks → Export* |
| Báo cáo lịch sử tài khoản (có balance) | DD theo %, kiểm tra lot theo vốn | *Toolbox → History → Report* |
| Ít nhất 20 phiên / 4 tuần log tiếp, gồm ngày yên ắng và ngày tin lớn | Đánh giá hiệu suất, giờ chạy, giới hạn ẩn | Để Logger chạy liên tục |

## 10. Phiên bản

| Version | File | Trạng thái |
|---|---|---|
| V1.00 | `Passview_DCA_Replica_V1_00.mq5` | Giữ nguyên để rollback. Mô hình DCA ngược giá **bị dữ liệu bác bỏ**, không dùng để tái hiện Passview |
| V2.00 | `Passview_DCA_Replica_V2_00.mq5` + 2 SET | TEST: chưa compile, chưa backtest, chưa demo |

Dữ liệu gốc và kết quả chi tiết từng lệnh **không được push**, vì repo đang công khai và dữ liệu là lịch sử giao dịch của tài khoản khác.
Muốn chạy lại script thì đặt các file `Tradelogdca_*.csv` vào `data/passview/`.
