"""Đóng gói cài đặt cho MT5: mỗi gói là một file zip đã sắp đúng cấu trúc thư mục MQL5 + hướng dẫn từng bước.

Người dùng chỉ cần giải nén và kéo thư mục MQL5 trong zip thả vào Data Folder của MT5.
- Gói 1 (MT5 demo): Phoenix V0.21 (vào lệnh liên tục) + MI Shadow theo dõi Phoenix. Gói V0.20 cũ giữ nguyên trong
  goi_cai_dat/ để quay lại khi cần.
- Gói 2 (MT5 real đang chạy Hydra): MI Shadow theo dõi Hydra + script chỉ đọc xuất lịch sử giao dịch.
- Gói 3 (tài khoản cent 500 USD): Phoenix V0.23 (bỏ PP10) + V0.21 dự phòng + file set đã dò cho cent 500 USD.

Kiểm tra trước khi đóng gói:
- mọi file nguồn tồn tại; file .mq5 / .mqh có BOM UTF-8; không file nào của gói 2 có lệnh giao dịch;
- mọi `#include "..."` trỏ tới file có trong cùng thư mục của gói, đúng tên;
- file .set đọc được (UTF-16 LE có BOM) và chỉ chứa input có trong EA tương ứng.

Chạy:  python3 dong_goi_cai_dat.py    ->  goi_cai_dat/<gói>.zip + goi_cai_dat/<hướng dẫn>.txt
"""
import os
import re
import sys
import zipfile

GOC = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
RA = os.path.join(GOC, "goi_cai_dat")

# file .set -> EA dùng file đó
SET_EA = {
    "PG_V023_CENT_500USD.set": "EA_PHOENIX_GRID_V0_23_TEST.mq5",
    "PG_V021_CENT_500USD.set": "EA_PHOENIX_GRID_V0_21_TEST.mq5",
    "PG_V021_DEMO_5000USD.set": "EA_PHOENIX_GRID_V0_21_TEST.mq5",
    "PG_V020_DEMO_5000USD.set": "EA_PHOENIX_GRID_V0_20_TEST.mq5",
    "PMI_V001_THEO_PHOENIX_d60n2.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
    "PMI_V001_THEO_PHOENIX_d80n3.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
    "PMI_V001_THEO_HYDRA_d60n2.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
}
CAM = ["OrderSend", "OrderSendAsync", "CTrade", "PositionClose", "TRADE_ACTION_DEAL", "TRADE_ACTION_SLTP"]

