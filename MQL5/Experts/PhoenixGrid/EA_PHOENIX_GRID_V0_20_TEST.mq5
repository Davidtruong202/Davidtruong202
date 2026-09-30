//+------------------------------------------------------------------+
//|                                  EA_PHOENIX_GRID_V0_20_TEST.mq5  |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  V0.20 TEST — PHOENIX DCA + TỈA LỆNH TUẦN HOÀN, KHÔNG CẮT LỖ.    |
//|  Chạy trên tài khoản thật, demo và Strategy Tester với cùng một  |
//|  logic (bạn cho phép mọi loại tài khoản ngày 30/09/2026).        |
//|  - Lệnh đầu basket: bộ PP định tuyến theo trạng thái Phoenix:    |
//|    PP1 (biên hộp, khi SIDEWAYS), PP10 (Fib + Bollinger hồi thuận |
//|    xu hướng, dựng lại theo tham số SET M2_FIBO).                 |
//|  - DCA: thêm tầng khi giá đi ngược một khoảng tầng (theo ATR M5).|
//|    Tỉa: mỗi tầng có TP riêng phía server, mở lại khi giá quay lại|
//|    (tuần hoàn).                                                  |
//|  - CLEAR để bắt đầu chu kỳ mới, giữ DD chuỗi DCA thấp:           |
//|    (1) đóng cả basket khi lãi ròng đạt mục tiêu; (2) lãi tỉa đã   |
//|    chốt dùng để xóa tầng đang lỗ nhiều nhất; (3) chuỗi đã xuống   |
//|    sâu thì đóng basket ngay khi hòa vốn. Lot mặc định 0,01 đều.  |
//|    Tham khảo Hydra 4.5: trailing clear, gộp lệnh lãi bù lệnh lỗ,  |
//|    bảng hệ số lot theo cấp (tùy chọn), giãn cách DCA, bảo vệ vốn  |
//|    (tùy chọn, mặc định tắt), báo về điện thoại.                  |
//|  - Không SL. Kiểm soát volume: lot mỗi tầng, hệ số lot, số tầng  |
//|    tối đa, margin level, số lệnh mỗi ngày, hoãn DCA khi Phoenix  |
//|    báo breakout ngược basket.                                    |
//|  - Log mỗi ngày: tín hiệu, lệnh, basket, thực thi, tổng kết ngày |
//|    (gồm tiền nạp / rút) để tối ưu dần.                           |
//|  Chưa compile trong môi trường phát triển.                       |
//|  Đặc tả: docs/phoenix_grid/06_EA_V0_20_DCA_TIA.md                |
//+------------------------------------------------------------------+
#property copyright   "DAVID HUNTER – PHOENIX GRID – 0941920986"
#property version     "0.20"
#property description "V0.20 TEST — Phoenix DCA + tỉa lệnh tuần hoàn + clear chu kỳ, không cắt lỗ. Bộ PP (PP1, PP10 theo SET M2). Chạy trên tài khoản thật, demo và Strategy Tester."

#define PG_PHIEN_BAN     "V0.20 TEST"
#define PG_P             "PG_"            // tiền tố tên đối tượng trên chart
#define PG_TICK_BUF      8192             // bộ đệm tick vòng
#define PG_BUCKET_MAX    720              // tối đa số ô đếm tick trong 60 phút
#define PG_SP_RING       1800             // 30 phút mẫu spread, mỗi giây một mẫu
#define PG_MAX_SPREAD    5000             // spread lớn hơn (point) được gộp vào ô cuối
#define PG_SO_THONG_BAO  5
#define PG_KHOI_DONG_M5  24               // số nến M5 dựng lại trạng thái cấu trúc khi khởi động
#define PG_CHO_CHI_BAO   10               // số lần chờ chỉ báo tính xong nến mới trước khi dùng giá trị hiện có
#define PG_CHO_DEAL_RA   30               // số giây chờ lịch sử có giao dịch đóng của một lệnh
#define PG_LOI_LIEN_TIEP 3                // số lần gửi lệnh lỗi liên tiếp thì tạm dừng
#define PG_TIN_TOI_DA    64               // số tin quan trọng lưu để lọc
#define PG_TANG_MAX      60               // số tầng tối đa của một basket (kích thước mảng)

#define PG_FONT          "Arial"
#define PG_FONT_B        "Arial Bold"
#define PG_FONT_T        "Arial Black"

#define CLR_NEN          C'10,8,6'
#define CLR_KHUNG        C'22,17,12'
#define CLR_VIEN         C'120,88,20'
#define CLR_VANG         C'255,205,70'
#define CLR_VANG_DAM     C'184,134,11'
#define CLR_CAM          C'255,140,0'
#define CLR_CHU          C'232,222,200'
#define CLR_MO           C'150,138,115'
#define CLR_XANH         C'80,210,120'
#define CLR_DO           C'255,95,80'
#define CLR_CHIP         C'40,32,22'

//--- Tiêu đề các file log (phân cách ;). Log trạng thái theo tháng; các log còn lại theo ngày
#define PG_TD_TT "thoi_gian;msc;su_kien;nen_m5;bid;ask;spread_point;cau_truc;thi_truong;tham_chieu_tren;tham_chieu_duoi;tham_chieu_rong;hop_tren;hop_duoi;atr_m5;atr_m1;adx;di_cong;di_tru;er;do_doc;cham_tren;cham_duoi;toc_do_tick;mat_do_tick;so_nen_tu_canh_bao;adx_dinh_sau_canh_bao;sau_bo_so_nen;sau_bo_tren;sau_bo_duoi;loc"
#define PG_TD_TS "thoi_gian;pp;huong;gia;ket_qua;ly_do;dau_nhip;cuoi_nhip;nhip_atr;nen_hoi;do_hoi;cham_band;nen_xac_nhan;atr_pp10;adx_pp10;hop_tren;hop_duoi;atr_m5;thi_truong_phoenix;cau_truc_phoenix;loc;spread_point"
#define PG_TD_GD "thoi_gian_vao;thoi_gian_ra;basket;tang;huong;lot;gia_vao;gia_ra;tp;ly_do_ra;loi_nhuan;phut_giu;ticket"
#define PG_TD_GI "thoi_gian_mo;thoi_gian_dong;basket;pp;huong;gia_tang0;khoang_tang;muc_tieu;ly_do_dong;loi_nhuan;so_lenh;so_tia;so_xoa;tang_sau_nhat;lot_mo_lon_nhat;lo_tha_noi_lon_nhat;lo_tha_noi_lon_nhat_pt_equity;phut_giu;equity_luc_dong"
#define PG_TD_TK "ngay;equity_dau_ngay;equity_cuoi_ngay;thay_doi;nap;rut;thay_doi_bo_nap_rut;so_basket_dong;so_lenh_mo;so_lan_tia;lai_basket_dong;dd_lon_nhat_pt;stop_out;basket_dang_mo;lot_dang_mo"
#define PG_TD_TH "thoi_gian;msc;hanh_dong;lan_thu;loai;lot;gia_yeu_cau;gia_khop;sl;tp;vi_the;retcode;phan_loai;tre_ms;bid;ask;comment;order;deal"

//--- Chế độ EA (chú thích của từng giá trị là nhãn hiển thị trên MT5)
enum PG_CHE_DO
  {
   PG_CD_QUAN_SAT  = 0,   // Quan sát (không gửi lệnh)
   PG_CD_GIAO_DICH = 1    // Giao dịch
  };

//--- Input (nhãn tiếng Việt)
input group "1. CHUNG"
input long      InpMagic          = 20260930;         // Magic của Phoenix Grid
input bool      InpGhiLog         = true;             // Ghi log CSV (tín hiệu, lệnh, basket, tổng kết ngày, trạng thái)
input string    InpThuMucLog      = "PhoenixGrid";    // Thư mục con trong Common\Files
input bool      InpThongBaoDT     = true;             // Gửi thông báo về app MT5 trên điện thoại (cần MetaQuotes ID)

input group "2. GIAO DỊCH — REAL / DEMO / TESTER"
input PG_CHE_DO InpCheDo          = PG_CD_GIAO_DICH;  // Chế độ EA
input bool      InpChoPhepTKThat  = true;             // Cho phép gửi lệnh trên tài khoản thật (bạn cho phép 30/09/2026)
input int       InpDoLechDiem     = 30;               // Độ lệch giá cho phép khi gửi lệnh (point)

input group "3. BỘ PP VÀO LỆNH ĐẦU BASKET"
input bool   InpDungPP10       = true;   // PP10: Fib + Bollinger hồi thuận xu hướng (SET M2), khi không sideways
input ENUM_TIMEFRAMES InpPP10TF = PERIOD_M2; // PP10: khung thời gian (không đổi theo chart)
input bool   InpDungPP1        = true;   // PP1: vào gần biên hộp khi Phoenix nhận SIDEWAYS
input double InpPP1Z           = 0.25;   // PP1: vùng vào lệnh tính từ biên hộp (× độ rộng hộp)
input bool   InpPP1XacNhan     = true;   // PP1: cần nến M1 từ chối

input group "4. PP10 — XU HƯỚNG (SET M2)"
input bool   InpDungEMA        = true;   // Lọc xu hướng: giá đóng cửa so với EMA
input int    InpEMA            = 53;     // Chu kỳ EMA
input bool   InpDungDocEMA     = true;   // Lọc xu hướng: EMA dốc theo hướng lệnh
input int    InpSoNenDoc       = 12;     // Số nến đo độ dốc EMA
input bool   InpDungADX        = true;   // Lọc bằng ADX
input int    InpADXChuKy       = 14;     // Chu kỳ ADX
input double InpADXMin         = 27.0;   // ADX tối thiểu
input double InpATRMinUSD      = 0.30;   // ATR tối thiểu (USD); SET ghi 30 "pips", hiểu 1 pip = 0,01 USD
input int    InpATRChuKy       = 14;     // Chu kỳ ATR

input group "5. PP10 — FIBONACCI (SET M2)"
input int    InpNenHoiMax      = 9;      // Số nến hồi tối đa kể từ điểm cuối nhịp đẩy
input int    InpNenHoiMin      = 4;      // Số nến hồi tối thiểu
input int    InpNenNhipDay     = 52;     // Cửa sổ tìm nhịp đẩy (số nến)
input double InpNhipDayMinATR  = 3.0;    // Nhịp đẩy tối thiểu (× ATR)
input double InpFibMin         = 0.5;    // Cận dưới vùng Fib
input double InpFibMax         = 0.618;  // Cận trên vùng Fib
input double InpFibDungSai     = 0.05;   // Dung sai vùng Fib
input double InpFibMatHieuLuc  = 0.786;  // Hồi quá mức này thì nhịp mất hiệu lực

input group "6. PP10 — BOLLINGER VÀ NẾN XÁC NHẬN (SET M2)"
input int    InpBBChuKy        = 11;     // Chu kỳ Bollinger
input double InpBBDoLech       = 2.4;    // Độ lệch chuẩn Bollinger
input int    InpNenCham        = 1;      // Số nến gần nhất được xét chạm band
input double InpChamDungSaiATR = 0.15;   // Dung sai chạm band (× ATR)
input bool   InpPinBar         = true;   // Nến xác nhận: pin bar
input bool   InpEngulfing      = true;   // Nến xác nhận: engulfing
input bool   InpStar           = true;   // Nến xác nhận: morning / evening star
input double InpBacPinMin      = 0.77;   // Pin bar: bấc tối thiểu (× biên độ nến)

input group "7. PHOENIX DCA VÀ TỈA LỆNH — KHÔNG CẮT LỖ"
input double InpLotCoSo        = 0.01;   // Lot tầng 0
input double InpHeSoLot        = 1.0;    // Hệ số lot mỗi tầng khi TẮT bảng hệ số (1 = lot bằng nhau)
input double InpLotTangToiDa   = 0.50;   // Lot tối đa một tầng
input double InpBuocATR        = 1.15;   // Khoảng cách tầng (× ATR M5 lúc mở basket)
input double InpBuocMinUSD     = 6.0;    // Khoảng cách tầng tối thiểu (USD)
input int    InpSoTangToiDa    = 40;     // Số tầng tối đa (tầng 0 là lệnh đầu)
input double InpTiaTPBuoc      = 1.0;    // Tỉa: chốt lời mỗi tầng khi giá hồi (× khoảng tầng)
input bool   InpTiaLapLai      = true;   // Mở lại tầng đã tỉa khi giá quay xuống lại (tuần hoàn)
input bool   InpHoanDCANguocBO = true;   // Hoãn DCA khi Phoenix cảnh báo / xác nhận breakout ngược basket
input int    InpGiayGiuaDCA    = 20;     // Số giây tối thiểu giữa 2 lệnh DCA (chống thác lệnh)

input group "7b. BẢNG HỆ SỐ LOT THEO CẤP (tham khảo Hydra; tắt = lot đều)"
input bool   InpDungBangLot    = false;  // Dùng bảng hệ số theo cấp (bật: hòa vốn gần hơn nhưng cháy sớm hơn)
input int    InpCap1           = 6;      // Nhóm 1 kết thúc ở cấp (cấp 1 = lệnh DCA đầu tiên)
input double InpHeSo1          = 1.2;    // Nhóm 1: hệ số nhân mỗi cấp
input int    InpCap2           = 14;     // Nhóm 2 kết thúc ở cấp
input double InpHeSo2          = 1.05;   // Nhóm 2: hệ số nhân mỗi cấp
input int    InpCap3           = 18;     // Nhóm 3 kết thúc ở cấp
input double InpHeSo3          = 1.5;    // Nhóm 3: hệ số nhân mỗi cấp
input int    InpCap4           = 26;     // Nhóm 4 kết thúc ở cấp
input double InpHeSo4          = 1.05;   // Nhóm 4: hệ số nhân mỗi cấp
input int    InpCap5           = 30;     // Nhóm 5 kết thúc ở cấp (sau đó × 1,00)
input double InpHeSo5          = 1.3;    // Nhóm 5: hệ số nhân mỗi cấp

input group "7c. CLEAR CHU KỲ — GIỮ DD CHUỖI DCA THẤP"
input double InpGioTPATR       = 1.0;    // Mốc clear basket: lãi ròng ≥ (× ATR M5 × giá trị 1 USD của lot tầng 0)
input bool   InpTrailClear     = true;   // Trailing clear: đạt mốc thì để lãi chạy, đóng khi lãi ròng tụt về % đỉnh
input double InpTrailGiuPT     = 60.0;   // Trailing clear: giữ lại tối thiểu % lãi ròng đỉnh
input int    InpHoaVonTuTang   = 4;      // Basket đã xuống tới tầng này: clear ngay khi lãi ròng ≥ 0 (0 = tắt)
input int    InpSauTuTang      = 0;      // Basket rất sâu tới tầng này: clear khi lãi ròng ≥ mức dưới (0 = tắt)
input double InpSauMucRong     = 0.0;    // Mức lãi ròng clear khi rất sâu (tiền tài khoản, số âm = chấp nhận lỗ)
input bool   InpXoaTangLo      = true;   // Clear từng phần: dùng lãi tỉa + tầng đang lãi để đóng tầng lỗ nhiều nhất
input int    InpXoaTuSoTang    = 3;      // Clear từng phần khi basket có từ số tầng mở này trở lên
input int    InpXoaGomLai      = 4;      // Gộp tối đa số tầng đang lãi (trừ tầng sâu nhất) để bù MỘT tầng lỗ (0 = chỉ lãi tỉa)
input double InpXoaLaiToiThieu = 0.0;    // Lãi còn lại tối thiểu của nhóm được đóng (tiền tài khoản)
input int    InpGiayChoSauClear = 10;    // Số giây chờ sau khi clear basket mới mở basket mới

input group "8. TRÍ TUỆ PHOENIX — BỘ LỌC MỞ BASKET"
input bool   InpChanSideways   = true;   // PP10 không vào khi Phoenix nhận SIDEWAYS / vùng mới
input bool   InpChanNguocBO    = true;   // Không mở basket ngược breakout đang cảnh báo / xác nhận
input bool   InpChanNguocXH    = true;   // Không mở basket ngược xu hướng M5 của Phoenix
input bool   InpLocTin         = true;   // Tránh tin USD quan trọng (lịch kinh tế MT5; không có trong tester)
input int    InpTinTruocPhut   = 30;     // Tránh tin: số phút trước
input int    InpTinSauPhut     = 30;     // Tránh tin: số phút sau
input double InpSpreadAbs      = 0.26;   // Spread tối đa tuyệt đối (USD/oz)
input double InpSpreadLan      = 1.5;    // Spread tối đa (× trung vị 30 phút)
input int    InpMatTickGiay    = 60;     // Mất tick quá số giây này trong phiên
input int    InpPhutTruocNghi  = 15;     // Không mở lệnh trong số phút trước giờ nghỉ

input group "9. KIỂM SOÁT VOLUME VÀ TÀI KHOẢN"
input double InpMLVao          = 500.0;  // Margin level tối thiểu sau lệnh mở (%)
input int    InpLenhToiDaNgay  = 200;    // Số lệnh mở tối đa mỗi ngày (chốt an toàn)
input double InpDDDungMoiPT    = 0.0;    // Không mở basket mới khi DD ≥ % (0 = tắt)
input double InpBaoVeVonPT     = 0.0;    // Bảo vệ vốn: đóng hết và TẠM DỪNG khi DD ≥ % (0 = tắt, đúng ý không cắt lỗ)
input bool   InpTamDungViTheLa = true;   // Tạm dừng khi tài khoản có vị thế / lệnh chờ không thuộc Phoenix

input group "10. PHOENIX — NHẬN DIỆN TRẠNG THÁI M5 (giá trị khởi đầu, chờ A0)"
input int    InpNBox           = 48;     // Số nến M5 dựng hộp giá
input double InpWMin           = 1.5;    // Độ rộng hộp tối thiểu (× ATR M5)
input double InpWMax           = 6.0;    // Độ rộng hộp tối đa (× ATR M5)
input double InpADXSideways    = 22.0;   // ADX M5 dưới mức này mới xét sideways
input double InpADXTrend       = 27.0;   // ADX M5 từ mức này trở lên mới xét xu hướng
input int    InpNER            = 24;     // Số nến M5 tính hiệu suất xu hướng (ER) và độ dốc
input double InpERSideways     = 0.30;   // ER dưới mức này mới xét sideways
input double InpERTrend        = 0.40;   // ER từ mức này trở lên mới xét xu hướng
input double InpBetaSideways   = 0.05;   // Độ dốc tối đa khi sideways (ATR M5 mỗi nến)
input double InpBetaTrend      = 0.10;   // Độ dốc tối thiểu khi xu hướng (ATR M5 mỗi nến)
input double InpTau            = 0.15;   // Dung sai chạm biên (× độ rộng hộp)
input int    InpMinCham        = 2;      // Số lần chạm tối thiểu ở mỗi biên
input int    InpHVao           = 2;      // Số nến M5 liên tiếp để nhận trạng thái mới
input int    InpHRa            = 2;      // Số nến M5 liên tiếp để bỏ trạng thái

input group "11. PHOENIX — BREAKOUT THEO TICK"
input double InpBW             = 0.35;   // Đệm cảnh báo breakout (× ATR M5)
input int    InpDeltaGiay      = 15;     // Cửa sổ đo tốc độ và mật độ tick (giây)
input double InpVW             = 1.0;    // Tốc độ tick để cảnh báo (× ATR M1 trong cửa sổ)
input double InpLambdaW        = 2.0;    // Mật độ tick để cảnh báo (× trung vị 60 phút)
input double InpBC             = 0.30;   // Xác nhận: nến M1 đóng vượt biên (× ATR M5)
input double InpBX             = 1.0;    // Xác nhận: giá vượt biên (× ATR M5)
input int    InpTCGiay         = 90;     // Xác nhận: giá ở ngoài biên liên tục (giây)
input double InpRF             = 0.30;   // Breakout giả: giá quay vào hộp (× độ rộng hộp)
input int    InpTFPhut         = 15;     // Breakout giả: xét trong (phút) kể từ lúc cảnh báo
input int    InpNMinVungMoi    = 24;     // Vùng mới: số nến M5 tối thiểu sau xác nhận breakout
input double InpDeltaADX       = 5.0;    // Vùng mới: ADX phải giảm tối thiểu từ đỉnh sau breakout
input int    InpNMaxTheoDoi    = 288;    // Theo dõi breakout tối đa (nến M5) để chờ vùng mới

input group "12. GIAO DIỆN"
input bool   InpHienBang       = true;   // Hiển thị bảng điều khiển
input double InpTyLe           = 1.0;    // Tỷ lệ kích thước bảng (0,8 – 1,5)
input bool   InpVeHop          = true;   // Vẽ hộp giá và mức cảnh báo trên chart

//--- Trạng thái cấu trúc
enum PG_CAU_TRUC
  {
   PG_CT_KHONG_RO = 0,
   PG_CT_SIDEWAYS = 1,
   PG_CT_TANG     = 2,
   PG_CT_GIAM     = 3
  };

//--- Chỉ báo và dữ liệu nến M5
int         g_hATR5 = INVALID_HANDLE, g_hATR1 = INVALID_HANDLE, g_hADX5 = INVALID_HANDLE;
double      g_point = 0.0;
int         g_digits = 0;
datetime    g_lastM5 = 0, g_lastM1 = 0;
bool        g_duLieuSan = false;
int         g_choChiBao = 0;
double      g_atr5 = 0.0, g_atr1 = 0.0, g_adx = 0.0, g_diP = 0.0, g_diM = 0.0, g_er = 0.0, g_beta = 0.0;
double      g_U = 0.0, g_L = 0.0, g_W = 0.0, g_M = 0.0;
int         g_tU = 0, g_tL = 0;
datetime    g_hopT1 = 0;
datetime    g_nenM5 = 0;          // giờ mở của nến M5 vừa tính

//--- Trạng thái cấu trúc có chống nhấp nháy
PG_CAU_TRUC g_ct = PG_CT_KHONG_RO, g_ctUngVien = PG_CT_KHONG_RO;
int         g_ctChuoi = 0;

//--- Hộp tham chiếu (hộp đang dùng để phát hiện breakout)
bool        g_hopOk = false;
double      g_rU = 0.0, g_rL = 0.0, g_rW = 0.0, g_rM = 0.0;
datetime    g_rT1 = 0;

//--- Hộp sau breakout: cửa sổ chỉ gồm các nến M5 mở từ mốc xác nhận, tối đa InpNBox nến
bool        g_hopSauBO = false;   // hộp tham chiếu đang là hộp sau breakout
bool        g_laVungMoi = false;  // hộp sau breakout có tâm lệch khỏi hộp cũ: VÙNG MỚI
datetime    g_vungMoc = 0;        // mốc cửa sổ của hộp sau breakout đang giữ
int         g_vungSai = 0;        // số nến liên tiếp hộp sau breakout không còn sideways
int         g_cK = 0;             // số nến của cửa sổ sau breakout (0 = không tính)
double      g_cU = 0.0, g_cL = 0.0, g_cW = 0.0, g_cM = 0.0, g_cEr = 0.0, g_cBeta = 0.0;
int         g_cTU = 0, g_cTL = 0;
datetime    g_cT1 = 0;

//--- Breakout
int         g_boHuong = 0;        // +1 lên, -1 xuống
int         g_boGiaiDoan = 0;     // 0 không có, 1 cảnh báo, 2 đã xác nhận
datetime    g_boBatDau = 0;       // thời điểm cảnh báo
datetime    g_boMoc = 0;          // mốc cửa sổ sau breakout: giờ mở nến M5 đầu tiên sau lúc xác nhận
long        g_boNgoaiTuMsc = 0;
double      g_boAdxDinh = 0.0;
int         g_boSoNen = 0;        // số nến M5 đã đóng kể từ cảnh báo
int         g_vmDung = 0, g_vcDung = 0;
bool        g_boDaBaoXuHuong = false;
datetime    g_giaDenLuc = 0;      // hiển thị "breakout giả" tới thời điểm này

