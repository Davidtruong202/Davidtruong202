//+------------------------------------------------------------------+
//|                       EA_DAVID_HUNTER_V5_00_TICK_AI_TEST.mq5     |
//|                                                     David Hunter |
//+------------------------------------------------------------------+
// DAVID HUNTER V5.00 TICK AI - bản TEST, viết mới, độc lập với dòng V4.x.
// Không dùng lại mã, Magic, GlobalVariable hay thư mục log của V4.x.
//
// Kiến trúc:
//  1. Bộ phân tích tick: bộ đệm theo giây (1 giờ) và theo phút; tốc độ, gia tốc,
//     cường độ tick, biến động thực, hiệu suất xu hướng, spread, phát hiện sốc giá.
//  2. Bối cảnh khung lớn từ nến M1/M5/M15/H1/D1 của terminal (có ngay khi khởi động).
//  3. Nhận diện trạng thái thị trường: khởi động, sốc, yếu, tăng, giảm, đi ngang, chuyển tiếp.
//  4. Ba phương pháp riêng, mỗi phương pháp chỉ chạy ở trạng thái phù hợp:
//       PP1 xu hướng - hồi - tiếp diễn (điểm vào khi động lượng tick quay lại)
//       PP2 phá vỡ hộp tích lũy (xác nhận bằng cường độ tick)
//       PP3 quét thanh khoản - đảo chiều (đỉnh/đáy ngày trước, phiên Á, 4 giờ)
//  5. Chấm điểm tín hiệu 0-100. Học thích nghi từ lệnh ảo: mỗi tín hiệu đều được theo dõi
//     như một lệnh ảo. Mặc định "chứng minh trước": ô PP x hướng x phiên chỉ được vào lệnh
//     thật khi lệnh ảo của ô đó đã có kỳ vọng dương (>= 30 mẫu, >= +0.10R) và tự tắt khi
//     kỳ vọng xuống dưới 0. Mô hình xác suất thắng (hồi quy logistic trực tuyến) chỉ có
//     quyền PHỦ QUYẾT, không có quyền tăng rủi ro.
//  6. Lớp kiểm soát rủi ro độc lập, khóa cứng trong mã: tối đa 1%/vị thế, lỗ ngày tối đa
//     10% vốn đầu ngày (tính cả đã đóng và thả nổi), ngân sách lỗ ngày trước mỗi lệnh,
//     cầu dao sụt giảm tổng từ đỉnh vốn (mặc định 20%), ký quỹ, spread, số vị thế, giờ
//     giao dịch. Phần học máy không đọc/ghi các giới hạn này.
//  7. SL/TP gắn ở máy chủ ngay khi mở; hòa vốn, trailing, giới hạn thời gian giữ lệnh,
//     đóng hết trước giờ nghỉ hằng ngày và cuối tuần; khôi phục trạng thái sau khởi động lại.
//
// Mặc định KHÔNG gửi lệnh trên tài khoản THẬT (chỉ phân tích và ghi lệnh ảo) cho tới khi
// người vận hành bật InpChoPhepTaiKhoanThat sau khi đã kiểm chứng và phê duyệt.
#property copyright   "David Hunter"
#property version     "5.00"
#property description "David Hunter V5.00 TICK AI TEST - phân tích từng tick, 3 phương pháp, học thích nghi, rủi ro 1%/vị thế, lỗ ngày 10%."

#define DH5_RUI_RO_TRAN     1.0     // Khóa cứng: rủi ro dự kiến tối đa mỗi vị thế (% vốn)
#define DH5_LO_NGAY_TRAN    10.0    // Khóa cứng: lỗ ngày tối đa (% vốn đầu ngày)
#define DH5_KY_QUY_SAN      150.0   // Khóa cứng: mức ký quỹ tối thiểu sau khi vào lệnh (%)
#define DH5_SO_VI_THE_TRAN  3       // Khóa cứng: số vị thế đồng thời tối đa
#define DH5_BUF             3600    // Bộ đệm theo giây: 1 giờ
#define DH5_PHUT_BUF        60      // Bộ đệm theo phút: 1 giờ
#define DH5_SO_O            18      // Ô học: 3 PP x 2 hướng x 3 phiên
#define DH5_SO_DT           12      // Số đặc trưng của mô hình xác suất
#define DH5_SO_AO           64      // Số lệnh ảo theo dõi đồng thời
#define DH5_SO_MUC          6       // Số mức thanh khoản của PP3
#define DH5_SO_THEO_DOI     16      // Số vị thế thật theo dõi
#define DH5_DOI_CHIEU_GIAY  15      // Thời gian đối chiếu lệnh chưa rõ kết quả (giây)

const string DH5_PHIEN_BAN = "5.00";
const string DH5_THU_MUC = "DavidHunterV5";

#define TT_KHOI_DONG    0
#define TT_SOC          1
#define TT_YEU          2
#define TT_TANG         3
#define TT_GIAM         4
#define TT_SIDEWAY      5
#define TT_CHUYEN_TIEP  6

enum ENUM_DH5_CHE_DO
{
   DH5_GIAO_DICH = 0,       // Giao dịch (Demo/Tester; tài khoản thật cần bật công tắc riêng)
   DH5_CHI_PHAN_TICH = 1    // Chỉ phân tích và ghi lệnh ảo, không gửi lệnh
};

enum ENUM_DH5_PHAM_VI_LO
{
   DH5_LO_TOAN_TAI_KHOAN = 0, // Toàn tài khoản (gồm lệnh tay và EA khác)
   DH5_LO_CHI_EA = 1          // Chỉ lệnh của EA này
};

enum ENUM_DH5_CHE_DO_HOC
{
   DH5_HOC_CHUNG_MINH_TRUOC = 0, // Chứng minh trước: chỉ vào lệnh thật ở ô đã có kỳ vọng dương bằng lệnh ảo
   DH5_HOC_TAT_KHI_AM = 1        // Vào lệnh ở mọi ô, chỉ tạm tắt ô có kỳ vọng âm
};

input group "1. VẬN HÀNH CHUNG"
input ENUM_DH5_CHE_DO InpCheDo = DH5_GIAO_DICH;             // Chế độ hoạt động
input bool   InpChoPhepTaiKhoanThat = false;               // Cho phép gửi lệnh trên tài khoản THẬT (chỉ bật sau khi đã kiểm chứng và phê duyệt)
input long   InpMagic = 500500;                             // Mã Magic riêng của V5 (khác V4.x)
input int    InpGioBatDau = 1;                              // Giờ bắt đầu được mở lệnh (giờ máy chủ)
input int    InpGioNgungVaoLenh = 20;                       // Giờ ngừng mở lệnh mới (giờ máy chủ, không bao gồm)
input int    InpGioDongHetLenh = 20;                        // Giờ đóng toàn bộ lệnh cuối ngày (giờ máy chủ)
input int    InpPhutDongHetLenh = 40;                       // Phút đóng toàn bộ lệnh cuối ngày
input bool   InpDongLenhCuoiNgay = true;                    // Đóng toàn bộ lệnh trước giờ nghỉ hằng ngày và cuối tuần

input group "2. QUẢN TRỊ VỐN - LỚP KIỂM SOÁT RỦI RO ĐỘC LẬP"
input double InpRuiRoMoiLenh = 1.0;                         // Rủi ro dự kiến mỗi vị thế (% vốn, tối đa 1.0)
input double InpLoNgayToiDa = 10.0;                         // Giới hạn lỗ ngày (% vốn đầu ngày, tối đa 10.0)
input ENUM_DH5_PHAM_VI_LO InpPhamViLoNgay = DH5_LO_TOAN_TAI_KHOAN; // Phạm vi tính lỗ ngày
input bool   InpDongLenhKhiChamLoNgay = true;               // Đóng toàn bộ lệnh của EA khi chạm giới hạn lỗ ngày
input double InpSutGiamToiDa = 20.0;                        // Cầu dao sụt giảm tổng: dừng hẳn khi Equity giảm từ đỉnh (%), 0 = tắt
input bool   InpDatLaiDinhVon = false;                      // Đặt lại đỉnh vốn và mở cầu dao sụt giảm khi khởi động (bật một lần sau khi đã kiểm tra, rồi tắt)
input int    InpSoViTheToiDa = 1;                           // Số vị thế đồng thời tối đa (1-3)
input double InpKyQuySauVaoLenh = 300.0;                    // Mức ký quỹ tối thiểu sau khi vào lệnh (%, không dưới 150)
input double InpPhiMoiLot = 0.0;                            // Phí giao dịch khứ hồi mỗi lot (tiền tài khoản)
input double InpTruotGiaDuPhong = 0.30;                     // Trượt giá dự phòng khi tính lot, lệch giá tối đa khi gửi lệnh (giá)
input double InpSpreadToiDa = 0.60;                         // Spread tối đa được mở lệnh (giá)
input double InpSpreadToiDaTheoSL = 10.0;                   // Spread tối đa so với khoảng SL (%)

input group "3. PHÂN TÍCH TICK"
input int    InpKhoiDongGiay = 300;                         // Số giây dữ liệu tick liên tục cần có trước khi xét tín hiệu
input int    InpMatTickToiDaGiay = 90;                      // Khoảng trống tick tối đa (giây) trước khi khởi động lại dữ liệu
input double InpSocHeSo = 10.0;                             // Sốc giá: biến động 5 giây gấp bao nhiêu lần mức thường
input double InpSocToiThieu = 4.0;                          // Sốc giá: biến động 5 giây tối thiểu (giá)
input int    InpTamDungSauSocGiay = 300;                    // Thời gian tạm dừng mở lệnh sau sốc giá (giây)
input double InpSpreadDotBienHeSo = 2.5;                    // Spread đột biến: gấp bao nhiêu lần spread trung bình

input group "4. NHẬN DIỆN TRẠNG THÁI THỊ TRƯỜNG"
input double InpERXuHuong = 0.30;                           // Hiệu suất xu hướng M5 tối thiểu để coi là có xu hướng
input double InpERSideway = 0.20;                           // Hiệu suất xu hướng M5 tối đa để coi là đi ngang
input double InpDocH1ToiThieu = 0.05;                       // Độ dốc EMA50 H1 tối thiểu (ATR H1 mỗi nến)
input double InpChiPhiToiDaATR = 0.08;                      // Chi phí tối đa: spread / ATR M5

input group "5. PP1 - XU HƯỚNG, HỒI, TIẾP DIỄN"
input bool   InpDungPP1 = true;                             // Bật PP1
input double InpPP1HoiToiThieu = 0.80;                      // Độ hồi tối thiểu (ATR M5)
input double InpPP1HoiToiDa = 2.50;                         // Độ hồi tối đa (ATR M5)
input double InpPP1BatLaiToiThieu = 0.25;                   // Giá bật lại tối thiểu từ đáy/đỉnh hồi (ATR M5)
input double InpPP1BatLaiToiDa = 1.00;                      // Giá bật lại tối đa, tránh đuổi giá (ATR M5)

input group "6. PP2 - PHÁ VỠ HỘP TÍCH LŨY"
input bool   InpDungPP2 = true;                             // Bật PP2
input int    InpPP2SoPhut = 45;                             // Số phút tạo hộp tích lũy
input double InpPP2NenToiDa = 0.90;                         // Độ nén: chiều cao hộp / biên độ thường tối đa
input double InpPP2VuotHop = 0.10;                          // Khoảng vượt hộp để xác nhận phá vỡ (ATR M5)
input double InpPP2CuongDoTick = 1.30;                      // Cường độ tick tối thiểu khi phá vỡ (lần mức nền 30 phút)

input group "7. PP3 - QUÉT THANH KHOẢN, ĐẢO CHIỀU"
input bool   InpDungPP3 = true;                             // Bật PP3
input double InpPP3QuetToiThieu = 0.15;                     // Độ quét tối thiểu vượt mức (ATR M5)
input double InpPP3QuetToiDa = 1.50;                        // Độ quét tối đa, vượt hơn coi là phá vỡ thật (ATR M5)
input int    InpPP3ThoiGianGiay = 900;                      // Thời gian tối đa từ lúc quét đến lúc quay lại (giây)

input group "8. SL, TP, HÒA VỐN, TRAILING"
input double InpSLToiThieu = 4.0;                           // Khoảng SL tối thiểu (giá)
input double InpSLToiThieuATR = 0.80;                       // Khoảng SL tối thiểu (ATR M5)
input double InpSLToiDa = 20.0;                             // Khoảng SL tối đa, xa hơn thì bỏ tín hiệu (giá)
input double InpDemSLATR = 0.15;                            // Đệm SL ngoài đỉnh/đáy (ATR M5)
input double InpTyLeRR = 2.0;                               // TP theo bội số R
input double InpHoaVonTaiR = 1.0;                           // Dời SL về hòa vốn khi lời đạt (R), 0 = tắt
input double InpTrailingTuR = 1.5;                          // Bắt đầu trailing khi lời đạt (R), 0 = tắt
input double InpTrailingKhoangR = 1.0;                      // Khoảng cách trailing (R)
input int    InpGiuLenhToiDaPhut = 240;                     // Thời gian giữ lệnh tối đa (phút), 0 = tắt

input group "9. CHẤM ĐIỂM VÀ HỌC THÍCH NGHI"
input double InpDiemToiThieu = 55.0;                        // Điểm chất lượng tín hiệu tối thiểu (0-100)
input bool   InpDungHocThichNghi = true;                    // Bật học thích nghi theo ô PP x hướng x phiên
input ENUM_DH5_CHE_DO_HOC InpCheDoHoc = DH5_HOC_CHUNG_MINH_TRUOC; // Cách học thích nghi
input int    InpHocSoMauToiThieu = 30;                      // Số lệnh ảo tối thiểu của một ô trước khi được bật/tắt
input double InpHocNguongBat = 0.10;                        // Chế độ chứng minh trước: bật ô khi kỳ vọng trung bình từ mức này (R)
input double InpHocNguongTat = -0.10;                       // Chế độ tắt khi âm: tắt ô khi kỳ vọng trung bình dưới mức này (R)
input int    InpHocChuKy = 40;                              // Chu kỳ nhớ của học thích nghi (số lệnh)
input bool   InpDungMoHinh = true;                          // Bật mô hình xác suất thắng (chỉ có quyền phủ quyết)
input int    InpMoHinhSoMau = 200;                          // Số lệnh ảo tối thiểu trước khi mô hình được phủ quyết
input double InpMoHinhXacSuat = 0.36;                       // Xác suất thắng tối thiểu theo mô hình
input bool   InpHocNapTrongTester = false;                  // Nạp dữ liệu học đã lưu khi chạy Strategy Tester

input group "10. GHI LOG VÀ HIỂN THỊ"
input bool   InpGhiTinHieu = true;                          // Ghi mọi tín hiệu và lý do vào/bỏ qua
input bool   InpGhiLenhAo = true;                           // Ghi kết quả lệnh ảo
input bool   InpHienBang = true;                            // Hiện bảng trạng thái trên biểu đồ

//+------------------------------------------------------------------+
//| Cấu trúc dữ liệu                                                 |
//+------------------------------------------------------------------+
struct DH5TinHieu
{
   long     id;
   int      pp;          // 0 = PP1, 1 = PP2, 2 = PP3
   int      huong;       // +1 mua, -1 bán
   int      trangThai;
   int      phien;       // 0 Á, 1 Âu, 2 Mỹ
   long     thoiGian;
   double   gia;         // giá vào dự kiến (Ask khi mua, Bid khi bán)
   double   sl;
   double   tp;
   double   khoangSL;
   double   q[6];        // 0 xu hướng, 1 động lượng, 2 gia tốc, 3 cường độ, 4 chi phí, 5 cấu trúc
   double   diem;
   double   xacSuat;     // xác suất thắng theo mô hình (-1 = chưa dùng)
   string   moTa;
};

struct DH5LenhAo
{
   bool     mo;
   long     id;
   int      pp;
   int      huong;
   int      phien;
   int      trangThai;
   double   gia;
   double   sl;
   double   tp;
   double   r0;
   double   tot;
   double   xau;
   bool     hoaVon;
   long     moT;
   double   diem;
   double   q[6];
   bool     thuc;
};

struct DH5LenhThuc
{
   bool     dung;
   ulong    ticket;
   long     posId;
   long     id;
   int      pp;
   int      huong;
   int      phien;
   int      trangThai;
   double   diem;
   double   giaYeuCau;
   double   giaKhop;
   double   sl0;
   double   tp0;
   double   lot;
   double   tienRuiRo;
   double   r0;
   long     moT;
   double   tot;
   double   xau;
   bool     hoaVon;
   long     lanDongCuoi;
   string   lyDoDong;
};

struct DH5Muc
{
   double   gia;
   int      loai;        // +1 mức đỉnh, -1 mức đáy
   bool     quet;
   long     quetT;
   double   cucTri;
   bool     daDung;
   bool     hong;
   int      ngay;
};

struct DH5PP1
{
   bool     san;
   int      huong;
   double   dinh;
   long     dinhT;
   double   hoi;
   long     hoiT;
   double   kichHoat;
   double   slGoc;
   double   doSau;
};

struct DH5PP2
{
   bool     san;
   double   hi;
   double   lo;
   double   tyLeNen;
};

struct DH5Ngay
{
   int      key;
   double   balanceDau;
   double   napRut;
   double   chotEA;
   double   thaNoiEA;
   double   lo;
   double   loMax;
   double   gioiHan;
   bool     dung;
   int      loiNghiemTrong;
};

struct DH5Cho
{
   bool     dung;
   string   cmt;
   long     guiT;
   double   tien;
   double   giaYeuCau;
   DH5TinHieu s;
};

struct DH5ThongKe
{
   int      n;
   int      thang;
   int      thua;
   double   loiGop;
   double   loGop;
   double   net;
   double   tongR;
   int      chuoiThua;
   int      chuoiThuaMax;
   double   rXauNhat;
   int      vuotRuiRo;
};

