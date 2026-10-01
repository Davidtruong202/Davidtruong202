//+------------------------------------------------------------------+
//| IDHG_Config.mqh                                                  |
//| Cấu hình + Config Manager (Load / Validate / SetPending /        |
//| ApplyPending / DiscardPending / Summary).                        |
//| Thông số GRID chỉ đổi qua Pending → APPLY GRID CHANGES.           |
//+------------------------------------------------------------------+
#ifndef IDHG_CONFIG_MQH
#define IDHG_CONFIG_MQH

#include "IDHG_Utils.mqh"

//--- Giá trị mặc định (dùng chung cho input và self-test, không lặp số)
#define IDHG_DEF_MAGIC               20261001
#define IDHG_DEF_PREFIX              "DHG"
#define IDHG_DEF_DEVIATION           30
#define IDHG_DEF_DIST_MODE           IDHG_DIST_FIXED
#define IDHG_DEF_BASE_DISTANCE       10.0
#define IDHG_DEF_DIST_MULTIPLIER     1.2
#define IDHG_DEF_ADDITIVE_STEP       2.0
#define IDHG_DEF_MIN_DISTANCE        1.0
#define IDHG_DEF_MAX_DISTANCE        100.0
#define IDHG_DEF_GAP_MODE            IDHG_GAP_OPEN_ALL_CROSSED
#define IDHG_DEF_BUY_LOT             0.01
#define IDHG_DEF_SELL_LOT            0.01
#define IDHG_DEF_LOT_MULTIPLIER      1.0
#define IDHG_DEF_MIN_LOT             0.01
#define IDHG_DEF_MAX_LOT             1.0
#define IDHG_DEF_INDIV_TP_ENABLED    true
#define IDHG_DEF_INDIV_TP_DISTANCE   10.0
#define IDHG_DEF_BASKET_ENABLED      false
#define IDHG_DEF_BASKET_TARGET       20.0
#define IDHG_DEF_SIDETOTAL_ENABLED   false
#define IDHG_DEF_SIDETOTAL_TARGET    10.0
#define IDHG_DEF_UNLIMITED_HOLD      false
#define IDHG_DEF_MAX_ORDERS          50
#define IDHG_DEF_MAX_TOTAL_LOTS      2.0
#define IDHG_DEF_MAX_BUY_LOTS        1.0
#define IDHG_DEF_MAX_SELL_LOTS       1.0
#define IDHG_DEF_MAX_DD_PERCENT      30.0
#define IDHG_DEF_MAX_MARGIN_USAGE    50.0
#define IDHG_DEF_MIN_MARGIN_LEVEL    300.0
#define IDHG_DEF_EQUITY_FLOOR        0.0
#define IDHG_DEF_MAX_SPREAD          1.0
#define IDHG_DEF_EMERGENCY_ACTION    IDHG_EMERGENCY_STOP_NEW_ENTRIES
#define IDHG_DEF_SURV_RISK_BUDGET    30.0
#define IDHG_DEF_SURV_SAFETY_BUFFER  20.0
#define IDHG_DEF_SURV_ADVERSE_DIST   200.0
#define IDHG_DEF_CAPACITY_MODE       IDHG_CAP_MANUAL
#define IDHG_DEF_MAX_ORDERS_AUTO     200
#define IDHG_DEF_MAX_SEND_ATTEMPTS   3
#define IDHG_DEF_CONFIRM_TIMEOUT     10
#define IDHG_DEF_CLOSE_TIMEOUT       15
#define IDHG_DEF_PENDING_TIMEOUT     30
#define IDHG_DEF_TIMER_SECONDS       1
#define IDHG_DEF_RECONCILE_SECONDS   30
#define IDHG_DEF_LOG_THROTTLE        30
#define IDHG_MAX_ORDERS_AUTO_CAP     2000

