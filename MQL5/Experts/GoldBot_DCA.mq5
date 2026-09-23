//+------------------------------------------------------------------+
//|                                              GoldBot_DCA.mq5     |
//|  DCA / martingale basket for XAUUSD - MQL5 twin of the Python    |
//|  simulator backtest/goldbot/dca.py (setup search: dca_setups.py).|
//|                                                                  |
//|  Always in the market (24/24):                                   |
//|  1. Flat -> on the next M1 bar open a 0.01 basket. Direction     |
//|     from the last CLOSED H1 bar: "side" = close above EMA50 buy, |
//|     below sell; "slope" = EMA50 rising buy, falling sell;        |
//|     "long" = buy only.                                           |
//|  2. Every Step x ATR(H1) against the first entry add one more    |
//|     position, lot x1.3, from order 6 on x1.2 (like CCBSN).       |
//|     Step and TP distance are frozen when the basket opens.       |
//|  3. No stop loss. The whole basket closes at TP x ATR(H1) beyond |
//|     its average price (server-side TP on every position + a      |
//|     backup check on every tick), then back to step 1.            |
//|  4. When flat with balance >= InpWithdrawAt: alert + push to     |
//|     remind you to withdraw down to InpWithdrawTo. Trading keeps  |
//|     going - the lot always restarts from InpStartLot.            |
//|  Closed baskets are logged to Common\Files\GoldBotDCA_<sym>_<magic>.csv
//+------------------------------------------------------------------+
#property copyright "Gold Bot"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

enum ENUM_DCA_DIR
{
   DIR_SIDE  = 0,  // side: gia tren EMA H1 -> Buy, duoi -> Sell
   DIR_SLOPE = 1,  // slope: EMA H1 doc len -> Buy, doc xuong -> Sell
   DIR_LONG  = 2   // long: chi Buy
};

//====================================================================
// Inputs (defaults = best 24/24 setup of dca_setups.py)
//====================================================================
input group "=== Huong vao chuoi ==="
input ENUM_DCA_DIR InpDirection   = DIR_SIDE;
input int    InpTrendEMA          = 50;     // EMA tren H1
input int    InpTrendSlopeBars    = 3;      // so nen H1 de do do doc (slope)
input int    InpATRPeriod         = 14;     // ATR tren H1

input group "=== Chuoi DCA ==="
input double InpStartLot          = 0.01;   // lot lenh dau moi chuoi
input double InpStepATR           = 1.5;    // khoang cach nhoi = x ATR(H1)
input double InpMult              = 1.3;    // he so nhan lot
input double InpMult2             = 1.2;    // he so nhan moi (0 = khong doi)
input int    InpMult2After        = 5;      // doi sang he so moi sau so lenh nay
input double InpTPATR             = 0.2;    // chot ca chuoi = gia trung binh +/- x ATR(H1)
input int    InpMaxOrders         = 0;      // toi da so lenh/chuoi (0 = khong gioi han, nhu backtest)

input group "=== Rut lai ==="
input double InpWithdrawAt        = 10000;  // nhac rut khi so du >= muc nay (0 = tat)
input double InpWithdrawTo        = 5000;   // rut ve con muc nay

input group "=== He thong ==="
input long   InpMagic             = 26092302;
input int    InpDeviationPoints   = 50;
input bool   InpAllowRealAccount  = false;  // an toan: chi chay demo neu false
input bool   InpWriteLog          = true;

//====================================================================
// Globals
//====================================================================
int      hATR = INVALID_HANDLE, hEMA = INVALID_HANDLE;
datetime g_lastBar = 0;
datetime g_addFailBar = 0;   // an add that failed is retried on the next M1 bar
string   g_gv;
string   g_status = "";
bool     g_withdrawWarned = false;
int      g_maxOrdersSeen = 0;
double   g_maxLotsSeen = 0;

// basket snapshot rebuilt from the open positions on every tick
struct Basket
{
   int    n;
   bool   buy;
   double lots;
   double avg;
   double profit;
   datetime openTime;
};

