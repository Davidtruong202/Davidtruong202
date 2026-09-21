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
//|  v1.01: bro gui them 5 anh chart khac (cung kenh "Tho dao vang"),  |
//|  cho thay day KHONG PHAI 1 cong thuc duy nhat ma la nhieu setup    |
//|  khac nhau ho dang chia se moi ngay (RSI period doi 10/14, co luc  |
//|  dung BB co luc khong). Gop lai thanh 2 CHE DO doc lap trong CUNG  |
//|  1 EA nay (theo yeu cau "tong hop luon vao 1 EA"):                 |
//|                                                                     |
//|  CHE DO 1 (Phan ky, giu nguyen tu v1.00): nhu mo ta o tren. THEM   |
//|  tuy chon InpRequireReversalCandle -- neu bat, bat buoc dung nen    |
//|  swing phai la nen dao chieu (Bullish/Bearish Engulfing hoac Pin    |
//|  Bar/Hammer) moi xac nhan tin hieu -- mac dinh TAT de KHONG doi     |
//|  hanh vi da test cua v1.00.                                         |
//|                                                                     |
//|  CHE DO 2 (MOI -- "Thuan theo xu huong RSI + nen pha vo", tu 3/5    |
//|  anh moi): day CHINH LA y tuong "tu duy nguoc" da noi se de lai o   |
//|  v1.00 (tiep tuc theo xu huong thay vi fade), nhung dung tieu chi   |
//|  RO RANG/do luong duoc thay vi khai niem mo ho "bam dai BB":         |
//|   - RSI phai giu LIEN TUC tren 50 (huong tang) hoac duoi 50 (huong  |
//|     giam) it nhat InpTrendRsiBars nen gan nhat => xac nhan "dang co  |
//|     xu huong ro rang".                                               |
//|   - Dong thoi phai co 1 "nen pha vo": than nen (body) lon hon        |
//|     InpBreakoutBodyMult lan than nen trung binh cua InpBreakoutBody-  |
//|     AvgBars nen truoc, VA dong cua vuot qua dinh/day cao nhat/thap    |
//|     nhat cua InpBreakoutRangeBars nen truoc do (pha vo vung tich luy).|
//|   - Neu ca 2 dieu kien tren dung => vao lenh THEO xu huong (Buy neu   |
//|     tang, Sell neu giam) -- NGUOC HAN voi Che do 1 (fade/dao chieu). |
//|   - Che do 2 KHONG dung Bollinger Bands (dung tieu chi rieng), va    |
//|     KHONG dung swing/phan kỳ -- hoan toan doc lap voi Che do 1.       |
//|                                                                       |
//|  Uu tien khi ca 2 che do cung ra tin hieu trong CUNG 1 nen: Che do   |
//|  1 (phan ky) xu ly TRUOC, Che do 2 CHI vao lenh neu Che do 1 chua     |
//|  vao lenh nao trong chinh nen do (xem alreadyActedThisTick trong      |
//|  OnTick()) -- tranh mo 2 lenh nguoc huong nhau tren cung 1 nen.       |
//|                                                                       |
//|  Ca 2 che do co the BAT/TAT rieng (InpUseDivergenceMode/InpUse-      |
//|  TrendBreakoutMode), dung chung risk management (SL/TP/lot) de don   |
//|  gian, chi khac diem tham chieu SL (swing point vs. dinh/day nen pha |
//|  vo).                                                                 |
//+------------------------------------------------------------------+
//|  v1.02: theo yeu cau "moi PP deu co tag rieng de nhan biet lai lo,   |
//|  them len bang co input bat tat":                                    |
//|   - Comment() cua tung lenh gio mang tag PHAN BIET ro rang: Che do 1 |
//|     dat comment "RsiBbDivergenceEA PP1-Buy"/"PP1-Sell", Che do 2 dat |
//|     "RsiBbDivergenceEA PP2-Buy"/"PP2-Sell" -- doc duoc ca tren MT5   |
//|     (cot Comment trong tab Trade/History) lan trong code.            |
//|   - Ham moi CalcDayProfitUSD(tagFilter): tinh lai/lo TRONG NGAY (da  |
//|     dong + dang mo) loc theo tag "PP1"/"PP2" (truyen "" = tinh CA 2  |
//|     gop lai). Loc CHINH XAC bang cach tim POSITION_ID cua cac lenh   |
//|     co deal MO (DEAL_ENTRY_IN) chua tag trong comment TRUOC (comment |
//|     luc mo lenh la dang tin cay duy nhat -- deal DONG co the bi      |
//|     broker ghi de comment khac, vd "tp"/"sl", nen KHONG loc truc     |
//|     tiep tren deal dong).                                            |
//|   - Them bang trang thai OBJ_LABEL tren chart (CreateDashboard/      |
//|     UpdateDashboard, kieu giong EMACrossCloneEA), hien 3 dong: PP1    |
//|     hom nay, PP2 hom nay, Tong hom nay -- cap nhat MOI TICK. Input    |
//|     moi InpShowDashboard (mac dinh true) de bat/tat toan bo bang.     |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.02"
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

