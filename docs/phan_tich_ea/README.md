# Thu log & suy ngược logic một EA bất kỳ

| File | Vai trò |
|---|---|
| [`../../MQL5/Experts/TradeLogger/TradeLogger_Universal.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger_Universal.mq5) | Logger 3.00 **dùng cho mọi EA**: tự khai báo chỉ báo, đơn vị point/pip |
| [`../../MQL5/Experts/TradeLogger/TradeLogger_TripTrap.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger_TripTrap.mq5) | Cùng mã với bản Universal, **cài sẵn** cho GoldVault Trip Trap (xem [`TRIP_TRAP.md`](TRIP_TRAP.md)) |
| [`../../research/phan_tich_ea/phan_tich_chung.py`](../../research/phan_tich_ea/phan_tich_chung.py) | Đọc log, in báo cáo: lệnh đầu, lưới/DCA, đóng rổ, trailing ảo, lệnh chờ, **dò khung thời gian và dò chỉ báo** (dùng khi không có file .set) |
| [`../../MQL5/Experts/TradeLogger/TradeLogger.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger.mq5) | Bản 2.00 riêng cho BE Nha Trang (giữ nguyên, xem [`../be_nha_trang/THU_LOG.md`](../be_nha_trang/THU_LOG.md)) |

Logger **không đặt lệnh**. Nó chỉ đọc lịch sử và trạng thái tài khoản, nên chạy được cả khi đăng nhập bằng mật khẩu
investor. Cả hai file `.mq5` **chưa compile** (môi trường của tôi không có MetaTrader). Nếu MetaEditor báo lỗi, gửi
nguyên văn lỗi để tôi sửa.

## Cài đặt Universal cho một EA mới

| Input | Đặt thế nào |
|---|---|
| `InpFilePrefix` | **Mỗi EA một tên riêng**, nếu không các logger sẽ ghi đè file của nhau |
| `InpMagicFilter` | Magic của EA. Chưa biết thì để `0`, chạy một lúc, xem cột `magic` trong `<prefix>_deals.csv`, rồi đặt lại |
| `InpSymbolFilter` | Symbol EA chạy (trống = tất cả) |
| `InpEntryTF` | **Khung chart gắn EA** (ví dụ H1). Dùng để đo "giây kể từ mở nến" và lấy nến đã đóng |
| `InpIndicators` | Chỉ báo EA dùng, lấy từ file .set / mô tả EA (cú pháp bên dưới). Không biết thì để `AUTO` |
| `InpDistUnit` | `Point` nếu file .set của EA ghi khoảng cách bằng point; `Pip` nếu ghi bằng pip |
| `InpFeatureTF` / `InpBiasTF` | Khung cho bộ đặc trưng chung (ATR/RSI/EMA20-50-200/BB/MACD/Stoch/PDH-PDL) |

Nhớ tăng Tools → Options → Charts → **Max bars in chart** để đủ lịch sử nến.

### Cú pháp `InpIndicators`

`LOẠI:KHUNG:tham số`, nhiều chỉ báo cách nhau dấu phẩy, tối đa 40. Để `AUTO` thì logger tự dùng bộ quét rộng (xem mục EA không có file .set). Thiếu tham số thì dùng giá trị mặc định.

| Loại | Tham số (mặc định) | Cột ghi ra |
|---|---|---|
| `EMA`, `SMA` | chu kỳ (20) | giá trị, `_dist` = (giá − MA) / đơn vị |
| `RSI` | chu kỳ (14) | giá trị |
| `ATR` | chu kỳ (14) | giá trị, `_u` = ATR đổi ra đơn vị (so trực tiếp với bước lưới) |
| `ADX` | chu kỳ (14) | ADX, `_pdi`, `_mdi` |
| `CCI` | chu kỳ (14) | giá trị |
| `BB` | chu kỳ, độ lệch (20, 2) | `_up`, `_mid`, `_lo`, `_pctb` (vị trí giá trong dải) |
| `MACD` | nhanh, chậm, tín hiệu (12, 26, 9) | `_main`, `_sig` |
| `STOCH` | K, D, slowing (5, 3, 3) | `_main`, `_sig` |

Khung viết như MT5: `M1 M5 M15 M30 H1 H4 D1 W1`… (có cả M2, M6, M12, H2, H3…).
Ví dụ: `EMA:H1:34,EMA:H1:89,RSI:M15:14,ATR:H1:14,BB:H1:20:2,MACD:H4:12:26:9`.

Mọi giá trị chỉ báo lấy trên **nến đã đóng** ngay trước lúc khớp lệnh, nên tính lại từ lịch sử cũng ra đúng giá trị EA
đã thấy lúc đó. Nếu EA dùng chỉ báo tuỳ chỉnh (file .ex5 riêng), logger không đọc được, cần bổ sung riêng.

## File xuất ra

Từ bản 3.21 mọi file nằm chung **một thư mục riêng**: `Files\<InpFolder>\<InpFilePrefix>\`. Mặc định là
`Files\TradeLogger\tradelog\`. Thư mục `Files` là `MQL5\Files` của terminal, hoặc
`C:\Users\<tên>\AppData\Roaming\MetaQuotes\Terminal\Common\Files` nếu bật `InpUseCommonFolder`. Dòng đầu
trong tab Experts in đường dẫn đầy đủ. Khi gửi log, chỉ cần nén **cả thư mục đó**.


| File | Nội dung |
|---|---|
| `<prefix>_deals.csv` | Mỗi deal một dòng, gồm các nhóm cột: thông tin deal · đặc trưng chung `f_*` · rổ lệnh `k_*` · nến khung EA `c_*` · chỉ báo `i_*` · giá tức thời `live_*` |
| `<prefix>_events_v3.csv` | Mỗi lần đặt, sửa, khớp hoặc huỷ lệnh chờ, và mỗi lần đổi SL/TP của vị thế. Có khoảng cách tới giá (`dist`); khi dời lệnh chờ có thêm giá cũ và khoảng cách cũ (`prev_price`, `prev_dist`) |
| `<prefix>_orders.csv` | Lịch sử order: market hay lệnh chờ, lý do |
| `<prefix>_ctxbars_<symbol>_<TF>.csv` | Mỗi nến khung EA kèm các cột `c_*` và `i_*`, để so "lúc EA vào lệnh" với "lúc không vào" |
| `<prefix>_bars_<symbol>_<TF>.csv` | Nến kèm đặc trưng chung |
| `<prefix>_symbols.csv` | Thông số symbol, đơn vị, chuỗi chỉ báo đã dùng |
| `<prefix>_m1_<symbol>.csv` | Nến M1 thuần (giá, spread), từ `InpM1LookbackDays` ngày trước lệnh đầu, nối thêm liên tục. Python tự gộp ra **mọi khung** và tính **mọi chỉ báo** từ file này (mục 8) |
| `<prefix>_auto.csv` | Mỗi magic: comment, số rổ BUY/SELL, lệnh thêm, khung đoán được (kiểm tra 19 khung M1…D1) |

Các cột `k_*` quan trọng nhất (khoảng cách đều theo đơn vị `k_unit`):

| Cột | Ý nghĩa |
|---|---|
| `k_basket`, `k_idx` | Rổ số mấy, lệnh thứ mấy trong rổ. Rổ = các vị thế cùng symbol, magic, chiều đang mở cùng lúc |
| `k_dist_last` | Lệnh vào cách lệnh trước bao nhiêu (dương = giá tốt hơn) → **bước lưới/DCA** |
| `k_lot_ratio` | Lot lệnh này / lot lệnh trước → **hệ số nhân** |
| `k_dist_avg` | Lúc đóng: giá đóng cách giá trung bình rổ bao nhiêu → **TP rổ** |
| `k_peak_after_last` | Có lời tối đa (so giá trung bình) từ lệnh vào cuối đến lúc đóng, xấp xỉ theo nến M1 → **trailing ảo** |
| `k_basket_age_sec` | Rổ đã mở bao lâu |

## Phân tích

```
python3 research/phan_tich_ea/phan_tich_chung.py <prefix>_deals.csv --events <prefix>_events_v3.csv --magic <magic> --out bao_cao.md
```

Tôi đã kiểm thử bằng log giả lập của một EA kiểu Trip Trap. Tham số giả lập: lệnh chờ 100, dời lệnh ở 200, lưới 300,
lot × 1.6, trailing bắt đầu 100 bước 50. Báo cáo tìm lại được:
- khoảng cách đặt lệnh chờ 100.0;
- ngưỡng dời lệnh ~200;
- bước lưới ~300;
- hệ số lot 1.585;
- trailing: có lời tối đa − giá đóng ≈ 50, có lời tối đa nhỏ nhất ≈ 104 (tức ≥ 100).

Phần MQL5 chưa được kiểm thử.

## EA hoàn toàn không có file .set (ví dụ chỉ có tài khoản Passview) — chế độ AUTO

Logger đọc lệnh trên server, nên đăng nhập bằng mật khẩu investor vẫn ghi đủ. Những gì không thấy được là input, khung
chart và chỉ báo của EA. Bản Universal 3.10 **mặc định đã ở chế độ AUTO**, không cần biết gì về EA:

| Input | Mặc định | Tác dụng |
|---|---|---|
| `InpIndicators` | `AUTO` | Bộ quét rộng 31 cột: EMA20/50/200, RSI14, ATR14, ADX14, BB20/2, MACD 12/26/9, Stoch 5/3/3, CCI14 trên **M15, H1, H4**, cộng ATR D1 |
| `InpCtxTFs` | `M15,H1,H4` | Xuất file nến kèm chỉ báo cho **cả 3 khung**, để so với khung EA thật sự dùng |
| `InpAutoReport` | true | Ghi `<prefix>_auto.csv` và in vào tab Experts: mọi magic trong tài khoản, comment lệnh (thường lộ tên EA), số rổ BUY/SELL, số lệnh thêm, **khung đoán được** |
| `InpMagicFilter` | 0 | Ghi tất cả magic; báo cáo sẽ tách riêng từng magic |

Các bước:

1. Gắn `TradeLogger_Universal.mq5` lên một chart bất kỳ của tài khoản Passview, chỉ đổi `InpFilePrefix` nếu muốn.
   Nên chạy liên tục (VPS là tốt nhất).
2. Xem tab Experts: dòng `[TradeLogger AUTO] magic=... khung doan: H1; comment: '...'` cho biết ngay có những EA nào
   và mỗi EA ra quyết định theo khung nào (`TICK` = chạy theo tick hoặc lệnh chờ).
3. Sau vài ngày đến vài tuần, chạy báo cáo, chỉ cần tiền tố file:

   ```
   python3 research/phan_tich_ea/phan_tich_chung.py --prefix "C:/.../Common/Files/TradeLogger/tradelog" --out bao_cao.md
   ```

   `--prefix` nhận luôn **thư mục log**. Script tự tìm `*_deals.csv`, `*_events_v3.csv`, `*_ctxbars_*.csv`,
   `*_auto.csv`, `*_m1_*.csv`, rồi
   phân tích **lần lượt từng magic** (bỏ qua magic có dưới 20 deal; đổi bằng `--min-deals`). Chỉ phân tích một EA thì
   thêm `--magic <số>`.
4. Đọc mục 6 và 7 của báo cáo:
   - **Mục 6 — dò khung thời gian:** với từng khung M1…D1, đếm tỉ lệ lệnh rơi vào 10 giây đầu nến, rồi so với tỉ lệ
     nếu ngẫu nhiên. Khung lớn nhất có ≥ 70% lệnh rơi đúng lúc mở nến chính là khung EA ra quyết định. Có file events
     thì script dò cả thời điểm đặt và dời lệnh chờ.
   - **Mục 7 — dò chỉ báo:** tự chọn file ctxbars **đúng khung vừa đoán được**. Với từng cột chỉ báo `i_*` và cột hiệu
     số tự tạo `d_*` (EMA nhanh − chậm, +DI − −DI, MACD/Stoch main − signal), so phân bố lúc vào lệnh đầu với phân bố
     trên mọi nến. Script tính KS, xếp hạng các cột, tách riêng BUY và SELL, rồi gợi ý điều kiện như `≤ 30`, `≥ 70`,
     `> 0 ở 100% lệnh`.
5. Nếu khung đoán được nằm ngoài M15/H1/H4 (ví dụ M5 hoặc D1), hoặc mọi cột đều có KS thấp, đổi `InpIndicators` sang
   danh sách tự khai báo với khung đó (tối đa 40 chỉ báo), rồi thu log tiếp.

Kiểm thử bằng một EA ẩn có quy tắc đã biết. Quy tắc: vào lệnh lúc mở nến H1; BUY khi RSI H1 < 30 và EMA20 > EMA50,
SELL khi RSI H1 > 70 và EMA20 < EMA50. Dữ liệu: 30 000 nến H1, 209 lệnh đầu. Báo cáo tìm ra:
- khung **H1**;
- BUY: `RSI ≤ 30`, `EMA20 − EMA50 > 0 ở 100% lệnh`;
- SELL: `RSI ≥ 70.07`, `EMA20 − EMA50 < 0 ở 100% lệnh`;
- ADX và Stoch (không liên quan) đều có KS < 0.15.

Thử thêm `--prefix` trên một thư mục log trộn 2 EA (EA ẩn trên + một EA kiểu Trip Trap). Script tự tách 2 magic, đoán
`H1` cho EA ẩn và `TICK` cho EA lệnh chờ, rồi chọn đúng file ctxbars H1 để dò. Phần AUTO trong MQL5 (bộ quét rộng,
file `_auto.csv`, ctxbars nhiều khung) **chưa được compile hay chạy thử**.

Giới hạn của việc dò:
- Chỉ tìm được chỉ báo **có trong danh sách đã ghi**. Chỉ báo tự viết (.ex5 riêng) thì không dò được.
- Cần ≥ 30 lệnh đầu mỗi chiều. Với ít lệnh, KS cao có thể chỉ là ngẫu nhiên.
- Điều kiện kết hợp, ví dụ "RSI < 30 **hoặc** giá chạm BB dưới", sẽ hiện ra yếu hơn điều kiện đơn.
- Điều kiện không sinh ra lệnh thì không thấy được trực tiếp, ví dụ lọc tin (chỉ lộ qua khoảng trống không có lệnh) và
  cắt lỗ theo equity chưa từng kích hoạt.

## Mục 8 — quét mọi khung × mọi chỉ báo từ nến M1 (`quet_khung.py`)

Bộ quét trong MT5 (AUTO) chỉ có vài khung và chu kỳ cố định. Mục 8 dùng file nến M1 để Python tự tính:

- **19 khung**: M1 M2 M3 M4 M5 M6 M10 M12 M15 M20 M30 H1 H2 H3 H4 H6 H8 H12 D1. Khung nào chưa đủ 300 nến
  thì bỏ qua, nên D1 cần khoảng 1 năm M1.
- **Mỗi khung khoảng 160 đặc trưng**: giá−EMA (16 chu kỳ 5…200), giá−SMA 20/50/200, **mọi cặp EMA** (120 cặp,
  ví dụ EMA34−EMA89), RSI 2/3/5/7/9/14/21, CCI 14/20, ADX14 và +DI−−DI, BB20 %b, MACD và MACD−signal,
  Stoch 5/3/3 và 14/3/3, ATR14, thân nến.
- Công thức như MT5 (ATR = SMA của TR, MACD signal = SMA, ADX = EMA). Có thể lệch rất nhỏ ở vài trăm nến
  đầu, do cách khởi tạo EMA.

Cách dò:

1. Lấy giá trị mọi đặc trưng tại nến **đã đóng** ngay trước mỗi lệnh đầu của rổ.
2. So với 2000 thời điểm ngẫu nhiên **lúc EA đang rảnh**: không có rổ cùng chiều, và không nằm sát trước một lệnh.
   Lúc rảnh mà điều kiện thật thỏa thì EA đã vào lệnh, nên điều kiện thật hiếm khi thỏa ở các thời điểm này.
3. **Dò quy tắc từng bước.** Mỗi bước chọn điều kiện `≤`/`≥` ngưỡng bao hết các lệnh mà để lại ít thời điểm rảnh
   nhất. Bước sau chỉ tính trên phần còn lại, nên chỉ báo "họ hàng" của điều kiện đã chọn tự bị loại.
4. Chạy y hệt trên "lệnh giả" ngẫu nhiên để biết mức nhiễu. Báo cáo kèm bảng KS từng đặc trưng và khung nổi bật.

Chạy riêng (khoảng 30 giây cho 80 ngày M1):

```
python3 research/phan_tich_ea/quet_khung.py --m1 <prefix>_m1_XAUUSD.csv --deals <prefix>_deals.csv --magic <magic>
```

Hoặc để `phan_tich_chung.py --prefix <thư mục>` tự chạy mục này.

**Kết quả kiểm thử (nói thẳng):** dùng 80 ngày M1 giả lập và một EA ẩn với quy tắc: vào lệnh lúc mở nến M6, BUY khi
EMA34 > EMA89 (M6) và RSI7 (M15) < 25, SELL ngược lại, 70 rổ.

- Mục 6 đoán đúng khung **M6**.
- Mục 8 tìm đúng **vùng**: quá bán/quá mua trên các khung M3–M30. RSI7 M15 có xuất hiện trong quy tắc. Quy tắc
  dò được bao 97–100% lệnh và chỉ còn ~1% thời điểm rảnh thỏa, trong khi lệnh giả còn 70–80%.
- Nhưng bước đầu lại chọn chỉ báo "họ hàng" (Stoch M30, MACD M12) thay vì đúng RSI7 M15, và **chưa tách được**
  bộ lọc EMA34 > EMA89. Lý do: EA vào lệnh ngay khi điều kiện vừa bắt đầu đúng, nên các chỉ báo đo động lượng
  "vừa đổi chiều" trông còn rõ hơn chính điều kiện gốc.

Vì vậy hãy coi quy tắc dò được là **giả thuyết mô tả đúng hành vi**, chưa phải mã gốc. Muốn chốt: viết EA theo
giả thuyết, backtest cùng giai đoạn, rồi so từng lệnh với EA gốc. Với dữ liệu thật càng nhiều rổ (≥ 50 mỗi
chiều) thì càng đáng tin.

## Giới hạn

- Logger không chạy song song với EA khác trong Strategy Tester (Tester chỉ chạy 1 EA). Cần log từ tài khoản
  demo/thật đang chạy EA.
- `live_*` chỉ có khi logger đang chạy đúng lúc deal xảy ra. Khi dời lệnh chờ, `prev_dist` và `dist` cũng đo bằng giá
  lúc logger nhận được sự kiện, nên logger phải đang chạy.
- `k_peak_after_last` xấp xỉ theo nến M1 và giá bid (lệnh SELL chưa trừ spread), nên có thể lệch vài point.
- Hệ số lot bị nhiễu khi lot nhỏ, vì làm tròn 0.01. Báo cáo có cột "hệ số ước lượng từ lot đầu" để giảm nhiễu.
