//+------------------------------------------------------------------+
//|                                                EA_MASTER_4PP.mq5 |
//|      EA MASTER - nền tảng tổng hợp 4 phương pháp cho MetaTrader 5 |
//|                                                                  |
//|  PP1 : RSI quá mua / quá bán       (từ RSI_Averaging_EA)          |
//|  PP2 : SMC - Order Block retest    (từ SmartMoneyConcepts V5 -    |
//|        bản gốc là INDICATOR, quy tắc vào lệnh do EA MASTER đặt)   |
//|  PP3 : Fibonacci Pivot ngày        (từ Fibonacci_Pivot_Points -   |
//|        bản gốc là INDICATOR, quy tắc vào lệnh do EA MASTER đặt)   |
//|  PP4 : Quasimodo (QM) Pattern      (từ Quasimodo_fQMl_Pattern_EA) |
//|                                                                  |
//|  Magic từng PP = Magic_Goc*10 + số PP  (160 -> 1601..1604)        |
//|  Comment lệnh : MASTER_PP1_BUY, MASTER_PP4_SELL_E2, ...           |
//|                                                                  |
//|  Bản kiểm thử đầu tiên - thông số mặc định KHÔNG phải tối ưu.     |
//+------------------------------------------------------------------+
#property copyright "EA MASTER 4PP"
#property version   "1.40"
#property description "EA MASTER tổng hợp 4 phương pháp (RSI / SMC / Fibo Pivot / Quasimodo)."
#property description "Bản dùng để backtest từng phương pháp - KHÔNG phải setting tối ưu."

#include <Trade\Trade.mqh>

#define EAM_VERSION "1.40"
#define DIR_BULL    1
#define DIR_BEAR    -1
#define SO_PP       4
#define OBJ_PREFIX  "EAM_"

//+------------------------------------------------------------------+
//| Kiểu liệt kê                                                      |
//+------------------------------------------------------------------+
enum ENUM_BO_THONG_SO
  {
   BTS_TUY_CHINH = 0, // TÙY CHỈNH (dùng đúng Input nhóm 3-5)
   BTS_AN_TOAN   = 1, // A. SAFE - ưu tiên DD thấp
   BTS_CAN_BANG  = 2, // B. BALANCED - cân bằng (mặc định)
   BTS_MAO_HIEM  = 3  // C. AGGRESSIVE - chấp nhận rủi ro cao hơn
  };

enum ENUM_CHE_DO_XUNG_DOT
  {
   XD_DOC_LAP          = 0, // 0 = Các PP hoạt động độc lập
   XD_DA_SO            = 1, // 1 = Đa số thắng
   XD_KHONG_DOI_NGHICH = 2, // 2 = Chỉ vào khi không có tín hiệu đối nghịch
   XD_DIEM_SO          = 3  // 3 = Theo điểm số (trọng số từng PP)
  };

enum ENUM_HUONG_GD
  {
   HGD_CA_HAI  = 0, // Cả BUY và SELL
   HGD_CHI_MUA = 1, // Chỉ BUY
   HGD_CHI_BAN = 2  // Chỉ SELL
  };

enum ENUM_KIEU_TRAILING
  {
   TRAIL_TAT  = 0, // Tắt trailing
   TRAIL_ATR  = 1, // Trailing theo ATR
   TRAIL_PIPS = 2  // Trailing theo pips cố định
  };

enum ENUM_KIEU_TP
  {
   TP_THEO_RR       = 0, // Theo tỉ lệ R:R
   TP_THEO_CAU_TRUC = 1  // Theo cấu trúc (QM: đỉnh/đáy BOS | Pivot: mức kế tiếp)
  };

enum ENUM_PP2_LOAI_OB
  {
   OB_NOI_BO = 0, // Chỉ OB nội bộ (internal)
   OB_SWING  = 1, // Chỉ OB swing
   OB_CA_HAI = 2  // Cả hai (ưu tiên OB swing)
  };

enum ENUM_PP3_CHE_DO
  {
   PP3_BAT_LAI = 0, // Bật lại (đảo chiều) tại S/R
   PP3_PHA_VO  = 1  // Phá vỡ (breakout) qua P/R/S
  };

//+------------------------------------------------------------------+
//| INPUT                                                            |
//+------------------------------------------------------------------+
input group "=== 0. CHỌN SET DỰNG SẴN (BACKTEST NHIỀU SET) ==="
input int    ChonSet         = 0;    // Chọn SET dựng sẵn: 0 = dùng Input | 1-52 vòng 1-3 | 53-102 vòng 4 (Optimization)
input bool   GhiKetQuaTester = true; // Ghi kết quả mỗi lượt Tester vào Common\Files\EAM_BACKTEST_KET_QUA.csv

input group "=== 1. CÀI ĐẶT CHUNG ==="
input long             Magic_Goc             = 160;          // Magic gốc (Magic PP = Magic_Goc*10 + số PP)
input string           TienTo_Comment        = "MASTER";     // Tên SET / tiền tố comment (vd S01 -> S01_PP2_BUY_SW)
input ENUM_BO_THONG_SO BoThongSo             = BTS_CAN_BANG; // Bộ thông số (ghi đè Risk%, giới hạn lệnh, DD, thua LT)
input ENUM_TIMEFRAMES  Signal_Timeframe      = PERIOD_M15;   // Khung tín hiệu chung (PP để CURRENT sẽ dùng khung này)
input ENUM_HUONG_GD    HuongGiaoDich         = HGD_CA_HAI;   // Hướng giao dịch cho phép
input double           TruotGia_Pips         = 3.0;          // Trượt giá tối đa (pips)
input double           KichThuocPip_TuyChinh = 0.0;          // Kích thước 1 pip theo giá (0 = tự động, XAU = 0.10)
input bool             InLogChiTiet          = true;         // In log chi tiết (tín hiệu / lý do bỏ qua)

input group "=== 1B. CHẠY NHIỀU SET TRÊN 1 TÀI KHOẢN ==="
input double   VonAo_USD     = 0.0;                  // Vốn ảo của SET (0 = dùng Balance/Equity thật)
input datetime VonAo_BatDau  = D'2026.10.01 00:00'; // Mốc bắt đầu tính vốn ảo (trùng mốc Dashboard)
input bool     GhiNhatKyCSV  = true;                 // Ghi nhật ký mọi lệnh mở/đóng ra CSV
input string   TenFileNhatKy = "";                   // Tên file nhật ký (trống = EAM_<SET>_<Magic>.csv, thư mục Common\Files)

input group "=== 2. BẬT / TẮT CHIẾN LƯỢC ==="
input bool Bat_ChienLuoc_1 = true; // PP1 - RSI quá mua / quá bán
input bool Bat_ChienLuoc_2 = true; // PP2 - SMC Order Block retest
input bool Bat_ChienLuoc_3 = true; // PP3 - Fibonacci Pivot ngày
input bool Bat_ChienLuoc_4 = true; // PP4 - Quasimodo (QM) Pattern

input group "=== 3. KHỐI LƯỢNG (LOT) ==="
input bool   SuDung_AutoLot          = true; // Dùng Auto Lot theo % rủi ro
input double Lot_CoDinh              = 0.01; // Lot cố định (khi tắt Auto Lot)
input double Risk_Percent            = 0.5;  // Rủi ro mỗi lệnh % Balance [chỉ khi TÙY CHỈNH]
input double Risk_GhiDe_PT           = 0.0;  // Ghi đè Risk% cho MỌI bộ thông số / SET (0 = không ghi đè)
input double Lot_ToiDa               = 1.0;  // Lot tối đa cho 1 lệnh (chặn lot bất thường)
input bool   ChoPhepDungLotToiThieu  = true; // Cho dùng lot min khi lot theo rủi ro < lot min
input double HeSoRuiRoToiDaVoiLotMin = 2.0;  // ...chỉ khi rủi ro thực tế <= hệ số x Risk%
input double RuiRoToiDaMoiLenh_PT    = 5.0;  // CHỐT CHẶN: bỏ lệnh nếu lỗ tại SL > % Balance này (0 = tắt)

input group "=== 4. GIỚI HẠN SỐ LỆNH ==="
input int  MaxLenh_Tong       = 4;     // Tối đa tổng số lệnh EA [chỉ khi TÙY CHỈNH]
input int  MaxLenh_Buy        = 2;     // Tối đa lệnh BUY [chỉ khi TÙY CHỈNH]
input int  MaxLenh_Sell       = 2;     // Tối đa lệnh SELL [chỉ khi TÙY CHỈNH]
input int  MaxLenh_MoiPP      = 1;     // Tối đa lệnh mỗi phương pháp [chỉ khi TÙY CHỈNH]
input bool ChanLenhNguocChieu = false; // Chặn mở lệnh ngược chiều lệnh EA đang có (tránh hedge)

input group "=== 5. QUẢN LÝ RỦI RO (RISK MANAGER) ==="
input bool   Bat_GioiHanDDNgay          = true;  // Bật giới hạn DD trong ngày
input double DDNgay_ToiDa_PhanTram      = 4.0;   // DD ngày tối đa % balance đầu ngày [chỉ khi TÙY CHỈNH]
input bool   Bat_GioiHanDDTaiKhoan      = true;  // Bật giới hạn DD tài khoản (tính từ đỉnh equity)
input double DDTaiKhoan_ToiDa_PhanTram  = 15.0;  // DD tài khoản tối đa % [chỉ khi TÙY CHỈNH]
input bool   DongTatCaKhiVuotDD         = false; // Đóng toàn bộ lệnh EA khi vượt DD
input bool   ResetDinhEquityKhiKhoiDong = false; // Reset đỉnh equity mỗi lần khởi động EA
input bool   Bat_GioiHanLoNgay          = false; // Bật giới hạn lỗ ngày (theo tiền)
input double LoNgay_ToiDa_Tien          = 100.0; // Lỗ ngày tối đa (tiền tài khoản, gồm floating)
input bool   Bat_GioiHanThuaLienTiep    = true;  // Bật giới hạn số lệnh thua liên tiếp
input int    ThuaLienTiep_ToiDa         = 4;     // Thua liên tiếp tối đa trong ngày [chỉ khi TÙY CHỈNH]

input group "=== 6. BỘ LỌC CHUNG ==="
input bool   Bat_LocSpread       = true;  // Bật lọc spread
input double Spread_ToiDa_Pips   = 6.0;   // Spread tối đa (pips; XAU: 1 pip = 0.10 USD)
input bool   Bat_LocPhien        = false; // Bật lọc phiên giao dịch
input int    LechGioServer_GMT   = 0;     // Giờ server lệch GMT (Exness = 0, nhiều sàn = +2/+3)
input bool   GiaoDich_PhienA     = true;  // Cho giao dịch phiên Á
input int    PhienA_BatDau_GMT   = 0;     // Phiên Á bắt đầu (giờ GMT)
input int    PhienA_KetThuc_GMT  = 8;     // Phiên Á kết thúc (giờ GMT)
input bool   GiaoDich_PhienAu    = true;  // Cho giao dịch phiên Âu
input int    PhienAu_BatDau_GMT  = 7;     // Phiên Âu bắt đầu (giờ GMT)
input int    PhienAu_KetThuc_GMT = 16;    // Phiên Âu kết thúc (giờ GMT)
input bool   GiaoDich_PhienMy    = true;  // Cho giao dịch phiên Mỹ
input int    PhienMy_BatDau_GMT  = 12;    // Phiên Mỹ bắt đầu (giờ GMT)
input int    PhienMy_KetThuc_GMT = 21;    // Phiên Mỹ kết thúc (giờ GMT)
input bool   Bat_LocGio          = false; // Bật lọc khung giờ (giờ server)
input int    StartHour           = 1;     // Giờ bắt đầu cho phép vào lệnh (server)
input int    EndHour             = 22;    // Giờ kết thúc (server, không gồm giờ này)
input bool   Bat_LocTin          = false; // Bật lọc tin (Lịch kinh tế MT5 - KHÔNG chạy trong Tester)
input string Tin_TienTe          = "USD"; // Tiền tệ cần lọc tin
input int    Tin_PhutTruoc       = 30;    // Không vào lệnh trước tin (phút)
input int    Tin_PhutSau         = 30;    // Không vào lệnh sau tin (phút)

input group "=== 7. XỬ LÝ XUNG ĐỘT TÍN HIỆU ==="
input ENUM_CHE_DO_XUNG_DOT CheDo_XungDot       = XD_DOC_LAP; // Chế độ xử lý xung đột
input int                  HieuLucTinHieu_Giay = 900;        // Hiệu lực 1 tín hiệu khi so xung đột (giây)
input double               Diem_PP1            = 1.0;        // Điểm PP1 (chế độ 3)
input double               Diem_PP2            = 1.0;        // Điểm PP2 (chế độ 3)
input double               Diem_PP3            = 1.0;        // Điểm PP3 (chế độ 3)
input double               Diem_PP4            = 1.0;        // Điểm PP4 (chế độ 3)
input double               DiemToiThieu        = 1.0;        // Điểm tối thiểu để vào lệnh (chế độ 3)

input group "=== 8. CHỐNG SPAM LỆNH ==="
input int  CooldownSeconds        = 60;   // Thời gian chờ tối thiểu giữa 2 lệnh cùng PP (giây)
input bool ChiVaoMotLenhMoiMoiNen = true; // Mỗi PP tối đa 1 lệnh mới trên 1 nến (khung của PP)

input group "=== 9. QUẢN LÝ LỆNH CHUNG cho PP2-PP4 (BE / Trailing / Chốt 1 phần) ==="
input bool               QL_ApDung_PP2           = true;      // Áp dụng cho lệnh PP2
input bool               QL_ApDung_PP3           = true;      // Áp dụng cho lệnh PP3
input bool               QL_ApDung_PP4           = true;      // Áp dụng cho lệnh PP4
input bool               QL_BatHoaVon            = true;      // Dời SL về hòa vốn
input double             QL_HoaVon_TaiR          = 1.0;       // Lợi nhuận (R) để dời hòa vốn
input double             QL_HoaVon_KhoaPips      = 5.0;       // Pips khóa lời khi dời hòa vốn
input ENUM_KIEU_TRAILING QL_KieuTrailing         = TRAIL_TAT; // Kiểu trailing stop
input double             QL_Trail_BatDauR        = 1.5;       // Trailing ATR: bắt đầu khi lời (R)
input double             QL_Trail_HeSoATR        = 2.0;       // Trailing ATR: hệ số ATR
input double             QL_Trail_KhoaPips       = 100.0;     // Trailing pips: lời tối thiểu được khóa (pips)
input double             QL_Trail_KhoangCachPips = 30.0;      // Trailing pips: khoảng cách sau giá (pips)
input double             QL_Trail_BuocPips       = 1.0;       // Bước dời SL tối thiểu (pips) - chống spam sửa lệnh
input bool               QL_BatChotMotPhan       = false;     // Chốt một phần
input double             QL_ChotMotPhan_TaiR     = 1.0;       // Chốt một phần tại (R)
input double             QL_ChotMotPhan_PhanTram = 50.0;      // % khối lượng chốt

input group "=== PP1 - RSI QUÁ MUA / QUÁ BÁN ==="
input ENUM_TIMEFRAMES PP1_Timeframe           = PERIOD_M1; // PP1: Khung thời gian (gốc: M1)
input int             PP1_RSI_ChuKy           = 19;        // PP1: Chu kỳ RSI
input double          PP1_RSI_VaoBan          = 70.0;      // PP1: RSI cắt lên mức này -> SELL
input double          PP1_RSI_VaoMua          = 30.0;      // PP1: RSI cắt xuống mức này -> BUY
input double          PP1_RSI_DongBan         = 60.0;      // PP1: RSI <= mức này -> đóng SELL
input double          PP1_RSI_DongMua         = 40.0;      // PP1: RSI >= mức này -> đóng BUY
input bool            PP1_DongKhiGiaVeLenhDau = false;     // PP1: Đóng khi giá về giá lệnh đầu (gốc: true)
input double          PP1_SL_Pips             = 150.0;     // PP1: SL cứng tính từ lệnh đầu (pips, bắt buộc > 0)
input double          PP1_TP_Pips             = 0.0;       // PP1: TP lệnh đầu (pips, 0 = thoát theo RSI như gốc)
input bool            PP1_BatNhoiLenh         = false;     // PP1: Bật nhồi lệnh (DCA) như bản gốc - RỦI RO CAO
input int             PP1_SoTangToiDa         = 5;         // PP1: Số tầng tối đa khi nhồi
input double          PP1_BuocNhoi_Pips       = 10.0;      // PP1: Khoảng cách giữa các tầng (pips)
input double          PP1_HeSoLot             = 1.0;       // PP1: Hệ số lot mỗi tầng (gốc 2.0 = MARTINGALE)

input group "=== PP2 - SMC ORDER BLOCK ==="
input ENUM_TIMEFRAMES  PP2_Timeframe          = PERIOD_CURRENT; // PP2: Khung thời gian (CURRENT = khung chung)
input int              PP2_DoDaiSwing         = 50;             // PP2: Độ dài swing (gốc 50)
input int              PP2_DoDaiNoiBo         = 5;              // PP2: Độ dài cấu trúc nội bộ (gốc 5)
input int              PP2_SoNenNapLichSu     = 1000;           // PP2: Số nến nạp lịch sử khi khởi động (gốc 1000)
input ENUM_PP2_LOAI_OB PP2_LoaiOB             = OB_CA_HAI;      // PP2: Loại Order Block giao dịch
input int              PP2_SoOBXemXet         = 5;              // PP2: Số OB gần nhất được xét (gốc hiển thị 5)
input bool             PP2_GiamThieuTheoClose = false;          // PP2: OB bị phá theo Close (false = High/Low như gốc)
input bool             PP2_TheoTrendSwing     = true;           // PP2: Chỉ vào lệnh theo xu hướng swing
input bool             PP2_LocHTF             = false;          // PP2: Lọc theo xu hướng khung lớn (HTF)
input ENUM_TIMEFRAMES  PP2_HTF                = PERIOD_H4;      // PP2: Khung lớn HTF (gốc H4)
input bool             PP2_LocPremiumDiscount = false;          // PP2: BUY ở vùng Discount, SELL ở vùng Premium
input bool             PP2_YeuCauNenXacNhan   = true;           // PP2: Yêu cầu nến phản ứng cùng chiều
input double           PP2_SL_DemPips         = 10.0;           // PP2: Đệm SL ngoài OB (pips)
input double           PP2_SL_ToiThieuPips    = 30.0;           // PP2: SL tối thiểu (pips)
input double           PP2_RR                 = 2.0;            // PP2: Tỉ lệ R:R cho TP

input group "=== PP3 - FIBONACCI PIVOT NGÀY ==="
input ENUM_TIMEFRAMES PP3_Timeframe        = PERIOD_CURRENT;   // PP3: Khung thời gian (CURRENT = khung chung)
input ENUM_PP3_CHE_DO PP3_CheDo            = PP3_BAT_LAI;      // PP3: Chế độ giao dịch
input int             PP3_SoMucSR          = 2;                // PP3: Số mức S/R dùng (1-3)
input bool            PP3_YeuCauNenXacNhan = true;             // PP3: Yêu cầu nến xác nhận (chế độ bật lại)
input double          PP3_SL_DemPips       = 20.0;             // PP3: Đệm SL (pips)
input double          PP3_SL_ToiThieuPips  = 30.0;             // PP3: SL tối thiểu (pips)
input ENUM_KIEU_TP    PP3_KieuTP           = TP_THEO_CAU_TRUC; // PP3: Kiểu TP
input double          PP3_RR               = 1.5;              // PP3: R:R (khi TP theo R:R)
input double          PP3_RR_ToiThieu      = 1.0;              // PP3: Bỏ lệnh nếu R:R thấp hơn
input bool            PP3_VeDuongPivot     = true;             // PP3: Vẽ các mức pivot lên chart

input group "=== PP4 - QUASIMODO (QM) ==="
input ENUM_TIMEFRAMES PP4_Timeframe        = PERIOD_CURRENT; // PP4: Khung thời gian (CURRENT = khung chung)
input int             PP4_SwingLookback    = 5;              // PP4: Số nến mỗi bên xác nhận swing (gốc 5)
input double          PP4_EntryBufferPips  = 0.0;            // PP4: Đệm vượt QM line khi vào (pips, gốc 0)
input bool            PP4_ChoNenTuChoi     = false;          // PP4: Chờ nến từ chối quay lại qua QM line
input bool            PP4_DungEntry2       = true;           // PP4: Dùng Entry 2 (nến ngược màu tại Head)
input int             PP4_SoNenChoToiDa    = 30;             // PP4: Số nến chờ retrace tối đa
input double          PP4_RR_ToiThieu      = 1.0;            // PP4: Bỏ setup nếu R:R thấp hơn
input bool            PP4_BoQuaVaiChung    = true;           // PP4: Bỏ setup dùng lại Left Shoulder cũ
input bool            PP4_YeuCauTrendTruoc = true;           // PP4: Yêu cầu có xu hướng trước mô hình
input int             PP4_SoPivotTrend     = 2;              // PP4: Số pivot xác nhận xu hướng trước
input double          PP4_SL_DemPips       = 20.0;           // PP4: Đệm SL ngoài Head (pips; gốc 200 points)
input bool            PP4_DungSanATR       = true;           // PP4: Nới SL tối thiểu theo ATR
input int             PP4_ATR_ChuKy        = 14;             // PP4: Chu kỳ ATR (SL sàn + trailing ATR)
input double          PP4_ATR_HeSoSL       = 1.0;            // PP4: Hệ số ATR cho SL sàn
input ENUM_KIEU_TP    PP4_KieuTP           = TP_THEO_RR;     // PP4: Kiểu TP
input double          PP4_RR               = 2.0;            // PP4: R:R cho TP
input bool            PP4_ChoPhepNhieuLenh = false;          // PP4: Cho nhiều lệnh PP4 cùng lúc (gốc: false)
input bool            PP4_NapLichSuSwing   = true;           // PP4: Nạp swing lịch sử khi khởi động
input int             PP4_SoNenLichSu      = 1000;           // PP4: Số nến lịch sử quét