HUONG_DAN_DEMO = r"""DAVID HUNTER – PHOENIX GRID – 0941920986
HƯỚNG DẪN CÀI ĐẶT TỪNG BƯỚC — Phoenix V0.21 + MI Shadow V0.01 — MT5 DEMO 5.000 USD

V0.21 = V0.20 + VÀO LỆNH LIÊN TỤC (PP0): không có basket thì mở lệnh đầu ngay sau 10 giây chờ, hướng theo
MA50 H1 (như lệnh đầu của Hydra). Xử lý lệnh (DCA, tỉa, clear) giữ nguyên như V0.20.
Sửa thêm: dòng "Hôm nay" không còn trừ hai lần tiền nạp; bỏ chữ "Label" ở đầu bảng.

Hai EA CHƯA được compile trong môi trường phát triển. Làm đúng Phần C; nếu có lỗi, gửi lỗi trước khi chạy.

TRONG GÓI NÀY
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_GRID_V0_21_TEST.mq5        EA 1: GIAO DỊCH (vào liên tục + DCA + tỉa + clear)
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5   EA 2: CHỈ GHI LOG, không gửi lệnh
  MQL5\Experts\PhoenixGrid\PHOENIX_MI_V0_01.mqh                  file phụ của EA 2 (phải nằm cùng thư mục với EA 2)
  MQL5\Presets\PG_V021_DEMO_5000USD.set                          cài đặt cho EA 1  (chart 1)
  MQL5\Presets\PMI_V001_THEO_PHOENIX_d60n2.set                   cài đặt cho EA 2  (chart 2)
  MQL5\Presets\PMI_V001_THEO_PHOENIX_d80n3.set                   cài đặt cho EA 2 thứ hai để so sánh (chart 3, tùy chọn)

  Tên file SET bắt đầu bằng PG_V021 -> dùng cho EA 1. Bắt đầu bằng PMI_V001 -> dùng cho EA 2.
  Không đổi tên file. Nếu trình duyệt tự thêm "(1)" vào tên file thì xóa phần đó đi.

  Demo 5.000 USD với lot 0,01 = cùng mức rủi ro như real cent 5.000 USC với lot 0,01.
  Không cần đổi lot hay tham số nào.

NẾU MT5 DEMO ĐANG CHẠY PHOENIX V0.20 (nâng cấp, không cần làm lại Phần A và D)
 N1. Làm Phần B (chép file) và Phần C (compile EA_PHOENIX_GRID_V0_21_TEST.mq5).
 N2. Kéo EA_PHOENIX_GRID_V0_21_TEST thả vào CHÍNH chart đang chạy V0.20 -> MT5 hỏi thay EA -> Yes.
     Làm Phần E4 (Load PG_V021_DEMO_5000USD.set). Không chạy V0.20 và V0.21 cùng lúc trên một tài khoản.
 N3. Basket V0.20 đang mở (nếu có) được V0.21 nhận lại và xử lý tiếp: cùng magic 20260930, cùng trạng thái lưu.
 N4. Chart MI Shadow (chart 2, chart 3) giữ nguyên, không cần gắn lại: vẫn theo dõi magic 20260930.
 N5. Dòng "Hôm nay" trên bảng bắt đầu đếm lại từ lúc gắn V0.21 (trạng thái của V0.20 không có mốc thời gian).
 N6. Log của V0.21 có tên bắt đầu bằng PG_V021_ (log PG_V020_ cũ giữ nguyên).

PHẦN A — CHUẨN BỊ (làm 1 lần)
 A1. Giải nén file zip: chuột phải file zip -> Extract All -> Extract.
 A2. Dùng một MT5 RIÊNG cho demo (không dùng MT5 đang chạy Hydra trên tài khoản real).
     Nếu chưa có: tải bộ cài MetaTrader 5 trong Exness Personal Area, chạy bộ cài, bấm "Settings",
     đổi thư mục cài thành  C:\Program Files\MT5 DEMO PHOENIX  -> Next -> chờ cài xong.
     KHÔNG đăng nhập demo trên MT5 đang chạy Hydra: nếu đổi tài khoản trên MT5 đó,
     Hydra sẽ chạy sang tài khoản demo.
 A3. Tài khoản demo: Exness Standard, MetaTrader 5, tiền USD, đòn bẩy 1:2000, số dư 5000.
 A4. MT5 demo -> File -> Login to Trade Account -> nhập số tài khoản, mật khẩu, server demo -> OK.

PHẦN B — CHÉP FILE (làm 1 lần)
 B1. Trong MT5 demo: File -> Open Data Folder. Một cửa sổ Windows mở ra, bên trong có thư mục MQL5.
 B2. Kéo thư mục MQL5 trong zip (đã giải nén) thả vào cửa sổ đó.
     Windows hỏi gộp thư mục / thay file -> chọn Yes (hoặc "Replace the files in the destination").
 B3. Kiểm tra: MQL5\Experts\PhoenixGrid có 3 file (2 file .mq5, 1 file .mqh); MQL5\Presets có 3 file .set.

PHẦN C — COMPILE (làm 1 lần; làm lại mỗi khi có bản mới)
 C1. Trong MT5 bấm phím F4 (hoặc nút IDE trên thanh công cụ): MetaEditor mở ra.
 C2. Cột Navigator bên trái MetaEditor -> Experts -> PhoenixGrid -> nhấp đúp EA_PHOENIX_GRID_V0_21_TEST.mq5.
 C3. Bấm F7. Nhìn tab Errors ở dưới cùng: dòng cuối phải là "0 errors".
 C4. Làm lại C2–C3 với EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5. Không compile file .mqh.
 C5. Nếu có lỗi: chụp màn hình tab Errors gửi cho Claude. DỪNG, chưa gắn EA.
 C6. Quay lại MT5: cột Navigator -> chuột phải "Expert Advisors" -> Refresh.

PHẦN D — CÀI ĐẶT MT5 (làm 1 lần)
 D1. Tools -> Options -> tab Expert Advisors -> tick "Allow algorithmic trading" -> OK.
 D2. Trên thanh công cụ, bấm nút "Algo Trading" cho chuyển sang màu xanh.
 D3. (Tùy chọn) Tools -> Options -> tab Notifications -> tick "Enable Push Notifications",
     nhập MetaQuotes ID (xem trong app MT5 trên điện thoại, mục Messages) -> OK.

PHẦN E — CHART 1: EA 1 PHOENIX V0.21 (giao dịch)
 E1. Market Watch (Ctrl+M): chuột phải -> Symbols -> gõ XAUUSDm -> chọn -> Show Symbol -> OK.
 E2. Chuột phải XAUUSDm trong Market Watch -> Chart Window (khung nào cũng được, nên chọn M5).
 E3. Navigator -> Expert Advisors -> PhoenixGrid -> kéo EA_PHOENIX_GRID_V0_21_TEST thả vào chart.
 E4. Tab Common: tick "Allow Algo Trading".
     Tab Inputs: bấm Load -> chọn PG_V021_DEMO_5000USD.set -> Open.
     Kiểm tra dòng "Cho phép gửi lệnh trên tài khoản thật" = false (đúng file). Bấm OK.
 E5. Trên bảng PHOENIX: "Gửi lệnh" = DEMO (chữ xanh), "Tạm dừng" = Không.
     Khung THÔNG BÁO có dòng "Lot tầng 0 = 0.01: giá đi 1 USD = 1.00 USD"
     và dòng "Khởi động V0.21 TEST: ..., vào lệnh liên tục (PP0)".
     Trong giờ giao dịch, khi không có basket: sau khoảng 10 giây EA tự mở lệnh đầu theo hướng MA50 H1
     (dòng cuối khối PHOENIX DCA ghi "Xét gần nhất: PP0 ..."). Nếu không mở, dòng đó ghi lý do
     (ví dụ "Ngược xu hướng M5 Phoenix": MA50 H1 và xu hướng M5 đang ngược nhau, EA chờ).
     Nếu "Gửi lệnh" = KHÔNG: đọc dòng chữ cuối khối PHOENIX DCA để biết lý do.
     Nếu "Tạm dừng" = Tự động: tài khoản đang có lệnh không phải của Phoenix -> đóng hết lệnh đó.

PHẦN F — CHART 2: EA 2 MI SHADOW (chỉ ghi log)
 F1. Mở chart XAUUSDm THỨ HAI (mỗi chart chỉ chạy được 1 EA).
 F2. Kéo EA_PHOENIX_MI_SHADOW_V0_01_TEST thả vào chart thứ hai.
 F3. Tab Inputs -> Load -> PMI_V001_THEO_PHOENIX_d60n2.set -> Open.
     Kiểm tra dòng "Magic basket cần theo dõi" = 20260930 -> OK.
 F4. Góc trái chart hiện "MI V0.01 SHADOW — CHỈ GHI LOG, KHÔNG GỬI LỆNH"
     (có thể phải chờ tới khi đóng nến M5 kế tiếp).
 F5. (Tùy chọn) Chart 3: như F1–F3 nhưng Load PMI_V001_THEO_PHOENIX_d80n3.set.

PHẦN G — CHẠY HẰNG NGÀY
 G1. Để MT5 demo chạy liên tục. Nếu cần tắt MT5: File -> Exit. Mở lại thì 2 EA tự chạy tiếp.
 G2. Không đánh tay, không chạy EA khác trên tài khoản demo này.
 G3. Muốn dừng EA 1: nút TẠM DỪNG / ĐÓNG BASKET / ĐÓNG TẤT CẢ trên bảng, bấm 2 lần trong 5 giây.
 G4. Mỗi ngày gửi log: File -> Open Data Folder -> lùi lên 2 cấp (thư mục "Terminal") -> Common -> Files
     -> chuột phải thư mục PhoenixGrid -> Send to -> Compressed (zipped) folder -> gửi file zip đó.

PHẦN H — THEO DÕI HYDRA TRÊN MT5 REAL
 Dùng gói riêng PhoenixGrid_theo_doi_Hydra.zip và file HUONG_DAN_THEO_DOI_HYDRA.txt.
 EA 1 (Phoenix V0.21) lúc này chỉ chạy trên demo; file PG_V021_DEMO_5000USD.set đã chặn gửi lệnh
 nếu lỡ gắn trên tài khoản thật.
"""

