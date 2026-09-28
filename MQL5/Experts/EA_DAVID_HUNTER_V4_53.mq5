// David Hunter Ver1 - V4.53 TEST - BRK/PVT/ENG profiles + optional EMA trend-pullback method.
// V4.53: add EMA method (EMA20<50<200 trend, closed-bar momentum candle after a Stoch/RSI
//        pullback, SL = k x ATR). OFF by default (InpUseEMA=false); engine appended last so
//        engine indexes of the four existing profiles (and their open positions) are unchanged.
//        Default America session 13-21 server (20:00-04:00 VN), Europe 8-13.
// Broker positions are the single source of truth in both Demo/Real and Strategy Tester.
// Risk-based sizing, protective broker SL/TP, BE/trailing, and daily entry/loss limits.
// V4.48: fix stale position locking, remove virtual-order execution, persist management state and logs.
// V4.52: a lock raised at start-up for an unrecognised/unprotected position of this
//        Magic is released automatically once that position is closed.
// V4.51: one combined dashboard (top-left), header "DAVID HUNTER" + phone only.
// V4.50: persistent day/month P/L, DD and trade statistics rebuilt from MT5 history,
//        monthly log files, no daily entry-count cap, EA-only daily loss stop (15%),
//        persistent serious-error lock, redesigned dashboard (Ver1 - Thần Tài).
// V4.49: accept fill deviation at the 5.0 minimum-SL boundary without raising money risk,
//        recover automatically from transient broker rejections (reconcile before any new entry),
//        remove the retired EMA/ICT/MM/SMC/PVEMA/PIN/LQ methods; only BRK758/PVT880/ENG626/ENG636 remain.
#property copyright "David Hunter"
#property version "4.53"
#property strict
#include <Trade/Trade.mqh>
const ENUM_TIMEFRAMES LIVE_FALLBACK_TF = PERIOD_M1;
// V4.49: seconds to wait for an uncertain send (TIMEOUT/CONNECTION/PLACED) to show
// up as a position/deal before the signal is treated as not filled.
const int LIVE_RECONCILE_SECONDS = 15;

enum ENUM_CHE_DO_LENH
{
   MOT_LENH_DUY_NHAT = 0,          // Một lệnh duy nhất như bản cũ
   BA_PHUONG_PHAP_DOC_LAP = 1      // Các phương pháp chạy độc lập
};

enum ENUM_CHE_DO_KHOI_LUONG
{
   LOT_CO_DINH = 0,                       // Lot cố định
   LOT_THEO_PHAN_TRAM_TAI_KHOAN = 1,      // Theo % Equity tài khoản
   LOT_THEO_SO_TIEN_SL = 2                // Theo số tiền mất tối đa mỗi lần SL
};

enum ENUM_PV_HUONG_GIAO_DICH
{
   PV_CA_BUY_VA_SELL = 0,           // Cả Buy và Sell
   PV_CHI_BUY = 1,                  // Chỉ Buy
   PV_CHI_SELL = 2                  // Chỉ Sell
};

enum ENUM_PV_CACH_KET_HOP
{
   PV_MOI_PP_DOC_LAP = 0,           // Chỉ cần một phương pháp đủ điều kiện
   PV_TAT_CA_DONG_THUAN = 1         // Các phương pháp đang bật phải đồng thuận
};

// Giá trị số giữ nguyên như V4.48 để file SET cũ nạp đúng; lựa chọn Pin Bar (2) đã loại bỏ.
enum ENUM_PV_MAU_PRICE_ACTION
{
   PV_CA_BA_MAU = 0,                // Tất cả mẫu đang giữ (ENG và BRK)
   PV_CHI_NEN_NHAN_CHIM = 1,        // Chỉ nến nhấn chìm
   PV_CHI_PHA_DINH_DAY = 3          // Chỉ phá đỉnh/đáy
};

enum ENUM_PV_MUC_PIVOT
{
   PV_CHI_R2_S2 = 0,                // Chỉ R2/S2
   PV_R1_S1_VA_R2_S2 = 1,           // R1/S1 và R2/S2
   PV_TAT_CA_MUC = 2                // PP, R1/S1 và R2/S2
};

enum ENUM_PV_NGAY_GIAO_DICH
{
   PV_THU_HAI_DEN_THU_SAU = 0,      // Thứ Hai đến Thứ Sáu
   PV_THU_HAI_DEN_THU_BAY = 1,      // Thứ Hai đến Thứ Bảy
   PV_CA_BAY_NGAY = 2               // Cả bảy ngày
};

enum ENUM_MATRIX_SWAP
{
   MATRIX_SWAP_SAN = 0, // Ước tính theo thông số swap hiện tại của sàn
   MATRIX_SWAP_TAY = 1, // Nhập tiền swap / lot / đêm bằng tiền tài khoản
   MATRIX_SWAP_KHONG = 2 // Không tính swap (kết quả chưa gồm swap)
};
enum ENUM_PORTFOLIO_SESSION
{
   PORTFOLIO_SESSION_ALL = 0,       // Tất cả phiên
   PORTFOLIO_SESSION_ASIA = 1,      // Phiên Á
   PORTFOLIO_SESSION_EUROPE = 2,    // Phiên Âu
   PORTFOLIO_SESSION_AMERICA = 3    // Phiên Mỹ
};

input group "1. CẤU HÌNH CHUNG"
input ENUM_CHE_DO_LENH InpExecutionMode = BA_PHUONG_PHAP_DOC_LAP; // Chế độ lệnh
input bool InpChoPhepGiaoDichThat = true; // Công tắc cho phép gửi lệnh lên tài khoản thật
input ulong InpMagic = 348937; // Mã Magic riêng để nhận diện lệnh của EA
input bool InpMatrixLenhTester = true; // Cho phép đặt lệnh broker trong Strategy Tester
input bool InpUseAsia = true; // Bật phiên Á
input int InpAsiaStart = 0; // Giờ bắt đầu phiên Á (giờ máy chủ)
input int InpAsiaEnd = 8; // Giờ kết thúc phiên Á (giờ máy chủ)
input bool InpUseEurope = true; // Bật phiên Âu
input int InpEuropeStart = 8; // Giờ bắt đầu phiên Âu (giờ máy chủ)
input int InpEuropeEnd = 13; // Giờ kết thúc phiên Âu (giờ máy chủ)
input bool InpUseAmerica = true; // Bật phiên Mỹ
input int InpAmericaStart = 13; // Giờ bắt đầu phiên Mỹ (giờ máy chủ) - 13 = 20:00 giờ VN
input int InpAmericaEnd = 21; // Giờ kết thúc phiên Mỹ (giờ máy chủ) - 21 = 04:00 giờ VN
input bool InpPVChiTradeTrongGio = false; // Chỉ giao dịch trong khung giờ bên dưới
input int InpPVGioBatDau = 7; // Giờ bắt đầu giao dịch (giờ máy chủ)
input int InpPVGioKetThuc = 20; // Giờ kết thúc giao dịch (không bao gồm)
input ENUM_PV_NGAY_GIAO_DICH InpPVNgayGiaoDich = PV_THU_HAI_DEN_THU_SAU; // Ngày giao dịch
input int InpPVNgungTruocTinPhut = 30; // Dừng trước tin (phút) - CHƯA ĐƯỢC SỬ DỤNG trong logic
input int InpPVNgungSauTinPhut = 30; // Dừng sau tin (phút) - CHƯA ĐƯỢC SỬ DỤNG trong logic

input group "2. CÁC PHƯƠNG PHÁP ĐANG HOẠT ĐỘNG"
input bool InpUseBRK758 = true; // BRK 758: BUY/SELL, phiên Á, phá vùng 8 nến, không retest
input ENUM_PV_HUONG_GIAO_DICH InpBRK758Huong = PV_CA_BUY_VA_SELL; // Hướng BRK 758
input ENUM_PORTFOLIO_SESSION InpBRK758Phien = PORTFOLIO_SESSION_ASIA; // Phiên BRK 758
input bool InpUsePVT880 = true; // PVT 880: BUY/SELL, phiên Mỹ, M6, vùng Pivot 1.00
input ENUM_PV_HUONG_GIAO_DICH InpPVT880Huong = PV_CA_BUY_VA_SELL; // Hướng PVT 880
input ENUM_PORTFOLIO_SESSION InpPVT880Phien = PORTFOLIO_SESSION_AMERICA; // Phiên PVT 880
input bool InpUseENG626 = true; // ENG 626: BUY/SELL, phiên Á, ENG ATR 0.90, thân 1.30
input ENUM_PV_HUONG_GIAO_DICH InpENG626Huong = PV_CA_BUY_VA_SELL; // Hướng ENG 626
input ENUM_PORTFOLIO_SESSION InpENG626Phien = PORTFOLIO_SESSION_ASIA; // Phiên ENG 626
input bool InpUseENG636 = true; // ENG 636: SELL, phiên Mỹ, ENG ATR 0.90, thân 1.30
input ENUM_PV_HUONG_GIAO_DICH InpENG636Huong = PV_CHI_SELL; // Hướng ENG 636
input ENUM_PORTFOLIO_SESSION InpENG636Phien = PORTFOLIO_SESSION_AMERICA; // Phiên ENG 636
input bool InpUseEMA = false; // EMA: thuận xu hướng EMA20<50<200 (mặc định TẮT - test trên cent trước)
input ENUM_PV_HUONG_GIAO_DICH InpEMAHuong = PV_CA_BUY_VA_SELL; // Hướng EMA
input ENUM_PORTFOLIO_SESSION InpEMAPhien = PORTFOLIO_SESSION_ALL; // Phiên EMA (bot mẫu vào lệnh EMA lúc 07:00 và 10:50 giờ server)
input ENUM_TIMEFRAMES InpEMAKhung = PERIOD_M5; // EMA: khung tín hiệu
input int InpEMANhanh = 20; // EMA: chu kỳ EMA nhanh
input int InpEMAGiua = 50; // EMA: chu kỳ EMA giữa
input int InpEMACham = 200; // EMA: chu kỳ EMA chậm
input int InpEMAATRChuKy = 14; // EMA: chu kỳ ATR (thân nến và SL)
input double InpEMAHoiStoch = 55.0; // EMA: SELL cần Stoch >= mức này (BUY <= 100 - mức này)
input double InpEMARSIMin = 35.0; // EMA: SELL cần RSI từ (BUY: 100 - RSI max)
input double InpEMARSIMax = 50.0; // EMA: SELL cần RSI đến (BUY: 100 - RSI min)
input double InpEMAThanNenATR = 0.40; // EMA: thân nến vừa đóng tối thiểu (ATR)
input double InpEMASLTheoATR = 2.5; // EMA: SL = hệ số x ATR (vẫn bị giới hạn SL min/max chung)
input double InpEMATP2R = 3.0; // EMA: TP2 theo R
input bool InpUseENGModule = false; // Công tắc module ENG cũ - KHÔNG CÓ TÁC DỤNG (bật/tắt bằng ENG 626/636)
input bool InpUseBRKModule = false; // Công tắc module BRK cũ - KHÔNG CÓ TÁC DỤNG (bật/tắt bằng BRK 758)
input bool InpUsePVTModule = false; // Công tắc module PVT cũ - KHÔNG CÓ TÁC DỤNG (bật/tắt bằng PVT 880)
input ENUM_PV_HUONG_GIAO_DICH InpPVHuongGiaoDich = PV_CA_BUY_VA_SELL; // Hướng chung - bị thay bằng hướng riêng từng cấu hình
input ENUM_PV_CACH_KET_HOP InpPVCachKetHop = PV_MOI_PP_DOC_LAP; // Cách kết hợp - KHÔNG CÓ TÁC DỤNG (mỗi cấu hình chạy độc lập)
input ENUM_PV_MAU_PRICE_ACTION InpPVMauPriceAction = PV_CA_BA_MAU; // Mẫu Price Action - KHÔNG CÓ TÁC DỤNG (mỗi cấu hình chạy độc lập)
input int InpPVSoMauPAToiThieu = 1; // Số mẫu đồng thuận - chỉ dùng khi kết hợp đồng thuận
input ENUM_TIMEFRAMES InpPVKhungVaoLenh = PERIOD_M6; // Khung đặt SL khi kết hợp đồng thuận
input ENUM_TIMEFRAMES InpPVKhungNhanChim = PERIOD_M4; // ENG: khung thời gian nến nhấn chìm
input int InpPVATRNhanChim = 13; // ENG: chu kỳ ATR của nến nhấn chìm
input double InpPVNhanChimMinATR = 0.90; // ENG: biên độ nhấn chìm tối thiểu (ATR)
input double InpPVNhanChimMaxATR = 1.90; // ENG: biên độ nhấn chìm tối đa (ATR)
input double InpPVThanNhanChimSoVoiThanTruoc = 1.30; // ENG: tỷ lệ thân so với thân nến trước
input double InpPVDongCuaManhNhanChim = 0.50; // ENG: vị trí đóng cửa mạnh trong biên nến
input ENUM_TIMEFRAMES InpPVKhungBreakout = PERIOD_M4; // BRK: khung thời gian Breakout
input double InpPVThanBreakoutToiThieu = 0.50; // BRK: thân nến phá vỡ tối thiểu (tỷ lệ nến)
input int InpPVSoNenVungBreakout = 8; // BRK: số nến tạo vùng phá vỡ (BRK 758)
input double InpPVDemBreakoutGia = 1.00; // BRK: đệm phá đỉnh/đáy (giá)
input bool InpPVChoRetest = false; // BRK: chờ retest sau phá vỡ (BRK 758 tắt)
input double InpPVDungSaiRetestGia = 0.20; // BRK: dung sai vùng retest (giá)
input ENUM_TIMEFRAMES InpPVKhungTinhPivot = PERIOD_M15; // PVT: khung tính PP/R/S từ nến trước
input ENUM_TIMEFRAMES InpPVKhungXacNhanPivot = PERIOD_M6; // PVT: khung nến xác nhận (PVT 880 dùng M6)
input double InpPVBKPVungPivotGia = 1.00; // PVT: bán kính vùng Pivot (giá)
input bool InpPVYeuCauNenDungHuong = true; // PVT: yêu cầu nến xác nhận đúng hướng
input ENUM_PV_MUC_PIVOT InpPVMucPivot = PV_CHI_R2_S2; // PVT: các mức Pivot sử dụng

input group "3. QUẢN TRỊ VỐN VÀ GIỚI HẠN RỦI RO"
input ENUM_CHE_DO_KHOI_LUONG InpVolumeMode = LOT_THEO_PHAN_TRAM_TAI_KHOAN; // Chế độ khối lượng; mặc định rủi ro theo % Equity mỗi SL
input double InpGiaTriKhoiLuong = 1.0; // Khi chọn % Equity: 1.0 = rủi ro mục tiêu 1% Equity tại SL ban đầu
input int InpMaxIndependentPositions = 10; // Tổng vị thế tối đa do EA quản lý
input int InpMatrixLenhMoiPP = 1; // Số vị thế tối đa mỗi phương pháp trong mỗi tài khoản
input int InpSoLenhToiDaMoiNgay = 20; // KHÔNG CÒN TÁC DỤNG từ V4.50: không giới hạn số lệnh mới/ngày (giữ để nạp SET cũ)
input double InpDailyLossPct = 15.0; // Dừng mở lệnh mới khi lỗ ngày của EA đạt % Balance đầu ngày; không đóng lệnh đang mở
input double InpTruotGiaToiDaGia = 0.30; // Trượt giá tối đa khi gửi lệnh (giá XAUUSD)
input double InpSpreadToiDaGia = 0.50; // Spread tối đa theo giá; 0 = tắt
input double InpMinSLPriceDistance = 5.0; // Khoảng SL tối thiểu cho mọi lệnh (giá)
input double InpMaxSLPriceDistance = 20.0; // Khoảng SL tối đa chung cho mọi lệnh (giá)
input int InpPVThuaLienTiepToiDa = 0; // Giới hạn thua liên tiếp - CHƯA ĐƯỢC SỬ DỤNG trong logic
input double InpMatrixHeSoTienThat = 0.0; // Đơn vị tài khoản / 1 tiền thật; 0 = tự nhận USD=1, USC/USDC=100
input double InpMatrixPhiKhuHoiLot = 0.0; // Commission khứ hồi / lot theo tiền tài khoản (USD hoặc USC)

input group "4. QUẢN LÝ VỊ THẾ: SL/TP, BE VÀ TRAILING"
input int InpPVSoNenTimSL = 5; // Số nến đã đóng tìm đỉnh/đáy đặt SL
input double InpPVDemSLGia = 1.50; // Đệm SL ngoài đỉnh/đáy (giá)
input double InpPVTP2R = 2.00; // TP2 theo R, luôn lớn hơn TP1
input double InpPVRRToiThieu = 1.0; // RR hiệu dụng tối thiểu (tính cả chốt một phần TP1)
input double InpPVBEKhiLoiGia = 5.00; // Dời BE khi lời (giá) - CHƯA ĐƯỢC SỬ DỤNG trong logic
input bool InpUseTP1Partial = true; // Bật chốt một phần tại TP1
input double InpTP1AtR = 1.0; // Vị trí TP1 chung cho mọi phương pháp, tính theo R
input double InpTP1ClosePct = 50.0; // Tỷ lệ khối lượng chốt tại TP1 cho mọi phương pháp (%)
input bool InpUseTrailing = true; // Bật dời SL tự động
input double InpTrailStartR = 1.0; // Bắt đầu trailing khi đạt số R này
input double InpTrailDistanceR = 1.0; // Khoảng trailing tính theo R
input double InpTrailStepGia = 0.01; // Bước tối thiểu mỗi lần dời SL (giá)

input group "5. GHI LOG VÀ THIẾT LẬP VẬN HÀNH"
input bool InpGhiTinHieuBiLoai = false; // Ghi chi tiết tín hiệu bị loại (tốn dung lượng)
input bool InpMatrixGhiNenM1 = true; // Xuất nến M1 một lần, dùng chung mọi cấu hình
input int InpMatrixGhiEquityPhut = 60; // Khoảng ghi đường vốn (phút); 0 = tắt file đường vốn
input bool InpMatrixBangNhe = true; // Hiện bảng trạng thái và thống kê trên biểu đồ
input bool InpMoKhoaLoiNghiemTrong = false; // Mở khóa lỗi nghiêm trọng đã lưu khi khởi động (bật một lần sau khi đã kiểm tra, rồi tắt)
input bool InpAnalyzeSL = false; // Tạo chỉ báo phân tích SL - CHƯA CÓ BỘ ĐỌC KẾT QUẢ
input ENUM_TIMEFRAMES InpSLAnalysisTF = PERIOD_M15; // Khung phân tích nguyên nhân SL
input int InpSLAnalysisATRPeriod = 14; // Chu kỳ ATR phân tích SL
input int InpSLAnalysisFastEMA = 34; // EMA nhanh phân tích xu hướng
input int InpSLAnalysisSlowEMA = 89; // EMA chậm phân tích xu hướng
input int InpMatrixSoLenhTinCay = 100; // Số lệnh đóng tối thiểu để xét hạng hiệu quả (Tester)
input int InpMatrixSoThangTinCay = 3; // Số tháng dữ liệu tối thiểu (tháng không lệnh vẫn tính)
input datetime InpMatrixTuNgayKiemChung = 0; // Mốc tách dữ liệu kiểm chứng; 0 = chưa tách, chỉ thăm dò
input string InpMatrixThuMuc = "DavidHunter_V443_Live_Portfolio"; // Giữ tương thích; LOG luôn dùng thư mục DavidHunterVer1
input ENUM_MATRIX_SWAP InpMatrixSwap = MATRIX_SWAP_SAN; // Cách tính swap mô phỏng
input double InpMatrixSwapBuy = 0.0; // Swap BUY / lot / đêm nếu nhập tay; số âm là phí
input double InpMatrixSwapSell = 0.0; // Swap SELL / lot / đêm nếu nhập tay
input int InpMatrixViThamChieu = 0; // Giữ tương thích file SET; LIVE luôn dùng tài khoản broker
input int InpMatrixToiDaVi = 1; // Giữ tương thích; không còn giới hạn ví mô phỏng
input int InpMatrixToiDaBo = 4; // Giữ tương thích; số tổ hợp lưới tối đa (lưới không chạy ở LIVE)
input bool InpMatrixTachHuongPhien = false; // Giữ tương thích; không phân bổ ví
input bool InpMatrixQuetLuoi = false; // Giữ tương thích; LIVE không quét lưới
input string InpLuoiENG = ""; // Giữ tương thích; lưới ENG không chạy ở LIVE
input string InpLuoiBRK = ""; // Giữ tương thích; lưới BRK không chạy ở LIVE
input string InpLuoiPVT = ""; // Giữ tương thích; lưới PVT không chạy ở LIVE
input double InpMatrixVonMoiVi = 0.0; // Giữ tương thích; không dùng cho LIVE REAL
input double InpMatrixTruotGiaVao = 0.30; // Giữ tương thích; LIVE dùng trượt giá tối đa ở nhóm 3

bool MatrixValidTF(const int v)
{
   return v==0 || v==1 || v==2 || v==3 || v==4 || v==5 || v==6 || v==10 ||
          v==12 || v==15 || v==20 || v==30 || v==16385 || v==16386 ||
          v==16387 || v==16388 || v==16390 || v==16392 || v==16396 ||
          v==16408 || v==32769 || v==49153;
}

