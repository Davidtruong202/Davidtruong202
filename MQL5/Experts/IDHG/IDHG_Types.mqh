//+------------------------------------------------------------------+
//| IDHG_Types.mqh                                                   |
//| Independent Dynamic Hedge Grid — kiểu dữ liệu dùng chung          |
//| Không phụ thuộc terminal (thuần logic).                          |
//+------------------------------------------------------------------+
#ifndef IDHG_TYPES_MQH
#define IDHG_TYPES_MQH

#define IDHG_VERSION          "1.00"
#define IDHG_SIDE_COUNT       2
#define IDHG_NO_LEVEL         (-1)
#define IDHG_EPS              1e-9

//--- Phía giao dịch. BUY và SELL là hai engine ĐỘC LẬP.
enum ENUM_IDHG_SIDE
  {
   IDHG_BUY  = 0,
   IDHG_SELL = 1
  };

//--- Chế độ khoảng cách grid
enum ENUM_IDHG_DISTANCE_MODE
  {
   IDHG_DIST_FIXED      = 0,   // FIXED: mọi bước bằng Base
   IDHG_DIST_MULTIPLIER = 1,   // MULTIPLIER: Base * Mult^(i-1)
   IDHG_DIST_ADDITIVE   = 2    // ADDITIVE: Base + Step*(i-1)
  };

//--- Xử lý khi giá nhảy qua nhiều level trong một lần
enum ENUM_IDHG_GAP_MODE
  {
   IDHG_GAP_OPEN_ALL_CROSSED  = 0,  // mở tất cả level bị vượt (gần → xa)
   IDHG_GAP_OPEN_LATEST_ONLY  = 1,  // chỉ mở level xa nhất, các level còn lại SKIPPED
   IDHG_GAP_SKIP_CROSSED      = 2   // bỏ qua tất cả level bị vượt (SKIPPED)
  };

//--- Trạng thái của một level
enum ENUM_IDHG_LEVEL_STATUS
  {
   IDHG_LVL_NONE    = 0,   // chưa được xử lý
   IDHG_LVL_CROSSED = 1,   // giá đã vượt, đang là ứng viên (candidate)
   IDHG_LVL_SENDING = 2,   // đã gửi lệnh, chờ broker xác nhận (nội bộ)
   IDHG_LVL_OPEN    = 3,   // broker xác nhận position đang mở
   IDHG_LVL_CLOSED  = 4,   // position đã đóng (broker xác nhận)
   IDHG_LVL_SKIPPED = 5,   // bỏ qua, có lý do; KHÔNG retry, KHÔNG backfill
   IDHG_LVL_FAILED  = 6    // gửi thất bại (tạm thời, trước khi retry/skip)
  };

//--- Lý do (skip / fail / ghi chú) — lưu cùng level
enum ENUM_IDHG_REASON
  {
   IDHG_R_NONE                  = 0,
   IDHG_R_SKIPPED_MAX_ORDERS    = 1,
   IDHG_R_SKIPPED_MAX_LOTS      = 2,   // MaxTotalLots
   IDHG_R_SKIPPED_MAX_SIDE_LOTS = 3,   // MaxBuyLots / MaxSellLots
   IDHG_R_SKIPPED_SPREAD        = 4,
   IDHG_R_SKIPPED_BROKER_ERROR  = 5,
   IDHG_R_SKIPPED_RISK          = 6,
   IDHG_R_SKIPPED_GAP_MODE      = 7,
   IDHG_R_SKIPPED_MARGIN        = 8,
   IDHG_R_SKIPPED_CAPACITY      = 9,
   IDHG_R_SKIPPED_PAUSED        = 10,
   IDHG_R_SKIPPED_STOP_GRID     = 11,
   IDHG_R_SKIPPED_SIDE_OFF      = 12,
   IDHG_R_SKIPPED_TRADE_DISABLED= 13,
   IDHG_R_SKIPPED_VOLUME        = 14,
   IDHG_R_SKIPPED_STATE         = 15,
   IDHG_R_SKIPPED_DUPLICATE     = 16,
   IDHG_R_FAILED_TRANSIENT      = 17,  // lỗi tạm thời (requote ...), sẽ thử lại có giới hạn
   IDHG_R_RECOVERED             = 18,
   IDHG_R_REASON_COUNT          = 19
  };