//--- Tick
long        g_tkMsc[PG_TICK_BUF];
double      g_tkMid[PG_TICK_BUF];
int         g_tkDau = 0, g_tkSo = 0;
double      g_vTick = 0.0, g_lambda = 0.0;
int         g_tickCuaSo = 0;
long        g_bkHienTai = -1;
int         g_bkDem = 0;
int         g_bkVong[PG_BUCKET_MAX];
int         g_bkSo = 0, g_bkViTri = 0;
double      g_bkTrungVi = 0.0;
datetime    g_tickCuoi = 0;
long        g_msCuoi = 0;
double      g_bid = 0.0, g_ask = 0.0;

//--- Spread lấy mẫu mỗi giây
int         g_spVong[PG_SP_RING];
int         g_spHist[PG_MAX_SPREAD + 1];
int         g_spSo = 0, g_spViTri = 0;
int         g_spTrungVi = 0;

//--- Bộ lọc
bool        g_loc = false;
string      g_lyDoLoc = "—";
string      g_maLoc = "CHO_DU_LIEU";

//--- Tài khoản
string      g_gvDinh = "", g_gvDDMax = "", g_gvNgay = "", g_gvDauNgay = "";
double      g_dinhEq = 0.0, g_ddMax = 0.0, g_dauNgayEq = 0.0;
int         g_ngay = -1;

//--- Giao diện
double      g_s = 1.0, g_sf = 1.0;    // tỷ lệ tọa độ (theo DPI màn hình) và tỷ lệ cỡ chữ
int         g_x0 = 0, g_y0 = 0, g_pw = 0, g_cw = 0;
bool        g_thuGon = false;
string      g_nutCho = "";
datetime    g_nutChoDen = 0;
string      g_thongBao[PG_SO_THONG_BAO];

//--- Log CSV
int         g_log = INVALID_HANDLE, g_logTS = INVALID_HANDLE, g_logGD = INVALID_HANDLE, g_logGI = INVALID_HANDLE;
int         g_logTK = INVALID_HANDLE, g_logTH = INVALID_HANDLE;
string      g_logThang = "", g_logTSKy = "", g_logGDKy = "", g_logGIKy = "", g_logTKKy = "", g_logTHKy = "";

//--- Môi trường chạy
bool        g_tester = false, g_toiUu = false, g_veBang = true;
double      g_vpp = 0.0;                  // tiền tài khoản mỗi lot mỗi 1,0 giá (TICK_VALUE_LOSS / TICK_SIZE)
int         g_dgLot = 2;                  // số chữ số thập phân của lot
ENUM_ORDER_TYPE_FILLING g_filling = ORDER_FILLING_FOK;

//--- Quyền gửi lệnh, tạm dừng, khẩn cấp
bool        g_duocGui = false;            // chế độ giao dịch + quyền loại tài khoản + Algo Trading bật
bool        g_laTKThat = false;
string      g_lyDoKhoa = "";
bool        g_tamDungTay = false;         // tạm dừng bằng nút (lưu GlobalVariable)
bool        g_loiNghiemTrong = false;     // lỗi nghiêm trọng / trạng thái không nhất quán: chờ bấm TIẾP TỤC
string      g_lyDoLoi = "";
string      g_lyDoTamDung = "";           // tạm dừng tự động: vị thế lạ
bool        g_dungMoiDD = false;          // DD ≥ ngưỡng: không mở basket mới
bool        g_dongTatCaCho = false;       // còn vị thế Phoenix phải đóng sau nút ĐÓNG TẤT CẢ
datetime    g_lanDongCuoi = 0;
int         g_loiLienTiep = 0;
int         g_lenhHomNay = 0;
string      g_gvTamDung = "", g_gvGio = "";

//--- PP10: chỉ báo trên khung PP10
int         g_hEMA = INVALID_HANDLE, g_hADXp = INVALID_HANDLE, g_hATRp = INVALID_HANDLE, g_hBB = INVALID_HANDLE;
datetime    g_lastPP = 0;
int         g_choPP = 0;
//--- Bộ PP: kết quả xét gần nhất (hiển thị)
int         g_ppHuong = 0;
double      g_ppADX = 0.0, g_ppATR = 0.0, g_ppNhip = 0.0, g_ppHoi = -1.0;
bool        g_ppCham = false;
string      g_ppNen = "", g_ppLyDo = "Chờ tín hiệu", g_ppGanNhat = "";
datetime    g_pp1Nen = 0;

//--- Basket DCA đang chạy (một basket tại một thời điểm)
long        g_gioId = 0;
int         g_gioHuong = 0;               // +1 BUY, -1 SELL, 0 không có basket
string      g_gioPP = "";
double      g_gioP0 = 0.0, g_gioBuoc = 0.0, g_gioMucTieu = 0.0;
datetime    g_gioLucMo = 0;
double      g_gioDaChot = 0.0, g_gioDDMax = 0.0, g_gioLotMax = 0.0, g_gioGiaTruoc = 0.0;
int         g_gioSoTia = 0, g_gioTangSau = 0, g_gioSoLenh = 0;
bool        g_gioDangDong = false;
string      g_gioLyDoDong = "";
double      g_gioEqMo = 0.0;
ulong       g_tang[PG_TANG_MAX];          // ticket đang mở ở mỗi tầng (0 = trống)

//--- Thống kê
int         g_tkGio = 0, g_tkGioThang = 0, g_tkGioHomNay = 0, g_tkTiaHomNay = 0, g_tkStopOutHomNay = 0;
double      g_tkRong = 0.0, g_tkRongHomNay = 0.0, g_ddNgayMax = 0.0, g_napRutHomNay = 0.0;
bool        g_daCapNhatTK = false;

//--- Lịch tin
datetime    g_tinLuc[PG_TIN_TOI_DA];
int         g_tinSo = 0;
datetime    g_tinCapNhat = 0;
bool        g_tinCo = false;              // đọc được lịch kinh tế

//--- Chu kỳ basket: chờ DCA, clear, stop out, nạp / rút
int         g_gioCho = -1;                // tầng đã bị giá vượt qua, đang chờ mở
string      g_gioLyDoCho = "";
int         g_gioSoXoa = 0;               // số tầng đã xóa bằng lãi tỉa
long        g_gioIdCuoi = 0;
string      g_gioCuoiKQ = "";
datetime    g_gioCuoiLuc = 0;
bool        g_tangDaTia[PG_TANG_MAX];     // tầng đã được tỉa ít nhất một lần
int         g_tangDong[PG_TANG_MAX];      // lệnh đóng do EA gửi: 1 xóa tầng lỗ, 2 tỉa bằng lệnh thị trường, 3 tầng lãi gộp để xóa
datetime    g_tangMat[PG_TANG_MAX];       // lúc thấy tầng đã đóng mà chưa có giao dịch đóng trong lịch sử
datetime    g_lanSuaTP = 0;
bool        g_sauStopOut = false;         // đã stop out: không mở basket / tầng mới tới khi nạp tiền hoặc bấm TIẾP TỤC
string      g_gvSauSO = "";
datetime    g_choGuiDen = 0;              // sau lỗi không đủ tiền: chưa gửi lệnh mở trước thời điểm này
long        g_msLenhCuoi = 0;             // thời điểm (msc của tick) gửi lệnh mở / xóa gần nhất
double      g_napHomNay = 0.0, g_rutHomNay = 0.0;
double      g_ppDau = 0.0, g_ppCuoi = 0.0;
int         g_ppNenHoi = 0;
double      g_gioDinhLai = 0.0;           // trailing clear: lãi ròng đỉnh sau khi đạt mốc (0 = chưa kích hoạt)
long        g_msDCACuoi = 0;              // thời điểm (msc của tick) mở lệnh DCA / lệnh đầu gần nhất

//+------------------------------------------------------------------+
//| Khởi động                                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // MT5 giữ biến toàn cục của EA khi đổi khung thời gian hoặc tham số: đặt lại toàn bộ trạng thái
   DatLaiTrangThai();
   g_tester = (bool)MQLInfoInteger(MQL_TESTER);
   g_toiUu  = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_veBang = InpHienBang && (!g_tester || (bool)MQLInfoInteger(MQL_VISUAL_MODE));
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(g_point <= 0.0)
     {
      Print("PG: point của symbol không hợp lệ");
      return INIT_FAILED;
     }
   if(InpNBox < 10 || InpNER < 5 || InpWMin <= 0.0 || InpWMin >= InpWMax || InpHVao < 1 || InpHRa < 1 ||
      InpMinCham < 1 || InpDeltaGiay < 1 || InpDeltaGiay > 300 || InpTCGiay < 1 || InpTFPhut < 1 ||
      InpNMinVungMoi < 5 || InpNMinVungMoi > InpNBox || InpNMaxTheoDoi <= InpNMinVungMoi ||
      InpDoLechDiem < 0 || InpPP1Z <= 0.0 || InpPP1Z > 0.5 ||
      InpEMA < 2 || InpSoNenDoc < 1 || InpADXChuKy < 2 || InpATRChuKy < 2 || InpATRMinUSD < 0.0 ||
      InpNenHoiMin < 1 || InpNenHoiMax < InpNenHoiMin || InpNenNhipDay < InpNenHoiMax + 3 || InpNhipDayMinATR <= 0.0 ||
      InpFibMin <= 0.0 || InpFibMax <= InpFibMin || InpFibMatHieuLuc <= InpFibMax || InpFibDungSai < 0.0 ||
      InpBBChuKy < 2 || InpBBDoLech <= 0.0 || InpNenCham < 1 || InpNenCham > 10 || InpChamDungSaiATR < 0.0 ||
      InpBacPinMin <= 0.0 || InpBacPinMin >= 1.0 ||
      InpLotCoSo <= 0.0 || InpHeSoLot < 1.0 || InpHeSoLot > 3.0 || InpLotTangToiDa <= 0.0 ||
      InpBuocATR <= 0.0 || InpBuocMinUSD <= 0.0 || InpSoTangToiDa < 1 || InpSoTangToiDa > PG_TANG_MAX ||
      InpTiaTPBuoc <= 0.0 || InpGioTPATR <= 0.0 || InpTinTruocPhut < 0 || InpTinSauPhut < 0 ||
      InpMLVao <= 0.0 || InpLenhToiDaNgay < 1 || InpDDDungMoiPT < 0.0 || InpXoaTuSoTang < 2 || InpHoaVonTuTang < 0 ||
      InpGiayGiuaDCA < 0 || InpGiayChoSauClear < 0 || InpTrailGiuPT < 0.0 || InpTrailGiuPT >= 100.0 ||
      InpSauTuTang < 0 || InpXoaGomLai < 0 || InpBaoVeVonPT < 0.0 ||
      InpHeSo1 <= 0.0 || InpHeSo2 <= 0.0 || InpHeSo3 <= 0.0 || InpHeSo4 <= 0.0 || InpHeSo5 <= 0.0 ||
      InpHeSo1 > 3.0 || InpHeSo2 > 3.0 || InpHeSo3 > 3.0 || InpHeSo4 > 3.0 || InpHeSo5 > 3.0)
     {
      Print("PG: tham số không hợp lệ, xem khoảng cho phép trong docs/phoenix_grid/06_EA_V0_20_DCA_TIA.md");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_hATR5 = iATR(_Symbol, PERIOD_M5, 14);
   g_hATR1 = iATR(_Symbol, PERIOD_M1, 14);
   g_hADX5 = iADX(_Symbol, PERIOD_M5, 14);
   g_hEMA  = iMA(_Symbol, InpPP10TF, InpEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hADXp = iADX(_Symbol, InpPP10TF, InpADXChuKy);
   g_hATRp = iATR(_Symbol, InpPP10TF, InpATRChuKy);
   g_hBB   = iBands(_Symbol, InpPP10TF, InpBBChuKy, 0, InpBBDoLech, PRICE_CLOSE);
   if(g_hATR5 == INVALID_HANDLE || g_hATR1 == INVALID_HANDLE || g_hADX5 == INVALID_HANDLE ||
      g_hEMA == INVALID_HANDLE || g_hADXp == INVALID_HANDLE || g_hATRp == INVALID_HANDLE || g_hBB == INVALID_HANDLE)
     {
      Print("PG: không tạo được chỉ báo");
      return INIT_FAILED;
     }
   CapNhatVpp();
   double stLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_dgLot = (stLot <= 0.0 || stLot >= 1.0) ? 0 : (int)MathRound(-MathLog10(stLot));
   g_filling = ChonKieuKhop();
   MqlTick t0;
   if(SymbolInfoTick(_Symbol, t0) && t0.bid > 0.0 && t0.ask > 0.0)
     {
      g_bid = t0.bid;
      g_ask = t0.ask;
     }
   KhoiTaoTaiKhoan();
   if(InpGhiLog)
     {
      ResetLastError();
      if(!FolderCreate(InpThuMucLog, FILE_COMMON))
         PrintFormat("PG: FolderCreate trả về false (lỗi %d), có thể thư mục đã tồn tại", GetLastError());
     }
   double tyLe = MathMax(0.8, MathMin(1.5, InpTyLe));
   int    dpi  = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   g_s  = tyLe * ((dpi > 0) ? dpi / 96.0 : 1.0);   // tọa độ tính bằng pixel nên nhân theo DPI
   g_sf = tyLe;                                     // cỡ chữ tính bằng point, MT5 tự nhân theo DPI
   CapNhatQuyenGui(false);
   if(g_veBang)
      DungBang();
   ThemThongBao("Khởi động " + PG_PHIEN_BAN + ": " +
                (InpCheDo == PG_CD_GIAO_DICH ? "Phoenix DCA + tỉa lệnh, không cắt lỗ" : "chế độ quan sát"));
   ThemThongBao("Symbol " + _Symbol + ", tiền tài khoản " + AccountInfoString(ACCOUNT_CURRENCY));
   if(StringFind(_Symbol, "XAU") != 0)
      ThemThongBao("Cảnh báo: tham số mặc định dành cho vàng (XAU)");
   if(InpLotCoSo < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      ThemThongBao("Lot tầng 0 nhỏ hơn lot tối thiểu của symbol: dùng " + DoubleToString(LotTang(0), g_dgLot));
   ThemThongBao("Lot tầng 0 = " + DoubleToString(LotTang(0), g_dgLot) + ": giá đi 1 USD = " +
                FTien(g_vpp * LotTang(0)) + " " + AccountInfoString(ACCOUNT_CURRENCY));
   if(InpCheDo == PG_CD_GIAO_DICH)
      ThemThongBao(g_duocGui ? "Được gửi lệnh (" + (g_tester ? "Strategy Tester" : (g_laTKThat ? "tài khoản THẬT" : "tài khoản demo")) + ")"
                   : g_lyDoKhoa + ": không gửi lệnh");
   if(!g_tester)
      NhanLaiBasket();
   if(g_tamDungTay)
      ThemThongBao("Đang TẠM DỪNG từ lần chạy trước: bấm TIẾP TỤC để chạy lại");
   int soPG = 0, soKhac = 0;
   DemViThe(soPG, soKhac);
   if(soKhac > 0)
      ThemThongBao("Tài khoản có " + IntegerToString(soKhac) + " vị thế không thuộc Phoenix");
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Kết thúc. Lệnh đang mở giữ nguyên TP phía server; khi gắn lại EA |
//| sẽ nhận lại basket (trạng thái lưu trong GlobalVariables).        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   int hs[7];
   hs[0] = g_hATR5;
   hs[1] = g_hATR1;
   hs[2] = g_hADX5;
   hs[3] = g_hEMA;
   hs[4] = g_hADXp;
   hs[5] = g_hATRp;
   hs[6] = g_hBB;
   for(int i = 0; i < 7; i++)
      if(hs[i] != INVALID_HANDLE)
         IndicatorRelease(hs[i]);
   g_hATR5 = INVALID_HANDLE;
   g_hATR1 = INVALID_HANDLE;
   g_hADX5 = INVALID_HANDLE;
   g_hEMA  = INVALID_HANDLE;
   g_hADXp = INVALID_HANDLE;
   g_hATRp = INVALID_HANDLE;
   g_hBB   = INVALID_HANDLE;
   ObjectsDeleteAll(0, PG_P);
   DongFileLog(g_log);
   DongFileLog(g_logTS);
   DongFileLog(g_logGD);
   DongFileLog(g_logGI);
   DongFileLog(g_logTK);
   DongFileLog(g_logTH);
   LuuTaiKhoan();
   LuuCo();
   if(g_gioHuong != 0)
      LuuBasketGV();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Mỗi tick: nạp mọi tick mới (không bỏ sót khi OnTick bị gộp), nến  |
//| mới, breakout, tín hiệu mở basket, quản lý basket. Không vẽ giao  |
//| diện. Trong Strategy Tester, MT5 gọi OnTick cho từng tick.        |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick ts[];
   int     n = 0;
   if(!g_tester && g_msCuoi > 0)
      n = CopyTicksRange(_Symbol, ts, COPY_TICKS_INFO, (ulong)(g_msCuoi + 1));
   if(n <= 0)
     {
      MqlTick t;
      if(!SymbolInfoTick(_Symbol, t) || (long)t.time_msc <= g_msCuoi)
         return;
      ArrayResize(ts, 1);
      ts[0] = t;
      n = 1;
     }
   // nến vừa đóng được xử lý trước, rồi mới xét các tick mới với hộp đã cập nhật
   KiemTraNenMoi();
   for(int i = 0; i < n; i++)
     {
      if(ts[i].bid <= 0.0 || ts[i].ask <= 0.0)
         continue;
      g_bid = ts[i].bid;
      g_ask = ts[i].ask;
      g_tickCuoi = ts[i].time;
      g_msCuoi = (long)ts[i].time_msc;
      CapNhatTick(ts[i]);
      if(g_duLieuSan)
         KiemTraBreakoutTick(ts[i].time, g_msCuoi);
     }
   QuanLyBasket();
   KiemTraNenPP10();
   XetPP1();
  }

//+------------------------------------------------------------------+
//| Mỗi giây: nến chờ chỉ báo, spread, bộ lọc, tài khoản, rủi ro,     |
//| basket, giao diện                                                 |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(g_vpp <= 0.0)
      CapNhatVpp();
   KiemTraNenMoi();
   KiemTraNenPP10();
   LayMauSpread();
   CapNhatLoc();
   CapNhatTaiKhoan();
   CapNhatQuyenGui();
   KiemTraRuiRo();
   KiemTraBasketTimer();
   CapNhatTin();
   if(g_nutCho != "" && TimeLocal() > g_nutChoDen)
      HuyChoXacNhan();
   if(!g_veBang)
      return;
   CapNhatBang();
   if(InpVeHop)
      VeHop();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Sự kiện chart: nút bấm (MT5 không gửi sự kiện này trong tester)   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam == PG_P + "B_thugon")
     {
      g_thuGon = !g_thuGon;
      DungBang();
      CapNhatBang();
      ChartRedraw(0);
      return;
     }
   if(sparam == PG_P + "B_n_tieptuc" || sparam == PG_P + "B_n_tamdung" ||
      sparam == PG_P + "B_n_dongbk" || sparam == PG_P + "B_n_dongtc")
     {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      XuLyNut(sparam);
      CapNhatBang();
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//| Giao dịch: tầng đóng (tỉa bằng TP, đóng basket, stop out), nạp /  |
//| rút tiền                                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BALANCE)
     {
      double v = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      g_napRutHomNay += v;
      if(v > 0.0)
        {
         g_napHomNay += v;
         g_dinhEq = AccountInfoDouble(ACCOUNT_EQUITY);   // nạp lại: đỉnh Equity tính từ vốn mới
         ThemThongBao("Nạp tiền " + DauTien(v));
         GhiLog("NAP_TIEN");
         if(g_sauStopOut)
           {
            g_sauStopOut = false;
            LuuCo();
            ThemThongBao("Đã nạp tiền: bỏ khóa sau stop out, EA chạy chu kỳ mới");
           }
        }
      else
        {
         g_rutHomNay -= v;
         ThemThongBao("Rút tiền " + DauTien(v));
         GhiLog("RUT_TIEN");
        }
      return;
     }
   if(g_gioHuong == 0)
      return;
   ulong pid = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int   i = TangCuaTicket(pid);
   if(i < 0)
      return;
   long vao = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(vao != DEAL_ENTRY_OUT && vao != DEAL_ENTRY_OUT_BY)
      return;
   if(PositionSelectByTicket(pid))
      return;                                   // mới đóng một phần, vị thế vẫn còn
   XuLyTangDong(i, trans.deal);
  }

//+------------------------------------------------------------------+
//| ĐẶT LẠI TRẠNG THÁI                                                |
//+------------------------------------------------------------------+
void DatLaiCauTruc()
  {
   g_ct = PG_CT_KHONG_RO;
   g_ctUngVien = PG_CT_KHONG_RO;
   g_ctChuoi = 0;
   g_hopOk = false;
   g_rU = 0.0;
   g_rL = 0.0;
   g_rW = 0.0;
   g_rM = 0.0;
   g_rT1 = 0;
   g_hopSauBO = false;
   g_laVungMoi = false;
   g_vungMoc = 0;
   g_vungSai = 0;
   g_cK = 0;
   KetThucBreakout();
  }

void DatLaiTrangThai()
  {
   DatLaiCauTruc();
   g_lastM5 = 0;
   g_lastM1 = 0;
   g_duLieuSan = false;
   g_choChiBao = 0;
   g_atr5 = 0.0;
   g_atr1 = 0.0;
   g_adx = 0.0;
   g_diP = 0.0;
   g_diM = 0.0;
   g_er = 0.0;
   g_beta = 0.0;
   g_U = 0.0;
   g_L = 0.0;
   g_W = 0.0;
   g_M = 0.0;
   g_tU = 0;
   g_tL = 0;
   g_hopT1 = 0;
   g_nenM5 = 0;
   g_giaDenLuc = 0;
   g_tkDau = 0;
   g_tkSo = 0;
   g_vTick = 0.0;
   g_lambda = 0.0;
   g_tickCuaSo = 0;
   g_bkHienTai = -1;
   g_bkDem = 0;
   g_bkSo = 0;
   g_bkViTri = 0;
   g_bkTrungVi = 0.0;
   g_tickCuoi = 0;
   g_msCuoi = 0;
   g_bid = 0.0;
   g_ask = 0.0;
   ArrayInitialize(g_spHist, 0);
   g_spSo = 0;
   g_spViTri = 0;
   g_spTrungVi = 0;
   g_loc = false;
   g_lyDoLoc = "—";
   g_maLoc = "CHO_DU_LIEU";
   g_thuGon = false;
   g_nutCho = "";
   g_nutChoDen = 0;
   for(int i = 0; i < PG_SO_THONG_BAO; i++)
      g_thongBao[i] = "";
   g_log = INVALID_HANDLE;
   g_logThang = "";
   g_logTS = INVALID_HANDLE;
   g_logGD = INVALID_HANDLE;
   g_logGI = INVALID_HANDLE;
   g_logTK = INVALID_HANDLE;
   g_logTH = INVALID_HANDLE;
   g_logTSKy = "";
   g_logGDKy = "";
   g_logGIKy = "";
   g_logTKKy = "";
   g_logTHKy = "";
   g_duocGui = false;
   g_laTKThat = false;
   g_lyDoKhoa = "";
   g_tamDungTay = false;
   g_loiNghiemTrong = false;
   g_lyDoLoi = "";
   g_lyDoTamDung = "";
   g_dungMoiDD = false;
   g_dongTatCaCho = false;
   g_lanDongCuoi = 0;
   g_loiLienTiep = 0;
   g_lenhHomNay = 0;
   g_lastPP = 0;
   g_choPP = 0;
   g_ppHuong = 0;
   g_ppADX = 0.0;
   g_ppATR = 0.0;
   g_ppNhip = 0.0;
   g_ppHoi = -1.0;
   g_ppCham = false;
   g_ppNen = "";
   g_ppLyDo = "Chờ tín hiệu";
   g_ppGanNhat = "";
   g_pp1Nen = 0;
   XoaBasket();
   g_tkGio = 0;
   g_tkGioThang = 0;
   g_tkGioHomNay = 0;
   g_tkTiaHomNay = 0;
   g_tkStopOutHomNay = 0;
   g_tkRong = 0.0;
   g_tkRongHomNay = 0.0;
   g_ddNgayMax = 0.0;
   g_napRutHomNay = 0.0;
   g_daCapNhatTK = false;
   g_tinSo = 0;
   g_tinCapNhat = 0;
   g_tinCo = false;
   g_gioIdCuoi = 0;
   g_gioCuoiKQ = "";
   g_gioCuoiLuc = 0;
   g_lanSuaTP = 0;
   g_sauStopOut = false;
   g_choGuiDen = 0;
   g_msLenhCuoi = 0;
   g_napHomNay = 0.0;
   g_rutHomNay = 0.0;
   g_ppDau = 0.0;
   g_ppCuoi = 0.0;
   g_ppNenHoi = 0;
   g_msDCACuoi = 0;
  }

//+------------------------------------------------------------------+
//| DỮ LIỆU TICK: tốc độ và mật độ tick                               |
//+------------------------------------------------------------------+
void CapNhatTick(const MqlTick &t)
  {
   long   msc = (long)t.time_msc;
   double mid = (t.bid + t.ask) / 2.0;
   g_tkMsc[g_tkDau] = msc;
   g_tkMid[g_tkDau] = mid;
   g_tkDau = (g_tkDau + 1) % PG_TICK_BUF;
   if(g_tkSo < PG_TICK_BUF)
      g_tkSo++;

   // tốc độ v = (m_t − m_{t−Δ}) / ATR1, với m_{t−Δ} là giá giữa đang có hiệu lực tại t − Δ
   long   tu = msc - (long)InpDeltaGiay * 1000;
   int    dem = 0;
   double midCu = mid;
   for(int k = 1; k <= g_tkSo; k++)
     {
      int idx = (g_tkDau - k + PG_TICK_BUF) % PG_TICK_BUF;
      midCu = g_tkMid[idx];
      if(g_tkMsc[idx] <= tu)
         break;                                  // tick cuối cùng tại hoặc trước t − Δ
      dem++;
     }
   g_tickCuaSo = dem;                             // số tick trong (t − Δ, t]
   g_vTick = (g_atr1 > 0.0) ? (mid - midCu) / g_atr1 : 0.0;

   // mật độ: đếm tick theo từng ô InpDeltaGiay giây, so với trung vị các ô trong 60 phút
   long o = msc / ((long)InpDeltaGiay * 1000);
   if(g_bkHienTai < 0)
     {
      g_bkHienTai = o;
      g_bkDem = 0;
     }
   if(o != g_bkHienTai)
     {
      DayO(g_bkDem);
      long boQua = o - g_bkHienTai - 1;          // các ô trống ở giữa, chỉ tính khi khoảng trống dưới 60 giây
      if(boQua > 0 && boQua * InpDeltaGiay < 60)
         for(long s = 0; s < boQua; s++)
            DayO(0);
      g_bkHienTai = o;
      g_bkDem = 0;
      TinhTrungViO();
     }
   g_bkDem++;
   g_lambda = (g_bkTrungVi > 0.0) ? g_tickCuaSo / g_bkTrungVi : 0.0;
  }

void DayO(const int v)
  {
   int cap = MathMin(PG_BUCKET_MAX, 3600 / InpDeltaGiay);
   g_bkVong[g_bkViTri] = v;
   g_bkViTri = (g_bkViTri + 1) % cap;
   if(g_bkSo < cap)
      g_bkSo++;
  }

void TinhTrungViO()
  {
   if(g_bkSo <= 0)
      return;
   int tmp[];
   ArrayResize(tmp, g_bkSo);
   for(int i = 0; i < g_bkSo; i++)
      tmp[i] = g_bkVong[i];
   ArraySort(tmp);
   if(g_bkSo % 2 == 1)
      g_bkTrungVi = tmp[g_bkSo / 2];
   else
      g_bkTrungVi = 0.5 * (tmp[g_bkSo / 2 - 1] + tmp[g_bkSo / 2]);
  }

//+------------------------------------------------------------------+
//| NẾN MỚI: M1 (ATR M1, xác nhận bằng nến M1), M5 (trạng thái)       |
//+------------------------------------------------------------------+
void KiemTraNenMoi()
  {
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 != 0 && m1 != g_lastM1)
     {
      g_lastM1 = m1;
      CapNhatAtr1();
      KiemTraXacNhanM1();
     }
   else
      if(g_atr1 <= 0.0)
         CapNhatAtr1();

   datetime m5 = iTime(_Symbol, PERIOD_M5, 0);
   if(m5 == 0 || m5 == g_lastM5)
      return;
   if(g_lastM5 == 0)
     {
      // khởi động nóng: dựng lại trạng thái cấu trúc từ các nến M5 gần nhất, không thông báo, không ghi log
      DatLaiCauTruc();
      for(int s = PG_KHOI_DONG_M5; s >= 2; s--)
         if(!TinhM5(s, true))
            return;
     }
   if(TinhM5(1, false))
      g_lastM5 = m5;
  }