//+------------------------------------------------------------------+
//| Thông số GRID (chịu quy tắc Pending → Apply)                      |
//+------------------------------------------------------------------+
struct SIdhgGridConfig
  {
   ENUM_IDHG_DISTANCE_MODE distanceMode;
   double            baseDistance;
   double            distMultiplier;
   double            additiveStep;
   double            minDistance;      // 0 = không giới hạn dưới
   double            maxDistance;      // 0 = không giới hạn trên
   ENUM_IDHG_GAP_MODE gapMode;
   double            buyLot;
   double            sellLot;
   double            lotMultiplier;    // 1.0 = không nhân lot (KHÔNG martingale mặc định)
   double            minLot;
   double            maxLot;           // 0 = theo broker
   bool              reopenClosedLevel;

   void              SetDefaults(void)
     {
      distanceMode = IDHG_DEF_DIST_MODE; baseDistance = IDHG_DEF_BASE_DISTANCE;
      distMultiplier = IDHG_DEF_DIST_MULTIPLIER; additiveStep = IDHG_DEF_ADDITIVE_STEP;
      minDistance = IDHG_DEF_MIN_DISTANCE; maxDistance = IDHG_DEF_MAX_DISTANCE;
      gapMode = IDHG_DEF_GAP_MODE; buyLot = IDHG_DEF_BUY_LOT; sellLot = IDHG_DEF_SELL_LOT;
      lotMultiplier = IDHG_DEF_LOT_MULTIPLIER; minLot = IDHG_DEF_MIN_LOT; maxLot = IDHG_DEF_MAX_LOT;
      reopenClosedLevel = false;
     }
  };

//+------------------------------------------------------------------+
//| Thông số chốt lời (mỗi phía riêng). Index 0 = BUY, 1 = SELL       |
//+------------------------------------------------------------------+
struct SIdhgProfitConfig
  {
   bool              indivEnabled[IDHG_SIDE_COUNT];
   double            indivDistance[IDHG_SIDE_COUNT];   // theo GIÁ
   bool              basketEnabled[IDHG_SIDE_COUNT];
   double            basketTarget[IDHG_SIDE_COUNT];    // tiền tài khoản (cent account = cent)
   bool              sideTotalEnabled[IDHG_SIDE_COUNT];
   double            sideTotalTarget[IDHG_SIDE_COUNT];
   bool              unlimitedHold[IDHG_SIDE_COUNT];

   void              SetDefaults(void)
     {
      for(int i = 0; i < IDHG_SIDE_COUNT; i++)
        {
         indivEnabled[i] = IDHG_DEF_INDIV_TP_ENABLED; indivDistance[i] = IDHG_DEF_INDIV_TP_DISTANCE;
         basketEnabled[i] = IDHG_DEF_BASKET_ENABLED; basketTarget[i] = IDHG_DEF_BASKET_TARGET;
         sideTotalEnabled[i] = IDHG_DEF_SIDETOTAL_ENABLED; sideTotalTarget[i] = IDHG_DEF_SIDETOTAL_TARGET;
         unlimitedHold[i] = IDHG_DEF_UNLIMITED_HOLD;
        }
     }
  };

//+------------------------------------------------------------------+
//| Thông số rủi ro                                                  |
//+------------------------------------------------------------------+
struct SIdhgRiskConfig
  {
   int               maxOrders;          // 0 = không giới hạn
   double            maxTotalLots;       // 0 = không giới hạn
   double            maxBuyLots;         // 0 = không giới hạn
   double            maxSellLots;        // 0 = không giới hạn
   bool              emergencyDrawdownEnabled;
   double            maxDrawdownPercent;
   bool              maxMarginUsageEnabled;
   double            maxMarginUsagePercent;
   double            minimumMarginLevel; // 0 = tắt
   double            equityFloor;        // 0 = tắt
   double            maxSpread;          // theo GIÁ, 0 = không giới hạn
   ENUM_IDHG_EMERGENCY_ACTION emergencyAction;

   void              SetDefaults(void)
     {
      maxOrders = IDHG_DEF_MAX_ORDERS; maxTotalLots = IDHG_DEF_MAX_TOTAL_LOTS;
      maxBuyLots = IDHG_DEF_MAX_BUY_LOTS; maxSellLots = IDHG_DEF_MAX_SELL_LOTS;
      emergencyDrawdownEnabled = true; maxDrawdownPercent = IDHG_DEF_MAX_DD_PERCENT;
      maxMarginUsageEnabled = true; maxMarginUsagePercent = IDHG_DEF_MAX_MARGIN_USAGE;
      minimumMarginLevel = IDHG_DEF_MIN_MARGIN_LEVEL; equityFloor = IDHG_DEF_EQUITY_FLOOR;
      maxSpread = IDHG_DEF_MAX_SPREAD; emergencyAction = IDHG_DEF_EMERGENCY_ACTION;
     }
  };

