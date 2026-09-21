//+------------------------------------------------------------------+
//|                                        RsiBbDivergenceEA.mq5     |
//|  EA TU VIET, dua theo PPGD "RSI(10) + Bollinger Bands" cua kenh   |
//|  "Tho dao vang" (Gold) -- bro chia se 7 anh chart thuc te (khong  |
//|  co tai lieu/source chinh thuc), minh tu quan sat va suy ra quy   |
//|  tac tu do. Ghi ro o day de ai doc code sau nay hieu dung nguon   |
//|  goc va gioi han cua logic.                                       |
//|                                                                    |
//|  QUY TAC QUAN SAT DUOC (5/7 anh la kieu nay -- PHAM VI v1.00):    |
//|   - Phan ky GIAM (bearish divergence): dinh GIA sau CAO HON dinh  |
//|     truoc, nhung dinh RSI sau THAP HON dinh truoc => Sell.         |
//|   - Phan ky TANG (bullish divergence): day GIA sau THAP HON day   |
//|     truoc, nhung day RSI sau CAO HON day truoc => Buy.             |
//|   - Bollinger Bands dung lam BOI CANH xac nhan: dinh/day phai     |
//|     cham hoac vuot qua dai BB tuong ung (tren/duoi) moi duoc tinh |
//|     la 1 "swing" hop le -- khop voi moi anh chart bro gui (dinh    |
//|     Sell deu nam sat/tren dai tren, day Buy deu nam sat/duoi dai   |
//|     duoi).                                                         |
//|   - Da khung: anh chart cho thay tin hieu phan ky doi khi lay tu   |
//|     M15 nhung vao lenh o M5 -- v1.00 CHUA lam da khung (chi dung   |
//|     dung 1 khung EA dang gan), de tranh phuc tap hoa qua som.      |
//|                                                                    |
//|  CHUA LAM O v1.00 (de danh cho ban sau, can them du lieu moi lam   |
//|  dung): che do "tu duy nguoc" -- tiep tuc theo xu huong khi gia    |
//|  dang "bam dai" BB (band walk) MA KHONG co phan ky ro rang (2/7    |
//|  anh bro gui la kieu nay). Day la 1 khai niem tinh te hon (phan    |
//|  biet "dang bam dai, con manh" voi "sap kiet suc, sap dao chieu")  |
//|  ma chi 2 vi du la chua du de rut ra cong thuc chac chan -- lam au |
//|  se de sai, anh huong tien that, nen CO CHU DICH de lai.           |
//|                                                                    |
//|  Khong co trinh bien dich MQL5 that trong moi truong nay -- code   |
//|  nay CHUA duoc compile/chay thu thuc te. Da tu kiem tra can bang   |
//|  ngoac/dau ngoac va thu tu khai bao ham bang script rieng truoc    |
//|  khi giao (xem quy trinh da dung cho ca EMACrossClone/EA truoc do).|
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// 1. RSI + Bollinger Bands
//====================================================================
input int    InpRSIPeriod   = 10;    // Chu ky RSI -- dung dung RSI(10) nhu trong moi anh chart bro gui
input int    InpBBPeriod    = 20;    // Chu ky Bollinger Bands (khong thay ghi ro trong anh, dung chuan pho bien)
input double InpBBDeviation = 2.0;   // Do lech chuan Bollinger Bands

// === 2. Phat hien Swing (dinh/day cuc bo tren gia, kieu "fractal") ===
input int    InpSwingLookback        = 3;   // So nen 2 BEN (truoc + sau) de xac nhan 1 dinh/day cuc bo
input int    InpMaxSwingSearchBars   = 150; // Quet lui toi da bao nhieu nen de tim 2 swing GAN NHAT
input int    InpMinBarsBetweenSwings = 5;   // Khoang cach toi thieu (nen) giua 2 swing lien tiep, tranh dem 2 dinh/day qua sat nhau thanh 2 swing rieng
input bool   InpRequireBandTouch     = true;  // Bat buoc dinh/day phai cham/vuot dai BB tuong ung moi tinh la swing hop le (dung theo moi anh chart bro gui)
input double InpBandTouchBufferATR   = 0.15;  // Cho phep "gan dai" trong pham vi bao nhieu x ATR (tranh doi cham CHINH XAC tung pixel gia)