void CapNhatAtr1()
  {
   double a1[];
   if(CopyBuffer(g_hATR1, 0, 1, 1, a1) == 1 && a1[0] > 0.0)
      g_atr1 = a1[0];
  }

//--- Chỉ báo M5 phải tính xong nến mới; nếu chờ quá PG_CHO_CHI_BAO lần thì dùng giá trị hiện có
bool ChiBaoDaCapNhat()
  {
   int bars = Bars(_Symbol, PERIOD_M5);
   if(BarsCalculated(g_hATR5) >= bars && BarsCalculated(g_hADX5) >= bars)
     {
      g_choChiBao = 0;
      return true;
     }
   g_choChiBao++;
   if(g_choChiBao <= PG_CHO_CHI_BAO)
      return false;
   g_choChiBao = 0;
   PrintFormat("PG: chỉ báo M5 chưa tính xong nến mới sau %d lần chờ, dùng giá trị hiện có", PG_CHO_CHI_BAO);
   return true;
  }

//+------------------------------------------------------------------+
//| NẾN M5: hộp giá, chỉ báo, trạng thái cấu trúc                     |
//| shift = nến M5 được tính (1 = nến vừa đóng). imLang = không thông |
//| báo, không ghi log (dùng khi khởi động nóng).                      |
//+------------------------------------------------------------------+
bool TinhM5(const int shift, const bool imLang)
  {
   int can = MathMax(InpNBox, InpNER + 1) + 2;
   MqlRates r[];
   int n = CopyRates(_Symbol, PERIOD_M5, shift, can, r);   // r[0] cũ nhất, r[n-1] là nến tại shift
   if(n < can)
      return false;
   double b1[], b2[], b3[], b4[];
   if(CopyBuffer(g_hATR5, 0, shift, 1, b1) != 1 || b1[0] <= 0.0 ||
      CopyBuffer(g_hADX5, 0, shift, 1, b2) != 1 || CopyBuffer(g_hADX5, 1, shift, 1, b3) != 1 ||
      CopyBuffer(g_hADX5, 2, shift, 1, b4) != 1)
      return false;
   if(!ChiBaoDaCapNhat())
      return false;
   g_atr5  = b1[0];
   g_adx   = b2[0];
   g_diP   = b3[0];
   g_diM   = b4[0];
   g_nenM5 = r[n - 1].time;

   // hộp giá, chạm biên, ER và độ dốc trên cửa sổ đầy đủ
   HopGia(r, n, InpNBox, g_U, g_L, g_tU, g_tL);
   g_W = g_U - g_L;
   g_M = (g_U + g_L) / 2.0;
   g_hopT1 = r[n - InpNBox].time;
   ErVaDoDoc(r, n, InpNER, g_er, g_beta);

   // trạng thái thô theo Mục 6 kế hoạch
   PG_CAU_TRUC tho = PG_CT_KHONG_RO;
   if(DieuKienSideways(g_W, g_tU, g_tL, g_er, g_beta))
      tho = PG_CT_SIDEWAYS;
   else
      if(g_adx >= InpADXTrend && g_diP > g_diM && g_er >= InpERTrend && g_beta >= InpBetaTrend)
         tho = PG_CT_TANG;
      else
         if(g_adx >= InpADXTrend && g_diM > g_diP && g_er >= InpERTrend && g_beta <= -InpBetaTrend)
            tho = PG_CT_GIAM;

   // chống nhấp nháy: phải đúng liên tiếp InpHVao nến (hoặc InpHRa nến khi về KHÔNG RÕ)
   if(tho == g_ctUngVien)
      g_ctChuoi++;
   else
     {
      g_ctUngVien = tho;
      g_ctChuoi = 1;
     }
   int canChuoi = (g_ctUngVien == PG_CT_KHONG_RO) ? InpHRa : InpHVao;
   if(g_ctUngVien != g_ct && g_ctChuoi >= canChuoi)
     {
      string cu = TenCauTruc(g_ct);
      g_ct = g_ctUngVien;
      if(!imLang)
        {
         ThemThongBao("Cấu trúc: " + TenHienThi(cu) + " → " + TenHienThi(TenCauTruc(g_ct)));
         GhiLog("CT_DOI");
        }
     }

   // hộp sau breakout: chỉ các nến mở từ mốc (xác nhận breakout hoặc vùng đang giữ), tối đa InpNBox nến
   datetime moc = (g_boGiaiDoan == 2) ? g_boMoc : ((g_boGiaiDoan == 0 && g_hopSauBO) ? g_vungMoc : (datetime)0);
   g_cK = 0;
   if(moc > 0)
     {
      int k = 0;
      for(int i = n - 1; i >= 0 && r[i].time >= moc; i--)
         k++;
      k = MathMin(k, InpNBox);
      if(k >= 5)
        {
         HopGia(r, n, k, g_cU, g_cL, g_cTU, g_cTL);
         g_cW = g_cU - g_cL;
         g_cM = (g_cU + g_cL) / 2.0;
         g_cT1 = r[n - k].time;
         ErVaDoDoc(r, n, MathMin(k, InpNER), g_cEr, g_cBeta);
         g_cK = k;
        }
     }

   g_duLieuSan = true;
   XuLyHopThamChieu(imLang);
   if(!imLang)
      GhiLog("M5");
   return true;
  }

//--- Hộp giá trên k nến cuối của r[]: biên trên/dưới và số đỉnh/đáy swing (fractal 2 nến mỗi bên) sát biên
void HopGia(const MqlRates &r[], const int n, const int k, double &U, double &L, int &tU, int &tL)
  {
   int dau = n - k;
   U = r[dau].high;
   L = r[dau].low;
   for(int i = dau + 1; i < n; i++)
     {
      if(r[i].high > U)
         U = r[i].high;
      if(r[i].low < L)
         L = r[i].low;
     }
   double W = U - L;
   tU = 0;
   tL = 0;
   for(int i = dau + 2; i <= n - 3; i++)
     {
      bool laDinh = r[i].high > r[i - 1].high && r[i].high > r[i - 2].high && r[i].high >= r[i + 1].high && r[i].high >= r[i + 2].high;
      bool laDay  = r[i].low < r[i - 1].low && r[i].low < r[i - 2].low && r[i].low <= r[i + 1].low && r[i].low <= r[i + 2].low;
      if(laDinh && r[i].high >= U - InpTau * W)
         tU++;
      if(laDay && r[i].low <= L + InpTau * W)
         tL++;
     }
  }

//--- Hiệu suất xu hướng Kaufman trên N nến cuối và độ dốc hồi quy Close (đơn vị ATR M5 mỗi nến)
void ErVaDoDoc(const MqlRates &r[], const int n, const int N, double &er, double &beta)
  {
   double tuSo = MathAbs(r[n - 1].close - r[n - 1 - N].close), mauSo = 0.0;
   for(int i = n - N; i < n; i++)
      mauSo += MathAbs(r[i].close - r[i - 1].close);
   er = (mauSo > 0.0) ? tuSo / mauSo : 0.0;
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int j = 0; j < N; j++)
     {
      double x = j, y = r[n - N + j].close;
      sx  += x;
      sy  += y;
      sxx += x * x;
      sxy += x * y;
     }
   double md = N * sxx - sx * sx;
   beta = (md != 0.0 && g_atr5 > 0.0) ? ((N * sxy - sx * sy) / md) / g_atr5 : 0.0;
  }

//--- Điều kiện SIDEWAYS của Mục 6 cho một hộp
bool DieuKienSideways(const double W, const int tU, const int tL, const double er, const double beta)
  {
   if(g_atr5 <= 0.0)
      return false;
   double wAtr = W / g_atr5;
   return wAtr >= InpWMin && wAtr <= InpWMax && g_adx < InpADXSideways && er < InpERSideways &&
          tU >= InpMinCham && tL >= InpMinCham && MathAbs(beta) < InpBetaSideways;
  }

//+------------------------------------------------------------------+
//| Hộp tham chiếu, vùng mới, hộp sau breakout                        |
//+------------------------------------------------------------------+
void XuLyHopThamChieu(const bool imLang)
  {
   // 1) đang có breakout: đếm nến, theo dõi đỉnh ADX; sau xác nhận thì chờ vùng mới
   if(g_boGiaiDoan > 0)
     {
      g_boSoNen++;
      if(g_adx > g_boAdxDinh)
         g_boAdxDinh = g_adx;
      if(g_boGiaiDoan == 2)
         XuLySauXacNhan(imLang);
      return;
     }
   // 2) đang giữ hộp sau breakout (vùng mới, hoặc sideways lại quanh hộp cũ)
   if(g_hopSauBO)
     {
      if(g_cK >= InpNMinVungMoi && DieuKienSideways(g_cW, g_cTU, g_cTL, g_cEr, g_cBeta))
        {
         g_vungSai = 0;
         DatHopThamChieu(g_cU, g_cL, g_cT1);
         return;
        }
      g_vungSai++;
      if(g_vungSai < InpHRa)
         return;                                  // chống nhấp nháy: giữ hộp hiện tại
      if(!imLang)
        {
         ThemThongBao((g_laVungMoi ? "Vùng mới" : "Hộp sau breakout") + " kết thúc: không còn sideways");
         GhiLog("HOP_SAU_BREAKOUT_KET_THUC");
        }
      g_hopSauBO = false;
      g_laVungMoi = false;
      g_vungMoc = 0;
      g_vungSai = 0;
     }
   // 3) hộp sideways thông thường theo trạng thái cấu trúc
   if(g_ct == PG_CT_SIDEWAYS)
     {
      if(!g_hopOk && !imLang)
         ThemThongBao("Hộp giá sideways: " + FGia(g_L) + " – " + FGia(g_U));
      DatHopThamChieu(g_U, g_L, g_hopT1);
     }
   else
      g_hopOk = false;
  }

void DatHopThamChieu(const double U, const double L, const datetime t1)
  {
   g_rU = U;
   g_rL = L;
   g_rW = U - L;
   g_rM = (U + L) / 2.0;
   g_rT1 = t1;
   g_hopOk = true;
  }

//--- Sau xác nhận: VÙNG MỚI, sideways lại quanh hộp cũ, hoặc hết thời gian theo dõi
void XuLySauXacNhan(const bool imLang)
  {
   // xu hướng cùng chiều breakout: chỉ ghi nhận một lần, vẫn tiếp tục chờ vùng mới
   if(!g_boDaBaoXuHuong && ((g_ct == PG_CT_TANG && g_boHuong > 0) || (g_ct == PG_CT_GIAM && g_boHuong < 0)))
     {
      g_boDaBaoXuHuong = true;
      if(!imLang)
        {
         ThemThongBao("Sau breakout: xu hướng " + (g_boHuong > 0 ? "TĂNG" : "GIẢM"));
         GhiLog("XU_HUONG_SAU_BREAKOUT");
        }
     }
   bool sideways = g_cK >= InpNMinVungMoi && DieuKienSideways(g_cW, g_cTU, g_cTL, g_cEr, g_cBeta);
   bool lech     = MathAbs(g_cM - g_rM) >= 0.5 * g_rW;
   g_vmDung = (sideways && lech && g_adx <= g_boAdxDinh - InpDeltaADX) ? g_vmDung + 1 : 0;
   g_vcDung = (sideways && !lech) ? g_vcDung + 1 : 0;
   if(g_vmDung >= InpHVao || g_vcDung >= InpHVao)
     {
      bool vm = (g_vmDung >= InpHVao);
      DatHopThamChieu(g_cU, g_cL, g_cT1);
      g_hopSauBO  = true;
      g_laVungMoi = vm;
      g_vungMoc   = g_boMoc;
      g_vungSai   = 0;
      KetThucBreakout();
      if(!imLang)
        {
         if(vm)
           {
            ThemThongBao("VÙNG MỚI: " + FGia(g_rL) + " – " + FGia(g_rU));
            GhiLog("VUNG_MOI");
           }
         else
           {
            ThemThongBao("Breakout không tạo vùng mới: sideways lại quanh hộp cũ");
            GhiLog("KHONG_THANH_VUNG_MOI");
           }
        }
      return;
     }
   if(g_boSoNen >= InpNMaxTheoDoi)
     {
      if(!imLang)
        {
         ThemThongBao("Dừng theo dõi breakout: " + IntegerToString(InpNMaxTheoDoi) + " nến M5 chưa có vùng mới");
         GhiLog("BREAKOUT_HET_THEO_DOI");
        }
      KetThucBreakout();
      g_hopOk = false;
      g_hopSauBO = false;
      g_laVungMoi = false;
      g_vungMoc = 0;
     }
  }

void KetThucBreakout()
  {
   g_boHuong = 0;
   g_boGiaiDoan = 0;
   g_boBatDau = 0;
   g_boMoc = 0;
   g_boNgoaiTuMsc = 0;
   g_boAdxDinh = 0.0;
   g_boSoNen = 0;
   g_vmDung = 0;
   g_vcDung = 0;
   g_boDaBaoXuHuong = false;
  }

//+------------------------------------------------------------------+
//| BREAKOUT THEO TICK: cảnh báo, xác nhận, breakout giả             |
//+------------------------------------------------------------------+
void KiemTraBreakoutTick(const datetime tg, const long msc)
  {
   if(!g_hopOk || g_atr5 <= 0.0)
      return;
   double bid = g_bid;
   if(g_boGiaiDoan == 0)
     {
      bool len   = bid >= g_rU + InpBW * g_atr5 || (bid > g_rU && g_vTick >= InpVW && g_lambda >= InpLambdaW);
      bool xuong = bid <= g_rL - InpBW * g_atr5 || (bid < g_rL && g_vTick <= -InpVW && g_lambda >= InpLambdaW);
      if(!len && !xuong)
         return;
      g_boHuong = len ? 1 : -1;
      g_boGiaiDoan = 1;
      g_boBatDau = tg;
      g_boNgoaiTuMsc = msc;
      g_boAdxDinh = g_adx;
      g_boSoNen = 0;
      ThemThongBao("CẢNH BÁO breakout " + MuiTen(g_boHuong) + " tại " + FGia(bid));
      GhiLog("CANH_BAO");
      return;
     }

   bool ngoai = (g_boHuong > 0) ? (bid > g_rU) : (bid < g_rL);
   if(!ngoai)
      g_boNgoaiTuMsc = 0;
   else
      if(g_boNgoaiTuMsc == 0)
         g_boNgoaiTuMsc = msc;

   bool trongHan = (tg - g_boBatDau) <= (long)InpTFPhut * 60;
   bool quayVao  = (g_boHuong > 0) ? (bid <= g_rU - InpRF * g_rW) : (bid >= g_rL + InpRF * g_rW);
   if(trongHan && quayVao)
     {
      g_giaDenLuc = tg + 300;
      ThemThongBao("BREAKOUT GIẢ " + MuiTen(g_boHuong) + ": giá quay lại hộp");
      GhiLog("BREAKOUT_GIA");
      KetThucBreakout();
      return;
     }

   if(g_boGiaiDoan == 1)
     {
      bool xa  = (g_boHuong > 0) ? (bid >= g_rU + InpBX * g_atr5) : (bid <= g_rL - InpBX * g_atr5);
      bool lau = g_boNgoaiTuMsc > 0 && (msc - g_boNgoaiTuMsc) >= (long)InpTCGiay * 1000;
      if(xa || lau)
        {
         XacNhanBreakout(xa ? "giá vượt xa biên" : "ở ngoài biên đủ lâu", tg);
         return;
        }
      if(!trongHan)
        {
         ThemThongBao("Cảnh báo breakout " + MuiTen(g_boHuong) + " hết hạn, chưa xác nhận");
         GhiLog("CANH_BAO_HET_HAN");
         KetThucBreakout();
        }
     }
  }

void XacNhanBreakout(const string lyDo, const datetime tg)
  {
   g_boGiaiDoan = 2;
   g_boMoc = LamTronLenM5(tg);
   g_vmDung = 0;
   g_vcDung = 0;
   ThemThongBao("XÁC NHẬN breakout " + MuiTen(g_boHuong) + " (" + lyDo + ")");
   GhiLog("XAC_NHAN");
  }

void KiemTraXacNhanM1()
  {
   if(g_boGiaiDoan != 1 || g_atr5 <= 0.0)
      return;
   double c = iClose(_Symbol, PERIOD_M1, 1);
   if(c <= 0.0)
      return;
   if((g_boHuong > 0 && c >= g_rU + InpBC * g_atr5) || (g_boHuong < 0 && c <= g_rL - InpBC * g_atr5))
      XacNhanBreakout("nến M1 đóng vượt biên", g_tickCuoi);
  }

//--- Giờ mở của nến M5 đầu tiên bắt đầu tại hoặc sau thời điểm t
datetime LamTronLenM5(const datetime t)
  {
   long p = PeriodSeconds(PERIOD_M5);
   long v = (long)t;
   return (datetime)(((v + p - 1) / p) * p);
  }

//+------------------------------------------------------------------+
//| SPREAD VÀ BỘ LỌC KHÔNG VÀO LỆNH                                   |
//+------------------------------------------------------------------+
void LayMauSpread()
  {
   if(g_bid <= 0.0 || g_ask <= 0.0)
      return;
   if(TimeTradeServer() - g_tickCuoi > 10)
      return;                               // không lấy mẫu khi không có tick (giờ nghỉ, mất kết nối)
   int sp = (int)MathRound((g_ask - g_bid) / g_point);
   if(sp < 0)
      return;
   if(sp > PG_MAX_SPREAD)
      sp = PG_MAX_SPREAD;
   if(g_spSo == PG_SP_RING)
      g_spHist[g_spVong[g_spViTri]]--;
   else
      g_spSo++;
   g_spVong[g_spViTri] = sp;
   g_spHist[sp]++;
   g_spViTri = (g_spViTri + 1) % PG_SP_RING;
   int nua = (g_spSo + 1) / 2, cong = 0;
   for(int i = 0; i <= PG_MAX_SPREAD; i++)
     {
      cong += g_spHist[i];
      if(cong >= nua)
        {
         g_spTrungVi = i;
         break;
        }
     }
  }

//--- Spread hiện tại ≤ min(ngưỡng tuyệt đối, bội số × trung vị 30 phút)
bool SpreadDat()
  {
   int    sp = (int)MathRound((g_ask - g_bid) / g_point);
   double nguongAbs = InpSpreadAbs / g_point;
   double nguongTv = (g_spTrungVi > 0) ? InpSpreadLan * g_spTrungVi : nguongAbs;
   return sp <= MathMin(nguongAbs, nguongTv) + 0.5;
  }

bool TrongPhien(const datetime bayGio, const int giayDem)
  {
   MqlDateTime dt;
   TimeToStruct(bayGio, dt);
   long     giay = dt.hour * 3600 + dt.min * 60 + dt.sec;
   datetime tu = 0, den = 0;
   for(uint k = 0; k < 10; k++)
     {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, k, tu, den))
         break;
      long a = (long)tu, b = (long)den;
      if(giay < a || giay >= b)
         continue;
      if(b >= 86400)
         return true;                      // phiên kéo qua nửa đêm sang ngày sau
      if(giay + giayDem < b)
         return true;
     }
   return false;
  }