//+------------------------------------------------------------------+
//| Biến toàn cục                                                     |
//+------------------------------------------------------------------+
// Thông số symbol và vận hành
double g_point = 0.0;
double g_tickSize = 0.0;
double g_lotMin = 0.0;
double g_lotMax = 0.0;
double g_lotStep = 0.0;
int    g_digits = 0;
int    g_lotDigits = 2;
ENUM_ORDER_TYPE_FILLING g_filling = ORDER_FILLING_FOK;
bool   g_sanSang = false;
bool   g_tester = false;
bool   g_hienThi = false;
bool   g_choPhepLenh = false;
string g_lyDoKhongGuiLenh = "";
long   g_tinHieuId = 0;
long   g_tamDungDen = 0;

// Bộ đệm tick theo giây
long   g_bT[DH5_BUF];
double g_bMid[DH5_BUF];
double g_bHi[DH5_BUF];
double g_bLo[DH5_BUF];
int    g_bN[DH5_BUF];
double g_bD2[DH5_BUF];
int    g_bHead = -1;
int    g_bCount = 0;
double g_sD2All = 0.0;
double g_sD2_60 = 0.0;
long   g_sN60 = 0;
long   g_sN1800 = 0;
int    g_demTinhLai = 0;

// Bộ đệm theo phút
long   g_mT[DH5_PHUT_BUF];
double g_mHi[DH5_PHUT_BUF];
double g_mLo[DH5_PHUT_BUF];
long   g_mHiT[DH5_PHUT_BUF];
long   g_mLoT[DH5_PHUT_BUF];
int    g_mHead = -1;
int    g_mCount = 0;

// Giá và đặc trưng tick
double g_bid = 0.0;
double g_ask = 0.0;
double g_mid = 0.0;
double g_spread = 0.0;
double g_sprTB = 0.0;
long   g_giayHienTai = 0;
long   g_batDauLienTuc = 0;
double g_rv1 = 0.0;
double g_rvPhut = 0.0;
double g_rvPhutTB = 0.0;
double g_tyLeBD = 1.0;
double g_cuongDo = 1.0;
double g_tickGiay = 0.0;
double g_er15 = 0.0;
double g_microHi = 0.0;
double g_microLo = 0.0;
double g_v5 = 0.0;
double g_v30 = 0.0;
double g_a30 = 0.0;
bool   g_soc = false;
long   g_socDen = 0;
bool   g_spreadDotBien = false;
bool   g_duLieuDu = false;

// Bối cảnh từ nến
double g_atrM1 = 0.0;
double g_atrM5 = 0.0;
double g_atrH1 = 0.0;
double g_emaH1 = 0.0;
double g_docH1 = 0.0;
double g_ema20M15 = 0.0;
double g_ema50M15 = 0.0;
double g_erM5 = 0.0;
double g_pdh = 0.0;
double g_pdl = 0.0;
double g_asiaHi = 0.0;
double g_asiaLo = 0.0;
bool   g_asiaCo = false;
double g_r4Hi = 0.0;
double g_r4Lo = 0.0;
double g_hopHi = 0.0;
double g_hopLo = 0.0;
bool   g_hopCo = false;
bool   g_ctxCo = false;
long   g_ctxPhut = 0;

// Trạng thái thị trường
int    g_trangThai = TT_KHOI_DONG;
int    g_trangThaiCu = -1;

// Phương pháp
DH5PP1 g_pp1;
long   g_pp1DaDung = 0;
DH5PP2 g_pp2;
long   g_pp2DaDung = 0;
DH5Muc g_muc[DH5_SO_MUC];

// Học thích nghi
double g_hocR[DH5_SO_O];
double g_hocW[DH5_SO_O];
int    g_hocN[DH5_SO_O];
bool   g_hocTat[DH5_SO_O];
double g_w[DH5_SO_DT];
double g_x[DH5_SO_DT];
int    g_moHinhN = 0;
long   g_hocLuuGiay = 0;     // thời điểm lưu dữ liệu học gần nhất (giờ máy chủ, không dùng đồng hồ máy)
DH5LenhAo g_ao[DH5_SO_AO];
int    g_aoBoQua = 0;
int    g_soAoMo = 0;         // số lệnh ảo đang mở (bỏ qua vòng lặp khi bằng 0 để Tester chạy nhanh)

// Rủi ro, lệnh thật
DH5Ngay g_ngay;
long   g_ngayDocGiay = 0;    // lần đọc lịch sử ngày gần nhất (giờ máy chủ; GetTickCount64 có thể là giờ thật trong Tester)
bool   g_ngayCanDoc = true;
DH5LenhThuc g_td[DH5_SO_THEO_DOI];
DH5Cho g_cho;
double g_nganSachLenh = 0.0;

// Cầu dao sụt giảm tổng (đỉnh Equity lưu bền vững; nạp/rút tiền dời đỉnh tương ứng)
double g_dinhSG = 0.0;
bool   g_dungSG = false;
double g_napRutDaTinh = 0.0;
int    g_napRutNgay = 0;
double g_balanceCu = 0.0;    // Balance ở tick trước: đổi thì đọc lịch sử ngay (nạp/rút phải được tính trước khi xét đỉnh vốn)

// Thống kê kiểm thử
DH5ThongKe g_tkTong;
DH5ThongKe g_tkPP[3];
DH5ThongKe g_tkPhien[3];
DH5ThongKe g_tkHuong[2];
DH5ThongKe g_tkTT[7];
double g_dinhVon = 0.0;
double g_ddMax = 0.0;
double g_ddMaxPct = 0.0;
double g_vonBanDau = 0.0;
long   g_tgBatDau = 0;
int    g_soTinHieu = 0;
int    g_soVaoLenh = 0;

// Log
int    g_hTH = INVALID_HANDLE;
int    g_hLenh = INVALID_HANDLE;
int    g_hSK = INVALID_HANDLE;
int    g_hAo = INVALID_HANDLE;
int    g_logThang = 0;
ulong  g_bangLuc = 0;
string g_tinHieuCuoi = "";

//+------------------------------------------------------------------+
//| Tiện ích                                                          |
//+------------------------------------------------------------------+
double Kep(const double x, const double lo, const double hi)
{
   if(x < lo) return lo;
   if(x > hi) return hi;
   return x;
}

int MaxI(const int a, const int b) { return a > b ? a : b; }
int MinI(const int a, const int b) { return a < b ? a : b; }

double ChuanGia(const double p)
{
   if(g_tickSize <= 0.0) return NormalizeDouble(p, g_digits);
   return NormalizeDouble(MathRound(p / g_tickSize) * g_tickSize, g_digits);
}

string SoGia(const double p) { return DoubleToString(p, g_digits); }
string So2(const double v) { return DoubleToString(v, 2); }
string So4(const double v) { return DoubleToString(v, 4); }

string ThoiGianChuoi(const long t)
{
   return TimeToString((datetime)t, TIME_DATE | TIME_SECONDS);
}

int NgayKey(const long t)
{
   MqlDateTime d;
   TimeToStruct((datetime)t, d);
   return d.year * 10000 + d.mon * 100 + d.day;
}

int ThangKey(const long t)
{
   MqlDateTime d;
   TimeToStruct((datetime)t, d);
   return d.year * 100 + d.mon;
}

long DauNgay(const long t)
{
   return t - (t % 86400);
}

int PhienCua(const long t)
{
   MqlDateTime d;
   TimeToStruct((datetime)t, d);
   if(d.hour < 7) return 0;
   if(d.hour < 13) return 1;
   return 2;
}

string TenPhien(const int p)
{
   if(p == 0) return "A";
   if(p == 1) return "AU";
   return "MY";
}

string MaTrangThai(const int tt)
{
   switch(tt)
   {
      case TT_KHOI_DONG:   return "KHOI_DONG";
      case TT_SOC:         return "SOC";
      case TT_YEU:         return "YEU";
      case TT_TANG:        return "TANG";
      case TT_GIAM:        return "GIAM";
      case TT_SIDEWAY:     return "SIDEWAY";
      case TT_CHUYEN_TIEP: return "CHUYEN_TIEP";
   }
   return "KHONG_RO";
}

string TenTrangThai(const int tt)
{
   switch(tt)
   {
      case TT_KHOI_DONG:   return "ĐANG KHỞI ĐỘNG DỮ LIỆU";
      case TT_SOC:         return "BIẾN ĐỘNG BẤT THƯỜNG";
      case TT_YEU:         return "THỊ TRƯỜNG YẾU / CHI PHÍ CAO";
      case TT_TANG:        return "XU HƯỚNG TĂNG";
      case TT_GIAM:        return "XU HƯỚNG GIẢM";
      case TT_SIDEWAY:     return "ĐI NGANG";
      case TT_CHUYEN_TIEP: return "CHUYỂN TIẾP";
   }
   return "KHÔNG RÕ";
}

string MaPP(const int pp)
{
   if(pp == 0) return "PP1_XU_HUONG_HOI";
   if(pp == 1) return "PP2_PHA_VO_HOP";
   return "PP3_QUET_DAO_CHIEU";
}

string TenGV(const string loai, const long so)
{
   return "DH5_" + IntegerToString(InpMagic) + "_" + loai + "_" + IntegerToString(so);
}

string TenGVChung(const string loai)
{
   return "DH5_" + IntegerToString(InpMagic) + "_" + loai + "_" + _Symbol;
}

ulong DoLechDiem()
{
   double p = g_point > 0.0 ? g_point : 0.001;
   double d = MathRound(InpTruotGiaDuPhong / p);
   if(d < 1.0) d = 1.0;
   return (ulong)d;
}

//+------------------------------------------------------------------+
//| Ghi log (thư mục chung MQL5\Files\Common\DavidHunterV5)           |
//+------------------------------------------------------------------+
string DuongDanLog(const string loai, const int thang)
{
   return DH5_THU_MUC + "\\DH5_" + IntegerToString(InpMagic) + "_" +
          StringFormat("%04d_%02d", thang / 100, thang % 100) + "_" + loai + ".csv";
}

int MoLog(const string loai, const string tieuDe, const int thang)
{
   string path = DuongDanLog(loai, thang);
   int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
   {
      Print("DH5 LOG: không mở được ", path, " lỗi ", GetLastError(), ". EA vẫn tiếp tục chạy.");
      return h;
   }
   if(FileSize(h) == 0) FileWriteString(h, tieuDe + "\r\n");
   FileSeek(h, 0, SEEK_END);
   return h;
}

void DongLog(int &h)
{
   if(h != INVALID_HANDLE)
   {
      FileFlush(h);
      FileClose(h);
   }
   h = INVALID_HANDLE;
}

const string HDR_TH = "thoi_gian;id;pp;huong;trang_thai;phien;diem;q_xu_huong;q_dong_luong;q_gia_toc;q_cuong_do;q_chi_phi;q_cau_truc;xac_suat_mo_hinh;gia;sl;tp;khoang_sl;spread;atr_m5;er_m5;doc_h1;v5;v30;a30;cuong_do;ty_le_bien_dong;quyet_dinh;ly_do;lot;tien_rui_ro;mo_ta";
const string HDR_LENH = "thoi_gian;su_kien;ticket;id;pp;huong;trang_thai;phien;diem;lot;gia_yeu_cau;gia_khop;truot_gia;sl;tp;tien_rui_ro;ket_qua_tien;ket_qua_R;ly_do;mfe_R;mae_R;giu_phut;ghi_chu";
const string HDR_SK = "thoi_gian;loai;noi_dung";
const string HDR_AO = "thoi_gian_dong;id;pp;huong;trang_thai;phien;diem;vao_that;gia;sl_ban_dau;r0;ket_qua_R;mfe_R;mae_R;giu_phut;ly_do";

void KiemTraThangLog()
{
   long now = g_giayHienTai > 0 ? g_giayHienTai : (long)TimeCurrent();
   int thang = ThangKey(now);
   if(thang == g_logThang && g_hSK != INVALID_HANDLE) return;
   DongLog(g_hTH);
   DongLog(g_hLenh);
   DongLog(g_hSK);
   DongLog(g_hAo);
   g_logThang = thang;
   if(InpGhiTinHieu) g_hTH = MoLog("tin_hieu", HDR_TH, thang);
   g_hLenh = MoLog("lenh", HDR_LENH, thang);
   g_hSK = MoLog("su_kien", HDR_SK, thang);
   if(InpGhiLenhAo) g_hAo = MoLog("lenh_ao", HDR_AO, thang);
}

string LamSach(const string s)
{
   string r = s;
   StringReplace(r, ";", ",");
   StringReplace(r, "\r", " ");
   StringReplace(r, "\n", " ");
   return r;
}

void GhiDong(const int h, const string dong)
{
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, dong + "\r\n");
}

void GhiSuKien(const string loai, const string noiDung)
{
   KiemTraThangLog();
   long now = g_giayHienTai > 0 ? g_giayHienTai : (long)TimeCurrent();
   GhiDong(g_hSK, ThoiGianChuoi(now) + ";" + loai + ";" + LamSach(noiDung));
}

void XaLog()
{
   if(g_hTH != INVALID_HANDLE) FileFlush(g_hTH);
   if(g_hLenh != INVALID_HANDLE) FileFlush(g_hLenh);
   if(g_hSK != INVALID_HANDLE) FileFlush(g_hSK);
   if(g_hAo != INVALID_HANDLE) FileFlush(g_hAo);
}

//+------------------------------------------------------------------+
//| Bộ phân tích tick                                                 |
//+------------------------------------------------------------------+
int BIdx(const int lui)
{
   int i = g_bHead - lui;
   if(i < 0) i += DH5_BUF;
   return i;
}

// Giá mid của giây cách giây hiện tại 'lui' giây (lấy ô cũ nhất nếu chưa đủ dữ liệu)
double MidTruoc(const int lui)
{
   if(g_bCount <= 0) return g_mid;
   int k = lui;
   if(k > g_bCount - 1) k = g_bCount - 1;
   if(k < 0) k = 0;
   return g_bMid[BIdx(k)];
}

void TickReset(const long giay, const double mid)
{
   g_bHead = 0;
   g_bCount = 1;
   g_bT[0] = giay;
   g_bMid[0] = mid;
   g_bHi[0] = mid;
   g_bLo[0] = mid;
   g_bN[0] = 0;
   g_bD2[0] = 0.0;
   g_sD2All = 0.0;
   g_sD2_60 = 0.0;
   g_sN60 = 0;
   g_sN1800 = 0;
   g_demTinhLai = 0;
   g_mHead = 0;
   g_mCount = 1;
   g_mT[0] = giay - (giay % 60);
   g_mHi[0] = mid;
   g_mLo[0] = mid;
   g_mHiT[0] = giay;
   g_mLoT[0] = giay;
   g_batDauLienTuc = giay;
   g_duLieuDu = false;
}

void CapNhatPhut(const long giay, const double hi, const double lo)
{
   long phut = giay - (giay % 60);
   if(g_mHead < 0 || g_mT[g_mHead] != phut)
   {
      int j = g_mHead + 1;
      if(j >= DH5_PHUT_BUF) j = 0;
      if(g_mHead < 0) j = 0;
      g_mHead = j;
      if(g_mCount < DH5_PHUT_BUF) g_mCount++;
      g_mT[j] = phut;
      g_mHi[j] = hi;
      g_mLo[j] = lo;
      g_mHiT[j] = giay;
      g_mLoT[j] = giay;
      return;
   }
   int k = g_mHead;
   if(hi > g_mHi[k]) { g_mHi[k] = hi; g_mHiT[k] = giay; }
   if(lo < g_mLo[k]) { g_mLo[k] = lo; g_mLoT[k] = giay; }
}

// Chốt số liệu của giây hiện tại trước khi chuyển sang giây mới
void KetThucGiay()
{
   int i = g_bHead;
   double d2 = 0.0;
   if(g_bCount > 1)
   {
      double d = g_bMid[i] - g_bMid[BIdx(1)];
      d2 = d * d;
   }
   g_bD2[i] = d2;
   g_sD2All += d2;
   g_sD2_60 += d2;
   if(g_bCount > 60) g_sD2_60 -= g_bD2[BIdx(60)];
   g_sN60 += g_bN[i];
   if(g_bCount > 60) g_sN60 -= g_bN[BIdx(60)];
   g_sN1800 += g_bN[i];
   if(g_bCount > 1800) g_sN1800 -= g_bN[BIdx(1800)];
   CapNhatPhut(g_bT[i], g_bHi[i], g_bLo[i]);
}

void DayGiay(const long giay, const double mid)
{
   int j = g_bHead + 1;
   if(j >= DH5_BUF) j = 0;
   if(g_bCount == DH5_BUF) g_sD2All -= g_bD2[j];
   else g_bCount++;
   g_bHead = j;
   g_bT[j] = giay;
   g_bMid[j] = mid;
   g_bHi[j] = mid;
   g_bLo[j] = mid;
   g_bN[j] = 0;
   g_bD2[j] = 0.0;
}

// Tính lại các tổng trượt từ đầu để tránh sai số cộng dồn
void TinhLaiTong()
{
   g_sD2All = 0.0;
   g_sD2_60 = 0.0;
   g_sN60 = 0;
   g_sN1800 = 0;
   for(int k = 1; k < g_bCount; k++)
   {
      int i = BIdx(k);
      g_sD2All += g_bD2[i];
      if(k <= 60) { g_sD2_60 += g_bD2[i]; g_sN60 += g_bN[i]; }
      if(k <= 1800) g_sN1800 += g_bN[i];
   }
}

