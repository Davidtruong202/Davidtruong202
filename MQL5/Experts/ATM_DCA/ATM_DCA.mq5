//+------------------------------------------------------------------+
//|                                                    ATM_DCA.mq5   |
//| Bot DCA dung logic vao lenh cua ban sao ATM SCALP AI lam lenh dau|
//|                                                                  |
//| Lenh dau ro (BUY, SELL doi xung) khi nen vua dong thoa:          |
//|   EMA21 > EMA55, ADX(14) Wilder > 20, close > EMA9, EMA9 > EMA21, |
//|   nen tang, close > high nen truoc, 7 nen gan nhat co low <= EMA14|
//| Gia di nguoc Buoc x ATR thi nhoi lop moi, lot x He so.           |
//| Ca ro dong khi gia ve gia trung binh + TP x ATR.                 |
//| Bao ve: so lop toi da, cat lo sau lop cuoi, cat theo % equity.   |
//|                                                                  |
//| ATR = ATR(14) kieu Wilder cua nen da dong luc mo lenh dau, luu   |
//| trong comment lenh nen EA khoi dong lai van dung dung buoc luoi. |
//+------------------------------------------------------------------+
#property copyright "ATM DCA"
#property version   "1.00"
#include <Trade/Trade.mqh>

input group "Tín hiệu (logic ATM SCALP AI)"
input double InpAdxMin        = 20;            // ADX tối thiểu
input int    InpPullbackBars  = 7;             // Cửa sổ nhịp hồi về EMA14 (số nến)
input bool   InpHourFilter    = false;         // Chỉ mở rổ trong khung giờ server
input int    InpHourStart     = 0;             // Giờ bắt đầu (tính cả)
input int    InpHourEnd       = 7;             // Giờ kết thúc (không tính)
input bool   InpHtfFilter     = false;         // Khung lớn cùng chiều (EMA21 vs EMA55)
input ENUM_TIMEFRAMES InpHtf  = PERIOD_H1;     // Khung lớn

input group "Lưới DCA"
input double InpStartLot      = 0.01;          // Lot lệnh đầu
input double InpLotMult       = 1.5;           // Hệ số nhân lot mỗi lớp
input double InpMaxLot        = 1.0;           // Lot tối đa 1 lệnh
input int    InpMaxLayers     = 6;             // Số lớp tối đa (tính cả lệnh đầu)
input double InpStepAtr       = 2.0;           // Bước lưới = x lần ATR
input double InpStepMult      = 1.0;           // Hệ số giãn bước mỗi lớp (1 = đều)
input bool   InpAddOnSignal   = false;         // Chỉ nhồi khi có tín hiệu cùng chiều mới
input double InpTpAtr         = 1.0;           // TP rổ = giá trung bình + x lần ATR

input group "Bảo vệ"
input double InpCutAtr        = 2.0;           // Cắt cả rổ khi giá đi tiếp x ATR sau lớp cuối (0 = không cắt)
input double InpMaxDDPercent  = 30;            // Cắt cả rổ khi lỗ thả nổi >= x% balance (0 = tắt)
input bool   InpCloseOnRev    = false;         // Đóng rổ khi có tín hiệu ngược chiều
input int    InpMaxSpread     = 0;             // Spread tối đa (point, 0 = không lọc)
input bool   InpServerTpSl    = true;          // Đặt TP/SL rổ lên server (phòng mất kết nối)

input group "Khác"
input long   InpMagic         = 26101301;      // Magic number
input bool   InpDrawLines     = true;          // Vẽ đường giá TB / TP / lớp kế / cắt lỗ

CTrade   trade;
int      hE9 = INVALID_HANDLE, hE14 = INVALID_HANDLE, hE21 = INVALID_HANDLE, hE55 = INVALID_HANDLE;
int      hADX = INVALID_HANDLE, hH21 = INVALID_HANDLE, hH55 = INVALID_HANDLE;
datetime g_lastBar = 0;
string   PFX = "ATMDCA_";

struct Basket
  {
   int    n, dir;
   double lots, avg, last, atr;
  };

//+------------------------------------------------------------------+
double AtrWilder()
  {
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int N = 300;
   if(CopyRates(_Symbol, _Period, 1, N, r) != N) return 0;
   double atr = 0, s = 0;
   for(int i = 0; i < N; i++)
     {
      double tr = (i == 0) ? r[i].high - r[i].low
                           : MathMax(r[i].high, r[i - 1].close) - MathMin(r[i].low, r[i - 1].close);
      if(i < 14) { s += tr; atr = s / (i + 1); }
      else       atr = (atr * 13.0 + tr) / 14.0;
     }
   return atr;
  }