//+------------------------------------------------------------------+
//| Thông số Capacity Planner / Survival Calculator                  |
//+------------------------------------------------------------------+
struct SIdhgCapacityConfig
  {
   bool              plannerEnabled;
   double            referencePrice;     // 0 = giá hiện tại
   double            targetPrice;        // 0 = dùng adverseDistance
   double            adverseDistance;    // khoảng bất lợi (GIÁ) khi targetPrice = 0
   double            riskBudgetPercent;  // lỗ tối đa chấp nhận tại giá mục tiêu (% equity)
   double            safetyBufferPercent;// đệm an toàn trên mức stop-out
   ENUM_IDHG_CAPACITY_MODE mode;
   int               maxOrdersAuto;      // trần mô phỏng
   double            commissionPerLot;   // phí round-turn / lot (tiền TK), 0 = ước tính từ lịch sử
   bool              creditFutureProfit; // mặc định false: KHÔNG tính lời tương lai

   void              SetDefaults(void)
     {
      plannerEnabled = true; referencePrice = 0; targetPrice = 0;
      adverseDistance = IDHG_DEF_SURV_ADVERSE_DIST; riskBudgetPercent = IDHG_DEF_SURV_RISK_BUDGET;
      safetyBufferPercent = IDHG_DEF_SURV_SAFETY_BUFFER; mode = IDHG_DEF_CAPACITY_MODE;
      maxOrdersAuto = IDHG_DEF_MAX_ORDERS_AUTO; commissionPerLot = 0; creditFutureProfit = false;
     }
  };

//+------------------------------------------------------------------+
//| Thông số chung                                                   |
//+------------------------------------------------------------------+
struct SIdhgGeneralConfig
  {
   long              magic;
   string            commentPrefix;
   int               deviationPoints;
   bool              sideEnabled[IDHG_SIDE_COUNT];
   int               maxSendAttempts;     // số lần gửi tối đa cho lỗi tạm thời
   int               confirmTimeoutSec;   // timeout chờ broker xác nhận mở
   int               closeTimeoutSec;     // timeout chờ broker xác nhận đóng
   int               pendingTimeoutSec;
   int               timerSeconds;
   int               reconcileSeconds;
   int               logThrottleSec;
   bool              autoStartFirstCycle; // tiện cho Strategy Tester (không có nút bấm)
   bool              dashboardEnabled;
   int               dashboardX;
   int               dashboardY;
   int               dashboardFontSize;
   int               confirmWindowSec;    // cửa sổ xác nhận nút nguy hiểm

   void              SetDefaults(void)
     {
      magic = IDHG_DEF_MAGIC; commentPrefix = IDHG_DEF_PREFIX; deviationPoints = IDHG_DEF_DEVIATION;
      sideEnabled[IDHG_BUY] = true; sideEnabled[IDHG_SELL] = true;
      maxSendAttempts = IDHG_DEF_MAX_SEND_ATTEMPTS; confirmTimeoutSec = IDHG_DEF_CONFIRM_TIMEOUT;
      closeTimeoutSec = IDHG_DEF_CLOSE_TIMEOUT; pendingTimeoutSec = IDHG_DEF_PENDING_TIMEOUT;
      timerSeconds = IDHG_DEF_TIMER_SECONDS; reconcileSeconds = IDHG_DEF_RECONCILE_SECONDS;
      logThrottleSec = IDHG_DEF_LOG_THROTTLE; autoStartFirstCycle = false; dashboardEnabled = true;
      dashboardX = 10; dashboardY = 20; dashboardFontSize = 8; confirmWindowSec = 10;
     }
  };

//+------------------------------------------------------------------+
//| Cấu hình đầy đủ                                                  |
//+------------------------------------------------------------------+
struct SIdhgConfig
  {
   SIdhgGridConfig     grid;
   SIdhgProfitConfig   profit;
   SIdhgRiskConfig     risk;
   SIdhgCapacityConfig capacity;
   SIdhgGeneralConfig  general;

   void              SetDefaults(void)
     {
      grid.SetDefaults(); profit.SetDefaults(); risk.SetDefaults();
      capacity.SetDefaults(); general.SetDefaults();
     }
  };