HUONG_DAN_HYDRA = r"""DAVID HUNTER – PHOENIX GRID – 0941920986
HƯỚNG DẪN: THEO DÕI HYDRA TRÊN MT5 REAL — chỉ đọc, không gửi lệnh

Mục đích:
  - Ghi lại Hydra làm gì trong từng trạng thái thị trường (sideway, breakout, reclaim), để tìm ra logic của Hydra.
  - Kiểm tra Breakout Defense (TEST 1) trên chính các basket của Hydra: nếu được phép, Phoenix sẽ khóa DCA / hedge lúc nào.
Hai công cụ trong gói KHÔNG gửi, KHÔNG sửa, KHÔNG đóng lệnh nào. Hydra chạy như cũ.
Chưa compile trong môi trường phát triển: làm đúng Phần B, có lỗi thì gửi lỗi trước.

TRONG GÓI NÀY
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5   EA shadow: mỗi nến M5 ghi trạng thái thị trường
                                                                 và Hydra đang BUY / SELL bao nhiêu lot
  MQL5\Experts\PhoenixGrid\PHOENIX_MI_V0_01.mqh                  file phụ của EA shadow (cùng thư mục)
  MQL5\Scripts\PhoenixGrid\PG_XuatLichSu.mq5                     script: xuất lịch sử deal, lệnh, vị thế đang mở
  MQL5\Presets\PMI_V001_THEO_HYDRA_d60n2.set                     cài đặt EA shadow cho tài khoản Hydra

PHẦN A — CHÉP FILE (trên MT5 đang chạy Hydra)
 A1. Giải nén zip: chuột phải -> Extract All -> Extract.
 A2. Trong MT5 đang chạy Hydra: File -> Open Data Folder.
 A3. Kéo thư mục MQL5 trong zip thả vào cửa sổ đó -> chọn Yes khi Windows hỏi gộp thư mục.

PHẦN B — COMPILE
 B1. Bấm F4: MetaEditor mở ra.
 B2. Navigator của MetaEditor -> Experts -> PhoenixGrid -> nhấp đúp EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5
     -> bấm F7 -> tab Errors phải báo "0 errors".
 B3. Navigator -> Scripts -> PhoenixGrid -> nhấp đúp PG_XuatLichSu.mq5 -> F7 -> phải "0 errors".
 B4. Có lỗi: chụp màn hình tab Errors gửi Claude, dừng lại.
 B5. Về MT5: Navigator -> chuột phải "Expert Advisors" -> Refresh; chuột phải "Scripts" -> Refresh.

PHẦN C — GẮN EA SHADOW (không đụng vào chart của Hydra)
 C1. Market Watch -> chuột phải XAUUSDc -> Chart Window: mở một chart XAUUSDc MỚI.
     Không kéo gì vào chart đang chạy Hydra.
 C2. Kéo EA_PHOENIX_MI_SHADOW_V0_01_TEST vào chart mới.
 C3. Tab Inputs -> Load -> PMI_V001_THEO_HYDRA_d60n2.set -> Open.
     Dòng "Magic basket cần theo dõi" = 0: theo dõi mọi lệnh XAUUSDc trên tài khoản.
     Giữ 0: lịch sử cho thấy Hydra dùng HAI magic, 20260826 (lệnh DCA "Hydra N") và 20260827
     (lệnh pyramid "Hydra Py N"); đặt 20260826 sẽ sót lệnh pyramid. Vì vậy khi đang theo dõi,
     không đánh tay XAUUSDc và không chạy EA khác trên symbol này của tài khoản.
     Bấm OK. Không cần tick "Allow Algo Trading".
 C4. Góc trái chart mới hiện "MI V0.01 SHADOW — CHỈ GHI LOG, KHÔNG GỬI LỆNH"
     và dòng "Basket: BUY/SELL ... lot" khớp với số lot Hydra đang mở (chờ tối đa 5 phút).

PHẦN D — XUẤT LỊCH SỬ HYDRA (lần đầu ngay bây giờ; sau đó mỗi tuần hoặc khi Claude cần)
 D1. Navigator -> Scripts -> PhoenixGrid -> kéo PG_XuatLichSu thả vào chart XAUUSDc mới ở Phần C
     (một chart vẫn chạy được cả 1 EA và 1 script).
 D2. Tab Inputs: "Từ ngày" = ngày Hydra bắt đầu chạy trên tài khoản này (không nhớ thì để 2026.01.01).
     Các ô khác để nguyên -> OK.
 D3. Hiện thông báo "PG_XuatLichSu: ... deal, ... lệnh, ... vị thế đang mở". Script tự dừng.

PHẦN E — LƯU CÀI ĐẶT HYDRA ĐANG CHẠY
 E1. Trên chart Hydra: nhấp đúp vào biểu tượng EA ở góc trên bên phải chart
     (hoặc chuột phải chart -> Expert Advisors -> Properties).
 E2. Tab Inputs -> bấm Save -> đặt tên Hydra_dang_chay.set -> Save.
 E3. Bấm Cancel để đóng cửa sổ (KHÔNG bấm OK, để Hydra không bị khởi động lại).
     File nằm trong Data Folder -> MQL5 -> Presets.

PHẦN F — GỬI CHO CLAUDE
 F1. Data Folder -> lùi lên 2 cấp (thư mục "Terminal") -> Common -> Files -> thư mục PhoenixGrid:
     nén cả thư mục (log shadow PMI_V001_XAUUSDc_..., lịch sử PG_lich_su_..., PG_vi_the_mo_...).
 F2. Data Folder -> MQL5 -> Logs: các file .log của những ngày cần xem
     (nhật ký quyết định Hydra ghi ra, vì Hydra đang bật "Ghi log chi tiết mọi quyết định").
 F3. File Hydra_dang_chay.set (Phần E).
 F4. Nếu trong Data Folder -> MQL5 -> Experts có file Hydra_4.5_VIP_VI.mq5
     (mã nguồn, không phải .ex5): gửi luôn. Có mã nguồn thì đọc được chính xác logic, không phải đoán.
 Mỗi ngày sau đó: gửi F1 và F2 của ngày hôm trước.

Hai MT5 trên cùng VPS dùng chung thư mục Common\Files\PhoenixGrid. Log không bị ghi đè:
tên file có symbol (XAUUSDm là demo, XAUUSDc là real) và tên server.
"""

