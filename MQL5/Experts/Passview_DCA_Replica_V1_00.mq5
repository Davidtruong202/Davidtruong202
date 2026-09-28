//+------------------------------------------------------------------+
//|                                  Passview_DCA_Replica_V1_00.mq5  |
//| Khung EA DCA de tai dung bot Passview tu du lieu TradeLogger.    |
//|                                                                  |
//| PHAN DA LAP TRINH DAY DU (khong phu thuoc logic Passview):       |
//|  - Quan ly basket theo Magic + symbol + chieu, khoi phuc sau     |
//|    khi khoi dong lai MT5 / doi timeframe (doc vi the dang mo).   |
//|  - Gioi han so leg, lot moi leg, tong lot, spread, margin level, |
//|    sut giam equity; xu ly loi dat/sua/dong lenh.                 |
//|  - Log CSV moi quyet dinh: mo lenh dau, them leg, bo qua, dong.  |
//|  - Chi ho tro tai khoan HEDGING (netting bi tu choi khi khoi dong)|
//|                                                                  |
//| PHAN CHUA KIEM CHUNG VOI PASSVIEW (chi la tham so de khop sau):  |
//|  - Tin hieu lenh dau, khoang cach DCA, cach tang lot, so leg toi |
//|    da, dieu kien chot/cat basket. Gia tri mac dinh la VI DU, KHONG|
//|    phai logic goc cua Passview. Xem docs/passview_dca/.          |
//+------------------------------------------------------------------+
#property copyright "Passview DCA Replica"
#property version   "1.00"
#property description "Khung EA DCA tái dựng bot Passview. Tín hiệu, bước DCA, lot, TP là tham số CHƯA KIỂM CHỨNG."
#property description "Chỉ hỗ trợ tài khoản hedging. Mặc định chỉ chạy demo/tester."

#include <Trade\Trade.mqh>

#define EA_VERSION "V1.00"

//--- che do tin hieu lenh dau
enum ENUM_PVR_ENTRY
  {
   PVR_ENTRY_OFF       = 0, // Tắt – chỉ quản lý basket đang có
   PVR_ENTRY_EMA_SIDE  = 1, // Giá đóng cửa trên EMA → BUY, dưới → SELL
   PVR_ENTRY_RSI       = 2, // RSI quá bán → BUY, quá mua → SELL
   PVR_ENTRY_CANDLE    = 3, // Theo màu nến vừa đóng
   PVR_ENTRY_BUY_ONLY  = 4, // Luôn BUY
   PVR_ENTRY_SELL_ONLY = 5  // Luôn SELL
  };

//--- cach tinh khoang cach DCA
enum ENUM_PVR_STEP
  {
   PVR_STEP_PRICE = 0, // Khoảng cách giá cố định
   PVR_STEP_ATR   = 1  // Bội số ATR (chốt tại lúc mở basket)
  };

//--- cach chot loi basket
enum ENUM_PVR_TP
  {
   PVR_TP_PRICE = 0, // Giá trung bình ± khoảng cách giá
   PVR_TP_ATR   = 1, // Giá trung bình ± bội số ATR
   PVR_TP_MONEY = 2  // Lãi ròng basket ≥ số tiền
  };

//====================================================================
// Input
//====================================================================
input group "1. Hệ thống và an toàn"
input long   InpMagic             = 55082601;  // Magic number riêng của EA
input bool   InpAllowRealAccount  = false;     // Cho phép chạy tài khoản THẬT
input int    InpSlippagePoints    = 50;        // Trượt giá tối đa (point)
input int    InpMaxRetries        = 3;         // Số lần thử lại khi đặt/đóng lệnh lỗi
input int    InpMaxConsecErrors   = 5;         // Lỗi liên tiếp tối đa trước khi tạm khóa tới nến sau

input group "2. Tín hiệu lệnh đầu (CHƯA KIỂM CHỨNG với Passview)"
input ENUM_PVR_ENTRY  InpEntryMode       = PVR_ENTRY_EMA_SIDE; // Chế độ tín hiệu lệnh đầu
input ENUM_TIMEFRAMES InpSignalTF        = PERIOD_M5;          // Khung tín hiệu (chỉ dùng nến đã đóng)
input int             InpEmaPeriod       = 50;                 // Chu kỳ EMA
input int             InpRsiPeriod       = 14;                 // Chu kỳ RSI
input double          InpRsiBuyBelow     = 30.0;               // RSI ≤ mức này → BUY
input double          InpRsiSellAbove    = 70.0;               // RSI ≥ mức này → SELL
input int             InpCooldownSeconds = 0;                  // Chờ sau khi đóng basket (giây)

input group "3. Thêm leg DCA (CHƯA KIỂM CHỨNG)"
input ENUM_PVR_STEP   InpStepMode          = PVR_STEP_PRICE; // Cách tính khoảng cách DCA
input double          InpStepPrice         = 3.0;            // Khoảng cách giá (XAUUSD: 1.0 = 1 USD)
input double          InpStepATRMult       = 1.0;            // Bội số ATR cho khoảng cách
input ENUM_TIMEFRAMES InpATRTF             = PERIOD_M5;      // Khung ATR
input int             InpATRPeriod         = 14;             // Chu kỳ ATR
input double          InpStepGrowth        = 1.0;            // Hệ số nới khoảng cách mỗi leg (1 = cố định)
input bool            InpAddOnBarCloseOnly = false;          // Chỉ thêm leg khi có nến mới của khung tín hiệu

