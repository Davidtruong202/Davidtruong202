# Chiến lược nghiên cứu "HTF Candle-2 Sweep → LTF CISD" cho XAUUSD

Ngày lập: 28/09/2026 · Trạng thái: **bản nghiên cứu, CHƯA được kiểm chứng trên XAUUSD**

Tệp liên quan:
- EA: `MQL5/Experts/FractalCISD_Research.mq5` (EA riêng, magic mặc định 26092801, không sửa EA nào đang có)
- Preset: `MQL5/Presets/FractalCISD_XAUUSD_*.set`
- Backtest tham chiếu Python (cùng logic): `research/fractal_cisd/fractal_cisd_bt.py`
- Kết quả chạy thử công cụ trên BTCUSDc (chỉ để kiểm tra code, không phải bằng chứng cho XAUUSD):
  `research/fractal_cisd/btc_pipeline_check.json`

Ký hiệu độ chắc chắn dùng trong tài liệu:
- **[NGUỒN]**: tác giả có trình bày quy tắc này. Tôi chỉ đọc được qua **trích đoạn của công cụ tìm kiếm**, không mở được toàn trang (xem mục 1.4).
- **[DIỄN GIẢI]**: cách tôi chuyển khái niệm thành điều kiện lập trình được. Đây là lựa chọn của tôi, không phải của tác giả.
- **[GIẢ THUYẾT]**: điều cần backtest mới biết đúng hay sai.

---

## 1. Nguồn nghiên cứu

### 1.1. TTrades: swing point, Fractal Model, CISD, Candle 2/3

| Nội dung | Đường dẫn | Quy tắc tác giả trình bày (theo trích đoạn đọc được) |
|---|---|---|
| Swing point / protected swing | https://ttrades.com/ttrades-ideal-formation-high-probability-swing-points/ , https://ttrades.com/protected-swings-understanding-trends-and-invalidations/ | Swing low tăng: một nến có đáy mà nến bên trái và bên phải đều có đáy cao hơn (swing high đối xứng). Protected swing: giá đóng cửa xuyên qua chuỗi nến ngược chiều đã đưa giá vào đỉnh/đáy đó. Mức quan trọng có thể là high, low hoặc FVG. |
| Candle 2 closure | https://ttrades.com/understanding-candle-2-closures-within-the-fractal-model/ , https://www.youtube.com/watch?v=tyoxl1l-6iI | C1 là nến ngữ cảnh chạm vùng quan trọng. C2 giao dịch ra ngoài range C1 nhưng **đóng lại vào trong**, tức phá vỡ thất bại. C3 được kỳ vọng mở rộng theo hướng mới. C2 chỉ có ý nghĩa khi hình thành tại điểm quan tâm của khung lớn (swing high/low, FVG). |
| CISD | https://ttrades.com/understanding-the-change-in-state-of-delivery-cisd/ , https://ttrades.com/how-change-in-the-state-of-delivery-confirms-swing-points/ | Chiều tăng sang giảm: một chuỗi nến đóng tăng, sau đó giá đóng cửa **dưới giá mở của chuỗi đó** (chiều ngược lại đối xứng). CISD dựa vào giá mở của chuỗi nến chứ không dựa vào swing high/low. |
| Cặp khung thời gian | https://ttrades.com/the-best-timeframes-for-ttrades-fractal-model-simple/ , https://ttrades.com/fractal-model-playbook-aligning-daily-hourly-and-5-minute-charts/ , https://ttrades.com/refining-entries-with-the-fractal-model-precision-with-1-minute-inversions/ | Hai bộ khung được nêu: Daily → 4H → 15m và Daily → 1H → 5m. M1 chỉ là lớp "tinh chỉnh" bên trong cặp 1H–5m. |

### 1.2. Michael J. Huddleston (ICT): liquidity, cấu trúc, OB, FVG

Nguồn gốc là chuỗi video YouTube của ICT (ví dụ 2022 Mentorship). **Tôi không xem được video hay transcript.** Nội dung dưới đây lấy từ các trang tổng hợp của bên thứ ba, nên chỉ được xem là **cách hiểu phổ biến**:

