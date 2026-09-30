//+------------------------------------------------------------------+
//|                           EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5    |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  TEST 1 — SHADOW BREAKOUT DETECTION (PHOENIX MARKET INTELLIGENCE)|
//|  EA này KHÔNG GỬI LỆNH, KHÔNG SỬA LỆNH, KHÔNG ĐÓNG LỆNH.         |
//|  Gắn trên một chart riêng (cùng symbol) bên cạnh EA baseline      |
//|  (Hydra / Phoenix) để ghi log mỗi nến đóng:                      |
//|  NORMAL → SIDEWAY → BREAKOUT SUSPECTED → BREAKOUT CONFIRMED →    |
//|  (RECLAIM) và quyết định phòng thủ "sẽ làm" DEFENSE → RECOVERY.  |
//|  Baseline không bị sửa. Chưa compile trong môi trường phát triển.|
//|  Cần file PHOENIX_MI_V0_01.mqh cùng thư mục.                     |
//|  Đặc tả: docs/phoenix_grid/07_MI_BREAKOUT_DEFENSE.md             |
//+------------------------------------------------------------------+
#property copyright   "DAVID HUNTER – PHOENIX GRID – 0941920986"
#property version     "0.01"
#property description "TEST 1 — Phoenix Market Intelligence: Shadow Breakout Detection. Chỉ ghi log, không gửi lệnh."

#include "PHOENIX_MI_V0_01.mqh"

//--- Input (nhãn tiếng Việt)
input group "1. PHOENIX MARKET INTELLIGENCE"
input bool            InpMIBat          = true;           // Bật Market Intelligence (tắt = EA không làm gì)
input ENUM_TIMEFRAMES InpMITF           = PERIOD_M5;      // Khung phân tích (không đổi theo chart)
input long            InpMagicTheoDoi   = 0;              // Magic basket cần theo dõi (0 = mọi vị thế của symbol; Hydra = 20260826)
input bool            InpGhiLog         = true;           // Ghi log CSV mỗi nến đóng
input string          InpThuMucLog      = "PhoenixGrid";  // Thư mục con trong Common\Files

input group "2. SIDEWAY / RANGE"
input int             InpSoNenRange     = 48;             // Số nến dựng range (48 nến M5 = 4 giờ)
input double          InpRangeMaxATR    = 6.0;            // Độ rộng range tối đa (× ATR)
input double          InpRangeADXMax    = 22.0;           // ADX dưới mức này mới xét sideway

input group "3. BREAKOUT DETECTION"
input int             InpDiemXacNhanBO  = 60;             // Điểm xác nhận Breakout (0–100, tổng các bằng chứng)
input int             InpSoNenXacNhan   = 2;              // Số nến xác nhận (đóng ngoài range liên tiếp; cũng dùng cho reclaim / trễ)

input group "4. BREAKOUT DEFENSE — SHADOW (chỉ ghi quyết định, không gửi lệnh)"
input bool            InpBDBat          = true;           // Bật Breakout Defense
input bool            InpKhoaDCABO      = true;           // Bật khóa DCA khi Breakout ngược basket
input bool            InpMarketHedge    = true;           // Bật Market Hedge (bản này chỉ ghi khối lượng hedge "sẽ mở")
input double          InpHedgeTyLe1     = 25.0;           // Tỷ lệ Hedge ban đầu (% exposure basket)
input double          InpHedgeTyLe2     = 50.0;           // Tỷ lệ Hedge cấp 2 (% exposure basket)
input int             InpHedgeGiuPhut   = 30;             // Thời gian giữ Hedge tối thiểu (phút)
input int             InpHedgeCooldown  = 60;             // Cooldown Hedge sau khi trở lại NORMAL (phút)
input bool            InpGiaLapBasket   = false;          // Tester: giả lập basket ngược mỗi breakout xác nhận (để kiểm luồng phòng thủ)

input group "5. NGỮ CẢNH FIB / BOLLINGER / NẾN"
input bool            InpFibLoc         = true;           // Bật Fib Filter (ngữ cảnh giữ / giảm hedge)
input bool            InpBBLoc          = true;           // Bật Bollinger Filter (bằng chứng breakout + ngữ cảnh)
input bool            InpNenXacNhan     = true;           // Bật Candle Confirmation (ngữ cảnh giữ / giảm hedge)

CPhoenixMI g_mi;
bool       g_miSan = false;

int OnInit()
  {
   g_miSan = false;
   if(!InpMIBat)
     {
      Comment("PHOENIX MI: đang tắt (InpMIBat = false)");
      return INIT_SUCCEEDED;
     }
   if(InpSoNenRange < 10 || InpSoNenRange > 200 || InpRangeMaxATR <= 1.5 || InpRangeADXMax <= 0.0 ||
      InpDiemXacNhanBO < 0 || InpDiemXacNhanBO > 100 || InpSoNenXacNhan < 1 || InpSoNenXacNhan > 20 ||
      InpHedgeTyLe1 < 0.0 || InpHedgeTyLe1 > 100.0 || InpHedgeTyLe2 < InpHedgeTyLe1 || InpHedgeTyLe2 > 100.0 ||
      InpHedgeGiuPhut < 0 || InpHedgeCooldown < 0)
     {
      Print("PMI: tham số không hợp lệ, xem docs/phoenix_grid/07_MI_BREAKOUT_DEFENSE.md");
      return INIT_PARAMETERS_INCORRECT;
     }
   PMI_CAU_HINH c;
   c.tf           = InpMITF;
   c.phongThu     = InpBDBat;
   c.khoaDCA      = InpKhoaDCABO;
   c.marketHedge  = InpMarketHedge;
   c.hedgeTyLe1   = InpHedgeTyLe1;
   c.hedgeTyLe2   = InpHedgeTyLe2;
   c.giuPhut      = InpHedgeGiuPhut;
   c.cooldownPhut = InpHedgeCooldown;
   c.diemXacNhan  = InpDiemXacNhanBO;
   c.soNenXacNhan = InpSoNenXacNhan;
   c.fib          = InpFibLoc;
   c.bb           = InpBBLoc;
   c.nen          = InpNenXacNhan;
   c.soNenRange   = InpSoNenRange;
   c.rangeMaxATR  = InpRangeMaxATR;
   c.rangeADXMax  = InpRangeADXMax;
   c.magic        = InpMagicTheoDoi;
   c.giaLapBasket = InpGiaLapBasket && (bool)MQLInfoInteger(MQL_TESTER);
   c.ghiLog       = InpGhiLog;
   if(!g_mi.Init(c))
     {
      Print("PMI: không tạo được chỉ báo");
      return INIT_FAILED;
     }
   if(InpGhiLog)
     {
      ResetLastError();
      if(!FolderCreate(InpThuMucLog, FILE_COMMON))
         PrintFormat("PMI: FolderCreate trả về false (lỗi %d), có thể thư mục đã tồn tại", GetLastError());
     }
   g_miSan = true;
   Comment(PMI_PHIEN_BAN + ": đang dựng lại trạng thái từ lịch sử nến...");
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_miSan)
      g_mi.Deinit();
   Comment("");
  }

void OnTick()
  {
   if(g_miSan && g_mi.CapNhat(InpThuMucLog) && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
      Comment(g_mi.MoTa());
  }

void OnTimer()
  {
   if(!g_miSan)
      return;
   g_mi.CapNhat(InpThuMucLog);
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
      Comment(g_mi.MoTa());
  }
//+------------------------------------------------------------------+