// === 3. Risk management ===
input bool   InpUseRiskPercent = true;   // true: tu tinh lot theo % Balance; false: dung InpLotSize co dinh
input double InpRiskPercent    = 2.0;    // % Balance chap nhan mat neu dinh dung SL
input double InpLotSize        = 0.01;   // Lot co dinh (chi dung khi InpUseRiskPercent=false)
input double InpMaxLotCap      = 1.0;    // Chan lot toi da (an toan, phong tinh sai/Balance qua lon)
input int    InpATRPeriod      = 14;     // Chu ky ATR (dung cho buffer SL va nguong cham dai BB)
input double InpSLBufferATR    = 0.3;    // SL dat QUA KHOI diem swing bao nhieu x ATR (them dem an toan, tranh bi quet SL ngay sat swing)
input double InpRR             = 2.0;    // TP = khoang cach SL x he so nay (Risk:Reward)

// === 4. Loc an toan ===
input double InpMaxSpreadUSD = 0.0;    // Bo qua vao lenh moi neu spread > gia tri nay ($ price distance). 0 = tat
input int    InpMagic        = 990100; // Magic number rieng cua EA nay -- doi neu chay song song EA khac tren cung Symbol
input double InpSlippageUSD  = 0.30;   // Do lech gia toi da chap nhan khi khop lenh ($ price distance)
input int    InpMinBarsBetweenSignals = 5; // So nen toi thieu giua 2 lenh MOI lien tiep (chong nhieu)

//====================================================================
// Globals
//====================================================================
int g_RsiHandle  = INVALID_HANDLE;
int g_BbHandle   = INVALID_HANDLE;
int g_AtrHandle  = INVALID_HANDLE;

datetime g_LastBarTime = 0;
int      g_Slippage    = 1;

// [chong lap tin hieu] luu THOI GIAN cua swing GAN NHAT da tung dung de vao lenh, cho tung huong rieng --
// chi vao lenh MOI khi tim thay 1 swing MOI (thoi gian khac swing da dung lan truoc), tranh vao lai lien tuc
// cung 1 cap swing suot nhieu nen lien tiep (vi khi chua co swing moi hon xuat hien, ham quet swing van tra
// ve dung cap swing cu do moi lan goi).
datetime g_LastSellSwingTime = 0;
datetime g_LastBuySwingTime  = 0;
int      g_LastEntryBarIndex = -1000000; // ap dung InpMinBarsBetweenSignals (dem theo so nen da xu ly, khong theo shift)
int      g_BarsProcessed     = 0;

//--- CHAN DOAN: dem so lan phat hien phan ky (truoc khi loc trung lap/khoang cach) va so lan xac nhan vao lenh
int g_DbgBearishSeen = 0, g_DbgBullishSeen = 0, g_DbgBuyOpened = 0, g_DbgSellOpened = 0;
int g_DbgBlockedSpread = 0, g_DbgBlockedBarsWait = 0, g_DbgBlockedPyramid = 0, g_DbgOrderSendFail = 0;

struct SwingPoint
{
   int      shift;
   double   price;
   double   rsi;
   datetime time;
};

//+------------------------------------------------------------------+
double CurrentBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double CurrentAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double CurrentSpreadPrice() { return CurrentAsk() - CurrentBid(); }

int PriceDistanceToPoints(double priceDistance)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if (point <= 0) return 1;
   return (int)MathRound(priceDistance / point);
}