// === 5. [MOI v1.01] Che do 1 -- Phan ky: xac nhan them bang mo hinh nen dao chieu (tuy chon) ===
input bool   InpUseDivergenceMode     = true;  // Bat/tat toan bo Che do 1 (phan ky RSI+BB)
input bool   InpRequireReversalCandle = false; // Bat buoc nen swing phai la nen dao chieu (Engulfing/Pin Bar) moi xac nhan -- mac dinh TAT (giu dung hanh vi v1.00)
input double InpPinWickRatio          = 2.0;   // Ty le toi thieu bong nen / than nen de tinh la Pin Bar/Hammer

// === 6. [MOI v1.01] Che do 2 -- Thuan theo xu huong RSI + nen pha vo (doc lap voi Che do 1) ===
input bool   InpUseTrendBreakoutMode = true; // Bat/tat toan bo Che do 2
input int    InpTrendRsiBars        = 5;    // So nen RSI phai giu LIEN TUC tren/duoi 50 de tinh la "dang co xu huong ro rang"
input int    InpBreakoutRangeBars   = 10;   // So nen gan nhat de xac dinh vung dinh/day can "pha vo"
input double InpBreakoutBodyMult    = 1.5;  // Than nen hien tai phai lon hon than nen trung binh bao nhieu lan moi tinh la "nen pha vo"
input int    InpBreakoutBodyAvgBars = 10;   // So nen dung de tinh than nen trung binh (so sanh voi nen pha vo)

// === 7. [MOI v1.02] Bang trang thai tren chart -- lai/lo rieng theo tung PP ===
input bool   InpShowDashboard = true; // Bat/tat bang trang thai tren chart (lai/lo rieng PP1/PP2 hom nay, cap nhat moi tick)

#define DASH_PREFIX "RsiBbDivEA_Dash_"
#define TAG_PP1 "PP1"
#define TAG_PP2 "PP2"

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

// [MOI v1.01] chong lap tin hieu rieng cho Che do 2 -- luu THOI GIAN cua nen pha vo GAN NHAT da tung dung
// de vao lenh, cho tung huong rieng (tuong tu g_LastSellSwingTime/g_LastBuySwingTime cua Che do 1).
datetime g_LastBreakoutSellTime = 0;
datetime g_LastBreakoutBuyTime  = 0;

//--- CHAN DOAN: dem so lan phat hien phan ky (truoc khi loc trung lap/khoang cach) va so lan xac nhan vao lenh
int g_DbgBearishSeen = 0, g_DbgBullishSeen = 0, g_DbgBuyOpened = 0, g_DbgSellOpened = 0;
int g_DbgBlockedSpread = 0, g_DbgBlockedBarsWait = 0, g_DbgBlockedPyramid = 0, g_DbgOrderSendFail = 0;
//--- [MOI v1.01] CHAN DOAN rieng cho Che do 2 (thuan xu huong + nen pha vo) va bo loc nen dao chieu cua Che do 1
int g_DbgTrendBreakoutUpSeen = 0, g_DbgTrendBreakoutDownSeen = 0;
int g_DbgTrendBuyOpened = 0, g_DbgTrendSellOpened = 0;
int g_DbgBlockedNoReversalCandle = 0;

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
//| [MOI v1.01] Nhan dien nen dao chieu -- CHI 2 mo hinh RO RANG, do   |
//| luong duoc bang cong thuc (Engulfing + Pin Bar/Hammer), KHONG co   |
//| gang nhan dien moi mo hinh nen kinh dien khac -- de tranh nhan     |
//| dien sai/qua chu quan nhu mat nguoi xem chart.                     |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(const double &openArr[], const double &closeArr[], int shift)
{
   bool prevBearish = closeArr[shift + 1] < openArr[shift + 1];
   bool curBullish  = closeArr[shift]     > openArr[shift];
   if (!prevBearish || !curBullish) return false;
   return (openArr[shift] <= closeArr[shift + 1]) && (closeArr[shift] >= openArr[shift + 1]);
}

