# Có nên chỉ rải lưới khi có sóng mạnh?

Ngày lập: 29/09/2026 · Tái lập: `python3 tools/passview/loc_song_manh.py` · EA: `Passview_DCA_Replica_V2_01.mq5`

## Trả lời ngắn

**Lập trình được** (V2.01 đã có, dạng tùy chọn). Nhưng **log Passview hiện có không ủng hộ** bộ lọc này:
đo "sóng mạnh" **trước** lúc đặt lưới **không** giúp lưới sau đó lãi hơn một cách ổn định. Lưới Stop vốn đã là
bộ bắt sóng: lệnh chỉ khớp khi giá chạy qua bậc. Vì vậy bộ lọc được để **mặc định TẮT**, chỉ dùng để kiểm chứng trên nhiều dữ liệu hơn.

## Cái bẫy cần tránh

Bảng "lãi theo biên độ nến M5" ở báo cáo 01 (nến biên độ thấp lỗ, nến biên độ cao lãi) dùng biên độ của **chính cây nến đang
giao dịch**. Lúc đặt lưới, bot chưa biết cây nến đó sẽ chạy bao xa. Dùng kết quả đó để làm bộ lọc là **nhìn trước tương lai**,
nên backtest sẽ đẹp giả.

## Cách kiểm tra

- **Đơn vị quyết định:** từng chu kỳ lưới (2.421 chu kỳ). Kết quả của một chu kỳ là lãi/lỗ ròng của mọi vị thế khớp từ lệnh của chu kỳ đó.
- **Vì sao tính chính xác được:** bỏ một chu kỳ không đổi kết quả các chu kỳ khác, vì mỗi lệnh có SL/trailing riêng và lưới mới chỉ phụ thuộc giá hiện tại.
- **Biến dự báo** (chỉ dùng dữ liệu có trước lúc đặt lưới):
  - biên độ và độ dịch chuyển giá trong 30/60/120 giây trước;
  - số lần khớp trong 30/60/120 giây trước;
  - biên độ và ATR14 của nến M5 đã đóng.
- **Chống khớp số:** chọn ngưỡng trên **thứ Sáu** (giữ 75/50/25% chu kỳ mạnh nhất), rồi áp nguyên ngưỡng đó cho **thứ Hai**.

## Kết quả 1: lọc theo độ mạnh đo trước

Gốc, không lọc: thứ Sáu 975 chu kỳ, lãi 1.200, PF 1,40 · thứ Hai 1.446 chu kỳ, lãi 2.020, PF 1,43.

| Biến (giữ chu kỳ mạnh nhất) | Tương quan xếp hạng T6 / T2 | T6: lãi, PF | T2: lãi, PF |
|---|---|---|---|
| Biên độ 60 s, top 50% | −0,10 / −0,03 | −12, 0,99 | 1.179, 1,41 |
| Số lần khớp 60 s, top 25% | −0,12 / −0,08 | −79, 0,92 | 729, 1,50 |
| Dịch chuyển 120 s, top 50% | −0,04 / −0,01 | 294, 1,18 | 1.139, 1,53 |
| Biên độ nến M5 vừa đóng, top 50% | 0,00 / −0,09 | 851, 1,56 | 1.262, 1,40 |
| ATR14 M5, top 50% | −0,06 / −0,05 | 60, 1,04 | 728, 1,54 |

Bảng đầy đủ 33 phương án: `ket_qua/loc_song_manh.csv`.

Nhận xét:
- **Tương quan đều gần 0 hoặc hơi âm trên cả hai ngày.** Sau một đoạn giá chạy mạnh, lưới kế tiếp không lãi hơn.
- **Không phương án nào vừa tăng PF ở thứ Sáu vừa giữ được ở thứ Hai.** Biên độ nến M5 tăng PF thứ Sáu (1,56) nhưng thứ Hai không hơn gốc (1,40). Các phương án tăng PF thứ Hai thì thứ Sáu lỗ hoặc gần hòa.
- **Trên thứ Hai (tập kiểm tra), cả 33 phương án đều làm giảm tổng lãi.** Trên thứ Sáu chỉ 1 phương án (biên độ nến M5 vừa đóng, giữ top 75%) nhỉnh hơn gốc 12 USD; sang thứ Hai, phương án đó có PF bằng gốc (1,43) và lãi giảm từ 2.020 xuống 1.583.

## Kết quả 2: bỏ các bậc sát giá

