//+------------------------------------------------------------------+
//|                                                 CopyReceiver.mq5 |
//| Gan vao terminal dang nhap tai khoan CUA BAN (vd tai khoan cent).|
//| Doc Common\Files\<kenh>.csv do CopySender ghi va sao chep y het: |
//| vao lenh, lenh cho, sua SL/TP (trailing), chot tung phan, dong.  |
//| Can bat Algo Trading.                                            |
//+------------------------------------------------------------------+
#property copyright "CopyReceiver"
#property version   "1.00"
#property description "Sao chep lenh tu CopySender (cung may) sang tai khoan nay."

#include <Trade\Trade.mqh>

enum ENUM_LOT_MODE
  {
   LOT_MULTIPLIER    = 0, // Lot nguon x he so (1.0 = y het)
   LOT_BALANCE_RATIO = 1, // Theo ti le balance (cung % rui ro)
   LOT_FIXED         = 2  // Lot co dinh
  };

input string        InpChannel           = "copy1";         // Ten kenh (trung voi CopySender)
input string        InpSymbolSuffix      = "c";             // Hau to symbol tai khoan nay (Exness cent: XAUUSDc). Trong = giu nguyen
input ENUM_LOT_MODE InpLotMode           = LOT_MULTIPLIER;  // Cach tinh lot
input double        InpLotValue          = 1.0;             // He so (mode 0,1) hoac lot co dinh (mode 2)
input double        InpMaxLot            = 1.0;             // Lot toi da moi lenh
input bool          InpCopyPending       = true;            // Sao chep ca lenh cho (limit/stop)
input bool          InpCopyExisting      = false;           // Sao chep ca lenh dang mo luc bat EA
input int           InpMaxSlippagePoints = 1000;            // Bo qua neu gia da chay xa hon (point). Vang 3 so le: 1000 = 1$
input int           InpMaxStaleSec       = 10;              // File nguon cu hon N giay -> tam dung (khong dong lenh)
input int           InpIntervalMs        = 250;             // Chu ky dong bo (ms)
input ulong         InpMagic             = 26092301;        // Magic cua lenh copy
input bool          InpHiddenStops       = true;            // An SL/TP: EA tu dong lenh khi gia cham
input int           InpEmergencySLPoints = 3000;            // SL khan cap tren san, xa hon SL an N point (vang: 3000 = 3$). 0 = khong dat

CTrade g_trade;

//--- du lieu doc tu nguon
string   mKind[], mSym[];
ulong    mTicket[];
int      mType[];
double   mVol[], mPrice[], mSL[], mTP[];
double   mBalance = 0;
datetime mTs = 0;

ulong    g_skip[];          // lenh da co san luc bat EA (khi InpCopyExisting=false)
bool     g_ready = false;
datetime g_lastStaleMsg = 0;

//+------------------------------------------------------------------+
string Tag(const ulong t) { return "CP" + IntegerToString((long)t); }
string GvOpened(const ulong t) { return "CPo_" + IntegerToString((long)t); }
string GvMInit(const ulong t)  { return "CPm_" + IntegerToString((long)t); }
string GvLInit(const ulong t)  { return "CPl_" + IntegerToString((long)t); }

//--- SL/TP gui len san. Che do an: khong gui TP, SL lui xa them InpEmergencySLPoints
void BrokerStops(const string sym, const bool buy, const double sl, const double tp, double &bsl, double &btp)
  {
   bsl = sl;
   btp = tp;
   if(!InpHiddenStops)
      return;
   btp = 0;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(sl <= 0 || InpEmergencySLPoints <= 0)
      bsl = 0;
   else
      bsl = NormPrice(sym, buy ? sl - InpEmergencySLPoints * point : sl + InpEmergencySLPoints * point);
  }

//--- SL/TP an: gia cham thi dong lenh
bool HiddenHit(const string sym, const bool buy, const double sl, const double tp)
  {
   if(!InpHiddenStops)
      return false;
   double bid = SymbolInfoDouble(sym, SYMBOL_BID), ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(buy)
      return (sl > 0 && bid <= sl) || (tp > 0 && bid >= tp);
   return (sl > 0 && ask >= sl) || (tp > 0 && ask <= tp);
  }

//--- sua SL/TP bi san tu choi -> cho 5 giay moi thu lai (tranh spam)
string GvFail(const ulong t) { return "CPx_" + IntegerToString((long)t); }
bool CanRetry(const ulong t)
  {
   return !GlobalVariableCheck(GvFail(t)) || TimeLocal() - (datetime)GlobalVariableGet(GvFail(t)) >= 5;
  }