//--- tin hieu tai nen vua dong: +1 BUY, -1 SELL, 0
int Signal()
  {
   int K = MathMax(InpPullbackBars, 2);
   MqlRates r[];
   double e9[1], e14[], e21[1], e55[1], adx[1];
   ArraySetAsSeries(r, true);
   ArraySetAsSeries(e14, true);
   if(CopyRates(_Symbol, _Period, 1, K, r) != K) return 0;
   if(CopyBuffer(hE14, 0, 1, K, e14) != K) return 0;
   if(CopyBuffer(hE9, 0, 1, 1, e9) != 1 || CopyBuffer(hE21, 0, 1, 1, e21) != 1 ||
      CopyBuffer(hE55, 0, 1, 1, e55) != 1 || CopyBuffer(hADX, 0, 1, 1, adx) != 1) return 0;
   for(int d = 1; d >= -1; d -= 2)
     {
      if((e21[0] - e55[0]) * d <= 0) continue;
      if(adx[0] <= InpAdxMin) continue;
      if((r[0].close - e9[0]) * d <= 0) continue;
      if((e9[0] - e21[0]) * d <= 0) continue;
      if((r[0].close - r[0].open) * d <= 0) continue;
      if(d > 0 ? r[0].close <= r[1].high : r[0].close >= r[1].low) continue;
      bool pull = false;
      for(int j = 0; j < InpPullbackBars && !pull; j++)
         pull = d > 0 ? r[j].low <= e14[j] : r[j].high >= e14[j];
      if(!pull) continue;
      return d;
     }
   return 0;
  }

bool PassFilters(const int dir)
  {
   if(InpHourFilter)
     {
      MqlDateTime mt;
      TimeToStruct(TimeCurrent(), mt);
      bool in = InpHourStart <= InpHourEnd ? (mt.hour >= InpHourStart && mt.hour < InpHourEnd)
                                           : (mt.hour >= InpHourStart || mt.hour < InpHourEnd);
      if(!in) return false;
     }
   if(InpHtfFilter)
     {
      double a[1], b[1];
      if(CopyBuffer(hH21, 0, 1, 1, a) != 1 || CopyBuffer(hH55, 0, 1, 1, b) != 1) return false;
      if((a[0] - b[0]) * dir <= 0) return false;
     }
   return true;
  }

bool SpreadOk()
  {
   return InpMaxSpread <= 0 || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpread;
  }

double NormLot(double lot)
  {
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMin(lot, InpMaxLot);
   lot = MathFloor(lot / st + 1e-9) * st;
   return MathMax(mn, MathMin(mx, lot));
  }

//--- doc ro hien tai tu cac lenh dang mo
void ReadBasket(Basket &b)
  {
   ZeroMemory(b);
   double pv = 0;
   datetime first = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      int d = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      double v = PositionGetDouble(POSITION_VOLUME), p = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      b.n++; b.dir = d; b.lots += v; pv += p * v;
      if(b.n == 1 || (d > 0 ? p < b.last : p > b.last)) b.last = p;
      if(first == 0 || t < first)
        {
         first = t;
         string cm = PositionGetString(POSITION_COMMENT);
         int k = StringFind(cm, "|");
         if(k >= 0) b.atr = StringToDouble(StringSubstr(cm, k + 1));
        }
     }
   if(b.n > 0) b.avg = pv / b.lots;
   if(b.n > 0 && b.atr <= 0) b.atr = AtrWilder();   // comment bi san cat mat
  }

//--- khoang cach tu lop k (1 = lenh dau) toi lop k+1
double StepDist(const Basket &b) { return InpStepAtr * b.atr * MathPow(InpStepMult, b.n - 1); }
double TpPrice(const Basket &b)  { return b.avg + b.dir * InpTpAtr * b.atr; }
double CutPrice(const Basket &b) { return b.last - b.dir * InpCutAtr * b.atr; }

void CloseAll(const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      trade.PositionClose(tk);
     }
   Print("[ATM DCA] Dong ro: ", why);
   ObjectsDeleteAll(0, PFX);
  }

void SyncTpSl(const Basket &b)
  {
   if(!InpServerTpSl || b.n == 0) return;
   double tp = NormalizeDouble(TpPrice(b), _Digits);
   double sl = (InpCutAtr > 0 && b.n >= InpMaxLayers) ? NormalizeDouble(CutPrice(b), _Digits) : 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(MathAbs(PositionGetDouble(POSITION_TP) - tp) > _Point || MathAbs(PositionGetDouble(POSITION_SL) - sl) > _Point)
         trade.PositionModify(tk, sl, tp);
     }
  }

void HLine(const string nm, const double p, const color cl, const ENUM_LINE_STYLE st)
  {
   string id = PFX + nm;
   if(p <= 0) { ObjectDelete(0, id); return; }
   if(ObjectFind(0, id) < 0) ObjectCreate(0, id, OBJ_HLINE, 0, 0, p);
   ObjectSetDouble(0, id, OBJPROP_PRICE, p);
   ObjectSetInteger(0, id, OBJPROP_COLOR, cl);
   ObjectSetInteger(0, id, OBJPROP_STYLE, st);
   ObjectSetString(0, id, OBJPROP_TOOLTIP, nm + " " + DoubleToString(p, _Digits));
  }