void CapNhatLoc()
  {
   string   ly = "", ma = "OK";
   datetime bayGio = TimeTradeServer();
   if(!g_duLieuSan)
     {
      ly = "Chờ dữ liệu M5/chỉ báo";
      ma = "CHO_DU_LIEU";
     }
   else
      if(!TrongPhien(bayGio, 0))
        {
         ly = "Ngoài phiên giao dịch";
         ma = "NGOAI_PHIEN";
        }
      else
         if(!TrongPhien(bayGio, InpPhutTruocNghi * 60))
           {
            ly = "Sát giờ nghỉ";
            ma = "SAT_GIO_NGHI";
           }
         else
            if(g_tickCuoi > 0 && bayGio - g_tickCuoi > InpMatTickGiay)
              {
               ly = "Mất tick";
               ma = "MAT_TICK";
              }
            else
               if(!SpreadDat())
                 {
                  ly = "Spread giãn";
                  ma = "SPREAD_GIAN";
                 }
   g_loc = (ma == "OK");
   g_lyDoLoc = g_loc ? "ĐƯỢC" : ly;
   g_maLoc = ma;
  }

//+------------------------------------------------------------------+
//| TÀI KHOẢN: đầu ngày, đỉnh Equity, drawdown (lưu GlobalVariable)   |
//+------------------------------------------------------------------+
void KhoiTaoTaiKhoan()
  {
   string k = "PG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString(InpMagic) + "_";
   g_gvDinh    = k + "dinh_eq";
   g_gvDDMax   = k + "dd_max";
   g_gvNgay    = k + "ngay";
   g_gvDauNgay = k + "dau_ngay_eq";
   g_gvTamDung = k + "tam_dung";
   g_gvGio     = k + "g_";
   g_gvSauSO   = k + "sau_stop_out";
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_tester)
     {
      // tester: không dùng số liệu lưu từ lần chạy khác
      g_dinhEq = eq;
      g_ddMax = 0.0;
      g_ngay = -1;
      g_dauNgayEq = eq;
      return;
     }
   g_dinhEq    = GlobalVariableCheck(g_gvDinh) ? GlobalVariableGet(g_gvDinh) : eq;
   g_ddMax     = GlobalVariableCheck(g_gvDDMax) ? GlobalVariableGet(g_gvDDMax) : 0.0;
   g_ngay      = GlobalVariableCheck(g_gvNgay) ? (int)GlobalVariableGet(g_gvNgay) : -1;
   g_dauNgayEq = GlobalVariableCheck(g_gvDauNgay) ? GlobalVariableGet(g_gvDauNgay) : eq;
   g_tamDungTay = GlobalVariableCheck(g_gvTamDung) && GlobalVariableGet(g_gvTamDung) > 0.5;
   g_sauStopOut = GlobalVariableCheck(g_gvSauSO) && GlobalVariableGet(g_gvSauSO) > 0.5;
   // cùng ngày với Equity đầu ngày đã lưu: cộng các khoản nạp / rút từ đầu ngày (chưa có trong Equity đầu ngày)
   int homNay = (int)((long)TimeCurrent() / 86400);
   if(g_ngay == homNay)
      TongNapRut((datetime)((long)homNay * 86400), TimeCurrent() + 86400, g_napHomNay, g_rutHomNay);
   g_napRutHomNay = g_napHomNay - g_rutHomNay;
  }

void CapNhatTaiKhoan()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   int    ngay = (int)((long)TimeCurrent() / 86400);
   if(ngay != g_ngay)
     {
      // tổng kết ngày cũ chỉ khi EA đã chạy qua ngày đó (không ghi ở lần cập nhật đầu tiên sau khi gắn EA)
      if(g_ngay >= 0 && g_daCapNhatTK)
         GhiTongKetNgay(g_ngay, eq);
      g_ngay = ngay;
      g_dauNgayEq = eq;
      g_lenhHomNay = 0;
      g_tkGioHomNay = 0;
      g_tkTiaHomNay = 0;
      g_tkStopOutHomNay = 0;
      g_tkRongHomNay = 0.0;
      g_ddNgayMax = 0.0;
      g_napRutHomNay = 0.0;
      g_napHomNay = 0.0;
      g_rutHomNay = 0.0;
     }
   g_daCapNhatTK = true;
   if(eq > g_dinhEq)
      g_dinhEq = eq;
   double dd = (g_dinhEq > 0.0) ? (g_dinhEq - eq) / g_dinhEq * 100.0 : 0.0;
   if(dd > g_ddMax)
      g_ddMax = dd;
   static datetime lanLuu = 0;
   if(TimeLocal() - lanLuu >= 30)
     {
      LuuTaiKhoan();
      lanLuu = TimeLocal();
     }
  }

void LuuTaiKhoan()
  {
   if(g_gvDinh == "" || g_tester)
      return;
   GlobalVariableSet(g_gvDinh, g_dinhEq);
   GlobalVariableSet(g_gvDDMax, g_ddMax);
   GlobalVariableSet(g_gvNgay, g_ngay);
   GlobalVariableSet(g_gvDauNgay, g_dauNgayEq);
  }

void DemViThe(int &soPG, int &soKhac)
  {
   soPG = 0;
   soKhac = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         soPG++;
      else
         soKhac++;
     }
  }

//+------------------------------------------------------------------+
//| TÊN HIỂN THỊ                                                      |
//+------------------------------------------------------------------+
string TenCauTruc(const PG_CAU_TRUC c)
  {
   if(c == PG_CT_SIDEWAYS)
      return "SIDEWAYS";
   if(c == PG_CT_TANG)
      return "TANG";
   if(c == PG_CT_GIAM)
      return "GIAM";
   return "KHONG_RO";
  }

string TenThiTruong()
  {
   if(g_boGiaiDoan == 1)
      return (g_boHuong > 0) ? "CANH_BAO_TANG" : "CANH_BAO_GIAM";
   if(g_boGiaiDoan == 2)
      return (g_boHuong > 0) ? "BREAKOUT_TANG" : "BREAKOUT_GIAM";
   if(g_hopOk)
      return g_laVungMoi ? "VUNG_MOI" : "SIDEWAYS";
   return TenCauTruc(g_ct);
  }

string TenHienThi(const string ma)
  {
   if(ma == "TANG")
      return "TĂNG";
   if(ma == "GIAM")
      return "GIẢM";
   if(ma == "KHONG_RO")
      return "KHÔNG RÕ";
   if(ma == "CANH_BAO_TANG")
      return "CẢNH BÁO ↑";
   if(ma == "CANH_BAO_GIAM")
      return "CẢNH BÁO ↓";
   if(ma == "BREAKOUT_TANG")
      return "BREAKOUT ↑";
   if(ma == "BREAKOUT_GIAM")
      return "BREAKOUT ↓";
   if(ma == "VUNG_MOI")
      return "VÙNG MỚI";
   return ma;
  }

string MuiTen(const int huong)  { return (huong > 0) ? "↑" : "↓"; }
string FGia(const double v)     { return DoubleToString(v, g_digits); }
string FTien(const double v)    { return DoubleToString(v, 2); }
string DauTien(const double v)  { return (v > 0.0 ? "+" : "") + DoubleToString(v, 2); }
color  MauDau(const double v)   { return (v > 0.0) ? CLR_XANH : ((v < 0.0) ? CLR_DO : CLR_CHU); }
int    S(const double v)        { return (int)MathRound(v * g_s); }
int    FS(const int coBan)      { return MathMax(6, (int)MathRound(coBan * g_sf)); }

void ThemThongBao(const string s)
  {
   for(int i = PG_SO_THONG_BAO - 1; i > 0; i--)
      g_thongBao[i] = g_thongBao[i - 1];
   datetime tg = (g_tickCuoi > 0) ? g_tickCuoi : TimeCurrent();
   g_thongBao[0] = "[" + TimeToString(tg, TIME_MINUTES) + "] " + s;
   Print("PG: ", s);
  }

//+------------------------------------------------------------------+
//| LOG CSV trong <Common>\Files\<thư mục>:                           |
//| PG_V020_<loại>_<symbol>_<YYYYMMDD hoặc YYYYMM>.csv                |
//| Theo ngày: tín hiệu, giao dịch, basket, thực thi. Theo tháng:     |
//| trạng thái thị trường, tổng kết ngày. Tester: tên có "tester",    |
//| ghi mới mỗi lần chạy. Chạy tối ưu hóa: không ghi log.             |
//+------------------------------------------------------------------+
datetime ThoiGianHienTai() { return (g_tickCuoi > 0) ? g_tickCuoi : TimeCurrent(); }

bool MoFileLog(int &h, string &kyMo, const string loai, const string tieuDe, const bool theoNgay, const datetime moc = 0)
  {
   MqlDateTime dt;
   TimeToStruct((moc > 0) ? moc : ThoiGianHienTai(), dt);
   string ky = theoNgay ? StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day) : StringFormat("%04d%02d", dt.year, dt.mon);
   if(h != INVALID_HANDLE && ky == kyMo)
      return true;
   DongFileLog(h);
   string ten = InpThuMucLog + "\\PG_V020_" + loai + "_" + _Symbol + (g_tester ? "_tester_" : "_") + ky + ".csv";
   int co = FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
   if(!g_tester)
      co |= FILE_READ;
   h = FileOpen(ten, co, ';', CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("PG: không mở được log %s (lỗi %d)", ten, GetLastError());
      return false;
     }
   if(FileSize(h) == 0)
      FileWriteString(h, tieuDe + "\r\n");
   FileSeek(h, 0, SEEK_END);
   kyMo = ky;
   return true;
  }

void DongFileLog(int &h)
  {
   if(h == INVALID_HANDLE)
      return;
   FileClose(h);
   h = INVALID_HANDLE;
  }

void GhiLog(const string suKien)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   if(!MoFileLog(g_log, g_logThang, "trang_thai", PG_TD_TT, false))
      return;
   bool coC = (g_cK > 0);
   FileWrite(g_log,
             TimeToString((g_tickCuoi > 0) ? g_tickCuoi : TimeCurrent(), TIME_DATE | TIME_SECONDS),
             IntegerToString(g_msCuoi), suKien,
             (g_nenM5 > 0) ? TimeToString(g_nenM5, TIME_DATE | TIME_MINUTES) : "",
             FGia(g_bid), FGia(g_ask), IntegerToString((int)MathRound((g_ask - g_bid) / g_point)),
             TenCauTruc(g_ct), TenThiTruong(),
             g_hopOk ? FGia(g_rU) : "", g_hopOk ? FGia(g_rL) : "", g_hopOk ? FGia(g_rW) : "",
             FGia(g_U), FGia(g_L),
             DoubleToString(g_atr5, 3), DoubleToString(g_atr1, 3), DoubleToString(g_adx, 2),
             DoubleToString(g_diP, 2), DoubleToString(g_diM, 2), DoubleToString(g_er, 3), DoubleToString(g_beta, 4),
             IntegerToString(g_tU), IntegerToString(g_tL), DoubleToString(g_vTick, 3), DoubleToString(g_lambda, 2),
             IntegerToString(g_boSoNen), DoubleToString(g_boAdxDinh, 2),
             IntegerToString(g_cK), coC ? FGia(g_cU) : "", coC ? FGia(g_cL) : "",
             g_maLoc);
   FileFlush(g_log);
  }

//+------------------------------------------------------------------+
//| VẼ HỘP GIÁ VÀ MỨC CẢNH BÁO TRÊN CHART                             |
//+------------------------------------------------------------------+
void VeHop()
  {
   string   rn = PG_P + "hop", nt = PG_P + "cb_tren", nd = PG_P + "cb_duoi", rs = PG_P + "hop_sau";
   datetime t2 = TimeCurrent() + 1800;
   if(g_boGiaiDoan == 2 && g_cK > 0)
      DatHinhChuNhat(rs, g_cT1, g_cU, t2, g_cL, CLR_CAM, false);
   else
      ObjectDelete(0, rs);
   if(!g_hopOk || g_atr5 <= 0.0)
     {
      ObjectDelete(0, rn);
      ObjectDelete(0, nt);
      ObjectDelete(0, nd);
      return;
     }
   color c = (g_boGiaiDoan > 0) ? C'95,42,10' : (g_laVungMoi ? C'15,62,58' : C'72,56,12');
   DatHinhChuNhat(rn, g_rT1, g_rU, t2, g_rL, c, true);
   DatDuongNgang(nt, g_rU + InpBW * g_atr5);
   DatDuongNgang(nd, g_rL - InpBW * g_atr5);
  }

void DatHinhChuNhat(const string ten, const datetime t1, const double p1, const datetime t2, const double p2,
                    const color c, const bool to)
  {
   if(ObjectFind(0, ten) < 0)
     {
      ObjectCreate(0, ten, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, ten, OBJPROP_BACK, true);
      ObjectSetInteger(0, ten, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ten, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, ten, OBJPROP_FILL, to);
   ObjectSetInteger(0, ten, OBJPROP_STYLE, to ? STYLE_SOLID : STYLE_DOT);
   ObjectSetInteger(0, ten, OBJPROP_COLOR, c);
   ObjectMove(0, ten, 0, t1, p1);
   ObjectMove(0, ten, 1, t2, p2);
  }

void DatDuongNgang(const string ten, const double gia)
  {
   if(ObjectFind(0, ten) < 0)
     {
      ObjectCreate(0, ten, OBJ_HLINE, 0, 0, gia);
      ObjectSetInteger(0, ten, OBJPROP_COLOR, CLR_CAM);
      ObjectSetInteger(0, ten, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, ten, OBJPROP_BACK, true);
      ObjectSetInteger(0, ten, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ten, OBJPROP_HIDDEN, true);
     }
   ObjectSetDouble(0, ten, OBJPROP_PRICE, 0, gia);
  }

//+------------------------------------------------------------------+
//| GIAO DIỆN: tiện ích tạo và cập nhật đối tượng                     |
//+------------------------------------------------------------------+
void TaoNen(const string id, const int x, const int y, const int w, const int h, const color nen, const color vien)
  {
   string n = PG_P + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, nen);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_COLOR, vien);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
  }

void TaoChu(const string id, const int x, const int y, const string text, const int fs, const color c,
            const string font = PG_FONT, const ENUM_ANCHOR_POINT neo = ANCHOR_LEFT_UPPER)
  {
   string n = PG_P + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, neo);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
  }

void TaoNut(const string id, const int x, const int y, const int w, const int h, const string text,
            const color nen, const color chu, const int fs)
  {
   string n = PG_P + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, PG_FONT_B);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
   ObjectSetInteger(0, n, OBJPROP_COLOR, chu);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, nen);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, CLR_VANG_DAM);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
  }

void TaoChip(const string id, const int x, const int y, const int w, const int h, const string text)
  {
   TaoNen(id, x, y, w, h, CLR_CHIP, CLR_VIEN);
   TaoChu(id + "_t", x + w / 2, y + h / 2, text, FS(7), CLR_MO, PG_FONT_B, ANCHOR_CENTER);
  }

void TaoDong(const string id, const int cot, const int y, const string nhan)
  {
   int xk = g_x0 + ((cot == 0) ? S(10) : g_pw / 2 + S(6));
   int xv = g_x0 + ((cot == 0) ? g_pw / 2 - S(8) : g_pw - S(10));
   TaoChu(id + "_k", xk, y, nhan, FS(8), CLR_MO, PG_FONT);
   TaoChu(id + "_v", xv, y, "—", FS(8), CLR_CHU, PG_FONT_B, ANCHOR_RIGHT_UPPER);
  }

int TaoKhung(const string id, const int y, const int soDong, const string tieuDe)
  {
   int h = S(19) + soDong * S(15) + S(5);
   TaoNen(id, g_x0, y, g_pw, h, CLR_KHUNG, CLR_VIEN);
   TaoChu(id + "_td", g_x0 + S(8), y + S(3), tieuDe, FS(8), CLR_VANG, PG_FONT_B);
   return h;
  }

void DatChu(const string id, const string text, const color c)
  {
   string n = PG_P + id;
   if(ObjectFind(0, n) < 0)
      return;
   if(ObjectGetString(0, n, OBJPROP_TEXT) != text)
      ObjectSetString(0, n, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, n, OBJPROP_COLOR) != c)
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
  }

void DatNen(const string id, const color nen)
  {
   string n = PG_P + id;
   if(ObjectFind(0, n) < 0)
      return;
   if((color)ObjectGetInteger(0, n, OBJPROP_BGCOLOR) != nen)
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, nen);
  }

void DatGiaTri(const string id, const string text, const color c) { DatChu(id + "_v", text, c); }

void DatChip(const string id, const bool bat, const color nenBat, const color chuBat)
  {
   DatNen(id, bat ? nenBat : CLR_CHIP);
   string n = PG_P + id + "_t";
   if(ObjectFind(0, n) < 0)
      return;
   color c = bat ? chuBat : CLR_MO;
   if((color)ObjectGetInteger(0, n, OBJPROP_COLOR) != c)
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
  }

//+------------------------------------------------------------------+
//| DỰNG BẢNG ĐIỀU KHIỂN (neo góc trái trên chart)                    |
//+------------------------------------------------------------------+
void DungBang()
  {
   ObjectsDeleteAll(0, PG_P + "B_");
   g_pw = S(440);
   g_x0 = S(6);
   g_y0 = S(26);
   g_cw = (g_pw - S(16) - 5 * S(4)) / 6;
   int x = g_x0, y = g_y0;

   TaoNen("B_nen", x - S(3), y - S(3), g_pw + S(6), S(100), CLR_NEN, CLR_VANG_DAM);

   // đầu bảng: tên, số điện thoại, phiên bản, nút thu gọn ở góc phải
   int hDau = S(64);
   TaoNen("B_dau", x, y, g_pw, hDau, CLR_KHUNG, CLR_VIEN);
   TaoChu("B_ten1", x + S(10), y + S(4), "DAVID HUNTER", FS(15), CLR_VANG, PG_FONT_T);
   TaoChu("B_ten2", x + S(10), y + S(28), "PHOENIX GRID", FS(11), CLR_CAM, PG_FONT_T);
   TaoChu("B_ten3", x + S(10), y + S(47), "0941920986", FS(9), CLR_VANG, PG_FONT_B);
   TaoChu("B_pb", x + g_pw - S(34), y + S(6), PG_PHIEN_BAN, FS(7), CLR_MO, PG_FONT, ANCHOR_RIGHT_UPPER);
   TaoChu("B_tt_ea", x + g_pw - S(34), y + S(20), "—", FS(8), CLR_VANG, PG_FONT_B, ANCHOR_RIGHT_UPPER);
   TaoChu("B_mini", x + g_pw - S(8), y + S(46), "", FS(8), CLR_CHU, PG_FONT_B, ANCHOR_RIGHT_UPPER);
   TaoNut("B_thugon", x + g_pw - S(28), y + S(6), S(22), S(18), g_thuGon ? "+" : "–", CLR_CHIP, CLR_VANG, FS(10));
   y += hDau + S(4);
   if(g_thuGon)
     {
      ObjectSetInteger(0, PG_P + "B_nen", OBJPROP_YSIZE, hDau + S(6));
      return;
     }

   // trạng thái thị trường
   int hTT = S(62);
   TaoNen("B_k_tt", x, y, g_pw, hTT, CLR_KHUNG, CLR_VIEN);
   TaoChu("B_k_tt_td", x + S(8), y + S(3), "TRẠNG THÁI THỊ TRƯỜNG", FS(8), CLR_VANG, PG_FONT_B);
   string ids[6]  = {"B_c_sw", "B_c_tang", "B_c_giam", "B_c_bo", "B_c_gia", "B_c_vm"};
   string nhan[6] = {"SIDEWAYS", "TĂNG", "GIẢM", "BREAKOUT", "B.GIẢ", "VÙNG MỚI"};
   for(int i = 0; i < 6; i++)
      TaoChip(ids[i], x + S(8) + i * (g_cw + S(4)), y + S(19), g_cw, S(20), nhan[i]);
   TaoChu("B_ea", x + S(8), y + S(44), "EA: PHOENIX DCA · TỈA LỆNH", FS(8), CLR_CHU, PG_FONT);
   TaoChu("B_loc", x + g_pw - S(8), y + S(44), "Lọc vào lệnh: —", FS(8), CLR_MO, PG_FONT_B, ANCHOR_RIGHT_UPPER);
   y += hTT + S(4);

   // tài khoản
   int h = TaoKhung("B_k_tk", y, 5, "THÔNG TIN TÀI KHOẢN");
   int yr = y + S(19);
   TaoDong("B_a_bal", 0, yr, "Balance");
   TaoDong("B_a_eq", 1, yr, "Equity");
   yr += S(15);
   TaoDong("B_a_fl", 0, yr, "Lãi/lỗ thả nổi");
   TaoDong("B_a_hn", 1, yr, "Hôm nay");
   yr += S(15);
   TaoDong("B_a_dd", 0, yr, "Drawdown hiện tại");
   TaoDong("B_a_ddmax", 1, yr, "Drawdown lớn nhất");
   yr += S(15);
   TaoDong("B_a_fm", 0, yr, "Free margin");
   TaoDong("B_a_ml", 1, yr, "Margin level");
   yr += S(15);
   TaoDong("B_a_pg", 0, yr, "Vị thế Phoenix");
   TaoDong("B_a_khac", 1, yr, "Vị thế khác");
   y += h + S(4);

   // vùng giá và breakout
   h = TaoKhung("B_k_vg", y, 7, "VÙNG GIÁ & BREAKOUT");
   yr = y + S(19);
   TaoDong("B_v_tren", 0, yr, "Biên trên");
   TaoDong("B_v_duoi", 1, yr, "Biên dưới");
   yr += S(15);
   TaoDong("B_v_rong", 0, yr, "Độ rộng hộp");
   TaoDong("B_v_cb", 1, yr, "Cảnh báo ↑ / ↓");
   yr += S(15);
   TaoDong("B_v_atr", 0, yr, "ATR M5 / M1");
   TaoDong("B_v_adx", 1, yr, "ADX (DI+/DI−)");
   yr += S(15);
   TaoDong("B_v_er", 0, yr, "ER / Độ dốc");
   TaoDong("B_v_cham", 1, yr, "Chạm biên trên/dưới");
   yr += S(15);
   TaoDong("B_v_v", 0, yr, "Tốc độ tick");
   TaoDong("B_v_lam", 1, yr, "Mật độ tick");
   yr += S(15);
   TaoDong("B_v_bo", 0, yr, "Nến từ cảnh báo");
   TaoDong("B_v_sau", 1, yr, "Hộp sau breakout");
   yr += S(15);
   TaoDong("B_v_sp", 0, yr, "Spread hiện tại");
   TaoDong("B_v_sptv", 1, yr, "Trung vị 30p / ngưỡng");
   y += h + S(4);

   // Phoenix DCA: basket, tỉa, clear, khoảng cách tới lúc cháy
   h = TaoKhung("B_k_rr", y, 8, "PHOENIX DCA · TỈA LỆNH · CLEAR (KHÔNG CẮT LỖ)");
   yr = y + S(19);
   TaoDong("B_g_gui", 0, yr, "Gửi lệnh");
   TaoDong("B_g_td", 1, yr, "Tạm dừng");
   yr += S(15);
   TaoDong("B_g_gio", 0, yr, "Basket");
   TaoDong("B_g_lai", 1, yr, "Lãi ròng basket");
   yr += S(15);
   TaoDong("B_g_tang", 0, yr, "Tầng mở / sâu / tối đa");
   TaoDong("B_g_buoc", 1, yr, "Khoảng tầng / lot mở");
   yr += S(15);
   TaoDong("B_g_tia", 0, yr, "Tỉa / xóa (lãi chốt)");
   TaoDong("B_g_muc", 1, yr, "Mốc clear basket");
   yr += S(15);
   TaoDong("B_g_hv", 0, yr, "Giá hòa vốn / cần hồi");
   TaoDong("B_g_dinh", 1, yr, "Trailing clear");
   yr += S(15);
   TaoDong("B_g_chay", 0, yr, "Giá ngược tới cháy");
   TaoDong("B_g_pp", 1, yr, "Basket gần nhất");
   yr += S(15);
   TaoDong("B_g_hn", 0, yr, "Hôm nay: basket / ròng");
   TaoDong("B_g_nap", 1, yr, "Nạp / rút hôm nay");
   yr += S(15);
   TaoChu("B_g_lydo", x + S(10), yr, "—", FS(7), CLR_MO, PG_FONT);
   y += h + S(4);

   // chu kỳ 6 bước
   int hCK = S(19) + S(20) + S(6);
   TaoNen("B_k_ck", x, y, g_pw, hCK, CLR_KHUNG, CLR_VIEN);
   TaoChu("B_k_ck_td", x + S(8), y + S(3), "CHU KỲ PHOENIX", FS(8), CLR_VANG, PG_FONT_B);
   string ck[6] = {"1 Sideways", "2 DCA", "3 Breakout", "4 Hedge", "5 Vùng mới", "6 Chu kỳ"};
   for(int i = 0; i < 6; i++)
      TaoChip("B_ck" + IntegerToString(i + 1), x + S(8) + i * (g_cw + S(4)), y + S(19), g_cw, S(20), ck[i]);
   y += hCK + S(4);

   // thông báo
   int hTB = S(19) + 4 * S(14) + S(5);
   TaoNen("B_k_tb", x, y, g_pw, hTB, CLR_KHUNG, CLR_VIEN);
   TaoChu("B_k_tb_td", x + S(8), y + S(3), "THÔNG BÁO", FS(8), CLR_VANG, PG_FONT_B);
   for(int i = 0; i < 4; i++)
      TaoChu("B_tb" + IntegerToString(i), x + S(10), y + S(19) + i * S(14), "", FS(7), CLR_MO, PG_FONT);
   y += hTB + S(4);

   // nút điều khiển: xác nhận 2 bước (bấm lần 2 trong 5 giây)
   int bw = (g_pw - 3 * S(6)) / 4, bh = S(26);
   TaoNut("B_n_tieptuc", x, y, bw, bh, "TIẾP TỤC", C'25,110,55', CLR_CHU, FS(8));
   TaoNut("B_n_tamdung", x + bw + S(6), y, bw, bh, "TẠM DỪNG", C'150,105,10', CLR_CHU, FS(8));
   TaoNut("B_n_dongbk", x + 2 * (bw + S(6)), y, bw, bh, "ĐÓNG BASKET", C'150,55,30', CLR_CHU, FS(8));
   TaoNut("B_n_dongtc", x + 3 * (bw + S(6)), y, bw, bh, "ĐÓNG TẤT CẢ", C'170,35,30', CLR_CHU, FS(8));
   y += bh;
   ObjectSetInteger(0, PG_P + "B_nen", OBJPROP_YSIZE, y - g_y0 + S(6));
   g_nutCho = "";
  }

