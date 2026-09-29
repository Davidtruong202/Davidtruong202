// David Hunter V4.39 MATRIX 7PP - research only, Strategy Tester only.
// Independent entry engines, independent wallets, ONE fixed native reference.
// No live trading. No hindsight switching. No artificial SL slippage cap.
// V4.39 MATRIX 7PP = bản sao V4.39 MATRIX RECONCILE 2 + input "0. BỘ CÀI SẴN" chứa sẵn 13 bộ test
// (kiểm chứng ứng viên + lưới đầy đủ) của 7 PP chưa triển khai: EMA, ICT, MM, SMC, PVEMA, PIN, LQ.
// Mặc định: BỘ HIỆU QUẢ NHẤT (EMA SELL/A, sàng lọc 2.568 ví MT5 9 tháng), bấm Start là chạy;
// Graph và lệnh Tester = đúng bộ đó. Kiểm chứng 6 PP / lưới đầy đủ: chọn trong input 0. "Thủ công" = y hệt bản gốc.
// Không đổi thuật toán vào lệnh, quản lý lệnh, mô phỏng ví hay định dạng file xuất.
#property copyright "David Hunter"
#property version "4.39"
#property strict
#include <Trade/Trade.mqh>
const bool LAB_RESEARCH_ONLY = true;
enum ENUM_ICT_PRIORITY
{
   ICT_PRIORITY_UNICORN = 0, // Ưu tiên Unicorn
   ICT_PRIORITY_OTE = 1,     // Ưu tiên OTE
   ICT_PRIORITY_INVERSION = 2, // Ưu tiên Inversion
   ICT_PRIORITY_2022 = 3     // Ưu tiên ICT 2022
};

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