| Khái niệm | Nguồn thứ cấp | Định nghĩa phổ biến |
|---|---|---|
| Mô hình 2022 | https://www.algokings.net/learn/ict-2022-model/ , https://innercircletrader.net/tutorials/complete-ict-trading-strategy-2022/ | Quét thanh khoản ngoài đỉnh/đáy, sau đó market structure shift có displacement, rồi vào lệnh ở FVG do displacement để lại, trong killzone London/New York. |
| Order block | https://www.litefinance.org/blog/for-beginners/trading-strategies/ict-trading-strategy/ | OB tăng là nến giảm cuối cùng trước một nhịp tăng mạnh (OB giảm đối xứng). |
| FVG | cùng nguồn | Mẫu 3 nến: đỉnh nến 1 và đáy nến 3 không chồng lên nhau (FVG tăng). |
| SMT | https://innercircletrader.net/tutorials/ict-smt-divergence-smart-money-technique/ , https://tradingfinder.com/education/forex/ict-smt-divergence/ | Hai mã tương quan phân kỳ tại swing, ví dụ một mã tạo đáy thấp hơn còn mã kia không. Với vàng thường dùng XAU–XAG (thuận chiều) hoặc XAU–DXY (nghịch chiều). |

### 1.3. GxTradez (Garrett): Universal Sequence, SMT, PSP, Strength Switch

| Nội dung | Đường dẫn | Quy tắc tác giả trình bày |
|---|---|---|
| Universal Sequence | https://x.com/GxTradez/status/2008058244808454245 , https://x.com/GxTradez/status/2024750614366810319 | "SMT at key level → Displacement creating gap → SMT fill with gap → LTF continuation entry"; một phiên bản khác là "Key level → 2-stage CIC → displacement away, creating a gap → SMT within the gap → Entry". |
| Strength Switch | https://x.com/GxTradez/status/1937272781969793231 | Tác giả gọi là "2-Stage SMT"; chi tiết nằm trong ảnh hoặc video mà tôi không đọc được. |
| Diễn giải của bên thứ ba | https://nixtrades.com/notes/03-smt-psp-strength-switch/ | PSP: nến C2 đóng lại trong range C1 trên cả hai mã tương quan, nhưng một mã đóng tăng còn mã kia đóng giảm. Strength switch: quan hệ mã dẫn/mã trễ đổi chỗ. |
| Video | https://www.youtube.com/watch?v=3eVxTV_7L2U , https://www.youtube.com/watch?v=oucPinjDdlk | **Chưa xem được.** |

### 1.4. Giới hạn của việc nghiên cứu (nói thẳng)

- Môi trường của tôi **chặn truy cập trực tiếp** ttrades.com, youtube.com, nixtrades.com, datafeed.dukascopy.com và histdata.com (egress proxy trả 403). Tôi chỉ dùng được công cụ tìm kiếm web, tức là đọc tiêu đề và **trích đoạn tóm tắt**, không đọc toàn văn.
- Vì vậy mọi quy tắc gắn nhãn [NGUỒN] ở trên là "tác giả có nói, theo trích đoạn". Tôi chưa thể xác nhận các chi tiết như "chuỗi nến" gồm những nến nào khi có nến doji, hay TTrades đặt SL/TP chính xác ra sao.
- **Tôi không nhận là đã học nội dung video của ba tác giả.** Universal Model và Strength Switch của GxTradez gần như chỉ có trong video, nên chưa đủ định nghĩa để lập trình.
- Muốn nâng độ tin cậy: bạn mở quyền truy cập (Network access của môi trường) tới `ttrades.com` và `youtube.com`, hoặc gửi transcript hay ghi chú, rồi đối chiếu lại mục 2.

---

## 2. Bảng định nghĩa quy tắc (máy đọc được)

Ký hiệu: HTF là khung bối cảnh (mặc định H1), LTF là khung vào lệnh (mặc định M5). Mọi điều kiện chỉ dùng **nến đã đóng**. Mô tả cho BUY; SELL đối xứng.