Cách này chỉ vào lệnh khi giá đã chạy ≥ k × 0,21 trong lúc lưới còn sống. Tính chính xác được từ log, vì các bậc ngoài là đúng những lệnh đó.

| Bỏ k bậc | Bậc đầu cách giá | T6: lệnh, lãi, PF | T2: lệnh, lãi, PF |
|---|---|---|---|
| 0 (như Passview) | 0,21 | 2.703, 1.200, 1,31 | 4.358, 2.021, 1,32 |
| 1 | 0,42 | 1.823, 730, 1,28 | 3.030, 1.415, 1,32 |
| 2 | 0,63 | 1.106, 362, 1,22 | 1.889, 1.009, 1,36 |
| 4 | 1,05 | 380, 34, 1,06 | 669, 520, 1,55 |
| 6 | 1,47 | 121, 6, 1,03 | 226, 247, 1,80 |

- **Hai ngày cho kết luận ngược nhau:** thứ Sáu càng bỏ bậc càng tệ; thứ Hai PF tăng nhưng tổng lãi vẫn giảm.
- **Bậc 1–3 sát giá có lãi ổn định cả hai ngày** (PF 1,25–1,38), không phải "bậc lỗ" như trực giác.
- Muốn thử cách này trong EA không cần input mới: đặt `InpFirstOffset = 0,21 × (k+1)` và `InpLevels = 10 − k`.

## Kết luận

| Nhận định | Mức độ |
|---|---|
| Đo sóng mạnh trước khi đặt lưới **không** cải thiện ổn định trên 2 phiên | 🟡 đủ nhất quán trong mẫu, nhưng mẫu chỉ 5 giờ |
| Bot đã tự lọc bằng cách **chỉ chạy đầu phiên Mỹ** (thường biến động mạnh) | ❓ chỉ 2 phiên, có thể do chủ bật/tắt tay |
| Bộ lọc có thể hữu ích ở **phiên yên ắng** (phiên Á, cuối tuần) mà log chưa có | ❓ chưa có dữ liệu để kiểm |

## EA V2.01: bộ lọc tùy chọn

**Input nhóm 6** (mặc định TẮT, nên V2.01 chạy giống hệt V2.00):
- `InpVolFilter`: 0 = tắt; 1 = **biên độ giá (mid) trong N giây gần nhất ≥ ngưỡng**, tính từ tick đã qua; 2 = **ATR của nến đã đóng ≥ ngưỡng**.
- `InpVolWindowSec`, `InpVolMinRange`, `InpVolTF`, `InpVolATRPeriod`, `InpVolMinATR`.

**Hành vi khi không đủ sóng:** không đặt lưới mới, hủy lệnh chờ đang có, vị thế đang mở vẫn trailing tới SL. Log ghi `PAUSE LOW_VOL` hoặc `VOL_WARMUP` kèm giá trị đo, và `RESUME` khi đủ sóng trở lại.

**Tương thích:** SET của V2.00 nạp được vào V2.01 (input thiếu nhận mặc định = tắt).

**Ngưỡng:** ngưỡng biên độ trong log Passview đo từ **giá khớp**, thấp hơn biên độ tick thật khoảng 0,2. Ngưỡng cho EA phải hiệu chỉnh bằng tick.

## Cách kiểm chứng đúng trong MT5

1. Strategy Tester trên tài khoản KVB, `XAUUSD.e`, *Every tick based on real ticks*, **nhiều tuần**, gồm cả ngày yên ắng.
2. Chạy **gốc** (`InpVolFilter = 0`) và **có lọc** trên cùng khoảng thời gian, cùng vốn, cùng khung giờ.
3. Nếu tối ưu: `InpVolMinRange` từ 1,0 tới 4,0, bước 0,5, bật **Forward = 1/3**. Chỉ tin ngưỡng tốt ở **cả phần tối ưu lẫn phần forward**, và lợi thế phải còn khi tăng spread/trượt giá.
4. So sánh Net Profit, Max DD, PF, số lệnh, Expectancy. Bộ lọc chỉ đáng bật nếu **giảm DD mà không làm mất phần lớn lãi** ở phần forward.

SET mẫu: `MQL5/Presets/Passview_DCA_Replica_V2_01_song_manh_thu_nghiem.set` (lọc biên độ 60 giây ≥ 2,5). Đây là **giá trị để thử**, không phải khuyến nghị.

Trạng thái V2.01: **TEST**, chưa compile, chưa backtest. V2.00 và V1.00 giữ nguyên để rollback.
