# EA Phoenix Grid V0.10 / V0.11 TEST — chế độ quan sát

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: TEST.**
>
> - Bản hiện hành là **V0.11** (30/09/2026). So với V0.10, V0.11 chỉ đổi giao diện: bảng chuyển sang góc trái trên
>   chart, bỏ biểu tượng phượng hoàng, bỏ dịch chart. Thuật toán, input nhận diện và các cột log giữ nguyên.
> - Môi trường làm việc của tôi không có MetaEditor, nên tôi chưa compile được. Ngày 30/09/2026 bạn phản hồi V0.10
>   "khá ổn", nhưng chưa gửi kết quả compile (số lỗi, số cảnh báo) cho tôi.
> - Bản này **không gửi lệnh**. Mã nguồn không có `OrderSend`, `CTrade`, `PositionClose` hay lời gọi giao dịch nào
>   khác (đã kiểm tra tĩnh, Mục 10).
> - Chưa có backtest. Không có con số hiệu suất nào trong tài liệu này.

| Bản | File | Ghi chú |
|---|---|---|
| **V0.11 TEST** | [`EA_PHOENIX_GRID_V0_11_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_11_TEST.mq5) | Bản hiện hành |
| V0.10 TEST | [`EA_PHOENIX_GRID_V0_10_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_10_TEST.mq5) | Giữ lại để rollback (bảng bên phải, có biểu tượng) |

## 1. Vì sao có bản EA này lúc này

- Ngày 30/09/2026 bạn yêu cầu "làm EA dần". Theo kế hoạch đã duyệt (Mục 18), EA giao dịch đến sau PG-R1.0. Vì vậy
  EA được làm song song theo từng bậc, và bậc đầu tiên **không giao dịch**.
- V0.10 là công cụ quan sát. Nó có ba chức năng:
  - Hiển thị trạng thái thị trường theo đúng định nghĩa Mục 6.
  - Dựng bảng điều khiển theo Mục 19.
  - Ước tính rủi ro theo Mục 8 bằng thông số đọc trực tiếp từ MT5.
- V0.10 ghi log CSV. Ở R0.2, bộ phân loại Python phải cho cùng trạng thái trên cùng dữ liệu (phần phân loại của
  NT-29).
- File nằm trong repo `Davidtruong202` vì phiên làm việc của tôi chỉ được ghi repo này. Khi thành EA giao dịch
  (V1.00 TEST), EA sẽ chuyển sang EA-PRO theo điểm 10 Mục 21 của kế hoạch.

## 2. Lộ trình EA (song song với lộ trình nghiên cứu)

| Bản | Nội dung | Gửi lệnh? | Điều kiện bắt đầu |
|---|---|---|---|
| **V0.10 / V0.11 TEST** | Quan sát: nhận diện trạng thái, bảng điều khiển, ước tính rủi ro, log CSV. V0.11 chỉ đổi giao diện | **Không** | Yêu cầu 30/09/2026 (bản này) |
| V0.20 TEST | Hạ tầng thực thi, chưa có chiến lược:<br>- RiskGate theo Mục 8.2 (4)<br>- Sổ basket, lưu và khôi phục trạng thái<br>- State machine Mục 12, nút ĐÓNG<br>- Vị thế lạ trên tài khoản riêng → PAUSED + cảnh báo | Chỉ demo / tester | Bạn duyệt đặc tả V0.20 |
| V0.3x TEST | Từng module (Entry, DCA, Hedge, Recovery), mỗi module một bản | Chỉ demo / tester | Module đó qua cổng nghiên cứu (A, C, D, E) + bạn duyệt |
| V1.00 TEST | Chỉ gồm module đã duyệt; forward demo ≥ 3 tháng (G3) | Demo | PG-R1.0 được duyệt |

Không bản nào chạy tiền thật trước quyết định LIVE_REAL của bạn.

## 3. Cài đặt và chạy

### 3.1. Compile