void MarkFailed(const ulong t) { GlobalVariableSet(GvFail(t), (double)TimeLocal()); }

bool InList(const ulong &arr[], const ulong t)
  {
   for(int i = 0; i < ArraySize(arr); i++)
      if(arr[i] == t)
         return true;
   return false;
  }

string LocalSymbol(const string src)
  {
   if(StringLen(InpSymbolSuffix) > 0 && SymbolSelect(src + InpSymbolSuffix, true))
      return src + InpSymbolSuffix;
   if(SymbolSelect(src, true))
      return src;
   return "";
  }

double NormPrice(const string sym, const double p)
  {
   if(p <= 0)
      return 0;
   return NormalizeDouble(p, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
  }

double NormLot(const string sym, double lot)
  {
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   if(step <= 0)
      step = 0.01;
   lot = MathRound(lot / step) * step;
   lot = MathMax(lot, vmin);
   lot = MathMin(lot, MathMin(vmax, InpMaxLot));
   return NormalizeDouble(lot, 2);
  }

double ScaleLot(const string sym, const double srcLot)
  {
   double lot = srcLot;
   if(InpLotMode == LOT_MULTIPLIER)
      lot = srcLot * InpLotValue;
   else if(InpLotMode == LOT_BALANCE_RATIO && mBalance > 0)
      lot = srcLot * AccountInfoDouble(ACCOUNT_BALANCE) / mBalance * InpLotValue;
   else if(InpLotMode == LOT_FIXED)
      lot = InpLotValue;
   return NormLot(sym, lot);
  }

//+------------------------------------------------------------------+
//| Doc file nguon; chi chap nhan khi co dong ket thuc E dung so dong |
//+------------------------------------------------------------------+
bool ReadSource()
  {
   int h = FileOpen(InpChannel + ".csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON |
                    FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      return false;
   string kind[], sym[];
   ulong  tk[];
   int    ty[];
   double vol[], pr[], sl[], tp[];
   double bal = 0;
   datetime ts = 0;
   int n = 0;
   bool complete = false;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      string f[];
      int k = StringSplit(line, ',', f);
      if(k < 1)
         continue;
      if(f[0] == "H" && k >= 3)
        {
         ts  = (datetime)StringToInteger(f[1]);
         bal = StringToDouble(f[2]);
        }
      else if((f[0] == "P" || f[0] == "O") && k >= 8)
        {
         ArrayResize(kind, n + 1); ArrayResize(sym, n + 1); ArrayResize(tk, n + 1); ArrayResize(ty, n + 1);
         ArrayResize(vol, n + 1);  ArrayResize(pr, n + 1);  ArrayResize(sl, n + 1); ArrayResize(tp, n + 1);
         kind[n] = f[0];
         tk[n]   = (ulong)StringToInteger(f[1]);
         sym[n]  = f[2];
         ty[n]   = (int)StringToInteger(f[3]);
         vol[n]  = StringToDouble(f[4]);
         pr[n]   = StringToDouble(f[5]);
         sl[n]   = StringToDouble(f[6]);
         tp[n]   = StringToDouble(f[7]);
         n++;
        }
      else if(f[0] == "E" && k >= 2)
         complete = ((int)StringToInteger(f[1]) == n);
     }
   FileClose(h);
   if(!complete || ts == 0)
      return false; // file dang ghi do, lan sau doc lai

   ArrayCopy(mKind, kind);  ArrayResize(mKind, n);
   ArrayCopy(mSym, sym);    ArrayResize(mSym, n);
   ArrayCopy(mTicket, tk);  ArrayResize(mTicket, n);
   ArrayCopy(mType, ty);    ArrayResize(mType, n);
   ArrayCopy(mVol, vol);    ArrayResize(mVol, n);
   ArrayCopy(mPrice, pr);   ArrayResize(mPrice, n);
   ArrayCopy(mSL, sl);      ArrayResize(mSL, n);
   ArrayCopy(mTP, tp);      ArrayResize(mTP, n);
   mBalance = bal;
   mTs = ts;
   return true;
  }

//+------------------------------------------------------------------+
ulong FindLocalPosition(const string tag)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t != 0 && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_COMMENT) == tag)
         return t;
     }
   return 0;
  }

ulong FindLocalOrder(const string tag)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t != 0 && (ulong)OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_COMMENT) == tag)
         return t;
     }
   return 0;
  }

bool SourceHas(const ulong t)
  {
   for(int i = 0; i < ArraySize(mTicket); i++)
      if(mTicket[i] == t)
         return true;
   return false;
  }

ulong TicketFromTag(const string c)
  {
   if(StringSubstr(c, 0, 2) != "CP")
      return 0;
   return (ulong)StringToInteger(StringSubstr(c, 2));
  }