//+------------------------------------------------------------------+
//| CẬP NHẬT GIÁ TRỊ TRÊN BẢNG (chỉ ghi lại nhãn thay đổi)            |
//+------------------------------------------------------------------+
void CapNhatBang()
  {
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   string tt  = TenThiTruong();
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   color  cEA = CLR_VANG;
   string sEA = TrangThaiEA(cEA);
   DatChu("B_tt_ea", sEA, cEA);
   if(g_thuGon)
     {
      DatChu("B_mini", TenHienThi(tt) + "  ·  Equity " + FTien(eq) + " " + cur +
             (g_gioHuong != 0 ? "  ·  basket " + IntegerToString(SoTangMo()) + " tầng" : ""), CLR_CHU);
      return;
     }
   DatChu("B_mini", "", CLR_CHU);

   // chip trạng thái thị trường
   bool bo    = (g_boGiaiDoan > 0);
   bool coHop = (!bo && g_hopOk);
   DatChip("B_c_sw", coHop, C'214,160,20', CLR_NEN);
   DatChip("B_c_tang", g_ct == PG_CT_TANG, C'30,150,70', CLR_CHU);
   DatChip("B_c_giam", g_ct == PG_CT_GIAM, C'190,45,35', CLR_CHU);
   DatChip("B_c_bo", bo, C'230,90,20', CLR_NEN);
   DatChu("B_c_bo_t", bo ? ((g_boGiaiDoan == 1 ? "CẢNH BÁO " : "BREAKOUT ") + MuiTen(g_boHuong)) : "BREAKOUT",
          bo ? CLR_NEN : CLR_MO);
   DatChip("B_c_gia", TimeCurrent() < g_giaDenLuc, C'130,80,170', CLR_CHU);
   DatChip("B_c_vm", coHop && g_laVungMoi, C'20,140,140', CLR_CHU);
   DatChu("B_ea", (InpCheDo == PG_CD_GIAO_DICH) ? "EA: PHOENIX DCA · TỈA LỆNH" : "EA: QUAN SÁT — không gửi lệnh", CLR_CHU);
   DatChu("B_loc", "Lọc vào lệnh: " + g_lyDoLoc, g_loc ? CLR_XANH : CLR_CAM);

   // tài khoản
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double fl  = AccountInfoDouble(ACCOUNT_PROFIT);
   double hn  = eq - g_dauNgayEq - g_napRutHomNay;   // không tính tiền nạp / rút trong ngày
   double hnP = (g_dauNgayEq > 0.0) ? hn / g_dauNgayEq * 100.0 : 0.0;
   double dd  = (g_dinhEq > 0.0) ? (g_dinhEq - eq) / g_dinhEq * 100.0 : 0.0;
   double ml  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   int    soPG = 0, soKhac = 0;
   DemViThe(soPG, soKhac);
   DatGiaTri("B_a_bal", FTien(bal) + " " + cur, CLR_CHU);
   DatGiaTri("B_a_eq", FTien(eq) + " " + cur, CLR_CHU);
   DatGiaTri("B_a_fl", DauTien(fl), MauDau(fl));
   DatGiaTri("B_a_hn", DauTien(hn) + " (" + DoubleToString(hnP, 2) + "%)", MauDau(hn));
   DatGiaTri("B_a_dd", DoubleToString(dd, 2) + "%", (dd >= 5.0) ? CLR_CAM : CLR_CHU);
   DatGiaTri("B_a_ddmax", DoubleToString(g_ddMax, 2) + "%", CLR_CHU);
   DatGiaTri("B_a_fm", FTien(AccountInfoDouble(ACCOUNT_MARGIN_FREE)), CLR_CHU);
   DatGiaTri("B_a_ml", (ml > 0.0) ? DoubleToString(ml, 0) + "%" : "—", CLR_CHU);
   DatGiaTri("B_a_pg", IntegerToString(soPG), CLR_CHU);
   DatGiaTri("B_a_khac", IntegerToString(soKhac), (soKhac > 0) ? CLR_CAM : CLR_CHU);

   // vùng giá
   if(g_hopOk)
     {
      DatGiaTri("B_v_tren", FGia(g_rU), CLR_VANG);
      DatGiaTri("B_v_duoi", FGia(g_rL), CLR_VANG);
      DatGiaTri("B_v_rong", DoubleToString(g_rW, 2) + " (" + DoubleToString((g_atr5 > 0.0) ? g_rW / g_atr5 : 0.0, 1) + "×ATR)", CLR_CHU);
      DatGiaTri("B_v_cb", FGia(g_rU + InpBW * g_atr5) + " / " + FGia(g_rL - InpBW * g_atr5), CLR_CAM);
     }
   else
     {
      DatGiaTri("B_v_tren", "—", CLR_MO);
      DatGiaTri("B_v_duoi", "—", CLR_MO);
      DatGiaTri("B_v_rong", "chưa có hộp", CLR_MO);
      DatGiaTri("B_v_cb", "—", CLR_MO);
     }
   DatGiaTri("B_v_atr", DoubleToString(g_atr5, 2) + " / " + DoubleToString(g_atr1, 2), CLR_CHU);
   DatGiaTri("B_v_adx", DoubleToString(g_adx, 1) + " (" + DoubleToString(g_diP, 0) + "/" + DoubleToString(g_diM, 0) + ")", CLR_CHU);
   DatGiaTri("B_v_er", DoubleToString(g_er, 2) + " / " + DoubleToString(g_beta, 3), CLR_CHU);
   DatGiaTri("B_v_cham", IntegerToString(g_tU) + " / " + IntegerToString(g_tL), CLR_CHU);
   DatGiaTri("B_v_v", DoubleToString(g_vTick, 2) + "×ATR1", (MathAbs(g_vTick) >= InpVW) ? CLR_CAM : CLR_CHU);
   DatGiaTri("B_v_lam", DoubleToString(g_lambda, 2) + "×", (g_lambda >= InpLambdaW) ? CLR_CAM : CLR_CHU);
   DatGiaTri("B_v_bo", bo ? IntegerToString(g_boSoNen) + " / " + IntegerToString(InpNMaxTheoDoi) : "—", bo ? CLR_CHU : CLR_MO);
   if(g_cK > 0)
      DatGiaTri("B_v_sau", IntegerToString(g_cK) + " nến · W " + DoubleToString(g_cW, 2), CLR_CHU);
   else
      DatGiaTri("B_v_sau", "—", CLR_MO);

   int spNow = (int)MathRound((g_ask - g_bid) / g_point);
   DatGiaTri("B_v_sp", IntegerToString(spNow) + " pt (" + DoubleToString(spNow * g_point, 3) + ")", SpreadDat() ? CLR_CHU : CLR_CAM);
   DatGiaTri("B_v_sptv", IntegerToString(g_spTrungVi) + " / " + DoubleToString(InpSpreadAbs / g_point, 0) + " pt", CLR_CHU);

   // Phoenix DCA
   if(g_duocGui)
      DatGiaTri("B_g_gui", g_tester ? "TESTER" : (g_laTKThat ? "TÀI KHOẢN THẬT" : "DEMO"),
                (g_laTKThat && !g_tester) ? CLR_CAM : CLR_XANH);
   else
      DatGiaTri("B_g_gui", "KHÔNG", CLR_DO);
   string td = TrangThaiTamDung();
   DatGiaTri("B_g_td", td, (td == "Không") ? CLR_CHU : CLR_CAM);
   if(g_gioHuong != 0)
     {
      bool   du = true;
      double tn = LaiThaNoiBasket(du);
      double rong = g_gioDaChot + tn;
      DatGiaTri("B_g_gio", (g_gioHuong > 0 ? "BUY " : "SELL ") + g_gioPP + " · " + IntegerToString(g_gioSoLenh) + " lệnh",
                (g_gioHuong > 0) ? CLR_XANH : CLR_DO);
      DatGiaTri("B_g_lai", DauTien(rong) + " (thả nổi " + DauTien(tn) + ")", MauDau(rong));
      DatGiaTri("B_g_tang", IntegerToString(SoTangMo()) + " / " + IntegerToString(g_gioTangSau) + " / " +
                IntegerToString(InpSoTangToiDa - 1), CLR_CHU);
      DatGiaTri("B_g_buoc", DoubleToString(g_gioBuoc, 2) + " / " + DoubleToString(LotDangMo(), g_dgLot), CLR_CHU);
      DatGiaTri("B_g_tia", IntegerToString(g_gioSoTia) + " / " + IntegerToString(g_gioSoXoa) + " (" + DauTien(g_gioDaChot) + ")",
                MauDau(g_gioDaChot));
      double muc = MucTieuHienTai();
      DatGiaTri("B_g_muc", (muc < g_gioMucTieu) ? ((muc < 0.0) ? "RẤT SÂU: " + DauTien(muc) : "HÒA VỐN") : "lãi ròng " + DauTien(muc),
                (muc < g_gioMucTieu) ? CLR_CAM : CLR_VANG);
      double hv = GiaHoaVon();
      if(hv > 0.0)
        {
         double canHoi = (g_gioHuong > 0) ? hv - g_bid : g_ask - hv;
         DatGiaTri("B_g_hv", FGia(hv) + " / " + ((canHoi > 0.0) ? DoubleToString(canHoi, 1) + " USD" : "đã qua"),
                   (canHoi > 0.0) ? CLR_CAM : CLR_XANH);
        }
      else
         DatGiaTri("B_g_hv", "—", CLR_MO);
      if(g_gioDinhLai > 0.0)
         DatGiaTri("B_g_dinh", "đỉnh " + DauTien(g_gioDinhLai) + ", đóng ≤ " + DauTien(g_gioDinhLai * InpTrailGiuPT / 100.0), CLR_XANH);
      else
         DatGiaTri("B_g_dinh", InpTrailClear ? "chưa kích hoạt" : "tắt", CLR_MO);
     }
   else
     {
      DatGiaTri("B_g_gio", "chờ tín hiệu", CLR_MO);
      DatGiaTri("B_g_lai", "—", CLR_MO);
      DatGiaTri("B_g_tang", "0 / — / " + IntegerToString(InpSoTangToiDa - 1), CLR_MO);
      DatGiaTri("B_g_buoc", "~" + DoubleToString(MathMax(InpBuocMinUSD, InpBuocATR * g_atr5), 2) + " / " +
                DoubleToString(LotTang(0), g_dgLot), CLR_MO);
      DatGiaTri("B_g_tia", "—", CLR_MO);
      DatGiaTri("B_g_muc", "~lãi ròng " + DauTien(InpGioTPATR * g_atr5 * g_vpp * LotTang(0)), CLR_MO);
      DatGiaTri("B_g_hv", "—", CLR_MO);
      DatGiaTri("B_g_dinh", InpTrailClear ? "giữ " + DoubleToString(InpTrailGiuPT, 0) + "% đỉnh" : "tắt", CLR_MO);
     }
   int    soTangChay = 0;
   double dc = KhoangChay(soTangChay);
   if(dc >= 0.0)
      DatGiaTri("B_g_chay", ((g_gioHuong != 0) ? "" : "~") + DoubleToString(dc, 0) + " USD (" + IntegerToString(soTangChay) + " tầng)",
                (dc < 50.0) ? CLR_DO : ((dc < 150.0) ? CLR_CAM : CLR_CHU));
   else
      DatGiaTri("B_g_chay", "—", CLR_MO);
   DatGiaTri("B_g_pp", (g_gioCuoiKQ == "") ? "—" : g_gioCuoiKQ, CLR_CHU);
   DatGiaTri("B_g_hn", IntegerToString(g_tkGioHomNay) + " / " + DauTien(g_tkRongHomNay), MauDau(g_tkRongHomNay));
   DatGiaTri("B_g_nap", DauTien(g_napHomNay) + " / " + DauTien(-g_rutHomNay), CLR_CHU);
   string dongLy = "Xét gần nhất: " + ((g_ppGanNhat == "") ? "—" : g_ppGanNhat);
   color  mauLy = CLR_MO;
   if(!g_duocGui)
     {
      dongLy = "Không gửi lệnh: " + g_lyDoKhoa;
      mauLy = CLR_DO;
     }
   else
      if(g_loiNghiemTrong)
        {
         dongLy = "Tạm dừng: " + g_lyDoLoi + " — kiểm tra rồi bấm TIẾP TỤC";
         mauLy = CLR_CAM;
        }
      else
         if(g_lyDoTamDung != "")
           {
            dongLy = "Tạm dừng: " + g_lyDoTamDung;
            mauLy = CLR_CAM;
           }
         else
            if(g_gioHuong != 0 && g_gioLyDoCho != "")
              {
               dongLy = "DCA tầng " + IntegerToString(g_gioCho) + " chờ: " + g_gioLyDoCho;
               mauLy = CLR_CAM;
              }
   DatChu("B_g_lydo", dongLy, mauLy);

   // chu kỳ: 1 sideways, 2 DCA (basket từ 2 tầng), 3 breakout, 5 vùng mới, 6 vừa clear basket (5 phút); 4 hedge chưa có
   bool ck[6];
   ck[0] = (!bo && tt == "SIDEWAYS");
   ck[1] = (g_gioHuong != 0 && SoTangMo() >= 2);
   ck[2] = bo;
   ck[3] = false;
   ck[4] = (!bo && tt == "VUNG_MOI");
   ck[5] = (g_gioHuong == 0 && g_gioCuoiLuc > 0 && ThoiGianHienTai() - g_gioCuoiLuc < 300);
   for(int i = 1; i <= 6; i++)
      DatChip("B_ck" + IntegerToString(i), ck[i - 1], C'214,160,20', CLR_NEN);

   // thông báo
   for(int i = 0; i < 4; i++)
      DatChu("B_tb" + IntegerToString(i), g_thongBao[i], (i == 0) ? CLR_CHU : CLR_MO);
  }

//+------------------------------------------------------------------+
//| NÚT: xác nhận 2 bước (bấm lần 2 trong 5 giây)                     |
//| TIẾP TỤC: bỏ tạm dừng bằng nút, lỗi thực thi, khóa sau stop out. |
//| TẠM DỪNG: không mở basket / tầng mới; lệnh đang mở giữ TP.       |
//| ĐÓNG BASKET: đóng mọi tầng của basket đang chạy, EA chạy tiếp.   |
//| ĐÓNG TẤT CẢ: đóng mọi vị thế Phoenix của symbol và TẠM DỪNG.     |
//+------------------------------------------------------------------+
void XuLyNut(const string ten)
  {
   if(g_nutCho != ten)
     {
      HuyChoXacNhan();
      g_nutCho = ten;
      g_nutChoDen = TimeLocal() + 5;
      ObjectSetString(0, ten, OBJPROP_TEXT, "XÁC NHẬN? 5s");
      return;
     }
   HuyChoXacNhan();
   if(ten == PG_P + "B_n_tieptuc")
     {
      g_tamDungTay = false;
      g_loiNghiemTrong = false;
      g_lyDoLoi = "";
      g_loiLienTiep = 0;
      g_sauStopOut = false;
      g_choGuiDen = 0;
      LuuCo();
      ThemThongBao("Đã TIẾP TỤC");
      GhiLog("NUT_TIEP_TUC");
      return;
     }
   if(ten == PG_P + "B_n_tamdung")
     {
      g_tamDungTay = true;
      LuuCo();
      ThemThongBao("Đã TẠM DỪNG: không mở basket / tầng mới, lệnh đang mở giữ TP");
      GhiLog("NUT_TAM_DUNG");
      return;
     }
   if(ten == PG_P + "B_n_dongbk")
     {
      if(g_gioHuong == 0)
        {
         ThemThongBao("Không có basket đang chạy");
         return;
        }
      ThemThongBao("ĐÓNG BASKET theo nút");
      GhiLog("NUT_DONG_BASKET");
      DongBasket("NUT");
      return;
     }
   if(ten == PG_P + "B_n_dongtc")
     {
      g_tamDungTay = true;
      LuuCo();
      g_dongTatCaCho = true;
      if(g_gioHuong != 0 && !g_gioDangDong)
        {
         g_gioDangDong = true;
         g_gioLyDoDong = "NUT_DONG_TAT_CA";
        }
      ThemThongBao("ĐÓNG TẤT CẢ vị thế Phoenix và TẠM DỪNG");
      GhiLog("NUT_DONG_TAT_CA");
      DongTatCaPhoenix("NUT_DONG_TAT_CA");
     }
  }

void HuyChoXacNhan()
  {
   if(g_nutCho == "")
      return;
   if(ObjectFind(0, g_nutCho) >= 0)
      ObjectSetString(0, g_nutCho, OBJPROP_TEXT, NhanGocNut(g_nutCho));
   g_nutCho = "";
  }

string NhanGocNut(const string ten)
  {
   if(ten == PG_P + "B_n_tieptuc")
      return "TIẾP TỤC";
   if(ten == PG_P + "B_n_tamdung")
      return "TẠM DỪNG";
   if(ten == PG_P + "B_n_dongbk")
      return "ĐÓNG BASKET";
   return "ĐÓNG TẤT CẢ";
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| QUYỀN GỬI LỆNH: chế độ, loại tài khoản, hedging, Algo Trading,    |
//| quyền của tài khoản và symbol. Đọc lại mỗi giây.                  |
//+------------------------------------------------------------------+
void CapNhatQuyenGui(const bool thongBao = true)
  {
   string ly = "";
   g_laTKThat = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL);
   if(InpCheDo != PG_CD_GIAO_DICH)
      ly = "Chế độ quan sát";
   else
      if(!g_tester && g_laTKThat && !InpChoPhepTKThat)
         ly = "Chưa cho phép tài khoản thật";
      else
         if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
            ly = "Cần tài khoản hedging";
         else
            if(!g_tester && !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
               ly = "Chưa bật Algo Trading";
            else
               if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
                  ly = "EA chưa được phép giao dịch";
               else
                  if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
                     ly = "Tài khoản không cho EA giao dịch";
                  else
                     if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
                        ly = "Symbol không cho mở lệnh mới";
   bool duoc = (ly == "");
   if(thongBao && (duoc != g_duocGui || ly != g_lyDoKhoa))
     {
      ThemThongBao(duoc ? "Được gửi lệnh trở lại" : "Không gửi lệnh: " + ly);
      BaoDienThoai(duoc ? "Được gửi lệnh trở lại" : "Không gửi lệnh: " + ly);
      GhiLog(duoc ? "DUOC_GUI_LENH" : "KHOA_GUI_LENH");
     }
   g_duocGui = duoc;
   g_lyDoKhoa = ly;
  }

//--- Lưu cờ tạm dừng và khóa sau stop out (giữ qua khởi động lại)
void LuuCo()
  {
   if(g_tester || g_gvTamDung == "")
      return;
   GlobalVariableSet(g_gvTamDung, g_tamDungTay ? 1.0 : 0.0);
   GlobalVariableSet(g_gvSauSO, g_sauStopOut ? 1.0 : 0.0);
   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
//| RỦI RO mỗi giây: DD trong ngày, ngưỡng DD không mở basket mới,   |
//| vị thế lạ / vị thế Phoenix ngoài basket, đóng lại sau ĐÓNG TẤT CẢ |
//+------------------------------------------------------------------+
void KiemTraRuiRo()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_dinhEq > 0.0) ? (g_dinhEq - eq) / g_dinhEq * 100.0 : 0.0;
   if(dd > g_ddNgayMax)
      g_ddNgayMax = dd;
   if(InpBaoVeVonPT > 0.0 && dd >= InpBaoVeVonPT && !g_dongTatCaCho)
     {
      int soPGbv = 0, soKhacBv = 0;
      DemViThe(soPGbv, soKhacBv);
      if(soPGbv > 0)
        {
         g_tamDungTay = true;
         LuuCo();
         g_dongTatCaCho = true;
         if(g_gioHuong != 0 && !g_gioDangDong)
           {
            g_gioDangDong = true;
            g_gioLyDoDong = "BAO_VE_VON";
           }
         ThemThongBao("BẢO VỆ VỐN: DD " + DoubleToString(dd, 1) + "% ≥ " + DoubleToString(InpBaoVeVonPT, 1) + "%, đóng hết và TẠM DỪNG");
         BaoDienThoai("BẢO VỆ VỐN: DD " + DoubleToString(dd, 1) + "%, đóng hết và tạm dừng");
         GhiLog("BAO_VE_VON");
         DongTatCaPhoenix("BAO_VE_VON");
        }
     }
   bool dungDD = (InpDDDungMoiPT > 0.0 && dd >= InpDDDungMoiPT);
   if(dungDD != g_dungMoiDD)
     {
      g_dungMoiDD = dungDD;
      ThemThongBao(dungDD ? "DD " + DoubleToString(dd, 1) + "%: không mở basket mới" : "DD dưới ngưỡng: mở basket mới trở lại");
     }
   int soPG = 0, soKhac = 0;
   DemViThe(soPG, soKhac);
   int    ngoai = SoViTheNgoaiBasket();
   string ly = "";
   if(ngoai > 0)
      ly = IntegerToString(ngoai) + " vị thế Phoenix ngoài basket (đóng tay hoặc ĐÓNG TẤT CẢ)";
   else
      if(InpTamDungViTheLa && (soKhac > 0 || SoLenhChoLa() > 0))
         ly = "Tài khoản có vị thế / lệnh chờ không thuộc Phoenix";
   if(ly != g_lyDoTamDung)
     {
      ThemThongBao((ly == "") ? "Hết điều kiện tạm dừng tự động" : "Tạm dừng tự động: " + ly);
      GhiLog((ly == "") ? "HET_TAM_DUNG_TU_DONG" : "TAM_DUNG_TU_DONG");
      g_lyDoTamDung = ly;
     }
   if(g_dongTatCaCho)
     {
      if(soPG == 0)
        {
         g_dongTatCaCho = false;
         ThemThongBao("Đã đóng hết vị thế Phoenix");
        }
      else
         if(TimeLocal() - g_lanDongCuoi >= 3 && TrongPhien(TimeTradeServer(), 0))
            DongTatCaPhoenix("NUT_DONG_TAT_CA");
     }
  }

