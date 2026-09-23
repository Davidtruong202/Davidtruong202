//+------------------------------------------------------------------+
//|                                  GoldBot_SessionBreakout.mq5     |
//|  Session Breakout for XAUUSD M5 - MQL5 twin of the Python bot    |
//|  (backtest/goldbot/strategies/breakout.py + engine.py).          |
//|                                                                  |
//|  1. Range   : high/low of the Asian session (19:00-02:00 NY).    |
//|  2. Filter  : range height 1-5 x ATR(H1).                        |
//|  3. Signal  : 02:00-11:00 NY, an M5 bar CLOSES beyond the range  |
//|               (+buffer), previous close still inside, real body. |
//|  4. Trend   : longs above a rising H1 EMA50, shorts below a      |
//|               falling one.                                       |
//|  5. Stop    : range middle, clamped 1.5-5 x ATR(M5).             |
//|  6. Exits   : 50% at 1R + breakeven, rest at 2R, trailing 3 ATR, |
//|               everything flat at 15:00 NY.                       |
//|  Decisions happen on the first tick of each new M5 bar using the |
//|  bar that just closed - the same moment the Python backtest uses.|
//|  Every deal is logged to Common\Files\GoldBot_<sym>_<magic>.csv  |
//|  so backtest/compare_ea.py can check the EA against Python.      |
//+------------------------------------------------------------------+
#property copyright "Gold Bot"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs (names match config.json -> strategy_params / risk)
//====================================================================
input group "=== Gio server -> New York ==="
input bool   InpBrokerEUDST          = true;  // HFM: server GMT+2/+3 doi gio theo lich chau Au
input bool   InpBrokerFixedNYOffset  = true;  // dung khi InpBrokerEUDST = false
input double InpServerToNYHours      = 7.0;
input double InpServerGMTOffsetHours = 0.0;   // dung khi InpBrokerFixedNYOffset = false
input double InpDayStartNY           = 17.0;  // ngay giao dich vang bat dau 17:00 NY

input group "=== Phien (gio New York) ==="
input double InpRangeStart = 19.0;
input double InpRangeEnd   = 2.0;
input double InpTradeStart = 2.0;
input double InpTradeEnd   = 11.0;
input double InpFlatHour   = 15.0;

input group "=== Bo loc ==="
input int    InpATRPeriod      = 14;
input int    InpH1ATRPeriod    = 14;
input double InpMinRangeH1ATR  = 1.0;
input double InpMaxRangeH1ATR  = 5.0;
input double InpBufferATR      = 0.1;
input double InpMinBody        = 0.5;
input bool   InpUseTrend       = true;
input int    InpTrendEMA       = 50;
input int    InpTrendSlopeBars = 3;

input group "=== Quan ly lenh ==="
input double InpMinSLATR          = 1.5;
input double InpMaxSLATR          = 5.0;
input double InpTP_R              = 2.0;
input double InpTP1_R             = 1.0;
input double InpTP1Frac           = 0.5;
input double InpTrailATR          = 3.0;
input int    InpMaxTradesPerDay   = 2;

input group "=== Rui ro ==="
input double InpRiskPercent         = 0.5;
input double InpMaxDailyLossPercent = 2.0;
input int    InpMaxConsecLosses     = 3;
input double InpMaxSpreadPoints     = 60;

input group "=== He thong ==="
input long   InpMagic             = 26092301;
input int    InpDeviationPoints   = 30;
input bool   InpAllowRealAccount  = false; // an toan: chi chay demo neu false
input bool   InpDrawRange         = true;
input bool   InpWriteTradeLog     = true;

//====================================================================
// Globals
//====================================================================
int      hATR = INVALID_HANDLE, hH1ATR = INVALID_HANDLE, hEMA = INVALID_HANDLE;
datetime g_lastBar = 0;
int      g_rs, g_re, g_ts, g_te, g_fl;
string   g_gv;         // global-variable prefix for per-position state
string   g_status = "";
long     g_cntBreaks=0, g_cntRange=0, g_cntTrend=0, g_cntBody=0, g_cntSide=0, g_cntSpread=0, g_cntBlocked=0, g_cntEntries=0;