//+------------------------------------------------------------------+
//| Quet lui toi da InpMaxSwingSearchBars nen de tim 2 dinh (swing    |
//| high) GAN NHAT hop le -- outSwings[0] la swing MOI NHAT (gan hien |
//| tai nhat), outSwings[1] la swing truoc do. Tra ve so swing tim    |
//| duoc (0, 1, hoac 2).                                              |
//+------------------------------------------------------------------+
int CollectSwingHighs(const double &high[], const double &rsiArr[], const double &bbUpper[], const double &atrArr[],
                       const datetime &time[], int scanBars, SwingPoint &outSwings[])
{
   int count = 0;
   ArrayResize(outSwings, 0);
   int lastAcceptedShift = -1000000;

   int maxShift = MathMin(scanBars, ArraySize(high) - InpSwingLookback - 1);

   for (int shift = InpSwingLookback; shift <= maxShift && count < 2; shift++)
   {
      bool isHigh = true;
      for (int j = 1; j <= InpSwingLookback; j++)
      {
         if (high[shift] < high[shift - j] || high[shift] < high[shift + j]) { isHigh = false; break; }
      }
      if (!isHigh) continue;

      if (InpRequireBandTouch)
      {
         double buf = (MathIsValidNumber(atrArr[shift]) ? atrArr[shift] * InpBandTouchBufferATR : 0.0);
         if (high[shift] < bbUpper[shift] - buf) continue; // dinh chua cham toi gan dai tren, khong tinh la swing hop le
      }

      if (shift - lastAcceptedShift < InpMinBarsBetweenSwings) continue; // qua gan swing MOI HON vua nhan, bo qua de tranh dem trung

      ArrayResize(outSwings, count + 1);
      outSwings[count].shift = shift;
      outSwings[count].price = high[shift];
      outSwings[count].rsi   = rsiArr[shift];
      outSwings[count].time  = time[shift];
      lastAcceptedShift = shift;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Doi xung voi CollectSwingHighs() nhung cho day (swing low), dung  |
//| dai DUOI Bollinger Bands lam boi canh xac nhan.                    |
//+------------------------------------------------------------------+
int CollectSwingLows(const double &low[], const double &rsiArr[], const double &bbLower[], const double &atrArr[],
                      const datetime &time[], int scanBars, SwingPoint &outSwings[])
{
   int count = 0;
   ArrayResize(outSwings, 0);
   int lastAcceptedShift = -1000000;

   int maxShift = MathMin(scanBars, ArraySize(low) - InpSwingLookback - 1);

   for (int shift = InpSwingLookback; shift <= maxShift && count < 2; shift++)
   {
      bool isLow = true;
      for (int j = 1; j <= InpSwingLookback; j++)
      {
         if (low[shift] > low[shift - j] || low[shift] > low[shift + j]) { isLow = false; break; }
      }
      if (!isLow) continue;

      if (InpRequireBandTouch)
      {
         double buf = (MathIsValidNumber(atrArr[shift]) ? atrArr[shift] * InpBandTouchBufferATR : 0.0);
         if (low[shift] > bbLower[shift] + buf) continue; // day chua cham toi gan dai duoi, khong tinh la swing hop le
      }

      if (shift - lastAcceptedShift < InpMinBarsBetweenSwings) continue;

      ArrayResize(outSwings, count + 1);
      outSwings[count].shift = shift;
      outSwings[count].price = low[shift];
      outSwings[count].rsi   = rsiArr[shift];
      outSwings[count].time  = time[shift];
      lastAcceptedShift = shift;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Tim vi the dang mo CUA CHINH EA NAY (Symbol + Magic). Thiet ke    |
//| chi giu 1 lenh tai 1 thoi diem (khong pyramid).                    |
//+------------------------------------------------------------------+
ulong GetOpenPosition(long &outType)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      outType = PositionGetInteger(POSITION_TYPE);
      return ticket;
   }
   outType = -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Tinh lot theo % Risk -- gan giong CalcRiskLot() da dung trong      |
//| EMACrossCloneEA, viet lai o day de file nay DOC LAP, khong phu     |
//| thuoc file khac.                                                    |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if (lotStep <= 0) lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = MathMin(lot, InpMaxLotCap);
   return NormalizeDouble(lot, 2);
}

double CalcRiskLot(double slDistancePrice)
{
   if (!InpUseRiskPercent || slDistancePrice <= 0) return NormalizeLot(InpLotSize);

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (InpRiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickValue <= 0 || tickSize <= 0) return NormalizeLot(InpLotSize);

   double lossPerLot = (slDistancePrice / tickSize) * tickValue;
   if (lossPerLot <= 0) return NormalizeLot(InpLotSize);

   double lot = riskMoney / lossPerLot;
   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_Slippage = PriceDistanceToPoints(InpSlippageUSD);
   if (g_Slippage <= 0) g_Slippage = 1;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(g_Slippage);

   g_RsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_BbHandle  = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_AtrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   if (g_RsiHandle == INVALID_HANDLE || g_BbHandle == INVALID_HANDLE || g_AtrHandle == INVALID_HANDLE)
   {
      Alert("RsiBbDivergenceEA: khong tao duoc 1 trong cac indicator handle (RSI/Bands/ATR). EA se khong chay.");
      return(INIT_FAILED);
   }

   g_LastBarTime = 0; // force-align vao nen moi ngay tick dau tien

   Print("RsiBbDivergenceEA v1.00: OnInit THANH CONG -- RSI/Bands/ATR handle deu tao duoc. EA bat dau chay tu day.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("RsiBbDivergenceEA: [CHAN DOAN v1.00] Tong ket khi ket thuc -- ",
         "so nen da xu ly=", g_BarsProcessed, " | ",
         "phan ky GIAM (bearish) thay=", g_DbgBearishSeen, " (Sell mo thanh cong=", g_DbgSellOpened, ") | ",
         "phan ky TANG (bullish) thay=", g_DbgBullishSeen, " (Buy mo thanh cong=", g_DbgBuyOpened, ")");
   Print("RsiBbDivergenceEA: [CHAN DOAN v1.00] Chi tiet ly do BI CHAN -- ",
         "spread vuot nguong=", g_DbgBlockedSpread, " | ",
         "chua du InpMinBarsBetweenSignals=", g_DbgBlockedBarsWait, " | ",
         "dang co lenh mo (khong pyramid)=", g_DbgBlockedPyramid, " | ",
         "trade.Buy()/Sell() bi tu choi=", g_DbgOrderSendFail);

   if (g_RsiHandle != INVALID_HANDLE) IndicatorRelease(g_RsiHandle);
   if (g_BbHandle  != INVALID_HANDLE) IndicatorRelease(g_BbHandle);
   if (g_AtrHandle != INVALID_HANDLE) IndicatorRelease(g_AtrHandle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (barTime == 0 || barTime == g_LastBarTime) return;
   g_LastBarTime = barTime;
   g_BarsProcessed++;

   int needBars = InpMaxSwingSearchBars + 2 * InpSwingLookback + 10;

   double high[], low[], rsiArr[], bbUpper[], bbLower[], atrArr[];
   datetime timeArr[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(rsiArr, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(atrArr, true);
   ArraySetAsSeries(timeArr, true);

   if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needBars, high) < needBars) return;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needBars, low) < needBars) return;
   if (CopyTime(_Symbol, PERIOD_CURRENT, 0, needBars, timeArr) < needBars) return;
   if (CopyBuffer(g_RsiHandle, 0, 0, needBars, rsiArr) < needBars) return;
   if (CopyBuffer(g_BbHandle, 1, 0, needBars, bbUpper) < needBars) return; // BANDS_UPPER
   if (CopyBuffer(g_BbHandle, 2, 0, needBars, bbLower) < needBars) return; // BANDS_LOWER
   if (CopyBuffer(g_AtrHandle, 0, 0, needBars, atrArr) < needBars) return;

   SwingPoint highs[], lows[];
   int highCount = CollectSwingHighs(high, rsiArr, bbUpper, atrArr, timeArr, InpMaxSwingSearchBars, highs);
   int lowCount  = CollectSwingLows(low, rsiArr, bbLower, atrArr, timeArr, InpMaxSwingSearchBars, lows);

   bool bearishDivergence = false;
   bool bullishDivergence = false;

   if (highCount == 2)
   {
      bool priceHigherHigh = highs[0].price > highs[1].price;
      bool rsiLowerHigh    = highs[0].rsi   < highs[1].rsi;
      if (priceHigherHigh && rsiLowerHigh)
      {
         bearishDivergence = true;
         g_DbgBearishSeen++;
      }
   }

   if (lowCount == 2)
   {
      bool priceLowerLow = lows[0].price < lows[1].price;
      bool rsiHigherLow  = lows[0].rsi   > lows[1].rsi;
      if (priceLowerLow && rsiHigherLow)
      {
         bullishDivergence = true;
         g_DbgBullishSeen++;
      }
   }

   long  openType   = -1;
   ulong openTicket = GetOpenPosition(openType);

   bool spreadOK = (InpMaxSpreadUSD <= 0.0) || (CurrentSpreadPrice() <= InpMaxSpreadUSD);
   bool waitOK   = (g_BarsProcessed - g_LastEntryBarIndex >= InpMinBarsBetweenSignals);

   // --- Ban Sell (phan ky GIAM) ---
   if (bearishDivergence && highs[0].time != g_LastSellSwingTime)
   {
      if (openTicket != 0)
      {
         g_DbgBlockedPyramid++;
      }
      else if (!spreadOK)
      {
         g_DbgBlockedSpread++;
      }
      else if (!waitOK)
      {
         g_DbgBlockedBarsWait++;
      }
      else
      {
         double atrNow = atrArr[0];
         double slBuffer = (MathIsValidNumber(atrNow) && atrNow > 0) ? atrNow * InpSLBufferATR : 0.0;
         double entryPrice = CurrentBid();
         double slPrice = highs[0].price + slBuffer;
         double slDist  = slPrice - entryPrice;

         if (slDist > 0)
         {
            double tpPrice = entryPrice - slDist * InpRR;
            double lot = CalcRiskLot(slDist);

            if (trade.Sell(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA Sell"))
            {
               g_LastSellSwingTime = highs[0].time;
               g_LastEntryBarIndex = g_BarsProcessed;
               g_DbgSellOpened++;
            }
            else
            {
               g_DbgOrderSendFail++;
               Print("RsiBbDivergenceEA: trade.Sell() that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }
   }

   // --- Ban Buy (phan ky TANG) ---
   if (bullishDivergence && lows[0].time != g_LastBuySwingTime)
   {
      if (openTicket != 0)
      {
         g_DbgBlockedPyramid++;
      }
      else if (!spreadOK)
      {
         g_DbgBlockedSpread++;
      }
      else if (!waitOK)
      {
         g_DbgBlockedBarsWait++;
      }
      else
      {
         double atrNow = atrArr[0];
         double slBuffer = (MathIsValidNumber(atrNow) && atrNow > 0) ? atrNow * InpSLBufferATR : 0.0;
         double entryPrice = CurrentAsk();
         double slPrice = lows[0].price - slBuffer;
         double slDist  = entryPrice - slPrice;

         if (slDist > 0)
         {
            double tpPrice = entryPrice + slDist * InpRR;
            double lot = CalcRiskLot(slDist);

            if (trade.Buy(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA Buy"))
            {
               g_LastBuySwingTime = lows[0].time;
               g_LastEntryBarIndex = g_BarsProcessed;
               g_DbgBuyOpened++;
            }
            else
            {
               g_DbgOrderSendFail++;
               Print("RsiBbDivergenceEA: trade.Buy() that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