//====================================================================
// Helpers
//====================================================================
double GV(string key, double def)
{
   string name = g_gv + key;
   return GlobalVariableCheck(name) ? GlobalVariableGet(name) : def;
}
void GVSet(string key, double v) { GlobalVariableSet(g_gv + key, v); }

double NormLot(double v)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(step<=0) step=0.01;
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   v = MathFloor(v/step + 1e-9)*step;
   return NormalizeDouble(MathMax(mn, MathMin(mx, v)), 2);
}

// lot of order index `level` (0 = first order), same as DCASim._lots
double LevelLot(int level)
{
   double v;
   if(InpMult2 > 0 && level >= InpMult2After)
      v = InpStartLot * MathPow(InpMult, InpMult2After-1) * MathPow(InpMult2, level-InpMult2After+1);
   else
      v = InpStartLot * MathPow(InpMult, level);
   return NormLot(v);
}

bool H1Value(int handle, int shift, double &v)
{
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return false;
   v = buf[0];
   return v > 0;
}

void ReadBasket(Basket &b)
{
   b.n=0; b.buy=true; b.lots=0; b.avg=0; b.profit=0; b.openTime=0;
   double pv = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      b.buy = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      b.lots += vol;
      pv += vol*PositionGetDouble(POSITION_PRICE_OPEN);
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(b.openTime==0 || t<b.openTime) b.openTime = t;
      b.n++;
   }
   if(b.lots > 0) b.avg = pv/b.lots;
}

// -1 = sell, +1 = buy, 0 = no data yet
int Direction()
{
   if(InpDirection == DIR_LONG) return 1;
   double e, c = iClose(_Symbol, PERIOD_H1, 1);
   if(!H1Value(hEMA, 1, e) || c<=0) return 0;
   if(InpDirection == DIR_SIDE) return c >= e ? 1 : -1;
   double ep;
   if(!H1Value(hEMA, 1+InpTrendSlopeBars, ep)) return 0;
   return e >= ep ? 1 : -1;
}

//====================================================================
// Basket actions
//====================================================================
void OpenBasket()
{
   int d = Direction();
   double atr;
   if(d==0 || !H1Value(hATR, 1, atr)) { g_status = "Cho du lieu H1..."; return; }
   double lot = NormLot(InpStartLot);
   bool ok = d>0 ? trade.Buy(lot, _Symbol, 0, 0, 0, "DCA#1") : trade.Sell(lot, _Symbol, 0, 0, 0, "DCA#1");
   if(!ok || trade.ResultRetcode()!=TRADE_RETCODE_DONE)
   {
      g_status = StringFormat("Mo chuoi that bai: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      Print("[DCA] ", g_status);
      return;
   }
   double px = trade.ResultPrice();
   if(px<=0) px = d>0 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   GVSet("anchor", px);
   GVSet("step", InpStepATR*atr);
   GVSet("tp", InpTPATR*atr);
   GVSet("buy", d>0 ? 1 : 0);
   GVSet("open", (double)TimeCurrent());
   PrintFormat("[DCA] Mo chuoi %s %.2f @ %.2f | step %.2f | TP %.2f | ATR H1 %.2f",
               d>0?"BUY":"SELL", lot, px, InpStepATR*atr, InpTPATR*atr, atr);
}

// put the basket TP on every position (server-side, works while the terminal is offline)
void SyncTP(const Basket &b)
{
   double tpDist = GV("tp", 0);
   if(tpDist<=0 || b.lots<=0) return;
   double tp = NormalizeDouble(b.buy ? b.avg+tpDist : b.avg-tpDist, _Digits);
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(MathAbs(PositionGetDouble(POSITION_TP)-tp) >= _Point)
         trade.PositionModify(tk, 0, tp);
   }
}

void CloseBasket()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      trade.PositionClose(tk);
   }
}

