//+------------------------------------------------------------------+
//|                                  EA_PHOENIX_GRID_V0_11_TEST.mq5  |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  V0.11 TEST — CHẾ ĐỘ QUAN SÁT. EA NÀY KHÔNG GỬI LỆNH.            |
//|  - Nhận diện trạng thái thị trường theo Mục 6 kế hoạch PG-R0.0:  |
//|    hộp giá M5, ATR, ADX, ER, độ dốc, chạm biên, dữ liệu tick.    |
//|  - Cảnh báo / xác nhận / breakout giả / vùng mới theo tick.      |
//|  - Bảng điều khiển Phoenix Grid (Mục 19) ở góc trái trên chart.  |
//|  - Ước tính lot và rủi ro theo Mục 8 với thông số thật.          |
//|  - Ghi CSV trạng thái để đối chiếu với bộ phân loại Python.      |
//|  Tham số nhận diện là giá trị khởi đầu trong khoảng đã duyệt     |
//|  (Mục 13.10); sẽ được thay bằng kết quả kiểm định A0.            |
//|  V0.11 so với V0.10: bảng chuyển sang bên trái chart, bỏ biểu    |
//|  tượng phượng hoàng, bỏ dịch chart. Thuật toán và log không đổi. |
//|  Đặc tả thuật toán: docs/phoenix_grid/04_EA_V0_10_QUAN_SAT.md    |
//+------------------------------------------------------------------+
#property copyright   "DAVID HUNTER – PHOENIX GRID – 0941920986"
#property version     "0.11"
#property description "V0.11 TEST — chế độ quan sát: nhận diện trạng thái thị trường, bảng điều khiển, ước tính rủi ro. KHÔNG gửi lệnh."

#define PG_PHIEN_BAN     "V0.11 TEST"
#define PG_P             "PG_"            // tiền tố tên đối tượng trên chart
#define PG_TICK_BUF      8192             // bộ đệm tick vòng
#define PG_BUCKET_MAX    720              // tối đa số ô đếm tick trong 60 phút
#define PG_SP_RING       1800             // 30 phút mẫu spread, mỗi giây một mẫu
#define PG_MAX_SPREAD    5000             // spread lớn hơn (point) được gộp vào ô cuối
#define PG_SO_THONG_BAO  5
#define PG_KHOI_DONG_M5  24               // số nến M5 dựng lại trạng thái cấu trúc khi khởi động
#define PG_CHO_CHI_BAO   10               // số lần chờ chỉ báo M5 tính xong nến mới trước khi dùng giá trị hiện có

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

//--- Input (nhãn tiếng Việt)
input group "1. CHUNG"
input long   InpMagic          = 20260930;      // Magic của Phoenix Grid (dùng từ bản giao dịch)
input bool   InpGhiLog         = true;          // Ghi file CSV trạng thái thị trường
input string InpThuMucLog      = "PhoenixGrid"; // Thư mục con trong Common\Files

input group "2. NHẬN DIỆN TRẠNG THÁI (giá trị khởi đầu, chờ kết quả A0)"
input int    InpNBox           = 48;    // Số nến M5 dựng hộp giá
input double InpWMin           = 1.5;   // Độ rộng hộp tối thiểu (× ATR M5)
input double InpWMax           = 6.0;   // Độ rộng hộp tối đa (× ATR M5)
input double InpADXSideways    = 22.0;  // ADX M5 dưới mức này mới xét sideways
input double InpADXTrend       = 27.0;  // ADX M5 từ mức này trở lên mới xét xu hướng
input int    InpNER            = 24;    // Số nến M5 tính hiệu suất xu hướng (ER) và độ dốc
input double InpERSideways     = 0.30;  // ER dưới mức này mới xét sideways
input double InpERTrend        = 0.40;  // ER từ mức này trở lên mới xét xu hướng
input double InpBetaSideways   = 0.05;  // Độ dốc tối đa khi sideways (ATR M5 mỗi nến)
input double InpBetaTrend      = 0.10;  // Độ dốc tối thiểu khi xu hướng (ATR M5 mỗi nến)
input double InpTau            = 0.15;  // Dung sai chạm biên (× độ rộng hộp)
input int    InpMinCham        = 2;     // Số lần chạm tối thiểu ở mỗi biên
input int    InpHVao           = 2;     // Số nến M5 liên tiếp để nhận trạng thái mới
input int    InpHRa            = 2;     // Số nến M5 liên tiếp để bỏ trạng thái

