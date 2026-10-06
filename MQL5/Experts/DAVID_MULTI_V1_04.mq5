//+------------------------------------------------------------------+
//|                                          DAVID_MULTI_V1_04.mq5   |
//|  DAVID MULTI V1.04 = DAVID CRT V1.03 + 3 chiến lược ĐƠN LỆNH     |
//|                                                                  |
//|  Liên hệ: 0941920986 - Davidhunter - Tele @adsmmo8386            |
//|                                                                  |
//|  1. CRT  (Magic 71001) - Candle Range Theory H4 + M15 (V1.03)    |
//|  2. SAR  (Magic 71002) - Scalping SAR, nguồn: Scalping M1 2.1    |
//|  3. BRK  (Magic 71003) - Breakout Stop OCO, nguồn: Máy in tiền   |
//|  4. ICT  (Magic 71004) - ICT hợp lưu, nguồn: OptimusPrime 2.20   |
//|                                                                  |
//|  Mỗi chiến lược: tối đa 1 lệnh (position hoặc lệnh chờ) cùng lúc,|
//|  KHÔNG DCA, KHÔNG Grid, KHÔNG Martingale, KHÔNG Hedge.           |
//|  Mỗi chiến lược có Magic, comment, công tắc Input và nút BẬT/TẮT |
//|  riêng trên bảng. Tradelog CSV ghi mọi vị thế đã đóng.           |
//|                                                                  |
//|  Phần CRT giữ nguyên logic V1.03: H4[1] = Reference,             |
//|  H4[0] = Active (Sweep), M15[1] = Confirmation.                  |
//+------------------------------------------------------------------+
#property copyright   "Davidhunter - 0941920986 - Tele @adsmmo8386"
#property version     "1.04"
#property description "DAVID MULTI V1.04: CRT + SAR + BRK + ICT (đơn lệnh) | 0941920986 - Tele @adsmmo8386"

#include <Trade\Trade.mqh>

//--- Timeframe cố định của CRT (KHÔNG BAO GIỜ dùng _Period)
#define CRT_TF_RANGE    PERIOD_H4
#define CRT_TF_CONFIRM  PERIOD_M15
#define CRT_TF_REPLAY   PERIOD_M1
#define CRT_PREFIX      "DAVIDCRT_"
#define CRT_EA_NAME     "DAVID MULTI V1.04"
#define DAVID_CONTACT   "0941920986-Davidhunter-Tele @adsmmo8386"

//--- Enum dùng trong Input
enum ENUM_BOARD_PERIOD
{
   BOARD_TODAY = 0,   // Hôm nay
   BOARD_MONTH = 1,   // Tháng này
   BOARD_ALL   = 2    // Toàn bộ
};

enum ENUM_SAR_MODE
{
   SAR_MODE_TREND     = 0,  // Theo xu hướng SAR (BUY + SELL)
   SAR_MODE_BUY_ONLY  = 1,  // Chỉ BUY
   SAR_MODE_SELL_ONLY = 2   // Chỉ SELL
};

enum ENUM_SAR_TP_MODE
{
   SAR_TP_FIXED = 0,  // TP cố định theo tiền
   SAR_TP_FLOAT = 1   // TP thả nổi (trailing lợi nhuận theo tiền)
};

//====================================================================
// INPUT (tên hiển thị tiếng Việt nằm ở comment phía sau mỗi input)
//====================================================================
input group "=== 0. CHUNG ==="
input uint   InpDeviationPoints   = 50;     // Độ_trượt_giá_tối_đa_(points)
input bool   InpOneTradeGlobal    = false;  // Chỉ_1_lệnh_cho_toàn_EA (mọi chiến lược cộng lại)

input group "=== 0. TRADELOG CSV ==="
input bool   InpTradeLog          = true;                    // Bật_xuất_file_tradelog
input string InpTradeLogName      = "DAVID_MULTI_TradeLog";  // Tên_file (MQL5 Common\Files, thêm _Symbol.csv)

input group "=== 0. BẢNG BOARD ==="
input bool              InpShowBoard        = true;         // Hiển_thị_bảng_Board
input int               InpBoardX           = 14;           // Vị_trí_X_bảng
input int               InpBoardY           = 16;           // Vị_trí_Y_bảng
input double            InpBoardScale       = 1.0;          // Tỷ_lệ_phóng_bảng (0.65 - 1.8)
input int               InpBoardRefresh     = 3;            // Chu_kỳ_quét_lịch_sử_(giây)
input ENUM_BOARD_PERIOD InpBoardPeriod      = BOARD_MONTH;  // Kỳ_thống_kê_mặc_định
input bool              InpBoardCollapsed   = false;        // Bắt_đầu_ở_trạng_thái_thu_gọn
input bool              InpBoardLines       = false;        // Vẽ_đường_Entry/SL/TP_vị_thế_đang_mở

//--------------------------------------------------------------------
// 1. CRT - Candle Range Theory (logic V1.03 giữ nguyên)
//--------------------------------------------------------------------
input group "=== 1. CRT - CANDLE RANGE THEORY (H4 + M15) ==="
input bool   InpEnableCRT         = true;   // Bật_chiến_lược_CRT
input ulong  InpMagic             = 71001;  // CRT_Magic_Number
input string InpCRTComment        = "CRT|0941920986|@adsmmo8386"; // CRT_Comment_lệnh (tối đa 31 ký tự)
input double InpFixedLot          = 0.01;   // CRT_Khối_lượng_cố_định
input bool   InpUseRiskEquity     = false;  // CRT_Sử_dụng_Risk_Theo_Equity
input double InpRiskPercent       = 1.0;    // CRT_Rủi_ro_mỗi_lệnh_%
input double InpSLBuffer          = 0.0;    // CRT_Khoảng_đệm_SL (giá)
input double InpMaxSpread         = 0.50;   // CRT_Spread_tối_đa (giá, 0 = tắt)
input double InpMinSweep          = 0.0;    // CRT_Sweep_tối_thiểu (giá, 0 = tắt)
input double InpMaxSweep          = 0.0;    // CRT_Sweep_tối_đa (giá, 0 = tắt)
input double InpMinRR             = 0.0;    // CRT_RR_tối_thiểu (0 = tắt)
input bool   InpAllowBuy          = true;   // CRT_Cho_phép_BUY
input bool   InpAllowSell         = true;   // CRT_Cho_phép_SELL
input bool   InpShowCRT           = true;   // CRT_Hiển_thị_trên_Chart
input bool   InpShowReference     = true;   // CRT_Hiển_thị_Reference_H4
input int    InpHistoryCount      = 100;    // CRT_Số_setup_lịch_sử_hiển_thị
input bool   InpDebug             = true;   // CRT_Chế_độ_Debug
input bool   InpVerboseLog        = true;   // CRT_Ghi_Log_Chi_Tiết

//--------------------------------------------------------------------
// 2. SAR - Scalping theo Parabolic SAR (nguồn: Scalping M1 2.1)
//--------------------------------------------------------------------
input group "=== 2. SAR - SCALPING PARABOLIC SAR ==="
input bool             InpEnableSAR        = false;          // Bật_chiến_lược_SAR
input ulong            InpSARMagic         = 71002;          // SAR_Magic_Number
input string           InpSARComment       = "SAR|0941920986|@adsmmo8386"; // SAR_Comment_lệnh (tối đa 31 ký tự)
input ENUM_TIMEFRAMES  InpSARTimeframe     = PERIOD_M1;      // SAR_Khung_thời_gian_tín_hiệu
input double           InpSARStep          = 0.02;           // SAR_Step
input double           InpSARMaximum       = 0.2;            // SAR_Maximum
input ENUM_SAR_MODE    InpSARMode          = SAR_MODE_TREND; // SAR_Chế_độ_giao_dịch
input double           InpSARLot           = 0.01;           // SAR_Khối_lượng_cố_định
input int              InpSARDistancePts   = 40;             // SAR_Khoảng_cách_tối_đa_tới_SAR (point, mã gốc cộng 5)
input int              InpSARCooldownSec   = 5;              // SAR_Nghỉ_giữa_2_lần_mở (giây)
input ENUM_SAR_TP_MODE InpSARTPMode        = SAR_TP_FIXED;   // SAR_Chế_độ_chốt_lời
input double           InpSARTPMoney       = 10.0;           // SAR_TP_cố_định (tiền tài khoản)
input double           InpSARSLMoneyFixed  = 20.0;           // SAR_SL_ở_chế_độ_TP_cố_định (tiền)
input double           InpSARFloatActivate = 10.0;           // SAR_Lãi_kích_hoạt_TP_thả_nổi (tiền)
input double           InpSARFloatRetrace  = 5.0;            // SAR_Mức_hồi_từ_đỉnh_lãi_để_đóng (tiền)
input double           InpSARFloatStep     = 1.0;            // SAR_Bước_cập_nhật_đỉnh_lãi (tiền)
input double           InpSARSLMoneyFloat  = 100.0;          // SAR_SL_ở_chế_độ_TP_thả_nổi (tiền)
input double           InpSARDailyTarget   = 0.0;            // SAR_Mục_tiêu_lãi_ngày_dừng_vào_lệnh (tiền, 0 = tắt)
input double           InpSARDailyLoss     = 0.0;            // SAR_Ngưỡng_lỗ_ngày_dừng_vào_lệnh (tiền, 0 = tắt)
input bool             InpSARSpreadFilter  = true;           // SAR_Bật_lọc_spread
input int              InpSARMaxSpreadPts  = 50;             // SAR_Spread_tối_đa (point)
input bool             InpSARCandleFilter  = true;           // SAR_Bật_lọc_nến_quá_lớn
input int              InpSARCandleLookback= 20;             // SAR_Số_nến_tính_biên_độ_TB
input double           InpSARCandleMaxMult = 2.5;            // SAR_Biên_nến_tối_đa_so_với_TB
input bool             InpSARUseCurrentBar = true;           // SAR_Dùng_nến_hiện_tại_để_lọc
input bool             InpSARATRFilter     = true;           // SAR_Bật_lọc_ATR
input int              InpSARATRPeriod     = 14;             // SAR_Chu_kỳ_ATR
input double           InpSARATRMin        = 0.5;            // SAR_Tỷ_lệ_ATR_tối_thiểu
input double           InpSARATRMax        = 2.5;            // SAR_Tỷ_lệ_ATR_tối_đa
input int              InpSARATRLookback   = 50;             // SAR_Số_nến_tính_ATR_TB
input bool             InpSARTickFilter    = true;           // SAR_Bật_lọc_số_tick
input int              InpSARMinTicks      = 5;              // SAR_Số_tick_tối_thiểu
input int              InpSARTickPeriodSec = 60;             // SAR_Khoảng_đếm_tick (giây)
input bool             InpSARTimeFilter    = false;          // SAR_Bật_lọc_giờ (giờ server)
input string           InpSARStartTime     = "08:00";        // SAR_Giờ_bắt_đầu (HH:MM server)
input string           InpSAREndTime       = "18:00";        // SAR_Giờ_kết_thúc (HH:MM server)

//--------------------------------------------------------------------
// 3. BRK - Breakout Buy Stop / Sell Stop OCO (nguồn: Máy in tiền 1.40)
//--------------------------------------------------------------------
input group "=== 3. BRK - BREAKOUT STOP OCO (MÁY IN TIỀN) ==="
input bool   InpEnableBRK         = false;  // Bật_chiến_lược_BRK
input ulong  InpBRKMagic          = 71003;  // BRK_Magic_Number
input string InpBRKComment        = "BRK|0941920986|@adsmmo8386"; // BRK_Comment_lệnh (tối đa 31 ký tự)
input double InpBRKLot            = 0.01;   // BRK_Khối_lượng_cố_định
input bool   InpBRKUseEquityLot   = false;  // BRK_Lot_theo_Equity (lot = Equity x Hệ_số / 1.000.000)
input double InpBRKEquityFactor   = 500;    // BRK_Hệ_số_Equity (KHÔNG phải %)
input double InpBRKDistance       = 1.0;    // BRK_Khoảng_đặt_lệnh_chờ (giá, mặc định = gốc trên XAUUSD)
input double InpBRKStopLoss       = 1.0;    // BRK_SL_ban_đầu (giá)
input double InpBRKTakeProfit     = 0.0;    // BRK_TP (giá, 0 = tắt)
input double InpBRKTrail          = 0.5;    // BRK_Khoảng_trailing_SL (giá, 0 = tắt)
input double InpBRKMoveStep       = 0.5;    // BRK_Bước_dời_lệnh_chờ (giá)
input int    InpBRKMoveSec        = 3;      // BRK_Nghỉ_giữa_2_lần_dời (giây)
input double InpBRKMaxSpread      = 0.50;   // BRK_Spread_tối_đa (giá, 0 = tắt)
input bool   InpBRKTimeFilter     = true;   // BRK_Bật_lọc_giờ (giờ server)
input string InpBRKStart1         = "00:00";// BRK_Khoảng_1_bắt_đầu
input string InpBRKEnd1           = "08:00";// BRK_Khoảng_1_kết_thúc
input string InpBRKStart2         = "09:00";// BRK_Khoảng_2_bắt_đầu
input string InpBRKEnd2           = "17:00";// BRK_Khoảng_2_kết_thúc
input string InpBRKStart3         = "20:00";// BRK_Khoảng_3_bắt_đầu
input string InpBRKEnd3           = "23:59";// BRK_Khoảng_3_kết_thúc

//--------------------------------------------------------------------
// 4. ICT - Hợp lưu Sweep / FVG / OB (nguồn: OptimusPrime 2.20)
//--------------------------------------------------------------------
input group "=== 4. ICT - HỢP LƯU SWEEP/FVG/OB (OPTIMUSPRIME) ==="
input bool            InpEnableICT         = false;       // Bật_chiến_lược_ICT
input ulong           InpICTMagic          = 71004;       // ICT_Magic_Number
input string          InpICTComment        = "ICT|0941920986|@adsmmo8386"; // ICT_Comment_lệnh (tối đa 31 ký tự)
input ENUM_TIMEFRAMES InpICTExecTF         = PERIOD_M15;  // ICT_Khung_vào_lệnh
input ENUM_TIMEFRAMES InpICTConfirmTF      = PERIOD_H1;   // ICT_Khung_xác_nhận
input ENUM_TIMEFRAMES InpICTBiasTF         = PERIOD_H4;   // ICT_Khung_xu_hướng
input double          InpICTRiskPercent    = 1.0;         // ICT_Rủi_ro_mỗi_setup_% (số dư)
input double          InpICTFixedLot       = 0.0;         // ICT_Lot_cố_định (0 = tính theo rủi ro %)
input int             InpICTMaxTradesDay   = 3;           // ICT_Số_setup_tối_đa_mỗi_ngày
input double          InpICTMaxDailyRisk   = 3.0;         // ICT_Ngân_sách_rủi_ro_ngày_% (0 = tắt)
input int             InpICTMaxConsLoss    = 3;           // ICT_Số_lệnh_thua_liên_tiếp_để_nghỉ (0 = tắt)
input int             InpICTCooldownMin    = 240;         // ICT_Thời_gian_nghỉ_sau_chuỗi_thua (phút)
input double          InpICTMaxDDPercent   = 5.0;         // ICT_DD_tối_đa_chặn_lệnh_mới_% (0 = tắt)
input int             InpICTMinScore       = 4;           // ICT_Điểm_hợp_lưu_tối_thiểu
input int             InpICTTRPeriodExec   = 14;          // ICT_Chu_kỳ_TR_khung_vào
input int             InpICTTRPeriodConf   = 10;          // ICT_Chu_kỳ_TR_khung_xác_nhận
input int             InpICTTRPeriodBias   = 8;           // ICT_Chu_kỳ_TR_khung_xu_hướng
input int             InpICTSwingWindow    = 5;           // ICT_Số_nến_mỗi_phía_xác_định_swing
input int             InpICTSwingLookback  = 20;          // ICT_Số_nến_quét_swing
input double          InpICTBOSFactor      = 0.2;         // ICT_Biên_phá_cấu_trúc_BOS (x TR)
input double          InpICTLSWick         = 0.3;         // ICT_Độ_vượt_swing_khi_quét (x TR)
input double          InpICTLSMinWick      = 0.5;         // ICT_Râu_quét_tối_thiểu (x TR)
input double          InpICTLSBody         = 0.6;         // ICT_Thân_nến_từ_chối_tối_thiểu (x TR)
input int             InpICTLSValidity     = 5;           // ICT_Số_nến_hiệu_lực_cú_quét
input double          InpICTFVGMin         = 0.4;         // ICT_FVG_tối_thiểu (x TR)
input double          InpICTFVGMax         = 2.5;         // ICT_FVG_tối_đa (x TR)
input double          InpICTImpulseBody    = 0.7;         // ICT_Thân_nến_xung_lực (x TR)
input double          InpICTOBMinBody      = 0.65;        // ICT_Thân_OB_tối_thiểu (x TR)
input int             InpICTImpulseCandles = 3;           // ICT_Số_nến_xung_lực_sau_OB
input double          InpICTImpulseMove    = 1.5;         // ICT_Tổng_xung_lực_tối_thiểu (x TR)
input double          InpICTOBMaxRange     = 0.8;         // ICT_Biên_OB_tối_đa (x TR)
input double          InpICTConfRadius     = 0.4;         // ICT_Bán_kính_hợp_lưu_FVG_OB (x TR)
input bool            InpICTUseLimit       = true;        // ICT_Dùng_lệnh_Limit_khi_cần_chờ_hồi
input int             InpICTLimitExpiryH   = 4;           // ICT_Hạn_lệnh_Limit (giờ)
input double          InpICTSLBuffer       = 0.3;         // ICT_Đệm_SL (x TR)
input double          InpICTSLMaxTR        = 2.0;         // ICT_Khoảng_SL_tối_đa (x TR)
input double          InpICTSLMaxPrice     = 0.0;         // ICT_Khoảng_SL_tối_đa (giá, 0 = tắt)
input double          InpICTTPRR           = 3.0;         // ICT_TP_theo_R (1 lệnh duy nhất)
input double          InpICTBreakEvenR     = 0.0;         // ICT_Dời_SL_hòa_vốn_khi_đạt_R (0 = tắt)
input bool            InpICTTrailing       = true;        // ICT_Bật_trailing
input double          InpICTTrailActR      = 2.0;         // ICT_Trailing_kích_hoạt_khi_đạt_R
input double          InpICTTrailTR        = 1.5;         // ICT_Khoảng_trailing (x TR)
input double          InpICTTrailStep      = 0.05;        // ICT_Bước_dời_SL_tối_thiểu (giá)
input double          InpICTMaxSpread      = 0.50;        // ICT_Spread_tối_đa (giá, 0 = tắt)
input double          InpICTVolMin         = 0.3;         // ICT_Tỷ_lệ_TR_vào/xu_hướng_thấp_nhất
input double          InpICTVolMax         = 3.0;         // ICT_Tỷ_lệ_TR_vào/xu_hướng_cao_nhất
input int             InpICTServerUTC      = 0;           // ICT_Giờ_server_lệch_UTC (giờ, Exness = 0)
input bool            InpICTLondon         = true;        // ICT_Phiên_London (07:00-10:00 UTC)
input bool            InpICTNewYork        = true;        // ICT_Phiên_New_York (12:00-16:00 UTC)
input bool            InpICTOffKillzone    = false;       // ICT_Cho_phép_ngoài_Killzone
input bool            InpICTPowerHours     = true;        // ICT_Cộng_điểm_30_phút_đầu_phiên


//====================================================================
// ENUM
//====================================================================
enum ENUM_CRT_BIAS
{
   CRT_BIAS_NONE = 0,
   CRT_BIAS_BUY  = 1,
   CRT_BIAS_SELL = 2,
   CRT_BIAS_BOTH = 3
};

enum ENUM_CRT_STATUS
{
   ST_WAITING_RANGE = 0,
   ST_WAITING_SWEEP,
   ST_LOW_SWEPT,          // Low đã bị sweep nhưng BUY không được phép (bias / input)
   ST_HIGH_SWEPT,         // High đã bị sweep nhưng SELL không được phép (bias / input)
   ST_WAITING_M15,        // Đã sweep đúng phía có quyền trade, chờ M15 đóng trong Range
   ST_BUY_CONFIRMED,
   ST_SELL_CONFIRMED,
   ST_BUY_ACTIVE,
   ST_SELL_ACTIVE,
   ST_TRADED,
   ST_INVALID_BOTH,
   ST_EXPIRED,
   ST_RANGE_ERROR,
   ST_SIGNAL_SKIPPED      // Có tín hiệu nhưng bị bỏ do bộ lọc / lỗi broker / offline (Range đã dùng)
};

//====================================================================
// STATE CỦA RANGE ĐANG HOẠT ĐỘNG
//====================================================================
struct CRTState
{
   bool     valid;
   datetime refTime;          // Open time của H4[1] (Reference)
   datetime refEnd;           // refTime + 4h
   datetime activeStart;      // Open time của H4[0] (Active)
   datetime activeEnd;        // activeStart + 4h
   double   crtHigh;          // High H4[1] - KHÓA
   double   crtLow;           // Low  H4[1] - KHÓA
   double   h2High;           // High H4[2]
   double   h2Low;            // Low  H4[2]
   int      bias;             // ENUM_CRT_BIAS

   bool     lowSwept;
   bool     highSwept;
   double   sweepLow;
   double   sweepHigh;
   datetime sweepLowTime;
   datetime sweepHighTime;

   bool     confirmed;
   int      confirmDir;       // +1 BUY, -1 SELL
   datetime confirmBarTime;   // Open time của nến M15 xác nhận
   double   confirmClose;

   bool     traded;
   int      tradeDir;
   ulong    positionId;
   datetime entryTime;
   double   entryPrice;       // Giá khớp thực tế
   double   slPrice;
   double   tpPrice;
   double   rr;
   double   lots;

   int      status;           // ENUM_CRT_STATUS
   string   skipReason;

   datetime lastM1Processed;  // M1 đã đóng cuối cùng được quét sweep
   datetime lastM15Processed; // M15 đã đóng cuối cùng được xét confirmation
};

//====================================================================
// GLOBAL
//====================================================================
CTrade   g_trade;
CRTState g;
bool     g_ready          = false;
bool     g_dirty          = false;
bool     g_isTester       = false;
bool     g_drawEnabled    = true;
datetime g_lastM1Seen     = 0;
datetime g_lastDashboard  = 0;
double   g_point          = 0.0;
string   g_stateFile      = "";

//====================================================================
// TIỆN ÍCH SO SÁNH GIÁ (tránh sai số double, vẫn giữ quy tắc < / > tuyệt đối)
//====================================================================
double PriceEps()                      { return g_point * 0.5; }
bool   PriceLess(double a, double b)   { return (a < b - PriceEps()); }
bool   PriceGreater(double a, double b){ return (a > b + PriceEps()); }
bool   PriceEqual(double a, double b)  { return (MathAbs(a - b) <= PriceEps()); }

string Px(double p)        { return DoubleToString(p, _Digits); }
string TimeHM(datetime t)  { return (t <= 0 ? "-" : StringSubstr(TimeToString(t, TIME_DATE | TIME_MINUTES), 11)); }
string TimeFull(datetime t){ return (t <= 0 ? "-" : TimeToString(t, TIME_DATE | TIME_MINUTES)); }
string YesNo(bool b)       { return (b ? "YES" : "NO"); }