enum ENUM_PV_MAU_PRICE_ACTION
{
   PV_CA_BA_MAU = 0,                // Cả ba mẫu
   PV_CHI_NEN_NHAN_CHIM = 1,        // Chỉ nến nhấn chìm
   PV_CHI_PIN_BAR = 2,              // Chỉ Pin Bar
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

enum ENUM_CHE_DO_VUNG_LENH
{
   VUNG_GOC_LUC_VAO_LENH = 0,        // Giữ vùng thực tế lúc vào lệnh
   VUNG_THEO_INPUT_HIEN_TAI = 1,     // Vẽ lại vùng theo Input hiện tại
   VUNG_GOC_VA_MO_PHONG = 2          // Hiển thị cả vùng gốc và vùng mô phỏng
};

enum ENUM_MUC_RETEST_EMA
{
   RETEST_EMA_NHANH = 0,              // Giá hồi về đường EMA nhanh của khung vào lệnh
   RETEST_EMA_CHAM = 1,               // Giá hồi sâu về đường EMA chậm của khung vào lệnh
   RETEST_VUNG_HAI_EMA = 2            // Giá đi vào vùng giữa hai đường EMA
};

enum ENUM_SETUP_ENGINE
{
   SETUP_ENGINE_ICT = 0,
   SETUP_ENGINE_MM = 1,
   SETUP_ENGINE_SMC = 2
};

enum ENUM_MATRIX_BO_CAI_SAN
{
   BO_THEO_INPUT = 0, // Thủ công: dùng các input bên dưới (y hệt V4.39 gốc)
   BO_KIEM_CHUNG_6PP = 1, // Kiểm chứng 6 PP cùng lúc: EMA, ICT, SMC, PVEMA, PIN, LQ (214 bộ)
   BO_KIEM_CHUNG_EMA = 2, // Kiểm chứng riêng EMA (32 bộ)
   BO_KIEM_CHUNG_ICT = 3, // Kiểm chứng riêng ICT (54 bộ)
   BO_KIEM_CHUNG_SMC = 4, // Kiểm chứng riêng SMC (48 bộ)
   BO_KIEM_CHUNG_PVEMA = 5, // Kiểm chứng riêng PVEMA (24 bộ)
   BO_KIEM_CHUNG_PIN = 6, // Kiểm chứng riêng PIN (24 bộ)
   BO_KIEM_CHUNG_LQ = 7, // Kiểm chứng riêng LQ (32 bộ)
   BO_LUOI_DAY_DU_EMA = 8, // Lưới đầy đủ EMA (384 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_ICT = 9, // Lưới đầy đủ ICT (720 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_MM = 10, // Lưới đầy đủ MM (384 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_SMC = 11, // Lưới đầy đủ SMC (720 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_PVEMA = 12, // Lưới đầy đủ PVEMA (432 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_PIN = 13, // Lưới đầy đủ PIN (768 bộ, chạy rất lâu)
   BO_LUOI_DAY_DU_LQ = 14, // Lưới đầy đủ LQ (864 bộ, chạy rất lâu)
   BO_HIEU_QUA_NHAT = 15 // Bộ hiệu quả nhất 9 tháng: EMA SELL/A, InpTimeframe=M1, InpFastEMA=7, InpSlowEMA=50, InpEMAKhungLoc=M15, InpMinDirectionEfficiency=0.1 (ví 10 = Graph)
};


input group "0. BỘ CÀI SẴN: CHỌN LÀ CHẠY, KHÔNG CẦN FILE SET"
input ENUM_MATRIX_BO_CAI_SAN InpMatrixBoCaiSan = BO_HIEU_QUA_NHAT; // Bộ cài sẵn (khác Thủ công: bỏ qua input bật PP, lưới, giới hạn và thư mục log bên dưới)
input group "A. ĐIỀU KIỆN GỐC VÀ QUẢN LÝ VỐN"
const ENUM_CHE_DO_LENH InpExecutionMode = BA_PHUONG_PHAP_DOC_LAP; // 
input int InpMaxIndependentPositions = 10; // Tổng vị thế tối đa trong một tài khoản mô phỏng
input bool InpUseEMAModule = true; // Bật phương pháp EMA đa khung M5 lọc, M1 vào
input bool InpUseICTModule = true; // Bật phương pháp ICT
input bool InpUseMMModule = true; // Bật phương pháp Market Maker
input bool InpUseSMCModule = true; // Bật phương pháp SMC M5, lọc xu hướng H1
input bool InpUsePVEMAModule = true; // Bật EMA 95/150 + EMA 26/29
input bool InpUseENGModule = true; // Bật nến nhấn chìm ENG
input bool InpUsePINModule = true; // Bật Pin Bar PIN
input bool InpUseBRKModule = true; // Bật phá đỉnh/đáy BRK
input bool InpUseLQModule = true; // Bật quét thanh khoản LQ
input bool InpUsePVTModule = true; // Bật Pivot PVT
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1; // Khung thời gian EMA
input int InpFastEMA = 7; // Chu kỳ EMA nhanh tìm điểm vào trên M1
input int InpSlowEMA = 34; // Chu kỳ EMA chậm tìm điểm vào trên M1
input int InpSLLookbackBars = 5; // Số nến đã đóng dùng tìm đỉnh/đáy SL
input double InpSLBufferGia = 0.0; // Khoảng đệm SL qua đỉnh/đáy (giá)
input bool InpEMAVaoSauRetest = true; // Chờ giá retest EMA sau giao cắt rồi mới vào
input ENUM_MUC_RETEST_EMA InpEMAMucRetest = RETEST_EMA_NHANH; // Đường/vùng EMA dùng làm điểm retest
input double InpEMAKhoangDiXaToiThieuATR = 0.35; // Giá phải chạy xa EMA tối thiểu theo ATR trước khi hồi
input double InpEMADungSaiRetestGia = 0.20; // Dung sai chạm đường EMA (giá)
input int InpEMASoNenChoToiThieu = 0; // Số nến tối thiểu sau giao cắt mới nhận retest; 0=chạm là vào
input int InpEMAHetHanRetestBars = 24; // Hủy thiết lập nếu chưa retest sau số nến này
input bool InpEMADungLocM5 = true; // Dùng EMA 34/89 M5 để lọc hướng lệnh M1
input ENUM_TIMEFRAMES InpEMAKhungLoc = PERIOD_M5; // Khung EMA lọc xu hướng
input int InpEMANhanhLoc = 34; // Chu kỳ EMA nhanh lọc xu hướng M5
input int InpEMAChamLoc = 89; // Chu kỳ EMA chậm lọc xu hướng M5
input bool InpUseWaveFilter = true; // Bật bộ lọc sóng yếu
input int InpWaveBars = 12; // Số nến dùng đo độ lớn sóng
input int InpATRPeriod = 14; // Chu kỳ ATR dùng chung
input double InpMinWaveATR = 2.0; // Biên độ sóng tối thiểu theo ATR
input double InpMinMoveATR = 0.65; // Độ dịch chuyển tối thiểu theo ATR
input int InpRecentCrossBars = 8; // Bỏ qua nếu vừa giao cắt trong N nến; 0=tắt
input double InpMinDirectionEfficiency = 0.22; // Hiệu suất hướng đi tối thiểu; 0=tắt
input bool InpRequireOuterHalf = true; // Chỉ vào khi điểm cắt nằm đúng nửa ngoài biên giá
input double InpMaxOpposingSlowSlopeATR = 0.08; // Độ dốc EMA chậm ngược hướng tối đa theo ATR
input ENUM_TIMEFRAMES InpICTEntryTF = PERIOD_M5; // Khung tìm Sweep/MSS/FVG
input ENUM_TIMEFRAMES InpICTBiasTF = PERIOD_M15; // Khung xác định xu hướng chính
input bool InpICTUse2022 = true; // Bật mô hình ICT 2022
input bool InpICTUseOTE = true; // Bật vùng vào lệnh OTE
input bool InpICTUseUnicorn = true; // Bật mô hình Unicorn
input bool InpICTUseInversion = true; // Bật mô hình Inversion
input ENUM_ICT_PRIORITY InpICTPriority = ICT_PRIORITY_UNICORN; // Mô hình được ưu tiên
input int InpICTLookback = 80; // Số nến tìm cấu trúc ICT
input int InpICTPivotBars = 2; // Số nến mỗi bên xác nhận Swing
input int InpICTSetupExpiryBars = 12; // Số nến chờ trước khi hủy thiết lập
input double InpICTMinFVG_ATR = 0.05; // Độ rộng FVG tối thiểu theo ATR
input double InpICTDisplacementATR = 0.60; // Thân nến MSS tối thiểu theo ATR
input double InpICTMinImpulseATR = 1.0; // Biên độ nhịp ICT tối thiểu theo ATR
input double InpICTOTEHigh = 0.62; // Biên trên vùng OTE
input double InpICTOTELow = 0.79; // Biên dưới vùng OTE
const double InpICTRR = 2.0; // RR cố định trong LAB
input double InpICTSLBufferGia = 0.02; // Khoảng đệm SL ICT (giá)
input ENUM_TIMEFRAMES InpMMEntryTF = PERIOD_M15; // Khung tìm điểm vào Market Maker
input ENUM_TIMEFRAMES InpMMBiasTF = PERIOD_H1; // Khung xác định vùng Premium/Discount
input int InpMMLookback = 96; // Số nến tìm cấu trúc Market Maker
input int InpMMPivotBars = 2; // Số nến mỗi bên xác nhận Swing
input int InpMMRangeBars = 36; // Số nến tạo Dealing Range khung cao
input double InpMMPremiumLevel = 0.62; // Mức Premium để tìm lệnh Sell
input double InpMMDiscountLevel = 0.38; // Mức Discount để tìm lệnh Buy
input double InpMMDisplacementATR = 0.70; // Nến dịch chuyển tối thiểu theo ATR
input double InpMMMinFVG_ATR = 0.03; // Độ rộng FVG tối thiểu theo ATR
input double InpMMMaxConsolidationATR = 3.0; // Biên tích lũy tối đa theo ATR
input int InpMMConsolidationBars = 6; // Số nến xác định vùng tích lũy
input int InpMMModelExpiryBars = 48; // Số nến tối đa duy trì một mô hình
input int InpMMLegSetupExpiryBars = 10; // Số nến chờ retest của nhịp 1/2
input int InpMMLowRiskExpiryBars = 14; // Số nến chờ retest Low-risk
input bool InpMMUseLowRisk = true; // Bật điểm vào Low-risk
input bool InpMMUseLeg1 = true; // Bật điểm vào nhịp thứ nhất
input bool InpMMUseLeg2 = true; // Bật điểm vào nhịp thứ hai
const double InpMMRR = 2.5; // RR cố định trong LAB
input double InpMMSLBufferGia = 0.03; // Khoảng đệm SL Market Maker (giá)
input ENUM_TIMEFRAMES InpSMCEntryTF = PERIOD_M5; // Khung tìm Sweep/BOS/CHoCH và vùng vào SMC
input ENUM_TIMEFRAMES InpSMCBiasTF = PERIOD_H1; // Khung lọc xu hướng chính của SMC
input int InpSMCLookback = 80; // Số nến tìm cấu trúc SMC
input int InpSMCPivotBars = 2; // Số nến mỗi bên xác nhận Swing SMC
input int InpSMCSetupExpiryBars = 12; // Số nến chờ giá hồi trước khi hủy thiết lập
input double InpSMCDisplacementATR = 0.60; // Thân nến phá cấu trúc tối thiểu theo ATR
input bool InpSMCBatBuocFVG = false; // Chỉ nhận thiết lập có FVG
input bool InpSMCUuTienVungFVG = true; // Ưu tiên vùng FVG; không có thì dùng Order Block
input double InpSMCMinFVGATR = 0.03; // Độ rộng FVG tối thiểu theo ATR
input bool InpSMCDungLocEMAH1 = true; // Lọc H1 bằng vị trí giá so với hai EMA
input int InpSMCEMANhanhH1 = 50; // Chu kỳ EMA nhanh lọc xu hướng H1
input int InpSMCEMAChamH1 = 200; // Chu kỳ EMA chậm lọc xu hướng H1
input bool InpSMCYeuCauThuTuEMAH1 = false; // Bắt buộc EMA nhanh/chậm H1 xếp đúng thứ tự
input bool InpSMCDungLocEMAM5 = true; // Lọc điểm vào theo EMA M5
input int InpSMCEMANhanhM5 = 20; // Chu kỳ EMA nhanh lọc điểm vào M5
input int InpSMCEMAChamM5 = 50; // Chu kỳ EMA chậm lọc điểm vào M5
input bool InpSMCYeuCauDoDocEMAM5 = true; // Bắt buộc hai EMA M5 dốc cùng hướng
input int InpSMCSoNenDoDocEMA = 3; // Số nến dùng đo độ dốc EMA M5
input bool InpSMCDungLocRSI = true; // Lọc động lượng SMC bằng RSI M5
input int InpSMCRSIPeriod = 14; // Chu kỳ RSI lọc SMC
input double InpSMCRSIMuaToiThieu = 50.0; // RSI tối thiểu cho SMC Buy
input double InpSMCRSIBanToiDa = 50.0; // RSI tối đa cho SMC Sell
const double InpSMCRR = 2.30; // RR cố định trong LAB
input double InpSMCSLBufferGia = 0.02; // Khoảng đệm SL ngoài điểm quét (giá)
const bool InpSMCBatLop2 = false; // LAB không đặt pending order lớp 2
const double InpSMCLop2PhanTramDenSL = 45.0; // 
input ENUM_PV_HUONG_GIAO_DICH InpPVHuongGiaoDich = PV_CA_BUY_VA_SELL; // Hướng giao dịch
input ENUM_PV_CACH_KET_HOP InpPVCachKetHop = PV_MOI_PP_DOC_LAP; // Cách chạy các phương pháp
input int InpPVSoNenTimSL = 5; // Số nến tìm đỉnh/đáy đặt SL
input double InpPVDemSLGia = 1.50; // Đệm SL ngoài đỉnh/đáy (giá)
const double InpPVBEKhiLoiGia = 5.00; // 
const double InpPVTP2R = 2.00; // RR cố định, luôn >= 1:1
const double InpPVRRToiThieu = 1.0; // 
const int InpPVThuaLienTiepToiDa = 0; // 
input ENUM_TIMEFRAMES InpPVKhungXuHuong = PERIOD_H1; // Khung xác định xu hướng
input ENUM_TIMEFRAMES InpPVKhungVaoLenh = PERIOD_M6; // Khung tìm điểm vào lệnh
input int InpPVEMANhanhXuHuong = 95; // EMA nhanh xu hướng
input int InpPVEMAChamXuHuong = 150; // EMA chậm xu hướng
input int InpPVEMANhanhVaoLenh = 26; // EMA nhanh tìm điểm vào lệnh
input int InpPVEMAChamVaoLenh = 29; // EMA chậm tìm điểm vào lệnh
input int InpPVChuKyATR = 30; // Chu kỳ ATR
input int InpPVChuKyADX = 21; // Chu kỳ ADX
input double InpPVADXToiThieu = 14.0; // ADX tối thiểu xác nhận xu hướng
input int InpPVSoNenKiemTraNhipHoi = 6; // Số nến kiểm tra nhịp hồi
input double InpPVDungSaiHoiATR = 0.25; // Dung sai vùng hồi (hệ số ATR)
input double InpPVThanNenToiThieu = 0.30; // Thân nến tín hiệu tối thiểu (tỷ lệ nến)
input double InpPVDoDaiNenToiDaATR = 1.80; // Độ dài nến tín hiệu tối đa (ATR)
input ENUM_PV_MAU_PRICE_ACTION InpPVMauPriceAction = PV_CA_BA_MAU; // Mẫu Price Action sử dụng
input int InpPVSoMauPAToiThieu = 1; // Số mẫu Price Action tối thiểu đồng thuận
input ENUM_TIMEFRAMES InpPVKhungNhanChim = PERIOD_M4; // Khung thời gian nến nhấn chìm
input int InpPVATRNhanChim = 13; // Chu kỳ ATR của nến nhấn chìm
input double InpPVNhanChimMinATR = 1.10; // Biên độ nhấn chìm tối thiểu (ATR)
input double InpPVNhanChimMaxATR = 1.90; // Biên độ nhấn chìm tối đa (ATR)
input double InpPVThanNhanChimSoVoiThanTruoc = 1.0; // Thân nhấn chìm tối thiểu / thân trước
input double InpPVDongCuaManhNhanChim = 0.50; // Vị trí đóng cửa mạnh của nến nhấn chìm
input ENUM_TIMEFRAMES InpPVKhungPinBar = PERIOD_M4; // Khung thời gian Pin Bar
input int InpPVATRPinBar = 10; // Chu kỳ ATR của Pin Bar
input double InpPVPinMinATR = 1.30; // Biên độ Pin Bar tối thiểu (ATR)
input double InpPVPinMaxATR = 1.80; // Biên độ Pin Bar tối đa (ATR)
input double InpPVRauChinhTrenThan = 2.20; // Râu chính Pin Bar / thân tối thiểu
input double InpPVRauDoiDienTrenThan = 0.70; // Râu đối diện / thân tối đa
input double InpPVDongCuaPinTrongBien = 0.60; // Vị trí đóng cửa tối thiểu trong biên nến
input int InpPVPinQuetSoNen = 6; // Pin Bar phải quét đỉnh/đáy số nến này
input ENUM_TIMEFRAMES InpPVKhungBreakout = PERIOD_M4; // Khung thời gian Breakout
input double InpPVThanBreakoutToiThieu = 0.50; // Thân nến phá vỡ tối thiểu (tỷ lệ nến)
input int InpPVSoNenVungBreakout = 2; // Số nến tìm vùng phá vỡ
input double InpPVDemBreakoutGia = 1.00; // Đệm phá đỉnh/đáy (giá)
input bool InpPVChoRetest = false; // Chờ nến retest sau phá vỡ
input double InpPVDungSaiRetestGia = 0.20; // Dung sai vùng retest (giá)
input ENUM_TIMEFRAMES InpPVKhungQuetThanhKhoan = PERIOD_M3; // Khung tìm cú quét
input int InpPVSoNenThanhKhoan = 6; // Số nến tìm đỉnh/đáy thanh khoản
input double InpPVDoXuyenToiThieuGia = 0.70; // Độ xuyên tối thiểu (giá)
input double InpPVDoXuyenToiDaGia = 1.00; // Độ xuyên tối đa (giá)
input double InpPVDongLaiVaoVungGia = 0.45; // Đóng lại vào vùng tối thiểu (giá)
input double InpPVRauQuetTrenThan = 3.0; // Râu quét / thân nến tối thiểu
input ENUM_TIMEFRAMES InpPVKhungTinhPivot = PERIOD_M15; // Khung tính PP/R/S từ nến trước
input ENUM_TIMEFRAMES InpPVKhungXacNhanPivot = PERIOD_M6; // Khung nến xác nhận tại Pivot
input double InpPVBKPVungPivotGia = 1.00; // Bán kính vùng Pivot (giá)
input bool InpPVYeuCauNenDungHuong = true; // Yêu cầu nến xác nhận đúng hướng
input ENUM_PV_MUC_PIVOT InpPVMucPivot = PV_CHI_R2_S2; // Các mức Pivot sử dụng
const int InpPVNgungTruocTinPhut = 30; // 
const int InpPVNgungSauTinPhut = 30; // 
input bool InpPVChiTradeTrongGio = false; // Chỉ giao dịch trong khung giờ bên dưới
input int InpPVGioBatDau = 7; // Giờ bắt đầu giao dịch (giờ máy chủ)
input int InpPVGioKetThuc = 20; // Giờ kết thúc giao dịch (không bao gồm)
input ENUM_PV_NGAY_GIAO_DICH InpPVNgayGiaoDich = PV_THU_HAI_DEN_THU_SAU; // Ngày giao dịch
input ENUM_CHE_DO_KHOI_LUONG InpVolumeMode = LOT_CO_DINH; // Chế độ lot: cố định / % Equity / tiền thật mỗi SL
input double InpGiaTriKhoiLuong = 0.02; // Giá trị lot / % Equity / tiền thật mỗi SL
input int InpSoLenhToiDaMoiNgay = 0; // Lệnh tối đa mỗi ngày mỗi tài khoản; 0=tắt
input double InpDailyLossPct = 0.0; // Ngừng vào mới khi lỗ ngày theo Equity (%); 0=tắt
input ulong InpMagic = 348937; // Mã Magic của lệnh tham chiếu trong Tester
const double InpTruotGiaToiDaGia = 0.30; // Giới hạn mô phỏng đã chốt
input double InpSpreadToiDaGia = 0.50; // Spread tối đa theo giá; 0=tắt
const double InpMinSLPriceDistance = 5.0; // Khoảng SL tối thiểu cho mọi lệnh (giá)
const double InpMaxSLPriceDistance = 20.0; // Khoảng SL tối đa chung cho mọi lệnh (giá)
const bool InpUseTP1Partial = true; // Bật chốt một phần tại TP1
const double InpTP1AtR = 1.0; // Vị trí TP1 chung cho mọi phương pháp, tính theo R
const double InpTP1ClosePct = 50.0; // Tỷ lệ khối lượng chốt tại TP1 cho mọi phương pháp (%)
const bool InpUseTrailing = true; // Bật dời SL tự động
const double InpTrailStartR = 1.0; // Bắt đầu trailing khi đạt số R này
const double InpTrailDistanceR = 1.0; // Khoảng trailing tính theo R
const double InpTrailStepGia = 0.01; // Bước tối thiểu mỗi lần dời SL (giá)
input bool InpUseEMASessionFilter = true; // EMA chỉ vào trong các phiên đã bật
input bool InpUseICTSessionFilter = true; // ICT chỉ vào trong các phiên đã bật
input bool InpUseMMSessionFilter = true; // Market Maker chỉ vào trong các phiên đã bật
input bool InpUseSMCSessionFilter = true; // SMC chỉ vào trong các phiên đã bật
const double InpEMAOutsideSessionRR = 2.0; // 
input bool InpUseAsia = true; // Bật phiên Á
input int InpAsiaStart = 0; // Giờ bắt đầu phiên Á
input int InpAsiaEnd = 8; // Giờ kết thúc phiên Á
const double InpAsiaRR = 1.5; // 
input bool InpUseEurope = true; // Bật phiên Âu
input int InpEuropeStart = 8; // Giờ bắt đầu phiên Âu
input int InpEuropeEnd = 16; // Giờ kết thúc phiên Âu
const double InpEuropeRR = 2.0; // 
input bool InpUseAmerica = true; // Bật phiên Mỹ
input int InpAmericaStart = 16; // Giờ bắt đầu phiên Mỹ
input int InpAmericaEnd = 24; // Giờ kết thúc phiên Mỹ
const double InpAmericaRR = 2.0; // 
const bool InpAnalyzeSL = false; // 
const ENUM_TIMEFRAMES InpSLAnalysisTF = PERIOD_M15; // Khung phân tích nguyên nhân SL
const int InpSLAnalysisATRPeriod = 14; // Chu kỳ ATR phân tích SL
const int InpSLAnalysisFastEMA = 34; // EMA nhanh phân tích xu hướng
const int InpSLAnalysisSlowEMA = 89; // EMA chậm phân tích xu hướng
input bool InpGhiTinHieuBiLoai = false; // Ghi chi tiết tín hiệu bị loại (tốn dung lượng)
enum ENUM_MATRIX_SWAP
{
   MATRIX_SWAP_SAN = 0, // Ước tính theo thông số swap hiện tại của sàn
   MATRIX_SWAP_TAY = 1, // Nhập tiền swap / lot / đêm bằng tiền tài khoản
   MATRIX_SWAP_KHONG = 2 // Không tính swap (kết quả chưa gồm swap)
};
input group "B. QUÉT NHIỀU INPUT TRONG MỘT LƯỢT"
input bool InpMatrixQuetLuoi = true; // Quét tích các danh sách input; false=chỉ bộ gốc
input bool InpMatrixTachHuongPhien = true; // Mỗi bộ thử 3 hướng x 4 phiên = 12 tài khoản riêng
input int InpMatrixToiDaBo = 128; // Giới hạn bộ tín hiệu để bảo vệ RAM; 1-1024
input int InpMatrixToiDaVi = 4096; // Giới hạn số tài khoản mô phỏng; 1-12289
input int InpMatrixLenhMoiPP = 1; // Số vị thế tối đa mỗi phương pháp trong mỗi tài khoản
input string InpLuoiEMA = "InpEMAKhoangDiXaToiThieuATR=0.35,0.75,1.0|InpMinDirectionEfficiency=0.10,0.22"; // Lưới EMA: khoảng chạy xa x hiệu suất sóng
input string InpLuoiICT = "InpICTDisplacementATR=0.60,0.90,1.20|InpICTMinFVG_ATR=0.05,0.10|InpICTPriority=0,1,2,3"; // Lưới ICT: lực phá x FVG x 4 ưu tiên mô hình
input string InpLuoiMM = "InpMMDisplacementATR=0.70,1.0,1.30|InpMMMinFVG_ATR=0.03,0.08"; // Lưới Market Maker
input string InpLuoiSMC = "InpSMCDisplacementATR=0.60,0.90,1.20|InpSMCMinFVGATR=0.03,0.08"; // Lưới SMC cơ sở; chưa mô phỏng lớp L2
input string InpLuoiPVEMA = "InpPVADXToiThieu=14,20,25|InpPVSoNenTimSL=5,10"; // Lưới EMA 95/150 - 26/29
input string InpLuoiENG = "InpPVNhanChimMinATR=0.90,1.10,1.30|InpPVThanNhanChimSoVoiThanTruoc=1.0,1.30"; // Lưới nến nhấn chìm
input string InpLuoiPIN = "InpPVRauChinhTrenThan=2.20,2.80,3.40|InpPVPinQuetSoNen=6,10"; // Lưới Pin Bar
input string InpLuoiBRK = "InpPVSoNenVungBreakout=2,4,8|InpPVChoRetest=false,true"; // Lưới phá vỡ và retest
input string InpLuoiLQ = "InpPVDoXuyenToiThieuGia=0.30,0.50,0.70|InpPVSoNenThanhKhoan=6,12"; // Lưới quét thanh khoản
input string InpLuoiPVT = "InpPVBKPVungPivotGia=0.50,1.0,1.50|InpPVKhungXacNhanPivot=M6,M15"; // Lưới Pivot
input group "C. VỐN, CHI PHÍ VÀ ĐƯỜNG TIỀN TESTER"
input bool InpMatrixLenhTester = true; // Đặt lệnh THAM CHIẾU trong Tester để có Balance/Equity
input int InpMatrixViThamChieu = 0; // ID tài khoản vẽ Graph; 0=bộ gốc gộp các PP, không đổi giữa lượt; Bộ hiệu quả nhất tự dùng ví 10
input double InpMatrixVonMoiVi = 0.0; // Vốn mỗi tài khoản bằng tiền tài khoản; 0=lấy Deposit của Tester
input double InpMatrixHeSoTienThat = 0.0; // Đơn vị tài khoản / 1 tiền thật; 0=tự nhận USD=1, USC/USDC=100
input double InpMatrixPhiKhuHoiLot = 0.0; // Commission khứ hồi / lot theo tiền tài khoản (USD hoặc USC)
input ENUM_MATRIX_SWAP InpMatrixSwap = MATRIX_SWAP_SAN; // Cách tính swap mô phỏng
input double InpMatrixSwapBuy = 0.0; // Swap BUY / lot / đêm nếu nhập tay; số âm là phí
input double InpMatrixSwapSell = 0.0; // Swap SELL / lot / đêm nếu nhập tay
input double InpMatrixTruotGiaVao = 0.0; // Trượt giá bất lợi khi mô phỏng vào lệnh: 0-0.30 giá
input group "D. ĐÁNH GIÁ VÀ XUẤT FILE"
input int InpMatrixSoLenhTinCay = 100; // Số lệnh đóng tối thiểu để xét hạng hiệu quả
input int InpMatrixSoThangTinCay = 3; // Số tháng dữ liệu tối thiểu (tháng không lệnh vẫn tính)
input datetime InpMatrixTuNgayKiemChung = 0; // Mốc tách dữ liệu kiểm chứng; 0=chưa tách, chỉ thăm dò
input string InpMatrixThuMuc = "DavidHunter_V439_Matrix"; // Thư mục log; mỗi lượt tạo thư mục con riêng
input bool InpMatrixGhiNenM1 = true; // Xuất nến M1 một lần, dùng chung mọi cấu hình
input int InpMatrixGhiEquityPhut = 60; // Khoảng ghi đường vốn từng tài khoản; 0=tắt file đường vốn
input bool InpMatrixBangNhe = true; // Bảng trạng thái nhỏ, chỉ trong Visual Tester

// V4.39 MATRIX 7PP: ví đặt lệnh tham chiếu thật (Graph). Bộ hiệu quả nhất = ví của đúng bộ đó.
int MXViThamChieu() { return InpMatrixBoCaiSan==BO_HIEU_QUA_NHAT?10:InpMatrixViThamChieu; }

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
   bool InpUseICTModule;
   bool InpUseMMModule;
   bool InpUseSMCModule;
   bool InpUsePVEMAModule;
   bool InpUseENGModule;
   bool InpUsePINModule;
   bool InpUseBRKModule;
   bool InpUseLQModule;
   bool InpUsePVTModule;
   ENUM_TIMEFRAMES InpTimeframe;
   int InpFastEMA;
   int InpSlowEMA;
   int InpSLLookbackBars;
   double InpSLBufferGia;
   bool InpEMAVaoSauRetest;
   ENUM_MUC_RETEST_EMA InpEMAMucRetest;
   double InpEMAKhoangDiXaToiThieuATR;
   double InpEMADungSaiRetestGia;
   int InpEMASoNenChoToiThieu;
   int InpEMAHetHanRetestBars;
   bool InpEMADungLocM5;
   ENUM_TIMEFRAMES InpEMAKhungLoc;
   int InpEMANhanhLoc;
   int InpEMAChamLoc;
   bool InpUseWaveFilter;
   int InpWaveBars;
   int InpATRPeriod;
   double InpMinWaveATR;
   double InpMinMoveATR;
   int InpRecentCrossBars;
   double InpMinDirectionEfficiency;
   bool InpRequireOuterHalf;
   double InpMaxOpposingSlowSlopeATR;
   ENUM_TIMEFRAMES InpICTEntryTF;
   ENUM_TIMEFRAMES InpICTBiasTF;
   bool InpICTUse2022;
   bool InpICTUseOTE;
   bool InpICTUseUnicorn;
   bool InpICTUseInversion;
   ENUM_ICT_PRIORITY InpICTPriority;
   int InpICTLookback;
   int InpICTPivotBars;
   int InpICTSetupExpiryBars;
   double InpICTMinFVG_ATR;
   double InpICTDisplacementATR;
   double InpICTMinImpulseATR;
   double InpICTOTEHigh;
   double InpICTOTELow;
   double InpICTRR;
   double InpICTSLBufferGia;
   ENUM_TIMEFRAMES InpMMEntryTF;
   ENUM_TIMEFRAMES InpMMBiasTF;
   int InpMMLookback;
   int InpMMPivotBars;
   int InpMMRangeBars;
   double InpMMPremiumLevel;
   double InpMMDiscountLevel;
   double InpMMDisplacementATR;
   double InpMMMinFVG_ATR;
   double InpMMMaxConsolidationATR;
   int InpMMConsolidationBars;
   int InpMMModelExpiryBars;
   int InpMMLegSetupExpiryBars;
   int InpMMLowRiskExpiryBars;
   bool InpMMUseLowRisk;
   bool InpMMUseLeg1;
   bool InpMMUseLeg2;
   double InpMMRR;
   double InpMMSLBufferGia;
   ENUM_TIMEFRAMES InpSMCEntryTF;
   ENUM_TIMEFRAMES InpSMCBiasTF;
   int InpSMCLookback;
   int InpSMCPivotBars;
   int InpSMCSetupExpiryBars;
   double InpSMCDisplacementATR;
   bool InpSMCBatBuocFVG;
   bool InpSMCUuTienVungFVG;
   double InpSMCMinFVGATR;
   bool InpSMCDungLocEMAH1;
   int InpSMCEMANhanhH1;
   int InpSMCEMAChamH1;
   bool InpSMCYeuCauThuTuEMAH1;
   bool InpSMCDungLocEMAM5;
   int InpSMCEMANhanhM5;
   int InpSMCEMAChamM5;
   bool InpSMCYeuCauDoDocEMAM5;
   int InpSMCSoNenDoDocEMA;
   bool InpSMCDungLocRSI;
   int InpSMCRSIPeriod;
   double InpSMCRSIMuaToiThieu;
   double InpSMCRSIBanToiDa;
   double InpSMCRR;
   double InpSMCSLBufferGia;
   bool InpSMCBatLop2;
   double InpSMCLop2PhanTramDenSL;
   ENUM_PV_HUONG_GIAO_DICH InpPVHuongGiaoDich;
   ENUM_PV_CACH_KET_HOP InpPVCachKetHop;
   int InpPVSoNenTimSL;
   double InpPVDemSLGia;
   double InpPVBEKhiLoiGia;
   double InpPVTP2R;
   double InpPVRRToiThieu;
   int InpPVThuaLienTiepToiDa;
   ENUM_TIMEFRAMES InpPVKhungXuHuong;
   ENUM_TIMEFRAMES InpPVKhungVaoLenh;
   int InpPVEMANhanhXuHuong;
   int InpPVEMAChamXuHuong;
   int InpPVEMANhanhVaoLenh;
   int InpPVEMAChamVaoLenh;
   int InpPVChuKyATR;
   int InpPVChuKyADX;
   double InpPVADXToiThieu;
   int InpPVSoNenKiemTraNhipHoi;
   double InpPVDungSaiHoiATR;
   double InpPVThanNenToiThieu;
   double InpPVDoDaiNenToiDaATR;
   ENUM_PV_MAU_PRICE_ACTION InpPVMauPriceAction;
   int InpPVSoMauPAToiThieu;
   ENUM_TIMEFRAMES InpPVKhungNhanChim;
   int InpPVATRNhanChim;
   double InpPVNhanChimMinATR;
   double InpPVNhanChimMaxATR;
   double InpPVThanNhanChimSoVoiThanTruoc;
   double InpPVDongCuaManhNhanChim;
   ENUM_TIMEFRAMES InpPVKhungPinBar;
   int InpPVATRPinBar;
   double InpPVPinMinATR;
   double InpPVPinMaxATR;
   double InpPVRauChinhTrenThan;
   double InpPVRauDoiDienTrenThan;
   double InpPVDongCuaPinTrongBien;
   int InpPVPinQuetSoNen;
   ENUM_TIMEFRAMES InpPVKhungBreakout;
   double InpPVThanBreakoutToiThieu;
   int InpPVSoNenVungBreakout;
   double InpPVDemBreakoutGia;
   bool InpPVChoRetest;
   double InpPVDungSaiRetestGia;
   ENUM_TIMEFRAMES InpPVKhungQuetThanhKhoan;
   int InpPVSoNenThanhKhoan;
   double InpPVDoXuyenToiThieuGia;
   double InpPVDoXuyenToiDaGia;
   double InpPVDongLaiVaoVungGia;
   double InpPVRauQuetTrenThan;
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
   bool InpUseEMASessionFilter;
   bool InpUseICTSessionFilter;
   bool InpUseMMSessionFilter;
   bool InpUseSMCSessionFilter;
   double InpEMAOutsideSessionRR;
   bool InpUseAsia;
   int InpAsiaStart;
   int InpAsiaEnd;
   double InpAsiaRR;
   bool InpUseEurope;
   int InpEuropeStart;
   int InpEuropeEnd;
   double InpEuropeRR;
   bool InpUseAmerica;
   int InpAmericaStart;
   int InpAmericaEnd;
   double InpAmericaRR;
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
   c.InpUseEMAModule = InpUseEMAModule;
   c.InpUseICTModule = InpUseICTModule;
   c.InpUseMMModule = InpUseMMModule;
   c.InpUseSMCModule = InpUseSMCModule;
   c.InpUsePVEMAModule = InpUsePVEMAModule;
   c.InpUseENGModule = InpUseENGModule;
   c.InpUsePINModule = InpUsePINModule;
   c.InpUseBRKModule = InpUseBRKModule;
   c.InpUseLQModule = InpUseLQModule;
   c.InpUsePVTModule = InpUsePVTModule;
   c.InpTimeframe = InpTimeframe;
   c.InpFastEMA = InpFastEMA;
   c.InpSlowEMA = InpSlowEMA;
   c.InpSLLookbackBars = InpSLLookbackBars;
   c.InpSLBufferGia = InpSLBufferGia;
   c.InpEMAVaoSauRetest = InpEMAVaoSauRetest;
   c.InpEMAMucRetest = InpEMAMucRetest;
   c.InpEMAKhoangDiXaToiThieuATR = InpEMAKhoangDiXaToiThieuATR;
   c.InpEMADungSaiRetestGia = InpEMADungSaiRetestGia;
   c.InpEMASoNenChoToiThieu = InpEMASoNenChoToiThieu;
   c.InpEMAHetHanRetestBars = InpEMAHetHanRetestBars;
   c.InpEMADungLocM5 = InpEMADungLocM5;
   c.InpEMAKhungLoc = InpEMAKhungLoc;
   c.InpEMANhanhLoc = InpEMANhanhLoc;
   c.InpEMAChamLoc = InpEMAChamLoc;
   c.InpUseWaveFilter = InpUseWaveFilter;
   c.InpWaveBars = InpWaveBars;
   c.InpATRPeriod = InpATRPeriod;
   c.InpMinWaveATR = InpMinWaveATR;
   c.InpMinMoveATR = InpMinMoveATR;
   c.InpRecentCrossBars = InpRecentCrossBars;
   c.InpMinDirectionEfficiency = InpMinDirectionEfficiency;
   c.InpRequireOuterHalf = InpRequireOuterHalf;
   c.InpMaxOpposingSlowSlopeATR = InpMaxOpposingSlowSlopeATR;
   c.InpICTEntryTF = InpICTEntryTF;
   c.InpICTBiasTF = InpICTBiasTF;
   c.InpICTUse2022 = InpICTUse2022;
   c.InpICTUseOTE = InpICTUseOTE;
   c.InpICTUseUnicorn = InpICTUseUnicorn;
   c.InpICTUseInversion = InpICTUseInversion;
   c.InpICTPriority = InpICTPriority;
   c.InpICTLookback = InpICTLookback;
   c.InpICTPivotBars = InpICTPivotBars;
   c.InpICTSetupExpiryBars = InpICTSetupExpiryBars;
   c.InpICTMinFVG_ATR = InpICTMinFVG_ATR;
   c.InpICTDisplacementATR = InpICTDisplacementATR;
   c.InpICTMinImpulseATR = InpICTMinImpulseATR;
   c.InpICTOTEHigh = InpICTOTEHigh;
   c.InpICTOTELow = InpICTOTELow;
   c.InpICTRR = InpICTRR;
   c.InpICTSLBufferGia = InpICTSLBufferGia;
   c.InpMMEntryTF = InpMMEntryTF;
   c.InpMMBiasTF = InpMMBiasTF;
   c.InpMMLookback = InpMMLookback;
   c.InpMMPivotBars = InpMMPivotBars;
   c.InpMMRangeBars = InpMMRangeBars;
   c.InpMMPremiumLevel = InpMMPremiumLevel;
   c.InpMMDiscountLevel = InpMMDiscountLevel;
   c.InpMMDisplacementATR = InpMMDisplacementATR;
   c.InpMMMinFVG_ATR = InpMMMinFVG_ATR;
   c.InpMMMaxConsolidationATR = InpMMMaxConsolidationATR;
   c.InpMMConsolidationBars = InpMMConsolidationBars;
   c.InpMMModelExpiryBars = InpMMModelExpiryBars;
   c.InpMMLegSetupExpiryBars = InpMMLegSetupExpiryBars;
   c.InpMMLowRiskExpiryBars = InpMMLowRiskExpiryBars;
   c.InpMMUseLowRisk = InpMMUseLowRisk;
   c.InpMMUseLeg1 = InpMMUseLeg1;
   c.InpMMUseLeg2 = InpMMUseLeg2;
   c.InpMMRR = InpMMRR;
   c.InpMMSLBufferGia = InpMMSLBufferGia;
   c.InpSMCEntryTF = InpSMCEntryTF;
   c.InpSMCBiasTF = InpSMCBiasTF;
   c.InpSMCLookback = InpSMCLookback;
   c.InpSMCPivotBars = InpSMCPivotBars;
   c.InpSMCSetupExpiryBars = InpSMCSetupExpiryBars;
   c.InpSMCDisplacementATR = InpSMCDisplacementATR;
   c.InpSMCBatBuocFVG = InpSMCBatBuocFVG;
   c.InpSMCUuTienVungFVG = InpSMCUuTienVungFVG;
   c.InpSMCMinFVGATR = InpSMCMinFVGATR;
   c.InpSMCDungLocEMAH1 = InpSMCDungLocEMAH1;
   c.InpSMCEMANhanhH1 = InpSMCEMANhanhH1;
   c.InpSMCEMAChamH1 = InpSMCEMAChamH1;
   c.InpSMCYeuCauThuTuEMAH1 = InpSMCYeuCauThuTuEMAH1;
   c.InpSMCDungLocEMAM5 = InpSMCDungLocEMAM5;
   c.InpSMCEMANhanhM5 = InpSMCEMANhanhM5;
   c.InpSMCEMAChamM5 = InpSMCEMAChamM5;
   c.InpSMCYeuCauDoDocEMAM5 = InpSMCYeuCauDoDocEMAM5;
   c.InpSMCSoNenDoDocEMA = InpSMCSoNenDoDocEMA;
   c.InpSMCDungLocRSI = InpSMCDungLocRSI;
   c.InpSMCRSIPeriod = InpSMCRSIPeriod;
   c.InpSMCRSIMuaToiThieu = InpSMCRSIMuaToiThieu;
   c.InpSMCRSIBanToiDa = InpSMCRSIBanToiDa;
   c.InpSMCRR = InpSMCRR;
   c.InpSMCSLBufferGia = InpSMCSLBufferGia;
   c.InpSMCBatLop2 = InpSMCBatLop2;
   c.InpSMCLop2PhanTramDenSL = InpSMCLop2PhanTramDenSL;
   c.InpPVHuongGiaoDich = InpPVHuongGiaoDich;
   c.InpPVCachKetHop = InpPVCachKetHop;
   c.InpPVSoNenTimSL = InpPVSoNenTimSL;
   c.InpPVDemSLGia = InpPVDemSLGia;
   c.InpPVBEKhiLoiGia = InpPVBEKhiLoiGia;
   c.InpPVTP2R = InpPVTP2R;
   c.InpPVRRToiThieu = InpPVRRToiThieu;
   c.InpPVThuaLienTiepToiDa = InpPVThuaLienTiepToiDa;
   c.InpPVKhungXuHuong = InpPVKhungXuHuong;
   c.InpPVKhungVaoLenh = InpPVKhungVaoLenh;
   c.InpPVEMANhanhXuHuong = InpPVEMANhanhXuHuong;
   c.InpPVEMAChamXuHuong = InpPVEMAChamXuHuong;
   c.InpPVEMANhanhVaoLenh = InpPVEMANhanhVaoLenh;
   c.InpPVEMAChamVaoLenh = InpPVEMAChamVaoLenh;
   c.InpPVChuKyATR = InpPVChuKyATR;
   c.InpPVChuKyADX = InpPVChuKyADX;
   c.InpPVADXToiThieu = InpPVADXToiThieu;
   c.InpPVSoNenKiemTraNhipHoi = InpPVSoNenKiemTraNhipHoi;
   c.InpPVDungSaiHoiATR = InpPVDungSaiHoiATR;
   c.InpPVThanNenToiThieu = InpPVThanNenToiThieu;
   c.InpPVDoDaiNenToiDaATR = InpPVDoDaiNenToiDaATR;
   c.InpPVMauPriceAction = InpPVMauPriceAction;
   c.InpPVSoMauPAToiThieu = InpPVSoMauPAToiThieu;
   c.InpPVKhungNhanChim = InpPVKhungNhanChim;
   c.InpPVATRNhanChim = InpPVATRNhanChim;
   c.InpPVNhanChimMinATR = InpPVNhanChimMinATR;
   c.InpPVNhanChimMaxATR = InpPVNhanChimMaxATR;
   c.InpPVThanNhanChimSoVoiThanTruoc = InpPVThanNhanChimSoVoiThanTruoc;
   c.InpPVDongCuaManhNhanChim = InpPVDongCuaManhNhanChim;
   c.InpPVKhungPinBar = InpPVKhungPinBar;
   c.InpPVATRPinBar = InpPVATRPinBar;
   c.InpPVPinMinATR = InpPVPinMinATR;
   c.InpPVPinMaxATR = InpPVPinMaxATR;
   c.InpPVRauChinhTrenThan = InpPVRauChinhTrenThan;
   c.InpPVRauDoiDienTrenThan = InpPVRauDoiDienTrenThan;
   c.InpPVDongCuaPinTrongBien = InpPVDongCuaPinTrongBien;
   c.InpPVPinQuetSoNen = InpPVPinQuetSoNen;
   c.InpPVKhungBreakout = InpPVKhungBreakout;
   c.InpPVThanBreakoutToiThieu = InpPVThanBreakoutToiThieu;
   c.InpPVSoNenVungBreakout = InpPVSoNenVungBreakout;
   c.InpPVDemBreakoutGia = InpPVDemBreakoutGia;
   c.InpPVChoRetest = InpPVChoRetest;
   c.InpPVDungSaiRetestGia = InpPVDungSaiRetestGia;
   c.InpPVKhungQuetThanhKhoan = InpPVKhungQuetThanhKhoan;
   c.InpPVSoNenThanhKhoan = InpPVSoNenThanhKhoan;
   c.InpPVDoXuyenToiThieuGia = InpPVDoXuyenToiThieuGia;
   c.InpPVDoXuyenToiDaGia = InpPVDoXuyenToiDaGia;
   c.InpPVDongLaiVaoVungGia = InpPVDongLaiVaoVungGia;
   c.InpPVRauQuetTrenThan = InpPVRauQuetTrenThan;
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
   c.InpUseEMASessionFilter = InpUseEMASessionFilter;
   c.InpUseICTSessionFilter = InpUseICTSessionFilter;
   c.InpUseMMSessionFilter = InpUseMMSessionFilter;
   c.InpUseSMCSessionFilter = InpUseSMCSessionFilter;
   c.InpEMAOutsideSessionRR = InpEMAOutsideSessionRR;
   c.InpUseAsia = InpUseAsia;
   c.InpAsiaStart = InpAsiaStart;
   c.InpAsiaEnd = InpAsiaEnd;
   c.InpAsiaRR = InpAsiaRR;
   c.InpUseEurope = InpUseEurope;
   c.InpEuropeStart = InpEuropeStart;
   c.InpEuropeEnd = InpEuropeEnd;
   c.InpEuropeRR = InpEuropeRR;
   c.InpUseAmerica = InpUseAmerica;
   c.InpAmericaStart = InpAmericaStart;
   c.InpAmericaEnd = InpAmericaEnd;
   c.InpAmericaRR = InpAmericaRR;
   c.InpAnalyzeSL = InpAnalyzeSL;
   c.InpSLAnalysisTF = InpSLAnalysisTF;
   c.InpSLAnalysisATRPeriod = InpSLAnalysisATRPeriod;
   c.InpSLAnalysisFastEMA = InpSLAnalysisFastEMA;
   c.InpSLAnalysisSlowEMA = InpSLAnalysisSlowEMA;
   c.InpGhiTinHieuBiLoai = InpGhiTinHieuBiLoai;
}
bool MatrixSetValue(MatrixConfig &c,const string key,const double value)
{
   if(key=="InpTimeframe") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpTimeframe=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpFastEMA") { if(value!=MathFloor(value)) return false; c.InpFastEMA=(int)value; return true; }
   if(key=="InpSlowEMA") { if(value!=MathFloor(value)) return false; c.InpSlowEMA=(int)value; return true; }
   if(key=="InpSLLookbackBars") { if(value!=MathFloor(value)) return false; c.InpSLLookbackBars=(int)value; return true; }
   if(key=="InpSLBufferGia") { c.InpSLBufferGia=(double)value; return true; }
   if(key=="InpEMAVaoSauRetest") { if(value!=0.0 && value!=1.0) return false; c.InpEMAVaoSauRetest=(bool)value; return true; }
   if(key=="InpEMAMucRetest") { if(value!=MathFloor(value)) return false; if(value<0 || value>2) return false; c.InpEMAMucRetest=(ENUM_MUC_RETEST_EMA)value; return true; }
   if(key=="InpEMAKhoangDiXaToiThieuATR") { c.InpEMAKhoangDiXaToiThieuATR=(double)value; return true; }
   if(key=="InpEMADungSaiRetestGia") { c.InpEMADungSaiRetestGia=(double)value; return true; }
   if(key=="InpEMASoNenChoToiThieu") { if(value!=MathFloor(value)) return false; c.InpEMASoNenChoToiThieu=(int)value; return true; }
   if(key=="InpEMAHetHanRetestBars") { if(value!=MathFloor(value)) return false; c.InpEMAHetHanRetestBars=(int)value; return true; }
   if(key=="InpEMADungLocM5") { if(value!=0.0 && value!=1.0) return false; c.InpEMADungLocM5=(bool)value; return true; }
   if(key=="InpEMAKhungLoc") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpEMAKhungLoc=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpEMANhanhLoc") { if(value!=MathFloor(value)) return false; c.InpEMANhanhLoc=(int)value; return true; }
   if(key=="InpEMAChamLoc") { if(value!=MathFloor(value)) return false; c.InpEMAChamLoc=(int)value; return true; }
   if(key=="InpUseWaveFilter") { if(value!=0.0 && value!=1.0) return false; c.InpUseWaveFilter=(bool)value; return true; }
   if(key=="InpWaveBars") { if(value!=MathFloor(value)) return false; c.InpWaveBars=(int)value; return true; }
   if(key=="InpATRPeriod") { if(value!=MathFloor(value)) return false; c.InpATRPeriod=(int)value; return true; }
   if(key=="InpMinWaveATR") { c.InpMinWaveATR=(double)value; return true; }
   if(key=="InpMinMoveATR") { c.InpMinMoveATR=(double)value; return true; }
   if(key=="InpRecentCrossBars") { if(value!=MathFloor(value)) return false; c.InpRecentCrossBars=(int)value; return true; }
   if(key=="InpMinDirectionEfficiency") { c.InpMinDirectionEfficiency=(double)value; return true; }
   if(key=="InpRequireOuterHalf") { if(value!=0.0 && value!=1.0) return false; c.InpRequireOuterHalf=(bool)value; return true; }
   if(key=="InpMaxOpposingSlowSlopeATR") { c.InpMaxOpposingSlowSlopeATR=(double)value; return true; }
   if(key=="InpICTEntryTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpICTEntryTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpICTBiasTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpICTBiasTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpICTUse2022") { if(value!=0.0 && value!=1.0) return false; c.InpICTUse2022=(bool)value; return true; }
   if(key=="InpICTUseOTE") { if(value!=0.0 && value!=1.0) return false; c.InpICTUseOTE=(bool)value; return true; }
   if(key=="InpICTUseUnicorn") { if(value!=0.0 && value!=1.0) return false; c.InpICTUseUnicorn=(bool)value; return true; }
   if(key=="InpICTUseInversion") { if(value!=0.0 && value!=1.0) return false; c.InpICTUseInversion=(bool)value; return true; }
   if(key=="InpICTPriority") { if(value!=MathFloor(value)) return false; if(value<0 || value>3) return false; c.InpICTPriority=(ENUM_ICT_PRIORITY)value; return true; }
   if(key=="InpICTLookback") { if(value!=MathFloor(value)) return false; c.InpICTLookback=(int)value; return true; }
   if(key=="InpICTPivotBars") { if(value!=MathFloor(value)) return false; c.InpICTPivotBars=(int)value; return true; }
   if(key=="InpICTSetupExpiryBars") { if(value!=MathFloor(value)) return false; c.InpICTSetupExpiryBars=(int)value; return true; }
   if(key=="InpICTMinFVG_ATR") { c.InpICTMinFVG_ATR=(double)value; return true; }
   if(key=="InpICTDisplacementATR") { c.InpICTDisplacementATR=(double)value; return true; }
   if(key=="InpICTMinImpulseATR") { c.InpICTMinImpulseATR=(double)value; return true; }
   if(key=="InpICTOTEHigh") { c.InpICTOTEHigh=(double)value; return true; }
   if(key=="InpICTOTELow") { c.InpICTOTELow=(double)value; return true; }
   if(key=="InpICTSLBufferGia") { c.InpICTSLBufferGia=(double)value; return true; }
   if(key=="InpMMEntryTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpMMEntryTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpMMBiasTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpMMBiasTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpMMLookback") { if(value!=MathFloor(value)) return false; c.InpMMLookback=(int)value; return true; }
   if(key=="InpMMPivotBars") { if(value!=MathFloor(value)) return false; c.InpMMPivotBars=(int)value; return true; }
   if(key=="InpMMRangeBars") { if(value!=MathFloor(value)) return false; c.InpMMRangeBars=(int)value; return true; }
   if(key=="InpMMPremiumLevel") { c.InpMMPremiumLevel=(double)value; return true; }
   if(key=="InpMMDiscountLevel") { c.InpMMDiscountLevel=(double)value; return true; }
   if(key=="InpMMDisplacementATR") { c.InpMMDisplacementATR=(double)value; return true; }
   if(key=="InpMMMinFVG_ATR") { c.InpMMMinFVG_ATR=(double)value; return true; }
   if(key=="InpMMMaxConsolidationATR") { c.InpMMMaxConsolidationATR=(double)value; return true; }
   if(key=="InpMMConsolidationBars") { if(value!=MathFloor(value)) return false; c.InpMMConsolidationBars=(int)value; return true; }
   if(key=="InpMMModelExpiryBars") { if(value!=MathFloor(value)) return false; c.InpMMModelExpiryBars=(int)value; return true; }
   if(key=="InpMMLegSetupExpiryBars") { if(value!=MathFloor(value)) return false; c.InpMMLegSetupExpiryBars=(int)value; return true; }
   if(key=="InpMMLowRiskExpiryBars") { if(value!=MathFloor(value)) return false; c.InpMMLowRiskExpiryBars=(int)value; return true; }
   if(key=="InpMMUseLowRisk") { if(value!=0.0 && value!=1.0) return false; c.InpMMUseLowRisk=(bool)value; return true; }
   if(key=="InpMMUseLeg1") { if(value!=0.0 && value!=1.0) return false; c.InpMMUseLeg1=(bool)value; return true; }
   if(key=="InpMMUseLeg2") { if(value!=0.0 && value!=1.0) return false; c.InpMMUseLeg2=(bool)value; return true; }
   if(key=="InpMMSLBufferGia") { c.InpMMSLBufferGia=(double)value; return true; }
   if(key=="InpSMCEntryTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpSMCEntryTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpSMCBiasTF") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpSMCBiasTF=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpSMCLookback") { if(value!=MathFloor(value)) return false; c.InpSMCLookback=(int)value; return true; }
   if(key=="InpSMCPivotBars") { if(value!=MathFloor(value)) return false; c.InpSMCPivotBars=(int)value; return true; }
   if(key=="InpSMCSetupExpiryBars") { if(value!=MathFloor(value)) return false; c.InpSMCSetupExpiryBars=(int)value; return true; }
   if(key=="InpSMCDisplacementATR") { c.InpSMCDisplacementATR=(double)value; return true; }
   if(key=="InpSMCBatBuocFVG") { if(value!=0.0 && value!=1.0) return false; c.InpSMCBatBuocFVG=(bool)value; return true; }
   if(key=="InpSMCUuTienVungFVG") { if(value!=0.0 && value!=1.0) return false; c.InpSMCUuTienVungFVG=(bool)value; return true; }
   if(key=="InpSMCMinFVGATR") { c.InpSMCMinFVGATR=(double)value; return true; }
   if(key=="InpSMCDungLocEMAH1") { if(value!=0.0 && value!=1.0) return false; c.InpSMCDungLocEMAH1=(bool)value; return true; }
   if(key=="InpSMCEMANhanhH1") { if(value!=MathFloor(value)) return false; c.InpSMCEMANhanhH1=(int)value; return true; }
   if(key=="InpSMCEMAChamH1") { if(value!=MathFloor(value)) return false; c.InpSMCEMAChamH1=(int)value; return true; }
   if(key=="InpSMCYeuCauThuTuEMAH1") { if(value!=0.0 && value!=1.0) return false; c.InpSMCYeuCauThuTuEMAH1=(bool)value; return true; }
   if(key=="InpSMCDungLocEMAM5") { if(value!=0.0 && value!=1.0) return false; c.InpSMCDungLocEMAM5=(bool)value; return true; }
   if(key=="InpSMCEMANhanhM5") { if(value!=MathFloor(value)) return false; c.InpSMCEMANhanhM5=(int)value; return true; }
   if(key=="InpSMCEMAChamM5") { if(value!=MathFloor(value)) return false; c.InpSMCEMAChamM5=(int)value; return true; }
   if(key=="InpSMCYeuCauDoDocEMAM5") { if(value!=0.0 && value!=1.0) return false; c.InpSMCYeuCauDoDocEMAM5=(bool)value; return true; }
   if(key=="InpSMCSoNenDoDocEMA") { if(value!=MathFloor(value)) return false; c.InpSMCSoNenDoDocEMA=(int)value; return true; }
   if(key=="InpSMCDungLocRSI") { if(value!=0.0 && value!=1.0) return false; c.InpSMCDungLocRSI=(bool)value; return true; }
   if(key=="InpSMCRSIPeriod") { if(value!=MathFloor(value)) return false; c.InpSMCRSIPeriod=(int)value; return true; }
   if(key=="InpSMCRSIMuaToiThieu") { c.InpSMCRSIMuaToiThieu=(double)value; return true; }
   if(key=="InpSMCRSIBanToiDa") { c.InpSMCRSIBanToiDa=(double)value; return true; }
   if(key=="InpSMCSLBufferGia") { c.InpSMCSLBufferGia=(double)value; return true; }
   if(key=="InpPVHuongGiaoDich") { if(value!=MathFloor(value)) return false; if(value<0 || value>2) return false; c.InpPVHuongGiaoDich=(ENUM_PV_HUONG_GIAO_DICH)value; return true; }
   if(key=="InpPVSoNenTimSL") { if(value!=MathFloor(value)) return false; c.InpPVSoNenTimSL=(int)value; return true; }
   if(key=="InpPVDemSLGia") { c.InpPVDemSLGia=(double)value; return true; }
   if(key=="InpPVKhungXuHuong") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungXuHuong=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVKhungVaoLenh") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungVaoLenh=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVEMANhanhXuHuong") { if(value!=MathFloor(value)) return false; c.InpPVEMANhanhXuHuong=(int)value; return true; }
   if(key=="InpPVEMAChamXuHuong") { if(value!=MathFloor(value)) return false; c.InpPVEMAChamXuHuong=(int)value; return true; }
   if(key=="InpPVEMANhanhVaoLenh") { if(value!=MathFloor(value)) return false; c.InpPVEMANhanhVaoLenh=(int)value; return true; }
   if(key=="InpPVEMAChamVaoLenh") { if(value!=MathFloor(value)) return false; c.InpPVEMAChamVaoLenh=(int)value; return true; }
   if(key=="InpPVChuKyATR") { if(value!=MathFloor(value)) return false; c.InpPVChuKyATR=(int)value; return true; }
   if(key=="InpPVChuKyADX") { if(value!=MathFloor(value)) return false; c.InpPVChuKyADX=(int)value; return true; }
   if(key=="InpPVADXToiThieu") { c.InpPVADXToiThieu=(double)value; return true; }
   if(key=="InpPVSoNenKiemTraNhipHoi") { if(value!=MathFloor(value)) return false; c.InpPVSoNenKiemTraNhipHoi=(int)value; return true; }
   if(key=="InpPVDungSaiHoiATR") { c.InpPVDungSaiHoiATR=(double)value; return true; }
   if(key=="InpPVThanNenToiThieu") { c.InpPVThanNenToiThieu=(double)value; return true; }
   if(key=="InpPVDoDaiNenToiDaATR") { c.InpPVDoDaiNenToiDaATR=(double)value; return true; }
   if(key=="InpPVSoMauPAToiThieu") { if(value!=MathFloor(value)) return false; c.InpPVSoMauPAToiThieu=(int)value; return true; }
   if(key=="InpPVKhungNhanChim") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungNhanChim=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVATRNhanChim") { if(value!=MathFloor(value)) return false; c.InpPVATRNhanChim=(int)value; return true; }
   if(key=="InpPVNhanChimMinATR") { c.InpPVNhanChimMinATR=(double)value; return true; }
   if(key=="InpPVNhanChimMaxATR") { c.InpPVNhanChimMaxATR=(double)value; return true; }
   if(key=="InpPVThanNhanChimSoVoiThanTruoc") { c.InpPVThanNhanChimSoVoiThanTruoc=(double)value; return true; }
   if(key=="InpPVDongCuaManhNhanChim") { c.InpPVDongCuaManhNhanChim=(double)value; return true; }
   if(key=="InpPVKhungPinBar") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungPinBar=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVATRPinBar") { if(value!=MathFloor(value)) return false; c.InpPVATRPinBar=(int)value; return true; }
   if(key=="InpPVPinMinATR") { c.InpPVPinMinATR=(double)value; return true; }
   if(key=="InpPVPinMaxATR") { c.InpPVPinMaxATR=(double)value; return true; }
   if(key=="InpPVRauChinhTrenThan") { c.InpPVRauChinhTrenThan=(double)value; return true; }
   if(key=="InpPVRauDoiDienTrenThan") { c.InpPVRauDoiDienTrenThan=(double)value; return true; }
   if(key=="InpPVDongCuaPinTrongBien") { c.InpPVDongCuaPinTrongBien=(double)value; return true; }
   if(key=="InpPVPinQuetSoNen") { if(value!=MathFloor(value)) return false; c.InpPVPinQuetSoNen=(int)value; return true; }
   if(key=="InpPVKhungBreakout") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungBreakout=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVThanBreakoutToiThieu") { c.InpPVThanBreakoutToiThieu=(double)value; return true; }
   if(key=="InpPVSoNenVungBreakout") { if(value!=MathFloor(value)) return false; c.InpPVSoNenVungBreakout=(int)value; return true; }
   if(key=="InpPVDemBreakoutGia") { c.InpPVDemBreakoutGia=(double)value; return true; }
   if(key=="InpPVChoRetest") { if(value!=0.0 && value!=1.0) return false; c.InpPVChoRetest=(bool)value; return true; }
   if(key=="InpPVDungSaiRetestGia") { c.InpPVDungSaiRetestGia=(double)value; return true; }
   if(key=="InpPVKhungQuetThanhKhoan") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungQuetThanhKhoan=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVSoNenThanhKhoan") { if(value!=MathFloor(value)) return false; c.InpPVSoNenThanhKhoan=(int)value; return true; }
   if(key=="InpPVDoXuyenToiThieuGia") { c.InpPVDoXuyenToiThieuGia=(double)value; return true; }
   if(key=="InpPVDoXuyenToiDaGia") { c.InpPVDoXuyenToiDaGia=(double)value; return true; }
   if(key=="InpPVDongLaiVaoVungGia") { c.InpPVDongLaiVaoVungGia=(double)value; return true; }
   if(key=="InpPVRauQuetTrenThan") { c.InpPVRauQuetTrenThan=(double)value; return true; }
   if(key=="InpPVKhungTinhPivot") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungTinhPivot=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVKhungXacNhanPivot") { if(value!=MathFloor(value)) return false; if(!MatrixValidTF((int)value)) return false; c.InpPVKhungXacNhanPivot=(ENUM_TIMEFRAMES)value; return true; }
   if(key=="InpPVBKPVungPivotGia") { c.InpPVBKPVungPivotGia=(double)value; return true; }
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
   s += "InpUseICTModule=" + (c.InpUseICTModule?"true":"false") + "|";
   s += "InpUseMMModule=" + (c.InpUseMMModule?"true":"false") + "|";
   s += "InpUseSMCModule=" + (c.InpUseSMCModule?"true":"false") + "|";
   s += "InpUsePVEMAModule=" + (c.InpUsePVEMAModule?"true":"false") + "|";
   s += "InpUseENGModule=" + (c.InpUseENGModule?"true":"false") + "|";
   s += "InpUsePINModule=" + (c.InpUsePINModule?"true":"false") + "|";
   s += "InpUseBRKModule=" + (c.InpUseBRKModule?"true":"false") + "|";
   s += "InpUseLQModule=" + (c.InpUseLQModule?"true":"false") + "|";
   s += "InpUsePVTModule=" + (c.InpUsePVTModule?"true":"false") + "|";
   s += "InpTimeframe=" + IntegerToString((long)c.InpTimeframe) + "|";
   s += "InpFastEMA=" + IntegerToString((long)c.InpFastEMA) + "|";
   s += "InpSlowEMA=" + IntegerToString((long)c.InpSlowEMA) + "|";
   s += "InpSLLookbackBars=" + IntegerToString((long)c.InpSLLookbackBars) + "|";
   s += "InpSLBufferGia=" + DoubleToString(c.InpSLBufferGia,10) + "|";
   s += "InpEMAVaoSauRetest=" + (c.InpEMAVaoSauRetest?"true":"false") + "|";
   s += "InpEMAMucRetest=" + IntegerToString((long)c.InpEMAMucRetest) + "|";
   s += "InpEMAKhoangDiXaToiThieuATR=" + DoubleToString(c.InpEMAKhoangDiXaToiThieuATR,10) + "|";
   s += "InpEMADungSaiRetestGia=" + DoubleToString(c.InpEMADungSaiRetestGia,10) + "|";
   s += "InpEMASoNenChoToiThieu=" + IntegerToString((long)c.InpEMASoNenChoToiThieu) + "|";
   s += "InpEMAHetHanRetestBars=" + IntegerToString((long)c.InpEMAHetHanRetestBars) + "|";
   s += "InpEMADungLocM5=" + (c.InpEMADungLocM5?"true":"false") + "|";
   s += "InpEMAKhungLoc=" + IntegerToString((long)c.InpEMAKhungLoc) + "|";
   s += "InpEMANhanhLoc=" + IntegerToString((long)c.InpEMANhanhLoc) + "|";
   s += "InpEMAChamLoc=" + IntegerToString((long)c.InpEMAChamLoc) + "|";
   s += "InpUseWaveFilter=" + (c.InpUseWaveFilter?"true":"false") + "|";
   s += "InpWaveBars=" + IntegerToString((long)c.InpWaveBars) + "|";
   s += "InpATRPeriod=" + IntegerToString((long)c.InpATRPeriod) + "|";
   s += "InpMinWaveATR=" + DoubleToString(c.InpMinWaveATR,10) + "|";
   s += "InpMinMoveATR=" + DoubleToString(c.InpMinMoveATR,10) + "|";
   s += "InpRecentCrossBars=" + IntegerToString((long)c.InpRecentCrossBars) + "|";
   s += "InpMinDirectionEfficiency=" + DoubleToString(c.InpMinDirectionEfficiency,10) + "|";
   s += "InpRequireOuterHalf=" + (c.InpRequireOuterHalf?"true":"false") + "|";
   s += "InpMaxOpposingSlowSlopeATR=" + DoubleToString(c.InpMaxOpposingSlowSlopeATR,10) + "|";
   s += "InpICTEntryTF=" + IntegerToString((long)c.InpICTEntryTF) + "|";
   s += "InpICTBiasTF=" + IntegerToString((long)c.InpICTBiasTF) + "|";
   s += "InpICTUse2022=" + (c.InpICTUse2022?"true":"false") + "|";
   s += "InpICTUseOTE=" + (c.InpICTUseOTE?"true":"false") + "|";
   s += "InpICTUseUnicorn=" + (c.InpICTUseUnicorn?"true":"false") + "|";
   s += "InpICTUseInversion=" + (c.InpICTUseInversion?"true":"false") + "|";
   s += "InpICTPriority=" + IntegerToString((long)c.InpICTPriority) + "|";
   s += "InpICTLookback=" + IntegerToString((long)c.InpICTLookback) + "|";
   s += "InpICTPivotBars=" + IntegerToString((long)c.InpICTPivotBars) + "|";
   s += "InpICTSetupExpiryBars=" + IntegerToString((long)c.InpICTSetupExpiryBars) + "|";
   s += "InpICTMinFVG_ATR=" + DoubleToString(c.InpICTMinFVG_ATR,10) + "|";
   s += "InpICTDisplacementATR=" + DoubleToString(c.InpICTDisplacementATR,10) + "|";
   s += "InpICTMinImpulseATR=" + DoubleToString(c.InpICTMinImpulseATR,10) + "|";
   s += "InpICTOTEHigh=" + DoubleToString(c.InpICTOTEHigh,10) + "|";
   s += "InpICTOTELow=" + DoubleToString(c.InpICTOTELow,10) + "|";
   s += "InpICTRR=" + DoubleToString(c.InpICTRR,10) + "|";
   s += "InpICTSLBufferGia=" + DoubleToString(c.InpICTSLBufferGia,10) + "|";
   s += "InpMMEntryTF=" + IntegerToString((long)c.InpMMEntryTF) + "|";
   s += "InpMMBiasTF=" + IntegerToString((long)c.InpMMBiasTF) + "|";
   s += "InpMMLookback=" + IntegerToString((long)c.InpMMLookback) + "|";
   s += "InpMMPivotBars=" + IntegerToString((long)c.InpMMPivotBars) + "|";
   s += "InpMMRangeBars=" + IntegerToString((long)c.InpMMRangeBars) + "|";
   s += "InpMMPremiumLevel=" + DoubleToString(c.InpMMPremiumLevel,10) + "|";
   s += "InpMMDiscountLevel=" + DoubleToString(c.InpMMDiscountLevel,10) + "|";
   s += "InpMMDisplacementATR=" + DoubleToString(c.InpMMDisplacementATR,10) + "|";
   s += "InpMMMinFVG_ATR=" + DoubleToString(c.InpMMMinFVG_ATR,10) + "|";
   s += "InpMMMaxConsolidationATR=" + DoubleToString(c.InpMMMaxConsolidationATR,10) + "|";
   s += "InpMMConsolidationBars=" + IntegerToString((long)c.InpMMConsolidationBars) + "|";
   s += "InpMMModelExpiryBars=" + IntegerToString((long)c.InpMMModelExpiryBars) + "|";
   s += "InpMMLegSetupExpiryBars=" + IntegerToString((long)c.InpMMLegSetupExpiryBars) + "|";
   s += "InpMMLowRiskExpiryBars=" + IntegerToString((long)c.InpMMLowRiskExpiryBars) + "|";
   s += "InpMMUseLowRisk=" + (c.InpMMUseLowRisk?"true":"false") + "|";
   s += "InpMMUseLeg1=" + (c.InpMMUseLeg1?"true":"false") + "|";
   s += "InpMMUseLeg2=" + (c.InpMMUseLeg2?"true":"false") + "|";
   s += "InpMMRR=" + DoubleToString(c.InpMMRR,10) + "|";
   s += "InpMMSLBufferGia=" + DoubleToString(c.InpMMSLBufferGia,10) + "|";
   s += "InpSMCEntryTF=" + IntegerToString((long)c.InpSMCEntryTF) + "|";
   s += "InpSMCBiasTF=" + IntegerToString((long)c.InpSMCBiasTF) + "|";
   s += "InpSMCLookback=" + IntegerToString((long)c.InpSMCLookback) + "|";
   s += "InpSMCPivotBars=" + IntegerToString((long)c.InpSMCPivotBars) + "|";
   s += "InpSMCSetupExpiryBars=" + IntegerToString((long)c.InpSMCSetupExpiryBars) + "|";
   s += "InpSMCDisplacementATR=" + DoubleToString(c.InpSMCDisplacementATR,10) + "|";
   s += "InpSMCBatBuocFVG=" + (c.InpSMCBatBuocFVG?"true":"false") + "|";
   s += "InpSMCUuTienVungFVG=" + (c.InpSMCUuTienVungFVG?"true":"false") + "|";
   s += "InpSMCMinFVGATR=" + DoubleToString(c.InpSMCMinFVGATR,10) + "|";
   s += "InpSMCDungLocEMAH1=" + (c.InpSMCDungLocEMAH1?"true":"false") + "|";
   s += "InpSMCEMANhanhH1=" + IntegerToString((long)c.InpSMCEMANhanhH1) + "|";
   s += "InpSMCEMAChamH1=" + IntegerToString((long)c.InpSMCEMAChamH1) + "|";
   s += "InpSMCYeuCauThuTuEMAH1=" + (c.InpSMCYeuCauThuTuEMAH1?"true":"false") + "|";
   s += "InpSMCDungLocEMAM5=" + (c.InpSMCDungLocEMAM5?"true":"false") + "|";
   s += "InpSMCEMANhanhM5=" + IntegerToString((long)c.InpSMCEMANhanhM5) + "|";
   s += "InpSMCEMAChamM5=" + IntegerToString((long)c.InpSMCEMAChamM5) + "|";
   s += "InpSMCYeuCauDoDocEMAM5=" + (c.InpSMCYeuCauDoDocEMAM5?"true":"false") + "|";
   s += "InpSMCSoNenDoDocEMA=" + IntegerToString((long)c.InpSMCSoNenDoDocEMA) + "|";
   s += "InpSMCDungLocRSI=" + (c.InpSMCDungLocRSI?"true":"false") + "|";
   s += "InpSMCRSIPeriod=" + IntegerToString((long)c.InpSMCRSIPeriod) + "|";
   s += "InpSMCRSIMuaToiThieu=" + DoubleToString(c.InpSMCRSIMuaToiThieu,10) + "|";
   s += "InpSMCRSIBanToiDa=" + DoubleToString(c.InpSMCRSIBanToiDa,10) + "|";
   s += "InpSMCRR=" + DoubleToString(c.InpSMCRR,10) + "|";
   s += "InpSMCSLBufferGia=" + DoubleToString(c.InpSMCSLBufferGia,10) + "|";
   s += "InpSMCBatLop2=" + (c.InpSMCBatLop2?"true":"false") + "|";
   s += "InpSMCLop2PhanTramDenSL=" + DoubleToString(c.InpSMCLop2PhanTramDenSL,10) + "|";
   s += "InpPVHuongGiaoDich=" + IntegerToString((long)c.InpPVHuongGiaoDich) + "|";
   s += "InpPVCachKetHop=" + IntegerToString((long)c.InpPVCachKetHop) + "|";
   s += "InpPVSoNenTimSL=" + IntegerToString((long)c.InpPVSoNenTimSL) + "|";
   s += "InpPVDemSLGia=" + DoubleToString(c.InpPVDemSLGia,10) + "|";
   s += "InpPVBEKhiLoiGia=" + DoubleToString(c.InpPVBEKhiLoiGia,10) + "|";
   s += "InpPVTP2R=" + DoubleToString(c.InpPVTP2R,10) + "|";
   s += "InpPVRRToiThieu=" + DoubleToString(c.InpPVRRToiThieu,10) + "|";
   s += "InpPVThuaLienTiepToiDa=" + IntegerToString((long)c.InpPVThuaLienTiepToiDa) + "|";
   s += "InpPVKhungXuHuong=" + IntegerToString((long)c.InpPVKhungXuHuong) + "|";
   s += "InpPVKhungVaoLenh=" + IntegerToString((long)c.InpPVKhungVaoLenh) + "|";
   s += "InpPVEMANhanhXuHuong=" + IntegerToString((long)c.InpPVEMANhanhXuHuong) + "|";
   s += "InpPVEMAChamXuHuong=" + IntegerToString((long)c.InpPVEMAChamXuHuong) + "|";
   s += "InpPVEMANhanhVaoLenh=" + IntegerToString((long)c.InpPVEMANhanhVaoLenh) + "|";
   s += "InpPVEMAChamVaoLenh=" + IntegerToString((long)c.InpPVEMAChamVaoLenh) + "|";
   s += "InpPVChuKyATR=" + IntegerToString((long)c.InpPVChuKyATR) + "|";
   s += "InpPVChuKyADX=" + IntegerToString((long)c.InpPVChuKyADX) + "|";
   s += "InpPVADXToiThieu=" + DoubleToString(c.InpPVADXToiThieu,10) + "|";
   s += "InpPVSoNenKiemTraNhipHoi=" + IntegerToString((long)c.InpPVSoNenKiemTraNhipHoi) + "|";
   s += "InpPVDungSaiHoiATR=" + DoubleToString(c.InpPVDungSaiHoiATR,10) + "|";
   s += "InpPVThanNenToiThieu=" + DoubleToString(c.InpPVThanNenToiThieu,10) + "|";
   s += "InpPVDoDaiNenToiDaATR=" + DoubleToString(c.InpPVDoDaiNenToiDaATR,10) + "|";
   s += "InpPVMauPriceAction=" + IntegerToString((long)c.InpPVMauPriceAction) + "|";
   s += "InpPVSoMauPAToiThieu=" + IntegerToString((long)c.InpPVSoMauPAToiThieu) + "|";
   s += "InpPVKhungNhanChim=" + IntegerToString((long)c.InpPVKhungNhanChim) + "|";
   s += "InpPVATRNhanChim=" + IntegerToString((long)c.InpPVATRNhanChim) + "|";
   s += "InpPVNhanChimMinATR=" + DoubleToString(c.InpPVNhanChimMinATR,10) + "|";
   s += "InpPVNhanChimMaxATR=" + DoubleToString(c.InpPVNhanChimMaxATR,10) + "|";
   s += "InpPVThanNhanChimSoVoiThanTruoc=" + DoubleToString(c.InpPVThanNhanChimSoVoiThanTruoc,10) + "|";
   s += "InpPVDongCuaManhNhanChim=" + DoubleToString(c.InpPVDongCuaManhNhanChim,10) + "|";
   s += "InpPVKhungPinBar=" + IntegerToString((long)c.InpPVKhungPinBar) + "|";
   s += "InpPVATRPinBar=" + IntegerToString((long)c.InpPVATRPinBar) + "|";
   s += "InpPVPinMinATR=" + DoubleToString(c.InpPVPinMinATR,10) + "|";
   s += "InpPVPinMaxATR=" + DoubleToString(c.InpPVPinMaxATR,10) + "|";
   s += "InpPVRauChinhTrenThan=" + DoubleToString(c.InpPVRauChinhTrenThan,10) + "|";
   s += "InpPVRauDoiDienTrenThan=" + DoubleToString(c.InpPVRauDoiDienTrenThan,10) + "|";
   s += "InpPVDongCuaPinTrongBien=" + DoubleToString(c.InpPVDongCuaPinTrongBien,10) + "|";
   s += "InpPVPinQuetSoNen=" + IntegerToString((long)c.InpPVPinQuetSoNen) + "|";
   s += "InpPVKhungBreakout=" + IntegerToString((long)c.InpPVKhungBreakout) + "|";
   s += "InpPVThanBreakoutToiThieu=" + DoubleToString(c.InpPVThanBreakoutToiThieu,10) + "|";
   s += "InpPVSoNenVungBreakout=" + IntegerToString((long)c.InpPVSoNenVungBreakout) + "|";
   s += "InpPVDemBreakoutGia=" + DoubleToString(c.InpPVDemBreakoutGia,10) + "|";
   s += "InpPVChoRetest=" + (c.InpPVChoRetest?"true":"false") + "|";
   s += "InpPVDungSaiRetestGia=" + DoubleToString(c.InpPVDungSaiRetestGia,10) + "|";
   s += "InpPVKhungQuetThanhKhoan=" + IntegerToString((long)c.InpPVKhungQuetThanhKhoan) + "|";
   s += "InpPVSoNenThanhKhoan=" + IntegerToString((long)c.InpPVSoNenThanhKhoan) + "|";
   s += "InpPVDoXuyenToiThieuGia=" + DoubleToString(c.InpPVDoXuyenToiThieuGia,10) + "|";
   s += "InpPVDoXuyenToiDaGia=" + DoubleToString(c.InpPVDoXuyenToiDaGia,10) + "|";
   s += "InpPVDongLaiVaoVungGia=" + DoubleToString(c.InpPVDongLaiVaoVungGia,10) + "|";
   s += "InpPVRauQuetTrenThan=" + DoubleToString(c.InpPVRauQuetTrenThan,10) + "|";
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
   s += "InpUseEMASessionFilter=" + (c.InpUseEMASessionFilter?"true":"false") + "|";
   s += "InpUseICTSessionFilter=" + (c.InpUseICTSessionFilter?"true":"false") + "|";
   s += "InpUseMMSessionFilter=" + (c.InpUseMMSessionFilter?"true":"false") + "|";
   s += "InpUseSMCSessionFilter=" + (c.InpUseSMCSessionFilter?"true":"false") + "|";
   s += "InpEMAOutsideSessionRR=" + DoubleToString(c.InpEMAOutsideSessionRR,10) + "|";
   s += "InpUseAsia=" + (c.InpUseAsia?"true":"false") + "|";
   s += "InpAsiaStart=" + IntegerToString((long)c.InpAsiaStart) + "|";
   s += "InpAsiaEnd=" + IntegerToString((long)c.InpAsiaEnd) + "|";
   s += "InpAsiaRR=" + DoubleToString(c.InpAsiaRR,10) + "|";
   s += "InpUseEurope=" + (c.InpUseEurope?"true":"false") + "|";
   s += "InpEuropeStart=" + IntegerToString((long)c.InpEuropeStart) + "|";
   s += "InpEuropeEnd=" + IntegerToString((long)c.InpEuropeEnd) + "|";
   s += "InpEuropeRR=" + DoubleToString(c.InpEuropeRR,10) + "|";
   s += "InpUseAmerica=" + (c.InpUseAmerica?"true":"false") + "|";
   s += "InpAmericaStart=" + IntegerToString((long)c.InpAmericaStart) + "|";
   s += "InpAmericaEnd=" + IntegerToString((long)c.InpAmericaEnd) + "|";
   s += "InpAmericaRR=" + DoubleToString(c.InpAmericaRR,10) + "|";
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
   FileWrite(h,"InpUseEMAModule","Bật phương pháp EMA đa khung M5 lọc, M1 vào","bool","true","NO");
   FileWrite(h,"InpUseICTModule","Bật phương pháp ICT","bool","true","NO");
   FileWrite(h,"InpUseMMModule","Bật phương pháp Market Maker","bool","true","NO");
   FileWrite(h,"InpUseSMCModule","Bật phương pháp SMC M5, lọc xu hướng H1","bool","true","NO");
   FileWrite(h,"InpUsePVEMAModule","Bật EMA 95/150 + EMA 26/29","bool","true","NO");
   FileWrite(h,"InpUseENGModule","Bật nến nhấn chìm ENG","bool","true","NO");
   FileWrite(h,"InpUsePINModule","Bật Pin Bar PIN","bool","true","NO");
   FileWrite(h,"InpUseBRKModule","Bật phá đỉnh/đáy BRK","bool","true","NO");
   FileWrite(h,"InpUseLQModule","Bật quét thanh khoản LQ","bool","true","NO");
   FileWrite(h,"InpUsePVTModule","Bật Pivot PVT","bool","true","NO");
   FileWrite(h,"InpTimeframe","Khung thời gian EMA","ENUM_TIMEFRAMES","PERIOD_M1","YES");
   FileWrite(h,"InpFastEMA","Chu kỳ EMA nhanh tìm điểm vào trên M1","int","7","YES");
   FileWrite(h,"InpSlowEMA","Chu kỳ EMA chậm tìm điểm vào trên M1","int","34","YES");
   FileWrite(h,"InpSLLookbackBars","Số nến đã đóng dùng tìm đỉnh/đáy SL","int","5","YES");
   FileWrite(h,"InpSLBufferGia","Khoảng đệm SL qua đỉnh/đáy (giá)","double","0.0","YES");
   FileWrite(h,"InpEMAVaoSauRetest","Chờ giá retest EMA sau giao cắt rồi mới vào","bool","true","YES");
   FileWrite(h,"InpEMAMucRetest","Đường/vùng EMA dùng làm điểm retest","ENUM_MUC_RETEST_EMA","RETEST_EMA_NHANH","YES");
   FileWrite(h,"InpEMAKhoangDiXaToiThieuATR","Giá phải chạy xa EMA tối thiểu theo ATR trước khi hồi","double","0.35","YES");
   FileWrite(h,"InpEMADungSaiRetestGia","Dung sai chạm đường EMA (giá)","double","0.20","YES");
   FileWrite(h,"InpEMASoNenChoToiThieu","Số nến tối thiểu sau giao cắt mới nhận retest, 0=chạm là vào","int","0","YES");
   FileWrite(h,"InpEMAHetHanRetestBars","Hủy thiết lập nếu chưa retest sau số nến này","int","24","YES");
   FileWrite(h,"InpEMADungLocM5","Dùng EMA 34/89 M5 để lọc hướng lệnh M1","bool","true","YES");
   FileWrite(h,"InpEMAKhungLoc","Khung EMA lọc xu hướng","ENUM_TIMEFRAMES","PERIOD_M5","YES");
   FileWrite(h,"InpEMANhanhLoc","Chu kỳ EMA nhanh lọc xu hướng M5","int","34","YES");
   FileWrite(h,"InpEMAChamLoc","Chu kỳ EMA chậm lọc xu hướng M5","int","89","YES");
   FileWrite(h,"InpUseWaveFilter","Bật bộ lọc sóng yếu","bool","true","YES");
   FileWrite(h,"InpWaveBars","Số nến dùng đo độ lớn sóng","int","12","YES");
   FileWrite(h,"InpATRPeriod","Chu kỳ ATR dùng chung","int","14","YES");
   FileWrite(h,"InpMinWaveATR","Biên độ sóng tối thiểu theo ATR","double","2.0","YES");
   FileWrite(h,"InpMinMoveATR","Độ dịch chuyển tối thiểu theo ATR","double","0.65","YES");
   FileWrite(h,"InpRecentCrossBars","Bỏ qua nếu vừa giao cắt trong N nến, 0=tắt","int","8","YES");
   FileWrite(h,"InpMinDirectionEfficiency","Hiệu suất hướng đi tối thiểu, 0=tắt","double","0.22","YES");
   FileWrite(h,"InpRequireOuterHalf","Chỉ vào khi điểm cắt nằm đúng nửa ngoài biên giá","bool","true","YES");
   FileWrite(h,"InpMaxOpposingSlowSlopeATR","Độ dốc EMA chậm ngược hướng tối đa theo ATR","double","0.08","YES");
   FileWrite(h,"InpICTEntryTF","Khung tìm Sweep/MSS/FVG","ENUM_TIMEFRAMES","PERIOD_M5","YES");
   FileWrite(h,"InpICTBiasTF","Khung xác định xu hướng chính","ENUM_TIMEFRAMES","PERIOD_M15","YES");
   FileWrite(h,"InpICTUse2022","Bật mô hình ICT 2022","bool","true","YES");
   FileWrite(h,"InpICTUseOTE","Bật vùng vào lệnh OTE","bool","true","YES");
   FileWrite(h,"InpICTUseUnicorn","Bật mô hình Unicorn","bool","true","YES");
   FileWrite(h,"InpICTUseInversion","Bật mô hình Inversion","bool","true","YES");
   FileWrite(h,"InpICTPriority","Mô hình được ưu tiên","ENUM_ICT_PRIORITY","ICT_PRIORITY_UNICORN","YES");
   FileWrite(h,"InpICTLookback","Số nến tìm cấu trúc ICT","int","80","YES");
   FileWrite(h,"InpICTPivotBars","Số nến mỗi bên xác nhận Swing","int","2","YES");
   FileWrite(h,"InpICTSetupExpiryBars","Số nến chờ trước khi hủy thiết lập","int","12","YES");
   FileWrite(h,"InpICTMinFVG_ATR","Độ rộng FVG tối thiểu theo ATR","double","0.05","YES");
   FileWrite(h,"InpICTDisplacementATR","Thân nến MSS tối thiểu theo ATR","double","0.60","YES");
   FileWrite(h,"InpICTMinImpulseATR","Biên độ nhịp ICT tối thiểu theo ATR","double","1.0","YES");
   FileWrite(h,"InpICTOTEHigh","Biên trên vùng OTE","double","0.62","YES");
   FileWrite(h,"InpICTOTELow","Biên dưới vùng OTE","double","0.79","YES");
   FileWrite(h,"InpICTSLBufferGia","Khoảng đệm SL ICT (giá)","double","0.02","YES");
   FileWrite(h,"InpMMEntryTF","Khung tìm điểm vào Market Maker","ENUM_TIMEFRAMES","PERIOD_M15","YES");
   FileWrite(h,"InpMMBiasTF","Khung xác định vùng Premium/Discount","ENUM_TIMEFRAMES","PERIOD_H1","YES");
   FileWrite(h,"InpMMLookback","Số nến tìm cấu trúc Market Maker","int","96","YES");
   FileWrite(h,"InpMMPivotBars","Số nến mỗi bên xác nhận Swing","int","2","YES");
   FileWrite(h,"InpMMRangeBars","Số nến tạo Dealing Range khung cao","int","36","YES");
   FileWrite(h,"InpMMPremiumLevel","Mức Premium để tìm lệnh Sell","double","0.62","YES");
   FileWrite(h,"InpMMDiscountLevel","Mức Discount để tìm lệnh Buy","double","0.38","YES");
   FileWrite(h,"InpMMDisplacementATR","Nến dịch chuyển tối thiểu theo ATR","double","0.70","YES");
   FileWrite(h,"InpMMMinFVG_ATR","Độ rộng FVG tối thiểu theo ATR","double","0.03","YES");
   FileWrite(h,"InpMMMaxConsolidationATR","Biên tích lũy tối đa theo ATR","double","3.0","YES");
   FileWrite(h,"InpMMConsolidationBars","Số nến xác định vùng tích lũy","int","6","YES");
   FileWrite(h,"InpMMModelExpiryBars","Số nến tối đa duy trì một mô hình","int","48","YES");
   FileWrite(h,"InpMMLegSetupExpiryBars","Số nến chờ retest của nhịp 1/2","int","10","YES");
   FileWrite(h,"InpMMLowRiskExpiryBars","Số nến chờ retest Low-risk","int","14","YES");
   FileWrite(h,"InpMMUseLowRisk","Bật điểm vào Low-risk","bool","true","YES");
   FileWrite(h,"InpMMUseLeg1","Bật điểm vào nhịp thứ nhất","bool","true","YES");
   FileWrite(h,"InpMMUseLeg2","Bật điểm vào nhịp thứ hai","bool","true","YES");
   FileWrite(h,"InpMMSLBufferGia","Khoảng đệm SL Market Maker (giá)","double","0.03","YES");
   FileWrite(h,"InpSMCEntryTF","Khung tìm Sweep/BOS/CHoCH và vùng vào SMC","ENUM_TIMEFRAMES","PERIOD_M5","YES");
   FileWrite(h,"InpSMCBiasTF","Khung lọc xu hướng chính của SMC","ENUM_TIMEFRAMES","PERIOD_H1","YES");
   FileWrite(h,"InpSMCLookback","Số nến tìm cấu trúc SMC","int","80","YES");
   FileWrite(h,"InpSMCPivotBars","Số nến mỗi bên xác nhận Swing SMC","int","2","YES");
   FileWrite(h,"InpSMCSetupExpiryBars","Số nến chờ giá hồi trước khi hủy thiết lập","int","12","YES");
   FileWrite(h,"InpSMCDisplacementATR","Thân nến phá cấu trúc tối thiểu theo ATR","double","0.60","YES");
   FileWrite(h,"InpSMCBatBuocFVG","Chỉ nhận thiết lập có FVG","bool","false","YES");
   FileWrite(h,"InpSMCUuTienVungFVG","Ưu tiên vùng FVG, không có thì dùng Order Block","bool","true","YES");
   FileWrite(h,"InpSMCMinFVGATR","Độ rộng FVG tối thiểu theo ATR","double","0.03","YES");
   FileWrite(h,"InpSMCDungLocEMAH1","Lọc H1 bằng vị trí giá so với hai EMA","bool","true","YES");
   FileWrite(h,"InpSMCEMANhanhH1","Chu kỳ EMA nhanh lọc xu hướng H1","int","50","YES");
   FileWrite(h,"InpSMCEMAChamH1","Chu kỳ EMA chậm lọc xu hướng H1","int","200","YES");
   FileWrite(h,"InpSMCYeuCauThuTuEMAH1","Bắt buộc EMA nhanh/chậm H1 xếp đúng thứ tự","bool","false","YES");
   FileWrite(h,"InpSMCDungLocEMAM5","Lọc điểm vào theo EMA M5","bool","true","YES");
   FileWrite(h,"InpSMCEMANhanhM5","Chu kỳ EMA nhanh lọc điểm vào M5","int","20","YES");
   FileWrite(h,"InpSMCEMAChamM5","Chu kỳ EMA chậm lọc điểm vào M5","int","50","YES");
   FileWrite(h,"InpSMCYeuCauDoDocEMAM5","Bắt buộc hai EMA M5 dốc cùng hướng","bool","true","YES");
   FileWrite(h,"InpSMCSoNenDoDocEMA","Số nến dùng đo độ dốc EMA M5","int","3","YES");
   FileWrite(h,"InpSMCDungLocRSI","Lọc động lượng SMC bằng RSI M5","bool","true","YES");
   FileWrite(h,"InpSMCRSIPeriod","Chu kỳ RSI lọc SMC","int","14","YES");
   FileWrite(h,"InpSMCRSIMuaToiThieu","RSI tối thiểu cho SMC Buy","double","50.0","YES");
   FileWrite(h,"InpSMCRSIBanToiDa","RSI tối đa cho SMC Sell","double","50.0","YES");
   FileWrite(h,"InpSMCSLBufferGia","Khoảng đệm SL ngoài điểm quét (giá)","double","0.02","YES");
   FileWrite(h,"InpPVHuongGiaoDich","Hướng giao dịch","ENUM_PV_HUONG_GIAO_DICH","PV_CA_BUY_VA_SELL","YES");
   FileWrite(h,"InpPVCachKetHop","Cách chạy các phương pháp","ENUM_PV_CACH_KET_HOP","PV_MOI_PP_DOC_LAP","NO");
   FileWrite(h,"InpPVSoNenTimSL","Số nến tìm đỉnh/đáy đặt SL","int","5","YES");
   FileWrite(h,"InpPVDemSLGia","Đệm SL ngoài đỉnh/đáy (giá)","double","1.50","YES");
   FileWrite(h,"InpPVKhungXuHuong","Khung xác định xu hướng","ENUM_TIMEFRAMES","PERIOD_H1","YES");
   FileWrite(h,"InpPVKhungVaoLenh","Khung tìm điểm vào lệnh","ENUM_TIMEFRAMES","PERIOD_M6","YES");
   FileWrite(h,"InpPVEMANhanhXuHuong","EMA nhanh xu hướng","int","95","YES");
   FileWrite(h,"InpPVEMAChamXuHuong","EMA chậm xu hướng","int","150","YES");
   FileWrite(h,"InpPVEMANhanhVaoLenh","EMA nhanh tìm điểm vào lệnh","int","26","YES");
   FileWrite(h,"InpPVEMAChamVaoLenh","EMA chậm tìm điểm vào lệnh","int","29","YES");
   FileWrite(h,"InpPVChuKyATR","Chu kỳ ATR","int","30","YES");
   FileWrite(h,"InpPVChuKyADX","Chu kỳ ADX","int","21","YES");
   FileWrite(h,"InpPVADXToiThieu","ADX tối thiểu xác nhận xu hướng","double","14.0","YES");
   FileWrite(h,"InpPVSoNenKiemTraNhipHoi","Số nến kiểm tra nhịp hồi","int","6","YES");
   FileWrite(h,"InpPVDungSaiHoiATR","Dung sai vùng hồi (hệ số ATR)","double","0.25","YES");
   FileWrite(h,"InpPVThanNenToiThieu","Thân nến tín hiệu tối thiểu (tỷ lệ nến)","double","0.30","YES");
   FileWrite(h,"InpPVDoDaiNenToiDaATR","Độ dài nến tín hiệu tối đa (ATR)","double","1.80","YES");
   FileWrite(h,"InpPVMauPriceAction","Mẫu Price Action sử dụng","ENUM_PV_MAU_PRICE_ACTION","PV_CA_BA_MAU","NO");
   FileWrite(h,"InpPVSoMauPAToiThieu","Số mẫu Price Action tối thiểu đồng thuận","int","1","YES");
   FileWrite(h,"InpPVKhungNhanChim","Khung thời gian nến nhấn chìm","ENUM_TIMEFRAMES","PERIOD_M4","YES");
   FileWrite(h,"InpPVATRNhanChim","Chu kỳ ATR của nến nhấn chìm","int","13","YES");
   FileWrite(h,"InpPVNhanChimMinATR","Biên độ nhấn chìm tối thiểu (ATR)","double","1.10","YES");
   FileWrite(h,"InpPVNhanChimMaxATR","Biên độ nhấn chìm tối đa (ATR)","double","1.90","YES");
   FileWrite(h,"InpPVThanNhanChimSoVoiThanTruoc","Thân nhấn chìm tối thiểu / thân trước","double","1.0","YES");
   FileWrite(h,"InpPVDongCuaManhNhanChim","Vị trí đóng cửa mạnh của nến nhấn chìm","double","0.50","YES");
   FileWrite(h,"InpPVKhungPinBar","Khung thời gian Pin Bar","ENUM_TIMEFRAMES","PERIOD_M4","YES");
   FileWrite(h,"InpPVATRPinBar","Chu kỳ ATR của Pin Bar","int","10","YES");
   FileWrite(h,"InpPVPinMinATR","Biên độ Pin Bar tối thiểu (ATR)","double","1.30","YES");
   FileWrite(h,"InpPVPinMaxATR","Biên độ Pin Bar tối đa (ATR)","double","1.80","YES");
   FileWrite(h,"InpPVRauChinhTrenThan","Râu chính Pin Bar / thân tối thiểu","double","2.20","YES");
   FileWrite(h,"InpPVRauDoiDienTrenThan","Râu đối diện / thân tối đa","double","0.70","YES");
   FileWrite(h,"InpPVDongCuaPinTrongBien","Vị trí đóng cửa tối thiểu trong biên nến","double","0.60","YES");
   FileWrite(h,"InpPVPinQuetSoNen","Pin Bar phải quét đỉnh/đáy số nến này","int","6","YES");
   FileWrite(h,"InpPVKhungBreakout","Khung thời gian Breakout","ENUM_TIMEFRAMES","PERIOD_M4","YES");
   FileWrite(h,"InpPVThanBreakoutToiThieu","Thân nến phá vỡ tối thiểu (tỷ lệ nến)","double","0.50","YES");
   FileWrite(h,"InpPVSoNenVungBreakout","Số nến tìm vùng phá vỡ","int","2","YES");
   FileWrite(h,"InpPVDemBreakoutGia","Đệm phá đỉnh/đáy (giá)","double","1.00","YES");
   FileWrite(h,"InpPVChoRetest","Chờ nến retest sau phá vỡ","bool","false","YES");
   FileWrite(h,"InpPVDungSaiRetestGia","Dung sai vùng retest (giá)","double","0.20","YES");
   FileWrite(h,"InpPVKhungQuetThanhKhoan","Khung tìm cú quét","ENUM_TIMEFRAMES","PERIOD_M3","YES");
   FileWrite(h,"InpPVSoNenThanhKhoan","Số nến tìm đỉnh/đáy thanh khoản","int","6","YES");
   FileWrite(h,"InpPVDoXuyenToiThieuGia","Độ xuyên tối thiểu (giá)","double","0.70","YES");
   FileWrite(h,"InpPVDoXuyenToiDaGia","Độ xuyên tối đa (giá)","double","1.00","YES");
   FileWrite(h,"InpPVDongLaiVaoVungGia","Đóng lại vào vùng tối thiểu (giá)","double","0.45","YES");
   FileWrite(h,"InpPVRauQuetTrenThan","Râu quét / thân nến tối thiểu","double","3.0","YES");
   FileWrite(h,"InpPVKhungTinhPivot","Khung tính PP/R/S từ nến trước","ENUM_TIMEFRAMES","PERIOD_M15","YES");
   FileWrite(h,"InpPVKhungXacNhanPivot","Khung nến xác nhận tại Pivot","ENUM_TIMEFRAMES","PERIOD_M6","YES");
   FileWrite(h,"InpPVBKPVungPivotGia","Bán kính vùng Pivot (giá)","double","1.00","YES");
   FileWrite(h,"InpPVYeuCauNenDungHuong","Yêu cầu nến xác nhận đúng hướng","bool","true","YES");
   FileWrite(h,"InpPVMucPivot","Các mức Pivot sử dụng","ENUM_PV_MUC_PIVOT","PV_CHI_R2_S2","YES");
   FileWrite(h,"InpPVChiTradeTrongGio","Chỉ giao dịch trong khung giờ bên dưới","bool","false","YES");
   FileWrite(h,"InpPVGioBatDau","Giờ bắt đầu giao dịch (giờ máy chủ)","int","7","YES");
   FileWrite(h,"InpPVGioKetThuc","Giờ kết thúc giao dịch (không bao gồm)","int","20","YES");
   FileWrite(h,"InpPVNgayGiaoDich","Ngày giao dịch","ENUM_PV_NGAY_GIAO_DICH","PV_THU_HAI_DEN_THU_SAU","YES");
   FileWrite(h,"InpVolumeMode","Chế độ lot: cố định / % Equity / tiền thật mỗi SL","ENUM_CHE_DO_KHOI_LUONG","LOT_CO_DINH","NO");
   FileWrite(h,"InpGiaTriKhoiLuong","Giá trị lot / % Equity / tiền thật mỗi SL","double","0.02","NO");
   FileWrite(h,"InpSoLenhToiDaMoiNgay","Lệnh tối đa mỗi ngày mỗi tài khoản, 0=tắt","int","0","NO");
   FileWrite(h,"InpDailyLossPct","Ngừng vào mới khi lỗ ngày theo Equity (%), 0=tắt","double","0.0","NO");
   FileWrite(h,"InpMagic","Mã Magic của lệnh tham chiếu trong Tester","ulong","348937","NO");
   FileWrite(h,"InpSpreadToiDaGia","Spread tối đa theo giá, 0=tắt","double","0.50","NO");
   FileWrite(h,"InpUseEMASessionFilter","EMA chỉ vào trong các phiên đã bật","bool","true","NO");
   FileWrite(h,"InpUseICTSessionFilter","ICT chỉ vào trong các phiên đã bật","bool","true","NO");
   FileWrite(h,"InpUseMMSessionFilter","Market Maker chỉ vào trong các phiên đã bật","bool","true","NO");
   FileWrite(h,"InpUseSMCSessionFilter","SMC chỉ vào trong các phiên đã bật","bool","true","NO");
   FileWrite(h,"InpUseAsia","Bật phiên Á","bool","true","NO");
   FileWrite(h,"InpAsiaStart","Giờ bắt đầu phiên Á","int","0","YES");
   FileWrite(h,"InpAsiaEnd","Giờ kết thúc phiên Á","int","8","YES");
   FileWrite(h,"InpUseEurope","Bật phiên Âu","bool","true","NO");
   FileWrite(h,"InpEuropeStart","Giờ bắt đầu phiên Âu","int","8","YES");
   FileWrite(h,"InpEuropeEnd","Giờ kết thúc phiên Âu","int","16","YES");
   FileWrite(h,"InpUseAmerica","Bật phiên Mỹ","bool","true","NO");
   FileWrite(h,"InpAmericaStart","Giờ bắt đầu phiên Mỹ","int","16","YES");
   FileWrite(h,"InpAmericaEnd","Giờ kết thúc phiên Mỹ","int","24","YES");
   FileWrite(h,"InpGhiTinHieuBiLoai","Ghi chi tiết tín hiệu bị loại (tốn dung lượng)","bool","false","NO");
}
struct TradeSetup
{
   bool active;
   bool buy;
   double zoneLow;
   double zoneHigh;
   double stop;
   datetime created;
   int expiryBars;
   string model;
};