void TinhDacTrungGiay()
{
   g_demTinhLai++;
   if(g_demTinhLai >= 600)
   {
      TinhLaiTong();
      g_demTinhLai = 0;
   }
   int daChot = g_bCount - 1;
   if(daChot < 1) return;
   g_rv1 = MathSqrt(g_sD2All / (double)daChot);
   g_rvPhut = MathSqrt(MathMax(0.0, g_sD2_60));
   g_rvPhutTB = g_rv1 * MathSqrt(60.0);
   g_tyLeBD = g_rvPhutTB > 0.0 ? g_rvPhut / g_rvPhutTB : 1.0;
   int n60 = MinI(60, daChot);
   int n1800 = MinI(1800, daChot);
   g_tickGiay = (double)g_sN60 / (double)n60;
   double nen = (double)g_sN1800 / (double)n1800;
   g_cuongDo = nen > 0.0 ? g_tickGiay / nen : 1.0;
   // Hiệu suất xu hướng 15 phút trên mẫu 15 giây
   if(daChot > 901)
   {
      double num = MathAbs(g_bMid[BIdx(1)] - g_bMid[BIdx(901)]);
      double den = 0.0;
      for(int k = 0; k < 60; k++)
         den += MathAbs(g_bMid[BIdx(1 + 15 * k)] - g_bMid[BIdx(16 + 15 * k)]);
      g_er15 = den > 0.0 ? num / den : 0.0;
   }
   // Cao/thấp 60 giây gần nhất (không gồm giây hiện tại)
   int m = MinI(60, daChot);
   double hi = g_bHi[BIdx(1)];
   double lo = g_bLo[BIdx(1)];
   for(int k = 2; k <= m; k++)
   {
      int i = BIdx(k);
      if(g_bHi[i] > hi) hi = g_bHi[i];
      if(g_bLo[i] < lo) lo = g_bLo[i];
   }
   g_microHi = hi;
   g_microLo = lo;
   g_sprTB = g_sprTB <= 0.0 ? g_spread : g_sprTB + (g_spread - g_sprTB) / 300.0;
   g_duLieuDu = (g_giayHienTai - g_batDauLienTuc) >= InpKhoiDongGiay && g_bCount >= 120;
}

void TinhDacTrungTick()
{
   double m5 = MidTruoc(5), m30 = MidTruoc(30), m60 = MidTruoc(60);
   g_v5 = (g_mid - m5) / 5.0;
   g_v30 = (g_mid - m30) / 30.0;
   double v30Cu = (m30 - m60) / 30.0;
   g_a30 = g_v30 - v30Cu;
   // Sốc giá
   if(g_duLieuDu && g_rv1 > 0.0)
   {
      double quang5 = MathAbs(g_mid - m5);
      double nguong = MathMax(InpSocHeSo * g_rv1 * MathSqrt(5.0), InpSocToiThieu);
      if(quang5 > nguong)
      {
         if(g_giayHienTai >= g_socDen)
            GhiSuKien("SOC_GIA", "Giá chạy " + So2(quang5) + " trong 5 giây (ngưỡng " + So2(nguong) + "); tạm dừng mở lệnh " +
                      IntegerToString(InpTamDungSauSocGiay) + " giây");
         g_socDen = g_giayHienTai + InpTamDungSauSocGiay;
      }
   }
   g_soc = g_giayHienTai < g_socDen;
   g_spreadDotBien = g_sprTB > 0.0 && g_spread > InpSpreadDotBienHeSo * g_sprTB && g_spread > g_sprTB + 0.05;
}

// Nạp một tick; trả về true khi vừa chuyển sang giây mới
bool CapNhatTick(const MqlTick &t)
{
   double mid = (t.bid + t.ask) * 0.5;
   long giay = (long)t.time;
   bool giayMoi = false;
   if(g_bHead < 0)
   {
      g_mid = mid;
      g_spread = t.ask - t.bid;
      g_sprTB = g_spread;
      TickReset(giay, mid);
      giayMoi = true;
   }
   else
   {
      long cur = g_bT[g_bHead];
      if(giay > cur)
      {
         if(giay - cur > InpMatTickToiDaGiay)
         {
            GhiSuKien("MAT_TICK", "Không có tick " + IntegerToString(giay - cur) + " giây; khởi động lại dữ liệu tick");
            TickReset(giay, mid);
         }
         else
         {
            KetThucGiay();
            for(long s = cur + 1; s < giay; s++)
            {
               DayGiay(s, g_mid);
               KetThucGiay();
            }
            DayGiay(giay, mid);
         }
         giayMoi = true;
      }
   }
   g_bid = t.bid;
   g_ask = t.ask;
   g_mid = mid;
   g_spread = t.ask - t.bid;
   int i = g_bHead;
   g_bMid[i] = mid;
   if(mid > g_bHi[i]) g_bHi[i] = mid;
   if(mid < g_bLo[i]) g_bLo[i] = mid;
   g_bN[i]++;
   if(giay > g_giayHienTai) g_giayHienTai = giay;
   if(giayMoi) TinhDacTrungGiay();
   TinhDacTrungTick();
   return giayMoi;
}

// Cực trị (cao nhất khi layCao=true) từ mốc tuGiay đến hiện tại, theo bộ đệm phút + giây hiện tại
double CucTri(const bool layCao, const long tuGiay, long &thoiDiem)
{
   double best = 0.0;
   bool co = false;
   thoiDiem = 0;
   for(int k = 0; k < g_mCount; k++)
   {
      int j = g_mHead - k;
      if(j < 0) j += DH5_PHUT_BUF;
      if(g_mT[j] + 59 < tuGiay) break;
      double v = layCao ? g_mHi[j] : g_mLo[j];
      if(!co || (layCao ? v > best : v < best))
      {
         best = v;
         thoiDiem = layCao ? g_mHiT[j] : g_mLoT[j];
         co = true;
      }
   }
   if(g_bHead >= 0)
   {
      double v = layCao ? g_bHi[g_bHead] : g_bLo[g_bHead];
      if(!co || (layCao ? v > best : v < best))
      {
         best = v;
         thoiDiem = g_bT[g_bHead];
         co = true;
      }
   }
   return best;
}

// Cực trị sau mốc tuGiay (tính cả giây của mốc)
double CucTriSau(const bool layCao, const long tuGiay, long &thoiDiem)
{
   double best = 0.0;
   bool co = false;
   thoiDiem = 0;
   for(int k = 0; k < g_mCount; k++)
   {
      int j = g_mHead - k;
      if(j < 0) j += DH5_PHUT_BUF;
      if(g_mT[j] + 59 < tuGiay) break;
      if(g_mT[j] >= tuGiay)
      {
         double v = layCao ? g_mHi[j] : g_mLo[j];
         if(!co || (layCao ? v > best : v < best))
         {
            best = v;
            thoiDiem = layCao ? g_mHiT[j] : g_mLoT[j];
            co = true;
         }
      }
      else
      {
         for(long s = tuGiay; s <= g_mT[j] + 59; s++)
         {
            long lui = g_bT[g_bHead] - s;
            if(lui < 0 || lui >= g_bCount) continue;
            int i = BIdx((int)lui);
            double v = layCao ? g_bHi[i] : g_bLo[i];
            if(!co || (layCao ? v > best : v < best))
            {
               best = v;
               thoiDiem = s;
               co = true;
            }
         }
      }
   }
   if(g_bHead >= 0 && g_bT[g_bHead] >= tuGiay)
   {
      double v = layCao ? g_bHi[g_bHead] : g_bLo[g_bHead];
      if(!co || (layCao ? v > best : v < best))
      {
         best = v;
         thoiDiem = g_bT[g_bHead];
         co = true;
      }
   }
   return co ? best : 0.0;
}

//+------------------------------------------------------------------+
//| Bối cảnh khung lớn                                                |
//+------------------------------------------------------------------+
double ATRTuNen(MqlRates &r[], const int soNen)
{
   int tong = ArraySize(r);
   if(tong < soNen + 1 || soNen < 1) return 0.0;
   double s = 0.0;
   for(int i = tong - soNen; i < tong; i++)
   {
      double h = r[i].high, l = r[i].low, pc = r[i - 1].close;
      double tr = MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
      s += tr;
   }
   return s / soNen;
}

// EMA tại nến (tong-1-lui), khởi tạo bằng giá đóng cửa nến đầu tiên
double EMATuNen(MqlRates &r[], const int chuKy, const int lui)
{
   int tong = ArraySize(r);
   if(tong < chuKy + lui + 1 || chuKy < 1) return 0.0;
   double k = 2.0 / (chuKy + 1.0);
   double e = r[0].close;
   for(int i = 1; i < tong - lui; i++) e = e + k * (r[i].close - e);
   return e;
}

void CapNhatMucPP3();

void CapNhatBoiCanh(const bool epBuoc)
{
   MqlRates m1[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 1, m1) < 1) return;
   long phut = (long)m1[0].time;
   if(!epBuoc && phut == g_ctxPhut) return;
   g_ctxPhut = phut;
   bool ok = true;
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, 15, r) == 15) g_atrM1 = ATRTuNen(r, 14); else ok = false;
   if(CopyRates(_Symbol, PERIOD_M5, 1, 15, r) == 15) g_atrM5 = ATRTuNen(r, 14); else ok = false;
   if(CopyRates(_Symbol, PERIOD_M5, 1, 13, r) == 13)
   {
      double num = MathAbs(r[12].close - r[0].close), den = 0.0;
      for(int i = 1; i < 13; i++) den += MathAbs(r[i].close - r[i - 1].close);
      g_erM5 = den > 0.0 ? num / den : 0.0;
   }
   else ok = false;
   int nh = CopyRates(_Symbol, PERIOD_H1, 1, 200, r);
   if(nh >= 80)
   {
      g_atrH1 = ATRTuNen(r, 14);
      double e0 = EMATuNen(r, 50, 0), e3 = EMATuNen(r, 50, 3);
      g_emaH1 = e0;
      g_docH1 = g_atrH1 > 0.0 ? (e0 - e3) / 3.0 / g_atrH1 : 0.0;
   }
   else ok = false;
   int nq = CopyRates(_Symbol, PERIOD_M15, 1, 200, r);
   if(nq >= 80)
   {
      g_ema20M15 = EMATuNen(r, 20, 0);
      g_ema50M15 = EMATuNen(r, 50, 0);
   }
   else ok = false;
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, r) == 1)
   {
      g_pdh = r[0].high;
      g_pdl = r[0].low;
   }
   else ok = false;
   // Biên độ phiên Á hôm nay (00:00-07:00 giờ máy chủ), chỉ dùng sau 07:00
   MqlDateTime d;
   TimeToStruct((datetime)phut, d);
   g_asiaCo = false;
   if(d.hour >= 7)
   {
      datetime dau = (datetime)DauNgay(phut);
      int na = CopyRates(_Symbol, PERIOD_M5, dau, (datetime)(DauNgay(phut) + 7 * 3600 - 1), r);
      if(na >= 12)
      {
         g_asiaHi = r[0].high;
         g_asiaLo = r[0].low;
         for(int i = 1; i < na; i++)
         {
            if(r[i].high > g_asiaHi) g_asiaHi = r[i].high;
            if(r[i].low < g_asiaLo) g_asiaLo = r[i].low;
         }
         g_asiaCo = true;
      }
   }
   // Đỉnh/đáy 4 giờ, bỏ 15 phút gần nhất
   int n4 = CopyRates(_Symbol, PERIOD_M5, 3, 48, r);
   if(n4 >= 24)
   {
      g_r4Hi = r[0].high;
      g_r4Lo = r[0].low;
      for(int i = 1; i < n4; i++)
      {
         if(r[i].high > g_r4Hi) g_r4Hi = r[i].high;
         if(r[i].low < g_r4Lo) g_r4Lo = r[i].low;
      }
   }
   else
   {
      g_r4Hi = 0.0;
      g_r4Lo = 0.0;
   }
   // Hộp tích lũy PP2
   g_hopCo = false;
   int nb = CopyRates(_Symbol, PERIOD_M1, 1, InpPP2SoPhut, r);
   if(nb == InpPP2SoPhut)
   {
      g_hopHi = r[0].high;
      g_hopLo = r[0].low;
      for(int i = 1; i < nb; i++)
      {
         if(r[i].high > g_hopHi) g_hopHi = r[i].high;
         if(r[i].low < g_hopLo) g_hopLo = r[i].low;
      }
      // Hộp chỉ hợp lệ khi các nến liền mạch (không có giờ nghỉ bên trong)
      g_hopCo = ((long)r[nb - 1].time - (long)r[0].time) <= (long)(InpPP2SoPhut + 5) * 60;
   }
   bool coTruoc = g_ctxCo;
   g_ctxCo = ok && g_atrM1 > 0.0 && g_atrM5 > 0.0 && g_atrH1 > 0.0 && g_emaH1 > 0.0;
   if(g_ctxCo != coTruoc)
      GhiSuKien("BOI_CANH", g_ctxCo ? "Đủ dữ liệu nến M1/M5/M15/H1/D1" : "Chưa đủ dữ liệu nến khung lớn");
   CapNhatMucPP3();
}

//+------------------------------------------------------------------+
//| Nhận diện trạng thái thị trường                                   |
//+------------------------------------------------------------------+
int TinhTrangThai()
{
   if(!g_duLieuDu) return TT_KHOI_DONG;
   if(g_soc || g_spreadDotBien) return TT_SOC;
   if(!g_ctxCo) return TT_KHOI_DONG;
   if(g_atrM5 <= 0.0 || g_spread / g_atrM5 > InpChiPhiToiDaATR) return TT_YEU;
   bool tang = g_docH1 >= InpDocH1ToiThieu && g_bid > g_emaH1 && g_ema20M15 > g_ema50M15;
   bool giam = g_docH1 <= -InpDocH1ToiThieu && g_bid < g_emaH1 && g_ema20M15 < g_ema50M15;
   if(tang && g_erM5 >= InpERXuHuong) return TT_TANG;
   if(giam && g_erM5 >= InpERXuHuong) return TT_GIAM;
   if(g_erM5 <= InpERSideway) return TT_SIDEWAY;
   return TT_CHUYEN_TIEP;
}

void CapNhatTrangThai()
{
   g_trangThai = TinhTrangThai();
   if(g_trangThai != g_trangThaiCu)
   {
      GhiSuKien("TRANG_THAI", MaTrangThai(g_trangThaiCu < 0 ? TT_KHOI_DONG : g_trangThaiCu) + " -> " + MaTrangThai(g_trangThai) +
                " | ER M5 " + So2(g_erM5) + " | dốc H1 " + So2(g_docH1) + " | ATR M5 " + So2(g_atrM5) + " | spread " + So2(g_spread));
      g_trangThaiCu = g_trangThai;
   }
}

//+------------------------------------------------------------------+
//| Tín hiệu: giá, điểm                                               |
//+------------------------------------------------------------------+
void KhoiTaoTinHieu(DH5TinHieu &s, const int pp, const int huong)
{
   ZeroMemory(s);
   s.pp = pp;
   s.huong = huong;
   s.trangThai = g_trangThai;
   s.phien = PhienCua(g_giayHienTai);
   s.thoiGian = g_giayHienTai;
   s.xacSuat = -1.0;
   for(int i = 0; i < 6; i++) s.q[i] = 0.5;
}

// Đặt giá vào, SL, TP từ SL gốc (theo cấu trúc). Trả về false khi SL quá xa.
bool TaoMucGia(DH5TinHieu &s, const double slGoc, string &lyDo)
{
   double gia = s.huong > 0 ? g_ask : g_bid;
   double khoang = s.huong > 0 ? gia - slGoc : slGoc - gia;
   double toiThieu = MathMax(InpSLToiThieu, InpSLToiThieuATR * g_atrM5);
   if(khoang < toiThieu) khoang = toiThieu;
   if(khoang > InpSLToiDa)
   {
      lyDo = "SL_QUA_XA " + So2(khoang);
      return false;
   }
   s.gia = gia;
   s.sl = ChuanGia(s.huong > 0 ? gia - khoang : gia + khoang);
   s.khoangSL = MathAbs(gia - s.sl);
   s.tp = ChuanGia(s.huong > 0 ? gia + InpTyLeRR * s.khoangSL : gia - InpTyLeRR * s.khoangSL);
   return true;
}

void TinhDiem(DH5TinHieu &s)
{
   double h = (double)s.huong;
   double chuan30 = g_rv1 * MathSqrt(30.0);
   if(chuan30 > 0.0)
   {
      double z = h * (g_mid - MidTruoc(30)) / chuan30;
      s.q[1] = Kep(z / 2.0, 0.0, 1.0);
      double za = h * g_a30 * 30.0 / (g_rv1 * MathSqrt(60.0));
      s.q[2] = Kep(0.5 + za / 4.0, 0.0, 1.0);
   }
   s.q[3] = Kep((g_cuongDo - 0.7) / 1.0, 0.0, 1.0);
   double tran = InpSpreadToiDaTheoSL / 100.0;
   s.q[4] = (s.khoangSL > 0.0 && tran > 0.0) ? Kep(1.0 - (g_spread / s.khoangSL) / tran, 0.0, 1.0) : 0.0;
   s.diem = 100.0 * (0.25 * s.q[0] + 0.20 * s.q[1] + 0.10 * s.q[2] + 0.10 * s.q[3] + 0.10 * s.q[4] + 0.25 * s.q[5]);
}

//+------------------------------------------------------------------+
//| PP1: xu hướng - hồi - tiếp diễn                                   |
//+------------------------------------------------------------------+
void PP1_ThietLap()
{
   g_pp1.san = false;
   if(!InpDungPP1 || !g_ctxCo || !g_duLieuDu) return;
   int h = 0;
   if(g_trangThai == TT_TANG) h = 1;
   else if(g_trangThai == TT_GIAM) h = -1;
   if(h == 0) return;
   if(g_bCount < 900 || g_atrM5 <= 0.0) return;
   long tDinh = 0;
   double dinh = CucTri(h > 0, g_giayHienTai - 3600, tDinh);
   if(tDinh == 0 || tDinh == g_pp1DaDung) return;
   long tHoi = 0;
   double hoi = CucTriSau(h < 0, tDinh, tHoi);
   if(tHoi == 0) return;
   double atr = g_atrM5;
   double doSau = h > 0 ? dinh - hoi : hoi - dinh;
   if(doSau < InpPP1HoiToiThieu * atr || doSau > InpPP1HoiToiDa * atr) return;
   if(g_giayHienTai - tHoi < 20) return;
   double batLai = h > 0 ? g_mid - hoi : hoi - g_mid;
   if(batLai < InpPP1BatLaiToiThieu * atr || batLai > InpPP1BatLaiToiDa * atr) return;
   g_pp1.san = true;
   g_pp1.huong = h;
   g_pp1.dinh = dinh;
   g_pp1.dinhT = tDinh;
   g_pp1.hoi = hoi;
   g_pp1.hoiT = tHoi;
   g_pp1.kichHoat = h > 0 ? g_microHi : g_microLo;
   double dem = InpDemSLATR * atr;
   g_pp1.slGoc = h > 0 ? hoi - g_spread * 0.5 - dem : hoi + g_spread * 0.5 + dem;
   g_pp1.doSau = doSau;
}

