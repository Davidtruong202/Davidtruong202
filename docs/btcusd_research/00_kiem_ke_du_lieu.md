# Nghiên cứu BTCUSD – EA David Hunter
# Bước 0: Kiểm kê dữ liệu, giải mã sơ bộ và danh sách thông tin còn thiếu

Ngày lập: 28/09/2026 · Trạng thái: **chưa đủ dữ liệu để backtest hoặc xếp hạng phương pháp**

Ký hiệu mức độ chắc chắn:
- ✅ **Xác nhận từ mã nguồn** (đọc trực tiếp code trong repo)
- 🟡 **Suy luận từ log** (có dữ liệu nhưng mẫu nhỏ / gián tiếp)
- ❓ **Chưa đủ dữ liệu** (giả thuyết, chưa được dùng để kết luận)

---

## 1. Kiểm kê dữ liệu

Đã rà soát toàn bộ 11 branch của repo `davidtruong202/davidtruong202`.

### 1.1. Các file được yêu cầu

| File | Tình trạng | Ghi chú |
|---|---|---|
| `tradelog_deals.csv` | ❌ **Không có** trong repo | Chưa được upload |
| `tradelog_orders.csv` | ❌ Không có | |
| `tradelog_events.csv` | ❌ Không có | |
| `tradelog_symbols.csv` | ❌ Không có | |
| `tradelog_bars_XAUUSD_M5.csv` | ❌ Không có | |
| `tradelog_bars_XAUUSD_CURRENT.csv` | ❌ Không có | Xem mục 1.3: tên file cho biết nó sinh ra từ một **phiên bản TradeLogger khác** |
| Mã nguồn EA David Hunter (`.mq5`) | ❌ Không có | Không branch nào có file nào mang tên "Hunter" |
| File `.set` | ❌ Không có | |
| Dữ liệu BTCUSD (nến / tick) | ❌ Không có | |

**Kết luận:** Hiện **không có dữ liệu giao dịch nào** để tính Win Rate, PF, DD… Mọi con số hiệu suất
trong báo cáo này (nếu có) đều lấy từ tài liệu phân tích trước đó, không phải từ tính toán mới.

### 1.2. Những gì liên quan đang có trong repo

| Tài nguyên | Branch | Giá trị cho nghiên cứu |
|---|---|---|
| `MQL5/Experts/TradeLogger.mq5` | `claude/compassionate-pasteur-t6m0nj` | ✅ Chính là công cụ sinh ra các file `tradelog_*.csv` → biết **chính xác schema** và cách tính từng đặc trưng |
| `docs/BE_NhaTrang_phan_tich.md` | cùng branch | 🟡 Phân tích bot "BE Nha Trang" (XAUUSD, Exness) với các setup **ENG, RSI, BRK, PVT, SMC, EMA, LQ** – trùng với các phương pháp bạn nêu |
| `tools/analyze_trades.py`, `tools/backtest_hypothesis.py` | cùng branch | Công cụ phân tích có sẵn, sẽ rà soát lại trước khi tái sử dụng |
| `MQL5/Experts/XAUUSD_ICT_M5.mq5` | branch hiện tại (và mọi branch) | EA ICT/SMC **khác**, không phải David Hunter – không dùng làm Baseline |
| Các EA khác (EMACross, Donchian, MeanReversion, GoldBot…) | các branch khác | Không liên quan trực tiếp |

⚠️ **Câu hỏi cần xác nhận:** "David Hunter" có phải **cùng bot / cùng nhà cung cấp** với "BE Nha Trang"
(chỉ đổi tên hoặc đổi comment), hay là một EA khác có setup trùng tên?
Theo nguyên tắc số 2 ("không suy luận chiến lược chỉ từ tên phương pháp"), tôi **không** mặc định
PVT/RSI/EMA/ENG của David Hunter giống của BE Nha Trang cho tới khi có log để đối chiếu.

### 1.3. Schema dữ liệu (✅ xác nhận từ mã nguồn TradeLogger.mq5)

**`tradelog_deals.csv`** – mỗi dòng là 1 deal BUY/SELL (bỏ qua nạp/rút):
`deal_ticket, order_ticket, position_id, time, time_msc, symbol, type, entry(IN/OUT/INOUT/OUT_BY), volume, price, sl, tp, profit, commission, swap, fee, magic, reason, comment` + 38 cột đặc trưng thị trường.