input group "=== HIỂN THỊ ==="
input bool HienThiBang = true; // Hiển thị bảng thông tin trên chart
input int  Bang_X      = 10;   // Bảng: vị trí X
input int  Bang_Y      = 25;   // Bảng: vị trí Y
input int  Bang_CoChu  = 9;    // Bảng: cỡ chữ

//+------------------------------------------------------------------+
//| Cấu trúc dữ liệu                                                 |
//+------------------------------------------------------------------+
struct SDemLenh
  {
   int    tong;
   int    buy;
   int    sell;
   int    pp[5];
   double floating;
  };

struct SLenhTheoDoi
  {
   ulong    ticket;
   int      pp;
   bool     laMua;
   double   giaVao;
   double   slBanDau;
   double   rui;           // khoảng cách giá entry - SL ban đầu (1R)
   bool     daChotMotPhan;
   datetime lanSuaLoi;     // thời điểm sửa SL lỗi gần nhất (chống spam)
  };

struct STinHieu
  {
   int    pp;
   int    huong;
   double sl;
   double tp;
   double lotCoDinh;  // > 0: dùng lot này (tầng nhồi PP1)
   bool   laNhoiLenh;
   string nhan;
   string lyDo;
  };

struct SGioPP1
  {
   int    soLenh;
   double giaDau;
   double giaCuoi;
   double lotDau;
   long   tgDau;
   long   tgCuoi;
  };

struct SPivotSMC
  {
   double   level;
   double   lastLevel;
   bool     crossed;
   datetime barTime;
   int      barIndex;
  };

struct SOBSMC
  {
   double   hi;
   double   lo;
   datetime barTime;
   datetime confirmTime;
   int      bias;
   bool     daGiaoDich;
  };

struct SPivotQM
  {
   bool     isHigh;
   double   price;
   datetime time;
  };

struct SSetupQM
  {
   bool     isActive;
   bool     isBull;
   double   qmLinePrice;
   double   headPrice;
   double   targetPrice;
   double   legPrice;
   datetime shoulderTime;
   datetime legTime;
   datetime headTime;
   datetime bosTime;
   double   shoulderPrice;
   datetime armedTime;
   bool     lineBroken;
   double   entry2Price;
   bool     entry2Valid;
   bool     entry2Broken;
  };

//+------------------------------------------------------------------+
//| Biến toàn cục - chung                                            |
//+------------------------------------------------------------------+
CTrade   g_trade;
double   g_pip          = 0.0;
int      g_digits       = 0;
double   g_point        = 0.0;
int      g_deviationPts = 30;
bool     g_laNetting    = false;
bool     g_veDuoc       = true;

ENUM_TIMEFRAMES g_tf[5];
datetime g_lastBarTime[5];
datetime g_lastEntryTime[5];
datetime g_lastEntryBar[5];
int      g_lastSigDir[5];
datetime g_lastSigTime[5];
string   g_lastRejectMsg[5];
datetime g_lastRejectTime[5];
bool     g_ppBat[5];
string   g_ppTen[5]  = {"MASTER", "PP1", "PP2", "PP3", "PP4"};
string   g_ppMoTa[5] = {"", "RSI", "SMC", "PIVOT", "QM"};

//--- Thông số rủi ro hiệu lực (sau khi áp dụng bộ thông số)
double g_riskPct   = 0.5;
int    g_maxTong   = 4;
int    g_maxBuy    = 2;
int    g_maxSell   = 2;
int    g_maxPP     = 1;
double g_ddNgayMax = 4.0;
double g_ddTKMax   = 15.0;
int    g_thuaLTMax = 4;
string g_tenBoThongSo = "";

//--- Trạng thái Risk Manager
datetime g_ngayHienTai      = 0;
double   g_balanceDauNgay   = 0.0;
double   g_dinhEquity       = 0.0;
double   g_loiNhuanDongNgay = 0.0;
int      g_thuaLienTiep     = 0;
int      g_soLenhDongNgay   = 0;
bool     g_canTinhLaiLichSu = true;
bool     g_khoaNgay         = false;
string   g_lyDoKhoaNgay     = "";
bool     g_khoaTaiKhoan     = false;
string   g_lyDoKhoaTK       = "";
bool     g_choPhepVaoLenh   = true;
string   g_lyDoKhoa         = "";
double   g_ddNgayHienTai    = 0.0;
double   g_ddTKHienTai      = 0.0;
string   g_gvDinh           = "";
double   g_loiNhuanSet      = 0.0;    // lợi nhuận đã đóng của SET từ mốc vốn ảo
bool     g_dinhKhoiTao      = false;
string   g_fileNhatKy       = "";

//--- Lọc tin
datetime g_tinThoiGian[];
string   g_tinTen[];
datetime g_tinCapNhatLuc   = 0;
bool     g_tinDaBaoTester  = false;

//--- Đếm lệnh, theo dõi lệnh, tín hiệu
SDemLenh     g_dem;
SLenhTheoDoi g_lenh[];
STinHieu     g_dsTinHieu[];

//--- Handle chỉ báo
int g_hRSI1 = INVALID_HANDLE;   // RSI cho PP1
int g_hATRQL[5] = {-1, -1, -1, -1, -1};   // ATR cho PP2..PP4 (trailing ATR + SL sàn PP4); -1 = INVALID_HANDLE

//--- Bảng hiển thị
uint g_dbLast = 0;

//--- Bản sao các Input có thể bị SET dựng sẵn (ChonSet) ghi đè
string v_TienTo_Comment;
ENUM_BO_THONG_SO v_BoThongSo;
ENUM_TIMEFRAMES v_Signal_Timeframe;
bool v_Bat_ChienLuoc_1;
bool v_Bat_ChienLuoc_2;
bool v_Bat_ChienLuoc_3;
bool v_Bat_ChienLuoc_4;
bool v_ChanLenhNguocChieu;
ENUM_CHE_DO_XUNG_DOT v_CheDo_XungDot;
ENUM_KIEU_TRAILING v_QL_KieuTrailing;
ENUM_TIMEFRAMES v_PP1_Timeframe;
int v_PP1_RSI_ChuKy;
double v_PP1_RSI_VaoBan;
double v_PP1_RSI_VaoMua;
ENUM_TIMEFRAMES v_PP2_Timeframe;
ENUM_PP2_LOAI_OB v_PP2_LoaiOB;
bool v_PP2_LocHTF;
ENUM_TIMEFRAMES v_PP2_HTF;
bool v_PP2_LocPremiumDiscount;
ENUM_TIMEFRAMES v_PP3_Timeframe;
ENUM_PP3_CHE_DO v_PP3_CheDo;
ENUM_KIEU_TP v_PP3_KieuTP;
ENUM_TIMEFRAMES v_PP4_Timeframe;
bool v_PP4_ChoNenTuChoi;
double v_PP2_RR;
int v_PP2_DoDaiSwing;
bool v_PP2_YeuCauNenXacNhan;
bool v_PP2_TheoTrendSwing;
int v_PP2_SoOBXemXet;
double v_PP4_RR;
ENUM_KIEU_TP v_PP4_KieuTP;
bool v_QL_BatHoaVon;
string   g_moTaSet      = "Theo Input";
datetime g_tgBatDauTest = 0;

//+------------------------------------------------------------------+
//| Biến toàn cục - PP2 (SMC)                                        |
//+------------------------------------------------------------------+
SPivotSMC g2_swH, g2_swL, g2_inH, g2_inL;
int       g2_swTr = 0;
int       g2_inTr = 0;
SOBSMC    g2_swOB[];
SOBSMC    g2_inOB[];
double    g2_hi[];
double    g2_lo[];
double    g2_pH[];
double    g2_pL[];
datetime  g2_t[];
int       g2_n            = 0;
datetime  g2_lastTime     = 0;
MqlRates  g2_barCuoi;
bool      g2_daKhoiTao    = false;
bool      g2_dangNapLichSu = false;
int       g2_hATR200      = INVALID_HANDLE;
int       g2_htfBias      = 0;
datetime  g2_htfLastCalc  = 0;
bool      g2_daBaoThieuNen = false;

//+------------------------------------------------------------------+
//| Biến toàn cục - PP3 (Fibonacci Pivot)                            |
//+------------------------------------------------------------------+
double   g3_muc[7];        // 0:S3 1:S2 2:S1 3:P 4:R1 5:R2 6:R3 (tăng dần)
datetime g3_ngayD1   = 0;
bool     g3_hopLe    = false;
int      g3_daGiaoDich = 0; // bitmask các mức đã giao dịch trong ngày
string   g3_tenMuc[7] = {"S3", "S2", "S1", "P", "R1", "R2", "R3"};

//+------------------------------------------------------------------+
//| Biến toàn cục - PP4 (Quasimodo)                                  |
//+------------------------------------------------------------------+
SPivotQM g4_pivots[];
int      g4_maxPivots              = 24;
double   g4_lastLabeledHigh        = 0.0;
datetime g4_lastLabeledHighTime    = 0;
double   g4_lastLabeledLow         = 0.0;
datetime g4_lastLabeledLowTime     = 0;
SSetupQM g4_setup;
datetime g4_lastArmedBosTime       = 0;
datetime g4_lastArmedShoulderTime  = 0;
bool     g4_replay                 = false;
bool     g4_daKhoiTao              = false;

//+------------------------------------------------------------------+
//| TIỆN ÍCH                                                         |
//+------------------------------------------------------------------+
string D(const double v)  { return DoubleToString(v, g_digits); }
string D2(const double v) { return DoubleToString(v, 2); }
string HuongStr(const int h) { return (h == DIR_BULL ? "BUY" : (h == DIR_BEAR ? "SELL" : "NONE")); }
double P2G(const double pips) { return pips * g_pip; }
double G2P(const double gia)  { return (g_pip > 0.0 ? gia / g_pip : 0.0); }
long   MagicCuaPP(const int pp) { return Magic_Goc * 10 + pp; }

int PPTuMagic(const long magic)
  {
   long d = magic - Magic_Goc * 10;
   if(d >= 1 && d <= SO_PP) return (int)d;
   return 0;
  }

string TfStr(const ENUM_TIMEFRAMES tf)
  {
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return s;
  }

void LogPP(const int pp, const string msg)
  {
   Print("[", g_ppTen[pp], "] ", msg);
  }

void LogChiTiet(const int pp, const string msg)
  {
   if(InLogChiTiet) LogPP(pp, msg);
  }

//--- Kích thước 1 pip theo giá (chuẩn hóa XAUUSD 2/3 digits)
double TinhKichThuocPip()
  {
   if(KichThuocPip_TuyChinh > 0.0) return KichThuocPip_TuyChinh;
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return 0.10;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0) return 0.01;
   if(_Digits == 3 || _Digits == 5) return 10.0 * _Point;
   return _Point;
  }

//--- Làm tròn giá theo tick size của symbol
double NormalizeGia(const double gia)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double g = gia;
   if(tick > 0.0) g = MathRound(g / tick) * tick;
   return NormalizeDouble(g, g_digits);
  }

//--- Số chữ số thập phân của bước lot
int SoChuSoLot()
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 2;
   int dg = 0;
   double s = step;
   while(dg < 8 && MathAbs(s - MathRound(s)) > 1e-9)
     {
      s *= 10.0;
      dg++;
     }
   return dg;
  }

//--- Chuẩn hóa lot: làm tròn XUỐNG theo bước, chặn max sàn & Lot_ToiDa (không tự nâng lên min)
double NormalizeLot(const double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   double capMax = vmax;
   if(Lot_ToiDa > 0.0 && (capMax <= 0.0 || Lot_ToiDa < capMax)) capMax = Lot_ToiDa;
   double l = MathFloor(lot / step + 1e-9) * step;
   if(capMax > 0.0 && l > capMax) l = MathFloor(capMax / step + 1e-9) * step;
   if(l < 0.0) l = 0.0;
   return NormalizeDouble(l, SoChuSoLot());
  }

//--- Khoảng cách tối thiểu SL/TP so với giá (StopLevel / FreezeLevel + biên an toàn)
double KhoangCachDungToiThieu()
  {
   long sl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long fz = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   long lv = (sl > fz ? sl : fz);
   return (double)(lv + 2) * g_point;
  }

double SpreadPips()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return 0.0;
   return G2P(tk.ask - tk.bid);
  }

double LayGiaTriChiBao(const int handle, const int buffer, const int shift)
  {
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   double v[];
   if(CopyBuffer(handle, buffer, shift, 1, v) < 1) return EMPTY_VALUE;
   return v[0];
  }

bool HuongChoPhep(const int huong)
  {
   if(HuongGiaoDich == HGD_CA_HAI) return true;
   if(HuongGiaoDich == HGD_CHI_MUA) return (huong == DIR_BULL);
   return (huong == DIR_BEAR);
  }

double DiemPP(const int pp)
  {
   if(pp == 1) return Diem_PP1;
   if(pp == 2) return Diem_PP2;
   if(pp == 3) return Diem_PP3;
   if(pp == 4) return Diem_PP4;
   return 0.0;
  }

string TenCheDoXungDot()
  {
   switch(v_CheDo_XungDot)
     {
      case XD_DOC_LAP:          return "Độc lập";
      case XD_DA_SO:            return "Đa số";
      case XD_KHONG_DOI_NGHICH: return "Không đối nghịch";
      case XD_DIEM_SO:          return "Điểm số";
     }
   return "?";
  }

ENUM_TIMEFRAMES ResolveTF(const ENUM_TIMEFRAMES tf)
  {
   if(tf != PERIOD_CURRENT) return tf;
   if(v_Signal_Timeframe != PERIOD_CURRENT) return v_Signal_Timeframe;
   return (ENUM_TIMEFRAMES)_Period;
  }

//--- Phát hiện nến mới theo khung của từng PP
bool IsNewBar(const int pp)
  {
   datetime t = iTime(_Symbol, g_tf[pp], 0);
   if(t == 0) return false;
   if(t != g_lastBarTime[pp])
     {
      g_lastBarTime[pp] = t;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| ĐẾM LỆNH                                                         |
//+------------------------------------------------------------------+
void DemLenh(SDemLenh &d)
  {
   d.tong = 0;
   d.buy = 0;
   d.sell = 0;
   d.floating = 0.0;
   for(int k = 0; k <= SO_PP; k++) d.pp[k] = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int pp = PPTuMagic(PositionGetInteger(POSITION_MAGIC));
      if(pp == 0) continue;
      d.tong++;
      d.pp[pp]++;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) d.buy++;
      else d.sell++;
      d.floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
  }

int DemViTheTrenSymbol()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol) n++;
     }
   return n;
  }

//+------------------------------------------------------------------+
//| THEO DÕI LỆNH (rủi ro ban đầu / chốt một phần)                  |
//+------------------------------------------------------------------+
int TimLenhTheoDoi(const ulong ticket)
  {
   for(int i = 0; i < ArraySize(g_lenh); i++)
      if(g_lenh[i].ticket == ticket) return i;
   return -1;
  }

void ThemLenhTheoDoi(const ulong ticket, const int pp, const bool laMua, const double giaVao, const double sl, const bool daChot)
  {
   if(ticket == 0 || TimLenhTheoDoi(ticket) >= 0) return;
   int n = ArraySize(g_lenh);
   ArrayResize(g_lenh, n + 1);
   g_lenh[n].ticket        = ticket;
   g_lenh[n].pp            = pp;
   g_lenh[n].laMua         = laMua;
   g_lenh[n].giaVao        = giaVao;
   g_lenh[n].slBanDau      = sl;
   g_lenh[n].rui           = (sl > 0.0 ? MathAbs(giaVao - sl) : 0.0);
   g_lenh[n].daChotMotPhan = daChot;
   g_lenh[n].lanSuaLoi     = 0;
  }

void CapNhatLenhTheoDoi()
  {
   //--- Bỏ các lệnh đã đóng
   for(int i = ArraySize(g_lenh) - 1; i >= 0; i--)
     {
      if(!PositionSelectByTicket(g_lenh[i].ticket))
        {
         int n = ArraySize(g_lenh);
         for(int j = i; j < n - 1; j++) g_lenh[j] = g_lenh[j + 1];
         ArrayResize(g_lenh, n - 1);
        }
     }
   //--- Nhận các lệnh của EA chưa được theo dõi (ví dụ sau khi khởi động lại)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int pp = PPTuMagic(PositionGetInteger(POSITION_MAGIC));
      if(pp == 0) continue;
      if(TimLenhTheoDoi(tk) >= 0) continue;
      bool laMua = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      //--- Như bản gốc QM: lệnh nhận lại coi như đã chốt một phần để tránh chốt ngoài ý muốn
      ThemLenhTheoDoi(tk, pp, laMua, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL), true);
     }
  }

//+------------------------------------------------------------------+
//| ĐÓNG LỆNH                                                        |
//+------------------------------------------------------------------+
//--- loai: -1 = tất cả, POSITION_TYPE_BUY, POSITION_TYPE_SELL ; pp = 0 -> mọi PP
int DongLenhTheoPP(const int pp, const int loai, const string lyDo)
  {
   int dem = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int p = PPTuMagic(PositionGetInteger(POSITION_MAGIC));
      if(p == 0) continue;
      if(pp > 0 && p != pp) continue;
      if(loai >= 0 && PositionGetInteger(POSITION_TYPE) != loai) continue;
      double loiNhuan = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(g_trade.PositionClose(tk))
        {
         dem++;
         LogPP(p, "Đóng lệnh #" + IntegerToString((long)tk) + " | lợi nhuận " + D2(loiNhuan) + " | lý do: " + lyDo);
        }
      else
         LogPP(p, "LỖI đóng lệnh #" + IntegerToString((long)tk) + ": retcode=" + IntegerToString((int)g_trade.ResultRetcode()) +
               " (" + g_trade.ResultRetcodeDescription() + ")");
     }
   return dem;
  }

void DongTatCaLenhEA(const string lyDo)
  {
   int n = DongLenhTheoPP(0, -1, lyDo);
   LogPP(0, "Đã đóng " + IntegerToString(n) + " lệnh của EA. Lý do: " + lyDo);
  }

//+------------------------------------------------------------------+
//| RISK MANAGER                                                     |
//+------------------------------------------------------------------+
void ApDungBoThongSo()
  {
   switch(v_BoThongSo)
     {
      case BTS_AN_TOAN:
         g_tenBoThongSo = "SAFE";
         g_riskPct = 0.25; g_maxTong = 2; g_maxBuy = 1; g_maxSell = 1; g_maxPP = 1;
         g_ddNgayMax = 2.0; g_ddTKMax = 8.0; g_thuaLTMax = 3;
         break;
      case BTS_CAN_BANG:
         g_tenBoThongSo = "BALANCED";
         g_riskPct = 0.5; g_maxTong = 4; g_maxBuy = 2; g_maxSell = 2; g_maxPP = 1;
         g_ddNgayMax = 4.0; g_ddTKMax = 15.0; g_thuaLTMax = 4;
         break;
      case BTS_MAO_HIEM:
         g_tenBoThongSo = "AGGRESSIVE";
         g_riskPct = 1.0; g_maxTong = 6; g_maxBuy = 4; g_maxSell = 4; g_maxPP = 2;
         g_ddNgayMax = 6.0; g_ddTKMax = 25.0; g_thuaLTMax = 6;
         break;
      default:
         g_tenBoThongSo = "TÙY CHỈNH";
         g_riskPct = Risk_Percent; g_maxTong = MaxLenh_Tong; g_maxBuy = MaxLenh_Buy; g_maxSell = MaxLenh_Sell;
         g_maxPP = MaxLenh_MoiPP; g_ddNgayMax = DDNgay_ToiDa_PhanTram; g_ddTKMax = DDTaiKhoan_ToiDa_PhanTram;
         g_thuaLTMax = ThuaLienTiep_ToiDa;
         break;
     }
   if(Risk_GhiDe_PT > 0.0) g_riskPct = Risk_GhiDe_PT;
  }

//--- Vốn ảo: mỗi SET coi như 1 tài khoản riêng (để nhiều SET chạy chung 1 tài khoản demo)
bool   DungVonAo()       { return (VonAo_USD > 0.0); }
double SoDuTinhToan()    { return (DungVonAo() ? VonAo_USD + g_loiNhuanSet : AccountInfoDouble(ACCOUNT_BALANCE)); }
double EquityTinhToan()  { return (DungVonAo() ? VonAo_USD + g_loiNhuanSet + g_dem.floating : AccountInfoDouble(ACCOUNT_EQUITY)); }