int SoViTheNgoaiBasket()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(TangCuaTicket(tk) < 0)
         n++;
     }
   return n;
  }

//--- Lệnh chờ trên tài khoản (Phoenix không dùng lệnh chờ)
int SoLenhChoLa()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0)
         continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY && t != ORDER_TYPE_SELL)
         n++;
     }
   return n;
  }

//+------------------------------------------------------------------+
//| THỰC THI LỆNH                                                     |
//+------------------------------------------------------------------+
//--- Tiền tài khoản của 1 lot khi giá đi 1,0 (đọc từ MT5, không tự quy đổi)
void CapNhatVpp()
  {
   double tsz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0)
      tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_vpp = (tsz > 0.0) ? tv / tsz : 0.0;
  }

ENUM_ORDER_TYPE_FILLING ChonKieuKhop()
  {
   long m = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((m & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((m & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//--- Kiểu khớp khác khi server báo sai kiểu khớp
ENUM_ORDER_TYPE_FILLING KieuKhopKhac(const ENUM_ORDER_TYPE_FILLING f)
  {
   long m = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if(f == ORDER_FILLING_FOK)
      return ((m & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN;
   if(f == ORDER_FILLING_IOC)
      return ORDER_FILLING_RETURN;
   return ORDER_FILLING_FOK;
  }

//--- 0 thành công; 1 giá đổi / từ chối tạm thời; 2 thị trường đóng / không cho giao dịch; 3 kết nối / quá thời gian;
//--- 4 sai mức TP; 5 lỗi khác; 6 không đủ tiền; 7 sai kiểu khớp
int PhanLoaiLoi(const uint rc)
  {
   switch(rc)
     {
      case TRADE_RETCODE_DONE:
      case TRADE_RETCODE_DONE_PARTIAL:
      case TRADE_RETCODE_PLACED:
         return 0;
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_REJECT:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_LOCKED:
      case TRADE_RETCODE_FROZEN:
         return 1;
      case TRADE_RETCODE_MARKET_CLOSED:
      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_SERVER_DISABLES_AT:
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
         return 2;
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_ERROR:
      case 0:
         return 3;
      case TRADE_RETCODE_INVALID_STOPS:
         return 4;
      case TRADE_RETCODE_NO_MONEY:
         return 6;
      case TRADE_RETCODE_INVALID_FILL:
         return 7;
     }
   return 5;
  }

string MoTaPhanLoai(const int kq)
  {
   switch(kq)
     {
      case 0:
         return "OK";
      case 1:
         return "GIA_DOI";
      case 2:
         return "THI_TRUONG_DONG";
      case 3:
         return "KET_NOI";
      case 4:
         return "SAI_TP";
      case 6:
         return "KHONG_DU_TIEN";
      case 7:
         return "SAI_KIEU_KHOP";
     }
   return "LOI_KHAC";
  }

//+------------------------------------------------------------------+
//| Gửi lệnh thị trường: mở (viTheDong = 0, kèm TP) hoặc đóng vị thế |
//| viTheDong. Lấy giá mới mỗi lần, thử tối đa 3 lần với lỗi tạm     |
//| thời. Mọi lần gửi được ghi log thực thi. Trả về phân loại kết quả.|
//+------------------------------------------------------------------+
int GuiLenhThiTruong(const ENUM_ORDER_TYPE loai, const double lot, const double tp, const ulong viTheDong,
                     const string cmt, const string hanhDong, ulong &ticketMo, double &giaKhop, double &lotKhop,
                     uint &retcode)
  {
   ticketMo = 0;
   giaKhop  = 0.0;
   lotKhop  = 0.0;
   retcode  = 0;
   double tpGui = tp;
   int    kq = 3;
   for(int lan = 1; lan <= 3; lan++)
     {
      MqlTick t;
      if(!SymbolInfoTick(_Symbol, t) || t.bid <= 0.0 || t.ask <= 0.0)
        {
         kq = 3;
         break;
        }
      MqlTradeRequest rq;
      MqlTradeResult  rs;
      ZeroMemory(rq);
      ZeroMemory(rs);
      rq.action       = TRADE_ACTION_DEAL;
      rq.symbol       = _Symbol;
      rq.volume       = lot;
      rq.type         = loai;
      rq.price        = (loai == ORDER_TYPE_BUY) ? t.ask : t.bid;
      rq.deviation    = (ulong)InpDoLechDiem;
      rq.type_filling = g_filling;
      rq.magic        = (ulong)InpMagic;
      rq.comment      = cmt;
      if(viTheDong > 0)
         rq.position = viTheDong;
      else
         rq.tp = tpGui;
      ulong t0 = GetMicrosecondCount();
      bool  ok = OrderSend(rq, rs);
      long  tre = (long)((GetMicrosecondCount() - t0) / 1000);
      retcode = rs.retcode;
      kq = PhanLoaiLoi(rs.retcode);
      if(!ok && kq == 0)
         kq = 3;
      GhiLogThucThi(hanhDong, lan, rq, rs, tre, kq, t.bid, t.ask);
      if(kq == 0)
        {
         lotKhop = (rs.volume > 0.0) ? rs.volume : lot;
         giaKhop = (rs.price > 0.0) ? rs.price : rq.price;
         if(viTheDong == 0)
            ticketMo = TimTicketViThe(rs.order, rs.deal);
         g_loiLienTiep = 0;
         return 0;
        }
      if(kq == 4 && tpGui > 0.0)
         tpGui = 0.0;                          // server không nhận TP: mở không TP, KiemTraTPTang đặt lại sau
      else
         if(kq == 7)
            g_filling = KieuKhopKhac(g_filling);
         else
            if(kq == 1 || kq == 3)
               Sleep(300);
            else
               break;
     }
   return kq;
  }

//--- Tài khoản hedging: ticket vị thế = ticket lệnh mở; nếu chưa thấy thì tra theo giao dịch
ulong TimTicketViThe(const ulong order, const ulong deal)
  {
   if(order > 0 && PositionSelectByTicket(order))
      return order;
   if(deal > 0 && HistoryDealSelect(deal))
     {
      ulong pid = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(pid > 0)
         return pid;
     }
   return order;                              // đối chiếu lại trong KiemTraBasketTimer
  }

//--- Đóng một vị thế bằng lệnh thị trường. true khi đã đóng (hoặc vị thế không còn)
bool DongViThe(const ulong tk, const string lyDo)
  {
   if(!PositionSelectByTicket(tk))
      return true;
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double vol = PositionGetDouble(POSITION_VOLUME);
   ulong  tkMo = 0;
   double gk = 0.0, lk = 0.0;
   uint   rc = 0;
   int kq = GuiLenhThiTruong((pt == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, vol, 0.0, tk,
                             "PG|DONG|" + lyDo, "DONG_" + lyDo, tkMo, gk, lk, rc);
   if(kq == 0 || !PositionSelectByTicket(tk))
      return true;
   ThemThongBao("Đóng lệnh " + IntegerToString((long)tk) + " lỗi " + IntegerToString(rc) + " (" + MoTaPhanLoai(kq) + "), sẽ thử lại");
   return false;
  }

//--- Đặt TP cho vị thế đang mở
bool SuaTP(const ulong tk, const double tp)
  {
   if(!PositionSelectByTicket(tk))
      return false;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return false;
   MqlTradeRequest rq;
   MqlTradeResult  rs;
   ZeroMemory(rq);
   ZeroMemory(rs);
   rq.action   = TRADE_ACTION_SLTP;
   rq.symbol   = _Symbol;
   rq.position = tk;
   rq.sl       = PositionGetDouble(POSITION_SL);
   rq.tp       = tp;
   rq.magic    = (ulong)InpMagic;
   ulong t0 = GetMicrosecondCount();
   bool  ok = OrderSend(rq, rs);
   long  tre = (long)((GetMicrosecondCount() - t0) / 1000);
   int   kq = (rs.retcode == TRADE_RETCODE_NO_CHANGES) ? 0 : PhanLoaiLoi(rs.retcode);
   if(!ok && kq == 0 && rs.retcode != TRADE_RETCODE_NO_CHANGES)
      kq = 3;
   GhiLogThucThi("SUA_TP", 1, rq, rs, tre, kq, t.bid, t.ask);
   return (kq == 0);
  }

//--- Đóng mọi vị thế Phoenix của symbol (cả vị thế ngoài basket)
void DongTatCaPhoenix(const string lyDo)
  {
   g_lanDongCuoi = TimeLocal();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      DongViThe(tk, lyDo);
     }
  }

//--- Lỗi gửi lệnh mở: đếm lỗi liên tiếp, tạm dừng khi lỗi nghiêm trọng
void XuLyLoiGui(const int kq, const string hanhDong, const uint rc)
  {
   if(kq == 0)
      return;
   string ms = hanhDong + " lỗi " + IntegerToString(rc) + " (" + MoTaPhanLoai(kq) + ")";
   if(kq == 2)
     {
      ThemThongBao(ms);
      return;
     }
   if(kq == 6)
     {
      g_choGuiDen = ThoiGianHienTai() + 60;
      ThemThongBao(ms + ": chờ 60 giây");
      GhiLog("KHONG_DU_TIEN");
      return;
     }
   g_loiLienTiep++;
   ThemThongBao(ms);
   if(kq == 5 || g_loiLienTiep >= PG_LOI_LIEN_TIEP)
     {
      g_loiNghiemTrong = true;
      g_lyDoLoi = (kq == 5) ? "lỗi gửi lệnh " + IntegerToString(rc) : IntegerToString(g_loiLienTiep) + " lần gửi lệnh lỗi liên tiếp";
      ThemThongBao("TẠM DỪNG do " + g_lyDoLoi + ": kiểm tra rồi bấm TIẾP TỤC");
      BaoDienThoai("TẠM DỪNG do " + g_lyDoLoi);
      GhiLog("LOI_NGHIEM_TRONG");
     }
  }

//+------------------------------------------------------------------+
//| BỘ PP: lý do không mở basket                                      |
//+------------------------------------------------------------------+
string LyDoChanMoBasket()
  {
   if(!g_duocGui)
      return g_lyDoKhoa;
   if(g_tamDungTay)
      return "Tạm dừng bằng nút";
   if(g_loiNghiemTrong)
      return g_lyDoLoi;
   if(g_lyDoTamDung != "")
      return g_lyDoTamDung;
   if(g_sauStopOut)
      return "Sau stop out: chờ nạp tiền hoặc TIẾP TỤC";
   if(g_dungMoiDD)
      return "DD vượt ngưỡng";
   if(g_dongTatCaCho)
      return "Đang đóng tất cả";
   if(g_gioHuong != 0)
      return "Đang có basket";
   if(g_gioCuoiLuc > 0 && ThoiGianHienTai() - g_gioCuoiLuc < InpGiayChoSauClear)
      return "Chờ sau clear basket";
   if(!g_loc)
      return g_lyDoLoc;
   if(!SpreadDat())
      return "Spread giãn";
   if(InpLocTin && GanTinManh())
      return "Gần tin USD quan trọng";
   if(g_lenhHomNay >= InpLenhToiDaNgay)
      return "Đủ số lệnh trong ngày";
   if(g_choGuiDen > 0 && ThoiGianHienTai() < g_choGuiDen)
      return "Chờ sau lỗi không đủ tiền";
   if(g_msCuoi - g_msLenhCuoi < 1000)
      return "Chờ 1 giây giữa hai lệnh";
   return "";
  }

//--- Trí tuệ Phoenix chặn theo hướng lệnh
string ChanTheoPhoenix(const int huong, const bool laPP10)
  {
   if(InpChanNguocBO && g_boGiaiDoan > 0 && g_boHuong == -huong)
      return "Ngược breakout Phoenix";
   if(InpChanNguocXH && ((g_ct == PG_CT_TANG && huong < 0) || (g_ct == PG_CT_GIAM && huong > 0)))
      return "Ngược xu hướng M5 Phoenix";
   if(laPP10 && InpChanSideways && g_hopOk && g_boGiaiDoan == 0)
      return g_laVungMoi ? "Phoenix: vùng mới (dành cho PP1)" : "Phoenix: sideways (dành cho PP1)";
   return "";
  }

//--- Có tín hiệu: quyết định mở basket và ghi log tín hiệu
void VaoTheoPP(const string pp, const int huong)
  {
   if(InpCheDo != PG_CD_GIAO_DICH)
     {
      KetQuaPP(pp, huong, "QUAN_SAT", "Có tín hiệu, chế độ quan sát");
      return;
     }
   string ly = LyDoChanMoBasket();
   if(ly == "")
      ly = ChanTheoPhoenix(huong, pp == "PP10");
   if(ly != "")
     {
      KetQuaPP(pp, huong, "BI_CHAN", ly);
      return;
     }
   if(MoBasket(huong, pp))
      KetQuaPP(pp, huong, "VAO_LENH", "Mở basket #" + IntegerToString(g_gioId));
   else
      KetQuaPP(pp, huong, "LOI_GUI", g_ppLyDo);
  }

void KetQuaPP(const string pp, const int huong, const string kq, const string ly)
  {
   g_ppLyDo = ly;
   g_ppGanNhat = pp + " " + TimeToString(ThoiGianHienTai(), TIME_MINUTES) + ((huong > 0) ? " BUY" : ((huong < 0) ? " SELL" : "")) +
                 " — " + ((kq == "KHONG") ? ly : kq + ": " + ly);
   GhiLogTinHieu(pp, huong, kq, ly);
  }

//+------------------------------------------------------------------+
//| PP10 — FIB + BOLLINGER HỒI THUẬN XU HƯỚNG. Dựng lại từ tham số   |
//| SET M2_FIBO (EA VuTru_Fibo_BB_Pullback, không có mã nguồn gốc);  |
//| cách hiểu từng tham số: docs/phoenix_grid/06_EA_V0_20_DCA_TIA.md. |
//| Xét một lần mỗi nến PP10 vừa đóng (nến 1).                        |
//+------------------------------------------------------------------+
void KiemTraNenPP10()
  {
   if(!InpDungPP10)
      return;
   datetime t = iTime(_Symbol, InpPP10TF, 0);
   if(t == 0 || t == g_lastPP)
      return;
   if(g_lastPP == 0)
     {
      g_lastPP = t;                             // lần đầu: chỉ ghi mốc, không vào lệnh theo nến cũ
      return;
     }
   if(!ChiBaoPP10DaCapNhat())
      return;
   g_lastPP = t;
   XetPP10();
  }

bool ChiBaoPP10DaCapNhat()
  {
   int bars = Bars(_Symbol, InpPP10TF);
   if(BarsCalculated(g_hEMA) >= bars && BarsCalculated(g_hADXp) >= bars && BarsCalculated(g_hATRp) >= bars &&
      BarsCalculated(g_hBB) >= bars)
     {
      g_choPP = 0;
      return true;
     }
   g_choPP++;
   if(g_choPP <= PG_CHO_CHI_BAO)
      return false;
   g_choPP = 0;
   return true;
  }

void XetPP10()
  {
   int soNen = MathMax(InpNenNhipDay, InpSoNenDoc + 1) + 3;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpPP10TF, 0, soNen, r) < soNen)
      return;
   double ema[], adx[], atr[], bbU[], bbL[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(bbU, true);
   ArraySetAsSeries(bbL, true);
   int soBB = InpNenCham + 1;
   if(CopyBuffer(g_hEMA, 0, 0, InpSoNenDoc + 2, ema) < InpSoNenDoc + 2 || CopyBuffer(g_hADXp, 0, 0, 2, adx) < 2 ||
      CopyBuffer(g_hATRp, 0, 0, 2, atr) < 2 || CopyBuffer(g_hBB, 1, 0, soBB, bbU) < soBB ||
      CopyBuffer(g_hBB, 2, 0, soBB, bbL) < soBB || atr[1] <= 0.0)
      return;
   g_ppHuong  = 0;
   g_ppADX    = adx[1];
   g_ppATR    = atr[1];
   g_ppNhip   = 0.0;
   g_ppHoi    = -1.0;
   g_ppCham   = false;
   g_ppNen    = "";
   g_ppNenHoi = 0;
   g_ppDau    = 0.0;
   g_ppCuoi   = 0.0;
   // bước 1: xu hướng (EMA, độ dốc EMA), ADX, ATR tối thiểu
   bool mua = true, ban = true;
   if(InpDungEMA)
     {
      mua = mua && r[1].close > ema[1];
      ban = ban && r[1].close < ema[1];
     }
   if(InpDungDocEMA)
     {
      mua = mua && ema[1] > ema[1 + InpSoNenDoc];
      ban = ban && ema[1] < ema[1 + InpSoNenDoc];
     }
   string ly = "";
   if(!mua && !ban)
      ly = "Không rõ xu hướng EMA";
   else
      if(InpDungADX && adx[1] < InpADXMin)
         ly = "ADX thấp";
      else
         if(atr[1] < InpATRMinUSD)
            ly = "ATR thấp";
   if(ly != "")
     {
      KetQuaPP("PP10", 0, "KHONG", ly);
      return;
     }
   // bước 2 – 4: nhịp đẩy và vùng Fib, chạm Bollinger, nến xác nhận
   int huong = 0, hXet = 0;
   if(mua)
     {
      hXet = 1;
      ly = TimSetupPP10(r, 1, atr[1], bbU, bbL);
      if(ly == "")
         huong = 1;
     }
   if(huong == 0 && ban)
     {
      hXet = -1;
      ly = TimSetupPP10(r, -1, atr[1], bbU, bbL);
      if(ly == "")
         huong = -1;
     }
   if(huong == 0)
     {
      KetQuaPP("PP10", hXet, "KHONG", ly);
      return;
     }
   VaoTheoPP("PP10", huong);
  }

//--- Setup PP10 theo hướng h (mảng dạng chuỗi thời gian, nến 1 = nến tín hiệu). Trả về "" khi đạt, ngược lại là lý do
string TimSetupPP10(const MqlRates &r[], const int h, const double atr, const double &bbU[], const double &bbL[])
  {
   g_ppHuong = h;
   int W = InpNenNhipDay;
   // điểm cuối nhịp đẩy: đỉnh cao nhất (BUY) / đáy thấp nhất (SELL) trong cửa sổ
   int iC = 1;
   for(int k = 2; k <= W; k++)
      if((h > 0 && r[k].high > r[iC].high) || (h < 0 && r[k].low < r[iC].low))
         iC = k;
   g_ppNenHoi = iC - 1;
   if(g_ppNenHoi < InpNenHoiMin)
      return "Hồi chưa đủ " + IntegerToString(InpNenHoiMin) + " nến";
   if(g_ppNenHoi > InpNenHoiMax)
      return "Hồi quá " + IntegerToString(InpNenHoiMax) + " nến";
   if(iC >= W)
      return "Không có nhịp đẩy trong cửa sổ";
   // điểm đầu nhịp đẩy: đáy thấp nhất (BUY) / đỉnh cao nhất (SELL) trước điểm cuối
   int iD = iC + 1;
   for(int k = iC + 2; k <= W; k++)
      if((h > 0 && r[k].low < r[iD].low) || (h < 0 && r[k].high > r[iD].high))
         iD = k;
   double cuoi = (h > 0) ? r[iC].high : r[iC].low;
   double dau  = (h > 0) ? r[iD].low : r[iD].high;
   double nhip = MathAbs(cuoi - dau);
   g_ppDau  = dau;
   g_ppCuoi = cuoi;
   g_ppNhip = nhip / atr;
   if(nhip <= 0.0 || nhip < InpNhipDayMinATR * atr)
      return "Nhịp đẩy nhỏ hơn " + DoubleToString(InpNhipDayMinATR, 1) + " ATR";
   // độ hồi sâu nhất từ điểm cuối, độ hồi của giá đóng nến tín hiệu
   double cuc = (h > 0) ? r[1].low : r[1].high;
   for(int k = 1; k < iC; k++)
      cuc = (h > 0) ? MathMin(cuc, r[k].low) : MathMax(cuc, r[k].high);
   double hoiSau = (h > 0) ? (cuoi - cuc) / nhip : (cuc - cuoi) / nhip;
   g_ppHoi = (h > 0) ? (cuoi - r[1].close) / nhip : (r[1].close - cuoi) / nhip;
   if(hoiSau > InpFibMatHieuLuc)
      return "Hồi quá " + DoubleToString(InpFibMatHieuLuc, 3) + ", nhịp mất hiệu lực";
   if(g_ppHoi < InpFibMin - InpFibDungSai || g_ppHoi > InpFibMax + InpFibDungSai)
      return "Giá đóng ngoài vùng Fib";
   // chạm Bollinger trong InpNenCham nến gần nhất
   for(int k = 1; k <= InpNenCham && !g_ppCham; k++)
      g_ppCham = (h > 0) ? (r[k].low <= bbL[k] + InpChamDungSaiATR * atr) : (r[k].high >= bbU[k] - InpChamDungSaiATR * atr);
   if(!g_ppCham)
      return "Không chạm Bollinger";
   g_ppNen = NenXacNhan(r, h, atr);
   if(g_ppNen == "")
      return "Không có nến xác nhận";
   return "";
  }

//--- Nến xác nhận tại nến 1: PIN (bấc ≥ InpBacPinMin × biên độ), ENGULF (thân nuốt thân nến 2), STAR (3 nến)
string NenXacNhan(const MqlRates &r[], const int h, const double atr)
  {
   double o1 = r[1].open, c1 = r[1].close, rg = r[1].high - r[1].low;
   if(InpPinBar && rg > 0.0)
     {
      double bac = (h > 0) ? MathMin(o1, c1) - r[1].low : r[1].high - MathMax(o1, c1);
      if(bac >= InpBacPinMin * rg)
         return "PIN";
     }
   if(InpEngulfing)
     {
      double o2 = r[2].open, c2 = r[2].close;
      if(h > 0 && c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2)
         return "ENGULF";
      if(h < 0 && c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2)
         return "ENGULF";
     }
   if(InpStar && atr > 0.0)
     {
      double o3 = r[3].open, c3 = r[3].close, than2 = MathAbs(r[2].close - r[2].open);
      bool   nen3 = (h > 0) ? (c3 < o3) : (c3 > o3);
      bool   nen1 = (h > 0) ? (c1 > o1 && c1 > (o3 + c3) / 2.0) : (c1 < o1 && c1 < (o3 + c3) / 2.0);
      if(nen3 && MathAbs(c3 - o3) >= 0.6 * atr && than2 <= 0.3 * atr && nen1)
         return "STAR";
     }
   return "";
  }

//+------------------------------------------------------------------+
//| PP1 — vào gần biên hộp khi Phoenix nhận SIDEWAYS / VÙNG MỚI (chưa |
//| có breakout). Mỗi nến M1 xét tối đa một lần khi giá ở vùng biên.  |
//+------------------------------------------------------------------+
void XetPP1()
  {
   if(!InpDungPP1 || g_gioHuong != 0 || !g_hopOk || g_boGiaiDoan != 0 || g_rW <= 0.0 || g_bid <= 0.0)
      return;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 == 0 || m1 == g_pp1Nen)
      return;
   double z = InpPP1Z * g_rW;
   int    huong = 0;
   if(g_bid <= g_rL + z)
      huong = 1;
   else
      if(g_ask >= g_rU - z)
         huong = -1;
   if(huong == 0)
      return;
   g_pp1Nen = m1;
   if(InpPP1XacNhan && !NenM1TuChoi(huong, z))
     {
      KetQuaPP("PP1", huong, "KHONG", "Chưa có nến M1 từ chối");
      return;
     }
   VaoTheoPP("PP1", huong);
  }

//--- Nến M1 vừa đóng chạm vùng biên rồi đóng cửa ngược lại (BUY: đóng ở 40% trên của biên độ)
bool NenM1TuChoi(const int huong, const double z)
  {
   double h = iHigh(_Symbol, PERIOD_M1, 1), l = iLow(_Symbol, PERIOD_M1, 1), c = iClose(_Symbol, PERIOD_M1, 1);
   double rg = h - l;
   if(rg <= 0.0)
      return false;
   if(huong > 0)
      return l <= g_rL + z && c >= l + 0.6 * rg;
   return h >= g_rU - z && c <= h - 0.6 * rg;
  }

//+------------------------------------------------------------------+
//| LỊCH TIN: tin USD quan trọng (lịch kinh tế MT5, giờ server).      |
//| Cập nhật 10 phút một lần. Không có trong Strategy Tester.         |
//+------------------------------------------------------------------+
void CapNhatTin()
  {
   if(g_tester || !InpLocTin)
      return;
   datetime bayGio = TimeTradeServer();
   if(g_tinCapNhat > 0 && bayGio - g_tinCapNhat < 600)
      return;
   g_tinCapNhat = bayGio;
   MqlCalendarValue v[];
   if(!CalendarValueHistory(v, bayGio - 7200, bayGio + 86400, NULL, "USD"))
     {
      g_tinCo = false;
      return;
     }
   g_tinSo = 0;
   for(int i = 0; i < ArraySize(v) && g_tinSo < PG_TIN_TOI_DA; i++)
     {
      MqlCalendarEvent e;
      if(!CalendarEventById(v[i].event_id, e))
         continue;
      if(e.importance == CALENDAR_IMPORTANCE_HIGH)
        {
         g_tinLuc[g_tinSo] = v[i].time;
         g_tinSo++;
        }
     }
   g_tinCo = true;
  }

bool GanTinManh()
  {
   if(!g_tinCo)
      return false;
   datetime bayGio = TimeTradeServer();
   for(int i = 0; i < g_tinSo; i++)
      if(bayGio >= g_tinLuc[i] - InpTinTruocPhut * 60 && bayGio <= g_tinLuc[i] + InpTinSauPhut * 60)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
//| BASKET DCA: tầng i ở giá P0 − hướng × i × khoảng tầng. TP tầng i |
//| = giá tầng + hướng × InpTiaTPBuoc × khoảng tầng (tỉa phía server).|
//+------------------------------------------------------------------+
double GiaTang(const int i) { return g_gioP0 - g_gioHuong * i * g_gioBuoc; }
double TPTang(const int i)  { return NormalizeGia(GiaTang(i) + g_gioHuong * InpTiaTPBuoc * g_gioBuoc); }

double NormalizeGia(const double p)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0.0)
      return NormalizeDouble(MathRound(p / ts) * ts, g_digits);
   return NormalizeDouble(p, g_digits);
  }

double ChuanHoaLot(const double lot)
  {
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double v = lot;
   if(st > 0.0)
      v = MathFloor(v / st + 1e-7) * st;
   if(v < mn)
      v = mn;
   if(mx > 0.0 && v > mx)
      v = mx;
   return NormalizeDouble(v, g_dgLot);
  }

//--- Hệ số nhân của cấp j (cấp 1 = lệnh DCA đầu tiên)
double HeSoCap(const int j)
  {
   if(!InpDungBangLot)
      return InpHeSoLot;
   if(j <= InpCap1)
      return InpHeSo1;
   if(j <= InpCap2)
      return InpHeSo2;
   if(j <= InpCap3)
      return InpHeSo3;
   if(j <= InpCap4)
      return InpHeSo4;
   if(j <= InpCap5)
      return InpHeSo5;
   return 1.0;
  }

//--- Lot tầng i = lot tầng 0 × tích hệ số cấp 1..i, làm tròn theo bước lot của symbol, không quá InpLotTangToiDa
double LotTang(const int i)
  {
   double lot = InpLotCoSo;
   for(int j = 1; j <= i; j++)
      lot *= HeSoCap(j);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st > 0.0)
      lot = MathRound(lot / st) * st;
   return ChuanHoaLot(MathMin(lot, InpLotTangToiDa));
  }

//--- Comment tầng: PG|<basket>|<tầng>|<khoảng tầng tính bằng point> (dựng lại basket khi mất trạng thái lưu)
string CommentTang(const int i)
  {
   return "PG|" + IntegerToString(g_gioId) + "|" + IntegerToString(i) + "|" + IntegerToString((long)MathRound(g_gioBuoc / g_point));
  }

bool DocComment(const string c, long &id, int &tang, double &buoc)
  {
   string p[];
   if(StringSplit(c, '|', p) != 4 || p[0] != "PG")
      return false;
   id   = StringToInteger(p[1]);
   tang = (int)StringToInteger(p[2]);
   buoc = StringToInteger(p[3]) * g_point;
   return id > 0 && tang >= 0 && tang < PG_TANG_MAX && buoc > 0.0;
  }

//--- Margin: còn free margin, margin level sau lệnh ≥ InpMLVao, không vượt giới hạn volume của symbol
bool MarginDat(const ENUM_ORDER_TYPE loai, const double lot)
  {
   double gia = (loai == ORDER_TYPE_BUY) ? g_ask : g_bid;
   double m = 0.0;
   if(gia <= 0.0 || !OrderCalcMargin(loai, _Symbol, lot, gia, m))
      return false;
   double mDung = AccountInfoDouble(ACCOUNT_MARGIN);
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) - m <= 0.0)
      return false;
   if(mDung + m > 0.0 && AccountInfoDouble(ACCOUNT_EQUITY) / (mDung + m) * 100.0 < InpMLVao)
      return false;
   double gh = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(gh > 0.0 && LotDangMo() + lot > gh + 1e-9)
      return false;
   return true;
  }

//--- Mốc clear cả basket: mục tiêu lãi, hoặc hòa vốn khi chuỗi đã xuống tới tầng InpHoaVonTuTang
double MucTieuHienTai()
  {
   if(InpSauTuTang > 0 && g_gioTangSau >= InpSauTuTang)
      return InpSauMucRong;
   if(InpHoaVonTuTang > 0 && g_gioTangSau >= InpHoaVonTuTang)
      return 0.0;
   return g_gioMucTieu;
  }

//--- Giá mà lãi ròng basket (đã chốt + thả nổi) bằng 0; trả về 0 khi không tính được
double GiaHoaVon()
  {
   double lot = 0.0, tich = 0.0, sw = 0.0;
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      if(g_tang[i] == 0 || !PositionSelectByTicket(g_tang[i]))
         continue;
      double v = PositionGetDouble(POSITION_VOLUME);
      lot  += v;
      tich += v * PositionGetDouble(POSITION_PRICE_OPEN);
      sw   += PositionGetDouble(POSITION_SWAP);
     }
   if(lot <= 0.0 || g_vpp <= 0.0)
      return 0.0;
   return tich / lot - g_gioHuong * (g_gioDaChot + sw) / (g_vpp * lot);
  }