bool IsBearishEngulfing(const double &openArr[], const double &closeArr[], int shift)
{
   bool prevBullish = closeArr[shift + 1] > openArr[shift + 1];
   bool curBearish  = closeArr[shift]     < openArr[shift];
   if (!prevBullish || !curBearish) return false;
   return (openArr[shift] >= closeArr[shift + 1]) && (closeArr[shift] <= openArr[shift + 1]);
}

bool IsBullishPinBar(const double &openArr[], const double &highArr[], const double &lowArr[], const double &closeArr[], int shift)
{
   double body      = MathAbs(closeArr[shift] - openArr[shift]);
   double lowerWick = MathMin(openArr[shift], closeArr[shift]) - lowArr[shift];
   double upperWick = highArr[shift] - MathMax(openArr[shift], closeArr[shift]);
   if (body <= 0) return false;
   return (lowerWick >= body * InpPinWickRatio) && (upperWick <= body * 0.5);
}

bool IsBearishPinBar(const double &openArr[], const double &highArr[], const double &lowArr[], const double &closeArr[], int shift)
{
   double body      = MathAbs(closeArr[shift] - openArr[shift]);
   double upperWick = highArr[shift] - MathMax(openArr[shift], closeArr[shift]);
   double lowerWick = MathMin(openArr[shift], closeArr[shift]) - lowArr[shift];
   if (body <= 0) return false;
   return (upperWick >= body * InpPinWickRatio) && (lowerWick <= body * 0.5);
}

bool IsReversalCandleBullish(const double &openArr[], const double &highArr[], const double &lowArr[], const double &closeArr[], int shift)
{
   return IsBullishEngulfing(openArr, closeArr, shift) || IsBullishPinBar(openArr, highArr, lowArr, closeArr, shift);
}

bool IsReversalCandleBearish(const double &openArr[], const double &highArr[], const double &lowArr[], const double &closeArr[], int shift)
{
   return IsBearishEngulfing(openArr, closeArr, shift) || IsBearishPinBar(openArr, highArr, lowArr, closeArr, shift);
}

//+------------------------------------------------------------------+
//| [MOI v1.01] Che do 2 -- "nen pha vo": than nen lon hon trung binh  |
//| InpBreakoutBodyAvgBars nen truoc it nhat InpBreakoutBodyMult lan,  |
//| VA dong cua vuot qua dinh/day cao nhat/thap nhat cua               |
//| InpBreakoutRangeBars nen truoc do (shift+1 .. shift+N, KHONG tinh  |
//| chinh nen dang xet).                                                |
//+------------------------------------------------------------------+
bool IsBreakoutCandleUp(const double &openArr[], const double &highArr[], const double &closeArr[], int shift)
{
   double body = closeArr[shift] - openArr[shift];
   if (body <= 0) return false; // phai la nen tang (bullish)

   double sumBody = 0;
   for (int j = shift + 1; j <= shift + InpBreakoutBodyAvgBars; j++)
      sumBody += MathAbs(closeArr[j] - openArr[j]);
   double avgBody = sumBody / InpBreakoutBodyAvgBars;
   if (avgBody <= 0 || body < avgBody * InpBreakoutBodyMult) return false;

   double priorHigh = highArr[shift + 1];
   for (int j = shift + 2; j <= shift + InpBreakoutRangeBars; j++)
      if (highArr[j] > priorHigh) priorHigh = highArr[j];

   return closeArr[shift] > priorHigh;
}