| # | Thành phần | Điều kiện lập trình | Loại |
|---|---|---|---|
| R1 | Swing (fractal) HTF | Nến q là swing low nếu `low[q] < low[q±i]` với i = 1..`Pivot` (mặc định 2). Swing chỉ được coi là xác nhận khi đủ `Pivot` nến bên phải **đã đóng**. | [NGUỒN] 3 nến (Pivot=1); [DIỄN GIẢI] Pivot=2 để bớt nhiễu |
| R2 | Thanh khoản | Mức thanh khoản bên bán = đáy của swing low R1 **chưa bị lấy**, tức mọi nến từ q+1 tới C1 đều có low > mức đó. Tìm tối đa `SwingLookback` = 48 nến HTF. | [NGUỒN] khái niệm; [DIỄN GIẢI] ngưỡng |
| R3 | Quét thanh khoản + C2 closure | Nến HTF vừa đóng (C2): `low[C2] < mức` **và** `close[C2] > mức`. Chế độ `LIQ_C1` thay mức bằng `low[C1]` (C2 closure thuần). | [NGUỒN] C2 closure tại swing point |
| R4 | SMT (tuỳ chọn, mặc định tắt) | Mã tương quan thuận (XAGUSD): `low_XAG[C2] >= low_XAG[C1]`, tức XAG không phá đáy trong khi XAU đã quét. | [DIỄN GIẢI] rút gọn về C1/C2, **không phải** PSP hay Strength Switch |
| R5 | Cửa sổ hiệu lực | Chỉ tìm tín hiệu LTF trong nến HTF kế tiếp (C3): từ `close(C2)` tới `close(C2) + ValidHTF×HTF` (mặc định 1 nến). | [NGUỒN] C3 là nến mở rộng; [DIỄN GIẢI] độ dài cửa sổ |
| R6 | Huỷ tín hiệu | Bất kỳ nến LTF nào trong cửa sổ **đóng dưới đáy C2** thì huỷ setup (cú quét thất bại, C2 bị phủ định). | [DIỄN GIẢI] |
| R7 | Cực trị nhịp hồi (protected swing) | `ext` = đáy thấp nhất của các nến LTF từ đầu cửa sổ tới nến hiện tại. | [NGUỒN] protected swing; [DIỄN GIẢI] cách đo |
| R8 | Chuỗi tham chiếu (OB theo nghĩa của CISD) | Tìm nến **đóng giảm** gần nhất có chỉ số ≤ nến tạo `ext`, rồi lùi lại qua các nến đóng giảm liền trước. `runOpen` là open của nến đầu chuỗi. | [NGUỒN] CISD dùng open của chuỗi; [DIỄN GIẢI] cách xử lý doji: doji không thuộc chuỗi |
| R9 | CISD (trigger) | Nến LTF vừa đóng là nến tăng, `close > runOpen`, và **chưa có nến nào sau chuỗi đóng trên runOpen trước đó** (lần vượt đầu tiên). | [NGUỒN] + [DIỄN GIẢI] "lần đầu" |
| R10 | FVG (tuỳ chọn, mặc định tắt) | Tồn tại x trong [ext+2 … nến CISD] với `low[x] > high[x-2]`. | [NGUỒN ICT, thứ cấp]; [GIẢ THUYẾT] có cải thiện không |
| R11 | Vào lệnh | Lệnh thị trường ngay tick đầu sau khi nến CISD đóng (BUY ở giá ask). | [DIỄN GIẢI] |
| R12 | SL | `ext − 0.10×ATR14(LTF)`. Với SELL thì cộng thêm spread vì lệnh SELL chạm SL ở giá ask. Bỏ lệnh nếu SL < 0.5 ATR hoặc > 4 ATR. | [NGUỒN] SL sau protected swing; [DIỄN GIẢI] đệm |
| R13 | TP | Mặc định RR cố định **2.0**. Tuỳ chọn TP = đỉnh C2 (thanh khoản đối diện) với RR tối thiểu 1.5. | [DIỄN GIẢI], xem mục 4 |
| R14 | Thoát theo thời gian | Đóng lệnh khi hết `ExitHTF` = 2 nến HTF tính từ lúc C2 đóng (hết C3 và C4) nếu chưa chạm SL/TP. | [DIỄN GIẢI] kỳ vọng "C3 mở rộng" không thành |
| R15 | Phiên | Chỉ vào lệnh 07:00–10:00 và 12:00–16:00 UTC (London, New York AM). Cần khai `GMTOffset` = giờ server − UTC. | [NGUỒN ICT, thứ cấp] killzone; [DIỄN GIẢI] giờ UTC cố định, chưa tính DST |
| R16 | Spread | Bỏ lệnh nếu spread > `MaxSpreadPts` (60 point = 0,60$) hoặc spread > 20% khoảng SL. | [DIỄN GIẢI] |
| R17 | Giới hạn | Tối đa 1 vị thế theo magic, 3 lệnh mỗi ngày, dừng khi thua liên tiếp 3 lệnh trong ngày hoặc lỗ đã đóng ≥ 2% số dư đầu ngày. Rủi ro 0,5%/lệnh; không làm tròn lên lot tối thiểu. | [DIỄN GIẢI] |