//====================================================================
// Time helpers (same maths as goldbot/common.py NYClock)
//====================================================================
datetime NthSundayOfMonth(int year, int month, int n)
{
   MqlDateTime dt;
   dt.year=year; dt.mon=month; dt.day=1; dt.hour=0; dt.min=0; dt.sec=0;
   datetime firstOfMonth = StructToTime(dt);
   MqlDateTime f;
   TimeToStruct(firstOfMonth, f);
   int daysToSunday = (7 - f.day_of_week) % 7;
   return firstOfMonth + (long)daysToSunday*86400 + (long)(n-1)*7*86400;
}

bool IsUSDST(datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   return (gmt >= NthSundayOfMonth(dt.year,3,2) && gmt < NthSundayOfMonth(dt.year,11,1));
}

datetime LastSundayOfMonth(int year, int month)
{
   MqlDateTime dt;
   dt.year = (month==12) ? year+1 : year; dt.mon = (month==12) ? 1 : month+1; dt.day=1;
   dt.hour=0; dt.min=0; dt.sec=0;
   datetime last = StructToTime(dt) - 86400;
   MqlDateTime l;
   TimeToStruct(last, l);
   return last - (datetime)(l.day_of_week*86400);   // day_of_week: 0 = Sunday
}

bool IsEUDST(datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   return (gmt >= LastSundayOfMonth(dt.year,3)+3600 && gmt < LastSundayOfMonth(dt.year,10)+3600);
}

long ToNY(datetime srv)
{
   if(InpBrokerEUDST)
   {
      long g = (long)srv - 2*3600;
      g = (long)srv - (IsEUDST((datetime)g) ? 3 : 2)*3600;
      return g - (IsUSDST((datetime)g) ? 4 : 5)*3600;
   }
   if(InpBrokerFixedNYOffset) return (long)srv - (long)(InpServerToNYHours*3600);
   long gmt = (long)srv - (long)(InpServerGMTOffsetHours*3600);
   return gmt - (IsUSDST((datetime)gmt) ? 4 : 5)*3600;
}

int PosMod(long a, long m) { long r = a % m; if(r<0) r+=m; return (int)r; }

// minutes since the trading-day start (17:00 NY)
int RelMin(datetime srv)
{
   long ny = ToNY(srv);
   return PosMod((long)(PosMod(ny,86400)/60) - (long)(InpDayStartNY*60), 1440);
}

int RelH(double hour) { return PosMod((long)MathRound((hour-InpDayStartNY)*60), 1440); }

long TradingDay(datetime srv)
{
   long x = ToNY(srv) - (long)(InpDayStartNY*3600);
   return (x>=0) ? x/86400 : -((-x+86399)/86400);
}

//====================================================================
// Indicator access
//====================================================================
double Buf(int h, int shift)
{
   double b[];
   if(CopyBuffer(h, 0, shift, 1, b) < 1) return 0;
   return b[0];
}

//====================================================================
// Position state (survives EA restarts via terminal global variables)
//====================================================================
string GVName(ulong ticket, string key) { return g_gv + (string)ticket + "_" + key; }
double GVGet(ulong ticket, string key, double def)
{
   string n = GVName(ticket,key);
   return GlobalVariableCheck(n) ? GlobalVariableGet(n) : def;
}
void GVSet(ulong ticket, string key, double v) { GlobalVariableSet(GVName(ticket,key), v); }

bool SelectMyPosition(ulong &ticket)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ticket = t;
      return true;
   }
   return false;
}

