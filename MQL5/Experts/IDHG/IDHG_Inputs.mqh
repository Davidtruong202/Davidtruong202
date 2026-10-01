//+------------------------------------------------------------------+
//| IDHG_Inputs.mqh                                                  |
//| Toàn bộ input của EA. Chỉ include trong file EA chính.            |
//| Đơn vị: khoảng cách/spread theo GIÁ (vd XAUUSD 10.0 = 10 USD).    |
//| Mục tiêu tiền (Target) theo tiền tài khoản (TK cent → cent).      |
//+------------------------------------------------------------------+
#ifndef IDHG_INPUTS_MQH
#define IDHG_INPUTS_MQH

#include "IDHG_Config.mqh"

input group "=== CHUNG ==="
input long                       InpMagicNumber          = IDHG_DEF_MAGIC;            // Magic Number
input string                     InpCommentPrefix        = IDHG_DEF_PREFIX;           // Tiền tố comment (1-6 ký tự)
input int                        InpDeviationPoints      = IDHG_DEF_DEVIATION;        // Deviation (point)
input bool                       InpBuyEnabled           = true;                      // BUY bật
input bool                       InpSellEnabled          = true;                      // SELL bật
input bool                       InpAutoStartFirstCycle  = false;                     // Tự START chu kỳ đầu (cho Strategy Tester)

input group "=== GRID (thay đổi khi đang chạy → chờ APPLY GRID CHANGES) ==="
input ENUM_IDHG_DISTANCE_MODE    InpDistanceMode         = IDHG_DEF_DIST_MODE;        // Chế độ khoảng cách
input double                     InpBaseDistance         = IDHG_DEF_BASE_DISTANCE;    // Khoảng cách cơ sở (giá)
input double                     InpDistanceMultiplier   = IDHG_DEF_DIST_MULTIPLIER;  // Hệ số nhân khoảng cách (MULTIPLIER)
input double                     InpAdditiveStep         = IDHG_DEF_ADDITIVE_STEP;    // Bước cộng khoảng cách (ADDITIVE)
input double                     InpMinDistance          = IDHG_DEF_MIN_DISTANCE;     // Khoảng cách tối thiểu (0 = tắt)
input double                     InpMaxDistance          = IDHG_DEF_MAX_DISTANCE;     // Khoảng cách tối đa (0 = tắt)
input ENUM_IDHG_GAP_MODE         InpGapMode              = IDHG_DEF_GAP_MODE;         // Xử lý gap / level bị vượt
input double                     InpBuyLot               = IDHG_DEF_BUY_LOT;          // Lot BUY
input double                     InpSellLot              = IDHG_DEF_SELL_LOT;         // Lot SELL
input double                     InpLotMultiplier        = IDHG_DEF_LOT_MULTIPLIER;   // Hệ số nhân lot (1.0 = không nhân)
input double                     InpMinLot               = IDHG_DEF_MIN_LOT;          // Lot tối thiểu
input double                     InpMaxLot               = IDHG_DEF_MAX_LOT;          // Lot tối đa mỗi lệnh (0 = theo broker)
input bool                       InpReopenClosedLevel    = false;                     // Mở lại level đã CLOSED

input group "=== CHỐT LỜI BUY ==="
input bool                       InpBuyIndividualTPEnabled  = IDHG_DEF_INDIV_TP_ENABLED;  // BUY Individual TP bật
input double                     InpBuyIndividualTPDistance = IDHG_DEF_INDIV_TP_DISTANCE; // BUY Individual TP khoảng (giá)
input bool                       InpBuyBasketTPEnabled      = IDHG_DEF_BASKET_ENABLED;    // BUY Basket TP bật
input double                     InpBuyBasketTargetCent     = IDHG_DEF_BASKET_TARGET;     // BUY Basket mục tiêu (tiền TK)
input bool                       InpBuySideTotalTPEnabled   = IDHG_DEF_SIDETOTAL_ENABLED; // BUY Side Total TP bật
input double                     InpBuySideTotalTargetCent  = IDHG_DEF_SIDETOTAL_TARGET;  // BUY Side Total mục tiêu (tiền TK)
input bool                       InpBuyUnlimitedHold        = IDHG_DEF_UNLIMITED_HOLD;    // BUY Unlimited Hold (gồng lệnh âm)

input group "=== CHỐT LỜI SELL ==="
input bool                       InpSellIndividualTPEnabled  = IDHG_DEF_INDIV_TP_ENABLED;  // SELL Individual TP bật
input double                     InpSellIndividualTPDistance = IDHG_DEF_INDIV_TP_DISTANCE; // SELL Individual TP khoảng (giá)
input bool                       InpSellBasketTPEnabled      = IDHG_DEF_BASKET_ENABLED;    // SELL Basket TP bật
input double                     InpSellBasketTargetCent     = IDHG_DEF_BASKET_TARGET;     // SELL Basket mục tiêu (tiền TK)
input bool                       InpSellSideTotalTPEnabled   = IDHG_DEF_SIDETOTAL_ENABLED; // SELL Side Total TP bật
input double                     InpSellSideTotalTargetCent  = IDHG_DEF_SIDETOTAL_TARGET;  // SELL Side Total mục tiêu (tiền TK)
input bool                       InpSellUnlimitedHold        = IDHG_DEF_UNLIMITED_HOLD;    // SELL Unlimited Hold (gồng lệnh âm)