struct MatrixConfig
{
   ENUM_CHE_DO_LENH InpExecutionMode;
   int InpMaxIndependentPositions;
   bool InpUseEMAModule;
   ENUM_TIMEFRAMES InpEMAKhung;
   int InpEMANhanh;
   int InpEMAGiua;
   int InpEMACham;
   int InpEMAATRChuKy;
   double InpEMAHoiStoch;
   double InpEMARSIMin;
   double InpEMARSIMax;
   double InpEMAThanNenATR;
   double InpEMASLTheoATR;
   bool InpUseENGModule;
   bool InpUseBRKModule;
   bool InpUsePVTModule;
   ENUM_PV_HUONG_GIAO_DICH InpPVHuongGiaoDich;
   ENUM_PV_CACH_KET_HOP InpPVCachKetHop;
   int InpPVSoNenTimSL;
   double InpPVDemSLGia;
   double InpPVBEKhiLoiGia;
   double InpPVTP2R;
   double InpPVRRToiThieu;
   int InpPVThuaLienTiepToiDa;
   ENUM_TIMEFRAMES InpPVKhungVaoLenh;
   ENUM_PV_MAU_PRICE_ACTION InpPVMauPriceAction;
   int InpPVSoMauPAToiThieu;
   ENUM_TIMEFRAMES InpPVKhungNhanChim;
   int InpPVATRNhanChim;
   double InpPVNhanChimMinATR;
   double InpPVNhanChimMaxATR;
   double InpPVThanNhanChimSoVoiThanTruoc;
   double InpPVDongCuaManhNhanChim;
   ENUM_TIMEFRAMES InpPVKhungBreakout;
   double InpPVThanBreakoutToiThieu;
   int InpPVSoNenVungBreakout;
   double InpPVDemBreakoutGia;
   bool InpPVChoRetest;
   double InpPVDungSaiRetestGia;
   ENUM_TIMEFRAMES InpPVKhungTinhPivot;
   ENUM_TIMEFRAMES InpPVKhungXacNhanPivot;
   double InpPVBKPVungPivotGia;
   bool InpPVYeuCauNenDungHuong;
   ENUM_PV_MUC_PIVOT InpPVMucPivot;
   int InpPVNgungTruocTinPhut;
   int InpPVNgungSauTinPhut;
   bool InpPVChiTradeTrongGio;
   int InpPVGioBatDau;
   int InpPVGioKetThuc;
   ENUM_PV_NGAY_GIAO_DICH InpPVNgayGiaoDich;
   ENUM_CHE_DO_KHOI_LUONG InpVolumeMode;
   double InpGiaTriKhoiLuong;
   int InpSoLenhToiDaMoiNgay;
   double InpDailyLossPct;
   ulong InpMagic;
   double InpTruotGiaToiDaGia;
   double InpSpreadToiDaGia;
   double InpMinSLPriceDistance;
   double InpMaxSLPriceDistance;
   bool InpUseTP1Partial;
   double InpTP1AtR;
   double InpTP1ClosePct;
   bool InpUseTrailing;
   double InpTrailStartR;
   double InpTrailDistanceR;
   double InpTrailStepGia;
   bool InpUseAsia;
   int InpAsiaStart;
   int InpAsiaEnd;
   bool InpUseEurope;
   int InpEuropeStart;
   int InpEuropeEnd;
   bool InpUseAmerica;
   int InpAmericaStart;
   int InpAmericaEnd;
   bool InpAnalyzeSL;
   ENUM_TIMEFRAMES InpSLAnalysisTF;
   int InpSLAnalysisATRPeriod;
   int InpSLAnalysisFastEMA;
   int InpSLAnalysisSlowEMA;
   bool InpGhiTinHieuBiLoai;
};
void MatrixBaseConfig(MatrixConfig &c)
{
   c.InpExecutionMode = InpExecutionMode;
   c.InpMaxIndependentPositions = InpMaxIndependentPositions;
   c.InpUseEMAModule = false;
   c.InpEMAKhung = InpEMAKhung;
   c.InpEMANhanh = InpEMANhanh;
   c.InpEMAGiua = InpEMAGiua;
   c.InpEMACham = InpEMACham;
   c.InpEMAATRChuKy = InpEMAATRChuKy;
   c.InpEMAHoiStoch = InpEMAHoiStoch;
   c.InpEMARSIMin = InpEMARSIMin;
   c.InpEMARSIMax = InpEMARSIMax;
   c.InpEMAThanNenATR = InpEMAThanNenATR;
   c.InpEMASLTheoATR = InpEMASLTheoATR;
   c.InpUseENGModule = InpUseENGModule;
   c.InpUseBRKModule = InpUseBRKModule;
   c.InpUsePVTModule = InpUsePVTModule;
   c.InpPVHuongGiaoDich = InpPVHuongGiaoDich;
   c.InpPVCachKetHop = InpPVCachKetHop;
   c.InpPVSoNenTimSL = InpPVSoNenTimSL;
   c.InpPVDemSLGia = InpPVDemSLGia;
   c.InpPVBEKhiLoiGia = InpPVBEKhiLoiGia;
   c.InpPVTP2R = InpPVTP2R;
   c.InpPVRRToiThieu = InpPVRRToiThieu;
   c.InpPVThuaLienTiepToiDa = InpPVThuaLienTiepToiDa;
   c.InpPVKhungVaoLenh = InpPVKhungVaoLenh;
   c.InpPVMauPriceAction = InpPVMauPriceAction;
   c.InpPVSoMauPAToiThieu = InpPVSoMauPAToiThieu;
   c.InpPVKhungNhanChim = InpPVKhungNhanChim;
   c.InpPVATRNhanChim = InpPVATRNhanChim;
   c.InpPVNhanChimMinATR = InpPVNhanChimMinATR;
   c.InpPVNhanChimMaxATR = InpPVNhanChimMaxATR;
   c.InpPVThanNhanChimSoVoiThanTruoc = InpPVThanNhanChimSoVoiThanTruoc;
   c.InpPVDongCuaManhNhanChim = InpPVDongCuaManhNhanChim;
   c.InpPVKhungBreakout = InpPVKhungBreakout;
   c.InpPVThanBreakoutToiThieu = InpPVThanBreakoutToiThieu;
   c.InpPVSoNenVungBreakout = InpPVSoNenVungBreakout;
   c.InpPVDemBreakoutGia = InpPVDemBreakoutGia;
   c.InpPVChoRetest = InpPVChoRetest;
   c.InpPVDungSaiRetestGia = InpPVDungSaiRetestGia;
   c.InpPVKhungTinhPivot = InpPVKhungTinhPivot;
   c.InpPVKhungXacNhanPivot = InpPVKhungXacNhanPivot;
   c.InpPVBKPVungPivotGia = InpPVBKPVungPivotGia;
   c.InpPVYeuCauNenDungHuong = InpPVYeuCauNenDungHuong;
   c.InpPVMucPivot = InpPVMucPivot;
   c.InpPVNgungTruocTinPhut = InpPVNgungTruocTinPhut;
   c.InpPVNgungSauTinPhut = InpPVNgungSauTinPhut;
   c.InpPVChiTradeTrongGio = InpPVChiTradeTrongGio;
   c.InpPVGioBatDau = InpPVGioBatDau;
   c.InpPVGioKetThuc = InpPVGioKetThuc;
   c.InpPVNgayGiaoDich = InpPVNgayGiaoDich;
   c.InpVolumeMode = InpVolumeMode;
   c.InpGiaTriKhoiLuong = InpGiaTriKhoiLuong;
   c.InpSoLenhToiDaMoiNgay = InpSoLenhToiDaMoiNgay;
   c.InpDailyLossPct = InpDailyLossPct;
   c.InpMagic = InpMagic;
   c.InpTruotGiaToiDaGia = InpTruotGiaToiDaGia;
   c.InpSpreadToiDaGia = InpSpreadToiDaGia;
   c.InpMinSLPriceDistance = InpMinSLPriceDistance;
   c.InpMaxSLPriceDistance = InpMaxSLPriceDistance;
   c.InpUseTP1Partial = InpUseTP1Partial;
   c.InpTP1AtR = InpTP1AtR;
   c.InpTP1ClosePct = InpTP1ClosePct;
   c.InpUseTrailing = InpUseTrailing;
   c.InpTrailStartR = InpTrailStartR;
   c.InpTrailDistanceR = InpTrailDistanceR;
   c.InpTrailStepGia = InpTrailStepGia;
   c.InpUseAsia = InpUseAsia;
   c.InpAsiaStart = InpAsiaStart;
   c.InpAsiaEnd = InpAsiaEnd;
   c.InpUseEurope = InpUseEurope;
   c.InpEuropeStart = InpEuropeStart;
   c.InpEuropeEnd = InpEuropeEnd;
   c.InpUseAmerica = InpUseAmerica;
   c.InpAmericaStart = InpAmericaStart;
   c.InpAmericaEnd = InpAmericaEnd;
   c.InpAnalyzeSL = InpAnalyzeSL;
   c.InpSLAnalysisTF = InpSLAnalysisTF;
   c.InpSLAnalysisATRPeriod = InpSLAnalysisATRPeriod;
   c.InpSLAnalysisFastEMA = InpSLAnalysisFastEMA;
   c.InpSLAnalysisSlowEMA = InpSLAnalysisSlowEMA;
   c.InpGhiTinHieuBiLoai = InpGhiTinHieuBiLoai;
}
bool MatrixSetValue(MatrixConfig &c,const string key,const double value)
{
   if(key=="InpPVSoNenTimSL") { if(value!=MathFloor(value)) return false; c.InpPVSoNenTimSL=(int)value; return true; }
   if(key=="InpPVDemSLGia") { c.InpPVDemSLGia=(double)value; return true; }
   if(key=="InpPVKhungNhanChim") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungNhanChim=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVATRNhanChim") { if(value!=MathFloor(value)) return false; c.InpPVATRNhanChim=(int)value; return true; }
   if(key=="InpPVNhanChimMaxATR") { c.InpPVNhanChimMaxATR=(double)value; return true; }
   if(key=="InpPVDongCuaManhNhanChim") { c.InpPVDongCuaManhNhanChim=(double)value; return true; }
   if(key=="InpPVKhungBreakout") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungBreakout=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVThanBreakoutToiThieu") { c.InpPVThanBreakoutToiThieu=(double)value; return true; }
   if(key=="InpPVDemBreakoutGia") { c.InpPVDemBreakoutGia=(double)value; return true; }
   if(key=="InpPVDungSaiRetestGia") { c.InpPVDungSaiRetestGia=(double)value; return true; }
   if(key=="InpPVKhungTinhPivot") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungTinhPivot=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVYeuCauNenDungHuong") { if(value!=0.0 && value!=1.0) return false; c.InpPVYeuCauNenDungHuong=(bool)value; return true; }
   if(key=="InpPVMucPivot") { if(value!=MathFloor(value)) return false; if(value<0 || value>2) return false; c.InpPVMucPivot=(ENUM_PV_MUC_PIVOT)value; return true; }
   if(key=="InpPVChiTradeTrongGio") { if(value!=0.0 && value!=1.0) return false; c.InpPVChiTradeTrongGio=(bool)value; return true; }
   if(key=="InpPVGioBatDau") { if(value!=MathFloor(value)) return false; c.InpPVGioBatDau=(int)value; return true; }
   if(key=="InpPVGioKetThuc") { if(value!=MathFloor(value)) return false; c.InpPVGioKetThuc=(int)value; return true; }
   if(key=="InpPVNgayGiaoDich") { if(value!=MathFloor(value)) return false; if(value<0 || value>2) return false; c.InpPVNgayGiaoDich=(ENUM_PV_NGAY_GIAO_DICH)value; return true; }
   if(key=="InpAsiaStart") { if(value!=MathFloor(value)) return false; c.InpAsiaStart=(int)value; return true; }
   if(key=="InpAsiaEnd") { if(value!=MathFloor(value)) return false; c.InpAsiaEnd=(int)value; return true; }
   if(key=="InpEuropeStart") { if(value!=MathFloor(value)) return false; c.InpEuropeStart=(int)value; return true; }
   if(key=="InpEuropeEnd") { if(value!=MathFloor(value)) return false; c.InpEuropeEnd=(int)value; return true; }
   if(key=="InpAmericaStart") { if(value!=MathFloor(value)) return false; c.InpAmericaStart=(int)value; return true; }
   if(key=="InpAmericaEnd") { if(value!=MathFloor(value)) return false; c.InpAmericaEnd=(int)value; return true; }
   return false;
}
string MatrixConfigText(const MatrixConfig &c)
{
   string s="";
   s += "InpExecutionMode=" + IntegerToString((long)c.InpExecutionMode) + "|";
   s += "InpMaxIndependentPositions=" + IntegerToString((long)c.InpMaxIndependentPositions) + "|";
   s += "InpUseEMAModule=" + (c.InpUseEMAModule?"true":"false") + "|";
   s += "InpUseENGModule=" + (c.InpUseENGModule?"true":"false") + "|";
   s += "InpUseBRKModule=" + (c.InpUseBRKModule?"true":"false") + "|";
   s += "InpUsePVTModule=" + (c.InpUsePVTModule?"true":"false") + "|";
   s += "InpPVHuongGiaoDich=" + IntegerToString((long)c.InpPVHuongGiaoDich) + "|";
   s += "InpPVCachKetHop=" + IntegerToString((long)c.InpPVCachKetHop) + "|";
   s += "InpPVSoNenTimSL=" + IntegerToString((long)c.InpPVSoNenTimSL) + "|";
   s += "InpPVDemSLGia=" + DoubleToString(c.InpPVDemSLGia,10) + "|";
   s += "InpPVBEKhiLoiGia=" + DoubleToString(c.InpPVBEKhiLoiGia,10) + "|";
   s += "InpPVTP2R=" + DoubleToString(c.InpPVTP2R,10) + "|";
   s += "InpPVRRToiThieu=" + DoubleToString(c.InpPVRRToiThieu,10) + "|";
   s += "InpPVThuaLienTiepToiDa=" + IntegerToString((long)c.InpPVThuaLienTiepToiDa) + "|";
   s += "InpPVKhungVaoLenh=" + IntegerToString((long)c.InpPVKhungVaoLenh) + "|";
   s += "InpPVMauPriceAction=" + IntegerToString((long)c.InpPVMauPriceAction) + "|";
   s += "InpPVSoMauPAToiThieu=" + IntegerToString((long)c.InpPVSoMauPAToiThieu) + "|";
   s += "InpPVKhungNhanChim=" + IntegerToString((long)c.InpPVKhungNhanChim) + "|";
   s += "InpPVATRNhanChim=" + IntegerToString((long)c.InpPVATRNhanChim) + "|";
   s += "InpPVNhanChimMinATR=" + DoubleToString(c.InpPVNhanChimMinATR,10) + "|";
   s += "InpPVNhanChimMaxATR=" + DoubleToString(c.InpPVNhanChimMaxATR,10) + "|";
   s += "InpPVThanNhanChimSoVoiThanTruoc=" + DoubleToString(c.InpPVThanNhanChimSoVoiThanTruoc,10) + "|";
   s += "InpPVDongCuaManhNhanChim=" + DoubleToString(c.InpPVDongCuaManhNhanChim,10) + "|";
   s += "InpPVKhungBreakout=" + IntegerToString((long)c.InpPVKhungBreakout) + "|";
   s += "InpPVThanBreakoutToiThieu=" + DoubleToString(c.InpPVThanBreakoutToiThieu,10) + "|";
   s += "InpPVSoNenVungBreakout=" + IntegerToString((long)c.InpPVSoNenVungBreakout) + "|";
   s += "InpPVDemBreakoutGia=" + DoubleToString(c.InpPVDemBreakoutGia,10) + "|";
   s += "InpPVChoRetest=" + (c.InpPVChoRetest?"true":"false") + "|";
   s += "InpPVDungSaiRetestGia=" + DoubleToString(c.InpPVDungSaiRetestGia,10) + "|";
   s += "InpPVKhungTinhPivot=" + IntegerToString((long)c.InpPVKhungTinhPivot) + "|";
   s += "InpPVKhungXacNhanPivot=" + IntegerToString((long)c.InpPVKhungXacNhanPivot) + "|";
   s += "InpPVBKPVungPivotGia=" + DoubleToString(c.InpPVBKPVungPivotGia,10) + "|";
   s += "InpPVYeuCauNenDungHuong=" + (c.InpPVYeuCauNenDungHuong?"true":"false") + "|";
   s += "InpPVMucPivot=" + IntegerToString((long)c.InpPVMucPivot) + "|";
   s += "InpPVNgungTruocTinPhut=" + IntegerToString((long)c.InpPVNgungTruocTinPhut) + "|";
   s += "InpPVNgungSauTinPhut=" + IntegerToString((long)c.InpPVNgungSauTinPhut) + "|";
   s += "InpPVChiTradeTrongGio=" + (c.InpPVChiTradeTrongGio?"true":"false") + "|";
   s += "InpPVGioBatDau=" + IntegerToString((long)c.InpPVGioBatDau) + "|";
   s += "InpPVGioKetThuc=" + IntegerToString((long)c.InpPVGioKetThuc) + "|";
   s += "InpPVNgayGiaoDich=" + IntegerToString((long)c.InpPVNgayGiaoDich) + "|";
   s += "InpVolumeMode=" + IntegerToString((long)c.InpVolumeMode) + "|";
   s += "InpGiaTriKhoiLuong=" + DoubleToString(c.InpGiaTriKhoiLuong,10) + "|";
   s += "InpSoLenhToiDaMoiNgay=" + IntegerToString((long)c.InpSoLenhToiDaMoiNgay) + "|";
   s += "InpDailyLossPct=" + DoubleToString(c.InpDailyLossPct,10) + "|";
   s += "InpMagic=" + IntegerToString((long)c.InpMagic) + "|";
   s += "InpTruotGiaToiDaGia=" + DoubleToString(c.InpTruotGiaToiDaGia,10) + "|";
   s += "InpSpreadToiDaGia=" + DoubleToString(c.InpSpreadToiDaGia,10) + "|";
   s += "InpMinSLPriceDistance=" + DoubleToString(c.InpMinSLPriceDistance,10) + "|";
   s += "InpMaxSLPriceDistance=" + DoubleToString(c.InpMaxSLPriceDistance,10) + "|";
   s += "InpUseTP1Partial=" + (c.InpUseTP1Partial?"true":"false") + "|";
   s += "InpTP1AtR=" + DoubleToString(c.InpTP1AtR,10) + "|";
   s += "InpTP1ClosePct=" + DoubleToString(c.InpTP1ClosePct,10) + "|";
   s += "InpUseTrailing=" + (c.InpUseTrailing?"true":"false") + "|";
   s += "InpTrailStartR=" + DoubleToString(c.InpTrailStartR,10) + "|";
   s += "InpTrailDistanceR=" + DoubleToString(c.InpTrailDistanceR,10) + "|";
   s += "InpTrailStepGia=" + DoubleToString(c.InpTrailStepGia,10) + "|";
   s += "InpUseAsia=" + (c.InpUseAsia?"true":"false") + "|";
   s += "InpAsiaStart=" + IntegerToString((long)c.InpAsiaStart) + "|";
   s += "InpAsiaEnd=" + IntegerToString((long)c.InpAsiaEnd) + "|";
   s += "InpUseEurope=" + (c.InpUseEurope?"true":"false") + "|";
   s += "InpEuropeStart=" + IntegerToString((long)c.InpEuropeStart) + "|";
   s += "InpEuropeEnd=" + IntegerToString((long)c.InpEuropeEnd) + "|";
   s += "InpUseAmerica=" + (c.InpUseAmerica?"true":"false") + "|";
   s += "InpAmericaStart=" + IntegerToString((long)c.InpAmericaStart) + "|";
   s += "InpAmericaEnd=" + IntegerToString((long)c.InpAmericaEnd) + "|";
   s += "InpAnalyzeSL=" + (c.InpAnalyzeSL?"true":"false") + "|";
   s += "InpSLAnalysisTF=" + IntegerToString((long)c.InpSLAnalysisTF) + "|";
   s += "InpSLAnalysisATRPeriod=" + IntegerToString((long)c.InpSLAnalysisATRPeriod) + "|";
   s += "InpSLAnalysisFastEMA=" + IntegerToString((long)c.InpSLAnalysisFastEMA) + "|";
   s += "InpSLAnalysisSlowEMA=" + IntegerToString((long)c.InpSLAnalysisSlowEMA) + "|";
   s += "InpGhiTinHieuBiLoai=" + (c.InpGhiTinHieuBiLoai?"true":"false") + "|";
   return s;
}
void MatrixWriteDictionary(const int h)
{
   FileWrite(h,"InpMaxIndependentPositions","Tổng vị thế tối đa trong một tài khoản mô phỏng","int","10","NO");
   FileWrite(h,"InpPVSoNenTimSL","Số nến tìm đỉnh/đáy đặt SL","int","5","YES");
   FileWrite(h,"InpPVDemSLGia","Đệm SL ngoài đỉnh/đáy (giá)","double","1.50","YES");
   FileWrite(h,"InpPVKhungNhanChim","Khung thời gian nến nhấn chìm","ENUM_TIMEFRAMES","PERIOD_M4","YES");
   FileWrite(h,"InpPVATRNhanChim","Chu kỳ ATR của nến nhấn chìm","int","13","YES");
   FileWrite(h,"InpPVNhanChimMinATR","Ngưỡng ENG 626/636 theo ATR","double","0.90","NO");
   FileWrite(h,"InpPVNhanChimMaxATR","Biên độ nhấn chìm tối đa (ATR)","double","1.90","YES");
   FileWrite(h,"InpPVThanNhanChimSoVoiThanTruoc","Tỷ lệ thân ENG 626/636 so với nến trước","double","1.30","NO");
   FileWrite(h,"InpPVDongCuaManhNhanChim","Vị trí đóng cửa mạnh của nến nhấn chìm","double","0.50","YES");
   FileWrite(h,"InpPVKhungBreakout","Khung thời gian Breakout","ENUM_TIMEFRAMES","PERIOD_M4","YES");
   FileWrite(h,"InpPVThanBreakoutToiThieu","Thân nến phá vỡ tối thiểu (tỷ lệ nến)","double","0.50","YES");
   FileWrite(h,"InpPVSoNenVungBreakout","Số nến vùng BRK 758, mặc định giữ cấu hình đã chọn","int","8","NO");
   FileWrite(h,"InpPVDemBreakoutGia","Đệm phá đỉnh/đáy (giá)","double","1.00","YES");
   FileWrite(h,"InpPVChoRetest","Chờ retest BRK 758, mặc định tắt theo cấu hình đã chọn","bool","false","NO");
   FileWrite(h,"InpPVDungSaiRetestGia","Dung sai vùng retest (giá)","double","0.20","YES");
   FileWrite(h,"InpPVKhungTinhPivot","Khung tính PP/R/S từ nến trước","ENUM_TIMEFRAMES","PERIOD_M15","YES");
   FileWrite(h,"InpPVKhungXacNhanPivot","Khung xác nhận PVT 880, mặc định khớp cấu hình đã chọn","ENUM_TIMEFRAMES","PERIOD_M6","NO");
   FileWrite(h,"InpPVBKPVungPivotGia","Bán kính vùng Pivot PVT 880, mặc định khớp cấu hình đã chọn","double","1.00","NO");
   FileWrite(h,"InpPVYeuCauNenDungHuong","Yêu cầu nến xác nhận đúng hướng","bool","true","YES");
   FileWrite(h,"InpPVMucPivot","Các mức Pivot sử dụng","ENUM_PV_MUC_PIVOT","PV_CHI_R2_S2","YES");
   FileWrite(h,"InpPVChiTradeTrongGio","Chỉ giao dịch trong khung giờ bên dưới","bool","false","YES");
   FileWrite(h,"InpPVGioBatDau","Giờ bắt đầu giao dịch (giờ máy chủ)","int","7","YES");
   FileWrite(h,"InpPVGioKetThuc","Giờ kết thúc giao dịch (không bao gồm)","int","20","YES");
   FileWrite(h,"InpPVNgayGiaoDich","Ngày giao dịch","ENUM_PV_NGAY_GIAO_DICH","PV_THU_HAI_DEN_THU_SAU","YES");
   FileWrite(h,"InpVolumeMode","Chế độ lot: cố định / % Equity / tiền thật mỗi SL","ENUM_CHE_DO_KHOI_LUONG","LOT_THEO_PHAN_TRAM_TAI_KHOAN","NO");
   FileWrite(h,"InpGiaTriKhoiLuong","Khi chọn % Equity: rủi ro mục tiêu mỗi SL","double","1.0","NO");
   FileWrite(h,"InpSoLenhToiDaMoiNgay","Không còn tác dụng từ V4.50 (không giới hạn lệnh/ngày)","int","20","NO");
   FileWrite(h,"InpDailyLossPct","Giới hạn lỗ ngày của EA (% Balance đầu ngày)","double","15.0","NO");
   FileWrite(h,"InpMagic","Mã Magic của lệnh tham chiếu trong Tester","ulong","348937","NO");
   FileWrite(h,"InpSpreadToiDaGia","Spread tối đa theo giá, 0=tắt","double","0.50","NO");
   FileWrite(h,"InpUseAsia","Bật phiên Á","bool","true","NO");
   FileWrite(h,"InpAsiaStart","Giờ bắt đầu phiên Á","int","0","YES");
   FileWrite(h,"InpAsiaEnd","Giờ kết thúc phiên Á","int","8","YES");
   FileWrite(h,"InpUseEurope","Bật phiên Âu","bool","true","NO");
   FileWrite(h,"InpEuropeStart","Giờ bắt đầu phiên Âu","int","8","YES");
   FileWrite(h,"InpEuropeEnd","Giờ kết thúc phiên Âu","int","13","YES");
   FileWrite(h,"InpUseAmerica","Bật phiên Mỹ","bool","true","NO");
   FileWrite(h,"InpAmericaStart","Giờ bắt đầu phiên Mỹ","int","13","YES");
   FileWrite(h,"InpAmericaEnd","Giờ kết thúc phiên Mỹ","int","21","YES");
   FileWrite(h,"InpGhiTinHieuBiLoai","Ghi chi tiết tín hiệu bị loại (tốn dung lượng)","bool","false","NO");
}




struct MXStats
{
   int trades, wins, losses, flats, streak, maxStreak;
   double net, grossWin, grossLoss;
};
struct MXWallet
{
   int engine, direction, session, open, dayEntries, forced, rejected, nativeErrors;
   int openFamily[10];
   bool listed, stopped;
   double initial, balance, equity, peak, ddMoney, ddPct, floating, margin;
   double dayStart, commission, swap, lots;
   MXStats all, train, holdout;
};
struct MXPosition
{
   int wallet, engine, family;
   long id;
   bool buy, partialDone;
   string method;
   datetime signalTime, opened;
   double entry, initialSL, sl, tp1, tp2, risk;
   double initialLot, left, part, net, mfe, mae, margin;
};
struct MXNative
{
   ulong ticket;
   long shadowID;
   int engine;
   string method;
   bool buy, partialDone;
   double entry, risk, tp1, tp2, part;
   double tp1Base;        // V4.49: volume right before the last TP1 request (runtime only)
   ulong tp1RetryTick;    // V4.49: no TP1 resend before this tick count after an unknown result
};
struct MXMonth
{
   double net, startEquity, endEquity, peak, ddPct;
   int trades, wins;
};
struct MXAxis
{
   string name;
   double values[];
};

void MatrixSignal(const int engine,const int family,const bool isBase,
                  const string method,const bool buy,const datetime signalTime,
                  const ENUM_TIMEFRAMES timeframe,const double entry,const double sl,
                  const double tp,const string source,const string details);
void MatrixEvent(const int engine,const string method,const string eventName,
                 const string status,const string reason,const datetime signalTime,
                 const string details);

class CDHSignalEngine
{
public:
   MatrixConfig cfg;
   int engineID, family;
   bool isBase;
   datetime nextWake;
   CTrade trade;
   int hSLAnalysisATR;
   int hSLAnalysisFast;
   int hSLAnalysisSlow;
   int hPVEngATR;
   int hEMAFast, hEMAMid, hEMASlow, hEMAATR, hEMARSI, hEMAStoch;
   datetime g_lastEMABar;
   ENUM_TIMEFRAMES g_slAnalysisTF;
   datetime g_lastPVEngBar;
   datetime g_lastPVBRKBar;
   datetime g_lastPVPivotBar;
   datetime g_lastPVCombinedSignal;
   string g_status;
   bool g_slAnalysisReady;
public:
   CDHSignalEngine()
   {
      engineID=0; family=0; isBase=false; nextWake=0;
      hSLAnalysisATR = INVALID_HANDLE;
      hSLAnalysisFast = INVALID_HANDLE;
      hSLAnalysisSlow = INVALID_HANDLE;
      hPVEngATR = INVALID_HANDLE;
      hEMAFast = INVALID_HANDLE; hEMAMid = INVALID_HANDLE; hEMASlow = INVALID_HANDLE;
      hEMAATR = INVALID_HANDLE; hEMARSI = INVALID_HANDLE; hEMAStoch = INVALID_HANDLE;
      g_lastEMABar = 0;
      g_slAnalysisTF = (ENUM_TIMEFRAMES)0;
      g_lastPVEngBar = 0;
      g_lastPVBRKBar = 0;
      g_lastPVPivotBar = 0;
      g_lastPVCombinedSignal = 0;
      g_status = "Đang chờ tín hiệu BRK/PVT/ENG/EMA";
      g_slAnalysisReady = false;
   }
void ResearchEvent(const string method, const string profile,
                   const string eventName, const string status,
                   const string reason, const int direction = 0,
                   const datetime signalTime = 0,
                   const ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT,
                   const double entry = 0.0, const double sl = 0.0,
                   const double tp = 0.0, const double volume = 0.0,
                   const string details = "")
{
   MatrixEvent(engineID, method, eventName, status, reason, signalTime, details);
}

void StartShadowProfiles(const string method, const bool buy,
                         const datetime signalTime,
                         const ENUM_TIMEFRAMES timeframe,
                         const double entry, const double baseSL,
                         const double baseTP, const string source,
                         const string details = "")
{
   MatrixSignal(engineID, family, isBase, method, buy, signalTime,
                timeframe, entry, baseSL, baseTP, source, details);
}

bool HourInSession(const int hour, const int startHour, const int endHour)
{
   if(startHour < endHour) return hour >= startHour && hour < endHour;
   // Cho phép phiên chạy qua nửa đêm, ví dụ 22 -> 6.
   if(startHour > endHour) return hour >= startHour || hour < endHour;
   return false;
}

int GetSession(const datetime when)
{
   MqlDateTime st;
   if(!TimeToStruct(when, st)) return 0;
   int hour = st.hour;
   if(cfg.InpUseAmerica && HourInSession(hour, cfg.InpAmericaStart, cfg.InpAmericaEnd)) return 3;
   if(cfg.InpUseEurope && HourInSession(hour, cfg.InpEuropeStart, cfg.InpEuropeEnd)) return 2;
   if(cfg.InpUseAsia && HourInSession(hour, cfg.InpAsiaStart, cfg.InpAsiaEnd)) return 1;
   return 0;
}

bool ValidSessionHours(const int startHour, const int endHour)
{
   return (startHour >= 0 && startHour < 24 && endHour >= 0 && endHour <= 24 &&
           startHour != endHour);
}

double TickSize()
{
   double v = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return (v > 0.0 ? v : _Point);
}

double PriceDown(const double price)
{
   return NormalizeDouble(MathFloor(price / TickSize() + 1e-9) * TickSize(), _Digits);
}

double PriceUp(const double price)
{
   return NormalizeDouble(MathCeil(price / TickSize() - 1e-9) * TickSize(), _Digits);
}

double EffectiveMaxSLDistance(const double methodMax)
{
   double commonMax = cfg.InpMaxSLPriceDistance;
   if(commonMax <= 0.0) return methodMax;
   if(methodMax <= 0.0) return commonMax;
   return MathMin(commonMax, methodMax);
}

bool NormalizeSLDistance(const bool buy, const double entry, double &sl,
                         const double methodMax, string &reason)
{
   reason = "";
   if(entry <= 0.0 || sl <= 0.0 ||
      (buy && sl >= entry) || (!buy && sl <= entry))
   {
      reason = "SL không nằm đúng phía của Entry";
      return false;
   }
   double risk = MathAbs(entry - sl);
   if(cfg.InpMinSLPriceDistance > 0.0 && risk < cfg.InpMinSLPriceDistance)
   {
      sl = buy ? PriceDown(entry - cfg.InpMinSLPriceDistance)
               : PriceUp(entry + cfg.InpMinSLPriceDistance);
      risk = MathAbs(entry - sl);
   }
   double maxDistance = EffectiveMaxSLDistance(methodMax);
   if(maxDistance > 0.0 && risk > maxDistance + TickSize() * 0.5)
   {
      reason = StringFormat("SL %.3f giá vượt tối đa %.3f giá",
                            risk, maxDistance);
      return false;
   }
   if(risk < TickSize())
   {
      reason = "Khoảng SL nhỏ hơn tick size";
      return false;
   }
   return true;
}

bool PVDirectionAllowed(const bool buy)
{
   if(cfg.InpPVHuongGiaoDich == PV_CA_BUY_VA_SELL) return true;
   if(cfg.InpPVHuongGiaoDich == PV_CHI_BUY) return buy;
   return !buy;
}

bool PVTradingTimeAllowed()
{
   MqlDateTime st;
   if(!TimeToStruct(TimeCurrent(), st)) return false;
   if(cfg.InpPVNgayGiaoDich == PV_THU_HAI_DEN_THU_SAU &&
      (st.day_of_week == 0 || st.day_of_week == 6)) return false;
   if(cfg.InpPVNgayGiaoDich == PV_THU_HAI_DEN_THU_BAY && st.day_of_week == 0)
      return false;
   if(!cfg.InpPVChiTradeTrongGio) return true;
   return HourInSession(st.hour, cfg.InpPVGioBatDau, cfg.InpPVGioKetThuc);
}

bool PVFindStructuralSL(const ENUM_TIMEFRAMES tf, const bool buy, double &sl)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 1, cfg.InpPVSoNenTimSL, r) < cfg.InpPVSoNenTimSL)
      return false;
   double extreme = buy ? r[0].low : r[0].high;
   for(int i = 1; i < cfg.InpPVSoNenTimSL; ++i)
   {
      if(buy) extreme = MathMin(extreme, r[i].low);
      else extreme = MathMax(extreme, r[i].high);
   }
   double buffer = cfg.InpPVDemSLGia;
   sl = buy ? PriceDown(extreme - buffer) : PriceUp(extreme + buffer);
   return sl > 0.0;
}

bool PVEntryGuard(const string method)
{
   return PVTradingTimeAllowed();
}

void EnterPVSignal(const bool buy, const string method,
                   const string commentTag, const ENUM_TIMEFRAMES signalTF,
                   const datetime sourceSignalTime = 0,
                   const double atrSL = 0.0)
{
   int direction = buy ? 1 : -1;
   datetime signalTime = sourceSignalTime > 0 ? sourceSignalTime
                                              : iTime(_Symbol, signalTF, 1);
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
   {
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       "Không đọc được giá Bid/Ask", direction,
                       signalTime, signalTF);
      return;
   }
   double entry = buy ? tick.ask : tick.bid;
   double sl = 0.0;
   // V4.53: EMA dùng SL = k x ATR; các phương pháp khác giữ SL theo đỉnh/đáy.
   if(atrSL > 0.0)
      sl = buy ? PriceDown(entry - atrSL) : PriceUp(entry + atrSL);
   else if(!PVFindStructuralSL(signalTF, buy, sl))
   {
      g_status = commentTag + ": chua du nen dat SL";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF, entry);
      return;
   }
   string slReason = "";
   if(!NormalizeSLDistance(buy, entry, sl, cfg.InpMaxSLPriceDistance, slReason))
   {
      g_status = commentTag + ": " + slReason;
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF, entry, sl);
      return;
   }
   double risk = MathAbs(entry - sl);
   double tp2Distance = cfg.InpPVTP2R * risk;
   double tp2 = buy ? PriceUp(entry + tp2Distance)
                    : PriceDown(entry - tp2Distance);
   double spreadPrice = tick.ask - tick.bid;
   string details = StringFormat("mau=%s|spread_price=%.3f|risk_price=%.3f|sl_bars=%d|tp1_r=%.3f|tp2_r=%.3f|rr_min=%.3f",
                                 commentTag, spreadPrice, risk,
                                 cfg.InpPVSoNenTimSL, cfg.InpTP1AtR,
                                 cfg.InpPVTP2R, cfg.InpPVRRToiThieu);
   ResearchEvent(method, "", "SIGNAL_RAW", "DETECTED", commentTag,
                 direction, signalTime, signalTF, entry, sl, tp2, 0.0, details);
   if(!PVDirectionAllowed(buy))
   {
      g_status = commentTag + ": hướng giao dịch đang bị tắt";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }
   if(!PVEntryGuard(method))
   {
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }
   if(cfg.InpSpreadToiDaGia > 0.0 && spreadPrice > cfg.InpSpreadToiDaGia)
   {
      g_status = commentTag + ": spread vuot gioi han";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }

   double maxSL = EffectiveMaxSLDistance(cfg.InpMaxSLPriceDistance);
   int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double safety = (stops + 1) * _Point;
   if(risk < TickSize() || (maxSL > 0.0 && risk > maxSL) ||
      (buy && sl >= tick.bid - safety) || (!buy && sl <= tick.ask + safety))
   {
      g_status = commentTag + ": SL khong hop le hoac qua xa";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }

   double tp1Distance = cfg.InpTP1AtR * risk;
   double effectiveReward = cfg.InpUseTP1Partial
                            ? (tp1Distance * cfg.InpTP1ClosePct +
                               tp2Distance * (100.0 - cfg.InpTP1ClosePct)) / 100.0
                            : tp2Distance;
   if(risk <= 0.0 || effectiveReward / risk < cfg.InpPVRRToiThieu)
   {
      g_status = commentTag + ": RR hieu dung chua dat";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }
   if((buy && tp2 <= tick.ask + safety) || (!buy && tp2 >= tick.bid - safety))
   {
      g_status = commentTag + ": TP không đạt stop-level sàn";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(method, "THUC_TE", "SIGNAL_DECISION", "REJECTED",
                       g_status, direction, signalTime, signalTF,
                       entry, sl, tp2, 0.0, details);
      return;
   }
   StartShadowProfiles(method, buy, signalTime, signalTF, entry, sl, tp2,
                       "ENTRY_FILTERS_PASSED", details);

}