struct EMARetestSetup
{
   bool active;
   bool buy;
   bool armed;
   datetime crossTime;
   datetime crossBarTime;
   double crossFast;
   double crossSlow;
   double maxAway;
   double lastPrice;
};

struct MMContext
{
   bool active;
   bool buy;
   int nextLeg;
   datetime reversalTime;
   double invalidation;
};

struct ClosedPositionSummary
{
   bool ok;
   bool buy;
   double entryPrice;
   double exitPrice;
   double initialVolume;
   double netProfit;
   datetime openTime;
   datetime closeTime;
};

struct TradeVisual
{
   bool ok;
   bool buy;
   bool closed;
   ulong positionID;
   double entryPrice;
   double exitPrice;
   double initialSL;
   double initialTP;
   double entryVolume;
   double exitVolume;
   double netProfit;
   datetime openTime;
   datetime closeTime;
   string method;
};

struct SimulatedTradeResult
{
   datetime exitTime;
   double profit;
};

struct ShadowTrade
{
   bool active;
   long id;
   string key;
   string profile;
   string method;
   bool buy;
   datetime signalTime;
   datetime entryTime;
   ENUM_TIMEFRAMES timeframe;
   double entry;
   double initialSL;
   double currentSL;
   double tp1;
   double tp2;
   double initialRisk;
   double initialVolume;
   double remainingVolume;
   double partialVolume;
   double realizedProfit;
   double mfePrice;
   double maePrice;
   bool useTP1;
   bool partialDone;
   bool beAfterTP1;
   bool useTrailing;
   double trailStartR;
   double trailDistanceR;
};




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
   int hFast;
   int hSlow;
   int hATR;
   int hEMABiasFast;
   int hEMABiasSlow;
   int hICTATR;
   int hMMATR;
   int hSMCATR;
   int hSMCBiasFast;
   int hSMCBiasSlow;
   int hSMCEntryFast;
   int hSMCEntrySlow;
   int hSMCRSI;
   int hSLAnalysisATR;
   int hSLAnalysisFast;
   int hSLAnalysisSlow;
   int hPVTrendFast;
   int hPVTrendSlow;
   int hPVEntryFast;
   int hPVEntrySlow;
   int hPVEntryATR;
   int hPVTrendADX;
   int hPVEngATR;
   int hPVPinATR;
   ENUM_TIMEFRAMES g_tf;
   ENUM_TIMEFRAMES g_ictTF;
   ENUM_TIMEFRAMES g_mmTF;
   ENUM_TIMEFRAMES g_smcTF;
   ENUM_TIMEFRAMES g_smcBiasTF;
   ENUM_TIMEFRAMES g_slAnalysisTF;
   datetime g_lastBar;
   datetime g_lastSignalBar;
   datetime g_lastICTBar;
   datetime g_lastMMBar;
   datetime g_lastSMCBar;
   datetime g_lastICTTaken;
   datetime g_lastMMTaken;
   datetime g_lastSMCTaken;
   datetime g_lastICTSetupTime;
   datetime g_lastMMSetupTime;
   datetime g_lastSMCSetupTime;
   datetime g_lastPVEMABar;
   datetime g_lastPVEngBar;
   datetime g_lastPVPinBar;
   datetime g_lastPVBRKBar;
   datetime g_lastPVLQBar;
   datetime g_lastPVPivotBar;
   datetime g_lastPVCombinedSignal;
   double g_previousEMADiff;
   bool g_havePreviousEMADiff;
   string g_status;
   string g_smcSetupDetails;
   bool g_slAnalysisReady;
   TradeSetup g_ictSetup;
   TradeSetup g_mmSetup;
   TradeSetup g_smcSetup;
   EMARetestSetup g_emaRetestSetup;
   MMContext g_mmContext;