input group "4. Khối lượng (CHƯA KIỂM CHỨNG)"
input double InpStartLot      = 0.01;  // Lot lệnh đầu
input double InpLotMultiplier = 1.5;   // Hệ số nhân lot mỗi leg
input double InpLotAdd        = 0.0;   // Cộng thêm lot mỗi leg
input int    InpMaxLegs       = 6;     // Số leg tối đa mỗi basket
input double InpMaxLotPerLeg  = 0.20;  // Lot tối đa một leg
input double InpMaxTotalLots  = 0.50;  // Tổng lot tối đa mỗi basket

input group "5. Đóng basket (CHƯA KIỂM CHỨNG)"
input ENUM_PVR_TP InpTPMode          = PVR_TP_PRICE; // Cách chốt lời basket
input double      InpTPPrice          = 1.5;         // Khoảng cách chốt từ giá trung bình (giá)
input double      InpTPATRMult        = 0.5;         // Bội số ATR chốt từ giá trung bình
input double      InpTPMoney          = 5.0;         // Lãi ròng mục tiêu (tiền tài khoản)
input double      InpTPMoneyPerLot    = 0.0;         // Cộng thêm mục tiêu cho mỗi 1.0 lot
input bool        InpSetServerTP      = true;        // Đặt TP trên server cho mọi leg (chế độ giá/ATR)
input double      InpBasketSLMoney    = 0.0;         // Cắt basket khi lỗ ròng ≥ số tiền (0 = tắt)
input int         InpMaxBasketHours   = 0;           // Đóng basket sau N giờ (0 = tắt)
input double      InpCommissionPerLot = 0.0;         // Hoa hồng ước tính mỗi 1.0 lot, khứ hồi

input group "6. Bộ lọc và giới hạn rủi ro"
input bool   InpAllowHedge       = false; // Cho phép basket BUY và SELL cùng lúc
input double InpMaxSpreadPrice   = 0.50;  // Spread tối đa để mở/thêm lệnh (giá, 0 = tắt)
input bool   InpUseSession       = false; // Chỉ mở lệnh đầu trong khung giờ
input int    InpSessionStartHour = 1;     // Giờ bắt đầu (giờ server)
input int    InpSessionEndHour   = 22;    // Giờ kết thúc (giờ server, không tính giờ này)
input double InpMaxDrawdownPct   = 30.0;  // Sụt giảm equity % balance → đóng mọi basket (0 = tắt)
input double InpMinMarginLevel   = 300.0; // Margin level tối thiểu sau khi vào lệnh (%, 0 = tắt)

input group "7. Nhật ký quyết định"
input bool   InpWriteLog        = true;   // Ghi log quyết định ra CSV
input bool   InpLogCommonFolder = true;   // Ghi vào thư mục Common\Files
input bool   InpLogSkips        = true;   // Ghi cả tín hiệu/leg bị bỏ qua

//====================================================================
// Trang thai
//====================================================================
struct Basket
  {
   bool     buy;
   int      n;
   double   lots;
   double   avg;
   double   floating;    // profit + swap cua cac vi the dang mo
   ulong    firstTicket; // dung lam ma basket
   datetime firstTime;
   double   firstPrice;
   double   lastPrice;
   double   lastLot;
   long     lastTimeMsc;
  };

CTrade   g_trade;
int      g_hEma = INVALID_HANDLE, g_hRsi = INVALID_HANDLE, g_hAtr = INVALID_HANDLE;
string   g_gv;
datetime g_lastSignalBar = 0;
bool     g_newSignalBar  = false;
datetime g_blockBar      = 0;     // khoa vao lenh moi trong nen nay sau loi lien tiep
int      g_consecErrors  = 0;
bool     g_closing[2];            // dang dong basket (0 = BUY, 1 = SELL)
string   g_closeReason[2];
int      g_prevN[2];
ulong    g_prevId[2];
datetime g_prevFirst[2];
double   g_pendStep[2], g_pendTp[2], g_pendAtr[2]; // tham so vua tinh luc mo lenh dau
int      g_syncN[2];
datetime g_syncTime[2];
string   g_skipKey[3];            // 0 = lenh dau, 1 = them leg BUY, 2 = them leg SELL
string   g_status = "";
int      g_statBaskets = 0, g_statMaxLegs = 0, g_statErrors = 0;
double   g_statMaxLots = 0, g_statMaxDDPct = 0;

//====================================================================
// Tien ich
//====================================================================
int    Idx(const bool buy)   { return buy ? 0 : 1; }
string DirS(const bool buy)  { return buy ? "BUY" : "SELL"; }
string Dk(const bool buy)    { return buy ? "B_" : "S_"; }

double GVGet(const string key, const double def)
  {
   string name = g_gv + key;
   return GlobalVariableCheck(name) ? GlobalVariableGet(name) : def;
  }
void GVPut(const string key, const double v) { GlobalVariableSet(g_gv + key, v); }
void GVDel(const string key)                 { GlobalVariableDel(g_gv + key); }

double Bid()    { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double Ask()    { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double Spread() { return Ask() - Bid(); }

bool ReadInd(const int handle, const int shift, double &v)
  {
   v = 0.0;
   if(handle == INVALID_HANDLE)
      return false;
   double buf[1];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
      return false;
   v = buf[0];
   return v != EMPTY_VALUE && MathIsValidNumber(v);
  }

double NormLot(double v)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0)
      step = 0.01;
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   v = MathRound(v / step) * step;
   if(v < mn)
      v = mn;
   if(mx > 0 && v > mx)
      v = mx;
   int d = (int)MathMax(0, MathRound(-MathLog10(step)));
   return NormalizeDouble(v, d);
  }