bool PP1_KichHoat(DH5TinHieu &s, string &lyDo)
{
   if(!g_pp1.san) return false;
   int h = g_pp1.huong;
   if(g_trangThai != (h > 0 ? TT_TANG : TT_GIAM)) return false;
   bool vuot = h > 0 ? g_mid > g_pp1.kichHoat : g_mid < g_pp1.kichHoat;
   if(!vuot) return false;
   if(h > 0 && !(g_v5 > 0.0 && g_v30 > 0.0 && g_a30 > 0.0)) return false;
   if(h < 0 && !(g_v5 < 0.0 && g_v30 < 0.0 && g_a30 < 0.0)) return false;
   double atr = g_atrM5;
   if(atr <= 0.0) return false;
   KhoiTaoTinHieu(s, 0, h);
   g_pp1.san = false;
   g_pp1DaDung = g_pp1.dinhT;
   s.moTa = "dinh=" + SoGia(g_pp1.dinh) + " hoi=" + SoGia(g_pp1.hoi) + " do_sau=" + So2(g_pp1.doSau / atr) + "ATR";
   if(!TaoMucGia(s, g_pp1.slGoc, lyDo)) return true;
   double qSau = Kep(1.0 - MathAbs(g_pp1.doSau / atr - 1.5), 0.0, 1.0);
   double batLai = h > 0 ? g_mid - g_pp1.hoi : g_pp1.hoi - g_mid;
   double rong = MathMax(0.01, InpPP1BatLaiToiDa - InpPP1BatLaiToiThieu);
   double qBat = Kep(1.0 - (batLai / atr - InpPP1BatLaiToiThieu) / rong, 0.0, 1.0);
   s.q[5] = 0.6 * qSau + 0.4 * qBat;
   double qDoc = Kep(MathAbs(g_docH1) / (3.0 * InpDocH1ToiThieu), 0.0, 1.0);
   double qER = Kep((g_erM5 - InpERSideway) / MathMax(0.01, 0.6 - InpERSideway), 0.0, 1.0);
   s.q[0] = 0.5 * qDoc + 0.5 * qER;
   return true;
}

//+------------------------------------------------------------------+
//| PP2: phá vỡ hộp tích lũy                                          |
//+------------------------------------------------------------------+
void PP2_ThietLap()
{
   g_pp2.san = false;
   if(!InpDungPP2 || !g_ctxCo || !g_duLieuDu || !g_hopCo) return;
   if(g_trangThai != TT_SIDEWAY && g_trangThai != TT_CHUYEN_TIEP && g_trangThai != TT_TANG && g_trangThai != TT_GIAM) return;
   if(g_giayHienTai - g_pp2DaDung < (long)InpPP2SoPhut * 30) return;
   double cao = g_hopHi - g_hopLo;
   double thuong = g_atrM5 * MathSqrt(InpPP2SoPhut / 5.0);
   if(thuong <= 0.0) return;
   double tyLe = cao / thuong;
   if(tyLe > InpPP2NenToiDa || cao < 0.8 * g_atrM5) return;
   g_pp2.san = true;
   g_pp2.hi = g_hopHi;
   g_pp2.lo = g_hopLo;
   g_pp2.tyLeNen = tyLe;
}

bool PP2_KichHoat(DH5TinHieu &s, string &lyDo)
{
   if(!g_pp2.san) return false;
   double vuot = InpPP2VuotHop * g_atrM5;
   int h = 0;
   if(g_bid > g_pp2.hi + vuot && g_v5 > 0.0 && g_v30 > 0.0 && g_trangThai != TT_GIAM) h = 1;
   else if(g_bid < g_pp2.lo - vuot && g_v5 < 0.0 && g_v30 < 0.0 && g_trangThai != TT_TANG) h = -1;
   if(h == 0) return false;
   if(g_cuongDo < InpPP2CuongDoTick) return false;
   KhoiTaoTinHieu(s, 1, h);
   g_pp2.san = false;
   g_pp2DaDung = g_giayHienTai;
   double giua = (g_pp2.hi + g_pp2.lo) * 0.5;
   double dem = 0.1 * g_atrM5;
   double slGoc = h > 0 ? giua - dem : giua + g_spread + dem;
   s.moTa = "hop=" + SoGia(g_pp2.lo) + "-" + SoGia(g_pp2.hi) + " nen=" + So2(g_pp2.tyLeNen) + " cuong_do=" + So2(g_cuongDo);
   if(!TaoMucGia(s, slGoc, lyDo)) return true;
   s.q[5] = 0.5 * Kep(1.0 - g_pp2.tyLeNen / InpPP2NenToiDa + 0.3, 0.0, 1.0) + 0.5 * Kep((g_cuongDo - 1.0) / 1.0, 0.0, 1.0);
   int hd = 0;
   if(g_docH1 >= InpDocH1ToiThieu) hd = 1;
   else if(g_docH1 <= -InpDocH1ToiThieu) hd = -1;
   if(hd == h) s.q[0] = 1.0;
   else if(hd == 0) s.q[0] = 0.6;
   else s.q[0] = 0.2;
   return true;
}

//+------------------------------------------------------------------+
//| PP3: quét thanh khoản - đảo chiều                                 |
//+------------------------------------------------------------------+
void DatMuc(const int i, const double gia, const int loai, const bool co)
{
   int ngay = NgayKey(g_giayHienTai);
   if(!co || gia <= 0.0)
   {
      g_muc[i].gia = 0.0;
      return;
   }
   bool doi = g_atrM5 > 0.0 ? MathAbs(gia - g_muc[i].gia) > 0.1 * g_atrM5 : gia != g_muc[i].gia;
   if(doi || g_muc[i].ngay != ngay || g_muc[i].loai != loai)
   {
      g_muc[i].gia = gia;
      g_muc[i].loai = loai;
      g_muc[i].quet = false;
      g_muc[i].quetT = 0;
      g_muc[i].cucTri = 0.0;
      g_muc[i].hong = false;
      g_muc[i].daDung = false;
      g_muc[i].ngay = ngay;
   }
}

void CapNhatMucPP3()
{
   DatMuc(0, g_pdh, 1, g_pdh > 0.0);
   DatMuc(1, g_pdl, -1, g_pdl > 0.0);
   DatMuc(2, g_asiaHi, 1, g_asiaCo);
   DatMuc(3, g_asiaLo, -1, g_asiaCo);
   DatMuc(4, g_r4Hi, 1, g_r4Hi > 0.0);
   DatMuc(5, g_r4Lo, -1, g_r4Lo > 0.0);
}

// Theo dõi trạng thái quét ở mọi tick (kể cả khi chưa được mở lệnh)
void PP3_TheoDoiQuet()
{
   if(!InpDungPP3 || g_atrM5 <= 0.0) return;
   double atr = g_atrM5;
   for(int i = 0; i < DH5_SO_MUC; i++)
   {
      if(g_muc[i].gia <= 0.0 || g_muc[i].daDung || g_muc[i].hong) continue;
      double L = g_muc[i].gia;
      double vuot = g_muc[i].loai > 0 ? g_bid - L : L - g_bid;
      if(!g_muc[i].quet)
      {
         if(vuot >= InpPP3QuetToiThieu * atr)
         {
            g_muc[i].quet = true;
            g_muc[i].quetT = g_giayHienTai;
            g_muc[i].cucTri = g_bid;
         }
         continue;
      }
      if(g_muc[i].loai > 0 ? g_bid > g_muc[i].cucTri : g_bid < g_muc[i].cucTri) g_muc[i].cucTri = g_bid;
      double sau = g_muc[i].loai > 0 ? g_muc[i].cucTri - L : L - g_muc[i].cucTri;
      if(sau > InpPP3QuetToiDa * atr) { g_muc[i].hong = true; continue; }
      if(g_giayHienTai - g_muc[i].quetT > InpPP3ThoiGianGiay) { g_muc[i].quet = false; continue; }
   }
}

bool PP3_KichHoat(DH5TinHieu &s, string &lyDo)
{
   if(!InpDungPP3 || !g_ctxCo || g_atrM5 <= 0.0) return false;
   double atr = g_atrM5;
   for(int i = 0; i < DH5_SO_MUC; i++)
   {
      if(g_muc[i].gia <= 0.0 || g_muc[i].daDung || g_muc[i].hong || !g_muc[i].quet) continue;
      double L = g_muc[i].gia;
      int h = -g_muc[i].loai;
      bool quayLai = h < 0 ? g_bid < L - 0.05 * atr : g_bid > L + 0.05 * atr;
      if(!quayLai) continue;
      bool dongLuc = h < 0 ? (g_v5 < 0.0 && g_v30 < 0.0 && g_a30 < 0.0) : (g_v5 > 0.0 && g_v30 > 0.0 && g_a30 > 0.0);
      if(!dongLuc) continue;
      if(h < 0 && g_trangThai == TT_TANG) continue;
      if(h > 0 && g_trangThai == TT_GIAM) continue;
      KhoiTaoTinHieu(s, 2, h);
      g_muc[i].daDung = true;
      double dem = InpDemSLATR * atr;
      double slGoc = h < 0 ? g_muc[i].cucTri + g_spread + dem : g_muc[i].cucTri - dem;
      double doQuet = (h < 0 ? g_muc[i].cucTri - L : L - g_muc[i].cucTri) / atr;
      double tg = (double)(g_giayHienTai - g_muc[i].quetT);
      s.moTa = "muc=" + IntegerToString(i) + " gia=" + SoGia(L) + " quet=" + So2(doQuet) + "ATR sau " + DoubleToString(tg, 0) + "s";
      if(!TaoMucGia(s, slGoc, lyDo)) return true;
      s.q[5] = 0.5 * Kep(1.0 - MathAbs(doQuet - 0.5), 0.0, 1.0) + 0.5 * Kep(1.0 - tg / MathMax(1.0, (double)InpPP3ThoiGianGiay), 0.0, 1.0);
      s.q[0] = Kep(1.0 - g_erM5 / 0.5, 0.0, 1.0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Học thích nghi                                                    |
//+------------------------------------------------------------------+
int ChiSoO(const int pp, const int huong, const int phien)
{
   return pp * 6 + (huong > 0 ? 0 : 3) + phien;
}

void DacTrungTuTinHieu(const DH5TinHieu &s)
{
   g_x[0] = 1.0;
   for(int i = 0; i < 6; i++) g_x[1 + i] = (s.q[i] - 0.5) * 2.0;
   g_x[7] = (double)s.huong;
   g_x[8] = s.pp == 0 ? 1.0 : 0.0;
   g_x[9] = s.pp == 2 ? 1.0 : 0.0;
   g_x[10] = s.phien == 0 ? 1.0 : 0.0;
   g_x[11] = s.phien == 2 ? 1.0 : 0.0;
}

void DacTrungTuLenhAo(const DH5LenhAo &a)
{
   g_x[0] = 1.0;
   for(int i = 0; i < 6; i++) g_x[1 + i] = (a.q[i] - 0.5) * 2.0;
   g_x[7] = (double)a.huong;
   g_x[8] = a.pp == 0 ? 1.0 : 0.0;
   g_x[9] = a.pp == 2 ? 1.0 : 0.0;
   g_x[10] = a.phien == 0 ? 1.0 : 0.0;
   g_x[11] = a.phien == 2 ? 1.0 : 0.0;
}

double MoHinhDuDoan()
{
   double z = 0.0;
   for(int j = 0; j < DH5_SO_DT; j++) z += g_w[j] * g_x[j];
   z = Kep(z, -30.0, 30.0);
   return 1.0 / (1.0 + MathExp(-z));
}

void MoHinhHoc(const double y)
{
   double p = MoHinhDuDoan();
   const double lr = 0.03, l2 = 0.001;
   for(int j = 0; j < DH5_SO_DT; j++) g_w[j] += lr * ((y - p) * g_x[j] - l2 * g_w[j]);
   g_moHinhN++;
}

void HocCapNhat(const DH5LenhAo &a, const double R)
{
   int o = ChiSoO(a.pp, a.huong, a.phien);
   g_hocN[o]++;
   double chia = MathMin((double)g_hocN[o], (double)MaxI(2, InpHocChuKy));
   double k = 1.0 / chia;
   g_hocR[o] += k * (R - g_hocR[o]);
   g_hocW[o] += k * ((R > 0.0 ? 1.0 : 0.0) - g_hocW[o]);
   bool cu = g_hocTat[o];
   if(g_hocN[o] >= InpHocSoMauToiThieu)
   {
      if(InpCheDoHoc == DH5_HOC_CHUNG_MINH_TRUOC)
      {
         // Chỉ bật khi lệnh ảo đã chứng minh kỳ vọng dương; tắt lại ngay khi kỳ vọng xuống dưới 0
         if(g_hocTat[o] && g_hocR[o] >= InpHocNguongBat) g_hocTat[o] = false;
         else if(!g_hocTat[o] && g_hocR[o] < 0.0) g_hocTat[o] = true;
      }
      else
      {
         if(!g_hocTat[o] && g_hocR[o] < InpHocNguongTat) g_hocTat[o] = true;
         else if(g_hocTat[o] && g_hocR[o] >= 0.0) g_hocTat[o] = false;
      }
   }
   if(cu != g_hocTat[o])
      GhiSuKien("HOC_THICH_NGHI", MaPP(a.pp) + " " + (a.huong > 0 ? "BUY" : "SELL") + " phiên " + TenPhien(a.phien) +
                (g_hocTat[o] ? " TẠM TẮT" : " BẬT LẠI") + " | kỳ vọng " + So2(g_hocR[o]) + "R | " + IntegerToString(g_hocN[o]) + " lệnh ảo");
   DacTrungTuLenhAo(a);
   MoHinhHoc(R > 0.0 ? 1.0 : 0.0);
}

string DuongDanHoc()
{
   return DH5_THU_MUC + "\\DH5_" + IntegerToString(InpMagic) + "_" + _Symbol + "_hoc.csv";
}

void LuuHoc()
{
   if(g_tester && !InpHocNapTrongTester) return;
   int h = FileOpen(DuongDanHoc(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "PHIEN_BAN;" + DH5_PHIEN_BAN + "\r\n");
   for(int o = 0; o < DH5_SO_O; o++)
      FileWriteString(h, "O;" + IntegerToString(o) + ";" + IntegerToString(g_hocN[o]) + ";" + DoubleToString(g_hocR[o], 6) + ";" +
                      DoubleToString(g_hocW[o], 6) + ";" + (g_hocTat[o] ? "1" : "0") + "\r\n");
   for(int j = 0; j < DH5_SO_DT; j++)
      FileWriteString(h, "W;" + IntegerToString(j) + ";" + DoubleToString(g_w[j], 8) + "\r\n");
   FileWriteString(h, "N;" + IntegerToString(g_moHinhN) + "\r\n");
   FileClose(h);
}

void NapHoc()
{
   if(g_tester && !InpHocNapTrongTester) return;
   if(!FileIsExist(DuongDanHoc(), FILE_COMMON)) return;
   int h = FileOpen(DuongDanHoc(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
   if(h == INVALID_HANDLE) return;
   int dong = 0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      string p[];
      int n = StringSplit(line, ';', p);
      if(n < 2) continue;
      if(p[0] == "O" && n >= 6)
      {
         int o = (int)StringToInteger(p[1]);
         if(o < 0 || o >= DH5_SO_O) continue;
         g_hocN[o] = (int)StringToInteger(p[2]);
         g_hocR[o] = StringToDouble(p[3]);
         g_hocW[o] = StringToDouble(p[4]);
         g_hocTat[o] = p[5] == "1";
         dong++;
      }
      else if(p[0] == "W" && n >= 3)
      {
         int j = (int)StringToInteger(p[1]);
         if(j < 0 || j >= DH5_SO_DT) continue;
         double w = StringToDouble(p[2]);
         if(MathIsValidNumber(w)) g_w[j] = w;
         dong++;
      }
      else if(p[0] == "N" && n >= 2)
         g_moHinhN = (int)StringToInteger(p[1]);
   }
   FileClose(h);
   Print("DH5: đã nạp dữ liệu học (", dong, " dòng, mô hình ", g_moHinhN, " mẫu).");
}

//+------------------------------------------------------------------+
//| Lệnh ảo (mỗi tín hiệu đều được theo dõi để học)                   |
//+------------------------------------------------------------------+
int TaoLenhAo(const DH5TinHieu &s)
{
   if(s.khoangSL <= 0.0) return -1;
   for(int i = 0; i < DH5_SO_AO; i++)
   {
      if(g_ao[i].mo) continue;
      g_ao[i].mo = true;
      g_ao[i].id = s.id;
      g_ao[i].pp = s.pp;
      g_ao[i].huong = s.huong;
      g_ao[i].phien = s.phien;
      g_ao[i].trangThai = s.trangThai;
      g_ao[i].gia = s.gia;
      g_ao[i].sl = s.sl;
      g_ao[i].tp = s.tp;
      g_ao[i].r0 = s.khoangSL;
      g_ao[i].tot = 0.0;
      g_ao[i].xau = 0.0;
      g_ao[i].hoaVon = false;
      g_ao[i].moT = g_giayHienTai;
      g_ao[i].diem = s.diem;
      for(int k = 0; k < 6; k++) g_ao[i].q[k] = s.q[k];
      g_ao[i].thuc = false;
      g_soAoMo++;
      return i;
   }
   g_aoBoQua++;
   return -1;
}

bool QuaGioDongCuoiNgay();

void DongLenhAo(const int i, const double giaDong, const string lyDo)
{
   double R = g_ao[i].huong * (giaDong - g_ao[i].gia) / g_ao[i].r0;
   if(InpDungHocThichNghi || InpDungMoHinh) HocCapNhat(g_ao[i], R);
   if(g_hAo != INVALID_HANDLE)
   {
      double phut = (double)(g_giayHienTai - g_ao[i].moT) / 60.0;
      GhiDong(g_hAo, ThoiGianChuoi(g_giayHienTai) + ";" + IntegerToString(g_ao[i].id) + ";" + MaPP(g_ao[i].pp) + ";" +
              (g_ao[i].huong > 0 ? "BUY" : "SELL") + ";" + MaTrangThai(g_ao[i].trangThai) + ";" + TenPhien(g_ao[i].phien) + ";" +
              DoubleToString(g_ao[i].diem, 1) + ";" + (g_ao[i].thuc ? "1" : "0") + ";" + SoGia(g_ao[i].gia) + ";" +
              SoGia(g_ao[i].gia - g_ao[i].huong * g_ao[i].r0) + ";" + So2(g_ao[i].r0) + ";" + So4(R) + ";" +
              So4(g_ao[i].tot / g_ao[i].r0) + ";" + So4(g_ao[i].xau / g_ao[i].r0) + ";" + DoubleToString(phut, 1) + ";" + lyDo);
   }
   g_ao[i].mo = false;
   if(g_soAoMo > 0) g_soAoMo--;
}

void QuanLyLenhAo()
{
   if(g_soAoMo <= 0) return;
   bool cuoiNgay = InpDongLenhCuoiNgay && QuaGioDongCuoiNgay();
   for(int i = 0; i < DH5_SO_AO; i++)
   {
      if(!g_ao[i].mo) continue;
      int h = g_ao[i].huong;
      double gia = h > 0 ? g_bid : g_ask;
      double loi = h > 0 ? g_bid - g_ao[i].gia : g_ao[i].gia - g_ask;
      if(loi > g_ao[i].tot) g_ao[i].tot = loi;
      if(loi < g_ao[i].xau) g_ao[i].xau = loi;
      if(h > 0 ? g_bid <= g_ao[i].sl : g_ask >= g_ao[i].sl)
      {
         DongLenhAo(i, gia, g_ao[i].hoaVon ? "SL_SAU_HOA_VON" : "SL");
         continue;
      }
      if(h > 0 ? g_bid >= g_ao[i].tp : g_ask <= g_ao[i].tp)
      {
         DongLenhAo(i, gia, "TP");
         continue;
      }
      if(cuoiNgay)
      {
         DongLenhAo(i, gia, "CUOI_NGAY");
         continue;
      }
      if(InpGiuLenhToiDaPhut > 0 && g_giayHienTai - g_ao[i].moT >= (long)InpGiuLenhToiDaPhut * 60)
      {
         DongLenhAo(i, gia, "HET_GIO");
         continue;
      }
      double r0 = g_ao[i].r0;
      if(InpHoaVonTaiR > 0.0 && !g_ao[i].hoaVon && loi >= InpHoaVonTaiR * r0)
      {
         double be = g_ao[i].gia + h * 2.0 * g_point;
         if(h > 0 ? be > g_ao[i].sl : be < g_ao[i].sl) g_ao[i].sl = be;
         g_ao[i].hoaVon = true;
      }
      if(InpTrailingTuR > 0.0 && loi >= InpTrailingTuR * r0)
      {
         double moi = h > 0 ? g_bid - InpTrailingKhoangR * r0 : g_ask + InpTrailingKhoangR * r0;
         if(h > 0 ? moi > g_ao[i].sl : moi < g_ao[i].sl) g_ao[i].sl = moi;
      }
   }
}

//+------------------------------------------------------------------+
//| Lớp kiểm soát rủi ro độc lập                                      |
//+------------------------------------------------------------------+
double RuiRoPhanTram() { return MathMin(InpRuiRoMoiLenh, DH5_RUI_RO_TRAN); }
double LoNgayPhanTram() { return MathMin(InpLoNgayToiDa, DH5_LO_NGAY_TRAN); }
int    SoViTheToiDa() { return MinI(InpSoViTheToiDa, DH5_SO_VI_THE_TRAN); }
double KyQuyToiThieu() { return MathMax(InpKyQuySauVaoLenh, DH5_KY_QUY_SAN); }

// Vốn làm cơ sở tính rủi ro: số dư MT5, không vượt Equity khi đang lỗ thả nổi
double VonCoSo()
{
   double b = AccountInfoDouble(ACCOUNT_BALANCE);
   double e = AccountInfoDouble(ACCOUNT_EQUITY);
   return MathMin(b, e);
}

bool LaViTheEA()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic;
}

int PPTuComment(const string cmt)
{
   string p[];
   int n = StringSplit(cmt, '|', p);
   if(n < 3 || p[0] != "DH5") return -1;
   int pp = (int)StringToInteger(p[1]) - 1;
   if(pp < 0 || pp > 2) return -1;
   return pp;
}

int DemViTheEA(const int pp)
{
   int dem = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      if(pp >= 0 && PPTuComment(PositionGetString(POSITION_COMMENT)) != pp) continue;
      dem++;
   }
   return dem;
}

// Tiền có thể mất thêm nếu mọi vị thế của EA chạm SL hiện tại
double RuiRoMoConLai()
{
   double tong = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      bool mua = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double thaNoi = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double taiSL = 0.0;
      if(sl <= 0.0 || !OrderCalcProfit(mua ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, open, sl, taiSL))
      {
         // Không có SL (không nên xảy ra): coi toàn bộ rủi ro đã lưu là còn nguyên
         double luu = GlobalVariableCheck(TenGV("M", (long)tk)) ? GlobalVariableGet(TenGV("M", (long)tk)) : VonCoSo() * RuiRoPhanTram() / 100.0;
         tong += luu;
         continue;
      }
      taiSL -= InpPhiMoiLot * vol * 0.5;
      double conLai = thaNoi - taiSL;
      if(conLai > 0.0) tong += conLai;
   }
   if(g_cho.dung) tong += g_cho.tien;
   return tong;
}

void DoiDinhTheoNapRut(const int ngay, const double napRut);

void DocLichSuNgay()
{
   long now = (long)TimeCurrent();
   long dau = DauNgay(now);
   if(!HistorySelect((datetime)(dau - 7 * 86400), (datetime)(now + 86400))) return;
   int n = HistoryDealsTotal();
   long ids[];
   int soId = 0;
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      long en = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(en != DEAL_ENTRY_IN && en != DEAL_ENTRY_INOUT) continue;
      ArrayResize(ids, soId + 1, 64);
      ids[soId] = HistoryDealGetInteger(d, DEAL_POSITION_ID);
      soId++;
   }
   double tong = 0.0, napRut = 0.0, chot = 0.0;
   for(int i = 0; i < n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetInteger(d, DEAL_TIME) < dau) continue;
      double net = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
                   HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_FEE);
      tong += net;
      long loai = HistoryDealGetInteger(d, DEAL_TYPE);
      if(loai != DEAL_TYPE_BUY && loai != DEAL_TYPE_SELL)
      {
         napRut += net;
         continue;
      }
      long pid = HistoryDealGetInteger(d, DEAL_POSITION_ID);
      for(int k = 0; k < soId; k++)
         if(ids[k] == pid) { chot += net; break; }
   }
   g_ngay.balanceDau = AccountInfoDouble(ACCOUNT_BALANCE) - tong;
   g_ngay.napRut = napRut;
   g_ngay.chotEA = chot;
   DoiDinhTheoNapRut(NgayKey(now), napRut);
}