bool CopyOneBuffer(const int handle, const int buffer, const int shift, double &value)
{
   double data[1];
   if(handle == INVALID_HANDLE || CopyBuffer(handle, buffer, shift, 1, data) != 1 ||
      !MathIsValidNumber(data[0])) return false;
   value = data[0];
   return true;
}

int PVEngulfingSignal(datetime &signalTime)
{
   signalTime = 0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungNhanChim, 0, 4, r) < 4) return 0;
   double atr;
   if(!CopyOneBuffer(hPVEngATR, 0, 1, atr) || atr <= 0.0) return 0;
   signalTime = r[1].time;
   double range = r[1].high - r[1].low;
   double body = MathAbs(r[1].close - r[1].open);
   double previousBody = MathAbs(r[2].close - r[2].open);
   if(range <= TickSize() || range / atr < cfg.InpPVNhanChimMinATR ||
      range / atr > cfg.InpPVNhanChimMaxATR ||
      body + TickSize() * 0.1 < previousBody * cfg.InpPVThanNhanChimSoVoiThanTruoc)
      return 0;
   bool bull = r[2].close < r[2].open && r[1].close > r[1].open &&
               r[1].open <= r[2].close && r[1].close >= r[2].open &&
               (r[1].close - r[1].low) / range >= cfg.InpPVDongCuaManhNhanChim;
   bool bear = r[2].close > r[2].open && r[1].close < r[1].open &&
               r[1].open >= r[2].close && r[1].close <= r[2].open &&
               (r[1].high - r[1].close) / range >= cfg.InpPVDongCuaManhNhanChim;
   if(bull == bear) return 0;
   return bull ? 1 : -1;
}

int PVBreakoutSignal(datetime &signalTime)
{
   signalTime = 0;
   int need = cfg.InpPVSoNenVungBreakout + 5;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungBreakout, 0, need, r) < need) return 0;
   signalTime = r[1].time;
   int breakoutShift = cfg.InpPVChoRetest ? 2 : 1;
   int firstLevelShift = breakoutShift + 1;
   double high = r[firstLevelShift].high, low = r[firstLevelShift].low;
   for(int i = firstLevelShift + 1;
       i < firstLevelShift + cfg.InpPVSoNenVungBreakout; ++i)
   {
      high = MathMax(high, r[i].high);
      low = MathMin(low, r[i].low);
   }
   double range = r[breakoutShift].high - r[breakoutShift].low;
   double body = MathAbs(r[breakoutShift].close - r[breakoutShift].open);
   if(range <= TickSize() || body / range < cfg.InpPVThanBreakoutToiThieu) return 0;
   double buffer = cfg.InpPVDemBreakoutGia;
   bool brokeUp = r[breakoutShift].close > high + buffer;
   bool brokeDown = r[breakoutShift].close < low - buffer;
   if(!cfg.InpPVChoRetest)
   {
      if(brokeUp == brokeDown) return 0;
      return brokeUp ? 1 : -1;
   }
   double tolerance = cfg.InpPVDungSaiRetestGia;
   bool buy = brokeUp && r[1].low <= high + tolerance &&
              r[1].close > high && r[1].close > r[1].open;
   bool sell = brokeDown && r[1].high >= low - tolerance &&
               r[1].close < low && r[1].close < r[1].open;
   if(buy == sell) return 0;
   return buy ? 1 : -1;
}

bool PVPivotTouched(const MqlRates &bar, const double level, const double radius)
{
   return bar.low <= level + radius && bar.high >= level - radius;
}

int PVPivotSignal(datetime &signalTime)
{
   signalTime = 0;
   MqlRates source[], confirm[];
   ArraySetAsSeries(source, true);
   ArraySetAsSeries(confirm, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungTinhPivot, 0, 3, source) < 3 ||
      CopyRates(_Symbol, cfg.InpPVKhungXacNhanPivot, 0, 3, confirm) < 3) return 0;
   signalTime = confirm[1].time;
   double pp = (source[1].high + source[1].low + source[1].close) / 3.0;
   double range = source[1].high - source[1].low;
   double r1 = 2.0 * pp - source[1].low;
   double s1 = 2.0 * pp - source[1].high;
   double r2 = pp + range;
   double s2 = pp - range;
   double radius = cfg.InpPVBKPVungPivotGia;
   bool bullish = confirm[1].close > confirm[1].open;
   bool bearish = confirm[1].close < confirm[1].open;
   bool buyTouch = PVPivotTouched(confirm[1], s2, radius);
   bool sellTouch = PVPivotTouched(confirm[1], r2, radius);
   if(cfg.InpPVMucPivot >= PV_R1_S1_VA_R2_S2)
   {
      buyTouch = buyTouch || PVPivotTouched(confirm[1], s1, radius);
      sellTouch = sellTouch || PVPivotTouched(confirm[1], r1, radius);
   }
   if(cfg.InpPVMucPivot == PV_TAT_CA_MUC)
   {
      buyTouch = buyTouch || PVPivotTouched(confirm[1], pp, radius);
      sellTouch = sellTouch || PVPivotTouched(confirm[1], pp, radius);
   }
   bool buy = buyTouch && (!cfg.InpPVYeuCauNenDungHuong || bullish);
   bool sell = sellTouch && (!cfg.InpPVYeuCauNenDungHuong || bearish);
   if(buy == sell) return 0;
   return buy ? 1 : -1;
}

// V4.53: EMA thuận xu hướng. Nến vừa đóng (shift 1):
// SELL: EMA nhanh < giữa < chậm, đóng cửa dưới EMA nhanh, nến đỏ thân >= k ATR,
//       Stoch còn cao (vừa hồi lên), RSI trong vùng [min,max]. BUY đối xứng.
int EMASignal(datetime &signalTime, double &atr)
{
   signalTime = 0;
   atr = 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, cfg.InpEMAKhung, 0, 3, r) < 3) return 0;
   signalTime = r[1].time;
   double fast, mid, slow, rsi, stoch;
   if(!CopyOneBuffer(hEMAFast, 0, 1, fast) || !CopyOneBuffer(hEMAMid, 0, 1, mid) ||
      !CopyOneBuffer(hEMASlow, 0, 1, slow) || !CopyOneBuffer(hEMAATR, 0, 1, atr) ||
      !CopyOneBuffer(hEMARSI, 0, 1, rsi) || !CopyOneBuffer(hEMAStoch, 0, 1, stoch) ||
      atr <= 0.0) return 0;
   double body = r[1].close - r[1].open;
   double minBody = cfg.InpEMAThanNenATR * atr;
   bool sell = fast < mid && mid < slow && r[1].close < fast && body <= -minBody &&
               stoch >= cfg.InpEMAHoiStoch &&
               rsi >= cfg.InpEMARSIMin && rsi <= cfg.InpEMARSIMax;
   bool buy = fast > mid && mid > slow && r[1].close > fast && body >= minBody &&
              stoch <= 100.0 - cfg.InpEMAHoiStoch &&
              rsi >= 100.0 - cfg.InpEMARSIMax && rsi <= 100.0 - cfg.InpEMARSIMin;
   if(buy == sell) return 0;
   return buy ? 1 : -1;
}

bool PVUseEngulfing()
{
   return cfg.InpUseENGModule &&
          (cfg.InpPVMauPriceAction == PV_CA_BA_MAU ||
           cfg.InpPVMauPriceAction == PV_CHI_NEN_NHAN_CHIM);
}

bool PVUseBreakout()
{
   return cfg.InpUseBRKModule &&
          (cfg.InpPVMauPriceAction == PV_CA_BA_MAU ||
           cfg.InpPVMauPriceAction == PV_CHI_PHA_DINH_DAY);
}

bool AnyAdditionalModuleEnabled()
{
   return PVUseEngulfing() || PVUseBreakout() || cfg.InpUsePVTModule ||
          cfg.InpUseEMAModule;
}

int PVPriceActionConsensus(const int eng, const int brk)
{
   int buys = 0, sells = 0;
   if(PVUseEngulfing()) { if(eng > 0) buys++; if(eng < 0) sells++; }
   if(PVUseBreakout()) { if(brk > 0) buys++; if(brk < 0) sells++; }
   if(buys >= cfg.InpPVSoMauPAToiThieu && sells == 0) return 1;
   if(sells >= cfg.InpPVSoMauPAToiThieu && buys == 0) return -1;
   return 0;
}

void ProcessAdditionalSignals()
{
   if(!AnyAdditionalModuleEnabled()) return;

   if(cfg.InpUseEMAModule)
   {
      datetime emaBar = iTime(_Symbol, cfg.InpEMAKhung, 0);
      if(emaBar > 0 && emaBar != g_lastEMABar)
      {
         g_lastEMABar = emaBar;
         datetime tEMA = 0;
         double atrEMA = 0.0;
         int ema = EMASignal(tEMA, atrEMA);
         if(ema != 0)
            EnterPVSignal(ema > 0, "EMA", "EMA", cfg.InpEMAKhung, tEMA,
                          cfg.InpEMASLTheoATR * atrEMA);
         else if(cfg.InpGhiTinHieuBiLoai)
            ResearchEvent("EMA", "", "PATTERN_SCAN", "NO_SIGNAL",
                          "EMA chưa đạt ngưỡng", 0, tEMA, cfg.InpEMAKhung);
      }
      // Cấu hình EMA chỉ bật module EMA; không quét ENG/BRK/PVT.
      if(!PVUseEngulfing() && !PVUseBreakout() && !cfg.InpUsePVTModule) return;
   }

   datetime engBar = iTime(_Symbol, cfg.InpPVKhungNhanChim, 0);
   datetime brkBar = iTime(_Symbol, cfg.InpPVKhungBreakout, 0);
   datetime pvtBar = iTime(_Symbol, cfg.InpPVKhungXacNhanPivot, 0);
   bool newENG = engBar > 0 && engBar != g_lastPVEngBar;
   bool newBRK = brkBar > 0 && brkBar != g_lastPVBRKBar;
   bool newPVT = pvtBar > 0 && pvtBar != g_lastPVPivotBar;
   if(newENG) g_lastPVEngBar = engBar;
   if(newBRK) g_lastPVBRKBar = brkBar;
   if(newPVT) g_lastPVPivotBar = pvtBar;
   if(!newENG && !newBRK && !newPVT) return;

   datetime tENG = 0, tBRK = 0, tPVT = 0;
   int eng = PVUseEngulfing() ? PVEngulfingSignal(tENG) : 0;
   int brk = PVUseBreakout() ? PVBreakoutSignal(tBRK) : 0;
   int pvt = cfg.InpUsePVTModule ? PVPivotSignal(tPVT) : 0;
   int pa = PVPriceActionConsensus(eng, brk);

   if(cfg.InpGhiTinHieuBiLoai)
   {
      if(newENG && PVUseEngulfing() && eng == 0)
         ResearchEvent("ENG", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Nến nhấn chìm chưa đạt ngưỡng", 0, tENG,
                       cfg.InpPVKhungNhanChim);
      if(newBRK && PVUseBreakout() && brk == 0)
         ResearchEvent("BRK", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Breakout/retest chưa đạt ngưỡng", 0, tBRK,
                       cfg.InpPVKhungBreakout);
      if(newPVT && cfg.InpUsePVTModule && pvt == 0)
         ResearchEvent("PVT", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Pivot chưa có xác nhận", 0, tPVT,
                       cfg.InpPVKhungXacNhanPivot);
   }

   if(cfg.InpPVCachKetHop == PV_MOI_PP_DOC_LAP)
   {
      // Ở chế độ độc lập, mỗi phương pháp được ghi nhận đúng theo tín hiệu
      // của chính nó.  Không để một mẫu Price Action khác chặn kết quả so sánh.
      if(newENG && eng != 0)
         EnterPVSignal(eng > 0, "ENG", "ENG", cfg.InpPVKhungNhanChim, tENG);
      if(newBRK && brk != 0)
         EnterPVSignal(brk > 0, "BRK", "BRK", cfg.InpPVKhungBreakout, tBRK);
      if(newPVT && pvt != 0)
         EnterPVSignal(pvt > 0, "PVT", "PVT", cfg.InpPVKhungXacNhanPivot, tPVT);
      return;
   }

   // Nhánh đồng thuận: không chạy trong LIVE vì MXOneFamily() ép mỗi cấu hình
   // chỉ bật một module và chế độ độc lập. Giữ để tương thích Input.
   int direction = 0;
   bool required = false;
   if(PVUseEngulfing() || PVUseBreakout())
   {
      if(pa == 0) return;
      direction = pa;
      required = true;
   }
   if(cfg.InpUsePVTModule)
   {
      if(pvt == 0 || (required && pvt != direction)) return;
      direction = pvt;
      required = true;
   }
   datetime newest = 0;
   if(tENG > newest) newest = tENG;
   if(tBRK > newest) newest = tBRK;
   if(tPVT > newest) newest = tPVT;
   if(required && direction != 0 && newest > g_lastPVCombinedSignal)
   {
      g_lastPVCombinedSignal = newest;
      EnterPVSignal(direction > 0, "CONSENSUS", "ALL-CONSENSUS",
                    cfg.InpPVKhungVaoLenh, newest);
   }
}


bool InputError(const string inputName, const string requirement)
{
   g_status = "Input sai: " + inputName;
   Print("INPUT KHONG HOP LE [", inputName, "]: ", requirement);
   return false;
}

