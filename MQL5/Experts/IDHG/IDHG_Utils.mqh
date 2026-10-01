//+------------------------------------------------------------------+
//| IDHG_Utils.mqh                                                   |
//| Tiện ích: normalize giá/lot, Net P/L, spread, comment, margin,   |
//| kiểm tra broker, log có kiểm soát.                               |
//| Phần A: thuần logic (không gọi terminal).                         |
//| Phần B: đọc dữ liệu thật từ terminal/broker.                      |
//+------------------------------------------------------------------+
#ifndef IDHG_UTILS_MQH
#define IDHG_UTILS_MQH

#include "IDHG_Types.mqh"

#define IDHG_MAX_COMMENT_LEN  31     // giới hạn comment lệnh của MT5

//==================================================================//
// PHẦN A — THUẦN LOGIC                                             //
//==================================================================//

string IdhgSideName(const ENUM_IDHG_SIDE side) { return side == IDHG_BUY ? "BUY" : "SELL"; }
int    IdhgSideDir(const ENUM_IDHG_SIDE side)  { return side == IDHG_BUY ? 1 : -1; }
ENUM_IDHG_SIDE IdhgSideFromIndex(const int i)  { return i == 0 ? IDHG_BUY : IDHG_SELL; }
string IdhgBoolVN(const bool v)                 { return v ? "BẬT" : "TẮT"; }
string IdhgBoolStr(const bool v)                { return v ? "true" : "false"; }

//--- So sánh số thực có dung sai
bool IdhgGE(const double a, const double b) { return a >= b - IDHG_EPS; }
bool IdhgLE(const double a, const double b) { return a <= b + IDHG_EPS; }
bool IdhgEQ(const double a, const double b) { return MathAbs(a - b) <= IDHG_EPS; }

//--- Số chữ số thập phân của một bước (vd 0.01 → 2)
int IdhgStepDigits(const double step)
  {
   if(step <= 0.0)
      return 8;
   int d = 0;
   double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-7)
     {
      s *= 10.0;
      d++;
     }
   return d;
  }

//--- Làm tròn giá về bội số của tick size (không normalize digits)
double TickSizeNormalize(const double price, const double tickSize)
  {
   if(tickSize <= 0.0)
      return price;
   return MathRound(price / tickSize) * tickSize;
  }

//--- Normalize giá theo SYMBOL_TRADE_TICK_SIZE + _Digits
double PriceNormalize(const double price, const double tickSize, const int digits)
  {
   return NormalizeDouble(TickSizeNormalize(price, tickSize), digits);
  }

//--- Normalize lot theo SYMBOL_VOLUME_MIN/MAX/STEP và MinLot/MaxLot của người dùng.
//    Làm tròn XUỐNG theo step (không bao giờ vượt lot lý thuyết trừ khi < volume min).
//    Trả về 0 nếu không thể tạo lot hợp lệ.
double LotNormalize(const double rawLot, const double volMin, const double volMax, const double volStep,
                    const double userMinLot, const double userMaxLot)
  {
   if(rawLot <= 0.0 || volStep <= 0.0 || volMin <= 0.0 || volMax <= 0.0)
      return 0.0;
   double lower = MathMax(volMin, userMinLot);
   double upper = volMax;
   if(userMaxLot > 0.0)
      upper = MathMin(upper, userMaxLot);
   if(lower > upper + IDHG_EPS)
      return 0.0;
   double lot = MathFloor(rawLot / volStep + 1e-7) * volStep;
   if(lot < lower)
      lot = lower;
   if(lot > upper)
      lot = MathFloor(upper / volStep + 1e-7) * volStep;
   if(lot < volMin - IDHG_EPS)
      return 0.0;
   return NormalizeDouble(lot, IdhgStepDigits(volStep));
  }

//--- Net P/L = Profit + Swap + Commission (+ Fee). Commission theo dấu MT5: âm = phí.
double GetNetPL(const double profit, const double swap, const double commission, const double fee = 0.0)
  {
   return profit + swap + commission + fee;
  }

//--- Spread theo GIÁ
double GetSpread(const double bid, const double ask) { return ask - bid; }