string RangeId(datetime refTime)
{
   MqlDateTime d;
   TimeToStruct(refTime, d);
   return StringFormat("%04d%02d%02d_%02d%02d", d.year, d.mon, d.day, d.hour, d.min);
}

string ObjName(string type)
{
   return CRT_PREFIX + type + "_" + _Symbol + "_" + RangeId(g.refTime);
}

string StatusText(int s)
{
   switch(s)
   {
      case ST_WAITING_RANGE:  return "WAITING RANGE";
      case ST_WAITING_SWEEP:  return "WAITING SWEEP";
      case ST_LOW_SWEPT:      return "LOW SWEPT";
      case ST_HIGH_SWEPT:     return "HIGH SWEPT";
      case ST_WAITING_M15:    return "WAITING M15 CONFIRM";
      case ST_BUY_CONFIRMED:  return "BUY CONFIRMED";
      case ST_SELL_CONFIRMED: return "SELL CONFIRMED";
      case ST_BUY_ACTIVE:     return "BUY ACTIVE";
      case ST_SELL_ACTIVE:    return "SELL ACTIVE";
      case ST_TRADED:         return "TRADED";
      case ST_INVALID_BOTH:   return "INVALID BOTH SIDES";
      case ST_EXPIRED:        return "EXPIRED";
      case ST_RANGE_ERROR:    return "RANGE ERROR";
      case ST_SIGNAL_SKIPPED: return "SIGNAL SKIPPED";
   }
   return "UNKNOWN";
}

string BiasText(int b)
{
   switch(b)
   {
      case CRT_BIAS_BUY:  return "BUY";
      case CRT_BIAS_SELL: return "SELL";
      case CRT_BIAS_BOTH: return "BOTH";
   }
   return "NONE";
}

bool BuyPermitted()  { return (InpAllowBuy  && (g.bias == CRT_BIAS_BUY  || g.bias == CRT_BIAS_BOTH)); }
bool SellPermitted() { return (InpAllowSell && (g.bias == CRT_BIAS_SELL || g.bias == CRT_BIAS_BOTH)); }

//--- Range còn sống: được phép cập nhật sweep / xét confirmation / vào lệnh
bool RangeIsLive()
{
   if(!g.valid || g.traded)
      return false;
   return (g.status == ST_WAITING_SWEEP || g.status == ST_LOW_SWEPT ||
           g.status == ST_HIGH_SWEPT    || g.status == ST_WAITING_M15);
}

//====================================================================
// LOG
//====================================================================
void WriteCRTLog(string msg, bool detailOnly = false)
{
   if(detailOnly && !InpVerboseLog)
      return;
   Print("[DAVID CRT] ", msg);
}

void WriteCRTDebug(string msg)
{
   if(!InpDebug)
      return;
   Print("[CRT DEBUG] ", msg);
}

void MarkDirty() { g_dirty = true; }

//====================================================================
// RESET STATE
//====================================================================
void ResetState()
{
   g.valid            = false;
   g.refTime          = 0;
   g.refEnd           = 0;
   g.activeStart      = 0;
   g.activeEnd        = 0;
   g.crtHigh          = 0.0;
   g.crtLow           = 0.0;
   g.h2High           = 0.0;
   g.h2Low            = 0.0;
   g.bias             = CRT_BIAS_NONE;
   g.lowSwept         = false;
   g.highSwept        = false;
   g.sweepLow         = 0.0;
   g.sweepHigh        = 0.0;
   g.sweepLowTime     = 0;
   g.sweepHighTime    = 0;
   g.confirmed        = false;
   g.confirmDir       = 0;
   g.confirmBarTime   = 0;
   g.confirmClose     = 0.0;
   g.traded           = false;
   g.tradeDir         = 0;
   g.positionId       = 0;
   g.entryTime        = 0;
   g.entryPrice       = 0.0;
   g.slPrice          = 0.0;
   g.tpPrice          = 0.0;
   g.rr               = 0.0;
   g.lots             = 0.0;
   g.status           = ST_WAITING_RANGE;
   g.skipReason       = "";
   g.lastM1Processed  = 0;
   g.lastM15Processed = 0;
}

//====================================================================
// H4: PHÁT HIỆN CÂY H4 MỚI
// Trả về true khi H4[0] (theo đúng timestamp broker) khác Active hiện tại.
//====================================================================
bool DetectNewH4Bar()
{
   datetime h4Open0 = iTime(_Symbol, CRT_TF_RANGE, 0);
   if(h4Open0 <= 0)
      return false;               // dữ liệu H4 chưa sẵn sàng
   return (h4Open0 > g.activeStart);
}

//====================================================================
// H4: ĐỌC H4[0], H4[1], H4[2] (rates[0]=H4[0], rates[1]=H4[1], rates[2]=H4[2])
//====================================================================
bool LoadReferenceH4(MqlRates &h4[])
{
   ArraySetAsSeries(h4, true);
   ResetLastError();
   int copied = CopyRates(_Symbol, CRT_TF_RANGE, 0, 3, h4);
   if(copied != 3)
   {
      WriteCRTLog(StringFormat("CopyRates H4 thất bại (copied=%d, err=%d) - thử lại tick sau", copied, GetLastError()), true);
      return false;
   }
   if(!(h4[0].time > h4[1].time && h4[1].time > h4[2].time))
   {
      WriteCRTLog("Dữ liệu H4 sai thứ tự thời gian - thử lại tick sau", true);
      return false;
   }
   return true;
}

//====================================================================
// H4: BIAS - High H4[1] > High H4[2] => BUY ; Low H4[1] < Low H4[2] => SELL
//====================================================================
int DetectH4Bias(double h1High, double h1Low, double h2High, double h2Low)
{
   bool buy  = PriceGreater(h1High, h2High);
   bool sell = PriceLess(h1Low, h2Low);
   if(buy && sell) return CRT_BIAS_BOTH;
   if(buy)         return CRT_BIAS_BUY;
   if(sell)        return CRT_BIAS_SELL;
   return CRT_BIAS_NONE;
}

//====================================================================
// TẠO CRT RANGE TỪ H4[1] - chỉ gọi khi H4 mới bắt đầu (H4[1] đã đóng)
//====================================================================
void CreateCRTRange(const MqlRates &h4[])
{
   ResetState();
   int h4Sec = PeriodSeconds(CRT_TF_RANGE);

   g.refTime     = h4[1].time;
   g.refEnd      = h4[1].time + h4Sec;
   g.activeStart = h4[0].time;
   g.activeEnd   = h4[0].time + h4Sec;

   //--- CHỈ High / Low của Reference. Không Open/Close, không 50%, không ATR, không buffer.
   g.crtHigh = h4[1].high;
   g.crtLow  = h4[1].low;
   g.h2High  = h4[2].high;
   g.h2Low   = h4[2].low;

   g.lastM1Processed  = g.activeStart - PeriodSeconds(CRT_TF_REPLAY);
   g.lastM15Processed = 0;

   if(!(PriceGreater(g.crtHigh, g.crtLow)))
   {
      g.valid  = false;
      g.status = ST_RANGE_ERROR;
      WriteCRTLog(StringFormat("RANGE ERROR: Reference %s High=%s Low=%s không hợp lệ",
                               TimeFull(g.refTime), Px(g.crtHigh), Px(g.crtLow)));
      MarkDirty();
      return;
   }

   g.bias   = DetectH4Bias(g.crtHigh, g.crtLow, g.h2High, g.h2Low);
   g.valid  = true;
   g.status = ST_WAITING_SWEEP;
   MarkDirty();

   WriteCRTLog(StringFormat("CRT RANGE MỚI %s | Reference %s-%s | Active %s-%s | High=%s Low=%s | Bias=%s",
                            RangeId(g.refTime), TimeFull(g.refTime), TimeHM(g.refEnd),
                            TimeFull(g.activeStart), TimeHM(g.activeEnd),
                            Px(g.crtHigh), Px(g.crtLow), BiasText(g.bias)));
   WriteCRTDebug(StringFormat("Reference H4 Start: %s | Reference H4 End: %s | Reference High: %s | Reference Low: %s",
                              TimeFull(g.refTime), TimeFull(g.refEnd), Px(g.crtHigh), Px(g.crtLow)));
   WriteCRTDebug(StringFormat("Active Start: %s | Active End: %s | H4[2] (%s) High: %s | H4[2] Low: %s | Bias: %s",
                              TimeFull(g.activeStart), TimeFull(g.activeEnd), TimeFull(h4[2].time),
                              Px(g.h2High), Px(g.h2Low), BiasText(g.bias)));
}

//====================================================================
// CẬP NHẬT TRẠNG THÁI SAU KHI SWEEP THAY ĐỔI
//====================================================================
void RefreshStatusAfterSweep()
{
   if(!RangeIsLive())
      return;
   if(g.lowSwept && g.highSwept)
   {
      g.status = ST_INVALID_BOTH;
      WriteCRTLog(StringFormat("INVALID BOTH SIDES: Range %s - Sweep Low %s (%s) và Sweep High %s (%s) trước Entry",
                               RangeId(g.refTime), Px(g.sweepLow), TimeFull(g.sweepLowTime),
                               Px(g.sweepHigh), TimeFull(g.sweepHighTime)));
   }
   else if(g.lowSwept)
      g.status = (BuyPermitted() ? ST_WAITING_M15 : ST_LOW_SWEPT);
   else if(g.highSwept)
      g.status = (SellPermitted() ? ST_WAITING_M15 : ST_HIGH_SWEPT);
   else
      g.status = ST_WAITING_SWEEP;
   MarkDirty();
}

//====================================================================
// CẬP NHẬT CỰC TRỊ SWEEP (chỉ cập nhật khi xuyên sâu hơn - không look-ahead)
//====================================================================
bool UpdateSweepExtreme(bool isLow, double price, datetime t)
{
   if(isLow)
   {
      if(PriceLess(price, g.sweepLow))
      {
         g.sweepLow     = price;
         g.sweepLowTime = t;
         WriteCRTLog(StringFormat("Sweep Low cập nhật: %s @ %s", Px(price), TimeToString(t, TIME_DATE | TIME_SECONDS)), true);
         return true;
      }
   }
   else
   {
      if(PriceGreater(price, g.sweepHigh))
      {
         g.sweepHigh     = price;
         g.sweepHighTime = t;
         WriteCRTLog(StringFormat("Sweep High cập nhật: %s @ %s", Px(price), TimeToString(t, TIME_DATE | TIME_SECONDS)), true);
         return true;
      }
   }
   return false;
}

//====================================================================
// NHẬN DIỆN SWEEP: Low < CRT_Low (strict) ; High > CRT_High (strict)
// low/high: giá đã thực sự xảy ra (tick Bid hoặc M1 đã đóng trong Active).
//====================================================================
void DetectLiquiditySweep(double low, double high, datetime tLow, datetime tHigh)
{
   if(!RangeIsLive())
      return;

   bool changed = false;

   if(PriceLess(low, g.crtLow))
   {
      if(!g.lowSwept)
      {
         g.lowSwept     = true;
         g.sweepLow     = low;
         g.sweepLowTime = tLow;
         changed        = true;
         WriteCRTLog(StringFormat("SWEEP LOW: %s < CRT Low %s @ %s", Px(low), Px(g.crtLow),
                                  TimeToString(tLow, TIME_DATE | TIME_SECONDS)));
      }
      else if(UpdateSweepExtreme(true, low, tLow))
         changed = true;
   }

   if(PriceGreater(high, g.crtHigh))
   {
      if(!g.highSwept)
      {
         g.highSwept     = true;
         g.sweepHigh     = high;
         g.sweepHighTime = tHigh;
         changed         = true;
         WriteCRTLog(StringFormat("SWEEP HIGH: %s > CRT High %s @ %s", Px(high), Px(g.crtHigh),
                                  TimeToString(tHigh, TIME_DATE | TIME_SECONDS)));
      }
      else if(UpdateSweepExtreme(false, high, tHigh))
         changed = true;
   }

   if(changed)
   {
      RefreshStatusAfterSweep();
      if(g.lowSwept)  DrawSweepMarker(true);
      if(g.highSwept) DrawSweepMarker(false);
      MarkDirty();
   }
}

//====================================================================
// BỎ TÍN HIỆU (Range coi như đã dùng)
//====================================================================
void SkipSignal(string reason)
{
   g.status     = ST_SIGNAL_SKIPPED;
   g.skipReason = reason;
   WriteCRTLog(reason + " | Range " + RangeId(g.refTime) + " coi như đã dùng");
   MarkDirty();
}

//====================================================================
// QUÉT LẠI CÁC NẾN M1 ĐÃ ĐÓNG TRONG ACTIVE H4
//  - Bù tick bị lỡ khi live / khôi phục khi restart.
//  - evaluateConfirm = true: (chỉ khi khởi tạo / restart) xét luôn các nến M15
//    đã đóng trong khoảng offline. Nếu có confirmation bị lỡ -> SIGNAL SKIPPED
//    (KHÔNG vào lệnh muộn).
//  - Chỉ dùng nến M1 ĐÃ ĐÓNG (time < M1[0]) -> không look-ahead.
//====================================================================
void ReplayClosedM1(bool evaluateConfirm)
{
   if(!g.valid)
      return;

   int      m1Sec  = PeriodSeconds(CRT_TF_REPLAY);
   int      m15Sec = PeriodSeconds(CRT_TF_CONFIRM);
   datetime m1Open0 = iTime(_Symbol, CRT_TF_REPLAY, 0);
   if(m1Open0 <= 0)
      return;

   datetime from = g.lastM1Processed + m1Sec;
   if(from < g.activeStart)
      from = g.activeStart;
   datetime to = m1Open0 - 1;            // chỉ nến đã đóng
   if(to > g.activeEnd - 1)
      to = g.activeEnd - 1;             // không vượt Active End
   if(from > to)
      return;

   MqlRates m1[];
   ArraySetAsSeries(m1, false);
   ResetLastError();
   int n = CopyRates(_Symbol, CRT_TF_REPLAY, from, to, m1);
   if(n <= 0)
   {
      WriteCRTLog(StringFormat("CopyRates M1 thất bại (%s -> %s, err=%d)", TimeFull(from), TimeFull(to), GetLastError()), true);
      return;
   }

   for(int i = 0; i < n; i++)
   {
      if(m1[i].time < from || m1[i].time > to)
         continue;

      if(RangeIsLive())
         DetectLiquiditySweep(m1[i].low, m1[i].high, m1[i].time, m1[i].time);

      g.lastM1Processed = m1[i].time;

      if(evaluateConfirm)
      {
         datetime endT = m1[i].time + m1Sec;
         if(((long)endT % m15Sec) == 0)
         {
            datetime m15Open = endT - m15Sec;
            if(m15Open > g.lastM15Processed)
            {
               double c = m1[i].close;
               int sh = iBarShift(_Symbol, CRT_TF_CONFIRM, m15Open, true);
               if(sh >= 1)
                  c = iClose(_Symbol, CRT_TF_CONFIRM, sh);
               if(RangeIsLive())
                  CheckM15Confirmation(m15Open, c, false);
               g.lastM15Processed = m15Open;
            }
         }
      }
   }
   MarkDirty();
}

//====================================================================
// M15: PHÁT HIỆN NẾN M15 MỚI ĐÓNG -> trả về M15[1]
//====================================================================
bool DetectNewM15Bar(MqlRates &closedBar)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, CRT_TF_CONFIRM, 1, 1, r) != 1)   // shift 1 = nến vừa đóng
      return false;
   if(r[0].time <= g.lastM15Processed)
      return false;
   closedBar = r[0];
   g.lastM15Processed = r[0].time;
   MarkDirty();
   return true;
}

//====================================================================
// M15 CONFIRMATION
//  BUY : đã Sweep Low, chưa Sweep High, BUY được phép,
//        CRT_Low < Close < CRT_High
//  SELL: đã Sweep High, chưa Sweep Low, SELL được phép,
//        CRT_Low < Close < CRT_High
//  Nến M15 phải nằm trong Active và ĐÓNG TRƯỚC Active End.
//  liveMode=false: confirmation xảy ra lúc EA offline -> bỏ (không vào muộn).
//====================================================================
bool CheckM15Confirmation(datetime barOpen, double barClose, bool liveMode)
{
   if(!RangeIsLive())
      return false;

   int      m15Sec   = PeriodSeconds(CRT_TF_CONFIRM);
   datetime barClose_t = barOpen + m15Sec;

   if(barOpen < g.activeStart || barClose_t >= g.activeEnd)
      return false;

   if(!g.lowSwept && !g.highSwept)
      return false;   // chưa có sweep -> không cần xét

   int  dir    = 0;
   bool inside = (PriceGreater(barClose, g.crtLow) && PriceLess(barClose, g.crtHigh));

   if(g.lowSwept && !g.highSwept && BuyPermitted() && inside)
      dir = +1;
   else if(g.highSwept && !g.lowSwept && SellPermitted() && inside)
      dir = -1;

   WriteCRTDebug(StringFormat("Last Closed M15: %s-%s | M15 Close: %s | CRT %s-%s | Bias: %s | Sweep Low: %s (%s) | Sweep High: %s (%s) | Confirmation: %s",
                              TimeFull(barOpen), TimeHM(barClose_t), Px(barClose),
                              Px(g.crtLow), Px(g.crtHigh), BiasText(g.bias),
                              YesNo(g.lowSwept),  (g.lowSwept  ? Px(g.sweepLow)  : "-"),
                              YesNo(g.highSwept), (g.highSwept ? Px(g.sweepHigh) : "-"),
                              (dir > 0 ? "VALID BUY" : (dir < 0 ? "VALID SELL" : "NO"))));

   if(dir == 0)
      return false;

   //--- Sweep phải xảy ra trước khi nến xác nhận đóng
   datetime sweepT = (dir > 0 ? g.sweepLowTime : g.sweepHighTime);
   if(sweepT >= barClose_t)
      return false;

   //--- Bộ lọc độ sâu sweep (mặc định tắt)
   double depth = (dir > 0 ? g.crtLow - g.sweepLow : g.sweepHigh - g.crtHigh);
   if(InpMinSweep > 0.0 && depth < InpMinSweep - PriceEps())
   {
      WriteCRTLog(StringFormat("Confirmation bị bỏ qua: độ sâu sweep %s < Sweep_tối_thiểu %s (tiếp tục chờ)",
                               DoubleToString(depth, _Digits), DoubleToString(InpMinSweep, _Digits)));
      return false;
   }

   g.confirmed      = true;
   g.confirmDir     = dir;
   g.confirmBarTime = barOpen;
   g.confirmClose   = barClose;
   g.status         = (dir > 0 ? ST_BUY_CONFIRMED : ST_SELL_CONFIRMED);
   MarkDirty();
   DrawConfirmationMarker();

   WriteCRTLog(StringFormat("M15 CONFIRM %s: nến %s-%s Close=%s nằm trong %s-%s | Sweep=%s",
                            (dir > 0 ? "BUY" : "SELL"), TimeFull(barOpen), TimeHM(barClose_t), Px(barClose),
                            Px(g.crtLow), Px(g.crtHigh), Px(dir > 0 ? g.sweepLow : g.sweepHigh)));

   if(InpMaxSweep > 0.0 && depth > InpMaxSweep + PriceEps())
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO SWEEP QUÁ SÂU (%s > %s)",
                              DoubleToString(depth, _Digits), DoubleToString(InpMaxSweep, _Digits)));
      return false;
   }

   if(!liveMode)
   {
      SkipSignal("CRT SIGNAL BỊ BỎ QUA: CONFIRMATION XẢY RA KHI EA OFFLINE - KHÔNG VÀO LỆNH MUỘN");
      return false;
   }
   return true;
}

//====================================================================
// VALIDATE RANGE NGAY TRƯỚC ORDERSEND
//====================================================================
bool ValidateCRTRangeBeforeTrade(datetime now)
{
   if(!g.valid)
      return false;

   //--- H4[0] vẫn phải là Active, H4[1] vẫn phải là Reference
   datetime h4Open0 = iTime(_Symbol, CRT_TF_RANGE, 0);
   if(h4Open0 != g.activeStart)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: H4[0]=%s khác Active Start=%s",
                               TimeFull(h4Open0), TimeFull(g.activeStart)));
      return false;
   }

   int shift = iBarShift(_Symbol, CRT_TF_RANGE, g.refTime, true);
   if(shift != 1)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: Reference %s không phải H4[1] (shift=%d)",
                               TimeFull(g.refTime), shift));
      return false;
   }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, CRT_TF_RANGE, 1, 2, r) != 2)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: không đọc lại được H4[1]/H4[2]");
      return false;
   }
   if(r[0].time != g.refTime || !PriceEqual(r[0].high, g.crtHigh) || !PriceEqual(r[0].low, g.crtLow))
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: stored %s-%s / source %s High=%s Low=%s",
                               Px(g.crtLow), Px(g.crtHigh), TimeFull(r[0].time), Px(r[0].high), Px(r[0].low)));
      return false;
   }
   if(DetectH4Bias(r[0].high, r[0].low, r[1].high, r[1].low) != g.bias)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: Bias đọc lại khác Bias đã lưu");
      return false;
   }
   if(now < g.activeStart || now >= g.activeEnd)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: thời gian %s ngoài Active %s-%s",
                               TimeFull(now), TimeFull(g.activeStart), TimeHM(g.activeEnd)));
      return false;
   }
   if(g.lowSwept && g.highSwept)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: cả hai phía đã bị sweep");
      return false;
   }
   if(g.traded)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: Range đã TRADED");
      return false;
   }
   return true;
}

//====================================================================
// KHỐI LƯỢNG
//====================================================================
int VolumeDigits(double step)
{
   int    d = 0;
   double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9)
   {
      s *= 10.0;
      d++;
   }
   return d;
}

double NormalizeVolumeDown(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   double v = MathFloor(lots / step + 1e-9) * step;
   return NormalizeDouble(v, VolumeDigits(step));
}

// Trả về lot hợp lệ, hoặc 0 nếu phải bỏ lệnh (lý do ghi vào reason)
double CalculateRiskLot(int dir, double entry, double sl, string &reason)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lots   = 0.0;

   if(!InpUseRiskEquity)
   {
      lots = NormalizeVolumeDown(InpFixedLot);
      if(lots < minLot - 1e-9)
      {
         reason = StringFormat("Khối_lượng_cố_định %.4f < Volume Min %.4f", InpFixedLot, minLot);
         return 0.0;
      }
      if(lots > maxLot)
      {
         WriteCRTLog(StringFormat("Khối lượng %.4f > Volume Max %.4f -> dùng Volume Max", lots, maxLot));
         lots = NormalizeVolumeDown(maxLot);
      }
      return lots;
   }

   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPercent / 100.0;
   double distance  = MathAbs(entry - sl);
   if(riskMoney <= 0.0 || distance <= 0.0)
   {
      reason = "Không tính được risk (equity / khoảng cách SL = 0)";
      return 0.0;
   }

   //--- Lỗ cho 1 lot nếu chạm SL: ưu tiên OrderCalcProfit (đã gồm quy đổi tiền tệ)
   double lossPerLot = 0.0;
   double profit     = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) && profit < 0.0)
      lossPerLot = -profit;
   else
   {
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tickValue <= 0.0)
         tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0)
         lossPerLot = (distance / tickSize) * tickValue;
   }
   if(lossPerLot <= 0.0)
   {
      reason = "Không tính được giá trị lỗ mỗi lot (tick size / tick value)";
      return 0.0;
   }

   double rawLots = riskMoney / lossPerLot;
   lots = NormalizeVolumeDown(rawLots);   // làm tròn XUỐNG -> không vượt risk

   WriteCRTLog(StringFormat("Risk lot: Equity=%.2f Risk=%.2f%% (%.2f) | SL dist=%s | Loss/lot=%.2f | Raw=%.4f -> %.4f",
                            equity, InpRiskPercent, riskMoney, DoubleToString(distance, _Digits),
                            lossPerLot, rawLots, lots), true);

   if(lots < minLot - 1e-9)
   {
      reason = StringFormat("Lot theo risk %.4f < Volume Min %.4f (dùng Min sẽ lỗ %.2f > risk %.2f)",
                            rawLots, minLot, minLot * lossPerLot, riskMoney);
      return 0.0;
   }
   if(lots > maxLot)
      lots = NormalizeVolumeDown(maxLot);
   return lots;
}

