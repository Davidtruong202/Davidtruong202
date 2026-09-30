"""Đóng gói cài đặt cho MT5: một file zip đã sắp đúng cấu trúc thư mục MQL5 + hướng dẫn từng bước.

Người dùng chỉ cần giải nén và kéo thư mục MQL5 trong zip thả vào Data Folder của MT5.
Kiểm tra trước khi đóng gói:
- mọi file nguồn tồn tại; file .mq5 / .mqh có BOM UTF-8;
- mọi `#include "..."` trỏ tới file có trong cùng thư mục của gói, đúng tên;
- file .set đọc được (UTF-16 LE có BOM) và chỉ chứa input có trong EA tương ứng.

Chạy:  python3 dong_goi_cai_dat.py    ->  goi_cai_dat/PhoenixGrid_V0_20_MI_V0_01.zip + goi_cai_dat/HUONG_DAN_CAI_DAT.txt
"""
import os
import re
import sys
import zipfile

GOC = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
RA = os.path.join(GOC, "goi_cai_dat")
TEN_ZIP = "PhoenixGrid_V0_20_MI_V0_01.zip"

# (đường dẫn trong repo, đường dẫn trong zip)
FILE = [
    ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_20_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_20_TEST.mq5"),
    ("MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "MQL5/Experts/PhoenixGrid/EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5"),
    ("MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh", "MQL5/Experts/PhoenixGrid/PHOENIX_MI_V0_01.mqh"),
    ("MQL5/Presets/PhoenixGrid/PG_V020_DEMO_5000USD.set", "MQL5/Presets/PG_V020_DEMO_5000USD.set"),
    ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_PHOENIX_d60n2.set", "MQL5/Presets/PMI_V001_THEO_PHOENIX_d60n2.set"),
    ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_PHOENIX_d80n3.set", "MQL5/Presets/PMI_V001_THEO_PHOENIX_d80n3.set"),
    ("MQL5/Presets/PhoenixGrid/PMI_V001_THEO_HYDRA_d60n2.set", "MQL5/Presets/PMI_V001_THEO_HYDRA_d60n2.set"),
]
# file .set -> EA dùng file đó
SET_EA = {
    "PG_V020_DEMO_5000USD.set": "EA_PHOENIX_GRID_V0_20_TEST.mq5",
    "PMI_V001_THEO_PHOENIX_d60n2.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
    "PMI_V001_THEO_PHOENIX_d80n3.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
    "PMI_V001_THEO_HYDRA_d60n2.set": "EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5",
}

HUONG_DAN = r"""DAVID HUNTER – PHOENIX GRID – 0941920986
HƯỚNG DẪN CÀI ĐẶT TỪNG BƯỚC — Phoenix V0.20 + MI Shadow V0.01 — TÀI KHOẢN DEMO 5.000 USD

Hai EA CHƯA được compile trong môi trường phát triển. Làm đúng Phần C; nếu có lỗi, gửi lỗi trước khi chạy.

TRONG GÓI NÀY
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_GRID_V0_20_TEST.mq5        EA 1: GIAO DỊCH (DCA + tỉa + clear)
  MQL5\Experts\PhoenixGrid\EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5   EA 2: CHỈ GHI LOG, không gửi lệnh
  MQL5\Experts\PhoenixGrid\PHOENIX_MI_V0_01.mqh                  file phụ của EA 2 (phải nằm cùng thư mục với EA 2)
  MQL5\Presets\PG_V020_DEMO_5000USD.set                          cài đặt cho EA 1
  MQL5\Presets\PMI_V001_THEO_PHOENIX_d60n2.set                   cài đặt cho EA 2 (theo dõi EA 1)
  MQL5\Presets\PMI_V001_THEO_PHOENIX_d80n3.set                   cài đặt cho EA 2 thứ hai để so sánh (tùy chọn)
  MQL5\Presets\PMI_V001_THEO_HYDRA_d60n2.set                     EA 2 cạnh Hydra trên tài khoản real (tùy chọn)

  Không đổi tên file. Nếu trình duyệt tự thêm "(1)" vào tên file thì xóa phần đó đi.

  Demo 5.000 USD với lot 0,01 = cùng mức rủi ro như real cent 5.000 USC với lot 0,01.
  Không cần đổi lot hay tham số nào.

PHẦN A — CHUẨN BỊ (làm 1 lần)
 A1. Giải nén file zip: chuột phải file zip -> Extract All -> Extract.
 A2. Cài một MT5 RIÊNG cho demo, để MT5 đang chạy Hydra trên tài khoản real không bị ảnh hưởng.
     - Tải bộ cài MetaTrader 5 trong Exness Personal Area (mục nền tảng giao dịch).
     - Chạy bộ cài, bấm "Settings", đổi thư mục cài thành:  C:\Program Files\MT5 DEMO PHOENIX
       -> Next -> chờ cài xong.
     - KHÔNG đăng nhập demo trên MT5 đang chạy Hydra: nếu đổi tài khoản trên MT5 đó,
       Hydra sẽ chạy sang tài khoản demo.
 A3. Mở tài khoản demo: Exness Personal Area -> mở tài khoản mới -> Demo -> Standard.
     Chọn: MetaTrader 5, tiền USD, đòn bẩy 1:2000, số dư 5000.
     Ghi lại: số tài khoản, mật khẩu, tên server.
 A4. Mở "MT5 DEMO PHOENIX" -> File -> Login to Trade Account -> nhập số tài khoản, mật khẩu,
     server demo -> OK. Góc dưới bên phải hiện tốc độ kết nối (ví dụ 58 ms) là đã vào được.

PHẦN B — CHÉP FILE (làm 1 lần)
 B1. Trong MT5 DEMO PHOENIX: File -> Open Data Folder.
     Một cửa sổ Windows mở ra, bên trong có thư mục MQL5.
 B2. Mở thư mục đã giải nén ở bước A1. Kéo thư mục MQL5 trong đó, thả vào cửa sổ ở bước B1.
     Windows hỏi gộp thư mục / thay file -> chọn Yes (hoặc "Replace the files in the destination").
 B3. Kiểm tra trong cửa sổ Data Folder:
     - MQL5\Experts\PhoenixGrid  có 3 file (2 file .mq5 và 1 file .mqh)
     - MQL5\Presets              có 4 file .set

PHẦN C — COMPILE (làm 1 lần; làm lại mỗi khi có bản mới)
 C1. Trong MT5 bấm phím F4 (hoặc nút IDE trên thanh công cụ): MetaEditor mở ra.
 C2. Cột Navigator bên trái MetaEditor -> Experts -> PhoenixGrid
     -> nhấp đúp EA_PHOENIX_GRID_V0_20_TEST.mq5.
 C3. Bấm F7. Nhìn tab Errors ở dưới cùng: dòng cuối phải là "0 errors".
 C4. Làm lại C2–C3 với EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5. Không compile file .mqh.
 C5. Nếu có lỗi: chụp màn hình tab Errors (hoặc chọn hết các dòng -> chuột phải -> Copy) gửi cho Claude.
     DỪNG, chưa gắn EA.
 C6. Quay lại MT5: cột Navigator -> chuột phải "Expert Advisors" -> Refresh.
     Thấy thư mục PhoenixGrid có 2 EA:  EA_PHOENIX_GRID_V0_20_TEST  và  EA_PHOENIX_MI_SHADOW_V0_01_TEST.

PHẦN D — CÀI ĐẶT MT5 (làm 1 lần)
 D1. Tools -> Options -> tab Expert Advisors -> tick "Allow algorithmic trading" -> OK.
 D2. Trên thanh công cụ, bấm nút "Algo Trading" cho chuyển sang màu xanh.
 D3. (Tùy chọn, để nhận thông báo trên điện thoại) Tools -> Options -> tab Notifications
     -> tick "Enable Push Notifications", nhập MetaQuotes ID -> OK.
     MetaQuotes ID xem trong app MT5 trên điện thoại, mục Messages (Tin nhắn).

PHẦN E — GẮN EA 1: PHOENIX V0.20 (giao dịch)
 E1. Cửa sổ Market Watch (Ctrl+M): chuột phải -> Symbols -> gõ XAUUSDm -> chọn -> Show Symbol -> OK.
 E2. Chuột phải XAUUSDm trong Market Watch -> Chart Window. Một chart mới mở ra
     (khung nào cũng được, nên chọn M5).
 E3. Cột Navigator của MT5 -> Expert Advisors -> PhoenixGrid
     -> kéo EA_PHOENIX_GRID_V0_20_TEST thả vào chart vừa mở.
 E4. Cửa sổ cài đặt EA hiện ra:
       - Tab Common: tick "Allow Algo Trading".
       - Tab Inputs: bấm nút Load -> chọn PG_V020_DEMO_5000USD.set -> Open.
       - Bấm OK.
 E5. Kiểm tra:
       - Góc trên bên phải chart: biểu tượng EA màu xanh.
       - Bảng PHOENIX ở bên trái chart, khối "PHOENIX DCA":
           "Gửi lệnh" = DEMO (chữ xanh), "Tạm dừng" = Không.
       - Khung THÔNG BÁO có dòng: "Lot tầng 0 = 0.01: giá đi 1 USD = 1.00 USD".
       - Nếu "Gửi lệnh" = KHÔNG: đọc dòng chữ cuối khối PHOENIX DCA để biết lý do
         (thường là quên bước D2 hoặc tick "Allow Algo Trading" ở E4).
       - Nếu "Tạm dừng" = Tự động: tài khoản đang có lệnh không phải của Phoenix -> đóng hết lệnh đó.

PHẦN F — GẮN EA 2: MI SHADOW (chỉ ghi log)
 F1. Mở chart XAUUSDm THỨ HAI: chuột phải XAUUSDm trong Market Watch -> Chart Window.
     Mỗi chart chỉ chạy được 1 EA, nên EA 2 phải ở chart khác EA 1.
 F2. Kéo EA_PHOENIX_MI_SHADOW_V0_01_TEST thả vào chart thứ hai.
 F3. Tab Inputs -> Load -> PMI_V001_THEO_PHOENIX_d60n2.set -> Open -> OK.
     Tab Common: tick "Allow Algo Trading" hay không đều được, vì EA này không có lệnh giao dịch.
 F4. Kiểm tra: góc trái trên chart hiện dòng
       "MI V0.01 SHADOW — CHỈ GHI LOG, KHÔNG GỬI LỆNH"
     và các dòng: Thị trường / Basket / Phòng thủ (sẽ làm) / Fib.
     Lần đầu có thể phải chờ tới khi đóng nến M5 kế tiếp (tối đa 5 phút).
 F5. (Tùy chọn) Chart thứ ba: làm như F1–F3 nhưng Load PMI_V001_THEO_PHOENIX_d80n3.set.

PHẦN G — CHẠY HẰNG NGÀY
 G1. Để MT5 DEMO PHOENIX chạy liên tục (VPS Windows, hoặc máy không tắt, không ngủ).
     Nếu cần tắt MT5: dùng File -> Exit. Mở lại thì 2 EA tự chạy tiếp.
 G2. Không đánh tay, không chạy EA khác trên tài khoản demo này
     (EA 1 tự tạm dừng khi thấy lệnh lạ).
 G3. Muốn dừng EA 1: dùng nút trên bảng Phoenix (TẠM DỪNG / ĐÓNG BASKET / ĐÓNG TẤT CẢ),
     bấm 2 lần trong 5 giây.
 G4. Mỗi ngày gửi log cho Claude:
     MT5 -> File -> Open Data Folder -> lùi lên 2 cấp (tới thư mục "Terminal")
     -> Common -> Files -> chuột phải thư mục PhoenixGrid -> Send to -> Compressed (zipped) folder
     -> gửi file zip vừa tạo.

PHẦN H — (TÙY CHỌN) EA 2 CẠNH HYDRA TRÊN TÀI KHOẢN REAL
 H1. Trên MT5 đang chạy Hydra: làm lại Phần B và Phần C (chép và compile trong Data Folder của MT5 này).
 H2. Mở một chart XAUUSDc MỚI (không phải chart của Hydra),
     kéo EA_PHOENIX_MI_SHADOW_V0_01_TEST vào, Load PMI_V001_THEO_HYDRA_d60n2.set -> OK.
     EA này không gửi lệnh, không đụng vào lệnh của Hydra.
 H3. EA 1 (Phoenix V0.20) lúc này chỉ chạy trên demo.
     File PG_V020_DEMO_5000USD.set đã chặn gửi lệnh nếu lỡ gắn trên tài khoản thật.
"""


def kiem_tra():
    for goc, _ in FILE:
        p = os.path.join(GOC, goc)
        assert os.path.isfile(p), f"thiếu file {goc}"
        raw = open(p, "rb").read()
        if goc.endswith((".mq5", ".mqh")):
            assert raw.startswith(b"\xef\xbb\xbf"), f"{goc} thiếu BOM UTF-8"
            src = raw[3:].decode("utf-8")
            for inc in re.findall(r'^\s*#include\s+"([^"]+)"', src, re.M):
                cung = os.path.dirname(goc) + "/" + inc
                assert any(g == cung for g, _ in FILE), f"{goc} include {inc} nhưng gói không có {cung}"
                zip_ea = dict(FILE)[goc]
                zip_inc = dict(FILE)[cung]
                assert os.path.dirname(zip_ea) == os.path.dirname(zip_inc), f"{inc} phải nằm cùng thư mục với {goc} trong zip"
        if goc.endswith(".set"):
            assert raw.startswith(b"\xff\xfe"), f"{goc} không phải UTF-16 LE có BOM"
            txt = raw[2:].decode("utf-16-le")
            ten = [l.split("=", 1)[0] for l in txt.split("\r\n") if l and not l.startswith(";")]
            ea = SET_EA[os.path.basename(goc)]
            ea_src = open(os.path.join(GOC, "MQL5/Experts/PhoenixGrid", ea), encoding="utf-8-sig").read()
            inp = set(re.findall(r"^input\s+\w+\s+(\w+)\s*=", ea_src, re.M))
            assert set(ten) == inp, (goc, set(ten) ^ inp)
    print("kiểm tra gói: đạt")


def dong_goi():
    kiem_tra()
    os.makedirs(RA, exist_ok=True)
    hd = "\ufeff" + HUONG_DAN.replace("\r\n", "\n").replace("\n", "\r\n")
    with open(os.path.join(RA, "HUONG_DAN_CAI_DAT.txt"), "w", encoding="utf-8", newline="") as f:
        f.write(hd)
    duong = os.path.join(RA, TEN_ZIP)
    with zipfile.ZipFile(duong, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("HUONG_DAN_CAI_DAT.txt", hd.encode("utf-8"))
        for goc, trong_zip in FILE:
            z.write(os.path.join(GOC, goc), trong_zip)
    with zipfile.ZipFile(duong) as z:
        ds = z.namelist()
        assert z.testzip() is None
    print(f"{TEN_ZIP}: {len(ds)} file, {os.path.getsize(duong)} byte")
    for n in ds:
        print("  ", n)


if __name__ == "__main__":
    sys.exit(dong_goi())