input group "=== RỦI RO ==="
input int                        InpMaxOrders               = IDHG_DEF_MAX_ORDERS;       // Số lệnh tối đa (0 = KHÔNG giới hạn)
input double                     InpMaxTotalLots            = IDHG_DEF_MAX_TOTAL_LOTS;   // Tổng lot tối đa (0 = KHÔNG giới hạn)
input double                     InpMaxBuyLots              = IDHG_DEF_MAX_BUY_LOTS;     // Lot BUY tối đa (0 = KHÔNG giới hạn)
input double                     InpMaxSellLots             = IDHG_DEF_MAX_SELL_LOTS;    // Lot SELL tối đa (0 = KHÔNG giới hạn)
input bool                       InpEmergencyDrawdownEnabled= true;                      // Bật khẩn cấp theo drawdown
input double                     InpMaxDrawdownPercent      = IDHG_DEF_MAX_DD_PERCENT;   // Drawdown tối đa (%)
input bool                       InpMaxMarginUsageEnabled   = true;                      // Bật giới hạn sử dụng margin
input double                     InpMaxMarginUsagePercent   = IDHG_DEF_MAX_MARGIN_USAGE; // Margin sử dụng tối đa (% equity)
input double                     InpMinimumMarginLevel      = IDHG_DEF_MIN_MARGIN_LEVEL; // Margin level tối thiểu (%) (0 = tắt)
input double                     InpEquityFloor             = IDHG_DEF_EQUITY_FLOOR;     // Sàn equity (0 = tắt)
input double                     InpMaxSpread               = IDHG_DEF_MAX_SPREAD;       // Spread tối đa (giá) (0 = KHÔNG giới hạn)
input ENUM_IDHG_EMERGENCY_ACTION InpEmergencyAction         = IDHG_DEF_EMERGENCY_ACTION; // Hành động khẩn cấp

input group "=== SỨC CHỊU ĐỰNG (CAPACITY PLANNER) ==="
input bool                       InpSurvivalPlannerEnabled   = true;                       // Bật Capacity Planner
input double                     InpSurvivalReferencePrice   = 0.0;                        // Giá tham chiếu (0 = giá hiện tại)
input double                     InpSurvivalTargetPrice      = 0.0;                        // Giá bất lợi mục tiêu (0 = dùng khoảng)
input double                     InpSurvivalAdverseDistance  = IDHG_DEF_SURV_ADVERSE_DIST; // Khoảng bất lợi (giá) khi mục tiêu = 0
input double                     InpSurvivalRiskBudgetPercent= IDHG_DEF_SURV_RISK_BUDGET;  // Ngân sách lỗ tối đa (% equity)
input double                     InpSurvivalSafetyBufferPercent = IDHG_DEF_SURV_SAFETY_BUFFER; // Đệm an toàn trên stop-out (%)
input ENUM_IDHG_CAPACITY_MODE    InpCapacityMode             = IDHG_DEF_CAPACITY_MODE;     // Chế độ giới hạn sức chứa
input int                        InpMaxOrdersAuto            = IDHG_DEF_MAX_ORDERS_AUTO;   // Trần số lệnh mô phỏng
input double                     InpCommissionPerLot         = 0.0;                        // Phí round-turn/lot (0 = ước tính từ lịch sử)

input group "=== THỰC THI / HỆ THỐNG ==="
input int                        InpMaxSendAttempts       = IDHG_DEF_MAX_SEND_ATTEMPTS; // Số lần gửi tối đa (lỗi tạm thời)
input int                        InpConfirmTimeoutSec     = IDHG_DEF_CONFIRM_TIMEOUT;   // Timeout xác nhận mở (giây)
input int                        InpCloseTimeoutSec       = IDHG_DEF_CLOSE_TIMEOUT;     // Timeout xác nhận đóng (giây)
input int                        InpTimerSeconds          = IDHG_DEF_TIMER_SECONDS;     // Chu kỳ timer (giây)
input int                        InpReconcileSeconds      = IDHG_DEF_RECONCILE_SECONDS; // Chu kỳ đối soát broker (giây)
input int                        InpLogThrottleSec        = IDHG_DEF_LOG_THROTTLE;      // Giới hạn log lặp (giây)

input group "=== DASHBOARD ==="
input bool                       InpDashboardEnabled      = true;   // Hiển thị dashboard
input int                        InpDashboardX            = 10;     // Vị trí X
input int                        InpDashboardY            = 20;     // Vị trí Y
input int                        InpDashboardFontSize     = 8;      // Cỡ chữ
input int                        InpConfirmWindowSec      = 10;     // Thời gian chờ xác nhận nút nguy hiểm (giây)