//====================================================================
// GIÁ
//====================================================================
double NormalizePrice(double p)
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0.0)
      p = MathRound(p / ts) * ts;
   return NormalizeDouble(p, _Digits);
}

//====================================================================
// TÌM POSITION THEO ID (chỉ Symbol + Magic của EA)
//====================================================================
bool SelectPositionById(ulong posId)
{
   if(posId == 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId)
         return true;
   }
   return false;
}

//====================================================================
// THỰC HIỆN LỆNH
//====================================================================
bool ExecuteCRTTrade(int dir, const MqlTick &tick)
{
   if(g.traded)
      return false;

   string side = (dir > 0 ? "BUY" : "SELL");

   //--- 1. Spread
   double spread = tick.ask - tick.bid;
   if(InpMaxSpread > 0.0 && spread > InpMaxSpread + PriceEps())
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO SPREAD (%s > %s)",
                              DoubleToString(spread, _Digits), DoubleToString(InpMaxSpread, _Digits)));
      return false;
   }

   //--- 2. Validate Range
   if(!ValidateCRTRangeBeforeTrade(tick.time))
   {
      g.status     = ST_RANGE_ERROR;
      g.skipReason = "CRT RANGE VALIDATION FAILED";
      MarkDirty();
      return false;
   }

   //--- 3. Entry / SL / TP theo chiến lược
   double price = (dir > 0 ? tick.ask : tick.bid);
   double sl    = NormalizePrice(dir > 0 ? g.sweepLow - InpSLBuffer : g.sweepHigh + InpSLBuffer);
   double tp    = NormalizePrice(dir > 0 ? g.crtHigh : g.crtLow);

   if(dir > 0 && !(sl < price && price < tp))
   {
      SkipSignal(StringFormat("BUY bỏ: hình học không hợp lệ (SL %s / Ask %s / TP %s)", Px(sl), Px(price), Px(tp)));
      return false;
   }
   if(dir < 0 && !(tp < price && price < sl))
   {
      SkipSignal(StringFormat("SELL bỏ: hình học không hợp lệ (TP %s / Bid %s / SL %s)", Px(tp), Px(price), Px(sl)));
      return false;
   }

   //--- 4. StopsLevel / FreezeLevel (SL/TP của BUY so với Bid, của SELL so với Ask)
   long   stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long   freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist     = (double)MathMax(stopsLevel, freezeLevel) * g_point;
   double ref         = (dir > 0 ? tick.bid : tick.ask);
   double slDist      = MathAbs(ref - sl);
   double tpDist      = MathAbs(tp - ref);
   if(slDist < minDist || tpDist < minDist)
   {
      SkipSignal(StringFormat("%s bỏ: SL/TP vi phạm StopsLevel/FreezeLevel (SL dist %s, TP dist %s, min %s) - không tự sửa SL chiến lược",
                              side, DoubleToString(slDist, _Digits), DoubleToString(tpDist, _Digits), DoubleToString(minDist, _Digits)));
      return false;
   }

   //--- 5. RR dự kiến
   double risk   = MathAbs(price - sl);
   double reward = MathAbs(tp - price);
   double rr     = (risk > 0.0 ? reward / risk : 0.0);
   if(InpMinRR > 0.0 && rr < InpMinRR)
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO RR %.2f < RR_tối_thiểu %.2f", rr, InpMinRR));
      return false;
   }

   //--- 6. Khối lượng
   string lotReason = "";
   double lots = CalculateRiskLot(dir, price, sl, lotReason);
   if(lots <= 0.0)
   {
      SkipSignal("CRT SIGNAL BỊ BỎ QUA DO VOLUME: " + lotReason);
      return false;
   }

   //--- 7. Margin
   double margin = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lots, price, margin))
   {
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      {
         SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO KHÔNG ĐỦ MARGIN (cần %.2f)", margin));
         return false;
      }
   }

   //--- 8. Khóa Range TRƯỚC khi gửi lệnh -> không bao giờ gửi lệnh lặp
   g.traded   = true;
   g.tradeDir = dir;
   MarkDirty();
   SaveCRTState();

   //--- Comment riêng của CRT kèm SĐT/Tele (tối đa 31 ký tự)
   string comment = StratComment(S_CRT);

   WriteCRTLog(StringFormat("GỬI %s %.2f lot | Giá tham chiếu %s | SL %s | TP %s | RR dự kiến 1:%.2f | Spread %s",
                            side, lots, Px(price), Px(sl), Px(tp), rr, DoubleToString(spread, _Digits)));

   bool sent = (dir > 0 ? g_trade.Buy(lots, _Symbol, 0.0, sl, tp, comment)
                        : g_trade.Sell(lots, _Symbol, 0.0, sl, tp, comment));
   uint rc = g_trade.ResultRetcode();

   if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
   {
      g.traded = false;   // không có lệnh thật
      SkipSignal(StringFormat("ORDER %s THẤT BẠI retcode=%u (%s) - không gửi lại", side, rc, g_trade.ResultRetcodeDescription()));
      return false;
   }

   //--- 9. Đọc giá khớp THỰC TẾ
   double   fill  = g_trade.ResultPrice();
   datetime ft    = tick.time;
   ulong    deal  = g_trade.ResultDeal();
   ulong    posId = 0;
   double   vol   = g_trade.ResultVolume();

   if(deal > 0 && HistoryDealSelect(deal))
   {
      double dp = HistoryDealGetDouble(deal, DEAL_PRICE);
      if(dp > 0.0)
         fill = dp;
      ft    = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      double dv = HistoryDealGetDouble(deal, DEAL_VOLUME);
      if(dv > 0.0)
         vol = dv;
   }
   if(posId == 0)
      posId = g_trade.ResultOrder();

   double actualSL = sl;
   double actualTP = tp;
   if(SelectPositionById(posId))
   {
      double po = PositionGetDouble(POSITION_PRICE_OPEN);
      if(po > 0.0)
         fill = po;
      actualSL = PositionGetDouble(POSITION_SL);
      actualTP = PositionGetDouble(POSITION_TP);
   }
   if(fill <= 0.0)
      fill = price;   // dự phòng cuối cùng; sẽ được làm mới từ position ở tick sau

   g.positionId = posId;
   g.entryTime  = ft;
   g.entryPrice = fill;
   g.slPrice    = actualSL;
   g.tpPrice    = actualTP;
   g.lots       = (vol > 0.0 ? vol : lots);
   double aRisk   = MathAbs(fill - actualSL);
   double aReward = MathAbs(actualTP - fill);
   g.rr         = (aRisk > 0.0 ? aReward / aRisk : 0.0);
   g.status     = (dir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE);
   MarkDirty();

   WriteCRTLog(StringFormat("%s ENTRY KHỚP %s @ %s | SL %s | TP %s | Risk %s | Reward %s | RR 1:%.2f | Position #%I64u",
                            side, DoubleToString(g.lots, 2), Px(fill), Px(actualSL), Px(actualTP),
                            DoubleToString(aRisk, _Digits), DoubleToString(aReward, _Digits), g.rr, posId));

   DrawEntrySLTP();
   SaveCRTState();
   return true;
}

//====================================================================
// THEO DÕI POSITION CỦA RANGE HIỆN TẠI
//====================================================================
void MonitorPosition()
{
   if(!g.traded)
      return;
   if(g.status != ST_BUY_ACTIVE && g.status != ST_SELL_ACTIVE)
      return;

   if(SelectPositionById(g.positionId))
   {
      double po = PositionGetDouble(POSITION_PRICE_OPEN);
      if(po > 0.0 && !PriceEqual(po, g.entryPrice))
      {
         g.entryPrice = po;
         double r = MathAbs(g.entryPrice - g.slPrice);
         g.rr = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
         DrawEntrySLTP();
         MarkDirty();
      }
      return;
   }

   g.status = ST_TRADED;
   WriteCRTLog(StringFormat("Position #%I64u của Range %s đã đóng -> TRADED", g.positionId, RangeId(g.refTime)));
   MarkDirty();
}

//====================================================================
// KHÔI PHỤC TRẠNG THÁI ĐÃ TRADE TỪ TERMINAL (position / history)
// Lệnh của Range = deal IN có Symbol + Magic đúng, thời gian trong Active.
//====================================================================
void RestoreTradeFromTerminal()
{
   if(!g.valid)
      return;

   //--- Position đang mở
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      datetime pt = (datetime)PositionGetInteger(POSITION_TIME);
      if(pt < g.activeStart || pt >= g.activeEnd)
         continue;

      g.traded     = true;
      g.tradeDir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
      g.positionId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      g.entryTime  = pt;
      g.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      g.slPrice    = PositionGetDouble(POSITION_SL);
      g.tpPrice    = PositionGetDouble(POSITION_TP);
      g.lots       = PositionGetDouble(POSITION_VOLUME);
      double r     = MathAbs(g.entryPrice - g.slPrice);
      g.rr         = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
      g.status     = (g.tradeDir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE);
      MarkDirty();
      WriteCRTLog(StringFormat("KHÔI PHỤC: Range %s đã có position mở #%I64u -> %s", RangeId(g.refTime), g.positionId, StatusText(g.status)));
      return;
   }

   //--- Deal đã đóng trong lịch sử
   if(!HistorySelect(g.activeStart, TimeCurrent() + 60))
      return;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(d, DEAL_MAGIC) != (long)InpMagic)
         continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      datetime dt = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(dt < g.activeStart || dt >= g.activeEnd)
         continue;

      g.traded     = true;
      g.tradeDir   = (HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BUY ? 1 : -1);
      g.positionId = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      g.entryTime  = dt;
      g.entryPrice = HistoryDealGetDouble(d, DEAL_PRICE);
      g.slPrice    = HistoryDealGetDouble(d, DEAL_SL);
      g.tpPrice    = HistoryDealGetDouble(d, DEAL_TP);
      g.lots       = HistoryDealGetDouble(d, DEAL_VOLUME);
      double r     = MathAbs(g.entryPrice - g.slPrice);
      g.rr         = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
      g.status     = (SelectPositionById(g.positionId) ? (g.tradeDir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE) : ST_TRADED);
      MarkDirty();
      WriteCRTLog(StringFormat("KHÔI PHỤC: Range %s đã có deal vào lệnh #%I64u -> %s", RangeId(g.refTime), d, StatusText(g.status)));
      return;
   }
}

//====================================================================
// LƯU / KHÔI PHỤC STATE (file text trong MQL5\Files)
//====================================================================
void WriteKV(int h, string key, string value)
{
   FileWriteString(h, key + "=" + value + "\r\n");
}

string D2S(double v)    { return DoubleToString(v, 8); }
string T2S(datetime t)  { return IntegerToString((long)t); }
string B2S(bool b)      { return (b ? "1" : "0"); }

void SaveCRTState()
{
   if(g_isTester)          // Strategy Tester không có restart -> không ghi file
      return;
   if(g.refTime <= 0)
      return;

   int h = FileOpen(g_stateFile, FILE_WRITE | FILE_TXT | FILE_UNICODE);
   if(h == INVALID_HANDLE)
   {
      WriteCRTLog(StringFormat("Không ghi được state file %s (err=%d)", g_stateFile, GetLastError()), true);
      return;
   }
   WriteKV(h, "version",          "1");
   WriteKV(h, "symbol",           _Symbol);
   WriteKV(h, "magic",            IntegerToString((long)InpMagic));
   WriteKV(h, "valid",            B2S(g.valid));
   WriteKV(h, "refTime",          T2S(g.refTime));
   WriteKV(h, "activeStart",      T2S(g.activeStart));
   WriteKV(h, "crtHigh",          D2S(g.crtHigh));
   WriteKV(h, "crtLow",           D2S(g.crtLow));
   WriteKV(h, "lowSwept",         B2S(g.lowSwept));
   WriteKV(h, "highSwept",        B2S(g.highSwept));
   WriteKV(h, "sweepLow",         D2S(g.sweepLow));
   WriteKV(h, "sweepHigh",        D2S(g.sweepHigh));
   WriteKV(h, "sweepLowTime",     T2S(g.sweepLowTime));
   WriteKV(h, "sweepHighTime",    T2S(g.sweepHighTime));
   WriteKV(h, "confirmed",        B2S(g.confirmed));
   WriteKV(h, "confirmDir",       IntegerToString(g.confirmDir));
   WriteKV(h, "confirmBarTime",   T2S(g.confirmBarTime));
   WriteKV(h, "confirmClose",     D2S(g.confirmClose));
   WriteKV(h, "traded",           B2S(g.traded));
   WriteKV(h, "tradeDir",         IntegerToString(g.tradeDir));
   WriteKV(h, "positionId",       IntegerToString((long)g.positionId));
   WriteKV(h, "entryTime",        T2S(g.entryTime));
   WriteKV(h, "entryPrice",       D2S(g.entryPrice));
   WriteKV(h, "slPrice",          D2S(g.slPrice));
   WriteKV(h, "tpPrice",          D2S(g.tpPrice));
   WriteKV(h, "rr",               D2S(g.rr));
   WriteKV(h, "lots",             D2S(g.lots));
   WriteKV(h, "status",           IntegerToString(g.status));
   WriteKV(h, "skipReason",       g.skipReason);
   WriteKV(h, "lastM1Processed",  T2S(g.lastM1Processed));
   WriteKV(h, "lastM15Processed", T2S(g.lastM15Processed));
   FileClose(h);
}

// Chỉ khôi phục khi state file thuộc ĐÚNG Range hiện tại (cùng Reference time + High/Low)
bool RestoreCRTState()
{
   if(g_isTester || !g.valid)
      return false;
   if(!FileIsExist(g_stateFile))
      return false;

   int h = FileOpen(g_stateFile, FILE_READ | FILE_TXT | FILE_UNICODE);
   if(h == INVALID_HANDLE)
      return false;

   string keys[];
   string vals[];
   int    n = 0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      int p = StringFind(line, "=");
      if(p <= 0)
         continue;
      ArrayResize(keys, n + 1);
      ArrayResize(vals, n + 1);
      keys[n] = StringSubstr(line, 0, p);
      vals[n] = StringSubstr(line, p + 1);
      StringTrimRight(vals[n]);
      n++;
   }
   FileClose(h);

   string sSymbol = "", sMagic = "", sRef = "", sHigh = "", sLow = "";
   for(int i = 0; i < n; i++)
   {
      if(keys[i] == "symbol")  sSymbol = vals[i];
      if(keys[i] == "magic")   sMagic  = vals[i];
      if(keys[i] == "refTime") sRef    = vals[i];
      if(keys[i] == "crtHigh") sHigh   = vals[i];
      if(keys[i] == "crtLow")  sLow    = vals[i];
   }
   if(sSymbol != _Symbol || sMagic != IntegerToString((long)InpMagic))
      return false;
   if((datetime)StringToInteger(sRef) != g.refTime)
   {
      WriteCRTLog("State file thuộc Range cũ -> bỏ qua, dùng Range mới từ H4[1]", true);
      return false;
   }
   if(!PriceEqual(StringToDouble(sHigh), g.crtHigh) || !PriceEqual(StringToDouble(sLow), g.crtLow))
   {
      WriteCRTLog("State file có High/Low khác dữ liệu H4[1] -> bỏ qua state", true);
      return false;
   }

   for(int i = 0; i < n; i++)
   {
      string k = keys[i];
      string v = vals[i];
      if(k == "lowSwept")         g.lowSwept         = (v == "1");
      if(k == "highSwept")        g.highSwept        = (v == "1");
      if(k == "sweepLow")         g.sweepLow         = StringToDouble(v);
      if(k == "sweepHigh")        g.sweepHigh        = StringToDouble(v);
      if(k == "sweepLowTime")     g.sweepLowTime     = (datetime)StringToInteger(v);
      if(k == "sweepHighTime")    g.sweepHighTime    = (datetime)StringToInteger(v);
      if(k == "confirmed")        g.confirmed        = (v == "1");
      if(k == "confirmDir")       g.confirmDir       = (int)StringToInteger(v);
      if(k == "confirmBarTime")   g.confirmBarTime   = (datetime)StringToInteger(v);
      if(k == "confirmClose")     g.confirmClose     = StringToDouble(v);
      if(k == "traded")           g.traded           = (v == "1");
      if(k == "tradeDir")         g.tradeDir         = (int)StringToInteger(v);
      if(k == "positionId")       g.positionId       = (ulong)StringToInteger(v);
      if(k == "entryTime")        g.entryTime        = (datetime)StringToInteger(v);
      if(k == "entryPrice")       g.entryPrice       = StringToDouble(v);
      if(k == "slPrice")          g.slPrice          = StringToDouble(v);
      if(k == "tpPrice")          g.tpPrice          = StringToDouble(v);
      if(k == "rr")               g.rr               = StringToDouble(v);
      if(k == "lots")             g.lots             = StringToDouble(v);
      if(k == "status")           g.status           = (int)StringToInteger(v);
      if(k == "skipReason")       g.skipReason       = v;
      if(k == "lastM1Processed")  g.lastM1Processed  = (datetime)StringToInteger(v);
      if(k == "lastM15Processed") g.lastM15Processed = (datetime)StringToInteger(v);
   }

   //--- Restart giữa Confirmation và Entry: không gửi lại / không vào muộn.
   //    Nếu lệnh thực sự đã khớp, RestoreTradeFromTerminal() sẽ ghi đè trạng thái.
   if(g.status == ST_BUY_CONFIRMED || g.status == ST_SELL_CONFIRMED)
   {
      g.status     = ST_SIGNAL_SKIPPED;
      g.skipReason = "EA restart giữa Confirmation và Entry - không vào lệnh muộn";
   }
   if(g.lastM1Processed < g.activeStart - PeriodSeconds(CRT_TF_REPLAY))
      g.lastM1Processed = g.activeStart - PeriodSeconds(CRT_TF_REPLAY);

   WriteCRTLog(StringFormat("KHÔI PHỤC STATE Range %s: CRT %s-%s | Low Swept %s (%s) | High Swept %s (%s) | Status %s",
                            RangeId(g.refTime), Px(g.crtLow), Px(g.crtHigh),
                            YesNo(g.lowSwept), (g.lowSwept ? Px(g.sweepLow) : "-"),
                            YesNo(g.highSwept), (g.highSwept ? Px(g.sweepHigh) : "-"),
                            StatusText(g.status)));
   return true;
}