public:
   CDHSignalEngine()
   {
      engineID=0; family=0; isBase=false; nextWake=0;
      hFast = INVALID_HANDLE;
      hSlow = INVALID_HANDLE;
      hATR = INVALID_HANDLE;
      hEMABiasFast = INVALID_HANDLE;
      hEMABiasSlow = INVALID_HANDLE;
      hICTATR = INVALID_HANDLE;
      hMMATR = INVALID_HANDLE;
      hSMCATR = INVALID_HANDLE;
      hSMCBiasFast = INVALID_HANDLE;
      hSMCBiasSlow = INVALID_HANDLE;
      hSMCEntryFast = INVALID_HANDLE;
      hSMCEntrySlow = INVALID_HANDLE;
      hSMCRSI = INVALID_HANDLE;
      hSLAnalysisATR = INVALID_HANDLE;
      hSLAnalysisFast = INVALID_HANDLE;
      hSLAnalysisSlow = INVALID_HANDLE;
      hPVTrendFast = INVALID_HANDLE;
      hPVTrendSlow = INVALID_HANDLE;
      hPVEntryFast = INVALID_HANDLE;
      hPVEntrySlow = INVALID_HANDLE;
      hPVEntryATR = INVALID_HANDLE;
      hPVTrendADX = INVALID_HANDLE;
      hPVEngATR = INVALID_HANDLE;
      hPVPinATR = INVALID_HANDLE;
      g_tf = (ENUM_TIMEFRAMES)0;
      g_ictTF = (ENUM_TIMEFRAMES)0;
      g_mmTF = (ENUM_TIMEFRAMES)0;
      g_smcTF = (ENUM_TIMEFRAMES)0;
      g_smcBiasTF = (ENUM_TIMEFRAMES)0;
      g_slAnalysisTF = (ENUM_TIMEFRAMES)0;
      g_lastBar = 0;
      g_lastSignalBar = 0;
      g_lastICTBar = 0;
      g_lastMMBar = 0;
      g_lastSMCBar = 0;
      g_lastICTTaken = 0;
      g_lastMMTaken = 0;
      g_lastSMCTaken = 0;
      g_lastICTSetupTime = 0;
      g_lastMMSetupTime = 0;
      g_lastSMCSetupTime = 0;
      g_lastPVEMABar = 0;
      g_lastPVEngBar = 0;
      g_lastPVPinBar = 0;
      g_lastPVBRKBar = 0;
      g_lastPVLQBar = 0;
      g_lastPVPivotBar = 0;
      g_lastPVCombinedSignal = 0;
      g_previousEMADiff = 0.0;
      g_havePreviousEMADiff = false;
      g_status = "Dang cho EMA giao cat";
      g_smcSetupDetails = "";
      g_slAnalysisReady = false;
      ZeroMemory(g_ictSetup);
      ZeroMemory(g_mmSetup);
      ZeroMemory(g_smcSetup);
      ZeroMemory(g_emaRetestSetup);
      ZeroMemory(g_mmContext);
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

double SessionRR(const int session)
{
   if(session == 1) return cfg.InpAsiaRR;
   if(session == 2) return cfg.InpEuropeRR;
   if(session == 3) return cfg.InpAmericaRR;
   return 0.0;
}

bool ValidSessionHours(const int startHour, const int endHour)
{
   return (startHour >= 0 && startHour < 24 && endHour >= 0 && endHour <= 24 &&
           startHour != endHour);
}

bool SelectNewestMethodPosition(const string method, ulong &ticket)
{
   ticket = 0; return false;
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

bool ReadCurrentEMAValues(double &fastEMA, double &slowEMA)
{
   double a[1], b[1];
   if(CopyBuffer(hFast, 0, 0, 1, a) != 1 ||
      CopyBuffer(hSlow, 0, 0, 1, b) != 1) return false;
   if(!MathIsValidNumber(a[0]) || !MathIsValidNumber(b[0])) return false;
   fastEMA = a[0];
   slowEMA = b[0];
   return fastEMA > 0.0 && slowEMA > 0.0;
}

string ShortTimeframeName(const ENUM_TIMEFRAMES timeframe)
{
   string name = EnumToString(timeframe);
   StringReplace(name, "PERIOD_", "");
   return name;
}

string CoreEMAMethodName()
{
   return StringFormat("EMA%dx%d_%s", cfg.InpFastEMA, cfg.InpSlowEMA,
                       ShortTimeframeName(g_tf));
}

bool ReadEMABias(int &bias, double &fastBias, double &slowBias)
{
   bias = 0;
   fastBias = 0.0;
   slowBias = 0.0;
   if(!cfg.InpEMADungLocM5) return true;
   double fastData[1], slowData[1];
   if(hEMABiasFast == INVALID_HANDLE || hEMABiasSlow == INVALID_HANDLE ||
      CopyBuffer(hEMABiasFast, 0, 1, 1, fastData) != 1 ||
      CopyBuffer(hEMABiasSlow, 0, 1, 1, slowData) != 1 ||
      !MathIsValidNumber(fastData[0]) || !MathIsValidNumber(slowData[0]))
      return false;
   fastBias = fastData[0];
   slowBias = slowData[0];
   if(fastBias > slowBias) bias = 1;
   else if(fastBias < slowBias) bias = -1;
   return true;
}

bool EMABiasAllows(const bool buy, string &details)
{
   if(!cfg.InpEMADungLocM5)
   {
      details = "loc_m5=tat";
      return true;
   }
   int bias = 0;
   double fastBias = 0.0, slowBias = 0.0;
   if(!ReadEMABias(bias, fastBias, slowBias))
   {
      details = "loc_m5=thieu_du_lieu";
      return false;
   }
   details = "loc_tf=" + ShortTimeframeName(cfg.InpEMAKhungLoc) +
             "|ema_loc_nhanh=" + DoubleToString(fastBias, _Digits) +
             "|ema_loc_cham=" + DoubleToString(slowBias, _Digits) +
             "|bias=" + (bias > 0 ? "BUY" : (bias < 0 ? "SELL" : "TRUNG_TINH"));
   return buy ? bias > 0 : bias < 0;
}

bool FindPreCrossExtreme(const bool buy, double &level)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, g_tf, 1, cfg.InpSLLookbackBars, r) < cfg.InpSLLookbackBars)
      return false;
   level = buy ? r[0].low : r[0].high;
   for(int i = 1; i < cfg.InpSLLookbackBars; ++i)
   {
      if(buy && r[i].low < level) level = r[i].low;
      if(!buy && r[i].high > level) level = r[i].high;
   }
   return true;
}

void RecordEMACrossCandidate(const bool buy, const datetime signalTime,
                             const double previousDiff,
                             const double currentDiff,
                             const bool startShadow)
{
   string method = CoreEMAMethodName();
   MqlTick tick;
   double extreme = 0.0;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !FindPreCrossExtreme(buy, extreme))
   {
      ResearchEvent(method, "", "SIGNAL_RAW", "DATA_MISSING",
                    "Không đọc được tick hoặc 5 nến tìm SL", buy ? 1 : -1,
                    signalTime, g_tf, 0.0, 0.0, 0.0, 0.0,
                    StringFormat("diff_truoc=%.8f|diff_hien_tai=%.8f",
                                 previousDiff, currentDiff));
      return;
   }
   double entry = buy ? tick.ask : tick.bid;
   double sl = buy ? PriceDown(extreme - cfg.InpSLBufferGia)
                   : PriceUp(extreme + cfg.InpSLBufferGia);
   string slReason = "";
   if(!NormalizeSLDistance(buy, entry, sl, cfg.InpMaxSLPriceDistance, slReason))
   {
      ResearchEvent(method, "", "SIGNAL_RAW", "REJECTED", slReason,
                    buy ? 1 : -1, signalTime, g_tf, entry, sl);
      return;
   }
   double risk = MathAbs(entry - sl);
   int session = GetSession(TimeCurrent());
   double rr = session > 0 ? SessionRR(session) : cfg.InpEMAOutsideSessionRR;
   double tp = buy ? PriceUp(entry + rr * risk) : PriceDown(entry - rr * risk);
   string details = StringFormat("diff_truoc=%.8f|diff_hien_tai=%.8f|wave_bars=%d|min_wave_atr=%.3f|min_move_atr=%.3f|eff_min=%.3f|outer_half=%s",
                                 previousDiff, currentDiff, cfg.InpWaveBars,
                                 cfg.InpMinWaveATR, cfg.InpMinMoveATR,
                                 cfg.InpMinDirectionEfficiency,
                                 cfg.InpRequireOuterHalf ? "true" : "false");
   ResearchEvent(method, "",
                 cfg.InpEMAVaoSauRetest ? "CROSS_SETUP" : "SIGNAL_RAW",
                 cfg.InpEMAVaoSauRetest ? "WAIT_RETEST" : "DETECTED",
                 cfg.InpEMAVaoSauRetest
                 ? "Hai EMA khung vào lệnh đã cắt; chờ giá chạy xa rồi hồi chạm EMA"
                 : "Hai EMA khung vào lệnh vừa giao cắt trên tick hiện tại",
                 buy ? 1 : -1,
                 signalTime, g_tf, entry, sl, tp, 0.0, details);
   if(startShadow)
      StartShadowProfiles(method, buy, signalTime, g_tf,
                          entry, sl, tp, "EMA_CROSS", details);
}

void ClearEMARetestSetup()
{
   g_emaRetestSetup.active = false;
   g_emaRetestSetup.buy = true;
   g_emaRetestSetup.armed = false;
   g_emaRetestSetup.crossTime = 0;
   g_emaRetestSetup.crossBarTime = 0;
   g_emaRetestSetup.crossFast = 0.0;
   g_emaRetestSetup.crossSlow = 0.0;
   g_emaRetestSetup.maxAway = 0.0;
   g_emaRetestSetup.lastPrice = 0.0;
}

string EMARetestTargetName()
{
   if(cfg.InpEMAMucRetest == RETEST_EMA_CHAM)
      return "EMA" + IntegerToString(cfg.InpSlowEMA);
   if(cfg.InpEMAMucRetest == RETEST_VUNG_HAI_EMA)
      return "VÙNG_EMA" + IntegerToString(cfg.InpFastEMA) + "_" +
             IntegerToString(cfg.InpSlowEMA);
   return "EMA" + IntegerToString(cfg.InpFastEMA);
}

void CreateEMARetestSetup(const bool buy, const datetime crossTime,
                          const datetime crossBarTime,
                          const double fastEMA, const double slowEMA)
{
   ClearEMARetestSetup();
   g_emaRetestSetup.active = true;
   g_emaRetestSetup.buy = buy;
   g_emaRetestSetup.crossTime = crossTime;
   g_emaRetestSetup.crossBarTime = crossBarTime;
   g_emaRetestSetup.crossFast = fastEMA;
   g_emaRetestSetup.crossSlow = slowEMA;
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick))
      g_emaRetestSetup.lastPrice = buy ? tick.bid : tick.ask;
   g_status = CoreEMAMethodName() + ": đã cắt - chờ giá hồi chạm " +
              EMARetestTargetName();
}

bool ReadEMARetestATR(double &atr)
{
   atr = 1.0;
   if(cfg.InpEMAKhoangDiXaToiThieuATR <= 0.0) return true;
   double data[1];
   if(hATR == INVALID_HANDLE || CopyBuffer(hATR, 0, 1, 1, data) != 1 ||
      !MathIsValidNumber(data[0]) || data[0] <= 0.0) return false;
   atr = data[0];
   return true;
}

bool PrepareEMARetestCandidate(const double fastEMA, const double slowEMA,
                               const double atr, double &entry,
                               double &sl, double &tp, string &details)
{
   MqlTick tick;
   double extreme = 0.0;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !FindPreCrossExtreme(g_emaRetestSetup.buy, extreme))
   {
      g_status = "EMA retest: chua du du lieu de tinh Entry/SL";
      return false;
   }
   entry = g_emaRetestSetup.buy ? tick.ask : tick.bid;
   sl = g_emaRetestSetup.buy
        ? PriceDown(extreme - cfg.InpSLBufferGia)
        : PriceUp(extreme + cfg.InpSLBufferGia);
   string slReason = "";
   if(!NormalizeSLDistance(g_emaRetestSetup.buy, entry, sl,
                           cfg.InpMaxSLPriceDistance, slReason))
   {
      g_status = "EMA retest: " + slReason;
      return false;
   }
   double risk = MathAbs(entry - sl);
   int session = GetSession(TimeCurrent());
   double rr = session > 0 ? SessionRR(session) : cfg.InpEMAOutsideSessionRR;
   tp = g_emaRetestSetup.buy ? PriceUp(entry + rr * risk)
                             : PriceDown(entry - rr * risk);
   double awayATR = atr > 0.0 ? g_emaRetestSetup.maxAway / atr : 0.0;
   details = "retest=" + EMARetestTargetName() +
             "|retest_time=" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) +
             "|ema_nhanh=" + DoubleToString(fastEMA, _Digits) +
             "|ema_cham=" + DoubleToString(slowEMA, _Digits) +
             "|max_away_atr=" + DoubleToString(awayATR, 3) +
             "|tolerance_price=" + DoubleToString(cfg.InpEMADungSaiRetestGia, _Digits);
   ResearchEvent(CoreEMAMethodName(), "", "RETEST_TOUCH", "DETECTED",
                 "Giá đã hồi chạm " + EMARetestTargetName(),
                 g_emaRetestSetup.buy ? 1 : -1,
                 g_emaRetestSetup.crossTime, g_tf, entry, sl, tp, 0.0,
                 details);
   return true;
}

void ProcessEMARetestSetup(const double fastEMA, const double slowEMA)
{
   if(!cfg.InpEMAVaoSauRetest || !g_emaRetestSetup.active) return;
   string method = CoreEMAMethodName();
   int secondsPerBar = PeriodSeconds(g_tf);
   if(secondsPerBar > 0 && cfg.InpEMAHetHanRetestBars > 0 &&
      TimeCurrent() >= g_emaRetestSetup.crossBarTime +
                       (long)cfg.InpEMAHetHanRetestBars * secondsPerBar)
   {
      g_status = method + ": thiết lập retest hết hạn";
      ResearchEvent(method, "", "SETUP_STATE", "EXPIRED", g_status,
                    g_emaRetestSetup.buy ? 1 : -1,
                    g_emaRetestSetup.crossTime, g_tf);
      ClearEMARetestSetup();
      return;
   }

   bool trendIntact = g_emaRetestSetup.buy ? fastEMA > slowEMA
                                           : fastEMA < slowEMA;
   if(!trendIntact)
   {
      g_status = method + ": hủy retest vì hai EMA M1 đã cắt ngược lại";
      ResearchEvent(method, "", "SETUP_STATE", "INVALIDATED", g_status,
                    g_emaRetestSetup.buy ? 1 : -1,
                    g_emaRetestSetup.crossTime, g_tf);
      ClearEMARetestSetup();
      return;
   }

   if(cfg.InpEMADungLocM5)
   {
      int bias = 0;
      double biasFast = 0.0, biasSlow = 0.0;
      if(!ReadEMABias(bias, biasFast, biasSlow))
      {
         g_status = method + ": đang chờ dữ liệu lọc " +
                    ShortTimeframeName(cfg.InpEMAKhungLoc);
         return;
      }
      bool biasAllows = g_emaRetestSetup.buy ? bias > 0 : bias < 0;
      if(!biasAllows)
      {
         string details = "ema_loc_nhanh=" + DoubleToString(biasFast, _Digits) +
                          "|ema_loc_cham=" + DoubleToString(biasSlow, _Digits) +
                          "|bias=" + (bias > 0 ? "BUY" :
                                      (bias < 0 ? "SELL" : "TRUNG_TINH"));
         g_status = method + ": hủy retest vì EMA " +
                    IntegerToString(cfg.InpEMANhanhLoc) + "/" +
                    IntegerToString(cfg.InpEMAChamLoc) + " " +
                    ShortTimeframeName(cfg.InpEMAKhungLoc) + " không còn đồng hướng";
         ResearchEvent(method, "", "SETUP_STATE", "INVALIDATED", g_status,
                       g_emaRetestSetup.buy ? 1 : -1,
                       g_emaRetestSetup.crossTime, g_tf, 0.0, 0.0, 0.0,
                       0.0, details);
         ClearEMARetestSetup();
         return;
      }
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
      return;
   double reference = g_emaRetestSetup.buy ? tick.bid : tick.ask;
   double atr = 0.0;
   if(!ReadEMARetestATR(atr))
   {
      g_status = "EMA retest: dang cho du lieu ATR";
      return;
   }
   double away = g_emaRetestSetup.buy ? reference - fastEMA
                                      : fastEMA - reference;
   if(away > g_emaRetestSetup.maxAway) g_emaRetestSetup.maxAway = away;

   if(!g_emaRetestSetup.armed)
   {
      double threshold = cfg.InpEMAKhoangDiXaToiThieuATR * atr;
      bool correctSide = g_emaRetestSetup.buy ? reference > fastEMA
                                              : reference < fastEMA;
      if(correctSide && away >= threshold)
      {
         g_emaRetestSetup.armed = true;
         g_emaRetestSetup.lastPrice = reference;
         g_status = method + ": giá đã chạy xa, chờ hồi chạm " +
                    EMARetestTargetName();
         ResearchEvent(method, "", "RETEST_ARMED", "READY", g_status,
                       g_emaRetestSetup.buy ? 1 : -1,
                       g_emaRetestSetup.crossTime, g_tf, reference,
                       0.0, 0.0, 0.0,
                       "away_atr=" + DoubleToString(away / atr, 3));
         return;
      }
      g_emaRetestSetup.lastPrice = reference;
      return;
   }

   if(secondsPerBar > 0 && cfg.InpEMASoNenChoToiThieu > 0 &&
      TimeCurrent() < g_emaRetestSetup.crossBarTime +
                      (long)cfg.InpEMASoNenChoToiThieu * secondsPerBar)
   {
      g_emaRetestSetup.lastPrice = reference;
      return;
   }

   double tolerance = cfg.InpEMADungSaiRetestGia;
   if((g_emaRetestSetup.buy && reference < slowEMA - tolerance) ||
      (!g_emaRetestSetup.buy && reference > slowEMA + tolerance))
   {
      g_status = method + ": hủy retest vì giá xuyên qua EMA" +
                 IntegerToString(cfg.InpSlowEMA);
      ResearchEvent(method, "", "SETUP_STATE", "INVALIDATED", g_status,
                    g_emaRetestSetup.buy ? 1 : -1,
                    g_emaRetestSetup.crossTime, g_tf, reference);
      ClearEMARetestSetup();
      return;
   }

   double target = cfg.InpEMAMucRetest == RETEST_EMA_CHAM ? slowEMA : fastEMA;
   bool touchedLine = MathAbs(reference - target) <= tolerance;
   bool crossedLine = false;
   if(g_emaRetestSetup.lastPrice > 0.0)
      crossedLine = g_emaRetestSetup.buy
                    ? (g_emaRetestSetup.lastPrice > target + tolerance &&
                       reference <= target + tolerance)
                    : (g_emaRetestSetup.lastPrice < target - tolerance &&
                       reference >= target - tolerance);
   bool insideZone = reference >= MathMin(fastEMA, slowEMA) - tolerance &&
                     reference <= MathMax(fastEMA, slowEMA) + tolerance;
   bool touched = cfg.InpEMAMucRetest == RETEST_VUNG_HAI_EMA
                  ? (insideZone && (touchedLine || crossedLine))
                  : (touchedLine || crossedLine);
   g_emaRetestSetup.lastPrice = reference;
   if(!touched) return;

   double entry = 0.0, sl = 0.0, tp = 0.0;
   string details = "";
   if(!PrepareEMARetestCandidate(fastEMA, slowEMA, atr,
                                 entry, sl, tp, details)) return;
   bool buy = g_emaRetestSetup.buy;
   datetime crossTime = g_emaRetestSetup.crossTime;
   ulong oldTicket = 0, newTicket = 0;
   bool hadPosition = SelectNewestMethodPosition("EMA_CORE", oldTicket);
   EnterOnCross(buy, true);
   bool hasPosition = SelectNewestMethodPosition("EMA_CORE", newTicket);
   bool opened = hasPosition && (!hadPosition || newTicket != oldTicket);
   if(!LAB_RESEARCH_ONLY && (opened || cfg.InpGhiTinHieuBiLoai))
      ResearchEvent(method, "THUC_TE", "LIVE_DECISION",
                    opened ? "OPENED_RETEST" : "REJECTED", g_status,
                    buy ? 1 : -1, crossTime, g_tf,
                    entry, sl, tp, 0.0, details);
   ClearEMARetestSetup();
}

bool WaveIsStrongEnough(const bool buy, const double currentMid,
                        const bool ignoreRecentCross)
{
   if(!cfg.InpUseWaveFilter) return true;
   double atr[1];
   if(CopyBuffer(hATR, 0, 1, 1, atr) != 1 ||
      !MathIsValidNumber(atr[0]) || atr[0] <= 0.0)
   {
      g_status = "Chua co ATR de loc song";
      return false;
   }

   if(!ignoreRecentCross && cfg.InpRecentCrossBars > 0)
   {
      int count = cfg.InpRecentCrossBars + 1;
      double fast[], slow[];
      ArraySetAsSeries(fast, true);
      ArraySetAsSeries(slow, true);
      if(CopyBuffer(hFast, 0, 1, count, fast) != count ||
         CopyBuffer(hSlow, 0, 1, count, slow) != count)
      {
         g_status = "Chua du du lieu kiem tra giao cat cu";
         return false;
      }
      // i=0 tests the last completed bar against the one preceding it.
      for(int i = 0; i < cfg.InpRecentCrossBars; ++i)
      {
         double oldDiff = fast[i + 1] - slow[i + 1];
         double newDiff = fast[i] - slow[i];
         if((oldDiff <= 0.0 && newDiff > 0.0) ||
            (oldDiff >= 0.0 && newDiff < 0.0))
         {
            g_status = "Bo qua: EMA vua cat nhau trong vung di ngang";
            if(cfg.InpGhiTinHieuBiLoai) Print(g_status);
            return false;
         }
      }
   }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, g_tf, 1, cfg.InpWaveBars, r) < cfg.InpWaveBars)
   {
      g_status = "Chua du nen kiem tra do lon song";
      return false;
   }
   double highest = currentMid, lowest = currentMid;
   for(int i = 0; i < cfg.InpWaveBars; ++i)
   {
      highest = MathMax(highest, r[i].high);
      lowest = MathMin(lowest, r[i].low);
   }
   double signedMove = currentMid - r[cfg.InpWaveBars - 1].close;
   double directionalMoveATR = (buy ? signedMove : -signedMove) / atr[0];
   double waveATR = (highest - lowest) / atr[0];
   if(waveATR < cfg.InpMinWaveATR || directionalMoveATR < cfg.InpMinMoveATR)
   {
      g_status = "Bo qua: song gia yeu";
      PrintFormat("Bo qua giao cat: bien do %.2f ATR, dich chuyen dung huong %.2f ATR",
                  waveATR, directionalMoveATR);
      return false;
   }

   // A wide range can still be sideways.  Efficiency compares net progress
   // with the full close-to-close path; low values mean price zigzags heavily.
   double path = MathAbs(currentMid - r[0].close);
   for(int i = 0; i < cfg.InpWaveBars - 1; ++i)
      path += MathAbs(r[i].close - r[i + 1].close);
   double efficiency = path > TickSize() ? MathAbs(signedMove) / path : 0.0;
   if(cfg.InpMinDirectionEfficiency > 0.0 && efficiency < cfg.InpMinDirectionEfficiency)
   {
      g_status = "Bo qua: gia zigzag, thi truong di ngang";
      PrintFormat("Bo qua giao cat: hieu suat huong di chi %.2f", efficiency);
      return false;
   }

   // The cross must occur on the correct half of the recent range.
   double rangeMid = (highest + lowest) * 0.5;
   if(cfg.InpRequireOuterHalf &&
      ((buy && currentMid <= rangeMid) || (!buy && currentMid >= rangeMid)))
   {
      g_status = "Bo qua: vi tri giao cat khong dep trong bien gia";
      return false;
   }

   // Fast EMA must already slope with the trade. Slow EMA may be flattening,
   // but it must not still point materially against the new direction.
   int slopeBars = MathMin(4, cfg.InpWaveBars - 1);
   double fastSlope[], slowSlope[];
   ArraySetAsSeries(fastSlope, true);
   ArraySetAsSeries(slowSlope, true);
   if(CopyBuffer(hFast, 0, 0, slopeBars + 1, fastSlope) != slopeBars + 1 ||
      CopyBuffer(hSlow, 0, 0, slopeBars + 1, slowSlope) != slopeBars + 1)
   {
      g_status = "Chua du du lieu kiem tra do doc EMA";
      return false;
   }
   double fastDirection = buy ? fastSlope[0] - fastSlope[slopeBars]
                              : fastSlope[slopeBars] - fastSlope[0];
   double slowDirection = buy ? slowSlope[0] - slowSlope[slopeBars]
                              : slowSlope[slopeBars] - slowSlope[0];
   if(fastDirection <= 0.0 ||
      slowDirection < -cfg.InpMaxOpposingSlowSlopeATR * atr[0])
   {
      g_status = "Bo qua: do doc EMA chua dong thuan";
      PrintFormat("Bo qua giao cat: doc EMA nhanh %.3f, EMA cham %.3f ATR",
                  fastDirection / atr[0], slowDirection / atr[0]);
      return false;
   }
   return true;
}