//+------------------------------------------------------------------+
//| Cầu dao sụt giảm tổng                                             |
//+------------------------------------------------------------------+
void LuuSG()
{
   GlobalVariableSet(TenGVChung("SGDINH"), g_dinhSG);
   GlobalVariableSet(TenGVChung("SGDUNG"), g_dungSG ? 1.0 : 0.0);
   GlobalVariableSet(TenGVChung("SGNRNG"), (double)g_napRutNgay);
   GlobalVariableSet(TenGVChung("SGNRXL"), g_napRutDaTinh);
}

// Nạp/rút tiền không phải lãi/lỗ: dời đỉnh vốn đúng bằng số tiền nạp/rút trong ngày
void DoiDinhTheoNapRut(const int ngay, const double napRut)
{
   if(g_napRutNgay < 0)
   {
      // Lần đọc đầu tiên sau khởi động: số nạp/rút hôm nay đã nằm trong Equity dùng làm đỉnh
      g_napRutNgay = ngay;
      g_napRutDaTinh = napRut;
      LuuSG();
      return;
   }
   if(g_napRutNgay != ngay)
   {
      g_napRutNgay = ngay;
      g_napRutDaTinh = 0.0;
   }
   double moi = napRut - g_napRutDaTinh;
   if(MathAbs(moi) < 1e-9) return;
   if(g_dinhSG > 0.0) g_dinhSG += moi;
   g_napRutDaTinh = napRut;
   GhiSuKien("NAP_RUT", "Nạp/rút " + So2(moi) + " trong ngày; dời đỉnh vốn của cầu dao sụt giảm thành " + So2(g_dinhSG));
   LuuSG();
}

void DongTatCa(const string lyDo);

void DungSutGiam(const double sg)
{
   g_dungSG = true;
   LuuSG();
   string msg = "Cầu dao sụt giảm tổng: Equity giảm " + So2(sg) + "% từ đỉnh " + So2(g_dinhSG) + " (ngưỡng " + So2(InpSutGiamToiDa) +
                "%). Dừng mở lệnh và đóng toàn bộ lệnh của EA. Chỉ mở lại bằng Input đặt lại đỉnh vốn sau khi đã kiểm tra.";
   Print("DH5 ", msg);
   GhiSuKien("DUNG_SUT_GIAM_TONG", msg);
   DongTatCa("SUT_GIAM_TONG");
}

void KhoiTaoSG()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_napRutNgay = -1;
   g_napRutDaTinh = 0.0;
   if(InpDatLaiDinhVon)
   {
      g_dinhSG = eq;
      g_dungSG = false;
      LuuSG();
      GhiSuKien("DAT_LAI_DINH_VON", "Người vận hành đặt lại đỉnh vốn = " + So2(eq) + " và mở cầu dao sụt giảm. Hãy tắt lại Input này.");
      Print("DH5: đã đặt lại đỉnh vốn ", So2(eq), ". Hãy tắt lại Input đặt lại đỉnh vốn.");
      return;
   }
   g_dinhSG = GlobalVariableCheck(TenGVChung("SGDINH")) ? MathMax(eq, GlobalVariableGet(TenGVChung("SGDINH"))) : eq;
   g_dungSG = GlobalVariableCheck(TenGVChung("SGDUNG")) && GlobalVariableGet(TenGVChung("SGDUNG")) > 0.5;
   int homNay = NgayKey((long)TimeCurrent());
   if(GlobalVariableCheck(TenGVChung("SGNRNG")) && (int)GlobalVariableGet(TenGVChung("SGNRNG")) == homNay)
   {
      g_napRutNgay = homNay;
      g_napRutDaTinh = GlobalVariableGet(TenGVChung("SGNRXL"));
   }
   if(g_dungSG)
      GhiSuKien("DUNG_SUT_GIAM_TONG", "Cầu dao sụt giảm đang đóng từ lần chạy trước (đỉnh " + So2(g_dinhSG) + "). Không mở lệnh mới.");
   LuuSG();
}

void DungNgay()
{
   if(g_ngay.dung) return;
   g_ngay.dung = true;
   GlobalVariableSet(TenGVChung("DUNG"), (double)g_ngay.key);
   string msg = "Chạm giới hạn lỗ ngày: lỗ " + So2(g_ngay.lo) + " / giới hạn " + So2(g_ngay.gioiHan) + " (" +
                So2(LoNgayPhanTram()) + "% vốn đầu ngày " + So2(g_ngay.balanceDau) + "). Dừng mở lệnh đến ngày giao dịch sau" +
                (InpDongLenhKhiChamLoNgay ? ", đóng toàn bộ lệnh của EA." : ".");
   Print("DH5 ", msg);
   GhiSuKien("DUNG_LO_NGAY", msg);
   if(InpDongLenhKhiChamLoNgay) DongTatCa("LO_NGAY");
}

void CapNhatNgay(const bool epBuoc)
{
   long now = g_giayHienTai > 0 ? g_giayHienTai : (long)TimeCurrent();
   int key = NgayKey(now);
   bool docLai = epBuoc || g_ngayCanDoc;
   if(key != g_ngay.key)
   {
      g_ngay.key = key;
      g_ngay.loMax = 0.0;
      g_ngay.loiNghiemTrong = 0;
      g_ngay.dung = GlobalVariableCheck(TenGVChung("DUNG")) && (int)GlobalVariableGet(TenGVChung("DUNG")) == key;
      docLai = true;
   }
   if(docLai || now - g_ngayDocGiay >= 5 || now < g_ngayDocGiay)
   {
      DocLichSuNgay();
      g_ngayDocGiay = now;
      g_ngayCanDoc = false;
   }
   double thaNoi = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      thaNoi += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   g_ngay.thaNoiEA = thaNoi;
   double pl = 0.0;
   if(InpPhamViLoNgay == DH5_LO_TOAN_TAI_KHOAN)
      pl = AccountInfoDouble(ACCOUNT_EQUITY) - g_ngay.balanceDau - g_ngay.napRut;
   else
      pl = g_ngay.chotEA + g_ngay.thaNoiEA;
   g_ngay.lo = MathMax(0.0, -pl);
   if(g_ngay.lo > g_ngay.loMax) g_ngay.loMax = g_ngay.lo;
   double von = g_ngay.balanceDau > 0.0 ? g_ngay.balanceDau : g_ngay.balanceDau + g_ngay.napRut;
   g_ngay.gioiHan = MathMax(0.0, von) * LoNgayPhanTram() / 100.0;
   if(!g_ngay.dung && g_ngay.gioiHan > 0.0 && g_ngay.lo >= g_ngay.gioiHan) DungNgay();
}

bool QuaGioDongCuoiNgay()
{
   MqlDateTime d;
   TimeToStruct((datetime)g_giayHienTai, d);
   int p = d.hour * 60 + d.min;
   int mc = InpGioDongHetLenh * 60 + InpPhutDongHetLenh;
   return p >= mc;
}

bool TrongGioVaoLenh()
{
   MqlDateTime d;
   TimeToStruct((datetime)g_giayHienTai, d);
   if(d.day_of_week < 1 || d.day_of_week > 5) return false;
   if(d.hour < InpGioBatDau || d.hour >= InpGioNgungVaoLenh) return false;
   if(InpDongLenhCuoiNgay && QuaGioDongCuoiNgay()) return false;
   return true;
}

// Khối lượng theo rủi ro: lot làm tròn xuống, không bao giờ làm tròn lên lot tối thiểu
double TinhLot(const DH5TinHieu &s, double &tien, string &lyDo)
{
   tien = 0.0;
   double coSo = VonCoSo();
   double ngan = coSo * RuiRoPhanTram() / 100.0;
   g_nganSachLenh = ngan;
   if(ngan <= 0.0) { lyDo = "VON_KHONG_HOP_LE"; return 0.0; }
   ENUM_ORDER_TYPE t = s.huong > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double vaoXau = s.huong > 0 ? s.gia + InpTruotGiaDuPhong : s.gia - InpTruotGiaDuPhong;
   double pl = 0.0;
   if(!OrderCalcProfit(t, _Symbol, 1.0, vaoXau, s.sl, pl)) { lyDo = "KHONG_TINH_DUOC_LAI_LO"; return 0.0; }
   double mat1 = -pl + InpPhiMoiLot;
   if(mat1 <= 0.0) { lyDo = "TIEN_MAT_MOI_LOT_KHONG_HOP_LE"; return 0.0; }
   double buoc = MathFloor(ngan / mat1 / g_lotStep);
   double lot = buoc * g_lotStep;
   if(lot > g_lotMax) lot = MathFloor(g_lotMax / g_lotStep) * g_lotStep;
   lot = NormalizeDouble(lot, g_lotDigits);
   while(lot > 0.0 && lot * mat1 > ngan) lot = NormalizeDouble(lot - g_lotStep, g_lotDigits);
   if(lot < g_lotMin - 1e-9)
   {
      lyDo = "LOT_TOI_THIEU_VUOT_" + So2(RuiRoPhanTram()) + "%";
      return 0.0;
   }
   tien = lot * mat1;
   return lot;
}

bool KiemTraRuiRo(const DH5TinHieu &s, double &lot, double &tien, string &lyDo)
{
   lot = 0.0;
   tien = 0.0;
   if(g_dungSG) { lyDo = "DA_CHAM_SUT_GIAM_TONG"; return false; }
   if(g_ngay.dung) { lyDo = "DA_CHAM_LO_NGAY"; return false; }
   if(g_ngay.loiNghiemTrong >= 5) { lyDo = "KHOA_LOI_SAN_TRONG_NGAY"; return false; }
   if(!TrongGioVaoLenh()) { lyDo = "NGOAI_GIO_GIAO_DICH"; return false; }
   if(g_tamDungDen > g_giayHienTai) { lyDo = "TAM_DUNG_SAU_LOI_SAN"; return false; }
   if(g_cho.dung) { lyDo = "DANG_DOI_CHIEU_LENH"; return false; }
   if(!g_tester && TerminalInfoInteger(TERMINAL_CONNECTED) == 0) { lyDo = "MAT_KET_NOI"; return false; }
   if(g_spread > InpSpreadToiDa) { lyDo = "SPREAD_CAO " + So2(g_spread); return false; }
   if(s.khoangSL <= 0.0 || g_spread > s.khoangSL * InpSpreadToiDaTheoSL / 100.0) { lyDo = "SPREAD_SO_VOI_SL"; return false; }
   if(DemViTheEA(-1) >= SoViTheToiDa()) { lyDo = "DU_SO_VI_THE"; return false; }
   if(DemViTheEA(s.pp) > 0) { lyDo = "PP_DANG_CO_LENH"; return false; }
   lot = TinhLot(s, tien, lyDo);
   if(lot <= 0.0) return false;
   double conLai = RuiRoMoConLai();
   if(g_ngay.gioiHan <= 0.0 || g_ngay.lo + conLai + tien > g_ngay.gioiHan)
   {
      lyDo = "VUOT_NGAN_SACH_LO_NGAY lo=" + So2(g_ngay.lo) + " mo=" + So2(conLai) + " moi=" + So2(tien) + " tran=" + So2(g_ngay.gioiHan);
      return false;
   }
   ENUM_ORDER_TYPE t = s.huong > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double kq = 0.0;
   if(!OrderCalcMargin(t, _Symbol, lot, s.gia, kq) || kq <= 0.0) { lyDo = "KHONG_TINH_DUOC_KY_QUY"; return false; }
   double tuDo = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double daDung = AccountInfoDouble(ACCOUNT_MARGIN);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(kq > tuDo * 0.95) { lyDo = "THIEU_KY_QUY"; return false; }
   double muc = (daDung + kq) > 0.0 ? 100.0 * eq / (daDung + kq) : 1e9;
   if(muc < KyQuyToiThieu()) { lyDo = "MUC_KY_QUY_SAU_VAO_LENH " + DoubleToString(muc, 0) + "%"; return false; }
   return true;
}