//====================================================================
// VẼ - HELPER
//====================================================================
void EnsureRect(string name, datetime t1, double p1, datetime t2, double p2, color clr, bool fill, ENUM_LINE_STYLE style, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void EnsureSegment(string name, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void EnsureText(string name, datetime t, double p, string text, color clr, ENUM_ANCHOR_POINT anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void EnsureArrow(string name, ENUM_OBJECT type, datetime t, double p, color clr, ENUM_ARROW_ANCHOR anchor, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, type, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

//====================================================================
// VẼ REFERENCE CANDLE (khung riêng, nhãn REFERENCE ONLY, tại refTime -> refEnd)
//====================================================================
void DrawReferenceCandle()
{
   if(!g_drawEnabled || !InpShowReference || !g.valid)
      return;
   string tip = StringFormat("CRT REFERENCE (REFERENCE ONLY) %s-%s H=%s L=%s",
                             TimeFull(g.refTime), TimeHM(g.refEnd), Px(g.crtHigh), Px(g.crtLow));
   EnsureRect(ObjName("REF"), g.refTime, g.crtHigh, g.refEnd, g.crtLow, clrDimGray, false, STYLE_DOT, tip);
   EnsureText(ObjName("REFLBL"), g.refTime, g.crtHigh, "CRT REFERENCE - REFERENCE ONLY", clrDimGray, ANCHOR_LEFT_LOWER);
}

//====================================================================
// VẼ ACTIVE CRT RECTANGLE: Time1 = Active Start @ CRT High, Time2 = Active End @ CRT Low
//====================================================================
void DrawCRTRange()
{
   if(!g_drawEnabled || !g.valid)
      return;
   string tip = StringFormat("ACTIVE CRT %s-%s | High %s | Low %s | Bias %s",
                             TimeFull(g.activeStart), TimeHM(g.activeEnd), Px(g.crtHigh), Px(g.crtLow), BiasText(g.bias));
   EnsureRect(ObjName("RANGE"), g.activeStart, g.crtHigh, g.activeEnd, g.crtLow, C'32,48,72', true, STYLE_SOLID, tip);
   EnsureText(ObjName("RANGELBL"), g.activeStart, g.crtHigh,
              "ACTIVE CRT " + TimeHM(g.activeStart) + "-" + TimeHM(g.activeEnd) + " [" + BiasText(g.bias) + "]",
              clrSilver, ANCHOR_LEFT_LOWER);
}

//====================================================================
// VẼ CRT HIGH / LOW: đoạn thẳng (không ray) Active Start -> Active End
//====================================================================
void DrawCRTHighLow()
{
   if(!g_drawEnabled || !g.valid)
      return;
   EnsureSegment(ObjName("HIGH"), g.activeStart, g.crtHigh, g.activeEnd, g.crtHigh, clrDodgerBlue, STYLE_SOLID, 2,
                 "CRT HIGH " + Px(g.crtHigh));
   EnsureSegment(ObjName("LOW"),  g.activeStart, g.crtLow,  g.activeEnd, g.crtLow,  clrOrangeRed, STYLE_SOLID, 2,
                 "CRT LOW " + Px(g.crtLow));
}

//====================================================================
// VẼ SWEEP MARKER tại (thời điểm, giá) cực trị sweep THỰC TẾ
//====================================================================
void DrawSweepMarker(bool isLow)
{
   if(!g_drawEnabled || !g.valid)
      return;
   if(isLow && g.lowSwept)
   {
      EnsureArrow(ObjName("SWEEPLOW"), OBJ_ARROW_UP, g.sweepLowTime, g.sweepLow, clrOrange, ANCHOR_TOP,
                  "SWEEP LOW " + Px(g.sweepLow) + " @ " + TimeToString(g.sweepLowTime, TIME_DATE | TIME_SECONDS));
      EnsureText(ObjName("SWEEPLOWLBL"), g.sweepLowTime, g.sweepLow, "SWEEP LOW " + Px(g.sweepLow), clrOrange, ANCHOR_LEFT_UPPER);
   }
   if(!isLow && g.highSwept)
   {
      EnsureArrow(ObjName("SWEEPHIGH"), OBJ_ARROW_DOWN, g.sweepHighTime, g.sweepHigh, clrOrange, ANCHOR_BOTTOM,
                  "SWEEP HIGH " + Px(g.sweepHigh) + " @ " + TimeToString(g.sweepHighTime, TIME_DATE | TIME_SECONDS));
      EnsureText(ObjName("SWEEPHIGHLBL"), g.sweepHighTime, g.sweepHigh, "SWEEP HIGH " + Px(g.sweepHigh), clrOrange, ANCHOR_LEFT_LOWER);
   }
}

//====================================================================
// VẼ M15 CONFIRMATION: đoạn ngang trên đúng nến M15 đã đóng (open -> open+15m) @ Close
//====================================================================
void DrawConfirmationMarker()
{
   if(!g_drawEnabled || !g.confirmed)
      return;
   datetime t2   = g.confirmBarTime + PeriodSeconds(CRT_TF_CONFIRM);
   string   side = (g.confirmDir > 0 ? "BUY" : "SELL");
   color    clr  = (g.confirmDir > 0 ? clrLime : clrMagenta);
   string   tip  = StringFormat("M15 CONFIRM %s | nến %s-%s | Close %s", side, TimeFull(g.confirmBarTime), TimeHM(t2), Px(g.confirmClose));
   EnsureSegment(ObjName("CONFIRM"), g.confirmBarTime, g.confirmClose, t2, g.confirmClose, clr, STYLE_SOLID, 4, tip);
   EnsureText(ObjName("CONFIRMLBL"), g.confirmBarTime, g.confirmClose,
              "M15 CONFIRM " + side + " " + Px(g.confirmClose), clr,
              (g.confirmDir > 0 ? ANCHOR_RIGHT_UPPER : ANCHOR_RIGHT_LOWER));
}

//====================================================================
// VẼ ENTRY (giá khớp thật) / SL / TP
//====================================================================
void DrawEntrySLTP()
{
   if(!g_drawEnabled || !g.traded || g.entryPrice <= 0.0)
      return;
   string   side = (g.tradeDir > 0 ? "BUY" : "SELL");
   datetime tEnd = g.activeEnd;
   if(tEnd <= g.entryTime)
      tEnd = g.entryTime + PeriodSeconds(CRT_TF_CONFIRM);

   EnsureArrow(ObjName("ENTRY"), (g.tradeDir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL), g.entryTime, g.entryPrice,
               (g.tradeDir > 0 ? clrLime : clrMagenta), ANCHOR_TOP, side + " ENTRY " + Px(g.entryPrice));
   EnsureText(ObjName("ENTRYLBL"), g.entryTime, g.entryPrice, "  " + side + " ENTRY " + Px(g.entryPrice),
              (g.tradeDir > 0 ? clrLime : clrMagenta), ANCHOR_LEFT);
   if(g.slPrice > 0.0)
   {
      EnsureSegment(ObjName("SL"), g.entryTime, g.slPrice, tEnd, g.slPrice, clrRed, STYLE_DASH, 1, "SL " + Px(g.slPrice));
      EnsureText(ObjName("SLLBL"), tEnd, g.slPrice, "SL " + Px(g.slPrice), clrRed, ANCHOR_RIGHT_UPPER);
   }
   if(g.tpPrice > 0.0)
   {
      EnsureSegment(ObjName("TP"), g.entryTime, g.tpPrice, tEnd, g.tpPrice, clrLimeGreen, STYLE_DASH, 1, "TP " + Px(g.tpPrice));
      EnsureText(ObjName("TPLBL"), tEnd, g.tpPrice, "TP " + Px(g.tpPrice), clrLimeGreen, ANCHOR_RIGHT_LOWER);
   }
}

//====================================================================
// XÓA TOÀN BỘ HÌNH VẼ CỦA SETUP HIỆN TẠI SAU KHI POSITION ĐÃ ĐÓNG.
// CHỈ LÀ HIỂN THỊ: không reset g.traded, không thay đổi Range, không cho vào lại.
//====================================================================
void DeleteCurrentSetupVisuals()
{
   if(g.refTime <= 0)
      return;

   string types[] =
   {
      "REF", "REFLBL", "RANGE", "RANGELBL", "HIGH", "LOW",
      "SWEEPLOW", "SWEEPLOWLBL", "SWEEPHIGH", "SWEEPHIGHLBL",
      "CONFIRM", "CONFIRMLBL", "ENTRY", "ENTRYLBL",
      "SL", "SLLBL", "TP", "TPLBL"
   };

   for(int i = 0; i < ArraySize(types); i++)
      ObjectDelete(0, ObjName(types[i]));
}

void DrawAllForCurrentRange()
{
   if(!g_drawEnabled || !g.valid)
      return;

   // Position của setup đã đóng: dọn setup khỏi chart ngay.
   // State g.traded vẫn giữ nguyên để tuyệt đối không mở lại trong cùng CRT Range.
   if(g.status == ST_TRADED)
   {
      DeleteCurrentSetupVisuals();
      ChartRedraw(0);
      return;
   }

   DrawReferenceCandle();
   DrawCRTRange();
   DrawCRTHighLow();
   DrawSweepMarker(true);
   DrawSweepMarker(false);
   DrawConfirmationMarker();
   DrawEntrySLTP();
   ChartRedraw(0);
}

//====================================================================
// XÓA OBJECT CỦA CÁC RANGE CŨ NHẤT (giữ InpHistoryCount Range gần nhất)
// Tên object: DAVIDCRT_<TYPE>_<SYMBOL>_<YYYYMMDD>_<HHMM>
//====================================================================
long ObjectRangeKey(string name)
{
   int len = StringLen(name);
   if(len < 13)
      return -1;
   string id = StringSubstr(name, len - 13);      // YYYYMMDD_HHMM
   if(StringSubstr(id, 8, 1) != "_")
      return -1;
   return StringToInteger(StringSubstr(id, 0, 8) + StringSubstr(id, 9, 4));
}

void DeleteOldCRTObjects()
{
   if(!g_drawEnabled)
      return;
   int keep = MathMax(1, InpHistoryCount);
   string symTag = "_" + _Symbol + "_";

   long keys[];
   int  nk = 0;
   int  total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, CRT_PREFIX) != 0 || StringFind(name, symTag) < 0)
         continue;
      long k = ObjectRangeKey(name);
      if(k <= 0)
         continue;
      bool found = false;
      for(int j = 0; j < nk; j++)
         if(keys[j] == k) { found = true; break; }
      if(!found)
      {
         ArrayResize(keys, nk + 1);
         keys[nk++] = k;
      }
   }
   if(nk <= keep)
      return;

   ArraySort(keys);                     // tăng dần: cũ nhất trước
   long threshold = keys[nk - keep];    // giữ các key >= threshold

   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, CRT_PREFIX) != 0 || StringFind(name, symTag) < 0)
         continue;
      long k = ObjectRangeKey(name);
      if(k > 0 && k < threshold)
         ObjectDelete(0, name);
   }
}



//====================================================================
// KẾT THÚC RANGE HIỆN TẠI (Active H4 hết hạn)
//====================================================================
void ExpireCurrentRange(string why)
{
   if(RangeIsLive())
   {
      g.status = ST_EXPIRED;
      WriteCRTLog(StringFormat("EXPIRED: Range %s (%s) - Low Swept %s, High Swept %s",
                               RangeId(g.refTime), why, YesNo(g.lowSwept), YesNo(g.highSwept)));
      MarkDirty();
   }
   else if(g.valid && (g.status == ST_BUY_ACTIVE || g.status == ST_SELL_ACTIVE))
      WriteCRTLog(StringFormat("Range %s kết thúc Active window, position #%I64u vẫn được quản lý bởi SL/TP broker",
                               RangeId(g.refTime), g.positionId), true);
}

//====================================================================
// KHỞI TẠO RANGE (khi H4 mới hoặc khi EA khởi động / restart)
//====================================================================
bool InitializeRange(bool tryRestore)
{
   MqlRates h4[];
   if(!LoadReferenceH4(h4))
      return false;

   CreateCRTRange(h4);

   if(g.valid)
   {
      if(tryRestore)
         RestoreCRTState();
      RestoreTradeFromTerminal();

      //--- Bù các nến M1/M15 đã đóng trong Active (offline / khởi động giữa chừng)
      if(RangeIsLive())
         ReplayClosedM1(true);

      //--- Đánh dấu M15[1] hiện tại là đã xử lý: không bao giờ vào lệnh muộn từ nến cũ
      datetime m15Open1 = iTime(_Symbol, CRT_TF_CONFIRM, 1);
      if(m15Open1 > g.lastM15Processed)
         g.lastM15Processed = m15Open1;
   }

   g_lastM1Seen = iTime(_Symbol, CRT_TF_REPLAY, 0);
   MarkDirty();
   DrawAllForCurrentRange();
   DeleteOldCRTObjects();
   SaveCRTState();
   return true;
}


//####################################################################
//####################################################################
//##  PHẦN MULTI V1.04 - KHUNG CHUNG CHO 4 CHIẾN LƯỢC ĐƠN LỆNH       ##
//##  Liên hệ: 0941920986 - Davidhunter - Tele @adsmmo8386           ##
//####################################################################
//####################################################################

#define STRAT_COUNT 4
#define S_CRT 0
#define S_SAR 1
#define S_BRK 2
#define S_ICT 3

string g_stName[STRAT_COUNT] = {"CRT", "SAR", "BRK", "ICT"};
string g_stDesc[STRAT_COUNT] = {"Candle Range H4 + M15", "Scalping Parabolic SAR", "Breakout Stop OCO", "ICT Sweep/FVG/OB"};
bool   g_on[STRAT_COUNT];                 // Công tắc RUNTIME (nút trên bảng)
string g_stLine1[STRAT_COUNT];            // Trạng thái dòng 1 hiển thị trên bảng
string g_stLine2[STRAT_COUNT];            // Trạng thái dòng 2 hiển thị trên bảng
string g_runId = "";

ulong StratMagic(const int i)
{
   switch(i)
   {
      case S_CRT: return InpMagic;
      case S_SAR: return InpSARMagic;
      case S_BRK: return InpBRKMagic;
      case S_ICT: return InpICTMagic;
   }
   return 0;
}

bool StratInputEnabled(const int i)
{
   switch(i)
   {
      case S_CRT: return InpEnableCRT;
      case S_SAR: return InpEnableSAR;
      case S_BRK: return InpEnableBRK;
      case S_ICT: return InpEnableICT;
   }
   return false;
}

string StratComment(const int i)
{
   string c = "";
   switch(i)
   {
      case S_CRT: c = InpCRTComment; break;
      case S_SAR: c = InpSARComment; break;
      case S_BRK: c = InpBRKComment; break;
      case S_ICT: c = InpICTComment; break;
   }
   //--- MT5 giới hạn comment lệnh 31 ký tự
   if(StringLen(c) > 31)
      c = StringSubstr(c, 0, 31);
   return c;
}

int StratFromMagic(const long magic)
{
   for(int i = 0; i < STRAT_COUNT; i++)
      if((long)StratMagic(i) == magic)
         return i;
   return -1;
}

//--- Đếm position / lệnh chờ theo Magic trên symbol hiện tại
int CountPosMagic(const ulong magic)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic) continue;
      n++;
   }
   return n;
}

int CountOrdMagic(const ulong magic)
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)magic) continue;
      n++;
   }
   return n;
}

void DeletePendingMagic(const ulong magic, CTrade &t)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)magic) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY || ot == ORDER_TYPE_SELL) continue;
      t.OrderDelete(tk);
   }
}

//--- Chế độ "1 lệnh cho toàn EA": chặn khi chiến lược KHÁC đang có position/lệnh chờ,
//    hoặc chính chiến lược này đang có position.
bool GlobalBlocked(const int self)
{
   if(!InpOneTradeGlobal)
      return false;
   for(int i = 0; i < STRAT_COUNT; i++)
   {
      ulong m = StratMagic(i);
      if(CountPosMagic(m) > 0)
         return true;
      if(i != self && CountOrdMagic(m) > 0)
         return true;
   }
   return false;
}

//--- Giờ server dạng "HH:MM" -> giây trong ngày
int HMToSeconds(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   string parts[];
   if(StringSplit(s, ':', parts) < 2)
      return -1;
   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);
   if(h < 0 || h > 23 || m < 0 || m > 59)
      return -1;
   int sec = h * 3600 + m * 60;
   if(h == 23 && m == 59)
      sec += 59;
   return sec;
}

bool InTimeWindow(const datetime t, const string startHM, const string endHM)
{
   int a = HMToSeconds(startHM);
   int b = HMToSeconds(endHM);
   if(a < 0 || b < 0)
      return false;
   MqlDateTime d;
   TimeToStruct(t, d);
   int cur = d.hour * 3600 + d.min * 60 + d.sec;
   if(a <= b)
      return (cur >= a && cur <= b);
   return (cur >= a || cur <= b);   // khoảng qua nửa đêm
}

datetime DayStart(const datetime t)
{
   return (datetime)((long)t - ((long)t % 86400));
}

//====================================================================
// CÔNG TẮC RUNTIME (nút BẬT/TẮT trên bảng)
// Input = công tắc gốc. Nút trên bảng ghi đè trong phiên và được giữ
// qua đổi TF / restart (Global Variable) cho tới khi Input đổi giá trị.
//====================================================================
string SwitchKey(const int i, const string suffix)
{
   return "DAVIDMULTI_" + _Symbol + "_" + IntegerToString((long)StratMagic(i)) + suffix;
}

void SaveSwitch(const int i)
{
   if(g_isTester)
      return;
   GlobalVariableSet(SwitchKey(i, "_IN"), StratInputEnabled(i) ? 1.0 : 0.0);
   GlobalVariableSet(SwitchKey(i, "_ON"), g_on[i] ? 1.0 : 0.0);
}

void LoadSwitches()
{
   for(int i = 0; i < STRAT_COUNT; i++)
   {
      bool inp = StratInputEnabled(i);
      g_on[i] = inp;
      if(!g_isTester && GlobalVariableCheck(SwitchKey(i, "_IN")) && GlobalVariableCheck(SwitchKey(i, "_ON")))
      {
         bool storedInp = (GlobalVariableGet(SwitchKey(i, "_IN")) != 0.0);
         if(storedInp == inp)
            g_on[i] = (GlobalVariableGet(SwitchKey(i, "_ON")) != 0.0);
      }
      SaveSwitch(i);
   }
}

//====================================================================
// TRADELOG CSV - mỗi vị thế đã đóng = 1 dòng (thư mục MQL5 Common\Files)
//====================================================================
ulong g_loggedIds[];

string TradeLogFileName()
{
   return InpTradeLogName + "_" + _Symbol + (g_isTester ? "_TESTER" : "") + ".csv";
}

bool IsLogged(const ulong id)
{
   for(int i = ArraySize(g_loggedIds) - 1; i >= 0; i--)
      if(g_loggedIds[i] == id)
         return true;
   return false;
}

void RememberLogged(const ulong id)
{
   int n = ArraySize(g_loggedIds);
   if(n >= 5000)
   {
      for(int i = 0; i < n - 1; i++)
         g_loggedIds[i] = g_loggedIds[i + 1];
      g_loggedIds[n - 1] = id;
      return;
   }
   ArrayResize(g_loggedIds, n + 1, 256);
   g_loggedIds[n] = id;
}

string CsvSafe(string s)
{
   StringReplace(s, ",", " ");
   StringReplace(s, ";", " ");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
}

string DealReasonText(const long r)
{
   switch((int)r)
   {
      case DEAL_REASON_SL:     return "SL";
      case DEAL_REASON_TP:     return "TP";
      case DEAL_REASON_EXPERT: return "EXPERT";
      case DEAL_REASON_CLIENT: return "MANUAL";
      case DEAL_REASON_MOBILE: return "MOBILE";
      case DEAL_REASON_WEB:    return "WEB";
      case DEAL_REASON_SO:     return "STOPOUT";
   }
   return "OTHER";
}

string TradeLogHeader()
{
   return "RunID,Mode,Account,Symbol,Strategy,Magic,PositionID,Side,Lots,OpenTime,OpenPrice,InitialSL,InitialTP," +
          "CloseTime,ClosePrice,CloseReason,DurationMin,PriceMove,Profit,Swap,Commission,Fee,NetProfit,Result," +
          "PlannedRR,RMultiple,OpenComment,Contact";
}

void AppendTradeLogLine(const string line)
{
   string fn = TradeLogFileName();
   ResetLastError();
   int h = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
   {
      Print("[DAVID MULTI] Không mở được tradelog ", fn, " err=", GetLastError());
      return;
   }
   if(FileSize(h) == 0)
      FileWriteString(h, TradeLogHeader() + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
}

//--- Ghi 1 vị thế đã đóng hoàn toàn. Trả về true nếu đã ghi.
bool LogClosedPosition(const ulong posId)
{
   if(!InpTradeLog || posId == 0 || IsLogged(posId))
      return false;
   if(!HistorySelectByPosition(posId))
      return false;

   int      deals    = HistoryDealsTotal();
   long     magicIn  = -1;
   string   symbol   = "";
   int      side     = 0;
   double   volIn    = 0.0, volOut = 0.0;
   double   pxInSum  = 0.0, pxOutSum = 0.0;
   datetime tOpen    = 0, tClose = 0;
   double   slInit   = 0.0, tpInit = 0.0;
   double   profit   = 0.0, swap = 0.0, comm = 0.0, fee = 0.0;
   string   cmtIn    = "";
   long     reason   = -1;

   for(int i = 0; i < deals; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE);
      if(dt != DEAL_TYPE_BUY && dt != DEAL_TYPE_SELL) continue;
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      double   vol = HistoryDealGetDouble(d, DEAL_VOLUME);
      double   px  = HistoryDealGetDouble(d, DEAL_PRICE);
      datetime tm  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      profit += HistoryDealGetDouble(d, DEAL_PROFIT);
      swap   += HistoryDealGetDouble(d, DEAL_SWAP);
      comm   += HistoryDealGetDouble(d, DEAL_COMMISSION);
      fee    += HistoryDealGetDouble(d, DEAL_FEE);

      if(en == DEAL_ENTRY_IN)
      {
         if(tOpen == 0 || tm < tOpen)
         {
            tOpen   = tm;
            magicIn = HistoryDealGetInteger(d, DEAL_MAGIC);
            symbol  = HistoryDealGetString(d, DEAL_SYMBOL);
            side    = (dt == DEAL_TYPE_BUY ? 1 : -1);
            slInit  = HistoryDealGetDouble(d, DEAL_SL);
            tpInit  = HistoryDealGetDouble(d, DEAL_TP);
            cmtIn   = HistoryDealGetString(d, DEAL_COMMENT);
         }
         volIn   += vol;
         pxInSum += px * vol;
      }
      else if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY)
      {
         volOut   += vol;
         pxOutSum += px * vol;
         if(tm >= tClose)
         {
            tClose = tm;
            reason = HistoryDealGetInteger(d, DEAL_REASON);
         }
      }
      else if(en == DEAL_ENTRY_INOUT)
         return false;   // vị thế đảo chiều (netting) - không thuộc mô hình đơn lệnh
   }

   int s = StratFromMagic(magicIn);
   if(s < 0 || symbol != _Symbol || volIn <= 0.0 || volOut <= 0.0)
      return false;
   double tol = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) * 0.1, 1e-7);
   if(volOut < volIn - tol)
      return false;      // chưa đóng hết

   double pxIn   = pxInSum / volIn;
   double pxOut  = pxOutSum / volOut;
   double move   = (pxOut - pxIn) * side;
   double net    = profit + swap + comm + fee;
   double riskPx = (slInit > 0.0 ? MathAbs(pxIn - slInit) : 0.0);
   double rrPlan = (riskPx > 0.0 && tpInit > 0.0 ? MathAbs(tpInit - pxIn) / riskPx : 0.0);
   double rMult  = (riskPx > 0.0 ? move / riskPx : 0.0);
   string result = (net > 0.0 ? "WIN" : (net < 0.0 ? "LOSS" : "BE"));
   int    dg     = _Digits;

   string line = CsvSafe(g_runId) + "," +
                 (g_isTester ? "TESTER" : "LIVE") + "," +
                 IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "," +
                 CsvSafe(_Symbol) + "," +
                 g_stName[s] + "," +
                 IntegerToString(magicIn) + "," +
                 IntegerToString((long)posId) + "," +
                 (side > 0 ? "BUY" : "SELL") + "," +
                 DoubleToString(volIn, 2) + "," +
                 TimeToString(tOpen, TIME_DATE | TIME_SECONDS) + "," +
                 DoubleToString(pxIn, dg) + "," +
                 DoubleToString(slInit, dg) + "," +
                 DoubleToString(tpInit, dg) + "," +
                 TimeToString(tClose, TIME_DATE | TIME_SECONDS) + "," +
                 DoubleToString(pxOut, dg) + "," +
                 DealReasonText(reason) + "," +
                 DoubleToString((double)(tClose - tOpen) / 60.0, 1) + "," +
                 DoubleToString(move, dg) + "," +
                 DoubleToString(profit, 2) + "," +
                 DoubleToString(swap, 2) + "," +
                 DoubleToString(comm, 2) + "," +
                 DoubleToString(fee, 2) + "," +
                 DoubleToString(net, 2) + "," +
                 result + "," +
                 DoubleToString(rrPlan, 2) + "," +
                 DoubleToString(rMult, 2) + "," +
                 CsvSafe(cmtIn) + "," +
                 CsvSafe(DAVID_CONTACT);

   AppendTradeLogLine(line);
   RememberLogged(posId);
   Print("[DAVID MULTI] TRADELOG ", g_stName[s], " #", posId, " ", result, " net=", DoubleToString(net, 2));

   //--- Thống kê chuỗi thua cho ICT
   if(s == S_ICT)
      ICT_OnClosedTrade(net);
   return true;
}

//--- Đọc PositionID đã có trong file (chỉ LIVE) để không ghi trùng
void LoadLoggedIdsFromCsv()
{
   ArrayResize(g_loggedIds, 0);
   if(g_isTester || !InpTradeLog)
      return;
   string fn = TradeLogFileName();
   if(!FileIsExist(fn, FILE_COMMON))
      return;
   int h = FileOpen(fn, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      string cols[];
      if(StringSplit(line, ',', cols) < 7)
         continue;
      long id = StringToInteger(cols[6]);
      if(id > 0)
         RememberLogged((ulong)id);
   }
   FileClose(h);
}

//--- Bù các vị thế đã đóng khi EA offline (chỉ LIVE)
void BackfillTradeLog()
{
   if(g_isTester || !InpTradeLog)
      return;
   if(!HistorySelect(0, TimeCurrent() + 60))
      return;
   ulong ids[];
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      if(StratFromMagic(HistoryDealGetInteger(d, DEAL_MAGIC)) < 0) continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(pid == 0 || IsLogged(pid)) continue;
      int n = ArraySize(ids);
      ArrayResize(ids, n + 1);
      ids[n] = pid;
   }
   int added = 0;
   for(int i = 0; i < ArraySize(ids); i++)
      if(LogClosedPosition(ids[i]))
         added++;
   if(added > 0)
      Print("[DAVID MULTI] Tradelog bù ", added, " vị thế đã đóng khi EA offline");
}

//####################################################################
//##  2. SAR - SCALPING PARABOLIC SAR (nguồn: Scalping M1 2.1)        ##
//##  Comment lệnh riêng: InpSARComment (kèm 0941920986 @adsmmo8386)  ##
//##  - Vào lệnh: SAR dưới Bid và 0 < Ask-SAR <= Distance+5 point     ##
//##    -> BUY; SAR trên Ask và 0 < SAR-Bid <= Distance+5 -> SELL.    ##
//##  - TP/SL ẩn theo tiền tài khoản (giữ nguyên mã gốc).             ##
//##  - ĐƠN LỆNH: tối đa 1 position. Bỏ chế độ hai chiều và nhân lot. ##
//##  - Sửa lỗi gốc: quản lý TP/SL LUÔN chạy trước mọi bộ lọc.        ##
//####################################################################
CTrade   g_tradeSAR;
int      g_sarHandle     = INVALID_HANDLE;
int      g_sarATRHandle  = INVALID_HANDLE;
datetime g_sarLastOpen   = 0;
ulong    g_sarPeakTicket = 0;
bool     g_sarPeakOn     = false;
double   g_sarPeak       = 0.0;
datetime g_sarTicks[];
datetime g_sarDailyAt    = 0;
double   g_sarDailyPL    = 0.0;
double   g_sarLastValue  = 0.0;