**Đặc trưng thị trường** (`f_*`) tính trên **nến đã đóng ngay trước thời điểm khớp lệnh**
(`iBarShift(...)+1`) → ✅ **không có look-ahead** ở cột đặc trưng. Gồm: giờ/thứ, ATR14, thân/bóng nến theo ATR,
chuỗi nến cùng màu, RSI14, khoảng cách tới EMA20/50/200 theo ATR, độ dốc EMA, EMA stack, %B và độ rộng
Bollinger(20,2), MACD(12,26,9), Stoch(14,3,3), khoảng cách tới đỉnh/đáy 20 nến, phá đỉnh/đáy 20 nến,
khoảng cách PDH/PDL/giá mở ngày, vị trí trong range ngày, và các đặc trưng khung bias (RSI, EMA50/200, dốc EMA50).

**`tradelog_orders.csv`** – lịch sử order: loại lệnh (market/limit/stop), trạng thái, SL/TP lúc đặt, magic, comment.

**`tradelog_events.csv`** – snapshot vị thế/lệnh chờ mỗi 5 giây: `NEW / MODIFY / GONE / EXISTING` kèm SL, TP, bid, ask.

**`tradelog_symbols.csv`** – digits, point, contract size, tick size/value, lot min/step, đòn bẩy, server.

**`tradelog_bars_<SYMBOL>_<TF>.csv`** – mọi nến kèm cùng bộ đặc trưng → dùng làm **nhóm đối chứng**
("nến có vào lệnh" vs "nến không vào lệnh") để ước lượng ngưỡng của từng setup.

### 1.4. Rủi ro chất lượng dữ liệu đã biết trước (từ thiết kế TradeLogger)

| # | Vấn đề | Ảnh hưởng | Cách xử lý dự kiến |
|---|---|---|---|
| 1 | File `..._CURRENT.csv`: phiên bản TradeLogger hiện tại ghi tên khung thật (M1/M5…), nên file tên `CURRENT` sinh ra từ **phiên bản cũ** với `InpFeatureTF = PERIOD_CURRENT` | Không biết file này thực sự là khung nào | Suy ra khung từ khoảng cách thời gian giữa các nến; không trộn với file M5 |
| 2 | Tài liệu cũ ghi nhận: dữ liệu đầu tiên bị **ghi nhầm khung bias** (M5 thay vì H1) | Cột `f_bias_*` của các lệnh cũ có thể sai | Kiểm tra `feature_tf/bias_tf` trong `symbols.csv`; tính lại đặc trưng từ nến gốc nếu cần |
| 3 | `events.csv` chỉ ghi khi EA đang chạy, chu kỳ 5 giây | Thiếu sự kiện khi terminal tắt; thời điểm dời BE/trailing sai số ±5 giây | Đối chiếu với `deals.csv`; đánh dấu khoảng trống |
| 4 | Cột đặc trưng để **trống** nếu chỉ báo chưa tính xong | Mất mẫu | Tính lại từ nến; loại mẫu nếu không tái tạo được |
| 5 | Chủ tài khoản **can thiệp tay** (magic 0, `DEAL_REASON_MOBILE`) – đã xảy ra ở BE Nha Trang | Làm sai lệch hiệu suất bot | Tách riêng; báo cáo 2 phiên bản: "bot thuần" và "thực tế tài khoản" |
| 6 | Comment của deal OUT thường bị sàn ghi đè (`[sl ...]`, `[tp ...]`) | Mất nhãn setup ở deal đóng | Gán nhãn setup qua `position_id` → deal IN |
| 7 | Một tín hiệu = nhiều vị thế (lệnh chính + tầng 2 `-L2`) và nhiều deal OUT (chốt từng phần) | Đếm sai số lệnh, sai Win Rate | Gộp theo **tín hiệu** (cùng setup, cùng hướng, cách nhau vài giây) và theo **vị thế** – báo cáo cả hai |
| 8 | Spread **không** được ghi trong deals; chỉ có bid/ask tại thời điểm event | Không đo được spread lịch sử | Dùng tick data của sàn cho BTCUSD; với XAUUSD dùng bid/ask trong events làm mẫu |
| 9 | Giờ server (Exness = GMT+0) | Phân phiên Á/Âu/Mỹ | Chuẩn hoá về UTC trước khi phân tích phiên |
| 10 | Lệnh chưa đóng tại thời điểm xuất file | Lợi nhuận chưa thực hiện | Loại khỏi thống kê, liệt kê riêng |
| 11 | Commission/swap phụ thuộc loại tài khoản | Chi phí thực | Lấy từ cột `commission/swap/fee`; xác nhận loại tài khoản |