//--- Mở basket: lệnh đầu (tầng 0) theo giá hiện tại, khoảng tầng theo ATR M5 lúc mở
bool MoBasket(const int huong, const string pp)
  {
   if(g_atr5 <= 0.0 || g_vpp <= 0.0)
     {
      g_ppLyDo = "Chưa có ATR M5 / giá trị lot";
      return false;
     }
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t) || t.bid <= 0.0 || t.ask <= 0.0)
     {
      g_ppLyDo = "Không lấy được giá";
      return false;
     }
   g_bid = t.bid;
   g_ask = t.ask;
   ENUM_ORDER_TYPE loai = (huong > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double lot = LotTang(0);
   if(!MarginDat(loai, lot))
     {
      g_ppLyDo = "Không đạt margin cho lệnh đầu";
      return false;
     }
   XoaBasket();
   long id = (long)ThoiGianHienTai();
   if(id <= g_gioIdCuoi)
      id = g_gioIdCuoi + 1;
   g_gioId    = id;
   g_gioHuong = huong;
   g_gioPP    = pp;
   g_gioBuoc  = NormalizeGia(MathMax(InpBuocMinUSD, InpBuocATR * g_atr5));
   g_gioP0    = NormalizeGia((huong > 0) ? t.ask : t.bid);
   ulong  tk = 0;
   double gk = 0.0, lk = 0.0;
   uint   rc = 0;
   g_msLenhCuoi = g_msCuoi;
   g_msDCACuoi = g_msCuoi;
   int kq = GuiLenhThiTruong(loai, lot, TPTang(0), 0, CommentTang(0), "MO_BASKET", tk, gk, lk, rc);
   if(kq != 0 || tk == 0)
     {
      XuLyLoiGui(kq, "Mở basket", rc);
      g_ppLyDo = "Gửi lệnh lỗi " + IntegerToString(rc) + " (" + MoTaPhanLoai(kq) + ")";
      XoaBasket();
      return false;
     }
   g_tang[0]     = tk;
   g_gioIdCuoi   = g_gioId;
   g_gioMucTieu  = InpGioTPATR * g_atr5 * g_vpp * lk;
   g_gioLucMo    = ThoiGianHienTai();
   g_gioEqMo     = AccountInfoDouble(ACCOUNT_EQUITY);
   g_gioSoLenh   = 1;
   g_gioLotMax   = lk;
   g_gioGiaTruoc = g_gioP0;
   g_lenhHomNay++;
   ThemThongBao("MỞ BASKET " + ((huong > 0) ? "BUY " : "SELL ") + pp + " tại " + FGia(gk) + ", khoảng tầng " +
                DoubleToString(g_gioBuoc, 2) + ", clear khi lãi ròng " + DauTien(g_gioMucTieu));
   GhiLog("MO_BASKET");
   BaoDienThoai("Mở basket " + ((huong > 0) ? "BUY " : "SELL ") + pp + " tại " + FGia(gk));
   LuuBasketGV();
   return true;
  }

//--- Mở tầng DCA i theo giá hiện tại, TP tỉa theo mức tầng
bool MoTang(const int i)
  {
   ENUM_ORDER_TYPE loai = (g_gioHuong > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double lot = LotTang(i);
   if(!MarginDat(loai, lot))
     {
      g_gioLyDoCho = "Không đạt margin level " + DoubleToString(InpMLVao, 0) + "%";
      return false;
     }
   double tp = TPTang(i);
   double kc = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * g_point;
   if((g_gioHuong > 0 && tp <= g_bid + kc) || (g_gioHuong < 0 && tp >= g_ask - kc))
      tp = 0.0;                                   // TP quá sát giá: mở không TP, KiemTraTPTang xử lý sau
   ulong  tk = 0;
   double gk = 0.0, lk = 0.0;
   uint   rc = 0;
   g_msLenhCuoi = g_msCuoi;
   g_msDCACuoi = g_msCuoi;
   int kq = GuiLenhThiTruong(loai, lot, tp, 0, CommentTang(i), "DCA", tk, gk, lk, rc);
   if(kq != 0 || tk == 0)
     {
      XuLyLoiGui(kq, "DCA tầng " + IntegerToString(i), rc);
      g_gioLyDoCho = "gửi lệnh lỗi " + IntegerToString(rc);
      return false;
     }
   g_tang[i]    = tk;
   g_tangMat[i] = 0;
   g_tangDong[i] = 0;
   g_gioSoLenh++;
   g_lenhHomNay++;
   if(i > g_gioTangSau)
      g_gioTangSau = i;
   double lm = LotDangMo();
   if(lm > g_gioLotMax)
      g_gioLotMax = lm;
   g_gioLyDoCho = "";
   ThemThongBao("DCA tầng " + IntegerToString(i) + " tại " + FGia(gk) + ", TP " + FGia(tp));
   LuuBasketGV();
   return true;
  }

//+------------------------------------------------------------------+
//| QUẢN LÝ BASKET mỗi tick. Thứ tự:                                 |
//| (1) CLEAR cả basket: lãi ròng (đã chốt + thả nổi) ≥ mốc clear;   |
//| (2) CLEAR từng phần: lãi tỉa đã chốt đủ trả lỗ tầng lỗ nhiều nhất |
//|     (trừ tầng sâu nhất) thì đóng tầng đó — giảm lot mở, giảm DD; |
//| (3) DCA: giá vượt qua mức tầng theo chiều ngược basket thì mở    |
//|     tầng sâu nhất vừa vượt (không mở dồn nhiều tầng một lúc).     |
//+------------------------------------------------------------------+
void QuanLyBasket()
  {
   if(g_gioHuong == 0 || g_bid <= 0.0 || g_ask <= 0.0)
      return;
   if(g_gioMucTieu <= 0.0 && g_atr5 > 0.0 && g_vpp > 0.0)
      g_gioMucTieu = InpGioTPATR * g_atr5 * g_vpp * LotTang(0);   // basket dựng lại từ comment
   bool   du = true;
   double tn = LaiThaNoiBasket(du);
   if(-tn > g_gioDDMax)
      g_gioDDMax = -tn;
   // tầng vừa đóng chưa được xử lý (chưa cộng vào lãi đã chốt): chờ để không tính sai lãi ròng
   if(!du || g_gioDangDong || SoTangMo() == 0)
      return;
   double rong = g_gioDaChot + tn;
   double muc = MucTieuHienTai();
   if(g_gioMucTieu > 0.0)
     {
      string lyClear = "";
      if(muc < g_gioMucTieu)
        {
         // chuỗi đã xuống sâu: clear ngay khi đạt mức hòa vốn / mức chấp nhận
         if(rong >= muc)
            lyClear = (muc < 0.0) ? "CLEAR_SAU" : "HOA_VON";
        }
      else
         if(!InpTrailClear)
           {
            if(rong >= muc)
               lyClear = "GIO_TP";
           }
         else
           {
            if(rong > g_gioDinhLai && (g_gioDinhLai > 0.0 || rong >= muc))
               g_gioDinhLai = rong;
            if(g_gioDinhLai > 0.0 && rong <= g_gioDinhLai * InpTrailGiuPT / 100.0)
               lyClear = "TRAIL_CLEAR";
           }
      if(lyClear != "")
        {
         ThemThongBao("CLEAR basket (" + lyClear + "): lãi ròng " + DauTien(rong) +
                      ((g_gioDinhLai > 0.0) ? ", đỉnh " + DauTien(g_gioDinhLai) : ""));
         DongBasket(lyClear);
         return;
        }
     }
   if(InpXoaTangLo && SoTangMo() >= InpXoaTuSoTang)
      XetXoaTang();
   // DCA
   double p = (g_gioHuong > 0) ? g_ask : g_bid;
   int    maxT = MathMin(InpSoTangToiDa, PG_TANG_MAX);
   if(g_gioGiaTruoc > 0.0)
      for(int i = 1; i < maxT; i++)
        {
         double L = GiaTang(i);
         bool   qua = (g_gioHuong > 0) ? (p <= L && g_gioGiaTruoc > L) : (p >= L && g_gioGiaTruoc < L);
         if(qua && g_tang[i] == 0 && (InpTiaLapLai || !g_tangDaTia[i]) && i > g_gioCho)
            g_gioCho = i;
        }
   g_gioGiaTruoc = p;
   if(g_gioCho <= 0)
      return;
   double Lc = GiaTang(g_gioCho);
   if(g_tang[g_gioCho] != 0 || (g_gioHuong > 0 && p > Lc) || (g_gioHuong < 0 && p < Lc))
     {
      g_gioCho = -1;                                // giá đã quay lại phía có lời của tầng: bỏ chờ
      g_gioLyDoCho = "";
      return;
     }
   string ly = LyDoChanDCA();
   if(ly != "")
     {
      g_gioLyDoCho = ly;
      return;
     }
   if(MoTang(g_gioCho))
      g_gioCho = -1;
  }

string LyDoChanDCA()
  {
   if(!g_duocGui)
      return g_lyDoKhoa;
   if(g_tamDungTay)
      return "Tạm dừng bằng nút";
   if(g_loiNghiemTrong)
      return g_lyDoLoi;
   if(g_lyDoTamDung != "")
      return g_lyDoTamDung;
   if(g_sauStopOut)
      return "Sau stop out";
   if(g_dongTatCaCho)
      return "Đang đóng tất cả";
   if(!TrongPhien(TimeTradeServer(), 0))
      return "Ngoài phiên giao dịch";
   if(!SpreadDat())
      return "Spread giãn";
   if(g_lenhHomNay >= InpLenhToiDaNgay)
      return "Đủ số lệnh trong ngày";
   if(g_choGuiDen > 0 && ThoiGianHienTai() < g_choGuiDen)
      return "Chờ sau lỗi không đủ tiền";
   if(g_msCuoi - g_msLenhCuoi < 1000)
      return "Chờ 1 giây giữa hai lệnh";
   if(g_msCuoi - g_msDCACuoi < (long)InpGiayGiuaDCA * 1000)
      return "Giãn cách " + IntegerToString(InpGiayGiuaDCA) + " giây giữa 2 lệnh DCA";
   if(InpHoanDCANguocBO && g_boGiaiDoan > 0 && g_boHuong == -g_gioHuong)
      return "Hoãn: breakout ngược basket";
   return "";
  }

//--- Clear từng phần: quỹ = lãi tỉa đã chốt + tối đa InpXoaGomLai tầng đang lãi nhiều nhất (dùng ít tầng nhất có thể).
//--- Quỹ đủ trả lỗ tầng đang lỗ nhiều nhất thì đóng cả nhóm: lot mở giảm, DD chuỗi giảm. Tầng sâu nhất luôn được giữ
//--- (tầng đó tỉa theo TP và giữ chu kỳ; basket chỉ kết thúc bằng clear cả basket).
void XetXoaTang()
  {
   if(g_msCuoi - g_msLenhCuoi < 1000 || !SpreadDat() || !g_duocGui)
      return;
   int sau = -1;
   for(int i = PG_TANG_MAX - 1; i >= 0 && sau < 0; i--)
      if(g_tang[i] != 0)
         sau = i;
   double lai[PG_TANG_MAX];
   int    xau = -1;
   double loXau = 0.0;
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      lai[i] = 0.0;
      if(g_tang[i] == 0)
         continue;
      if(g_tangDong[i] != 0 || !PositionSelectByTicket(g_tang[i]))
         return;                                    // còn lệnh đóng chưa xử lý xong
      lai[i] = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(i < sau && lai[i] < loXau)
        {
         loXau = lai[i];
         xau = i;
        }
     }
   if(xau < 0)
      return;
   double quy = MathMax(0.0, g_gioDaChot);
   int    chon[PG_TANG_MAX];
   int    soChon = 0;
   lai[xau] = 0.0;
   while(quy + loXau < InpXoaLaiToiThieu && soChon < InpXoaGomLai)
     {
      int tot = -1;
      for(int i = 0; i < PG_TANG_MAX; i++)
         if(g_tang[i] != 0 && i != sau && lai[i] > 0.0 && (tot < 0 || lai[i] > lai[tot]))
            tot = i;
      if(tot < 0)
         break;
      quy += lai[tot];
      lai[tot] = 0.0;
      chon[soChon] = tot;
      soChon++;
     }
   if(quy + loXau < InpXoaLaiToiThieu)
      return;
   g_msLenhCuoi = g_msCuoi;
   g_tangDong[xau] = 1;
   if(!DongViThe(g_tang[xau], "XOA"))
     {
      g_tangDong[xau] = 0;
      return;
     }
   for(int k = 0; k < soChon; k++)
     {
      g_tangDong[chon[k]] = 3;
      if(!DongViThe(g_tang[chon[k]], "GOM"))
         g_tangDong[chon[k]] = 0;
     }
  }

//--- Đóng cả basket (clear, nút). Các tầng chưa đóng được sẽ gửi lại trong KiemTraBasketTimer
void DongBasket(const string lyDo)
  {
   if(g_gioHuong == 0)
      return;
   if(!g_gioDangDong)
     {
      g_gioDangDong = true;
      g_gioLyDoDong = lyDo;
     }
   DongCacTang();
  }

void DongCacTang()
  {
   g_lanDongCuoi = TimeLocal();
   for(int i = PG_TANG_MAX - 1; i >= 0; i--)
      if(g_tang[i] != 0)
         DongViThe(g_tang[i], g_gioLyDoDong);
  }

//+------------------------------------------------------------------+
//| Mỗi giây: đối chiếu tầng đã đóng (khi lỡ sự kiện giao dịch), gửi |
//| lại lệnh đóng basket, đặt TP còn thiếu                            |
//+------------------------------------------------------------------+
void KiemTraBasketTimer()
  {
   if(g_gioHuong == 0)
      return;
   datetime bayGio = TimeLocal();
   for(int i = 0; i < PG_TANG_MAX && g_gioHuong != 0; i++)
     {
      if(g_tang[i] == 0)
         continue;
      if(PositionSelectByTicket(g_tang[i]))
        {
         g_tangMat[i] = 0;
         continue;
        }
      ulong d = TimDealRa(g_tang[i]);
      if(d > 0)
         XuLyTangDong(i, d);
      else
         if(g_tangMat[i] == 0)
            g_tangMat[i] = bayGio;
         else
            if(bayGio - g_tangMat[i] >= PG_CHO_DEAL_RA)
              {
               ThemThongBao("Tầng " + IntegerToString(i) + " đã đóng nhưng chưa thấy giao dịch đóng trong lịch sử");
               XuLyTangDong(i, 0);
              }
     }
   if(g_gioHuong == 0)
      return;
   if(g_gioDangDong && bayGio - g_lanDongCuoi >= 3 && TrongPhien(TimeTradeServer(), 0))
      DongCacTang();
   KiemTraTPTang();
  }

//--- Tầng mở mà không có TP (server không nhận TP lúc mở): đặt lại TP, hoặc tỉa ngay nếu giá đã qua mức TP
void KiemTraTPTang()
  {
   if(g_gioHuong == 0 || g_gioDangDong || !g_duocGui || TimeLocal() - g_lanSuaTP < 5)
      return;
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      if(g_tang[i] == 0 || g_tangDong[i] != 0 || !PositionSelectByTicket(g_tang[i]) || PositionGetDouble(POSITION_TP) > 0.0)
         continue;
      g_lanSuaTP = TimeLocal();
      double tp = TPTang(i);
      if((g_gioHuong > 0) ? (g_bid >= tp) : (g_ask <= tp))
        {
         g_tangDong[i] = 2;
         if(!DongViThe(g_tang[i], "TIA"))
            g_tangDong[i] = 0;
        }
      else
         SuaTP(g_tang[i], tp);
      return;                                       // mỗi lần xử lý một tầng
     }
  }

//--- Một tầng đã đóng: cộng lãi / lỗ vào basket, ghi log lệnh; hết tầng thì kết thúc basket
void XuLyTangDong(const int i, const ulong dealRa)
  {
   ulong tk = g_tang[i];
   if(tk == 0)
      return;
   string ly = "KHONG_RO";
   if(dealRa > 0 && HistoryDealSelect(dealRa))
      ly = LyDoDeal((ENUM_DEAL_REASON)HistoryDealGetInteger(dealRa, DEAL_REASON));
   if(g_tangDong[i] == 1)
      ly = "XOA";
   else
      if(g_tangDong[i] == 2)
         ly = "TIA";
      else
         if(g_tangDong[i] == 3)
            ly = "GOM";
      else
         if(ly == "EA" && g_gioDangDong)
            ly = g_gioLyDoDong;
   datetime tgVao = 0, tgRa = 0;
   double   giaVao = 0.0, giaRa = 0.0, lot = 0.0, tp = 0.0, ln = 0.0;
   TomTatViThe(tk, tgVao, tgRa, giaVao, giaRa, lot, tp, ln);
   g_tang[i] = 0;
   g_tangMat[i] = 0;
   g_tangDong[i] = 0;
   g_gioDaChot += ln;
   bool tia = (ly == "TP" || ly == "TIA" || ly == "GOM");
   if(tia)
     {
      g_gioSoTia++;
      g_tkTiaHomNay++;
      g_tangDaTia[i] = true;
     }
   if(ly == "XOA")
      g_gioSoXoa++;
   if(ly == "SO")
     {
      g_tkStopOutHomNay++;
      if(!g_sauStopOut)
        {
         g_sauStopOut = true;
         LuuCo();
         ThemThongBao("STOP OUT: dừng mở basket / tầng mới tới khi nạp tiền hoặc bấm TIẾP TỤC");
         BaoDienThoai("STOP OUT: EA dừng mở lệnh mới tới khi nạp tiền hoặc bấm TIẾP TỤC");
         GhiLog("STOP_OUT");
        }
     }
   GhiLogGiaoDich(tk, i, ly, tgVao, tgRa, giaVao, giaRa, lot, tp, ln);
   if(tia)
      ThemThongBao("Tỉa tầng " + IntegerToString(i) + " " + DauTien(ln));
   else
      if(ly == "XOA")
         ThemThongBao("Xóa tầng " + IntegerToString(i) + " " + DauTien(ln) + " bằng lãi tỉa / gộp lệnh lãi");
   if(SoTangMo() == 0)
     {
      string lyDo = g_gioDangDong ? g_gioLyDoDong : (tia ? "TIA_HET" : ((ly == "SO") ? "STOP_OUT" : "DONG_NGOAI_" + ly));
      KetThucBasket(lyDo);
      return;
     }
   LuuBasketGV();
  }