void ManageBasket(Basket &b)
{
   // state lost (new terminal, GV deleted): rebuild from the first position and today's ATR
   if(GV("step",0)<=0)
   {
      double atr;
      if(!H1Value(hATR, 1, atr)) return;
      double first = 0; datetime ft = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong tk = PositionGetTicket(i);
         if(tk==0 || PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if(ft==0 || t<ft) { ft=t; first=PositionGetDouble(POSITION_PRICE_OPEN); }
      }
      GVSet("anchor", first); GVSet("step", InpStepATR*atr); GVSet("tp", InpTPATR*atr); GVSet("buy", b.buy?1:0); GVSet("open", (double)ft);
      Print("[DCA] Khoi phuc trang thai chuoi tu vi the dang mo");
   }
   double step = GV("step",0), tpDist = GV("tp",0), anchor = GV("anchor",0);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID), ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   // backup basket TP (the server TP normally does this)
   if((b.buy && bid >= b.avg+tpDist) || (!b.buy && ask <= b.avg-tpDist))
   {
      CloseBasket();
      return;
   }

   // add the next level: buy when ask reaches anchor - n*step, sell when bid reaches anchor + n*step
   double next = b.buy ? anchor - b.n*step : anchor + b.n*step;
   bool hit = b.buy ? ask <= next : bid >= next;
   if(hit && (InpMaxOrders<=0 || b.n < InpMaxOrders))
   {
      datetime bar = iTime(_Symbol, PERIOD_M1, 0);
      if(g_addFailBar == bar) return;
      double lot = LevelLot(b.n);
      string cm = StringFormat("DCA#%d", b.n+1);
      bool ok = b.buy ? trade.Buy(lot, _Symbol, 0, 0, 0, cm) : trade.Sell(lot, _Symbol, 0, 0, 0, cm);
      if(ok && trade.ResultRetcode()==TRADE_RETCODE_DONE)
      {
         PrintFormat("[DCA] Nhoi lenh %d: %s %.2f @ %.2f", b.n+1, b.buy?"BUY":"SELL", lot, trade.ResultPrice());
         ReadBasket(b);
      }
      else
      {
         g_addFailBar = bar;
         PrintFormat("[DCA] Nhoi lenh %d that bai: %d %s", b.n+1, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
   // re-sync the server TP when the basket changed, otherwise at most once a minute
   static int      syncN = -1;
   static datetime syncBar = 0;
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(b.n != syncN || m1 != syncBar)
   {
      syncN = b.n; syncBar = m1;
      SyncTP(b);
   }
}

//====================================================================
// Basket log
//====================================================================
void LogBasket(datetime from)
{
   if(!InpWriteLog || from==0) return;
   if(!HistorySelect(from-1, TimeCurrent()+60)) return;
   double pnl=0, maxLot=0; int n=0; string dir="";
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic || HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      pnl += HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION);
      if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN)
      {
         n++;
         maxLot = MathMax(maxLot, HistoryDealGetDouble(d,DEAL_VOLUME));
         dir = HistoryDealGetInteger(d,DEAL_TYPE)==DEAL_TYPE_BUY ? "buy" : "sell";
      }
   }
   string fn = StringFormat("GoldBotDCA_%s_%I64d.csv", _Symbol, InpMagic);
   int h = FileOpen(fn, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0) FileWrite(h, "open","close","dir","orders","max_lot","pnl","balance");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString(from, TIME_DATE|TIME_SECONDS), TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
             dir, (string)n, DoubleToString(maxLot,2), DoubleToString(pnl,2), DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
   FileClose(h);
   PrintFormat("[DCA] Dong chuoi %s %d lenh, lot lon nhat %.2f, P/L %.2f", dir, n, maxLot, pnl);
}