//--- Lợi nhuận đã đóng của SET kể từ mốc vốn ảo (mọi deal của các Magic thuộc SET)
void TinhLaiLoiNhuanSet()
  {
   g_loiNhuanSet = 0.0;
   if(!DungVonAo()) return;
   if(!HistorySelect(VonAo_BatDau, TimeCurrent() + 86400)) return;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong dl = HistoryDealGetTicket(i);
      if(dl == 0) continue;
      if(PPTuMagic(HistoryDealGetInteger(dl, DEAL_MAGIC)) == 0) continue;
      g_loiNhuanSet += HistoryDealGetDouble(dl, DEAL_PROFIT) + HistoryDealGetDouble(dl, DEAL_SWAP)
                     + HistoryDealGetDouble(dl, DEAL_COMMISSION) + HistoryDealGetDouble(dl, DEAL_FEE);
     }
  }

//--- Tính lại lợi nhuận đã đóng trong ngày + chuỗi thua liên tiếp (chỉ lệnh của EA trên symbol này)
void TinhLaiThongKeNgay()
  {
   g_loiNhuanDongNgay = 0.0;
   g_thuaLienTiep     = 0;
   g_soLenhDongNgay   = 0;
   g_canTinhLaiLichSu = false;
   TinhLaiLoiNhuanSet();
   if(!HistorySelect(g_ngayHienTai, TimeCurrent() + 86400)) return;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong dl = HistoryDealGetTicket(i);
      if(dl == 0) continue;
      if(HistoryDealGetString(dl, DEAL_SYMBOL) != _Symbol) continue;
      if(PPTuMagic(HistoryDealGetInteger(dl, DEAL_MAGIC)) == 0) continue;
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dl, DEAL_ENTRY);
      double p = HistoryDealGetDouble(dl, DEAL_PROFIT) + HistoryDealGetDouble(dl, DEAL_SWAP) +
                 HistoryDealGetDouble(dl, DEAL_COMMISSION) + HistoryDealGetDouble(dl, DEAL_FEE);
      g_loiNhuanDongNgay += p;
      if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
        {
         g_soLenhDongNgay++;
         if(p < 0.0) g_thuaLienTiep++;
         else if(p > 0.0) g_thuaLienTiep = 0;
        }
     }
  }

void KhoaNgay(const string lyDo, const bool laDD)
  {
   g_khoaNgay = true;
   g_lyDoKhoaNgay = lyDo;
   LogPP(0, "RISK MANAGER: NGỪNG mở lệnh mới tới hết ngày. Lý do: " + lyDo);
   if(laDD && DongTatCaKhiVuotDD) DongTatCaLenhEA(lyDo);
  }

bool CheckRiskManager(string &lyDo)
  {
   long t = (long)TimeCurrent();
   datetime ngay = (datetime)(t - t % 86400);
   bool ngayMoi = (ngay != g_ngayHienTai);
   bool lanDau  = (g_ngayHienTai == 0);
   if(ngayMoi)
     {
      g_ngayHienTai = ngay;
      if(g_khoaNgay) LogPP(0, "Sang ngày mới -> mở khóa giới hạn ngày.");
      g_khoaNgay = false;
      g_lyDoKhoaNgay = "";
      g_canTinhLaiLichSu = true;
      g3_daGiaoDich = 0;
     }
   if(g_canTinhLaiLichSu) TinhLaiThongKeNgay();
   if(ngayMoi)
     {
      g_balanceDauNgay = SoDuTinhToan();
      if(!lanDau) LogChiTiet(0, "Ngày mới " + TimeToString(ngay, TIME_DATE) + " | balance đầu ngày" +
                             (DungVonAo() ? " (vốn ảo)" : "") + " = " + D2(g_balanceDauNgay));
     }

   double eq = EquityTinhToan();
   if(!g_dinhKhoiTao)
     {
      //--- Chỉ nhớ đỉnh equity qua các lần khởi động khi chạy thật (Tester luôn bắt đầu từ equity hiện tại)
      g_dinhEquity = eq;
      if(DungVonAo()) g_dinhEquity = MathMax(eq, VonAo_USD);
      if(MQLInfoInteger(MQL_TESTER) == 0 && !ResetDinhEquityKhiKhoiDong && GlobalVariableCheck(g_gvDinh))
         g_dinhEquity = MathMax(g_dinhEquity, GlobalVariableGet(g_gvDinh));
      g_dinhKhoiTao = true;
     }
   if(eq > g_dinhEquity) g_dinhEquity = eq;
   if(MQLInfoInteger(MQL_TESTER) == 0) GlobalVariableSet(g_gvDinh, g_dinhEquity);
   g_ddNgayHienTai = (g_balanceDauNgay > 0.0 ? MathMax(0.0, (g_balanceDauNgay - eq) / g_balanceDauNgay * 100.0) : 0.0);
   g_ddTKHienTai   = (g_dinhEquity > 0.0 ? MathMax(0.0, (g_dinhEquity - eq) / g_dinhEquity * 100.0) : 0.0);

   //--- DD ngày
   if(!g_khoaNgay && Bat_GioiHanDDNgay && g_ddNgayMax > 0.0 && g_ddNgayHienTai >= g_ddNgayMax)
      KhoaNgay(StringFormat("DD ngày %.2f%% >= %.2f%%", g_ddNgayHienTai, g_ddNgayMax), true);
   //--- DD tài khoản (khóa tới khi khởi động lại EA)
   if(!g_khoaTaiKhoan && Bat_GioiHanDDTaiKhoan && g_ddTKMax > 0.0 && g_ddTKHienTai >= g_ddTKMax)
     {
      g_khoaTaiKhoan = true;
      g_lyDoKhoaTK = StringFormat("DD tài khoản %.2f%% >= %.2f%%", g_ddTKHienTai, g_ddTKMax);
      LogPP(0, "RISK MANAGER: NGỪNG mở lệnh mới (khóa tới khi khởi động lại EA). Lý do: " + g_lyDoKhoaTK);
      if(DongTatCaKhiVuotDD) DongTatCaLenhEA(g_lyDoKhoaTK);
     }
   //--- Lỗ ngày theo tiền (đã đóng + đang thả nổi)
   if(!g_khoaNgay && Bat_GioiHanLoNgay && LoNgay_ToiDa_Tien > 0.0)
     {
      double loNgay = g_loiNhuanDongNgay + g_dem.floating;
      if(loNgay <= -LoNgay_ToiDa_Tien)
         KhoaNgay(StringFormat("Lỗ ngày %.2f <= -%.2f", loNgay, LoNgay_ToiDa_Tien), false);
     }
   //--- Thua liên tiếp
   if(!g_khoaNgay && Bat_GioiHanThuaLienTiep && g_thuaLTMax > 0 && g_thuaLienTiep >= g_thuaLTMax)
      KhoaNgay(StringFormat("Thua liên tiếp %d lệnh >= %d", g_thuaLienTiep, g_thuaLTMax), false);

   if(g_khoaTaiKhoan) { lyDo = g_lyDoKhoaTK;   return false; }
   if(g_khoaNgay)     { lyDo = g_lyDoKhoaNgay; return false; }
   lyDo = "";
   return true;
  }

//+------------------------------------------------------------------+
//| BỘ LỌC CHUNG                                                     |
//+------------------------------------------------------------------+
bool CheckSpread(string &lyDo)
  {
   if(!Bat_LocSpread) return true;
   double sp = SpreadPips();
   if(sp > Spread_ToiDa_Pips)
     {
      lyDo = StringFormat("Spread %.1f pips > tối đa %.1f pips", sp, Spread_ToiDa_Pips);
      return false;
     }
   return true;
  }

bool TrongKhoangGio(const int h, const int batDau, const int ketThuc)
  {
   if(batDau == ketThuc) return true;
   if(batDau < ketThuc) return (h >= batDau && h < ketThuc);
   return (h >= batDau || h < ketThuc);   // khung qua nửa đêm
  }

bool CheckTradingTime(string &lyDo)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hServer = dt.hour;
   if(Bat_LocGio && !TrongKhoangGio(hServer, StartHour, EndHour))
     {
      lyDo = StringFormat("Ngoài khung giờ %02d:00-%02d:00 (server %02d:%02d)", StartHour, EndHour, dt.hour, dt.min);
      return false;
     }
   if(Bat_LocPhien)
     {
      int hGMT = ((hServer - LechGioServer_GMT) % 24 + 24) % 24;
      bool ok = (GiaoDich_PhienA  && TrongKhoangGio(hGMT, PhienA_BatDau_GMT,  PhienA_KetThuc_GMT)) ||
                (GiaoDich_PhienAu && TrongKhoangGio(hGMT, PhienAu_BatDau_GMT, PhienAu_KetThuc_GMT)) ||
                (GiaoDich_PhienMy && TrongKhoangGio(hGMT, PhienMy_BatDau_GMT, PhienMy_KetThuc_GMT));
      if(!ok)
        {
         lyDo = StringFormat("Ngoài phiên được phép (giờ GMT %02d)", hGMT);
         return false;
        }
     }
   return true;
  }

//--- Lọc tin dùng Lịch kinh tế tích hợp của MT5. Không hoạt động trong Strategy Tester.
void CapNhatLichTin()
  {
   ArrayResize(g_tinThoiGian, 0);
   ArrayResize(g_tinTen, 0);
   datetime now = TimeTradeServer();
   MqlCalendarValue vals[];
   if(!CalendarValueHistory(vals, now - 86400, now + 86400, NULL, Tin_TienTe))
     {
      LogChiTiet(0, "Lọc tin: không đọc được Lịch kinh tế (lỗi " + IntegerToString(GetLastError()) + ")");
      return;
     }
   int n = ArraySize(vals);
   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id, ev)) continue;
      if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
      int k = ArraySize(g_tinThoiGian);
      ArrayResize(g_tinThoiGian, k + 1);
      ArrayResize(g_tinTen, k + 1);
      g_tinThoiGian[k] = vals[i].time;
      g_tinTen[k] = ev.name;
     }
  }

bool CheckNews(string &lyDo)
  {
   if(!Bat_LocTin) return true;
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      if(!g_tinDaBaoTester)
        {
         LogPP(0, "Lọc tin: Lịch kinh tế không có trong Strategy Tester -> bộ lọc tin KHÔNG có tác dụng khi backtest.");
         g_tinDaBaoTester = true;
        }
      return true;
     }
   datetime now = TimeTradeServer();
   if(now - g_tinCapNhatLuc > 900)
     {
      CapNhatLichTin();
      g_tinCapNhatLuc = now;
     }
   for(int i = 0; i < ArraySize(g_tinThoiGian); i++)
     {
      if(now >= g_tinThoiGian[i] - Tin_PhutTruoc * 60 && now <= g_tinThoiGian[i] + Tin_PhutSau * 60)
        {
         lyDo = "Gần tin quan trọng: " + g_tinTen[i] + " lúc " + TimeToString(g_tinThoiGian[i], TIME_DATE | TIME_MINUTES);
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| TÍNH LOT                                                         |
//+------------------------------------------------------------------+
//--- Số tiền lỗ khi 1 lot chạm SL
//--- Hệ số đổi tiền lợi nhuận của symbol -> tiền tài khoản (xử lý tài khoản Cent USC/USD)
double HeSoTienTe()
  {
   string tk = AccountInfoString(ACCOUNT_CURRENCY);
   string ln = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(tk == ln) return 1.0;
   if(ln == "USD" && tk == "USC") return 100.0;
   if(ln == "USC" && tk == "USD") return 0.01;
   return 0.0;   // không quy đổi được -> bỏ qua cách tính này
  }

//--- Số tiền lỗ khi 1 lot chạm SL: tính 3 cách, lấy giá trị LỚN NHẤT (an toàn, lot nhỏ hơn)
double TinhLoMoiLot(const int huong, const double giaVao, const double sl)
  {
   double kc = MathAbs(giaVao - sl);
   double a = 0.0, b = 0.0, c = 0.0, p = 0.0;
   ENUM_ORDER_TYPE ot = (huong == DIR_BULL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcProfit(ot, _Symbol, 1.0, giaVao, sl, p) && p < 0.0) a = -p;
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv > 0.0 && ts > 0.0) b = kc / ts * tv;
   double cs = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double hs = HeSoTienTe();
   if(cs > 0.0 && hs > 0.0) c = kc * cs * hs;
   return MathMax(a, MathMax(b, c));
  }

//--- In thông số hợp đồng để kiểm tra lot (đặc biệt tài khoản Cent)
void InThongSoHopDong()
  {
   double gia = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(gia <= 0.0) gia = iClose(_Symbol, PERIOD_D1, 1);
   double p = 0.0, a = 0.0;
   if(gia > 0.0 && OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, gia, gia - P2G(10.0), p)) a = -p;
   Print(StringFormat("HỢP ĐỒNG %s: tiền TK=%s | tiền lợi nhuận=%s | contract=%.2f | tick size=%s tick value=%.5f | lot min/step/max=%.2f/%.2f/%.2f",
                      _Symbol, AccountInfoString(ACCOUNT_CURRENCY), SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT),
                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE),
                      DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), g_digits),
                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
                      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
                      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)));
   if(gia > 0.0)
      Print(StringFormat("KIỂM TRA LOT: 1 lot đi ngược 10 pip (%.2f giá) = lỗ %.2f %s (OrderCalcProfit %.2f) | Balance %.2f",
                         P2G(10.0), TinhLoMoiLot(DIR_BULL, gia, gia - P2G(10.0)), AccountInfoString(ACCOUNT_CURRENCY),
                         a, AccountInfoDouble(ACCOUNT_BALANCE)));
  }

double CalculateLot(const int pp, const int huong, const double giaVao, const double sl, const double lotCoDinh, string &lyDo)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double bal  = SoDuTinhToan();
   double lot  = 0.0;
   if(lotCoDinh > 0.0)
      lot = lotCoDinh;
   else if(!SuDung_AutoLot)
      lot = Lot_CoDinh;
   else
     {
      double lo1Lot = TinhLoMoiLot(huong, giaVao, sl);
      if(lo1Lot <= 0.0 || bal <= 0.0)
        {
         lyDo = "Không tính được giá trị rủi ro mỗi lot";
         return 0.0;
        }
      lot = bal * g_riskPct / 100.0 / lo1Lot;
      if(lot < vmin)
        {
         double ruiThucTe = lo1Lot * vmin / bal * 100.0;
         if(ChoPhepDungLotToiThieu && ruiThucTe <= g_riskPct * HeSoRuiRoToiDaVoiLotMin)
           {
            LogChiTiet(pp, StringFormat("Lot theo rủi ro %.4f < lot min %.2f -> dùng lot min (rủi ro thực tế %.2f%%)", lot, vmin, ruiThucTe));
            lot = vmin;
           }
         else
           {
            lyDo = StringFormat("Lot theo rủi ro %.4f < lot min %.2f (rủi ro thực tế với lot min %.2f%% quá cao)", lot, vmin, ruiThucTe);
            return 0.0;
           }
        }
     }
   lot = NormalizeLot(lot);
   if(lot < vmin - 1e-9)
     {
      lyDo = "Lot sau chuẩn hóa nhỏ hơn lot tối thiểu của sàn";
      return 0.0;
     }
   //--- Kiểm tra ký quỹ
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = (huong == DIR_BULL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcMargin(ot, _Symbol, lot, giaVao, margin) && margin > 0.0)
     {
      double kyQuyTrong = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > kyQuyTrong * 0.9)
        {
         double lotMoi = NormalizeLot(lot * kyQuyTrong * 0.9 / margin);
         if(lotMoi < vmin - 1e-9)
           {
            lyDo = "Không đủ ký quỹ";
            return 0.0;
           }
         LogPP(pp, "Giảm lot do thiếu ký quỹ: " + D2(lot) + " -> " + D2(lotMoi));
         lot = lotMoi;
        }
     }
   return lot;
  }

//+------------------------------------------------------------------+
//| LOG TỪ CHỐI (chống spam log)                                     |
//+------------------------------------------------------------------+
void LogTuChoi(const int pp, const int huong, const string lyDo)
  {
   string key = HuongStr(huong) + "|" + lyDo;
   if(key == g_lastRejectMsg[pp] && (long)TimeCurrent() - (long)g_lastRejectTime[pp] < 300) return;
   g_lastRejectMsg[pp]  = key;
   g_lastRejectTime[pp] = TimeCurrent();
   if(InLogChiTiet) LogPP(pp, "Bỏ qua tín hiệu " + HuongStr(huong) + " - lý do: " + lyDo);
  }

//+------------------------------------------------------------------+
//| NHẬT KÝ LỆNH CSV (Common\Files) - để so sánh các SET về sau     |
//+------------------------------------------------------------------+
string ChuoiCSV(string v)
  {
   StringReplace(v, ";", ",");
   StringReplace(v, "\r", " ");
   StringReplace(v, "\n", " ");
   return v;
  }

void GhiNhatKy(const string suKien, const int pp, const ulong ticket, const string loai, const double lot,
               const double gia, const double sl, const double tp, const double loiNhuan, const string ghiChu,
               const string comment)
  {
   if(!GhiNhatKyCSV || g_fileNhatKy == "") return;
   int h = FileOpen(g_fileNhatKy, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      LogPP(0, "Không mở được file nhật ký " + g_fileNhatKy + " (lỗi " + IntegerToString(GetLastError()) + ")");
      return;
     }
   if(FileSize(h) <= 2)
      FileWriteString(h, "Thoi gian;SET;Magic;PP;Su kien;Ticket;Loai;Lot;Gia;SL;TP;Loi nhuan;Spread pips;"
                         + "Bo TS;Xung dot;Khung PP;Comment;Ghi chu\r\n");
   FileSeek(h, 0, SEEK_END);
   string dong = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
               + ";" + ChuoiCSV(v_TienTo_Comment)
               + ";" + IntegerToString(pp > 0 ? MagicCuaPP(pp) : Magic_Goc)
               + ";" + (pp > 0 ? g_ppTen[pp] + " " + g_ppMoTa[pp] : "-")
               + ";" + suKien
               + ";" + IntegerToString((long)ticket)
               + ";" + loai
               + ";" + D2(lot)
               + ";" + D(gia)
               + ";" + (sl > 0.0 ? D(sl) : "")
               + ";" + (tp > 0.0 ? D(tp) : "")
               + ";" + D2(loiNhuan)
               + ";" + DoubleToString(SpreadPips(), 1)
               + ";" + g_tenBoThongSo
               + ";" + TenCheDoXungDot()
               + ";" + (pp > 0 ? TfStr(g_tf[pp]) : "")
               + ";" + ChuoiCSV(comment)
               + ";" + ChuoiCSV(ghiChu) + "\r\n";
   FileWriteString(h, dong);
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| MỞ LỆNH                                                          |
//+------------------------------------------------------------------+
bool OpenTrade(STinHieu &s)
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
     {
      LogTuChoi(s.pp, s.huong, "Không lấy được giá hiện tại");
      return false;
     }
   bool   laMua   = (s.huong == DIR_BULL);
   double gia     = (laMua ? tk.ask : tk.bid);
   double sl      = s.sl;
   double tp      = s.tp;
   double minDist = KhoangCachDungToiThieu();

   if(sl <= 0.0)
     {
      LogTuChoi(s.pp, s.huong, "Tín hiệu không có SL (EA không cho phép lệnh không SL)");
      return false;
     }
   if(laMua)
     {
      if(sl >= gia)
        {
         LogTuChoi(s.pp, s.huong, "SL " + D(sl) + " nằm trên giá vào " + D(gia));
         return false;
        }
      if(tk.bid - sl < minDist)
        {
         LogChiTiet(s.pp, "SL quá gần (StopLevel) -> nới SL từ " + D(sl) + " thành " + D(tk.bid - minDist));
         sl = tk.bid - minDist;
        }
      if(tp > 0.0)
        {
         if(tp <= gia)
           {
            LogTuChoi(s.pp, s.huong, "TP " + D(tp) + " đã bị giá vượt qua");
            return false;
           }
         if(tp - tk.bid < minDist) tp = tk.bid + minDist;
        }
     }
   else
     {
      if(sl <= gia)
        {
         LogTuChoi(s.pp, s.huong, "SL " + D(sl) + " nằm dưới giá vào " + D(gia));
         return false;
        }
      if(sl - tk.ask < minDist)
        {
         LogChiTiet(s.pp, "SL quá gần (StopLevel) -> nới SL từ " + D(sl) + " thành " + D(tk.ask + minDist));
         sl = tk.ask + minDist;
        }
      if(tp > 0.0)
        {
         if(tp >= gia)
           {
            LogTuChoi(s.pp, s.huong, "TP " + D(tp) + " đã bị giá vượt qua");
            return false;
           }
         if(tk.ask - tp < minDist) tp = tk.ask - minDist;
        }
     }
   sl = NormalizeGia(sl);
   if(tp > 0.0) tp = NormalizeGia(tp);

   string lyDoLot = "";
   double lot = CalculateLot(s.pp, s.huong, gia, sl, s.lotCoDinh, lyDoLot);
   if(lot <= 0.0)
     {
      LogTuChoi(s.pp, s.huong, lyDoLot);
      return false;
     }
   //--- CHỐT CHẶN rủi ro: lỗ tại SL không được vượt RuiRoToiDaMoiLenh_PT % Balance (áp dụng cả lot cố định)
   double tienLoSL = TinhLoMoiLot(s.huong, gia, sl) * lot;
   double balRui   = SoDuTinhToan();
   double ruiPT    = (balRui > 0.0 ? tienLoSL / balRui * 100.0 : 0.0);
   if(RuiRoToiDaMoiLenh_PT > 0.0 && ruiPT > RuiRoToiDaMoiLenh_PT)
     {
      LogTuChoi(s.pp, s.huong, StringFormat("CHỐT CHẶN: lot %s lỗ tại SL %.2f = %.2f%% Balance > %.2f%%",
                                            D2(lot), tienLoSL, ruiPT, RuiRoToiDaMoiLenh_PT));
      return false;
     }

   string cmt = v_TienTo_Comment + "_PP" + IntegerToString(s.pp) + "_" + (laMua ? "BUY" : "SELL");
   if(s.nhan != "") cmt += "_" + s.nhan;
   if(StringLen(cmt) > 31) cmt = StringSubstr(cmt, 0, 31);

   g_trade.SetExpertMagicNumber((ulong)MagicCuaPP(s.pp));
   bool ok = (laMua ? g_trade.Buy(lot, _Symbol, 0.0, sl, tp, cmt) : g_trade.Sell(lot, _Symbol, 0.0, sl, tp, cmt));
   uint rc = g_trade.ResultRetcode();
   //--- Đặt cooldown cả khi lỗi để không gửi lệnh liên tục
   g_lastEntryTime[s.pp] = TimeCurrent();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
     {
      LogPP(s.pp, StringFormat("LỖI mở lệnh %s: retcode=%u (%s) | lot=%s giá=%s SL=%s TP=%s spread=%.1f pips",
                               (laMua ? "BUY" : "SELL"), rc, g_trade.ResultRetcodeDescription(),
                               D2(lot), D(gia), D(sl), D(tp), SpreadPips()));
      GhiNhatKy("LOI MO", s.pp, 0, (laMua ? "BUY" : "SELL"), lot, gia, sl, tp, 0.0,
                "retcode " + IntegerToString((int)rc) + " " + g_trade.ResultRetcodeDescription() + " | " + s.lyDo, cmt);
      return false;
     }

   double giaKhop = g_trade.ResultPrice();
   if(giaKhop <= 0.0) giaKhop = gia;
   ulong posId = 0;
   ulong deal  = g_trade.ResultDeal();
   if(deal > 0 && HistoryDealSelect(deal)) posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   if(posId == 0) posId = g_trade.ResultOrder();
   ThemLenhTheoDoi(posId, s.pp, laMua, giaKhop, sl, false);

   g_lastEntryBar[s.pp] = iTime(_Symbol, g_tf[s.pp], 0);
   g_dem.tong++;
   g_dem.pp[s.pp]++;
   if(laMua) g_dem.buy++;
   else g_dem.sell++;

   LogPP(s.pp, StringFormat("MỞ %s #%s | giá=%s SL=%s TP=%s | lot=%s | rủi ro=%.1f pips (%.2f%% TK) | spread=%.1f pips | magic=%d | %s | %s",
                            (laMua ? "BUY" : "SELL"), IntegerToString((long)posId), D(giaKhop), D(sl),
                            (tp > 0.0 ? D(tp) : "không"), D2(lot), G2P(MathAbs(giaKhop - sl)), ruiPT, SpreadPips(),
                            (int)MagicCuaPP(s.pp), cmt, s.lyDo));
   GhiNhatKy("MO", s.pp, posId, (laMua ? "BUY" : "SELL"), lot, giaKhop, sl, tp, 0.0, s.lyDo, cmt);
   return true;
  }

