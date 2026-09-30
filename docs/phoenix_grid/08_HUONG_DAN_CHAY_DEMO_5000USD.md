# Hướng dẫn chạy Phoenix V0.21 + MI Shadow trên demo 5.000 USD

> **V0.21 (30/09/2026):** vào lệnh liên tục (PP0), sửa "Hôm nay" và chữ "Label". Đặc tả:
> [`09_EA_V0_21_VAO_LIEN_TUC.md`](09_EA_V0_21_VAO_LIEN_TUC.md). Đang chạy V0.20: xem Mục 7 của tài liệu đó để nâng
> cấp. V0.20 và gói `PhoenixGrid_V0_20_MI_V0_01.zip` giữ nguyên để quay lại.

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> Cả hai EA **chưa compile** trong môi trường phát triển. Bước 3 là compile trên máy bạn. Nếu có lỗi, gửi tôi toàn bộ
> lỗi và cảnh báo trước khi chạy.

## 0. Cách nhanh nhất: gói cài đặt

Tải [`goi_cai_dat/PhoenixGrid_V0_21_MI_V0_01.zip`](../../goi_cai_dat/PhoenixGrid_V0_21_MI_V0_01.zip). Zip đã sắp đúng
cấu trúc thư mục MT5, và có hướng dẫn từng bước
[`HUONG_DAN_CAI_DAT.txt`](../../goi_cai_dat/HUONG_DAN_CAI_DAT.txt) (các phần A–H):

1. giải nén;
2. kéo thư mục `MQL5` trong zip thả vào Data Folder của MT5;
3. compile;
4. gắn EA 1 lên chart thứ nhất, EA 2 lên chart thứ hai.

Gói được tạo bằng `research/phoenix_grid/cong_cu_ea/dong_goi_cai_dat.py`. Script kiểm tra file `.mqh` nằm cùng thư mục
với EA shadow, và file SET khớp input.

**Dùng một MT5 riêng cho demo** (cài vào thư mục khác, ví dụ `C:\Program Files\MT5 DEMO PHOENIX`). Không đăng nhập
demo trên MT5 đang chạy Hydra: đổi tài khoản trên MT5 đó thì Hydra chạy sang tài khoản demo.

## 1. Demo 5.000 USD thay cho real cent 5.000 USC — không cần đổi lot

Số liệu hợp đồng đọc từ MT5 ở PG-R0.1:

| | Real Standard Cent | Demo Standard (USD) |
|---|---|---|
| Symbol | XAUUSDc | XAUUSDm (demo Pro / Raw / Zero: XAUUSD) |
| Hợp đồng | 1 lot = 100 USC khi giá đi 1 USD/oz | 1 lot = 100 USD khi giá đi 1 USD/oz |
| 0,01 lot, giá đi 1 USD/oz | 1 USC | 1 USD |
| Vốn | 5.000 USC | 5.000 USD |

Tỷ lệ lot / vốn giống hệt nhau, nên:

- giữ **lot 0,01** và mọi tham số khác như real;
- số trên bảng và log của demo (USD) bằng đúng số sẽ thấy trên real cent (USC);
- khoảng giá ngược tới cháy như nhau: khoảng 242 USD/oz với khoảng tầng 6 USD (tài liệu 06, Mục 9).

Khác biệt còn lại giữa demo và real:

- spread XAUUSDm thấp hơn XAUUSDc (0,16 so với 0,26 USD/oz khi đo tick);
- khớp lệnh demo không có trượt giá thật.

Nên chọn demo **Standard** (không commission). Demo Raw / Zero có commission: phần lãi thả nổi EA dùng để clear không
trừ commission, nên kết quả lệch real cent.

## 2. File cần chép