input group "3. BREAKOUT THEO TICK"
input double InpBW             = 0.35;  // Đệm cảnh báo breakout (× ATR M5)
input int    InpDeltaGiay      = 15;    // Cửa sổ đo tốc độ và mật độ tick (giây)
input double InpVW             = 1.0;   // Tốc độ tick để cảnh báo (× ATR M1 trong cửa sổ)
input double InpLambdaW        = 2.0;   // Mật độ tick để cảnh báo (× trung vị 60 phút)
input double InpBC             = 0.30;  // Xác nhận: nến M1 đóng vượt biên (× ATR M5)
input double InpBX             = 1.0;   // Xác nhận: giá vượt biên (× ATR M5)
input int    InpTCGiay         = 90;    // Xác nhận: giá ở ngoài biên liên tục (giây)
input double InpRF             = 0.30;  // Breakout giả: giá quay vào hộp (× độ rộng hộp)
input int    InpTFPhut         = 15;    // Breakout giả: xét trong (phút) kể từ lúc cảnh báo
input int    InpNMinVungMoi    = 24;    // Vùng mới: số nến M5 tối thiểu sau xác nhận breakout
input double InpDeltaADX       = 5.0;   // Vùng mới: ADX phải giảm tối thiểu từ đỉnh sau breakout
input int    InpNMaxTheoDoi    = 288;   // Theo dõi breakout tối đa (nến M5) để chờ vùng mới

input group "4. BỘ LỌC KHÔNG VÀO LỆNH"
input double InpSpreadAbs      = 0.26;  // Spread tối đa tuyệt đối (USD/oz)
input double InpSpreadLan      = 1.5;   // Spread tối đa (× trung vị 30 phút)
input int    InpMatTickGiay    = 60;    // Mất tick quá số giây này trong phiên
input int    InpPhutTruocNghi  = 15;    // Không vào lệnh trong số phút trước giờ nghỉ

input group "5. RỦI RO — CHỈ ƯỚC TÍNH, KHÔNG ĐẶT LỆNH"
input double InpVonGoc         = 5000;  // Vốn gốc (tiền tài khoản)
input double InpAlpha          = 0.5;   // Tỷ lệ tái đầu tư lợi nhuận (α)
input double InpRbPhanTram     = 1.0;   // Ngân sách rủi ro mỗi basket (% vốn tham chiếu)
input int    InpSoBac          = 3;     // Số bậc DCA dùng để ước tính
input double InpBuocATR        = 1.15;  // Khoảng cách giữa các bậc (× ATR M5)
input double InpTruotMoiChieu  = 0.05;  // Trượt giá dự phòng mỗi chiều vào/ra (USD/oz)
input double InpTruotCatLo     = 2.0;   // Trượt giá dự phòng khi cắt lỗ (USD/oz)
input double InpPhiKhuHoi      = 0.0;   // Commission + phí khứ hồi mỗi lot (tiền tài khoản, R0.1 đo được 0)

input group "6. GIAO DIỆN"
input bool   InpHienBang       = true;  // Hiển thị bảng điều khiển
input double InpTyLe           = 1.0;   // Tỷ lệ kích thước bảng (0,8 – 1,5)
input bool   InpVeHop          = true;  // Vẽ hộp giá và mức cảnh báo trên chart

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
bool        g_thuGon = false, g_tamDung = false;
string      g_nutCho = "";
datetime    g_nutChoDen = 0;
string      g_thongBao[PG_SO_THONG_BAO];