// lot cua leg thu k (k = 0 la lenh dau)
double LegLot(const int k)
  {
   double v = InpStartLot * MathPow(InpLotMultiplier, k) + InpLotAdd * k;
   if(InpMaxLotPerLeg > 0)
      v = MathMin(v, InpMaxLotPerLeg);
   return NormLot(v);
  }

double DrawdownPct()
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0)
      return 0.0;
   return MathMax(0.0, (bal - AccountInfoDouble(ACCOUNT_EQUITY)) / bal * 100.0);
  }

bool InSession()
  {
   if(!InpUseSession || InpSessionStartHour == InpSessionEndHour)
      return true;
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(InpSessionStartHour < InpSessionEndHour)
      return t.hour >= InpSessionStartHour && t.hour < InpSessionEndHour;
   return t.hour >= InpSessionStartHour || t.hour < InpSessionEndHour;
  }

string Clean(string s)
  {
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }

//====================================================================
// Doc basket tu vi the dang mo (nguon su that duy nhat -> tu khoi phuc)
//====================================================================
void ReadBasket(const bool buy, Basket &b)
  {
   b.buy = buy; b.n = 0; b.lots = 0; b.avg = 0; b.floating = 0;
   b.firstTicket = 0; b.firstTime = 0; b.firstPrice = 0;
   b.lastPrice = 0; b.lastLot = 0; b.lastTimeMsc = 0;
   long firstMsc = 0;
   double pv = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != buy)
         continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double px  = PositionGetDouble(POSITION_PRICE_OPEN);
      long   msc = PositionGetInteger(POSITION_TIME_MSC);
      b.n++;
      b.lots += vol;
      pv += vol * px;
      b.floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(b.firstTicket == 0 || msc < firstMsc)
        {
         firstMsc      = msc;
         b.firstTicket = tk;
         b.firstTime   = (datetime)PositionGetInteger(POSITION_TIME);
         b.firstPrice  = px;
        }
      if(msc >= b.lastTimeMsc)
        {
         b.lastTimeMsc = msc;
         b.lastPrice   = px;
         b.lastLot     = vol;
        }
     }
   if(b.lots > 0)
      b.avg = pv / b.lots;
  }

double NetProfit(const Basket &b) { return b.floating - InpCommissionPerLot * b.lots; }

int CountLegs(const bool buy)
  {
   Basket b;
   ReadBasket(buy, b);
   return b.n;
  }

//====================================================================
// Nhat ky quyet dinh (ASCII de doc bang Excel/Python khong loi font)
//====================================================================
string LogName()
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   return StringFormat("PassviewDCA_%s_%I64d_%04d_%02d.csv", _Symbol, InpMagic, t.year, t.mon);
  }

void LogRow(const string ev, const string dir, const Basket &b, const double lot, const double price,
            const string reason, const uint retcode = 0)
  {
   if(!InpWriteLog)
      return;
   int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
   if(InpLogCommonFolder)
      flags |= FILE_COMMON;
   int h = FileOpen(LogName(), flags);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[PVR] Khong mo duoc file log %s, loi %d", LogName(), GetLastError());
      return;
     }
   if(FileSize(h) == 0)
      FileWriteString(h, "time,time_msc,event,dir,basket_id,legs,lot,price,bid,ask,spread,lots_total,avg_price,"
                         "net_float,balance,equity,margin_level,dd_pct,atr,ema,rsi,signal_bar,version,retcode,reason\r\n");
   FileSeek(h, 0, SEEK_END);
   double atr, ema, rsi;
   ReadInd(g_hAtr, 1, atr);
   ReadInd(g_hEma, 1, ema);
   ReadInd(g_hRsi, 1, rsi);
   MqlTick tk;
   long msc = SymbolInfoTick(_Symbol, tk) ? tk.time_msc : (long)TimeCurrent() * 1000;
   int dg = _Digits;
   string line = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "," + IntegerToString(msc) + "," +
                 ev + "," + dir + "," + IntegerToString((long)b.firstTicket) + "," + IntegerToString(b.n) + "," +
                 DoubleToString(lot, 2) + "," + DoubleToString(price, dg) + "," +
                 DoubleToString(Bid(), dg) + "," + DoubleToString(Ask(), dg) + "," + DoubleToString(Spread(), dg) + "," +
                 DoubleToString(b.lots, 2) + "," + DoubleToString(b.avg, dg) + "," + DoubleToString(NetProfit(b), 2) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 1) + "," + DoubleToString(DrawdownPct(), 2) + "," +
                 DoubleToString(atr, dg) + "," + DoubleToString(ema, dg) + "," + DoubleToString(rsi, 2) + "," +
                 TimeToString(iTime(_Symbol, InpSignalTF, 1), TIME_DATE | TIME_MINUTES) + "," + EA_VERSION + "," +
                 IntegerToString(retcode) + "," + Clean(reason);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
  }

// ghi SKIP mot lan cho moi khoa (tranh ghi lap moi tick)
void LogSkip(const int channel, const string key, const string dir, const Basket &b, const string reason)
  {
   if(!InpLogSkips || g_skipKey[channel] == key)
      return;
   g_skipKey[channel] = key;
   LogRow("SKIP", dir, b, 0, 0, reason);
  }

//====================================================================
// Thuc thi lenh
//====================================================================
bool IsRetryable(const uint rc)
  {
   return rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF ||
          rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_TOO_MANY_REQUESTS ||
          rc == TRADE_RETCODE_LOCKED || rc == TRADE_RETCODE_ERROR;
  }

bool IsUnknownOutcome(const uint rc) { return rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION; }