//--- So sánh hai cấu hình grid
bool IdhgGridConfigEquals(const SIdhgGridConfig &a, const SIdhgGridConfig &b)
  {
   return a.distanceMode == b.distanceMode && IdhgEQ(a.baseDistance, b.baseDistance) &&
          IdhgEQ(a.distMultiplier, b.distMultiplier) && IdhgEQ(a.additiveStep, b.additiveStep) &&
          IdhgEQ(a.minDistance, b.minDistance) && IdhgEQ(a.maxDistance, b.maxDistance) &&
          a.gapMode == b.gapMode && IdhgEQ(a.buyLot, b.buyLot) && IdhgEQ(a.sellLot, b.sellLot) &&
          IdhgEQ(a.lotMultiplier, b.lotMultiplier) && IdhgEQ(a.minLot, b.minLot) &&
          IdhgEQ(a.maxLot, b.maxLot) && a.reopenClosedLevel == b.reopenClosedLevel;
  }

//--- Kiểm tra cấu hình grid. Trả về chuỗi lỗi rỗng nếu hợp lệ.
string IdhgValidateGrid(const SIdhgGridConfig &g)
  {
   string e = "";
   if(g.baseDistance <= 0.0)
      e += "BaseDistance phải > 0; ";
   if(g.distanceMode == IDHG_DIST_MULTIPLIER && g.distMultiplier <= 0.0)
      e += "DistanceMultiplier phải > 0; ";
   if(g.distanceMode == IDHG_DIST_ADDITIVE && g.additiveStep < 0.0 && g.minDistance <= 0.0)
      e += "AdditiveStep âm cần MinDistance > 0; ";
   if(g.minDistance < 0.0 || g.maxDistance < 0.0)
      e += "Min/MaxDistance không được âm; ";
   if(g.minDistance > 0.0 && g.maxDistance > 0.0 && g.minDistance > g.maxDistance)
      e += "MinDistance > MaxDistance; ";
   if(g.buyLot <= 0.0 || g.sellLot <= 0.0)
      e += "BuyLot/SellLot phải > 0; ";
   if(g.lotMultiplier <= 0.0)
      e += "LotMultiplier phải > 0; ";
   if(g.minLot < 0.0 || g.maxLot < 0.0)
      e += "MinLot/MaxLot không được âm; ";
   if(g.maxLot > 0.0 && g.minLot > g.maxLot)
      e += "MinLot > MaxLot; ";
   return e;
  }

string IdhgValidateProfit(const SIdhgProfitConfig &p)
  {
   string e = "";
   for(int i = 0; i < IDHG_SIDE_COUNT; i++)
     {
      string s = IdhgSideName(IdhgSideFromIndex(i));
      if(p.indivEnabled[i] && p.indivDistance[i] <= 0.0)
         e += s + " IndividualTPDistance phải > 0; ";
      if(p.basketEnabled[i] && p.basketTarget[i] <= 0.0)
         e += s + " BasketTarget phải > 0; ";
      if(p.sideTotalEnabled[i] && p.sideTotalTarget[i] <= 0.0)
         e += s + " SideTotalTarget phải > 0; ";
     }
   return e;
  }

string IdhgValidateRisk(const SIdhgRiskConfig &r)
  {
   string e = "";
   if(r.maxOrders < 0)
      e += "MaxOrders không được âm; ";
   if(r.maxTotalLots < 0.0 || r.maxBuyLots < 0.0 || r.maxSellLots < 0.0)
      e += "Max*Lots không được âm; ";
   if(r.maxDrawdownPercent < 0.0 || r.maxDrawdownPercent > 100.0)
      e += "MaxDrawdownPercent phải trong [0,100]; ";
   if(r.emergencyDrawdownEnabled && r.maxDrawdownPercent <= 0.0)
      e += "EmergencyDrawdown bật nhưng MaxDrawdownPercent = 0; ";
   if(r.maxMarginUsagePercent < 0.0)
      e += "MaxMarginUsagePercent không được âm; ";
   if(r.maxMarginUsageEnabled && r.maxMarginUsagePercent <= 0.0)
      e += "MaxMarginUsage bật nhưng = 0; ";
   if(r.minimumMarginLevel < 0.0 || r.equityFloor < 0.0 || r.maxSpread < 0.0)
      e += "MinimumMarginLevel/EquityFloor/MaxSpread không được âm; ";
   return e;
  }