//+------------------------------------------------------------------+
//| Thực thi lệnh                                                     |
//+------------------------------------------------------------------+
void ChonFilling()
{
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) != 0) g_filling = ORDER_FILLING_FOK;
   else if((mode & SYMBOL_FILLING_IOC) != 0) g_filling = ORDER_FILLING_IOC;
   else g_filling = ORDER_FILLING_RETURN;
}

int TimTheoDoi(const ulong tk)
{
   for(int i = 0; i < DH5_SO_THEO_DOI; i++)
      if(g_td[i].dung && g_td[i].ticket == tk) return i;
   return -1;
}

int ChoTrongTheoDoi()
{
   for(int i = 0; i < DH5_SO_THEO_DOI; i++)
      if(!g_td[i].dung) return i;
   return -1;
}

bool SuaSLTP(const ulong tk, const double sl, const double tp)
{
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_SLTP;
   req.position = tk;
   req.symbol = _Symbol;
   req.magic = (ulong)InpMagic;
   req.sl = sl;
   req.tp = tp;
   bool ok = OrderSend(req, res);
   return ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL || res.retcode == TRADE_RETCODE_NO_CHANGES);
}

bool DongViThe(const ulong tk, const string lyDo)
{
   if(!PositionSelectByTicket(tk)) return true;
   int k = TimTheoDoi(tk);
   if(k >= 0)
   {
      if(g_td[k].lanDongCuoi > 0 && g_giayHienTai - g_td[k].lanDongCuoi < 10) return false;
      g_td[k].lanDongCuoi = g_giayHienTai;
      g_td[k].lyDoDong = lyDo;
   }
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   bool mua = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   req.action = TRADE_ACTION_DEAL;
   req.position = tk;
   req.symbol = _Symbol;
   req.magic = (ulong)InpMagic;
   req.volume = PositionGetDouble(POSITION_VOLUME);
   req.type = mua ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price = mua ? g_bid : g_ask;
   req.deviation = DoLechDiem();
   req.type_filling = g_filling;
   req.comment = StringSubstr("DH5|DONG|" + lyDo, 0, 31);
   bool ok = OrderSend(req, res);
   if(!ok || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL))
   {
      GhiSuKien("LOI_DONG_LENH", "ticket " + IntegerToString((long)tk) + " lý do " + lyDo + " retcode " + IntegerToString((long)res.retcode));
      return false;
   }
   GhiSuKien("DONG_LENH", "ticket " + IntegerToString((long)tk) + " lý do " + lyDo);
   g_ngayCanDoc = true;
   return true;
}

void DongTatCa(const string lyDo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      DongViThe(tk, lyDo);
   }
}

void GhiLenh(const string suKien, const DH5LenhThuc &r, const double ketQua, const double R, const string lyDo, const string ghiChu)
{
   KiemTraThangLog();
   if(g_hLenh == INVALID_HANDLE) return;
   double r0 = r.r0 > 0.0 ? r.r0 : 1.0;
   double phut = (double)(g_giayHienTai - r.moT) / 60.0;
   GhiDong(g_hLenh, ThoiGianChuoi(g_giayHienTai) + ";" + suKien + ";" + IntegerToString((long)r.ticket) + ";" + IntegerToString(r.id) + ";" +
           MaPP(r.pp) + ";" + (r.huong > 0 ? "BUY" : "SELL") + ";" + MaTrangThai(r.trangThai) + ";" + TenPhien(r.phien) + ";" +
           DoubleToString(r.diem, 1) + ";" + DoubleToString(r.lot, g_lotDigits) + ";" + SoGia(r.giaYeuCau) + ";" + SoGia(r.giaKhop) + ";" +
           SoGia(r.huong * (r.giaKhop - r.giaYeuCau)) + ";" + SoGia(r.sl0) + ";" + SoGia(r.tp0) + ";" + So2(r.tienRuiRo) + ";" +
           So2(ketQua) + ";" + So4(R) + ";" + lyDo + ";" + So4(r.tot / r0) + ";" + So4(r.xau / r0) + ";" + DoubleToString(phut, 1) + ";" +
           LamSach(ghiChu));
}

// Sau khi khớp: kiểm tra SL/TP và rủi ro thực tế, lưu trạng thái để khôi phục
bool SauKhop(const ulong tk, const DH5TinHieu &s, const double tienDuKien, const double giaYeuCau, string &lyDo)
{
   if(!PositionSelectByTicket(tk)) { lyDo = "VI_THE_DA_DONG_NGAY_SAU_KHOP"; return false; }
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double vol = PositionGetDouble(POSITION_VOLUME);
   long pid = PositionGetInteger(POSITION_IDENTIFIER);
   long moT = PositionGetInteger(POSITION_TIME);
   bool mua = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   if(sl <= 0.0 || tp <= 0.0)
   {
      if(!SuaSLTP(tk, s.sl, s.tp))
      {
         DongViThe(tk, "THIEU_SL_TP");
         lyDo = "THIEU_SL_TP_DA_DONG";
         GhiSuKien("THIEU_SL_TP", "Vị thế " + IntegerToString((long)tk) + " khớp thiếu SL/TP và không đặt lại được; đã đóng.");
         return false;
      }
      sl = s.sl;
      tp = s.tp;
   }
   double pl = 0.0;
   OrderCalcProfit(mua ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, open, sl, pl);
   double ruiRoThuc = -pl + InpPhiMoiLot * vol;
   if(ruiRoThuc > g_nganSachLenh * 1.05)
   {
      DongViThe(tk, "TRUOT_GIA_VUOT_RR");
      lyDo = "TRUOT_GIA_LAM_RUI_RO_VUOT_" + So2(RuiRoPhanTram()) + "%";
      GhiSuKien("VUOT_RUI_RO_SAU_KHOP", "Vị thế " + IntegerToString((long)tk) + " khớp " + SoGia(open) + " (yêu cầu " + SoGia(giaYeuCau) +
                "), rủi ro thực " + So2(ruiRoThuc) + " > ngân sách " + So2(g_nganSachLenh) + "; đã đóng.");
      return false;
   }
   int k = ChoTrongTheoDoi();
   if(k < 0) k = 0;
   ZeroMemory(g_td[k]);
   g_td[k].dung = true;
   g_td[k].ticket = tk;
   g_td[k].posId = pid;
   g_td[k].id = s.id;
   g_td[k].pp = s.pp;
   g_td[k].huong = s.huong;
   g_td[k].phien = s.phien;
   g_td[k].trangThai = s.trangThai;
   g_td[k].diem = s.diem;
   g_td[k].giaYeuCau = giaYeuCau;
   g_td[k].giaKhop = open;
   g_td[k].sl0 = sl;
   g_td[k].tp0 = tp;
   g_td[k].lot = vol;
   g_td[k].tienRuiRo = ruiRoThuc > 0.0 ? ruiRoThuc : tienDuKien;
   g_td[k].r0 = MathAbs(open - sl);
   g_td[k].moT = moT > 0 ? moT : g_giayHienTai;
   GlobalVariableSet(TenGV("R", (long)tk), g_td[k].r0);
   GlobalVariableSet(TenGV("M", (long)tk), g_td[k].tienRuiRo);
   GlobalVariableSet(TenGV("B", (long)tk), 0.0);
   GlobalVariableSet(TenGV("S", (long)tk), (double)(s.trangThai * 10 + s.phien));
   GhiLenh("MO", g_td[k], 0.0, 0.0, "", s.moTa);
   g_soVaoLenh++;
   g_ngayCanDoc = true;
   return true;
}

ulong TimViTheSauKhop(const MqlTradeResult &res)
{
   if(res.order > 0 && PositionSelectByTicket(res.order)) return res.order;
   if(res.deal > 0 && HistoryDealSelect(res.deal))
   {
      long pid = HistoryDealGetInteger(res.deal, DEAL_POSITION_ID);
      if(pid > 0 && PositionSelectByTicket((ulong)pid)) return (ulong)pid;
   }
   return 0;
}

void BatDauDoiChieu(const DH5TinHieu &s, const string cmt, const double tien, const double giaYeuCau, const string why)
{
   g_cho.dung = true;
   g_cho.cmt = cmt;
   g_cho.guiT = g_giayHienTai;
   g_cho.tien = tien;
   g_cho.giaYeuCau = giaYeuCau;
   g_cho.s = s;
   GhiSuKien("DOI_CHIEU_BAT_DAU", cmt + " | " + why + " | tạm dừng lệnh mới tới khi biết kết quả");
}

// Lệnh chưa rõ kết quả: tìm vị thế/deal theo comment trước khi nhận tín hiệu mới
void DoiChieu()
{
   if(!g_cho.dung) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      if(PositionGetString(POSITION_COMMENT) != g_cho.cmt || TimTheoDoi(tk) >= 0) continue;
      string lyDo = "";
      g_cho.dung = false;
      bool ok = SauKhop(tk, g_cho.s, g_cho.tien, g_cho.giaYeuCau, lyDo);
      GhiSuKien("DOI_CHIEU_KET_THUC", g_cho.cmt + (ok ? " | đã tìm thấy vị thế và đưa vào quản lý" : " | " + lyDo));
      return;
   }
   if(HistorySelect((datetime)(g_cho.guiT - 120), (datetime)(g_giayHienTai + 60)))
   {
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
         if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         if(HistoryDealGetString(d, DEAL_COMMENT) != g_cho.cmt) continue;
         g_cho.dung = false;
         GhiSuKien("DOI_CHIEU_KET_THUC", g_cho.cmt + " | deal vào lệnh đã có nhưng vị thế đã đóng; không mở lại");
         return;
      }
   }
   if(g_giayHienTai - g_cho.guiT >= DH5_DOI_CHIEU_GIAY)
   {
      g_cho.dung = false;
      GhiSuKien("DOI_CHIEU_KET_THUC", g_cho.cmt + " | không có vị thế/deal sau " + IntegerToString(DH5_DOI_CHIEU_GIAY) + " giây; bỏ tín hiệu");
   }
}

void XuLyLoiMoLenh(const uint rc, const DH5TinHieu &s, const string cmt, const double tien, const double giaYeuCau, string &lyDo)
{
   lyDo = "LOI_SAN_" + IntegerToString((long)rc);
   if(rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF)
   {
      GhiSuKien("LOI_TAM_THOI", cmt + " retcode " + IntegerToString((long)rc) + "; bỏ tín hiệu, không gửi lại");
      return;
   }
   if(rc == TRADE_RETCODE_MARKET_CLOSED)
   {
      g_tamDungDen = g_giayHienTai + 300;
      GhiSuKien("THI_TRUONG_DONG", cmt + "; tạm dừng mở lệnh 5 phút");
      return;
   }
   if(rc == 0 || rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_PLACED)
   {
      BatDauDoiChieu(s, cmt, tien, giaYeuCau, "kết quả gửi lệnh chưa rõ, retcode " + IntegerToString((long)rc));
      return;
   }
   g_ngay.loiNghiemTrong++;
   g_tamDungDen = g_giayHienTai + 900;
   string msg = cmt + " retcode " + IntegerToString((long)rc) + "; tạm dừng mở lệnh 15 phút (lỗi thứ " + IntegerToString(g_ngay.loiNghiemTrong) +
                " trong ngày" + (g_ngay.loiNghiemTrong >= 5 ? ", khóa mở lệnh đến ngày sau)" : ")");
   Print("DH5 ", msg);
   GhiSuKien("LOI_SAN_NGHIEM_TRONG", msg);
}

bool VaoLenh(const DH5TinHieu &s, const double lot, const double tien, string &lyDo)
{
   string cmt = "DH5|" + IntegerToString(s.pp + 1) + "|" + IntegerToString(s.id);
   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.magic = (ulong)InpMagic;
   req.volume = lot;
   req.type = s.huong > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = s.huong > 0 ? g_ask : g_bid;
   req.sl = s.sl;
   req.tp = s.tp;
   req.deviation = DoLechDiem();
   req.type_filling = g_filling;
   req.comment = cmt;
   bool ok = OrderSend(req, res);
   uint rc = res.retcode;
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
   {
      ulong tk = TimViTheSauKhop(res);
      if(tk == 0)
      {
         BatDauDoiChieu(s, cmt, tien, req.price, "sàn báo khớp nhưng chưa thấy vị thế");
         lyDo = "CHO_DOI_CHIEU";
         return false;
      }
      return SauKhop(tk, s, tien, req.price, lyDo);
   }
   XuLyLoiMoLenh(rc, s, cmt, tien, req.price, lyDo);
   return false;
}

//+------------------------------------------------------------------+
//| Quản lý vị thế thật                                               |
//+------------------------------------------------------------------+
void CongThongKe(DH5ThongKe &t, const double net, const double R)
{
   t.n++;
   t.net += net;
   t.tongR += R;
   if(net > 0.0)
   {
      t.thang++;
      t.loiGop += net;
      t.chuoiThua = 0;
   }
   else
   {
      t.thua++;
      t.loGop -= net;
      t.chuoiThua++;
      if(t.chuoiThua > t.chuoiThuaMax) t.chuoiThuaMax = t.chuoiThua;
   }
   if(t.n == 1 || R < t.rXauNhat) t.rXauNhat = R;
   if(R < -1.10) t.vuotRuiRo++;
}

void KetThucLenh(const int k)
{
   ulong tk = g_td[k].ticket;
   double net = 0.0, giaDong = 0.0;
   long lyDoSan = -1;
   long pid = g_td[k].posId > 0 ? g_td[k].posId : (long)tk;
   if(HistorySelectByPosition(pid))
   {
      int n = HistoryDealsTotal();
      for(int i = 0; i < n; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         net += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
                HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_FEE);
         long en = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
         {
            giaDong = HistoryDealGetDouble(d, DEAL_PRICE);
            lyDoSan = HistoryDealGetInteger(d, DEAL_REASON);
         }
      }
   }
   string lyDo = g_td[k].lyDoDong;
   if(lyDoSan == DEAL_REASON_SL) lyDo = g_td[k].hoaVon ? "SL_SAU_HOA_VON" : "SL";
   else if(lyDoSan == DEAL_REASON_TP) lyDo = "TP";
   else if(lyDoSan == DEAL_REASON_SO) lyDo = "STOP_OUT";
   else if(lyDo == "") lyDo = "DONG_NGOAI_EA";
   double R = g_td[k].tienRuiRo > 0.0 ? net / g_td[k].tienRuiRo : 0.0;
   string ghiChu = "gia_dong=" + SoGia(giaDong);
   if(lyDo == "SL" && giaDong > 0.0)
   {
      double truot = g_td[k].huong > 0 ? g_td[k].sl0 - giaDong : giaDong - g_td[k].sl0;
      ghiChu += " truot_tai_SL=" + SoGia(truot);
   }
   GhiLenh("DONG", g_td[k], net, R, lyDo, ghiChu);
   if(R < -1.10)
   {
      string msg = "Vị thế " + IntegerToString((long)tk) + " lỗ " + So2(R) + "R (" + So2(net) + "), vượt rủi ro dự kiến do gap/trượt giá.";
      Print("DH5 ", msg);
      GhiSuKien("VUOT_RUI_RO_DU_KIEN", msg);
   }
   CongThongKe(g_tkTong, net, R);
   CongThongKe(g_tkPP[g_td[k].pp], net, R);
   CongThongKe(g_tkPhien[g_td[k].phien], net, R);
   CongThongKe(g_tkHuong[g_td[k].huong > 0 ? 0 : 1], net, R);
   if(g_td[k].trangThai >= 0 && g_td[k].trangThai < 7) CongThongKe(g_tkTT[g_td[k].trangThai], net, R);
   GlobalVariableDel(TenGV("R", (long)tk));
   GlobalVariableDel(TenGV("M", (long)tk));
   GlobalVariableDel(TenGV("B", (long)tk));
   GlobalVariableDel(TenGV("S", (long)tk));
   g_td[k].dung = false;
   g_ngayCanDoc = true;
}