bool LoadRatesTF(const ENUM_TIMEFRAMES tf, const int count, MqlRates &r[])
{
   ArraySetAsSeries(r, true);
   return CopyRates(_Symbol, tf, 0, count, r) == count;
}

bool IsPivotHigh(MqlRates &r[], const int total, const int shift, const int wing)
{
   if(shift - wing < 1 || shift + wing >= total) return false;
   for(int k = 1; k <= wing; ++k)
      if(r[shift].high <= r[shift-k].high || r[shift].high < r[shift+k].high)
         return false;
   return true;
}

bool IsPivotLow(MqlRates &r[], const int total, const int shift, const int wing)
{
   if(shift - wing < 1 || shift + wing >= total) return false;
   for(int k = 1; k <= wing; ++k)
      if(r[shift].low >= r[shift-k].low || r[shift].low > r[shift+k].low)
         return false;
   return true;
}

int FindPivot(MqlRates &r[], const int total, const bool high,
              const int firstShift, const int lastShift, const int wing)
{
   int first = MathMax(firstShift, wing + 1);
   int last = MathMin(lastShift, total - wing - 1);
   for(int i = first; i <= last; ++i)
      if(high ? IsPivotHigh(r, total, i, wing) : IsPivotLow(r, total, i, wing))
         return i;
   return -1;
}

int StructuralBias(const ENUM_TIMEFRAMES tf, const int lookback, const int wing)
{
   int need = MathMax(lookback, 24) + wing + 5;
   MqlRates r[];
   if(!LoadRatesTF(tf, need, r)) return 0;
   int h1 = FindPivot(r, need, true, wing + 1, need - wing - 1, wing);
   int l1 = FindPivot(r, need, false, wing + 1, need - wing - 1, wing);
   if(h1 < 0 || l1 < 0) return 0;
   int h2 = FindPivot(r, need, true, h1 + wing + 1, need - wing - 1, wing);
   int l2 = FindPivot(r, need, false, l1 + wing + 1, need - wing - 1, wing);
   if(h2 >= 0 && l2 >= 0)
   {
      if(r[h1].high > r[h2].high && r[l1].low > r[l2].low) return 1;
      if(r[h1].high < r[h2].high && r[l1].low < r[l2].low) return -1;
   }
   double mid = (r[h1].high + r[l1].low) * 0.5;
   if(r[1].close > mid) return 1;
   if(r[1].close < mid) return -1;
   return 0;
}

bool ReadClosedATR(const int handle, double &atr)
{
   double a[1];
   if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, 1, 1, a) != 1 ||
      !MathIsValidNumber(a[0]) || a[0] <= 0.0) return false;
   atr = a[0];
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
                   const datetime sourceSignalTime = 0)
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
   if(!PVFindStructuralSL(signalTF, buy, sl))
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

int PVEMASignal(datetime &signalTime)
{
   signalTime = 0;
   int need = MathMax(12, cfg.InpPVSoNenKiemTraNhipHoi + 4);
   MqlRates r[];
   double ef[], es[], atr[];
   ArraySetAsSeries(r, true);
   ArraySetAsSeries(ef, true);
   ArraySetAsSeries(es, true);
   ArraySetAsSeries(atr, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungVaoLenh, 0, need, r) < need ||
      CopyBuffer(hPVEntryFast, 0, 0, need, ef) < need ||
      CopyBuffer(hPVEntrySlow, 0, 0, need, es) < need ||
      CopyBuffer(hPVEntryATR, 0, 0, need, atr) < need) return 0;
   double trendFast, trendSlow, adx;
   if(!CopyOneBuffer(hPVTrendFast, 0, 1, trendFast) ||
      !CopyOneBuffer(hPVTrendSlow, 0, 1, trendSlow) ||
      !CopyOneBuffer(hPVTrendADX, 0, 1, adx) || atr[1] <= 0.0) return 0;

   signalTime = r[1].time;
   double range = r[1].high - r[1].low;
   double body = MathAbs(r[1].close - r[1].open);
   if(range <= TickSize() || body / range < cfg.InpPVThanNenToiThieu ||
      range > cfg.InpPVDoDaiNenToiDaATR * atr[1] || adx < cfg.InpPVADXToiThieu) return 0;

   bool pullback = false;
   int last = MathMin(need - 1, cfg.InpPVSoNenKiemTraNhipHoi + 1);
   for(int i = 2; i <= last; ++i)
   {
      if(!MathIsValidNumber(atr[i]) || atr[i] <= 0.0) continue;
      double zoneLow = MathMin(ef[i], es[i]) - cfg.InpPVDungSaiHoiATR * atr[i];
      double zoneHigh = MathMax(ef[i], es[i]) + cfg.InpPVDungSaiHoiATR * atr[i];
      if(r[i].low <= zoneHigh && r[i].high >= zoneLow)
      {
         pullback = true;
         break;
      }
   }
   if(!pullback) return 0;
   bool bullish = r[1].close > r[1].open;
   bool bearish = r[1].close < r[1].open;
   bool buy = trendFast > trendSlow && ef[1] > es[1] && bullish &&
              r[1].close > MathMax(ef[1], es[1]);
   bool sell = trendFast < trendSlow && ef[1] < es[1] && bearish &&
               r[1].close < MathMin(ef[1], es[1]);
   if(buy == sell) return 0;
   return buy ? 1 : -1;
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

int PVPinBarSignal(datetime &signalTime)
{
   signalTime = 0;
   int need = cfg.InpPVPinQuetSoNen + 2;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungPinBar, 0, need, r) < need) return 0;
   double atr;
   if(!CopyOneBuffer(hPVPinATR, 0, 1, atr) || atr <= 0.0) return 0;
   signalTime = r[1].time;
   double range = r[1].high - r[1].low;
   double body = MathMax(TickSize(), MathAbs(r[1].close - r[1].open));
   if(range <= TickSize() || range / atr < cfg.InpPVPinMinATR ||
      range / atr > cfg.InpPVPinMaxATR) return 0;
   double upper = r[1].high - MathMax(r[1].open, r[1].close);
   double lower = MathMin(r[1].open, r[1].close) - r[1].low;
   double priorHigh = r[2].high, priorLow = r[2].low;
   for(int i = 3; i < need; ++i)
   {
      priorHigh = MathMax(priorHigh, r[i].high);
      priorLow = MathMin(priorLow, r[i].low);
   }
   bool bull = lower / body >= cfg.InpPVRauChinhTrenThan &&
               upper / body <= cfg.InpPVRauDoiDienTrenThan &&
               (r[1].close - r[1].low) / range >= cfg.InpPVDongCuaPinTrongBien &&
               r[1].low < priorLow;
   bool bear = upper / body >= cfg.InpPVRauChinhTrenThan &&
               lower / body <= cfg.InpPVRauDoiDienTrenThan &&
               (r[1].high - r[1].close) / range >= cfg.InpPVDongCuaPinTrongBien &&
               r[1].high > priorHigh;
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

int PVLiquiditySignal(datetime &signalTime)
{
   signalTime = 0;
   int need = cfg.InpPVSoNenThanhKhoan + 2;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, cfg.InpPVKhungQuetThanhKhoan, 0, need, r) < need) return 0;
   signalTime = r[1].time;
   double priorHigh = r[2].high, priorLow = r[2].low;
   for(int i = 3; i < need; ++i)
   {
      priorHigh = MathMax(priorHigh, r[i].high);
      priorLow = MathMin(priorLow, r[i].low);
   }
   double minPen = MathMin(cfg.InpPVDoXuyenToiThieuGia,
                           cfg.InpPVDoXuyenToiDaGia);
   double maxPen = MathMax(cfg.InpPVDoXuyenToiThieuGia,
                           cfg.InpPVDoXuyenToiDaGia);
   double closeInside = cfg.InpPVDongLaiVaoVungGia;
   double body = MathMax(TickSize(), MathAbs(r[1].close - r[1].open));
   double lowerWick = MathMin(r[1].open, r[1].close) - r[1].low;
   double upperWick = r[1].high - MathMax(r[1].open, r[1].close);
   double downPen = priorLow - r[1].low;
   double upPen = r[1].high - priorHigh;
   bool buy = downPen >= minPen && downPen <= maxPen &&
              r[1].close >= priorLow + closeInside &&
              lowerWick / body >= cfg.InpPVRauQuetTrenThan;
   bool sell = upPen >= minPen && upPen <= maxPen &&
               r[1].close <= priorHigh - closeInside &&
               upperWick / body >= cfg.InpPVRauQuetTrenThan;
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

bool PVUseEngulfing()
{
   return cfg.InpUseENGModule &&
          (cfg.InpPVMauPriceAction == PV_CA_BA_MAU ||
           cfg.InpPVMauPriceAction == PV_CHI_NEN_NHAN_CHIM);
}

bool PVUsePinBar()
{
   return cfg.InpUsePINModule &&
          (cfg.InpPVMauPriceAction == PV_CA_BA_MAU ||
           cfg.InpPVMauPriceAction == PV_CHI_PIN_BAR);
}

bool PVUseBreakout()
{
   return cfg.InpUseBRKModule &&
          (cfg.InpPVMauPriceAction == PV_CA_BA_MAU ||
           cfg.InpPVMauPriceAction == PV_CHI_PHA_DINH_DAY);
}

bool AnyAdditionalModuleEnabled()
{
   return cfg.InpUsePVEMAModule || PVUseEngulfing() || PVUsePinBar() ||
          PVUseBreakout() || cfg.InpUseLQModule || cfg.InpUsePVTModule;
}

int PVPriceActionConsensus(const int eng, const int pin, const int brk)
{
   int buys = 0, sells = 0;
   if(PVUseEngulfing()) { if(eng > 0) buys++; if(eng < 0) sells++; }
   if(PVUsePinBar()) { if(pin > 0) buys++; if(pin < 0) sells++; }
   if(PVUseBreakout()) { if(brk > 0) buys++; if(brk < 0) sells++; }
   if(buys >= cfg.InpPVSoMauPAToiThieu && sells == 0) return 1;
   if(sells >= cfg.InpPVSoMauPAToiThieu && buys == 0) return -1;
   return 0;
}

void ProcessAdditionalSignals()
{
   if(!AnyAdditionalModuleEnabled()) return;

   datetime emaBar = iTime(_Symbol, cfg.InpPVKhungVaoLenh, 0);
   datetime engBar = iTime(_Symbol, cfg.InpPVKhungNhanChim, 0);
   datetime pinBar = iTime(_Symbol, cfg.InpPVKhungPinBar, 0);
   datetime brkBar = iTime(_Symbol, cfg.InpPVKhungBreakout, 0);
   datetime lqBar = iTime(_Symbol, cfg.InpPVKhungQuetThanhKhoan, 0);
   datetime pvtBar = iTime(_Symbol, cfg.InpPVKhungXacNhanPivot, 0);
   bool newEMA = emaBar > 0 && emaBar != g_lastPVEMABar;
   bool newENG = engBar > 0 && engBar != g_lastPVEngBar;
   bool newPIN = pinBar > 0 && pinBar != g_lastPVPinBar;
   bool newBRK = brkBar > 0 && brkBar != g_lastPVBRKBar;
   bool newLQ = lqBar > 0 && lqBar != g_lastPVLQBar;
   bool newPVT = pvtBar > 0 && pvtBar != g_lastPVPivotBar;
   if(newEMA) g_lastPVEMABar = emaBar;
   if(newENG) g_lastPVEngBar = engBar;
   if(newPIN) g_lastPVPinBar = pinBar;
   if(newBRK) g_lastPVBRKBar = brkBar;
   if(newLQ) g_lastPVLQBar = lqBar;
   if(newPVT) g_lastPVPivotBar = pvtBar;
   if(!newEMA && !newENG && !newPIN && !newBRK && !newLQ && !newPVT) return;

   datetime tEMA = 0, tENG = 0, tPIN = 0, tBRK = 0, tLQ = 0, tPVT = 0;
   int ema = cfg.InpUsePVEMAModule ? PVEMASignal(tEMA) : 0;
   int eng = PVUseEngulfing() ? PVEngulfingSignal(tENG) : 0;
   int pin = PVUsePinBar() ? PVPinBarSignal(tPIN) : 0;
   int brk = PVUseBreakout() ? PVBreakoutSignal(tBRK) : 0;
   int lq = cfg.InpUseLQModule ? PVLiquiditySignal(tLQ) : 0;
   int pvt = cfg.InpUsePVTModule ? PVPivotSignal(tPVT) : 0;
   int pa = PVPriceActionConsensus(eng, pin, brk);

   if(cfg.InpGhiTinHieuBiLoai)
   {
      if(newEMA && cfg.InpUsePVEMAModule && ema == 0)
         ResearchEvent("PVEMA", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "EMA 95/150-26/29 chưa đạt đủ xu hướng, ADX, nến hoặc nhịp hồi",
                       0, tEMA, cfg.InpPVKhungVaoLenh);
      if(newENG && PVUseEngulfing() && eng == 0)
         ResearchEvent("ENG", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Nến nhấn chìm chưa đạt ngưỡng", 0, tENG,
                       cfg.InpPVKhungNhanChim);
      if(newPIN && PVUsePinBar() && pin == 0)
         ResearchEvent("PIN", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Pin Bar chưa đạt ngưỡng", 0, tPIN, cfg.InpPVKhungPinBar);
      if(newBRK && PVUseBreakout() && brk == 0)
         ResearchEvent("BRK", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Breakout/retest chưa đạt ngưỡng", 0, tBRK,
                       cfg.InpPVKhungBreakout);
      if(newLQ && cfg.InpUseLQModule && lq == 0)
         ResearchEvent("LQ", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Quét thanh khoản chưa đạt ngưỡng", 0, tLQ,
                       cfg.InpPVKhungQuetThanhKhoan);
      if(newPVT && cfg.InpUsePVTModule && pvt == 0)
         ResearchEvent("PVT", "", "PATTERN_SCAN", "NO_SIGNAL",
                       "Pivot chưa có xác nhận", 0, tPVT,
                       cfg.InpPVKhungXacNhanPivot);
   }

   if(cfg.InpPVCachKetHop == PV_MOI_PP_DOC_LAP)
   {
      if(newEMA && ema != 0)
         EnterPVSignal(ema > 0, "PVEMA", "EMA95x150-26x29", cfg.InpPVKhungVaoLenh, tEMA);
      // Ở chế độ độc lập, mỗi phương pháp được ghi nhận đúng theo tín hiệu
      // của chính nó.  Không để một mẫu Price Action khác chặn kết quả so sánh.
      if(newENG && eng != 0)
         EnterPVSignal(eng > 0, "ENG", "ENG", cfg.InpPVKhungNhanChim, tENG);
      if(newPIN && pin != 0)
         EnterPVSignal(pin > 0, "PIN", "PIN", cfg.InpPVKhungPinBar, tPIN);
      if(newBRK && brk != 0)
         EnterPVSignal(brk > 0, "BRK", "BRK", cfg.InpPVKhungBreakout, tBRK);
      if(newLQ && lq != 0)
         EnterPVSignal(lq > 0, "LQ", "LQ", cfg.InpPVKhungQuetThanhKhoan, tLQ);
      if(newPVT && pvt != 0)
         EnterPVSignal(pvt > 0, "PVT", "PVT", cfg.InpPVKhungXacNhanPivot, tPVT);
      return;
   }

   int direction = 0;
   bool required = false;
   if(cfg.InpUsePVEMAModule)
   {
      if(ema == 0) return;
      direction = ema;
      required = true;
   }
   if(PVUseEngulfing() || PVUsePinBar() || PVUseBreakout())
   {
      if(pa == 0 || (required && pa != direction)) return;
      direction = pa;
      required = true;
   }
   if(cfg.InpUseLQModule)
   {
      if(lq == 0 || (required && lq != direction)) return;
      direction = lq;
      required = true;
   }
   if(cfg.InpUsePVTModule)
   {
      if(pvt == 0 || (required && pvt != direction)) return;
      direction = pvt;
      required = true;
   }
   datetime newest = tEMA;
   if(tENG > newest) newest = tENG;
   if(tPIN > newest) newest = tPIN;
   if(tBRK > newest) newest = tBRK;
   if(tLQ > newest) newest = tLQ;
   if(tPVT > newest) newest = tPVT;
   if(required && direction != 0 && newest > g_lastPVCombinedSignal)
   {
      g_lastPVCombinedSignal = newest;
      EnterPVSignal(direction > 0, "CONSENSUS", "ALL-CONSENSUS",
                    cfg.InpPVKhungVaoLenh, newest);
   }
}

bool IntersectZone(const double aLow, const double aHigh,
                   const double bLow, const double bHigh,
                   double &outLow, double &outHigh)
{
   outLow = MathMax(MathMin(aLow, aHigh), MathMin(bLow, bHigh));
   outHigh = MathMin(MathMax(aLow, aHigh), MathMax(bLow, bHigh));
   return outHigh > outLow + TickSize() * 0.25;
}

bool DetectSweepMSSFVG(MqlRates &r[], const int total, const bool buy,
                       const int wing, const int lookback, const double atr,
                       const double displacementATR, const double minFVGATR,
                       double &zoneLow, double &zoneHigh, double &sweepExtreme,
                       double &breakerLow, double &breakerHigh,
                       double &invLow, double &invHigh, bool &hasInversion,
                       datetime &signalTime)
{
   int maxShift = MathMin(lookback, total - wing - 2);
   for(int sweep = wing + 3; sweep <= maxShift; ++sweep)
   {
      int liq = FindPivot(r, total, !buy, sweep + wing,
                          MathMin(maxShift + wing, total - wing - 1), wing);
      if(liq < 0) continue;
      double level = buy ? r[liq].low : r[liq].high;
      bool swept = buy ? (r[sweep].low < level && r[sweep].close > level)
                       : (r[sweep].high > level && r[sweep].close < level);
      if(!swept) continue;

      double structure = buy ? -1.0e100 : 1.0e100;
      int structureEnd = MathMin(sweep + 16, total - 1);
      for(int j = sweep + 1; j <= structureEnd; ++j)
      {
         if(buy) structure = MathMax(structure, r[j].high);
         else structure = MathMin(structure, r[j].low);
      }
      if(!MathIsValidNumber(structure)) continue;

      int mss = -1;
      for(int j = sweep - 1; j >= 1; --j)
      {
         double body = MathAbs(r[j].close - r[j].open);
         bool broken = buy ? r[j].close > structure : r[j].close < structure;
         if(broken && body >= displacementATR * atr) { mss = j; break; }
      }
      if(mss < 1) continue;

      int fvg = -1;
      for(int k = mss; k >= 1; --k)
      {
         if(k + 2 > sweep) continue;
         double gap = buy ? r[k].low - r[k+2].high
                          : r[k+2].low - r[k].high;
         if(gap >= minFVGATR * atr) { fvg = k; break; }
      }
      if(fvg < 1) continue;
      if(buy) { zoneLow = r[fvg+2].high; zoneHigh = r[fvg].low; }
      else    { zoneLow = r[fvg].high; zoneHigh = r[fvg+2].low; }

      int opposite = -1;
      for(int j = mss + 1; j <= sweep; ++j)
      {
         if((buy && r[j].close < r[j].open) || (!buy && r[j].close > r[j].open))
            { opposite = j; break; }
      }
      if(opposite < 0) opposite = sweep;
      breakerLow = r[opposite].low;
      breakerHigh = r[opposite].high;

      hasInversion = false;
      invLow = invHigh = 0.0;
      for(int k = mss + 1; k + 2 <= sweep; ++k)
      {
         if(buy && r[k+2].low > r[k].high)
         {
            double lo = r[k].high, hi = r[k+2].low;
            if(r[mss].close > hi) { invLow = lo; invHigh = hi; hasInversion = true; break; }
         }
         if(!buy && r[k].low > r[k+2].high)
         {
            double lo = r[k+2].high, hi = r[k].low;
            if(r[mss].close < lo) { invLow = lo; invHigh = hi; hasInversion = true; break; }
         }
      }
      sweepExtreme = buy ? r[sweep].low : r[sweep].high;
      signalTime = r[mss].time;
      return true;
   }
   return false;
}

void ClearSetup(TradeSetup &s)
{
   s.active = false;
   s.buy = true;
   s.zoneLow = s.zoneHigh = s.stop = 0.0;
   s.created = 0;
   s.expiryBars = 0;
   s.model = "";
}

bool SetupExpired(TradeSetup &s, const ENUM_TIMEFRAMES tf)
{
   if(!s.active) return true;
   int sec = PeriodSeconds(tf);
   return sec > 0 && TimeCurrent() > s.created + (long)s.expiryBars * sec;
}

bool BuildICTSetup()
{
   if(!cfg.InpUseICTModule) return false;
   int bias = StructuralBias(cfg.InpICTBiasTF, cfg.InpICTLookback, cfg.InpICTPivotBars);
   if(bias == 0) { g_status = "ICT: chua co bias khung cao"; return false; }
   int need = cfg.InpICTLookback + cfg.InpICTPivotBars * 2 + 12;
   MqlRates r[];
   double atr;
   if(!LoadRatesTF(g_ictTF, need, r) || !ReadClosedATR(hICTATR, atr)) return false;

   bool buy = bias > 0;
   double fvgLow, fvgHigh, sweep, bbLow, bbHigh, invLow, invHigh;
   bool hasInv;
   datetime signalTime;
   if(!DetectSweepMSSFVG(r, need, buy, cfg.InpICTPivotBars, cfg.InpICTLookback, atr,
                         cfg.InpICTDisplacementATR, cfg.InpICTMinFVG_ATR,
                         fvgLow, fvgHigh, sweep, bbLow, bbHigh,
                         invLow, invHigh, hasInv, signalTime))
      return false;
   if(signalTime <= g_lastICTTaken || signalTime <= g_lastICTSetupTime) return false;

   double chosenLow = fvgLow, chosenHigh = fvgHigh;
   string model = "ICT-2022";
   double unicornLow, unicornHigh, oteLow, oteHigh;
   bool unicorn = cfg.InpICTUseUnicorn &&
                  IntersectZone(fvgLow, fvgHigh, bbLow, bbHigh, unicornLow, unicornHigh);
   double impulseHigh = r[1].high, impulseLow = r[1].low;
   for(int i = 1; i < need && r[i].time >= signalTime; ++i)
   {
      impulseHigh = MathMax(impulseHigh, r[i].high);
      impulseLow = MathMin(impulseLow, r[i].low);
   }
   if(buy) impulseLow = MathMin(impulseLow, sweep);
   else impulseHigh = MathMax(impulseHigh, sweep);
   double range = impulseHigh - impulseLow;
   double rawOTELow, rawOTEHigh;
   if(buy)
   {
      rawOTELow = impulseHigh - range * cfg.InpICTOTELow;
      rawOTEHigh = impulseHigh - range * cfg.InpICTOTEHigh;
   }
   else
   {
      rawOTELow = impulseLow + range * cfg.InpICTOTEHigh;
      rawOTEHigh = impulseLow + range * cfg.InpICTOTELow;
   }
   bool ote = cfg.InpICTUseOTE && range >= cfg.InpICTMinImpulseATR * atr &&
              IntersectZone(fvgLow, fvgHigh, rawOTELow, rawOTEHigh, oteLow, oteHigh);
   bool inversion = cfg.InpICTUseInversion && hasInv;

   bool selected = false;
   if(cfg.InpICTPriority == ICT_PRIORITY_UNICORN && unicorn)
      { chosenLow=unicornLow; chosenHigh=unicornHigh; model="ICT-UNICORN"; selected=true; }
   if(cfg.InpICTPriority == ICT_PRIORITY_OTE && ote)
      { chosenLow=oteLow; chosenHigh=oteHigh; model="ICT-OTE"; selected=true; }
   if(cfg.InpICTPriority == ICT_PRIORITY_INVERSION && inversion)
      { chosenLow=invLow; chosenHigh=invHigh; model="ICT-INV"; selected=true; }
   if(cfg.InpICTPriority == ICT_PRIORITY_2022 && cfg.InpICTUse2022) selected=true;
   if(!selected && unicorn)
      { chosenLow=unicornLow; chosenHigh=unicornHigh; model="ICT-UNICORN"; selected=true; }
   if(!selected && ote)
      { chosenLow=oteLow; chosenHigh=oteHigh; model="ICT-OTE"; selected=true; }
   if(!selected && inversion)
      { chosenLow=invLow; chosenHigh=invHigh; model="ICT-INV"; selected=true; }
   if(!selected && cfg.InpICTUse2022) selected=true;
   if(!selected) return false;

   if(g_ictSetup.active && g_ictSetup.created == signalTime && g_ictSetup.model == model)
      return false;
   g_ictSetup.active = true;
   g_ictSetup.buy = buy;
   g_ictSetup.zoneLow = MathMin(chosenLow, chosenHigh);
   g_ictSetup.zoneHigh = MathMax(chosenLow, chosenHigh);
   g_ictSetup.stop = buy ? sweep - cfg.InpICTSLBufferGia
                         : sweep + cfg.InpICTSLBufferGia;
   g_ictSetup.created = signalTime;
   g_ictSetup.expiryBars = cfg.InpICTSetupExpiryBars;
   g_ictSetup.model = model;
   g_lastICTSetupTime = signalTime;
   g_status = model + ": cho gia hoi ve vung vao";
   return true;
}

bool HTFDealingRange(double &low, double &high)
{
   MqlRates r[];
   if(!LoadRatesTF(cfg.InpMMBiasTF, cfg.InpMMRangeBars + 2, r)) return false;
   low = r[1].low; high = r[1].high;
   for(int i = 2; i <= cfg.InpMMRangeBars; ++i)
   {
      low = MathMin(low, r[i].low);
      high = MathMax(high, r[i].high);
   }
   return high > low;
}

bool DetectMMContinuation(MqlRates &r[], const int total, const double atr,
                          const bool buy, double &zoneLow, double &zoneHigh,
                          double &stop)
{
   int n = cfg.InpMMConsolidationBars;
   if(total < n + 5) return false;
   double hi = r[2].high, lo = r[2].low;
   for(int i = 3; i < n + 2; ++i)
      { hi = MathMax(hi, r[i].high); lo = MathMin(lo, r[i].low); }
   if(hi - lo > cfg.InpMMMaxConsolidationATR * atr) return false;
   double body = MathAbs(r[1].close - r[1].open);
   bool breakout = buy ? r[1].close > hi : r[1].close < lo;
   if(!breakout || body < cfg.InpMMDisplacementATR * atr) return false;
   if(buy && r[1].low > r[3].high)
      { zoneLow = r[3].high; zoneHigh = r[1].low; stop = lo; return true; }
   if(!buy && r[3].low > r[1].high)
      { zoneLow = r[1].high; zoneHigh = r[3].low; stop = hi; return true; }
   return false;
}

bool BuildMMSetup()
{
   if(!cfg.InpUseMMModule) return false;
   int need = cfg.InpMMLookback + cfg.InpMMPivotBars * 2 + 12;
   MqlRates r[];
   double atr;
   if(!LoadRatesTF(g_mmTF, need, r) || !ReadClosedATR(hMMATR, atr)) return false;

   if(g_mmContext.active)
   {
      if((g_mmContext.buy && r[1].low <= g_mmContext.invalidation) ||
         (!g_mmContext.buy && r[1].high >= g_mmContext.invalidation))
         g_mmContext.active = false;
      int sec = PeriodSeconds(g_mmTF);
      if(g_mmContext.active && sec > 0 && TimeCurrent() > g_mmContext.reversalTime +
                                   (long)cfg.InpMMModelExpiryBars * sec)
         g_mmContext.active = false;
      else if(g_mmContext.active && g_mmContext.nextLeg <= 2 &&
              ((g_mmContext.nextLeg == 1 && cfg.InpMMUseLeg1) ||
               (g_mmContext.nextLeg == 2 && cfg.InpMMUseLeg2)))
      {
         double zl, zh, st;
         if(DetectMMContinuation(r, need, atr, g_mmContext.buy, zl, zh, st))
         {
            if(r[1].time <= g_lastMMSetupTime) return false;
            g_mmSetup.active = true;
            g_mmSetup.buy = g_mmContext.buy;
            g_mmSetup.zoneLow = MathMin(zl, zh);
            g_mmSetup.zoneHigh = MathMax(zl, zh);
            g_mmSetup.stop = g_mmContext.buy ? st - cfg.InpMMSLBufferGia
                                             : st + cfg.InpMMSLBufferGia;
            g_mmSetup.created = r[1].time;
            g_mmSetup.expiryBars = cfg.InpMMLegSetupExpiryBars;
            g_mmSetup.model = g_mmContext.nextLeg == 1 ? "MM-LEG1" : "MM-LEG2";
            g_lastMMSetupTime = r[1].time;
            g_status = g_mmSetup.model + ": cho retest";
            return true;
         }
      }
   }

   if(!cfg.InpMMUseLowRisk) return false;
   double rangeLow, rangeHigh;
   if(!HTFDealingRange(rangeLow, rangeHigh)) return false;
   double premium = rangeLow + (rangeHigh - rangeLow) * cfg.InpMMPremiumLevel;
   double discount = rangeLow + (rangeHigh - rangeLow) * cfg.InpMMDiscountLevel;

   for(int side = 0; side < 2; ++side)
   {
      bool buy = side == 0;
      double fvgLow, fvgHigh, sweep, bbLow, bbHigh, invLow, invHigh;
      bool hasInv;
      datetime signalTime;
      if(!DetectSweepMSSFVG(r, need, buy, cfg.InpMMPivotBars, cfg.InpMMLookback, atr,
                            cfg.InpMMDisplacementATR, cfg.InpMMMinFVG_ATR,
                            fvgLow, fvgHigh, sweep, bbLow, bbHigh,
                            invLow, invHigh, hasInv, signalTime)) continue;
      if(signalTime <= g_lastMMTaken || signalTime <= g_lastMMSetupTime) continue;
      if((buy && sweep > discount) || (!buy && sweep < premium)) continue;
      double zl, zh;
      if(!IntersectZone(fvgLow, fvgHigh, bbLow, bbHigh, zl, zh))
         { zl = fvgLow; zh = fvgHigh; }
      g_mmSetup.active = true;
      g_mmSetup.buy = buy;
      g_mmSetup.zoneLow = MathMin(zl, zh);
      g_mmSetup.zoneHigh = MathMax(zl, zh);
      g_mmSetup.stop = buy ? sweep - cfg.InpMMSLBufferGia
                           : sweep + cfg.InpMMSLBufferGia;
      g_mmSetup.created = signalTime;
      g_mmSetup.expiryBars = cfg.InpMMLowRiskExpiryBars;
      g_mmSetup.model = "MM-LOWRISK";
      g_lastMMSetupTime = signalTime;
      g_mmContext.active = true;
      g_mmContext.buy = buy;
      g_mmContext.nextLeg = 1;
      g_mmContext.reversalTime = signalTime;
      g_mmContext.invalidation = g_mmSetup.stop;
      g_status = "MM: smart-money reversal, cho low-risk entry";
      return true;
   }
   return false;
}

int ReadSMCBias(string &details)
{
   details = "";
   if(!cfg.InpSMCDungLocEMAH1)
   {
      int structural = StructuralBias(g_smcBiasTF, cfg.InpSMCLookback,
                                      cfg.InpSMCPivotBars);
      details = "bias_mode=structure|bias=" +
                (structural > 0 ? "BUY" :
                 (structural < 0 ? "SELL" : "TRUNG_TINH"));
      return structural;
   }

   MqlRates biasBar[];
   ArraySetAsSeries(biasBar, true);
   double fast = 0.0, slow = 0.0;
   if(CopyRates(_Symbol, g_smcBiasTF, 1, 1, biasBar) != 1 ||
      !CopyOneBuffer(hSMCBiasFast, 0, 1, fast) ||
      !CopyOneBuffer(hSMCBiasSlow, 0, 1, slow))
   {
      details = "bias_mode=ema|data=missing";
      return 0;
   }

   double close = biasBar[0].close;
   bool buy = close > MathMax(fast, slow);
   bool sell = close < MathMin(fast, slow);
   if(cfg.InpSMCYeuCauThuTuEMAH1)
   {
      buy = buy && fast > slow;
      sell = sell && fast < slow;
   }
   int bias = buy == sell ? 0 : (buy ? 1 : -1);
   details = "bias_mode=ema|bias_tf=" + ShortTimeframeName(g_smcBiasTF) +
             "|bias_close=" + DoubleToString(close, _Digits) +
             "|bias_ema_fast=" + DoubleToString(fast, _Digits) +
             "|bias_ema_slow=" + DoubleToString(slow, _Digits) +
             "|bias=" + (bias > 0 ? "BUY" :
                         (bias < 0 ? "SELL" : "TRUNG_TINH"));
   return bias;
}

bool SMCEntryFiltersAllow(const bool buy, string &details)
{
   details = "";
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, g_smcTF, 1, 1, bar) != 1)
   {
      details = "entry_data=missing";
      return false;
   }

   double close = bar[0].close;
   details = "entry_close=" + DoubleToString(close, _Digits);
   if(cfg.InpSMCDungLocEMAM5)
   {
      int slopeBars = MathMax(1, cfg.InpSMCSoNenDoDocEMA);
      double fastNow = 0.0, slowNow = 0.0;
      double fastOld = 0.0, slowOld = 0.0;
      if(!CopyOneBuffer(hSMCEntryFast, 0, 1, fastNow) ||
         !CopyOneBuffer(hSMCEntrySlow, 0, 1, slowNow) ||
         !CopyOneBuffer(hSMCEntryFast, 0, 1 + slopeBars, fastOld) ||
         !CopyOneBuffer(hSMCEntrySlow, 0, 1 + slopeBars, slowOld))
      {
         details += "|entry_ema=missing";
         return false;
      }
      bool priceSide = buy ? close > MathMax(fastNow, slowNow)
                           : close < MathMin(fastNow, slowNow);
      bool slopeSide = buy ? (fastNow > fastOld && slowNow > slowOld)
                           : (fastNow < fastOld && slowNow < slowOld);
      details += "|entry_ema_fast=" + DoubleToString(fastNow, _Digits) +
                 "|entry_ema_slow=" + DoubleToString(slowNow, _Digits) +
                 "|entry_fast_slope=" +
                 DoubleToString(fastNow - fastOld, _Digits) +
                 "|entry_slow_slope=" +
                 DoubleToString(slowNow - slowOld, _Digits);
      if(!priceSide || (cfg.InpSMCYeuCauDoDocEMAM5 && !slopeSide))
      {
         details += "|entry_ema_filter=blocked";
         return false;
      }
   }

   if(cfg.InpSMCDungLocRSI)
   {
      double rsi = 0.0;
      if(!CopyOneBuffer(hSMCRSI, 0, 1, rsi))
      {
         details += "|rsi=missing";
         return false;
      }
      details += "|rsi=" + DoubleToString(rsi, 2);
      if((buy && rsi < cfg.InpSMCRSIMuaToiThieu) ||
         (!buy && rsi > cfg.InpSMCRSIBanToiDa))
      {
         details += "|rsi_filter=blocked";
         return false;
      }
   }
   return true;
}