### Những khái niệm **không** đưa vào (và lý do)

- **Strength Switch, PSP, Universal Model (GxTradez):** không có định nghĩa gốc đọc được. PSP cần đồng bộ nến giữa hai mã; nếu làm theo diễn giải của bên thứ ba thì sẽ là bịa quy tắc cho tác giả. Tôi chỉ giữ SMT dạng đơn giản (R4) làm bộ lọc tuỳ chọn.
- **OB dạng "nến ngược chiều cuối cùng" như một vùng để đặt lệnh chờ:** trong logic này, open của chuỗi CISD (R8) chính là mức OB mà TTrades mô tả. Thêm một lớp OB/limit riêng sẽ là hai khái niệm chồng nhau, và làm phát sinh thêm câu hỏi về xác suất khớp lệnh chờ.
- **Market structure BOS/CHoCH theo swing LTF:** CISD đã đảm nhận vai trò xác nhận đổi hướng. Dùng cả hai là lặp.
- **Premium/Discount, OTE, killzone Asia, lọc tin tức:** không cần cho logic lõi. Có thể thử sau như giả thuyết riêng.

---

## 3. Sơ đồ điều kiện BUY / SELL

```
Mỗi khi 1 nến HTF (H1) ĐÓNG  → gọi nến đó là C2
│
├─ BUY:  có mức SSL (swing low HTF chưa bị lấy) mà low[C2] < mức < close[C2] ?
├─ SELL: có mức BSL (swing high HTF chưa bị lấy) mà high[C2] > mức > close[C2] ?
│      (tuỳ chọn SMT: XAG không phá đáy/đỉnh C1 tương ứng)
│   không → không có setup (log "HTF_khong_quet")
│   có    → tạo SETUP, cửa sổ = trọn nến HTF kế tiếp (C3)
│
Mỗi khi 1 nến LTF (M5) ĐÓNG, với mỗi SETUP còn hiệu lực:
├─ nến LTF đóng vượt cực trị C2 (BUY: đóng < low C2) → HUỶ
├─ hết cửa sổ C3 → HẾT HẠN
├─ tìm chuỗi nến ngược chiều đưa giá vào cực trị nhịp hồi → runOpen
├─ nến vừa đóng thuận chiều và đóng vượt runOpen lần đầu → CISD
│      (tuỳ chọn: chân CISD có FVG)
└─ CISD → kiểm tra theo thứ tự:
       có vị thế cùng magic? → ngoài phiên? → đủ lệnh/ngày? → chuỗi thua/lỗ ngày?
       → SL trong [0.5, 4] ATR? → spread? → RR (nếu TP = cực trị C2)?
       → lot ≥ lot tối thiểu? → ký quỹ?
       đạt hết → VÀO LỆNH (SL, TP, hẹn giờ đóng = hết C4)
       trượt bước nào → log "TU_CHOI <lý do>", setup vẫn chờ CISD kế tiếp
Vị thế: SL/TP phía sàn; EA đóng theo giờ khi quá 2 nến HTF từ lúc C2 đóng.
```

---

## 4. Giả thuyết chưa chắc chắn (cần backtest XAUUSD)