//+------------------------------------------------------------------+
//| TÍN HIỆU + XUNG ĐỘT + KIỂM TRA TRƯỚC KHI VÀO                     |
//+------------------------------------------------------------------+
void ThemTinHieu(const int pp, const int huong, const double sl, const double tp, const double lotCoDinh,
                 const bool laNhoi, const string nhan, const string lyDo)
  {
   int n = ArraySize(g_dsTinHieu);
   ArrayResize(g_dsTinHieu, n + 1);
   g_dsTinHieu[n].pp         = pp;
   g_dsTinHieu[n].huong      = huong;
   g_dsTinHieu[n].sl         = sl;
   g_dsTinHieu[n].tp         = tp;
   g_dsTinHieu[n].lotCoDinh  = lotCoDinh;
   g_dsTinHieu[n].laNhoiLenh = laNhoi;
   g_dsTinHieu[n].nhan       = nhan;
   g_dsTinHieu[n].lyDo       = lyDo;
   if(!laNhoi)
     {
      g_lastSigDir[pp]  = huong;
      g_lastSigTime[pp] = TimeCurrent();
     }
   LogChiTiet(pp, "TÍN HIỆU " + HuongStr(huong) + (laNhoi ? " (tầng nhồi)" : "") + " | " + lyDo +
              " | SL=" + D(sl) + " TP=" + (tp > 0.0 ? D(tp) : "không"));
  }

bool ChapNhanTheoXungDot(STinHieu &s, string &lyDo)
  {
   if(v_CheDo_XungDot == XD_DOC_LAP || s.laNhoiLenh) return true;
   int    soMua = 0, soBan = 0;
   double diemMua = 0.0, diemBan = 0.0;
   long   now = (long)TimeCurrent();
   for(int pp = 1; pp <= SO_PP; pp++)
     {
      if(!g_ppBat[pp] || g_lastSigDir[pp] == 0) continue;
      if(now - (long)g_lastSigTime[pp] > HieuLucTinHieu_Giay) continue;
      if(g_lastSigDir[pp] == DIR_BULL) { soMua++; diemMua += DiemPP(pp); }
      else                             { soBan++; diemBan += DiemPP(pp); }
     }
   string tk = StringFormat("BUY=%d (%.1f điểm) / SELL=%d (%.1f điểm)", soMua, diemMua, soBan, diemBan);
   bool laMua = (s.huong == DIR_BULL);
   if(v_CheDo_XungDot == XD_DA_SO)
     {
      if(laMua ? (soMua > soBan) : (soBan > soMua)) return true;
      lyDo = "Xung đột - đa số không ủng hộ: " + tk;
      return false;
     }
   if(v_CheDo_XungDot == XD_KHONG_DOI_NGHICH)
     {
      if(laMua ? (soBan == 0) : (soMua == 0)) return true;
      lyDo = "Xung đột - có tín hiệu đối nghịch: " + tk;
      return false;
     }
   if(v_CheDo_XungDot == XD_DIEM_SO)
     {
      double chenh = (laMua ? diemMua - diemBan : diemBan - diemMua);
      double diem  = (laMua ? diemMua : diemBan);
      if(chenh > 0.0 && diem >= DiemToiThieu) return true;
      lyDo = "Xung đột - điểm không đủ: " + tk;
      return false;
     }
   return true;
  }

bool KiemTraTruocKhiVao(STinHieu &s, string &lyDo)
  {
   if(!HuongChoPhep(s.huong))              { lyDo = "Hướng giao dịch bị tắt trong Input"; return false; }
   if(!g_choPhepVaoLenh)                   { lyDo = "Risk Manager đang khóa: " + g_lyDoKhoa; return false; }
   if(!CheckSpread(lyDo))                  return false;
   if(!CheckTradingTime(lyDo))             return false;
   if(!CheckNews(lyDo))                    return false;
   if(g_laNetting && DemViTheTrenSymbol() > 0)
     {
      lyDo = "Tài khoản NETTING: đã có vị thế trên symbol";
      return false;
     }
   if(g_dem.tong >= g_maxTong)             { lyDo = StringFormat("Đã đạt tối đa tổng lệnh (%d)", g_maxTong); return false; }
   if(s.huong == DIR_BULL && g_dem.buy >= g_maxBuy)   { lyDo = StringFormat("Đã đạt tối đa lệnh BUY (%d)", g_maxBuy); return false; }
   if(s.huong == DIR_BEAR && g_dem.sell >= g_maxSell) { lyDo = StringFormat("Đã đạt tối đa lệnh SELL (%d)", g_maxSell); return false; }
   int maxPP = g_maxPP;
   if(s.pp == 4 && !PP4_ChoPhepNhieuLenh) maxPP = 1;
   //--- Tầng nhồi PP1 đã bị giới hạn bởi PP1_SoTangToiDa, không áp giới hạn mỗi PP
   if(!s.laNhoiLenh && g_dem.pp[s.pp] >= maxPP)
     {
      lyDo = StringFormat("Đã đạt tối đa lệnh của %s (%d)", g_ppTen[s.pp], maxPP);
      return false;
     }
   if(v_ChanLenhNguocChieu)
     {
      if(s.huong == DIR_BULL && g_dem.sell > 0) { lyDo = "Đang có lệnh SELL của EA (chặn ngược chiều)"; return false; }
      if(s.huong == DIR_BEAR && g_dem.buy > 0)  { lyDo = "Đang có lệnh BUY của EA (chặn ngược chiều)";  return false; }
     }
   if(CooldownSeconds > 0 && g_lastEntryTime[s.pp] > 0 &&
      (long)TimeCurrent() - (long)g_lastEntryTime[s.pp] < CooldownSeconds)
     {
      lyDo = StringFormat("Đang cooldown (%d giây)", CooldownSeconds);
      return false;
     }
   if(ChiVaoMotLenhMoiMoiNen && g_lastEntryBar[s.pp] == iTime(_Symbol, g_tf[s.pp], 0))
     {
      lyDo = "Đã vào lệnh trên nến hiện tại";
      return false;
     }
   return true;
  }

void XuLyDanhSachTinHieu()
  {
   int n = ArraySize(g_dsTinHieu);
   for(int i = 0; i < n; i++)
     {
      string lyDo = "";
      if(!ChapNhanTheoXungDot(g_dsTinHieu[i], lyDo))
        {
         LogTuChoi(g_dsTinHieu[i].pp, g_dsTinHieu[i].huong, lyDo);
         continue;
        }
      if(!KiemTraTruocKhiVao(g_dsTinHieu[i], lyDo))
        {
         LogTuChoi(g_dsTinHieu[i].pp, g_dsTinHieu[i].huong, lyDo);
         continue;
        }
      OpenTrade(g_dsTinHieu[i]);
     }
   ArrayResize(g_dsTinHieu, 0);
  }

//+------------------------------------------------------------------+
//| QUẢN LÝ LỆNH (BE / Trailing / Chốt một phần) - port từ EA QM     |
//+------------------------------------------------------------------+
bool CoTheSuaSL(const bool laMua, const double slMoi, const double slHT, const double tpHT, const MqlTick &tk)
  {
   double stopDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   double freeze   = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * g_point;
   if(laMua)
     {
      if(tk.bid - slMoi <= stopDist) return false;
      if(freeze > 0.0 && slHT > 0.0 && tk.bid - slHT <= freeze) return false;
      if(freeze > 0.0 && tpHT > 0.0 && tpHT - tk.bid <= freeze) return false;
     }
   else
     {
      if(slMoi - tk.ask <= stopDist) return false;
      if(freeze > 0.0 && slHT > 0.0 && slHT - tk.ask <= freeze) return false;
      if(freeze > 0.0 && tpHT > 0.0 && tk.ask - tpHT <= freeze) return false;
     }
   return true;
  }

void QuanLyMotLenh(const int idx)
  {
   ulong ticket = g_lenh[idx].ticket;
   int   pp     = g_lenh[idx].pp;
   if(!PositionSelectByTicket(ticket)) return;
   if(g_lenh[idx].lanSuaLoi > 0 && (long)TimeCurrent() - (long)g_lenh[idx].lanSuaLoi < 10) return;

   bool   laMua  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double giaVao = PositionGetDouble(POSITION_PRICE_OPEN);
   double slHT   = PositionGetDouble(POSITION_SL);
   double tpHT   = PositionGetDouble(POSITION_TP);
   double kl     = PositionGetDouble(POSITION_VOLUME);
   double rui    = (g_lenh[idx].rui > 0.0 ? g_lenh[idx].rui : MathAbs(giaVao - slHT));
   if(rui <= 0.0) return;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double profitR = (laMua ? (tk.bid - giaVao) / rui : (giaVao - tk.ask) / rui);

   //--- Chốt một phần
   if(QL_BatChotMotPhan && !g_lenh[idx].daChotMotPhan && profitR >= QL_ChotMotPhan_TaiR)
     {
      double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = 0.01;
      double klDong = NormalizeDouble(MathFloor((kl * QL_ChotMotPhan_PhanTram / 100.0) / step + 1e-9) * step, SoChuSoLot());
      if(klDong >= vmin - 1e-9 && (kl - klDong) >= vmin - 1e-9)
        {
         if(g_trade.PositionClosePartial(ticket, klDong))
            LogPP(pp, "Chốt một phần #" + IntegerToString((long)ticket) + " khối lượng " + D2(klDong) + " tại " + D2(profitR) + "R");
         else
            LogPP(pp, "LỖI chốt một phần #" + IntegerToString((long)ticket) + ": " + g_trade.ResultRetcodeDescription());
        }
      g_lenh[idx].daChotMotPhan = true;
      if(!PositionSelectByTicket(ticket)) return;
      slHT = PositionGetDouble(POSITION_SL);
      tpHT = PositionGetDouble(POSITION_TP);
     }

   //--- Dời SL hòa vốn
   if(v_QL_BatHoaVon && profitR >= QL_HoaVon_TaiR)
     {
      double slMoi = NormalizeGia(laMua ? giaVao + P2G(QL_HoaVon_KhoaPips) : giaVao - P2G(QL_HoaVon_KhoaPips));
      bool caiThien = (laMua ? (slHT < slMoi - g_point * 0.5) : (slHT == 0.0 || slHT > slMoi + g_point * 0.5));
      if(caiThien && CoTheSuaSL(laMua, slMoi, slHT, tpHT, tk))
        {
         if(g_trade.PositionModify(ticket, slMoi, tpHT))
           {
            LogChiTiet(pp, "Dời SL hòa vốn #" + IntegerToString((long)ticket) + " -> " + D(slMoi));
            slHT = slMoi;
           }
         else
           {
            g_lenh[idx].lanSuaLoi = TimeCurrent();
            LogPP(pp, "LỖI dời SL hòa vốn #" + IntegerToString((long)ticket) + ": " + g_trade.ResultRetcodeDescription());
            return;
           }
        }
     }

   //--- Trailing stop
   if(v_QL_KieuTrailing != TRAIL_TAT)
     {
      double slMoi = 0.0;
      if(v_QL_KieuTrailing == TRAIL_PIPS)
        {
         double loiPips = (laMua ? G2P(tk.bid - giaVao) : G2P(giaVao - tk.ask));
         if(loiPips >= QL_Trail_KhoaPips + QL_Trail_KhoangCachPips)
            slMoi = (laMua ? tk.bid - P2G(QL_Trail_KhoangCachPips) : tk.ask + P2G(QL_Trail_KhoangCachPips));
        }
      else if(v_QL_KieuTrailing == TRAIL_ATR && profitR >= QL_Trail_BatDauR)
        {
         double atr = LayGiaTriChiBao(g_hATRQL[pp], 0, 1);
         if(atr != EMPTY_VALUE && atr > 0.0)
            slMoi = (laMua ? tk.bid - QL_Trail_HeSoATR * atr : tk.ask + QL_Trail_HeSoATR * atr);
        }
      if(slMoi > 0.0)
        {
         slMoi = NormalizeGia(slMoi);
         double buoc = MathMax(P2G(QL_Trail_BuocPips), g_point);
         bool caiThien = (laMua ? (slMoi >= slHT + buoc) : (slHT == 0.0 || slMoi <= slHT - buoc));
         if(caiThien && CoTheSuaSL(laMua, slMoi, slHT, tpHT, tk))
           {
            if(!g_trade.PositionModify(ticket, slMoi, tpHT))
              {
               g_lenh[idx].lanSuaLoi = TimeCurrent();
               LogPP(pp, "LỖI trailing #" + IntegerToString((long)ticket) + ": " + g_trade.ResultRetcodeDescription());
              }
           }
        }
     }
  }

void ManagePositions()
  {
   for(int i = ArraySize(g_lenh) - 1; i >= 0; i--)
     {
      int pp = g_lenh[i].pp;
      bool apDung = (pp == 2 && QL_ApDung_PP2) || (pp == 3 && QL_ApDung_PP3) || (pp == 4 && QL_ApDung_PP4);
      if(apDung) QuanLyMotLenh(i);
     }
  }

//+------------------------------------------------------------------+
//| PP1 - RSI QUÁ MUA / QUÁ BÁN (+ nhồi lệnh tùy chọn)               |
//+------------------------------------------------------------------+
void CapNhatGioPP1(SGioPP1 &g, const double gia, const long tgMsc, const double kl)
  {
   if(g.soLenh == 0 || tgMsc < g.tgDau)
     {
      g.tgDau  = tgMsc;
      g.giaDau = gia;
      g.lotDau = kl;
     }
   if(g.soLenh == 0 || tgMsc >= g.tgCuoi)
     {
      g.tgCuoi  = tgMsc;
      g.giaCuoi = gia;
     }
   g.soLenh++;
  }

void ResetGioPP1(SGioPP1 &g)
  {
   g.soLenh = 0;
   g.giaDau = 0.0;
   g.giaCuoi = 0.0;
   g.lotDau = 0.0;
   g.tgDau = 0;
   g.tgCuoi = 0;
  }

//--- Trạng thái giỏ lệnh PP1 lấy trực tiếp từ vị thế thật (sửa lỗi đồng bộ của bản gốc)
void LayTrangThaiPP1(SGioPP1 &mua, SGioPP1 &ban)
  {
   ResetGioPP1(mua);
   ResetGioPP1(ban);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PPTuMagic(PositionGetInteger(POSITION_MAGIC)) != 1) continue;
      double gia = PositionGetDouble(POSITION_PRICE_OPEN);
      long   tg  = PositionGetInteger(POSITION_TIME_MSC);
      double kl  = PositionGetDouble(POSITION_VOLUME);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) CapNhatGioPP1(mua, gia, tg, kl);
      else CapNhatGioPP1(ban, gia, tg, kl);
     }
  }

void CheckStrategy1()
  {
   if(g_hRSI1 == INVALID_HANDLE) return;
   if(!IsNewBar(1)) return;

   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_hRSI1, 0, 0, 3, rsi) < 3)
     {
      LogChiTiet(1, "Chưa đọc được RSI (dữ liệu chưa sẵn sàng)");
      return;
     }
   double rsiNow  = rsi[1];   // nến đã đóng gần nhất
   double rsiPrev = rsi[2];

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;

   SGioPP1 mua, ban;
   LayTrangThaiPP1(mua, ban);

   //--- THOÁT GIỎ SELL (luôn chạy kể cả khi PP1 đang tắt, để không bỏ rơi lệnh)
   if(ban.soLenh > 0)
     {
      bool rsiExit   = (rsiNow <= PP1_RSI_DongBan);
      bool priceExit = (PP1_DongKhiGiaVeLenhDau && tk.ask <= ban.giaDau);
      bool stopExit  = (PP1_SL_Pips > 0.0 && tk.ask >= ban.giaDau + P2G(PP1_SL_Pips));
      if(rsiExit || priceExit || stopExit)
        {
         string lyDo = (rsiExit ? StringFormat("RSI %.2f <= %.1f", rsiNow, PP1_RSI_DongBan) :
                        (priceExit ? "Giá về giá lệnh SELL đầu tiên" : "Chạm SL cứng của giỏ SELL"));
         LogPP(1, "Đóng toàn bộ SELL (" + IntegerToString(ban.soLenh) + " lệnh). Lý do: " + lyDo);
         DongLenhTheoPP(1, POSITION_TYPE_SELL, lyDo);
         ResetGioPP1(ban);
        }
     }
   //--- THOÁT GIỎ BUY
   if(mua.soLenh > 0)
     {
      bool rsiExit   = (rsiNow >= PP1_RSI_DongMua);
      bool priceExit = (PP1_DongKhiGiaVeLenhDau && tk.bid >= mua.giaDau);
      bool stopExit  = (PP1_SL_Pips > 0.0 && tk.bid <= mua.giaDau - P2G(PP1_SL_Pips));
      if(rsiExit || priceExit || stopExit)
        {
         string lyDo = (rsiExit ? StringFormat("RSI %.2f >= %.1f", rsiNow, PP1_RSI_DongMua) :
                        (priceExit ? "Giá về giá lệnh BUY đầu tiên" : "Chạm SL cứng của giỏ BUY"));
         LogPP(1, "Đóng toàn bộ BUY (" + IntegerToString(mua.soLenh) + " lệnh). Lý do: " + lyDo);
         DongLenhTheoPP(1, POSITION_TYPE_BUY, lyDo);
         ResetGioPP1(mua);
        }
     }

   if(!g_ppBat[1]) return;

   //--- VÀO SELL: RSI cắt lên vùng quá mua
   if(ban.soLenh == 0 && rsiPrev < v_PP1_RSI_VaoBan && rsiNow >= v_PP1_RSI_VaoBan)
     {
      double sl = tk.bid + P2G(PP1_SL_Pips);
      double tp = (PP1_TP_Pips > 0.0 ? tk.bid - P2G(PP1_TP_Pips) : 0.0);
      ThemTinHieu(1, DIR_BEAR, sl, tp, 0.0, false, "",
                  StringFormat("RSI cắt lên %.1f (RSI=%.2f, nến trước=%.2f)", v_PP1_RSI_VaoBan, rsiNow, rsiPrev));
     }
   //--- NHỒI SELL (chỉ khi người dùng bật)
   else if(PP1_BatNhoiLenh && !g_laNetting && ban.soLenh > 0 && ban.soLenh < PP1_SoTangToiDa)
     {
      double giaTangMoi = ban.giaCuoi + P2G(PP1_BuocNhoi_Pips);
      if(tk.ask >= giaTangMoi)
        {
         double lot = ban.lotDau * MathPow(PP1_HeSoLot, ban.soLenh);
         ThemTinHieu(1, DIR_BEAR, ban.giaDau + P2G(PP1_SL_Pips), 0.0, lot, true, "L" + IntegerToString(ban.soLenh + 1),
                     StringFormat("Nhồi SELL tầng %d (giá đi ngược %.1f pips, RSI=%.2f)", ban.soLenh + 1, PP1_BuocNhoi_Pips, rsiNow));
        }
     }

   //--- VÀO BUY: RSI cắt xuống vùng quá bán
   if(mua.soLenh == 0 && rsiPrev > v_PP1_RSI_VaoMua && rsiNow <= v_PP1_RSI_VaoMua)
     {
      double sl = tk.ask - P2G(PP1_SL_Pips);
      double tp = (PP1_TP_Pips > 0.0 ? tk.ask + P2G(PP1_TP_Pips) : 0.0);
      ThemTinHieu(1, DIR_BULL, sl, tp, 0.0, false, "",
                  StringFormat("RSI cắt xuống %.1f (RSI=%.2f, nến trước=%.2f)", v_PP1_RSI_VaoMua, rsiNow, rsiPrev));
     }
   //--- NHỒI BUY
   else if(PP1_BatNhoiLenh && !g_laNetting && mua.soLenh > 0 && mua.soLenh < PP1_SoTangToiDa)
     {
      double giaTangMoi = mua.giaCuoi - P2G(PP1_BuocNhoi_Pips);
      if(tk.bid <= giaTangMoi)
        {
         double lot = mua.lotDau * MathPow(PP1_HeSoLot, mua.soLenh);
         ThemTinHieu(1, DIR_BULL, mua.giaDau - P2G(PP1_SL_Pips), 0.0, lot, true, "L" + IntegerToString(mua.soLenh + 1),
                     StringFormat("Nhồi BUY tầng %d (giá đi ngược %.1f pips, RSI=%.2f)", mua.soLenh + 1, PP1_BuocNhoi_Pips, rsiNow));
        }
     }
  }