void QuanLyViThe()
{
   bool cuoiNgay = InpDongLenhCuoiNgay && QuaGioDongCuoiNgay();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      if(cuoiNgay) { DongViThe(tk, "CUOI_NGAY"); continue; }
      if(g_dungSG) { DongViThe(tk, "SUT_GIAM_TONG"); continue; }
      if(g_ngay.dung && InpDongLenhKhiChamLoNgay) { DongViThe(tk, "LO_NGAY"); continue; }
      if(!PositionSelectByTicket(tk)) continue;
      bool mua = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long moT = PositionGetInteger(POSITION_TIME);
      int k = TimTheoDoi(tk);
      double r0 = k >= 0 ? g_td[k].r0 : (GlobalVariableCheck(TenGV("R", (long)tk)) ? GlobalVariableGet(TenGV("R", (long)tk)) : 0.0);
      if(r0 <= 0.0 && tp > 0.0) r0 = MathAbs(tp - open) / MathMax(0.1, InpTyLeRR);
      if(r0 <= 0.0) continue;
      double loi = mua ? g_bid - open : open - g_ask;
      if(k >= 0)
      {
         if(loi > g_td[k].tot) g_td[k].tot = loi;
         if(loi < g_td[k].xau) g_td[k].xau = loi;
      }
      if(InpGiuLenhToiDaPhut > 0 && moT > 0 && g_giayHienTai - moT >= (long)InpGiuLenhToiDaPhut * 60)
      {
         DongViThe(tk, "HET_GIO");
         continue;
      }
      double moi = sl;
      bool daHoaVon = k >= 0 ? g_td[k].hoaVon : (GlobalVariableCheck(TenGV("B", (long)tk)) && GlobalVariableGet(TenGV("B", (long)tk)) > 0.5);
      bool hoaVonMoi = false;
      if(InpHoaVonTaiR > 0.0 && !daHoaVon && loi >= InpHoaVonTaiR * r0)
      {
         double be = open + (mua ? 2.0 : -2.0) * g_point;
         if(mua ? be > moi : (moi <= 0.0 || be < moi)) moi = be;
         hoaVonMoi = true;
      }
      if(InpTrailingTuR > 0.0 && loi >= InpTrailingTuR * r0)
      {
         double tr = mua ? g_bid - InpTrailingKhoangR * r0 : g_ask + InpTrailingKhoangR * r0;
         if(mua ? tr > moi : (moi <= 0.0 || tr < moi)) moi = tr;
      }
      moi = ChuanGia(moi);
      double buoc = MathMax(0.1 * r0, 10.0 * g_point);
      bool tot = false;
      if(mua) tot = (moi > sl + buoc) || (hoaVonMoi && moi > sl);
      else tot = (sl <= 0.0) || (moi < sl - buoc) || (hoaVonMoi && moi < sl);
      if(!tot) continue;
      long lv = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      long fz = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      if(fz > lv) lv = fz;
      double an = (double)(lv + 1) * g_point;
      if(mua ? moi >= g_bid - an : moi <= g_ask + an) continue;
      if(SuaSLTP(tk, moi, tp))
      {
         if(hoaVonMoi)
         {
            if(k >= 0) g_td[k].hoaVon = true;
            GlobalVariableSet(TenGV("B", (long)tk), 1.0);
         }
      }
   }
   for(int k = 0; k < DH5_SO_THEO_DOI; k++)
   {
      if(!g_td[k].dung) continue;
      if(PositionSelectByTicket(g_td[k].ticket)) continue;
      KetThucLenh(k);
   }
}

// Khôi phục vị thế của EA sau khởi động lại MT5 / gắn lại EA / đổi khung
void KhoiPhucViThe()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !LaViTheEA()) continue;
      if(TimTheoDoi(tk) >= 0) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      int pp = PPTuComment(cmt);
      bool mua = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double r0 = GlobalVariableCheck(TenGV("R", (long)tk)) ? GlobalVariableGet(TenGV("R", (long)tk)) : 0.0;
      if(r0 <= 0.0 && sl > 0.0 && MathAbs(open - sl) > 10.0 * g_point) r0 = MathAbs(open - sl);
      if(r0 <= 0.0 && tp > 0.0) r0 = MathAbs(tp - open) / MathMax(0.1, InpTyLeRR);
      if(r0 <= 0.0) r0 = InpSLToiDa;
      if(sl <= 0.0 || tp <= 0.0)
      {
         // Vị thế thiếu bảo vệ: đặt lại SL/TP theo R đã lưu; không được thì đóng
         double slMoi = sl > 0.0 ? sl : ChuanGia(mua ? open - r0 : open + r0);
         double tpMoi = tp > 0.0 ? tp : ChuanGia(mua ? open + InpTyLeRR * r0 : open - InpTyLeRR * r0);
         if(!SuaSLTP(tk, slMoi, tpMoi))
         {
            GhiSuKien("KHOI_PHUC", "Vị thế " + IntegerToString((long)tk) + " thiếu SL/TP, không đặt lại được; đóng để bảo vệ vốn");
            DongViThe(tk, "KHOI_PHUC_THIEU_SL");
            continue;
         }
         sl = slMoi;
         tp = tpMoi;
      }
      int k = ChoTrongTheoDoi();
      if(k < 0) break;
      ZeroMemory(g_td[k]);
      g_td[k].dung = true;
      g_td[k].ticket = tk;
      g_td[k].posId = PositionGetInteger(POSITION_IDENTIFIER);
      g_td[k].pp = pp >= 0 ? pp : 0;
      g_td[k].huong = mua ? 1 : -1;
      double s = GlobalVariableCheck(TenGV("S", (long)tk)) ? GlobalVariableGet(TenGV("S", (long)tk)) : 0.0;
      g_td[k].trangThai = (int)(s / 10.0);
      g_td[k].phien = (int)MathRound(s - 10.0 * g_td[k].trangThai);
      if(g_td[k].phien < 0 || g_td[k].phien > 2) g_td[k].phien = PhienCua((long)PositionGetInteger(POSITION_TIME));
      if(g_td[k].trangThai < 0 || g_td[k].trangThai > 6) g_td[k].trangThai = TT_KHOI_DONG;
      g_td[k].giaYeuCau = open;
      g_td[k].giaKhop = open;
      g_td[k].sl0 = mua ? open - r0 : open + r0;
      g_td[k].tp0 = tp;
      g_td[k].lot = vol;
      double pl = 0.0;
      OrderCalcProfit(mua ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, vol, open, g_td[k].sl0, pl);
      g_td[k].tienRuiRo = GlobalVariableCheck(TenGV("M", (long)tk)) ? GlobalVariableGet(TenGV("M", (long)tk)) : -pl + InpPhiMoiLot * vol;
      g_td[k].r0 = r0;
      g_td[k].moT = PositionGetInteger(POSITION_TIME);
      g_td[k].hoaVon = GlobalVariableCheck(TenGV("B", (long)tk)) && GlobalVariableGet(TenGV("B", (long)tk)) > 0.5;
      GlobalVariableSet(TenGV("R", (long)tk), r0);
      GlobalVariableSet(TenGV("M", (long)tk), g_td[k].tienRuiRo);
      GhiSuKien("KHOI_PHUC", "Đã nhận lại vị thế " + IntegerToString((long)tk) + " " + cmt + " | R0 " + So2(r0) + " | rủi ro " + So2(g_td[k].tienRuiRo) +
                (g_td[k].hoaVon ? " | đã hòa vốn" : ""));
   }
}

//+------------------------------------------------------------------+
//| Quy trình quyết định                                              |
//+------------------------------------------------------------------+
bool OBiTat(const DH5TinHieu &s)
{
   int o = ChiSoO(s.pp, s.huong, s.phien);
   return g_hocTat[o];
}

void GhiTinHieu(const DH5TinHieu &s, const string quyetDinh, const string lyDo, const double lot, const double tien)
{
   g_tinHieuCuoi = ThoiGianChuoi(s.thoiGian) + " " + MaPP(s.pp) + " " + (s.huong > 0 ? "BUY" : "SELL") + " điểm " + DoubleToString(s.diem, 0) +
                   " -> " + quyetDinh + (lyDo != "" ? " (" + lyDo + ")" : "");
   if(!InpGhiTinHieu) return;
   KiemTraThangLog();
   if(g_hTH == INVALID_HANDLE) return;
   GhiDong(g_hTH, ThoiGianChuoi(s.thoiGian) + ";" + IntegerToString(s.id) + ";" + MaPP(s.pp) + ";" + (s.huong > 0 ? "BUY" : "SELL") + ";" +
           MaTrangThai(s.trangThai) + ";" + TenPhien(s.phien) + ";" + DoubleToString(s.diem, 1) + ";" +
           So4(s.q[0]) + ";" + So4(s.q[1]) + ";" + So4(s.q[2]) + ";" + So4(s.q[3]) + ";" + So4(s.q[4]) + ";" + So4(s.q[5]) + ";" +
           So4(s.xacSuat) + ";" + SoGia(s.gia) + ";" + SoGia(s.sl) + ";" + SoGia(s.tp) + ";" + So2(s.khoangSL) + ";" + SoGia(g_spread) + ";" +
           So2(g_atrM5) + ";" + So4(g_erM5) + ";" + So4(g_docH1) + ";" + So4(g_v5) + ";" + So4(g_v30) + ";" + So4(g_a30) + ";" +
           So2(g_cuongDo) + ";" + So2(g_tyLeBD) + ";" + quyetDinh + ";" + LamSach(lyDo) + ";" + DoubleToString(lot, g_lotDigits) + ";" +
           So2(tien) + ";" + LamSach(s.moTa));
}

void XuLyMotTinHieu(DH5TinHieu &s, const string lyDoMucGia)
{
   g_tinHieuId++;
   g_soTinHieu++;
   s.id = g_tinHieuId;
   GlobalVariableSet(TenGVChung("ID"), (double)g_tinHieuId);   // mã tín hiệu không lặp lại sau khi khởi động lại
   if(lyDoMucGia != "" || s.khoangSL <= 0.0)
   {
      GhiTinHieu(s, "BO_QUA", lyDoMucGia != "" ? lyDoMucGia : "KHONG_DAT_MUC_GIA", 0.0, 0.0);
      return;
   }
   TinhDiem(s);
   if(InpDungMoHinh)
   {
      DacTrungTuTinHieu(s);
      s.xacSuat = MoHinhDuDoan();
   }
   int ao = TaoLenhAo(s);
   string lyDo = "";
   bool vao = true;
   if(s.diem < InpDiemToiThieu) { vao = false; lyDo = "DIEM_THAP"; }
   else if(InpDungHocThichNghi && OBiTat(s)) { vao = false; lyDo = "HOC_THICH_NGHI_TAT_O"; }
   else if(InpDungMoHinh && g_moHinhN >= InpMoHinhSoMau && s.xacSuat < InpMoHinhXacSuat) { vao = false; lyDo = "MO_HINH_PHU_QUYET"; }
   double lot = 0.0, tien = 0.0;
   if(vao && !KiemTraRuiRo(s, lot, tien, lyDo)) vao = false;
   if(vao && !g_choPhepLenh) { vao = false; lyDo = g_lyDoKhongGuiLenh; }
   string quyetDinh = "BO_QUA";
   if(vao)
   {
      if(VaoLenh(s, lot, tien, lyDo)) quyetDinh = "VAO_LENH";
      else vao = false;
   }
   if(ao >= 0) g_ao[ao].thuc = vao;
   GhiTinHieu(s, quyetDinh, lyDo, lot, tien);
}

void XuLyTinHieu()
{
   PP3_TheoDoiQuet();
   if(!g_duLieuDu || !g_ctxCo) return;
   if(g_trangThai == TT_KHOI_DONG || g_trangThai == TT_SOC || g_trangThai == TT_YEU) return;
   if(!TrongGioVaoLenh()) return;
   DH5TinHieu s;
   string lyDo = "";
   if(InpDungPP1 && PP1_KichHoat(s, lyDo)) XuLyMotTinHieu(s, lyDo);
   lyDo = "";
   if(InpDungPP2 && PP2_KichHoat(s, lyDo)) XuLyMotTinHieu(s, lyDo);
   lyDo = "";
   if(InpDungPP3 && PP3_KichHoat(s, lyDo)) XuLyMotTinHieu(s, lyDo);
}

//+------------------------------------------------------------------+
//| Theo dõi sụt giảm, bảng trạng thái, kết quả kiểm thử              |
//+------------------------------------------------------------------+
void TheoDoiSutGiam()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_dinhVon) g_dinhVon = eq;
   double dd = g_dinhVon - eq;
   if(dd > g_ddMax) g_ddMax = dd;
   if(g_dinhVon > 0.0 && 100.0 * dd / g_dinhVon > g_ddMaxPct) g_ddMaxPct = 100.0 * dd / g_dinhVon;
   if(InpSutGiamToiDa <= 0.0) return;
   if(eq > g_dinhSG)
   {
      g_dinhSG = eq;
      GlobalVariableSet(TenGVChung("SGDINH"), g_dinhSG);
   }
   double sg = g_dinhSG > 0.0 ? 100.0 * (g_dinhSG - eq) / g_dinhSG : 0.0;
   if(!g_dungSG && sg >= InpSutGiamToiDa) DungSutGiam(sg);
}

string DongHoc(const int pp)
{
   string s = "";
   for(int h = 0; h < 2; h++)
      for(int p = 0; p < 3; p++)
      {
         int o = pp * 6 + h * 3 + p;
         if(g_hocN[o] == 0) continue;
         s += (h == 0 ? "B" : "S") + TenPhien(p) + ":" + So2(g_hocR[o]) + "R/" + IntegerToString(g_hocN[o]) + (g_hocTat[o] ? "(tắt) " : " ");
      }
   return s == "" ? "chưa có lệnh ảo" : s;
}

void VeBang()
{
   if(!InpHienBang || !g_hienThi) return;
   ulong ms = GetTickCount64();
   if(ms - g_bangLuc < 1000) return;
   g_bangLuc = ms;
   string cheDo = g_choPhepLenh ? "GIAO DỊCH" : "CHỈ PHÂN TÍCH (" + g_lyDoKhongGuiLenh + ")";
   string trangThaiNgay = g_dungSG ? "ĐÃ DỪNG (cầu dao sụt giảm tổng)" : (g_ngay.dung ? "ĐÃ DỪNG (chạm giới hạn lỗ ngày)" : "đang hoạt động");
   double sgNay = g_dinhSG > 0.0 ? 100.0 * (g_dinhSG - AccountInfoDouble(ACCOUNT_EQUITY)) / g_dinhSG : 0.0;
   string t = "DAVID HUNTER V" + DH5_PHIEN_BAN + " TICK AI TEST | " + _Symbol + " | Magic " + IntegerToString(InpMagic) + "\n";
   t += "Chế độ: " + cheDo + "\n";
   t += "Trạng thái thị trường: " + TenTrangThai(g_trangThai) + " | ER M5 " + So2(g_erM5) + " | dốc H1 " + So2(g_docH1) + " | ATR M5 " + So2(g_atrM5) + "\n";
   t += "Tick: " + DoubleToString(g_tickGiay, 1) + " tick/giây | cường độ " + So2(g_cuongDo) + " | tốc độ 30s " + So4(g_v30) + " | gia tốc " + So4(g_a30) +
        " | spread " + SoGia(g_spread) + (g_soc ? " | SỐC GIÁ" : "") + "\n";
   t += "Rủi ro: " + So2(RuiRoPhanTram()) + "%/vị thế | lỗ ngày " + So2(g_ngay.lo) + " / " + So2(g_ngay.gioiHan) + " (" + So2(LoNgayPhanTram()) + "%) | " +
        trangThaiNgay + "\n";
   t += "Sụt giảm từ đỉnh vốn: " + So2(sgNay) + "% / cầu dao " + (InpSutGiamToiDa > 0.0 ? So2(InpSutGiamToiDa) + "%" : "tắt") + " | đỉnh " + So2(g_dinhSG) + "\n";
   t += "Vị thế EA: " + IntegerToString(DemViTheEA(-1)) + " / " + IntegerToString(SoViTheToiDa()) + " | rủi ro mở còn lại " + So2(RuiRoMoConLai()) +
        " | tín hiệu " + IntegerToString(g_soTinHieu) + " | đã vào " + IntegerToString(g_soVaoLenh) + "\n";
   t += "Học PP1: " + DongHoc(0) + "\n";
   t += "Học PP2: " + DongHoc(1) + "\n";
   t += "Học PP3: " + DongHoc(2) + "\n";
   t += "Mô hình xác suất: " + IntegerToString(g_moHinhN) + " mẫu" + (g_moHinhN >= InpMoHinhSoMau ? " (đang phủ quyết)" : " (chưa đủ mẫu)") + "\n";
   t += "Tín hiệu gần nhất: " + (g_tinHieuCuoi == "" ? "chưa có" : g_tinHieuCuoi);
   Comment(t);
}

void GhiDongKetQua(const int h, const string nhom, const DH5ThongKe &t)
{
   double wr = t.n > 0 ? 100.0 * t.thang / t.n : 0.0;
   double pf = t.loGop > 0.0 ? t.loiGop / t.loGop : (t.loiGop > 0.0 ? 999.0 : 0.0);
   double kv = t.n > 0 ? t.net / t.n : 0.0;
   double kvR = t.n > 0 ? t.tongR / t.n : 0.0;
   double tbThang = t.thang > 0 ? t.loiGop / t.thang : 0.0;
   double tbThua = t.thua > 0 ? t.loGop / t.thua : 0.0;
   FileWriteString(h, nhom + ";" + IntegerToString(t.n) + ";" + So2(wr) + ";" + So2(pf) + ";" + So2(t.net) + ";" + So4(kv) + ";" + So4(kvR) + ";" +
                   So2(tbThang) + ";" + So2(tbThua) + ";" + IntegerToString(t.chuoiThuaMax) + ";" + So4(t.rXauNhat) + ";" + IntegerToString(t.vuotRuiRo) + "\r\n");
}