bool IsFatal(const uint rc)
  {
   return rc == TRADE_RETCODE_NO_MONEY || rc == TRADE_RETCODE_TRADE_DISABLED || rc == TRADE_RETCODE_MARKET_CLOSED ||
          rc == TRADE_RETCODE_INVALID_VOLUME || rc == TRADE_RETCODE_LIMIT_VOLUME || rc == TRADE_RETCODE_LIMIT_POSITIONS ||
          rc == TRADE_RETCODE_CLIENT_DISABLES_AT || rc == TRADE_RETCODE_SERVER_DISABLES_AT;
  }

void RegisterError(const uint rc)
  {
   g_consecErrors++;
   g_statErrors++;
   if(g_consecErrors >= InpMaxConsecErrors || IsFatal(rc))
     {
      g_blockBar = iTime(_Symbol, InpSignalTF, 0);
      g_status = StringFormat("Tạm khóa lệnh mới tới nến sau (lỗi %u)", rc);
     }
  }

bool Blocked() { return g_blockBar != 0 && g_blockBar == iTime(_Symbol, InpSignalTF, 0); }

// gui lenh thi truong; tra ve true khi co vi the moi (ke ca ket qua chua ro nhung vi the da xuat hien)
bool SendMarket(const bool buy, const double lot, const string cmt, double &fill, uint &rc)
  {
   fill = 0;
   rc = 0;
   int before = CountLegs(buy);
   for(int a = 0; a < MathMax(1, InpMaxRetries); a++)
     {
      ResetLastError();
      bool ok = buy ? g_trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, cmt) : g_trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, cmt);
      rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
        {
         fill = g_trade.ResultPrice();
         if(fill <= 0)
            fill = buy ? Ask() : Bid();
         g_consecErrors = 0;
         return true;
        }
      if(IsUnknownOutcome(rc))
        {
         Sleep(500);
         if(CountLegs(buy) > before)   // lenh da khop du bao loi -> khong gui lai de tranh trung
           {
            fill = buy ? Ask() : Bid();
            g_consecErrors = 0;
            return true;
           }
        }
      if(!IsRetryable(rc))
         break;
      Sleep(300);
     }
   RegisterError(rc);
   return false;
  }

// dong moi vi the cua basket; tra ve true khi khong con vi the nao
bool CloseBasket(const bool buy)
  {
   bool allOk = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != buy)
         continue;
      bool done = false;
      uint rc = 0;
      for(int a = 0; a < MathMax(1, InpMaxRetries) && !done; a++)
        {
         done = g_trade.PositionClose(tk, InpSlippagePoints);
         rc = g_trade.ResultRetcode();
         done = done && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED);
         if(!done && !IsRetryable(rc))
            break;
         if(!done)
            Sleep(300);
        }
      if(!done)
        {
         allOk = false;
         g_statErrors++;
         Basket b;
         ReadBasket(buy, b);
         LogRow("ERROR", DirS(buy), b, PositionSelectByTicket(tk) ? PositionGetDouble(POSITION_VOLUME) : 0, 0,
                StringFormat("CLOSE_FAILED ticket=%I64u %s", tk, g_trade.ResultRetcodeDescription()), rc);
        }
     }
   return allOk && CountLegs(buy) == 0;
  }

bool MarginOK(const bool buy, const double lot, string &why)
  {
   double price = buy ? Ask() : Bid();
   double m = 0;
   if(!OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, m))
     {
      why = "MARGIN_CALC_FAILED";
      return false;
     }
   double eq = AccountInfoDouble(ACCOUNT_EQUITY), used = AccountInfoDouble(ACCOUNT_MARGIN);
   if(eq - used - m <= 0)
     {
      why = StringFormat("NO_FREE_MARGIN need=%.2f free=%.2f", m, eq - used);
      return false;
     }
   if(InpMinMarginLevel > 0 && used + m > 0)
     {
      double lvl = eq / (used + m) * 100.0;
      if(lvl < InpMinMarginLevel)
        {
         why = StringFormat("MARGIN_LEVEL_AFTER %.0f < %.0f", lvl, InpMinMarginLevel);
         return false;
        }
     }
   return true;
  }

//====================================================================
// Tham so co dinh cua basket (luu GlobalVariable, khoi phuc duoc)
//====================================================================
bool CalcParams(double &step, double &tpd, double &atr)
  {
   step = InpStepPrice;
   tpd  = InpTPPrice;
   atr  = 0;
   bool needAtr = (InpStepMode == PVR_STEP_ATR || InpTPMode == PVR_TP_ATR);
   if(needAtr && (!ReadInd(g_hAtr, 1, atr) || atr <= 0))
      return false;
   if(InpStepMode == PVR_STEP_ATR)
      step = InpStepATRMult * atr;
   if(InpTPMode == PVR_TP_ATR)
      tpd = InpTPATRMult * atr;
   if(InpTPMode == PVR_TP_MONEY)
      tpd = 0;
   return step > 0;
  }