//+------------------------------------------------------------------+
//| PP2 - SMC: động cơ cấu trúc (port từ SmartMoneyConcepts V5)      |
//+------------------------------------------------------------------+
void PP2_ResetPivot(SPivotSMC &p)
  {
   p.level     = EMPTY_VALUE;
   p.lastLevel = EMPTY_VALUE;
   p.crossed   = false;
   p.barTime   = 0;
   p.barIndex  = -1;
  }

void PP2_Reset()
  {
   PP2_ResetPivot(g2_swH);
   PP2_ResetPivot(g2_swL);
   PP2_ResetPivot(g2_inH);
   PP2_ResetPivot(g2_inL);
   g2_swTr = 0;
   g2_inTr = 0;
   ArrayResize(g2_swOB, 0);
   ArrayResize(g2_inOB, 0);
   ArrayResize(g2_hi, 0);
   ArrayResize(g2_lo, 0);
   ArrayResize(g2_pH, 0);
   ArrayResize(g2_pL, 0);
   ArrayResize(g2_t, 0);
   g2_n = 0;
   g2_lastTime = 0;
  }

void PP2_GanPivot(SPivotSMC &p, const double level, const int idx)
  {
   p.lastLevel = p.level;
   p.level     = level;
   p.crossed   = false;
   p.barTime   = g2_t[idx];
   p.barIndex  = idx;
  }

//--- Pivot đối xứng trái/phải như bản gốc (UpdatePivots)
void PP2_CapNhatPivot(const int size, const bool internal, const int barIdx)
  {
   int pivIdx = barIdx - size;
   if(pivIdx < size) return;
   if(pivIdx + size >= g2_n) return;
   double pivH = g2_hi[pivIdx];
   double pivL = g2_lo[pivIdx];
   bool isH = true, isL = true;
   for(int i = pivIdx - size; i < pivIdx; i++)
     {
      if(g2_hi[i] >= pivH) isH = false;
      if(g2_lo[i] <= pivL) isL = false;
     }
   for(int i = pivIdx + 1; i <= pivIdx + size; i++)
     {
      if(g2_hi[i] >= pivH) isH = false;
      if(g2_lo[i] <= pivL) isL = false;
     }
   if(!isH && !isL) return;
   if(internal)
     {
      if(isL) PP2_GanPivot(g2_inL, pivL, pivIdx);
      if(isH) PP2_GanPivot(g2_inH, pivH, pivIdx);
     }
   else
     {
      if(isL) PP2_GanPivot(g2_swL, pivL, pivIdx);
      if(isH) PP2_GanPivot(g2_swH, pivH, pivIdx);
     }
  }

void PP2_ChenOB(SOBSMC &arr[], SOBSMC &ob)
  {
   int sz = ArraySize(arr);
   if(sz >= 100) sz = 99;   // bỏ OB cũ nhất (cuối mảng) như bản gốc
   ArrayResize(arr, sz + 1);
   for(int i = sz; i > 0; i--) arr[i] = arr[i - 1];
   arr[0] = ob;
  }

void PP2_XoaOB(SOBSMC &arr[], const int idx)
  {
   int sz = ArraySize(arr);
   for(int i = idx; i < sz - 1; i++) arr[i] = arr[i + 1];
   ArrayResize(arr, sz - 1);
  }

//--- Lưu Order Block (StoreOB): tìm nến cực trị giữa pivot và nến phá cấu trúc
void PP2_LuuOB(SPivotSMC &p, const bool internal, const int bias, const int bosIdx)
  {
   int si = p.barIndex, ei = bosIdx;
   if(si < 0 || si >= ei) return;
   int    best_i = si;
   double best   = (bias == DIR_BEAR ? -DBL_MAX : DBL_MAX);
   for(int i = si; i < ei && i < g2_n; i++)
     {
      if(bias == DIR_BEAR && g2_pH[i] > best) { best = g2_pH[i]; best_i = i; }
      if(bias == DIR_BULL && g2_pL[i] < best) { best = g2_pL[i]; best_i = i; }
     }
   SOBSMC ob;
   ob.hi          = g2_hi[best_i];
   ob.lo          = g2_lo[best_i];
   ob.barTime     = g2_t[best_i];
   ob.confirmTime = g2_t[bosIdx];
   ob.bias        = bias;
   ob.daGiaoDich  = false;
   if(internal) PP2_ChenOB(g2_inOB, ob);
   else PP2_ChenOB(g2_swOB, ob);
  }

//--- Phát hiện BOS/CHoCH (ProcessStruct)
void PP2_XuLyCauTruc(const bool internal, const double c, const int barIdx)
  {
   SPivotSMC pH, pL;
   int tr;
   if(internal) { pH = g2_inH; pL = g2_inL; tr = g2_inTr; }
   else         { pH = g2_swH; pL = g2_swL; tr = g2_swTr; }
   int trCu = tr;

   if(pH.level != EMPTY_VALUE && !pH.crossed)
     {
      bool ex = (internal ? (g2_inH.level != g2_swH.level) : true);
      if(c > pH.level && ex)
        {
         pH.crossed = true;
         tr = DIR_BULL;
         PP2_LuuOB(pH, internal, DIR_BULL, barIdx);
        }
     }
   if(pL.level != EMPTY_VALUE && !pL.crossed)
     {
      bool ex = (internal ? (g2_inL.level != g2_swL.level) : true);
      if(c < pL.level && ex)
        {
         pL.crossed = true;
         tr = DIR_BEAR;
         PP2_LuuOB(pL, internal, DIR_BEAR, barIdx);
        }
     }

   if(internal) { g2_inH = pH; g2_inL = pL; g2_inTr = tr; }
   else
     {
      g2_swH = pH; g2_swL = pL; g2_swTr = tr;
      if(!g2_dangNapLichSu && tr != trCu && trCu != 0)
         LogChiTiet(2, "CHoCH swing -> xu hướng " + (tr == DIR_BULL ? "TĂNG" : "GIẢM"));
     }
  }

void PP2_GiamThieuOB(SOBSMC &arr[], const double c, const double h, const double l)
  {
   double bearSrc = (PP2_GiamThieuTheoClose ? c : h);
   double bullSrc = (PP2_GiamThieuTheoClose ? c : l);
   for(int i = ArraySize(arr) - 1; i >= 0; i--)
     {
      bool mit = (arr[i].bias == DIR_BEAR && bearSrc > arr[i].hi) || (arr[i].bias == DIR_BULL && bullSrc < arr[i].lo);
      if(mit) PP2_XoaOB(arr, i);
     }
  }

//--- Xử lý 1 nến ĐÃ ĐÓNG (không xử lý nến đang chạy -> không repaint)
void PP2_XuLyNen(MqlRates &r, const double atr)
  {
   int i = g2_n;
   ArrayResize(g2_hi, i + 1, 5000);
   ArrayResize(g2_lo, i + 1, 5000);
   ArrayResize(g2_pH, i + 1, 5000);
   ArrayResize(g2_pL, i + 1, 5000);
   ArrayResize(g2_t,  i + 1, 5000);
   bool hv = (atr > 0.0 && (r.high - r.low) >= 2.0 * atr);   // nến biến động cao: đảo high/low như bản gốc
   g2_hi[i] = r.high;
   g2_lo[i] = r.low;
   g2_pH[i] = (hv ? r.low : r.high);
   g2_pL[i] = (hv ? r.high : r.low);
   g2_t[i]  = r.time;
   g2_n = i + 1;

   PP2_CapNhatPivot(v_PP2_DoDaiSwing, false, i);
   PP2_CapNhatPivot(PP2_DoDaiNoiBo, true, i);
   PP2_XuLyCauTruc(true, r.close, i);
   PP2_XuLyCauTruc(false, r.close, i);
   PP2_GiamThieuOB(g2_inOB, r.close, r.high, r.low);
   PP2_GiamThieuOB(g2_swOB, r.close, r.high, r.low);
   g2_barCuoi = r;
  }

bool PP2_KhoiTao()
  {
   if(g2_hATR200 == INVALID_HANDLE) return false;
   if(BarsCalculated(g2_hATR200) <= 0) return false;
   int tong = Bars(_Symbol, g_tf[2]);
   int can  = MathMin(PP2_SoNenNapLichSu, tong - 2);
   if(can < v_PP2_DoDaiSwing * 2 + 10)
     {
      if(!g2_daBaoThieuNen)
        {
         LogPP(2, "Chưa đủ dữ liệu lịch sử để dựng cấu trúc SMC (cần > " + IntegerToString(v_PP2_DoDaiSwing * 2 + 10) + " nến)");
         g2_daBaoThieuNen = true;
        }
      return false;
     }
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, g_tf[2], 1, can, r);
   if(got < v_PP2_DoDaiSwing * 2 + 10) return false;
   double atr[];
   ArraySetAsSeries(atr, false);
   int gotA = CopyBuffer(g2_hATR200, 0, 1, got, atr);
   if(gotA < 0) gotA = 0;

   PP2_Reset();
   g2_dangNapLichSu = true;
   for(int i = 0; i < got; i++)
     {
      int    ai = i - (got - gotA);
      double a  = ((gotA > 0 && ai >= 0 && ai < gotA) ? atr[ai] : 0.0);
      PP2_XuLyNen(r[i], a);
     }
   g2_dangNapLichSu = false;
   g2_lastTime  = r[got - 1].time;
   g2_daKhoiTao = true;
   LogPP(2, StringFormat("Khởi tạo cấu trúc SMC xong: %d nến %s | swing trend=%s | OB swing=%d | OB nội bộ=%d",
                         got, TfStr(g_tf[2]), (g2_swTr == DIR_BULL ? "TĂNG" : (g2_swTr == DIR_BEAR ? "GIẢM" : "chưa rõ")),
                         ArraySize(g2_swOB), ArraySize(g2_inOB)));
   return true;
  }

int PP2_CapNhatNenMoi()
  {
   int shiftCu = iBarShift(_Symbol, g_tf[2], g2_lastTime, false);
   if(shiftCu < 0) return 0;
   int soMoi = shiftCu - 1;
   if(soMoi <= 0) return 0;
   if(soMoi > 500) soMoi = 500;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, g_tf[2], 1, soMoi, r);
   if(got <= 0) return 0;
   double atr[];
   ArraySetAsSeries(atr, false);
   int gotA = CopyBuffer(g2_hATR200, 0, 1, got, atr);
   if(gotA < 0) gotA = 0;
   int dem = 0;
   for(int i = 0; i < got; i++)
     {
      if(r[i].time <= g2_lastTime) continue;
      int    ai = i - (got - gotA);
      double a  = ((gotA > 0 && ai >= 0 && ai < gotA) ? atr[ai] : 0.0);
      PP2_XuLyNen(r[i], a);
      g2_lastTime = r[i].time;
      dem++;
     }
   return dem;
  }

//--- Bias khung lớn (port phần Swing của CalcHTFBias; chỉ dùng nến đã đóng)
int PP2_TinhBiasHTF()
  {
   datetime t = iTime(_Symbol, v_PP2_HTF, 0);
   if(t == 0 || t == g2_htfLastCalc) return g2_htfBias;
   int pl    = v_PP2_DoDaiSwing;
   int need  = MathMax(pl, 5) * 4 + 10;
   int avail = Bars(_Symbol, v_PP2_HTF) - 1;
   if(avail < need) need = avail;
   if(need < pl * 2 + 2) return g2_htfBias;
   double h[], l[], c[];
   ArraySetAsSeries(h, false);
   ArraySetAsSeries(l, false);
   ArraySetAsSeries(c, false);
   if(CopyHigh(_Symbol, v_PP2_HTF, 1, need, h) < need) return g2_htfBias;
   if(CopyLow(_Symbol, v_PP2_HTF, 1, need, l) < need) return g2_htfBias;
   if(CopyClose(_Symbol, v_PP2_HTF, 1, need, c) < need) return g2_htfBias;
   int    swBias = 0;
   double swPivH = 0.0, swPivL = 0.0;
   bool   hCross = false, lCross = false;
   for(int i = pl; i < need - pl; i++)
     {
      bool isH = true;
      for(int j = 1; j <= pl && isH; j++)
         if(h[i - j] >= h[i] || h[i + j] >= h[i]) isH = false;
      if(isH) { swPivH = h[i]; hCross = false; }
      bool isL = true;
      for(int j = 1; j <= pl && isL; j++)
         if(l[i - j] <= l[i] || l[i + j] <= l[i]) isL = false;
      if(isL) { swPivL = l[i]; lCross = false; }
      if(swPivH > 0.0 && c[i] > swPivH && !hCross) { hCross = true; swBias = DIR_BULL; }
      if(swPivL > 0.0 && c[i] < swPivL && !lCross) { lCross = true; swBias = DIR_BEAR; }
     }
   g2_htfBias     = swBias;
   g2_htfLastCalc = t;
   return g2_htfBias;
  }

//--- Tìm OB vừa bị chạm (retest) trên nến đã đóng gần nhất
int PP2_TimOBCham(SOBSMC &arr[], const int bias, MqlRates &r)
  {
   int lim = MathMin(ArraySize(arr), v_PP2_SoOBXemXet);
   for(int i = 0; i < lim; i++)
     {
      if(arr[i].bias != bias || arr[i].daGiaoDich) continue;
      if(arr[i].confirmTime >= r.time) continue;   // không vào trên chính nến tạo OB
      if(bias == DIR_BULL)
        {
         if(r.low <= arr[i].hi && (!v_PP2_YeuCauNenXacNhan || r.close > r.open)) return i;
        }
      else
        {
         if(r.high >= arr[i].lo && (!v_PP2_YeuCauNenXacNhan || r.close < r.open)) return i;
        }
     }
   return -1;
  }

void PP2_DanhGiaTinHieu()
  {
   MqlRates r = g2_barCuoi;
   bool choMua = true, choBan = true;
   if(v_PP2_TheoTrendSwing)
     {
      choMua = (g2_swTr == DIR_BULL);
      choBan = (g2_swTr == DIR_BEAR);
     }
   int htf = 0;
   if(v_PP2_LocHTF)
     {
      htf = PP2_TinhBiasHTF();
      if(htf != DIR_BULL) choMua = false;
      if(htf != DIR_BEAR) choBan = false;
     }
   bool   coEq = (g2_swH.level != EMPTY_VALUE && g2_swL.level != EMPTY_VALUE && g2_swH.level > g2_swL.level);
   double eq   = (coEq ? (g2_swH.level + g2_swL.level) / 2.0 : 0.0);
   if(v_PP2_LocPremiumDiscount)
     {
      if(!coEq) { choMua = false; choBan = false; }
      else
        {
         if(r.close > eq) choMua = false;   // BUY chỉ ở vùng Discount
         if(r.close < eq) choBan = false;   // SELL chỉ ở vùng Premium
        }
     }
   if(!choMua && !choBan) return;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   string trendStr = (g2_swTr == DIR_BULL ? "TĂNG" : (g2_swTr == DIR_BEAR ? "GIẢM" : "chưa rõ"));
   string htfStr   = (v_PP2_LocHTF ? (" | HTF " + TfStr(v_PP2_HTF) + "=" + (htf == DIR_BULL ? "TĂNG" : (htf == DIR_BEAR ? "GIẢM" : "chưa rõ"))) : "");

   for(int lan = 0; lan < 2; lan++)
     {
      int bias = (lan == 0 ? DIR_BULL : DIR_BEAR);
      if(bias == DIR_BULL && !choMua) continue;
      if(bias == DIR_BEAR && !choBan) continue;
      int idx = -1;
      bool laSwing = false;
      if(v_PP2_LoaiOB != OB_NOI_BO)
        {
         idx = PP2_TimOBCham(g2_swOB, bias, r);
         if(idx >= 0) laSwing = true;
        }
      if(idx < 0 && v_PP2_LoaiOB != OB_SWING) idx = PP2_TimOBCham(g2_inOB, bias, r);
      if(idx < 0) continue;

      double obHi, obLo;
      if(laSwing) { obHi = g2_swOB[idx].hi; obLo = g2_swOB[idx].lo; g2_swOB[idx].daGiaoDich = true; }
      else        { obHi = g2_inOB[idx].hi; obLo = g2_inOB[idx].lo; g2_inOB[idx].daGiaoDich = true; }

      double minSL = P2G(PP2_SL_ToiThieuPips);
      double entry, sl, tp;
      if(bias == DIR_BULL)
        {
         entry = tk.ask;
         sl = obLo - P2G(PP2_SL_DemPips);
         if(entry - sl < minSL) sl = entry - minSL;
         tp = entry + v_PP2_RR * (entry - sl);
        }
      else
        {
         entry = tk.bid;
         sl = obHi + P2G(PP2_SL_DemPips);
         if(sl - entry < minSL) sl = entry + minSL;
         tp = entry - v_PP2_RR * (sl - entry);
        }
      ThemTinHieu(2, bias, sl, tp, 0.0, false, (laSwing ? "SW" : "IN"),
                  StringFormat("Retest OB %s %s [%s - %s] | swing trend=%s%s",
                               (laSwing ? "swing" : "nội bộ"), (bias == DIR_BULL ? "tăng" : "giảm"),
                               D(obLo), D(obHi), trendStr, htfStr));
      return;   // tối đa 1 tín hiệu mỗi nến
     }
  }

void CheckStrategy2()
  {
   if(!g_ppBat[2]) return;
   if(!g2_daKhoiTao)
     {
      if(!PP2_KhoiTao()) return;
     }
   if(!IsNewBar(2)) return;
   if(PP2_CapNhatNenMoi() <= 0) return;
   PP2_DanhGiaTinHieu();
  }

//+------------------------------------------------------------------+
//| PP3 - FIBONACCI PIVOT NGÀY                                       |
//+------------------------------------------------------------------+
void PP3_VeDuong()
  {
   if(!PP3_VeDuongPivot || !g_veDuoc) return;
   for(int k = 0; k < 7; k++)
     {
      string nm = OBJ_PREFIX + "PV_" + g3_tenMuc[k];
      color  cl = (k < 3 ? clrRed : (k == 3 ? clrDarkOrchid : clrMediumSeaGreen));
      if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_HLINE, 0, 0, g3_muc[k]);
      ObjectSetDouble(0, nm, OBJPROP_PRICE, g3_muc[k]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, cl);
      ObjectSetInteger(0, nm, OBJPROP_STYLE, (k == 3 ? STYLE_DASH : STYLE_SOLID));
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, ((k == 1 || k == 5) ? 2 : 1));
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, nm, OBJPROP_TOOLTIP, "Fibo Pivot " + g3_tenMuc[k] + " = " + D(g3_muc[k]));
     }
  }