bool InitSAR()
{
   g_tradeSAR.SetExpertMagicNumber(InpSARMagic);
   g_tradeSAR.SetDeviationInPoints(InpDeviationPoints);
   g_tradeSAR.SetTypeFillingBySymbol(_Symbol);
   g_tradeSAR.LogLevel(LOG_LEVEL_ERRORS);

   g_sarHandle = iSAR(_Symbol, InpSARTimeframe, InpSARStep, InpSARMaximum);
   if(g_sarHandle == INVALID_HANDLE)
   {
      Print("[SAR] Không tạo được Parabolic SAR, err=", GetLastError());
      return false;
   }
   if(InpSARATRFilter)
   {
      g_sarATRHandle = iATR(_Symbol, InpSARTimeframe, MathMax(1, InpSARATRPeriod));
      if(g_sarATRHandle == INVALID_HANDLE)
      {
         Print("[SAR] Không tạo được ATR, err=", GetLastError());
         return false;
      }
   }
   ArrayResize(g_sarTicks, 0);
   return true;
}

void SAR_UpdateTicks(const datetime now)
{
   int n = ArraySize(g_sarTicks);
   ArrayResize(g_sarTicks, n + 1, 512);
   g_sarTicks[n] = now;
   datetime cutoff = now - MathMax(1, InpSARTickPeriodSec) * 2;
   int drop = 0;
   n = ArraySize(g_sarTicks);
   while(drop < n && g_sarTicks[drop] < cutoff)
      drop++;
   if(drop > 0)
   {
      for(int i = 0; i < n - drop; i++)
         g_sarTicks[i] = g_sarTicks[i + drop];
      ArrayResize(g_sarTicks, n - drop, 512);
   }
}

int SAR_TickCount(const datetime now)
{
   int c = 0;
   for(int i = ArraySize(g_sarTicks) - 1; i >= 0; i--)
   {
      if(now - g_sarTicks[i] > InpSARTickPeriodSec)
         break;
      c++;
   }
   return c;
}

bool SAR_CandleAllowed()
{
   int lookback = MathMax(1, InpSARCandleLookback);
   int count = lookback + 1;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpSARTimeframe, 0, count, r) < count)
      return false;
   double avg = 0.0;
   for(int i = 1; i <= lookback; i++)       // trung bình CHỈ nến đã đóng
      avg += r[i].high - r[i].low;
   avg /= lookback;
   if(avg <= 0.0)
      return true;
   int idx = (InpSARUseCurrentBar ? 0 : 1);
   return ((r[idx].high - r[idx].low) / avg <= InpSARCandleMaxMult);
}

bool SAR_ATRAllowed()
{
   if(g_sarATRHandle == INVALID_HANDLE)
      return true;
   int lb = MathMax(2, InpSARATRLookback);
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(g_sarATRHandle, 0, 0, lb, a) < lb)
      return false;
   double avg = 0.0;
   for(int i = 1; i < lb; i++)
      avg += a[i];
   avg /= (lb - 1);
   if(avg <= 0.0)
      return true;
   double ratio = a[0] / avg;
   return (ratio >= InpSARATRMin && ratio <= InpSARATRMax);
}

//--- Lãi/lỗ trong ngày (deal đã đóng + thả nổi) của riêng SAR, tính lại mỗi 10 giây
double SAR_DailyPL(const datetime now)
{
   if(now - g_sarDailyAt < 10)
      return g_sarDailyPL;
   g_sarDailyAt = now;
   double pl = 0.0;
   if(HistorySelect(DayStart(now), now + 60))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0) continue;
         if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(d, DEAL_MAGIC) != (long)InpSARMagic) continue;
         pl += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP)
             + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      }
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpSARMagic) continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   g_sarDailyPL = pl;
   return pl;
}

//--- Quản lý TP/SL ẩn theo tiền (LUÔN chạy, kể cả khi SAR bị tắt hoặc bộ lọc chặn)
void SAR_Manage()
{
   double slMoney = (InpSARTPMode == SAR_TP_FIXED ? InpSARSLMoneyFixed : InpSARSLMoneyFloat);
   bool   found   = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpSARMagic) continue;
      found = true;
      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(InpSARTPMode == SAR_TP_FIXED && InpSARTPMoney > 0.0 && pl >= InpSARTPMoney)
      {
         if(g_tradeSAR.PositionClose(t))
            Print("[SAR] Đóng TP cố định #", t, " lãi=", DoubleToString(pl, 2));
         continue;
      }

      if(InpSARTPMode == SAR_TP_FLOAT && InpSARFloatRetrace > 0.0)
      {
         if(g_sarPeakTicket != t)
         {
            g_sarPeakTicket = t;
            g_sarPeakOn     = false;
            g_sarPeak       = 0.0;
         }
         if(!g_sarPeakOn && (InpSARFloatActivate <= 0.0 || pl >= InpSARFloatActivate))
         {
            g_sarPeakOn = true;
            g_sarPeak   = pl;
         }
         if(g_sarPeakOn)
         {
            if(pl > g_sarPeak && (InpSARFloatStep <= 0.0 || pl >= g_sarPeak + InpSARFloatStep))
               g_sarPeak = pl;
            if(g_sarPeak - pl >= InpSARFloatRetrace)
            {
               if(g_tradeSAR.PositionClose(t))
                  Print("[SAR] Đóng TP thả nổi #", t, " đỉnh=", DoubleToString(g_sarPeak, 2), " lãi=", DoubleToString(pl, 2));
               continue;
            }
         }
      }

      if(slMoney > 0.0 && pl <= -slMoney)
      {
         if(g_tradeSAR.PositionClose(t))
            Print("[SAR] Đóng SL theo tiền #", t, " lỗ=", DoubleToString(pl, 2));
         continue;
      }
   }
   if(!found)
   {
      g_sarPeakTicket = 0;
      g_sarPeakOn     = false;
      g_sarPeak       = 0.0;
   }
}

double SAR_Lots()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot  = NormalizeVolumeDown(InpSARLot);
   if(lot < mn - 1e-9)
      return 0.0;
   if(lot > mx)
      lot = NormalizeVolumeDown(mx);
   return lot;
}

void SAR_Open(const int dir, const MqlTick &tick)
{
   double lot = SAR_Lots();
   if(lot <= 0.0)
   {
      g_stLine1[S_SAR] = "LOT KHÔNG HỢP LỆ (< Volume Min)";
      return;
   }
   double margin = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, (dir > 0 ? tick.ask : tick.bid), margin)
      && margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9)
   {
      g_stLine1[S_SAR] = "THIẾU KÝ QUỸ";
      return;
   }
   g_sarLastOpen = tick.time;    // khóa cooldown kể cả khi gửi lỗi -> không spam lệnh
   string cmt = StratComment(S_SAR);
   bool ok = (dir > 0 ? g_tradeSAR.Buy(lot, _Symbol, 0.0, 0.0, 0.0, cmt)
                      : g_tradeSAR.Sell(lot, _Symbol, 0.0, 0.0, 0.0, cmt));
   uint rc = g_tradeSAR.ResultRetcode();
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
      Print("[SAR] Mở ", (dir > 0 ? "BUY" : "SELL"), " ", DoubleToString(lot, 2), " @ ", Px(g_tradeSAR.ResultPrice()),
            " | SAR=", Px(g_sarLastValue), " | ", cmt);
   else
      Print("[SAR] Mở lệnh thất bại retcode=", rc, " ", g_tradeSAR.ResultRetcodeDescription());
}

void ProcessSAR(const MqlTick &tick)
{
   datetime now = tick.time;
   SAR_UpdateTicks(now);

   //--- 1. Quản lý lệnh đang mở LUÔN chạy trước (sửa lỗi bản gốc)
   SAR_Manage();

   int pos = CountPosMagic(InpSARMagic);
   double dayPL = SAR_DailyPL(now);
   g_stLine2[S_SAR] = StringFormat("M%I64u • SAR %s • Spread %d pt • Lãi/lỗ ngày %s • Tick/%ds: %d",
                                   InpSARMagic, (g_sarLastValue > 0 ? Px(g_sarLastValue) : "-"),
                                   (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), DoubleToString(dayPL, 2),
                                   InpSARTickPeriodSec, SAR_TickCount(now));

   if(!g_on[S_SAR])
   {
      g_stLine1[S_SAR] = (pos > 0 ? "TẮT VÀO LỆNH MỚI - vẫn quản lý lệnh đang mở" : "TẮT");
      return;
   }
   if(pos > 0)
   {
      g_stLine1[S_SAR] = "ĐANG CÓ LỆNH - quản lý TP/SL theo tiền (" + (InpSARTPMode == SAR_TP_FIXED ? "TP cố định" : "TP thả nổi") + ")";
      return;
   }

   //--- 2. Bộ lọc vào lệnh
   if(InpSARDailyTarget > 0.0 && dayPL >= InpSARDailyTarget) { g_stLine1[S_SAR] = "ĐẠT MỤC TIÊU LÃI NGÀY - dừng vào lệnh"; return; }
   if(InpSARDailyLoss > 0.0 && dayPL <= -InpSARDailyLoss)    { g_stLine1[S_SAR] = "CHẠM NGƯỠNG LỖ NGÀY - dừng vào lệnh"; return; }
   if(InpSARTimeFilter && !InTimeWindow(now, InpSARStartTime, InpSAREndTime)) { g_stLine1[S_SAR] = "NGOÀI GIỜ GIAO DỊCH"; return; }
   if(InpSARSpreadFilter && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpSARMaxSpreadPts) { g_stLine1[S_SAR] = "SPREAD QUÁ CAO"; return; }
   if(InpSARCandleFilter && !SAR_CandleAllowed()) { g_stLine1[S_SAR] = "LỌC NẾN: nến quá lớn"; return; }
   if(InpSARATRFilter && !SAR_ATRAllowed())       { g_stLine1[S_SAR] = "LỌC ATR: biến động ngoài ngưỡng"; return; }
   if(InpSARTickFilter && SAR_TickCount(now) < InpSARMinTicks) { g_stLine1[S_SAR] = "LỌC TICK: chưa đủ số tick"; return; }
   if(GlobalBlocked(S_SAR)) { g_stLine1[S_SAR] = "CHỜ - chế độ 1 lệnh toàn EA đang có lệnh khác"; return; }
   if(now - g_sarLastOpen < InpSARCooldownSec) { g_stLine1[S_SAR] = "NGHỈ GIỮA 2 LẦN MỞ"; return; }

   //--- 3. Tín hiệu SAR (nến hiện tại của khung InpSARTimeframe, như bản gốc)
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_sarHandle, 0, 0, 1, buf) < 1 || buf[0] <= 0.0 || buf[0] == EMPTY_VALUE)
   {
      g_stLine1[S_SAR] = "THIẾU DỮ LIỆU SAR";
      return;
   }
   double sar = buf[0];
   g_sarLastValue = sar;
   double pt = g_point;
   double distBuy  = (tick.ask - sar) / pt;
   double distSell = (sar - tick.bid) / pt;
   bool   up   = (sar < tick.bid);
   bool   down = (sar > tick.ask);
   int    maxD = InpSARDistancePts + 5;

   if(up && InpSARMode != SAR_MODE_SELL_ONLY)
   {
      if(distBuy > 0 && distBuy <= maxD)
      {
         SAR_Open(+1, tick);
         return;
      }
      g_stLine1[S_SAR] = StringFormat("XU HƯỚNG TĂNG - chờ giá về gần SAR (%.0f / %d pt)", distBuy, maxD);
      return;
   }
   if(down && InpSARMode != SAR_MODE_BUY_ONLY)
   {
      if(distSell > 0 && distSell <= maxD)
      {
         SAR_Open(-1, tick);
         return;
      }
      g_stLine1[S_SAR] = StringFormat("XU HƯỚNG GIẢM - chờ giá về gần SAR (%.0f / %d pt)", distSell, maxD);
      return;
   }
   g_stLine1[S_SAR] = "CHỜ TÍN HIỆU SAR";
}

//####################################################################
//##  3. BRK - BREAKOUT STOP OCO (nguồn: Máy in tiền 1.40)            ##
//##  Comment lệnh riêng: InpBRKComment (kèm 0941920986 @adsmmo8386)  ##
//##  - Duy trì Buy Stop trên Ask và Sell Stop dưới Bid, dời theo giá. ##
//##  - SL tại sàn + trailing SL theo Bid/Ask, TP tùy chọn.           ##
//##  - ĐƠN LỆNH (OCO): khi 1 phía khớp -> xóa phía còn lại, không đặt ##
//##    lệnh chờ mới cho tới khi position đóng.                        ##
//##  - Sửa lỗi gốc: trailing vẫn chạy ngoài giờ; spread cao -> xóa    ##
//##    lệnh chờ; không Sleep; giờ lọc theo giờ server.                ##
//####################################################################
CTrade   g_tradeBRK;
datetime g_brkLastMoveBuy  = 0;
datetime g_brkLastMoveSell = 0;
datetime g_brkLastFail     = 0;

void InitBRK()
{
   g_tradeBRK.SetExpertMagicNumber(InpBRKMagic);
   g_tradeBRK.SetDeviationInPoints(InpDeviationPoints);
   g_tradeBRK.SetTypeFillingBySymbol(_Symbol);
   g_tradeBRK.LogLevel(LOG_LEVEL_ERRORS);
}

bool BRK_TimeAllowed(const datetime now)
{
   if(!InpBRKTimeFilter)
      return true;
   return (InTimeWindow(now, InpBRKStart1, InpBRKEnd1) ||
           InTimeWindow(now, InpBRKStart2, InpBRKEnd2) ||
           InTimeWindow(now, InpBRKStart3, InpBRKEnd3));
}

double BRK_Lots()
{
   double lot = InpBRKLot;
   if(InpBRKUseEquityLot)
   {
      lot = AccountInfoDouble(ACCOUNT_EQUITY) * InpBRKEquityFactor / 1000000.0;
      if(lot > 100.0) lot = 100.0;
   }
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = NormalizeVolumeDown(lot);
   if(lot < mn - 1e-9)
      lot = (InpBRKUseEquityLot ? NormalizeVolumeDown(mn) : 0.0);   // bản gốc kẹp tối thiểu 0.01 khi theo equity
   if(lot > mx)
      lot = NormalizeVolumeDown(mx);
   return lot;
}

double MinStopDistance()
{
   long st = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long fz = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   return (double)MathMax(st, fz) * g_point;
}

void BRK_Trail(const MqlTick &tick)
{
   if(InpBRKTrail <= 0.0 || tick.time - g_brkLastFail < 1)
      return;
   double minD = MinStopDistance();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpBRKMagic) continue;
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      bool   buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double target = NormalizePrice(buy ? tick.bid - InpBRKTrail : tick.ask + InpBRKTrail);
      bool improve = (buy ? (sl <= 0.0 || target > sl + g_point * 0.5) : (sl <= 0.0 || target < sl - g_point * 0.5));
      if(!improve)
         continue;
      if(buy && (tick.bid - target < minD || (sl > 0.0 && tick.bid - sl <= minD)))
         continue;
      if(!buy && (target - tick.ask < minD || (sl > 0.0 && sl - tick.ask <= minD)))
         continue;
      if(!g_tradeBRK.PositionModify(t, target, tp))
      {
         g_brkLastFail = tick.time;
         Print("[BRK] Trailing SL thất bại retcode=", g_tradeBRK.ResultRetcode());
      }
   }
}

void ProcessBRK(const MqlTick &tick)
{
   datetime now = tick.time;
   int pos = CountPosMagic(InpBRKMagic);

   //--- 1. Có position -> OCO: xóa mọi lệnh chờ, chỉ trailing SL (LUÔN chạy)
   if(pos > 0)
   {
      if(CountOrdMagic(InpBRKMagic) > 0)
      {
         DeletePendingMagic(InpBRKMagic, g_tradeBRK);
         Print("[BRK] OCO: đã khớp 1 phía -> xóa lệnh chờ còn lại");
      }
      BRK_Trail(tick);
      g_stLine1[S_BRK] = (g_on[S_BRK] ? "ĐANG CÓ LỆNH - trailing SL" : "TẮT VÀO LỆNH MỚI - vẫn trailing lệnh đang mở");
      g_stLine2[S_BRK] = StringFormat("M%I64u • Trailing %s • OCO: không đặt lệnh chờ mới khi đang có lệnh",
                                      InpBRKMagic, DoubleToString(InpBRKTrail, _Digits));
      return;
   }

   //--- 2. Không có position: kiểm tra điều kiện duy trì lệnh chờ
   double spread = tick.ask - tick.bid;
   string block = "";
   if(!g_on[S_BRK])                                          block = "TẮT";
   else if(!BRK_TimeAllowed(now))                            block = "NGOÀI GIỜ - đã hủy lệnh chờ";
   else if(InpBRKMaxSpread > 0.0 && spread > InpBRKMaxSpread + PriceEps()) block = "SPREAD QUÁ CAO - đã hủy lệnh chờ";
   else if(GlobalBlocked(S_BRK))                             block = "CHỜ - chế độ 1 lệnh toàn EA đang có lệnh khác";

   if(block != "")
   {
      if(CountOrdMagic(InpBRKMagic) > 0)
         DeletePendingMagic(InpBRKMagic, g_tradeBRK);
      g_stLine1[S_BRK] = block;
      g_stLine2[S_BRK] = StringFormat("M%I64u • Khoảng đặt %s • SL %s • TP %s • Spread %s",
                                      InpBRKMagic, DoubleToString(InpBRKDistance, _Digits), DoubleToString(InpBRKStopLoss, _Digits),
                                      (InpBRKTakeProfit > 0 ? DoubleToString(InpBRKTakeProfit, _Digits) : "tắt"),
                                      DoubleToString(spread, _Digits));
      return;
   }

   double lot = BRK_Lots();
   if(lot <= 0.0)
   {
      g_stLine1[S_BRK] = "LOT KHÔNG HỢP LỆ (< Volume Min)";
      return;
   }
   if(InpBRKDistance < MinStopDistance() || InpBRKStopLoss < MinStopDistance())
   {
      g_stLine1[S_BRK] = "KHOẢNG ĐẶT / SL NHỎ HƠN STOPSLEVEL CỦA SÀN";
      return;
   }

   //--- 3. Tìm lệnh chờ hiện có
   ulong  buyTk = 0, sellTk = 0;
   double buyPx = 0.0, sellPx = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpBRKMagic) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP)
      {
         if(buyTk != 0) { g_tradeBRK.OrderDelete(tk); continue; }   // giữ đúng 1 lệnh mỗi phía
         buyTk = tk; buyPx = OrderGetDouble(ORDER_PRICE_OPEN);
      }
      else if(ot == ORDER_TYPE_SELL_STOP)
      {
         if(sellTk != 0) { g_tradeBRK.OrderDelete(tk); continue; }
         sellTk = tk; sellPx = OrderGetDouble(ORDER_PRICE_OPEN);
      }
   }

   string cmt = StratComment(S_BRK);
   double bTarget = NormalizePrice(tick.ask + InpBRKDistance);
   double sTarget = NormalizePrice(tick.bid - InpBRKDistance);

   //--- 4. Đặt mới hoặc dời lệnh chờ theo giá (như bản gốc)
   if(buyTk == 0)
   {
      double sl = NormalizePrice(bTarget - InpBRKStopLoss);
      double tp = (InpBRKTakeProfit > 0.0 ? NormalizePrice(bTarget + InpBRKTakeProfit) : 0.0);
      if(g_tradeBRK.BuyStop(lot, bTarget, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt))
         g_brkLastMoveBuy = now;
      else
         Print("[BRK] Đặt Buy Stop thất bại retcode=", g_tradeBRK.ResultRetcode());
   }
   else if(now - g_brkLastMoveBuy >= InpBRKMoveSec && MathAbs(buyPx - bTarget) > InpBRKMoveStep + PriceEps())
   {
      double sl = NormalizePrice(bTarget - InpBRKStopLoss);
      double tp = (InpBRKTakeProfit > 0.0 ? NormalizePrice(bTarget + InpBRKTakeProfit) : 0.0);
      g_brkLastMoveBuy = now;
      if(!g_tradeBRK.OrderModify(buyTk, bTarget, sl, tp, ORDER_TIME_GTC, 0))
         Print("[BRK] Dời Buy Stop thất bại retcode=", g_tradeBRK.ResultRetcode());
      else
         buyPx = bTarget;
   }

   if(sellTk == 0)
   {
      double sl = NormalizePrice(sTarget + InpBRKStopLoss);
      double tp = (InpBRKTakeProfit > 0.0 ? NormalizePrice(sTarget - InpBRKTakeProfit) : 0.0);
      if(g_tradeBRK.SellStop(lot, sTarget, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt))
         g_brkLastMoveSell = now;
      else
         Print("[BRK] Đặt Sell Stop thất bại retcode=", g_tradeBRK.ResultRetcode());
   }
   else if(now - g_brkLastMoveSell >= InpBRKMoveSec && MathAbs(sellPx - sTarget) > InpBRKMoveStep + PriceEps())
   {
      double sl = NormalizePrice(sTarget + InpBRKStopLoss);
      double tp = (InpBRKTakeProfit > 0.0 ? NormalizePrice(sTarget - InpBRKTakeProfit) : 0.0);
      g_brkLastMoveSell = now;
      if(!g_tradeBRK.OrderModify(sellTk, sTarget, sl, tp, ORDER_TIME_GTC, 0))
         Print("[BRK] Dời Sell Stop thất bại retcode=", g_tradeBRK.ResultRetcode());
      else
         sellPx = sTarget;
   }

   g_stLine1[S_BRK] = "CHỜ BREAKOUT - Buy Stop + Sell Stop (OCO)";
   g_stLine2[S_BRK] = StringFormat("M%I64u • Buy Stop %s • Sell Stop %s • SL %s • Lot %.2f",
                                   InpBRKMagic, (buyPx > 0 ? Px(buyPx) : Px(bTarget)), (sellPx > 0 ? Px(sellPx) : Px(sTarget)),
                                   DoubleToString(InpBRKStopLoss, _Digits), lot);
}

//####################################################################
//##  4. ICT - HỢP LƯU SWEEP / FVG / OB (nguồn: OptimusPrime 2.20)    ##
//##  Comment lệnh riêng: InpICTComment (kèm 0941920986 @adsmmo8386)  ##
//##  - Điểm: FVG+OB gần nhau +3 | 1 vùng +1 | Quét thanh khoản +2 |  ##
//##    30 phút đầu phiên +1 | H1 xác nhận +2.                        ##
//##  - ĐƠN LỆNH: 1 lệnh/setup (bản gốc tách 3 lệnh TP1/TP2/TP3),     ##
//##    TP = InpICTTPRR x R, tối đa 1 position hoặc 1 lệnh Limit.      ##
//##  - Sửa lỗi gốc: dùng nến ĐÃ ĐÓNG; tự chạy (không cần nút Run);   ##
//##    đếm cả lệnh chờ; R tính theo SL ban đầu; lot < min -> bỏ lệnh; ##
//##    ngân sách rủi ro ngày tính cả lệnh mới; chuỗi thua reset sau   ##
//##    khi nghỉ; swing [0] = swing gần nhất.                          ##
//####################################################################
struct ICTZone
{
   bool     valid;
   double   high;
   double   low;
   double   mid;
   double   size;
   double   entry;
   datetime t;
};