---

## 2. Giải mã sơ bộ các phương pháp (từ tài liệu BE Nha Trang)

> ⚠️ Toàn bộ mục này là **🟡/❓ suy luận từ log của bot BE Nha Trang** trên **10 tín hiệu / 12 vị thế
> trong ~1,5 ngày (22–23/09/2026)**, mỗi setup chỉ 1–3 mẫu. Đây **không** phải mã nguồn gốc,
> **không** phải dữ liệu David Hunter (trừ khi bạn xác nhận là cùng bot), và **không** đủ để xếp hạng.

### 2.1. Khung quản lý chung

| Thành phần | Magic 79 (lướt) | Magic 78 (ăn dài) | Độ chắc |
|---|---|---|---|
| Setup | RSI, PVT, LQ, BRK, (ENG?), SMC | EMA, SMC | ✅ (theo comment) |
| Lot | rủi ro cố định / khoảng SL (~2% tk ~2000$) | ~53–59$/lệnh | ✅ / 🟡 |
| SL | đỉnh/đáy gần nhất (ngày / 20 nến M5) ± **1,50$** | ≈ **2,5–2,6 × ATR14 M5** | ✅ / 🟡 |
| TP | +**10$** | +**30$** (thực tế là trần) | ✅ |
| Tầng 2 | Limit cách **1,8$**, cùng lot, chung SL | Limit cách **5$** | ✅ |
| BE / chốt phần | +5$ → chốt 50%, SL về hoà vốn, trailing ~5$ | +~10$ → chốt 50%, trailing ~5$ | ✅ / 🟡 |
| Hedge | Có thể giữ BUY và SELL cùng lúc | | ✅ |
| Chu kỳ quét | vào lệnh đúng giây :00/:01, phút chia hết cho 6 | | ❓ |

⚠️ Tầng 2 dùng **cùng lot** và chung SL → rủi ro thực tế mỗi tín hiệu lớn hơn rủi ro "lệnh chính".
Đây là dạng nhồi lệnh (tương tự DCA 2 tầng). Khi tính hiệu suất phải tính **theo tín hiệu** (gộp 2 tầng),
không được để tầng 2 làm đẹp Win Rate.

### 2.2. Bối cảnh vào lệnh từng setup (phân vị so với 706 nến M5)

| Setup | Hướng quan sát | Bối cảnh tại nến vừa đóng | Kiểu tư duy | Số mẫu | Độ chắc |
|---|---|---|---|---|---|
| **PVT** | BUY | RSI 22, Stoch 4, vừa phá đáy 20 nến, giá dưới EMA50 4,5 ATR, sát đáy ngày | Đảo chiều tại cực trị (pivot) | 1 | ❓ |
| **RSI** | SELL | RSI 77 (phân vị 99%), Stoch 92, %B 0,94, cách EMA20 +2,8 ATR, đỉnh ngày | Đảo chiều quá mua/quá bán | 1 | ❓ |
| **EMA** | SELL ×2 | EMA20<50<200, RSI ~41, Stoch 66–69 (vừa hồi), nến đỏ −0,5..−0,8 ATR, dưới EMA20 | Thuận xu hướng, vào sau nhịp hồi | 2 | ❓ |
| **ENG** | SELL | RSI 64, 3 nến xanh liên tiếp, vùng cao ngày (84%) | Mô hình nến (Engulfing?) đảo chiều | 1 | ❓ |
| SMC | SELL ×3 | dưới EMA50 3–3,7 ATR, RSI 30–36, sát đáy ngày, nến trước xanh nhỏ | Thuận xu hướng | 3 | ❓ |
| LQ | BUY | phá đáy 20 nến, %B < 0, sát đáy ngày, nến đỏ dài | Quét thanh khoản → đảo chiều | 1 | ❓ |
| BRK | SELL | sát đỉnh ngày (95%), nến đỏ nhỏ | Phá vỡ / phá vỡ giả | 1 | ❓ |