string IdhgValidateCapacity(const SIdhgCapacityConfig &c)
  {
   string e = "";
   if(c.referencePrice < 0.0 || c.targetPrice < 0.0 || c.adverseDistance < 0.0)
      e += "Giá/khoảng Survival không được âm; ";
   if(c.plannerEnabled && c.targetPrice <= 0.0 && c.adverseDistance <= 0.0)
      e += "Cần SurvivalTargetPrice hoặc SurvivalAdverseDistance > 0; ";
   if(c.riskBudgetPercent <= 0.0 || c.riskBudgetPercent > 100.0)
      e += "SurvivalRiskBudgetPercent phải trong (0,100]; ";
   if(c.safetyBufferPercent < 0.0)
      e += "SurvivalSafetyBufferPercent không được âm; ";
   if(c.maxOrdersAuto < 1 || c.maxOrdersAuto > IDHG_MAX_ORDERS_AUTO_CAP)
      e += "MaxOrdersAuto phải trong [1," + IntegerToString(IDHG_MAX_ORDERS_AUTO_CAP) + "]; ";
   if(c.commissionPerLot < 0.0)
      e += "CommissionPerLot nhập số dương (phí); ";
   if(c.mode != IDHG_CAP_MANUAL && !c.plannerEnabled)
      e += "CapacityMode tự động cần bật SurvivalPlanner; ";
   return e;
  }

string IdhgValidateGeneral(const SIdhgGeneralConfig &g)
  {
   string e = "";
   if(g.magic <= 0)
      e += "MagicNumber phải > 0; ";
   if(StringLen(g.commentPrefix) == 0 || StringLen(g.commentPrefix) > 6 || StringFind(g.commentPrefix, "|") >= 0)
      e += "CommentPrefix 1-6 ký tự, không chứa '|'; ";
   if(g.deviationPoints < 0)
      e += "Deviation không được âm; ";
   if(g.maxSendAttempts < 1)
      e += "MaxSendAttempts phải >= 1; ";
   if(g.confirmTimeoutSec < 1 || g.closeTimeoutSec < 1 || g.pendingTimeoutSec < 1)
      e += "Timeout phải >= 1 giây; ";
   if(g.timerSeconds < 1 || g.reconcileSeconds < 1)
      e += "Timer/Reconcile phải >= 1 giây; ";
   if(g.confirmWindowSec < 1)
      e += "ConfirmWindow phải >= 1 giây; ";
   return e;
  }