//--- Kiểm tra tài khoản HEDGING
bool IdhgIsHedgingMode(const long marginMode) { return marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; }

//--- Tên mã lý do (tên kỹ thuật, dùng trong log và dashboard)
string IdhgReasonCode(const ENUM_IDHG_REASON r)
  {
   switch(r)
     {
      case IDHG_R_NONE:                   return "";
      case IDHG_R_SKIPPED_MAX_ORDERS:     return "SKIPPED_MAX_ORDERS";
      case IDHG_R_SKIPPED_MAX_LOTS:       return "SKIPPED_MAX_LOTS";
      case IDHG_R_SKIPPED_MAX_SIDE_LOTS:  return "SKIPPED_MAX_SIDE_LOTS";
      case IDHG_R_SKIPPED_SPREAD:         return "SKIPPED_SPREAD";
      case IDHG_R_SKIPPED_BROKER_ERROR:   return "SKIPPED_BROKER_ERROR";
      case IDHG_R_SKIPPED_RISK:           return "SKIPPED_RISK";
      case IDHG_R_SKIPPED_GAP_MODE:       return "SKIPPED_GAP_MODE";
      case IDHG_R_SKIPPED_MARGIN:         return "SKIPPED_MARGIN";
      case IDHG_R_SKIPPED_CAPACITY:       return "SKIPPED_CAPACITY";
      case IDHG_R_SKIPPED_PAUSED:         return "SKIPPED_PAUSED";
      case IDHG_R_SKIPPED_STOP_GRID:      return "SKIPPED_STOP_GRID";
      case IDHG_R_SKIPPED_SIDE_OFF:       return "SKIPPED_SIDE_OFF";
      case IDHG_R_SKIPPED_TRADE_DISABLED: return "SKIPPED_TRADE_DISABLED";
      case IDHG_R_SKIPPED_VOLUME:         return "SKIPPED_VOLUME";
      case IDHG_R_SKIPPED_STATE:          return "SKIPPED_STATE";
      case IDHG_R_SKIPPED_DUPLICATE:      return "SKIPPED_DUPLICATE";
      case IDHG_R_FAILED_TRANSIENT:       return "FAILED_TRANSIENT";
      case IDHG_R_RECOVERED:              return "RECOVERED";
      default:                            return "REASON_" + IntegerToString((int)r);
     }
  }

string IdhgLevelStatusName(const ENUM_IDHG_LEVEL_STATUS s)
  {
   switch(s)
     {
      case IDHG_LVL_NONE:    return "NONE";
      case IDHG_LVL_CROSSED: return "CROSSED";
      case IDHG_LVL_SENDING: return "SENDING";
      case IDHG_LVL_OPEN:    return "OPEN";
      case IDHG_LVL_CLOSED:  return "CLOSED";
      case IDHG_LVL_SKIPPED: return "SKIPPED";
      case IDHG_LVL_FAILED:  return "FAILED";
      default:               return "?";
     }
  }

string IdhgCloseReasonName(const ENUM_IDHG_CLOSE_REASON r)
  {
   switch(r)
     {
      case IDHG_CR_INDIVIDUAL_TP: return "INDIVIDUAL_TP";
      case IDHG_CR_BASKET_TP:     return "BASKET_TP";
      case IDHG_CR_SIDE_TOTAL_TP: return "SIDE_TOTAL_TP";
      case IDHG_CR_EMERGENCY:     return "EMERGENCY";
      case IDHG_CR_MANUAL_PROFIT: return "MANUAL_CLOSE_PROFIT";
      case IDHG_CR_MANUAL_SIDE:   return "MANUAL_CLOSE_SIDE";
      case IDHG_CR_MANUAL_ALL:    return "MANUAL_CLOSE_ALL";
      case IDHG_CR_EXTERNAL:      return "EXTERNAL";
      default:                    return "NONE";
     }
  }

