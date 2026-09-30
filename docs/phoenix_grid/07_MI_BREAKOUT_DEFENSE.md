# Phoenix Market Intelligence + Breakout Defense — TEST 1: Shadow Breakout Detection

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: TEST 1 (SHADOW / LOG ONLY).**
>
> - Module: [`PHOENIX_MI_V0_01.mqh`](../../MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh). EA chạy module:
>   [`EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5).
> - **Không gửi lệnh, không sửa lệnh, không đóng lệnh.** Mã không có `OrderSend` hay lời gọi giao dịch nào (kiểm tra
>   tĩnh, Mục 11). Không có baseline nào bị sửa.
> - **Chưa compile** (không có MetaEditor). **Chưa backtest trong MT5.**
> - Mục 9 có số liệu xem trước từ **bản sao Python của logic**, chạy trên nến lịch sử. Đó không phải EA và không phải
>   backtest giao dịch.

## 1. Baseline: điều cần bạn xác nhận trước TEST 2

Yêu cầu nói "giữ nguyên Emergency Hedge GD1 15% → 70%, GD2 25% → 100%, tối đa 2 lần / chu kỳ, dùng lời hedge tỉa lệnh
lỗ xa nhất", và cả Pyramid. Các chức năng đó là của **Hydra 4.5 VIP** (ảnh input bạn gửi, nhóm 5, 8, 13), không phải
của Phoenix:

| Nguồn | Tình trạng |
|---|---|
| Hydra 4.5 VIP `.mq5` | **Không có** ở bất kỳ đâu tôi truy cập được: repo `Davidtruong202` (mọi nhánh), EA-PRO (mọi nhánh), máy làm việc. Tôi chỉ có 5 ảnh màn hình input |
| Phoenix V0.20 TEST | Có (commit `afe5d41`): DCA + tỉa + clear, **chưa có hedge, chưa có pyramid** |
| SET | `M2_FIBO.set` (VuTru_Fibo_BB_Pullback, không có mã nguồn); EA-PRO có `set4pp*.set` của David Hunter V4.x (không liên quan) |
| AGENTS.md / README | Đã đọc (EA-PRO): không sửa baseline, tạo phiên bản mới, không nhận đã compile khi chưa compile |

Vì vậy:

- **TEST 1 làm được ngay mà không cần sửa baseline nào.** Module chạy trên một chart riêng, cạnh EA baseline, và đọc
  vị thế của baseline theo magic. Với Hydra, magic là 20260826 (trong ảnh). File SET theo dõi Hydra dùng magic 0
  (mọi lệnh XAUUSDc trên tài khoản), để không sót lệnh hedge nếu Hydra dùng magic khác.
- **TEST 2 trở đi phải chèn vào EA baseline** (khóa DCA, mở / tháo hedge, tỉa):
  - Nếu baseline là **Hydra 4.5**: cần bạn gửi file `.mq5`. Tôi không thể "giữ nguyên" hay nối vào mã mà tôi chưa đọc.
  - Nếu baseline là **Phoenix V0.20**: đã có sẵn điểm chèn (Mục 3), nhưng Phoenix chưa có Emergency Hedge để "giữ".

## 2. Luồng ENTRY → DCA/PYRAMID → BASKET → HEDGE → TRIM → EXIT

### 2.1. Phoenix V0.20 (đọc từ mã nguồn)

| Bước | Hàm | Ghi chú |
|---|---|---|
| ENTRY | `KiemTraNenPP10` → `XetPP10` → `VaoTheoPP` → `MoBasket`; `XetPP1` | Chỉ khi chưa có basket; `LyDoChanMoBasket`, `ChanTheoPhoenix` |
| DCA | `QuanLyBasket` (bước 3) → `LyDoChanDCA` → `MoTang` | Đã có "hoãn DCA khi breakout ngược basket" theo bộ nhận diện V0.11 |
| BASKET | `g_tang[]`, `LuuBasketGV` / `NhanLaiBasket`, `KiemTraBasketTimer` | Một basket mỗi symbol |
| HEDGE | — | Chưa có |
| TRIM | TP server từng tầng; `XetXoaTang` (clear từng phần) | |
| EXIT | `QuanLyBasket` (bước 1: trailing clear, hòa vốn khi sâu) → `DongBasket` | |

### 2.2. Hydra 4.5 (chỉ suy ra từ tên input, **chưa kiểm chứng bằng mã nguồn**)

| Bước | Nhóm input trong ảnh |
|---|---|
| ENTRY | 4: lệnh đầu theo MA50 H1 |
| DCA / PYRAMID | 1, 3, 5, 6: lưới 150 điểm (hoặc theo ATR), bảng hệ số lot; Pyramid khi có lãi 150 điểm, hệ số 1,368 |
| BASKET | 2, 7b: bảo vệ vốn 20%; giai đoạn GD2 (12 lệnh) / GD3 (18 lệnh) |
| HEDGE | 13: GD1 15% → 70%, GD2 25% → 100%, margin level 250%, tối đa 2 lần / chu kỳ, dùng lời hedge cắt lệnh lỗ xa nhất |
| TRIM | 12: gộp tối đa 4 lệnh lãi bù 1 lệnh lỗ, từ 30 lệnh DCA |
| EXIT | 7, 8, 9, 10: trailing rổ DCA, trailing rổ Pyramid, SL hòa vốn chung, chốt lời cố định |

## 3. Vị trí chèn và kiểm tra xung đột (cho TEST 2+)

Module trả lời EA chủ qua các hàm:

- `TrangThai()`;
- `PhongThu()`;
- `HuongBreakout()`;
- `DiemBO()`;
- `KhoaDCA()`;
- `HedgeTyLe()`;
- `HedgeLot()`.

EA chủ gọi `CapNhat()` một lần mỗi tick. Module chỉ tính lại khi có nến mới.

| Điểm chèn | Phoenix V0.20 | Hydra 4.5 (khi có mã nguồn) |
|---|---|---|
| Khóa DCA | Thêm `KhoaDCA()` vào `LyDoChanDCA` | Trước khi mở lệnh DCA |
| Market Hedge | Module mới sau bước clear, trước DCA trong `QuanLyBasket` | Lớp riêng, trước Emergency Hedge |
| Tỉa bằng lời hedge | Sau Market Hedge, trước DCA | Cạnh cơ chế "dùng lời hedge cắt lệnh lỗ xa nhất" |

| Xung đột | Yêu cầu thiết kế khi làm TEST 2–6 |
|---|---|
| DCA ↔ Hedge | Đang DEFENSE thì không mở DCA ngược breakout. Lệnh hedge không được tính là tầng DCA |
| Pyramid ↔ Hedge | Lệnh hedge có magic / comment riêng (ví dụ `PMI|H|<chu kỳ>`) và không bao giờ là lệnh gốc cho Pyramid. Tổng hedge ≤ tỷ lệ mục tiêu × lot basket, nên không thành chuỗi SELL tự tăng |
| Trim ↔ Hedge | Chỉ tỉa khi tiêu chí định lượng cải thiện basket (giảm exposure, giữ lãi ròng ≥ ngưỡng). Log `trim_reason`, `trim_volume`, `trim_pnl`, exposure trước / sau |
| Emergency ↔ Market Hedge | Emergency (DD 15% / 25%) luôn ưu tiên và không bị sửa. Khi Emergency đã hedge, Market Hedge không mở thêm. Khối lượng hedge tính gộp để không vượt 100% |

Thứ tự ưu tiên theo yêu cầu:

```
RISK / HARD SAFETY → EMERGENCY HEDGE → BREAKOUT DEFENSE → MARKET HEDGE → TRIM → NORMAL DCA → PYRAMID → NEW ENTRY
```

Thứ tự này khớp Phoenix V0.20. Ở V0.20, clear (EXIT) đang đứng trước DCA. Khi chèn DEFENSE, DEFENSE sẽ đứng sau
RISK và trước clear, để khóa DCA có hiệu lực ngay trong cùng tick.

## 4. Market Intelligence: công thức

Mọi số đo tính trên **nến đã đóng** của khung MI (mặc định M5, không đổi theo chart).

### 4.1. Range / Sideway (giống bộ nhận diện Phoenix V0.11)

Hộp là 48 nến cuối: U = max High, L = min Low, W = U − L. Hộp là SIDEWAY khi đồng thời thỏa:

- 1,5 ≤ W / ATR14 ≤ 6;
- ADX14 < 22;
- ER24 < 0,30;
- ít nhất 2 đỉnh swing sát biên trên (trong 0,15 W) và 2 đáy swing sát biên dưới;
- |độ dốc hồi quy 24 nến| < 0,05 ATR mỗi nến.

Swing là fractal 2 nến mỗi bên. Cần 2 nến liên tiếp thỏa mới vào SIDEWAY, và 2 nến liên tiếp không thỏa mới bỏ.

### 4.2. Cấu trúc

- HH / LH: so sánh hai đỉnh swing gần nhất. HL / LL: so sánh hai đáy.
- BOS: nến đóng vượt đỉnh swing gần nhất (↑), hoặc thủng đáy swing gần nhất (↓).
- `structure_score` = (HH +50 / LH −50) + (HL +50 / LL −50).

### 4.3. Bollinger (MA20, 2,0)

| Số đo | Công thức |
|---|---|
| Band Width | BW = dải trên − dải dưới, kèm BW / ATR |
| Squeeze | BW ≤ phân vị 20% của 100 nến |
| Band mở | dải trên tăng và dải dưới giảm so với nến trước |
| Đóng ngoài band | Close > dải trên hoặc Close < dải dưới |
| Chạy dọc band | ≥ 3 trong 5 nến đóng ở 20% ngoài cùng của nửa dải |
| `bb_score` | (Close − MA20) / (dải trên − MA20) × 100, kẹp trong ±100 |

### 4.4. Fibonacci

Nhịp dùng để tính:

- Đang có breakout: nhịp từ swing ngược chiều gần nhất trước lúc nghi vấn, tới cực trị kể từ lúc nghi vấn.
- Không có breakout: nhịp giữa hai swing ngược chiều gần nhất.

Tỷ lệ hồi tính từ điểm cuối nhịp. Các vùng:

- 0–38,2;
- 38,2–50;
- 50–61,8;
- 61,8–78,6;
- 78,6–100;
- mở rộng 100–127,2, 127,2–161,8, và 161,8+.

Vùng 50–61,8 **không** được mặc định là tốt nhất. Vùng này chỉ dùng làm ngữ cảnh ở Mục 4.7.

### 4.5. Nến (R biên độ, B thân, UW / LW bấc trên / dưới; xét theo thứ tự)

| Mẫu | Công thức |
|---|---|
| Bullish / Bearish Engulfing | nến 1 ngược màu nến 2, thân nến 1 bao trọn thân nến 2 và lớn hơn |
| Morning / Evening Star | nến 3 thân ≥ 0,5 ATR; nến 2 thân ≤ 50% thân nến 3; nến 1 ngược màu nến 3, đóng quá giữa thân nến 3 |
| Pin Bar / Shooting Star | bấc dưới / trên ≥ 60% R, thân ≤ 30% R, bấc còn lại ≤ 20% R |
| Bullish / Bearish Rejection | bấc dưới / trên ≥ 45% R, đóng ở nửa trên / dưới của biên độ |

### 4.6. Điểm breakout (0–100)

Điểm tính cho hướng d, so với range bị phá (range được giữ cố định kể từ lúc nghi vấn):

| Bằng chứng | Điểm | Điều kiện |
|---|---|---|
| `CLOSE_NGOAI` | 20 | Close ngoài biên ≥ 0,1 ATR |
| `PHA_SWING` | 15 | Close vượt swing cực trị theo hướng d của cửa sổ (hình thành trước lúc nghi vấn) |
| `BW_TANG` | 15 | BW ≥ 1,2 × BW 3 nến trước (khi bật Bollinger Filter) |
| `BAND_MO` | 10 | Band mở và close ngoài band theo hướng d (khi bật Bollinger Filter) |
| `MOMENTUM` | 15 | (C − C[3]) × d ≥ 1 ATR và DI cùng hướng |
| `THAN_MANH` | 10 | Có nến đóng ngoài với thân ≥ 60% R và ≥ 0,5 ATR theo hướng d kể từ lúc nghi vấn |
| `KHONG_RECLAIM` | 15 | Số nến đóng ngoài liên tiếp ≥ "Số nến xác nhận" |

Nếu tắt Bollinger Filter, điểm được quy đổi lại về thang 100 trên các bằng chứng còn lại.

### 4.7. State machine thị trường

```
NORMAL ──(hộp sideway 2 nến)──► SIDEWAY ──(close ngoài biên ≥ 0,1 ATR)──► BREAKOUT_SUSPECTED
BREAKOUT_SUSPECTED ──(điểm ≥ ngưỡng VÀ ≥ N nến đóng ngoài liên tiếp)──► BREAKOUT_CONFIRMED
BREAKOUT_SUSPECTED ──(close vào trong range ≥ 25% W)──► SIDEWAY          [BO_THAT_BAI: breakout giả]
BREAKOUT_SUSPECTED ──(12 nến chưa xác nhận)──► SIDEWAY (giá trong range) / NORMAL
BREAKOUT_CONFIRMED ──(close vào trong range ≥ 25% W)──► RECLAIM
BREAKOUT_CONFIRMED ──(range mới hình thành hoàn toàn sau breakout)──► SIDEWAY  [VUNG_MOI]
BREAKOUT_CONFIRMED ──(288 nến)──► NORMAL
RECLAIM ──(N + 1 nến đóng trong range)──► SIDEWAY                       [RECLAIM_XAC_NHAN]
RECLAIM ──(close lại ngoài biên theo hướng breakout)──► BREAKOUT_CONFIRMED
RECLAIM ──(close ngoài biên đối diện)──► BREAKOUT_SUSPECTED hướng ngược
```

Khi khởi động, module dựng lại trạng thái thị trường bằng cách chạy lại 300 nến gần nhất. Kết quả xác định: cùng dữ
liệu nến thì cho cùng trạng thái.

### 4.8. Breakout Defense Controller (TEST 1: chỉ ghi quyết định "sẽ làm")

```
IDLE ──(BREAKOUT_CONFIRMED ngược hướng basket, hết cooldown)──► DEFENSE_1: khóa DCA, hedge tỷ lệ 1
DEFENSE_1 ──(giá cách biên bị phá ≥ max(1 × W, 2 ATR) trong N nến, điểm ≥ ngưỡng, đã giữ ≥ thời gian tối thiểu,
             giá cách lần đổi cấp trước ≥ 1 ATR)──► DEFENSE_2: hedge tỷ lệ 2
DEFENSE_2 ──(ngữ cảnh GIẢM N nến, đã giữ đủ, cách ≥ 1 ATR)──► DEFENSE_1
DEFENSE_x ──(reclaim / breakout ngược đã hết, đã giữ ≥ thời gian tối thiểu)──► RECOVERY: tháo hedge có kiểm soát
RECOVERY ──(N nến không breakout lại)──► IDLE + cooldown ; RECOVERY ──(breakout xác nhận lại)──► DEFENSE_1
DEFENSE_x ──(basket đóng)──► IDLE
```

Ngữ cảnh hedge khi đang phòng thủ. Mỗi bộ lọc tắt thì được coi là thỏa.

- **GIU** (giữ hedge): cần đủ ba điều kiện:
  - Fib 45–66,8% của nhịp breakout;
  - giá chạm tới vùng MA20 (± 0,1 ATR);
  - nến từ chối theo hướng breakout.
- **GIAM** (giảm hedge): cần nến ngược hướng breakout, và thêm một trong hai điều kiện:
  - giá hồi quá 78,6%;
  - close qua swing ngược chiều gần nhất.
- **TRUNG_TINH**: các trường hợp còn lại.

Không có quy tắc "chạm band = hedge" hay "chạm Fib = hedge".

Chống bật / tắt liên tục:

| Biện pháp | Cách làm |
|---|---|
| Xác nhận | Điểm + N nến |
| Trễ | Reclaim cần 25% W và N + 1 nến |
| Thời gian giữ tối thiểu | 30 phút |
| Cooldown | 60 phút |
| Khoảng cách tối thiểu giữa 2 lần đổi cấp | 1 ATR |
| Trạng thái lưu | Trạng thái phòng thủ lưu trong GlobalVariables, không mất khi khởi động lại MT5 / VPS |

**Chưa có trong TEST 1**, để dành cho các bản sau:

- Smart Trim (TEST 6);
- các điểm tổng hợp BUY / SELL / DCA / HEDGE / TRIM / EXIT (TEST 7–8).

Log đã có các điểm thành phần: `trend_score`, `structure_score`, `breakout_score`, `bb_score`, `momentum_score`, `fib_zone`.

## 5. Input

| Nhóm | Input | Mặc định |
|---|---|---|
| 1 | Bật Market Intelligence; Khung phân tích; Magic basket cần theo dõi (0 = mọi vị thế của symbol, Hydra = 20260826); Ghi log; Thư mục | bật; M5; 0; bật; PhoenixGrid |
| 2 | Số nến dựng range; Độ rộng range tối đa (× ATR); ADX tối đa khi sideway | 48; 6,0; 22 |
| 3 | Điểm xác nhận Breakout; Số nến xác nhận | 60; 2 |
| 4 | Bật Breakout Defense; Bật khóa DCA khi Breakout; Bật Market Hedge; Tỷ lệ Hedge ban đầu; Tỷ lệ Hedge cấp 2; Thời gian giữ Hedge tối thiểu; Cooldown Hedge; Giả lập basket trong tester | bật; bật; bật; 25%; 50%; 30 phút; 60 phút; tắt |
| 5 | Bật Fib Filter; Bật Bollinger Filter; Bật Candle Confirmation | bật |

Muốn thử tỷ lệ hedge 70% / 100%, đặt ở hai input tỷ lệ.

## 6. Log mỗi nến đóng

File là `Common\Files\PhoenixGrid\PMI_V001_<symbol>_d<điểm>n<số nến>[_tester]_<YYYYMMDD>.csv`. Nhãn `d60n2` cho phép
chạy nhiều cấu hình song song mà không ghi đè nhau. Có 48 cột:

| Nhóm | Cột |
|---|---|
| Thời điểm, sự kiện | `thoi_gian`, `su_kien` (ví dụ `BO_NGHI_VAN`, `BO_XAC_NHAN+DEF_BAT_DAU`, `RECLAIM_XAC_NHAN`; nến không có sự kiện ghi `NEN`) |
| Thị trường | `market_state`, `trend`, `trend_score`, `structure`, `structure_score`, `bos`, `range_high`, `range_low`, `range_w_atr` |
| Breakout | `breakout_direction`, `breakout_score`, `bang_chung`, `so_nen_ngoai`, `so_nen_tu_breakout` |
| Bollinger | `bb_mid`, `bb_width`, `bb_width_atr`, `bb_squeeze`, `bb_expand`, `bb_ngoai`, `bb_doc`, `bb_score` |
| Fib, nến, momentum | `fib_dau`, `fib_cuoi`, `fib_ratio`, `fib_zone`, `nen`, `momentum_atr`, `momentum_score`, `adx`, `atr`, `close` |
| Basket | `basket_direction`, `basket_buy_volume`, `basket_sell_volume`, `basket_volume`, `net_exposure` |
| Phòng thủ | `hedge_volume` (luôn 0 ở TEST 1), `hedge_ratio` (luôn 0), `hedge_target_ratio`, `hedge_target_volume` ("sẽ mở"), `dca_lock`, `trim_action`, `defense_state`, `hedge_context`, `reason` |

## 7. Chạy TEST 1

1. Chép **cả hai file** `EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5` và `PHOENIX_MI_V0_01.mqh` vào
   `MQL5\Experts\PhoenixGrid\`. Compile EA (F7), gửi tôi toàn bộ lỗi / cảnh báo.
2. **Chạy thật cạnh Hydra** (hoặc Phoenix):
   - Hydra: dùng gói [`goi_cai_dat/PhoenixGrid_theo_doi_Hydra.zip`](../../goi_cai_dat/PhoenixGrid_theo_doi_Hydra.zip)
     và làm theo `HUONG_DAN_THEO_DOI_HYDRA.txt`.
   - Mở một chart XAUUSDc **mới**, gắn EA shadow, nạp `PMI_V001_THEO_HYDRA_d60n2.set` (magic 0 = mọi lệnh XAUUSDc;
     nếu có đánh tay XAUUSDc trên tài khoản đó thì đổi thành 20260826).
   - Không cần bật Allow Algo Trading, vì EA không gửi lệnh.
   - Có thể mở thêm chart thứ ba với cấu hình khác, ví dụ điểm 80, số nến 3.
   - Để tìm logic Hydra: chạy script chỉ đọc
     [`PG_XuatLichSu.mq5`](../../MQL5/Scripts/PhoenixGrid/PG_XuatLichSu.mq5). Script xuất mọi deal, lệnh, vị thế đang mở
     (magic, comment, lý do đóng) ra `Common\Files\PhoenixGrid\PG_lich_su_deal_<server>_<từ>_<đến>.csv`,
     `PG_lich_su_lenh_…`, `PG_vi_the_mo_…`. Tên file có server, không có số tài khoản. Kết hợp với log shadow và nhật ký
     quyết định của Hydra (`MQL5\Logs`), có thể dựng lại: lệnh đầu, khoảng lưới, hệ số lot, Pyramid, hedge, cách thoát.
3. **Strategy Tester** (chỉ kiểm tra nhận diện):
   - XAUUSDc, M5, "Every tick based on real ticks" hoặc "1 minute OHLC".
   - Đặt `Giả lập basket = true` để xem luồng DEFENSE / RECOVERY.
   - Log có chữ `_tester`.
4. Gửi tôi log mỗi ngày. Tôi đánh giá bằng
   [`research/phoenix_grid/phan_tich_log_mi.py`](../../research/phoenix_grid/phan_tich_log_mi.py):

   ```bash
   python3 research/phoenix_grid/phan_tich_log_mi.py --thu-muc <thư mục log> --symbol XAUUSDc --nhan d60n2 --out <kết quả>
   ```

   Cách đọc kết quả:
   - Breakout xác nhận là "đi tiếp" nếu trong 48 nến giá đóng cách biên ≥ 1 × độ rộng range trước khi reclaim.
   - Breakout thất bại / hết hạn là "loại đúng" nếu sau đó giá không đi tiếp như vậy.
   - Phòng thủ được đếm theo đợt, thời lượng, và số lần bật lại trong 2 giờ.

## 8. Cổng đi tiếp sang TEST 2 (đề xuất, cần bạn duyệt)

TEST 1 đạt khi đủ ba điều kiện:

1. Chạy ≥ 2 tuần thật (hoặc tester ≥ 6 tháng). Đọc từng đợt breakout trên chart và thấy trạng thái khớp mắt nhìn.
2. Không có trạng thái kẹt. Số lần bật lại phòng thủ trong 2 giờ ≤ 10% số đợt phòng thủ.
3. Bạn chọn được cấu hình xác nhận (Mục 9 cho thấy đánh đổi).

Sau đó mới làm TEST 2 (chỉ khóa DCA) trên baseline bạn chọn (Mục 1).

Chỉ số và 5 câu hỏi của TEST 2–8 sẽ được báo so với TEST 0:

- Market Hedge giảm Max DD bao nhiêu?
- Đổi lại mất bao nhiêu Profit?
- Có giảm Emergency Hedge không?
- Có giảm tầng DCA sâu không?
- Có làm basket bị khóa lâu hơn không?

Quy trình chống overfit:

- in-sample → out-of-sample → walk-forward nếu đủ dữ liệu;
- đo độ nhạy tham số;
- không kết luận từ một tuần.

## 9. Xem trước bằng bản sao Python (không phải EA, không phải backtest giao dịch)

[`research/phoenix_grid/ban_sao_python_mi.py`](../../research/phoenix_grid/ban_sao_python_mi.py) chạy lại các công thức
Mục 4 trên 52.237 nến M5 XAUUSDm (02/01–27/09/2026), dựng từ nến M1 trên EA-PRO. Basket được giả lập ngược mỗi breakout.
Kết quả đầy đủ:
[`results_mi/xem_truoc_ban_sao_python_XAUUSDm_2026_d60n2.md`](../../research/phoenix_grid/results_mi/xem_truoc_ban_sao_python_XAUUSDm_2026_d60n2.md).

| Điểm / số nến xác nhận | Breakout xác nhận | Đi tiếp ≥ 1 W trong 4 giờ | Thất bại / hết hạn | Loại đúng | Đợt phòng thủ | Lên cấp 2 | Bật lại trong 2 giờ |
|---|---|---|---|---|---|---|---|
| **60 / 2 (mặc định)** | 41 | 31,7% | 16 | 81,2% | 36 | 13 | 6 |
| 80 / 2 | 34 | 35,3% | 22 | 81,8% | 33 | 8 | 3 |
| 60 / 3 | 26 | 42,3% | 26 | 80,8% | 26 | 10 | 2 |
| 80 / 3 | 22 | 50,0% | 30 | 83,3% | 22 | 5 | 2 |

Nhận xét:

1. **Lỗi logic đã tìm thấy và đã sửa nhờ bản sao.** Ở trạng thái RECLAIM, nếu giá xuyên qua cả range sang biên đối
   diện thì trạng thái bị kẹt: có một đợt phòng thủ kéo dài 13.435 phút. Đã thêm nhánh "breakout ngược chiều" và
   giới hạn 288 nến. Sau khi sửa, đợt dài nhất là 3.460 phút (gồm nghỉ cuối tuần).
2. **SIDEWAY chỉ chiếm 2,1% số nến; NORMAL chiếm 92,6%.** Định nghĩa range của Phoenix rất chặt. Phần lớn các đợt
   giá chạy mạnh xuất phát từ trạng thái không có range, nên Breakout Defense theo đúng định nghĩa "thoát range" sẽ
   không phản ứng với chúng.

   Đây là câu hỏi thiết kế cần bạn quyết định. Tôi chưa tự thêm gì. Có ba lựa chọn:
   - (a) nới điều kiện range;
   - (b) thêm "trend mạnh từ NORMAL" (BOS + momentum + band mở) làm một loại breakout;
   - (c) giữ nguyên.
3. Với cấu hình mặc định, chỉ khoảng 1/3 breakout xác nhận đi tiếp ≥ 1 độ rộng range trong 4 giờ. Ngưỡng chặt hơn
   thì tỷ lệ đi tiếp cao hơn, nhưng ít đợt hơn và xác nhận chậm hơn. Mẫu 22–41 đợt là quá nhỏ để chọn cấu hình.
4. Bản sao chưa có ngữ cảnh Fib / nến, nên chưa có DEF_GIAM_CAP. ADX tính lại có thể lệch MT5.

## 10. Giới hạn đã biết

- Chỉ xét nến đóng của khung MI. Phản ứng chậm nhất 1 nến (5 phút với M5), đổi lại không phản ứng với cú chọc biên
  trong nến.
- Basket được nhận theo magic. Nếu EA baseline dùng cùng magic cho lệnh hedge của nó, log gộp cả hai phía. Cột
  BUY / SELL tách riêng để đọc được.
- Trong Strategy Tester không có vị thế thật, nên phần phòng thủ chỉ xem được khi bật giả lập basket.

## 11. Kiểm tra kỹ thuật

- **Compile MQL5: chưa làm được** (không có MetaEditor).
- Kiểm tra tĩnh trên bản ghép EA + module:
  - ngoặc cân bằng, mọi lời gọi có nguồn, không hàm trùng;
  - **không có từ khóa giao dịch**;
  - 21 input có nhãn tiếng Việt.

  Sáu hàm truy vấn (`TrangThai`, `PhongThu`, `HuongBreakout`, `DiemBO`, `HedgeTyLe`, `HedgeLot`) chưa được gọi vì là
  giao diện cho TEST 2+.
- `phan_tich_log_mi.py --tu-kiem-tra`: đạt. Tiêu đề 48 cột đọc thẳng từ file `.mqh`.
- Backtest MT5: chưa chạy.