Ghi chú: tên "ENG" gợi ý Engulfing nhưng **chưa được xác nhận** – mẫu duy nhất cho thấy "3 nến xanh liên tiếp",
chưa thấy cấu trúc nến nhấn chìm trong đặc trưng đã ghi. Không suy luận từ tên.

Quan sát phụ (❓, 10 mẫu): cả 2 lệnh thua (BRK, LQ) đều **ngược xu hướng H1** → là **giả thuyết** cho bộ lọc H1,
chưa phải kết luận.

### 2.3. Kết quả quan sát (không đủ ý nghĩa thống kê)

| Setup | Tín hiệu | Kết quả ($) |
|---|---|---|
| ENG | 1 | +24,72 |
| RSI | 1 | +60,08 |
| BRK | 1 (+L2) | −55,16 |
| PVT | 1 (+L2) | +121,21 |
| SMC | 3 | +5,70 / +1,91 / +1,92 |
| EMA | 2 | +52,02 / +81,29 |
| LQ | 1 (+L2) | −54,64 |
| **Tổng** | 10 | ≈ **+249** trên ~2000$ trong ~1,5 ngày |

Với 1–3 lệnh/setup: **không tính** PF, Max DD, chuỗi thắng/thua theo setup – mọi con số như vậy sẽ gây hiểu nhầm.
Giai đoạn này chỉ trùng với một đoạn thị trường XAUUSD duy nhất; admin cũng xác nhận bot có chuỗi thua trước đó.

---

## 3. Nhận định phương pháp luận cho việc chuyển XAUUSD → BTCUSD

Các điểm dưới đây là **nguyên tắc thiết kế nghiên cứu**, không phải kết quả:

1. **Mọi tham số tính bằng $ cố định đều không chuyển được.** SL buffer 1,50$, TP 10$/30$, tầng 2 1,8$/5$, BE +5$
   được thiết kế cho giá vàng (biên độ M5 vài $). Với BTC, 10$ chỉ là một phần rất nhỏ của biến động M5
   và có thể nhỏ hơn cả spread. → Cần **chuẩn hoá lại mỗi tham số theo ATR tại thời điểm vào lệnh** trên XAUUSD
   (ví dụ TP 10$ ÷ ATR14 M5 lúc đó = k × ATR), rồi áp dụng k × ATR trên BTC. TradeLogger đã ghi `f_atr`
   cho từng deal nên phép chuẩn hoá này tính được trực tiếp khi có file deals.
2. **Tỷ lệ spread / SL** là tiêu chí sống còn cho M1/M5 trên BTC; phải đo từ tick data thật của sàn,
   theo từng giờ trong ngày và cuối tuần.
3. **Phiên giao dịch:** BTC giao dịch 24/7 ở thị trường gốc, nhưng CFD BTC của từng sàn có thể có giờ nghỉ
   bảo trì, spread cuối tuần khác. Cần xác nhận lịch giao dịch & spread cuối tuần của **chính sàn bạn dùng**.
4. **Chi phí qua đêm (swap)** của CFD crypto có thể lớn; phải lấy thông số thực của sàn, không dùng giả định.
5. **Hedge + 2 tầng**: giữ nguyên trong Baseline để đo đúng chiến lược gốc, nhưng báo cáo riêng hiệu suất
   "chỉ lệnh chính" như một giả thuyết cải tiến ở Giai đoạn 2 (vì nhồi lệnh làm tăng rủi ro đuôi).

---

## 4. Kế hoạch nghiên cứu khi có dữ liệu