void DrawBasket(const Basket &b)
  {
   if(!InpDrawLines) return;
   if(b.n == 0) { ObjectsDeleteAll(0, PFX); return; }
   HLine("TB", b.avg, clrWhite, STYLE_SOLID);
   HLine("TP", TpPrice(b), clrLime, STYLE_DASH);
   HLine("Lop_ke", b.n < InpMaxLayers ? b.last - b.dir * StepDist(b) : 0, clrOrange, STYLE_DOT);
   HLine("Cat_lo", InpCutAtr > 0 && b.n >= InpMaxLayers ? CutPrice(b) : 0, clrRed, STYLE_DASH);
  }

bool Open(const int dir, const double lot, const double atr, const int layer)
  {
   string cm = StringFormat("ATMDCA L%d|%.5f", layer, atr);
   bool ok = dir > 0 ? trade.Buy(NormLot(lot), _Symbol, 0, 0, 0, cm) : trade.Sell(NormLot(lot), _Symbol, 0, 0, 0, cm);
   if(!ok) PrintFormat("[ATM DCA] Loi mo lenh lop %d: %d %s", layer, trade.ResultRetcode(), trade.ResultRetcodeDescription());
   return ok;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   hE9  = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
   hE14 = iMA(_Symbol, _Period, 14, 0, MODE_EMA, PRICE_CLOSE);
   hE21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   hE55 = iMA(_Symbol, _Period, 55, 0, MODE_EMA, PRICE_CLOSE);
   hADX = iADXWilder(_Symbol, _Period, 14);
   if(hE9 == INVALID_HANDLE || hE14 == INVALID_HANDLE || hE21 == INVALID_HANDLE || hE55 == INVALID_HANDLE || hADX == INVALID_HANDLE)
      return INIT_FAILED;
   if(InpHtfFilter)
     {
      hH21 = iMA(_Symbol, InpHtf, 21, 0, MODE_EMA, PRICE_CLOSE);
      hH55 = iMA(_Symbol, InpHtf, 55, 0, MODE_EMA, PRICE_CLOSE);
      if(hH21 == INVALID_HANDLE || hH55 == INVALID_HANDLE) return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(50);
   g_lastBar = iTime(_Symbol, _Period, 0);   // khong vao lenh theo nen cu khi vua gan EA
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   int h[7];
   h[0] = hE9; h[1] = hE14; h[2] = hE21; h[3] = hE55; h[4] = hADX; h[5] = hH21; h[6] = hH55;
   for(int i = 0; i < 7; i++)
      if(h[i] != INVALID_HANDLE) IndicatorRelease(h[i]);
  }

void OnTick()
  {
   bool newBar = false;
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt != g_lastBar) { g_lastBar = bt; newBar = true; }
   int sig = newBar ? Signal() : 0;

   Basket b;
   ReadBasket(b);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(b.n > 0)
     {
      double px = b.dir > 0 ? bid : ask;                          // gia dong lenh
      //--- 1) TP ro
      if((px - TpPrice(b)) * b.dir >= 0) { CloseAll("cham TP ro"); return; }
      //--- 2) cat lo theo % balance
      if(InpMaxDDPercent > 0)
        {
         double fl = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
            if(PositionGetTicket(i) != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
               fl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(-fl >= AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDDPercent / 100.0)
           { CloseAll(StringFormat("lo tha noi %.2f >= %.0f%% balance", fl, InpMaxDDPercent)); return; }
        }
      //--- 3) cat lo sau lop cuoi
      if(InpCutAtr > 0 && b.n >= InpMaxLayers && (px - CutPrice(b)) * b.dir <= 0) { CloseAll("cat lo sau lop cuoi"); return; }
      //--- 4) tin hieu nguoc
      if(InpCloseOnRev && sig == -b.dir) { CloseAll("tin hieu nguoc chieu"); b.n = 0; }
     }

   if(b.n > 0)
     {
      //--- 5) nhoi lop
      double pin = b.dir > 0 ? ask : bid;                         // gia vao lenh
      if(b.n < InpMaxLayers && (b.last - pin) * b.dir >= StepDist(b) && SpreadOk() && (!InpAddOnSignal || sig == b.dir))
        {
         if(Open(b.dir, InpStartLot * MathPow(InpLotMult, b.n), b.atr, b.n + 1))
            ReadBasket(b);
        }
      SyncTpSl(b);
      DrawBasket(b);
      return;
     }

   //--- 6) mo ro moi
   if(sig != 0 && SpreadOk() && PassFilters(sig))
     {
      double atr = AtrWilder();
      if(atr <= 0) return;
      if(Open(sig, InpStartLot, atr, 1))
        {
         ReadBasket(b);
         SyncTpSl(b);
         DrawBasket(b);
        }
     }
  }
//+------------------------------------------------------------------+