HUONG_DAN_CENT = r"""DAVID HUNTER – PHOENIX GRID – 0941920986
HƯỚNG DẪN TỪNG BƯỚC — Phoenix V0.23 + set tài khoản cent 500 USD

GÓI NÀY LÀ GÌ
  - EA_PHOENIX_GRID_V0_23_TEST.mq5: Phoenix V0.23 = V0.21 bỏ PP10 (Fibo + Bollinger). Xử lý lệnh giữ nguyên V0.21.
    V0.23 CHƯA được compile trong môi trường phát triển: làm Phần C, có lỗi thì gửi ảnh tab Errors.
  - EA_PHOENIX_GRID_V0_21_TEST.mq5: bản V0.21 (đã compile trên máy bạn 0 lỗi) để dùng nếu V0.23 báo lỗi.
  - PG_V023_CENT_500USD.set (cho V0.23) và PG_V021_CENT_500USD.set (cho V0.21, tắt Fibo): cùng một set.

SET NÀY TÌM RA THẾ NÀO (đọc trước khi chạy)
  - Dò bằng MÔ PHỎNG PYTHON trên nến XAUUSDm 01-09/2026, KHÔNG phải backtest MT5.
  - Chọn ở 01-04/2026, kiểm lại ở 05-06/2026, kiểm lần cuối một lần ở 07-09/2026: không cháy trên mọi đường giá
    thử, DD lớn nhất 26% / 5% / 4%. Kết luận cao nhất: ĐẠT SƠ BỘ, CẦN CHẠY THỬ (forward) THÊM.
  - Mô phỏng cả 9 tháng với vốn 500 USD, lot 0,01: lãi trung bình khoảng 1,2 USD / ngày (có ngày lỗ, xấu nhất
    khoảng -20 USD), khoảng 0,36 lot / ngày, 23 basket / ngày. Không cam kết lợi nhuận.
  - Vốn nhỏ hơn 500 USD hoặc lot lớn hơn 0,01 thì DD tăng mạnh: 100 USD lot 0,01 có đường giá bị CHÁY;
    500 USD lot 0,05 có đường giá bị CHÁY. Muốn 10 USD / ngày với DD khoảng 30% cần khoảng 3.000 USD
    (lot 0,08). Chi tiết: docs/phoenix_grid/11_EA_V0_23_BO_PP10_SET_CENT.md.
  - Không cắt lệnh theo DD, không dừng lỗ (như bạn yêu cầu). PP1 tắt để EA chạy giống phần đã mô phỏng.

TRONG GÓI NÀY
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_GRID_V0_23_TEST.mq5        EA giao dịch (bản mới)
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_GRID_V0_21_TEST.mq5        EA giao dịch (dự phòng)
  MQL5\Presets\PG_V023_CENT_500USD.set                          set cho V0.23
  MQL5\Presets\PG_V021_CENT_500USD.set                          set cho V0.21 (cùng set, tắt Fibo)
  Không đổi tên file. Nếu trình duyệt tự thêm "(1)" vào tên file thì xóa phần đó đi.

PHẦN A — CHỌN TÀI KHOẢN
 A1. NÊN CHẠY THỬ TRƯỚC TRÊN DEMO: tạo Exness Standard demo, tiền USD, đòn bẩy 1:2000, số dư 50.000 USD.
     Demo 50.000 USD với lot 0,01 có cùng tỷ lệ rủi ro như cent 500 USD (= 50.000 USC) với lot 0,01.
     Dùng một MT5 riêng cho demo này (không dùng MT5 đang chạy Hydra).
 A2. Tài khoản cent thật: Standard Cent, số dư 500 USD (hiện 50.000 USC). Dùng tài khoản RIÊNG cho Phoenix:
     không chạy Phoenix và Hydra trên cùng một tài khoản (Phoenix tự tạm dừng khi thấy lệnh không phải của nó).
     File set này để "Cho phép gửi lệnh trên tài khoản thật" = true: gắn lên tài khoản thật là EA gửi lệnh.

PHẦN B — CHÉP FILE
 B1. Giải nén zip. Trong MT5: File -> Open Data Folder.
 B2. Kéo thư mục MQL5 trong zip thả vào cửa sổ đó -> chọn Yes khi Windows hỏi gộp / thay file.

PHẦN C — COMPILE
 C1. Bấm F4 (MetaEditor). Navigator -> Experts -> PhoenixGrid -> nhấp đúp EA_PHOENIX_GRID_V0_23_TEST.mq5 -> F7.
     Tab Errors phải báo "0 errors" (cảnh báo "version ... must be xx.yyy" bỏ qua được).
 C2. Nếu V0.23 có lỗi: chụp tab Errors gửi Claude, và tạm dùng V0.21 (đã compile được) với PG_V021_CENT_500USD.set.
 C3. Về MT5: Navigator -> chuột phải "Expert Advisors" -> Refresh.

PHẦN D — CÀI ĐẶT MT5
 D1. Tools -> Options -> tab Expert Advisors -> tick "Allow algorithmic trading" -> OK.
 D2. Bấm nút "Algo Trading" trên thanh công cụ cho sang màu xanh.

PHẦN E — GẮN EA
 E1. Market Watch (Ctrl+M) -> chuột phải -> Symbols: tài khoản cent dùng XAUUSDc; demo Standard dùng XAUUSDm
     (hoặc XAUUSD). Mở chart symbol đó (nên chọn khung M5).
 E2. Navigator -> Expert Advisors -> PhoenixGrid -> kéo EA_PHOENIX_GRID_V0_23_TEST thả vào chart.
 E3. Tab Common: tick "Allow Algo Trading". Tab Inputs: Load -> PG_V023_CENT_500USD.set -> Open -> OK.
     (Dùng V0.21 thì kéo EA_PHOENIX_GRID_V0_21_TEST và Load PG_V021_CENT_500USD.set.)
 E4. Kiểm tra trên bảng PHOENIX: "Gửi lệnh" = DEMO hoặc THẬT (đúng tài khoản), "Tạm dừng" = Không;
     khung THÔNG BÁO có "Khởi động V0.23 TEST"; lot tầng 0 = 0.01; khoảng tầng khoảng 20 USD.
 E5. Nếu MT5 đang chạy Phoenix V0.21 trên chart này: kéo V0.23 thả vào chính chart đó -> Yes để thay EA.
     Basket đang mở được nhận lại (cùng magic 20260930). Không chạy hai bản Phoenix cùng lúc trên một tài khoản.

PHẦN F — HẰNG NGÀY
 F1. Để MT5 chạy liên tục (VPS). Không đánh tay, không chạy EA khác trên tài khoản này.
 F2. Ghi lại mỗi ngày: số dư, Equity, DD lớn nhất trong ngày (dòng trên bảng), số lệnh.
 F3. Gửi log cho Claude: File -> Open Data Folder -> lùi lên 2 cấp -> Common -> Files -> nén thư mục PhoenixGrid
     (log V0.23 có tên bắt đầu bằng PG_V023_).
"""