//+------------------------------------------------------------------+
//| Vi the nguon -> vi the local                                     |
//+------------------------------------------------------------------+
void SyncPosition(const int i)
  {
   ulong  st  = mTicket[i];
   string tag = Tag(st);
   string sym = LocalSymbol(mSym[i]);
   if(sym == "")
      return;
   double sl = NormPrice(sym, mSL[i]), tp = NormPrice(sym, mTP[i]);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);

   ulong lp = FindLocalPosition(tag);
   if(lp == 0)
     {
      ulong lo = FindLocalOrder(tag);
      // 1 = da mo market (hoac bo qua vi truot gia), 3 = da tung co vi the local
      // -> vi the local da dong thi KHONG mo lai. 2 = moi dat lenh cho, chua khop.
      if(lo == 0 && GlobalVariableCheck(GvOpened(st)) && GlobalVariableGet(GvOpened(st)) != 2)
         return;
      if(lo != 0)
         g_trade.OrderDelete(lo); // lenh cho local chua khop trong khi nguon da khop -> vao market

      bool buy = (mType[i] == POSITION_TYPE_BUY);
      double cur = buy ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
      double worse = buy ? (cur - mPrice[i]) : (mPrice[i] - cur);
      if(worse / point > InpMaxSlippagePoints)
        {
         PrintFormat("[CopyReceiver] Bo qua %s: gia da chay %.0f point (> %d)", tag, worse / point, InpMaxSlippagePoints);
         GlobalVariableSet(GvOpened(st), 1);
         return;
        }
      double lot = ScaleLot(sym, mVol[i]);
      double bsl, btp;
      BrokerStops(sym, buy, sl, tp, bsl, btp);
      bool ok = buy ? g_trade.Buy(lot, sym, 0, bsl, btp, tag) : g_trade.Sell(lot, sym, 0, bsl, btp, tag);
      if(!ok && g_trade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
         ok = buy ? g_trade.Buy(lot, sym, 0, 0, 0, tag) : g_trade.Sell(lot, sym, 0, 0, 0, tag);
      PrintFormat("[CopyReceiver] Mo %s %s %.2f lot -> %s (%d)", buy ? "BUY" : "SELL", sym, lot,
                  ok ? "OK" : "LOI", g_trade.ResultRetcode());
      GlobalVariableSet(GvOpened(st), 1);
      if(ok)
        {
         if(!GlobalVariableCheck(GvMInit(st)))
            GlobalVariableSet(GvMInit(st), mVol[i]);
         GlobalVariableSet(GvLInit(st), lot);
        }
      return;
     }

   //--- da co vi the local: dong bo SL/TP
   GlobalVariableSet(GvOpened(st), 3);
   if(!PositionSelectByTicket(lp))
      return;
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   if(HiddenHit(sym, isBuy, sl, tp))
     {
      bool ok = g_trade.PositionClose(lp);
      PrintFormat("[CopyReceiver] Cham SL/TP an %s -> dong (%s)", tag, ok ? "OK" : "LOI");
      return;
     }
   double bsl, btp;
   BrokerStops(sym, isBuy, sl, tp, bsl, btp);
   double lsl = PositionGetDouble(POSITION_SL), ltp = PositionGetDouble(POSITION_TP);
   if((MathAbs(lsl - bsl) > point * 0.5 || MathAbs(ltp - btp) > point * 0.5) && CanRetry(st))
     {
      if(!g_trade.PositionModify(lp, bsl, btp))
         MarkFailed(st);
      else if(!PositionSelectByTicket(lp))
         return;
     }

   //--- dong bo chot tung phan
   if(!GlobalVariableCheck(GvMInit(st)))
      GlobalVariableSet(GvMInit(st), mVol[i]);
   if(!GlobalVariableCheck(GvLInit(st)))
      GlobalVariableSet(GvLInit(st), PositionGetDouble(POSITION_VOLUME));
   double mInit = GlobalVariableGet(GvMInit(st));
   double lInit = GlobalVariableGet(GvLInit(st));
   if(mInit <= 0)
      return;
   double target = NormLot(sym, lInit * mVol[i] / mInit);
   double lvol   = PositionGetDouble(POSITION_VOLUME);
   double step   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(lvol - target >= step - 1e-9)
     {
      bool ok = g_trade.PositionClosePartial(lp, NormalizeDouble(lvol - target, 2));
      PrintFormat("[CopyReceiver] Chot 1 phan %s: %.2f -> %.2f lot (%s)", tag, lvol, target, ok ? "OK" : "LOI");
     }
  }