| File trong repo | Chép vào (MT5: File → Open Data Folder) |
|---|---|
| `MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5` | `MQL5\Experts\PhoenixGrid\` |
| `MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5` | `MQL5\Experts\PhoenixGrid\` |
| `MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh` | `MQL5\Experts\PhoenixGrid\` (bắt buộc cùng thư mục với EA shadow) |
| `MQL5/Presets/PhoenixGrid/*.set` (file V0.21 và 2 file `PMI_V001_THEO_PHOENIX`; file `THEO_HYDRA` dùng ở MT5 real chạy Hydra) | `MQL5\Presets\` |

| File SET | Dùng cho | Khác mặc định |
|---|---|---|
| `PG_V021_DEMO_5000USD.set` | Phoenix V0.21 trên demo | `InpChoPhepTKThat = false`: lỡ nạp trên tài khoản thật thì EA không gửi lệnh |
| `PG_V021_DEMO_5000USD_HESO_1_2.set` | Phoenix V0.21, lot nhân 1,2 mỗi tầng (yêu cầu 30/09/2026) | Như trên + `InpHeSoLot = 1.2`; bảo vệ vốn và dừng mở basket theo DD ghi rõ = 0 (không cắt lệnh, không dừng lỗ). Vốn cạn khi giá ngược khoảng 115 USD (lot đều: khoảng 242 USD) |
| `PG_V020_DEMO_5000USD.set` | Phoenix V0.20 (quay lại) | như trên |
| `PMI_V001_THEO_PHOENIX_d60n2.set` | MI Shadow theo dõi Phoenix (magic 20260930) | ngưỡng 60 điểm / 2 nến |
| `PMI_V001_THEO_PHOENIX_d80n3.set` | MI Shadow thứ hai để so sánh (tùy chọn) | ngưỡng 80 điểm / 3 nến |
| `PMI_V001_THEO_HYDRA_d60n2.set` | MI Shadow cạnh Hydra trên MT5 real (gói riêng `PhoenixGrid_theo_doi_Hydra.zip`) | magic 0 = mọi lệnh XAUUSDc trên tài khoản |

File SET được sinh từ chính mã nguồn bằng `research/phoenix_grid/cong_cu_ea/tao_file_set.py`, nên tên input và giá
trị luôn khớp EA. Định dạng giống file MT5 tự lưu: UTF-16, mỗi dòng `tên=giá trị`.

## 3. Các bước

1. **Mở demo**: Exness Personal Area → Demo → Standard, MT5, tiền USD, số dư 5.000, đòn bẩy 1:2000. Tài khoản
   hedging (mặc định của Exness MT5). Đăng nhập tài khoản demo trên MT5.
2. **Chép file** theo Mục 2.
3. **Compile**:
   - Mở MetaEditor (F4), mở từng file `.mq5`, nhấn F7.
   - Phải thấy "0 errors". Gửi tôi toàn bộ dòng trong tab Errors, kể cả cảnh báo.
4. **Cài đặt MT5**:
   - Tools → Options → Expert Advisors: tick "Allow algorithmic trading".
   - Tools → Options → Notifications: nhập MetaQuotes ID (xem trong app MT5 điện thoại: Settings → Chats and
     Messages) để nhận thông báo mở / clear basket, stop out.
   - Bật nút **Algo Trading** trên thanh công cụ (màu xanh).
5. **Chart 1 — Phoenix V0.21 (gửi lệnh)**:
   - Mở chart **XAUUSDm**, khung nào cũng được (EA tự dùng M1, M2, M5).
   - Kéo `EA_PHOENIX_GRID_V0_21_TEST` vào chart.
   - Tab Inputs → **Load** → chọn `PG_V021_DEMO_5000USD.set`.
   - Tab Common: tick "Allow Algo Trading". Bấm OK.
6. **Kiểm tra bảng Phoenix ngay sau khi gắn**:

   | Dòng | Phải thấy |
   |---|---|
   | Góc trên bên phải | `CHỜ TÍN HIỆU · DEMO` |
   | Gửi lệnh | `DEMO` (xanh) |
   | Tạm dừng | `Không`. Nếu là `Tự động` thì tài khoản còn vị thế / lệnh chờ không phải Phoenix: đóng hết |
   | Thông báo | `Lot tầng 0 = 0.01: giá đi 1 USD = 1.00 USD` |
   | Giá ngược tới cháy | khoảng `~240 USD` |
   | Lọc vào lệnh | `ĐƯỢC` trong giờ giao dịch khi spread bình thường |

   Nếu Gửi lệnh là `KHÔNG`, dòng cuối khối Phoenix DCA ghi lý do. Ví dụ: "Chưa bật Algo Trading", "Cần tài khoản hedging".
7. **Chart 2 — MI Shadow (chỉ ghi log)**:
   - Mở chart **XAUUSDm thứ hai**. Kéo `EA_PHOENIX_MI_SHADOW_V0_01_TEST` vào.
   - Tab Inputs → Load → `PMI_V001_THEO_PHOENIX_d60n2.set`.
   - Không cần tick Allow Algo Trading, vì EA này không gửi lệnh.
   - Góc trái chart hiện dòng chữ "MI V0.01 SHADOW — CHỈ GHI LOG, KHÔNG GỬI LỆNH", trạng thái thị trường, basket,
     phòng thủ "sẽ làm".
8. **Chart 3 (tùy chọn)**: làm giống chart 2, nạp `PMI_V001_THEO_PHOENIX_d80n3.set`. Log hai chart không ghi đè nhau.
9. **Chạy 24/7**:
   - Dùng VPS Windows (hoặc máy không tắt, tắt chế độ ngủ).
   - Tắt MT5 bằng File → Exit để MT5 lưu chart và EA. Khi mở lại, EA tự chạy lại. Phoenix nhận lại basket đang mở từ
     trạng thái lưu (GlobalVariables), hoặc từ comment lệnh nếu mất trạng thái.
   - Nếu dùng MQL5 VPS: đồng bộ (Migrate) từ máy chính sau khi đã gắn đủ các chart.

## 4. Không nên làm trên tài khoản demo này

- Không mở lệnh tay và không chạy EA khác. Phoenix mặc định **tạm dừng** khi thấy vị thế lạ.
- Không đổi `InpMagic`. MI Shadow theo dõi basket bằng magic 20260930.
- Không đóng tay từng lệnh của basket. Muốn dừng, dùng nút trên bảng: TẠM DỪNG, ĐÓNG BASKET, ĐÓNG TẤT CẢ. Mỗi nút
  bấm 2 lần trong 5 giây.

## 5. Gửi log mỗi ngày

Mở thư mục log: File → Open Data Folder, lùi lên 2 cấp, vào `Common\Files\PhoenixGrid\`. Gửi tôi các file của ngày
hôm trước:

| File | Nguồn |
|---|---|
| `PG_V021_tin_hieu_XAUUSDm_<ngày>.csv`, `PG_V021_giao_dich_…`, `PG_V021_basket_…`, `PG_V021_thuc_thi_…` | Phoenix V0.21 |
| `PG_V021_tong_ket_ngay_XAUUSDm_<tháng>.csv`, `PG_V021_trang_thai_XAUUSDm_<tháng>.csv` | Phoenix V0.21 (file theo tháng) |
| `PMI_V001_XAUUSDm_d60n2_<ngày>.csv` (và `d80n3` nếu chạy chart 3) | MI Shadow |

Tôi đọc bằng `phan_tich_log_v020.py` và `phan_tich_log_mi.py`. Nén cả thư mục thành zip rồi gửi cũng được.

## 6. Chạy thử trong Strategy Tester (tùy chọn, trước khi treo demo)

- Expert: `EA_PHOENIX_GRID_V0_21_TEST`, symbol XAUUSDm, khoảng ngày tùy chọn.
- Modelling: "Every tick based on real ticks". Deposit 5.000 USD, leverage 1:2000.
- Inputs → Load → `PG_V021_DEMO_5000USD.set`.
- Log tester có chữ `_tester` trong tên file, nằm cùng thư mục `Common\Files\PhoenixGrid\`.
- Bộ lọc tin không chạy trong tester.
- MI Shadow chạy tester riêng (một EA mỗi lần chạy), với input "Giả lập basket" = true để xem luồng phòng thủ.