//--- Tính pivot từ nến D1 hôm trước (thứ Hai dùng nến thứ Sáu nếu sàn có nến Chủ nhật)
bool PP3_TinhPivot()
  {
   datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if(d0 == 0) return false;
   if(g3_hopLe && d0 == g3_ngayD1) return true;
   MqlRates d[];
   ArraySetAsSeries(d, true);
   int got = CopyRates(_Symbol, PERIOD_D1, 0, 6, d);
   if(got < 2) return false;
   int idx = 1;
   MqlDateTime tm;
   TimeToStruct(d[0].time, tm);
   if(tm.day_of_week == MONDAY)
     {
      MqlDateTime tm1;
      TimeToStruct(d[1].time, tm1);
      if(tm1.day_of_week != FRIDAY)
        {
         for(int k = 1; k < got; k++)
           {
            MqlDateTime tk2;
            TimeToStruct(d[k].time, tk2);
            if(tk2.day_of_week == FRIDAY) { idx = k; break; }
           }
        }
     }
   double H = d[idx].high, L = d[idx].low, C = d[idx].close;
   double R = H - L;
   double P = (H + L + C) / 3.0;
   g3_muc[0] = P - R * 1.000;   // S3
   g3_muc[1] = P - R * 0.618;   // S2
   g3_muc[2] = P - R * 0.382;   // S1
   g3_muc[3] = P;               // P
   g3_muc[4] = P + R * 0.382;   // R1
   g3_muc[5] = P + R * 0.618;   // R2
   g3_muc[6] = P + R * 1.000;   // R3
   if(d0 != g3_ngayD1) g3_daGiaoDich = 0;
   g3_ngayD1 = d0;
   g3_hopLe  = (R > 0.0);
   LogChiTiet(3, StringFormat("Pivot ngày %s (từ nến %s): S3=%s S2=%s S1=%s P=%s R1=%s R2=%s R3=%s",
                              TimeToString(d0, TIME_DATE), TimeToString(d[idx].time, TIME_DATE),
                              D(g3_muc[0]), D(g3_muc[1]), D(g3_muc[2]), D(g3_muc[3]), D(g3_muc[4]), D(g3_muc[5]), D(g3_muc[6])));
   PP3_VeDuong();
   return g3_hopLe;
  }

double PP3_TimTP(const int huong, const double entry, const double rui)
  {
   if(v_PP3_KieuTP == TP_THEO_CAU_TRUC)
     {
      double minD = KhoangCachDungToiThieu() + P2G(1.0);
      if(huong == DIR_BULL)
        {
         for(int k = 0; k < 7; k++)
            if(g3_muc[k] > entry + minD) return g3_muc[k];
        }
      else
        {
         for(int k = 6; k >= 0; k--)
            if(g3_muc[k] < entry - minD) return g3_muc[k];
        }
     }
   //--- TP theo R:R (hoặc dự phòng khi không còn mức pivot phía trước)
   return (huong == DIR_BULL ? entry + PP3_RR * rui : entry - PP3_RR * rui);
  }

void PP3_TaoLenh(const int huong, const double mucGia, const string tenMuc, const int bit, MqlRates &r1)
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double minSL = P2G(PP3_SL_ToiThieuPips);
   double entry, sl;
   if(huong == DIR_BULL)
     {
      entry = tk.ask;
      sl = (v_PP3_CheDo == PP3_BAT_LAI ? MathMin(r1.low, mucGia) : mucGia) - P2G(PP3_SL_DemPips);
      if(entry - sl < minSL) sl = entry - minSL;
     }
   else
     {
      entry = tk.bid;
      sl = (v_PP3_CheDo == PP3_BAT_LAI ? MathMax(r1.high, mucGia) : mucGia) + P2G(PP3_SL_DemPips);
      if(sl - entry < minSL) sl = entry + minSL;
     }
   double rui = MathAbs(entry - sl);
   double tp  = PP3_TimTP(huong, entry, rui);
   double rr  = (rui > 0.0 ? MathAbs(tp - entry) / rui : 0.0);
   g3_daGiaoDich |= (1 << bit);   // mỗi mức chỉ xét 1 lần/ngày/chiều
   if(rr < PP3_RR_ToiThieu)
     {
      LogTuChoi(3, huong, StringFormat("R:R %.2f < tối thiểu %.2f tại %s", rr, PP3_RR_ToiThieu, tenMuc));
      return;
     }
   string cheDo = (v_PP3_CheDo == PP3_BAT_LAI ? "Bật lại tại " : "Phá vỡ ");
   ThemTinHieu(3, huong, sl, tp, 0.0, false, tenMuc,
               StringFormat("%s%s=%s | nến: O=%s H=%s L=%s C=%s | R:R=%.2f", cheDo, tenMuc, D(mucGia),
                            D(r1.open), D(r1.high), D(r1.low), D(r1.close), rr));
  }

void CheckStrategy3()
  {
   if(!g_ppBat[3]) return;
   if(!IsNewBar(3)) return;
   if(!PP3_TinhPivot()) return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, g_tf[3], 1, 2, r) < 2) return;
   //--- r[0] = nến đã đóng gần nhất, r[1] = nến trước đó
   if(r[0].time < g3_ngayD1) return;   // nến thuộc ngày cũ -> pivot không áp dụng
   int soMuc = MathMax(1, MathMin(3, PP3_SoMucSR));

   if(v_PP3_CheDo == PP3_BAT_LAI)
     {
      int kMua = -1, kBan = -1;
      for(int k = soMuc - 1; k >= 0; k--)   // mức sâu nhất bị chạm mà nến đóng cửa quay lại
        {
         double L = g3_muc[2 - k];        // S1=muc[2], S2=muc[1], S3=muc[0]
         if(r[0].low <= L && r[0].close > L && (!PP3_YeuCauNenXacNhan || r[0].close > r[0].open)) { kMua = k; break; }
        }
      for(int k = soMuc - 1; k >= 0; k--)
        {
         double L = g3_muc[4 + k];        // R1=muc[4], R2=muc[5], R3=muc[6]
         if(r[0].high >= L && r[0].close < L && (!PP3_YeuCauNenXacNhan || r[0].close < r[0].open)) { kBan = k; break; }
        }
      if(kMua >= 0 && kBan >= 0)
        {
         LogChiTiet(3, "Nến chạm cả vùng hỗ trợ và kháng cự -> bỏ qua");
         return;
        }
      if(kMua >= 0 && (g3_daGiaoDich & (1 << kMua)) == 0)
         PP3_TaoLenh(DIR_BULL, g3_muc[2 - kMua], g3_tenMuc[2 - kMua], kMua, r[0]);
      if(kBan >= 0 && (g3_daGiaoDich & (1 << (3 + kBan))) == 0)
         PP3_TaoLenh(DIR_BEAR, g3_muc[4 + kBan], g3_tenMuc[4 + kBan], 3 + kBan, r[0]);
     }
   else
     {
      //--- Phá vỡ: BUY khi đóng cửa vượt lên P/R1/R2..., SELL khi đóng cửa thủng P/S1/S2...
      int jMua = -1, jBan = -1;
      for(int j = soMuc; j >= 0; j--)
        {
         double L = g3_muc[3 + j];
         if(r[1].close <= L && r[0].close > L) { jMua = j; break; }
        }
      for(int j = soMuc; j >= 0; j--)
        {
         double L = g3_muc[3 - j];
         if(r[1].close >= L && r[0].close < L) { jBan = j; break; }
        }
      if(jMua >= 0 && (g3_daGiaoDich & (1 << (6 + jMua))) == 0)
         PP3_TaoLenh(DIR_BULL, g3_muc[3 + jMua], g3_tenMuc[3 + jMua], 6 + jMua, r[0]);
      if(jBan >= 0 && (g3_daGiaoDich & (1 << (10 + jBan))) == 0)
         PP3_TaoLenh(DIR_BEAR, g3_muc[3 - jBan], g3_tenMuc[3 - jBan], 10 + jBan, r[0]);
     }
  }

//+------------------------------------------------------------------+
//| PP4 - QUASIMODO (port từ Quasimodo_fQMl_Pattern_EA)              |
//+------------------------------------------------------------------+
void PP4_Log(const string msg)
  {
   if(!g4_replay) LogChiTiet(4, msg);
  }

void PP4_AddPivotToZigZag(const bool isHigh, const double price, const datetime time)
  {
   int count = ArraySize(g4_pivots);
   if(count == 0)
     {
      ArrayResize(g4_pivots, 1);
      g4_pivots[0].isHigh = isHigh;
      g4_pivots[0].price  = price;
      g4_pivots[0].time   = time;
      return;
     }
   //--- Cùng loại với pivot trước: giữ pivot cực trị hơn
   if(g4_pivots[count - 1].isHigh == isHigh)
     {
      bool moreExtreme = (isHigh ? (price > g4_pivots[count - 1].price) : (price < g4_pivots[count - 1].price));
      if(moreExtreme)
        {
         g4_pivots[count - 1].price = price;
         g4_pivots[count - 1].time  = time;
        }
      return;
     }
   ArrayResize(g4_pivots, count + 1);
   g4_pivots[count].isHigh = isHigh;
   g4_pivots[count].price  = price;
   g4_pivots[count].time   = time;
   if(ArraySize(g4_pivots) > g4_maxPivots)
     {
      int drop = ArraySize(g4_pivots) - g4_maxPivots;
      for(int i = 0; i < ArraySize(g4_pivots) - drop; i++) g4_pivots[i] = g4_pivots[i + drop];
      ArrayResize(g4_pivots, g4_maxPivots);
     }
  }

bool PP4_IsPriorTrendConfirmed(const bool isBull, const int shoulderIndex)
  {
   if(!PP4_YeuCauTrendTruoc) return true;
   if(PP4_SoPivotTrend < 2) return true;
   int oldestIndex = shoulderIndex - PP4_SoPivotTrend;
   if(oldestIndex < 0) return false;
   for(int i = oldestIndex; i + 2 <= shoulderIndex; i++)
     {
      double earlier = g4_pivots[i].price;
      double later   = g4_pivots[i + 2].price;
      if(!isBull) { if(!(later > earlier)) return false; }   // QM giảm cần xu hướng tăng trước đó
      else        { if(!(later < earlier)) return false; }   // QM tăng cần xu hướng giảm trước đó
     }
   return true;
  }

void PP4_CancelArmedSetup(const string reason)
  {
   if(!g4_setup.isActive) return;
   g4_setup.isActive = false;
   PP4_Log("QM " + (g4_setup.isBull ? "tăng" : "giảm") + " bị hủy: " + reason);
  }

double PP4_FindSwingCandleClose(const datetime pivotTime, const bool wantBearish, const int maxLookBars)
  {
   int shift = iBarShift(_Symbol, g_tf[4], pivotTime);
   if(shift < 0) return 0.0;
   for(int i = 0; i <= maxLookBars; i++)
     {
      int    s = shift + i;
      double o = iOpen(_Symbol, g_tf[4], s);
      double c = iClose(_Symbol, g_tf[4], s);
      if(wantBearish && c < o) return c;
      if(!wantBearish && c > o) return c;
     }
   return 0.0;
  }

void PP4_ArmSetup(const bool isBull, const SPivotQM &shoulder, const SPivotQM &leg, const SPivotQM &head,
                  const SPivotQM &bos, const int shoulderIndex)
  {
   //--- Quy tắc 1 lệnh/lần như bản gốc
   if(!PP4_ChoPhepNhieuLenh && g_dem.pp[4] > 0) return;
   g4_setup.isActive      = true;
   g4_setup.isBull        = isBull;
   g4_setup.qmLinePrice   = shoulder.price;
   g4_setup.shoulderPrice = shoulder.price;
   g4_setup.headPrice     = head.price;
   g4_setup.targetPrice   = bos.price;
   g4_setup.legPrice      = leg.price;
   g4_setup.shoulderTime  = shoulder.time;
   g4_setup.legTime       = leg.time;
   g4_setup.headTime      = head.time;
   g4_setup.bosTime       = bos.time;
   g4_setup.armedTime     = iTime(_Symbol, g_tf[4], 0);
   g4_setup.lineBroken    = false;
   g4_setup.entry2Price   = (PP4_DungEntry2 ? PP4_FindSwingCandleClose(head.time, isBull, PP4_SwingLookback + 2) : 0.0);
   g4_setup.entry2Valid   = (g4_setup.entry2Price > 0.0);
   g4_setup.entry2Broken  = false;
   g4_lastArmedBosTime      = bos.time;
   g4_lastArmedShoulderTime = shoulder.time;
   PP4_Log("QM " + (isBull ? "TĂNG" : "GIẢM") + " đã kích hoạt | QM line=" + D(g4_setup.qmLinePrice) +
           " Head=" + D(g4_setup.headPrice) + " Target=" + D(g4_setup.targetPrice) +
           (g4_setup.entry2Valid ? (" Entry2=" + D(g4_setup.entry2Price)) : "") + " -> chờ giá hồi về QM line");
  }

void PP4_CheckForQMPattern()
  {
   int count = ArraySize(g4_pivots);
   if(count < 4) return;
   SPivotQM shoulder = g4_pivots[count - 4];
   SPivotQM leg      = g4_pivots[count - 3];
   SPivotQM head     = g4_pivots[count - 2];
   SPivotQM bos      = g4_pivots[count - 1];
   //--- QM giảm: H, L, H, L
   if(shoulder.isHigh && !leg.isHigh && head.isHigh && !bos.isHigh)
     {
      if(head.price > shoulder.price && leg.price < shoulder.price && bos.price < leg.price)
        {
         if(bos.time != g4_lastArmedBosTime && HuongChoPhep(DIR_BEAR) &&
            (!PP4_BoQuaVaiChung || shoulder.time != g4_lastArmedShoulderTime) &&
            PP4_IsPriorTrendConfirmed(false, count - 4))
            PP4_ArmSetup(false, shoulder, leg, head, bos, count - 4);
        }
      return;
     }
   //--- QM tăng: L, H, L, H
   if(!shoulder.isHigh && leg.isHigh && !head.isHigh && bos.isHigh)
     {
      if(head.price < shoulder.price && leg.price > shoulder.price && bos.price > leg.price)
        {
         if(bos.time != g4_lastArmedBosTime && HuongChoPhep(DIR_BULL) &&
            (!PP4_BoQuaVaiChung || shoulder.time != g4_lastArmedShoulderTime) &&
            PP4_IsPriorTrendConfirmed(true, count - 4))
            PP4_ArmSetup(true, shoulder, leg, head, bos, count - 4);
        }
     }
  }

//--- Tính SL/TP như OpenTrade của bản gốc, rồi đưa thành tín hiệu cho EA MASTER
void PP4_TaoTinHieu(const bool isBull, const string entryTag)
  {
   if(!PP4_ChoPhepNhieuLenh && g_dem.pp[4] > 0) return;
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double stopBuffer = P2G(PP4_SL_DemPips);
   double atr = (PP4_DungSanATR ? LayGiaTriChiBao(g_hATRQL[4], 0, 1) : 0.0);
   if(atr == EMPTY_VALUE) atr = 0.0;
   double entry, stop, takeProfit;
   if(isBull)
     {
      entry = tk.ask;
      double structStop = g4_setup.headPrice - stopBuffer;
      double atrStop    = (atr > 0.0 ? entry - PP4_ATR_HeSoSL * atr : structStop);
      stop = MathMin(structStop, atrStop);   // lấy SL xa hơn
     }
   else
     {
      entry = tk.bid;
      double structStop = g4_setup.headPrice + stopBuffer;
      double atrStop    = (atr > 0.0 ? entry + PP4_ATR_HeSoSL * atr : structStop);
      stop = MathMax(structStop, atrStop);
     }
   double riskDistance = (isBull ? entry - stop : stop - entry);
   if(riskDistance <= 0.0)
     {
      PP4_CancelArmedSetup("khoảng cách rủi ro không hợp lệ");
      return;
     }
   if(v_PP4_KieuTP == TP_THEO_RR)
      takeProfit = (isBull ? entry + v_PP4_RR * riskDistance : entry - v_PP4_RR * riskDistance);
   else
      takeProfit = g4_setup.targetPrice;
   double rewardDistance = (isBull ? takeProfit - entry : entry - takeProfit);
   if(rewardDistance <= 0.0)
     {
      PP4_CancelArmedSetup("TP cấu trúc nằm sai phía giá vào");
      return;
     }
   double rr = rewardDistance / riskDistance;
   if(rr < PP4_RR_ToiThieu)
     {
      PP4_CancelArmedSetup(StringFormat("R:R %.2f thấp hơn tối thiểu %.2f", rr, PP4_RR_ToiThieu));
      return;
     }
   ThemTinHieu(4, (isBull ? DIR_BULL : DIR_BEAR), stop, takeProfit, 0.0, false,
               (entryTag == "Entry 2" ? "E2" : "E1"),
               StringFormat("QM %s %s | QM line=%s Head=%s Target=%s | R:R=%.2f",
                            (isBull ? "tăng" : "giảm"), entryTag, D(g4_setup.qmLinePrice),
                            D(g4_setup.headPrice), D(g4_setup.targetPrice), rr));
   //--- Setup được tiêu thụ (như bản gốc: dù lệnh khớp hay lỗi)
   g4_setup.isActive = false;
  }

void PP4_CheckArmedSetupForEntry()
  {
   ENUM_TIMEFRAMES tf = g_tf[4];
   double priorClose  = iClose(_Symbol, tf, 1);
   double buffer      = P2G(PP4_EntryBufferPips);
   int    barsElapsed = iBarShift(_Symbol, tf, g4_setup.armedTime);
   if(barsElapsed > PP4_SoNenChoToiDa)
     {
      PP4_CancelArmedSetup("hết hạn (giá không hồi về kịp)");
      return;
     }
   if(!PP4_ChoPhepNhieuLenh && g_dem.pp[4] > 0) return;

   if(g4_setup.isBull)
     {
      if(priorClose < g4_setup.headPrice) { PP4_CancelArmedSetup("bị vô hiệu (đóng cửa phá Head)"); return; }
      if(!v_PP4_ChoNenTuChoi)
        {
         if(priorClose <= g4_setup.qmLinePrice - buffer) PP4_TaoTinHieu(true, "Entry 1");
        }
      else
        {
         if(!g4_setup.lineBroken)
           {
            if(priorClose <= g4_setup.qmLinePrice) g4_setup.lineBroken = true;
           }
         else if(priorClose >= g4_setup.qmLinePrice + buffer)
            PP4_TaoTinHieu(true, "Entry 1");
        }
      if(g4_setup.isActive && g4_setup.entry2Valid)
        {
         if(!v_PP4_ChoNenTuChoi)
           {
            if(priorClose <= g4_setup.entry2Price - buffer) PP4_TaoTinHieu(true, "Entry 2");
           }
         else
           {
            if(!g4_setup.entry2Broken)
              {
               if(priorClose <= g4_setup.entry2Price) g4_setup.entry2Broken = true;
              }
            else if(priorClose >= g4_setup.entry2Price + buffer)
               PP4_TaoTinHieu(true, "Entry 2");
           }
        }
     }
   else
     {
      if(priorClose > g4_setup.headPrice) { PP4_CancelArmedSetup("bị vô hiệu (đóng cửa phá Head)"); return; }
      if(!v_PP4_ChoNenTuChoi)
        {
         if(priorClose >= g4_setup.qmLinePrice + buffer) PP4_TaoTinHieu(false, "Entry 1");
        }
      else
        {
         if(!g4_setup.lineBroken)
           {
            if(priorClose >= g4_setup.qmLinePrice) g4_setup.lineBroken = true;
           }
         else if(priorClose <= g4_setup.qmLinePrice - buffer)
            PP4_TaoTinHieu(false, "Entry 1");
        }
      if(g4_setup.isActive && g4_setup.entry2Valid)
        {
         if(!v_PP4_ChoNenTuChoi)
           {
            if(priorClose >= g4_setup.entry2Price + buffer) PP4_TaoTinHieu(false, "Entry 2");
           }
         else
           {
            if(!g4_setup.entry2Broken)
              {
               if(priorClose >= g4_setup.entry2Price) g4_setup.entry2Broken = true;
              }
            else if(priorClose <= g4_setup.entry2Price - buffer)
               PP4_TaoTinHieu(false, "Entry 2");
           }
        }
     }
  }

void PP4_EvaluateSwingPivotAtShift(const int pivotShift, const int lookback)
  {
   ENUM_TIMEFRAMES tf = g_tf[4];
   datetime pivotTime = iTime(_Symbol, tf, pivotShift);
   double   pivotHigh = iHigh(_Symbol, tf, pivotShift);
   double   pivotLow  = iLow(_Symbol, tf, pivotShift);
   bool isHigh = true, isLow = true;
   for(int j = 1; j <= lookback; j++)
     {
      if(iHigh(_Symbol, tf, pivotShift - j) >= pivotHigh || iHigh(_Symbol, tf, pivotShift + j) >= pivotHigh) isHigh = false;
      if(iLow(_Symbol, tf, pivotShift - j) <= pivotLow || iLow(_Symbol, tf, pivotShift + j) <= pivotLow) isLow = false;
     }
   if(isHigh && pivotTime != g4_lastLabeledHighTime)
     {
      g4_lastLabeledHigh     = pivotHigh;
      g4_lastLabeledHighTime = pivotTime;
      PP4_AddPivotToZigZag(true, pivotHigh, pivotTime);
      PP4_CheckForQMPattern();
     }
   if(isLow && pivotTime != g4_lastLabeledLowTime)
     {
      g4_lastLabeledLow     = pivotLow;
      g4_lastLabeledLowTime = pivotTime;
      PP4_AddPivotToZigZag(false, pivotLow, pivotTime);
      PP4_CheckForQMPattern();
     }
  }

void PP4_DetectSwingPivot()
  {
   int lookback = MathMax(1, PP4_SwingLookback);
   if(iBars(_Symbol, g_tf[4]) < lookback * 2 + 2) return;
   PP4_EvaluateSwingPivotAtShift(lookback + 1, lookback);
  }