//====================================================================
// Day statistics from deal history (same rules as RiskGate)
//====================================================================
void DayStats(int &buys, int &sells, double &dayPnl, int &consec)
{
   buys=0; sells=0; dayPnl=0; consec=0;
   datetime now = TimeCurrent();
   long today = TradingDay(now);
   if(!HistorySelect(now - 4*86400, now + 86400)) return;

   ulong  posIds[];  double posPnl[];  datetime posTime[];
   int n = HistoryDealsTotal();
   for(int i=0; i<n; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d==0) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC)!=InpMagic) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL)!=_Symbol) continue;
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(TradingDay(t)!=today) continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry==DEAL_ENTRY_IN)
      {
         if(HistoryDealGetInteger(d, DEAL_TYPE)==DEAL_TYPE_BUY) buys++; else sells++;
         continue;
      }
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      double pnl = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP)
                 + HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      int k=-1;
      for(int j=0; j<ArraySize(posIds); j++) if(posIds[j]==pid) { k=j; break; }
      if(k<0)
      {
         k = ArraySize(posIds);
         ArrayResize(posIds,k+1); ArrayResize(posPnl,k+1); ArrayResize(posTime,k+1);
         posIds[k]=pid; posPnl[k]=0; posTime[k]=0;
      }
      posPnl[k] += pnl;
      if(t>posTime[k]) posTime[k]=t;
   }
   // ignore positions still open (partially closed)
   ulong openTicket=0;
   ulong openId=0;
   if(SelectMyPosition(openTicket)) openId=(ulong)PositionGetInteger(POSITION_IDENTIFIER);

   // closed positions in time order
   int m = ArraySize(posIds);
   bool used[]; ArrayResize(used, m);
   for(int j=0; j<m; j++) used[j]=false;
   for(int step=0; step<m; step++)
   {
      int best=-1;
      for(int j=0; j<m; j++)
         if(!used[j] && (best<0 || posTime[j]<posTime[best])) best=j;
      used[best]=true;
      if(posIds[best]==openId) continue;
      dayPnl += posPnl[best];
      if(posPnl[best]<0) consec++; else consec=0;
   }
}

string BlockedReason(double dayPnl, int consec)
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double startBal = bal - dayPnl;
   if(startBal>0 && -dayPnl >= startBal*InpMaxDailyLossPercent/100.0) return "daily_loss";
   if(InpMaxConsecLosses>0 && consec>=InpMaxConsecLosses) return "consec_losses";
   return "";
}

//====================================================================
// Sizing (same as goldbot.common.lot_size)
//====================================================================
double LotSize(double slDist)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0 || tickValue<=0 || slDist<=0) return 0;
   double lots = AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercent/100.0 / (slDist/tickSize*tickValue);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(step<=0) step=0.01;
   lots = MathFloor(lots/step + 1e-9)*step;
   lots = MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), lots));
   return NormalizeDouble(lots, 2);
}

//====================================================================
// Trade log for compare_ea.py
//====================================================================
void LogDeal(ulong deal)
{
   if(!InpWriteTradeLog) return;
   string fn = StringFormat("GoldBot_%s_%I64d.csv", _Symbol, InpMagic);
   int h = FileOpen(fn, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0)
      FileWrite(h, "time","position","entry","type","volume","price","profit","comment");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString((datetime)HistoryDealGetInteger(deal,DEAL_TIME), TIME_DATE|TIME_SECONDS),
             (string)HistoryDealGetInteger(deal,DEAL_POSITION_ID),
             HistoryDealGetInteger(deal,DEAL_ENTRY)==DEAL_ENTRY_IN ? "in" : "out",
             HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_BUY ? "buy" : "sell",
             DoubleToString(HistoryDealGetDouble(deal,DEAL_VOLUME),2),
             DoubleToString(HistoryDealGetDouble(deal,DEAL_PRICE),_Digits),
             DoubleToString(HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP),2),
             HistoryDealGetString(deal,DEAL_COMMENT));
   FileClose(h);
}