bool ValidateInputs()
{
   if(cfg.InpMagic == 0)
      return InputError("Mã Magic Number", "phải lớn hơn 0");
   if(cfg.InpExecutionMode == BA_PHUONG_PHAP_DOC_LAP &&
      (cfg.InpMaxIndependentPositions < 1 || cfg.InpMaxIndependentPositions > 10))
      return InputError("Tổng số lệnh tối đa khi chạy độc lập", "chọn từ 1 đến 10");
   if(cfg.InpVolumeMode == LOT_CO_DINH && cfg.InpGiaTriKhoiLuong <= 0.0)
      return InputError("Lot cố định", "phải lớn hơn 0");
   if(cfg.InpVolumeMode == LOT_THEO_PHAN_TRAM_TAI_KHOAN &&
      (cfg.InpGiaTriKhoiLuong <= 0.0 || cfg.InpGiaTriKhoiLuong > 100.0))
      return InputError("Phần trăm Equity cho mỗi SL", "chọn lớn hơn 0 và không quá 100%");
   if(cfg.InpVolumeMode == LOT_THEO_SO_TIEN_SL && cfg.InpGiaTriKhoiLuong <= 0.0)
      return InputError("Số tiền mất tối đa mỗi SL", "phải lớn hơn 0");
   if(cfg.InpDailyLossPct < 0.0 || cfg.InpDailyLossPct > 100.0)
      return InputError("Giới hạn lỗ ngày", "chọn từ 0 đến 100%; 0 là tắt");
   if(cfg.InpTruotGiaToiDaGia < 0.0 || cfg.InpSpreadToiDaGia < 0.0)
      return InputError("Trượt giá/Spread tối đa", "không được âm");
   if(cfg.InpMinSLPriceDistance <= 0.0 || cfg.InpMaxSLPriceDistance <= 0.0 ||
      cfg.InpMinSLPriceDistance > cfg.InpMaxSLPriceDistance)
      return InputError("Khoảng SL chung",
                        "SL tối thiểu và tối đa phải lớn hơn 0; tối thiểu không vượt tối đa");
   if(cfg.InpUseTP1Partial &&
      (cfg.InpTP1AtR <= 0.0 || cfg.InpTP1ClosePct <= 0.0 || cfg.InpTP1ClosePct >= 100.0))
      return InputError("Thiết lập TP1", "R phải lớn hơn 0 và tỷ lệ chốt nằm giữa 0-100%");
   if(cfg.InpUseTrailing &&
      (cfg.InpTrailStartR <= 0.0 || cfg.InpTrailDistanceR <= 0.0 || cfg.InpTrailStepGia < 0.0))
      return InputError("Thiết lập Trailing", "R bắt đầu/khoảng cách phải lớn hơn 0; bước không âm");

   bool usePVEng = PVUseEngulfing();
   bool usePVBrk = PVUseBreakout();
   bool hasPVPriceAction = usePVEng || usePVBrk;
   bool hasPV = hasPVPriceAction || cfg.InpUsePVTModule || cfg.InpUseEMAModule;
   if(cfg.InpUseEMAModule &&
      (cfg.InpEMANhanh < 1 || cfg.InpEMANhanh >= cfg.InpEMAGiua ||
       cfg.InpEMAGiua >= cfg.InpEMACham || cfg.InpEMAATRChuKy < 1))
      return InputError("EMA", "chu kỳ nhanh < giữa < chậm, ATR từ 1");
   if(cfg.InpUseEMAModule &&
      (cfg.InpEMASLTheoATR <= 0.0 || cfg.InpEMAThanNenATR < 0.0 ||
       cfg.InpEMAHoiStoch < 0.0 || cfg.InpEMAHoiStoch > 100.0 ||
       cfg.InpEMARSIMin < 0.0 || cfg.InpEMARSIMin > cfg.InpEMARSIMax || cfg.InpEMARSIMax > 100.0))
      return InputError("EMA", "SL ATR > 0; thân >= 0; Stoch 0-100; RSI min <= max trong 0-100");
   if(hasPV)
   {
      if(cfg.InpPVSoNenTimSL < 1 || cfg.InpPVDemSLGia < 0.0)
         return InputError("SL ENG/BRK/PVT", "số nến từ 1 và đệm không âm");
      if(cfg.InpPVTP2R <= cfg.InpTP1AtR || cfg.InpPVRRToiThieu < 0.0 ||
         cfg.InpPVBEKhiLoiGia < 0.0)
         return InputError("TP/BE ENG/BRK/PVT/EMA", "TP2 R phải lớn hơn TP1 R chung; RR/BE không âm");
      if(cfg.InpPVThuaLienTiepToiDa < 0)
         return InputError("Giới hạn thua ENG/BRK/PVT", "số lệnh không được âm");
      if(hasPVPriceAction &&
         (cfg.InpPVSoMauPAToiThieu < 1 || cfg.InpPVSoMauPAToiThieu > 3))
         return InputError("Số mẫu Price Action đồng thuận", "chọn từ 1 đến 3");
      if(usePVEng &&
         (cfg.InpPVATRNhanChim < 1 || cfg.InpPVNhanChimMinATR <= 0.0 ||
          cfg.InpPVNhanChimMaxATR < cfg.InpPVNhanChimMinATR ||
          cfg.InpPVThanNhanChimSoVoiThanTruoc <= 0.0 ||
          cfg.InpPVDongCuaManhNhanChim < 0.0 || cfg.InpPVDongCuaManhNhanChim > 1.0))
         return InputError("Nến nhấn chìm", "ATR/range/thân > 0; max >= min; vị trí đóng 0-1");
      if(usePVBrk &&
         (cfg.InpPVThanBreakoutToiThieu < 0.0 || cfg.InpPVThanBreakoutToiThieu > 1.0 ||
          cfg.InpPVSoNenVungBreakout < 1 || cfg.InpPVDemBreakoutGia < 0.0 ||
          cfg.InpPVDungSaiRetestGia < 0.0))
         return InputError("Breakout", "tỷ lệ thân 0-1; số nến từ 1; khoảng cách không âm");
      if(cfg.InpUsePVTModule && cfg.InpPVBKPVungPivotGia < 0.0)
         return InputError("Bán kính Pivot", "không được âm");
      if(cfg.InpPVNgungTruocTinPhut < 0 || cfg.InpPVNgungSauTinPhut < 0)
         return InputError("Khoảng dừng tin", "không được âm");
      if(cfg.InpPVChiTradeTrongGio && !ValidSessionHours(cfg.InpPVGioBatDau, cfg.InpPVGioKetThuc))
         return InputError("Giờ trade ENG/BRK/PVT", "giờ bắt đầu/kết thúc không hợp lệ");
   }

   if(cfg.InpUseAsia && !ValidSessionHours(cfg.InpAsiaStart, cfg.InpAsiaEnd))
      return InputError("Giờ phiên Á", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");
   if(cfg.InpUseEurope && !ValidSessionHours(cfg.InpEuropeStart, cfg.InpEuropeEnd))
      return InputError("Giờ phiên Âu", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");
   if(cfg.InpUseAmerica && !ValidSessionHours(cfg.InpAmericaStart, cfg.InpAmericaEnd))
      return InputError("Giờ phiên Mỹ", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");

   if(!hasPV)
      Print("THONG BAO: tat ca phuong phap dang tat; EA van duoc nap de sua Input.");
   return true;
}

int Initialize()
{
   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;
   g_slAnalysisTF = cfg.InpSLAnalysisTF == PERIOD_CURRENT
                    ? LIVE_FALLBACK_TF : cfg.InpSLAnalysisTF;
   if(PVUseEngulfing()) hPVEngATR = iATR(_Symbol, cfg.InpPVKhungNhanChim,
                                         cfg.InpPVATRNhanChim);
   if(cfg.InpAnalyzeSL)
   {
      hSLAnalysisATR = iATR(_Symbol, g_slAnalysisTF, cfg.InpSLAnalysisATRPeriod);
      hSLAnalysisFast = iMA(_Symbol, g_slAnalysisTF, cfg.InpSLAnalysisFastEMA,
                            0, MODE_EMA, PRICE_CLOSE);
      hSLAnalysisSlow = iMA(_Symbol, g_slAnalysisTF, cfg.InpSLAnalysisSlowEMA,
                            0, MODE_EMA, PRICE_CLOSE);
      g_slAnalysisReady = hSLAnalysisATR != INVALID_HANDLE &&
                          hSLAnalysisFast != INVALID_HANDLE &&
                          hSLAnalysisSlow != INVALID_HANDLE;
      if(!g_slAnalysisReady)
         Print("CANH BAO: khong tao duoc indicator phan tich SL; Telegram van hoat dong.");
   }
   if(cfg.InpUseEMAModule)
   {
      hEMAFast = iMA(_Symbol, cfg.InpEMAKhung, cfg.InpEMANhanh, 0, MODE_EMA, PRICE_CLOSE);
      hEMAMid = iMA(_Symbol, cfg.InpEMAKhung, cfg.InpEMAGiua, 0, MODE_EMA, PRICE_CLOSE);
      hEMASlow = iMA(_Symbol, cfg.InpEMAKhung, cfg.InpEMACham, 0, MODE_EMA, PRICE_CLOSE);
      hEMAATR = iATR(_Symbol, cfg.InpEMAKhung, cfg.InpEMAATRChuKy);
      hEMARSI = iRSI(_Symbol, cfg.InpEMAKhung, 14, PRICE_CLOSE);
      hEMAStoch = iStochastic(_Symbol, cfg.InpEMAKhung, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
      if(hEMAFast == INVALID_HANDLE || hEMAMid == INVALID_HANDLE ||
         hEMASlow == INVALID_HANDLE || hEMAATR == INVALID_HANDLE ||
         hEMARSI == INVALID_HANDLE || hEMAStoch == INVALID_HANDLE)
      {
         Print("Khong tao duoc indicator EMA: ", GetLastError());
         return INIT_FAILED;
      }
      g_lastEMABar = iTime(_Symbol, cfg.InpEMAKhung, 0);
   }
   if(PVUseEngulfing() && hPVEngATR == INVALID_HANDLE)
   {
      Print("Khong tao duoc indicator handles: ", GetLastError());
      return INIT_FAILED;
   }
   g_lastPVEngBar = iTime(_Symbol, cfg.InpPVKhungNhanChim, 0);
   g_lastPVBRKBar = iTime(_Symbol, cfg.InpPVKhungBreakout, 0);
   g_lastPVPivotBar = iTime(_Symbol, cfg.InpPVKhungXacNhanPivot, 0);
   return INIT_SUCCEEDED;
}

void Step()
{
   ProcessAdditionalSignals();
}

void Release()
{
   if(hPVEngATR != INVALID_HANDLE) IndicatorRelease(hPVEngATR);
   if(hEMAFast != INVALID_HANDLE) IndicatorRelease(hEMAFast);
   if(hEMAMid != INVALID_HANDLE) IndicatorRelease(hEMAMid);
   if(hEMASlow != INVALID_HANDLE) IndicatorRelease(hEMASlow);
   if(hEMAATR != INVALID_HANDLE) IndicatorRelease(hEMAATR);
   if(hEMARSI != INVALID_HANDLE) IndicatorRelease(hEMARSI);
   if(hEMAStoch != INVALID_HANDLE) IndicatorRelease(hEMAStoch);
   if(hSLAnalysisATR != INVALID_HANDLE) IndicatorRelease(hSLAnalysisATR);
   if(hSLAnalysisFast != INVALID_HANDLE) IndicatorRelease(hSLAnalysisFast);
   if(hSLAnalysisSlow != INVALID_HANDLE) IndicatorRelease(hSLAnalysisSlow);
}
   void ScheduledStep(const datetime now)
   {
      if(now<nextWake) return;
      Step();
      ENUM_TIMEFRAMES tf=LIVE_FALLBACK_TF;
      if(family==0)tf=cfg.InpEMAKhung;
      else if(family==5)tf=cfg.InpPVKhungNhanChim;
      else if(family==7)tf=cfg.InpPVKhungBreakout;
      else if(family==9)tf=cfg.InpPVKhungXacNhanPivot;
      if(tf==PERIOD_CURRENT)tf=LIVE_FALLBACK_TF;
      int seconds=PeriodSeconds(tf);
      datetime bar=iTime(_Symbol,tf,0);
      nextWake=(bar>0 && seconds>0)?bar+seconds:now+1;
      if(nextWake<=now) nextWake=now+1;
      if(seconds>=86400 && nextWake>now+60)nextWake=now+60;
   }
};



CDHSignalEngine *g_engines[];
MatrixConfig g_base;
int g_walletStart[], g_walletCount[], g_engineSession[];
MXWallet g_wallets[];
MXPosition g_positions[];
MXNative g_native[];
MXPosition g_nativeQueue[];
int g_activeWallets[];
MXMonth g_months[];
int g_monthKeys[];
string g_axisDescriptions[];
string g_runFolder="", g_currency="";
MqlTick g_quote;
CTrade g_executor;
long g_nextPosition=1;
bool g_ready=false, g_finished=false, g_fatal=false;
bool g_liveTradingBlocked=false,g_liveDailyStopped=false;
string g_liveBlockReason="";
datetime g_liveBlockTime=0;
bool g_liveBlockRecoverable=false;
double g_livePeakEquity=0.0,g_liveMaxDD=0.0;
datetime g_panelAttachTime=0;
double g_panelAttachPeak=0.0,g_panelAttachMaxDD=0.0;
int g_liveClosedDeals=0;
double g_moneyFactor=1.0, g_minLot=0.0, g_lotStep=0.0, g_maxLot=0.0, g_priceStep=0.0;
double g_buyUp=0.0,g_buyDown=0.0,g_sellUp=0.0,g_sellDown=0.0;
double g_swapLong=0.0,g_swapShort=0.0,g_swapDays[7];
int g_swapMode=0, g_monthSlot=-1, g_dayKey=0;
datetime g_firstTick=0,g_lastTick=0,g_lastEquityLog=0,g_lastBarLog=0,g_lastCurrentBarLog=0,g_dayStart=0;
ulong g_lastFlush=0,g_lastPanel=0;
int g_hTrades=INVALID_HANDLE,g_hEvents=INVALID_HANDLE,g_hEquity=INVALID_HANDLE;
int g_hBars=INVALID_HANDLE,g_hConfig=INVALID_HANDLE,g_hWallet=INVALID_HANDLE;
int g_hAudit=INVALID_HANDLE,g_hOrders=INVALID_HANDLE,g_hSymbols=INVALID_HANDLE,g_hBarsCurrent=INVALID_HANDLE;
int g_delayEvents=0,g_nativeOperationErrors=0,g_nativeRequestCount=0;
double g_nativeInitialBalance=0.0,g_nativeDealsNet=0.0,g_nativeReconcileGap=0.0;
bool g_nativeHistoryOK=false;
// V4.49: live entry pauses that are NOT hard trading blocks. Open positions keep
// being managed; only new entries wait until the condition is resolved.
struct LivePendingOpen
{
   bool active;
   MXPosition p;
   string comment;
   ulong order, deal;
   uint retcode;
   datetime sentTime;
   ulong sentTick;
   double requestPrice;
};
LivePendingOpen g_livePending;
bool g_liveMarketClosed=false;
datetime g_liveMarketClosedTime=0;
// V4.49 counters for Backtest/Real comparison (written to thong_tin_run and Experts).
int g_statPreSendGuard=0,g_statMinSLTolerance=0,g_statPostFillRiskClose=0;
int g_statBrokerTransient=0,g_statMarketClosed=0,g_statUncertain=0,g_statAdopted=0;
int g_statBrokerSerious=0,g_statTradingBlocks=0;

// ---------------------------------------------------------------------------
// V4.50 persistent performance statistics (server time, EA positions only)
// ---------------------------------------------------------------------------
// Definitions
//  * Lãi/lỗ đã chốt (closedNet): profit+commission+swap+fee of every deal of a
//    position opened by this EA (Magic + symbol) whose deal time is in the period.
//    Rebuilt from MT5 history on every refresh, so detaching/reattaching,
//    restarting MT5/VPS or reconnecting can neither reset nor double count it.
//  * Lãi/lỗ đang chạy (floating): profit+swap of the EA positions still open.
//  * Balance đầu kỳ: current Balance minus the net of ALL account deals
//    (trades, deposits, withdrawals) since server 00:00 of the day / the 1st of
//    the month. Never the attach time.
//  * Vốn kỳ (capital) = Balance đầu kỳ + nạp/rút/điều chỉnh balance trong kỳ
//    (treated as if made at the period start, so they are never profit or DD).
//  * Đường vốn EA của kỳ = capital + closedNet + floating. Manual trades and
//    other EAs are excluded.
//  * Drawdown kỳ = largest fall from the running peak of that curve, % of peak.
//    Closed-deal history gives a lower bound; the peak/DD observed while the EA
//    runs are persisted in GlobalVariables. Floating swings that happened while
//    the EA was detached cannot be recovered.
//  * Lỗ ngày cho giới hạn = -(closedNet ngày + floating); ngưỡng = InpDailyLossPct
//    % của Balance đầu ngày (00:00 server). If that Balance is <= 0 (account first
//    funded today) the day capital is used instead.
struct DHPeriodStats
{
   int key;
   datetime start;
   double balanceStart;
   double capital;
   double closedNet;
   int entries;
   int closedPositions;
   int wins;
   double closedPeak;
   double closedMaxDD;
   double peak;
   double maxDD;
};
DHPeriodStats g_dhDay, g_dhMonth;
double g_dhFloating=0.0;
bool g_dhDirty=true;
ulong g_dhLastRefresh=0, g_dhLastGVFlush=0;
bool g_dhPersistBlocks=false;
int g_logMonth=0;
const string DH_HDR_DEALS="time;deal;order;position_id;symbol;magic;entry;type;volume;price;profit;commission;swap;fee;method;comment";
const string DH_HDR_ORDERS="time;transaction_type;order;deal;position;symbol;order_type;volume;price;price_sl;price_tp;retcode;description";
const string DH_HDR_EVENTS="time;engine_id;method;event;status;reason;signal_time;details";
const string DH_HDR_AUDIT="action;signal_id;engine_id;position_ticket;order_ticket;deal_ticket;request_tick_ms;deal_ms;after_tick_ms;elapsed_ms;side;request_bid;request_ask;requested_price;fill_price;price_difference;result_volume;api_ok;retcode;description";
const string DH_HDR_EQUITY="time;account;balance;equity;max_dd_pct;positions;currency";
const string DH_HDR_BARS_M1="time;open;high;low;close;tick_volume;spread_points";
const string DH_HDR_BARS_CUR="time;timeframe;open;high;low;close;tick_volume;spread_points";

datetime DHDayStart(const datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0; return StructToTime(d);
}
datetime DHMonthStart(const datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.day=1; d.hour=0; d.min=0; d.sec=0; return StructToTime(d);
}
int DHDayKey(const datetime t) { MqlDateTime d; TimeToStruct(t,d); return d.year*10000+d.mon*100+d.day; }
int DHMonthKey(const datetime t) { MqlDateTime d; TimeToStruct(t,d); return d.year*100+d.mon; }
string DHStatKey(const string field,const string period)
{
   return "DH450_ST_"+field+"_"+period+"_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
bool DHPersist() { return !MQLInfoInteger(MQL_TESTER) && InpChoPhepGiaoDichThat; }
int DHFindId(const ulong &ids[],const ulong id)
{
   for(int i=0;i<ArraySize(ids);i++) if(ids[i]==id) return i;
   return -1;
}
// Restores the persisted peak/max DD of the same period and never lets them go
// below what the closed-deal history proves.
void DHMergePeriod(DHPeriodStats &fresh,const DHPeriodStats &old,const string period)
{
   fresh.peak=fresh.capital; fresh.maxDD=0.0;
   if(old.key==fresh.key) { fresh.peak=old.peak; fresh.maxDD=old.maxDD; }
   else if(DHPersist() && GlobalVariableCheck(DHStatKey("KEY",period)) &&
           (int)GlobalVariableGet(DHStatKey("KEY",period))==fresh.key)
   {
      fresh.peak=GlobalVariableGet(DHStatKey("PEAK",period));
      fresh.maxDD=GlobalVariableGet(DHStatKey("MAXDD",period));
   }
   fresh.peak=MathMax(fresh.peak,fresh.closedPeak);
   fresh.maxDD=MathMax(fresh.maxDD,fresh.closedMaxDD);
}
void DHSavePeriod(const DHPeriodStats &st,const string period)
{
   if(!DHPersist()) return;
   GlobalVariableSet(DHStatKey("KEY",period),st.key);
   GlobalVariableSet(DHStatKey("PEAK",period),st.peak);
   GlobalVariableSet(DHStatKey("MAXDD",period),st.maxDD);
}
void DHRefreshStats(const bool force)
{
   datetime now=TimeCurrent(); if(now<=0) return;
   int dk=DHDayKey(now), mk=DHMonthKey(now);
   bool periodChanged=g_dhDay.key!=dk || g_dhMonth.key!=mk;
   if(!force && !g_dhDirty && !periodChanged && GetTickCount64()-g_dhLastRefresh<5000) return;
   datetime ds=DHDayStart(now), ms=DHMonthStart(now);
   // 40 extra days so positions opened before the month can still be attributed.
   if(!HistorySelect(ms-40*86400,now+86400)) return;
   g_dhLastRefresh=GetTickCount64(); g_dhDirty=false;
   DHPeriodStats d,m; ZeroMemory(d); ZeroMemory(m);
   d.key=dk; d.start=ds; m.key=mk; m.start=ms;
   int total=HistoryDealsTotal();
   ulong owned[];
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY);
      if(en!=DEAL_ENTRY_IN && en!=DEAL_ENTRY_INOUT) continue;
      ulong id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
      if(id>0 && DHFindId(owned,id)<0) { int n=ArraySize(owned); ArrayResize(owned,n+1); owned[n]=id; }
   }
   double sinceDay=0.0,sinceMonth=0.0,opsDay=0.0,opsMonth=0.0;
   ulong pos[]; double pnet[]; bool pOutDay[],pOutMonth[];
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      datetime tm=(datetime)HistoryDealGetInteger(t,DEAL_TIME);
      double net=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_COMMISSION)+
                 HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_FEE);
      if(tm>=ms) sinceMonth+=net;
      if(tm>=ds) sinceDay+=net;
      ulong id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
      ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(t,DEAL_TYPE);
      if(id==0 && dt!=DEAL_TYPE_BUY && dt!=DEAL_TYPE_SELL)
      {
         // Deposit, withdrawal, credit, correction, bonus...: capital, not P/L.
         if(tm>=ms) opsMonth+=net;
         if(tm>=ds) opsDay+=net;
         continue;
      }
      if(id==0 || HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol || DHFindId(owned,id)<0) continue;
      int k=DHFindId(pos,id);
      if(k<0)
      {
         k=ArraySize(pos); ArrayResize(pos,k+1); ArrayResize(pnet,k+1);
         ArrayResize(pOutDay,k+1); ArrayResize(pOutMonth,k+1);
         pos[k]=id; pnet[k]=0.0; pOutDay[k]=false; pOutMonth[k]=false;
      }
      pnet[k]+=net;
      ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY);
      bool isIn=en==DEAL_ENTRY_IN || en==DEAL_ENTRY_INOUT;
      bool isOut=en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY || en==DEAL_ENTRY_INOUT;
      if(tm>=ms) { m.closedNet+=net; if(isIn && (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagic) m.entries++; if(isOut) pOutMonth[k]=true; }
      if(tm>=ds) { d.closedNet+=net; if(isIn && (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagic) d.entries++; if(isOut) pOutDay[k]=true; }
   }
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   d.balanceStart=balance-sinceDay; m.balanceStart=balance-sinceMonth;
   d.capital=d.balanceStart+opsDay; m.capital=m.balanceStart+opsMonth;
   // Closed-deal curves in chronological order: lower bound of the period peak/DD.
   double runD=0.0,runM=0.0,peakRunD=0.0,peakRunM=0.0;
   for(int i=0;i<total;i++)
   {
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      datetime tm=(datetime)HistoryDealGetInteger(t,DEAL_TIME);
      if(tm<ms) continue;
      ulong id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
      if(id==0 || HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol || DHFindId(owned,id)<0) continue;
      double net=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_COMMISSION)+
                 HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_FEE);
      runM+=net; peakRunM=MathMax(peakRunM,runM);
      double pkM=m.capital+peakRunM;
      if(pkM>0.0) m.closedMaxDD=MathMax(m.closedMaxDD,100.0*(peakRunM-runM)/pkM);
      if(tm>=ds)
      {
         runD+=net; peakRunD=MathMax(peakRunD,runD);
         double pkD=d.capital+peakRunD;
         if(pkD>0.0) d.closedMaxDD=MathMax(d.closedMaxDD,100.0*(peakRunD-runD)/pkD);
      }
   }
   d.closedPeak=d.capital+peakRunD; m.closedPeak=m.capital+peakRunM;
   // Win rate: positions fully closed with a closing deal inside the period.
   for(int k=0;k<ArraySize(pos);k++)
   {
      bool stillOpen=false;
      for(int j=PositionsTotal()-1;j>=0;j--)
      {
         ulong pt=PositionGetTicket(j);
         if(pt>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==pos[k]) { stillOpen=true; break; }
      }
      if(stillOpen) continue;
      if(pOutDay[k]) { d.closedPositions++; if(pnet[k]>0.0) d.wins++; }
      if(pOutMonth[k]) { m.closedPositions++; if(pnet[k]>0.0) m.wins++; }
   }
   DHMergePeriod(d,g_dhDay,"D"); DHMergePeriod(m,g_dhMonth,"M");
   g_dhDay=d; g_dhMonth=m;
   DHSavePeriod(g_dhDay,"D"); DHSavePeriod(g_dhMonth,"M");
}
void DHObservePeriod(DHPeriodStats &st,const string period)
{
   double value=st.capital+st.closedNet+g_dhFloating;
   bool changed=false;
   if(value>st.peak) { st.peak=value; changed=true; }
   double dd=st.peak>0.0?100.0*(st.peak-value)/st.peak:0.0;
   if(dd>st.maxDD+1e-9) { st.maxDD=dd; changed=true; }
   if(changed) DHSavePeriod(st,period);
}
// Called every tick/timer: floating P/L of EA positions and peak/DD tracking.
void DHObserveEquity()
{
   DHRefreshStats(false);
   double fl=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         fl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   g_dhFloating=fl;
   if(g_dhDay.key==0) return;
   DHObservePeriod(g_dhDay,"D"); DHObservePeriod(g_dhMonth,"M");
   if(DHPersist() && GetTickCount64()-g_dhLastGVFlush>=60000)
   {
      GlobalVariablesFlush(); g_dhLastGVFlush=GetTickCount64();
   }
}
double DHDayLossMoney() { return -(g_dhDay.closedNet+g_dhFloating); }
double DHDayLossReference() { return g_dhDay.balanceStart>0.0?g_dhDay.balanceStart:g_dhDay.capital; }
double DHDayLossLimitMoney() { return DHDayLossReference()*InpDailyLossPct/100.0; }
bool DHDailyLossReached()
{
   if(InpDailyLossPct<=0.0) return false;
   DHObserveEquity();
   double limit=DHDayLossLimitMoney();
   return limit>0.0 && DHDayLossMoney()>=limit;
}
// Daily stop only blocks NEW entries; open positions keep SL/TP/BE/Trailing.
void DHSetDailyStop()
{
   if(g_liveDailyStopped) return;
   g_liveDailyStopped=true;
   g_liveBlockTime=TimeCurrent();
   if(DHPersist())
   {
      GlobalVariableSet(LiveDayKeyName(),DHDayKey(TimeCurrent()));
      GlobalVariableSet(LiveDayStopKey(),1.0);
   }
   Print(StringFormat("V4.52: lỗ ngày của EA %.2f %s đạt ngưỡng %.1f%% Balance đầu ngày (%.2f %s); "
                      "dừng mở lệnh mới đến ngày giao dịch kế tiếp, vị thế đang mở vẫn được quản lý.",
                      DHDayLossMoney(),g_currency,InpDailyLossPct,DHDayLossLimitMoney(),g_currency));
}
// Serious-error lock persistence (LIVE). Recovery-time checks are re-evaluated at
// every start, so only locks raised while running (g_dhPersistBlocks) are saved.
string DHLockKey() { return "DH450_LOCK_"+IntegerToString((long)InpMagic)+"_"+_Symbol; }
string DHLockFile() { return g_runFolder+"\\DavidHunter_khoa_loi_"+IntegerToString((long)InpMagic)+"_"+_Symbol+".txt"; }
void DHSaveLock(const string reason)
{
   if(!DHPersist() || !g_dhPersistBlocks) return;
   GlobalVariableSet(DHLockKey(),(double)TimeCurrent());
   int h=FileOpen(DHLockFile(),FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(h!=INVALID_HANDLE) { FileWriteString(h,reason); FileClose(h); }
   GlobalVariablesFlush();
}
void DHDeleteLock()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(GlobalVariableCheck(DHLockKey())) GlobalVariableDel(DHLockKey());
   FileDelete(DHLockFile(),FILE_COMMON);
}
string DHReadLockReason()
{
   string reason="";
   int h=FileOpen(DHLockFile(),FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(h!=INVALID_HANDLE) { reason=FileReadString(h); FileClose(h); }
   return reason==""?"Khóa lỗi nghiêm trọng từ lần chạy trước":reason;
}
// Monthly log files: <folder>\DavidHunter_YYYY_MM_<kind>.csv (server time).
string DHLogPath(const string kind,const int mk)
{
   return g_runFolder+"\\DavidHunter_"+StringFormat("%04d_%02d",mk/100,mk%100)+"_"+kind+".csv";
}
void DHReopenLog(int &h,const string kind,const string header,const int mk)
{
   if(h==INVALID_HANDLE) return;
   FileFlush(h); FileClose(h);
   h=MXFileMonth(kind,header,mk);
}
void DHRotateLogs(const datetime now)
{
   if(g_logMonth==0 || now<=0) return;
   int mk=DHMonthKey(now);
   if(mk<=g_logMonth) return;
   DHReopenLog(g_hTrades,"deals",DH_HDR_DEALS,mk);
   DHReopenLog(g_hOrders,"orders",DH_HDR_ORDERS,mk);
   DHReopenLog(g_hEvents,"events",DH_HDR_EVENTS,mk);
   DHReopenLog(g_hAudit,"management_requests",DH_HDR_AUDIT,mk);
   DHReopenLog(g_hEquity,"equity",DH_HDR_EQUITY,mk);
   DHReopenLog(g_hBars,"bars_"+_Symbol+"_M1",DH_HDR_BARS_M1,mk);
   DHReopenLog(g_hBarsCurrent,"bars_"+_Symbol+"_CURRENT",DH_HDR_BARS_CUR,mk);
   Print("V4.52: chuyển file log sang tháng ",StringFormat("%04d_%02d",mk/100,mk%100),
         "; file tháng ",StringFormat("%04d_%02d",g_logMonth/100,g_logMonth%100)," được giữ nguyên.");
   g_logMonth=mk;
}

// Shared portfolio UI and live-account helpers belong at file scope.
string g_panelPrefix="DH450_PANEL_";
void PanelRect(const string key,const int corner,const int x,const int y,const int w,const int h,const color fill)
{
   string name=g_panelPrefix+key;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,fill);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
string LivePeakKey()
{
   return "DH443_PEAK_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
string LiveDDKey()
{
   return "DH443_DD_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
string LiveDayKeyName()
{
   return "DH443_DAY_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
string LiveDayEquityKey()
{
   return "DH443_DAYEQ_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
string LiveDayStopKey()
{
   return "DH443_DAYSTOP_"+IntegerToString((long)InpMagic)+"_"+_Symbol;
}
int LiveTodayEntryCount()
{
   datetime now=TimeCurrent(); MqlDateTime d; TimeToStruct(now,d);
   d.hour=0; d.min=0; d.sec=0; datetime midnight=StructToTime(d);
   if(!HistorySelect(midnight,now)) return 0;
   int count=0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
         (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(en==DEAL_ENTRY_IN || en==DEAL_ENTRY_INOUT) count++;
   }
   return count;
}
int LiveOpenCount()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) count++;
   }
   return count;
}
int LiveOpenCountForEngine(const int engine)
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string fields[]; int n=StringSplit(PositionGetString(POSITION_COMMENT),'|',fields);
      if(n>=4 && fields[0]=="DH443" && (int)StringToInteger(fields[2])==engine) count++;
   }
   return count;
}
void UpdateDailyLossStop()
{
   if(InpDailyLossPct<=0.0 || g_liveDailyStopped || ArraySize(g_wallets)==0) return;
   if(DHDailyLossReached()) DHSetDailyStop();
}
void UpdateLiveDrawdown()
{
   if(!MQLInfoInteger(MQL_TESTER) && !InpChoPhepGiaoDichThat) return;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0.0) return;
   if(g_panelAttachPeak<=0.0 || equity>g_panelAttachPeak) g_panelAttachPeak=equity;
   double attachDD=100.0*(g_panelAttachPeak-equity)/g_panelAttachPeak;
   if(attachDD>g_panelAttachMaxDD) g_panelAttachMaxDD=attachDD;
   if(equity>g_livePeakEquity) g_livePeakEquity=equity;
   double dd=g_livePeakEquity>0.0?100.0*(g_livePeakEquity-equity)/g_livePeakEquity:0.0;
   if(dd>g_liveMaxDD) g_liveMaxDD=dd;
   if(!MQLInfoInteger(MQL_TESTER))
   {
      GlobalVariableSet(LivePeakKey(),g_livePeakEquity);
      GlobalVariableSet(LiveDDKey(),g_liveMaxDD);
   }
}
// ---------------------------------------------------------------------------
// Dashboard (V4.51): one combined panel at the top-left of the chart.
// Objects are created once and only updated (max once per second).
// ---------------------------------------------------------------------------
const color DH_BG=C'22,18,10';
const color DH_BG_HEAD=C'38,30,14';
const color DH_GOLD=C'255,200,40';
const color DH_GOLD_DIM=C'184,146,54';
const color DH_TEXT=C'236,228,210';
const color DH_MUTED=C'160,148,120';
const color DH_GREEN=C'46,204,113';
const color DH_RED=C'235,77,61';
const color DH_ORANGE=C'255,165,0';
void PanelBox(const string key,const int x,const int y,const int w,const int h,const color fill,const color border)
{
   PanelRect(key,CORNER_LEFT_UPPER,x,y,w,h,fill);
   ObjectSetInteger(0,g_panelPrefix+key,OBJPROP_COLOR,border);
}
void PanelLabel(const string key,const string text,const int x,const int y,const color ink,
                const int size,const string font,const ENUM_ANCHOR_POINT anchor)
{
   string name=g_panelPrefix+key;
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,1);
   }
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   if(ObjectGetString(0,name,OBJPROP_TEXT)!=text) ObjectSetString(0,name,OBJPROP_TEXT,text);
}
void PanelLeft(const string key,const string text,const int x,const int y,const color ink,const int size=9,const string font="Arial")
{ PanelLabel(key,text,x,y,ink,size,font,ANCHOR_LEFT_UPPER); }
void PanelRight(const string key,const string text,const int x,const int y,const color ink,const int size=9,const string font="Arial")
{ PanelLabel(key,text,x,y,ink,size,font,ANCHOR_RIGHT_UPPER); }
void PanelDeleteGroup(const string group)
{
   string prefix=g_panelPrefix+group;
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string n=ObjectName(0,i,0,-1);
      if(StringFind(n,prefix)==0) ObjectDelete(0,n);
   }
}
string DHSessionName(const int session)
{
   if(session==1) return "Á";
   if(session==2) return "Âu";
   if(session==3) return "Mỹ";
   return "Mọi phiên";
}
string DHDirectionName(const ENUM_PV_HUONG_GIAO_DICH d)
{
   if(d==PV_CHI_BUY) return "Chỉ Mua";
   if(d==PV_CHI_SELL) return "Chỉ Bán";
   return "Mua/Bán";
}
int DHEngineIndex(const string axis)
{
   for(int i=0;i<ArraySize(g_axisDescriptions);i++) if(g_axisDescriptions[i]==axis) return i;
   return -1;
}
string DHMoney(const double v) { return StringFormat("%+.2f",v); }
string DHWinRate(const DHPeriodStats &st)
{
   if(st.closedPositions<=0) return "--";
   return StringFormat("%.1f%% (%d/%d)",100.0*st.wins/st.closedPositions,st.wins,st.closedPositions);
}
void DrawDashboard()
{
   if(!InpMatrixBangNhe || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))) return;
   ulong now=GetTickCount64(); if(now-g_lastPanel<1000) return; g_lastPanel=now;
   // Keep clear of the One Click Trading buttons when they are shown.
   bool oneClick=ChartGetInteger(0,CHART_SHOW_ONE_CLICK)!=0;

   bool locked=g_fatal || g_liveTradingBlocked;
   bool paused=g_liveDailyStopped || LiveNewEntryPaused();
   string stateText=locked?"KHÓA":(paused?"TẠM DỪNG":"ĐANG GIAO DỊCH");
   color stateColor=locked?DH_RED:(paused?DH_ORANGE:DH_GREEN);
   string reason="Không có cảnh báo";
   color reasonColor=DH_MUTED;
   if(g_fatal) { reason="EA gặp lỗi nghiêm trọng, xem tab Experts"; reasonColor=DH_RED; }
   else if(g_liveTradingBlocked) { reason=g_liveBlockReason; reasonColor=DH_RED; }
   else if(g_liveDailyStopped) { reason=StringFormat("Chạm giới hạn lỗ ngày %.1f%%, chờ ngày mới",InpDailyLossPct); reasonColor=DH_ORANGE; }
   else if(LiveNewEntryPaused()) { reason=LivePauseReason(); reasonColor=DH_ORANGE; }
   if(StringLen(reason)>54) reason=StringSubstr(reason,0,51)+"...";

   // ---------------- V4.51: one combined panel, top-left ----------------
   PanelDeleteGroupOnce();
   int lx=8, ly=oneClick?86:20, lw=400, row=19;
   int lh=22*row+46;
   PanelBox("dh_bg",lx,ly,lw,lh,DH_BG,DH_GOLD_DIM);
   PanelBox("dh_head",lx+1,ly+1,lw-2,2*row+6,DH_BG_HEAD,DH_BG_HEAD);
   int x=lx+12, xr=lx+lw-12, c1=lx+280, y=ly+8;
   PanelLeft("dh_title","DAVID HUNTER",x,y,DH_GOLD,13,"Arial Bold");
   PanelRight("dh_ver","V4.53",xr,y+4,DH_GOLD_DIM,9,"Arial Bold");
   y+=row+3;
   PanelLeft("dh_sub","SĐT: 0941920986   |   "+_Symbol+"   |   Magic "+IntegerToString((long)InpMagic),x,y,DH_MUTED,8);
   y+=row+4;
   PanelLeft("dh_state_l","Trạng thái",x,y,DH_TEXT,9);
   PanelRight("dh_state_v",stateText,xr,y,stateColor,10,"Arial Bold");
   y+=row;
   PanelLeft("dh_reason",reason,x,y,reasonColor,8);
   y+=row;
   PanelLeft("dh_pp_head","CÁC PHƯƠNG PHÁP",x,y,DH_GOLD,9,"Arial Bold");
   y+=row;
   string names[5]={"BRK758","PVT880","ENG626","ENG636","EMA"};
   int session=GetSessionForPanel();
   for(int k=0;k<5;k++)
   {
      int e=DHEngineIndex(names[k]);
      string info=names[k];
      string st="Tắt"; color sc=DH_MUTED;
      if(e>=0)
      {
         info+="   "+DHDirectionName(g_engines[e].cfg.InpPVHuongGiaoDich)+" · "+DHSessionName(g_engineSession[e]);
         if(LiveOpenCountForEngine(e)>0) { st="Đang giữ lệnh"; sc=DH_GREEN; }
         else if(locked || paused) { st="Tạm dừng"; sc=DH_ORANGE; }
         else if(g_engineSession[e]>0 && g_engineSession[e]!=session) { st="Ngoài phiên"; sc=DH_MUTED; }
         else { st="Chờ tín hiệu"; sc=DH_GOLD; }
      }
      PanelLeft("dh_pp_n"+IntegerToString(k),info,x+6,y,e>=0?DH_TEXT:DH_MUTED,9);
      PanelRight("dh_pp_s"+IntegerToString(k),st,xr,y,sc,9,"Arial Bold");
      y+=row;
   }
   PanelBox("dh_line1",x,y+2,lw-24,1,DH_GOLD_DIM,DH_GOLD_DIM);
   y+=8;
   PanelLeft("dh_open_l","Vị thế EA đang quản lý",x,y,DH_TEXT,9);
   PanelRight("dh_open_v",StringFormat("%d / %d   (mỗi PP ≤ %d)",LiveOpenCount(),InpMaxIndependentPositions,InpMatrixLenhMoiPP),xr,y,DH_TEXT,9);
   y+=row;
   PanelLeft("dh_lock_l","Khóa lỗi broker nghiêm trọng",x,y,DH_TEXT,9);
   PanelRight("dh_lock_v",locked?"CÓ":"Không",xr,y,locked?DH_RED:DH_GREEN,9,"Arial Bold");
   y+=row;
   bool connected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0;
   bool brokerReady=connected && !LiveNewEntryPaused();
   PanelLeft("dh_broker_l","Broker / kết nối",x,y,DH_TEXT,9);
   PanelRight("dh_broker_v",brokerReady?"Sẵn sàng":(connected?"Tạm dừng":"Mất kết nối"),xr,y,brokerReady?DH_GREEN:DH_ORANGE,9,"Arial Bold");
   y+=row;
   PanelBox("dh_line2",x,y+2,lw-24,1,DH_GOLD_DIM,DH_GOLD_DIM);
   y+=8;
   PanelLeft("dh_pf_h0","HIỆU SUẤT ("+g_currency+")",x,y,DH_GOLD,9,"Arial Bold");
   PanelRight("dh_pf_h1","Hôm nay",c1,y,DH_GOLD,9,"Arial Bold");
   PanelRight("dh_pf_h2","Tháng này",xr,y,DH_GOLD,9,"Arial Bold");
   y+=row;
   PanelLeft("dh_pf_r0","Lãi/lỗ đã chốt",x,y,DH_TEXT,9);
   PanelRight("dh_pf_r0d",DHMoney(g_dhDay.closedNet),c1,y,g_dhDay.closedNet>=0.0?DH_GREEN:DH_RED,10,"Arial Bold");
   PanelRight("dh_pf_r0m",DHMoney(g_dhMonth.closedNet),xr,y,g_dhMonth.closedNet>=0.0?DH_GREEN:DH_RED,10,"Arial Bold");
   y+=row;
   PanelLeft("dh_pf_r1","Drawdown tối đa",x,y,DH_TEXT,9);
   PanelRight("dh_pf_r1d",StringFormat("%.2f%%",g_dhDay.maxDD),c1,y,g_dhDay.maxDD>0.0?DH_ORANGE:DH_TEXT,9);
   PanelRight("dh_pf_r1m",StringFormat("%.2f%%",g_dhMonth.maxDD),xr,y,g_dhMonth.maxDD>0.0?DH_ORANGE:DH_TEXT,9);
   y+=row;
   PanelLeft("dh_pf_r2","Số lệnh mở mới",x,y,DH_TEXT,9);
   PanelRight("dh_pf_r2d",IntegerToString(g_dhDay.entries),c1,y,DH_TEXT,9);
   PanelRight("dh_pf_r2m",IntegerToString(g_dhMonth.entries),xr,y,DH_TEXT,9);
   y+=row;
   PanelLeft("dh_pf_r3","Win Rate (lệnh đã đóng)",x,y,DH_TEXT,9);
   PanelRight("dh_pf_r3d",DHWinRate(g_dhDay),c1,y,DH_TEXT,9);
   PanelRight("dh_pf_r3m",DHWinRate(g_dhMonth),xr,y,DH_TEXT,9);
   y+=row;
   PanelBox("dh_line3",x,y+2,lw-24,1,DH_GOLD_DIM,DH_GOLD_DIM);
   y+=8;
   double lossNow=MathMax(0.0,DHDayLossMoney());
   double lossPct=DHDayLossReference()>0.0?100.0*lossNow/DHDayLossReference():0.0;
   PanelLeft("dh_i0","Equity hiện tại",x,y,DH_TEXT,9);
   PanelRight("dh_i0v",StringFormat("%.2f",AccountInfoDouble(ACCOUNT_EQUITY)),xr,y,DH_GOLD,10,"Arial Bold");
   y+=row;
   PanelLeft("dh_i1","Lãi/lỗ đang chạy",x,y,DH_TEXT,9);
   PanelRight("dh_i1v",DHMoney(g_dhFloating),xr,y,g_dhFloating>=0.0?DH_GREEN:DH_RED,9);
   y+=row;
   PanelLeft("dh_i2","Lỗ ngày hiện tại (đã chốt + đang chạy)",x,y,DH_TEXT,9);
   PanelRight("dh_i2v",StringFormat("%.2f (%.2f%%)",-lossNow,lossPct),xr,y,lossNow>0.0?DH_RED:DH_TEXT,9);
   y+=row;
   PanelLeft("dh_i3",StringFormat("Ngưỡng dừng %.1f%% Balance đầu ngày",InpDailyLossPct),x,y,DH_TEXT,9);
   PanelRight("dh_i3v",g_liveDailyStopped?"ĐÃ DỪNG":StringFormat("%.2f",-DHDayLossLimitMoney()),xr,y,g_liveDailyStopped?DH_RED:DH_ORANGE,9,g_liveDailyStopped?"Arial Bold":"Arial");
   ChartRedraw(0);
}
bool g_dhOldPanelCleared=false;
void PanelDeleteGroupOnce()
{
   if(g_dhOldPanelCleared) return;
   // Objects of the V4.50 two-panel layout.
   PanelDeleteGroup("pf_"); PanelDeleteGroup("op_");
   g_dhOldPanelCleared=true;
}
int GetSessionForPanel()
{
   return ArraySize(g_engines)>0?g_engines[0].GetSession(TimeCurrent()):MXCurrentSession();
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // Re-anchor the bottom-right panel immediately when the chart is resized.
   if(id==CHARTEVENT_CHART_CHANGE && g_ready) { g_lastPanel=0; DrawDashboard(); }
}