//--- Lý do đóng position
enum ENUM_IDHG_CLOSE_REASON
  {
   IDHG_CR_NONE            = 0,
   IDHG_CR_INDIVIDUAL_TP   = 1,
   IDHG_CR_BASKET_TP       = 2,
   IDHG_CR_SIDE_TOTAL_TP   = 3,
   IDHG_CR_EMERGENCY       = 4,
   IDHG_CR_MANUAL_PROFIT   = 5,
   IDHG_CR_MANUAL_SIDE     = 6,
   IDHG_CR_MANUAL_ALL      = 7,
   IDHG_CR_EXTERNAL        = 8    // đóng bởi broker/người dùng ngoài EA (stop-out ...)
  };

//--- Trạng thái chu kỳ / máy trạng thái EA
enum ENUM_IDHG_STATE
  {
   IDHG_STATE_IDLE        = 0,
   IDHG_STATE_RUNNING     = 1,
   IDHG_STATE_PAUSED      = 2,
   IDHG_STATE_STOP_GRID   = 3,
   IDHG_STATE_CYCLE_ENDED = 4
  };

//--- Hành động khẩn cấp khi vượt ngưỡng rủi ro
enum ENUM_IDHG_EMERGENCY_ACTION
  {
   IDHG_EMERGENCY_STOP_NEW_ENTRIES = 0,  // mặc định: chỉ chặn vào lệnh mới
   IDHG_EMERGENCY_CLOSE_ALL        = 1   // đóng toàn bộ lệnh EA + chuyển STOP_GRID
  };

//--- Chế độ giới hạn sức chứa
enum ENUM_IDHG_CAPACITY_MODE
  {
   IDHG_CAP_MANUAL           = 0,  // chỉ dùng MaxOrders/MaxLots người dùng nhập
   IDHG_CAP_AUTO_BY_MARGIN   = 1,  // giới hạn thêm theo margin dự phóng tại giá vào lệnh
   IDHG_CAP_SURVIVE_TO_PRICE = 2   // giới hạn thêm để chịu được tới giá bất lợi mục tiêu
  };

//--- Trạng thái sức chịu đựng
enum ENUM_IDHG_CAPACITY_STATUS
  {
   IDHG_CAPS_UNKNOWN      = 0,
   IDHG_CAPS_SAFE         = 1,
   IDHG_CAPS_WARNING      = 2,
   IDHG_CAPS_DANGER       = 3,
   IDHG_CAPS_NOT_FEASIBLE = 4
  };

//--- Lệnh điều khiển từ dashboard / người dùng
enum ENUM_IDHG_COMMAND
  {
   IDHG_CMD_NONE = 0,
   IDHG_CMD_START,
   IDHG_CMD_PAUSE,
   IDHG_CMD_RESUME,
   IDHG_CMD_STOP_GRID,
   IDHG_CMD_RESUME_GRID,
   IDHG_CMD_TOGGLE_BUY,
   IDHG_CMD_TOGGLE_SELL,
   IDHG_CMD_TOGGLE_BASKET_BUY,
   IDHG_CMD_TOGGLE_BASKET_SELL,
   IDHG_CMD_TOGGLE_INDIV_BUY,
   IDHG_CMD_TOGGLE_INDIV_SELL,
   IDHG_CMD_TOGGLE_SIDETOTAL_BUY,
   IDHG_CMD_TOGGLE_SIDETOTAL_SELL,
   IDHG_CMD_TOGGLE_HOLD_BUY,
   IDHG_CMD_TOGGLE_HOLD_SELL,
   IDHG_CMD_CLOSE_PROFIT_BUY,
   IDHG_CMD_CLOSE_PROFIT_SELL,
   IDHG_CMD_CLOSE_BUY,
   IDHG_CMD_CLOSE_SELL,
   IDHG_CMD_CLOSE_ALL,
   IDHG_CMD_RESET_CYCLE,
   IDHG_CMD_APPLY_GRID,
   IDHG_CMD_DISCARD_GRID,
   IDHG_CMD_COUNT
  };