void KetThucBasket(const string lyDo)
  {
   double ln = g_gioDaChot;
   GhiLogBasket(lyDo, ln);
   g_tkGio++;
   g_tkGioHomNay++;
   g_tkRong += ln;
   g_tkRongHomNay += ln;
   g_gioCuoiKQ = ((g_gioHuong > 0) ? "BUY " : "SELL ") + DauTien(ln) + " " + lyDo;
   g_gioCuoiLuc = ThoiGianHienTai();
   ThemThongBao("Kết thúc basket " + g_gioCuoiKQ + ": " + IntegerToString(g_gioSoLenh) + " lệnh, tỉa " +
                IntegerToString(g_gioSoTia) + ", xóa " + IntegerToString(g_gioSoXoa) + ", sâu nhất tầng " + IntegerToString(g_gioTangSau));
   GhiLog("KET_THUC_BASKET");
   BaoDienThoai("Clear basket " + g_gioCuoiKQ + ", sâu nhất tầng " + IntegerToString(g_gioTangSau) +
                ", equity " + FTien(AccountInfoDouble(ACCOUNT_EQUITY)));
   XoaBasketGV();
   XoaBasket();
  }

void XoaBasket()
  {
   g_gioId = 0;
   g_gioHuong = 0;
   g_gioPP = "";
   g_gioP0 = 0.0;
   g_gioBuoc = 0.0;
   g_gioMucTieu = 0.0;
   g_gioLucMo = 0;
   g_gioDaChot = 0.0;
   g_gioDDMax = 0.0;
   g_gioLotMax = 0.0;
   g_gioGiaTruoc = 0.0;
   g_gioSoTia = 0;
   g_gioSoXoa = 0;
   g_gioTangSau = 0;
   g_gioSoLenh = 0;
   g_gioDangDong = false;
   g_gioLyDoDong = "";
   g_gioEqMo = 0.0;
   g_gioCho = -1;
   g_gioLyDoCho = "";
   g_gioDinhLai = 0.0;
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      g_tang[i] = 0;
      g_tangDaTia[i] = false;
      g_tangDong[i] = 0;
      g_tangMat[i] = 0;
     }
  }

int SoTangMo()
  {
   int n = 0;
   for(int i = 0; i < PG_TANG_MAX; i++)
      if(g_tang[i] != 0)
         n++;
   return n;
  }

double LotDangMo()
  {
   double v = 0.0;
   for(int i = 0; i < PG_TANG_MAX; i++)
      if(g_tang[i] != 0 && PositionSelectByTicket(g_tang[i]))
         v += PositionGetDouble(POSITION_VOLUME);
   return v;
  }

//--- Lãi / lỗ thả nổi các tầng đang mở; du = false khi có tầng đã đóng mà chưa xử lý
double LaiThaNoiBasket(bool &du)
  {
   du = true;
   double v = 0.0;
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      if(g_tang[i] == 0)
         continue;
      if(!PositionSelectByTicket(g_tang[i]))
        {
         du = false;
         continue;
        }
      v += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return v;
  }

int TangCuaTicket(const ulong tk)
  {
   if(tk == 0)
      return -1;
   for(int i = 0; i < PG_TANG_MAX; i++)
      if(g_tang[i] == tk)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
//| Khoảng giá đi ngược basket tới lúc cháy (Equity chạm mức stop out|
//| của tài khoản), tính cả các tầng DCA sẽ mở thêm, lot theo input. |
//| Không tính lãi tỉa / xóa tầng (ước tính thận trọng). Không có     |
//| basket: giả định basket BUY mở ngay tại giá hiện tại.             |
//+------------------------------------------------------------------+
double KhoangChay(int &soTang)
  {
   soTang = 0;
   if(g_vpp <= 0.0 || g_bid <= 0.0 || g_ask <= 0.0)
      return -1.0;
   bool   co   = (g_gioHuong != 0);
   int    h    = co ? g_gioHuong : 1;
   double buoc = co ? g_gioBuoc : MathMax(InpBuocMinUSD, InpBuocATR * g_atr5);
   double p0   = co ? g_gioP0 : g_ask;
   if(buoc <= 0.0)
      return -1.0;
   double gia = (h > 0) ? g_bid : g_ask;
   double lot = co ? LotDangMo() : LotTang(0);
   soTang = co ? SoTangMo() : 1;
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double mpl = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, g_ask, mpl))
      mpl = 0.0;
   double soPT = 0.0, soTien = 0.0;
   if(AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE) == ACCOUNT_STOPOUT_MODE_PERCENT)
      soPT = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO) / 100.0;
   else
      soTien = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   double d = 0.0;
   int    maxT = MathMin(InpSoTangToiDa, PG_TANG_MAX);
   for(int i = 1; i < maxT; i++)
     {
      if(co && g_tang[i] != 0)
         continue;
      double di = (h > 0) ? gia - (p0 - i * buoc) : (p0 + i * buoc) - gia;
      if(di <= d)
         continue;                                  // mức tầng ở phía có lời của giá hiện tại
      double conLai = eq - (soTien + soPT * mpl * lot);
      if(lot > 0.0 && conLai <= g_vpp * lot * (di - d))
         return d + MathMax(0.0, conLai) / (g_vpp * lot);
      eq  -= g_vpp * lot * (di - d);
      d    = di;
      lot += LotTang(i);
      soTang++;
     }
   double con = eq - (soTien + soPT * mpl * lot);
   return (lot > 0.0) ? d + MathMax(0.0, con) / (g_vpp * lot) : -1.0;
  }

//+------------------------------------------------------------------+
//| LƯU / NHẬN LẠI BASKET qua GlobalVariables (không dùng trong       |
//| tester). Mất trạng thái lưu: dựng lại từ comment của các tầng.    |
//+------------------------------------------------------------------+
void LuuBasketGV()
  {
   if(g_tester || g_gvGio == "" || g_gioHuong == 0)
      return;
   string k = g_gvGio;
   GlobalVariableSet(k + "id", (double)g_gioId);
   GlobalVariableSet(k + "huong", g_gioHuong);
   GlobalVariableSet(k + "p0", g_gioP0);
   GlobalVariableSet(k + "buoc", g_gioBuoc);
   GlobalVariableSet(k + "muc", g_gioMucTieu);
   GlobalVariableSet(k + "chot", g_gioDaChot);
   GlobalVariableSet(k + "tia", g_gioSoTia);
   GlobalVariableSet(k + "xoa", g_gioSoXoa);
   GlobalVariableSet(k + "sau", g_gioTangSau);
   GlobalVariableSet(k + "lenh", g_gioSoLenh);
   GlobalVariableSet(k + "mo", (double)g_gioLucMo);
   GlobalVariableSet(k + "ddmax", g_gioDDMax);
   GlobalVariableSet(k + "lotmax", g_gioLotMax);
   GlobalVariableSet(k + "eqmo", g_gioEqMo);
   GlobalVariableSet(k + "dinh", g_gioDinhLai);
   GlobalVariableSet(k + "pp", (g_gioPP == "PP10") ? 10.0 : ((g_gioPP == "PP1") ? 1.0 : 0.0));
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      string n = k + "t" + IntegerToString(i);
      if(g_tang[i] != 0)
         GlobalVariableSet(n, (double)g_tang[i]);
      else
         if(GlobalVariableCheck(n))
            GlobalVariableDel(n);
      string m = k + "dt" + IntegerToString(i);
      if(g_tangDaTia[i])
         GlobalVariableSet(m, 1.0);
      else
         if(GlobalVariableCheck(m))
            GlobalVariableDel(m);
     }
   GlobalVariablesFlush();
  }

void XoaBasketGV()
  {
   if(g_tester || g_gvGio == "")
      return;
   GlobalVariablesDeleteAll(g_gvGio);
   GlobalVariablesFlush();
  }

void NhanLaiBasket()
  {
   XoaBasket();
   string k = g_gvGio;
   if(GlobalVariableCheck(k + "id") && GlobalVariableCheck(k + "huong"))
     {
      g_gioId      = (long)GlobalVariableGet(k + "id");
      g_gioHuong   = (int)GlobalVariableGet(k + "huong");
      g_gioP0      = GlobalVariableGet(k + "p0");
      g_gioBuoc    = GlobalVariableGet(k + "buoc");
      g_gioMucTieu = GlobalVariableGet(k + "muc");
      g_gioDaChot  = GlobalVariableGet(k + "chot");
      g_gioSoTia   = (int)GlobalVariableGet(k + "tia");
      g_gioSoXoa   = (int)GlobalVariableGet(k + "xoa");
      g_gioTangSau = (int)GlobalVariableGet(k + "sau");
      g_gioSoLenh  = (int)GlobalVariableGet(k + "lenh");
      g_gioLucMo   = (datetime)(long)GlobalVariableGet(k + "mo");
      g_gioDDMax   = GlobalVariableGet(k + "ddmax");
      g_gioLotMax  = GlobalVariableGet(k + "lotmax");
      g_gioEqMo    = GlobalVariableGet(k + "eqmo");
      g_gioDinhLai = GlobalVariableCheck(k + "dinh") ? GlobalVariableGet(k + "dinh") : 0.0;
      double pp    = GlobalVariableGet(k + "pp");
      g_gioPP      = (pp > 5.0) ? "PP10" : ((pp > 0.5) ? "PP1" : "?");
      if(g_gioHuong == 0 || g_gioBuoc <= 0.0)
         XoaBasket();
      else
         for(int i = 0; i < PG_TANG_MAX; i++)
           {
            g_tangDaTia[i] = GlobalVariableCheck(k + "dt" + IntegerToString(i));
            string n = k + "t" + IntegerToString(i);
            if(GlobalVariableCheck(n))
               g_tang[i] = (ulong)GlobalVariableGet(n);
           }
     }
   // vị thế Phoenix đang mở chưa có trong trạng thái lưu: nhận theo comment
   for(int j = PositionsTotal() - 1; j >= 0; j--)
     {
      ulong tk = PositionGetTicket(j);
      if(tk == 0 || PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(TangCuaTicket(tk) >= 0)
         continue;
      long   id = 0;
      int    tang = 0;
      double buoc = 0.0;
      if(!DocComment(PositionGetString(POSITION_COMMENT), id, tang, buoc))
         continue;
      int h = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(g_gioHuong == 0)
        {
         double tp = PositionGetDouble(POSITION_TP);
         double giaTang = (tp > 0.0) ? tp - h * InpTiaTPBuoc * buoc : PositionGetDouble(POSITION_PRICE_OPEN);
         g_gioId      = id;
         g_gioHuong   = h;
         g_gioBuoc    = buoc;
         g_gioP0      = NormalizeGia(giaTang + h * tang * buoc);
         g_gioLucMo   = (datetime)id;
         g_gioEqMo    = AccountInfoDouble(ACCOUNT_EQUITY);
         g_gioPP      = "?";
         g_gioMucTieu = 0.0;                        // tính lại khi có ATR M5
         ThemThongBao("Không có trạng thái basket lưu: dựng lại từ comment lệnh (lãi đã chốt trước đó không tính)");
        }
      if(id != g_gioId || h != g_gioHuong || g_tang[tang] != 0)
         continue;                                  // không khớp basket: KiemTraRuiRo sẽ tạm dừng
      g_tang[tang] = tk;
     }
   if(g_gioHuong == 0)
      return;
   // tầng đã đóng trong lúc EA tắt: cộng lãi / lỗ từ lịch sử
   for(int i = 0; i < PG_TANG_MAX; i++)
     {
      if(g_tang[i] == 0 || PositionSelectByTicket(g_tang[i]))
         continue;
      XuLyTangDong(i, TimDealRa(g_tang[i]));
      if(g_gioHuong == 0)
         return;                                    // basket đã kết thúc trong lúc EA tắt
     }
   for(int i = 0; i < PG_TANG_MAX; i++)
      if(g_tang[i] != 0 && i > g_gioTangSau)
         g_gioTangSau = i;
   g_gioIdCuoi = g_gioId;
   g_gioGiaTruoc = 0.0;
   ThemThongBao("Nhận lại basket " + ((g_gioHuong > 0) ? "BUY" : "SELL") + " #" + IntegerToString(g_gioId) + ": " +
                IntegerToString(SoTangMo()) + " tầng đang mở");
   GhiLog("NHAN_LAI_BASKET");
   LuuBasketGV();
  }

//+------------------------------------------------------------------+
//| LỊCH SỬ GIAO DỊCH                                                 |
//+------------------------------------------------------------------+
//--- Tổng hợp một vị thế đã đóng: giờ / giá vào, giờ / giá ra, lot, TP, lãi ròng (gồm swap, commission, phí)
bool TomTatViThe(const ulong tk, datetime &tgVao, datetime &tgRa, double &giaVao, double &giaRa, double &lot,
                 double &tp, double &ln)
  {
   tgVao = 0;
   tgRa = 0;
   giaVao = 0.0;
   giaRa = 0.0;
   lot = 0.0;
   tp = 0.0;
   ln = 0.0;
   if(!HistorySelectByPosition(tk))
      return false;
   int n = HistoryDealsTotal();
   for(int k = 0; k < n; k++)
     {
      ulong d = HistoryDealGetTicket(k);
      if(d == 0)
         continue;
      long vao = HistoryDealGetInteger(d, DEAL_ENTRY);
      ln += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
            HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      if(vao == DEAL_ENTRY_IN)
        {
         tgVao  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         giaVao = HistoryDealGetDouble(d, DEAL_PRICE);
         lot    = HistoryDealGetDouble(d, DEAL_VOLUME);
         if(tp <= 0.0)
            tp = HistoryDealGetDouble(d, DEAL_TP);
        }
      else
         if(vao == DEAL_ENTRY_OUT || vao == DEAL_ENTRY_OUT_BY)
           {
            tgRa  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            giaRa = HistoryDealGetDouble(d, DEAL_PRICE);
            if(HistoryDealGetDouble(d, DEAL_TP) > 0.0)
               tp = HistoryDealGetDouble(d, DEAL_TP);
           }
     }
   return (n > 0);
  }

ulong TimDealRa(const ulong tk)
  {
   if(!HistorySelectByPosition(tk))
      return 0;
   for(int k = HistoryDealsTotal() - 1; k >= 0; k--)
     {
      ulong d = HistoryDealGetTicket(k);
      long  vao = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(vao == DEAL_ENTRY_OUT || vao == DEAL_ENTRY_OUT_BY)
         return d;
     }
   return 0;
  }

string LyDoDeal(const ENUM_DEAL_REASON r)
  {
   switch(r)
     {
      case DEAL_REASON_TP:
         return "TP";
      case DEAL_REASON_SL:
         return "SL";
      case DEAL_REASON_SO:
         return "SO";
      case DEAL_REASON_EXPERT:
         return "EA";
      case DEAL_REASON_CLIENT:
         return "TAY_PC";
      case DEAL_REASON_MOBILE:
         return "TAY_MOBILE";
      case DEAL_REASON_WEB:
         return "TAY_WEB";
     }
   return "KHAC";
  }

//--- Tổng nạp, tổng rút (số dương) trong khoảng thời gian
void TongNapRut(const datetime tu, const datetime den, double &nap, double &rut)
  {
   nap = 0.0;
   rut = 0.0;
   if(!HistorySelect(tu, den))
      return;
   for(int k = HistoryDealsTotal() - 1; k >= 0; k--)
     {
      ulong d = HistoryDealGetTicket(k);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_TYPE) != DEAL_TYPE_BALANCE)
         continue;
      double v = HistoryDealGetDouble(d, DEAL_PROFIT);
      if(v > 0.0)
         nap += v;
      else
         rut -= v;
     }
  }

//+------------------------------------------------------------------+
//| LOG THEO NGÀY để tối ưu: tín hiệu, lệnh, basket, thực thi; tổng  |
//| kết ngày theo tháng                                               |
//+------------------------------------------------------------------+
void GhiLogTinHieu(const string pp, const int huong, const string ketQua, const string lyDo)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   if(!MoFileLog(g_logTS, g_logTSKy, "tin_hieu", PG_TD_TS, true))
      return;
   bool la10 = (pp == "PP10");
   bool coNhip = la10 && g_ppNhip > 0.0;
   FileWrite(g_logTS,
             TimeToString(ThoiGianHienTai(), TIME_DATE | TIME_SECONDS), pp,
             (huong > 0) ? "BUY" : ((huong < 0) ? "SELL" : ""), FGia((huong < 0) ? g_bid : g_ask), ketQua, lyDo,
             coNhip ? FGia(g_ppDau) : "", coNhip ? FGia(g_ppCuoi) : "", coNhip ? DoubleToString(g_ppNhip, 2) : "",
             (la10 && g_ppNenHoi > 0) ? IntegerToString(g_ppNenHoi) : "",
             (la10 && g_ppHoi >= 0.0) ? DoubleToString(g_ppHoi, 3) : "",
             la10 ? (g_ppCham ? "1" : "0") : "", la10 ? g_ppNen : "",
             la10 ? DoubleToString(g_ppATR, 3) : "", la10 ? DoubleToString(g_ppADX, 1) : "",
             g_hopOk ? FGia(g_rU) : "", g_hopOk ? FGia(g_rL) : "", DoubleToString(g_atr5, 3),
             TenThiTruong(), TenCauTruc(g_ct), g_maLoc, IntegerToString((int)MathRound((g_ask - g_bid) / g_point)));
   FileFlush(g_logTS);
  }

void GhiLogGiaoDich(const ulong tk, const int i, const string ly, const datetime tgVao, const datetime tgRa,
                    const double giaVao, const double giaRa, const double lot, const double tp, const double ln)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   if(!MoFileLog(g_logGD, g_logGDKy, "giao_dich", PG_TD_GD, true))
      return;
   datetime ra = (tgRa > 0) ? tgRa : ThoiGianHienTai();
   FileWrite(g_logGD,
             (tgVao > 0) ? TimeToString(tgVao, TIME_DATE | TIME_SECONDS) : "", TimeToString(ra, TIME_DATE | TIME_SECONDS),
             IntegerToString(g_gioId), IntegerToString(i), (g_gioHuong > 0) ? "BUY" : "SELL",
             DoubleToString(lot, g_dgLot), FGia(giaVao), FGia(giaRa), FGia(tp), ly, FTien(ln),
             (tgVao > 0) ? DoubleToString((double)(ra - tgVao) / 60.0, 1) : "", IntegerToString((long)tk));
   FileFlush(g_logGD);
  }

void GhiLogBasket(const string lyDo, const double ln)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   if(!MoFileLog(g_logGI, g_logGIKy, "basket", PG_TD_GI, true))
      return;
   datetime bayGio = ThoiGianHienTai();
   FileWrite(g_logGI,
             TimeToString(g_gioLucMo, TIME_DATE | TIME_SECONDS), TimeToString(bayGio, TIME_DATE | TIME_SECONDS),
             IntegerToString(g_gioId), g_gioPP, (g_gioHuong > 0) ? "BUY" : "SELL", FGia(g_gioP0),
             DoubleToString(g_gioBuoc, 2), FTien(g_gioMucTieu), lyDo, FTien(ln),
             IntegerToString(g_gioSoLenh), IntegerToString(g_gioSoTia), IntegerToString(g_gioSoXoa),
             IntegerToString(g_gioTangSau), DoubleToString(g_gioLotMax, g_dgLot), FTien(g_gioDDMax),
             DoubleToString((g_gioEqMo > 0.0) ? g_gioDDMax / g_gioEqMo * 100.0 : 0.0, 2),
             DoubleToString((double)(bayGio - g_gioLucMo) / 60.0, 1), FTien(AccountInfoDouble(ACCOUNT_EQUITY)));
   FileFlush(g_logGI);
  }

void GhiTongKetNgay(const int ngay, const double eq)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   datetime moc = (datetime)((long)ngay * 86400);
   if(!MoFileLog(g_logTK, g_logTKKy, "tong_ket_ngay", PG_TD_TK, false, moc))
      return;
   double thayDoi = eq - g_dauNgayEq;
   FileWrite(g_logTK,
             TimeToString(moc, TIME_DATE), FTien(g_dauNgayEq), FTien(eq), FTien(thayDoi),
             FTien(g_napHomNay), FTien(g_rutHomNay), FTien(thayDoi - g_napHomNay + g_rutHomNay),
             IntegerToString(g_tkGioHomNay), IntegerToString(g_lenhHomNay), IntegerToString(g_tkTiaHomNay),
             FTien(g_tkRongHomNay), DoubleToString(g_ddNgayMax, 2), IntegerToString(g_tkStopOutHomNay),
             (g_gioHuong != 0) ? IntegerToString(g_gioId) : "", DoubleToString(LotDangMo(), g_dgLot));
   FileFlush(g_logTK);
  }

void GhiLogThucThi(const string hanhDong, const int lan, const MqlTradeRequest &rq, const MqlTradeResult &rs,
                   const long treMs, const int kq, const double bid, const double ask)
  {
   if(!InpGhiLog || g_toiUu)
      return;
   if(!MoFileLog(g_logTH, g_logTHKy, "thuc_thi", PG_TD_TH, true))
      return;
   string loai = (rq.action == TRADE_ACTION_SLTP) ? "SLTP" : ((rq.type == ORDER_TYPE_BUY) ? "BUY" : "SELL");
   FileWrite(g_logTH,
             TimeToString(ThoiGianHienTai(), TIME_DATE | TIME_SECONDS), IntegerToString(g_msCuoi), hanhDong,
             IntegerToString(lan), loai, DoubleToString(rq.volume, g_dgLot), FGia(rq.price), FGia(rs.price),
             FGia(rq.sl), FGia(rq.tp), IntegerToString((long)rq.position), IntegerToString(rs.retcode),
             MoTaPhanLoai(kq), IntegerToString(treMs), FGia(bid), FGia(ask), rq.comment,
             IntegerToString((long)rs.order), IntegerToString((long)rs.deal));
   FileFlush(g_logTH);
  }

//+------------------------------------------------------------------+
//| TRẠNG THÁI HIỂN THỊ                                               |
//+------------------------------------------------------------------+
string TrangThaiEA(color &c)
  {
   c = CLR_VANG;
   if(InpCheDo != PG_CD_GIAO_DICH)
      return "QUAN SÁT";
   if(!g_duocGui)
     {
      c = CLR_DO;
      return "KHÔNG GỬI LỆNH";
     }
   string mt = g_tester ? "TESTER" : (g_laTKThat ? "REAL" : "DEMO");
   if(g_laTKThat && !g_tester)
      c = CLR_CAM;
   if(TrangThaiTamDung() != "Không")
      return "TẠM DỪNG · " + mt;
   if(g_gioHuong != 0)
      return ((g_gioHuong > 0) ? "BASKET BUY · " : "BASKET SELL · ") + mt;
   return "CHỜ TÍN HIỆU · " + mt;
  }

string TrangThaiTamDung()
  {
   if(g_dongTatCaCho)
      return "Đang đóng tất cả";
   if(g_tamDungTay)
      return "Bằng nút";
   if(g_loiNghiemTrong)
      return "Lỗi thực thi";
   if(g_sauStopOut)
      return "Sau stop out";
   if(g_lyDoTamDung != "")
      return "Tự động";
   if(g_dungMoiDD)
      return "Không mở basket (DD)";
   return "Không";
  }
//+------------------------------------------------------------------+

//--- Thông báo về app MT5 trên điện thoại (Tools > Options > Notifications, nhập MetaQuotes ID)
void BaoDienThoai(const string ms)
  {
   if(!InpThongBaoDT || g_tester || !TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      return;
   if(!SendNotification("Phoenix " + _Symbol + ": " + ms))
      PrintFormat("PG: không gửi được thông báo điện thoại (lỗi %d)", GetLastError());
  }
//+------------------------------------------------------------------+