// Free-form log text cannot inject extra CSV columns or records.
string MXCleanText(string s)
{
   StringReplace(s,";",",");StringReplace(s,"\r"," ");StringReplace(s,"\n"," ");
   return s;
}

string MXTime(const datetime t) { return TimeToString(t,TIME_DATE|TIME_SECONDS); }
string MXMoney(const double v) { return DoubleToString(v,8); }
string MXFamily(const int f)
{
   string names[10]={"EMA","ICT","MM","SMC","PVEMA","ENG","PIN","BRK","LQ","PVT"};
   return f>=0 && f<10 ? names[f] : "PORTFOLIO_GOC";
}
string MXDirection(const int d) { return d==1?"BUY":(d==2?"SELL":"BUY_SELL"); }
string MXSession(const int s) { return s==1?"A":(s==2?"AU":(s==3?"MY":"TAT_CA")); }
bool MXHour(const int hour,const int start,const int end)
{
   if(start<end) return hour>=start && hour<end;
   return start>end && (hour>=start || hour<end);
}
int MXCurrentSession()
{
   MqlDateTime dt; TimeToStruct(g_quote.time,dt);
   if(InpUseAmerica && MXHour(dt.hour,InpAmericaStart,InpAmericaEnd)) return 3;
   if(InpUseEurope && MXHour(dt.hour,InpEuropeStart,InpEuropeEnd)) return 2;
   if(InpUseAsia && MXHour(dt.hour,InpAsiaStart,InpAsiaEnd)) return 1;
   return 0;
}
double MXFloorLot(const double v)
{
   return g_lotStep>0.0?NormalizeDouble(MathFloor(v/g_lotStep+1e-8)*g_lotStep,8):0.0;
}
double MXPrice(const double v,const bool up)
{
   return NormalizeDouble((up?MathCeil(v/g_priceStep-1e-8):MathFloor(v/g_priceStep+1e-8))*g_priceStep,_Digits);
}
bool MXSplit(const double lot,double &part)
{
   part=0.0;
   if(!InpUseTP1Partial) return true;
   part=MXFloorLot(lot*InpTP1ClosePct/100.0);
   return part>=g_minLot-1e-8 && lot-part>=g_minLot-1e-8;
}
bool MXSplitOrSkipPartialLive(const double lot,double &part)
{
   if(MXSplit(lot,part)) return true;
   if(lot>=g_minLot-1e-8)
   { part=0.0; return true; }
   return false;
}
void MXFail(const string why)
{
   if(!g_fatal) Print("V4.53 DỪNG: ",why);
   g_fatal=true;
}
int MXFile(const string kind,const string header)
{
   if(g_logMonth==0) g_logMonth=DHMonthKey(TimeCurrent());
   return MXFileMonth(kind,header,g_logMonth);
}
int MXFileMonth(const string kind,const string header,const int mk)
{
   string path=DHLogPath(kind,mk);
   int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE,';',CP_UTF8);
   if(h==INVALID_HANDLE)
   {
      Print("V4.52 LOG: không mở được ",path,"; lỗi=",GetLastError(),". EA vẫn tiếp tục quản lý giao dịch.");
      return h;
   }
   if(FileSize(h)==0) FileWriteString(h,header+"\r\n");
   FileSeek(h,0,SEEK_END);
   return h;
}
void MXFlush()
{
   if(g_hTrades!=INVALID_HANDLE) FileFlush(g_hTrades);
   if(g_hEvents!=INVALID_HANDLE) FileFlush(g_hEvents);
   if(g_hEquity!=INVALID_HANDLE) FileFlush(g_hEquity);
   if(g_hBars!=INVALID_HANDLE) FileFlush(g_hBars);
   if(g_hBarsCurrent!=INVALID_HANDLE) FileFlush(g_hBarsCurrent);
   if(g_hAudit!=INVALID_HANDLE) FileFlush(g_hAudit);
   if(g_hOrders!=INVALID_HANDLE) FileFlush(g_hOrders);
   if(g_hSymbols!=INVALID_HANDLE) FileFlush(g_hSymbols);
}
void MatrixEvent(const int engine,const string method,const string eventName,
                 const string status,const string reason,const datetime signalTime,
                 const string details)
{
   if(g_hEvents==INVALID_HANDLE) return;
   if(!InpGhiTinHieuBiLoai && status!="ERROR" && status!="REJECT_MONEY" && eventName!="INIT") return;
   FileWrite(g_hEvents,MXTime(TimeCurrent()),engine,MXCleanText(method),eventName,status,MXCleanText(reason),MXTime(signalTime),MXCleanText(details));
}
void MXTradeLog(const MXPosition &p,const string eventName,const double price,
                const double eventNet,const string detail="")
{
   if(g_hTrades==INVALID_HANDLE) return;
   FileWrite(g_hTrades,MXTime(g_quote.time),p.wallet,p.engine,p.id,p.method,eventName,
             p.buy?"BUY":"SELL",MXTime(p.signalTime),MXTime(p.opened),
             DoubleToString(p.entry,_Digits),DoubleToString(p.initialSL,_Digits),
             DoubleToString(p.sl,_Digits),DoubleToString(p.tp1,_Digits),DoubleToString(p.tp2,_Digits),
             MXMoney(p.initialLot),MXMoney(p.left),DoubleToString(price,_Digits),
             MXMoney(eventNet),MXMoney(p.net),MXMoney(p.mfe/p.risk),MXMoney(p.mae/p.risk),
             MXMoney(g_wallets[p.wallet].balance),g_currency,MXCleanText(detail));
}
// Four exact OrderCalcProfit probes per tick share conversion rates across
// linear XAUUSD/Forex/CFD contracts. Reject non-linear symbol calc modes.
bool MXRates()
{
   double ref=g_minLot, delta=100.0*g_priceStep;
   if(ref<=0.0 || delta<=0.0) return false;
   double a,b,c,d;
   if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,ref,g_quote.ask,g_quote.ask+delta,a) ||
      !OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,ref,g_quote.ask,g_quote.ask-delta,b) ||
      !OrderCalcProfit(ORDER_TYPE_SELL,_Symbol,ref,g_quote.bid,g_quote.bid+delta,c) ||
      !OrderCalcProfit(ORDER_TYPE_SELL,_Symbol,ref,g_quote.bid,g_quote.bid-delta,d)) return false;
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b) || !MathIsValidNumber(c) || !MathIsValidNumber(d) ||
      a<=0.0 || b>=0.0 || c>=0.0 || d<=0.0) return false;
   g_buyUp=a/(ref*delta); g_buyDown=-b/(ref*delta);
   g_sellUp=-c/(ref*delta); g_sellDown=d/(ref*delta);
   return true;
}
double MXProfit(const bool buy,const double lot,const double entry,const double price)
{
   double move=price-entry;
   if(buy) return move*lot*(move>=0.0?g_buyUp:g_buyDown);
   return -move*lot*(move>=0.0?g_sellUp:g_sellDown);
}
void MXMark(const int w)
{
   g_wallets[w].equity=g_wallets[w].balance+g_wallets[w].floating;
   if(g_wallets[w].equity>g_wallets[w].peak) g_wallets[w].peak=g_wallets[w].equity;
   double dd=g_wallets[w].peak-g_wallets[w].equity;
   g_wallets[w].ddMoney=MathMax(g_wallets[w].ddMoney,dd);
   if(g_wallets[w].peak>0.0) g_wallets[w].ddPct=MathMax(g_wallets[w].ddPct,100.0*dd/g_wallets[w].peak);
   if(g_monthSlot>=0)
   {
      int k=g_monthSlot*ArraySize(g_wallets)+w;
      g_months[k].endEquity=g_wallets[w].equity;
      g_months[k].peak=MathMax(g_months[k].peak,g_wallets[w].equity);
      if(g_months[k].peak>0.0) g_months[k].ddPct=MathMax(g_months[k].ddPct,100.0*(g_months[k].peak-g_wallets[w].equity)/g_months[k].peak);
   }
}
void MXCash(const int w,const double cash)
{
   g_wallets[w].balance+=cash;
   if(g_monthSlot>=0) g_months[g_monthSlot*ArraySize(g_wallets)+w].net+=cash;
}
void MXStatClose(MXStats &s,const double net)
{
   s.trades++; s.net+=net;
   if(net>1e-8) { s.wins++; s.grossWin+=net; s.streak=0; }
   else if(net < -1e-8) { s.losses++; s.grossLoss-=net; s.streak++; s.maxStreak=(int)MathMax(s.maxStreak,s.streak); }
   else { s.flats++; s.streak=0; }
}
double MXPF(const MXStats &s) { return s.grossLoss>0.0?s.grossWin/s.grossLoss:(s.grossWin>0.0?-1.0:0.0); }
double MXWR(const MXStats &s) { return s.trades>0?100.0*s.wins/s.trades:0.0; }

bool MXNativeOK()
{
   uint ret=g_executor.ResultRetcode();
   return ret==TRADE_RETCODE_DONE || ret==TRADE_RETCODE_DONE_PARTIAL;
}
string LivePositionKey(const string field,const ulong ticket)
{
   return "DH443_"+field+"_"+IntegerToString((long)InpMagic)+"_"+IntegerToString((long)ticket);
}
void LiveSetTradingBlock(const string reason,const bool recoverable)
{
   g_statTradingBlocks++;
   g_liveTradingBlocked=true;
   g_liveBlockReason=reason;
   g_liveBlockTime=TimeCurrent();
   g_liveBlockRecoverable=recoverable;
   if(!recoverable) DHSaveLock(reason);
   Print("V4.52 TẠM KHÓA LỆNH MỚI: ",reason);
}
void LiveClearTradingBlock(const string note)
{
   if(!g_liveTradingBlocked) return;
   g_liveTradingBlocked=false;
   g_liveBlockReason="";
   g_liveBlockTime=0;
   g_liveBlockRecoverable=false;
   DHDeleteLock();
   Print("V4.52 ĐÃ TỰ KHÔI PHỤC GIAO DỊCH: ",note);
}
bool LiveSelectOwnedPosition(const ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   return PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic;
}
void LiveDeletePositionState(const ulong ticket)
{
   GlobalVariableDel(LivePositionKey("R",ticket));
   GlobalVariableDel(LivePositionKey("T",ticket));
   GlobalVariableDel(LivePositionKey("P",ticket));
   GlobalVariableDel(LivePositionKey("D",ticket));
}
void LiveRemoveNativeSlot(const int slot,const string reason)
{
   if(slot<0 || slot>=ArraySize(g_native)) return;
   ulong ticket=g_native[slot].ticket;
   LiveDeletePositionState(ticket);
   // V4.49: a TP1 rejection block names its ticket; it cannot outlive the position.
   if(g_liveTradingBlocked && StringFind(g_liveBlockReason,"ticket "+IntegerToString((long)ticket)+":")>=0)
      LiveClearTradingBlock("vị thế bị từ chối TP1 đã đóng tại broker");
   int last=ArraySize(g_native)-1;
   if(slot<last) g_native[slot]=g_native[last];
   ArrayResize(g_native,last);
   Print("V4.52 đã dọn trạng thái vị thế ",ticket,": ",reason);
}
bool LiveRecoverPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string comment=PositionGetString(POSITION_COMMENT), parts[];
      int count=StringSplit(comment,'|',parts);
      string rk=LivePositionKey("R",ticket), pk=LivePositionKey("P",ticket), dk=LivePositionKey("D",ticket);
      if(count<4 || parts[0]!="DH443")
      {
         LiveSetTradingBlock("Không nhận diện được phương pháp của vị thế "+IntegerToString((long)ticket),false);
         LiveAddRecoveryTicket(ticket);
         continue;
      }
      MXNative n; ZeroMemory(n);
      n.ticket=ticket; n.buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      n.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double brokerSL=PositionGetDouble(POSITION_SL);
      n.risk=GlobalVariableCheck(rk)?GlobalVariableGet(rk):MathAbs(n.entry-brokerSL);
      n.tp1=GlobalVariableCheck(LivePositionKey("T",ticket))?GlobalVariableGet(LivePositionKey("T",ticket)):
            (n.buy?n.entry+n.risk*InpTP1AtR:n.entry-n.risk*InpTP1AtR);
      double currentVolume=PositionGetDouble(POSITION_VOLUME);
      n.part=GlobalVariableCheck(pk)?GlobalVariableGet(pk):MXFloorLot(currentVolume*InpTP1ClosePct/100.0);
      if(n.part<g_minLot || currentVolume-n.part<g_minLot) n.part=0.0;
      n.partialDone=GlobalVariableCheck(dk)?GlobalVariableGet(dk)>0.5:false;
      n.tp2=PositionGetDouble(POSITION_TP); n.shadowID=(long)StringToInteger(parts[1]);
      n.engine=(int)StringToInteger(parts[2]); n.method=parts[3];
      if(n.risk<=0.0 || n.tp2<=0.0)
      {
         LiveSetTradingBlock("SL/TP bảo vệ không hợp lệ ở vị thế "+IntegerToString((long)ticket),false);
         LiveAddRecoveryTicket(ticket);
         continue;
      }
      int sz=ArraySize(g_native); ArrayResize(g_native,sz+1); g_native[sz]=n;
      g_wallets[0].open++;
      if(n.engine>=0 && n.engine<10) g_wallets[0].openFamily[n.engine]++;
      GlobalVariableSet(rk,n.risk); GlobalVariableSet(LivePositionKey("T",ticket),n.tp1);
      GlobalVariableSet(pk,n.part); GlobalVariableSet(dk,n.partialDone?1.0:0.0);
   }
   return true;
}
bool MXRequestMoved(const MqlTick &before,const MqlTick &after,const long dealMsc,const bool quoteOK)
{
   return !quoteOK || dealMsc>before.time_msc || after.time_msc>before.time_msc ||
          after.bid!=before.bid || after.ask!=before.ask;
}
bool MXAuditRequest(const string action,const long shadowID,const int engine,
                    const ulong ticket,const bool buy,const MqlTick &before,const bool apiOK)
{
   g_nativeRequestCount++;
   uint ret=g_executor.ResultRetcode();
   ulong deal=g_executor.ResultDeal();
   long dealMsc=0;
   double fill=g_executor.ResultPrice(),volume=g_executor.ResultVolume();
   if(deal>0 && HistoryDealSelect(deal))
   {
      dealMsc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
      fill=HistoryDealGetDouble(deal,DEAL_PRICE);
      volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
   }
   MqlTick after;ZeroMemory(after);bool quoteOK=SymbolInfoTick(_Symbol,after);
   long elapsed=(long)MathMax(0.0,(double)(MathMax((double)dealMsc,(double)after.time_msc)-before.time_msc));
   double requested=buy?before.ask:before.bid;
   bool accepted=apiOK && MXNativeOK();
   if(!accepted)g_nativeOperationErrors++;
   if(g_hAudit!=INVALID_HANDLE)
      FileWrite(g_hAudit,action,shadowID,engine,ticket,g_executor.ResultOrder(),deal,
         before.time_msc,dealMsc,after.time_msc,elapsed,buy?"BUY":"SELL",
         DoubleToString(before.bid,_Digits),DoubleToString(before.ask,_Digits),
         DoubleToString(requested,_Digits),DoubleToString(fill,_Digits),
         DoubleToString(fill>0.0?fill-requested:0.0,_Digits),MXMoney(volume),apiOK,ret,
         MXCleanText(g_executor.ResultRetcodeDescription()));
   if(!g_finished && MQLInfoInteger(MQL_TESTER) && MXRequestMoved(before,after,dealMsc,quoteOK))
   {
      g_delayEvents++;
      MatrixEvent(engine,"REFERENCE","TESTER_DELAY","ERROR",
         "Thời gian hoặc giá đã đổi trong yêu cầu giao dịch. Chọn No Delay để đối chiếu Matrix.",
         before.time,"action="+action+"|elapsed_ms="+IntegerToString(elapsed));
      MXFail("Lượt Matrix không đồng bộ do trễ khớp lệnh. Chọn Execution = No Delay rồi chạy lại ngắn.");
      return false;
   }
   return accepted;
}
// ---------------------------------------------------------------------------
// V4.49 live execution helpers
// ---------------------------------------------------------------------------
// Minimum-SL tolerance. The signal sets SL at least InpMinSLPriceDistance away
// from the requested price, and the lot is sized on that requested distance.
// A fill that lands closer to the SL (inside the allowed slippage) only makes
// the money at risk SMALLER, so it must not be closed as "invalid SL".
double LiveMinRiskTolerance()
{
   return InpTruotGiaToiDaGia+g_priceStep*0.5;
}
// Before sending, the lot is still to be sized on this distance, so only a
// half-tick float tolerance is allowed (5.00 may compute as 4.9999999).
// After the fill the lot is fixed and the slippage tolerance applies.
// Max side keeps only a half-tick float tolerance: a wider SL than planned
// would raise the money at risk above the sizing budget.
bool LiveRiskInsideLimits(const double risk,const double minTolerance)
{
   return risk>=InpMinSLPriceDistance-minTolerance &&
          risk<=InpMaxSLPriceDistance+g_priceStep*0.5;
}
string LiveRiskText(const double risk,const double minTolerance)
{
   return StringFormat("SL %.2f giá, dải cho phép %.2f-%.2f (dung sai cận dưới %.2f)",
                       risk,InpMinSLPriceDistance,InpMaxSLPriceDistance,minTolerance);
}
bool LiveTransientRetcode(const uint ret)
{
   return ret==TRADE_RETCODE_REQUOTE || ret==TRADE_RETCODE_PRICE_CHANGED ||
          ret==TRADE_RETCODE_PRICE_OFF;
}
// Result not known: the order may or may not have reached the market.
bool LiveUncertainRetcode(const uint ret)
{
   return ret==0 || ret==TRADE_RETCODE_TIMEOUT || ret==TRADE_RETCODE_CONNECTION ||
          ret==TRADE_RETCODE_PLACED;
}
bool LiveNewEntryPaused()
{
   return g_livePending.active || g_liveMarketClosed;
}
string LivePauseReason()
{
   if(g_livePending.active) return "Đang đối chiếu lệnh vừa gửi (kết quả chưa rõ)";
   if(g_liveMarketClosed) return "Sàn báo thị trường đóng; chờ phiên mở";
   return "";
}
bool LiveTradeSessionOpen(const datetime now)
{
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY) return false;
   MqlDateTime dt; TimeToStruct(now,dt);
   long secOfDay=dt.hour*3600+dt.min*60+dt.sec;
   datetime from=0,to=0; bool any=false;
   for(uint i=0;i<32;i++)
   {
      if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)dt.day_of_week,i,from,to)) break;
      any=true;
      long s=(long)from, e=(long)to;
      if(e<=s) e+=86400;
      if(secOfDay>=s && secOfDay<e) return true;
   }
   // No session table published by the broker: rely on the fresh-tick check only.
   return !any;
}
bool LiveTicketTracked(const ulong ticket)
{
   for(int i=0;i<ArraySize(g_native);i++) if(g_native[i].ticket==ticket) return true;
   return false;
}
// Finds the broker position created by the pending request, if any.
ulong LiveFindPendingPosition(const ulong positionID)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic || LiveTicketTracked(t)) continue;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(positionID>0 && id==positionID) return t;
      if(g_livePending.order>0 && id==g_livePending.order) return t;
      if(PositionGetString(POSITION_COMMENT)==g_livePending.comment &&
         (datetime)PositionGetInteger(POSITION_TIME)>=g_livePending.sentTime-120) return t;
   }
   return 0;
}
void LiveClearPending(const string note)
{
   if(!g_livePending.active) return;
   Print("V4.52 KẾT THÚC ĐỐI CHIẾU ",g_livePending.comment,": ",note);
   MatrixEvent(g_livePending.p.engine,g_livePending.p.method,"RECONCILE","ERROR",note,
               g_livePending.p.signalTime,g_livePending.comment);
   ZeroMemory(g_livePending);
   g_livePending.active=false;
}
void MXNativeAfterFill(const MXPosition &p,const ulong ticket,const double requestPrice,
                       const bool live,const string comment);