// dam bao basket co tham so; tra ve false neu chua tinh duoc (thieu du lieu ATR)
bool EnsureParams(const Basket &b, double &step, double &tpd)
  {
   const bool buy = b.buy;
   const int k = Idx(buy);
   if((ulong)GVGet(Dk(buy) + "id", 0) == b.firstTicket && GVGet(Dk(buy) + "step", 0) > 0)
     {
      step = GVGet(Dk(buy) + "step", 0);
      tpd  = GVGet(Dk(buy) + "tp", 0);
      return true;
     }
   double atr = 0;
   bool fresh = g_pendStep[k] > 0;
   if(fresh)
     {
      step = g_pendStep[k];
      tpd  = g_pendTp[k];
      atr  = g_pendAtr[k];
     }
   else if(!CalcParams(step, tpd, atr))
      return false;
   GVPut(Dk(buy) + "id", (double)b.firstTicket);
   GVPut(Dk(buy) + "step", step);
   GVPut(Dk(buy) + "tp", tpd);
   GVPut(Dk(buy) + "atr", atr);
   g_pendStep[k] = 0;
   if(!fresh)
     {
      LogRow("RECOVER_PARAMS", DirS(buy), b, 0, 0,
             StringFormat("params recomputed from current data step=%.5f tp=%.5f atr=%.5f", step, tpd, atr));
      PrintFormat("[PVR] Basket %s #%I64u: không có tham số đã lưu, tính lại từ dữ liệu hiện tại (bước %.2f, TP %.2f)",
                  DirS(buy), b.firstTicket, step, tpd);
     }
   return true;
  }

void SyncServerTP(const Basket &b, const double tpd)
  {
   if(!InpSetServerTP || InpTPMode == PVR_TP_MONEY || tpd <= 0 || b.n == 0)
      return;
   const int k = Idx(b.buy);
   if(b.n == g_syncN[k] && TimeCurrent() - g_syncTime[k] < 60)
      return;
   g_syncN[k] = b.n;
   g_syncTime[k] = TimeCurrent();
   double tp = NormalizeDouble(b.buy ? b.avg + tpd : b.avg - tpd, _Digits);
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(b.buy ? (tp <= Bid() + minDist) : (tp >= Ask() - minDist))
      return;   // qua sat gia: de phan dong basket trong EA xu ly
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) != b.buy)
         continue;
      if(MathAbs(PositionGetDouble(POSITION_TP) - tp) < _Point)
         continue;
      if(!g_trade.PositionModify(tk, PositionGetDouble(POSITION_SL), tp))
        {
         g_statErrors++;
         LogRow("ERROR", DirS(b.buy), b, 0, tp,
                StringFormat("MODIFY_TP_FAILED ticket=%I64u %s", tk, g_trade.ResultRetcodeDescription()),
                g_trade.ResultRetcode());
         g_syncTime[k] = 0;   // thu lai o tick sau
         g_syncN[k] = -1;
        }
     }
  }

//====================================================================
// Quyet dinh
//====================================================================
// +1 BUY, -1 SELL, 0 khong co tin hieu; chi dung nen da dong (shift 1)
int Signal(string &why)
  {
   double c1 = iClose(_Symbol, InpSignalTF, 1), o1 = iOpen(_Symbol, InpSignalTF, 1);
   double ema, rsi;
   switch(InpEntryMode)
     {
      case PVR_ENTRY_BUY_ONLY:
         why = "BUY_ONLY";
         return 1;
      case PVR_ENTRY_SELL_ONLY:
         why = "SELL_ONLY";
         return -1;
      case PVR_ENTRY_EMA_SIDE:
         if(!ReadInd(g_hEma, 1, ema) || c1 <= 0)
           {
            why = "NO_DATA_EMA";
            return 0;
           }
         why = StringFormat("close1=%.5f ema=%.5f", c1, ema);
         return c1 > ema ? 1 : (c1 < ema ? -1 : 0);
      case PVR_ENTRY_RSI:
         if(!ReadInd(g_hRsi, 1, rsi))
           {
            why = "NO_DATA_RSI";
            return 0;
           }
         why = StringFormat("rsi1=%.2f", rsi);
         return rsi <= InpRsiBuyBelow ? 1 : (rsi >= InpRsiSellAbove ? -1 : 0);
      case PVR_ENTRY_CANDLE:
         if(c1 <= 0 || o1 <= 0)
           {
            why = "NO_DATA_BAR";
            return 0;
           }
         why = StringFormat("open1=%.5f close1=%.5f", o1, c1);
         return c1 > o1 ? 1 : (c1 < o1 ? -1 : 0);
      default:
         why = "ENTRY_OFF";
         return 0;
     }
  }