| # | Giả thuyết | Cách kiểm |
|---|---|---|
| H1 | Điều kiện quét HTF (R3) tốt hơn CISD đơn thuần | So `mac_dinh` với `doi_chung_khong_HTF_sweep` (LIQ_NONE), cùng mọi bộ lọc khác. |
| H2 | Fractal swing tốt hơn C1 thuần | So `LIQ_FRACTAL` với `LIQ_C1`. |
| H3 | Yêu cầu FVG cải thiện expectancy | So `InpRequireFVG` bật/tắt. Trên dữ liệu thử, bộ lọc này cắt khoảng 85–90% số lệnh, nên cần mẫu lớn. |
| H4 | Phiên London/NY tốt hơn cả ngày | So `InpUseSession` bật/tắt, và tách kết quả theo giờ. |
| H5 | TP thanh khoản (C2) tốt hơn RR cố định | So `InpTPMode`. Lưu ý: TP = C2 cho rất ít lệnh vì đa số CISD xảy ra khi giá đã gần đỉnh C2. |
| H6 | H1→M5 là cặp khung hợp lý nhất cho XAUUSD ngắn hạn | So ba preset H1→M5, H4→M15, M15→M1; xem chi phí trên SL (spread/SL) của từng cặp. |
| H7 | Đóng theo giờ sau C4 không cắt mất lệnh thắng | Thống kê R của các lệnh "het_gio" so với các lệnh chạm SL/TP. |

**Lý do chọn H1→M5 làm mặc định (lập luận, chưa phải kết quả đo):**
1. TTrades trực tiếp nêu cặp 1H–5m. M1 chỉ là lớp tinh chỉnh bên trong cặp đó, không phải khung tín hiệu riêng.
2. Chi phí: spread XAUUSD gần như cố định theo giá, còn biên độ nến tăng xấp xỉ theo căn bậc hai thời gian (xấp xỉ bước ngẫu nhiên). SL trên M1 vì thế nhỏ hơn M5 khoảng √5 ≈ 2,2 lần, nên tỷ lệ spread/SL trên M1 cao hơn khoảng 2,2 lần. Với cùng một spread, M1 chịu chi phí tương đối lớn nhất.
3. M15 (cặp H4→M15) có chi phí thấp nhất, nhưng mỗi setup kéo dài 4–8 giờ và cho ít lệnh hơn, nên ít "ngắn hạn" hơn. Preset này được giữ để so sánh.
4. Tất cả điểm trên cần xác nhận bằng spread thực tế và backtest trên dữ liệu của sàn bạn.

---

## 5. Kiểm định

### 5.1. Đã làm được gì

**XAUUSD: chưa có dữ liệu**, nên chưa có bất kỳ số liệu hiệu suất nào. Repo chỉ có nến M1 và tick BTCUSDc; môi trường chặn tải dữ liệu vàng từ Dukascopy và HistData.

Để kiểm tra công cụ và logic (không phải để đánh giá chiến lược), tôi chạy backtest Python trên **BTCUSDc M1 01/2023 → 09/2026** (dữ liệu có sẵn trong repo). Thiết lập: spread lấy từ cột SPREAD của từng nến M1, commission 0, tách 60% đầu làm tập xây dựng (IS) và 40% sau làm tập kiểm tra (OOS). Kết quả xem ở mục 5.3. **Không suy ra bất kỳ điều gì về XAUUSD từ các số này.**

### 5.2. Quy tắc chống nhìn trước trong backtest Python
- Nến HTF và LTF được dựng lại từ M1 và chỉ dùng sau khi đóng. Fractal chỉ dùng khi đủ nến bên phải.
- Lệnh khớp ở giá mở nến M1 kế tiếp, cộng spread của chính nến đó và slippage (tham số).
- Thoát lệnh xét trên từng nến M1. Nếu cùng một nến M1 chạm cả SL lẫn TP thì tính là SL.
- R của mỗi lệnh đã trừ spread, slippage và commission.
- Khác biệt đã biết so với EA: Python chưa mô phỏng giới hạn lỗ ngày và chuỗi thua trong ngày; spread lấy từ dữ liệu nến M1 thay vì spread tick thực.

### 5.3. Kết quả kiểm tra công cụ trên BTCUSDc (KHÔNG áp dụng cho XAUUSD)