bool DetectSMCStructure(MqlRates &r[], const int total, const bool buy,
                        const double atr, double &zoneLow, double &zoneHigh,
                        double &sweepExtreme, bool &hasFVG,
                        string &zoneSource, datetime &signalTime)
{
   int wing = cfg.InpSMCPivotBars;
   int maxShift = MathMin(cfg.InpSMCLookback, total - wing - 2);
   for(int sweep = wing + 3; sweep <= maxShift; ++sweep)
   {
      int liquidity = FindPivot(r, total, !buy, sweep + wing,
                                MathMin(maxShift + wing,
                                        total - wing - 1), wing);
      if(liquidity < 0) continue;
      double level = buy ? r[liquidity].low : r[liquidity].high;
      bool swept = buy ? (r[sweep].low < level && r[sweep].close > level)
                       : (r[sweep].high > level && r[sweep].close < level);
      if(!swept) continue;

      double structure = buy ? -1.0e100 : 1.0e100;
      int structureEnd = MathMin(sweep + 16, total - 1);
      for(int j = sweep + 1; j <= structureEnd; ++j)
      {
         if(buy) structure = MathMax(structure, r[j].high);
         else structure = MathMin(structure, r[j].low);
      }

      int displacement = -1;
      for(int j = sweep - 1; j >= 1; --j)
      {
         double body = MathAbs(r[j].close - r[j].open);
         bool broke = buy ? r[j].close > structure
                          : r[j].close < structure;
         if(broke && body >= cfg.InpSMCDisplacementATR * atr)
         {
            displacement = j;
            break;
         }
      }
      if(displacement < 1) continue;

      int orderBlock = -1;
      for(int j = displacement + 1; j <= sweep; ++j)
      {
         bool opposite = buy ? r[j].close < r[j].open
                             : r[j].close > r[j].open;
         if(opposite) { orderBlock = j; break; }
      }
      if(orderBlock < 0) orderBlock = sweep;
      double obLow = r[orderBlock].low;
      double obHigh = r[orderBlock].high;

      hasFVG = false;
      double fvgLow = 0.0, fvgHigh = 0.0;
      for(int k = displacement; k >= 1; --k)
      {
         if(k + 2 > sweep) continue;
         double gap = buy ? r[k].low - r[k+2].high
                          : r[k+2].low - r[k].high;
         if(gap < cfg.InpSMCMinFVGATR * atr) continue;
         if(buy)
         {
            fvgLow = r[k+2].high;
            fvgHigh = r[k].low;
         }
         else
         {
            fvgLow = r[k].high;
            fvgHigh = r[k+2].low;
         }
         hasFVG = true;
         break;
      }
      if(cfg.InpSMCBatBuocFVG && !hasFVG) continue;

      zoneLow = MathMin(obLow, obHigh);
      zoneHigh = MathMax(obLow, obHigh);
      zoneSource = "ORDER_BLOCK";
      if(hasFVG && cfg.InpSMCUuTienVungFVG)
      {
         double intersectionLow = 0.0, intersectionHigh = 0.0;
         if(IntersectZone(obLow, obHigh, fvgLow, fvgHigh,
                          intersectionLow, intersectionHigh))
         {
            zoneLow = intersectionLow;
            zoneHigh = intersectionHigh;
            zoneSource = "OB_FVG";
         }
         else
         {
            zoneLow = MathMin(fvgLow, fvgHigh);
            zoneHigh = MathMax(fvgLow, fvgHigh);
            zoneSource = "FVG";
         }
      }

      sweepExtreme = buy ? r[sweep].low : r[sweep].high;
      bool invalidated = false;
      for(int j = displacement - 1; j >= 1; --j)
      {
         if((buy && r[j].low <= sweepExtreme) ||
            (!buy && r[j].high >= sweepExtreme))
         {
            invalidated = true;
            break;
         }
      }
      if(invalidated) continue;
      signalTime = r[displacement].time;
      return true;
   }
   return false;
}

bool BuildSMCSetup()
{
   if(!cfg.InpUseSMCModule) return false;
   g_smcSetupDetails = "";
   string biasDetails = "";
   int bias = ReadSMCBias(biasDetails);
   if(bias == 0)
   {
      g_status = "SMC: chưa có xu hướng H1 hợp lệ";
      g_smcSetupDetails = biasDetails;
      return false;
   }

   bool buy = bias > 0;
   string entryDetails = "";
   if(!SMCEntryFiltersAllow(buy, entryDetails))
   {
      g_status = "SMC: bộ lọc EMA/RSI M5 chưa đồng thuận";
      g_smcSetupDetails = biasDetails + "|" + entryDetails;
      return false;
   }

   int need = cfg.InpSMCLookback + cfg.InpSMCPivotBars * 2 + 20;
   MqlRates rates[];
   double atr = 0.0;
   if(!LoadRatesTF(g_smcTF, need, rates) ||
      !ReadClosedATR(hSMCATR, atr))
   {
      g_status = "SMC: chưa đủ dữ liệu nến/ATR";
      g_smcSetupDetails = biasDetails + "|" + entryDetails +
                          "|structure_data=missing";
      return false;
   }

   double zoneLow = 0.0, zoneHigh = 0.0, sweep = 0.0;
   bool hasFVG = false;
   string zoneSource = "";
   datetime signalTime = 0;
   if(!DetectSMCStructure(rates, need, buy, atr, zoneLow, zoneHigh,
                          sweep, hasFVG, zoneSource, signalTime))
   {
      g_status = "SMC: chưa có Sweep + BOS/CHoCH + Displacement hợp lệ";
      g_smcSetupDetails = biasDetails + "|" + entryDetails;
      return false;
   }
   if(signalTime <= g_lastSMCTaken || signalTime <= g_lastSMCSetupTime)
   {
      g_status = "SMC: thiết lập gần nhất đã được xử lý";
      g_smcSetupDetails = biasDetails + "|" + entryDetails +
                          "|signal_time=" +
                          TimeToString(signalTime, TIME_DATE|TIME_SECONDS);
      return false;
   }
   if(g_smcSetup.active && g_smcSetup.created == signalTime) return false;

   g_smcSetup.active = true;
   g_smcSetup.buy = buy;
   g_smcSetup.zoneLow = MathMin(zoneLow, zoneHigh);
   g_smcSetup.zoneHigh = MathMax(zoneLow, zoneHigh);
   g_smcSetup.stop = buy
                     ? sweep - cfg.InpSMCSLBufferGia
                     : sweep + cfg.InpSMCSLBufferGia;
   g_smcSetup.created = signalTime;
   g_smcSetup.expiryBars = cfg.InpSMCSetupExpiryBars;
   g_smcSetup.model = zoneSource == "ORDER_BLOCK" ? "SMC-OB" : "SMC-FVG";
   g_lastSMCSetupTime = signalTime;
   g_smcSetupDetails = biasDetails + "|" + entryDetails +
                       "|zone_source=" + zoneSource +
                       "|has_fvg=" + (hasFVG ? "true" : "false") +
                       "|atr=" + DoubleToString(atr, _Digits);
   g_status = g_smcSetup.model + ": chờ giá hồi vào vùng";
   return true;
}

void EnterOnCross(const bool buy, const bool retestEntry)
{


   string biasDetails = "";
   if(!EMABiasAllows(buy, biasDetails))
   {
      g_status = CoreEMAMethodName() + ": bộ lọc EMA " +
                 IntegerToString(cfg.InpEMANhanhLoc) + "/" +
                 IntegerToString(cfg.InpEMAChamLoc) + " " +
                 ShortTimeframeName(cfg.InpEMAKhungLoc) +
                 " không cho phép hướng " + (buy ? "BUY" : "SELL") +
                 " (" + biasDetails + ")";
      return;
   }

   int session = GetSession(TimeCurrent());
   if(cfg.InpUseEMASessionFilter && session == 0)
      { g_status = "Tin hieu EMA ngoai phien da bat"; return; }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0 || tick.ask <= 0)
      { g_status = "Khong co gia hop le"; return; }
   if(cfg.InpSpreadToiDaGia > 0.0 && tick.ask - tick.bid > cfg.InpSpreadToiDaGia)
      { g_status = "Spread vuot gioi han"; return; }
   if(!WaveIsStrongEnough(buy, (tick.ask + tick.bid) * 0.5,
                          retestEntry)) return;

   double recentExtreme;
   if(!FindPreCrossExtreme(buy, recentExtreme))
      { g_status = "Chua du nen de lay SL gan diem cat"; return; }

   double entry = buy ? tick.ask : tick.bid;
   double sl = buy ? PriceDown(recentExtreme - cfg.InpSLBufferGia)
                   : PriceUp(recentExtreme + cfg.InpSLBufferGia);
   string slReason = "";
   if(!NormalizeSLDistance(buy, entry, sl, cfg.InpMaxSLPriceDistance, slReason))
   {
      g_status = slReason;
      return;
   }
   double risk = MathAbs(entry - sl);
   int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double safety = (stops + 1) * _Point;
   if((buy && sl >= tick.bid - safety) || (!buy && sl <= tick.ask + safety))
      { g_status = "SL gan qua, khong dat stop-level san"; return; }
   double effectiveMaxSL = EffectiveMaxSLDistance(cfg.InpMaxSLPriceDistance);
   if(effectiveMaxSL > 0.0 && risk > effectiveMaxSL)
   {
      g_status = "SL swing xa hon gioi han gia";
      PrintFormat("Bo qua giao cat: SL cach Entry %.3f gia, gioi han %.3f",
                  risk, effectiveMaxSL);
      return;
   }

   double rr = session > 0 ? SessionRR(session) : cfg.InpEMAOutsideSessionRR;
   double tp = buy ? PriceUp(entry + rr * risk) : PriceDown(entry - rr * risk);
   if((buy && tp <= tick.bid + safety) || (!buy && tp >= tick.ask - safety))
      { g_status = "TP2 khong dat stop-level san"; return; }
   datetime signalTime = retestEntry ? g_emaRetestSetup.crossTime : TimeCurrent();
   string labDetails = "entry_type=" + (retestEntry ? "EMA_RETEST" : "EMA_CROSS") +
                       "|rr=" + DoubleToString(rr, 3) +
                       "|risk_price=" + DoubleToString(risk, _Digits);
   if(retestEntry)
   {
      double retestATR = 0.0;
      if(ReadEMARetestATR(retestATR) && retestATR > 0.0)
         labDetails += "|max_away_atr=" + DoubleToString(g_emaRetestSetup.maxAway/retestATR, 5);
   }
   StartShadowProfiles(CoreEMAMethodName(), buy, signalTime, g_tf,
                       entry, sl, tp,
                       retestEntry ? "EMA_RETEST" : "EMA_CROSS",
                       labDetails);

}