CTrade   g_tradeICT;
ICTZone  g_ictFvgBull, g_ictFvgBear, g_ictObBull, g_ictObBear;
bool     g_ictSwBullOn = false, g_ictSwBearOn = false;
double   g_ictSwBullPx = 0.0,   g_ictSwBearPx = 0.0;
int      g_ictSwBullAge = 0,    g_ictSwBearAge = 0;
double   g_ictHiExec[2], g_ictLoExec[2], g_ictHiBias[2], g_ictLoBias[2];
double   g_ictTRExec = 0.0, g_ictTRConf = 0.0, g_ictTRBias = 0.0;
int      g_ictBias = 0;          // 1 tăng, -1 giảm, 0 trung tính
bool     g_ictH1Conf = false;
datetime g_ictLastExecBar = 0, g_ictLastConfBar = 0, g_ictLastBiasBar = 0;
int      g_ictDayKey = -1;
int      g_ictDayTrades = 0;
double   g_ictDayRisk = 0.0;
int      g_ictConsLoss = 0;
datetime g_ictCooldownUntil = 0;
ulong    g_ictPosId = 0;
double   g_ictInitRisk = 0.0;
int      g_ictLastScoreBuy = 0, g_ictLastScoreSell = 0;
string   g_ictReason = "";

void ICT_ResetZone(ICTZone &z)
{
   z.valid = false; z.high = 0; z.low = 0; z.mid = 0; z.size = 0; z.entry = 0; z.t = 0;
}

void InitICT()
{
   g_tradeICT.SetExpertMagicNumber(InpICTMagic);
   g_tradeICT.SetDeviationInPoints(InpDeviationPoints);
   g_tradeICT.SetTypeFillingBySymbol(_Symbol);
   g_tradeICT.LogLevel(LOG_LEVEL_ERRORS);
   ICT_ResetZone(g_ictFvgBull); ICT_ResetZone(g_ictFvgBear);
   ICT_ResetZone(g_ictObBull);  ICT_ResetZone(g_ictObBear);
   ArrayInitialize(g_ictHiExec, 0.0); ArrayInitialize(g_ictLoExec, 0.0);
   ArrayInitialize(g_ictHiBias, 0.0); ArrayInitialize(g_ictLoBias, 0.0);
}

datetime ICT_UTC(const datetime serverTime)
{
   return serverTime - InpICTServerUTC * 3600;
}

//--- True Range trung bình trên NẾN ĐÃ ĐÓNG
double ICT_TR(const ENUM_TIMEFRAMES tf, const int period)
{
   if(period <= 0)
      return 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 1, period + 1, r) < period + 1)
      return 0.0;
   double s = 0.0;
   for(int i = 0; i < period; i++)
      s += MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - r[i + 1].close), MathAbs(r[i].low - r[i + 1].close)));
   return s / period;
}

//--- Swing trên NẾN ĐÃ ĐÓNG: hi[0]/lo[0] = swing gần nhất, [1] = swing trước đó
void ICT_DetectSwings(const ENUM_TIMEFRAMES tf, double &hi[], double &lo[])
{
   hi[0] = 0; hi[1] = 0; lo[0] = 0; lo[1] = 0;
   int w = MathMax(1, InpICTSwingWindow);
   int lb = MathMax(w + 1, InpICTSwingLookback);
   int need = lb + w * 2;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, tf, 1, need, r) < need)
      return;
   int nh = 0, nl = 0;
   for(int i = w; i < lb && (nh < 2 || nl < 2); i++)
   {
      bool sh = true, sl = true;
      for(int j = 1; j <= w; j++)
      {
         if(r[i].high <= r[i - j].high || r[i].high <= r[i + j].high) sh = false;
         if(r[i].low  >= r[i - j].low  || r[i].low  >= r[i + j].low)  sl = false;
      }
      if(sh && nh < 2) hi[nh++] = r[i].high;
      if(sl && nl < 2) lo[nl++] = r[i].low;
   }
}

void ICT_DetectBOS()
{
   if(g_ictHiBias[0] <= 0 || g_ictHiBias[1] <= 0 || g_ictLoBias[0] <= 0 || g_ictLoBias[1] <= 0)
      return;
   double c1 = iClose(_Symbol, InpICTBiasTF, 1);
   double minBreak = InpICTBOSFactor * g_ictTRBias;
   if(g_ictHiBias[0] > g_ictHiBias[1] + minBreak && c1 > g_ictHiBias[0])
   {
      if(g_ictBias != 1) Print("[ICT] BOS tăng trên ", EnumToString(InpICTBiasTF));
      g_ictBias = 1;
      return;
   }
   if(g_ictLoBias[0] < g_ictLoBias[1] - minBreak && c1 < g_ictLoBias[0])
   {
      if(g_ictBias != -1) Print("[ICT] BOS giảm trên ", EnumToString(InpICTBiasTF));
      g_ictBias = -1;
   }
}

void ICT_CheckConfirm()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpICTConfirmTF, 1, 2, r) < 2)   // r[0] = nến xác nhận vừa đóng
   {
      g_ictH1Conf = false;
      return;
   }
   if(g_ictBias == 1)
      g_ictH1Conf = (r[0].low > r[1].low || (r[0].close > r[0].open && r[0].close > r[1].close));
   else if(g_ictBias == -1)
      g_ictH1Conf = (r[0].high < r[1].high || (r[0].close < r[0].open && r[0].close < r[1].close));
   else
      g_ictH1Conf = (MathAbs(r[0].close - r[0].open) > g_ictTRConf * 0.3);
}

void ICT_ExpireZones(const MqlTick &tick)
{
   datetime now = tick.time;
   int maxAge = 8 * 3600;
   if(g_ictFvgBull.valid && (tick.bid < g_ictFvgBull.low || now - g_ictFvgBull.t > maxAge)) g_ictFvgBull.valid = false;
   if(g_ictFvgBear.valid && (tick.ask > g_ictFvgBear.high || now - g_ictFvgBear.t > maxAge)) g_ictFvgBear.valid = false;
   if(g_ictObBull.valid && (tick.bid < g_ictObBull.low - g_ictTRExec * 0.5 || now - g_ictObBull.t > maxAge)) g_ictObBull.valid = false;
   if(g_ictObBear.valid && (tick.ask > g_ictObBear.high + g_ictTRExec * 0.5 || now - g_ictObBear.t > maxAge)) g_ictObBear.valid = false;
}

void ICT_DetectSweep()
{
   //--- lão hóa trước, phát hiện sau (bản gốc lão hóa ngay trong lần phát hiện)
   if(g_ictSwBullOn && ++g_ictSwBullAge > InpICTLSValidity) g_ictSwBullOn = false;
   if(g_ictSwBearOn && ++g_ictSwBearAge > InpICTLSValidity) g_ictSwBearOn = false;
   if(g_ictLoExec[0] <= 0 || g_ictHiExec[0] <= 0 || g_ictTRExec <= 0)
      return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpICTExecTF, 1, 1, r) < 1)   // nến vừa đóng
      return;
   double body = MathAbs(r[0].close - r[0].open);
   double minWick = InpICTLSMinWick * g_ictTRExec;
   double minBody = InpICTLSBody * g_ictTRExec;
   double swl = g_ictLoExec[0];
   if(r[0].low < swl - InpICTLSWick * g_ictTRExec && r[0].close > swl && (swl - r[0].low) >= minWick &&
      body >= minBody && r[0].close > r[0].open)
   {
      g_ictSwBullOn = true; g_ictSwBullPx = r[0].low; g_ictSwBullAge = 0;
      Print("[ICT] Quét thanh khoản TĂNG: đáy ", Px(r[0].low), " < swing ", Px(swl));
   }
   double swh = g_ictHiExec[0];
   if(r[0].high > swh + InpICTLSWick * g_ictTRExec && r[0].close < swh && (r[0].high - swh) >= minWick &&
      body >= minBody && r[0].close < r[0].open)
   {
      g_ictSwBearOn = true; g_ictSwBearPx = r[0].high; g_ictSwBearAge = 0;
      Print("[ICT] Quét thanh khoản GIẢM: đỉnh ", Px(r[0].high), " > swing ", Px(swh));
   }
}

void ICT_DetectFVG(const datetime now)
{
   if(g_ictTRExec <= 0)
      return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpICTExecTF, 1, 3, r) < 3)   // r[0]=C, r[1]=B (xung lực), r[2]=A - đều đã đóng
      return;
   double bBody = MathAbs(r[1].close - r[1].open);
   double mn = InpICTFVGMin * g_ictTRExec, mx = InpICTFVGMax * g_ictTRExec, imp = InpICTImpulseBody * g_ictTRExec;
   double up = r[0].low - r[2].high;
   if(up > 0 && up >= mn && up <= mx && bBody >= imp && r[1].close > r[1].open)
   {
      g_ictFvgBull.valid = true; g_ictFvgBull.high = r[0].low; g_ictFvgBull.low = r[2].high;
      g_ictFvgBull.mid = (g_ictFvgBull.high + g_ictFvgBull.low) / 2; g_ictFvgBull.size = up;
      g_ictFvgBull.entry = g_ictFvgBull.low + 0.25 * up; g_ictFvgBull.t = now;
   }
   double dn = r[2].low - r[0].high;
   if(dn > 0 && dn >= mn && dn <= mx && bBody >= imp && r[1].close < r[1].open)
   {
      g_ictFvgBear.valid = true; g_ictFvgBear.high = r[2].low; g_ictFvgBear.low = r[0].high;
      g_ictFvgBear.mid = (g_ictFvgBear.high + g_ictFvgBear.low) / 2; g_ictFvgBear.size = dn;
      g_ictFvgBear.entry = g_ictFvgBear.high - 0.25 * dn; g_ictFvgBear.t = now;
   }
}

void ICT_DetectOB(const datetime now)
{
   if(g_ictTRExec <= 0)
      return;
   int n = 15;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpICTExecTF, 1, n, r) < n)   // r[0] = nến vừa đóng
      return;
   int    imp   = MathMax(1, InpICTImpulseCandles);
   double minOB = InpICTOBMinBody * g_ictTRExec;
   double minImp = InpICTImpulseBody * g_ictTRExec;
   double minMove = InpICTImpulseMove * g_ictTRExec;
   double maxRange = InpICTOBMaxRange * g_ictTRExec;

   for(int dir = 1; dir >= -1; dir -= 2)
   {
      for(int i = imp; i < 10; i++)            // cần đủ imp nến xung lực SAU OB (đã đóng)
      {
         double body  = (dir > 0 ? r[i].open - r[i].close : r[i].close - r[i].open);   // OB ngược hướng
         double range = r[i].high - r[i].low;
         if(body <= 0 || range <= 0 || body < minOB || body / range < 0.7 || range > maxRange)
            continue;
         bool   ok = true;
         double move = 0.0;
         for(int j = 1; j <= imp; j++)
         {
            int k = i - j;
            double b = (dir > 0 ? r[k].close - r[k].open : r[k].open - r[k].close);
            if(b <= 0 || b < minImp) { ok = false; break; }
            move += b;
         }
         if(!ok || move < minMove)
            continue;
         if(dir > 0)
         {
            g_ictObBull.valid = true; g_ictObBull.high = r[i].high; g_ictObBull.low = r[i].low;
            g_ictObBull.mid = (r[i].high + r[i].low) / 2; g_ictObBull.size = range;
            g_ictObBull.entry = r[i].high - 0.25 * range; g_ictObBull.t = now;
         }
         else
         {
            g_ictObBear.valid = true; g_ictObBear.high = r[i].high; g_ictObBear.low = r[i].low;
            g_ictObBear.mid = (r[i].high + r[i].low) / 2; g_ictObBear.size = range;
            g_ictObBear.entry = r[i].low + 0.25 * range; g_ictObBear.t = now;
         }
         break;
      }
   }
}

bool ICT_InKillzone(const datetime now)
{
   if(InpICTOffKillzone)
      return true;
   MqlDateTime d;
   TimeToStruct(ICT_UTC(now), d);
   int m = d.hour * 60 + d.min;
   if(InpICTLondon && m >= 7 * 60 && m < 10 * 60)  return true;
   if(InpICTNewYork && m >= 12 * 60 && m < 16 * 60) return true;
   return false;
}

bool ICT_InPowerHour(const datetime now)
{
   MqlDateTime d;
   TimeToStruct(ICT_UTC(now), d);
   if(InpICTLondon && d.hour == 7 && d.min < 30)  return true;
   if(InpICTNewYork && d.hour == 12 && d.min < 30) return true;
   return false;
}

int ICT_Score(const bool bull, const datetime now)
{
   int s = 0;
   ICTZone fvg, ob;
   if(bull) { fvg = g_ictFvgBull; ob = g_ictObBull; }
   else     { fvg = g_ictFvgBear; ob = g_ictObBear; }
   if(fvg.valid && ob.valid)
   {
      if(MathAbs(fvg.mid - ob.mid) <= InpICTConfRadius * g_ictTRExec)
         s += 3;
   }
   else if(fvg.valid || ob.valid)
      s += 1;
   if(bull ? g_ictSwBullOn : g_ictSwBearOn)
      s += 2;
   if(InpICTPowerHours && ICT_InPowerHour(now))
      s += 1;
   if(g_ictH1Conf)
      s += 2;
   return s;
}

void ICT_DailyReset(const datetime now)
{
   MqlDateTime d;
   TimeToStruct(ICT_UTC(now), d);
   int key = d.year * 1000 + d.day_of_year;
   if(key != g_ictDayKey)
   {
      g_ictDayKey = key;
      g_ictDayTrades = 0;
      g_ictDayRisk = 0.0;
   }
}

void ICT_OnClosedTrade(const double net)
{
   if(net < 0.0)
      g_ictConsLoss++;
   else
      g_ictConsLoss = 0;
   if(InpICTMaxConsLoss > 0 && g_ictConsLoss >= InpICTMaxConsLoss)
   {
      g_ictCooldownUntil = TimeCurrent() + InpICTCooldownMin * 60;
      g_ictConsLoss = 0;   // sửa lỗi gốc: không khóa vô hạn
      Print("[ICT] Thua liên tiếp ", InpICTMaxConsLoss, " lệnh -> nghỉ tới ", TimeToString(g_ictCooldownUntil));
   }
}

double ICT_LossPerLot(const int dir, const double entry, const double sl)
{
   double profit = 0.0;
   if(OrderCalcProfit(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, 1.0, entry, sl, profit) && profit < 0.0)
      return -profit;
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0.0 || tv <= 0.0)
      return 0.0;
   return MathAbs(entry - sl) / ts * tv;
}

void ICT_TrySetup(const MqlTick &tick)
{
   datetime now = tick.time;
   g_ictLastScoreBuy  = ICT_Score(true, now);
   g_ictLastScoreSell = ICT_Score(false, now);

   if(!g_on[S_ICT])                               { g_ictReason = "TẮT"; return; }
   if(CountPosMagic(InpICTMagic) > 0 || CountOrdMagic(InpICTMagic) > 0) { g_ictReason = "ĐANG CÓ LỆNH / LỆNH CHỜ"; return; }
   if(now < g_ictCooldownUntil)                   { g_ictReason = "NGHỈ SAU CHUỖI THUA tới " + TimeToString(g_ictCooldownUntil, TIME_DATE | TIME_MINUTES); return; }
   if(InpICTMaxTradesDay > 0 && g_ictDayTrades >= InpICTMaxTradesDay) { g_ictReason = "ĐỦ SỐ SETUP TRONG NGÀY"; return; }
   if(!ICT_InKillzone(now))                       { g_ictReason = "NGOÀI KILLZONE"; return; }
   if(InpICTMaxSpread > 0.0 && tick.ask - tick.bid > InpICTMaxSpread + PriceEps()) { g_ictReason = "SPREAD QUÁ CAO"; return; }
   if(g_ictTRExec > 0 && g_ictTRBias > 0)
   {
      double vr = g_ictTRExec / g_ictTRBias;
      if(vr < InpICTVolMin || vr > InpICTVolMax)  { g_ictReason = StringFormat("BIẾN ĐỘNG NGOÀI NGƯỠNG (%.2f)", vr); return; }
   }
   if(GlobalBlocked(S_ICT))                       { g_ictReason = "CHỜ - chế độ 1 lệnh toàn EA"; return; }

   //--- Tín hiệu cũ > 5 giờ cần H1 xác nhận (giữ nguyên bản gốc)
   int soft = 5 * 3600;
   bool old = (g_ictFvgBull.valid && now - g_ictFvgBull.t > soft) || (g_ictFvgBear.valid && now - g_ictFvgBear.t > soft) ||
              (g_ictObBull.valid && now - g_ictObBull.t > soft)   || (g_ictObBear.valid && now - g_ictObBear.t > soft);
   if(old && !g_ictH1Conf)                        { g_ictReason = "TÍN HIỆU CŨ > 5 GIỜ - chờ H1 xác nhận"; return; }

   int dir = 0;
   if((g_ictBias >= 0) && g_ictLastScoreBuy >= InpICTMinScore)       dir = 1;
   else if((g_ictBias <= 0) && g_ictLastScoreSell >= InpICTMinScore) dir = -1;
   if(dir == 0)
   {
      g_ictReason = StringFormat("CHỜ HỢP LƯU (BUY %d / SELL %d, cần %d)", g_ictLastScoreBuy, g_ictLastScoreSell, InpICTMinScore);
      return;
   }

   ICTZone fvg, ob;
   if(dir > 0) { fvg = g_ictFvgBull; ob = g_ictObBull; }
   else        { fvg = g_ictFvgBear; ob = g_ictObBear; }
   if(!fvg.valid && !ob.valid) { g_ictReason = "KHÔNG CÓ VÙNG FVG/OB HỢP LỆ"; return; }

   double entry;
   if(fvg.valid && ob.valid) entry = (dir > 0 ? MathMin(fvg.entry, ob.entry) : MathMax(fvg.entry, ob.entry));
   else entry = (fvg.valid ? fvg.entry : ob.entry);

   double sl;
   bool swept = (dir > 0 ? g_ictSwBullOn : g_ictSwBearOn);
   if(swept)
      sl = (dir > 0 ? g_ictSwBullPx - InpICTSLBuffer * g_ictTRExec : g_ictSwBearPx + InpICTSLBuffer * g_ictTRExec);
   else
   {
      double zone;
      if(dir > 0) zone = (fvg.valid && ob.valid ? MathMin(fvg.low, ob.low) : (fvg.valid ? fvg.low : ob.low));
      else        zone = (fvg.valid && ob.valid ? MathMax(fvg.high, ob.high) : (fvg.valid ? fvg.high : ob.high));
      sl = (dir > 0 ? zone - InpICTSLBuffer * g_ictTRExec : zone + InpICTSLBuffer * g_ictTRExec);
   }
   sl = NormalizePrice(sl);

   //--- Market hay Limit
   bool useLimit = false;
   if(InpICTUseLimit)
      useLimit = (dir > 0 ? tick.bid > entry : tick.ask < entry);
   double px = (useLimit ? NormalizePrice(entry) : (dir > 0 ? tick.ask : tick.bid));
   double risk = (dir > 0 ? px - sl : sl - px);
   if(risk <= 0)                                            { g_ictReason = "SL NẰM SAI PHÍA GIÁ VÀO"; return; }
   if(InpICTSLMaxTR > 0 && risk > InpICTSLMaxTR * g_ictTRExec) { g_ictReason = "SL QUÁ XA (theo TR)"; return; }
   if(InpICTSLMaxPrice > 0 && risk > InpICTSLMaxPrice)      { g_ictReason = "SL QUÁ XA (theo giá)"; return; }
   double tp = NormalizePrice(dir > 0 ? px + InpICTTPRR * risk : px - InpICTTPRR * risk);

   double minD = MinStopDistance();
   if(risk < minD || MathAbs(tp - px) < minD)               { g_ictReason = "SL/TP VI PHẠM STOPSLEVEL"; return; }
   if(useLimit && MathAbs((dir > 0 ? tick.ask : tick.bid) - px) < minD) { g_ictReason = "GIÁ LIMIT QUÁ SÁT GIÁ HIỆN TẠI"; return; }

   //--- Khối lượng
   double lossPerLot = ICT_LossPerLot(dir, px, sl);
   double lot;
   if(InpICTFixedLot > 0.0)
      lot = NormalizeVolumeDown(InpICTFixedLot);
   else
   {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpICTRiskPercent / 100.0;
      lot = (lossPerLot > 0 ? NormalizeVolumeDown(riskMoney / lossPerLot) : 0.0);
   }
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lot < mn - 1e-9)                                      { g_ictReason = "LOT THEO RỦI RO < VOLUME MIN - bỏ setup"; return; }
   if(lot > mx) lot = NormalizeVolumeDown(mx);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE), eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpICTMaxDDPercent > 0 && bal > 0 && (bal - eq) / bal * 100.0 >= InpICTMaxDDPercent) { g_ictReason = "DRAWDOWN VƯỢT NGƯỠNG"; return; }
   double newRiskPct = (bal > 0 ? lot * lossPerLot / bal * 100.0 : 0.0);
   if(InpICTMaxDailyRisk > 0 && g_ictDayRisk + newRiskPct > InpICTMaxDailyRisk + 1e-9) { g_ictReason = "VƯỢT NGÂN SÁCH RỦI RO NGÀY"; return; }

   //--- Gửi 1 lệnh duy nhất
   string cmt = StratComment(S_ICT);
   bool ok;
   if(useLimit)
      ok = (dir > 0 ? g_tradeICT.BuyLimit(lot, px, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                    : g_tradeICT.SellLimit(lot, px, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt));
   else
      ok = (dir > 0 ? g_tradeICT.Buy(lot, _Symbol, 0.0, sl, tp, cmt)
                    : g_tradeICT.Sell(lot, _Symbol, 0.0, sl, tp, cmt));
   uint rc = g_tradeICT.ResultRetcode();
   //--- tính setup đã dùng dù thành công hay lỗi -> không gửi lặp trong cùng nến
   g_ictDayTrades++;
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
   {
      g_ictDayRisk += newRiskPct;
      g_ictReason = StringFormat("ĐÃ VÀO %s %s %.2f lot @ %s | SL %s | TP %s (1:%.1f)", (dir > 0 ? "BUY" : "SELL"),
                                 (useLimit ? "LIMIT" : "MARKET"), lot, Px(px), Px(sl), Px(tp), InpICTTPRR);
      Print("[ICT] ", g_ictReason, " | điểm ", (dir > 0 ? g_ictLastScoreBuy : g_ictLastScoreSell), " | ", cmt);
      //--- vùng đã dùng -> vô hiệu, tránh vào lại cùng vùng
      if(dir > 0) { g_ictFvgBull.valid = false; g_ictObBull.valid = false; g_ictSwBullOn = false; }
      else        { g_ictFvgBear.valid = false; g_ictObBear.valid = false; g_ictSwBearOn = false; }
   }
   else
   {
      g_ictReason = StringFormat("GỬI LỆNH LỖI retcode=%u", rc);
      Print("[ICT] ", g_ictReason, " ", g_tradeICT.ResultRetcodeDescription());
   }
}