//====================================================================
// Intrabar: TP1 partial + breakeven on every tick
//====================================================================
void ManageTicks()
{
   ulong ticket;
   if(!SelectMyPosition(ticket)) return;
   if(GVGet(ticket,"tp1done",1)>0) return;
   double tp1 = GVGet(ticket,"tp1",0);
   if(tp1<=0) return;
   bool isBuy = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
   double px = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if((isBuy && px<tp1) || (!isBuy && px>tp1)) return;

   double vol  = PositionGetDouble(POSITION_VOLUME);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp   = PositionGetDouble(POSITION_TP);
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(step<=0) step=0.01;
   double cv   = NormalizeDouble(MathFloor(vol*InpTP1Frac/step + 1e-9)*step, 2);
   if(cv>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN) && cv<vol)
      trade.PositionClosePartial(ticket, cv);
   if(SelectMyPosition(ticket))
      trade.PositionModify(ticket, NormalizeDouble(open,_Digits), tp);
   GVSet(ticket,"tp1done",1);
}

//====================================================================
// Range of the trading day that contains bar shift 1
//====================================================================
bool DayRange(double &hi, double &lo)
{
   datetime t1 = iTime(_Symbol, PERIOD_M5, 1);
   long day = TradingDay(t1);
   bool found=false;
   for(int s=1; s<400; s++)
   {
      datetime t = iTime(_Symbol, PERIOD_M5, s);
      if(t==0 || TradingDay(t)!=day) break;
      int m = RelMin(t);
      if(m>=g_rs && m<g_re)
      {
         double h=iHigh(_Symbol,PERIOD_M5,s), l=iLow(_Symbol,PERIOD_M5,s);
         if(!found) { hi=h; lo=l; found=true; }
         else { hi=MathMax(hi,h); lo=MathMin(lo,l); }
      }
   }
   return found;
}

void DrawRange(double hi, double lo)
{
   if(!InpDrawRange || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   datetime t1 = iTime(_Symbol, PERIOD_M5, 1);
   string name = "GB_range_" + (string)TradingDay(t1);
   if(ObjectFind(0,name)>=0) return;
   datetime dayStart = (datetime)((long)t1 - (long)RelMin(t1)*60);
   datetime a = dayStart + (datetime)(g_rs*60), b = dayStart + (datetime)(g_re*60), e = dayStart + (datetime)(g_te*60);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, a, hi, b, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrSlateBlue);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   string hn = name+"_hi", ln = name+"_lo";
   ObjectCreate(0, hn, OBJ_TREND, 0, b, hi, e, hi);
   ObjectCreate(0, ln, OBJ_TREND, 0, b, lo, e, lo);
   ObjectSetInteger(0, hn, OBJPROP_COLOR, clrMediumSeaGreen);
   ObjectSetInteger(0, ln, OBJPROP_COLOR, clrTomato);
   ObjectSetInteger(0, hn, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_DASH);
}