string IdhgDistanceModeName(const ENUM_IDHG_DISTANCE_MODE m)
  {
   switch(m)
     {
      case IDHG_DIST_FIXED:      return "FIXED";
      case IDHG_DIST_MULTIPLIER: return "MULTIPLIER";
      case IDHG_DIST_ADDITIVE:   return "ADDITIVE";
      default:                   return "?";
     }
  }

string IdhgGapModeName(const ENUM_IDHG_GAP_MODE m)
  {
   switch(m)
     {
      case IDHG_GAP_OPEN_ALL_CROSSED: return "OPEN_ALL_CROSSED";
      case IDHG_GAP_OPEN_LATEST_ONLY: return "OPEN_LATEST_ONLY";
      case IDHG_GAP_SKIP_CROSSED:     return "SKIP_CROSSED";
      default:                        return "?";
     }
  }

string IdhgCapacityModeName(const ENUM_IDHG_CAPACITY_MODE m)
  {
   switch(m)
     {
      case IDHG_CAP_MANUAL:           return "MANUAL";
      case IDHG_CAP_AUTO_BY_MARGIN:   return "AUTO_BY_MARGIN";
      case IDHG_CAP_SURVIVE_TO_PRICE: return "SURVIVE_TO_PRICE";
      default:                        return "?";
     }
  }

string IdhgCapacityStatusName(const ENUM_IDHG_CAPACITY_STATUS s)
  {
   switch(s)
     {
      case IDHG_CAPS_SAFE:         return "SAFE";
      case IDHG_CAPS_WARNING:      return "WARNING";
      case IDHG_CAPS_DANGER:       return "DANGER";
      case IDHG_CAPS_NOT_FEASIBLE: return "NOT FEASIBLE";
      default:                     return "UNKNOWN";
     }
  }

//--- "C001", "L005"
string IdhgCycleTag(const int cycleId) { return "C" + IntegerToString(cycleId, 3, '0'); }
string IdhgLevelTag(const int levelId) { return "L" + IntegerToString(levelId, 3, '0'); }

//--- Comment: PREFIX|C001|BUY|L005|5010.00  (phần giá bị bỏ nếu vượt 31 ký tự)
string IdhgBuildComment(const string prefix, const int cycleId, const ENUM_IDHG_SIDE side,
                        const int levelId, const double logicalPrice, const int digits)
  {
   string base = prefix + "|" + IdhgCycleTag(cycleId) + "|" + IdhgSideName(side) + "|" + IdhgLevelTag(levelId);
   string full = base + "|" + DoubleToString(logicalPrice, digits);
   if(StringLen(full) <= IDHG_MAX_COMMENT_LEN)
      return full;
   return base;
  }

bool IdhgIsAllDigits(const string s)
  {
   int n = StringLen(s);
   if(n == 0)
      return false;
   for(int i = 0; i < n; i++)
     {
      string ch = StringSubstr(s, i, 1);
      if(StringFind("0123456789", ch) < 0)
         return false;
     }
   return true;
  }

//--- Kiểm tra chuỗi giá: chỉ chữ số + đúng 1 dấu '.', đúng 'digits' chữ số thập phân
bool IdhgIsPriceString(const string s, const int digits)
  {
   int dot = StringFind(s, ".");
   if(digits == 0)
      return IdhgIsAllDigits(s);
   if(dot <= 0)
      return false;
   string ip = StringSubstr(s, 0, dot);
   string fp = StringSubstr(s, dot + 1);
   return IdhgIsAllDigits(ip) && IdhgIsAllDigits(fp) && StringLen(fp) == digits;
  }