//--- Quản lý: hủy Limit quá hạn, BE, trailing (LUÔN chạy)
void ICT_Manage(const MqlTick &tick)
{
   //--- Hủy lệnh Limit quá hạn
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != (long)InpICTMagic) continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(InpICTLimitExpiryH > 0 && tick.time - setup >= InpICTLimitExpiryH * 3600)
      {
         if(g_tradeICT.OrderDelete(tk))
            Print("[ICT] Hủy lệnh Limit quá hạn #", tk);
      }
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpICTMagic) continue;
      ulong  pid  = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool   buy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      //--- R theo SL BAN ĐẦU (đọc 1 lần từ deal vào lệnh)
      if(pid != g_ictPosId)
      {
         g_ictPosId = pid;
         g_ictInitRisk = MathAbs(open - sl);
         if(HistorySelectByPosition(pid))
         {
            for(int k = 0; k < HistoryDealsTotal(); k++)
            {
               ulong d = HistoryDealGetTicket(k);
               if(d > 0 && HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetDouble(d, DEAL_SL) > 0)
               {
                  g_ictInitRisk = MathAbs(open - HistoryDealGetDouble(d, DEAL_SL));
                  break;
               }
            }
         }
      }
      if(g_ictInitRisk <= 0)
         continue;
      double cur = (buy ? tick.bid : tick.ask);
      double R = (buy ? cur - open : open - cur) / g_ictInitRisk;
      double minD = MinStopDistance();
      double newSL = sl;

      if(InpICTBreakEvenR > 0 && R >= InpICTBreakEvenR)
      {
         double be = NormalizePrice(open);
         if(buy ? (sl < be) : (sl > be || sl <= 0))
            newSL = be;
      }
      if(InpICTTrailing && R >= InpICTTrailActR && g_ictTRExec > 0)
      {
         double tr = NormalizePrice(buy ? cur - InpICTTrailTR * g_ictTRExec : cur + InpICTTrailTR * g_ictTRExec);
         if(buy ? (tr > newSL + InpICTTrailStep) : (newSL <= 0 || tr < newSL - InpICTTrailStep))
            newSL = tr;
      }
      if(newSL != sl && (buy ? cur - newSL >= minD : newSL - cur >= minD))
      {
         if(!g_tradeICT.PositionModify(t, newSL, tp))
            Print("[ICT] Dời SL thất bại retcode=", g_tradeICT.ResultRetcode());
      }
   }
}

void ProcessICT(const MqlTick &tick)
{
   datetime now = tick.time;
   ICT_Manage(tick);
   ICT_DailyReset(now);

   //--- Hủy lệnh Limit khi chiến lược bị tắt
   if(!g_on[S_ICT] && CountOrdMagic(InpICTMagic) > 0)
      DeletePendingMagic(InpICTMagic, g_tradeICT);

   //--- Cập nhật cấu trúc theo nến mới (chỉ dùng nến đã đóng)
   datetime biasBar = iTime(_Symbol, InpICTBiasTF, 0);
   if(biasBar > 0 && biasBar != g_ictLastBiasBar)
   {
      g_ictLastBiasBar = biasBar;
      g_ictTRBias = ICT_TR(InpICTBiasTF, InpICTTRPeriodBias);
      ICT_DetectSwings(InpICTBiasTF, g_ictHiBias, g_ictLoBias);
      ICT_DetectBOS();
   }
   datetime confBar = iTime(_Symbol, InpICTConfirmTF, 0);
   if(confBar > 0 && confBar != g_ictLastConfBar)
   {
      g_ictLastConfBar = confBar;
      g_ictTRConf = ICT_TR(InpICTConfirmTF, InpICTTRPeriodConf);
      ICT_CheckConfirm();
   }
   datetime execBar = iTime(_Symbol, InpICTExecTF, 0);
   if(execBar > 0 && execBar != g_ictLastExecBar)
   {
      g_ictLastExecBar = execBar;
      g_ictTRExec = ICT_TR(InpICTExecTF, InpICTTRPeriodExec);
      ICT_ExpireZones(tick);
      ICT_DetectSwings(InpICTExecTF, g_ictHiExec, g_ictLoExec);
      ICT_DetectSweep();
      ICT_DetectFVG(now);
      ICT_DetectOB(now);
      ICT_TrySetup(tick);
   }

   int pos = CountPosMagic(InpICTMagic), ord = CountOrdMagic(InpICTMagic);
   string state;
   if(pos > 0)       state = (g_on[S_ICT] ? "ĐANG CÓ LỆNH - quản lý BE/trailing" : "TẮT VÀO LỆNH MỚI - vẫn quản lý lệnh đang mở");
   else if(ord > 0)  state = "ĐANG CHỜ KHỚP LỆNH LIMIT";
   else if(!g_on[S_ICT]) state = "TẮT";
   else              state = (g_ictReason == "" ? "CHỜ NẾN MỚI " + EnumToString(InpICTExecTF) : g_ictReason);
   g_stLine1[S_ICT] = state;
   g_stLine2[S_ICT] = StringFormat("M%I64u • Bias %s • H1 %s • Điểm B%d/S%d (≥%d) • FVG %s%s • OB %s%s • Sweep %s%s • Ngày %d/%d",
                                   InpICTMagic, (g_ictBias > 0 ? "TĂNG" : (g_ictBias < 0 ? "GIẢM" : "TRUNG TÍNH")),
                                   (g_ictH1Conf ? "OK" : "-"), g_ictLastScoreBuy, g_ictLastScoreSell, InpICTMinScore,
                                   (g_ictFvgBull.valid ? "B" : ""), (g_ictFvgBear.valid ? "S" : ""),
                                   (g_ictObBull.valid ? "B" : ""), (g_ictObBear.valid ? "S" : ""),
                                   (g_ictSwBullOn ? "B" : ""), (g_ictSwBearOn ? "S" : ""),
                                   g_ictDayTrades, InpICTMaxTradesDay);
}

//####################################################################
//##  1. CRT - xử lý mỗi tick (logic V1.03 giữ nguyên, chỉ tách hàm)  ##
//##  Comment lệnh riêng: InpCRTComment (kèm 0941920986 @adsmmo8386)  ##
//####################################################################
void UpdateCRTStatusLines()
{
   string st = DashboardStatusVN(g.status);
   if(!g_on[S_CRT])
      st = (g.traded && (g.status == ST_BUY_ACTIVE || g.status == ST_SELL_ACTIVE)) ? "TẮT VÀO LỆNH MỚI - lệnh đang mở do SL/TP sàn quản lý" : "TẮT";
   string ref = (g.refTime > 0 ? TimeHM(g.refTime) + "-" + TimeHM(g.refEnd) : "-");
   string act = (g.activeStart > 0 ? TimeHM(g.activeStart) + "-" + TimeHM(g.activeEnd) : "-");
   g_stLine1[S_CRT] = st + " • Ref " + ref + " • Active " + act;

   string sw = "";
   if(g.lowSwept)  sw += " • Sweep L " + Px(g.sweepLow);
   if(g.highSwept) sw += " • Sweep H " + Px(g.sweepHigh);
   string cf = (g.confirmed ? " • M15 " + (g.confirmDir > 0 ? "BUY " : "SELL ") + Px(g.confirmClose) : "");
   string tr = (g.traded && g.entryPrice > 0 ? StringFormat(" • Entry %s SL %s TP %s RR 1:%.2f", Px(g.entryPrice), Px(g.slPrice), Px(g.tpPrice), g.rr) : "");
   g_stLine2[S_CRT] = StringFormat("M%I64u • H %s L %s • Bias %s", InpMagic,
                                   (g.refTime > 0 ? Px(g.crtHigh) : "-"), (g.refTime > 0 ? Px(g.crtLow) : "-"),
                                   DashboardBiasText()) + sw + cf + tr;
}

void ProcessCRT(const MqlTick &tick)
{
   datetime now = tick.time;

   //--- 0. Khởi tạo (dữ liệu H4 có thể chưa sẵn sàng ở OnInit)
   if(!g_ready)
   {
      g_ready = InitializeRange(true);
      if(!g_ready)
         return;
   }

   //--- 1. H4 mới -> Range cũ hết hạn, tạo Range mới từ H4[1] vừa đóng
   if(DetectNewH4Bar())
   {
      ExpireCurrentRange("H4 mới bắt đầu");
      SaveCRTState();
      InitializeRange(false);
   }

   //--- Hết Active window nhưng series H4 chưa cập nhật -> hết hạn ngay
   if(RangeIsLive() && now >= g.activeEnd)
      ExpireCurrentRange("quá Active End");

   //--- 2. Bù sweep từ các nến M1 vừa đóng
   datetime m1Open0 = iTime(_Symbol, CRT_TF_REPLAY, 0);
   if(g.valid && m1Open0 > 0 && m1Open0 != g_lastM1Seen)
   {
      g_lastM1Seen = m1Open0;
      if(RangeIsLive())
         ReplayClosedM1(false);
   }

   //--- 3. M15 vừa đóng -> Confirmation trên M15[1] -> Entry tại tick này
   if(g.valid)
   {
      MqlRates m15Closed;
      if(DetectNewM15Bar(m15Closed))
      {
         if(CheckM15Confirmation(m15Closed.time, m15Closed.close, true))
         {
            if(GlobalBlocked(S_CRT))
               SkipSignal("CRT SIGNAL BỊ BỎ QUA: CHẾ ĐỘ 1 LỆNH TOÀN EA ĐANG CÓ LỆNH KHÁC");
            else
               ExecuteCRTTrade(g.confirmDir, tick);
         }
      }
   }

   //--- 4. Sweep realtime theo Bid
   if(RangeIsLive() && now >= g.activeStart && now < g.activeEnd)
   {
      int      m15Sec      = PeriodSeconds(CRT_TF_CONFIRM);
      datetime tickM15Open = (datetime)((long)now - ((long)now % m15Sec));
      datetime m15Open0    = iTime(_Symbol, CRT_TF_CONFIRM, 0);
      if(m15Open0 >= tickM15Open)
         DetectLiquiditySweep(tick.bid, tick.bid, now, now);
   }

   //--- 5. Theo dõi position của Range
   MonitorPosition();

   //--- 6. Lưu state + vẽ
   if(g_dirty)
   {
      SaveCRTState();
      DrawAllForCurrentRange();
      g_dirty = false;
   }
}

//--- Trạng thái chữ CRT (dùng lại từ Dashboard V1.03)
string DashboardStatusVN(int s)
{
   switch(s)
   {
      case ST_WAITING_RANGE:  return "CHỜ TẠO VÙNG H4";
      case ST_WAITING_SWEEP:  return "CHỜ QUÉT THANH KHOẢN";
      case ST_LOW_SWEPT:      return "ĐÃ QUÉT ĐÁY - KHÔNG ĐỦ QUYỀN BUY";
      case ST_HIGH_SWEPT:     return "ĐÃ QUÉT ĐỈNH - KHÔNG ĐỦ QUYỀN SELL";
      case ST_WAITING_M15:    return "ĐÃ SWEEP - CHỜ M15 ĐÓNG XÁC NHẬN";
      case ST_BUY_CONFIRMED:  return "ĐÃ XÁC NHẬN BUY";
      case ST_SELL_CONFIRMED: return "ĐÃ XÁC NHẬN SELL";
      case ST_BUY_ACTIVE:     return "BUY ĐANG CHẠY";
      case ST_SELL_ACTIVE:    return "SELL ĐANG CHẠY";
      case ST_TRADED:         return "ĐÃ XONG - CHỜ H4 MỚI";
      case ST_INVALID_BOTH:   return "HỦY - ĐÃ QUÉT CẢ HAI ĐẦU";
      case ST_EXPIRED:        return "HẾT HẠN RANGE";
      case ST_RANGE_ERROR:    return "LỖI DỮ LIỆU RANGE";
      case ST_SIGNAL_SKIPPED: return "TÍN HIỆU ĐÃ BỎ QUA";
   }
   return "KHÔNG XÁC ĐỊNH";
}

string DashboardBiasText()
{
   if(g.bias == CRT_BIAS_BUY)  return "BUY";
   if(g.bias == CRT_BIAS_SELL) return "SELL";
   if(g.bias == CRT_BIAS_BOTH) return "BOTH";
   return "NONE";
}

//####################################################################
//##  BẢNG BOARD - theo mẫu David Multi Method Board V1.00            ##
//##  + Nút "−" / "+" thu gọn / mở rộng bảng                          ##
//##  + Nút BẬT/TẮT từng phương pháp ngay trên biểu đồ                ##
//##  + 2 dòng trạng thái chi tiết cho từng phương pháp               ##
//##  Thống kê theo Magic: Thắng / Thua / Hòa / Winrate / Lãi-lỗ ròng.##
//####################################################################
struct BoardMethod
{
   string name;
   string desc;
   long   magic;
   bool   on;
   bool   inputOn;
   string line1;
   string line2;
   int    wins, losses, breakeven, opened, pending;
   double net, floating;
};

struct BoardRecord
{
   ulong    id;
   int      method;
   bool     hasEntry, hasExit, ambiguous, reversed, relevant;
   double   incoming, outgoing, net;
   datetime closed;
};

struct BoardLive
{
   ulong  ticket;
   int    method;
   long   side;
   double lot, entry, sl, tp, floating;
};

class CDavidBoard
{
private:
   long        m_chart;
   string      m_prefix, m_error, m_keep[];
   BoardMethod m_methods[];
   BoardRecord m_records[];
   BoardLive   m_live[];
   int         m_period;            // 0 hôm nay, 1 tháng, 2 toàn bộ
   int         m_x, m_y, m_refresh, m_page, m_perPage, m_excluded;
   double      m_userScale, m_scale;
   datetime    m_scanned, m_periodStart, m_firstHistory;
   bool        m_lines, m_historyOk, m_dirty, m_collapsed, m_ready;
   color       m_bg, m_panel, m_border, m_text, m_muted, m_green, m_red, m_blue, m_gold;

   int    Pxs(const double v)  { return (int)MathRound(v * m_scale); }
   string Cut(const string s, const int n) { if(StringLen(s) <= n) return s; return StringSubstr(s, 0, n - 1) + "…"; }
   string Signed(const double v) { return (v > 0 ? "+" : "") + DoubleToString(v, 2); }
   color  PLColor(const double v) { return (v > 0.005 ? m_green : (v < -0.005 ? m_red : m_muted)); }
   string Rate(const int w, const int l, const int b) { int n = w + l + b; return (n > 0 ? DoubleToString(100.0 * w / n, 1) + "%" : "—"); }

   datetime PeriodStartTime()
   {
      if(m_period == 2) return 0;
      MqlDateTime d;
      TimeToStruct(TimeCurrent(), d);
      d.hour = 0; d.min = 0; d.sec = 0;
      if(m_period == 1) d.day = 1;
      return StructToTime(d);
   }
   string PeriodText() { return (m_period == 0 ? "HÔM NAY" : (m_period == 1 ? "THÁNG NÀY" : "TOÀN BỘ")); }

   int MethodFromMagic(const long magic)
   {
      for(int i = 0; i < ArraySize(m_methods); i++)
         if(m_methods[i].magic == magic)
            return i;
      return -1;
   }

   int RecordIndex(const ulong id, const bool create)
   {
      int lo = 0, hi = ArraySize(m_records) - 1;
      while(lo <= hi)
      {
         int mid = (lo + hi) / 2;
         if(m_records[mid].id == id) return mid;
         if(m_records[mid].id < id) lo = mid + 1; else hi = mid - 1;
      }
      if(!create) return -1;
      int n = ArraySize(m_records);
      if(ArrayResize(m_records, n + 1, 2048) != n + 1) return -1;
      for(int j = n; j > lo; j--) m_records[j] = m_records[j - 1];
      BoardRecord r;
      ZeroMemory(r);
      r.id = id;
      r.method = -1;
      m_records[lo] = r;
      return lo;
   }