//====================================================================
// New bar: manage open position or look for a signal
//====================================================================
void OnNewBar()
{
   datetime t1 = iTime(_Symbol, PERIOD_M5, 1);
   int m = RelMin(t1) + 5;               // close time of bar 1, minutes since day start
   double atr = Buf(hATR, 1);
   double o=iOpen(_Symbol,PERIOD_M5,1), h=iHigh(_Symbol,PERIOD_M5,1), l=iLow(_Symbol,PERIOD_M5,1), c=iClose(_Symbol,PERIOD_M5,1);
   double prev = iClose(_Symbol, PERIOD_M5, 2);

   double rh=0, rl=0;
   bool haveRange = DayRange(rh, rl) && m >= g_re;
   if(haveRange) DrawRange(rh, rl);

   ulong ticket;
   if(SelectMyPosition(ticket))
   {
      bool isBuy = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double sl  = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      if(m >= g_fl)
      {
         trade.PositionClose(ticket);
         g_status = "Dong lenh: het gio";
         return;
      }
      if(GVGet(ticket,"tp1done",1)>0 && InpTrailATR>0 && atr>0)
      {
         // best close since the entry bar (Python: pos.best)
         datetime openBar = (datetime)GVGet(ticket,"openbar",(double)PositionGetInteger(POSITION_TIME));
         double best = PositionGetDouble(POSITION_PRICE_OPEN);
         for(int s=1; s<2000; s++)
         {
            datetime t = iTime(_Symbol,PERIOD_M5,s);
            if(t==0 || t<openBar) break;
            double cc = iClose(_Symbol,PERIOD_M5,s);
            best = isBuy ? MathMax(best,cc) : MathMin(best,cc);
         }
         double nsl = isBuy ? best - InpTrailATR*atr : best + InpTrailATR*atr;
         double px  = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double gap = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
         bool better = isBuy ? nsl>sl : (sl==0 || nsl<sl);
         bool valid  = isBuy ? nsl<px-gap : nsl>px+gap;
         if(better && valid) trade.PositionModify(ticket, NormalizeDouble(nsl,_Digits), tp);
      }
      return;
   }

   // ---------------- entry logic (goldbot/strategies/breakout.py on_bar) ----------------
   if(!(m>=g_ts && m<=g_te) || atr<=0) return;
   double ha = Buf(hH1ATR, 1);
   if(!haveRange || ha<=0) return;

   int buys, sells, consec; double dayPnl;
   DayStats(buys, sells, dayPnl, consec);
   if(buys+sells >= InpMaxTradesPerDay) return;

   double buf = InpBufferATR*atr;
   bool up = (c > rh+buf && prev <= rh+buf);
   bool dn = (c < rl-buf && prev >= rl-buf);
   if(!up && !dn) return;
   g_cntBreaks++;

   double height = rh-rl;
   if(height < InpMinRangeH1ATR*ha || height > InpMaxRangeH1ATR*ha) { g_cntRange++; return; }
   double rng = h-l;
   if(rng<=0 || MathAbs(c-o) < InpMinBody*rng || (up && c<o) || (dn && c>o)) { g_cntBody++; return; }
   if(InpUseTrend)
   {
      double en = Buf(hEMA,1), ep = Buf(hEMA,1+InpTrendSlopeBars);
      if(en<=0 || (up && !(c>en && en>ep)) || (dn && !(c<en && en<ep))) { g_cntTrend++; return; }
   }
   if((up && buys>0) || (dn && sells>0)) { g_cntSide++; return; }

   // ---------------- engine-side gates ----------------
   string blocked = BlockedReason(dayPnl, consec);
   if(blocked!="") { g_cntBlocked++; g_status="Khoa: "+blocked; return; }
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID), ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(ask-bid > InpMaxSpreadPoints*_Point) { g_cntSpread++; return; }

   double mid  = (rh+rl)/2.0;
   double dist = MathMin(MathMax(MathAbs(c-mid), InpMinSLATR*atr), InpMaxSLATR*atr);
   double sl   = up ? c-dist : c+dist;
   double fill = up ? ask : bid;
   double risk = up ? fill-sl : sl-fill;
   if(risk <= MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),1.0)*_Point) return;
   double lots = LotSize(risk);
   if(lots<=0) return;
   double tp = up ? fill+InpTP_R*risk : fill-InpTP_R*risk;

   bool ok = up ? trade.Buy(lots, _Symbol, fill, NormalizeDouble(sl,_Digits), NormalizeDouble(tp,_Digits), "GB-BO")
                : trade.Sell(lots, _Symbol, fill, NormalizeDouble(sl,_Digits), NormalizeDouble(tp,_Digits), "GB-BO");
   if(!ok || !SelectMyPosition(ticket))
   {
      PrintFormat("[GoldBot] Vao lenh that bai: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
   }
   g_cntEntries++;
   // targets from the real fill, like the Python engine
   double real = PositionGetDouble(POSITION_PRICE_OPEN);
   double r2   = up ? real-sl : sl-real;
   double tp1  = InpTP1_R>0 ? (up ? real+InpTP1_R*r2 : real-InpTP1_R*r2) : 0;
   GVSet(ticket,"tp1",tp1);
   GVSet(ticket,"tp1done", InpTP1_R>0 ? 0 : 1);
   GVSet(ticket,"openbar",(double)iTime(_Symbol,PERIOD_M5,0));
   double want = NormalizeDouble(up ? real+InpTP_R*r2 : real-InpTP_R*r2, _Digits);
   if(MathAbs(want-PositionGetDouble(POSITION_TP)) >= 5*_Point)
      trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), want);
   g_status = StringFormat("%s %.2f lot @ %.2f  SL %.2f  TP1 %.2f  TP %.2f", up?"MUA":"BAN", lots, real, sl, tp1, want);
   PrintFormat("[GoldBot] %s", g_status);
}