void CheckWithdraw()
{
   if(InpWithdrawAt<=0) return;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal < InpWithdrawAt) { g_withdrawWarned = false; return; }
   if(g_withdrawWarned) return;
   g_withdrawWarned = true;
   string msg = StringFormat("GoldBot DCA %s: so du %.2f >= %.2f -> rut %.2f ve con %.2f",
                             _Symbol, bal, InpWithdrawAt, bal-InpWithdrawTo, InpWithdrawTo);
   Print("[DCA] ", msg);
   if(!MQLInfoInteger(MQL_TESTER)) { Alert(msg); SendNotification(msg); }
}

//====================================================================
// Standard handlers
//====================================================================
int OnInit()
{
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   bool demo   = AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO;
   if(!tester && !demo && !InpAllowRealAccount)
   {
      Alert("GoldBot DCA: day la tai khoan THAT. Bat InpAllowRealAccount neu ban chac chan muon chay.");
      return INIT_FAILED;
   }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Alert("GoldBot DCA can tai khoan HEDGING (nhieu vi the cung chieu).");
      return INIT_FAILED;
   }
   hATR = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   hEMA = iMA(_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hATR==INVALID_HANDLE || hEMA==INVALID_HANDLE) return INIT_FAILED;
   g_gv = StringFormat("GBDCA_%s_%I64d_", _Symbol, InpMagic);
   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_lastBar = iTime(_Symbol, PERIOD_M1, 0);
   string lots = "";
   for(int k=0; k<12; k++) lots += StringFormat("%s%.2f", k?" ":"", LevelLot(k));
   PrintFormat("[DCA] Khoi dong %s | %s | step %.2f ATR, TP %.2f ATR | lot: %s ...",
               _Symbol, demo?"DEMO":(tester?"TESTER":"THAT"), InpStepATR, InpTPATR, lots);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PrintFormat("[DCA Summary] chuoi dai nhat %d lenh, tong lot lon nhat %.2f", g_maxOrdersSeen, g_maxLotsSeen);
   IndicatorRelease(hATR); IndicatorRelease(hEMA);
   Comment("");
}

void OnTick()
{
   Basket b;
   ReadBasket(b);
   datetime bt = iTime(_Symbol, PERIOD_M1, 0);
   if(b.n > 0)
   {
      ManageBasket(b);
      g_maxOrdersSeen = (int)MathMax(g_maxOrdersSeen, b.n);
      g_maxLotsSeen   = MathMax(g_maxLotsSeen, b.lots);
      ReadBasket(b);
      if(b.n == 0) g_lastBar = bt;           // closed on this tick: log it first, next basket on the next M1 bar
   }
   if(bt != g_lastBar)
   {
      g_lastBar = bt;
      ReadBasket(b);
      if(b.n == 0)
      {
         CheckWithdraw();
         OpenBasket();
      }
   }
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      ReadBasket(b);
      string info = "Khong co chuoi";
      if(b.n > 0)
      {
         double step = GV("step",0), tp = GV("tp",0), anchor = GV("anchor",0);
         info = StringFormat("Chuoi %s: %d lenh, %.2f lot | TB %.2f | TP %.2f\nLenh tiep: %.2f lot tai %.2f | P/L %.2f",
                             b.buy?"BUY":"SELL", b.n, b.lots, b.avg, b.buy?b.avg+tp:b.avg-tp,
                             LevelLot(b.n), b.buy?anchor-b.n*step:anchor+b.n*step, b.profit);
      }
      Comment(StringFormat("GoldBot DCA | %s\nSo du %.2f | Equity %.2f | Rut khi >= %.0f\n%s\nChuoi dai nhat tu luc chay: %d lenh / %.2f lot\n%s",
              _Symbol, AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY), InpWithdrawAt,
              info, g_maxOrdersSeen, g_maxLotsSeen, g_status));
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   Basket b;
   ReadBasket(b);
   if(b.n > 0) return;                       // basket still has positions
   datetime from = (datetime)(long)GV("open", 0);
   LogBasket(from);
   GlobalVariablesDeleteAll(g_gv);           // flat: next basket starts fresh
}
//+------------------------------------------------------------------+