//--- Phân tích comment. KHÔNG đoán: sai định dạng → ok=false + error.
bool IdhgParseComment(const string comment, const string prefix, const int digits, SIdhgCommentInfo &info)
  {
   info.Reset();
   string parts[];
   int n = StringSplit(comment, (ushort)StringGetCharacter("|", 0), parts);
   if(n < 4 || n > 5)
     {
      info.error = "số trường không hợp lệ";
      return false;
     }
   if(parts[0] != prefix)
     {
      info.error = "prefix khác";
      return false;
     }
   if(StringLen(parts[1]) < 2 || StringSubstr(parts[1], 0, 1) != "C" || !IdhgIsAllDigits(StringSubstr(parts[1], 1)))
     {
      info.error = "CycleID hỏng";
      return false;
     }
   if(parts[2] == "BUY")
      info.side = IDHG_BUY;
   else
      if(parts[2] == "SELL")
         info.side = IDHG_SELL;
      else
        {
         info.error = "Side hỏng";
         return false;
        }
   if(StringLen(parts[3]) < 2 || StringSubstr(parts[3], 0, 1) != "L" || !IdhgIsAllDigits(StringSubstr(parts[3], 1)))
     {
      info.error = "LevelID hỏng";
      return false;
     }
   info.cycleId = (int)StringToInteger(StringSubstr(parts[1], 1));
   info.levelId = (int)StringToInteger(StringSubstr(parts[3], 1));
   if(info.cycleId <= 0 || info.levelId < 0)
     {
      info.error = "ID ngoài phạm vi";
      return false;
     }
   if(n == 5)
     {
      if(IdhgIsPriceString(parts[4], digits))
        {
         info.hasPrice = true;
         info.logicalPrice = StringToDouble(parts[4]);
        }
      else
         info.error = "giá logic trong comment hỏng/bị cắt";
     }
   info.ok = true;
   return true;
  }

//--- Margin ước tính cho một rổ lệnh BUY/SELL trên tài khoản hedging.
//    marginPerLot: margin của 1 lot (từ OrderCalcMargin). hedgedRatio = SYMBOL_MARGIN_HEDGED / CONTRACT_SIZE.
//    useLeg = SYMBOL_MARGIN_HEDGED_USE_LEG (tính theo chân lớn hơn).
double IdhgEstimateHedgedMargin(const double buyLots, const double sellLots, const double marginPerLotBuy,
                                const double marginPerLotSell, const double hedgedRatio, const bool useLeg)
  {
   if(useLeg)
      return MathMax(buyLots * marginPerLotBuy, sellLots * marginPerLotSell);
   double hedged = MathMin(buyLots, sellLots);
   double perLotAvg = (marginPerLotBuy + marginPerLotSell) * 0.5;
   double unhedgedBuy = buyLots - hedged;
   double unhedgedSell = sellLots - hedged;
   return unhedgedBuy * marginPerLotBuy + unhedgedSell * marginPerLotSell + 2.0 * hedged * perLotAvg * hedgedRatio;
  }

//--- Kiểm tra thông số symbol đủ dữ liệu
bool IdhgCheckSymbolSpec(const SIdhgSymbolSpec &spec, string &err)
  {
   err = "";
   if(spec.tickSize <= 0.0)
      err += "tick size=0; ";
   if(spec.volMin <= 0.0 || spec.volMax <= 0.0 || spec.volStep <= 0.0)
      err += "volume min/max/step không hợp lệ; ";
   if(spec.contractSize <= 0.0)
      err += "contract size=0; ";
   if(spec.tickValue <= 0.0)
      err += "tick value=0; ";
   if(spec.digits < 0 || spec.digits > 10)
      err += "digits bất thường; ";
   return err == "";
  }

//+------------------------------------------------------------------+
//| Log có kiểm soát: cùng một key chỉ in tối đa 1 lần / khoảng thời gian|
//+------------------------------------------------------------------+
class CIdhgLog
  {
private:
   string            m_keys[];
   datetime          m_times[];
   int               m_throttleSec;
   bool              m_quiet;

public:
                     CIdhgLog(void) : m_throttleSec(30), m_quiet(false) {}
   void              SetThrottle(const int sec) { m_throttleSec = sec; }
   void              SetQuiet(const bool q) { m_quiet = q; }
   //--- In ngay (sự kiện quan trọng: gửi lệnh, xác nhận, lỗi)
   void              Info(const string msg) { if(!m_quiet) Print("[IDHG] ", msg); }
   void              Warn(const string msg) { if(!m_quiet) Print("[IDHG][CẢNH BÁO] ", msg); }
   //--- In có giới hạn theo key (sự kiện lặp lại mỗi tick)
   bool              Throttled(const string key, const string msg, const datetime now)
     {
      int n = ArraySize(m_keys);
      for(int i = 0; i < n; i++)
        {
         if(m_keys[i] == key)
           {
            if(now - m_times[i] < m_throttleSec)
               return false;
            m_times[i] = now;
            if(!m_quiet)
               Print("[IDHG] ", msg);
            return true;
           }
        }
      ArrayResize(m_keys, n + 1);
      ArrayResize(m_times, n + 1);
      m_keys[n] = key;
      m_times[n] = now;
      if(!m_quiet)
         Print("[IDHG] ", msg);
      return true;
     }
  };