   bool IsOpenId(const ulong id)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetTicket(i) == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_IDENTIFIER) == id)
            return true;
      }
      return false;
   }

   void ScanHistory()
   {
      m_historyOk = HistorySelect(0, TimeCurrent() + 60);
      if(!m_historyOk) { m_error = "Chưa đọc được lịch sử; sẽ thử lại."; return; }
      m_error = ""; m_excluded = 0; m_firstHistory = 0;
      ArrayResize(m_records, 0);
      for(int j = 0; j < ArraySize(m_methods); j++)
      {
         m_methods[j].wins = 0; m_methods[j].losses = 0; m_methods[j].breakeven = 0; m_methods[j].net = 0;
      }
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
         ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
         if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
         ulong id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
         if(id == 0) continue;
         int k = RecordIndex(id, true);
         if(k < 0) { m_historyOk = false; m_error = "Thiếu bộ nhớ lịch sử."; return; }
         datetime tm = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
         if(m_firstHistory == 0 || tm < m_firstHistory) m_firstHistory = tm;
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
         double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
         m_records[k].net += HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP)
                           + HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
         if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         {
            int owner = MethodFromMagic(HistoryDealGetInteger(deal, DEAL_MAGIC));
            if(owner >= 0) m_records[k].relevant = true;
            if(!m_records[k].hasEntry) m_records[k].method = owner;
            else if(m_records[k].method != owner) m_records[k].ambiguous = true;
            m_records[k].hasEntry = true;
            m_records[k].incoming += vol;
            if(entry == DEAL_ENTRY_INOUT) m_records[k].reversed = true;
         }
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
         {
            m_records[k].outgoing += vol;
            m_records[k].hasExit = true;
            if(tm > m_records[k].closed) m_records[k].closed = tm;
         }
      }
      m_periodStart = PeriodStartTime();
      double tol = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) * 0.1, 0.0000001);
      for(int i = 0; i < ArraySize(m_records); i++)
      {
         if(!m_records[i].relevant) continue;
         if(m_records[i].ambiguous || m_records[i].reversed || m_records[i].method < 0) { m_excluded++; continue; }
         if(!m_records[i].hasEntry || !m_records[i].hasExit) continue;
         if(MathAbs(m_records[i].incoming - m_records[i].outgoing) > tol || IsOpenId(m_records[i].id)) continue;
         if(m_records[i].closed < m_periodStart) continue;
         int k = m_records[i].method;
         double p = m_records[i].net;
         m_methods[k].net += p;
         if(p > 0.005) m_methods[k].wins++;
         else if(p < -0.005) m_methods[k].losses++;
         else m_methods[k].breakeven++;
      }
      m_scanned = TimeCurrent();
      m_dirty = false;
   }

   void ReadLive()
   {
      ArrayResize(m_live, 0);
      for(int i = 0; i < ArraySize(m_methods); i++)
      {
         m_methods[i].opened = 0; m_methods[i].floating = 0;
         m_methods[i].pending = CountOrdMagic((ulong)m_methods[i].magic);
      }
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         ulong id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
         int r = RecordIndex(id, false), k;
         if(r >= 0)
         {
            if(!m_records[r].relevant) continue;
            k = (m_records[r].ambiguous || m_records[r].reversed) ? -1 : m_records[r].method;
         }
         else
         {
            k = MethodFromMagic(PositionGetInteger(POSITION_MAGIC));
            if(k < 0) continue;
         }
         int n = ArraySize(m_live);
         ArrayResize(m_live, n + 1);
         m_live[n].ticket = ticket; m_live[n].method = k;
         m_live[n].side = PositionGetInteger(POSITION_TYPE);
         m_live[n].lot = PositionGetDouble(POSITION_VOLUME);
         m_live[n].entry = PositionGetDouble(POSITION_PRICE_OPEN);
         m_live[n].sl = PositionGetDouble(POSITION_SL);
         m_live[n].tp = PositionGetDouble(POSITION_TP);
         m_live[n].floating = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(k >= 0) { m_methods[k].opened++; m_methods[k].floating += m_live[n].floating; }
      }
   }

   string Keep(const string key)
   {
      string n = m_prefix + key;
      int s = ArraySize(m_keep);
      ArrayResize(m_keep, s + 1, 256);
      m_keep[s] = n;
      return n;
   }

   void CleanupStale()
   {
      for(int i = ObjectsTotal(m_chart, -1, -1) - 1; i >= 0; i--)
      {
         string n = ObjectName(m_chart, i, -1, -1);
         if(StringFind(n, m_prefix) != 0) continue;
         bool keep = false;
         for(int j = 0; j < ArraySize(m_keep); j++)
            if(m_keep[j] == n) { keep = true; break; }
         if(!keep) ObjectDelete(m_chart, n);
      }
   }

   void Common(const string n)
   {
      ObjectSetInteger(m_chart, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chart, n, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chart, n, OBJPROP_HIDDEN, true);
   }

   void Box(const string key, const double x, const double y, const double w, const double h, const color bg, const color border)
   {
      string n = Keep(key);
      if(ObjectFind(m_chart, n) < 0) ObjectCreate(m_chart, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      Common(n);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, m_x + Pxs(x));
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, m_y + Pxs(y));
      ObjectSetInteger(m_chart, n, OBJPROP_XSIZE, MathMax(1, Pxs(w)));
      ObjectSetInteger(m_chart, n, OBJPROP_YSIZE, MathMax(1, Pxs(h)));
      ObjectSetInteger(m_chart, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, border);
      ObjectSetInteger(m_chart, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chart, n, OBJPROP_WIDTH, 1);
   }

   void Text(const string key, const double x, const double y, const string value, const color c, const int font = 10, const bool bold = false)
   {
      string n = Keep(key);
      if(ObjectFind(m_chart, n) < 0) ObjectCreate(m_chart, n, OBJ_LABEL, 0, 0, 0);
      Common(n);
      ObjectSetInteger(m_chart, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, m_x + Pxs(x));
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, m_y + Pxs(y));
      ObjectSetInteger(m_chart, n, OBJPROP_FONTSIZE, (int)MathMax(7, Pxs(font)));
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, c);
      ObjectSetString(m_chart, n, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
      ObjectSetString(m_chart, n, OBJPROP_TEXT, value);
   }

   void Button(const string key, const double x, const double y, const double w, const double h, const string label,
               const color bg, const color fg, const color border, const int font = 9)
   {
      string n = Keep(key);
      if(ObjectFind(m_chart, n) < 0) ObjectCreate(m_chart, n, OBJ_BUTTON, 0, 0, 0);
      Common(n);
      ObjectSetInteger(m_chart, n, OBJPROP_XDISTANCE, m_x + Pxs(x));
      ObjectSetInteger(m_chart, n, OBJPROP_YDISTANCE, m_y + Pxs(y));
      ObjectSetInteger(m_chart, n, OBJPROP_XSIZE, Pxs(w));
      ObjectSetInteger(m_chart, n, OBJPROP_YSIZE, Pxs(h));
      ObjectSetInteger(m_chart, n, OBJPROP_FONTSIZE, (int)MathMax(7, Pxs(font)));
      ObjectSetInteger(m_chart, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, fg);
      ObjectSetInteger(m_chart, n, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(m_chart, n, OBJPROP_ZORDER, 20);
      ObjectSetInteger(m_chart, n, OBJPROP_STATE, false);
      ObjectSetString(m_chart, n, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetString(m_chart, n, OBJPROP_TEXT, label);
   }

   void TabButton(const string key, const double x, const double y, const double w, const string label, const bool active)
   {
      Button(key, x, y, w, 26, label, (active ? C'27,70,74' : m_panel), (active ? m_green : m_muted), (active ? m_green : m_border));
   }

   void Level(const string key, const double price, const color c, const string text, const ENUM_LINE_STYLE style)
   {
      if(price <= 0) return;
      string n = Keep(key);
      if(ObjectFind(m_chart, n) < 0) ObjectCreate(m_chart, n, OBJ_HLINE, 0, 0, price);
      ObjectSetDouble(m_chart, n, OBJPROP_PRICE, price);
      ObjectSetInteger(m_chart, n, OBJPROP_COLOR, c);
      ObjectSetInteger(m_chart, n, OBJPROP_STYLE, style);
      ObjectSetInteger(m_chart, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chart, n, OBJPROP_BACK, true);
      ObjectSetInteger(m_chart, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, n, OBJPROP_HIDDEN, true);
      ObjectSetString(m_chart, n, OBJPROP_TEXT, text);
   }

   string MethodName(const int k) { return (k >= 0 ? m_methods[k].name : "GỘP PP"); }

   void DrawCollapsed()
   {
      int wins = 0, losses = 0, be = 0; double net = 0, fl = 0; int onCount = 0;
      for(int i = 0; i < ArraySize(m_methods); i++)
      {
         wins += m_methods[i].wins; losses += m_methods[i].losses; be += m_methods[i].breakeven;
         net += m_methods[i].net; fl += m_methods[i].floating;
         if(m_methods[i].on) onCount++;
      }
      Box("frame", 0, 0, 470, 46, m_bg, m_border);
      Box("accent", 0, 0, 470, 3, m_green, m_green);
      Text("title", 14, 12, CRT_EA_NAME, m_text, 11, true);
      Text("mini", 175, 15, StringFormat("%d/%d PP bật • WR %s • %s %s", onCount, ArraySize(m_methods),
                                         Rate(wins, losses, be), PeriodText(), Signed(net)), PLColor(net), 9);
      Button("collapse", 428, 10, 30, 26, "+", m_panel, m_green, m_green, 12);
   }

   void Draw()
   {
      ArrayResize(m_keep, 0);
      int width  = (int)ChartGetInteger(m_chart, CHART_WIDTH_IN_PIXELS);
      int height = (int)ChartGetInteger(m_chart, CHART_HEIGHT_IN_PIXELS, 0);
      m_scale = MathMin(m_userScale, MathMax(0.55, (width - m_x - 12) / 860.0));
      if(m_collapsed)
      {
         DrawCollapsed();
         CleanupStale();
         ChartRedraw(m_chart);
         return;
      }

      int methods = ArraySize(m_methods), live = ArraySize(m_live);
      int wins = 0, losses = 0, be = 0; double net = 0, floating = 0;
      for(int i = 0; i < methods; i++)
      {
         wins += m_methods[i].wins; losses += m_methods[i].losses; be += m_methods[i].breakeven; net += m_methods[i].net;
      }
      for(int i = 0; i < live; i++) floating += m_live[i].floating;

      const double rowH = 64;
      double y = 218 + methods * rowH;
      m_perPage = (int)MathMin(8, MathMax(1, MathFloor(((height - m_y) / m_scale - y - 160) / 42.0)));
      int pages = (live > 0 ? (live + m_perPage - 1) / m_perPage : 1);
      if(m_page >= pages) m_page = pages - 1;
      if(m_page < 0) m_page = 0;
      int first = m_page * m_perPage, shown = (int)MathMin(m_perPage, live - first);
      double footer = (live > 0 ? y + 87 + shown * 42 : y + 8);

      Box("shadow", 4, 5, 840, footer + 88, C'5,9,15', C'5,9,15');
      Box("frame", 0, 0, 840, footer + 88, m_bg, m_border);
      Box("accent", 0, 0, 840, 3, m_green, m_green);
      Text("title", 22, 15, "DAVID • MULTI METHOD V1.04", m_text, 16, true);
      Text("subtitle", 22, 47, _Symbol + "  •  " + AccountInfoString(ACCOUNT_CURRENCY) + "  •  PHÂN LOẠI MAGIC  •  4 PP ĐƠN LỆNH", m_muted, 9);
      bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      Text("connection", 560, 19, (connected ? "● ĐANG KẾT NỐI" : "● MẤT KẾT NỐI"), (connected ? m_green : m_red), 9, true);
      Button("collapse", 790, 13, 30, 26, "−", m_panel, m_gold, m_border, 12);
      TabButton("today", 504, 46, 96, "Hôm nay", m_period == 0);
      TabButton("month", 607, 46, 102, "Tháng này", m_period == 1);
      TabButton("all", 716, 46, 103, "Toàn bộ", m_period == 2);

      string labels[4] = {"VỊ THẾ ĐÃ ĐÓNG", "WINRATE TỔNG", "LÃI/LỖ ĐÃ ĐÓNG", "THẢ NỔI HIỆN TẠI"};
      string values[4];
      values[0] = (m_historyOk ? IntegerToString(wins + losses + be) : "—");
      values[1] = (m_historyOk ? Rate(wins, losses, be) : "—");
      values[2] = (m_historyOk ? Signed(net) : "—");
      values[3] = Signed(floating);
      for(int i = 0; i < 4; i++)
      {
         string s = IntegerToString(i); double x = 20 + i * 201;
         Box("card" + s, x, 83, 195, 66, m_panel, m_border);
         Text("cardlabel" + s, x + 12, 92, labels[i], m_muted, 9);
         Text("cardvalue" + s, x + 12, 112, values[i], (i == 2 ? PLColor(net) : (i == 3 ? PLColor(floating) : m_text)), 19, true);
      }

      Text("tabletitle", 22, 163, "HIỆU SUẤT TỪNG PHƯƠNG PHÁP", m_text, 10, true);
      Text("sample", 470, 164, "Bấm BẬT/TẮT để bật tắt PP • Thắng/(Thắng+Thua+Hòa)", m_muted, 8);
      Box("thead", 20, 188, 800, 30, C'29,40,56', C'29,40,56');
      Text("hmethod", 31, 194, "PHƯƠNG PHÁP", m_muted, 9);
      Text("hclosed", 232, 194, "ĐÓNG", m_muted, 9);
      Text("hw", 293, 194, "THẮNG", m_green, 9);
      Text("hl", 360, 194, "THUA", m_red, 9);
      Text("hbe", 424, 194, "HÒA", m_muted, 9);
      Text("hwr", 486, 194, "WINRATE", m_muted, 9);
      Text("hprofit", 638, 194, "LÃI/LỖ", m_muted, 9);
      Text("hstate", 738, 194, "MỞ/CHỜ", m_muted, 9);

      for(int i = 0; i < methods; i++)
      {
         string s = IntegerToString(i); double row = 218 + i * rowH;
         color bg = (i % 2 == 0 ? C'19,28,41' : C'23,33,47');
         Box("row" + s, 20, row, 800, rowH, bg, bg);
         Text("name" + s, 32, row + 6, m_methods[i].name, (m_methods[i].on ? m_text : m_muted), 11, true);
         //--- Nút BẬT/TẮT phương pháp
         bool on = m_methods[i].on;
         Button("sw" + s, 82, row + 6, 64, 22, (on ? "● BẬT" : "○ TẮT"),
                (on ? C'22,70,58' : C'70,30,38'), (on ? m_green : m_red), (on ? m_green : m_red), 8);
         Text("desc" + s, 154, row + 10, Cut(m_methods[i].desc, 12), m_muted, 7);

         int w = m_methods[i].wins, l = m_methods[i].losses, b = m_methods[i].breakeven, n = w + l + b;
         Text("n" + s, 240, row + 8, (m_historyOk ? IntegerToString(n) : "—"), m_text, 10);
         Text("w" + s, 310, row + 8, (m_historyOk ? IntegerToString(w) : "—"), m_green, 10);
         Text("l" + s, 376, row + 8, (m_historyOk ? IntegerToString(l) : "—"), m_red, 10);
         Text("b" + s, 435, row + 8, (m_historyOk ? IntegerToString(b) : "—"), m_muted, 10);
         color wr = (n > 0 ? (100.0 * w / n >= 50 ? m_green : m_gold) : m_muted);
         Text("wr" + s, 487, row + 6, (m_historyOk ? Rate(w, l, b) : "—"), wr, 12, true);
         Box("track" + s, 563, row + 15, 52, 5, m_border, m_border);
         if(m_historyOk && w > 0 && n > 0) Box("bar" + s, 563, row + 15, MathMax(1, 52.0 * w / n), 5, wr, wr);
         Text("profit" + s, 638, row + 8, (m_historyOk ? Signed(m_methods[i].net) : "—"), PLColor(m_methods[i].net), 10, true);
         Text("state" + s, 750, row + 8, IntegerToString(m_methods[i].opened) + " / " + IntegerToString(m_methods[i].pending),
              (m_methods[i].opened > 0 ? m_blue : (m_methods[i].pending > 0 ? m_gold : m_muted)), 10, true);
         //--- 2 dòng trạng thái chi tiết
         color c1 = (!on ? m_red : (m_methods[i].opened > 0 ? m_blue : m_gold));
         Text("st1" + s, 32, row + 31, Cut(m_methods[i].line1, 118), c1, 8);
         Text("st2" + s, 32, row + 46, Cut(m_methods[i].line2, 128), m_muted, 8);
      }

      if(live > 0)
      {
         Text("livetitle", 22, y + 22, "VỊ THẾ ĐANG MỞ  •  " + IntegerToString(live), m_blue, 10, true);
         if(pages > 1)
         {
            Text("page", 607, y + 23, IntegerToString(m_page + 1) + " / " + IntegerToString(pages), m_muted, 9);
            Button("prev", 713, y + 15, 47, 26, "<", m_panel, m_muted, m_border);
            Button("next", 769, y + 15, 47, 26, ">", m_panel, m_muted, m_border);
         }
         Box("livehead", 20, y + 49, 800, 29, C'29,40,56', C'29,40,56');
         Text("lm", 32, y + 55, "PP / TICKET", m_muted, 9);
         Text("lside", 205, y + 55, "LỆNH / LOT", m_muted, 9);
         Text("lentry", 335, y + 55, "ENTRY", m_blue, 9);
         Text("lsl", 459, y + 55, "STOP LOSS", m_red, 9);
         Text("ltp", 585, y + 55, "TAKE PROFIT", m_green, 9);
         Text("lpl", 717, y + 55, "THẢ NỔI", m_muted, 9);
         for(int j = 0; j < shown; j++)
         {
            int i = first + j; string s = IntegerToString(j); double row = y + 78 + j * 42;
            color bg = (j % 2 == 0 ? C'19,28,41' : C'23,33,47');
            Box("livebg" + s, 20, row, 800, 42, bg, bg);
            Text("livepp" + s, 32, row + 3, Cut(MethodName(m_live[i].method), 16), m_text, 10, true);
            Text("liveticket" + s, 32, row + 22, "#" + IntegerToString((long)m_live[i].ticket), m_muted, 8);
            bool buy = (m_live[i].side == POSITION_TYPE_BUY);
            Text("liveside" + s, 205, row + 11, (buy ? "BUY " : "SELL ") + DoubleToString(m_live[i].lot, 2), (buy ? m_green : m_red), 10, true);
            Text("liveentry" + s, 335, row + 11, DoubleToString(m_live[i].entry, _Digits), m_blue, 11);
            Text("livesl" + s, 459, row + 11, (m_live[i].sl > 0 ? DoubleToString(m_live[i].sl, _Digits) : "Ẩn / chưa đặt"), (m_live[i].sl > 0 ? m_red : m_gold), 11);
            Text("livetp" + s, 585, row + 11, (m_live[i].tp > 0 ? DoubleToString(m_live[i].tp, _Digits) : "Ẩn / chưa đặt"), (m_live[i].tp > 0 ? m_green : m_gold), 11);
            Text("livepl" + s, 717, row + 11, Signed(m_live[i].floating), PLColor(m_live[i].floating), 11, true);
         }
         if(m_lines)
         {
            for(int i = 0; i < live; i++)
            {
               string id = IntegerToString((long)m_live[i].ticket);
               string label = MethodName(m_live[i].method) + " #" + id;
               Level("lv.e." + id, m_live[i].entry, m_blue, label + " ENTRY", STYLE_DOT);
               Level("lv.s." + id, m_live[i].sl, m_red, label + " SL", STYLE_DASH);
               Level("lv.t." + id, m_live[i].tp, m_green, label + " TP", STYLE_DASH);
            }
         }
      }

      string note = "Winrate = Thắng / (Thắng + Thua + Hòa). Lãi/lỗ ròng gồm swap + phí. Kỳ thống kê theo ngày đóng, giờ máy chủ.";
      if(!m_historyOk) note = m_error;
      else if(m_excluded > 0) note = "Đã loại " + IntegerToString(m_excluded) + " ID vị thế gộp nhiều PP / đảo chiều khỏi thống kê.";
      Text("foot1", 22, footer + 8, note, (m_excluded > 0 || !m_historyOk ? m_gold : m_muted), 8);
      string hist = (m_firstHistory > 0 ? TimeToString(m_firstHistory, TIME_DATE) : "chưa có");
      Text("foot2", 22, footer + 27, "Lịch sử từ: " + hist + "  •  " + PeriodText() + "  •  Tradelog: " +
           (InpTradeLog ? TradeLogFileName() + " (Common\\Files)" : "TẮT") + "  •  Cập nhật " + TimeToString(TimeCurrent(), TIME_SECONDS), m_muted, 8);
      Text("foot3", 22, footer + 50, "Liên hệ: 0941920986  •  Davidhunter  •  Telegram @adsmmo8386", m_gold, 9, true);
      CleanupStale();
      ChartRedraw(m_chart);
   }

public:
   bool Init(const long chart, const int period, const int x, const int y, const double scale, const int refresh,
             const bool lines, const bool collapsed)
   {
      m_chart = chart; m_prefix = "DAVIDMB."; m_period = period;
      m_x = (int)MathMax(0, x); m_y = (int)MathMax(0, y);
      m_userScale = MathMax(0.65, MathMin(1.8, scale)); m_scale = m_userScale;
      m_refresh = (int)MathMax(2, refresh); m_lines = lines;
      m_page = 0; m_scanned = 0; m_periodStart = 0; m_historyOk = false; m_dirty = true; m_collapsed = collapsed;
      m_bg = C'13,20,31'; m_panel = C'20,31,46'; m_border = C'41,56,75'; m_text = C'235,242,250';
      m_muted = C'145,163,184'; m_green = C'62,218,173'; m_red = C'255,111,127'; m_blue = C'109,186,255'; m_gold = C'249,196,99';
      ArrayResize(m_methods, STRAT_COUNT);
      for(int i = 0; i < STRAT_COUNT; i++)
      {
         ZeroMemory(m_methods[i]);
         m_methods[i].name  = g_stName[i];
         m_methods[i].desc  = g_stDesc[i];
         m_methods[i].magic = (long)StratMagic(i);
      }
      ArrayResize(m_records, 0);
      ArrayResize(m_live, 0);
      m_ready = true;
      return true;
   }

   void SetMethodState(const int i, const bool on, const bool inputOn, const string line1, const string line2)
   {
      if(i < 0 || i >= ArraySize(m_methods)) return;
      m_methods[i].on = on; m_methods[i].inputOn = inputOn;
      m_methods[i].line1 = line1; m_methods[i].line2 = line2;
   }

   bool IsCollapsed() { return m_collapsed; }

   void Update(const bool force = false)
   {
      if(!m_ready) return;
      if(force || m_dirty || !m_historyOk || TimeCurrent() - m_scanned >= m_refresh || PeriodStartTime() != m_periodStart)
         ScanHistory();
      ReadLive();
      Draw();
   }

   void MarkDirty() { m_dirty = true; }

   //--- Trả về chỉ số phương pháp nếu người dùng bấm nút BẬT/TẮT, ngược lại -1
   int Event(const int id, const long lparam, const double dparam, const string sparam)
   {
      if(!m_ready) return -1;
      if(id == CHARTEVENT_CHART_CHANGE) { Draw(); return -1; }
      if(id != CHARTEVENT_OBJECT_CLICK || StringFind(sparam, m_prefix) != 0) return -1;
      string key = StringSubstr(sparam, StringLen(m_prefix));
      ObjectSetInteger(m_chart, sparam, OBJPROP_STATE, false);
      int toggled = -1;
      if(key == "collapse")  { m_collapsed = !m_collapsed; ObjectsDeleteAll(m_chart, m_prefix); }
      else if(key == "today") { m_period = 0; m_dirty = true; }
      else if(key == "month") { m_period = 1; m_dirty = true; }
      else if(key == "all")   { m_period = 2; m_dirty = true; }
      else if(key == "prev")  m_page = (int)MathMax(0, m_page - 1);
      else if(key == "next")  m_page++;
      else if(StringFind(key, "sw") == 0 && StringLen(key) == 3)
         toggled = (int)StringToInteger(StringSubstr(key, 2, 1));
      return toggled;
   }

   void Destroy()
   {
      if(!m_ready) return;
      ObjectsDeleteAll(m_chart, m_prefix);
      ChartRedraw(m_chart);
      m_ready = false;
   }
};

CDavidBoard g_board;
bool        g_boardOn = false;
datetime    g_boardLast = 0;

void RefreshBoard(const bool force)
{
   if(!g_boardOn)
      return;
   for(int i = 0; i < STRAT_COUNT; i++)
      g_board.SetMethodState(i, g_on[i], StratInputEnabled(i), g_stLine1[i], g_stLine2[i]);
   g_board.Update(force);
}

//--- Bật / tắt phương pháp từ nút trên bảng
void SetStrategyOn(const int i, const bool on)
{
   if(i < 0 || i >= STRAT_COUNT)
      return;
   g_on[i] = on;
   SaveSwitch(i);
   Print("[DAVID MULTI] ", g_stName[i], (on ? " -> BẬT" : " -> TẮT"), " (nút trên bảng)");
   if(!on)
   {
      if(i == S_BRK) DeletePendingMagic(InpBRKMagic, g_tradeBRK);
      if(i == S_ICT) DeletePendingMagic(InpICTMagic, g_tradeICT);
   }
   else if(i == S_CRT)
      g_ready = false;   // khởi tạo lại Range (khôi phục + quét lại M1, không vào lệnh muộn)
}

//####################################################################
//##  SỰ KIỆN MT5                                                     ##
//####################################################################
int OnInit()
{
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_point <= 0.0)
      g_point = _Point;

   g_isTester    = (bool)MQLInfoInteger(MQL_TESTER);
   bool visual   = (!g_isTester || (bool)MQLInfoInteger(MQL_VISUAL_MODE));
   g_drawEnabled = InpShowCRT && visual;
   g_stateFile   = "DAVIDCRT_" + _Symbol + "_" + IntegerToString((long)InpMagic) + ".state";
   g_runId       = TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);

   //--- Kiểm tra Magic không trùng
   for(int a = 0; a < STRAT_COUNT; a++)
      for(int b = a + 1; b < STRAT_COUNT; b++)
         if(StratMagic(a) == StratMagic(b))
         {
            Print("[DAVID MULTI] Magic của ", g_stName[a], " và ", g_stName[b], " bị trùng - mỗi chiến lược phải có Magic riêng");
            return INIT_PARAMETERS_INCORRECT;
         }
   for(int i = 0; i < STRAT_COUNT; i++)
   {
      string raw = (i == S_CRT ? InpCRTComment : (i == S_SAR ? InpSARComment : (i == S_BRK ? InpBRKComment : InpICTComment)));
      if(StringLen(raw) > 31)
         Print("[DAVID MULTI] Comment ", g_stName[i], " dài hơn 31 ký tự, MT5 sẽ cắt còn: ", StratComment(i));
   }

   //--- CRT (giữ nguyên kiểm tra V1.03)
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
   if(InpFixedLot <= 0.0 && !InpUseRiskEquity)
   {
      Print("[DAVID CRT] Khối_lượng_cố_định phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseRiskEquity && InpRiskPercent <= 0.0)
   {
      Print("[DAVID CRT] Rủi_ro_mỗi_lệnh_% phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSLBuffer < 0.0 || InpMaxSpread < 0.0 || InpMinSweep < 0.0 || InpMaxSweep < 0.0 || InpMinRR < 0.0)
   {
      Print("[DAVID CRT] Các tham số giá / bộ lọc không được âm");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Chiến lược khác
   if(!InitSAR())
      return INIT_FAILED;
   InitBRK();
   InitICT();

   //--- Công tắc runtime
   LoadSwitches();
   for(int i = 0; i < STRAT_COUNT; i++)
   {
      g_stLine1[i] = (g_on[i] ? "ĐANG KHỞI TẠO" : "TẮT");
      g_stLine2[i] = "M" + IntegerToString((long)StratMagic(i)) + " • " + g_stDesc[i] + " • Comment: " + StratComment(i);
   }

   ResetState();
   g_ready = false;
   if(g_on[S_CRT])
      g_ready = InitializeRange(true);

   //--- Tradelog
   LoadLoggedIdsFromCsv();
   BackfillTradeLog();

   //--- Bảng board
   g_boardOn = InpShowBoard && visual;
   if(g_boardOn)
   {
      g_board.Init(0, (int)InpBoardPeriod, InpBoardX, InpBoardY, InpBoardScale, InpBoardRefresh, InpBoardLines, InpBoardCollapsed);
      RefreshBoard(true);
   }
   Comment("");

   Print("[DAVID MULTI] ", CRT_EA_NAME, " khởi động | ", _Symbol, " | CRT=", (g_on[S_CRT] ? "BẬT" : "TẮT"),
         " SAR=", (g_on[S_SAR] ? "BẬT" : "TẮT"), " BRK=", (g_on[S_BRK] ? "BẬT" : "TẮT"), " ICT=", (g_on[S_ICT] ? "BẬT" : "TẮT"),
         " | Tester=", YesNo(g_isTester), " | Liên hệ: ", DAVID_CONTACT);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_on[S_CRT])
      SaveCRTState();
   if(g_sarHandle != INVALID_HANDLE)    IndicatorRelease(g_sarHandle);
   if(g_sarATRHandle != INVALID_HANDLE) IndicatorRelease(g_sarATRHandle);
   //--- Không xóa object Range CRT (giữ lịch sử). Chỉ dọn bảng.
   if(g_boardOn)
      g_board.Destroy();
   Comment("");
}

void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   //--- 1. CRT
   if(g_on[S_CRT])
   {
      ProcessCRT(tick);
      UpdateCRTStatusLines();
   }
   else
   {
      MonitorPosition();
      UpdateCRTStatusLines();
   }

   //--- 2. SAR (quản lý lệnh luôn chạy kể cả khi tắt)
   ProcessSAR(tick);

   //--- 3. BRK (trailing luôn chạy kể cả khi tắt)
   ProcessBRK(tick);

   //--- 4. ICT (quản lý lệnh luôn chạy kể cả khi tắt)
   ProcessICT(tick);

   //--- 5. Bảng (tối đa 1 lần / giây)
   if(g_boardOn && tick.time != g_boardLast)
   {
      g_boardLast = tick.time;
      RefreshBoard(false);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY)
   {
      ulong pid = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      LogClosedPosition(pid);
   }
   if(g_boardOn)
      g_board.MarkDirty();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_boardOn)
      return;
   int k = g_board.Event(id, lparam, dparam, sparam);
   if(k >= 0 && k < STRAT_COUNT)
      SetStrategyOn(k, !g_on[k]);
   if(id == CHARTEVENT_OBJECT_CLICK)
      RefreshBoard(true);
}
//+------------------------------------------------------------------+