(xem bảng ở `research/fractal_cisd/KET_QUA_BTC_PIPELINE.md`)

### 5.4. Kế hoạch backtest XAUUSD (bạn chạy, hoặc gửi dữ liệu cho tôi chạy)

**Dữ liệu cần có:**
1. XAUUSD M1 xuất từ MT5 (Ctrl+U, chọn Bars, Export) từ 2021 tới nay, của đúng sàn bạn giao dịch. Nếu có thể, kèm tick data (xuất Ticks) của ít nhất 3–6 tháng gần nhất để hiệu chỉnh spread.
2. Thông số symbol: contract size, commission mỗi lot, giờ server (GMT+?), có áp dụng DST không.
3. (SMT) XAGUSD M1 cùng giai đoạn.

**Chạy Python (nhanh, lặp nhiều giả thuyết):**
```
python3 research/fractal_cisd/fractal_cisd_bt.py --data XAUUSD_M1_*.csv \
   --point 0.01 --contract 100 --commission <USD/lot round-turn> --slippage 5 \
   --gmt-offset <giờ server - UTC> --out xau_results.json --trades-csv xau_trades.csv
```

**Chạy MT5 Strategy Tester (xác nhận EA):**
- Chế độ **Every tick based on real ticks**, delay mặc định. Dùng commission thật của tài khoản.
- Giai đoạn xây dựng (IS): 2021-01-01 → 2024-06-30. Kiểm tra độc lập (OOS): 2024-07-01 → nay. Chỉ chạy OOS **một lần** sau khi đã chốt tham số trên IS.
- Walk-forward: 4 cửa sổ 12 tháng IS + 6 tháng OOS, trượt 6 tháng.
- Stress: tăng spread (Tester cho đặt spread cố định: 1×, 1,5×, 2×, 3× spread trung bình), thêm delay 100–500 ms.
- Đọc log `[FCISD]` và tệp `Common\Files\FCISD_<symbol>_<magic>.csv` để đối chiếu từng lệnh với backtest Python (thời điểm tín hiệu, SL, TP nên khớp; giá vào có thể chênh do spread).

**Chỉ số báo cáo cho mỗi biến thể và mỗi tập IS/OOS:** số lệnh, lợi nhuận (R và $), Max DD (R và %), Win Rate, Profit Factor, Expectancy (R/lệnh), RR thực tế (TB lệnh thắng / TB lệnh thua), chuỗi thua dài nhất, phân bổ lý do thoát (SL/TP/hết giờ), kết quả khi spread ×1,5 / ×2 / ×3.

**Ablation (mỗi lần chỉ đổi một yếu tố so với mặc định):** H1–H7 ở mục 4. Một bộ lọc chỉ được giữ nếu cải thiện expectancy trên **cả IS và OOS** và không làm số lệnh giảm dưới ~100 lệnh/tập.

**Tiêu chí so sánh với Baseline.** Trong repo này không có EA-PRO hay Baseline nào. Tôi đề xuất dùng hai mốc so sánh:
1. Biến thể đối chứng `LIQ_NONE` (CISD không có bối cảnh HTF), để đo giá trị gia tăng của phần "ICT/TTrades".
2. Baseline EA-PRO của bạn (nếu gửi repo), chạy cùng giai đoạn, cùng sàn, cùng chi phí.

Chiến lược chỉ nên được xem là "đáng tiếp tục" nếu trên OOS có: ≥ 100 lệnh, PF ≥ 1,2 khi spread ×1,5, expectancy > 0 sau chi phí, Max DD ≤ 15R, và lợi thế so với đối chứng `LIQ_NONE` không biến mất khi spread ×2. Đây là ngưỡng đề xuất, bạn có thể điều chỉnh theo khẩu vị rủi ro.

---

## 6. Trạng thái compile

**Chưa compile.** Môi trường này không có MetaTrader 5, MetaEditor hay Wine. Mã đã được rà soát thủ công nhưng chưa qua trình biên dịch. Bạn cần mở MetaEditor, nhấn F7 và gửi lại danh sách lỗi hoặc cảnh báo (nếu có) để tôi sửa.