GOI = [
    {"zip": "PhoenixGrid_V0_21_MI_V0_01.zip", "huong_dan": "HUONG_DAN_CAI_DAT.txt", "text": HUONG_DAN_DEMO,
     "chi_doc": False,
     "file": [
         ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5"),
         ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5"),
         ("MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh", "MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh"),
         ("MQL5/Presets/PhoenixGrid/PG_V021_DEMO_5000USD.set", "MQL5/Presets/PG_V021_DEMO_5000USD.set"),
         ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_PHOENIX_d60n2.set", "MQL5/Presets/PMI_V001_THEO_PHOENIX_d60n2.set"),
         ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_PHOENIX_d80n3.set", "MQL5/Presets/PMI_V001_THEO_PHOENIX_d80n3.set"),
     ]},
    {"zip": "PhoenixGrid_V0_23_CENT_500USD.zip", "huong_dan": "HUONG_DAN_CENT_500USD.txt", "text": HUONG_DAN_CENT,
     "chi_doc": False,
     "file": [
         ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_23_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_23_TEST.mq5"),
         ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5"),
         ("MQL5/Presets/PhoenixGrid/PG_V023_CENT_500USD.set", "MQL5/Presets/PG_V023_CENT_500USD.set"),
         ("MQL5/Presets/PhoenixGrid/PG_V021_CENT_500USD.set", "MQL5/Presets/PG_V021_CENT_500USD.set"),
     ]},
    {"zip": "PhoenixGrid_theo_doi_Hydra.zip", "huong_dan": "HUONG_DAN_THEO_DOI_HYDRA.txt", "text": HUONG_DAN_HYDRA,
     "chi_doc": True,
     "file": [
         ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5"),
         ("MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh", "MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh"),
         ("MQL5/Scripts/PhoenixGrid/PG_XuatLichSu.mq5", "MQL5/Scripts/PhoenixGrid/PG_XuatLichSu.mq5"),
         ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_HYDRA_d60n2.set", "MQL5/Presets/PMI_V001_THEO_HYDRA_d60n2.set"),
     ]},
]