//+------------------------------------------------------------------+
//| CConfig — Config Manager                                         |
//+------------------------------------------------------------------+
class CConfig
  {
private:
   SIdhgConfig       m_cfg;             // cấu hình đang hiệu lực (grid = ACTIVE)
   SIdhgGridConfig   m_pending;         // grid chờ áp dụng
   bool              m_hasPending;
   bool              m_loaded;
   string            m_lastError;

public:
                     CConfig(void) : m_hasPending(false), m_loaded(false), m_lastError("") { m_cfg.SetDefaults(); m_pending.SetDefaults(); }

   //--- Load: nạp toàn bộ cấu hình (thường từ input) rồi validate
   bool              Load(const SIdhgConfig &cfg)
     {
      string e = Validate(cfg);
      if(e != "")
        {
         m_lastError = e;
         return false;
        }
      m_cfg = cfg;
      m_hasPending = false;
      m_loaded = true;
      m_lastError = "";
      return true;
     }

   //--- Validate toàn bộ (không thay đổi trạng thái)
   string            Validate(const SIdhgConfig &cfg) const
     {
      return IdhgValidateGrid(cfg.grid) + IdhgValidateProfit(cfg.profit) + IdhgValidateRisk(cfg.risk) +
             IdhgValidateCapacity(cfg.capacity) + IdhgValidateGeneral(cfg.general);
     }

   //--- Đặt cấu hình grid chờ. Không ảnh hưởng level hiện có cho tới ApplyPending.
   bool              SetPending(const SIdhgGridConfig &g)
     {
      string e = IdhgValidateGrid(g);
      if(e != "")
        {
         m_lastError = e;
         return false;
        }
      if(IdhgGridConfigEquals(g, m_cfg.grid))
        {
         m_hasPending = false;   // không có gì khác biệt
         return true;
        }
      m_pending = g;
      m_hasPending = true;
      return true;
     }

   //--- Áp dụng grid chờ → active. Chỉ level TƯƠNG LAI dùng thông số mới.
   bool              ApplyPending(void)
     {
      if(!m_hasPending)
         return false;
      m_cfg.grid = m_pending;
      m_hasPending = false;
      return true;
     }

   void              DiscardPending(void) { m_hasPending = false; }
   bool              HasPending(void) const { return m_hasPending; }
   bool              IsLoaded(void) const { return m_loaded; }
   string            LastError(void) const { return m_lastError; }

   //--- Truy cập (trả qua tham chiếu out — MQL5 không trả struct theo tham chiếu)
   void              Get(SIdhgConfig &out) const { out = m_cfg; }
   void              GetGrid(SIdhgGridConfig &out) const { out = m_cfg.grid; }
   void              GetPending(SIdhgGridConfig &out) const { out = m_pending; }

   //--- Thay đổi runtime KHÔNG thuộc grid: áp dụng ngay
   void              SetSideEnabled(const ENUM_IDHG_SIDE s, const bool v) { m_cfg.general.sideEnabled[s] = v; }
   void              SetIndivEnabled(const ENUM_IDHG_SIDE s, const bool v) { m_cfg.profit.indivEnabled[s] = v; }
   void              SetBasketEnabled(const ENUM_IDHG_SIDE s, const bool v) { m_cfg.profit.basketEnabled[s] = v; }
   void              SetSideTotalEnabled(const ENUM_IDHG_SIDE s, const bool v) { m_cfg.profit.sideTotalEnabled[s] = v; }
   void              SetUnlimitedHold(const ENUM_IDHG_SIDE s, const bool v) { m_cfg.profit.unlimitedHold[s] = v; }
   void              SetActiveGrid(const SIdhgGridConfig &g) { m_cfg.grid = g; }   // dùng cho recovery

   bool              SideEnabled(const ENUM_IDHG_SIDE s) const { return m_cfg.general.sideEnabled[s]; }
   bool              IndivEnabled(const ENUM_IDHG_SIDE s) const { return m_cfg.profit.indivEnabled[s]; }
   bool              BasketEnabled(const ENUM_IDHG_SIDE s) const { return m_cfg.profit.basketEnabled[s]; }
   bool              SideTotalEnabled(const ENUM_IDHG_SIDE s) const { return m_cfg.profit.sideTotalEnabled[s]; }
   bool              UnlimitedHold(const ENUM_IDHG_SIDE s) const { return m_cfg.profit.unlimitedHold[s]; }
   long              Magic(void) const { return m_cfg.general.magic; }
   string            Prefix(void) const { return m_cfg.general.commentPrefix; }

   //--- Tóm tắt cấu hình (log / dashboard)
   string            Summary(void) const
     {
      string s = "GRID[" + IdhgDistanceModeName(m_cfg.grid.distanceMode) +
                 " base=" + DoubleToString(m_cfg.grid.baseDistance, 2) +
                 " mult=" + DoubleToString(m_cfg.grid.distMultiplier, 3) +
                 " step=" + DoubleToString(m_cfg.grid.additiveStep, 2) +
                 " min=" + DoubleToString(m_cfg.grid.minDistance, 2) +
                 " max=" + DoubleToString(m_cfg.grid.maxDistance, 2) +
                 " gap=" + IdhgGapModeName(m_cfg.grid.gapMode) +
                 " lotB=" + DoubleToString(m_cfg.grid.buyLot, 2) +
                 " lotS=" + DoubleToString(m_cfg.grid.sellLot, 2) +
                 " lotMult=" + DoubleToString(m_cfg.grid.lotMultiplier, 3) + "]";
      s += " RISK[maxOrd=" + IntegerToString(m_cfg.risk.maxOrders) +
           " maxLots=" + DoubleToString(m_cfg.risk.maxTotalLots, 2) +
           " maxSpread=" + DoubleToString(m_cfg.risk.maxSpread, 2) + "]";
      s += " CAP[" + IdhgCapacityModeName(m_cfg.capacity.mode) + "]";
      if(m_hasPending)
         s += " PENDING_GRID[" + IdhgDistanceModeName(m_pending.distanceMode) +
              " base=" + DoubleToString(m_pending.baseDistance, 2) + "]";
      return s;
     }
  };

#endif