//--- Dựng cấu hình từ input
void IdhgConfigFromInputs(SIdhgConfig &c)
  {
   c.SetDefaults();
   c.general.magic = InpMagicNumber;
   c.general.commentPrefix = InpCommentPrefix;
   c.general.deviationPoints = InpDeviationPoints;
   c.general.sideEnabled[IDHG_BUY] = InpBuyEnabled;
   c.general.sideEnabled[IDHG_SELL] = InpSellEnabled;
   c.general.autoStartFirstCycle = InpAutoStartFirstCycle;
   c.general.maxSendAttempts = InpMaxSendAttempts;
   c.general.confirmTimeoutSec = InpConfirmTimeoutSec;
   c.general.closeTimeoutSec = InpCloseTimeoutSec;
   c.general.timerSeconds = InpTimerSeconds;
   c.general.reconcileSeconds = InpReconcileSeconds;
   c.general.logThrottleSec = InpLogThrottleSec;
   c.general.dashboardEnabled = InpDashboardEnabled;
   c.general.dashboardX = InpDashboardX;
   c.general.dashboardY = InpDashboardY;
   c.general.dashboardFontSize = InpDashboardFontSize;
   c.general.confirmWindowSec = InpConfirmWindowSec;

   c.grid.distanceMode = InpDistanceMode;
   c.grid.baseDistance = InpBaseDistance;
   c.grid.distMultiplier = InpDistanceMultiplier;
   c.grid.additiveStep = InpAdditiveStep;
   c.grid.minDistance = InpMinDistance;
   c.grid.maxDistance = InpMaxDistance;
   c.grid.gapMode = InpGapMode;
   c.grid.buyLot = InpBuyLot;
   c.grid.sellLot = InpSellLot;
   c.grid.lotMultiplier = InpLotMultiplier;
   c.grid.minLot = InpMinLot;
   c.grid.maxLot = InpMaxLot;
   c.grid.reopenClosedLevel = InpReopenClosedLevel;

   c.profit.indivEnabled[IDHG_BUY] = InpBuyIndividualTPEnabled;
   c.profit.indivDistance[IDHG_BUY] = InpBuyIndividualTPDistance;
   c.profit.basketEnabled[IDHG_BUY] = InpBuyBasketTPEnabled;
   c.profit.basketTarget[IDHG_BUY] = InpBuyBasketTargetCent;
   c.profit.sideTotalEnabled[IDHG_BUY] = InpBuySideTotalTPEnabled;
   c.profit.sideTotalTarget[IDHG_BUY] = InpBuySideTotalTargetCent;
   c.profit.unlimitedHold[IDHG_BUY] = InpBuyUnlimitedHold;
   c.profit.indivEnabled[IDHG_SELL] = InpSellIndividualTPEnabled;
   c.profit.indivDistance[IDHG_SELL] = InpSellIndividualTPDistance;
   c.profit.basketEnabled[IDHG_SELL] = InpSellBasketTPEnabled;
   c.profit.basketTarget[IDHG_SELL] = InpSellBasketTargetCent;
   c.profit.sideTotalEnabled[IDHG_SELL] = InpSellSideTotalTPEnabled;
   c.profit.sideTotalTarget[IDHG_SELL] = InpSellSideTotalTargetCent;
   c.profit.unlimitedHold[IDHG_SELL] = InpSellUnlimitedHold;

   c.risk.maxOrders = InpMaxOrders;
   c.risk.maxTotalLots = InpMaxTotalLots;
   c.risk.maxBuyLots = InpMaxBuyLots;
   c.risk.maxSellLots = InpMaxSellLots;
   c.risk.emergencyDrawdownEnabled = InpEmergencyDrawdownEnabled;
   c.risk.maxDrawdownPercent = InpMaxDrawdownPercent;
   c.risk.maxMarginUsageEnabled = InpMaxMarginUsageEnabled;
   c.risk.maxMarginUsagePercent = InpMaxMarginUsagePercent;
   c.risk.minimumMarginLevel = InpMinimumMarginLevel;
   c.risk.equityFloor = InpEquityFloor;
   c.risk.maxSpread = InpMaxSpread;
   c.risk.emergencyAction = InpEmergencyAction;

   c.capacity.plannerEnabled = InpSurvivalPlannerEnabled;
   c.capacity.referencePrice = InpSurvivalReferencePrice;
   c.capacity.targetPrice = InpSurvivalTargetPrice;
   c.capacity.adverseDistance = InpSurvivalAdverseDistance;
   c.capacity.riskBudgetPercent = InpSurvivalRiskBudgetPercent;
   c.capacity.safetyBufferPercent = InpSurvivalSafetyBufferPercent;
   c.capacity.mode = InpCapacityMode;
   c.capacity.maxOrdersAuto = InpMaxOrdersAuto;
   c.capacity.commissionPerLot = InpCommissionPerLot;
   c.capacity.creditFutureProfit = false;   // đặc tả: mặc định KHÔNG tính lời tương lai
  }

#endif