void TryEnterSetup(TradeSetup &s, const ENUM_TIMEFRAMES tf,
                   const double rr, const double maxSLDistance,
                   const ENUM_SETUP_ENGINE engine)
{
   if(!s.active) return;
   if(SetupExpired(s, tf))
   {
      g_status = s.model + ": setup het han";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(s.model, "", "SETUP_STATE", "EXPIRED", g_status,
                       s.buy ? 1 : -1, s.created, tf, 0.0, s.stop);
      ClearSetup(s);
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
   {
      g_status = s.model + ": khong doc duoc gia Bid/Ask";
      return;
   }
   if((s.buy && tick.bid <= s.stop) || (!s.buy && tick.ask >= s.stop))
   {
      g_status = s.model + ": setup bi vo hieu";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(s.model, "", "SETUP_STATE", "INVALIDATED", g_status,
                       s.buy ? 1 : -1, s.created, tf, 0.0, s.stop);
      ClearSetup(s);
      return;
   }
   double entry = s.buy ? tick.ask : tick.bid;
   double tolerance = TickSize();
   if(entry < s.zoneLow - tolerance || entry > s.zoneHigh + tolerance) return;
   string smcTouchDetails = "";
   if(engine == SETUP_ENGINE_SMC)
   {
      string currentBiasDetails = "", currentEntryDetails = "";
      int currentBias = ReadSMCBias(currentBiasDetails);
      if(currentBias != (s.buy ? 1 : -1))
      {
         g_status = s.model + ": xu hướng H1 đã đổi trước khi hồi vùng";
         ResearchEvent(s.model, "", "ZONE_TOUCH", "REJECTED", g_status,
                       s.buy ? 1 : -1, s.created, tf, entry, s.stop,
                       0.0, 0.0, currentBiasDetails);
         ClearSetup(s);
         return;
      }
      if(!SMCEntryFiltersAllow(s.buy, currentEntryDetails))
      {
         g_status = s.model + ": EMA/RSI khung vào chưa đồng thuận lúc chạm vùng";
         ResearchEvent(s.model, "", "ZONE_TOUCH", "REJECTED", g_status,
                       s.buy ? 1 : -1, s.created, tf, entry, s.stop,
                       0.0, 0.0,
                       currentBiasDetails + "|" + currentEntryDetails);
         return;
      }
      smcTouchDetails = currentBiasDetails + "|" + currentEntryDetails;
   }
   string method = engine == SETUP_ENGINE_ICT ? "ICT" :
                   (engine == SETUP_ENGINE_MM ? "MM" : "SMC");
   double sl = s.buy ? PriceDown(s.stop) : PriceUp(s.stop);
   string slReason = "";
   if(!NormalizeSLDistance(s.buy, entry, sl, maxSLDistance, slReason))
   {
      g_status = s.model + ": " + slReason;
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(s.model, "THUC_TE", "ZONE_TOUCH", "REJECTED",
                       g_status, s.buy ? 1 : -1, s.created, tf,
                       entry, sl, 0.0, 0.0, smcTouchDetails);
      ClearSetup(s);
      return;
   }
   double risk = MathAbs(entry - sl);
   double tp = risk > 0.0
               ? (s.buy ? PriceUp(entry + rr * risk)
                        : PriceDown(entry - rr * risk))
               : 0.0;
   string details = "zone_low=" + DoubleToString(s.zoneLow, _Digits) +
                    "|zone_high=" + DoubleToString(s.zoneHigh, _Digits) +
                    "|rr=" + DoubleToString(rr, 3) +
                    "|max_sl_price=" + DoubleToString(maxSLDistance, _Digits);
   if(engine == SETUP_ENGINE_SMC && g_smcSetupDetails != "")
      details += "|" + g_smcSetupDetails;
   if(engine == SETUP_ENGINE_SMC && smcTouchDetails != "")
      details += "|touch=" + smcTouchDetails;
   ResearchEvent(s.model, "", "ZONE_TOUCH", "DETECTED",
                 "Giá đã chạm vùng vào lệnh", s.buy ? 1 : -1,
                 s.created, tf, entry, sl, tp, 0.0, details);
   int session = GetSession(TimeCurrent());
   bool useSessionFilter = engine == SETUP_ENGINE_ICT
                           ? cfg.InpUseICTSessionFilter
                           : (engine == SETUP_ENGINE_MM
                              ? cfg.InpUseMMSessionFilter
                              : cfg.InpUseSMCSessionFilter);
   if(useSessionFilter && session == 0)
   {
      g_status = s.model + ": ngoai phien da bat";
      if(cfg.InpGhiTinHieuBiLoai)
         ResearchEvent(s.model, "THUC_TE", "LIVE_DECISION", "REJECTED",
                       g_status, s.buy ? 1 : -1, s.created, tf,
                       entry, sl, tp, 0.0, details);
      return;
   }
   StartShadowProfiles(s.model, s.buy, s.created, tf, entry, sl, tp,
                       "ENTRY_FILTERS_PASSED", details);
   if(engine == SETUP_ENGINE_ICT) g_lastICTTaken = s.created;
   else if(engine == SETUP_ENGINE_MM) g_lastMMTaken = s.created;
   else g_lastSMCTaken = s.created;
   ClearSetup(s);
}

void DrawDashboard() {

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
   if(cfg.InpSoLenhToiDaMoiNgay < 0)
      return InputError("Tổng số lệnh tối đa mỗi ngày", "không được âm; 0 là tắt");
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

   bool needsATR = (cfg.InpUseEMAModule &&
                    (cfg.InpUseWaveFilter ||
                     (cfg.InpEMAVaoSauRetest &&
                      cfg.InpEMAKhoangDiXaToiThieuATR > 0.0))) ||
                   cfg.InpUseICTModule || cfg.InpUseMMModule || cfg.InpUseSMCModule;
   if(needsATR && cfg.InpATRPeriod < 1)
      return InputError("Chu kỳ ATR dùng chung", "phải từ 1 trở lên");

   if(cfg.InpUseEMAModule)
   {
      if(cfg.InpFastEMA < 1 || cfg.InpSlowEMA < 1)
         return InputError("Chu kỳ EMA", "cả hai chu kỳ phải từ 1 trở lên");
      if(cfg.InpFastEMA == cfg.InpSlowEMA)
         Print("CANH BAO INPUT: hai chu ky EMA bang nhau nen se khong co giao cat.");
      if(cfg.InpSLLookbackBars < 1)
         return InputError("Số nến tìm SL EMA", "phải từ 1 trở lên");
      if(cfg.InpSLBufferGia < 0.0)
         return InputError("Đệm SL EMA", "không được âm");
      if(cfg.InpEMAVaoSauRetest &&
         (cfg.InpEMAKhoangDiXaToiThieuATR < 0.0 ||
          cfg.InpEMADungSaiRetestGia < 0.0 || cfg.InpEMASoNenChoToiThieu < 0 ||
          cfg.InpEMAHetHanRetestBars < 1 ||
          cfg.InpEMASoNenChoToiThieu >= cfg.InpEMAHetHanRetestBars))
         return InputError("Điểm vào retest EMA M1",
                           "khoảng/dung sai không âm; hạn từ 1 nến và lớn hơn số nến chờ tối thiểu");
      if(cfg.InpEMADungLocM5 &&
         (cfg.InpEMANhanhLoc < 1 || cfg.InpEMAChamLoc < 1 ||
          cfg.InpEMANhanhLoc == cfg.InpEMAChamLoc))
         return InputError("EMA lọc xu hướng khung cao",
                           "hai chu kỳ phải từ 1 trở lên và khác nhau");
      if(cfg.InpUseWaveFilter &&
         (cfg.InpWaveBars < 2 || cfg.InpMinWaveATR < 0.0 || cfg.InpMinMoveATR < 0.0 ||
          cfg.InpRecentCrossBars < 0 || cfg.InpMinDirectionEfficiency < 0.0 ||
          cfg.InpMinDirectionEfficiency > 1.0 || cfg.InpMaxOpposingSlowSlopeATR < 0.0))
         return InputError("Bộ lọc sóng EMA",
                           "số nến từ 2; hiệu suất 0-1; các ngưỡng khác không được âm");
      if(cfg.InpUseAsia && cfg.InpAsiaRR <= 0.0)
         return InputError("RR phiên Á", "phải lớn hơn 0");
      if(cfg.InpUseEurope && cfg.InpEuropeRR <= 0.0)
         return InputError("RR phiên Âu", "phải lớn hơn 0");
      if(cfg.InpUseAmerica && cfg.InpAmericaRR <= 0.0)
         return InputError("RR phiên Mỹ", "phải lớn hơn 0");
      if(!cfg.InpUseEMASessionFilter && cfg.InpEMAOutsideSessionRR <= 0.0)
         return InputError("RR EMA khi tắt lọc phiên", "phải lớn hơn 0");
   }

   if(cfg.InpUseICTModule)
   {
      if(cfg.InpICTLookback < 1 || cfg.InpICTPivotBars < 1 || cfg.InpICTSetupExpiryBars < 1)
         return InputError("Số nến/Pivot/Hạn thiết lập ICT", "tất cả phải từ 1 trở lên");
      if(cfg.InpICTMinFVG_ATR < 0.0 || cfg.InpICTDisplacementATR <= 0.0 ||
         cfg.InpICTMinImpulseATR < 0.0)
         return InputError("Ngưỡng ATR của ICT", "FVG/nhịp không âm và Displacement lớn hơn 0");
      if(cfg.InpICTUseOTE &&
         (cfg.InpICTOTEHigh < 0.0 || cfg.InpICTOTELow > 1.0 ||
          cfg.InpICTOTELow <= cfg.InpICTOTEHigh))
         return InputError("Vùng OTE", "hai mức nằm trong 0-1 và biên dưới phải lớn hơn biên trên");
      if(cfg.InpICTRR <= 0.0 || cfg.InpICTSLBufferGia < 0.0)
         return InputError("RR/SL của ICT", "RR lớn hơn 0 và Buffer không được âm");
      if(!cfg.InpICTUse2022 && !cfg.InpICTUseOTE && !cfg.InpICTUseUnicorn && !cfg.InpICTUseInversion)
         Print("CANH BAO INPUT: ICT dang bat nhung tat ca mo hinh ICT deu tat.");
   }

   if(cfg.InpUseMMModule)
   {
      if(cfg.InpMMLookback < 1 || cfg.InpMMPivotBars < 1 || cfg.InpMMRangeBars < 1)
         return InputError("Số nến/Pivot Market Maker", "tất cả phải từ 1 trở lên");
      if(cfg.InpMMDiscountLevel < 0.0 || cfg.InpMMPremiumLevel > 1.0 ||
         cfg.InpMMDiscountLevel >= cfg.InpMMPremiumLevel)
         return InputError("Premium/Discount", "hai mức nằm trong 0-1 và Discount nhỏ hơn Premium");
      if(cfg.InpMMDisplacementATR <= 0.0 || cfg.InpMMMinFVG_ATR < 0.0 ||
         cfg.InpMMMaxConsolidationATR <= 0.0)
         return InputError("Ngưỡng ATR Market Maker", "FVG không âm; các ngưỡng còn lại lớn hơn 0");
      if(cfg.InpMMConsolidationBars < 2 || cfg.InpMMModelExpiryBars < 1 ||
         cfg.InpMMLegSetupExpiryBars < 1 || cfg.InpMMLowRiskExpiryBars < 1)
         return InputError("Số nến/hạn Market Maker", "tích lũy từ 2 nến; các hạn từ 1 nến");
      if(cfg.InpMMRR <= 0.0 || cfg.InpMMSLBufferGia < 0.0)
         return InputError("RR/SL Market Maker", "RR lớn hơn 0 và Buffer không được âm");
      if(!cfg.InpMMUseLowRisk && !cfg.InpMMUseLeg1 && !cfg.InpMMUseLeg2)
         Print("CANH BAO INPUT: Market Maker dang bat nhung tat ca diem vao deu tat.");
   }

   if(cfg.InpUseSMCModule)
   {
      if(cfg.InpSMCLookback < 1 || cfg.InpSMCPivotBars < 1 ||
         cfg.InpSMCSetupExpiryBars < 1)
         return InputError("Số nến/Pivot/Hạn thiết lập SMC",
                           "tất cả phải từ 1 trở lên");
      if(cfg.InpSMCDisplacementATR <= 0.0 || cfg.InpSMCMinFVGATR < 0.0)
         return InputError("Ngưỡng ATR của SMC",
                           "Displacement lớn hơn 0 và FVG không được âm");
      if(cfg.InpSMCDungLocEMAH1 &&
         (cfg.InpSMCEMANhanhH1 < 1 || cfg.InpSMCEMAChamH1 < 1 ||
          cfg.InpSMCEMANhanhH1 == cfg.InpSMCEMAChamH1))
         return InputError("EMA lọc H1 của SMC",
                           "hai chu kỳ phải từ 1 trở lên và khác nhau");
      if(cfg.InpSMCDungLocEMAM5 &&
         (cfg.InpSMCEMANhanhM5 < 1 || cfg.InpSMCEMAChamM5 < 1 ||
          cfg.InpSMCEMANhanhM5 == cfg.InpSMCEMAChamM5 ||
          cfg.InpSMCSoNenDoDocEMA < 1))
         return InputError("EMA lọc khung vào của SMC",
                           "hai chu kỳ khác nhau, từ 1; số nến đo dốc từ 1");
      if(cfg.InpSMCDungLocRSI &&
         (cfg.InpSMCRSIPeriod < 1 || cfg.InpSMCRSIMuaToiThieu < 0.0 ||
          cfg.InpSMCRSIMuaToiThieu > 100.0 || cfg.InpSMCRSIBanToiDa < 0.0 ||
          cfg.InpSMCRSIBanToiDa > 100.0))
         return InputError("RSI lọc SMC",
                           "chu kỳ từ 1 và các ngưỡng nằm trong 0-100");
      if(cfg.InpSMCRR <= 0.0 || cfg.InpSMCSLBufferGia < 0.0)
         return InputError("RR/SL của SMC",
                           "RR lớn hơn 0 và Buffer không được âm");
      if(cfg.InpSMCBatLop2 &&
         (cfg.InpSMCLop2PhanTramDenSL <= 0.0 ||
          cfg.InpSMCLop2PhanTramDenSL >= 100.0))
         return InputError("Lệnh SMC-L2",
                           "vị trí phải nằm giữa 0-100%");
      if(cfg.InpSMCBatLop2 && cfg.InpExecutionMode != BA_PHUONG_PHAP_DOC_LAP)
         Print("CANH BAO INPUT: SMC-L2 chi dat lenh khi chay che do doc lap.");
      if(cfg.InpSMCBatLop2 && cfg.InpExecutionMode == BA_PHUONG_PHAP_DOC_LAP &&
         cfg.InpMaxIndependentPositions < 2)
         Print("CANH BAO INPUT: can toi thieu 2 vi the doc lap de SMC-L2 hoat dong.");
   }

   bool usePVEng = PVUseEngulfing();
   bool usePVPin = PVUsePinBar();
   bool usePVBrk = PVUseBreakout();
   bool hasPVPriceAction = usePVEng || usePVPin || usePVBrk;
   bool hasPV = cfg.InpUsePVEMAModule || hasPVPriceAction ||
                cfg.InpUseLQModule || cfg.InpUsePVTModule;
   if(hasPV)
   {
      if(cfg.InpPVSoNenTimSL < 1 || cfg.InpPVDemSLGia < 0.0)
         return InputError("SL EMA/PA/LQ/PVT", "số nến từ 1 và đệm không âm");
      if(cfg.InpPVTP2R <= cfg.InpTP1AtR || cfg.InpPVRRToiThieu < 0.0 ||
         cfg.InpPVBEKhiLoiGia < 0.0)
         return InputError("TP/BE EMA/PA/LQ/PVT", "TP2 R phải lớn hơn TP1 R chung; RR/BE không âm");
      if(cfg.InpPVThuaLienTiepToiDa < 0)
         return InputError("Giới hạn thua EMA/PA/LQ/PVT", "số lệnh không được âm");
      if(cfg.InpUsePVEMAModule &&
         (cfg.InpPVEMANhanhXuHuong < 1 || cfg.InpPVEMAChamXuHuong < 1 ||
          cfg.InpPVEMANhanhVaoLenh < 1 || cfg.InpPVEMAChamVaoLenh < 1 ||
          cfg.InpPVChuKyATR < 1 || cfg.InpPVChuKyADX < 1 ||
          cfg.InpPVSoNenKiemTraNhipHoi < 1 || cfg.InpPVADXToiThieu < 0.0 ||
          cfg.InpPVDungSaiHoiATR < 0.0 || cfg.InpPVThanNenToiThieu < 0.0 ||
          cfg.InpPVThanNenToiThieu > 1.0 || cfg.InpPVDoDaiNenToiDaATR <= 0.0))
         return InputError("Bộ lọc EMA 95/150-26/29", "chu kỳ/số nến > 0; tỷ lệ thân 0-1; ngưỡng hợp lệ");
      if(hasPVPriceAction &&
         (cfg.InpPVSoMauPAToiThieu < 1 || cfg.InpPVSoMauPAToiThieu > 3))
         return InputError("Số mẫu Price Action đồng thuận", "chọn từ 1 đến 3");
      if(usePVEng &&
         (cfg.InpPVATRNhanChim < 1 || cfg.InpPVNhanChimMinATR <= 0.0 ||
          cfg.InpPVNhanChimMaxATR < cfg.InpPVNhanChimMinATR ||
          cfg.InpPVThanNhanChimSoVoiThanTruoc <= 0.0 ||
          cfg.InpPVDongCuaManhNhanChim < 0.0 || cfg.InpPVDongCuaManhNhanChim > 1.0))
         return InputError("Nến nhấn chìm", "ATR/range/thân > 0; max >= min; vị trí đóng 0-1");
      if(usePVPin &&
         (cfg.InpPVATRPinBar < 1 || cfg.InpPVPinMinATR <= 0.0 ||
          cfg.InpPVPinMaxATR < cfg.InpPVPinMinATR || cfg.InpPVRauChinhTrenThan <= 0.0 ||
          cfg.InpPVRauDoiDienTrenThan < 0.0 || cfg.InpPVDongCuaPinTrongBien < 0.0 ||
          cfg.InpPVDongCuaPinTrongBien > 1.0 || cfg.InpPVPinQuetSoNen < 1))
         return InputError("Pin Bar", "các chu kỳ/tỷ lệ phải hợp lệ; vị trí đóng 0-1");
      if(usePVBrk &&
         (cfg.InpPVThanBreakoutToiThieu < 0.0 || cfg.InpPVThanBreakoutToiThieu > 1.0 ||
          cfg.InpPVSoNenVungBreakout < 1 || cfg.InpPVDemBreakoutGia < 0.0 ||
          cfg.InpPVDungSaiRetestGia < 0.0))
         return InputError("Breakout", "tỷ lệ thân 0-1; số nến từ 1; khoảng cách không âm");
      if(cfg.InpUseLQModule &&
         (cfg.InpPVSoNenThanhKhoan < 1 || cfg.InpPVDoXuyenToiThieuGia < 0.0 ||
          cfg.InpPVDoXuyenToiDaGia < 0.0 || cfg.InpPVDongLaiVaoVungGia < 0.0 ||
          cfg.InpPVRauQuetTrenThan <= 0.0))
         return InputError("Quét thanh khoản", "số nến từ 1 và các khoảng/tỷ lệ hợp lệ");
      if(cfg.InpUseLQModule && cfg.InpPVDoXuyenToiThieuGia > cfg.InpPVDoXuyenToiDaGia)
         Print("CANH BAO: Do xuyen thanh khoan min > max; EA tu sap xep thanh ",
               cfg.InpPVDoXuyenToiDaGia, " - ", cfg.InpPVDoXuyenToiThieuGia, " giá.");
      if(cfg.InpUsePVTModule && cfg.InpPVBKPVungPivotGia < 0.0)
         return InputError("Bán kính Pivot", "không được âm");
      if(cfg.InpPVNgungTruocTinPhut < 0 || cfg.InpPVNgungSauTinPhut < 0)
         return InputError("Khoảng dừng tin", "không được âm");
      if(cfg.InpPVChiTradeTrongGio && !ValidSessionHours(cfg.InpPVGioBatDau, cfg.InpPVGioKetThuc))
         return InputError("Giờ trade EMA/PA/LQ/PVT", "giờ bắt đầu/kết thúc không hợp lệ");
   }

   if(cfg.InpUseAsia && !ValidSessionHours(cfg.InpAsiaStart, cfg.InpAsiaEnd))
      return InputError("Giờ phiên Á", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");
   if(cfg.InpUseEurope && !ValidSessionHours(cfg.InpEuropeStart, cfg.InpEuropeEnd))
      return InputError("Giờ phiên Âu", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");
   if(cfg.InpUseAmerica && !ValidSessionHours(cfg.InpAmericaStart, cfg.InpAmericaEnd))
      return InputError("Giờ phiên Mỹ", "giờ bắt đầu 0-23, kết thúc 0-24 và không được bằng nhau");

   if(!cfg.InpUseEMAModule && !cfg.InpUseICTModule && !cfg.InpUseMMModule &&
      !cfg.InpUseSMCModule && !hasPV)
      Print("THONG BAO: tat ca phuong phap dang tat; EA van duoc nap de sua Input.");
   bool activeSessionFilter = (cfg.InpUseEMAModule && cfg.InpUseEMASessionFilter) ||
                              (cfg.InpUseICTModule && cfg.InpUseICTSessionFilter) ||
                              (cfg.InpUseMMModule && cfg.InpUseMMSessionFilter) ||
                              (cfg.InpUseSMCModule && cfg.InpUseSMCSessionFilter);
   if(activeSessionFilter &&
      !cfg.InpUseAsia && !cfg.InpUseEurope && !cfg.InpUseAmerica)
      Print("CANH BAO INPUT: tat ca phien dang tat; phuong phap dung loc phien se khong vao lenh.");
   return true;
}

int Initialize()
{
   if(!ValidateInputs()) return INIT_PARAMETERS_INCORRECT;
   g_tf = cfg.InpTimeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : cfg.InpTimeframe;
   g_ictTF = cfg.InpICTEntryTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : cfg.InpICTEntryTF;
   g_mmTF = cfg.InpMMEntryTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : cfg.InpMMEntryTF;
   g_smcTF = cfg.InpSMCEntryTF == PERIOD_CURRENT
             ? (ENUM_TIMEFRAMES)_Period : cfg.InpSMCEntryTF;
   g_smcBiasTF = cfg.InpSMCBiasTF == PERIOD_CURRENT
                 ? (ENUM_TIMEFRAMES)_Period : cfg.InpSMCBiasTF;
   g_slAnalysisTF = cfg.InpSLAnalysisTF == PERIOD_CURRENT
                    ? (ENUM_TIMEFRAMES)_Period : cfg.InpSLAnalysisTF;
   if(cfg.InpUseEMAModule)
   {
      hFast = iMA(_Symbol, g_tf, cfg.InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      hSlow = iMA(_Symbol, g_tf, cfg.InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      bool needsCoreATR = cfg.InpUseWaveFilter ||
                          (cfg.InpEMAVaoSauRetest &&
                           cfg.InpEMAKhoangDiXaToiThieuATR > 0.0);
      if(needsCoreATR) hATR = iATR(_Symbol, g_tf, cfg.InpATRPeriod);
      if(cfg.InpEMADungLocM5)
      {
         hEMABiasFast = iMA(_Symbol, cfg.InpEMAKhungLoc, cfg.InpEMANhanhLoc,
                            0, MODE_EMA, PRICE_CLOSE);
         hEMABiasSlow = iMA(_Symbol, cfg.InpEMAKhungLoc, cfg.InpEMAChamLoc,
                            0, MODE_EMA, PRICE_CLOSE);
      }
   }
   if(cfg.InpUseICTModule) hICTATR = iATR(_Symbol, g_ictTF, cfg.InpATRPeriod);
   if(cfg.InpUseMMModule) hMMATR = iATR(_Symbol, g_mmTF, cfg.InpATRPeriod);
   if(cfg.InpUseSMCModule)
   {
      hSMCATR = iATR(_Symbol, g_smcTF, cfg.InpATRPeriod);
      if(cfg.InpSMCDungLocEMAH1)
      {
         hSMCBiasFast = iMA(_Symbol, g_smcBiasTF, cfg.InpSMCEMANhanhH1,
                            0, MODE_EMA, PRICE_CLOSE);
         hSMCBiasSlow = iMA(_Symbol, g_smcBiasTF, cfg.InpSMCEMAChamH1,
                            0, MODE_EMA, PRICE_CLOSE);
      }
      if(cfg.InpSMCDungLocEMAM5)
      {
         hSMCEntryFast = iMA(_Symbol, g_smcTF, cfg.InpSMCEMANhanhM5,
                             0, MODE_EMA, PRICE_CLOSE);
         hSMCEntrySlow = iMA(_Symbol, g_smcTF, cfg.InpSMCEMAChamM5,
                             0, MODE_EMA, PRICE_CLOSE);
      }
      if(cfg.InpSMCDungLocRSI)
         hSMCRSI = iRSI(_Symbol, g_smcTF, cfg.InpSMCRSIPeriod, PRICE_CLOSE);
   }
   if(cfg.InpUsePVEMAModule)
   {
      hPVTrendFast = iMA(_Symbol, cfg.InpPVKhungXuHuong,
                         cfg.InpPVEMANhanhXuHuong, 0, MODE_EMA, PRICE_CLOSE);
      hPVTrendSlow = iMA(_Symbol, cfg.InpPVKhungXuHuong,
                         cfg.InpPVEMAChamXuHuong, 0, MODE_EMA, PRICE_CLOSE);
      hPVEntryFast = iMA(_Symbol, cfg.InpPVKhungVaoLenh,
                         cfg.InpPVEMANhanhVaoLenh, 0, MODE_EMA, PRICE_CLOSE);
      hPVEntrySlow = iMA(_Symbol, cfg.InpPVKhungVaoLenh,
                         cfg.InpPVEMAChamVaoLenh, 0, MODE_EMA, PRICE_CLOSE);
      hPVEntryATR = iATR(_Symbol, cfg.InpPVKhungVaoLenh, cfg.InpPVChuKyATR);
      hPVTrendADX = iADX(_Symbol, cfg.InpPVKhungXuHuong, cfg.InpPVChuKyADX);
   }
   if(PVUseEngulfing()) hPVEngATR = iATR(_Symbol, cfg.InpPVKhungNhanChim,
                                         cfg.InpPVATRNhanChim);
   if(PVUsePinBar()) hPVPinATR = iATR(_Symbol, cfg.InpPVKhungPinBar,
                                      cfg.InpPVATRPinBar);
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
   bool needsCoreATR = cfg.InpUseEMAModule &&
                       (cfg.InpUseWaveFilter ||
                        (cfg.InpEMAVaoSauRetest &&
                         cfg.InpEMAKhoangDiXaToiThieuATR > 0.0));
   if((cfg.InpUseEMAModule &&
       (hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE ||
        (needsCoreATR && hATR == INVALID_HANDLE) ||
        (cfg.InpEMADungLocM5 &&
         (hEMABiasFast == INVALID_HANDLE || hEMABiasSlow == INVALID_HANDLE)))) ||
      (cfg.InpUseICTModule && hICTATR == INVALID_HANDLE) ||
      (cfg.InpUseMMModule && hMMATR == INVALID_HANDLE) ||
      (cfg.InpUseSMCModule &&
       (hSMCATR == INVALID_HANDLE ||
        (cfg.InpSMCDungLocEMAH1 &&
         (hSMCBiasFast == INVALID_HANDLE || hSMCBiasSlow == INVALID_HANDLE)) ||
        (cfg.InpSMCDungLocEMAM5 &&
         (hSMCEntryFast == INVALID_HANDLE || hSMCEntrySlow == INVALID_HANDLE)) ||
        (cfg.InpSMCDungLocRSI && hSMCRSI == INVALID_HANDLE))) ||
      (cfg.InpUsePVEMAModule &&
       (hPVTrendFast == INVALID_HANDLE || hPVTrendSlow == INVALID_HANDLE ||
        hPVEntryFast == INVALID_HANDLE || hPVEntrySlow == INVALID_HANDLE ||
        hPVEntryATR == INVALID_HANDLE || hPVTrendADX == INVALID_HANDLE)) ||
      (PVUseEngulfing() && hPVEngATR == INVALID_HANDLE) ||
      (PVUsePinBar() && hPVPinATR == INVALID_HANDLE))
   {
      Print("Khong tao duoc indicator handles: ", GetLastError());
      return INIT_FAILED;
   }
   g_lastBar = iTime(_Symbol, g_tf, 0);
   g_lastICTBar = iTime(_Symbol, g_ictTF, 0);
   g_lastMMBar = iTime(_Symbol, g_mmTF, 0);
   g_lastSMCBar = iTime(_Symbol, g_smcTF, 0);
   g_lastPVEMABar = iTime(_Symbol, cfg.InpPVKhungVaoLenh, 0);
   g_lastPVEngBar = iTime(_Symbol, cfg.InpPVKhungNhanChim, 0);
   g_lastPVPinBar = iTime(_Symbol, cfg.InpPVKhungPinBar, 0);
   g_lastPVBRKBar = iTime(_Symbol, cfg.InpPVKhungBreakout, 0);
   g_lastPVLQBar = iTime(_Symbol, cfg.InpPVKhungQuetThanhKhoan, 0);
   g_lastPVPivotBar = iTime(_Symbol, cfg.InpPVKhungXacNhanPivot, 0);
   ClearSetup(g_ictSetup); ClearSetup(g_mmSetup); ClearSetup(g_smcSetup);
   ClearEMARetestSetup(); g_mmContext.active = false; g_mmContext.nextLeg = 0;
   return INIT_SUCCEEDED;
}

void Step()
{
   ProcessAdditionalSignals();

   datetime ictBar = iTime(_Symbol, g_ictTF, 0);
   if(cfg.InpUseICTModule && ictBar > 0 && ictBar != g_lastICTBar)
   {
      g_lastICTBar = ictBar;
      if(!g_ictSetup.active || SetupExpired(g_ictSetup, g_ictTF))
      {
         g_status = "ICT: chưa hình thành setup hợp lệ";
         bool built = BuildICTSetup();
         if(built)
            ResearchEvent(g_ictSetup.model, "", "SETUP_CREATED", "READY",
                          "Chờ giá hồi vào vùng ICT", g_ictSetup.buy ? 1 : -1,
                          g_ictSetup.created, g_ictTF, 0.0, g_ictSetup.stop, 0.0,
                          0.0, "zone_low=" +
                          DoubleToString(g_ictSetup.zoneLow, _Digits) +
                          "|zone_high=" +
                          DoubleToString(g_ictSetup.zoneHigh, _Digits) +
                          "|expiry_bars=" +
                          IntegerToString(g_ictSetup.expiryBars));
         else if(cfg.InpGhiTinHieuBiLoai)
            ResearchEvent("ICT", "", "SETUP_SCAN", "NO_SETUP",
                          g_status, 0, ictBar, g_ictTF);
      }
   }
   datetime mmBar = iTime(_Symbol, g_mmTF, 0);
   if(cfg.InpUseMMModule && mmBar > 0 && mmBar != g_lastMMBar)
   {
      g_lastMMBar = mmBar;
      if(!g_mmSetup.active || SetupExpired(g_mmSetup, g_mmTF))
      {
         g_status = "Market Maker: chưa hình thành setup hợp lệ";
         bool built = BuildMMSetup();
         if(built)
            ResearchEvent(g_mmSetup.model, "", "SETUP_CREATED", "READY",
                          "Chờ giá hồi vào vùng Market Maker",
                          g_mmSetup.buy ? 1 : -1, g_mmSetup.created, g_mmTF,
                          0.0, g_mmSetup.stop, 0.0, 0.0,
                          "zone_low=" +
                          DoubleToString(g_mmSetup.zoneLow, _Digits) +
                          "|zone_high=" +
                          DoubleToString(g_mmSetup.zoneHigh, _Digits) +
                          "|expiry_bars=" +
                          IntegerToString(g_mmSetup.expiryBars));
         else if(cfg.InpGhiTinHieuBiLoai)
            ResearchEvent("MM", "", "SETUP_SCAN", "NO_SETUP",
                          g_status, 0, mmBar, g_mmTF);
      }
   }

   datetime smcBar = iTime(_Symbol, g_smcTF, 0);
   if(cfg.InpUseSMCModule && smcBar > 0 && smcBar != g_lastSMCBar)
   {
      g_lastSMCBar = smcBar;
      if(!g_smcSetup.active || SetupExpired(g_smcSetup, g_smcTF))
      {
         g_status = "SMC: chưa hình thành setup hợp lệ";
         bool built = BuildSMCSetup();
         if(built)
            ResearchEvent(g_smcSetup.model, "", "SETUP_CREATED", "READY",
                          "Chờ giá hồi vào vùng SMC",
                          g_smcSetup.buy ? 1 : -1,
                          g_smcSetup.created, g_smcTF, 0.0,
                          g_smcSetup.stop, 0.0, 0.0,
                          "zone_low=" +
                          DoubleToString(g_smcSetup.zoneLow, _Digits) +
                          "|zone_high=" +
                          DoubleToString(g_smcSetup.zoneHigh, _Digits) +
                          "|expiry_bars=" +
                          IntegerToString(g_smcSetup.expiryBars) +
                          (g_smcSetupDetails == ""
                           ? "" : "|" + g_smcSetupDetails));
         else if(cfg.InpGhiTinHieuBiLoai)
            ResearchEvent("SMC", "", "SETUP_SCAN", "NO_SETUP",
                          g_status, 0, smcBar, g_smcTF,
                          0.0, 0.0, 0.0, 0.0, g_smcSetupDetails);
      }
   }
   TryEnterSetup(g_ictSetup, g_ictTF, cfg.InpICTRR,
                 cfg.InpMaxSLPriceDistance, SETUP_ENGINE_ICT);
   TryEnterSetup(g_mmSetup, g_mmTF, cfg.InpMMRR,
                 cfg.InpMaxSLPriceDistance, SETUP_ENGINE_MM);
   TryEnterSetup(g_smcSetup, g_smcTF, cfg.InpSMCRR,
                 cfg.InpMaxSLPriceDistance, SETUP_ENGINE_SMC);

   datetime bar = iTime(_Symbol, g_tf, 0);
   if(cfg.InpUseEMAModule && bar > 0)
   {
      double fastEMA = 0.0, slowEMA = 0.0;
      if(ReadCurrentEMAValues(fastEMA, slowEMA))
      {
         double currentDiff = fastEMA - slowEMA;
         if(!g_havePreviousEMADiff)
         {
            g_previousEMADiff = currentDiff;
            g_havePreviousEMADiff = true;
         }
         else
         {
            double previousDiff = g_previousEMADiff;
            bool buy = (previousDiff <= 0.0 && currentDiff > 0.0);
            bool sell = (previousDiff >= 0.0 && currentDiff < 0.0);
            g_previousEMADiff = currentDiff;
            if((buy || sell) && g_lastSignalBar != bar)
            {
               int secondsPerBar = PeriodSeconds(g_tf);
               bool recentLiveCross = cfg.InpUseWaveFilter && cfg.InpRecentCrossBars > 0 &&
                  g_lastSignalBar > 0 && secondsPerBar > 0 &&
                  (bar - g_lastSignalBar) < (long)cfg.InpRecentCrossBars * secondsPerBar;
               string biasDetails = "";
               bool biasOK = EMABiasAllows(buy, biasDetails);
               RecordEMACrossCandidate(buy, TimeCurrent(), previousDiff,
                                       currentDiff, false);
               string method = CoreEMAMethodName();
               if(recentLiveCross)
               {
                  g_status = "Bỏ qua: EMA M1 vừa cắt nhau liên tục";

                  ClearEMARetestSetup();
                  if(cfg.InpGhiTinHieuBiLoai)
                     ResearchEvent(method, "THUC_TE", "LIVE_DECISION",
                                   "REJECTED", g_status, buy ? 1 : -1,
                                   TimeCurrent(), g_tf);
               }
               else if(!biasOK)
               {
                  g_status = method + ": hướng " + (buy ? "BUY" : "SELL") +
                             " bị lọc bởi EMA " +
                             IntegerToString(cfg.InpEMANhanhLoc) + "/" +
                             IntegerToString(cfg.InpEMAChamLoc) + " " +
                             ShortTimeframeName(cfg.InpEMAKhungLoc);
                  ClearEMARetestSetup();
                  if(cfg.InpGhiTinHieuBiLoai)
                     ResearchEvent(method, "THUC_TE", "LIVE_DECISION",
                                   "REJECTED", g_status, buy ? 1 : -1,
                                   TimeCurrent(), g_tf, 0.0, 0.0, 0.0,
                                   0.0, biasDetails);
               }
               else if(cfg.InpEMAVaoSauRetest)
               {
                  CreateEMARetestSetup(buy, TimeCurrent(), bar,
                                       fastEMA, slowEMA);
               }
               else
               {
                  ulong oldTicket = 0, newTicket = 0;
                  bool hadPosition = SelectNewestMethodPosition("EMA_CORE", oldTicket);
                  EnterOnCross(buy, false);
                  bool hasPosition = SelectNewestMethodPosition("EMA_CORE", newTicket);
                  bool opened = hasPosition && (!hadPosition || newTicket != oldTicket);
                  if(!LAB_RESEARCH_ONLY && (opened || cfg.InpGhiTinHieuBiLoai))
                     ResearchEvent(method, "THUC_TE", "LIVE_DECISION",
                                   opened ? "OPENED" : "REJECTED", g_status,
                                   buy ? 1 : -1, TimeCurrent(), g_tf);
               }
               g_lastSignalBar = bar;
               DrawDashboard();
            }
         }
         if(cfg.InpEMAVaoSauRetest)
            ProcessEMARetestSetup(fastEMA, slowEMA);
      }
   }
   if(bar != g_lastBar)
   {
      g_lastBar = bar;
      DrawDashboard();
   }
}

void Release()
{
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hEMABiasFast != INVALID_HANDLE) IndicatorRelease(hEMABiasFast);
   if(hEMABiasSlow != INVALID_HANDLE) IndicatorRelease(hEMABiasSlow);
   if(hICTATR != INVALID_HANDLE) IndicatorRelease(hICTATR);
   if(hMMATR != INVALID_HANDLE) IndicatorRelease(hMMATR);
   if(hSMCATR != INVALID_HANDLE) IndicatorRelease(hSMCATR);
   if(hSMCBiasFast != INVALID_HANDLE) IndicatorRelease(hSMCBiasFast);
   if(hSMCBiasSlow != INVALID_HANDLE) IndicatorRelease(hSMCBiasSlow);
   if(hSMCEntryFast != INVALID_HANDLE) IndicatorRelease(hSMCEntryFast);
   if(hSMCEntrySlow != INVALID_HANDLE) IndicatorRelease(hSMCEntrySlow);
   if(hSMCRSI != INVALID_HANDLE) IndicatorRelease(hSMCRSI);
   if(hPVTrendFast != INVALID_HANDLE) IndicatorRelease(hPVTrendFast);
   if(hPVTrendSlow != INVALID_HANDLE) IndicatorRelease(hPVTrendSlow);
   if(hPVEntryFast != INVALID_HANDLE) IndicatorRelease(hPVEntryFast);
   if(hPVEntrySlow != INVALID_HANDLE) IndicatorRelease(hPVEntrySlow);
   if(hPVEntryATR != INVALID_HANDLE) IndicatorRelease(hPVEntryATR);
   if(hPVTrendADX != INVALID_HANDLE) IndicatorRelease(hPVTrendADX);
   if(hPVEngATR != INVALID_HANDLE) IndicatorRelease(hPVEngATR);
   if(hPVPinATR != INVALID_HANDLE) IndicatorRelease(hPVPinATR);
   if(hSLAnalysisATR != INVALID_HANDLE) IndicatorRelease(hSLAnalysisATR);
   if(hSLAnalysisFast != INVALID_HANDLE) IndicatorRelease(hSLAnalysisFast);
   if(hSLAnalysisSlow != INVALID_HANDLE) IndicatorRelease(hSLAnalysisSlow);
}
   void ScheduledStep(const datetime now)
   {
      if(family==0) { Step(); return; } // Intrabar EMA cross/retest must retain every tick.
      bool active=(family==1 && g_ictSetup.active) || (family==2 && g_mmSetup.active) ||
                  (family==3 && g_smcSetup.active);
      if(!active && now<nextWake) return;
      Step();
      ENUM_TIMEFRAMES tf=g_tf;
      if(family==1)tf=g_ictTF; else if(family==2)tf=g_mmTF; else if(family==3)tf=g_smcTF;
      else if(family==4)tf=cfg.InpPVKhungVaoLenh; else if(family==5)tf=cfg.InpPVKhungNhanChim;
      else if(family==6)tf=cfg.InpPVKhungPinBar; else if(family==7)tf=cfg.InpPVKhungBreakout;
      else if(family==8)tf=cfg.InpPVKhungQuetThanhKhoan; else if(family==9)tf=cfg.InpPVKhungXacNhanPivot;
      if(tf==PERIOD_CURRENT)tf=(ENUM_TIMEFRAMES)_Period;
      int seconds=PeriodSeconds(tf);
      datetime bar=iTime(_Symbol,tf,0);
      nextWake=(bar>0 && seconds>0)?bar+seconds:now+1;
      if(nextWake<=now) nextWake=now+1;
      if(seconds>=86400 && nextWake>now+60)nextWake=now+60;
   }
};



CDHSignalEngine *g_engines[];
MatrixConfig g_base;
int g_walletStart[], g_walletCount[];
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
double g_moneyFactor=1.0, g_minLot=0.0, g_lotStep=0.0, g_maxLot=0.0, g_priceStep=0.0;
double g_buyUp=0.0,g_buyDown=0.0,g_sellUp=0.0,g_sellDown=0.0;
double g_swapLong=0.0,g_swapShort=0.0,g_swapDays[7];
int g_swapMode=0, g_monthSlot=-1, g_dayKey=0;
datetime g_firstTick=0,g_lastTick=0,g_lastEquityLog=0,g_lastBarLog=0,g_dayStart=0;
ulong g_lastFlush=0,g_lastPanel=0;
int g_hTrades=INVALID_HANDLE,g_hEvents=INVALID_HANDLE,g_hEquity=INVALID_HANDLE;
int g_hBars=INVALID_HANDLE,g_hConfig=INVALID_HANDLE,g_hWallet=INVALID_HANDLE;
int g_hAudit=INVALID_HANDLE;
int g_delayEvents=0,g_nativeOperationErrors=0,g_nativeRequestCount=0;
double g_nativeInitialBalance=0.0,g_nativeDealsNet=0.0,g_nativeReconcileGap=0.0;
bool g_nativeHistoryOK=false;

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
void MXFail(const string why)
{
   if(!g_fatal) Print("V4.39 DỪNG: ",why);
   g_fatal=true;
}
int MXFile(const string kind,const string header)
{
   int h=FileOpen(g_runFolder+"\\"+kind+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(h==INVALID_HANDLE) { MXFail("Không mở được "+kind+"; lỗi="+IntegerToString(GetLastError())); return h; }
   FileWriteString(h,header+"\r\n");
   return h;
}
void MXFlush()
{
   if(g_hTrades!=INVALID_HANDLE) FileFlush(g_hTrades);
   if(g_hEvents!=INVALID_HANDLE) FileFlush(g_hEvents);
   if(g_hEquity!=INVALID_HANDLE) FileFlush(g_hEquity);
   if(g_hBars!=INVALID_HANDLE) FileFlush(g_hBars);
   if(g_hAudit!=INVALID_HANDLE) FileFlush(g_hAudit);
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
   if(!g_finished && MXRequestMoved(before,after,dealMsc,quoteOK))
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
void MXNativeOpen(const MXPosition &p)
{
   if(!MQLInfoInteger(MQL_TESTER) || !InpMatrixLenhTester || p.wallet!=MXViThamChieu()) return;
   string comment="MX439|"+IntegerToString(p.id)+"|"+p.method;
   if(StringLen(comment)>31) comment=StringSubstr(comment,0,31);
   MqlTick before;
   if(!SymbolInfoTick(_Symbol,before)) {MXFail("Không lấy được giá trước gửi lệnh");return;}
   if(before.time_msc!=g_quote.time_msc || before.bid!=g_quote.bid || before.ask!=g_quote.ask)
      {g_delayEvents++;MXFail("Giá thay đổi trước gửi tham chiếu. Chọn No Delay.");return;}
   bool ok=p.buy?g_executor.Buy(p.initialLot,_Symbol,before.ask,p.initialSL,p.tp2,comment):
                 g_executor.Sell(p.initialLot,_Symbol,before.bid,p.initialSL,p.tp2,comment);
   bool auditOK=MXAuditRequest("OPEN",p.id,p.engine,g_executor.ResultOrder(),p.buy,before,ok);
   if(g_fatal)return;
   if(!auditOK)
   {
      g_wallets[p.wallet].nativeErrors++;
      MatrixEvent(p.engine,p.method,"NATIVE_OPEN","ERROR",g_executor.ResultRetcodeDescription(),p.signalTime,comment);
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
   if(ticket==0 || !PositionSelectByTicket(ticket)) { MXFail("Không tìm được vị thế tham chiếu vừa khớp"); return; }
   if(MathAbs(PositionGetDouble(POSITION_VOLUME)-p.initialLot)>g_lotStep*0.1)
      {MXFail("Khớp thiếu khối lượng tham chiếu, dừng để đối chiếu trước khi xếp hạng");return;}
   MXNative n; ZeroMemory(n);
   n.shadowID=p.id;n.engine=p.engine;n.method=p.method;
   n.ticket=ticket; n.buy=p.buy; n.entry=PositionGetDouble(POSITION_PRICE_OPEN);
   n.risk=MathAbs(n.entry-p.initialSL); n.tp1=n.buy?n.entry+n.risk*InpTP1AtR:n.entry-n.risk*InpTP1AtR;
   n.tp2=PositionGetDouble(POSITION_TP); n.part=p.part;
   if(MathAbs(n.entry-(p.buy?before.ask:before.bid))>InpTruotGiaToiDaGia+g_priceStep*0.5)
   {
      MatrixEvent(p.engine,p.method,"NATIVE_SLIPPAGE","ERROR","Khớp vượt độ lệch cho phép; yêu cầu đóng vị thế",p.signalTime,comment);
      MqlTick closeQuote;SymbolInfoTick(_Symbol,closeQuote);
      bool closed=g_executor.PositionClose(ticket);
      MXAuditRequest("SLIPPAGE_CLOSE",p.id,p.engine,ticket,!p.buy,closeQuote,closed);
      if(!closed || !MXNativeOK()) MXFail("Không đóng được lệnh trượt giá vượt giới hạn");
      g_wallets[p.wallet].nativeErrors++;
      MXFail("Tham chiếu trượt quá 0.30 giá, dừng đối chiếu để không xếp hạng dữ liệu lệch.");return;
   }
   int count=ArraySize(g_native); ArrayResize(g_native,count+1); g_native[count]=n;
}
void MXNativeManage()
{
   if(!MQLInfoInteger(MQL_TESTER) || !InpMatrixLenhTester) return;
   for(int i=ArraySize(g_native)-1;i>=0;i--)
   {
      MXNative n=g_native[i];
      if(!PositionSelectByTicket(n.ticket))
      {
         g_native[i]=g_native[ArraySize(g_native)-1]; ArrayResize(g_native,ArraySize(g_native)-1); continue;
      }
      double price=n.buy?g_quote.bid:g_quote.ask;
      if(InpUseTP1Partial && !n.partialDone && (n.buy?price>=n.tp1:price<=n.tp1))
      {
         double oldVolume=PositionGetDouble(POSITION_VOLUME);
         MqlTick before;SymbolInfoTick(_Symbol,before);
         bool ok=g_executor.PositionClosePartial(n.ticket,n.part);
         bool accepted=MXAuditRequest("TP1",n.shadowID,n.engine,n.ticket,!n.buy,before,ok);
         if(g_fatal)return;
         if(accepted)
         {
            double left=PositionSelectByTicket(n.ticket)?PositionGetDouble(POSITION_VOLUME):0.0;
            double done=MathMax(0.0,oldVolume-left);
            n.part=MathMax(0.0,n.part-done);n.partialDone=n.part<g_lotStep*0.5;
         }
      }
      if(!PositionSelectByTicket(n.ticket)) continue;
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
         MXAuditRequest("MODIFY_SL",n.shadowID,n.engine,n.ticket,n.buy,before,ok);
         if(g_fatal)return;
      }
      g_native[i]=n;
   }
}
void MXNativeCloseAll()
{
   if(!MQLInfoInteger(MQL_TESTER) || !InpMatrixLenhTester) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      MqlTick before;SymbolInfoTick(_Symbol,before);
      bool ok=g_executor.PositionClose(ticket);
      MXAuditRequest("FINAL_CLOSE",0,-1,ticket,!buy,before,ok);
      if(!ok || !MXNativeOK())
         Print("V4.39 không đóng được tham chiếu cuối test: ",ticket," ",g_executor.ResultRetcodeDescription());
   }
}
void MXClose(const int slot,const double price,const string reason)
{
   MXPosition p=g_positions[slot]; int w=p.wallet;
   double commission=InpMatrixPhiKhuHoiLot*p.left*0.5;
   double cash=MXProfit(p.buy,p.left,p.entry,price)-commission;
   p.net+=cash; MXCash(w,cash); g_wallets[w].commission+=commission;
   g_wallets[w].margin=MathMax(0.0,g_wallets[w].margin-p.margin);
   g_wallets[w].open--; g_wallets[w].openFamily[p.family]--; p.left=0.0;
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
      for(int w=0;w<ArraySize(g_wallets);w++) { g_wallets[w].dayStart=g_wallets[w].equity; g_wallets[w].dayEntries=0; }
      g_dayStart=midnight; g_dayKey=day;
   }
}
double MXLot(const int w,const bool buy,const double entry,const double sl)
{
   if(InpVolumeMode==LOT_CO_DINH) return MXFloorLot(InpGiaTriKhoiLuong);
   double budget=InpVolumeMode==LOT_THEO_PHAN_TRAM_TAI_KHOAN?
                   g_wallets[w].equity*InpGiaTriKhoiLuong/100.0:InpGiaTriKhoiLuong*g_moneyFactor;
   double one=-MXProfit(buy,1.0,entry,sl)+InpMatrixPhiKhuHoiLot;
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
   if(g_wallets[w].stopped || g_wallets[w].equity<=0.0) return;
   if(g_wallets[w].open>=InpMaxIndependentPositions || g_wallets[w].openFamily[family]>=InpMatrixLenhMoiPP)
      { MXReject(w,engine,method,"DA_CO_LENH"); return; }
   if(InpSoLenhToiDaMoiNgay>0 && g_wallets[w].dayEntries>=InpSoLenhToiDaMoiNgay)
      { MXReject(w,engine,method,"GIOI_HAN_LENH_NGAY"); return; }
   if(InpDailyLossPct>0.0 && g_wallets[w].equity<=g_wallets[w].dayStart*(1.0-InpDailyLossPct/100.0))
      { MXReject(w,engine,method,"GIOI_HAN_LO_NGAY"); return; }
   MXPosition p; ZeroMemory(p);
   p.wallet=w; p.engine=engine; p.family=family; p.id=g_nextPosition++;
   p.method=method; p.buy=buy; p.signalTime=signalTime; p.opened=g_quote.time;
   p.entry=MXPrice(baseEntry+(buy?1.0:-1.0)*InpMatrixTruotGiaVao,buy);
   p.initialSL=sl; p.sl=sl; p.risk=MathAbs(p.entry-sl);
   if(p.risk<InpMinSLPriceDistance-g_priceStep*0.5 || p.risk>InpMaxSLPriceDistance+g_priceStep*0.5)
      { MXReject(w,engine,method,"SL_NGOAI_5_20_GIA"); return; }
   double rr=MathAbs(tp-baseEntry)/MathAbs(baseEntry-sl);
   if(rr<1.0-1e-8) { MXReject(w,engine,method,"RR_DUOI_1"); return; }
   p.tp2=MXPrice(p.entry+(buy?1.0:-1.0)*rr*p.risk,buy);
   p.tp1=MXPrice(p.entry+(buy?1.0:-1.0)*InpTP1AtR*p.risk,buy);
   p.initialLot=MXLot(w,buy,p.entry,sl);
   if(p.initialLot<g_minLot-1e-8 || p.initialLot>g_maxLot+1e-8 || !MXSplit(p.initialLot,p.part))
      { MXReject(w,engine,method,"LOT_KHONG_HOP_LE_HOAC_KHONG_CHIA_DUOC_TP1"); return; }
   if(!OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,p.initialLot,p.entry,p.margin))
      { MXFail("Không tính được margin tại tín hiệu"); return; }
   double volumeLimit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT),sameLots=0.0;
   if(volumeLimit>0.0)
      for(int j=0;j<ArraySize(g_positions);j++)
         if(g_positions[j].wallet==w && g_positions[j].buy==buy) sameLots+=g_positions[j].left;
   if(volumeLimit>0.0 && sameLots+p.initialLot>volumeLimit+1e-8)
      { MXReject(w,engine,method,"GIOI_HAN_KHOI_LUONG_SAN"); return; }
   double fee=InpMatrixPhiKhuHoiLot*p.initialLot*0.5;
   double instant=MXProfit(buy,p.initialLot,p.entry,buy?g_quote.bid:g_quote.ask)-2.0*fee;
   if(g_wallets[w].equity+instant-g_wallets[w].margin<p.margin)
      { MXReject(w,engine,method,"THIEU_MARGIN"); return; }
   p.left=p.initialLot; p.net=-fee;
   MXCash(w,-fee); g_wallets[w].commission+=fee; g_wallets[w].lots+=p.initialLot;
   g_wallets[w].open++; g_wallets[w].openFamily[family]++; g_wallets[w].dayEntries++;
   g_wallets[w].margin+=p.margin;
   if(!g_wallets[w].listed)
   {
      int n=ArraySize(g_activeWallets); ArrayResize(g_activeWallets,n+1); g_activeWallets[n]=w; g_wallets[w].listed=true;
   }
   int n=ArraySize(g_positions); ArrayResize(g_positions,n+1,4096); g_positions[n]=p;
   g_wallets[w].floating+=MXProfit(buy,p.left,p.entry,buy?g_quote.bid:g_quote.ask)-fee;
   MXMark(w); MXTradeLog(p,"OPEN",p.entry,-fee,details);
   if(InpMatrixLenhTester && w==MXViThamChieu())
   {
      int q=ArraySize(g_nativeQueue);ArrayResize(g_nativeQueue,q+1);g_nativeQueue[q]=p;
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
   if(isBase) MXOpen(0,engine,family,method,buy,signalTime,entry,sl,tp,trace);
   int session=g_engines[engine].GetSession(g_quote.time);
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
// ---------- V4.39 MATRIX 7PP: bộ cài sẵn thay cho 13 file SET ----------
// Ứng viên hạng 1 và lưới lấy từ nghiên cứu Python (docs/david_hunter_v439 trong repo Davidtruong202).
bool MXPresetActive() { return InpMatrixBoCaiSan!=BO_THEO_INPUT; }
bool MXPresetFull() { return InpMatrixBoCaiSan>=BO_LUOI_DAY_DU_EMA && InpMatrixBoCaiSan<=BO_LUOI_DAY_DU_LQ; }
bool MXPresetBest() { return InpMatrixBoCaiSan==BO_HIEU_QUA_NHAT; }
int MXPresetFamily()
{
   switch(InpMatrixBoCaiSan)
   {
      case BO_HIEU_QUA_NHAT: return 0;
      case BO_KIEM_CHUNG_EMA: case BO_LUOI_DAY_DU_EMA: return 0;
      case BO_KIEM_CHUNG_ICT: case BO_LUOI_DAY_DU_ICT: return 1;
      case BO_LUOI_DAY_DU_MM: return 2;
      case BO_KIEM_CHUNG_SMC: case BO_LUOI_DAY_DU_SMC: return 3;
      case BO_KIEM_CHUNG_PVEMA: case BO_LUOI_DAY_DU_PVEMA: return 4;
      case BO_KIEM_CHUNG_PIN: case BO_LUOI_DAY_DU_PIN: return 6;
      case BO_KIEM_CHUNG_LQ: case BO_LUOI_DAY_DU_LQ: return 8;
   }
   return -1;
}
bool MXPresetUses(const int f)
{
   if(InpMatrixBoCaiSan==BO_KIEM_CHUNG_6PP)
      return f==0 || f==1 || f==3 || f==4 || f==6 || f==8;
   return f==MXPresetFamily();
}
// Input gốc của từng PP khi kiểm chứng = ứng viên hạng 1; lưới đầy đủ giữ input mặc định V4.39.
string MXPresetBase(const int f)
{
   if(!MXPresetActive() || MXPresetFull()) return "";
   if(MXPresetBest()) return f==0?"InpTimeframe=M1|InpFastEMA=7|InpSlowEMA=50|InpEMAKhungLoc=M15|InpEMAKhoangDiXaToiThieuATR=0.35|InpMinDirectionEfficiency=0.1|InpEMAMucRetest=0":""; // EMA bộ hiệu quả nhất
   if(f==0) return "InpTimeframe=M1|InpFastEMA=12|InpSlowEMA=34|InpEMAKhungLoc=M15|InpEMAKhoangDiXaToiThieuATR=0.35|InpMinDirectionEfficiency=0.22|InpEMAMucRetest=0"; // EMA
   if(f==1) return "InpICTEntryTF=M1|InpICTBiasTF=M30|InpICTDisplacementATR=0.9|InpICTMinFVG_ATR=0.05|InpICTPriority=0|InpICTSetupExpiryBars=12"; // ICT
   if(f==3) return "InpSMCEntryTF=M1|InpSMCBiasTF=M15|InpSMCDisplacementATR=1.2|InpSMCMinFVGATR=0.03|InpSMCDungLocEMAH1=false|InpSMCDungLocEMAM5=false|InpSMCDungLocRSI=true"; // SMC
   if(f==4) return "InpPVKhungVaoLenh=M6|InpPVKhungXuHuong=M30|InpPVADXToiThieu=14|InpPVSoNenTimSL=10|InpPVDungSaiHoiATR=0.25|InpPVThanNenToiThieu=0.3"; // PVEMA
   if(f==6) return "InpPVKhungPinBar=M1|InpPVRauChinhTrenThan=3.4|InpPVPinQuetSoNen=3|InpPVPinMinATR=1|InpPVPinMaxATR=2.5|InpPVSoNenTimSL=10"; // PIN
   if(f==8) return "InpPVKhungQuetThanhKhoan=M4|InpPVDoXuyenToiThieuGia=0.7|InpPVDoXuyenToiDaGia=2|InpPVSoNenThanhKhoan=6|InpPVRauQuetTrenThan=3|InpPVSoNenTimSL=5"; // LQ
   return "";
}
string MXPresetGrid(const int f)
{
   if(!MXPresetUses(f) || MXPresetBest()) return ""; // bộ hiệu quả nhất: 1 bộ, không lưới
   if(MXPresetFull())
   {
      if(f==0) return "InpTimeframe=M1,M2,M3,M5|InpFastEMA=7,12|InpSlowEMA=21,34,50|InpEMAKhungLoc=M5,M15|InpEMAKhoangDiXaToiThieuATR=0.35,1.0|InpMinDirectionEfficiency=0.1,0.22|InpEMAMucRetest=0,1"; // EMA
      if(f==1) return "InpICTEntryTF=M1,M2,M3,M5,M15|InpICTBiasTF=M15,M30,H1|InpICTDisplacementATR=0.6,0.9,1.2|InpICTMinFVG_ATR=0.05,0.1|InpICTPriority=0,1,2,3|InpICTSetupExpiryBars=12,24"; // ICT
      if(f==2) return "InpMMEntryTF=M1,M3,M5,M15|InpMMBiasTF=M30,H1|InpMMDisplacementATR=0.7,1.0,1.3|InpMMMinFVG_ATR=0.03,0.08|InpMMPremiumLevel=0.62,0.7|InpMMDiscountLevel=0.3,0.38|InpMMUseLeg1=true,false"; // MM
      if(f==3) return "InpSMCEntryTF=M1,M2,M3,M5,M15|InpSMCBiasTF=M15,M30,H1|InpSMCDisplacementATR=0.6,0.9,1.2|InpSMCMinFVGATR=0.03,0.08|InpSMCDungLocEMAH1=true,false|InpSMCDungLocEMAM5=true,false|InpSMCDungLocRSI=true,false"; // SMC
      if(f==4) return "InpPVKhungVaoLenh=M3,M4,M5,M6,M10,M15|InpPVKhungXuHuong=M15,M30,H1|InpPVADXToiThieu=14,20,25|InpPVSoNenTimSL=5,10|InpPVDungSaiHoiATR=0.25,0.5|InpPVThanNenToiThieu=0.3,0.5"; // PVEMA
      if(f==6) return "InpPVKhungPinBar=M1,M2,M3,M4,M5,M6,M10,M15|InpPVRauChinhTrenThan=1.8,2.2,2.8,3.4|InpPVPinQuetSoNen=3,6,10|InpPVPinMinATR=1.0,1.3|InpPVPinMaxATR=1.8,2.5|InpPVSoNenTimSL=5,10"; // PIN
      if(f==8) return "InpPVKhungQuetThanhKhoan=M1,M2,M3,M4,M5,M6,M10,M15|InpPVDoXuyenToiThieuGia=0.3,0.5,0.7|InpPVDoXuyenToiDaGia=1.0,2.0,3.0|InpPVSoNenThanhKhoan=6,12|InpPVRauQuetTrenThan=1.5,2.0,3.0|InpPVSoNenTimSL=5,10"; // LQ
      return "";
   }
   if(f==0) return "InpTimeframe=M1,M2|InpFastEMA=7,12|InpSlowEMA=34,50|InpEMAKhungLoc=M5,M15|InpMinDirectionEfficiency=0.1,0.22"; // EMA
   if(f==1) return "InpICTEntryTF=M1,M2|InpICTBiasTF=M15,M30,H1|InpICTDisplacementATR=0.6,0.9,1.2|InpICTPriority=0,2,3"; // ICT
   if(f==3) return "InpSMCEntryTF=M1,M2,M3|InpSMCBiasTF=M15,M30|InpSMCDisplacementATR=0.9,1.2|InpSMCDungLocEMAH1=true,false|InpSMCDungLocRSI=true,false"; // SMC
   if(f==4) return "InpPVKhungVaoLenh=M5,M6,M10|InpPVKhungXuHuong=M30,H1|InpPVADXToiThieu=14,20|InpPVSoNenTimSL=5,10"; // PVEMA
   if(f==6) return "InpPVKhungPinBar=M1,M2|InpPVRauChinhTrenThan=2.8,3.4,4.0|InpPVPinQuetSoNen=3,6|InpPVSoNenTimSL=5,10"; // PIN
   if(f==8) return "InpPVKhungQuetThanhKhoan=M1,M4|InpPVDoXuyenToiThieuGia=0.5,0.7|InpPVDoXuyenToiDaGia=1.0,2.0|InpPVSoNenThanhKhoan=6,12|InpPVRauQuetTrenThan=2.0,3.0"; // LQ
   return "";
}
// Ví của ứng viên trong 12 ví của bộ gốc: d = 0 cả 2 hướng / 1 BUY / 2 SELL; s = 0 cả ngày / 1 Á / 2 Âu / 3 Mỹ.
bool MXPresetWallet(const int f,int &d,int &s)
{
   d=0; s=0;
   if(!MXPresetActive() || MXPresetFull()) return false;
   if(MXPresetBest()) { d=2; s=1; return f==0; } // SELL/A
   if(f==0) { d=0; s=0; return true; } // EMA BUY_SELL/TAT_CA
   if(f==1) { d=0; s=2; return true; } // ICT BUY_SELL/AU
   if(f==3) { d=1; s=2; return true; } // SMC BUY/AU
   if(f==4) { d=0; s=1; return true; } // PVEMA BUY_SELL/A
   if(f==6) { d=0; s=0; return true; } // PIN BUY_SELL/TAT_CA
   if(f==8) { d=0; s=2; return true; } // LQ BUY_SELL/AU
   return false;
}
string MXPresetPython(const int f)
{
   if(MXPresetBest()) return "MT5 01/01-27/09/2026 vi 166: 116 lenh, WR 62.9%, PF 1.69, net +349.0 USD lot 0.02, lai 9/9 thang";
   if(f==0) return "Python 01-12/01/2026: 31 lenh, WR 67.7%, PF 2.41, net +141.6 USD lot 0.02"; // EMA
   if(f==1) return "Python 01-12/01/2026: 11 lenh, WR 81.8%, PF 3.99, net +79.9 USD lot 0.02"; // ICT
   if(f==3) return "Python 01-12/01/2026: 10 lenh, WR 90.0%, PF 11.23, net +102.3 USD lot 0.02"; // SMC
   if(f==4) return "Python 01-12/01/2026: 12 lenh, WR 91.7%, PF 24.50, net +246.5 USD lot 0.02"; // PVEMA
   if(f==6) return "Python 01-12/01/2026: 44 lenh, WR 65.9%, PF 2.17, net +199.0 USD lot 0.02"; // PIN
   if(f==8) return "Python 01-12/01/2026: 17 lenh, WR 82.4%, PF 5.19, net +146.5 USD lot 0.02"; // LQ
   return "";
}
string MXPresetFolder()
{
   switch(InpMatrixBoCaiSan)
   {
      case BO_KIEM_CHUNG_6PP: return "DH_V439_7PP_KiemChung_6PP";
      case BO_HIEU_QUA_NHAT: return "DH_V439_7PP_HieuQuaNhat";
      case BO_KIEM_CHUNG_EMA: return "DH_V439_7PP_KiemChung_EMA";
      case BO_KIEM_CHUNG_ICT: return "DH_V439_7PP_KiemChung_ICT";
      case BO_KIEM_CHUNG_SMC: return "DH_V439_7PP_KiemChung_SMC";
      case BO_KIEM_CHUNG_PVEMA: return "DH_V439_7PP_KiemChung_PVEMA";
      case BO_KIEM_CHUNG_PIN: return "DH_V439_7PP_KiemChung_PIN";
      case BO_KIEM_CHUNG_LQ: return "DH_V439_7PP_KiemChung_LQ";
      case BO_LUOI_DAY_DU_EMA: return "DH_V439_7PP_LuoiDayDu_EMA";
      case BO_LUOI_DAY_DU_ICT: return "DH_V439_7PP_LuoiDayDu_ICT";
      case BO_LUOI_DAY_DU_MM: return "DH_V439_7PP_LuoiDayDu_MM";
      case BO_LUOI_DAY_DU_SMC: return "DH_V439_7PP_LuoiDayDu_SMC";
      case BO_LUOI_DAY_DU_PVEMA: return "DH_V439_7PP_LuoiDayDu_PVEMA";
      case BO_LUOI_DAY_DU_PIN: return "DH_V439_7PP_LuoiDayDu_PIN";
      case BO_LUOI_DAY_DU_LQ: return "DH_V439_7PP_LuoiDayDu_LQ";
   }
   return InpMatrixThuMuc;
}
int MXMaxBo() { return MXPresetActive()?1024:InpMatrixToiDaBo; }
int MXMaxVi() { return MXPresetActive()?12289:InpMatrixToiDaVi; }
bool MXQuetLuoi() { return MXPresetActive() || InpMatrixQuetLuoi; }
bool MXTachHuongPhien() { return MXPresetActive() || InpMatrixTachHuongPhien; }
// Ghi input gốc của bộ cài sẵn vào cấu hình gốc của PP, cùng bộ đọc với lưới (MXNumber + MatrixSetValue).
bool MXApplyPresetBase(MatrixConfig &c,const int family)
{
   string text=MXTrim(MXPresetBase(family));
   if(text=="") return true;
   string items[]; int count=StringSplit(text,'|',items);
   for(int i=0;i<count;i++)
   {
      string kv[]; double v=0.0;
      if(StringSplit(items[i],'=',kv)!=2 || !MXNumber(kv[1],v) || !MatrixSetValue(c,MXTrim(kv[0]),v))
         {MXFail("Bộ cài sẵn có input không hợp lệ: "+items[i]);return false;}
   }
   return true;
}

void MXOneFamily(MatrixConfig &c,const int family)
{
   c.InpUseEMAModule=family==0; c.InpUseICTModule=family==1;
   c.InpUseMMModule=family==2; c.InpUseSMCModule=family==3;
   c.InpUsePVEMAModule=family==4; c.InpUseENGModule=family==5;
   c.InpUsePINModule=family==6; c.InpUseBRKModule=family==7;
   c.InpUseLQModule=family==8; c.InpUsePVTModule=family==9;
   c.InpPVCachKetHop=PV_MOI_PP_DOC_LAP; c.InpPVMauPriceAction=PV_CA_BA_MAU;
}
bool MXEnabled(const int f)
{
   if(MXPresetActive()) return MXPresetUses(f);
   if(f==0) return InpUseEMAModule; if(f==1) return InpUseICTModule;
   if(f==2) return InpUseMMModule; if(f==3) return InpUseSMCModule;
   if(f==4) return InpUsePVEMAModule; if(f==5) return InpUseENGModule;
   if(f==6) return InpUsePINModule; if(f==7) return InpUseBRKModule;
   if(f==8) return InpUseLQModule; return InpUsePVTModule;
}
string MXGrid(const int f)
{
   if(MXPresetActive()) return MXPresetGrid(f);
   if(f==0)return InpLuoiEMA; if(f==1)return InpLuoiICT; if(f==2)return InpLuoiMM;
   if(f==3)return InpLuoiSMC; if(f==4)return InpLuoiPVEMA; if(f==5)return InpLuoiENG;
   if(f==6)return InpLuoiPIN; if(f==7)return InpLuoiBRK; if(f==8)return InpLuoiLQ; return InpLuoiPVT;
}
int MXAddWallet(const int engine,const int direction,const int session)
{
   int w=ArraySize(g_wallets);
   if(w>=MXMaxVi()) { MXFail("Vượt giới hạn tài khoản mô phỏng; giảm lưới hoặc tăng giới hạn"); return -1; }
   MXWallet p; ZeroMemory(p); p.engine=engine; p.direction=direction; p.session=session;
   p.initial=InpMatrixVonMoiVi>0.0?InpMatrixVonMoiVi:AccountInfoDouble(ACCOUNT_BALANCE);
   p.balance=p.initial; p.equity=p.initial; p.peak=p.initial; p.dayStart=p.initial;
   ArrayResize(g_wallets,w+1,2048); g_wallets[w]=p;
   FileWrite(g_hWallet,w,engine,MXDirection(direction),MXSession(session),MXMoney(p.initial),g_currency,
             w==MXViThamChieu()?"NATIVE_REFERENCE":"VIRTUAL_INDEPENDENT");
   return w;
}
bool MXAddEngine(const MatrixConfig &cfg,const int family,const bool base,const string axis)
{
   int n=ArraySize(g_engines);
   if(n>=MXMaxBo()) { MXFail("Lưới vượt giới hạn bộ tín hiệu. Không tự cắt bớt để tránh bỏ sót tổ hợp."); return false; }
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
   ArrayResize(g_walletStart,n+1); ArrayResize(g_walletCount,n+1);
   g_walletStart[n]=ArraySize(g_wallets);
   for(int d=0;d<(MXTachHuongPhien()?3:1);d++)
      for(int s=0;s<(MXTachHuongPhien()?4:1);s++)
         if(MXAddWallet(n,d,s)<0) return false;
   g_walletCount[n]=ArraySize(g_wallets)-g_walletStart[n];
   FileWrite(g_hConfig,n,MXFamily(family),base?"BASE":"GRID",axis,MatrixConfigText(cfg));
   return true;
}
bool MXBuildFamily(const int family)
{
   MatrixConfig base=g_base; MXOneFamily(base,family);
   if(!MXApplyPresetBase(base,family)) return false;
   if(!MXAddEngine(base,family,true,"BASE")) return false;
   if(!MXQuetLuoi() || MXTrim(MXGrid(family))=="") return true;
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
      if(combinations>MXMaxBo()) {MXFail("Một phương pháp có quá nhiều tổ hợp; giảm số giá trị mỗi trục");return false;}
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
      if(!MXAddEngine(cfg,family,false,desc)) return false;
   }
   return true;
}

void MXLogBars()
{
   if(g_hBars==INVALID_HANDLE) return;
   datetime bar=iTime(_Symbol,PERIOD_M1,1);
   if(bar<=0 || bar==g_lastBarLog) return;
   int count=1;
   if(g_lastBarLog>0) count=(int)MathMax(1,iBarShift(_Symbol,PERIOD_M1,g_lastBarLog,false)-1);
   MqlRates r[]; ArraySetAsSeries(r,true); int n=CopyRates(_Symbol,PERIOD_M1,1,count,r);
   if(n<1)return;
   for(int i=n-1;i>=0;i--) FileWrite(g_hBars,MXTime(r[i].time),DoubleToString(r[i].open,_Digits),
      DoubleToString(r[i].high,_Digits),DoubleToString(r[i].low,_Digits),DoubleToString(r[i].close,_Digits),r[i].tick_volume,r[i].spread);
   g_lastBarLog=bar;
}
void MXLogEquity(const bool force=false)
{
   if(g_hEquity==INVALID_HANDLE) return;
   if(!force && g_lastEquityLog>0 && g_quote.time-g_lastEquityLog<InpMatrixGhiEquityPhut*60) return;
   for(int w=0;w<ArraySize(g_wallets);w++) FileWrite(g_hEquity,MXTime(g_quote.time),w,MXMoney(g_wallets[w].balance),
      MXMoney(g_wallets[w].equity),MXMoney(g_wallets[w].ddPct),g_wallets[w].open,g_currency);
   g_lastEquityLog=g_quote.time;
}
void MXPanel()
{
   if(!InpMatrixBangNhe || !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   ulong now=GetTickCount64(); if(now-g_lastPanel<1000) return; g_lastPanel=now;
   int r=MXViThamChieu(); if(r<0 || r>=ArraySize(g_wallets))return;
   Comment("DAVID HUNTER V4.39 MATRIX | CHỈ TESTER\n",
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
   if(MXPresetActive() && !MXPresetFull())
   {
      // V4.39 MATRIX 7PP: một dòng cho ví ứng viên của mỗi PP, để đọc nhanh không cần lọc xep_hang.
      int hc=MXFile("ket_qua_ung_vien","phuong_phap;wallet_id;huong;phien;input_goc_ung_vien;lenh_dong;lenh_thang;winrate_pct;profit_factor;net;dd_equity_pct;thua_lien_tiep;thang_lai;so_thang;holdout_n;holdout_net;danh_gia;so_sanh_python;tien_te");
      if(hc!=INVALID_HANDLE)
      {
         for(int e=0;e<ArraySize(g_engines);e++)
         {
            int d=0,s=0,f=g_engines[e].family;
            if(!g_engines[e].isBase || !MXPresetWallet(f,d,s)) continue;
            int w=g_walletStart[e]+(MXTachHuongPhien()?d*4+s:0);
            if(w<0 || w>=ArraySize(g_wallets)) continue;
            MXWallet p=g_wallets[w];
            FileWrite(hc,MXFamily(f),w,MXDirection(p.direction),MXSession(p.session),MXPresetBase(f),
               p.all.trades,p.all.wins,MXMoney(MXWR(p.all)),MXMoney(MXPF(p.all)),MXMoney(p.all.net),MXMoney(p.ddPct),
               p.all.maxStreak,MXPositiveMonths(w),ArraySize(g_monthKeys),p.holdout.trades,MXMoney(p.holdout.net),
               MXQualification(w),MXPresetPython(f),g_currency);
         }
         FileClose(hc);
      }
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
      FileWrite(h,"version","4.39 MATRIX 7PP"); FileWrite(h,"preset",EnumToString(InpMatrixBoCaiSan)); FileWrite(h,"status",status); FileWrite(h,"symbol",_Symbol);
      FileWrite(h,"server",AccountInfoString(ACCOUNT_SERVER));FileWrite(h,"currency",g_currency);
      FileWrite(h,"account_units_per_real_unit",MXMoney(g_moneyFactor));
      FileWrite(h,"first_tick",MXTime(g_firstTick));FileWrite(h,"last_tick",MXTime(g_lastTick));
      FileWrite(h,"engines",ArraySize(g_engines));FileWrite(h,"wallets",n);
      FileWrite(h,"reference_wallet",MXViThamChieu());FileWrite(h,"native_orders_enabled",InpMatrixLenhTester);
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
      FileWrite(h,"reference_shadow_net",MXMoney(g_wallets[MXViThamChieu()].all.net));
      FileWrite(h,"native_net_minus_shadow_net",MXMoney(AccountInfoDouble(ACCOUNT_BALANCE)-g_nativeInitialBalance-g_wallets[MXViThamChieu()].all.net));
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
      FileWrite(h,"split_direction_session",MXTachHuongPhien());
      FileWrite(h,"grid_enabled",MXQuetLuoi());
      FileWrite(h,"equity_log_minutes",InpMatrixGhiEquityPhut);
      FileWrite(h,"volume_min",g_minLot);FileWrite(h,"volume_step",g_lotStep);FileWrite(h,"volume_max",g_maxLot);
      FileWrite(h,"tick_size",g_priceStep);FileWrite(h,"point",_Point);
      FileWrite(h,"entry_slippage_price",InpMatrixTruotGiaVao);
      FileWrite(h,"holdout_entry_date",MXTime(InpMatrixTuNgayKiemChung));
      FileWrite(h,"minimum_trades",InpMatrixSoLenhTinCay);FileWrite(h,"minimum_months",InpMatrixSoThangTinCay);
      FileWrite(h,"pf_minus_one_means","gross loss is zero: undefined/infinite, NOT a reliable winning setup");
      FileWrite(h,"limitations","Swap uses current broker snapshot, margin has no hedge offsets, commission is manual. Check native Report. MT5 may generate missing ticks. No guarantee of future profit.");
      FileWrite(h,"holdout_rule","Trades split by entry date. Monthly cash by posting date. Inspect overlapping trades at split. Never switch native reference to hindsight winner.");
      FileWrite(h,"matrix_scope","Cartesian product of configured axes for each family; direction/session are independent entry filters. Not all possible values; no cross-family portfolio Cartesian product; SMC L2 disabled.");
      FileClose(h);
   }
   Print("V4.39 đã xuất kết quả ",status," | ",ArraySize(g_engines)," bộ tín hiệu | ",n," tài khoản | ",g_runFolder);
}
void MXFinish(const string status)
{
   if(g_finished || !g_ready)return;
   g_finished=true;
   for(int i=ArraySize(g_positions)-1;i>=0;i--) MXClose(i,g_positions[i].buy?g_quote.bid:g_quote.ask,status=="COMPLETE"?"END_TEST":"STOPPED_EARLY");
   MXMarkAllActive(); MXNativeCloseAll(); MXLogEquity(true); MXExportResults(g_fatal?"ERROR":status); MXFlush();
}

int OnInit()
{
   // Two safety barriers: initialization + every native order function.
   if(!MQLInfoInteger(MQL_TESTER)) { Print("V4.39 chỉ được chạy trong Strategy Tester, không chạy tài khoản thật/demo.");return INIT_FAILED; }
   g_nativeInitialBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(MQLInfoInteger(MQL_OPTIMIZATION)) { Print("Chọn Optimization = Disabled. EA tự quét lưới bên trong một lượt.");return INIT_PARAMETERS_INCORRECT; }
   if(InpMatrixToiDaBo<1 || InpMatrixToiDaBo>1024 || InpMatrixToiDaVi<1 || InpMatrixToiDaVi>12289 ||
      InpMatrixLenhMoiPP<1 || InpMatrixLenhMoiPP>10 || InpMatrixSoLenhTinCay<1 || InpMatrixSoThangTinCay<1 ||
      InpMatrixPhiKhuHoiLot<0.0 || InpMatrixVonMoiVi<0.0 || InpMatrixHeSoTienThat<0.0 ||
      InpMatrixTruotGiaVao<0.0 || InpMatrixTruotGiaVao>0.30 || InpMatrixGhiEquityPhut<0 ||
      MXViThamChieu()<0) {Print("Thiết lập Matrix ngoài giới hạn");return INIT_PARAMETERS_INCORRECT;}
   if(InpMatrixLenhTester && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {Print("Tham chiếu nhiều phương pháp cần tài khoản Tester Hedging. Hoặc tắt lệnh tham chiếu để chỉ mô phỏng.");return INIT_PARAMETERS_INCORRECT;}
   if(InpMatrixLenhTester && InpMatrixVonMoiVi>0.0 && MathAbs(InpMatrixVonMoiVi-AccountInfoDouble(ACCOUNT_BALANCE))>0.01)
      {Print("Để đối chiếu công bằng: Vốn mỗi ví phải bằng Deposit Tester, hoặc để 0.");return INIT_PARAMETERS_INCORRECT;}
   int calc=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE);
   if(calc!=SYMBOL_CALC_MODE_FOREX && calc!=SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE &&
      calc!=SYMBOL_CALC_MODE_CFD && calc!=SYMBOL_CALC_MODE_CFDLEVERAGE && calc!=SYMBOL_CALC_MODE_CFDINDEX)
      {Print("V4.39 giới hạn sản phẩm Forex/CFD tuyến tính như XAUUSD; không hỗ trợ mode này.");return INIT_PARAMETERS_INCORRECT;}
   g_minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);g_maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);g_priceStep=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(g_minLot<=0.0 || g_lotStep<=0.0 || g_priceStep<=0.0)return INIT_FAILED;
   double part=0.0;
   if(InpVolumeMode==LOT_CO_DINH && (MathAbs(MXFloorLot(InpGiaTriKhoiLuong)-InpGiaTriKhoiLuong)>1e-8 ||
      InpGiaTriKhoiLuong<g_minLot || InpGiaTriKhoiLuong>g_maxLot || !MXSplit(InpGiaTriKhoiLuong,part)))
      {Print("Lot không hợp lệ hoặc không chia được TP1. Sàn bước 0.01: dùng lot 0.02 cho TP1 50%, hoặc tắt TP1.");return INIT_PARAMETERS_INCORRECT;}
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
   string parent=MXTrim(MXPresetActive()?MXPresetFolder():InpMatrixThuMuc);
   if(parent=="" || StringFind(parent,"\\")>=0 || StringFind(parent,"/")>=0 || StringFind(parent,":")>=0 || parent=="..")
      {Print("Tên thư mục không được rỗng hay chứa dấu đường dẫn");return INIT_PARAMETERS_INCORRECT;}
   FolderCreate(parent,FILE_COMMON);
   string run=TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS);StringReplace(run,":","");StringReplace(run," ","_");
   g_runFolder=parent+"\\RUN_"+run+"_"+IntegerToString((long)GetTickCount64());
   FolderCreate(g_runFolder,FILE_COMMON);
   g_hConfig=MXFile("bo_cau_hinh","engine_id;phuong_phap;loai;input_da_doi;toan_bo_input");
   g_hWallet=MXFile("danh_muc_tai_khoan","wallet_id;engine_id;huong;phien;von_dau;tien_te;vai_tro");
   g_hTrades=MXFile("lenh_mo_phong","time;wallet_id;engine_id;trade_id;method;event;direction;signal_time;entry_time;entry;initial_sl;current_sl;tp1;tp2;initial_lot;remaining_lot;event_price;event_net;trade_net;mfe_r;mae_r;balance;currency;details");
   g_hEvents=MXFile("su_kien","time;engine_id;method;event;status;reason;signal_time;details");
   g_hAudit=MXFile("doi_chieu_khop_lenh","action;shadow_trade_id;engine_id;position_ticket;order_ticket;deal_ticket;request_tick_ms;deal_ms;after_tick_ms;elapsed_ms;side;request_bid;request_ask;requested_price;fill_price;price_difference;result_volume;api_ok;retcode;description");
   if(InpMatrixGhiEquityPhut>0)g_hEquity=MXFile("duong_von","time;wallet_id;balance;equity;max_dd_pct;positions;currency");
   if(InpMatrixGhiNenM1)g_hBars=MXFile("nen_M1","time;open;high;low;close;tick_volume;spread_points");
   if(g_fatal)return INIT_FAILED;
   int dictionary=MXFile("tu_dien_input","ma_input;ten_tieng_viet;kieu;mac_dinh;cho_phep_quet_luoi");
   if(dictionary!=INVALID_HANDLE){MatrixWriteDictionary(dictionary);FileClose(dictionary);}
   MatrixBaseConfig(g_base);
   if(MXAddWallet(-1,0,0)<0)return INIT_FAILED;
   for(int f=0;f<10;f++)if(MXEnabled(f) && !MXBuildFamily(f))return INIT_PARAMETERS_INCORRECT;
   if(ArraySize(g_engines)==0 || MXViThamChieu()>=ArraySize(g_wallets))
      {Print("Không có phương pháp hoặc ID tham chiếu không tồn tại.");return INIT_PARAMETERS_INCORRECT;}
   FileFlush(g_hConfig);FileClose(g_hConfig);g_hConfig=INVALID_HANDLE;
   FileFlush(g_hWallet);FileClose(g_hWallet);g_hWallet=INVALID_HANDLE;
   g_executor.SetExpertMagicNumber(InpMagic);g_executor.SetAsyncMode(false);g_executor.SetTypeFillingBySymbol(_Symbol);
   g_executor.SetDeviationInPoints((ulong)MathFloor(InpTruotGiaToiDaGia/_Point));
   g_ready=true;
   Print("V4.39 MATRIX 7PP | Bộ cài sẵn: ",EnumToString(InpMatrixBoCaiSan),
         MXPresetActive()?" | bỏ qua input bật PP/lưới/giới hạn/thư mục":" | theo input thủ công");
   Print("V4.39 MATRIX | ",ArraySize(g_engines)," bộ tín hiệu độc lập | ",ArraySize(g_wallets),
         " tài khoản | Graph=ID ",MXViThamChieu()," | ",g_runFolder);
   Print("Swap mô phỏng dùng thông số HIỆN TẠI; commission cần nhập. Giữ Journal để kiểm tra dữ liệu tick.");
   Print("ĐỐI CHIẾU: đặt Execution = No Delay. Nếu thời gian thay đổi trong giao dịch, Matrix sẽ dừng và ghi ERROR.");
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(!g_ready || g_finished)return;
   if(g_fatal){ExpertRemove();return;}
   if(!SymbolInfoTick(_Symbol,g_quote) || g_quote.bid<=0.0 || g_quote.ask<g_quote.bid)return;
   if(!MXRates()) {MXFail("OrderCalcProfit không có tỷ giá hợp lệ; kiểm tra lịch sử mã quy đổi tiền");ExpertRemove();return;}
   if(g_firstTick==0)g_firstTick=g_quote.time;g_lastTick=g_quote.time;
   MXCalendar();MXUpdatePositions();
   for(int e=0;e<ArraySize(g_engines) && !g_fatal;e++)g_engines[e].ScheduledStep(g_quote.time);
   MXLogBars();MXLogEquity();MXPanel();
   // All virtual wallets and engines finish on the same market snapshot first.
   // Blocking native requests must never run inside the engine iteration.
   if(!g_fatal)MXNativeManage();
   for(int q=0;q<ArraySize(g_nativeQueue) && !g_fatal;q++)MXNativeOpen(g_nativeQueue[q]);
   ArrayResize(g_nativeQueue,0);
   if(g_fatal){ExpertRemove();return;}
   ulong now=GetTickCount64();if(now-g_lastFlush>=5000){MXFlush();g_lastFlush=now;}
}
double OnTester()
{
   MXFinish("COMPLETE");
   return ArraySize(g_wallets)>0?MXScore(MXViThamChieu()):0.0;
}
void OnDeinit(const int reason)
{
   if(g_ready && !g_finished)MXFinish("STOPPED_EARLY");
   for(int e=0;e<ArraySize(g_engines);e++)
      if(CheckPointer(g_engines[e])!=POINTER_INVALID) {g_engines[e].Release();delete g_engines[e];}
   if(g_hTrades!=INVALID_HANDLE)FileClose(g_hTrades);
   if(g_hEvents!=INVALID_HANDLE)FileClose(g_hEvents);
   if(g_hAudit!=INVALID_HANDLE)FileClose(g_hAudit);
   if(g_hEquity!=INVALID_HANDLE)FileClose(g_hEquity);
   if(g_hBars!=INVALID_HANDLE)FileClose(g_hBars);
   if(g_hConfig!=INVALID_HANDLE)FileClose(g_hConfig);
   if(g_hWallet!=INVALID_HANDLE)FileClose(g_hWallet);
   Comment("");
}