void TryOpenFirst()
  {
   if(InpEntryMode == PVR_ENTRY_OFF)
      return;
   Basket none;
   ReadBasket(true, none);   // chi de lay cau truc rong khi ghi log
   none.n = 0; none.lots = 0; none.avg = 0; none.floating = 0; none.firstTicket = 0;
   string barKey = TimeToString(iTime(_Symbol, InpSignalTF, 1));
   string why;
   int sig = Signal(why);
   if(sig == 0)
     {
      LogSkip(0, barKey + "nosig", "", none, "NO_SIGNAL " + why);
      return;
     }
   const bool buy = sig > 0;
   none.buy = buy;
   Basket same, opp;
   ReadBasket(buy, same);
   ReadBasket(!buy, opp);
   if(same.n > 0)
     {
      LogSkip(0, barKey + "same", DirS(buy), same, "BASKET_SAME_DIR_OPEN " + why);
      return;
     }
   if(opp.n > 0 && !InpAllowHedge)
     {
      LogSkip(0, barKey + "opp", DirS(buy), none, "OPPOSITE_BASKET_OPEN_NO_HEDGE " + why);
      return;
     }
   datetime lastClose = (datetime)(long)GVGet(Dk(buy) + "closed", 0);
   if(InpCooldownSeconds > 0 && TimeCurrent() - lastClose < InpCooldownSeconds)
     {
      LogSkip(0, barKey + "cd", DirS(buy), none, StringFormat("COOLDOWN %ds", (int)(TimeCurrent() - lastClose)));
      return;
     }
   if(!InSession())
     {
      LogSkip(0, barKey + "sess", DirS(buy), none, "OUT_OF_SESSION");
      return;
     }
   if(InpMaxSpreadPrice > 0 && Spread() > InpMaxSpreadPrice)
     {
      LogSkip(0, barKey + "spr", DirS(buy), none, StringFormat("SPREAD %.5f > %.5f", Spread(), InpMaxSpreadPrice));
      return;
     }
   if(InpMaxDrawdownPct > 0 && DrawdownPct() >= InpMaxDrawdownPct * 0.5)
     {
      LogSkip(0, barKey + "dd", DirS(buy), none, StringFormat("ACCOUNT_DD %.2f%% >= half limit", DrawdownPct()));
      return;
     }
   if(Blocked())
     {
      LogSkip(0, barKey + "blk", DirS(buy), none, "BLOCKED_AFTER_ERRORS");
      return;
     }
   double step, tpd, atr;
   if(!CalcParams(step, tpd, atr))
     {
      LogSkip(0, barKey + "atr", DirS(buy), none, "NO_DATA_ATR");
      return;
     }
   double lot = LegLot(0);
   string mwhy;
   if(!MarginOK(buy, lot, mwhy))
     {
      LogSkip(0, barKey + "mg", DirS(buy), none, mwhy);
      return;
     }
   const int k = Idx(buy);
   g_pendStep[k] = step;
   g_pendTp[k]   = tpd;
   g_pendAtr[k]  = atr;
   double fill;
   uint rc;
   string cmt = StringFormat("PVR|%s|L1", buy ? "B" : "S");
   if(!SendMarket(buy, lot, cmt, fill, rc))
     {
      g_pendStep[k] = 0;
      LogRow("ERROR", DirS(buy), none, lot, 0, "OPEN_FIRST_FAILED " + g_trade.ResultRetcodeDescription(), rc);
      return;
     }
   Basket b;
   ReadBasket(buy, b);
   double s2, t2;
   EnsureParams(b, s2, t2);
   LogRow("OPEN_FIRST", DirS(buy), b, lot, fill,
          StringFormat("%s step=%.5f tp=%.5f atr=%.5f", why, step, tpd, atr), rc);
   PrintFormat("[PVR] Mở basket %s %.2f lot @ %.5f | %s | bước %.2f | TP %.2f", DirS(buy), lot, fill, why, step, tpd);
  }

void TryAdd(Basket &b, const double step0)
  {
   const int ch = b.buy ? 1 : 2;
   string key = IntegerToString((long)b.firstTicket) + "_" + IntegerToString(b.n);
   double dist = step0 * MathPow(InpStepGrowth, b.n - 1);
   double trigger = b.buy ? b.lastPrice - dist : b.lastPrice + dist;
   bool hit = b.buy ? (Ask() <= trigger) : (Bid() >= trigger);
   if(!hit)
      return;
   if(b.n >= InpMaxLegs)
     {
      LogSkip(ch, key + "max", DirS(b.buy), b, StringFormat("MAX_LEGS %d", InpMaxLegs));
      return;
     }
   if(InpAddOnBarCloseOnly && !g_newSignalBar)
      return;
   double lot = LegLot(b.n);
   if(InpMaxTotalLots > 0 && b.lots + lot > InpMaxTotalLots + 1e-9)
     {
      LogSkip(ch, key + "lots", DirS(b.buy), b, StringFormat("MAX_TOTAL_LOTS %.2f+%.2f>%.2f", b.lots, lot, InpMaxTotalLots));
      return;
     }
   if(InpMaxSpreadPrice > 0 && Spread() > InpMaxSpreadPrice)
     {
      LogSkip(ch, key + "spr", DirS(b.buy), b, StringFormat("SPREAD %.5f > %.5f", Spread(), InpMaxSpreadPrice));
      return;
     }
   if(Blocked())
     {
      LogSkip(ch, key + "blk", DirS(b.buy), b, "BLOCKED_AFTER_ERRORS");
      return;
     }
   string mwhy;
   if(!MarginOK(b.buy, lot, mwhy))
     {
      LogSkip(ch, key + "mg", DirS(b.buy), b, mwhy);
      return;
     }
   double fill;
   uint rc;
   string cmt = StringFormat("PVR|%s|L%d", b.buy ? "B" : "S", b.n + 1);
   if(!SendMarket(b.buy, lot, cmt, fill, rc))
     {
      LogRow("ERROR", DirS(b.buy), b, lot, 0, "ADD_LEG_FAILED " + g_trade.ResultRetcodeDescription(), rc);
      return;
     }
   double lastPx = b.lastPrice;
   ReadBasket(b.buy, b);
   LogRow("ADD_LEG", DirS(b.buy), b, lot, fill,
          StringFormat("leg=%d dist=%.5f trigger=%.5f prev_leg=%.5f moved=%.5f", b.n, dist, trigger, lastPx,
                       MathAbs(fill - lastPx)), rc);
   PrintFormat("[PVR] Thêm leg %d %s %.2f lot @ %.5f (cách leg trước %.2f)", b.n, DirS(b.buy), lot, fill, MathAbs(fill - lastPx));
  }