bool IsBreakoutCandleDown(const double &openArr[], const double &lowArr[], const double &closeArr[], int shift)
{
   double body = openArr[shift] - closeArr[shift];
   if (body <= 0) return false; // phai la nen giam (bearish)

   double sumBody = 0;
   for (int j = shift + 1; j <= shift + InpBreakoutBodyAvgBars; j++)
      sumBody += MathAbs(closeArr[j] - openArr[j]);
   double avgBody = sumBody / InpBreakoutBodyAvgBars;
   if (avgBody <= 0 || body < avgBody * InpBreakoutBodyMult) return false;

   double priorLow = lowArr[shift + 1];
   for (int j = shift + 2; j <= shift + InpBreakoutRangeBars; j++)
      if (lowArr[j] < priorLow) priorLow = lowArr[j];

   return closeArr[shift] < priorLow;
}

//+------------------------------------------------------------------+
//| [MOI v1.01] Che do 2 -- "dang co xu huong ro rang": RSI giu LIEN   |
//| TUC tren (hoac duoi) 50 trong it nhat 'bars' nen gan nhat.         |
//+------------------------------------------------------------------+
bool IsRsiTrendingUp(const double &rsiArr[], int shift, int bars)
{
   for (int j = shift; j < shift + bars; j++)
      if (!MathIsValidNumber(rsiArr[j]) || rsiArr[j] <= 50.0) return false;
   return true;
}

bool IsRsiTrendingDown(const double &rsiArr[], int shift, int bars)
{
   for (int j = shift; j < shift + bars; j++)
      if (!MathIsValidNumber(rsiArr[j]) || rsiArr[j] >= 50.0) return false;
   return true;
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
//| [MOI v1.02] Lai/lo TRONG NGAY (da dong + dang mo), loc theo tag    |
//| "PP1"/"PP2" trong comment cua lenh -- truyen "" de tinh CA 2 PP     |
//| gop lai. Xem giai thich cach loc CHINH XAC qua POSITION_ID trong    |
//| changelog v1.02 o dau file (deal DONG khong dang tin cay de loc     |
//| truc tiep comment).                                                 |
//+------------------------------------------------------------------+
double CalcDayProfitUSD(string tagFilter)
{
   double total = 0.0;

   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime dayStart = StructToTime(dtNow);
   datetime now = TimeCurrent();

   if (HistorySelect(dayStart, now + 86400))
   {
      int totalDeals = HistoryDealsTotal();

      ulong matchedPosId[];
      if (tagFilter != "")
      {
         for (int i = 0; i < totalDeals; i++)
         {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket == 0) continue;
            if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
            if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
            if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            if (StringFind(HistoryDealGetString(ticket, DEAL_COMMENT), tagFilter) < 0) continue;

            int sz = ArraySize(matchedPosId);
            ArrayResize(matchedPosId, sz + 1);
            matchedPosId[sz] = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         }
      }

      for (int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if (ticket == 0) continue;
         if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

         if (tagFilter != "")
         {
            ulong posId = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            bool found = false;
            for (int k = 0; k < ArraySize(matchedPosId); k++)
               if (matchedPosId[k] == posId) { found = true; break; }
            if (!found) continue;
         }

         total += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                  HistoryDealGetDouble(ticket, DEAL_SWAP) +
                  HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }

   // Lenh dang mo: POSITION_COMMENT VAN la comment goc luc mo lenh (khong bi ghi de nhu deal dong),
   // nen loc truc tiep duoc, khong can tra POSITION_ID nhu o tren.
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (tagFilter != "" && StringFind(PositionGetString(POSITION_COMMENT), tagFilter) < 0) continue;

      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   return total;
}

//+------------------------------------------------------------------+
//| [MOI v1.02] Bang trang thai tren chart -- OBJ_LABEL + khung nen     |
//| OBJ_RECTANGLE_LABEL, cung kieu da dung trong EMACrossCloneEA.        |
//+------------------------------------------------------------------+
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   string keys[] = {"Title", "PP1", "PP2", "Total", "Position"};
   int x = 10, y = 16, dy = 16;
   int panelW = 300, panelH = ArraySize(keys) * dy + 14;

   string bgName = DASH_PREFIX + "BG";
   if (ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 6);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 8);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   for (int i = 0; i < ArraySize(keys); i++)
   {
      string name = DASH_PREFIX + keys[i];
      if (ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + i * dy);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT, "...");
   }
}

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); }