// Uncertain send: never open a new entry until the broker state is known.
void LiveReconcilePending()
{
   if(!g_livePending.active) return;
   ulong positionID=0; bool dealSeen=false;
   if(HistorySelect(g_livePending.sentTime-120,TimeCurrent()+120))
   {
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol ||
            (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
         ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
         if(en!=DEAL_ENTRY_IN) continue;
         bool sameOrder=g_livePending.order>0 && (ulong)HistoryDealGetInteger(d,DEAL_ORDER)==g_livePending.order;
         bool sameDeal=g_livePending.deal>0 && d==g_livePending.deal;
         bool sameComment=HistoryDealGetString(d,DEAL_COMMENT)==g_livePending.comment;
         if(sameOrder || sameDeal || sameComment)
         { dealSeen=true; positionID=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID); break; }
      }
   }
   ulong ticket=LiveFindPendingPosition(positionID);
   if(ticket>0)
   {
      g_statAdopted++;
      MXPosition p=g_livePending.p; string comment=g_livePending.comment; double req=g_livePending.requestPrice;
      Print("V4.52 ĐỐI CHIẾU: tìm thấy vị thế ",ticket," của ",comment,"; kiểm tra SL/TP và đưa vào quản lý.");
      ZeroMemory(g_livePending); g_livePending.active=false;
      MXNativeAfterFill(p,ticket,req,true,comment);
      return;
   }
   if(dealSeen)
   {
      LiveClearPending("deal vào lệnh đã có nhưng vị thế không còn mở (đã đóng tại broker); không mở lại tín hiệu");
      return;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong o=OrderGetTicket(i);
      if(o==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol || (ulong)OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      if(o==g_livePending.order || OrderGetString(ORDER_COMMENT)==g_livePending.comment) return; // still working
   }
   if(GetTickCount64()-g_livePending.sentTick<(ulong)LIVE_RECONCILE_SECONDS*1000) return;
   LiveClearPending(StringFormat("không có order/deal/vị thế sau %d giây (retcode %u); tín hiệu bỏ qua, không gửi lại",
                                 LIVE_RECONCILE_SECONDS,g_livePending.retcode));
}
// Called every tick/timer in LIVE before signals are evaluated.
// V4.52: positions of this Magic found at start-up that the EA cannot manage
// (unknown comment or missing SL/TP). New entries stay locked only while at
// least one of them is still open at the broker.
ulong g_liveRecoveryTickets[];
void LiveAddRecoveryTicket(const ulong ticket)
{
   int n=ArraySize(g_liveRecoveryTickets); ArrayResize(g_liveRecoveryTickets,n+1); g_liveRecoveryTickets[n]=ticket;
}
void LiveReleaseRecoveryBlock()
{
   int n=ArraySize(g_liveRecoveryTickets);
   if(n==0) return;
   for(int i=n-1;i>=0;i--)
   {
      if(LiveSelectOwnedPosition(g_liveRecoveryTickets[i])) continue;
      Print("V4.52: vị thế ",g_liveRecoveryTickets[i]," (không quản lý được) đã đóng tại broker.");
      int last=ArraySize(g_liveRecoveryTickets)-1;
      if(i<last) g_liveRecoveryTickets[i]=g_liveRecoveryTickets[last];
      ArrayResize(g_liveRecoveryTickets,last);
   }
   if(ArraySize(g_liveRecoveryTickets)>0 || !g_liveTradingBlocked) return;
   // Only release the start-up lock; any other lock raised later keeps its own reason.
   if(StringFind(g_liveBlockReason,"Không nhận diện được phương pháp của vị thế ")==0 ||
      StringFind(g_liveBlockReason,"SL/TP bảo vệ không hợp lệ ở vị thế ")==0)
      LiveClearTradingBlock("các vị thế không quản lý được đã đóng");
}
void LiveProcessEntryPauses()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   LiveReleaseRecoveryBlock();
   if(g_livePending.active) LiveReconcilePending();
   if(g_liveMarketClosed && g_quote.time>g_liveMarketClosedTime &&
      LiveTradeSessionOpen(g_quote.time))
   {
      g_liveMarketClosed=false;
      Print("V4.52 ĐÃ TỰ KHÔI PHỤC: phiên giao dịch mở và có giá mới; nhận tín hiệu mới.");
   }
}
void LiveStartReconcile(const MXPosition &p,const string comment,const double requestPrice,const string why)
{
   g_statUncertain++;
   ZeroMemory(g_livePending);
   g_livePending.active=true; g_livePending.p=p; g_livePending.comment=comment;
   g_livePending.order=g_executor.ResultOrder(); g_livePending.deal=g_executor.ResultDeal();
   g_livePending.retcode=g_executor.ResultRetcode();
   g_livePending.sentTime=TimeCurrent(); g_livePending.sentTick=GetTickCount64();
   g_livePending.requestPrice=requestPrice;
   Print("V4.52 TẠM DỪNG LỆNH MỚI: ",why," | ",comment," | retcode ",g_livePending.retcode,
         " | đối chiếu order/deal/vị thế trước khi nhận tín hiệu mới.");
   MatrixEvent(p.engine,p.method,"RECONCILE_START","ERROR",why,p.signalTime,comment);
   LiveReconcilePending();
}
// Classifies a rejected live open. Nothing is re-sent: the signal is dropped.
void LiveHandleOpenFailure(const MXPosition &p,const string comment,const double requestPrice)
{
   uint ret=g_executor.ResultRetcode();
   string desc=g_executor.ResultRetcodeDescription();
   if(LiveTransientRetcode(ret))
   {
      g_statBrokerTransient++;
      Print("V4.52: broker từ chối tạm thời (",ret," ",desc,") ",comment,
            "; bỏ tín hiệu, không gửi lại, không khóa EA.");
      return;
   }
   if(ret==TRADE_RETCODE_MARKET_CLOSED)
   {
      g_statMarketClosed++;
      g_liveMarketClosed=true; g_liveMarketClosedTime=TimeCurrent();
      Print("V4.52 TẠM DỪNG LỆNH MỚI: sàn báo thị trường đóng (",comment,
            "); tự nhận tín hiệu mới khi phiên mở và có giá mới.");
      return;
   }
   if(LiveUncertainRetcode(ret))
   {
      LiveStartReconcile(p,comment,requestPrice,"kết quả gửi lệnh chưa rõ: "+desc);
      return;
   }
   g_statBrokerSerious++;
   LiveSetTradingBlock("Broker từ chối mở lệnh: "+desc,false);
}
void MXNativeOpen(const MXPosition &p)
{
   bool live=!MQLInfoInteger(MQL_TESTER);
   if((!live && !InpMatrixLenhTester) ||
      (live && (!InpChoPhepGiaoDichThat || g_liveTradingBlocked || g_liveDailyStopped ||
                LiveNewEntryPaused()))) return;
   string comment="DH443|"+IntegerToString(p.id)+"|"+IntegerToString(p.engine)+"|"+p.method;
   if(StringLen(comment)>31) comment=StringSubstr(comment,0,31);
   MqlTick before;
   if(!SymbolInfoTick(_Symbol,before))
   {
      // Nothing was sent, so there is no position uncertainty: drop this signal only.
      if(live)
      {
         g_statPreSendGuard++;
         Print("V4.52 LIVE_GUARD: không lấy được giá trước gửi lệnh ",comment,"; bỏ tín hiệu.");
         MatrixEvent(p.engine,p.method,"LIVE_GUARD","REJECTED","Không lấy được giá trước gửi lệnh",p.signalTime,comment);
         return;
      }
      MXFail("Không lấy được giá trước gửi lệnh");return;
   }
   if(!live && (before.time_msc!=g_quote.time_msc || before.bid!=g_quote.bid || before.ask!=g_quote.ask))
      {g_delayEvents++;MXFail("Giá thay đổi trước gửi tham chiếu. Chọn No Delay.");return;}
   double requestPrice=p.buy?before.ask:before.bid;
   double requestSL=p.initialSL, requestTP=p.tp2, requestLot=p.initialLot;
   if(live)
   {
      double slip=MathAbs(requestPrice-p.entry);
      double liveRisk=MathAbs(requestPrice-requestSL);
      if(slip>InpTruotGiaToiDaGia+g_priceStep*0.5 || !LiveRiskInsideLimits(liveRisk,g_priceStep*0.5))
      {
         g_statPreSendGuard++;
         string why=StringFormat("Giá đổi %.2f giá (tối đa %.2f) hoặc %s trước khi gửi",
                                 slip,InpTruotGiaToiDaGia,LiveRiskText(liveRisk,g_priceStep*0.5));
         Print("V4.52 LIVE_GUARD: ",comment," ",why);
         MatrixEvent(p.engine,p.method,"LIVE_GUARD","REJECTED",why,p.signalTime,comment);
         return;
      }
      double rr=MathAbs(p.tp2-p.entry)/MathMax(p.risk,g_priceStep);
      requestTP=MXPrice(requestPrice+(p.buy?1.0:-1.0)*rr*liveRisk,p.buy);
      requestLot=MXLot(p.wallet,p.buy,requestPrice,requestSL);
      double livePart=0.0;
      if(requestLot<g_minLot || !MXSplitOrSkipPartialLive(requestLot,livePart))
      { MatrixEvent(p.engine,p.method,"LIVE_GUARD","REJECTED","Khối lượng thấp hơn mức tối thiểu của sàn",p.signalTime,comment); return; }
   }
   bool ok=p.buy?g_executor.Buy(requestLot,_Symbol,requestPrice,requestSL,requestTP,comment):
                 g_executor.Sell(requestLot,_Symbol,requestPrice,requestSL,requestTP,comment);
   bool auditOK=MXAuditRequest("OPEN",p.id,p.engine,g_executor.ResultOrder(),p.buy,before,ok);
   if(g_fatal)return;
   if(!auditOK)
   {
      g_wallets[p.wallet].nativeErrors++;
      MatrixEvent(p.engine,p.method,"NATIVE_OPEN","ERROR",g_executor.ResultRetcodeDescription(),p.signalTime,comment);
      if(live) LiveHandleOpenFailure(p,comment,requestPrice);
      return;
   }
   ulong ticket=g_executor.ResultOrder();
   if(!PositionSelectByTicket(ticket))
   {
      ulong deal=g_executor.ResultDeal(), id=0;
      if(HistoryDealSelect(deal)) id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      ticket=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong t=PositionGetTicket(i);
         if(t>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==id) { ticket=t; break; }
      }
   }
   if(ticket==0 || !PositionSelectByTicket(ticket))
   {
      // Broker confirmed the fill but the terminal has not listed the position yet.
      if(live) { LiveStartReconcile(p,comment,requestPrice,"broker báo khớp nhưng chưa thấy vị thế"); return; }
      MXFail("Không tìm được vị thế vừa khớp"); return;
   }
   MXNativeAfterFill(p,ticket,requestPrice,live,comment);
}
// Post-fill protection shared by the direct path and the reconcile path.
void MXNativeAfterFill(const MXPosition &p,const ulong ticket,const double requestPrice,
                       const bool live,const string comment)
{
   if(!PositionSelectByTicket(ticket))
   {
      // Reconcile path only: the position closed at the broker (SL/TP) before adoption.
      if(live) { Print("V4.52 ĐỐI CHIẾU: vị thế ",ticket," (",comment,") đã đóng trước khi đưa vào quản lý."); return; }
      MXFail("Không tìm được vị thế vừa khớp"); return;
   }
   double actualVolume=PositionGetDouble(POSITION_VOLUME);
   if(actualVolume<=0.0) { if(live)LiveSetTradingBlock("Lệnh báo khớp nhưng không tìm thấy khối lượng",false); MXFail("Lệnh được báo khớp nhưng không tìm thấy volume vị thế");return; }
   if(!live && MathAbs(actualVolume-p.initialLot)>g_lotStep*0.1)
      {MXFail("Khớp thiếu khối lượng tham chiếu, dừng để đối chiếu trước khi xếp hạng");return;}
   MXNative n; ZeroMemory(n);
   n.shadowID=p.id;n.engine=p.engine;n.method=p.method;
   n.ticket=ticket; n.buy=p.buy; n.entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double actualSL=PositionGetDouble(POSITION_SL);
   if(actualSL<=0.0 || PositionGetDouble(POSITION_TP)<=0.0)
   {
      MqlTick closeQuote; SymbolInfoTick(_Symbol,closeQuote);
      bool closed=g_executor.PositionClose(ticket);
      MXAuditRequest("MISSING_PROTECTIVE_STOPS_CLOSE",p.id,p.engine,ticket,!p.buy,closeQuote,closed);
      if(!closed || !MXNativeOK()) {LiveSetTradingBlock("Vị thế thiếu SL/TP và không đóng được",false);MXFail("Vị thế khớp thiếu SL/TP và không đóng được");}
      else Print("V4.52 đã đóng an toàn vị thế thiếu SL/TP; tiếp tục chờ tín hiệu mới.");
      return;
   }
   n.risk=MathAbs(n.entry-actualSL);
   if(live && !LiveRiskInsideLimits(n.risk,LiveMinRiskTolerance()))
   {
      g_statPostFillRiskClose++;
      string why=StringFormat("Khớp %s tại %s, yêu cầu %s: %s; đóng vị thế bảo vệ",
                              comment,DoubleToString(n.entry,_Digits),DoubleToString(requestPrice,_Digits),
                              LiveRiskText(n.risk,LiveMinRiskTolerance()));
      Print("V4.52 INVALID_RISK_CLOSE: ",why);
      MatrixEvent(p.engine,p.method,"INVALID_RISK_CLOSE","ERROR",why,p.signalTime,comment);
      MqlTick closeQuote; SymbolInfoTick(_Symbol,closeQuote);
      bool closed=g_executor.PositionClose(ticket);
      MXAuditRequest("INVALID_RISK_CLOSE",p.id,p.engine,ticket,!p.buy,closeQuote,closed);
      if(!closed || !MXNativeOK()) {LiveSetTradingBlock("Không đóng được vị thế có khoảng SL vượt giới hạn",false);MXFail("Không đóng được vị thế có khoảng SL vượt giới hạn");}
      else Print("V4.52 đã đóng vị thế có khoảng SL không hợp lệ; tiếp tục chờ tín hiệu mới.");
      return;
   }
   if(live && n.risk<InpMinSLPriceDistance)
   {
      g_statMinSLTolerance++;
      Print(StringFormat("V4.52 GIỮ VỊ THẾ %I64u (%s): SL %.2f giá < %.2f do khớp lệch %.2f giá so với yêu cầu; "
                         "nằm trong dung sai %.2f, rủi ro tiền không tăng vì lot tính theo giá yêu cầu.",
                         ticket,comment,n.risk,InpMinSLPriceDistance,n.entry-requestPrice,LiveMinRiskTolerance()));
   }
   n.tp1=n.buy?n.entry+n.risk*InpTP1AtR:n.entry-n.risk*InpTP1AtR;
   n.tp2=PositionGetDouble(POSITION_TP);
   n.part=MXFloorLot(actualVolume*InpTP1ClosePct/100.0);
   if(n.part<g_minLot || actualVolume-n.part<g_minLot) n.part=0.0;
   if(MathAbs(n.entry-requestPrice)>InpTruotGiaToiDaGia+g_priceStep*0.5)
   {
      MatrixEvent(p.engine,p.method,"NATIVE_SLIPPAGE","ERROR","Khớp vượt 0.30 giá; yêu cầu đóng vị thế",p.signalTime,comment);
      MqlTick closeQuote;SymbolInfoTick(_Symbol,closeQuote);
      bool closed=g_executor.PositionClose(ticket);
      MXAuditRequest("SLIPPAGE_CLOSE",p.id,p.engine,ticket,!p.buy,closeQuote,closed);
      if(!closed || !MXNativeOK()) {LiveSetTradingBlock("Không đóng được lệnh vượt giới hạn trượt giá",false);MXFail("Không đóng được lệnh vượt giới hạn trượt giá");}
      g_wallets[p.wallet].nativeErrors++;
      if(!live) MXFail("Tham chiếu trượt quá 0.30 giá, dừng đối chiếu.");
      else Print("V4.52 đã đóng lệnh vượt giới hạn trượt giá; tiếp tục chờ tín hiệu mới.");
      return;
   }
   int count=ArraySize(g_native); ArrayResize(g_native,count+1); g_native[count]=n;
   if(live)
   {
      GlobalVariableSet(LivePositionKey("R",n.ticket),n.risk);
      GlobalVariableSet(LivePositionKey("T",n.ticket),n.tp1);
      GlobalVariableSet(LivePositionKey("P",n.ticket),n.part);
      GlobalVariableSet(LivePositionKey("D",n.ticket),n.partialDone?1.0:0.0);
   }
}
void MXNativeManage()
{
   if((MQLInfoInteger(MQL_TESTER) && !InpMatrixLenhTester) ||
      (!MQLInfoInteger(MQL_TESTER) && !InpChoPhepGiaoDichThat)) return;
   for(int i=ArraySize(g_native)-1;i>=0;i--)
   {
      MXNative n=g_native[i];
      if(!LiveSelectOwnedPosition(n.ticket))
      {
         LiveRemoveNativeSlot(i,"broker xác nhận vị thế không còn tồn tại");
         if(g_liveTradingBlocked && g_liveBlockRecoverable)
            LiveClearTradingBlock("vị thế cũ đã đóng và dữ liệu quản lý đã được dọn");
         continue;
      }
      double price=n.buy?g_quote.bid:g_quote.ask;
      if(InpUseTP1Partial && !n.partialDone && (n.buy?price>=n.tp1:price<=n.tp1))
      {
         if(n.part<g_minLot)
            n.partialDone=true;
         else
         {
            if(!LiveSelectOwnedPosition(n.ticket))
            {
               LiveRemoveNativeSlot(i,"vị thế đã đóng trước khi thực hiện TP1");
               if(g_liveTradingBlocked && g_liveBlockRecoverable)
                  LiveClearTradingBlock("bỏ qua TP1 vì vị thế đã đóng");
               continue;
            }
            double oldVolume=PositionGetDouble(POSITION_VOLUME);
            if(n.tp1Base>0.0 && oldVolume<n.tp1Base-g_lotStep*0.5)
            {
               // V4.49: an earlier TP1 request whose result was not confirmed has been
               // executed by the broker. Count it; never send a second partial close for it.
               double doneEarlier=n.tp1Base-oldVolume;
               n.part=MathMax(0.0,n.part-doneEarlier); n.partialDone=n.part<g_lotStep*0.5;
               n.tp1Base=n.partialDone?0.0:oldVolume;
               Print("V4.52 TP1 ticket ",n.ticket,": broker đã đóng ",DoubleToString(doneEarlier,2),
                     " lot từ yêu cầu trước; không gửi lại phần đã đóng.");
               if(g_liveTradingBlocked && StringFind(g_liveBlockReason,"ticket "+IntegerToString((long)n.ticket)+":")>=0)
                  LiveClearTradingBlock("đã xác minh TP1 được broker thực hiện");
            }
            if(n.partialDone || GetTickCount64()<n.tp1RetryTick)
            {
               g_native[i]=n;
            }
            else if(oldVolume<=0.0 || n.part>oldVolume-g_minLot+g_lotStep*0.1)
            {
               n.part=0.0; n.partialDone=true;
               MatrixEvent(n.engine,n.method,"TP1","SKIPPED","Khối lượng còn lại không đủ để đóng một phần",TimeCurrent(),"ticket="+IntegerToString((long)n.ticket));
               g_native[i]=n;
               continue;
            }
            else
            {
            MqlTick before;
            if(!SymbolInfoTick(_Symbol,before))
            {
               // Nothing was sent; retry on the next tick without blocking new entries.
               Print("V4.52: không lấy được giá trước khi đóng TP1 ticket ",n.ticket,"; thử lại ở tick sau.");
               continue;
            }
            n.tp1Base=oldVolume;
            bool ok=g_executor.PositionClosePartial(n.ticket,n.part);
            bool accepted=MXAuditRequest("TP1",n.shadowID,n.engine,n.ticket,!n.buy,before,ok);
            if(g_fatal)return;
            if(accepted)
            {
               double left=PositionSelectByTicket(n.ticket)?PositionGetDouble(POSITION_VOLUME):0.0;
               double done=MathMax(0.0,oldVolume-left);
               n.part=MathMax(0.0,n.part-done);n.partialDone=n.part<g_lotStep*0.5;
               n.tp1Base=0.0;
               if(g_liveTradingBlocked && StringFind(g_liveBlockReason,IntegerToString((long)n.ticket))>=0)
                  LiveClearTradingBlock("đóng TP1 thành công sau lần broker từ chối trước");
            }
            else if(!MQLInfoInteger(MQL_TESTER))
            {
               uint ret=g_executor.ResultRetcode();
               if(!LiveSelectOwnedPosition(n.ticket) || ret==TRADE_RETCODE_POSITION_CLOSED)
               {
                  LiveRemoveNativeSlot(i,"TP1 nhận position closed; broker xác nhận vị thế đã đóng");
                  if(g_liveTradingBlocked && g_liveBlockRecoverable)
                     LiveClearTradingBlock("đã xác minh position closed là trạng thái bình thường");
                  continue;
               }
               MatrixEvent(n.engine,n.method,"TP1","ERROR",g_executor.ResultRetcodeDescription(),TimeCurrent(),"ticket="+IntegerToString((long)n.ticket));
               double nowVolume=PositionGetDouble(POSITION_VOLUME);
               if(nowVolume<oldVolume-g_lotStep*0.5)
               {
                  // Reported as failed but the broker reduced the volume: treat as executed.
                  double doneNow=oldVolume-nowVolume;
                  n.part=MathMax(0.0,n.part-doneNow); n.partialDone=n.part<g_lotStep*0.5;
                  n.tp1Base=n.partialDone?0.0:nowVolume;
                  Print("V4.52 TP1 ticket ",n.ticket,": broker báo lỗi nhưng khối lượng đã giảm ",
                        DoubleToString(doneNow,2)," lot; ghi nhận đã chốt, không gửi lại.");
               }
               else if(LiveTransientRetcode(ret))
               {
                  Print("V4.52 TP1 ticket ",n.ticket,": broker từ chối tạm thời (",ret," ",
                        g_executor.ResultRetcodeDescription(),"); thử lại ở tick sau, không khóa lệnh mới.");
               }
               else if(LiveUncertainRetcode(ret))
               {
                  n.tp1RetryTick=GetTickCount64()+(ulong)LIVE_RECONCILE_SECONDS*1000;
                  Print("V4.52 TP1 ticket ",n.ticket,": kết quả chưa rõ (",ret," ",
                        g_executor.ResultRetcodeDescription(),"); chờ ",LIVE_RECONCILE_SECONDS,
                        " giây rồi đối chiếu khối lượng trước khi gửi lại.");
               }
               else
                  LiveSetTradingBlock("Broker từ chối đóng TP1 ticket "+IntegerToString((long)n.ticket)+": "+g_executor.ResultRetcodeDescription(),false);
            }
            }
         }
      }
      if(!LiveSelectOwnedPosition(n.ticket))
      {
         LiveRemoveNativeSlot(i,"vị thế đóng trong lúc xử lý TP1/SL/TP");
         continue;
      }
      double old=PositionGetDouble(POSITION_SL), candidate=old;
      if(n.partialDone) candidate=n.buy?MathMax(old,n.entry):MathMin(old,n.entry);
      double fav=n.buy?price-n.entry:n.entry-price;
      if(InpUseTrailing && fav>=InpTrailStartR*n.risk)
      {
         double next=n.buy?MathMax(n.entry,price-InpTrailDistanceR*n.risk):MathMin(n.entry,price+InpTrailDistanceR*n.risk);
         candidate=n.buy?MathMax(candidate,next):MathMin(candidate,next);
      }
      candidate=MXPrice(candidate,!n.buy);
      double safety=(MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+1)*_Point;
      bool better=n.buy?candidate>old+InpTrailStepGia && candidate<price-safety && candidate<n.tp2:
                          candidate<old-InpTrailStepGia && candidate>price+safety && candidate>n.tp2;
      if(better)
      {
         MqlTick before;SymbolInfoTick(_Symbol,before);
         bool ok=g_executor.PositionModify(n.ticket,candidate,n.tp2);
         bool accepted=MXAuditRequest("MODIFY_SL",n.shadowID,n.engine,n.ticket,n.buy,before,ok);
         if(g_fatal)return;
         if(!accepted && !LiveSelectOwnedPosition(n.ticket))
         {
            LiveRemoveNativeSlot(i,"vị thế đóng trong lúc dời BE/Trailing");
            continue;
         }
      }
      g_native[i]=n;
      if(!MQLInfoInteger(MQL_TESTER))
      {
         GlobalVariableSet(LivePositionKey("P",n.ticket),n.part);
         GlobalVariableSet(LivePositionKey("D",n.ticket),n.partialDone?1.0:0.0);
      }
   }
}
void MXNativeCloseAll()
{
   if((MQLInfoInteger(MQL_TESTER) && !InpMatrixLenhTester) ||
      (!MQLInfoInteger(MQL_TESTER) && !InpChoPhepGiaoDichThat)) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      MqlTick before;SymbolInfoTick(_Symbol,before);
      bool ok=g_executor.PositionClose(ticket);
      MXAuditRequest("FINAL_CLOSE",0,-1,ticket,!buy,before,ok);
      if(!ok || !MXNativeOK())
         Print("V4.52 không đóng được tham chiếu cuối test: ",ticket," ",g_executor.ResultRetcodeDescription());
   }
}
void MXClose(const int slot,const double price,const string reason)
{
   MXPosition p=g_positions[slot]; int w=p.wallet;
   double commission=InpMatrixPhiKhuHoiLot*p.left*0.5;
   double cash=MXProfit(p.buy,p.left,p.entry,price)-commission;
   p.net+=cash; MXCash(w,cash); g_wallets[w].commission+=commission;
   g_wallets[w].margin=MathMax(0.0,g_wallets[w].margin-p.margin);
   g_wallets[w].open--; g_wallets[w].openFamily[p.engine]--; p.left=0.0;
   MXStatClose(g_wallets[w].all,p.net);
   if(InpMatrixTuNgayKiemChung>0 && p.opened>=InpMatrixTuNgayKiemChung) MXStatClose(g_wallets[w].holdout,p.net);
   else MXStatClose(g_wallets[w].train,p.net);
   if(g_monthSlot>=0)
   {
      int k=g_monthSlot*ArraySize(g_wallets)+w;
      g_months[k].trades++; if(p.net>1e-8) g_months[k].wins++;
   }
   if(reason=="END_TEST" || reason=="STOPPED_EARLY") g_wallets[w].forced++;
   MXTradeLog(p,reason,price,cash);
   g_positions[slot]=g_positions[ArraySize(g_positions)-1];
   ArrayResize(g_positions,ArraySize(g_positions)-1);
}
void MXMarkAllActive()
{
   for(int j=0;j<ArraySize(g_activeWallets);j++) g_wallets[g_activeWallets[j]].floating=0.0;
   for(int i=0;i<ArraySize(g_positions);i++)
   {
      MXPosition p=g_positions[i];
      // Reserve exit commission in floating P&L; prevents understated Equity DD.
      g_wallets[p.wallet].floating+=MXProfit(p.buy,p.left,p.entry,p.buy?g_quote.bid:g_quote.ask)-InpMatrixPhiKhuHoiLot*p.left*0.5;
   }
   for(int j=ArraySize(g_activeWallets)-1;j>=0;j--)
   {
      int w=g_activeWallets[j]; MXMark(w);
      if(g_wallets[w].open==0)
      {
         g_wallets[w].listed=false;
         g_activeWallets[j]=g_activeWallets[ArraySize(g_activeWallets)-1];
         ArrayResize(g_activeWallets,ArraySize(g_activeWallets)-1);
      }
   }
}
void MXUpdatePositions()
{
   for(int i=ArraySize(g_positions)-1;i>=0;i--)
   {
      MXPosition p=g_positions[i]; double price=p.buy?g_quote.bid:g_quote.ask;
      double fav=p.buy?price-p.entry:p.entry-price;
      p.mfe=MathMax(p.mfe,fav); p.mae=MathMax(p.mae,-fav);
      g_positions[i]=p;
      // Gap risk is REAL: use available quote, never cap stop loss at 0.30.
      if(p.buy?price<=p.sl:price>=p.sl) { MXClose(i,price,"SL"); continue; }
      // Attached TP2 is processed by the tester before EA-managed partial TP1.
      // The user's real-tick Tester fills TP2 at the executable quote, including
      // favourable gaps. Confirmed by all 44 TP2 closes in the V4.38 sample.
      if(p.buy?price>=p.tp2:price<=p.tp2) { MXClose(i,price,"TP2"); continue; }
      if(InpUseTP1Partial && !p.partialDone && (p.buy?price>=p.tp1:price<=p.tp1))
      {
         double fee=InpMatrixPhiKhuHoiLot*p.part*0.5;
         double cash=MXProfit(p.buy,p.part,p.entry,price)-fee;
         double released=p.margin*p.part/p.left;
         p.margin-=released; g_wallets[p.wallet].margin-=released;
         p.left=NormalizeDouble(p.left-p.part,8); p.net+=cash; p.partialDone=true;
         p.sl=p.entry; MXCash(p.wallet,cash); g_wallets[p.wallet].commission+=fee;
         MXTradeLog(p,"TP1",price,cash);
      }
      g_positions[i]=p;
      if(InpUseTrailing && fav>=InpTrailStartR*p.risk)
      {
         double next=p.buy?MathMax(p.entry,price-InpTrailDistanceR*p.risk):MathMin(p.entry,price+InpTrailDistanceR*p.risk);
         next=MXPrice(next,!p.buy);
         double safety=(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*_Point;
         if(p.buy?next>p.sl+InpTrailStepGia && next<price-safety && next<p.tp2:
                  next<p.sl-InpTrailStepGia && next>price+safety && next>p.tp2) p.sl=next;
      }
      g_positions[i]=p;
   }
   MXMarkAllActive();
   // Conservative standalone margin model. Does not net hedge offsets.
   for(int j=ArraySize(g_activeWallets)-1;j>=0;j--)
   {
      int w=g_activeWallets[j]; double margin=g_wallets[w].margin;
      bool stop=g_wallets[w].equity<=0.0;
      if(margin>0.0)
      {
         double so=AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
         if(AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)==ACCOUNT_STOPOUT_MODE_PERCENT)
            stop=stop || 100.0*g_wallets[w].equity/margin<=so;
         else stop=stop || g_wallets[w].equity-margin<=so;
      }
      if(stop)
      {
         g_wallets[w].stopped=true;
         for(int i=ArraySize(g_positions)-1;i>=0;i--)
            if(g_positions[i].wallet==w) MXClose(i,g_positions[i].buy?g_quote.bid:g_quote.ask,"STOP_OUT_APPROX");
      }
   }
   MXMarkAllActive();
}
double MXSwapPerLot(const bool buy)
{
   if(InpMatrixSwap==MATRIX_SWAP_KHONG) return 0.0;
   if(InpMatrixSwap==MATRIX_SWAP_TAY) return buy?InpMatrixSwapBuy:InpMatrixSwapSell;
   double rate=buy?g_swapLong:g_swapShort;
   if(g_swapMode==SYMBOL_SWAP_MODE_DISABLED) return 0.0;
   if(g_swapMode==SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT) return rate;
   if(g_swapMode==SYMBOL_SWAP_MODE_POINTS)
      return MXProfit(buy,1.0,buy?g_quote.ask:g_quote.bid,
                      (buy?g_quote.ask:g_quote.bid)+(buy?1.0:-1.0)*rate*_Point);
   return 0.0; // Unsupported modes rejected at initialization, not silently ignored.
}
void MXCalendar()
{
   MqlDateTime d; TimeToStruct(g_quote.time,d);
   int day=d.year*10000+d.mon*100+d.day, month=d.year*100+d.mon;
   d.hour=0; d.min=0; d.sec=0; datetime midnight=StructToTime(d);
   if(g_monthSlot<0 || g_monthKeys[g_monthSlot]!=month)
   {
      // Explicitly add no-trade calendar months so the score cannot omit them.
      int next=ArraySize(g_monthKeys)>0?g_monthKeys[ArraySize(g_monthKeys)-1]:month;
      if(ArraySize(g_monthKeys)>0) { int y=next/100,m=next%100+1; if(m>12) {m=1;y++;} next=y*100+m; }
      while(next<=month)
      {
         g_monthSlot=ArraySize(g_monthKeys); ArrayResize(g_monthKeys,g_monthSlot+1); g_monthKeys[g_monthSlot]=next;
         int old=ArraySize(g_months); ArrayResize(g_months,old+ArraySize(g_wallets));
         for(int w=0;w<ArraySize(g_wallets);w++)
         {
            MXMonth m; ZeroMemory(m); m.startEquity=g_wallets[w].equity;
            m.endEquity=m.startEquity; m.peak=m.startEquity; g_months[old+w]=m;
         }
         int y=next/100,mo=next%100+1; if(mo>12) {mo=1;y++;} next=y*100+mo;
      }
   }
   if(g_dayKey!=day)
   {
      // Charge each elapsed rollover using the previous day's broker multiplier.
      if(g_dayStart>0)
      {
         for(datetime t=g_dayStart;t<midnight;t+=86400)
         {
            MqlDateTime prev; TimeToStruct(t,prev); double mult=g_swapDays[prev.day_of_week];
            for(int i=0;i<ArraySize(g_positions);i++)
            {
               if(g_positions[i].opened>=t+86400) continue;
               double cash=MXSwapPerLot(g_positions[i].buy)*g_positions[i].left*mult;
               g_positions[i].net+=cash; MXCash(g_positions[i].wallet,cash);
               g_wallets[g_positions[i].wallet].swap+=cash;
               if(cash!=0.0) MXTradeLog(g_positions[i],"SWAP_ESTIMATE",0.0,cash);
            }
         }
      }
      MXMarkAllActive();
      for(int w=0;w<ArraySize(g_wallets);w++)
      {
         g_wallets[w].dayStart=(!MQLInfoInteger(MQL_TESTER) && InpChoPhepGiaoDichThat && w==0)?
                                AccountInfoDouble(ACCOUNT_EQUITY):g_wallets[w].equity;
         g_wallets[w].dayEntries=0;
      }
      g_liveDailyStopped=false;
      if(!MQLInfoInteger(MQL_TESTER) && InpChoPhepGiaoDichThat)
      {
         GlobalVariableSet(LiveDayKeyName(),day); GlobalVariableSet(LiveDayEquityKey(),g_wallets[0].dayStart);
         GlobalVariableSet(LiveDayStopKey(),0.0);
      }
      g_dayStart=midnight; g_dayKey=day;
   }
}
double MXLot(const int w,const bool buy,const double entry,const double sl)
{
   if(InpVolumeMode==LOT_CO_DINH) return MXFloorLot(InpGiaTriKhoiLuong);
   double sizingEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   double budget=InpVolumeMode==LOT_THEO_PHAN_TRAM_TAI_KHOAN?
                   sizingEquity*InpGiaTriKhoiLuong/100.0:InpGiaTriKhoiLuong*g_moneyFactor;
   double one=0.0,calcProfit=0.0;
   if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,1.0,entry,sl,calcProfit)) return 0.0;
   one=-calcProfit+InpMatrixPhiKhuHoiLot;
   if(one<=0.0 || budget<=0.0) return 0.0;
   return MXFloorLot(MathMin(g_maxLot,budget/one));
}
void MXReject(const int w,const int engine,const string method,const string why)
{
   g_wallets[w].rejected++;
   // Aggregate rejects in summary; detail optional to keep files bounded.
   if(InpGhiTinHieuBiLoai) MatrixEvent(engine,method,"MONEY_GUARD","REJECT_MONEY",why,g_quote.time,"wallet="+IntegerToString(w));
}
void MXOpen(const int w,const int engine,const int family,const string method,
            const bool buy,const datetime signalTime,const double baseEntry,
            const double sl,const double tp,const string details)
{
   if(g_wallets[w].stopped || g_wallets[w].equity<=0.0 || g_liveTradingBlocked || g_liveDailyStopped || LiveNewEntryPaused()) return;
   if(engine<0 || engine>=10) { MXFail("Mã cấu hình danh mục vượt giới hạn"); return; }
   int currentOpen=LiveOpenCount();
   int currentFamilyOpen=LiveOpenCountForEngine(engine);
   if(currentOpen>=InpMaxIndependentPositions || currentFamilyOpen>=InpMatrixLenhMoiPP)
      { MXReject(w,engine,method,"DA_CO_LENH"); return; }
   // V4.50: no cap on new entries per day. Daily loss stop uses the EA-only
   // day P/L (closed today + floating) against the Balance at server midnight.
   if(DHDailyLossReached())
   {
      DHSetDailyStop();
      MXReject(w,engine,method,"GIOI_HAN_LO_NGAY"); return;
   }
   MXPosition p; ZeroMemory(p);
   p.wallet=w; p.engine=engine; p.family=family; p.id=g_nextPosition++;
   p.method=method; p.buy=buy; p.signalTime=signalTime; p.opened=g_quote.time;
   p.entry=MXPrice(baseEntry,buy);
   p.initialSL=sl; p.sl=sl; p.risk=MathAbs(p.entry-sl);
   if(p.risk<InpMinSLPriceDistance-g_priceStep*0.5 || p.risk>InpMaxSLPriceDistance+g_priceStep*0.5)
      { MXReject(w,engine,method,"SL_NGOAI_5_20_GIA"); return; }
   double rr=MathAbs(tp-baseEntry)/MathAbs(baseEntry-sl);
   if(rr<1.0-1e-8) { MXReject(w,engine,method,"RR_DUOI_1"); return; }
   p.tp2=MXPrice(p.entry+(buy?1.0:-1.0)*rr*p.risk,buy);
   p.tp1=MXPrice(p.entry+(buy?1.0:-1.0)*InpTP1AtR*p.risk,buy);
   p.initialLot=MXLot(w,buy,p.entry,sl);
   bool validSplit=MXSplitOrSkipPartialLive(p.initialLot,p.part);
   if(p.initialLot<g_minLot-1e-8 || p.initialLot>g_maxLot+1e-8 || !validSplit)
      { MXReject(w,engine,method,"LOT_KHONG_HOP_LE_HOAC_KHONG_CHIA_DUOC_TP1"); return; }
   if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,p.initialLot,p.entry,p.margin))
      { MXFail("Không tính được margin tại tín hiệu"); return; }
   double volumeLimit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT),sameLots=0.0;
   if(volumeLimit>0.0)
      for(int j=PositionsTotal()-1;j>=0;j--)
      {
         ulong ticket=PositionGetTicket(j);
         if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
            (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic &&
            ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)==buy)
            sameLots+=PositionGetDouble(POSITION_VOLUME);
      }
   if(volumeLimit>0.0 && sameLots+p.initialLot>volumeLimit+1e-8)
      { MXReject(w,engine,method,"GIOI_HAN_KHOI_LUONG_SAN"); return; }
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)<p.margin)
      { MXReject(w,engine,method,"THIEU_MARGIN"); return; }
   p.left=p.initialLot;
   if(((MQLInfoInteger(MQL_TESTER) && InpMatrixLenhTester) ||
       (!MQLInfoInteger(MQL_TESTER) && InpChoPhepGiaoDichThat)))
   {
      int q=ArraySize(g_nativeQueue);ArrayResize(g_nativeQueue,q+1);g_nativeQueue[q]=p;
      MatrixEvent(engine,method,"LIVE_SIGNAL","READY","Tín hiệu đã qua bộ lọc và chờ gửi broker",signalTime,details);
   }
}
void MatrixSignal(const int engine,const int family,const bool isBase,
                  const string method,const bool buy,const datetime signalTime,
                  const ENUM_TIMEFRAMES timeframe,const double entry,const double sl,
                  const double tp,const string source,const string details)
{
   if(!g_ready || g_fatal || engine<0 || engine>=ArraySize(g_engines)) return;
   if(entry<=0.0 || sl<=0.0 || tp<=0.0 || (buy?(sl>=entry || tp<=entry):(sl<=entry || tp>=entry))) return;
   double risk=MathAbs(entry-sl);
   double safety=(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*_Point;
   if(risk<InpMinSLPriceDistance-g_priceStep*0.5 || risk>InpMaxSLPriceDistance+g_priceStep*0.5 ||
      (buy?(sl>=g_quote.bid-safety || tp<=g_quote.ask+safety):(sl<=g_quote.ask+safety || tp>=g_quote.bid-safety))) return;
   if(InpSpreadToiDaGia>0.0 && g_quote.ask-g_quote.bid>InpSpreadToiDaGia) return;
   string trace=source+"|tf="+EnumToString(timeframe)+"|"+details;
   int session=g_engines[engine].GetSession(g_quote.time);
   if(engine>=ArraySize(g_engineSession) ||
      (g_engineSession[engine]>0 && g_engineSession[engine]!=session)) return;
   for(int w=g_walletStart[engine];w<g_walletStart[engine]+g_walletCount[engine];w++)
   {
      if(g_wallets[w].direction!=0 && g_wallets[w].direction!=(buy?1:2)) continue;
      if(g_wallets[w].session!=0 && g_wallets[w].session!=session) continue;
      MXOpen(w,engine,family,method,buy,signalTime,entry,sl,tp,trace);
   }
}

string MXTrim(string s) { StringTrimLeft(s); StringTrimRight(s); return s; }
bool MXNumber(string s,double &v)
{
   s=MXTrim(s); string t=s; StringToUpper(t);
   if(t=="TRUE") {v=1.0;return true;} if(t=="FALSE") {v=0.0;return true;}
   if(StringFind(t,"PERIOD_")==0) t=StringSubstr(t,7);
   if(t=="CURRENT") {v=0;return true;}
   if(t=="D1") {v=16408;return true;} if(t=="W1") {v=32769;return true;} if(t=="MN1") {v=49153;return true;}
   if(StringLen(t)>1 && (StringSubstr(t,0,1)=="M" || StringSubstr(t,0,1)=="H"))
   {
      string tail=StringSubstr(t,1); int k=(int)StringToInteger(tail);
      if(IntegerToString(k)!=tail) return false;
      v=StringSubstr(t,0,1)=="H"?16384+k:k; return MatrixValidTF((int)v);
   }
   if(s=="") return false;
   bool digit=false,dot=false;
   for(int i=0;i<StringLen(s);i++)
   {
      ushort c=StringGetCharacter(s,i);
      if(c>='0' && c<='9') {digit=true;continue;}
      if((c=='+' || c=='-') && i==0) continue;
      if(c=='.' && !dot) {dot=true;continue;}
      return false;
   }
   v=StringToDouble(s); return digit && MathIsValidNumber(v);
}
void MXOneFamily(MatrixConfig &c,const int family)
{
   // Mã family giữ nguyên như V4.48: 5=ENG, 7=BRK, 9=PVT. V4.53: 0=EMA.
   c.InpUseENGModule=family==5; c.InpUseBRKModule=family==7;
   c.InpUsePVTModule=family==9; c.InpUseEMAModule=family==0;
   c.InpPVCachKetHop=PV_MOI_PP_DOC_LAP; c.InpPVMauPriceAction=PV_CA_BA_MAU;
}
string MXGrid(const int f)
{
   if(f==5)return InpLuoiENG; if(f==7)return InpLuoiBRK; if(f==9)return InpLuoiPVT;
   return "";
}
int MXAddWallet(const int engine,const int direction,const int session)
{
   int w=ArraySize(g_wallets);
   if(w>0) return 0;
   MXWallet p; ZeroMemory(p); p.engine=engine; p.direction=direction; p.session=session;
   p.initial=AccountInfoDouble(ACCOUNT_BALANCE);
   p.balance=p.initial; p.equity=p.initial; p.peak=p.initial; p.dayStart=p.initial;
   ArrayResize(g_wallets,w+1,2048); g_wallets[w]=p;
   FileWrite(g_hWallet,w,engine,MXDirection(direction),MXSession(session),MXMoney(p.initial),g_currency,
             "LIVE_REAL_ACCOUNT");
   return w;
}
bool MXAddEngine(const MatrixConfig &cfg,const int family,const bool base,const string axis,const int allowedSession)
{
   int n=ArraySize(g_engines);
   if(n>=5) { MXFail("V4.53 hỗ trợ tối đa năm cấu hình LIVE (BRK/PVT/ENG/ENG/EMA)."); return false; }
   CDHSignalEngine *e=new CDHSignalEngine;
   if(CheckPointer(e)==POINTER_INVALID) { MXFail("Thiếu bộ nhớ cho cấu hình"); return false; }
   e.cfg=cfg; e.engineID=n; e.family=family; e.isBase=base;
   if(e.Initialize()!=INIT_SUCCEEDED)
   {
      e.Release(); delete e;
      MXFail("Cấu hình không hợp lệ: "+MXFamily(family)+" "+axis); return false;
   }
   ArrayResize(g_engines,n+1); g_engines[n]=e;
   ArrayResize(g_axisDescriptions,n+1); g_axisDescriptions[n]=axis;
   ArrayResize(g_walletStart,n+1); ArrayResize(g_walletCount,n+1); ArrayResize(g_engineSession,n+1);
   g_walletStart[n]=0; g_walletCount[n]=1; g_engineSession[n]=allowedSession;
   FileWrite(g_hConfig,n,MXFamily(family),base?"BASE":"GRID",axis,MatrixConfigText(cfg));
   return true;
}
bool MXBuildFamily(const int family)
{
   MatrixConfig base=g_base; MXOneFamily(base,family);
   if(!MXAddEngine(base,family,true,"BASE",0)) return false;
   if(!InpMatrixQuetLuoi || MXTrim(MXGrid(family))=="") return true;
   string items[]; int count=StringSplit(MXGrid(family),'|',items);
   if(count<1 || count>12) {MXFail("Mỗi lưới cần 1-12 trục input");return false;}
   MXAxis axes[]; ArrayResize(axes,count); long combinations=1;
   for(int i=0;i<count;i++)
   {
      string kv[]; if(StringSplit(items[i],'=',kv)!=2) {MXFail("Sai cú pháp lưới: "+items[i]);return false;}
      axes[i].name=MXTrim(kv[0]);
      for(int j=0;j<i;j++) if(axes[j].name==axes[i].name) {MXFail("Trùng trục input: "+axes[i].name);return false;}
      string vals[]; int nv=StringSplit(kv[1],',',vals);
      if(nv<1 || nv>32) {MXFail("Mỗi trục cần 1-32 giá trị");return false;}
      ArrayResize(axes[i].values,nv);
      for(int j=0;j<nv;j++)
      {
         double v=0.0; MatrixConfig probe=base;
         if(!MXNumber(vals[j],v) || !MatrixSetValue(probe,axes[i].name,v))
            {MXFail("Tên hoặc giá trị trục không được hỗ trợ: "+items[i]);return false;}
         for(int k=0;k<j;k++) if(axes[i].values[k]==v) {MXFail("Giá trị lưới bị lặp: "+items[i]);return false;}
         axes[i].values[j]=v;
      }
      combinations*=nv;
      if(combinations>InpMatrixToiDaBo) {MXFail("Một phương pháp có quá nhiều tổ hợp; giảm số giá trị mỗi trục");return false;}
   }
   string baseline=MatrixConfigText(base);
   for(long index=0;index<combinations;index++)
   {
      long remaining=index; MatrixConfig cfg=base; string desc="";
      for(int a=0;a<count;a++)
      {
         int n=ArraySize(axes[a].values), valueIndex=(int)(remaining%n); remaining/=n;
         double value=axes[a].values[valueIndex];
         if(!MatrixSetValue(cfg,axes[a].name,value)) return false;
         if(desc!="")desc+="|"; desc+=axes[a].name+"="+DoubleToString(value,8);
      }
      if(MatrixConfigText(cfg)==baseline) continue;
      if(!MXAddEngine(cfg,family,false,desc,0)) return false;
   }
   return true;
}

string LiveBarLogKey(const ENUM_TIMEFRAMES tf)
{
   return "DH448_BAR_"+IntegerToString((long)InpMagic)+"_"+_Symbol+"_"+IntegerToString((int)tf);
}
void MXLogBarStream(const ENUM_TIMEFRAMES tf,const int handle,datetime &lastBar,const bool includeTF)
{
   if(handle==INVALID_HANDLE) return;
   string key=LiveBarLogKey(tf);
   if(lastBar==0 && GlobalVariableCheck(key)) lastBar=(datetime)GlobalVariableGet(key);
   datetime bar=iTime(_Symbol,tf,1);
   if(bar<=0 || bar==lastBar) return;
   int count=1;
   if(lastBar>0) count=(int)MathMax(1,iBarShift(_Symbol,tf,lastBar,false)-1);
   MqlRates r[]; ArraySetAsSeries(r,true); int n=CopyRates(_Symbol,tf,1,count,r);
   if(n<1)return;
   string kind=includeTF?"bars_"+_Symbol+"_CURRENT":"bars_"+_Symbol+"_M1";
   string header=includeTF?DH_HDR_BARS_CUR:DH_HDR_BARS_M1;
   int oldHandle=INVALID_HANDLE, oldMonth=0;
   for(int i=n-1;i>=0;i--)
   {
      if(r[i].time<=lastBar) continue;
      // V4.50: a bar of the previous month logged after the switch goes to its own month file.
      int h=handle, mk=DHMonthKey(r[i].time);
      if(mk<g_logMonth)
      {
         if(oldMonth!=mk) { if(oldHandle!=INVALID_HANDLE) FileClose(oldHandle); oldHandle=MXFileMonth(kind,header,mk); oldMonth=mk; }
         if(oldHandle==INVALID_HANDLE) continue;
         h=oldHandle;
      }
      if(includeTF) FileWrite(h,MXTime(r[i].time),EnumToString(tf),DoubleToString(r[i].open,_Digits),
         DoubleToString(r[i].high,_Digits),DoubleToString(r[i].low,_Digits),DoubleToString(r[i].close,_Digits),r[i].tick_volume,r[i].spread);
      else FileWrite(h,MXTime(r[i].time),DoubleToString(r[i].open,_Digits),
         DoubleToString(r[i].high,_Digits),DoubleToString(r[i].low,_Digits),DoubleToString(r[i].close,_Digits),r[i].tick_volume,r[i].spread);
   }
   if(oldHandle!=INVALID_HANDLE) FileClose(oldHandle);
   lastBar=bar; GlobalVariableSet(key,(double)lastBar);
}
void MXLogBars()
{
   MXLogBarStream(PERIOD_M1,g_hBars,g_lastBarLog,false);
   MXLogBarStream((ENUM_TIMEFRAMES)_Period,g_hBarsCurrent,g_lastCurrentBarLog,true);
}
void MXLogEquity(const bool force=false)
{
   if(g_hEquity==INVALID_HANDLE) return;
   if(!force && g_lastEquityLog>0 && g_quote.time-g_lastEquityLog<InpMatrixGhiEquityPhut*60) return;
   FileWrite(g_hEquity,MXTime(g_quote.time),AccountInfoInteger(ACCOUNT_LOGIN),
      MXMoney(AccountInfoDouble(ACCOUNT_BALANCE)),MXMoney(AccountInfoDouble(ACCOUNT_EQUITY)),
      MXMoney(g_liveMaxDD),LiveOpenCount(),g_currency);
   g_lastEquityLog=g_quote.time;
}
void MXPanel()
{
   if(!InpMatrixBangNhe || !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   ulong now=GetTickCount64(); if(now-g_lastPanel<1000) return; g_lastPanel=now;
   int r=0; if(r>=ArraySize(g_wallets))return;
   Comment("DAVID HUNTER V4.53 | BẢNG TRẠNG THÁI\n",
           "Bộ tín hiệu: ",ArraySize(g_engines)," | Tài khoản độc lập: ",ArraySize(g_wallets),
           " | Lệnh ảo đang mở: ",ArraySize(g_positions),"\n",
           "Graph MT5 chỉ là tham chiếu ID ",r,"; không cộng vốn các tổ hợp\n",
           "MT5 Balance: ",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),
           " | Equity: ",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)," ",g_currency,"\n",
           "Mô phỏng ID ",r,": Equity ",DoubleToString(g_wallets[r].equity,2),
           " | DD ",DoubleToString(g_wallets[r].ddPct,2),"% | ",g_wallets[r].all.trades," lệnh đóng\n",
           "Kết quả xếp hạng trong: ",g_runFolder,"\n",
           "Swap mô phỏng là ước tính; không bảo đảm lợi nhuận tương lai.");
}
int MXPositiveMonths(const int w)
{
   int n=0; for(int m=0;m<ArraySize(g_monthKeys);m++) if(g_months[m*ArraySize(g_wallets)+w].net>0.0)n++; return n;
}
string MXQualification(const int w)
{
   if(g_wallets[w].all.trades==0)return "KHONG_CO_LENH";
   if(g_fatal)return "DU_LIEU_LOI";
   if(g_wallets[w].stopped)return "STOP_OUT";
   if(g_wallets[w].all.trades<InpMatrixSoLenhTinCay || g_wallets[w].all.losses<5 || ArraySize(g_monthKeys)<InpMatrixSoThangTinCay)return "THIEU_MAU";
   if(g_wallets[w].all.net<=0.0)return "LO";
   if(InpMatrixTuNgayKiemChung==0)return "THAM_DO_CHUA_KIEM_CHUNG";
   if(g_wallets[w].holdout.trades<30)return "KIEM_CHUNG_THIEU_MAU";
   if(g_wallets[w].holdout.net<=0.0)return "KIEM_CHUNG_AM";
   return "UNG_VIEN_CAN_TEST_LAI";
}
bool MXEnough(const int w)
{
   return !g_fatal && !g_wallets[w].stopped && g_wallets[w].all.trades>=InpMatrixSoLenhTinCay &&
          g_wallets[w].all.losses>=5 && ArraySize(g_monthKeys)>=InpMatrixSoThangTinCay;
}
double MXScore(const int w)
{
   MXWallet p=g_wallets[w];
   if(!MXEnough(w) || p.all.net<=0.0) return -1000000.0+(p.all.trades>0?p.all.net/p.initial:0.0);
   double recovery=p.all.net/MathMax(p.ddMoney,p.initial*0.001);
   double stability=ArraySize(g_monthKeys)>0?(double)MXPositiveMonths(w)/ArraySize(g_monthKeys):0.0;
   // Exploratory score only; independent columns and Pareto front also exported.
   double score=100.0*MathMin(10.0,recovery)+25.0*MathMin(5.0,MXPF(p.all))+
                100.0*stability+MXWR(p.all)-2.0*p.ddPct;
   if(InpMatrixTuNgayKiemChung>0 && (p.holdout.trades<30 || p.holdout.net<=0.0)) score-=1000.0;
   return score;
}
bool MXPareto(const int w)
{
   if(!MXEnough(w) || g_wallets[w].all.net<=0.0)return false;
   for(int j=1;j<ArraySize(g_wallets);j++)
   {
      if(j==w || !MXEnough(j))continue;
      bool all=g_wallets[j].all.net>=g_wallets[w].all.net && MXWR(g_wallets[j].all)>=MXWR(g_wallets[w].all) && g_wallets[j].ddPct<=g_wallets[w].ddPct;
      bool strict=g_wallets[j].all.net>g_wallets[w].all.net || MXWR(g_wallets[j].all)>MXWR(g_wallets[w].all) || g_wallets[j].ddPct<g_wallets[w].ddPct;
      if(all && strict)return false;
   }
   return true;
}
void MXExportResults(const string status)
{
   int h=MXFile("xep_hang","hang_tong_hop;wallet_id;engine_id;phuong_phap;huong;phien;von_dau;tien_te;net;balance;equity;winrate_pct;profit_factor;dd_equity_pct;dd_equity_tien;lenh_dong;lenh_thang;lenh_thua;hoa_von;thua_lien_tiep;lot;commission;swap_uoc_tinh;thang_lai;so_thang;lenh_ep_dong_cuoi;lenh_bi_chan;loi_lenh_tham_chieu;train_n;train_net;holdout_n;holdout_net;holdout_winrate;holdout_pf;diem;pareto;danh_gia;trang_thai_run;input_da_doi");
   int order[]; int n=ArraySize(g_wallets); ArrayResize(order,n);
   double scores[]; ArrayResize(scores,n);
   for(int w=0;w<n;w++) {order[w]=w;scores[w]=MXScore(w);}
   for(int i=1;i<n;i++)
   {
      int v=order[i],j=i-1; while(j>=0 && scores[order[j]]<scores[v]) {order[j+1]=order[j];j--;} order[j+1]=v;
   }
   if(h!=INVALID_HANDLE)
   {
      for(int k=0;k<n;k++)
      {
         int w=order[k], e=g_wallets[w].engine; MXWallet p=g_wallets[w];
         FileWrite(h,k+1,w,e,e>=0?MXFamily(g_engines[e].family):"PORTFOLIO_GOC",
            MXDirection(p.direction),MXSession(p.session),MXMoney(p.initial),g_currency,MXMoney(p.all.net),MXMoney(p.balance),MXMoney(p.equity),
            MXMoney(MXWR(p.all)),MXMoney(MXPF(p.all)),MXMoney(p.ddPct),MXMoney(p.ddMoney),p.all.trades,p.all.wins,p.all.losses,p.all.flats,p.all.maxStreak,
            MXMoney(p.lots),MXMoney(p.commission),MXMoney(p.swap),MXPositiveMonths(w),ArraySize(g_monthKeys),p.forced,p.rejected,p.nativeErrors,
            p.train.trades,MXMoney(p.train.net),p.holdout.trades,MXMoney(p.holdout.net),MXMoney(MXWR(p.holdout)),MXMoney(MXPF(p.holdout)),
            MXMoney(scores[w]),w>0 && MXPareto(w)?"YES":"NO",MXQualification(w),status,e>=0?g_axisDescriptions[e]:"BASE_ALL_METHODS");
      }
      FileClose(h);
   }
   h=MXFile("lenh_tham_chieu_MT5","ticket;position_id;time;type;entry_type;reason;volume;price;profit;commission;swap;fee;comment;currency");
   if(h!=INVALID_HANDLE)
   {
      // Include fills made during final closing, even if the clock advanced.
      g_nativeDealsNet=0.0;
      g_nativeHistoryOK=HistorySelect(0,TimeCurrent()+86400);
      if(g_nativeHistoryOK)
      {
         // Tester-forced closing deals need not retain the EA magic number.
         // Establish ownership from the position's original entry, not only
         // from the closing deal. Do not call HistoryDealSelect in these loops.
         ulong ownedPositions[];
         for(int i=0;i<HistoryDealsTotal();i++)
         {
            ulong t=HistoryDealGetTicket(i);
            if(t==0 || HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol ||
               (ulong)HistoryDealGetInteger(t,DEAL_MAGIC)!=InpMagic ||
               (ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
            ulong id=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
            int n=ArraySize(ownedPositions);ArrayResize(ownedPositions,n+1);ownedPositions[n]=id;
         }
         int raw=MXFile("lich_su_MT5_day_du","ticket;position_id;magic;symbol;time;type;entry_type;reason;volume;price;profit;commission;swap;fee;belongs_to_reference;comment");
         for(int i=0;i<HistoryDealsTotal();i++)
         {
            ulong t=HistoryDealGetTicket(i);
            if(t==0)continue;
            ulong pos=(ulong)HistoryDealGetInteger(t,DEAL_POSITION_ID);
            bool owned=(ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagic;
            if(!owned && pos>0)
               for(int j=0;j<ArraySize(ownedPositions);j++)if(ownedPositions[j]==pos){owned=true;break;}
            owned=owned && HistoryDealGetString(t,DEAL_SYMBOL)==_Symbol;
            if(raw!=INVALID_HANDLE)
               FileWrite(raw,t,pos,HistoryDealGetInteger(t,DEAL_MAGIC),HistoryDealGetString(t,DEAL_SYMBOL),
                  MXTime((datetime)HistoryDealGetInteger(t,DEAL_TIME)),
                  EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(t,DEAL_TYPE)),
                  EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)),
                  EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(t,DEAL_REASON)),
                  MXMoney(HistoryDealGetDouble(t,DEAL_VOLUME)),DoubleToString(HistoryDealGetDouble(t,DEAL_PRICE),_Digits),
                  MXMoney(HistoryDealGetDouble(t,DEAL_PROFIT)),MXMoney(HistoryDealGetDouble(t,DEAL_COMMISSION)),
                  MXMoney(HistoryDealGetDouble(t,DEAL_SWAP)),MXMoney(HistoryDealGetDouble(t,DEAL_FEE)),
                  owned,MXCleanText(HistoryDealGetString(t,DEAL_COMMENT)));
            if(!owned)continue;
            g_nativeDealsNet+=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_COMMISSION)+
               HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_FEE);
            FileWrite(h,t,HistoryDealGetInteger(t,DEAL_POSITION_ID),MXTime((datetime)HistoryDealGetInteger(t,DEAL_TIME)),
               EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(t,DEAL_TYPE)),
               EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY)),
               EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(t,DEAL_REASON)),
               MXMoney(HistoryDealGetDouble(t,DEAL_VOLUME)),DoubleToString(HistoryDealGetDouble(t,DEAL_PRICE),_Digits),
               MXMoney(HistoryDealGetDouble(t,DEAL_PROFIT)),MXMoney(HistoryDealGetDouble(t,DEAL_COMMISSION)),
               MXMoney(HistoryDealGetDouble(t,DEAL_SWAP)),MXMoney(HistoryDealGetDouble(t,DEAL_FEE)),MXCleanText(HistoryDealGetString(t,DEAL_COMMENT)),g_currency);
         }
         if(raw!=INVALID_HANDLE)FileClose(raw);
      }
      FileClose(h);
   }
   h=MXFile("ket_qua_thang","wallet_id;thang;net_da_chot;equity_dau;equity_cuoi;thay_doi_equity;dd_equity_pct;lenh_dong;lenh_thang;tien_te");
   if(h!=INVALID_HANDLE)
   {
      for(int m=0;m<ArraySize(g_monthKeys);m++) for(int w=0;w<n;w++)
      {
         MXMonth p=g_months[m*n+w];
         FileWrite(h,w,g_monthKeys[m],MXMoney(p.net),MXMoney(p.startEquity),MXMoney(p.endEquity),MXMoney(p.endEquity-p.startEquity),MXMoney(p.ddPct),p.trades,p.wins,g_currency);
      }
      FileClose(h);
   }
   h=MXFile("thong_tin_run","key;value");
   if(h!=INVALID_HANDLE)
   {
      FileWrite(h,"version","4.53"); FileWrite(h,"status",status); FileWrite(h,"symbol",_Symbol);
      FileWrite(h,"server",AccountInfoString(ACCOUNT_SERVER));FileWrite(h,"currency",g_currency);
      FileWrite(h,"account_units_per_real_unit",MXMoney(g_moneyFactor));
      FileWrite(h,"first_tick",MXTime(g_firstTick));FileWrite(h,"last_tick",MXTime(g_lastTick));
      FileWrite(h,"engines",ArraySize(g_engines));FileWrite(h,"wallets",n);
      FileWrite(h,"reference_wallet",0);FileWrite(h,"native_orders_enabled",InpMatrixLenhTester);
      FileWrite(h,"native_balance",MXMoney(AccountInfoDouble(ACCOUNT_BALANCE)));FileWrite(h,"native_equity",MXMoney(AccountInfoDouble(ACCOUNT_EQUITY)));
      g_nativeReconcileGap=AccountInfoDouble(ACCOUNT_BALANCE)-g_nativeInitialBalance-g_nativeDealsNet;
      FileWrite(h,"native_initial_balance",MXMoney(g_nativeInitialBalance));
      FileWrite(h,"native_deals_net",MXMoney(g_nativeDealsNet));
      FileWrite(h,"native_balance_minus_initial_minus_deals",MXMoney(g_nativeReconcileGap));
      FileWrite(h,"native_history_selected",g_nativeHistoryOK);
      FileWrite(h,"native_open_positions_at_export",PositionsTotal());
      FileWrite(h,"native_request_count",g_nativeRequestCount);
      FileWrite(h,"native_operation_errors",g_nativeOperationErrors);
      FileWrite(h,"native_time_or_quote_advance_events",g_delayEvents);
      FileWrite(h,"reference_shadow_net","DISABLED_LIVE_REAL");
      FileWrite(h,"native_net_minus_shadow_net","DISABLED_LIVE_REAL");
      FileWrite(h,"reference_quality",!InpMatrixLenhTester?"DISABLED":
         (g_delayEvents>0 || g_fatal?"INVALID_RUN":
         (!g_nativeHistoryOK || MathAbs(g_nativeReconcileGap)>0.01 || PositionsTotal()>0 || g_nativeOperationErrors>0?"REVIEW_REQUIRED":"RECONCILE_TRADES_NEXT")));
      FileWrite(h,"execution_requirement","Matrix reference calibration requires Tester Execution No Delay. Time advance during native request invalidates run.");
      FileWrite(h,"csv_text_policy","Semicolons and newlines in free text replaced with comma or space.");
      FileWrite(h,"commission_roundtrip_per_lot",MXMoney(InpMatrixPhiKhuHoiLot));
      FileWrite(h,"swap_model",EnumToString(InpMatrixSwap));FileWrite(h,"broker_swap_mode",g_swapMode);
      FileWrite(h,"swap_long_current",g_swapLong);FileWrite(h,"swap_short_current",g_swapShort);
      FileWrite(h,"swap_buy_manual",InpMatrixSwapBuy);FileWrite(h,"swap_sell_manual",InpMatrixSwapSell);
      for(int d=0;d<7;d++)FileWrite(h,"swap_multiplier_day_"+IntegerToString(d),g_swapDays[d]);
      FileWrite(h,"positions_per_method",InpMatrixLenhMoiPP);
      FileWrite(h,"split_direction_session",InpMatrixTachHuongPhien);
      FileWrite(h,"grid_enabled",InpMatrixQuetLuoi);
      FileWrite(h,"equity_log_minutes",InpMatrixGhiEquityPhut);
      FileWrite(h,"volume_min",g_minLot);FileWrite(h,"volume_step",g_lotStep);FileWrite(h,"volume_max",g_maxLot);
      FileWrite(h,"tick_size",g_priceStep);FileWrite(h,"point",_Point);
      FileWrite(h,"entry_slippage_price",InpMatrixTruotGiaVao);
      FileWrite(h,"holdout_entry_date",MXTime(InpMatrixTuNgayKiemChung));
      FileWrite(h,"minimum_trades",InpMatrixSoLenhTinCay);FileWrite(h,"minimum_months",InpMatrixSoThangTinCay);
      FileWrite(h,"pf_minus_one_means","gross loss is zero: undefined/infinite, NOT a reliable winning setup");
      FileWrite(h,"limitations","Swap uses current broker snapshot, margin has no hedge offsets, commission is manual. Check native Report. MT5 may generate missing ticks. No guarantee of future profit.");
      FileWrite(h,"holdout_rule","Trades split by entry date. Monthly cash by posting date. Inspect overlapping trades at split. Never switch native reference to hindsight winner.");
      LiveWriteV449Stats(h);
      FileWrite(h,"matrix_scope","Selected BRK/PVT/ENG/EMA configurations run in one shared simulated wallet; per-configuration direction and server session; each configuration has its own open-position cap.");
      FileClose(h);
   }
   Print("V4.53 đã xuất kết quả ",status," | ",ArraySize(g_engines)," bộ tín hiệu | ",n," tài khoản | ",g_runFolder);
}
void MXFinish(const string status)
{
   if(g_finished || !g_ready)return;
   g_finished=true;
   for(int i=ArraySize(g_positions)-1;i>=0;i--) MXClose(i,g_positions[i].buy?g_quote.bid:g_quote.ask,status=="COMPLETE"?"END_TEST":"STOPPED_EARLY");
   MXMarkAllActive(); MXNativeCloseAll(); MXLogEquity(true); MXExportResults(g_fatal?"ERROR":status); MXFlush();
}