1. Chép file vào `<Data Folder>\MQL5\Experts\PhoenixGrid\` (MT5: File → Open Data Folder).
2. Mở bằng MetaEditor, nhấn F7.
3. Gửi tôi toàn bộ dòng lỗi và cảnh báo trong tab Errors, kể cả cảnh báo. Tôi sẽ sửa thành V0.11.

File lưu dạng UTF-8 có BOM để MetaEditor đọc đúng tiếng Việt.

### 3.2. Chạy trên chart

- Tài khoản Phoenix (Exness-MT5Real20), chart **XAUUSDc**, khung thời gian nào cũng được, vì EA tự dùng M5 và M1.
- Bảng nằm ở góc trái trên, ngay dưới dòng tên chart. Nếu chart đang bật One Click Trading, bảng sẽ che bảng giao dịch
  nhanh. Khi đó tắt One Click Trading trên chart này (chuột phải vào chart).
- Khi thay V0.10 bằng V0.11 trên cùng chart, gỡ V0.10 trước. V0.10 tự trả lại chế độ dịch chart như cũ khi bị gỡ.
- **Để TẮT "Allow Algo Trading"** trong thuộc tính EA. V0.10 không cần quyền giao dịch, và tắt quyền là thêm một lớp
  an toàn trên tài khoản thật. EA vẫn nhận tick và cập nhật bảng khi tắt quyền này.
- Tài khoản đang có 3 vị thế mở (lần đọc thông số 30/09/2026). V0.10 chỉ báo "Vị thế khác" màu cam, không đụng vào
  chúng. Trước khi chạy bản giao dịch (V0.20 trở đi), tài khoản riêng phải không còn vị thế lạ.

### 3.3. Strategy Tester (chế độ trực quan)

- Symbol XAUUSDc, chế độ **"Every tick based on real ticks"**. Tốc độ và mật độ tick chỉ có nghĩa với tick thật.
- MT5 không gửi sự kiện chart cho EA trong tester, nên các nút trên bảng không bấm được. Bảng và hộp giá vẫn hiển
  thị.
- Log tester ghi vào file riêng `PG_V011_trang_thai_XAUUSDc_tester_YYYYMM.csv` (V0.10: `PG_V010_…`), ghi mới mỗi lần
  chạy. File này không lẫn với log chạy thật.

## 4. Cần kiểm tra khi chạy lần đầu

| # | Kiểm tra | Kết quả mong đợi |
|---|---|---|
| 1 | Compile | 0 lỗi. Cảnh báo (nếu có) gửi tôi |
| 2 | Bảng điều khiển | V0.11: nằm góc trái trên, dưới dòng tên chart, chữ tiếng Việt đủ dấu, không có biểu tượng; nến mới nhất ở bên phải, không bị che |
| 3 | Thông báo khởi động | "Khởi động V0.11 TEST: chế độ quan sát, không gửi lệnh", "Symbol XAUUSDc, tiền tài khoản USC" và "Tài khoản có 3 vị thế không thuộc Phoenix" |
| 4 | Sau tối đa 1 nến M5 | Dòng "Lọc vào lệnh" hết "Chờ dữ liệu". Có ATR, ADX, ER, chạm biên |
| 5 | Khi có SIDEWAYS | Chip SIDEWAYS sáng, hộp màu vàng sẫm vẽ trên chart, hai đường chấm cam là mức cảnh báo |
| 6 | Rủi ro ước tính | Lỗ 100 USD / lot min = 100,00 (≈ 2% của 5.000); margin lot min ≈ 2 USC; "Phòng thủ tối đa" khoảng 18–27 USD tùy ATR (Mục 7.9) |
| 7 | File log | `Common\Files\PhoenixGrid\PG_V011_trang_thai_XAUUSDc_YYYYMM.csv`, mỗi 5 phút một dòng `M5` |
| 8 | Tab Journal / Experts | Không có lỗi `PG:` lặp lại (ví dụ "không mở được log") |
| 9 | Nút | TẠM DỪNG / TIẾP TỤC đổi thành "XÁC NHẬN? 5s" ở lần bấm đầu. ĐÓNG BASKET / ĐÓNG TẤT CẢ chỉ báo "chức năng có từ V0.20" |

Nếu bảng bị chồng chữ trên màn hình độ phân giải cao, chỉnh `Tỷ lệ kích thước bảng` (0,8–1,5). Tọa độ bảng đã tự
nhân theo DPI màn hình. Nút "–" ở đầu bảng thu gọn bảng còn một dòng.

## 5. Tham số và đối chiếu kế hoạch

Cột "Khoảng duyệt" lấy từ Mục 13.10. Mọi giá trị mặc định nằm trong khoảng đã duyệt, trừ các dòng đánh dấu ⚠, là
những tham số kế hoạch có nhắc nhưng chưa ghi khoảng. Các dòng ⚠ được liệt kê lại ở Mục 8 để bạn duyệt.

| Input (nhãn trên MT5) | Mặc định | Ký hiệu kế hoạch | Khoảng duyệt |
|---|---|---|---|
| Số nến M5 dựng hộp giá | 48 | N_box | 24–72 |
| Độ rộng hộp tối thiểu / tối đa (× ATR M5) | 1,5 / 6,0 | w_min / w_max | 1,5 – 6 |
| ADX M5 sideways / xu hướng | 22 / 27 | a_side / a_trend | 18–25 / 25–30 |
| Số nến M5 tính ER và độ dốc | 24 | N của ER_N, β_N | ⚠ chưa có khoảng |
| ER sideways / xu hướng | 0,30 / 0,40 | e_side / e_trend | 0,20–0,35 / ≥ 0,40 |
| Độ dốc tối đa khi sideways / tối thiểu khi xu hướng | 0,05 / 0,10 | β_side / β_t | ⚠ chưa có khoảng |
| Dung sai chạm biên; số lần chạm | 0,15; 2 | τ; t_U, t_L ≥ 2 | 0,10–0,20; ≥ 2 |
| Số nến nhận / bỏ trạng thái | 2 / 2 | h_in / h_out | 1–3 |
| Đệm cảnh báo breakout | 0,35 | b_w | 0,2–0,5 × ATR5 |
| Cửa sổ tick; tốc độ tick cảnh báo | 15 giây; 1,0 | Δ; v_w | 5–30 giây; 0,5–1,5 × ATR1 |
| Mật độ tick cảnh báo | 2,0 | λ_w | 1,5–3 |
| Xác nhận: M1 đóng vượt; giá vượt; ở ngoài liên tục | 0,30; 1,0; 90 giây | b_c; b_x; T_c | 0,1–0,5; 0,8–1,5; 30–180 giây |
| Breakout giả: quay vào; thời hạn | 0,30 × W; 15 phút | r_f; T_f | 0,2–0,5 × W; 5–30 phút |
| Vùng mới: số nến tối thiểu; ADX giảm | 24; 5 | N_min; Δ_adx | 12–36; 3–8 |
| Theo dõi breakout tối đa | 288 nến M5 | — | ⚠ mới (Mục 8) |
| Spread tối đa tuyệt đối; × trung vị 30 phút | 0,26 USD; 1,5 | s_abs; ŝ_max | p99 tài khoản Cent (0,26 theo R0.1); 1,3–2 |
| Mất tick | 60 giây | — | 60 giây (Mục 6) |
| Phút trước giờ nghỉ | 15 | — | ⚠ kế hoạch ghi "sát giờ nghỉ", chưa có số |
| Vốn gốc; α; ngân sách basket | 5.000; 0,5; 1% | E_ref; α; r_b | —; {0; 0,5; 1}; 1% (Mục 21, điểm 1) |
| Số bậc; khoảng cách bậc | 3; 1,15 × ATR5 | n_max; k_d | 1–4; 0,6–1,5 |
| Trượt mỗi chiều; trượt khi cắt | 0,05; 2,0 USD | trượt; ε | 0,05 (Mục 7.1); 2 (Bảng D) |
| Commission + phí khứ hồi mỗi lot | 0 | commission | R0.1 đo được 0 |
| Magic | 20260930 | — | Magic riêng (Mục 21, điểm 11) |

Các tham số nhận diện sẽ được thay bằng kết quả A0. Không tối ưu trên các giá trị này trước khi A0 chạy.

## 6. Bảng điều khiển

Bảng theo Mục 19, neo góc trái trên chart (V0.11). Đầu bảng có ba dòng "DAVID HUNTER", "PHOENIX GRID" và
"0941920986". V0.10 có thêm biểu tượng phượng hoàng; từ V0.11 bỏ theo yêu cầu ngày 30/09/2026.

| Khu vực | Nội dung |
|---|---|
| Đầu bảng | Phiên bản, trạng thái EA (QUAN SÁT / TẠM DỪNG), nút thu gọn |
| Trạng thái thị trường | 6 chip: SIDEWAYS, TĂNG, GIẢM, BREAKOUT (CẢNH BÁO ↑↓ / BREAKOUT ↑↓), B.GIẢ (sáng 5 phút), VÙNG MỚI. Dòng bộ lọc vào lệnh |
| Thông tin tài khoản | Balance, Equity, lãi/lỗ thả nổi, hôm nay, drawdown hiện tại và lớn nhất, free margin, margin level, số vị thế Phoenix và vị thế khác |
| Vùng giá & breakout | Biên hộp, độ rộng, mức cảnh báo, ATR M5/M1, ADX (DI+/DI−), ER, độ dốc, số chạm biên, tốc độ và mật độ tick, số nến từ cảnh báo, hộp sau breakout |
| Rủi ro (ước tính) | Vốn tham chiếu, ngân sách basket, phòng thủ tối đa, số bậc × lot, lỗ 100 USD với lot min, margin lot min, spread hiện tại và trung vị |
| Chu kỳ Phoenix | 6 bước. V0.10 chỉ sáng bước 1 (Sideways), 3 (Breakout), 5 (Vùng mới), vì bước 2, 4, 6 cần lệnh |
| Thông báo | 4 thông báo gần nhất (cũng in ra tab Experts) |
| Nút | TIẾP TỤC, TẠM DỪNG (xác nhận 2 bước, chỉ dừng ghi log), ĐÓNG BASKET, ĐÓNG TẤT CẢ (chưa có chức năng) |

## 7. Đặc tả thuật toán

Bộ phân loại Python ở R0.2 phải làm đúng như mục này để đối chiếu với log của EA.

### 7.1. Chỉ báo

- ATR5 = `iATR(M5, 14)`, ATR1 = `iATR(M1, 14)`. ATR của MT5 là trung bình cộng TR (không phải Wilder), giống cách
  tính ở phụ lục 02.
- ADX, DI+, DI− = `iADX(M5, 14)`, bản ADX chuẩn của MT5 (không phải `iADXWilder`).
- Mọi giá trị M5 lấy tại nến vừa đóng (shift 1). ATR1 lấy tại nến M1 vừa đóng, cập nhật mỗi nến M1.
- Trước khi dùng, EA chờ chỉ báo tính xong nến mới (`BarsCalculated ≥ Bars`). Nếu 10 lần chờ vẫn chưa xong, EA dùng
  giá trị hiện có và ghi dòng cảnh báo vào tab Experts.

### 7.2. Hộp giá và đặc trưng M5 (mỗi nến M5 đóng)

- Hộp trên N_box nến gần nhất: U = max High, L = min Low, W = U − L, M = (U + L)/2 (giá Bid, như nến MT5).
- Đỉnh swing tại nến i: High_i > High của 2 nến trước và High_i ≥ High của 2 nến sau (đáy đối xứng). Chỉ xét nến có
  đủ 2 nến mỗi bên trong cửa sổ. t_U = số đỉnh swing có High ≥ U − τW; t_L = số đáy swing có Low ≤ L + τW.
- ER_N = |C_1 − C_{N+1}| / Σ_{i=1..N} |C_i − C_{i+1}| (C_1 là nến vừa đóng).
- β_N = hệ số góc hồi quy bình phương nhỏ nhất của Close trên N nến cuối, chia ATR5 (đơn vị ATR mỗi nến).

### 7.3. Trạng thái cấu trúc

- Trạng thái thô theo Mục 6:
  - SIDEWAYS: w_min ≤ W/ATR5 ≤ w_max, ADX < a_side, ER < e_side, t_U ≥ 2, t_L ≥ 2, |β| < β_side.
  - TĂNG: ADX ≥ a_trend, DI+ > DI−, ER ≥ e_trend, β ≥ β_t.
  - GIẢM: đối xứng với TĂNG.
  - Không thỏa điều kiện nào: KHÔNG RÕ.
- Chống nhấp nháy: trạng thái mới được nhận khi trạng thái thô giống nhau h_in nến liên tiếp. Riêng việc về KHÔNG RÕ
  cần h_out nến liên tiếp.
- Khởi động nóng: khi gắn EA, trạng thái cấu trúc được dựng lại từ 24 nến M5 gần nhất, không thông báo, không ghi
  log. Trạng thái breakout không dựng lại được, vì cần tick.

### 7.4. Hộp tham chiếu

Hộp tham chiếu là hộp dùng để phát hiện breakout. Mỗi nến M5 đóng, khi không có breakout đang theo dõi:

1. Nếu đang giữ **hộp sau breakout** (Mục 7.6): tính lại hộp đó trên cửa sổ sau breakout.
   - Còn thỏa SIDEWAYS thì cập nhật.
   - Sai h_out nến liên tiếp thì bỏ (sự kiện `HOP_SAU_BREAKOUT_KET_THUC`), rồi xét bước 2.
2. Nếu trạng thái cấu trúc là SIDEWAYS thì hộp tham chiếu là hộp N_box nến (trượt theo từng nến).
3. Nếu không, không có hộp tham chiếu, và không có cảnh báo breakout.

Khi breakout đang được theo dõi (cảnh báo hoặc đã xác nhận), hộp tham chiếu đứng yên.

### 7.5. Breakout theo tick (xét trên từng tick, chiều ↓ đối xứng)

| Sự kiện | Điều kiện |
|---|---|
| `CANH_BAO` ↑ | Không có breakout đang theo dõi, có hộp tham chiếu, và (bid ≥ U + b_w × ATR5) hoặc (bid > U và v ≥ v_w và λ ≥ λ_w) |
| `XAC_NHAN` | Đang cảnh báo, và một trong ba: (bid ≥ U + b_x × ATR5), hoặc (bid > U liên tục T_c giây), hoặc (nến M1 đóng ≥ U + b_c × ATR5) |
| `BREAKOUT_GIA` | Đang cảnh báo hoặc đã xác nhận, trong vòng T_f phút từ lúc cảnh báo, bid ≤ U − r_f × W |
| `CANH_BAO_HET_HAN` ⚠ | Đang cảnh báo, quá T_f phút mà chưa xác nhận |

Mốc cửa sổ sau breakout = giờ mở của nến M5 đầu tiên bắt đầu tại hoặc sau lúc xác nhận.

### 7.6. Sau xác nhận: vùng mới

Mỗi nến M5 đóng sau xác nhận:

- Cửa sổ sau breakout gồm các nến mở từ mốc, tối đa N_box nến. Gọi số nến là K. Trên cửa sổ này tính U', L', W', M',
  t_U', t_L', và ER, β trên min(K, N_ER) nến. ADX là giá trị của nến.
- Điều kiện "sideways sau breakout" là K ≥ N_min và bộ điều kiện SIDEWAYS của Mục 7.3 áp cho hộp này.
- ADX đỉnh được theo dõi từ lúc cảnh báo.

| Sự kiện | Điều kiện, đúng h_in nến liên tiếp | Kết quả |
|---|---|---|
| `VUNG_MOI` | Sideways sau breakout, và \|M' − M_cũ\| ≥ 0,5 × W_cũ, và ADX ≤ ADX đỉnh − Δ_adx | Hộp tham chiếu = hộp sau breakout, nhãn VÙNG MỚI |
| `KHONG_THANH_VUNG_MOI` ⚠ | Sideways sau breakout, và \|M' − M_cũ\| < 0,5 × W_cũ | Hộp tham chiếu = hộp sau breakout, nhãn SIDEWAYS |
| `BREAKOUT_HET_THEO_DOI` ⚠ | Đã qua 288 nến M5 kể từ cảnh báo mà chưa có hai sự kiện trên | Bỏ hộp tham chiếu |
| `XU_HUONG_SAU_BREAKOUT` | Trạng thái cấu trúc là xu hướng cùng chiều breakout (ghi một lần) | Chỉ ghi nhận, vẫn chờ vùng mới |

Hộp sau breakout được giữ và tính lại mỗi nến theo Mục 7.4, bước 1. Khi K đạt N_box, hộp này trùng với hộp N_box
thông thường.

### 7.7. Đặc trưng tick

- EA nạp **mọi** tick mới bằng `CopyTicksRange` từ mili-giây sau tick cuối đã xử lý, nên không bỏ sót tick khi MT5 gộp
  sự kiện OnTick.
- m = (bid + ask)/2.
- v = (m_t − m_{t−Δ}) / ATR1. m_{t−Δ} là giá giữa của tick cuối cùng có thời điểm ≤ t − Δ.
- λ = số tick trong (t − Δ, t] chia cho trung vị số tick của các ô Δ giây trong 60 phút gần nhất.
  - Ô chia theo thời gian tuyệt đối: ô = ⌊msc / (1000·Δ)⌋.
  - Ô trống giữa hai tick chỉ được tính (bằng 0) khi khoảng trống dưới 60 giây. Giờ nghỉ và mất kết nối không kéo
    trung vị về 0.

### 7.8. Bộ lọc không vào lệnh (V0.10 chỉ hiển thị)

Xét theo thứ tự, gặp điều kiện đầu tiên thì dừng:

1. `CHO_DU_LIEU`: chưa tính được nến M5 nào.
2. `NGOAI_PHIEN`: ngoài phiên giao dịch. Phiên đọc từ `SymbolInfoSessionTrade`.
3. `SAT_GIO_NGHI`: còn dưới 15 phút tới hết phiên. Phiên kéo tới 24:00 được coi là nối sang ngày sau.
4. `MAT_TICK`: không có tick quá 60 giây.
5. `SPREAD_GIAN`: spread > min(s_abs, ŝ_max × trung vị 30 phút). Trung vị lấy từ mẫu mỗi giây, chỉ lấy mẫu khi có tick
   trong 10 giây gần nhất.

Chưa có lọc tin tức (Mục 9).

### 7.9. Ước tính rủi ro

Lấy từ Mục 8.2 (2) với w_k = 1 và V_0 = lot tối thiểu. EA giải ngược ra khoảng phòng thủ tối đa D.

```
E_ref = min(Equity, Vốn gốc + α × max(0, Equity − Vốn gốc))
R_b   = r_b × E_ref
VPP   = TICK_VALUE_LOSS / TICK_SIZE                      (đọc từ MT5; XAUUSDc: 100 USC mỗi lot mỗi 1 USD)
c_rt  = VPP × (spread trung vị + 2 × trượt) + phí khứ hồi
d_k   = k × k_d × ATR5,  k = 0..m−1
D     = (R_b / V_min − m × c_rt + VPP × Σ d_k) / (m × VPP) − ε
Chọn m lớn nhất (≤ số bậc) sao cho D > (m − 1) × k_d × ATR5. Không có m nào → "KHÔNG ĐỦ NGÂN SÁCH".
```

Kiểm tra công thức với Bảng C của kế hoạch (đặt trượt = 0, ε = 0, bước 6 USD, spread 0,26):

| Basket | Bảng C | Công thức V0.10 |
|---|---|---|
| B1 | 49,7 USD | 49,74 |
| B2 | 27,7 | 27,74 |
| B3 | 22,4 | 22,41 |
| B3, r_b = 2% | 39,1 | 39,07 |

Với mặc định V0.10 (trượt 0,05 mỗi chiều, ε = 2 USD, k_d = 1,15, 3 bậc × 0,01), E = 5.000 USC, r_b = 1%:

| ATR5 (phụ lục 02) | Phòng thủ tối đa D |
|---|---|
| 3,18 (p10) | 17,96 USD |
| 5,24 (trung vị) | 20,33 USD |
| 10,68 (p90) | 26,59 USD |

Nghĩa là với ngân sách 1%, basket 3 bậc lot tối thiểu chỉ chịu được khoảng 18–27 USD đi ngược tính từ lệnh đầu. Con số
này thấp hơn nhiều so với biên độ ngày trung vị khoảng 100 USD. Kết luận này giống Mục 8.5: phòng thủ phải xảy ra sớm,
không thể "gồng" basket.

### 7.10. Thứ tự xử lý

- **OnTick**:
  1. Nạp các tick mới.
  2. Nếu có nến M1 mới: cập nhật ATR1, xét xác nhận bằng nến M1.
  3. Nếu có nến M5 mới: tính trạng thái (Mục 7.2–7.6).
  4. Với từng tick mới theo thứ tự thời gian: cập nhật v, λ, rồi xét breakout (Mục 7.5).
- **OnTimer (mỗi giây)**:
  1. Thử lại nến M5 nếu lần trước chỉ báo chưa sẵn sàng.
  2. Lấy mẫu spread, cập nhật bộ lọc và tài khoản.
  3. Vẽ bảng và hộp.

## 8. Chi tiết cài đặt chưa có trong kế hoạch — cần bạn duyệt

Các chi tiết dưới đây không làm EA giao dịch. Chúng quyết định cách bộ phân loại quan sát gán nhãn, và A0 sẽ đo
chúng cùng các tham số khác. Nếu bạn không đồng ý điểm nào, tôi sửa ở V0.11.

| # | Chi tiết | Lựa chọn trong V0.10 | Lý do |
|---|---|---|---|
| 1 | Chu kỳ ATR, ADX | 14 | Mặc định MT5, cùng đơn vị ATR với phụ lục 02 |
| 2 | Định nghĩa đỉnh/đáy swing khi đếm chạm biên | Fractal 2 nến mỗi bên | Kế hoạch dùng swing k ∈ {2; 3} cho Entry; chọn 2 để có đủ điểm trong hộp 48 nến |
| 3 | N của ER và độ dốc; β_side; β_t | 24; 0,05; 0,10 | Mục 13.10 chưa ghi khoảng. Đề xuất khoảng cho A0: N ∈ {12; 24; 36}, β_side ∈ {0,03; 0,05; 0,08}, β_t ∈ {0,08; 0,10; 0,15} |
| 4 | "Cửa sổ ≥ N_min nến kể từ breakout" của VÙNG MỚI | Nến M5 mở từ lúc xác nhận, tối đa N_box nến; ER và β trên min(K, N_ER) | Hộp mới không được lẫn nến trước breakout, nếu không W luôn quá rộng và không bao giờ thỏa SIDEWAYS |
| 5 | Chống nhấp nháy cho VÙNG MỚI | Đúng h_in nến liên tiếp | Mục 6 áp chống nhấp nháy cho VÙNG MỚI |
| 6 | Cảnh báo không được xác nhận | Hết hạn sau T_f phút (`CANH_BAO_HET_HAN`) | Kế hoạch chưa nói cảnh báo kết thúc thế nào nếu không xác nhận cũng không giả |
| 7 | Sideways lại quanh hộp cũ sau xác nhận | `KHONG_THANH_VUNG_MOI`, nhãn SIDEWAYS | Tránh treo trạng thái BREAKOUT nhiều giờ khi giá đã về vùng cũ |
| 8 | Giữ hộp sau breakout | Tính lại mỗi nến; bỏ khi sai h_out nến liên tiếp | Cùng quy tắc chống nhấp nháy |
| 9 | Theo dõi breakout tối đa | 288 nến M5 (24 giờ) | Bằng cận dưới T_legacy (1 ngày giao dịch, Mục 13.10): sau mốc đó basket cũ đã bị đóng theo time stop |
| 10 | Breakout theo dõi cùng lúc | Một. Khi đang theo dõi, không xét breakout phía bên kia hộp cũ | Đơn giản; khớp với một hedge mỗi basket |
| 11 | "Sát giờ nghỉ" | 15 phút trước khi phiên kết thúc | Kế hoạch chưa có số |
| 12 | Ước tính D | w_k = 1, lot tối thiểu | Chỉ để hiển thị; V0.20 sẽ dùng đúng công thức Mục 8.2 với cấu hình basket được duyệt |

## 9. Giới hạn đã biết

- Chưa có lọc tin tức. Cần lịch tin (DL trong Mục 17).
- Trạng thái breakout không khôi phục khi gắn lại EA. Chỉ trạng thái cấu trúc được dựng lại (Mục 7.3).
- "Hôm nay" tính từ Equity lúc EA thấy ngày server mới, hoặc lúc gắn EA nếu gắn giữa ngày.
- Đỉnh Equity và DD lớn nhất lưu trong Global Variables của terminal (`PG_<login>_<magic>_…`). Xóa Global Variables
  thì mất số liệu này. Global Variables chỉ nằm trên máy của bạn, không ghi vào log hay repo.
- Nút TẠM DỪNG chỉ dừng ghi log, vì V0.10 không có lệnh để dừng.
- Khi đang theo dõi một breakout đã xác nhận, EA không phát hiện breakout ngược chiều của hộp cũ (Mục 8, điểm 10).

## 10. Kiểm tra kỹ thuật đã làm

| Hạng mục | Kết quả |
|---|---|
| Compile MetaEditor | **Chưa làm** (không có MetaEditor) |
| Chạy trên MT5 / tester | **Chưa làm** |
| Kiểm tra tĩnh (`research/phoenix_grid/cong_cu_ea/kiem_tra_tinh_mq5.py`) | Đạt cho cả hai bản:<br>- Ngoặc cân bằng; không có chuỗi bị cắt ngang dòng<br>- Mọi lời gọi hàm có định nghĩa hoặc là hàm MQL5 chuẩn (V0.10: 66 hàm tự định nghĩa; V0.11: 63)<br>- Không có hàm định nghĩa trùng hay định nghĩa mà không gọi<br>- Mọi biến `g_` đều có khai báo<br>- Input đều có nhãn tiếng Việt (V0.10: 45; V0.11: 44, bỏ "Dịch chart")<br>- V0.10: mảng biểu tượng đủ 4.096 phần tử |
| Không có lệnh giao dịch | Đạt: không có `OrderSend`, `OrderSendAsync`, `CTrade`, `Trade.mqh`, `PositionClose`, `PositionModify`, `OrderCloseBy`, `TRADE_ACTION` |
| Mã hóa file | UTF-8 có BOM, xuống dòng LF |
| Công thức rủi ro | Khớp Bảng C của kế hoạch (Mục 7.9) |

## 11. Log CSV

- Vị trí: `Common\Files\PhoenixGrid\PG_V011_trang_thai_<symbol>_<YYYYMM>.csv` (tester: `_tester_`). V0.10 ghi
  `PG_V010_…`. Hai bản có cùng các cột.
- Dấu phân cách `;`, mã hóa UTF-8.
- Không ghi số tài khoản, tên hay số dư. Chỉ có giá và trạng thái.

| Cột | Ý nghĩa |
|---|---|
| `thoi_gian`, `msc` | Thời điểm tick cuối đã xử lý (giờ server, mili-giây) |
| `su_kien` | `M5`, `CT_DOI`, `CANH_BAO`, `XAC_NHAN`, `BREAKOUT_GIA`, `CANH_BAO_HET_HAN`, `XU_HUONG_SAU_BREAKOUT`, `VUNG_MOI`, `KHONG_THANH_VUNG_MOI`, `HOP_SAU_BREAKOUT_KET_THUC`, `BREAKOUT_HET_THEO_DOI` |
| `nen_m5` | Giờ mở của nến M5 vừa tính |
| `bid`, `ask`, `spread_point` | Giá lúc ghi |
| `cau_truc` | `SIDEWAYS`, `TANG`, `GIAM`, `KHONG_RO` (sau chống nhấp nháy) |
| `thi_truong` | Nhãn hiển thị: `SIDEWAYS`, `VUNG_MOI`, `CANH_BAO_TANG/GIAM`, `BREAKOUT_TANG/GIAM`, `TANG`, `GIAM`, `KHONG_RO` |
| `tham_chieu_tren/duoi/rong` | Hộp tham chiếu (trống nếu không có) |
| `hop_tren`, `hop_duoi` | Hộp N_box nến |
| `atr_m5`, `atr_m1`, `adx`, `di_cong`, `di_tru`, `er`, `do_doc`, `cham_tren`, `cham_duoi` | Đặc trưng M5 |
| `toc_do_tick`, `mat_do_tick` | v và λ tại tick cuối |
| `so_nen_tu_canh_bao`, `adx_dinh_sau_canh_bao` | Theo dõi breakout |
| `sau_bo_so_nen`, `sau_bo_tren`, `sau_bo_duoi` | Cửa sổ sau breakout (trống nếu không tính) |
| `loc` | Mã bộ lọc (Mục 7.8) |

Quy ước thời điểm ghi:

- Sự kiện **kết thúc** (`BREAKOUT_GIA`, `CANH_BAO_HET_HAN`, `BREAKOUT_HET_THEO_DOI`, `HOP_SAU_BREAKOUT_KET_THUC`)
  được ghi **trước** khi xóa trạng thái. Dòng log vì vậy còn giữ chiều và hộp của breakout vừa kết thúc.
- Các sự kiện khác được ghi **sau** khi đổi trạng thái.