//+------------------------------------------------------------------+
//| [MOI v1.02] Dien so lieu that vao bang -- dat SAU GetOpenPosition() |
//| va CalcDayProfitUSD() vi can goi 2 ham do (MQL5 doi khai bao truoc, |
//| goi sau).                                                            |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   SetLabel(DASH_PREFIX + "Title", StringFormat("=== RsiBbDivergenceEA v1.02 (%s) ===", _Symbol), clrWhite);

   double pp1USD = CalcDayProfitUSD(TAG_PP1);
   double pp2USD = CalcDayProfitUSD(TAG_PP2);
   double totalUSD = pp1USD + pp2USD;

   SetLabel(DASH_PREFIX + "PP1", StringFormat("PP1 (Phan ky) hom nay: %s%.2f %s",
            (pp1USD >= 0 ? "+" : ""), pp1USD, AccountInfoString(ACCOUNT_CURRENCY)),
            (pp1USD >= 0 ? clrLimeGreen : clrTomato));

   SetLabel(DASH_PREFIX + "PP2", StringFormat("PP2 (Xu huong) hom nay: %s%.2f %s",
            (pp2USD >= 0 ? "+" : ""), pp2USD, AccountInfoString(ACCOUNT_CURRENCY)),
            (pp2USD >= 0 ? clrLimeGreen : clrTomato));

   SetLabel(DASH_PREFIX + "Total", StringFormat("Tong hom nay: %s%.2f %s",
            (totalUSD >= 0 ? "+" : ""), totalUSD, AccountInfoString(ACCOUNT_CURRENCY)),
            (totalUSD >= 0 ? clrLimeGreen : clrTomato));

   long  posType   = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0 && PositionSelectByTicket(posTicket))
   {
      string dirTxt = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      string cmt    = PositionGetString(POSITION_COMMENT);
      double openP  = PositionGetDouble(POSITION_PRICE_OPEN);
      double slP    = PositionGetDouble(POSITION_SL);
      double tpP    = PositionGetDouble(POSITION_TP);
      SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh: [%s] %s @ %.2f | SL %.2f | TP %.2f",
               cmt, dirTxt, openP, slP, tpP), clrKhaki);
   }
   else
   {
      SetLabel(DASH_PREFIX + "Position", "Lenh: Khong co", clrSilver);
   }
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

   if (InpShowDashboard) CreateDashboard(); // [MOI v1.02]

   Print("RsiBbDivergenceEA v1.02: OnInit THANH CONG -- RSI/Bands/ATR handle deu tao duoc. Che do 1 (phan ky)=",
         InpUseDivergenceMode, " | Che do 2 (thuan xu huong+nen pha vo)=", InpUseTrendBreakoutMode,
         " -- EA bat dau chay tu day.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   DeleteDashboard(); // [MOI v1.02]

   Print("RsiBbDivergenceEA: [CHAN DOAN v1.02] Che do 1 (phan ky) -- so nen da xu ly=", g_BarsProcessed, " | ",
         "phan ky GIAM (bearish) thay=", g_DbgBearishSeen, " (Sell mo thanh cong=", g_DbgSellOpened, ") | ",
         "phan ky TANG (bullish) thay=", g_DbgBullishSeen, " (Buy mo thanh cong=", g_DbgBuyOpened, ") | ",
         "bi chan vi thieu nen dao chieu (InpRequireReversalCandle)=", g_DbgBlockedNoReversalCandle);
   Print("RsiBbDivergenceEA: [CHAN DOAN v1.02] Che do 2 (thuan xu huong+nen pha vo) -- ",
         "breakout LEN thay=", g_DbgTrendBreakoutUpSeen, " (Buy mo thanh cong=", g_DbgTrendBuyOpened, ") | ",
         "breakout XUONG thay=", g_DbgTrendBreakoutDownSeen, " (Sell mo thanh cong=", g_DbgTrendSellOpened, ")");
   Print("RsiBbDivergenceEA: [CHAN DOAN v1.02] Chi tiet ly do BI CHAN (chung ca 2 che do) -- ",
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
   // [MOI v1.02] Dat TRUOC gate "nen moi" ben duoi co y -- can cap nhat MOI TICK (khong phai moi nen)
   // de lai/lo hien thi thay doi lien tuc theo gia thi truong (giong EMACrossCloneEA).
   if (InpShowDashboard) UpdateDashboard();

   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (barTime == 0 || barTime == g_LastBarTime) return;
   g_LastBarTime = barTime;
   g_BarsProcessed++;

   // [MOI v1.01] needBars gio phai du cho CA 2 che do: quet swing (Che do 1) LAN nhin lui cho
   // nen pha vo + than nen trung binh (Che do 2) -- lay so lon nhat can, cong them đem an toan.
   int needBars = InpMaxSwingSearchBars + 2 * InpSwingLookback + InpBreakoutRangeBars + InpBreakoutBodyAvgBars + 20;

   double high[], low[], openP[], closeP[], rsiArr[], bbUpper[], bbLower[], atrArr[];
   datetime timeArr[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(openP, true);
   ArraySetAsSeries(closeP, true);
   ArraySetAsSeries(rsiArr, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(atrArr, true);
   ArraySetAsSeries(timeArr, true);

   if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needBars, high) < needBars) return;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needBars, low) < needBars) return;
   if (CopyOpen(_Symbol, PERIOD_CURRENT, 0, needBars, openP) < needBars) return;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, needBars, closeP) < needBars) return;
   if (CopyTime(_Symbol, PERIOD_CURRENT, 0, needBars, timeArr) < needBars) return;
   if (CopyBuffer(g_RsiHandle, 0, 0, needBars, rsiArr) < needBars) return;
   if (CopyBuffer(g_BbHandle, 1, 0, needBars, bbUpper) < needBars) return; // BANDS_UPPER
   if (CopyBuffer(g_BbHandle, 2, 0, needBars, bbLower) < needBars) return; // BANDS_LOWER
   if (CopyBuffer(g_AtrHandle, 0, 0, needBars, atrArr) < needBars) return;

   long  openType   = -1;
   ulong openTicket = GetOpenPosition(openType);

   bool spreadOK = (InpMaxSpreadUSD <= 0.0) || (CurrentSpreadPrice() <= InpMaxSpreadUSD);
   bool waitOK   = (g_BarsProcessed - g_LastEntryBarIndex >= InpMinBarsBetweenSignals);

   bool alreadyActedThisTick = false; // [MOI v1.01] chi cho phep 1 trong 2 che do vao lenh MOI tren CUNG 1 nen

   //====================================================================
   // CHE DO 1 -- Phan ky RSI + Bollinger Bands (xem chi tiet o v1.00)
   //====================================================================
   if (InpUseDivergenceMode)
   {
      SwingPoint highs[], lows[];
      int highCount = CollectSwingHighs(high, rsiArr, bbUpper, atrArr, timeArr, InpMaxSwingSearchBars, highs);
      int lowCount  = CollectSwingLows(low, rsiArr, bbLower, atrArr, timeArr, InpMaxSwingSearchBars, lows);

      bool bearishDivergence = false;
      bool bullishDivergence = false;

      if (highCount == 2 && (highs[0].price > highs[1].price) && (highs[0].rsi < highs[1].rsi))
      {
         bearishDivergence = true;
         g_DbgBearishSeen++;
      }
      if (lowCount == 2 && (lows[0].price < lows[1].price) && (lows[0].rsi > lows[1].rsi))
      {
         bullishDivergence = true;
         g_DbgBullishSeen++;
      }

      // --- Ban Sell (phan ky GIAM) ---
      if (bearishDivergence && highs[0].time != g_LastSellSwingTime && !alreadyActedThisTick)
      {
         bool candleOK = (!InpRequireReversalCandle) || IsReversalCandleBearish(openP, high, low, closeP, highs[0].shift);
         if (!candleOK)
         {
            g_DbgBlockedNoReversalCandle++;
         }
         else if (openTicket != 0)
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

               if (trade.Sell(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA PP1-Sell"))
               {
                  g_LastSellSwingTime = highs[0].time;
                  g_LastEntryBarIndex = g_BarsProcessed;
                  g_DbgSellOpened++;
                  alreadyActedThisTick = true;
               }
               else
               {
                  g_DbgOrderSendFail++;
                  Print("RsiBbDivergenceEA: trade.Sell() (Che do 1) that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               }
            }
         }
      }

      // --- Ban Buy (phan ky TANG) ---
      if (bullishDivergence && lows[0].time != g_LastBuySwingTime && !alreadyActedThisTick)
      {
         bool candleOK = (!InpRequireReversalCandle) || IsReversalCandleBullish(openP, high, low, closeP, lows[0].shift);
         if (!candleOK)
         {
            g_DbgBlockedNoReversalCandle++;
         }
         else if (openTicket != 0)
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

               if (trade.Buy(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA PP1-Buy"))
               {
                  g_LastBuySwingTime = lows[0].time;
                  g_LastEntryBarIndex = g_BarsProcessed;
                  g_DbgBuyOpened++;
                  alreadyActedThisTick = true;
               }
               else
               {
                  g_DbgOrderSendFail++;
                  Print("RsiBbDivergenceEA: trade.Buy() (Che do 1) that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }

   //====================================================================
   // CHE DO 2 -- [MOI v1.01] Thuan theo xu huong RSI + nen pha vo
   // Danh gia tren nen DA DONG (shift=1), KHONG dung nen dang chay (shift=0), tranh repaint.
   //====================================================================
   if (InpUseTrendBreakoutMode)
   {
      bool breakoutUp   = IsRsiTrendingUp(rsiArr, 1, InpTrendRsiBars)   && IsBreakoutCandleUp(openP, high, closeP, 1);
      bool breakoutDown = IsRsiTrendingDown(rsiArr, 1, InpTrendRsiBars) && IsBreakoutCandleDown(openP, low, closeP, 1);

      if (breakoutUp)   g_DbgTrendBreakoutUpSeen++;
      if (breakoutDown) g_DbgTrendBreakoutDownSeen++;

      // --- Mua THEO xu huong (breakout LEN) ---
      if (breakoutUp && timeArr[1] != g_LastBreakoutBuyTime && !alreadyActedThisTick)
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
            double atrNow = atrArr[1];
            double slBuffer = (MathIsValidNumber(atrNow) && atrNow > 0) ? atrNow * InpSLBufferATR : 0.0;
            double entryPrice = CurrentAsk();
            double slPrice = low[1] - slBuffer; // duoi day nen pha vo
            double slDist  = entryPrice - slPrice;

            if (slDist > 0)
            {
               double tpPrice = entryPrice + slDist * InpRR;
               double lot = CalcRiskLot(slDist);

               if (trade.Buy(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA PP2-Buy"))
               {
                  g_LastBreakoutBuyTime = timeArr[1];
                  g_LastEntryBarIndex = g_BarsProcessed;
                  g_DbgTrendBuyOpened++;
                  alreadyActedThisTick = true;
               }
               else
               {
                  g_DbgOrderSendFail++;
                  Print("RsiBbDivergenceEA: trade.Buy() (Che do 2) that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               }
            }
         }
      }

      // --- Ban THEO xu huong (breakout XUONG) ---
      if (breakoutDown && timeArr[1] != g_LastBreakoutSellTime && !alreadyActedThisTick)
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
            double atrNow = atrArr[1];
            double slBuffer = (MathIsValidNumber(atrNow) && atrNow > 0) ? atrNow * InpSLBufferATR : 0.0;
            double entryPrice = CurrentBid();
            double slPrice = high[1] + slBuffer; // tren dinh nen pha vo
            double slDist  = slPrice - entryPrice;

            if (slDist > 0)
            {
               double tpPrice = entryPrice - slDist * InpRR;
               double lot = CalcRiskLot(slDist);

               if (trade.Sell(lot, _Symbol, entryPrice, slPrice, tpPrice, "RsiBbDivergenceEA PP2-Sell"))
               {
                  g_LastBreakoutSellTime = timeArr[1];
                  g_LastEntryBarIndex = g_BarsProcessed;
                  g_DbgTrendSellOpened++;
                  alreadyActedThisTick = true;
               }
               else
               {
                  g_DbgOrderSendFail++;
                  Print("RsiBbDivergenceEA: trade.Sell() (Che do 2) that bai -- ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