void XuatKetQua()
{
   string path = DH5_THU_MUC + "\\DH5_" + IntegerToString(InpMagic) + "_ket_qua_" + TimeToString((datetime)g_tgBatDau, TIME_DATE) + "_" +
                 TimeToString((datetime)g_giayHienTai, TIME_DATE) + ".csv";
   StringReplace(path, ".", "_");
   StringReplace(path, "_csv", ".csv");
   int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   double net = g_tkTong.net;
   double rf = g_ddMax > 0.0 ? net / g_ddMax : 0.0;
   if(h != INVALID_HANDLE)
   {
      FileWriteString(h, "chi_so;gia_tri\r\n");
      FileWriteString(h, "phien_ban;" + DH5_PHIEN_BAN + "\r\n");
      FileWriteString(h, "symbol;" + _Symbol + "\r\n");
      FileWriteString(h, "tu;" + ThoiGianChuoi(g_tgBatDau) + "\r\n");
      FileWriteString(h, "den;" + ThoiGianChuoi(g_giayHienTai) + "\r\n");
      FileWriteString(h, "von_ban_dau;" + So2(g_vonBanDau) + "\r\n");
      FileWriteString(h, "net_profit;" + So2(net) + "\r\n");
      FileWriteString(h, "max_dd_tien;" + So2(g_ddMax) + "\r\n");
      FileWriteString(h, "max_dd_phan_tram;" + So2(g_ddMaxPct) + "\r\n");
      FileWriteString(h, "recovery_factor;" + So2(rf) + "\r\n");
      FileWriteString(h, "so_tin_hieu;" + IntegerToString(g_soTinHieu) + "\r\n");
      string sgDong = g_dungSG ? "1" : "0";
      FileWriteString(h, "cau_dao_sut_giam_da_dong;" + sgDong + "\r\n");
      FileWriteString(h, "so_lenh_ao_bo_qua_do_day_bo_nho;" + IntegerToString(g_aoBoQua) + "\r\n");
      FileWriteString(h, "\r\nnhom;so_lenh;win_rate_pct;profit_factor;net;ky_vong_tien;ky_vong_R;tb_lenh_thang;tb_lenh_thua;chuoi_thua_max;R_xau_nhat;so_lenh_lo_vuot_1_1R\r\n");
      GhiDongKetQua(h, "TONG", g_tkTong);
      for(int i = 0; i < 3; i++) GhiDongKetQua(h, MaPP(i), g_tkPP[i]);
      for(int i = 0; i < 3; i++) GhiDongKetQua(h, "PHIEN_" + TenPhien(i), g_tkPhien[i]);
      GhiDongKetQua(h, "BUY", g_tkHuong[0]);
      GhiDongKetQua(h, "SELL", g_tkHuong[1]);
      for(int i = 0; i < 7; i++) if(g_tkTT[i].n > 0) GhiDongKetQua(h, "TT_" + MaTrangThai(i), g_tkTT[i]);
      FileWriteString(h, "\r\no_hoc;so_lenh_ao;ky_vong_R;ty_le_thang;dang_tat\r\n");
      for(int o = 0; o < DH5_SO_O; o++)
         FileWriteString(h, MaPP(o / 6) + "_" + ((o % 6) < 3 ? "BUY" : "SELL") + "_" + TenPhien(o % 3) + ";" + IntegerToString(g_hocN[o]) + ";" +
                         So4(g_hocR[o]) + ";" + So4(g_hocW[o]) + ";" + (g_hocTat[o] ? "1" : "0") + "\r\n");
      FileClose(h);
   }
   double pf = g_tkTong.loGop > 0.0 ? g_tkTong.loiGop / g_tkTong.loGop : 0.0;
   Print("DH5 KẾT QUẢ | lệnh ", g_tkTong.n, " | net ", So2(net), " | WR ", So2(g_tkTong.n > 0 ? 100.0 * g_tkTong.thang / g_tkTong.n : 0.0),
         "% | PF ", So2(pf), " | kỳ vọng ", So4(g_tkTong.n > 0 ? g_tkTong.tongR / g_tkTong.n : 0.0), "R | max DD ", So2(g_ddMaxPct),
         "% | chuỗi thua ", g_tkTong.chuoiThuaMax, " | lỗ vượt 1,1R ", g_tkTong.vuotRuiRo, " | tín hiệu ", g_soTinHieu);
}

//+------------------------------------------------------------------+
//| Khởi tạo, sự kiện                                                 |
//+------------------------------------------------------------------+
void DatLaiThongKe(DH5ThongKe &t)
{
   ZeroMemory(t);
}

// Trong MQL5, đổi khung/symbol không nạp lại biến toàn cục: phải tự đặt lại mọi trạng thái chạy
void DatLaiTrangThai()
{
   g_sanSang = false;
   g_bHead = -1;
   g_bCount = 0;
   g_mHead = -1;
   g_mCount = 0;
   g_sD2All = 0.0;
   g_sD2_60 = 0.0;
   g_sN60 = 0;
   g_sN1800 = 0;
   g_demTinhLai = 0;
   g_bid = 0.0;
   g_ask = 0.0;
   g_mid = 0.0;
   g_spread = 0.0;
   g_sprTB = 0.0;
   g_giayHienTai = 0;
   g_batDauLienTuc = 0;
   g_rv1 = 0.0;
   g_rvPhut = 0.0;
   g_rvPhutTB = 0.0;
   g_tyLeBD = 1.0;
   g_cuongDo = 1.0;
   g_tickGiay = 0.0;
   g_er15 = 0.0;
   g_microHi = 0.0;
   g_microLo = 0.0;
   g_v5 = 0.0;
   g_v30 = 0.0;
   g_a30 = 0.0;
   g_soc = false;
   g_socDen = 0;
   g_spreadDotBien = false;
   g_duLieuDu = false;
   g_atrM1 = 0.0;
   g_atrM5 = 0.0;
   g_atrH1 = 0.0;
   g_emaH1 = 0.0;
   g_docH1 = 0.0;
   g_ema20M15 = 0.0;
   g_ema50M15 = 0.0;
   g_erM5 = 0.0;
   g_pdh = 0.0;
   g_pdl = 0.0;
   g_asiaHi = 0.0;
   g_asiaLo = 0.0;
   g_asiaCo = false;
   g_r4Hi = 0.0;
   g_r4Lo = 0.0;
   g_hopHi = 0.0;
   g_hopLo = 0.0;
   g_hopCo = false;
   g_ctxCo = false;
   g_ctxPhut = 0;
   g_trangThai = TT_KHOI_DONG;
   g_trangThaiCu = -1;
   ZeroMemory(g_pp1);
   g_pp1DaDung = 0;
   ZeroMemory(g_pp2);
   g_pp2DaDung = 0;
   for(int i = 0; i < DH5_SO_MUC; i++) ZeroMemory(g_muc[i]);
   for(int o = 0; o < DH5_SO_O; o++)
   {
      g_hocR[o] = 0.0;
      g_hocW[o] = 0.0;
      g_hocN[o] = 0;
      g_hocTat[o] = InpCheDoHoc == DH5_HOC_CHUNG_MINH_TRUOC;   // chứng minh trước: mọi ô bắt đầu ở trạng thái chỉ lệnh ảo
   }
   for(int j = 0; j < DH5_SO_DT; j++)
   {
      g_w[j] = 0.0;
      g_x[j] = 0.0;
   }
   g_moHinhN = 0;
   g_hocLuuGiay = 0;
   for(int i = 0; i < DH5_SO_AO; i++) ZeroMemory(g_ao[i]);
   g_aoBoQua = 0;
   g_soAoMo = 0;
   ZeroMemory(g_ngay);
   g_ngayDocGiay = 0;
   g_ngayCanDoc = true;
   for(int i = 0; i < DH5_SO_THEO_DOI; i++) ZeroMemory(g_td[i]);
   ZeroMemory(g_cho);
   g_nganSachLenh = 0.0;
   DatLaiThongKe(g_tkTong);
   for(int i = 0; i < 3; i++) DatLaiThongKe(g_tkPP[i]);
   for(int i = 0; i < 3; i++) DatLaiThongKe(g_tkPhien[i]);
   for(int i = 0; i < 2; i++) DatLaiThongKe(g_tkHuong[i]);
   for(int i = 0; i < 7; i++) DatLaiThongKe(g_tkTT[i]);
   g_dinhSG = 0.0;
   g_dungSG = false;
   g_napRutDaTinh = 0.0;
   g_napRutNgay = -1;
   g_balanceCu = 0.0;
   g_dinhVon = 0.0;
   g_ddMax = 0.0;
   g_ddMaxPct = 0.0;
   g_vonBanDau = 0.0;
   g_tgBatDau = 0;
   g_soTinHieu = 0;
   g_soVaoLenh = 0;
   g_tinHieuId = 0;
   g_tamDungDen = 0;
   g_logThang = 0;
   g_bangLuc = 0;
   g_tinHieuCuoi = "";
   g_choPhepLenh = false;
   g_lyDoKhongGuiLenh = "";
}

bool KiemTraInput()
{
   string loi = "";
   if(InpRuiRoMoiLenh <= 0.0 || InpRuiRoMoiLenh > DH5_RUI_RO_TRAN) loi = "Rủi ro mỗi vị thế phải trong (0; " + So2(DH5_RUI_RO_TRAN) + "]%";
   else if(InpLoNgayToiDa <= 0.0 || InpLoNgayToiDa > DH5_LO_NGAY_TRAN) loi = "Giới hạn lỗ ngày phải trong (0; " + So2(DH5_LO_NGAY_TRAN) + "]%";
   else if(InpSoViTheToiDa < 1 || InpSoViTheToiDa > DH5_SO_VI_THE_TRAN) loi = "Số vị thế tối đa phải từ 1 đến " + IntegerToString(DH5_SO_VI_THE_TRAN);
   else if(InpKyQuySauVaoLenh < DH5_KY_QUY_SAN) loi = "Mức ký quỹ tối thiểu không được dưới " + DoubleToString(DH5_KY_QUY_SAN, 0) + "%";
   else if(InpSutGiamToiDa < 0.0 || InpSutGiamToiDa >= 100.0) loi = "Cầu dao sụt giảm tổng phải từ 0 (tắt) đến dưới 100%";
   else if(InpMagic <= 0) loi = "Magic phải lớn hơn 0";
   else if(InpGioBatDau < 0 || InpGioBatDau > 23 || InpGioNgungVaoLenh < 1 || InpGioNgungVaoLenh > 24 || InpGioBatDau >= InpGioNgungVaoLenh)
      loi = "Giờ giao dịch không hợp lệ";
   else if(InpGioDongHetLenh < 0 || InpGioDongHetLenh > 23 || InpPhutDongHetLenh < 0 || InpPhutDongHetLenh > 59)
      loi = "Giờ đóng lệnh cuối ngày không hợp lệ";
   else if(InpDongLenhCuoiNgay && InpGioDongHetLenh * 60 + InpPhutDongHetLenh < InpGioNgungVaoLenh * 60 && InpGioNgungVaoLenh < 24 &&
           InpGioDongHetLenh * 60 + InpPhutDongHetLenh <= InpGioBatDau * 60)
      loi = "Giờ đóng lệnh cuối ngày phải sau giờ bắt đầu giao dịch";
   else if(InpSLToiThieu <= 0.0 || InpSLToiDa <= InpSLToiThieu || InpSLToiThieuATR < 0.0 || InpDemSLATR < 0.0)
      loi = "Khoảng SL không hợp lệ (tối thiểu > 0, tối đa > tối thiểu)";
   else if(InpTyLeRR < 1.0) loi = "TP phải từ 1R trở lên";
   else if(InpTrailingTuR > 0.0 && InpTrailingKhoangR <= 0.0) loi = "Khoảng trailing phải lớn hơn 0";
   else if(InpTruotGiaDuPhong < 0.0 || InpSpreadToiDa <= 0.0 || InpSpreadToiDaTheoSL <= 0.0 || InpPhiMoiLot < 0.0)
      loi = "Trượt giá/spread/phí không hợp lệ";
   else if(InpKhoiDongGiay < 60 || InpMatTickToiDaGiay < 5) loi = "Thời gian khởi động tick tối thiểu 60 giây, khoảng trống tick tối thiểu 5 giây";
   else if(InpPP2SoPhut < 10 || InpPP2SoPhut > 240 || InpPP2NenToiDa <= 0.0 || InpPP2VuotHop < 0.0 || InpPP2CuongDoTick < 0.0)
      loi = "Thông số PP2 không hợp lệ (hộp 10-240 phút, độ nén > 0)";
   else if(InpPP1HoiToiThieu <= 0.0 || InpPP1HoiToiDa <= InpPP1HoiToiThieu || InpPP1BatLaiToiThieu < 0.0 || InpPP1BatLaiToiDa <= InpPP1BatLaiToiThieu)
      loi = "Thông số PP1 không hợp lệ (tối đa phải lớn hơn tối thiểu)";
   else if(InpPP3QuetToiThieu < 0.0 || InpPP3QuetToiDa <= InpPP3QuetToiThieu || InpPP3ThoiGianGiay < 10)
      loi = "Thông số PP3 không hợp lệ";
   else if(InpSocHeSo <= 0.0 || InpSocToiThieu < 0.0 || InpSpreadDotBienHeSo <= 1.0 || InpTamDungSauSocGiay < 0 || InpChiPhiToiDaATR <= 0.0)
      loi = "Thông số sốc giá / chi phí không hợp lệ";
   else if(InpHocChuKy < 2 || InpHocSoMauToiThieu < 1 || InpMoHinhSoMau < 1 || InpHocNguongBat < 0.0) loi = "Thông số học thích nghi không hợp lệ";
   else if(InpERSideway < 0.0 || InpERXuHuong <= InpERSideway || InpERXuHuong > 1.0) loi = "Ngưỡng ER: 0 <= đi ngang < xu hướng <= 1";
   if(loi != "")
   {
      Print("DH5 INPUT KHÔNG HỢP LỆ: ", loi);
      return false;
   }
   return true;
}

int OnInit()
{
   DatLaiTrangThai();
   if(!KiemTraInput()) return INIT_PARAMETERS_INCORRECT;
   g_tester = MQLInfoInteger(MQL_TESTER) != 0;
   g_hienThi = !g_tester || MQLInfoInteger(MQL_VISUAL_MODE) != 0;
   if(MQLInfoInteger(MQL_OPTIMIZATION) != 0 && InpHocNapTrongTester)
   {
      Print("DH5: không nạp dữ liệu học khi tối ưu hóa.");
      return INIT_PARAMETERS_INCORRECT;
   }
   long calc = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   if(calc != SYMBOL_CALC_MODE_CFD && calc != SYMBOL_CALC_MODE_CFDLEVERAGE && calc != SYMBOL_CALC_MODE_FOREX &&
      calc != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE && calc != SYMBOL_CALC_MODE_CFDINDEX)
   {
      Print("DH5: chỉ hỗ trợ sản phẩm Forex/CFD tuyến tính như XAUUSD.");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_lotMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(g_point <= 0.0 || g_lotMin <= 0.0 || g_lotStep <= 0.0 || g_lotMax < g_lotMin)
   {
      Print("DH5: thông số symbol không hợp lệ.");
      return INIT_FAILED;
   }
   if(g_tickSize <= 0.0) g_tickSize = g_point;
   g_lotDigits = 0;
   double st = g_lotStep;
   while(g_lotDigits < 8 && MathAbs(st - MathRound(st)) > 1e-9)
   {
      st *= 10.0;
      g_lotDigits++;
   }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && InpSoViTheToiDa > 1)
   {
      Print("DH5: tài khoản netting chỉ cho phép 1 vị thế; đặt Số vị thế đồng thời tối đa = 1.");
      return INIT_PARAMETERS_INCORRECT;
   }
   ChonFilling();
   // Công tắc tài khoản thật: mô hình mới không tự lên tài khoản REAL
   g_choPhepLenh = true;
   if(InpCheDo == DH5_CHI_PHAN_TICH)
   {
      g_choPhepLenh = false;
      g_lyDoKhongGuiLenh = "CHE_DO_CHI_PHAN_TICH";
   }
   else if(!g_tester && AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpChoPhepTaiKhoanThat)
   {
      g_choPhepLenh = false;
      g_lyDoKhongGuiLenh = "TAI_KHOAN_THAT_CHUA_DUOC_PHEP";
   }
   FolderCreate(DH5_THU_MUC, FILE_COMMON);
   g_giayHienTai = (long)TimeCurrent();
   KiemTraThangLog();
   NapHoc();
   g_tinHieuId = GlobalVariableCheck(TenGVChung("ID")) ? (long)GlobalVariableGet(TenGVChung("ID")) : 0;
   KhoiPhucViThe();
   KhoiTaoSG();
   g_ngay.key = 0;
   CapNhatNgay(true);
   g_vonBanDau = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dinhVon = AccountInfoDouble(ACCOUNT_EQUITY);
   g_tgBatDau = (long)TimeCurrent();
   if(!g_tester) EventSetTimer(1);
   g_sanSang = true;
   string msg = "DH5 V" + DH5_PHIEN_BAN + " khởi động | " + _Symbol + " | Magic " + IntegerToString(InpMagic) + " | rủi ro " + So2(RuiRoPhanTram()) +
                "%/vị thế | lỗ ngày " + So2(LoNgayPhanTram()) + "% | tối đa " + IntegerToString(SoViTheToiDa()) + " vị thế | " +
                (g_choPhepLenh ? "ĐƯỢC GỬI LỆNH" : "CHỈ PHÂN TÍCH: " + g_lyDoKhongGuiLenh);
   Print(msg);
   GhiSuKien("KHOI_DONG", msg);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_sanSang)
   {
      LuuHoc();
      if(g_tester) XuatKetQua();
      GhiSuKien("DUNG_EA", "Lý do " + IntegerToString(reason) + "; vị thế tại sàn và dữ liệu khôi phục được giữ nguyên");
   }
   DongLog(g_hTH);
   DongLog(g_hLenh);
   DongLog(g_hSK);
   DongLog(g_hAo);
   if(!g_tester) GlobalVariablesFlush();
   Comment("");
   g_sanSang = false;
}

void OnTick()
{
   if(!g_sanSang) return;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t) || t.bid <= 0.0 || t.ask < t.bid) return;
   bool giayMoi = CapNhatTick(t);
   if(giayMoi)
   {
      CapNhatBoiCanh(false);
      CapNhatTrangThai();
      PP1_ThietLap();
      PP2_ThietLap();
   }
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal != g_balanceCu)
   {
      g_ngayCanDoc = true;
      g_balanceCu = bal;
   }
   CapNhatNgay(false);
   QuanLyViThe();
   QuanLyLenhAo();
   DoiChieu();
   XuLyTinHieu();
   TheoDoiSutGiam();
   if(giayMoi)
   {
      VeBang();
      if(g_hocLuuGiay == 0) g_hocLuuGiay = g_giayHienTai;
      if(g_giayHienTai - g_hocLuuGiay >= 1800)
      {
         LuuHoc();
         XaLog();
         g_hocLuuGiay = g_giayHienTai;
      }
   }
}

void OnTimer()
{
   if(!g_sanSang) return;
   CapNhatNgay(false);
   VeBang();
   XaLog();
}

double OnTester()
{
   return g_tkTong.net;
}
//+------------------------------------------------------------------+