def bo_chu_thich_va_chuoi(src):
    src = re.sub(r"/\*.*?\*/", " ", src, flags=re.S)
    src = re.sub(r"//[^\n]*", " ", src)
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', src)


def kiem_tra(goi):
    ds = dict(goi["file"])
    for goc, trong_zip in goi["file"]:
        p = os.path.join(GOC, goc)
        assert os.path.isfile(p), f"thiếu file {goc}"
        raw = open(p, "rb").read()
        if goc.endswith((".mq5", ".mqh")):
            assert raw.startswith(b"\xef\xbb\xbf"), f"{goc} thiếu BOM UTF-8"
            src = raw[3:].decode("utf-8")
            for inc in re.findall(r'^\s*#include\s+"([^"]+)"', src, re.M):
                cung = os.path.dirname(goc) + "/" + inc
                assert cung in ds, f"{goc} include {inc} nhưng gói không có {cung}"
                assert os.path.dirname(ds[goc]) == os.path.dirname(ds[cung]), f"{inc} phải nằm cùng thư mục với {goc}"
            if goi["chi_doc"]:
                ma = bo_chu_thich_va_chuoi(src)
                co = [w for w in CAM if re.search(r"\b" + w + r"\b", ma)]
                assert not co, f"{goc} là gói chỉ đọc nhưng có {co}"
        if goc.endswith(".set"):
            assert raw.startswith(b"\xff\xfe"), f"{goc} không phải UTF-16 LE có BOM"
            txt = raw[2:].decode("utf-16-le")
            ten = [l.split("=", 1)[0] for l in txt.split("\r\n") if l and not l.startswith(";")]
            ea = SET_EA[os.path.basename(goc)]
            ea_src = open(os.path.join(GOC, "MQL5/Experts/PhoenixGrid", ea), encoding="utf-8-sig").read()
            inp = set(re.findall(r"^input\s+\w+\s+(\w+)\s*=", ea_src, re.M))
            assert set(ten) == inp, (goc, set(ten) ^ inp)
    for ten_file in re.findall(r"[A-Za-z0-9_][A-Za-z0-9_.]*\.(?:mq5|mqh|set)", goi["text"]):
        if ten_file in ("Hydra_4.5_VIP_VI.mq5", "Hydra_dang_chay.set"):
            continue
        assert any(os.path.basename(z) == ten_file for _, z in goi["file"]), f"hướng dẫn nhắc {ten_file} nhưng gói không có"
    print(f"kiểm tra {goi['zip']}: đạt")


def dong_goi():
    os.makedirs(RA, exist_ok=True)
    for goi in GOI:
        kiem_tra(goi)
        hd = "\ufeff" + goi["text"].replace("\r\n", "\n").replace("\n", "\r\n")
        with open(os.path.join(RA, goi["huong_dan"]), "w", encoding="utf-8", newline="") as f:
            f.write(hd)
        duong = os.path.join(RA, goi["zip"])
        with zipfile.ZipFile(duong, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr(goi["huong_dan"], hd.encode("utf-8"))
            for goc, trong_zip in goi["file"]:
                z.write(os.path.join(GOC, goc), trong_zip)
        with zipfile.ZipFile(duong) as z:
            ds = z.namelist()
            assert z.testzip() is None
        print(f"{goi['zip']}: {len(ds)} file, {os.path.getsize(duong)} byte")
        for n in ds:
            print("  ", n)


if __name__ == "__main__":
    sys.exit(dong_goi())