void PP4_LoadHistoricalSwings()
  {
   if(!PP4_NapLichSuSwing || PP4_SoNenLichSu <= 0) return;
   int lookback  = MathMax(1, PP4_SwingLookback);
   int available = iBars(_Symbol, g_tf[4]);
   int minShift  = lookback + 1;
   int maxShift  = MathMin(PP4_SoNenLichSu, available - lookback - 2);
   if(maxShift < minShift) return;
   g4_replay = true;
   for(int shift = maxShift; shift >= minShift; shift--)
      PP4_EvaluateSwingPivotAtShift(shift, lookback);
   //--- Như bản gốc: setup dựng lại từ lịch sử KHÔNG được tự giao dịch
   g4_setup.isActive = false;
   g4_replay = false;
   LogChiTiet(4, StringFormat("Nạp lịch sử swing: %d nến %s, zig-zag hiện có %d pivot", maxShift, TfStr(g_tf[4]), ArraySize(g4_pivots)));
  }

void CheckStrategy4()
  {
   if(!g_ppBat[4]) return;
   if(!g4_daKhoiTao)
     {
      if(iBars(_Symbol, g_tf[4]) < MathMax(1, PP4_SwingLookback) * 2 + 2) return;
      PP4_LoadHistoricalSwings();
      g4_daKhoiTao = true;
     }
   if(!IsNewBar(4)) return;
   PP4_DetectSwingPivot();
   PP4_CheckForQMPattern();
   if(g4_setup.isActive) PP4_CheckArmedSetupForEntry();
  }

//+------------------------------------------------------------------+
//| BẢNG HIỂN THỊ                                                    |
//+------------------------------------------------------------------+
void DB_Dong(const int i, const string text, const color clr)
  {
   string name = OBJ_PREFIX + "DB_" + IntegerToString(i);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Bang_CoChu);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, Bang_X + 8);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, Bang_Y + 6 + i * (Bang_CoChu + 7));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void UpdateDashboard()
  {
   if(!HienThiBang || !g_veDuoc) return;
   uint now = GetTickCount();
   if(g_dbLast != 0 && now - g_dbLast < 1000) return;
   g_dbLast = now;

   int soDong = 16;
   string bg = OBJ_PREFIX + "DB_BG";
   if(ObjectFind(0, bg) < 0)
     {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'16,20,30');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_COLOR, C'60,70,90');
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, Bang_X);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, Bang_Y);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 20 * Bang_CoChu + 110);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, soDong * (Bang_CoChu + 7) + 10);

   double bal = SoDuTinhToan();
   double eq  = EquityTinhToan();
   double pnlNgay = g_loiNhuanDongNgay + g_dem.floating;
   int n = 0;
   DB_Dong(n++, "EA MASTER v" + EAM_VERSION + "  |  SET " + v_TienTo_Comment + "  |  " + _Symbol, clrGold);
   DB_Dong(n++, StringFormat("Magic: %d  (PP1-PP4: %d - %d)", (int)Magic_Goc, (int)MagicCuaPP(1), (int)MagicCuaPP(4)), clrSilver);
   DB_Dong(n++, "Bộ TS: " + g_tenBoThongSo + "  |  Xung đột: " + TenCheDoXungDot(), clrSilver);
   for(int pp = 1; pp <= SO_PP; pp++)
      DB_Dong(n++, StringFormat("%s %s [%s]: %s  |  lệnh: %d", g_ppTen[pp], g_ppMoTa[pp], TfStr(g_tf[pp]),
                                (g_ppBat[pp] ? "ON" : "OFF"), g_dem.pp[pp]), (g_ppBat[pp] ? clrLime : clrGray));
   DB_Dong(n++, StringFormat("BUY đang mở: %d  |  SELL đang mở: %d", g_dem.buy, g_dem.sell), clrWhite);
   DB_Dong(n++, StringFormat("Tổng position: %d / %d", g_dem.tong, g_maxTong), clrWhite);
   DB_Dong(n++, (DungVonAo() ? "Balance (vốn ảo): " : "Balance: ") + D2(bal), clrWhite);
   DB_Dong(n++, (DungVonAo() ? "Equity (vốn ảo): " : "Equity: ") + D2(eq), clrWhite);
   DB_Dong(n++, "Floating Profit: " + D2(g_dem.floating), (g_dem.floating >= 0.0 ? clrLime : clrTomato));
   DB_Dong(n++, StringFormat("DD hiện tại: %.2f%%  |  DD ngày: %.2f%%", g_ddTKHienTai, g_ddNgayHienTai), clrWhite);
   DB_Dong(n++, StringFormat("Profit ngày: %.2f  (đã đóng %.2f)", pnlNgay, g_loiNhuanDongNgay), (pnlNgay >= 0.0 ? clrLime : clrTomato));
   DB_Dong(n++, StringFormat("Spread: %.1f pips  |  Thua liên tiếp: %d", SpreadPips(), g_thuaLienTiep), clrSilver);
   DB_Dong(n++, (g_choPhepVaoLenh ? "Trạng thái: CHO PHÉP vào lệnh" : "KHÓA: " + g_lyDoKhoa), (g_choPhepVaoLenh ? clrLime : clrOrange));
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| THỐNG KÊ THEO PP (in khi kết thúc backtest / gỡ EA)              |
//+------------------------------------------------------------------+
void InThongKeTheoPP()
  {
   if(!HistorySelect(0, TimeCurrent() + 86400)) return;
   double loiNhuan[5], lai[5], lo[5];
   int    so[5], thang[5];
   ArrayInitialize(loiNhuan, 0.0);
   ArrayInitialize(lai, 0.0);
   ArrayInitialize(lo, 0.0);
   ArrayInitialize(so, 0);
   ArrayInitialize(thang, 0);
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong dl = HistoryDealGetTicket(i);
      if(dl == 0) continue;
      if(HistoryDealGetString(dl, DEAL_SYMBOL) != _Symbol) continue;
      int pp = PPTuMagic(HistoryDealGetInteger(dl, DEAL_MAGIC));
      if(pp == 0) continue;
      double p = HistoryDealGetDouble(dl, DEAL_PROFIT) + HistoryDealGetDouble(dl, DEAL_SWAP) + HistoryDealGetDouble(dl, DEAL_COMMISSION);
      loiNhuan[pp] += p;
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dl, DEAL_ENTRY);
      if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
        {
         so[pp]++;
         if(p > 0.0) { thang[pp]++; lai[pp] += p; }
         else lo[pp] += -p;
        }
     }
   Print("========== THỐNG KÊ EA MASTER THEO PHƯƠNG PHÁP (", _Symbol, ") ==========");
   for(int pp = 1; pp <= SO_PP; pp++)
     {
      double wr = (so[pp] > 0 ? 100.0 * thang[pp] / so[pp] : 0.0);
      string pf = (lo[pp] > 0.0 ? DoubleToString(lai[pp] / lo[pp], 2) : (lai[pp] > 0.0 ? "vô cực" : "-"));
      Print(StringFormat("%s %-5s | magic %d | lần đóng lệnh: %d | thắng: %.1f%% | lợi nhuận: %.2f | PF: %s",
                         g_ppTen[pp], g_ppMoTa[pp], (int)MagicCuaPP(pp), so[pp], wr, loiNhuan[pp], pf));
     }
   Print("Ghi chú: 'lần đóng lệnh' tính theo deal đóng (chốt một phần / đóng giỏ được tính riêng từng deal).");
  }

//+------------------------------------------------------------------+
//| SET DỰNG SẴN (ChonSet) - dùng cho Optimization nhiều SET         |
//| Mỗi SET bắt đầu từ: tắt cả 4 PP, BALANCED, độc lập, khung M15,   |
//| PP1 M1, rồi chỉ đổi đúng các thông số ghi trong case.            |
//+------------------------------------------------------------------+
#define SO_SET_DUNG_SAN 102

void SaoChepInput()
  {
   v_PP2_RR = PP2_RR;
   v_PP2_DoDaiSwing = PP2_DoDaiSwing;
   v_PP2_YeuCauNenXacNhan = PP2_YeuCauNenXacNhan;
   v_PP2_TheoTrendSwing = PP2_TheoTrendSwing;
   v_PP2_SoOBXemXet = PP2_SoOBXemXet;
   v_PP4_RR = PP4_RR;
   v_PP4_KieuTP = PP4_KieuTP;
   v_QL_BatHoaVon = QL_BatHoaVon;
   v_TienTo_Comment = TienTo_Comment;
   v_BoThongSo = BoThongSo;
   v_Signal_Timeframe = Signal_Timeframe;
   v_Bat_ChienLuoc_1 = Bat_ChienLuoc_1;
   v_Bat_ChienLuoc_2 = Bat_ChienLuoc_2;
   v_Bat_ChienLuoc_3 = Bat_ChienLuoc_3;
   v_Bat_ChienLuoc_4 = Bat_ChienLuoc_4;
   v_ChanLenhNguocChieu = ChanLenhNguocChieu;
   v_CheDo_XungDot = CheDo_XungDot;
   v_QL_KieuTrailing = QL_KieuTrailing;
   v_PP1_Timeframe = PP1_Timeframe;
   v_PP1_RSI_ChuKy = PP1_RSI_ChuKy;
   v_PP1_RSI_VaoBan = PP1_RSI_VaoBan;
   v_PP1_RSI_VaoMua = PP1_RSI_VaoMua;
   v_PP2_Timeframe = PP2_Timeframe;
   v_PP2_LoaiOB = PP2_LoaiOB;
   v_PP2_LocHTF = PP2_LocHTF;
   v_PP2_HTF = PP2_HTF;
   v_PP2_LocPremiumDiscount = PP2_LocPremiumDiscount;
   v_PP3_Timeframe = PP3_Timeframe;
   v_PP3_CheDo = PP3_CheDo;
   v_PP3_KieuTP = PP3_KieuTP;
   v_PP4_Timeframe = PP4_Timeframe;
   v_PP4_ChoNenTuChoi = PP4_ChoNenTuChoi;
  }

bool ApDungChonSet()
  {
   if(ChonSet <= 0) return true;
   if(ChonSet > SO_SET_DUNG_SAN) return false;
   v_Bat_ChienLuoc_1 = false; v_Bat_ChienLuoc_2 = false; v_Bat_ChienLuoc_3 = false; v_Bat_ChienLuoc_4 = false;
   v_BoThongSo = BTS_CAN_BANG; v_CheDo_XungDot = XD_DOC_LAP; v_ChanLenhNguocChieu = false;
   v_QL_KieuTrailing = TRAIL_TAT; v_Signal_Timeframe = PERIOD_M15;
   v_PP1_Timeframe = PERIOD_M1; v_PP1_RSI_ChuKy = 19; v_PP1_RSI_VaoBan = 70.0; v_PP1_RSI_VaoMua = 30.0;
   v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_CA_HAI; v_PP2_LocHTF = false; v_PP2_HTF = PERIOD_H4; v_PP2_LocPremiumDiscount = false;
   v_PP3_Timeframe = PERIOD_M15; v_PP3_CheDo = PP3_BAT_LAI; v_PP3_KieuTP = TP_THEO_CAU_TRUC;
   v_PP4_Timeframe = PERIOD_M15; v_PP4_ChoNenTuChoi = false;
   v_PP2_RR = 2.0; v_PP2_DoDaiSwing = 50; v_PP2_YeuCauNenXacNhan = true; v_PP2_TheoTrendSwing = true; v_PP2_SoOBXemXet = 5;
   v_PP4_RR = 2.0; v_PP4_KieuTP = TP_THEO_RR; v_QL_BatHoaVon = true;
   switch(ChonSet)
     {
      case 1: g_moTaSet = "PP1 RSI M1 (gốc)"; v_Bat_ChienLuoc_1 = true; v_PP1_Timeframe = PERIOD_M1; break;
      case 2: g_moTaSet = "PP1 RSI M5"; v_Bat_ChienLuoc_1 = true; v_PP1_Timeframe = PERIOD_M5; break;
      case 3: g_moTaSet = "PP1 RSI M15"; v_Bat_ChienLuoc_1 = true; v_PP1_Timeframe = PERIOD_M15; break;
      case 4: g_moTaSet = "PP1 RSI(14) 75/25 M5"; v_Bat_ChienLuoc_1 = true; v_PP1_Timeframe = PERIOD_M5; v_PP1_RSI_ChuKy = 14; v_PP1_RSI_VaoBan = 75.0; v_PP1_RSI_VaoMua = 25.0; break;
      case 5: g_moTaSet = "PP2 SMC M15"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; break;
      case 6: g_moTaSet = "PP2 SMC H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; break;
      case 7: g_moTaSet = "PP2 SMC H1 + lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 8: g_moTaSet = "PP2 SMC M15 + Premium/Discount"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LocPremiumDiscount = true; break;
      case 9: g_moTaSet = "PP2 SMC M15 chỉ OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; break;
      case 10: g_moTaSet = "PP3 Pivot bật lại M15"; v_Bat_ChienLuoc_3 = true; v_PP3_Timeframe = PERIOD_M15; v_PP3_CheDo = PP3_BAT_LAI; break;
      case 11: g_moTaSet = "PP3 Pivot bật lại M5"; v_Bat_ChienLuoc_3 = true; v_PP3_Timeframe = PERIOD_M5; v_PP3_CheDo = PP3_BAT_LAI; break;
      case 12: g_moTaSet = "PP3 Pivot bật lại M15 TP R:R"; v_Bat_ChienLuoc_3 = true; v_PP3_Timeframe = PERIOD_M15; v_PP3_CheDo = PP3_BAT_LAI; v_PP3_KieuTP = TP_THEO_RR; break;
      case 13: g_moTaSet = "PP3 Pivot phá vỡ M15"; v_Bat_ChienLuoc_3 = true; v_PP3_Timeframe = PERIOD_M15; v_PP3_CheDo = PP3_PHA_VO; break;
      case 14: g_moTaSet = "PP4 QM M15"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M15; break;
      case 15: g_moTaSet = "PP4 QM H1"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H1; break;
      case 16: g_moTaSet = "PP4 QM M5"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M5; break;
      case 17: g_moTaSet = "PP4 QM M15 chờ nến từ chối"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M15; v_PP4_ChoNenTuChoi = true; break;
      case 18: g_moTaSet = "PP4 QM M15 trailing ATR"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M15; v_QL_KieuTrailing = TRAIL_ATR; break;
      case 19: g_moTaSet = "PP2 SMC M15 trailing ATR"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_QL_KieuTrailing = TRAIL_ATR; break;
      case 20: g_moTaSet = "4PP BALANCED độc lập"; v_Bat_ChienLuoc_1 = true; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_3 = true; v_Bat_ChienLuoc_4 = true; break;
      case 21: g_moTaSet = "4PP SAFE không đối nghịch"; v_Bat_ChienLuoc_1 = true; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_3 = true; v_Bat_ChienLuoc_4 = true; v_BoThongSo = BTS_AN_TOAN; v_CheDo_XungDot = XD_KHONG_DOI_NGHICH; v_ChanLenhNguocChieu = true; break;
      case 22: g_moTaSet = "4PP BALANCED đa số thắng"; v_Bat_ChienLuoc_1 = true; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_3 = true; v_Bat_ChienLuoc_4 = true; v_CheDo_XungDot = XD_DA_SO; break;
      case 23: g_moTaSet = "V2 PP2 H1 chỉ OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; break;
      case 24: g_moTaSet = "V2 PP2 H1 OB swing R:R 3"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; v_PP2_RR = 3.0; break;
      case 25: g_moTaSet = "V2 PP2 H1 R:R 3"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_RR = 3.0; break;
      case 26: g_moTaSet = "V2 PP2 H1 R:R 1.5"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_RR = 1.5; break;
      case 27: g_moTaSet = "V2 PP2 H1 không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_QL_BatHoaVon = false; break;
      case 28: g_moTaSet = "V2 PP2 M30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; break;
      case 29: g_moTaSet = "V2 PP2 M30 chỉ OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_LoaiOB = OB_SWING; break;
      case 30: g_moTaSet = "V2 PP2 H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H4; break;
      case 31: g_moTaSet = "V2 PP2 M15 OB swing R:R 3"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP2_RR = 3.0; break;
      case 32: g_moTaSet = "V2 PP2 M15 OB swing không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_QL_BatHoaVon = false; break;
      case 33: g_moTaSet = "V2 PP2 H1 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_DoDaiSwing = 30; break;
      case 34: g_moTaSet = "V2 PP2 H1 không cần nến xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_YeuCauNenXacNhan = false; break;
      case 35: g_moTaSet = "V2 PP4 H1 R:R 3"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H1; v_PP4_RR = 3.0; break;
      case 36: g_moTaSet = "V2 PP4 H1 TP cấu trúc"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H1; v_PP4_KieuTP = TP_THEO_CAU_TRUC; break;
      case 37: g_moTaSet = "V2 PP4 H4"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H4; break;
      case 38: g_moTaSet = "V2 PP4 H1 không hòa vốn"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H1; v_QL_BatHoaVon = false; break;
      case 39: g_moTaSet = "V2 PP2 H1 + PP4 H1"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_H1; v_PP4_Timeframe = PERIOD_H1; break;
      case 40: g_moTaSet = "V2 PP2 H1 OB swing + PP4 H1"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; v_PP4_Timeframe = PERIOD_H1; break;
      case 41: g_moTaSet = "V3 PP2 M15 OB swing không cần nến xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP2_YeuCauNenXacNhan = false; break;
      case 42: g_moTaSet = "V3 PP2 M15 xét 10 OB, 2 lệnh/PP"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_SoOBXemXet = 10; v_BoThongSo = BTS_MAO_HIEM; break;
      case 43: g_moTaSet = "V3 PP2 M15 lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 44: g_moTaSet = "V3 PP2 M15 lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 45: g_moTaSet = "V3 PP2 M5 lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 46: g_moTaSet = "V3 PP2 M5 OB swing lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LoaiOB = OB_SWING; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 47: g_moTaSet = "V3 PP2 M15 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_DoDaiSwing = 30; break;
      case 48: g_moTaSet = "V3 PP2 M15 swing 20 OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_DoDaiSwing = 20; v_PP2_LoaiOB = OB_SWING; break;
      case 49: g_moTaSet = "V3 PP2 M30 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_DoDaiSwing = 30; break;
      case 50: g_moTaSet = "V3 PP2 H1 swing 20"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_DoDaiSwing = 20; break;
      case 51: g_moTaSet = "V3 PP2 M15 OB swing + PP4 H1"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP4_Timeframe = PERIOD_H1; break;
      case 52: g_moTaSet = "V3 PP2 M15 OB swing + PP4 M15 R:R 3"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP4_Timeframe = PERIOD_M15; v_PP4_RR = 3.0; break;
      case 53: g_moTaSet = "V4 PP2 M5"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; break;
      case 54: g_moTaSet = "V4 PP2 M5 OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LoaiOB = OB_SWING; break;
      case 55: g_moTaSet = "V4 PP2 M5 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_YeuCauNenXacNhan = false; break;
      case 56: g_moTaSet = "V4 PP2 M5 OB swing không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LoaiOB = OB_SWING; v_PP2_YeuCauNenXacNhan = false; break;
      case 57: g_moTaSet = "V4 PP2 M5 lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 58: g_moTaSet = "V4 PP2 M5 OB swing lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LoaiOB = OB_SWING; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 59: g_moTaSet = "V4 PP2 M5 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_DoDaiSwing = 30; break;
      case 60: g_moTaSet = "V4 PP2 M5 swing 30 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_DoDaiSwing = 30; v_PP2_YeuCauNenXacNhan = false; break;
      case 61: g_moTaSet = "V4 PP2 M5 R:R 1.5 không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_RR = 1.5; v_QL_BatHoaVon = false; break;
      case 62: g_moTaSet = "V4 PP2 M5 R:R 3, 10 OB, 2 lệnh"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_RR = 3.0; v_PP2_SoOBXemXet = 10; v_BoThongSo = BTS_MAO_HIEM; break;
      case 63: g_moTaSet = "V4 PP2 M15"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; break;
      case 64: g_moTaSet = "V4 PP2 M15 OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; break;
      case 65: g_moTaSet = "V4 PP2 M15 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_YeuCauNenXacNhan = false; break;
      case 66: g_moTaSet = "V4 PP2 M15 OB swing không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP2_YeuCauNenXacNhan = false; break;
      case 67: g_moTaSet = "V4 PP2 M15 lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 68: g_moTaSet = "V4 PP2 M15 OB swing lọc HTF H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; break;
      case 69: g_moTaSet = "V4 PP2 M15 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_DoDaiSwing = 30; break;
      case 70: g_moTaSet = "V4 PP2 M15 swing 30 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_DoDaiSwing = 30; v_PP2_YeuCauNenXacNhan = false; break;
      case 71: g_moTaSet = "V4 PP2 M15 R:R 1.5 không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_RR = 1.5; v_QL_BatHoaVon = false; break;
      case 72: g_moTaSet = "V4 PP2 M15 R:R 3, 10 OB, 2 lệnh"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_RR = 3.0; v_PP2_SoOBXemXet = 10; v_BoThongSo = BTS_MAO_HIEM; break;
      case 73: g_moTaSet = "V4 PP2 M30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; break;
      case 74: g_moTaSet = "V4 PP2 M30 OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_LoaiOB = OB_SWING; break;
      case 75: g_moTaSet = "V4 PP2 M30 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_YeuCauNenXacNhan = false; break;
      case 76: g_moTaSet = "V4 PP2 M30 OB swing không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_LoaiOB = OB_SWING; v_PP2_YeuCauNenXacNhan = false; break;
      case 77: g_moTaSet = "V4 PP2 M30 lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 78: g_moTaSet = "V4 PP2 M30 OB swing lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_LoaiOB = OB_SWING; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 79: g_moTaSet = "V4 PP2 M30 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_DoDaiSwing = 30; break;
      case 80: g_moTaSet = "V4 PP2 M30 swing 30 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_DoDaiSwing = 30; v_PP2_YeuCauNenXacNhan = false; break;
      case 81: g_moTaSet = "V4 PP2 M30 R:R 1.5 không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_RR = 1.5; v_QL_BatHoaVon = false; break;
      case 82: g_moTaSet = "V4 PP2 M30 R:R 3, 10 OB, 2 lệnh"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_M30; v_PP2_RR = 3.0; v_PP2_SoOBXemXet = 10; v_BoThongSo = BTS_MAO_HIEM; break;
      case 83: g_moTaSet = "V4 PP2 H1"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; break;
      case 84: g_moTaSet = "V4 PP2 H1 OB swing"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; break;
      case 85: g_moTaSet = "V4 PP2 H1 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_YeuCauNenXacNhan = false; break;
      case 86: g_moTaSet = "V4 PP2 H1 OB swing không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; v_PP2_YeuCauNenXacNhan = false; break;
      case 87: g_moTaSet = "V4 PP2 H1 lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 88: g_moTaSet = "V4 PP2 H1 OB swing lọc HTF H4"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_LoaiOB = OB_SWING; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H4; break;
      case 89: g_moTaSet = "V4 PP2 H1 swing 30"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_DoDaiSwing = 30; break;
      case 90: g_moTaSet = "V4 PP2 H1 swing 30 không xác nhận"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_DoDaiSwing = 30; v_PP2_YeuCauNenXacNhan = false; break;
      case 91: g_moTaSet = "V4 PP2 H1 R:R 1.5 không hòa vốn"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_RR = 1.5; v_QL_BatHoaVon = false; break;
      case 92: g_moTaSet = "V4 PP2 H1 R:R 3, 10 OB, 2 lệnh"; v_Bat_ChienLuoc_2 = true; v_PP2_Timeframe = PERIOD_H1; v_PP2_RR = 3.0; v_PP2_SoOBXemXet = 10; v_BoThongSo = BTS_MAO_HIEM; break;
      case 93: g_moTaSet = "V4 PP4 M15 R:R 3"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M15; v_PP4_RR = 3.0; break;
      case 94: g_moTaSet = "V4 PP4 M30"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M30; break;
      case 95: g_moTaSet = "V4 PP4 M30 R:R 3"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M30; v_PP4_RR = 3.0; break;
      case 96: g_moTaSet = "V4 PP4 H1 R:R 3 không hòa vốn"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_H1; v_PP4_RR = 3.0; v_QL_BatHoaVon = false; break;
      case 97: g_moTaSet = "V4 PP4 M15 TP cấu trúc"; v_Bat_ChienLuoc_4 = true; v_PP4_Timeframe = PERIOD_M15; v_PP4_KieuTP = TP_THEO_CAU_TRUC; break;
      case 98: g_moTaSet = "V4 PP2 M15 OB swing + PP4 M15"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M15; v_PP2_LoaiOB = OB_SWING; v_PP4_Timeframe = PERIOD_M15; break;
      case 99: g_moTaSet = "V4 PP2 M15 + PP4 H1"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M15; v_PP4_Timeframe = PERIOD_H1; break;
      case 100: g_moTaSet = "V4 PP2 M30 + PP4 M30"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M30; v_PP4_Timeframe = PERIOD_M30; break;
      case 101: g_moTaSet = "V4 PP2 M5 lọc HTF H1 + PP4 M15"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M5; v_PP2_LocHTF = true; v_PP2_HTF = PERIOD_H1; v_PP4_Timeframe = PERIOD_M15; break;
      case 102: g_moTaSet = "V4 PP2 M15 + PP3 bật lại M15 + PP4 H1"; v_Bat_ChienLuoc_2 = true; v_Bat_ChienLuoc_3 = true; v_Bat_ChienLuoc_4 = true; v_PP2_Timeframe = PERIOD_M15; v_PP3_Timeframe = PERIOD_M15; v_PP4_Timeframe = PERIOD_H1; break;
     }
   v_TienTo_Comment = StringFormat("B%02d", ChonSet);
   return true;
  }