//--- Log CSV
int         g_log = INVALID_HANDLE;
string      g_logThang = "";

//+------------------------------------------------------------------+
//| Khởi động                                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // MT5 giữ biến toàn cục của EA khi đổi khung thời gian hoặc tham số: đặt lại toàn bộ trạng thái
   DatLaiTrangThai();
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
      InpSoBac < 1 || InpSoBac > 20 || InpRbPhanTram <= 0.0 || InpVonGoc <= 0.0)
     {
      Print("PG: tham số không hợp lệ, xem khoảng cho phép trong docs/phoenix_grid/04_EA_V0_10_QUAN_SAT.md");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_hATR5 = iATR(_Symbol, PERIOD_M5, 14);
   g_hATR1 = iATR(_Symbol, PERIOD_M1, 14);
   g_hADX5 = iADX(_Symbol, PERIOD_M5, 14);
   if(g_hATR5 == INVALID_HANDLE || g_hATR1 == INVALID_HANDLE || g_hADX5 == INVALID_HANDLE)
     {
      Print("PG: không tạo được chỉ báo ATR/ADX");
      return INIT_FAILED;
     }
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
   if(InpHienBang)
      DungBang();
   ThemThongBao("Khởi động " + PG_PHIEN_BAN + ": chế độ quan sát, không gửi lệnh");
   ThemThongBao("Symbol " + _Symbol + ", tiền tài khoản " + AccountInfoString(ACCOUNT_CURRENCY));
   int soPG = 0, soKhac = 0;
   DemViThe(soPG, soKhac);
   if(soKhac > 0)
      ThemThongBao("Tài khoản có " + IntegerToString(soKhac) + " vị thế không thuộc Phoenix");
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Kết thúc                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_hATR5 != INVALID_HANDLE)
      IndicatorRelease(g_hATR5);
   if(g_hATR1 != INVALID_HANDLE)
      IndicatorRelease(g_hATR1);
   if(g_hADX5 != INVALID_HANDLE)
      IndicatorRelease(g_hADX5);
   g_hATR5 = INVALID_HANDLE;
   g_hATR1 = INVALID_HANDLE;
   g_hADX5 = INVALID_HANDLE;
   ObjectsDeleteAll(0, PG_P);
   if(g_log != INVALID_HANDLE)
     {
      FileClose(g_log);
      g_log = INVALID_HANDLE;
     }
   LuuTaiKhoan();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Mỗi tick: nạp mọi tick mới (không bỏ sót khi OnTick bị gộp),      |
//| nến mới, breakout. Không vẽ giao diện.                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick ts[];
   int     n = 0;
   if(g_msCuoi > 0)
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
  }

//+------------------------------------------------------------------+
//| Mỗi giây: nến chờ chỉ báo, spread, bộ lọc, tài khoản, giao diện   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   KiemTraNenMoi();
   LayMauSpread();
   CapNhatLoc();
   CapNhatTaiKhoan();
   if(g_nutCho != "" && TimeLocal() > g_nutChoDen)
      HuyChoXacNhan();
   if(InpHienBang)
      CapNhatBang();
   if(InpVeHop)
      VeHop();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Sự kiện chart: nút bấm                                            |
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
   g_tamDung = false;
   g_nutCho = "";
   g_nutChoDen = 0;
   for(int i = 0; i < PG_SO_THONG_BAO; i++)
      g_thongBao[i] = "";
   g_log = INVALID_HANDLE;
   g_logThang = "";
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
              {
               int    sp = (int)MathRound((g_ask - g_bid) / g_point);
               double nguongAbs = InpSpreadAbs / g_point;
               double nguongTv = (g_spTrungVi > 0) ? InpSpreadLan * g_spTrungVi : nguongAbs;
               if(sp > MathMin(nguongAbs, nguongTv) + 0.5)
                 {
                  ly = "Spread giãn";
                  ma = "SPREAD_GIAN";
                 }
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
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dinhEq    = GlobalVariableCheck(g_gvDinh) ? GlobalVariableGet(g_gvDinh) : eq;
   g_ddMax     = GlobalVariableCheck(g_gvDDMax) ? GlobalVariableGet(g_gvDDMax) : 0.0;
   g_ngay      = GlobalVariableCheck(g_gvNgay) ? (int)GlobalVariableGet(g_gvNgay) : -1;
   g_dauNgayEq = GlobalVariableCheck(g_gvDauNgay) ? GlobalVariableGet(g_gvDauNgay) : eq;
  }