//+------------------------------------------------------------------+
//| Thông số symbol (đọc từ broker, không hard-code)                  |
//+------------------------------------------------------------------+
struct SIdhgSymbolSpec
  {
   string            name;
   int               digits;
   double            point;
   double            tickSize;
   double            tickValue;        // tiền tài khoản / 1 tick / 1 lot
   double            tickValueLoss;
   double            contractSize;
   double            volMin;
   double            volMax;
   double            volStep;
   double            volLimit;
   double            marginHedged;     // SYMBOL_MARGIN_HEDGED
   bool              marginHedgedUseLeg;
   long              tradeMode;
   long              fillingMode;
   long              stopsLevel;
   long              freezeLevel;
   bool              valid;

   void              Reset(void)
     {
      name = ""; digits = 0; point = 0; tickSize = 0; tickValue = 0; tickValueLoss = 0;
      contractSize = 0; volMin = 0; volMax = 0; volStep = 0; volLimit = 0; marginHedged = 0;
      marginHedgedUseLeg = false; tradeMode = 0; fillingMode = 0; stopsLevel = 0; freezeLevel = 0;
      valid = false;
     }
  };

//+------------------------------------------------------------------+
//| Ảnh chụp tài khoản (đọc từ broker)                                |
//+------------------------------------------------------------------+
struct SIdhgAccountSnap
  {
   double            balance;
   double            equity;
   double            margin;
   double            freeMargin;
   double            marginLevel;      // %, 0 nếu không có margin
   double            stopOutLevel;     // ACCOUNT_MARGIN_SO_SO
   double            marginCallLevel;  // ACCOUNT_MARGIN_SO_CALL
   bool              stopOutPercent;   // true: mức stop-out tính theo %
   long              leverage;
   long              marginMode;
   bool              tradeAllowed;
   bool              valid;

   void              Reset(void)
     {
      balance = 0; equity = 0; margin = 0; freeMargin = 0; marginLevel = 0;
      stopOutLevel = 0; marginCallLevel = 0; stopOutPercent = true; leverage = 0;
      marginMode = 0; tradeAllowed = false; valid = false;
     }
  };

//+------------------------------------------------------------------+
//| Giá thị trường hiện tại                                          |
//+------------------------------------------------------------------+
struct SIdhgMarket
  {
   double            bid;
   double            ask;
   double            mid;
   double            spread;          // theo GIÁ (ask - bid)
   datetime          time;
   bool              valid;

   void              Reset(void) { bid = 0; ask = 0; mid = 0; spread = 0; time = 0; valid = false; }
  };

//+------------------------------------------------------------------+
//| Một level của grid                                               |
//+------------------------------------------------------------------+
struct SIdhgLevel
  {
   int               cycleId;
   ENUM_IDHG_SIDE    side;
   int               levelId;
   double            logicalPrice;     // giá logic của grid (KHÔNG phải giá khớp)
   double            distance;         // khoảng cách từ level trước
   double            lot;              // lot đã normalize
   double            lotRaw;           // lot lý thuyết (trước normalize) — dùng cho multiplier
   ENUM_IDHG_LEVEL_STATUS status;
   ENUM_IDHG_REASON  reason;
   int               retcode;          // retcode broker gần nhất (nếu có)
   datetime          openTime;
   datetime          closeTime;
   double            actualEntryPrice; // giá khớp thực tế
   ulong             ticket;           // position ticket hiện tại / gần nhất
   ulong             orderTicket;      // order ticket của lần gửi gần nhất
   int               attempts;         // số lần gửi trong lần mở hiện tại
   int               timesOpened;      // số lần broker xác nhận mở (reopen > 1)
   bool              rearmed;          // dùng cho ReopenClosedLevel
   bool              priceEstimated;   // recovery: giá logic là ước tính

   void              Reset(void)
     {
      cycleId = 0; side = IDHG_BUY; levelId = IDHG_NO_LEVEL; logicalPrice = 0; distance = 0;
      lot = 0; lotRaw = 0; status = IDHG_LVL_NONE; reason = IDHG_R_NONE; retcode = 0;
      openTime = 0; closeTime = 0; actualEntryPrice = 0; ticket = 0; orderTicket = 0;
      attempts = 0; timesOpened = 0; rearmed = false; priceEstimated = false;
     }
  };