//+------------------------------------------------------------------+
//| KẾT QUẢ TESTER: 1 dòng / lượt vào Common\Files (gom mọi lượt)    |
//+------------------------------------------------------------------+
double OnTester()
  {
   double loiNhuan = TesterStatistics(STAT_PROFIT);
   double soLenh   = TesterStatistics(STAT_TRADES);
   double ddTien   = TesterStatistics(STAT_EQUITY_DD);
   //--- Tiêu chí tùy chỉnh (Custom max): Recovery = Lợi nhuận / Max DD, chỉ tính khi đủ 30 lệnh
   double diem = (soLenh >= 30 ? loiNhuan / MathMax(ddTien, 1.0) : 0.0);
   if(!GhiKetQuaTester) return diem;

   //--- Thống kê riêng từng PP
   double lnPP[5];
   int    slPP[5], thPP[5];
   ArrayInitialize(lnPP, 0.0);
   ArrayInitialize(slPP, 0);
   ArrayInitialize(thPP, 0);
   if(HistorySelect(0, TimeCurrent() + 86400))
     {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
        {
         ulong dl = HistoryDealGetTicket(i);
         if(dl == 0) continue;
         int pp = PPTuMagic(HistoryDealGetInteger(dl, DEAL_MAGIC));
         if(pp == 0) continue;
         double p = HistoryDealGetDouble(dl, DEAL_PROFIT) + HistoryDealGetDouble(dl, DEAL_SWAP) +
                    HistoryDealGetDouble(dl, DEAL_COMMISSION) + HistoryDealGetDouble(dl, DEAL_FEE);
         lnPP[pp] += p;
         ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dl, DEAL_ENTRY);
         if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
           {
            slPP[pp]++;
            if(p > 0.0) thPP[pp]++;
           }
        }
     }

   string ten = "EAM_BACKTEST_KET_QUA.csv";
   int h = INVALID_HANDLE;
   for(int lan = 0; lan < 20 && h == INVALID_HANDLE; lan++)
      h = FileOpen(ten, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return diem;
   if(FileSize(h) <= 2)
      FileWriteString(h, "ChonSet;Mo ta;Symbol;Tu;Den;Von dau;Loi nhuan;PF;Expected payoff;So lenh;Thang %;"
                         + "Max DD equity %;Max DD equity $;Recovery;Sharpe;Diem;"
                         + "PP1 lenh;PP1 thang %;PP1 LN;PP2 lenh;PP2 thang %;PP2 LN;"
                         + "PP3 lenh;PP3 thang %;PP3 LN;PP4 lenh;PP4 thang %;PP4 LN\r\n");
   FileSeek(h, 0, SEEK_END);
   string dong = IntegerToString(ChonSet) + ";" + g_moTaSet + ";" + _Symbol
               + ";" + TimeToString(g_tgBatDauTest, TIME_DATE) + ";" + TimeToString(TimeCurrent(), TIME_DATE)
               + ";" + DoubleToString(TesterStatistics(STAT_INITIAL_DEPOSIT), 2)
               + ";" + DoubleToString(loiNhuan, 2)
               + ";" + DoubleToString(TesterStatistics(STAT_PROFIT_FACTOR), 2)
               + ";" + DoubleToString(TesterStatistics(STAT_EXPECTED_PAYOFF), 2)
               + ";" + DoubleToString(soLenh, 0)
               + ";" + DoubleToString(soLenh > 0 ? 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / soLenh : 0.0, 1)
               + ";" + DoubleToString(TesterStatistics(STAT_EQUITYDD_PERCENT), 2)
               + ";" + DoubleToString(ddTien, 2)
               + ";" + DoubleToString(TesterStatistics(STAT_RECOVERY_FACTOR), 2)
               + ";" + DoubleToString(TesterStatistics(STAT_SHARPE_RATIO), 2)
               + ";" + DoubleToString(diem, 3);
   for(int pp = 1; pp <= SO_PP; pp++)
      dong += ";" + IntegerToString(slPP[pp])
            + ";" + DoubleToString(slPP[pp] > 0 ? 100.0 * thPP[pp] / slPP[pp] : 0.0, 1)
            + ";" + DoubleToString(lnPP[pp], 2);
   FileWriteString(h, dong + "\r\n");
   FileClose(h);
   return diem;
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SaoChepInput();
   if(!ApDungChonSet())
     {
      Print("LỖI INPUT: ChonSet phải từ 0 đến ", SO_SET_DUNG_SAN);
      return INIT_PARAMETERS_INCORRECT;
     }
   g_tgBatDauTest = TimeCurrent();
   //--- Kiểm tra tham số phi lý
   if(Magic_Goc <= 0)                                  { Print("LỖI INPUT: Magic_Goc phải > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(PP1_SL_Pips <= 0.0)                              { Print("LỖI INPUT: PP1_SL_Pips phải > 0 (EA không cho phép lệnh không SL)"); return INIT_PARAMETERS_INCORRECT; }
   if(v_BoThongSo == BTS_TUY_CHINH && (Risk_Percent <= 0.0 || Risk_Percent > 10.0))
                                                       { Print("LỖI INPUT: Risk_Percent phải trong (0; 10]"); return INIT_PARAMETERS_INCORRECT; }
   if(Risk_GhiDe_PT < 0.0 || Risk_GhiDe_PT > 10.0) { Print("LỖI INPUT: Risk_GhiDe_PT phải trong [0; 10]"); return INIT_PARAMETERS_INCORRECT; }
   if(!SuDung_AutoLot && Lot_CoDinh <= 0.0)            { Print("LỖI INPUT: Lot_CoDinh phải > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(v_BoThongSo == BTS_TUY_CHINH && (MaxLenh_Tong <= 0 || MaxLenh_Buy <= 0 || MaxLenh_Sell <= 0 || MaxLenh_MoiPP <= 0))
                                                       { Print("LỖI INPUT: các giới hạn số lệnh phải > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(v_PP1_RSI_ChuKy < 2 || v_PP2_DoDaiSwing < 2 || PP2_DoDaiNoiBo < 2 || PP4_SwingLookback < 1 || PP4_ATR_ChuKy < 1)
                                                       { Print("LỖI INPUT: chu kỳ / độ dài swing không hợp lệ"); return INIT_PARAMETERS_INCORRECT; }
   if(v_PP2_RR <= 0.0 || PP3_RR <= 0.0 || v_PP4_RR <= 0.0) { Print("LỖI INPUT: R:R phải > 0"); return INIT_PARAMETERS_INCORRECT; }
   if(PP1_BatNhoiLenh && (PP1_HeSoLot < 1.0 || PP1_HeSoLot > 3.0 || PP1_SoTangToiDa < 1 || PP1_SoTangToiDa > 10 || PP1_BuocNhoi_Pips <= 0.0))
                                                       { Print("LỖI INPUT: thông số nhồi lệnh PP1 không hợp lệ (hệ số 1-3, tầng 1-10, bước > 0)"); return INIT_PARAMETERS_INCORRECT; }

   ApDungBoThongSo();

   g_digits = _Digits;
   g_point  = _Point;
   g_pip    = TinhKichThuocPip();
   if(g_pip <= 0.0) g_pip = _Point;
   g_deviationPts = (int)MathMax(1.0, MathRound(P2G(TruotGia_Pips) / g_point));

   g_trade.SetDeviationInPoints(g_deviationPts);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetMarginMode();
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_laNetting = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   g_veDuoc    = !(MQLInfoInteger(MQL_TESTER) != 0 && MQLInfoInteger(MQL_VISUAL_MODE) == 0);

   g_ppBat[0] = false;
   g_ppBat[1] = v_Bat_ChienLuoc_1;
   g_ppBat[2] = v_Bat_ChienLuoc_2;
   g_ppBat[3] = v_Bat_ChienLuoc_3;
   g_ppBat[4] = v_Bat_ChienLuoc_4;

   g_tf[0] = ResolveTF(PERIOD_CURRENT);
   g_tf[1] = ResolveTF(v_PP1_Timeframe);
   g_tf[2] = ResolveTF(v_PP2_Timeframe);
   g_tf[3] = ResolveTF(v_PP3_Timeframe);
   g_tf[4] = ResolveTF(v_PP4_Timeframe);

   for(int pp = 0; pp <= SO_PP; pp++)
     {
      g_lastBarTime[pp]    = iTime(_Symbol, g_tf[pp], 0);   // không vào lệnh ngay khi vừa gắn EA
      g_lastEntryTime[pp]  = 0;
      g_lastEntryBar[pp]   = 0;
      g_lastSigDir[pp]     = 0;
      g_lastSigTime[pp]    = 0;
      g_lastRejectMsg[pp]  = "";
      g_lastRejectTime[pp] = 0;
      g_hATRQL[pp]         = INVALID_HANDLE;
     }

   //--- Handle chỉ báo (RSI luôn tạo để vẫn thoát được giỏ PP1 khi PP1 bị tắt)
   g_hRSI1 = iRSI(_Symbol, g_tf[1], v_PP1_RSI_ChuKy, PRICE_CLOSE);
   if(g_hRSI1 == INVALID_HANDLE) { Print("LỖI: không tạo được RSI cho PP1"); return INIT_FAILED; }
   for(int pp = 2; pp <= SO_PP; pp++)
     {
      g_hATRQL[pp] = iATR(_Symbol, g_tf[pp], PP4_ATR_ChuKy);
      if(g_hATRQL[pp] == INVALID_HANDLE) { Print("LỖI: không tạo được ATR cho ", g_ppTen[pp]); return INIT_FAILED; }
     }
   if(g_ppBat[2])
     {
      g2_hATR200 = iATR(_Symbol, g_tf[2], 200);
      if(g2_hATR200 == INVALID_HANDLE) { Print("LỖI: không tạo được ATR(200) cho PP2"); return INIT_FAILED; }
     }

   //--- Trạng thái chiến lược
   PP2_Reset();
   g2_daKhoiTao     = false;
   g2_daBaoThieuNen = false;
   g2_htfBias       = 0;
   g2_htfLastCalc   = 0;
   g3_hopLe         = false;
   g3_ngayD1        = 0;
   g3_daGiaoDich    = 0;
   ArrayResize(g4_pivots, 0);
   g4_setup.isActive = false;
   g4_daKhoiTao      = false;
   g4_lastLabeledHigh = 0.0; g4_lastLabeledHighTime = 0;
   g4_lastLabeledLow  = 0.0; g4_lastLabeledLowTime  = 0;
   g4_lastArmedBosTime = 0;  g4_lastArmedShoulderTime = 0;

   //--- Risk Manager
   //--- Khóa đỉnh equity tách riêng giữa chế độ thật và vốn ảo (đổi mốc vốn ảo = đo lại)
   g_gvDinh = "EAM_" + IntegerToString(Magic_Goc) +
              (DungVonAo() ? "_DINH_VA_" + IntegerToString((long)VonAo_BatDau) : "_DINH_EQUITY");
   g_dinhEquity  = 0.0;
   g_dinhKhoiTao = false;
   g_loiNhuanSet = 0.0;
   g_ngayHienTai      = 0;
   g_khoaNgay         = false;
   g_khoaTaiKhoan     = false;
   g_canTinhLaiLichSu = true;

   ArrayResize(g_lenh, 0);
   ArrayResize(g_dsTinHieu, 0);
   g_fileNhatKy = (TenFileNhatKy != "" ? TenFileNhatKy :
                   "EAM_" + v_TienTo_Comment + "_" + IntegerToString(Magic_Goc) +
                   (MQLInfoInteger(MQL_TESTER) != 0 ? "_TESTER" : "") + ".csv");
   CapNhatLenhTheoDoi();
   DemLenh(g_dem);

   //--- Thông báo cấu hình
   Print("================ EA MASTER v", EAM_VERSION, " khởi động trên ", _Symbol, " ================");
   Print(StringFormat("Pip = %s giá | Digits = %d | Point = %s | Trượt giá = %d points | Tài khoản %s",
                      DoubleToString(g_pip, g_digits), g_digits, DoubleToString(g_point, g_digits), g_deviationPts,
                      (g_laNetting ? "NETTING (chỉ 1 vị thế/symbol, tắt nhồi lệnh)" : "HEDGING")));
   Print(StringFormat("Bộ thông số: %s | Risk=%.2f%% | Max tổng=%d BUY=%d SELL=%d mỗi PP=%d | DD ngày=%.1f%% DD TK=%.1f%% | Thua LT=%d",
                      g_tenBoThongSo, g_riskPct, g_maxTong, g_maxBuy, g_maxSell, g_maxPP, g_ddNgayMax, g_ddTKMax, g_thuaLTMax));
   for(int pp = 1; pp <= SO_PP; pp++)
      Print(StringFormat("%s %s: %s | khung %s | magic %d", g_ppTen[pp], g_ppMoTa[pp], (g_ppBat[pp] ? "BẬT" : "TẮT"),
                         TfStr(g_tf[pp]), (int)MagicCuaPP(pp)));
   InThongSoHopDong();
   Print("SET dựng sẵn: ", (ChonSet > 0 ? StringFormat("B%02d - ", ChonSet) + g_moTaSet : "không (dùng Input)"));
   Print("Xung đột tín hiệu: ", TenCheDoXungDot(), " | SET: ", v_TienTo_Comment,
         (DungVonAo() ? " | VỐN ẢO " + D2(VonAo_USD) + " từ " + TimeToString(VonAo_BatDau, TIME_DATE | TIME_MINUTES)
                      : " | dùng Balance/Equity thật"));
   if(GhiNhatKyCSV) Print("Nhật ký lệnh: Common\\Files\\", g_fileNhatKy);
   if(PP1_BatNhoiLenh)
      Print("CẢNH BÁO: PP1 đang BẬT nhồi lệnh (DCA)", (PP1_HeSoLot > 1.0 ? " + MARTINGALE (hệ số lot > 1)" : ""),
            " - rủi ro cộng dồn tới ", PP1_SoTangToiDa, " tầng.");
   if(Bat_LocTin && MQLInfoInteger(MQL_TESTER) != 0)
      Print("LƯU Ý: Lọc tin không hoạt động trong Strategy Tester.");

   //--- Vẽ bảng ngay, và cập nhật theo timer để bảng vẫn hiện khi thị trường đóng cửa (không có tick)
   if(HienThiBang && g_veDuoc)
     {
      EventSetTimer(1);
      CapNhatBangKhongTick();
     }
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(MQLInfoInteger(MQL_TESTER) != 0 || reason == REASON_REMOVE) InThongKeTheoPP();
   if(g_hRSI1 != INVALID_HANDLE) IndicatorRelease(g_hRSI1);
   if(g2_hATR200 != INVALID_HANDLE) IndicatorRelease(g2_hATR200);
   for(int pp = 0; pp <= SO_PP; pp++)
      if(g_hATRQL[pp] != INVALID_HANDLE) IndicatorRelease(g_hATRQL[pp]);
   g_hRSI1    = INVALID_HANDLE;
   g2_hATR200 = INVALID_HANDLE;
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction - đánh dấu cần tính lại thống kê ngày         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   g_canTinhLaiLichSu = true;
   if(!GhiNhatKyCSV || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   int pp = PPTuMagic(HistoryDealGetInteger(trans.deal, DEAL_MAGIC));
   if(pp == 0) return;
   ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(en != DEAL_ENTRY_OUT && en != DEAL_ENTRY_OUT_BY && en != DEAL_ENTRY_INOUT) return;
   double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
              HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) + HistoryDealGetDouble(trans.deal, DEAL_FEE);
   ENUM_DEAL_REASON rs = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   string lyDo = (rs == DEAL_REASON_SL ? "Cham SL" : (rs == DEAL_REASON_TP ? "Cham TP" :
                 (rs == DEAL_REASON_SO ? "Stop out" : (rs == DEAL_REASON_EXPERT ? "EA dong" : "Dong tay/khac"))));
   //--- deal đóng của lệnh BUY là deal SELL và ngược lại
   string loai = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_SELL ? "BUY" : "SELL");
   GhiNhatKy("DONG", pp, (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID), loai,
             HistoryDealGetDouble(trans.deal, DEAL_VOLUME), HistoryDealGetDouble(trans.deal, DEAL_PRICE),
             0.0, 0.0, p, lyDo, HistoryDealGetString(trans.deal, DEAL_COMMENT));
  }

//+------------------------------------------------------------------+
//| Cập nhật bảng khi không có tick (cuối tuần, mất kết nối...)      |
//+------------------------------------------------------------------+
void CapNhatBangKhongTick()
  {
   DemLenh(g_dem);
   g_choPhepVaoLenh = CheckRiskManager(g_lyDoKhoa);
   g_dbLast = 0;   // vẽ ngay, bỏ qua giới hạn 1 giây
   UpdateDashboard();
  }

void OnTimer()
  {
   //--- OnTick đã vẽ bảng trong 2 giây gần nhất thì bỏ qua
   if(g_dbLast != 0 && GetTickCount() - g_dbLast < 2000) return;
   CapNhatBangKhongTick();
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   CapNhatLenhTheoDoi();
   DemLenh(g_dem);
   g_choPhepVaoLenh = CheckRiskManager(g_lyDoKhoa);

   ManagePositions();

   ArrayResize(g_dsTinHieu, 0);
   CheckStrategy1();
   CheckStrategy2();
   CheckStrategy3();
   CheckStrategy4();
   if(ArraySize(g_dsTinHieu) > 0)
     {
      DemLenh(g_dem);   // đếm lại sau khi PP1 có thể vừa đóng giỏ
      XuLyDanhSachTinHieu();
     }

   UpdateDashboard();
  }
//+------------------------------------------------------------------+