//====================================================================
// Standard handlers
//====================================================================
int OnInit()
{
   if(_Period != PERIOD_M5)
      Print("[GoldBot] Luu y: EA tinh theo M5 bat ke khung chart, nen gan vao chart M5 de de theo doi.");
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   bool demo   = AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO;
   if(!tester && !demo && !InpAllowRealAccount)
   {
      Alert("GoldBot: day la tai khoan THAT. Bat InpAllowRealAccount neu ban chac chan muon chay.");
      return INIT_FAILED;
   }
   hATR   = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   hH1ATR = iATR(_Symbol, PERIOD_H1, InpH1ATRPeriod);
   hEMA   = iMA(_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hATR==INVALID_HANDLE || hH1ATR==INVALID_HANDLE || hEMA==INVALID_HANDLE) return INIT_FAILED;

   g_rs=RelH(InpRangeStart); g_re=RelH(InpRangeEnd);
   g_ts=RelH(InpTradeStart); g_te=RelH(InpTradeEnd); g_fl=RelH(InpFlatHour);
   g_gv = StringFormat("GB_%I64d_", InpMagic);

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_lastBar = iTime(_Symbol, PERIOD_M5, 0);   // act from the next fresh bar
   PrintFormat("[GoldBot] Khoi dong %s | %s | rui ro %.2f%%/lenh", _Symbol, demo?"DEMO":(tester?"TESTER":"THAT"), InpRiskPercent);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PrintFormat("[GoldBot Summary] entries=%I64d breaks=%I64d f_range=%I64d f_body=%I64d f_trend=%I64d f_side=%I64d spread=%I64d blocked=%I64d",
               g_cntEntries, g_cntBreaks, g_cntRange, g_cntBody, g_cntTrend, g_cntSide, g_cntSpread, g_cntBlocked);
   IndicatorRelease(hATR); IndicatorRelease(hH1ATR); IndicatorRelease(hEMA);
   Comment("");
}

void OnTick()
{
   ManageTicks();
   datetime bt = iTime(_Symbol, PERIOD_M5, 0);
   if(bt != g_lastBar)
   {
      g_lastBar = bt;
      OnNewBar();
   }
   ulong tk;
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
      Comment(StringFormat("GoldBot Session Breakout | %s\nGio NY: %s\n%s\n%s",
              _Symbol, TimeToString((datetime)ToNY(TimeCurrent()), TIME_MINUTES),
              SelectMyPosition(tk) ? StringFormat("Vi the #%I64u  P/L %.2f", tk, PositionGetDouble(POSITION_PROFIT)) : "Khong co vi the",
              g_status));
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   LogDeal(trans.deal);
   ulong tk;
   if(!SelectMyPosition(tk)) GlobalVariablesDeleteAll(g_gv);  // flat: drop stale per-position state
}
//+------------------------------------------------------------------+