//+------------------------------------------------------------------+
//| Ứng viên mở lệnh do Grid Engine trả về (Grid KHÔNG gửi lệnh)       |
//+------------------------------------------------------------------+
struct SIdhgCandidate
  {
   ENUM_IDHG_SIDE    side;
   int               cycleId;
   int               levelId;
   double            logicalPrice;
   double            distance;
   double            lot;
   int               direction;        // +1 BUY, -1 SELL
   ENUM_IDHG_LEVEL_STATUS status;
   ENUM_IDHG_REASON  reason;
   bool              isInitial;
   bool              isReopen;

   void              Reset(void)
     {
      side = IDHG_BUY; cycleId = 0; levelId = IDHG_NO_LEVEL; logicalPrice = 0; distance = 0;
      lot = 0; direction = 0; status = IDHG_LVL_NONE; reason = IDHG_R_NONE;
      isInitial = false; isReopen = false;
     }
  };

//+------------------------------------------------------------------+
//| Ảnh chụp một position của EA                                     |
//+------------------------------------------------------------------+
struct SIdhgPosition
  {
   ulong             ticket;
   ulong             identifier;
   ENUM_IDHG_SIDE    side;
   double            volume;
   double            priceOpen;
   double            priceCurrent;
   double            profit;
   double            swap;
   double            commission;       // tổng commission đã tính (âm = phí) theo dấu MT5
   double            net;              // profit + swap + commission
   datetime          timeOpen;
   string            comment;
   int               cycleId;          // 0 nếu không parse được
   int               levelId;          // IDHG_NO_LEVEL nếu không parse được
   double            logicalPrice;     // từ comment nếu có, 0 nếu không
   bool              parsed;
   bool              closing;          // đã gửi lệnh đóng, chờ xác nhận

   void              Reset(void)
     {
      ticket = 0; identifier = 0; side = IDHG_BUY; volume = 0; priceOpen = 0; priceCurrent = 0;
      profit = 0; swap = 0; commission = 0; net = 0; timeOpen = 0; comment = "";
      cycleId = 0; levelId = IDHG_NO_LEVEL; logicalPrice = 0; parsed = false; closing = false;
     }
  };

//+------------------------------------------------------------------+
//| Bản ghi deal (dùng cho recovery + thống kê)                       |
//+------------------------------------------------------------------+
struct SIdhgDeal
  {
   ulong             ticket;
   ulong             order;
   ulong             positionId;
   datetime          time;
   bool              entryIn;          // true = DEAL_ENTRY_IN
   bool              entryOut;         // true = DEAL_ENTRY_OUT / OUT_BY
   ENUM_IDHG_SIDE    positionSide;     // phía của POSITION (không phải deal)
   double            volume;
   double            price;
   double            profit;
   double            swap;
   double            commission;
   double            fee;
   string            comment;

   void              Reset(void)
     {
      ticket = 0; order = 0; positionId = 0; time = 0; entryIn = false; entryOut = false;
      positionSide = IDHG_BUY; volume = 0; price = 0; profit = 0; swap = 0; commission = 0;
      fee = 0; comment = "";
     }
  };

//+------------------------------------------------------------------+
//| Kết quả phân tích comment "DHG|C001|BUY|L005|5010.00"             |
//+------------------------------------------------------------------+
struct SIdhgCommentInfo
  {
   bool              ok;
   bool              hasPrice;
   int               cycleId;
   ENUM_IDHG_SIDE    side;
   int               levelId;
   double            logicalPrice;
   string            error;

   void              Reset(void)
     {
      ok = false; hasPrice = false; cycleId = 0; side = IDHG_BUY; levelId = IDHG_NO_LEVEL;
      logicalPrice = 0; error = "";
     }
  };

#endif