// Reset process-local bookkeeping only. Broker positions and persistent recovery
// keys are preserved and reloaded by LiveRecoverPositions during initialization.
void MXResetRuntime()
{
   ArrayFree(g_engines);
   ArrayFree(g_walletStart); ArrayFree(g_walletCount); ArrayFree(g_engineSession);
   ArrayFree(g_wallets); ArrayFree(g_positions); ArrayFree(g_native);
   ArrayFree(g_nativeQueue); ArrayFree(g_activeWallets);
   ArrayFree(g_months); ArrayFree(g_monthKeys); ArrayFree(g_axisDescriptions);
   ZeroMemory(g_base); ZeroMemory(g_quote);
   g_runFolder=""; g_currency=""; g_nextPosition=1;
   g_ready=false; g_finished=false; g_fatal=false;
   g_liveTradingBlocked=false; g_liveDailyStopped=false;
   g_liveBlockReason=""; g_liveBlockTime=0; g_liveBlockRecoverable=false;
   g_livePeakEquity=0.0; g_liveMaxDD=0.0; g_liveClosedDeals=0;
   g_panelAttachTime=0; g_panelAttachPeak=0.0; g_panelAttachMaxDD=0.0;
   g_moneyFactor=1.0; g_minLot=0.0; g_lotStep=0.0; g_maxLot=0.0; g_priceStep=0.0;
   g_buyUp=0.0; g_buyDown=0.0; g_sellUp=0.0; g_sellDown=0.0;
   g_swapLong=0.0; g_swapShort=0.0; ArrayInitialize(g_swapDays,0.0);
   g_swapMode=0; g_monthSlot=-1; g_dayKey=0;
   g_firstTick=0; g_lastTick=0; g_lastEquityLog=0; g_lastBarLog=0; g_lastCurrentBarLog=0; g_dayStart=0;
   g_lastFlush=0; g_lastPanel=0;
   g_hTrades=INVALID_HANDLE; g_hEvents=INVALID_HANDLE; g_hEquity=INVALID_HANDLE;
   g_hBars=INVALID_HANDLE; g_hConfig=INVALID_HANDLE; g_hWallet=INVALID_HANDLE;
   g_hAudit=INVALID_HANDLE; g_hOrders=INVALID_HANDLE; g_hSymbols=INVALID_HANDLE; g_hBarsCurrent=INVALID_HANDLE;
   g_delayEvents=0; g_nativeOperationErrors=0; g_nativeRequestCount=0;
   g_nativeInitialBalance=0.0; g_nativeDealsNet=0.0; g_nativeReconcileGap=0.0;
   g_nativeHistoryOK=false;
   ZeroMemory(g_livePending); g_livePending.active=false;
   g_liveMarketClosed=false; g_liveMarketClosedTime=0;
   g_statPreSendGuard=0; g_statMinSLTolerance=0; g_statPostFillRiskClose=0;
   g_statBrokerTransient=0; g_statMarketClosed=0; g_statUncertain=0; g_statAdopted=0;
   g_statBrokerSerious=0; g_statTradingBlocks=0;
   ArrayFree(g_liveRecoveryTickets);
   ZeroMemory(g_dhDay); ZeroMemory(g_dhMonth); g_dhFloating=0.0; g_dhDirty=true;
   g_dhLastRefresh=0; g_dhLastGVFlush=0; g_dhPersistBlocks=false; g_logMonth=0;
}
void LiveWriteV449Stats(const int h)
{
   FileWrite(h,"v449_pre_send_guard_rejects",g_statPreSendGuard);
   FileWrite(h,"v449_min_sl_tolerance_accepted",g_statMinSLTolerance);
   FileWrite(h,"v449_post_fill_invalid_risk_closes",g_statPostFillRiskClose);
   FileWrite(h,"v449_broker_transient_rejects",g_statBrokerTransient);
   FileWrite(h,"v449_broker_market_closed",g_statMarketClosed);
   FileWrite(h,"v449_uncertain_reconciles",g_statUncertain);
   FileWrite(h,"v449_reconcile_adopted_positions",g_statAdopted);
   FileWrite(h,"v449_broker_serious_rejects",g_statBrokerSerious);
   FileWrite(h,"v449_trading_blocks",g_statTradingBlocks);
}
string LiveV449StatsText()
{
   return StringFormat("chặn trước gửi=%d | giữ nhờ dung sai SL=%d | đóng sau khớp do SL=%d | từ chối tạm thời=%d | "
                       "thị trường đóng=%d | đối chiếu=%d (nhận lại %d) | từ chối nghiêm trọng=%d | lần khóa=%d",
                       g_statPreSendGuard,g_statMinSLTolerance,g_statPostFillRiskClose,g_statBrokerTransient,
                       g_statMarketClosed,g_statUncertain,g_statAdopted,g_statBrokerSerious,g_statTradingBlocks);
}