//+------------------------------------------------------------------+
//| Lenh cho nguon -> lenh cho local                                 |
//+------------------------------------------------------------------+
void SyncOrder(const int i)
  {
   ulong  st  = mTicket[i];
   string tag = Tag(st);
   string sym = LocalSymbol(mSym[i]);
   if(sym == "")
      return;
   ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)mType[i];
   if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT &&
      type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
      return;
   double price = NormPrice(sym, mPrice[i]);
   bool   buy   = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP);
   double sl, tp;
   BrokerStops(sym, buy, NormPrice(sym, mSL[i]), NormPrice(sym, mTP[i]), sl, tp);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);

   ulong lo = FindLocalOrder(tag);
   if(lo == 0)
     {
      if(GlobalVariableCheck(GvOpened(st)))
         return; // da dat roi (da khop hoac bi huy)
      double lot = ScaleLot(sym, mVol[i]);
      bool ok = g_trade.OrderOpen(sym, type, lot, 0, price, sl, tp, ORDER_TIME_GTC, 0, tag);
      PrintFormat("[CopyReceiver] Dat %s %s %.2f lot @ %s -> %s (%d)", EnumToString(type), sym, lot,
                  DoubleToString(price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS)), ok ? "OK" : "LOI", g_trade.ResultRetcode());
      GlobalVariableSet(GvOpened(st), 2); // 2 = da dat lenh cho
      GlobalVariableSet(GvMInit(st), mVol[i]);
      GlobalVariableSet(GvLInit(st), lot);
      return;
     }
   if(!OrderSelect(lo))
      return;
   if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) > point * 0.5 ||
      MathAbs(OrderGetDouble(ORDER_SL) - sl) > point * 0.5 ||
      MathAbs(OrderGetDouble(ORDER_TP) - tp) > point * 0.5)
      if(CanRetry(st) && !g_trade.OrderModify(lo, price, sl, tp, ORDER_TIME_GTC, 0))
         MarkFailed(st);
  }

//+------------------------------------------------------------------+
//| Dong/huy nhung gi nguon khong con                                |
//+------------------------------------------------------------------+
void CloseOrphans()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      ulong st = TicketFromTag(PositionGetString(POSITION_COMMENT));
      if(st != 0 && !SourceHas(st))
        {
         bool ok = g_trade.PositionClose(t);
         PrintFormat("[CopyReceiver] Nguon da dong CP%I64u -> dong local (%s)", st, ok ? "OK" : "LOI");
        }
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0 || (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagic)
         continue;
      ulong st = TicketFromTag(OrderGetString(ORDER_COMMENT));
      if(st != 0 && !SourceHas(st))
        {
         bool ok = g_trade.OrderDelete(t);
         PrintFormat("[CopyReceiver] Nguon da huy lenh cho CP%I64u -> huy local (%s)", st, ok ? "OK" : "LOI");
        }
     }
  }

//+------------------------------------------------------------------+
void Sync()
  {
   if(!ReadSource())
      return;
   if(TimeLocal() - mTs > InpMaxStaleSec)
     {
      if(TimeLocal() - g_lastStaleMsg > 60)
        {
         PrintFormat("[CopyReceiver] File nguon da cu %d giay - CopySender con chay khong? Tam dung (khong dong lenh).",
                     (int)(TimeLocal() - mTs));
         g_lastStaleMsg = TimeLocal();
        }
      return;
     }
   if(!g_ready)
     {
      ArrayResize(g_skip, 0);
      if(!InpCopyExisting)
         ArrayCopy(g_skip, mTicket);
      g_ready = true;
      PrintFormat("[CopyReceiver] Ket noi nguon OK (balance nguon %.2f). Bo qua %d lenh co san.", mBalance, ArraySize(g_skip));
     }
   for(int i = 0; i < ArraySize(mTicket); i++)
     {
      if(InList(g_skip, mTicket[i]))
         continue;
      if(mKind[i] == "P")
         SyncPosition(i);
      else if(InpCopyPending)
         SyncOrder(i);
     }
   CloseOrphans();
  }

int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      Print("[CopyReceiver] CHU Y: chua bat Algo Trading hoac chua tick 'Allow Algo Trading' -> se khong vao lenh duoc.");
   PrintFormat("[CopyReceiver] Tai khoan %I64d, doc kenh '%s', hau to symbol '%s'",
               AccountInfoInteger(ACCOUNT_LOGIN), InpChannel, InpSymbolSuffix);
   g_ready = false;
   EventSetMillisecondTimer(MathMax(50, InpIntervalMs));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { EventKillTimer(); }
void OnTimer()                  { Sync(); }
void OnTick()                   {}
//+------------------------------------------------------------------+