//==================================================================//
// PHẦN B — ĐỌC DỮ LIỆU THẬT TỪ TERMINAL / BROKER                   //
//==================================================================//

bool IdhgReadSymbolSpec(const string symbol, SIdhgSymbolSpec &spec)
  {
   spec.Reset();
   spec.name = symbol;
   spec.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   spec.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   spec.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   spec.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   spec.tickValueLoss = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(spec.tickValueLoss <= 0.0)
      spec.tickValueLoss = spec.tickValue;
   spec.contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   spec.volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   spec.volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   spec.volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   spec.volLimit = SymbolInfoDouble(symbol, SYMBOL_VOLUME_LIMIT);
   spec.marginHedged = SymbolInfoDouble(symbol, SYMBOL_MARGIN_HEDGED);
   spec.marginHedgedUseLeg = (SymbolInfoInteger(symbol, SYMBOL_MARGIN_HEDGED_USE_LEG) != 0);
   spec.tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   spec.fillingMode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   spec.stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   spec.freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   string err;
   spec.valid = IdhgCheckSymbolSpec(spec, err);
   return spec.valid;
  }

bool IdhgReadAccount(SIdhgAccountSnap &acc)
  {
   acc.Reset();
   acc.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   acc.equity = AccountInfoDouble(ACCOUNT_EQUITY);
   acc.margin = AccountInfoDouble(ACCOUNT_MARGIN);
   acc.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   acc.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   acc.stopOutLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   acc.marginCallLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
   acc.stopOutPercent = (AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE) == ACCOUNT_STOPOUT_MODE_PERCENT);
   acc.leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   acc.marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   acc.tradeAllowed = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0) && (AccountInfoInteger(ACCOUNT_TRADE_EXPERT) != 0);
   acc.valid = (acc.equity > 0.0 || acc.balance > 0.0);
   return acc.valid;
  }

bool IdhgReadMarket(const string symbol, const SIdhgSymbolSpec &spec, SIdhgMarket &mk)
  {
   mk.Reset();
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;
   if(tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;
   mk.bid = tick.bid;
   mk.ask = tick.ask;
   mk.mid = PriceNormalize((tick.bid + tick.ask) * 0.5, spec.tickSize, spec.digits);
   mk.spread = GetSpread(tick.bid, tick.ask);
   mk.time = tick.time;
   mk.valid = true;
   return true;
  }

//--- Quyền giao dịch: terminal + chương trình + tài khoản + symbol
bool IdhgTradePermitted(const SIdhgSymbolSpec &spec, const ENUM_IDHG_SIDE side, string &why)
  {
   why = "";
   if(TerminalInfoInteger(TERMINAL_CONNECTED) == 0)
      why = "terminal mất kết nối";
   else
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
         why = "terminal tắt AutoTrading";
      else
         if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
            why = "EA không được phép giao dịch";
         else
            if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0 || AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0)
               why = "tài khoản không cho phép giao dịch tự động";
            else
               if(spec.tradeMode == SYMBOL_TRADE_MODE_DISABLED || spec.tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
                  why = "symbol không cho mở lệnh mới";
               else
                  if(side == IDHG_BUY && spec.tradeMode == SYMBOL_TRADE_MODE_SHORTONLY)
                     why = "symbol chỉ cho SELL";
                  else
                     if(side == IDHG_SELL && spec.tradeMode == SYMBOL_TRADE_MODE_LONGONLY)
                        why = "symbol chỉ cho BUY";
   return why == "";
  }

#endif