int OnInit()
{
   MXResetRuntime();
   // Two safety barriers: initialization + every native order function.
   if(!MQLInfoInteger(MQL_TESTER) && !InpChoPhepGiaoDichThat) { Print("V4.53: bật công tắc InpChoPhepGiaoDichThat để chạy trên tài khoản.");return INIT_FAILED; }
   g_nativeInitialBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   bool tradePermissionOK=TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
                          AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   if(MQLInfoInteger(MQL_OPTIMIZATION)) { Print("Chọn Optimization = Disabled. EA V4.53 chạy các cấu hình đã chọn trong một danh mục.");return INIT_PARAMETERS_INCORRECT; }
   if(InpMatrixLenhMoiPP<1 || InpMatrixLenhMoiPP>10 || InpMatrixSoLenhTinCay<1 || InpMatrixSoThangTinCay<1 ||
      InpMatrixPhiKhuHoiLot<0.0 || InpMatrixVonMoiVi<0.0 || InpMatrixHeSoTienThat<0.0 ||
      InpMatrixTruotGiaVao<0.0 || InpMatrixTruotGiaVao>0.30 || InpMatrixGhiEquityPhut<0)
      {Print("Thiết lập ngoài giới hạn");return INIT_PARAMETERS_INCORRECT;}
   if(((MQLInfoInteger(MQL_TESTER) && InpMatrixLenhTester) || !MQLInfoInteger(MQL_TESTER)) && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {Print("V4.52 cần tài khoản Hedging để tách và quản lý từng vị thế.");return INIT_PARAMETERS_INCORRECT;}
   int calc=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE);
   if(calc!=SYMBOL_CALC_MODE_FOREX && calc!=SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE &&
      calc!=SYMBOL_CALC_MODE_CFD && calc!=SYMBOL_CALC_MODE_CFDLEVERAGE && calc!=SYMBOL_CALC_MODE_CFDINDEX)
      {Print("V4.52 giới hạn sản phẩm Forex/CFD tuyến tính như XAUUSD; không hỗ trợ mode này.");return INIT_PARAMETERS_INCORRECT;}
   g_minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);g_maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);g_priceStep=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(g_minLot<=0.0 || g_lotStep<=0.0 || g_priceStep<=0.0)return INIT_FAILED;
   double part=0.0;
   if(InpVolumeMode==LOT_CO_DINH && (MathAbs(MXFloorLot(InpGiaTriKhoiLuong)-InpGiaTriKhoiLuong)>1e-8 ||
      InpGiaTriKhoiLuong<g_minLot || InpGiaTriKhoiLuong>g_maxLot ||
      (InpUseTP1Partial && (MQLInfoInteger(MQL_TESTER) || !InpChoPhepGiaoDichThat) && !MXSplit(InpGiaTriKhoiLuong,part))))
      {Print("Lot cố định không hợp lệ; nếu chạy tham chiếu với TP1 50%, lot cần đủ để chia theo bước lot của sàn.");return INIT_PARAMETERS_INCORRECT;}
   g_currency=AccountInfoString(ACCOUNT_CURRENCY);string currency=g_currency;StringToUpper(currency);
   if(InpMatrixHeSoTienThat>0.0)g_moneyFactor=InpMatrixHeSoTienThat;
   else if(currency=="USC" || currency=="USDC" || currency=="USD CENT" || currency=="US CENT")g_moneyFactor=100.0;
   else if(currency=="USD")g_moneyFactor=1.0;
   else if(InpVolumeMode==LOT_THEO_SO_TIEN_SL)
      {Print("Tiền tài khoản chưa nhận dạng. Nhập hệ số đơn vị tiền thật trước khi dùng chế độ tiền mỗi SL.");return INIT_PARAMETERS_INCORRECT;}
   g_swapMode=(int)SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE);
   g_swapLong=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_LONG);g_swapShort=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SHORT);
   g_swapDays[0]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SUNDAY);g_swapDays[1]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_MONDAY);
   g_swapDays[2]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_TUESDAY);g_swapDays[3]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_WEDNESDAY);
   g_swapDays[4]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_THURSDAY);g_swapDays[5]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_FRIDAY);
   g_swapDays[6]=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SATURDAY);
   if(InpMatrixSwap==MATRIX_SWAP_SAN && g_swapMode!=SYMBOL_SWAP_MODE_DISABLED &&
      g_swapMode!=SYMBOL_SWAP_MODE_POINTS && g_swapMode!=SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT)
      {Print("Swap sàn dùng cách tính chưa hỗ trợ. Chọn nhập tay swap/lot/đêm bằng tiền tài khoản, không được bỏ phí im lặng.");return INIT_PARAMETERS_INCORRECT;}
   if(InpMatrixSwap==MATRIX_SWAP_TAY)
   {
      int triple=(int)SymbolInfoInteger(_Symbol,SYMBOL_SWAP_ROLLOVER3DAYS);
      for(int d=0;d<7;d++)g_swapDays[d]=(d==0 || d==6)?0.0:(d==triple?3.0:1.0);
   }
   g_runFolder="DavidHunterVer1";
   FolderCreate(g_runFolder,FILE_COMMON);
   g_hConfig=MXFile("config","engine_id;phuong_phap;loai;input_da_doi;toan_bo_input");
   g_hWallet=MXFile("account","wallet_id;engine_id;huong;phien;von_dau;tien_te;vai_tro");
   g_hTrades=MXFile("deals",DH_HDR_DEALS);
   g_hOrders=MXFile("orders",DH_HDR_ORDERS);
   g_hEvents=MXFile("events",DH_HDR_EVENTS);
   g_hAudit=MXFile("management_requests",DH_HDR_AUDIT);
   g_hSymbols=MXFile("symbols","time;symbol;digits;point;tick_size;volume_min;volume_step;volume_max;spread_price;chart_tf;trade_fallback_tf");
   if(InpMatrixGhiEquityPhut>0)g_hEquity=MXFile("equity",DH_HDR_EQUITY);
   if(InpMatrixGhiNenM1)
   {
      g_hBars=MXFile("bars_"+_Symbol+"_M1",DH_HDR_BARS_M1);
      g_hBarsCurrent=MXFile("bars_"+_Symbol+"_CURRENT",DH_HDR_BARS_CUR);
   }
   if(g_hSymbols!=INVALID_HANDLE)
      FileWrite(g_hSymbols,MXTime(TimeCurrent()),_Symbol,_Digits,DoubleToString(_Point,_Digits),
                DoubleToString(g_priceStep,_Digits),g_minLot,g_lotStep,g_maxLot,
                DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits),
                EnumToString((ENUM_TIMEFRAMES)_Period),EnumToString(LIVE_FALLBACK_TF));
   int dictionary=MXFile("input_dictionary","ma_input;ten_tieng_viet;kieu;mac_dinh;cho_phep_quet_luoi");
   if(dictionary!=INVALID_HANDLE){MatrixWriteDictionary(dictionary);FileClose(dictionary);}
   MatrixBaseConfig(g_base);
   if(MXAddWallet(-1,0,0)<0)return INIT_FAILED;
   if(!MQLInfoInteger(MQL_TESTER))
   {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      string peakKey=LivePeakKey();
      g_livePeakEquity=GlobalVariableCheck(peakKey)?MathMax(eq,GlobalVariableGet(peakKey)):eq;
      g_liveMaxDD=GlobalVariableCheck(LiveDDKey())?GlobalVariableGet(LiveDDKey()):0.0;
      if(g_livePeakEquity>0.0) g_liveMaxDD=MathMax(g_liveMaxDD,100.0*(g_livePeakEquity-eq)/g_livePeakEquity);
      g_wallets[0].initial=AccountInfoDouble(ACCOUNT_BALANCE);
      g_wallets[0].balance=AccountInfoDouble(ACCOUNT_BALANCE);
      g_wallets[0].equity=eq; g_wallets[0].peak=g_livePeakEquity;
      MqlDateTime today; TimeToStruct(TimeCurrent(),today); int todayKey=today.year*10000+today.mon*100+today.day;
      if(GlobalVariableCheck(LiveDayKeyName()) && (int)GlobalVariableGet(LiveDayKeyName())==todayKey && GlobalVariableCheck(LiveDayEquityKey()))
      {
         g_wallets[0].dayStart=GlobalVariableGet(LiveDayEquityKey());
         g_liveDailyStopped=GlobalVariableCheck(LiveDayStopKey()) && GlobalVariableGet(LiveDayStopKey())>0.5;
         if(g_liveDailyStopped) g_liveBlockTime=TimeCurrent();
      }
      else
      {
         g_wallets[0].dayStart=eq;
         GlobalVariableSet(LiveDayKeyName(),todayKey); GlobalVariableSet(LiveDayEquityKey(),eq);
      }
      g_dayKey=todayKey;
   }
   int made=0;
   if(InpUseBRK758)
   {
      MatrixConfig c=g_base; MXOneFamily(c,7); c.InpPVHuongGiaoDich=InpBRK758Huong;
      if(!MXAddEngine(c,7,true,"BRK758",(int)InpBRK758Phien))return INIT_PARAMETERS_INCORRECT;
      made++;
   }
   if(InpUsePVT880)
   {
      MatrixConfig c=g_base; MXOneFamily(c,9); c.InpPVHuongGiaoDich=InpPVT880Huong;
      if(!MXAddEngine(c,9,true,"PVT880",(int)InpPVT880Phien))return INIT_PARAMETERS_INCORRECT;
      made++;
   }
   if(InpUseENG626)
   {
      MatrixConfig c=g_base; MXOneFamily(c,5); c.InpPVHuongGiaoDich=InpENG626Huong;
      if(!MXAddEngine(c,5,true,"ENG626",(int)InpENG626Phien))return INIT_PARAMETERS_INCORRECT;
      made++;
   }
   if(InpUseENG636)
   {
      MatrixConfig c=g_base; MXOneFamily(c,5); c.InpPVHuongGiaoDich=InpENG636Huong;
      if(!MXAddEngine(c,5,true,"ENG636",(int)InpENG636Phien))return INIT_PARAMETERS_INCORRECT;
      made++;
   }
   // V4.53: EMA luôn được thêm CUỐI để chỉ số engine (ghi trong comment lệnh) của
   // các cấu hình cũ không đổi, lệnh đang mở vẫn được nhận lại đúng.
   if(InpUseEMA)
   {
      MatrixConfig c=g_base; MXOneFamily(c,0); c.InpPVHuongGiaoDich=InpEMAHuong; c.InpPVTP2R=InpEMATP2R;
      if(!MXAddEngine(c,0,true,"EMA",(int)InpEMAPhien))return INIT_PARAMETERS_INCORRECT;
      made++;
   }
   if(made==0) {Print("Bật ít nhất một cấu hình BRK/PVT/ENG/EMA trước khi chạy.");return INIT_PARAMETERS_INCORRECT;}
   if(!MQLInfoInteger(MQL_TESTER)) LiveRecoverPositions();
   if(DHPersist() && GlobalVariableCheck(DHLockKey()))
   {
      if(InpMoKhoaLoiNghiemTrong)
      {
         Print("V4.52: người vận hành mở khóa lỗi nghiêm trọng đã lưu: ",DHReadLockReason(),
               ". Hãy tắt lại Input mở khóa sau khi kiểm tra.");
         DHDeleteLock();
      }
      else if(!g_liveTradingBlocked)
      {
         g_liveTradingBlocked=true; g_liveBlockRecoverable=false;
         g_liveBlockReason=DHReadLockReason();
         g_liveBlockTime=(datetime)GlobalVariableGet(DHLockKey());
         Print("V4.52: khôi phục khóa lỗi nghiêm trọng từ lần chạy trước: ",g_liveBlockReason,
               ". Kiểm tra rồi bật InpMoKhoaLoiNghiemTrong để mở khóa.");
      }
   }
   g_dhPersistBlocks=true;
   // Remove panel objects left by earlier David Hunter builds (same EA family only).
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) { string on=ObjectName(0,i,0,-1); if(StringFind(on,"DH448_PANEL_")==0) ObjectDelete(0,on); }
   DHRefreshStats(true); DHObserveEquity();
   if(ArraySize(g_engines)==0 || ArraySize(g_wallets)!=1)
      {Print("Không có phương pháp hoặc ID tham chiếu không tồn tại.");return INIT_PARAMETERS_INCORRECT;}
   FileFlush(g_hConfig);FileClose(g_hConfig);g_hConfig=INVALID_HANDLE;
   FileFlush(g_hWallet);FileClose(g_hWallet);g_hWallet=INVALID_HANDLE;
   g_executor.SetExpertMagicNumber(InpMagic);g_executor.SetAsyncMode(false);g_executor.SetTypeFillingBySymbol(_Symbol);
   g_executor.SetDeviationInPoints((ulong)MathFloor(InpTruotGiaToiDaGia/_Point));
   g_ready=true;
   if(!MQLInfoInteger(MQL_TESTER) && !tradePermissionOK && !g_liveTradingBlocked)
      LiveSetTradingBlock("MT5 hoặc tài khoản chưa cho phép giao dịch tự động",true);
   MqlTick initialQuote;
   if(SymbolInfoTick(_Symbol,initialQuote) && initialQuote.bid>0.0 && initialQuote.ask>=initialQuote.bid)
      g_quote=initialQuote;
   else
      g_quote.time=TimeCurrent();
   g_panelAttachTime=TimeCurrent();
   g_panelAttachPeak=AccountInfoDouble(ACCOUNT_EQUITY);
   g_panelAttachMaxDD=0.0;
   g_lastPanel=0;
   DrawDashboard();
   if(!MQLInfoInteger(MQL_TESTER) && !EventSetTimer(1))
      Print("V4.52: không bật được bộ hẹn giờ làm mới bảng; bảng vẫn cập nhật khi có tick.");
   if(!MQLInfoInteger(MQL_TESTER))
      Print("V4.53 LIVE đã bật. XAUUSD: rủi ro ",DoubleToString(InpGiaTriKhoiLuong,2),
            "%/lệnh | không giới hạn lệnh/ngày | tối đa ",
            InpMaxIndependentPositions," vị thế | dừng ngày ",DoubleToString(InpDailyLossPct,1),"%.");

   Print("V4.53 TEST | ",ArraySize(g_engines)," cấu hình | tài khoản broker thực | ",g_runFolder);
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("Tester: swap ước tính theo thông số sàn hiện tại; kiểm tra commission và mô hình tick trong Journal.");
      Print("Tester tham chiếu yêu cầu Execution = No Delay để đối chiếu.");
   }
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(!g_ready || g_finished)return;
   if(g_fatal){ExpertRemove();return;}
   if(!SymbolInfoTick(_Symbol,g_quote) || g_quote.bid<=0.0 || g_quote.ask<g_quote.bid)return;
   if(!MXRates()) {MXFail("OrderCalcProfit không có tỷ giá hợp lệ; kiểm tra lịch sử mã quy đổi tiền");ExpertRemove();return;}
   if(g_firstTick==0)g_firstTick=g_quote.time;g_lastTick=g_quote.time;
   DHRotateLogs(TimeCurrent());
   LiveProcessEntryPauses();
   MXCalendar();MXUpdatePositions();DHObserveEquity();UpdateDailyLossStop();UpdateLiveDrawdown();
   for(int e=0;e<ArraySize(g_engines) && !g_fatal;e++)g_engines[e].ScheduledStep(g_quote.time);
   MXLogBars();MXLogEquity();DrawDashboard();
   // All virtual wallets and engines finish on the same market snapshot first.
   // Blocking native requests must never run inside the engine iteration.
   if(!g_fatal)MXNativeManage();
   for(int q=0;q<ArraySize(g_nativeQueue) && !g_fatal;q++)MXNativeOpen(g_nativeQueue[q]);
   ArrayResize(g_nativeQueue,0);
   if(g_fatal){ExpertRemove();return;}
   ulong now=GetTickCount64();if(now-g_lastFlush>=5000){MXFlush();g_lastFlush=now;}
}
void OnTimer()
{
   if(!g_ready || g_finished) return;
   MqlTick latest;
   if(SymbolInfoTick(_Symbol,latest) && latest.bid>0.0 && latest.ask>=latest.bid)
      g_quote=latest;
   UpdateLiveDrawdown();
   if(g_liveTradingBlocked && g_liveBlockRecoverable &&
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      LiveClearTradingBlock("quyền giao dịch tự động đã hoạt động trở lại");
   LiveProcessEntryPauses();
   DHRotateLogs(TimeCurrent());
   DHObserveEquity();
   DrawDashboard();
}
string LiveMethodFromComment(const string comment)
{
   string parts[];
   int count=StringSplit(comment,'|',parts);
   return count>=4?parts[3]:"";
}
string LiveMethodFromPositionID(const ulong positionID)
{
   if(positionID==0 || !HistorySelectByPosition(positionID)) return "";
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      string method=LiveMethodFromComment(HistoryDealGetString(deal,DEAL_COMMENT));
      if(method!="") return method;
   }
   return "";
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) g_dhDirty=true;
   DHRotateLogs(TimeCurrent());
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0 && g_hTrades!=INVALID_HANDLE && HistoryDealSelect(trans.deal))
   {
      ulong magic=(ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
      if(magic==InpMagic)
      {
         string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
         ulong positionID=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
         string method=LiveMethodFromComment(comment);
         if(method=="") method=LiveMethodFromPositionID(positionID);
         if(!HistoryDealSelect(trans.deal)) return;
         // V4.50: a deal stamped in the previous month is appended to that month's file.
         int dealMonth=DHMonthKey((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME));
         int hDeals=dealMonth<g_logMonth?MXFileMonth("deals",DH_HDR_DEALS,dealMonth):g_hTrades;
         if(hDeals==INVALID_HANDLE) return;
         FileWrite(hDeals,
            MXTime((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME)),trans.deal,
            (ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER),positionID,
            HistoryDealGetString(trans.deal,DEAL_SYMBOL),magic,
            EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY)),
            EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal,DEAL_TYPE)),
            HistoryDealGetDouble(trans.deal,DEAL_VOLUME),DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),_Digits),
            HistoryDealGetDouble(trans.deal,DEAL_PROFIT),HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),
            HistoryDealGetDouble(trans.deal,DEAL_SWAP),HistoryDealGetDouble(trans.deal,DEAL_FEE),
            method,MXCleanText(comment));
         if(hDeals!=g_hTrades) FileClose(hDeals);
      }
   }
   if((trans.type==TRADE_TRANSACTION_ORDER_ADD || trans.type==TRADE_TRANSACTION_ORDER_UPDATE ||
       trans.type==TRADE_TRANSACTION_ORDER_DELETE) && g_hOrders!=INVALID_HANDLE)
   {
      ulong magic=request.magic;
      string symbol=trans.symbol;
      if(trans.order>0 && HistoryOrderSelect(trans.order))
      {
         magic=(ulong)HistoryOrderGetInteger(trans.order,ORDER_MAGIC);
         symbol=HistoryOrderGetString(trans.order,ORDER_SYMBOL);
      }
      else if(trans.order>0 && OrderSelect(trans.order))
      {
         magic=(ulong)OrderGetInteger(ORDER_MAGIC);
         symbol=OrderGetString(ORDER_SYMBOL);
      }
      if(magic==InpMagic)
         FileWrite(g_hOrders,MXTime(TimeCurrent()),EnumToString(trans.type),trans.order,trans.deal,trans.position,
            symbol,EnumToString(trans.order_type),trans.volume,DoubleToString(trans.price,_Digits),
            DoubleToString(trans.price_sl,_Digits),DoubleToString(trans.price_tp,_Digits),result.retcode,
            MXCleanText(result.comment));
   }
}
double OnTester()
{
   MXFinish("COMPLETE");
   return TesterStatistics(STAT_PROFIT);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_ready && !g_finished)
   {
      if(MQLInfoInteger(MQL_TESTER)) MXFinish("STOPPED_EARLY");
      else
      {
         g_finished=true; MXLogEquity(true); MXFlush();
         if(DHPersist()) GlobalVariablesFlush();
         Print("V4.53 thống kê vận hành: ",LiveV449StatsText());
         if(reason==REASON_CHARTCHANGE)
            Print("V4.53: đổi timeframe/chart, giữ nguyên vị thế và trạng thái quản lý để khởi tạo lại.");
         else
            Print("V4.53 TEST tách khỏi chart; vị thế tại broker và dữ liệu khôi phục được giữ nguyên.");
      }
   }
   for(int e=0;e<ArraySize(g_engines);e++)
   {
      if(CheckPointer(g_engines[e])==POINTER_DYNAMIC) {g_engines[e].Release();delete g_engines[e];}
      g_engines[e]=NULL;
   }
   ArrayFree(g_engines);
   if(g_hTrades!=INVALID_HANDLE)FileClose(g_hTrades);
   if(g_hEvents!=INVALID_HANDLE)FileClose(g_hEvents);
   if(g_hAudit!=INVALID_HANDLE)FileClose(g_hAudit);
   if(g_hOrders!=INVALID_HANDLE)FileClose(g_hOrders);
   if(g_hSymbols!=INVALID_HANDLE)FileClose(g_hSymbols);
   if(g_hBarsCurrent!=INVALID_HANDLE)FileClose(g_hBarsCurrent);
   if(g_hEquity!=INVALID_HANDLE)FileClose(g_hEquity);
   if(g_hBars!=INVALID_HANDLE)FileClose(g_hBars);
   if(g_hConfig!=INVALID_HANDLE)FileClose(g_hConfig);
   if(g_hWallet!=INVALID_HANDLE)FileClose(g_hWallet);
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) { string n=ObjectName(0,i,0,-1); if(StringFind(n,g_panelPrefix)==0) ObjectDelete(0,n); }
   Comment("");
   MXResetRuntime();
}