| Giai đoạn | Việc làm | Đầu ra |
|---|---|---|
| **0. Làm sạch** | Kiểm tra thiếu/trùng/lệch giờ, gộp deal → vị thế → tín hiệu, tách lệnh tay, gắn nhãn setup | Bảng tín hiệu sạch + báo cáo chất lượng dữ liệu |
| **A. Giải mã** | Với mỗi setup: phân phối đặc trưng lúc vào lệnh so với toàn bộ nến (bars) → ước lượng ngưỡng; tái dựng SL/TP/BE/trailing từ events | Quy tắc Entry/Exit + mức độ chắc chắn từng quy tắc |
| **B. Baseline BTC** | Cài đặt lại logic đã giải mã (tham số theo ATR) trong bộ backtest Python dựa trên tick/nến BTC; cùng lúc bạn chạy MT5 Strategy Tester (Real Ticks) nếu có mã nguồn | Bảng hiệu suất từng setup trên BTC, có chi phí |
| **C. Cải tiến** | Mỗi lần 1 giả thuyết (bộ lọc H1, bỏ tầng 2, timeframe M1/M5/M15, regime filter…) chỉ trên tập 60% | Bảng so sánh giả thuyết |
| **D. Kiểm chứng** | 20% validation → 20% test cuối (chỉ chạy **một lần**) → walk-forward → stress test (spread ×2/×3, slippage, chuỗi thua Monte Carlo) | Kết luận đạt/không đạt tiêu chí |
| **E. Đề xuất EA** | Chỉ viết đặc tả; **chưa code** cho tới khi bạn phê duyệt | Đặc tả EA BTCUSD |

Giới hạn cần biết trước: môi trường của tôi **không có MetaTrader 5**. Tôi chỉ chạy được backtest bằng Python
trên dữ liệu bạn cung cấp. Với M1/M5 trên BTC, kết quả Python trên nến OHLC là **xấp xỉ** (không biết thứ tự
chạm SL/TP trong cùng một nến) → cần tick data, hoặc đối chiếu bằng MT5 Strategy Tester "Every tick based on real ticks".

Cỡ mẫu tối thiểu: để có ước lượng PF/Win Rate có ý nghĩa cho **từng setup**, cần ít nhất ~30 tín hiệu/setup
trong log thực; với backtest BTC, mục tiêu ≥ 100 lệnh/setup trên tập nghiên cứu và nhiều giai đoạn thị trường khác nhau
(tăng mạnh, giảm mạnh, đi ngang).

---

## 5. Thông tin cần bạn cung cấp

**Bắt buộc để bắt đầu Phần A:**
1. 6 file `tradelog_*.csv` (upload vào repo, ví dụ thư mục `data/xauusd_log/`, hoặc gửi cho tôi đường dẫn).
2. Xác nhận: **David Hunter có phải là bot "BE Nha Trang"** (hoặc cùng nhà cung cấp) không? Nếu khác, tên comment/magic của David Hunter là gì?
3. Khoảng thời gian bot chạy trong log và có lần nào **đổi cấu hình / đổi phiên bản bot** giữa chừng không.
4. Bạn có can thiệp tay vào lệnh trong giai đoạn log không?

**Bắt buộc để bắt đầu Phần B (BTCUSD):**
5. Tick data BTCUSD của đúng sàn sẽ giao dịch (tối thiểu 12–24 tháng; Real Ticks xuất từ MT5 là tốt nhất),
   hoặc ít nhất nến M1 có kèm spread.
6. Thông số BTCUSD của sàn: contract size, lot min/step, commission, swap long/short, giờ giao dịch, giờ nghỉ bảo trì.
7. Loại tài khoản (Standard / Raw / Zero…), có cho phép Hedge không, đòn bẩy.

**Có thì tốt (nâng độ chắc chắn):**
8. Mã nguồn `.mq5` hoặc file `.set` của David Hunter (nếu có) → chuyển nhiều mục từ 🟡 sang ✅.
9. Tin nhắn/tài liệu của admin về quy tắc (giới hạn lệnh/ngày, lỗ tối đa/ngày, hành vi khi có tin).
10. Mức rủi ro/Drawdown tối đa bạn chấp nhận và số vốn dự kiến.

Khi có mục 1–4, tôi sẽ làm tiếp Phần A (giải mã đầy đủ từng setup với số liệu thật).
Khi có mục 5–7, tôi sẽ bắt đầu Phần B (Baseline trên BTCUSD).