void CapNhatTaiKhoan()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   int    ngay = (int)((long)TimeCurrent() / 86400);
   if(ngay != g_ngay)
     {
      g_ngay = ngay;
      g_dauNgayEq = eq;
     }
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
   if(g_gvDinh == "")
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
//| ƯỚC TÍNH RỦI RO theo Mục 8.2 (2) kế hoạch — chỉ hiển thị           |
//| D tối đa: khoảng cách phòng thủ (từ lệnh đầu) để basket m bậc ×  |
//| lot tối thiểu lỗ không quá ngân sách R_b, gồm chi phí và trượt.  |
//+------------------------------------------------------------------+
void UocTinhRuiRo(double &eref, double &rb, double &dmax, int &soBac, double &lo100, double &mMin, double &lotMin)
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   eref   = MathMin(eq, InpVonGoc + InpAlpha * MathMax(0.0, eq - InpVonGoc));
   rb     = InpRbPhanTram / 100.0 * eref;
   lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double ts  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double vpp = (ts > 0.0) ? tv / ts : 0.0;
   lo100 = lotMin * vpp * 100.0;
   mMin  = 0.0;
   double mm = 0.0;
   if(g_ask > 0.0 && lotMin > 0.0 && OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotMin, g_ask, mm))
      mMin = mm;
   dmax  = -1.0;
   soBac = 0;
   if(vpp <= 0.0 || lotMin <= 0.0 || g_atr5 <= 0.0)
      return;
   double sp   = (g_spTrungVi > 0) ? g_spTrungVi * g_point : (g_ask - g_bid);
   double crt  = vpp * (sp + 2.0 * InpTruotMoiChieu) + InpPhiKhuHoi;   // chi phí khứ hồi mỗi lot (Mục 5)
   double buoc = InpBuocATR * g_atr5;
   for(int m = InpSoBac; m >= 1; m--)
     {
      double tongD = 0.0;
      for(int k = 0; k < m; k++)
         tongD += k * buoc;
      double D = (rb / lotMin - m * crt + vpp * tongD) / (m * vpp) - InpTruotCatLo;
      if(D > (m - 1) * buoc)
        {
         dmax = D;
         soBac = m;
         return;
        }
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
//| LOG CSV theo tháng: <Common>\Files\PhoenixGrid\                   |
//| Chạy thật: ghi nối tiếp. Tester: file riêng, ghi mới mỗi lần chạy.|
//+------------------------------------------------------------------+
void MoLog()
  {
   MqlDateTime dt;
   TimeToStruct((g_tickCuoi > 0) ? g_tickCuoi : TimeCurrent(), dt);
   string thang = StringFormat("%04d%02d", dt.year, dt.mon);
   if(g_log != INVALID_HANDLE && thang == g_logThang)
      return;
   if(g_log != INVALID_HANDLE)
     {
      FileClose(g_log);
      g_log = INVALID_HANDLE;
     }
   bool   tester = (bool)MQLInfoInteger(MQL_TESTER);
   string ten = InpThuMucLog + "\\PG_V011_trang_thai_" + _Symbol + (tester ? "_tester_" : "_") + thang + ".csv";
   int    co = FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
   if(!tester)
      co |= FILE_READ;
   g_log = FileOpen(ten, co, ';', CP_UTF8);
   if(g_log == INVALID_HANDLE)
     {
      PrintFormat("PG: không mở được log %s (lỗi %d)", ten, GetLastError());
      return;
     }
   if(FileSize(g_log) == 0)
      FileWrite(g_log, "thoi_gian", "msc", "su_kien", "nen_m5", "bid", "ask", "spread_point", "cau_truc", "thi_truong",
                "tham_chieu_tren", "tham_chieu_duoi", "tham_chieu_rong", "hop_tren", "hop_duoi",
                "atr_m5", "atr_m1", "adx", "di_cong", "di_tru", "er", "do_doc", "cham_tren", "cham_duoi",
                "toc_do_tick", "mat_do_tick", "so_nen_tu_canh_bao", "adx_dinh_sau_canh_bao",
                "sau_bo_so_nen", "sau_bo_tren", "sau_bo_duoi", "loc");
   FileSeek(g_log, 0, SEEK_END);
   g_logThang = thang;
  }

void GhiLog(const string suKien)
  {
   if(!InpGhiLog || g_tamDung)
      return;
   MoLog();
   if(g_log == INVALID_HANDLE)
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
   TaoChu("B_tt_ea", x + g_pw - S(34), y + S(20), "QUAN SÁT", FS(8), CLR_VANG, PG_FONT_B, ANCHOR_RIGHT_UPPER);
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
   TaoChu("B_ea", x + S(8), y + S(44), "EA: QUAN SÁT — không gửi lệnh", FS(8), CLR_CHU, PG_FONT);
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
   h = TaoKhung("B_k_vg", y, 6, "VÙNG GIÁ & BREAKOUT");
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
   y += h + S(4);

   // rủi ro ước tính
   h = TaoKhung("B_k_rr", y, 4, "RỦI RO (ƯỚC TÍNH, CHƯA ĐẶT LỆNH)");
   yr = y + S(19);
   TaoDong("B_r_eref", 0, yr, "Vốn tham chiếu");
   TaoDong("B_r_rb", 1, yr, "Ngân sách basket");
   yr += S(15);
   TaoDong("B_r_d", 0, yr, "Phòng thủ tối đa");
   TaoDong("B_r_bac", 1, yr, "Số bậc × lot");
   yr += S(15);
   TaoDong("B_r_lo100", 0, yr, "Lỗ 100 USD / lot min");
   TaoDong("B_r_mmin", 1, yr, "Margin lot min");
   yr += S(15);
   TaoDong("B_r_sp", 0, yr, "Spread hiện tại");
   TaoDong("B_r_sptv", 1, yr, "Trung vị 30p / ngưỡng");
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
   TaoNut("B_n_dongbk", x + 2 * (bw + S(6)), y, bw, bh, "ĐÓNG BASKET", C'70,30,25', CLR_MO, FS(8));
   TaoNut("B_n_dongtc", x + 3 * (bw + S(6)), y, bw, bh, "ĐÓNG TẤT CẢ", C'70,30,25', CLR_MO, FS(8));
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
   DatChu("B_tt_ea", g_tamDung ? "TẠM DỪNG" : "QUAN SÁT", g_tamDung ? CLR_CAM : CLR_VANG);
   if(g_thuGon)
     {
      DatChu("B_mini", TenHienThi(tt) + "  ·  Equity " + FTien(eq) + " " + cur, CLR_CHU);
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
   DatChu("B_ea", g_tamDung ? "EA: TẠM DỪNG (không ghi log)" : "EA: QUAN SÁT — không gửi lệnh", CLR_CHU);
   DatChu("B_loc", "Lọc vào lệnh: " + g_lyDoLoc, g_loc ? CLR_XANH : CLR_CAM);

   // tài khoản
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double fl  = AccountInfoDouble(ACCOUNT_PROFIT);
   double hn  = eq - g_dauNgayEq;
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

   // rủi ro ước tính
   double eref = 0.0, rb = 0.0, dmax = 0.0, lo100 = 0.0, mMin = 0.0, lotMin = 0.0;
   int    soBac = 0;
   UocTinhRuiRo(eref, rb, dmax, soBac, lo100, mMin, lotMin);
   DatGiaTri("B_r_eref", FTien(eref), CLR_CHU);
   DatGiaTri("B_r_rb", FTien(rb) + " (" + DoubleToString(InpRbPhanTram, 1) + "%)", CLR_CHU);
   if(dmax > 0.0)
     {
      DatGiaTri("B_r_d", DoubleToString(dmax, 1) + " USD (" + DoubleToString(dmax / g_atr5, 1) + "×ATR)", CLR_VANG);
      DatGiaTri("B_r_bac", IntegerToString(soBac) + " × " + DoubleToString(lotMin, 2), CLR_CHU);
     }
   else
     {
      DatGiaTri("B_r_d", (g_atr5 > 0.0) ? "KHÔNG ĐỦ NGÂN SÁCH" : "chờ dữ liệu", (g_atr5 > 0.0) ? CLR_DO : CLR_MO);
      DatGiaTri("B_r_bac", "—", CLR_MO);
     }
   DatGiaTri("B_r_lo100", FTien(lo100) + " (" + DoubleToString((eref > 0.0) ? lo100 / eref * 100.0 : 0.0, 1) + "%)", CLR_CHU);
   DatGiaTri("B_r_mmin", FTien(mMin), CLR_CHU);
   int spNow = (int)MathRound((g_ask - g_bid) / g_point);
   DatGiaTri("B_r_sp", IntegerToString(spNow) + " pt (" + DoubleToString(spNow * g_point, 3) + ")", g_loc ? CLR_CHU : CLR_CAM);
   DatGiaTri("B_r_sptv", IntegerToString(g_spTrungVi) + " / " + DoubleToString(InpSpreadAbs / g_point, 0) + " pt", CLR_CHU);

   // chu kỳ: bản quan sát chỉ sáng các bước thuộc thị trường (1, 3, 5)
   int buoc = 0;
   if(bo)
      buoc = 3;
   else
      if(tt == "VUNG_MOI")
         buoc = 5;
      else
         if(tt == "SIDEWAYS")
            buoc = 1;
   for(int i = 1; i <= 6; i++)
      DatChip("B_ck" + IntegerToString(i), i == buoc, C'214,160,20', CLR_NEN);

   // thông báo
   for(int i = 0; i < 4; i++)
      DatChu("B_tb" + IntegerToString(i), g_thongBao[i], (i == 0) ? CLR_CHU : CLR_MO);
  }

//+------------------------------------------------------------------+
//| NÚT: xác nhận 2 bước. Bản quan sát không có lệnh: ĐÓNG chỉ báo   |
//+------------------------------------------------------------------+
void XuLyNut(const string ten)
  {
   if(ten == PG_P + "B_n_dongbk" || ten == PG_P + "B_n_dongtc")
     {
      ThemThongBao("Bản quan sát không có lệnh để đóng (chức năng có từ V0.20)");
      return;
     }
   if(g_nutCho != ten)
     {
      HuyChoXacNhan();
      g_nutCho = ten;
      g_nutChoDen = TimeLocal() + 5;
      ObjectSetString(0, ten, OBJPROP_TEXT, "XÁC NHẬN? 5s");
      return;
     }
   bool tamDung = (ten == PG_P + "B_n_tamdung");
   HuyChoXacNhan();
   if(tamDung != g_tamDung)
     {
      g_tamDung = tamDung;
      ThemThongBao(tamDung ? "Đã TẠM DỪNG ghi log (bản quan sát không giao dịch)" : "Đã TIẾP TỤC");
     }
  }

void HuyChoXacNhan()
  {
   if(g_nutCho == "")
      return;
   string nhan = (g_nutCho == PG_P + "B_n_tieptuc") ? "TIẾP TỤC" : "TẠM DỪNG";
   if(ObjectFind(0, g_nutCho) >= 0)
      ObjectSetString(0, g_nutCho, OBJPROP_TEXT, nhan);
   g_nutCho = "";
  }
//+------------------------------------------------------------------+