string ExitReason(const Basket &b, const double tpd)
  {
   double net = NetProfit(b);
   if(InpTPMode == PVR_TP_MONEY)
     {
      double target = InpTPMoney + InpTPMoneyPerLot * b.lots;
      if(net >= target)
         return StringFormat("TP_MONEY net=%.2f target=%.2f", net, target);
     }
   else if(tpd > 0)
     {
      if(b.buy && Bid() >= b.avg + tpd)
         return StringFormat("TP_AVG bid=%.5f avg=%.5f tp_dist=%.5f", Bid(), b.avg, tpd);
      if(!b.buy && Ask() <= b.avg - tpd)
         return StringFormat("TP_AVG ask=%.5f avg=%.5f tp_dist=%.5f", Ask(), b.avg, tpd);
     }
   if(InpBasketSLMoney > 0 && net <= -InpBasketSLMoney)
      return StringFormat("SL_MONEY net=%.2f", net);
   if(InpMaxBasketHours > 0 && TimeCurrent() - b.firstTime >= (long)InpMaxBasketHours * 3600)
      return StringFormat("TIME_STOP %dh", InpMaxBasketHours);
   return "";
  }

void RequestClose(const bool buy, const Basket &b, const string reason)
  {
   const int k = Idx(buy);
   if(!g_closing[k])
     {
      g_closing[k] = true;
      g_closeReason[k] = reason;
      LogRow("CLOSE_REQUEST", DirS(buy), b, b.lots, buy ? Bid() : Ask(), reason);
     }
   CloseBasket(buy);
  }

// basket vua het vi the: ghi ket qua thuc te tu lich su deal
void OnBasketGone(const bool buy, const ulong id, const datetime first, const string how)
  {
   const int k = Idx(buy);
   double pnl = 0;
   int legs = 0, outs = 0;
   string lastReason = "";
   double lastPrice = 0;
   if(first > 0 && HistorySelect(first - 1, TimeCurrent() + 60))
     {
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
            continue;
         long type = HistoryDealGetInteger(d, DEAL_TYPE);
         long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
         bool inLeg  = entry == DEAL_ENTRY_IN && ((type == DEAL_TYPE_BUY) == buy);
         bool outLeg = (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) && ((type == DEAL_TYPE_SELL) == buy);
         if(!inLeg && !outLeg)
            continue;
         pnl += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
         if(inLeg)
            legs++;
         else
           {
            outs++;
            lastPrice = HistoryDealGetDouble(d, DEAL_PRICE);
            lastReason = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(d, DEAL_REASON));
           }
        }
     }
   Basket b;
   ReadBasket(buy, b);
   b.firstTicket = id;
   LogRow("BASKET_CLOSED", DirS(buy), b, 0, lastPrice,
          StringFormat("%s legs=%d outs=%d pnl=%.2f deal_reason=%s req=%s", how, legs, outs, pnl, lastReason,
                       g_closing[k] ? g_closeReason[k] : "none"));
   PrintFormat("[PVR] Đóng basket %s #%I64u: %d leg, P/L %.2f (%s)", DirS(buy), id, legs, pnl, lastReason);
   g_statBaskets++;
   GVPut(Dk(buy) + "closed", (double)TimeCurrent());
   GVDel(Dk(buy) + "id");
   GVDel(Dk(buy) + "step");
   GVDel(Dk(buy) + "tp");
   GVDel(Dk(buy) + "atr");
   g_closing[k] = false;
   g_closeReason[k] = "";
   g_syncN[k] = -1;
  }

void ManageSide(const bool buy)
  {
   const int k = Idx(buy);
   Basket b;
   ReadBasket(buy, b);
   if(b.n == 0)
     {
      if(g_prevN[k] > 0)
         OnBasketGone(buy, g_prevId[k], g_prevFirst[k], "LIVE");
      g_prevN[k] = 0;
      return;
     }
   g_prevN[k]     = b.n;
   g_prevId[k]    = b.firstTicket;
   g_prevFirst[k] = b.firstTime;
   g_statMaxLegs  = MathMax(g_statMaxLegs, b.n);
   g_statMaxLots  = MathMax(g_statMaxLots, b.lots);

   if(g_closing[k])
     {
      CloseBasket(buy);
      return;
     }
   double step = 0, tpd = 0;
   bool haveParams = EnsureParams(b, step, tpd);
   string why = ExitReason(b, haveParams ? tpd : 0);
   if(why != "")
     {
      RequestClose(buy, b, why);
      return;
     }
   if(!haveParams)
      return;
   SyncServerTP(b, tpd);
   TryAdd(b, step);
   ReadBasket(buy, b);
   SyncServerTP(b, tpd);
  }

//====================================================================
// Su kien chuan
//====================================================================
int OnInit()
  {
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      string m = (mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) ? "NETTING" : "EXCHANGE";
      Alert("Passview DCA ", EA_VERSION, ": tài khoản ", m,
            " KHÔNG được hỗ trợ. EA cần tài khoản HEDGING để giữ nhiều leg cùng chiều như bot DCA.");
      return INIT_FAILED;
     }
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   bool demo   = AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO;
   if(!tester && !demo && !InpAllowRealAccount)
     {
      Alert("Passview DCA: đây là tài khoản THẬT. Bật 'Cho phép chạy tài khoản THẬT' nếu chắc chắn.");
      return INIT_FAILED;
     }
   if(InpStartLot <= 0 || InpLotMultiplier <= 0 || InpMaxLegs < 1 || InpStepGrowth <= 0 ||
      (InpStepMode == PVR_STEP_PRICE && InpStepPrice <= 0) || (InpStepMode == PVR_STEP_ATR && InpStepATRMult <= 0) ||
      (InpTPMode == PVR_TP_PRICE && InpTPPrice <= 0) || (InpTPMode == PVR_TP_ATR && InpTPATRMult <= 0) ||
      InpSessionStartHour < 0 || InpSessionStartHour > 23 || InpSessionEndHour < 0 || InpSessionEndHour > 23)
     {
      Print("[PVR] Tham số không hợp lệ (lot, số leg, bước, TP hoặc giờ phiên).");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_hEma = iMA(_Symbol, InpSignalTF, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_hRsi = iRSI(_Symbol, InpSignalTF, InpRsiPeriod, PRICE_CLOSE);
   g_hAtr = iATR(_Symbol, InpATRTF, InpATRPeriod);
   if(g_hEma == INVALID_HANDLE || g_hRsi == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
     {
      Print("[PVR] Không tạo được chỉ báo.");
      return INIT_FAILED;
     }
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);
   g_gv = StringFormat("PVR_%s_%I64d_", _Symbol, InpMagic);

   g_consecErrors = 0;
   g_blockBar = 0;
   for(int i = 0; i < 3; i++)
      g_skipKey[i] = "";
   // khong vao lenh dau o nen dang chay luc gan EA / doi timeframe
   g_lastSignalBar = iTime(_Symbol, InpSignalTF, 0);

   //--- khoi phuc: vi the dang mo la nguon su that; tham so lay tu GlobalVariable neu con
   for(int s = 0; s < 2; s++)
     {
      bool buy = (s == 0);
      g_closing[s] = false;
      g_closeReason[s] = "";
      g_pendStep[s] = 0;
      g_syncN[s] = -1;
      g_syncTime[s] = 0;
      Basket b;
      ReadBasket(buy, b);
      ulong savedId = (ulong)GVGet(Dk(buy) + "id", 0);
      if(b.n > 0)
        {
         g_prevN[s] = b.n;
         g_prevId[s] = b.firstTicket;
         g_prevFirst[s] = b.firstTime;
         LogRow("RECOVER", DirS(buy), b, 0, b.avg,
                StringFormat("found open basket legs=%d saved_params=%s", b.n, savedId == b.firstTicket ? "yes" : "no"));
         PrintFormat("[PVR] Khôi phục basket %s: %d leg, %.2f lot, giá TB %.5f", DirS(buy), b.n, b.lots, b.avg);
        }
      else
        {
         g_prevN[s] = 0;
         g_prevId[s] = 0;
         g_prevFirst[s] = 0;
         if(savedId > 0)   // basket da dong trong luc EA khong chay
           {
            datetime first = 0;
            if(HistorySelectByPosition(savedId) && HistoryDealsTotal() > 0)
               first = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(0), DEAL_TIME);
            OnBasketGone(buy, savedId, first, "WHILE_EA_OFFLINE");
           }
        }
     }
   PrintFormat("[PVR] %s khởi động %s | %s | tín hiệu %s | lot: %.2f %.2f %.2f %.2f ... | tối đa %d leg",
               EA_VERSION, _Symbol, tester ? "TESTER" : (demo ? "DEMO" : "THẬT"), EnumToString(InpEntryMode),
               LegLot(0), LegLot(1), LegLot(2), LegLot(3), InpMaxLegs);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   // KHONG xoa GlobalVariable: can cho khoi phuc khi doi timeframe / khoi dong lai
   PrintFormat("[PVR Summary] basket đã đóng %d | leg lớn nhất %d | tổng lot lớn nhất %.2f | DD lớn nhất %.2f%% | lỗi %d",
               g_statBaskets, g_statMaxLegs, g_statMaxLots, g_statMaxDDPct, g_statErrors);
   IndicatorRelease(g_hEma);
   IndicatorRelease(g_hRsi);
   IndicatorRelease(g_hAtr);
   Comment("");
  }

void OnTick()
  {
   datetime bar = iTime(_Symbol, InpSignalTF, 0);
   g_newSignalBar = (bar != 0 && bar != g_lastSignalBar);
   if(g_newSignalBar && !Blocked())
      g_consecErrors = 0;

   //--- gioi han sut giam toan tai khoan
   double dd = DrawdownPct();
   g_statMaxDDPct = MathMax(g_statMaxDDPct, dd);
   if(InpMaxDrawdownPct > 0 && dd >= InpMaxDrawdownPct)
     {
      for(int s = 0; s < 2; s++)
        {
         Basket b;
         ReadBasket(s == 0, b);
         if(b.n > 0)
            RequestClose(s == 0, b, StringFormat("MAX_DRAWDOWN %.2f%% >= %.2f%%", dd, InpMaxDrawdownPct));
        }
     }

   ManageSide(true);
   ManageSide(false);

   if(g_newSignalBar)
     {
      g_lastSignalBar = bar;
      TryOpenFirst();
     }

   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
     {
      string txt = StringFormat("Passview DCA %s | %s | Magic %I64d\nSpread %.2f | DD %.2f%% | Lỗi %d\n",
                                EA_VERSION, _Symbol, InpMagic, Spread(), dd, g_statErrors);
      for(int s = 0; s < 2; s++)
        {
         Basket b;
         ReadBasket(s == 0, b);
         if(b.n > 0)
            txt += StringFormat("%s: %d leg | %.2f lot | TB %.2f | lãi ròng %.2f\n",
                                DirS(s == 0), b.n, b.lots, b.avg, NetProfit(b));
        }
      Comment(txt + g_status);
     }
  }

double OnTester()
  {
   PrintFormat("[PVR Tester] basket %d | leg lớn nhất %d | tổng lot lớn nhất %.2f | DD equity lớn nhất %.2f%%",
               g_statBaskets, g_statMaxLegs, g_statMaxLots, g_statMaxDDPct);
   return 0.0;
  }
//+------------------------------------------------------------------+
