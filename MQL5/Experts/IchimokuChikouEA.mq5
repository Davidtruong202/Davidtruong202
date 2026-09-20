//+------------------------------------------------------------------+
//|                                            IchimokuChikouEA.mq5  |
//|  EA tu dong vao lenh theo chien luoc "Ichimoku Chikou Span Cross |
//|  da khung gio" (video "The Easiest and Most Effective Ichimoku   |
//|  Strategy" - @TechnicalAnalysisInstitute) -- TU VIET tu dau,      |
//|  KHONG dung file .ex5 dong goi nao, KHONG goi iCustom() toi ben   |
//|  thu 3. Chi dung 2 duong cua Ichimoku: Lagging Span (Chikou) va   |
//|  Span B (Senkou Span B) -- KHONG can Tenkan/Kijun/Span A.         |
//|                                                                    |
//|  LOGIC (dung y het video, xem tom tat cuoi file):                 |
//|   1) Vao lenh (2 buoc, khung 15 phut + khung 1 gio):               |
//|      - Buoc 1 (khung vao lenh, vd M15): Lagging Span cat LEN tren  |
//|        Span B -> Buy; cat XUONG -> Sell.                           |
//|      - Buoc 2 (khung xac nhan, vd H1): gia phai dang o phia thuan  |
//|        loi so voi Span B cua khung do (tren Span B cho Buy, duoi   |
//|        cho Sell), VA khoang cach tu gia den Span B phai du lon     |
//|        (loc theo boi so ATR cua khung xac nhan).                   |
//|   2) SL: dat tai muc thap nhat trong 2 day tuong doi gan nhat      |
//|      (Buy) / cao nhat trong 2 dinh tuong doi gan nhat (Sell) --    |
//|      "day/dinh tuong doi" = nen fractal (thap/cao hon N nen ben    |
//|      trai VA N nen ben phai).                                      |
//|   3) KHONG CO TP CO DINH -- chi thoat lenh khi Lagging Span cat    |
//|      NGUOC LAI qua Span B (dung y het dieu kien vao lenh, dao      |
//|      chieu) -- giu lenh xuyen suot du gia di ngang bao lau.        |
//|                                                                    |
//|  GHI CHU KY THUAT QUAN TRONG VE CACH TINH "Chikou cat Span B":     |
//|  Day la diem de sai NHAT khi code Ichimoku trong MQL5, vi ca 2     |
//|  duong deu bi "dich chuyen" khi ve len chart (Span B dich TOI      |
//|  TUONG LAI InpKijunPeriod nen, Chikou dich VE QUA KHU              |
//|  InpKijunPeriod nen). EA nay KHONG dung buffer co san cua          |
//|  iIchimoku() (de tranh nham lan ve quy uoc dich chuyen noi bo cua  |
//|  MT5) -- ma TU TINH TAY moi thu tu gia goc (High/Low/Close), suy   |
//|  luan lai dung nghia toan hoc cua Chikou/Span B tu dau:            |
//|                                                                    |
//|   - RawSpanB(k) = (Highest(High, N2, k) + Lowest(Low, N2, k)) / 2  |
//|     (N2 = InpSenkouBPeriod, k = so nen lui ve qua khu, k=0=nen     |
//|     hien tai). Day la gia tri "goc", CHUA dich chuyen gi ca.       |
//|   - Span B VE tren chart tai vi tri "k nen truoc" = RawSpanB tinh  |
//|     tu du lieu "k+N1 nen truoc" (N1=InpKijunPeriod), vi Span B bi  |
//|     day TOI TUONG LAI N1 nen so voi luc tinh.                      |
//|   - Chikou VE tren chart tai vi tri "k nen truoc" = gia dong cua   |
//|     nen "(k-N1) nen truoc" (= CLOSE[k-N1]), vi Chikou bi day VE    |
//|     QUA KHU N1 nen so voi luc tinh (gia hom nay duoc ve lui N1 nen).|
//|   - Tin hieu "hom nay" (nhin Chikou cua HOM NAY xem no dang o dau  |
//|     tren chart) tuong duong xet tai vi tri "N1 nen truoc" (vi do   |
//|     la noi Chikou cua hom nay duoc ve toi): Chikou tai do =        |
//|     CLOSE[N1-N1] = CLOSE[0] (dung, gia hom nay). Span B tai vi tri |
//|     do = RawSpanB(N1+N1) = RawSpanB(2*N1).                         |
//|   => KET LUAN: tin hieu "Chikou cat Span B hom nay" = so sanh      |
//|      CLOSE[0] (gia dong hom nay) voi RawSpanB(2*InpKijunPeriod)    |
//|      (Span B tinh tu du lieu 2*N1 nen truoc). Day CHINH XAC la     |
//|      dinh nghia Ichimoku goc -- da tu suy luan lai 2 lan doc lap   |
//|      de xac nhan, KHONG phai doan mo.                              |
//|                                                                    |
//|  Khong co trinh bien dich MQL5 that trong moi truong nay -- code   |
//|  nay CHUA duoc compile/chay thu thuc te. Da tu kiem tra can bang   |
//|  ngoac/dau ngoac bang script rieng truoc khi giao.                 |
//+------------------------------------------------------------------+
#property copyright "Gold Hunter"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== 1. Ichimoku (chi dung Chikou + Span B) ==="
input int InpKijunPeriod   = 26; // So nen dich chuyen (N1) -- boi so Kijun mac dinh cua Ichimoku chuan
input int InpSenkouBPeriod = 52; // Chu ky tinh Span B (N2) -- mac dinh cua Ichimoku chuan

input group "=== 2. Xac nhan da khung gio (buoc 2) ==="
input bool             InpUseH1Filter     = true;         // Bat/tat buoc xac nhan khung gio lon hon
input ENUM_TIMEFRAMES  InpConfirmTimeframe = PERIOD_H1;    // Khung xac nhan (video dung H1 khi EA chay tren M15)
input int              InpConfirmAtrPeriod = 14;           // Chu ky ATR cua khung xac nhan, dung de do "khoang cach du lon"
input double           InpConfirmMinDistAtr = 0.3;         // Khoang cach toi thieu tu gia den Span B (khung xac nhan), boi so ATR. 0 = chi can dung phia, khong xet khoang cach

input group "=== 3. Stop Loss theo day/dinh tuong doi (fractal) ==="
input int InpFractalBars     = 2;   // So nen 2 ben (trai/phai) phai cao/thap hon de tinh la 1 day/dinh tuong doi
input int InpMaxSwingSearch  = 300; // So nen toi da lui ve qua khu de tim du 2 day/dinh tuong doi gan nhat
input double InpSlBufferAtr  = 0.1; // Dem them 1 khoang nho (boi so ATR khung vao lenh) ra ngoai day/dinh, tranh SL bi cham do rau nen (0 = khong dem)

input group "=== 4. Quan ly lenh ==="
input bool   InpOnePositionOnly = true;    // Chan tin hieu moi neu da co lenh dang mo (dung thiet ke: khong pyramid)
input double InpMaxSpreadUSD    = 0.0;     // Bo qua vao lenh moi neu spread > gia tri nay ($ price distance). 0 = tat
input ulong  InpMagic           = 20260920;
input double InpSlippageUSD     = 0.30;

input group "=== 5. Khoi luong lenh theo % RISK ==="
input bool   InpUseRiskPercent = true;  // true: tu tinh lot theo % Balance (khuyen nghi); false: dung InpLotSize co dinh
input double InpRiskPercent    = 3.0;   // % Balance chap nhan mat neu dinh dung SL
input double InpLotSize        = 0.01;  // Lot co dinh, dung khi InpUseRiskPercent=false hoac khi thieu du lieu de tinh risk%
input double InpMaxLotCap      = 1.0;   // Chan lot toi da (an toan)

input group "=== 6. Tu dong DUNG VAO LENH MOI khi lo qua nguong trong ngay ==="
input bool   InpUseDailyLossLimit = true;
input double InpMaxDailyLossUSD   = 15.0;

input group "=== 7. Telegram - thong bao truc tiep, 1 lop duy nhat ==="
input string InpTgBotToken = "";
input long   InpTgChatId   = 0;
input int    InpTgTopicId  = 0;

input group "=== 8. Bang trang thai + nut Test tren chart ==="
input bool InpShowDashboard   = true;
input bool InpShowTestButtons = true;

//====================================================================
// Globals
//====================================================================
datetime g_LastBarTime = 0;
int      g_AtrHandleEntry  = INVALID_HANDLE; // ATR tren khung vao lenh (dung cho InpSlBufferAtr)
int      g_AtrHandleConfirm = INVALID_HANDLE; // ATR tren khung xac nhan (dung cho InpConfirmMinDistAtr)

int g_DbgBarsProcessed = 0;
int g_DbgCrossUp = 0, g_DbgCrossDown = 0;
int g_DbgBuyOpened = 0, g_DbgSellOpened = 0;
int g_DbgBlockedH1Filter = 0, g_DbgBlockedSpread = 0, g_DbgBlockedMargin = 0, g_DbgBlockedFreeMargin = 0;
int g_DbgBlockedPyramid = 0, g_DbgBlockedDailyLoss = 0, g_DbgOrderSendFail = 0, g_DbgBlockedNoSwing = 0;

datetime g_DailyLossAlertDay = 0;

string g_lastSignalTxt = "Chua co tin hieu nao";
datetime g_lastSignalBarTime = 0;

#define DASH_PREFIX "IchiEA_Dash_"

//====================================================================
// A. Helpers thuan tuy
//====================================================================
double CurrentBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double CurrentAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }
double CurrentSpreadPrice() { return CurrentAsk() - CurrentBid(); }

int PriceDistanceToPoints(double priceDistance)
{
   if (_Point <= 0.0) return 0;
   return (int)MathRound(priceDistance / _Point);
}

double MarginRequiredPerLot(ENUM_ORDER_TYPE type, double price)
{
   double margin = 0.0;
   if (!OrderCalcMargin(type, _Symbol, 1.0, price, margin)) return 0.0;
   return margin;
}

double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if (step <= 0) step = 0.01;
   double norm = MathRound(lot / step) * step;
   if (norm < minLot) norm = minLot;
   if (maxLot > 0 && norm > maxLot) norm = maxLot;
   return norm;
}

double CalcRiskLot(double slDistancePrice)
{
   if (slDistancePrice <= 0) return InpLotSize;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || tickValue <= 0) return InpLotSize;
   double valuePerPriceUnit = tickValue / tickSize;
   if (valuePerPriceUnit <= 0) return InpLotSize;
   double lot = riskAmount / (slDistancePrice * valuePerPriceUnit);
   return MathMin(NormalizeLot(lot), InpMaxLotCap);
}

//====================================================================
// B. Vi the cua EA nay (theo magic+symbol)
//====================================================================
ulong GetOpenPosition(long &outType)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      outType = PositionGetInteger(POSITION_TYPE);
      return ticket;
   }
   outType = -1;
   return 0;
}

void CloseAllPositions()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      trade.PositionClose(ticket);
   }
}

//====================================================================
// C. Telegram - thong bao truc tiep 1 lop duy nhat (POST + HTML, giong
// pattern da kiem chung trong EMACrossCloneEA)
//====================================================================
string UrlEncode(const string text)
{
   uchar bytes[];
   int n = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   string result = "";
   for (int i = 0; i < n; i++)
   {
      uchar b = bytes[i];
      if (b == 0) break;
      if ((b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') ||
          b == '-' || b == '_' || b == '.' || b == '~')
         result += CharToString(b);
      else
         result += StringFormat("%%%02X", b);
   }
   return result;
}

bool TelegramSendMessage(const string text)
{
   if (StringLen(InpTgBotToken) == 0 || InpTgChatId == 0) return false;

   string url = "https://api.telegram.org/bot" + InpTgBotToken + "/sendMessage";
   string body = "chat_id=" + IntegerToString(InpTgChatId) + "&parse_mode=HTML&text=" + UrlEncode(text);
   if (InpTgTopicId > 0)
      body += "&message_thread_id=" + IntegerToString(InpTgTopicId);

   char   post[];
   char   resultData[];
   string resultHeaders;
   StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   int postLen = ArraySize(post);
   if (postLen > 0) ArrayResize(post, postLen - 1);

   ResetLastError();
   int res = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded\r\n", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      Print("IchimokuChikouEA: gui Telegram that bai, loi ", GetLastError(),
            " -- kiem tra da whitelist https://api.telegram.org trong Tools->Options->Expert Advisors chua");
      return false;
   }
   return true;
}

//====================================================================
// D. Lai/lo trong ngay theo USD (circuit breaker) -- tinh lai TU DAU moi
// lan goi, tu dong reset khi sang ngay moi, giong pattern EMACrossCloneEA.
//====================================================================
double CalcDayProfitUSD()
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
      for (int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if (ticket == 0) continue;
         if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagic) continue;
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
         total += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                  HistoryDealGetDouble(ticket, DEAL_SWAP) +
                  HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

//====================================================================
// E. Tinh RawSpanB(k) -- gia tri GOC (chua dich chuyen gi) cua Span B,
// dung du lieu High/Low cua khung 'timeframe' bat ky. k = so nen lui ve
// qua khu tinh tu nen vua dong cua khung do (0 = nen vua dong).
// Xem ghi chu toan hoc day du o dau file truoc khi doi bat ky dong nao.
//====================================================================
bool ComputeRawSpanB(string symbol, ENUM_TIMEFRAMES timeframe, int senkouBPeriod, int k, double &outValue)
{
   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   int need = k + senkouBPeriod + 2;
   if (CopyHigh(symbol, timeframe, 0, need, highArr) < need) return false;
   if (CopyLow(symbol, timeframe, 0, need, lowArr) < need) return false;

   double hi = highArr[k], lo = lowArr[k];
   for (int j = k + 1; j < k + senkouBPeriod; j++)
   {
      if (highArr[j] > hi) hi = highArr[j];
      if (lowArr[j] < lo) lo = lowArr[j];
   }
   outValue = (hi + lo) / 2.0;
   return true;
}

//====================================================================
// F. Day/dinh tuong doi kieu fractal (2 ben deu thap/cao hon) -- dung tim
// SL. lowArr/highArr da lay theo kieu series (idx 0 = nen moi nhat).
//====================================================================
bool IsSwingLow(const double &lowArr[], int idx, int fractalBars, int n)
{
   if (idx - fractalBars < 0 || idx + fractalBars >= n) return false;
   for (int j = 1; j <= fractalBars; j++)
   {
      if (lowArr[idx - j] < lowArr[idx]) return false; // nen gan hien tai hon thap hon -> khong phai day tuong doi
      if (lowArr[idx + j] < lowArr[idx]) return false; // nen xa hien tai hon thap hon -> khong phai day tuong doi
   }
   return true;
}

bool IsSwingHigh(const double &highArr[], int idx, int fractalBars, int n)
{
   if (idx - fractalBars < 0 || idx + fractalBars >= n) return false;
   for (int j = 1; j <= fractalBars; j++)
   {
      if (highArr[idx - j] > highArr[idx]) return false;
      if (highArr[idx + j] > highArr[idx]) return false;
   }
   return true;
}

// Tim gia SL cho lenh BUY: thap nhat trong 2 day tuong doi GAN NHAT (lui ve qua khu tu startIdx).
// Tra ve 0 neu khong tim thay du (nen fallback dung ATR o noi goi).
double FindBuySlFromSwingLows(const double &lowArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   double found[2];
   int cnt = 0;
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit && cnt < 2; idx++)
   {
      if (IsSwingLow(lowArr, idx, fractalBars, n))
      {
         found[cnt] = lowArr[idx];
         cnt++;
      }
   }
   if (cnt == 0) return 0.0;
   if (cnt == 1) return found[0];
   return MathMin(found[0], found[1]);
}

double FindSellSlFromSwingHighs(const double &highArr[], int n, int fractalBars, int startIdx, int maxSearch)
{
   double found[2];
   int cnt = 0;
   int limit = MathMin(n - fractalBars, startIdx + maxSearch);
   for (int idx = startIdx; idx < limit && cnt < 2; idx++)
   {
      if (IsSwingHigh(highArr, idx, fractalBars, n))
      {
         found[cnt] = highArr[idx];
         cnt++;
      }
   }
   if (cnt == 0) return 0.0;
   if (cnt == 1) return found[0];
   return MathMax(found[0], found[1]);
}

//====================================================================
// G. Dashboard (OBJ_LABEL + khung nen) va nut Test -- xem OnChartEvent().
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateTestButton(string name, string text, int x, int y, int w, int h, color bg)
{
   if (ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void CreateDashboard()
{
   string keys[] = {"Title", "LastSignal", "Position", "DayPL", "Status"};
   int x = 10, y = 16, dy = 16;
   int panelW = 340, panelH = ArraySize(keys) * dy + 14;

   if (InpShowDashboard)
   {
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

   if (InpShowTestButtons)
   {
      int by = InpShowDashboard ? ((y - 8) + panelH + 6) : y;
      int bw = 90, bh = 22, gap = 6;
      CreateTestButton(DASH_PREFIX + "BtnTestTg",   "Test TG",   x, by, bw, bh, clrDarkSlateGray);
      CreateTestButton(DASH_PREFIX + "BtnTestBuy",  "Test BUY",  x + (bw + gap), by, bw, bh, clrDarkGreen);
      CreateTestButton(DASH_PREFIX + "BtnTestSell", "Test SELL", x + 2 * (bw + gap), by, bw, bh, clrMaroon);
   }
}

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); }

//====================================================================
// H. Mo lenh -- SL theo swing low/high, KHONG CO TP (thoat khi co tin
// hieu Chikou cat nguoc lai, xu ly trong CheckSignal()).
//====================================================================
bool OpenPosition(ENUM_ORDER_TYPE type, double slPrice, bool isTest)
{
   if (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0)
   {
      double dayProfitUSD = CalcDayProfitUSD();
      if (dayProfitUSD <= -MathAbs(InpMaxDailyLossUSD))
      {
         Print("IchimokuChikouEA: da lo ", DoubleToString(dayProfitUSD, 2), " ", AccountInfoString(ACCOUNT_CURRENCY),
               " hom nay, vuot nguong -- TAM DUNG vao lenh MOI");
         g_DbgBlockedDailyLoss++;

         MqlDateTime dtNow;
         TimeToStruct(TimeCurrent(), dtNow);
         dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
         datetime dayStart = StructToTime(dtNow);
         if (g_DailyLossAlertDay != dayStart)
         {
            g_DailyLossAlertDay = dayStart;
            TelegramSendMessage(StringFormat("⚠️ <b>TẠM DỪNG VÀO LỆNH MỚI</b> — %s\n\nĐã lỗ <b>%.2f %s</b> hôm nay, vượt ngưỡng %.2f.",
                                               _Symbol, dayProfitUSD, AccountInfoString(ACCOUNT_CURRENCY), InpMaxDailyLossUSD));
         }
         return false;
      }
   }

   if (InpMaxSpreadUSD > 0 && CurrentSpreadPrice() > InpMaxSpreadUSD)
   {
      Print("IchimokuChikouEA: spread vuot InpMaxSpreadUSD, bo qua vao lenh");
      g_DbgBlockedSpread++;
      return false;
   }

   double price = (type == ORDER_TYPE_BUY) ? CurrentAsk() : CurrentBid();
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (slPrice <= 0)
   {
      Print("IchimokuChikouEA: khong tim duoc du 2 day/dinh tuong doi de dat SL, bo qua vao lenh");
      g_DbgBlockedNoSwing++;
      return false;
   }
   double slDistance = MathAbs(price - slPrice);
   double sl = NormalizeDouble(slPrice, digits);

   double lotToUse = InpUseRiskPercent ? CalcRiskLot(slDistance) : InpLotSize;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = MarginRequiredPerLot(type, price);
   if (marginReq <= 0)
   {
      Print("IchimokuChikouEA: OrderCalcMargin() that bai, bo qua vao lenh");
      g_DbgBlockedMargin++;
      return false;
   }
   if (lotToUse * marginReq > freeMargin)
   {
      Print("IchimokuChikouEA: khong du margin cho lenh lot=", DoubleToString(lotToUse, 2));
      g_DbgBlockedFreeMargin++;
      return false;
   }

   string tag = isTest ? ((type == ORDER_TYPE_BUY) ? "IchiEA TEST BUY" : "IchiEA TEST SELL")
                        : ((type == ORDER_TYPE_BUY) ? "IchiEA BUY" : "IchiEA SELL");

   bool ok;
   if (type == ORDER_TYPE_BUY)
      ok = trade.Buy(lotToUse, _Symbol, price, sl, 0, tag); // 0 = khong dat TP, dung thiet ke chien luoc
   else
      ok = trade.Sell(lotToUse, _Symbol, price, sl, 0, tag);

   if (!ok)
   {
      Print("IchimokuChikouEA: mo lenh that bai, Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      g_DbgOrderSendFail++;
      return false;
   }

   Print("IchimokuChikouEA: ", (isTest ? "[TEST] " : ""), "mo lenh ", EnumToString(type),
         " lot=", DoubleToString(lotToUse, 2), " SL=", DoubleToString(sl, digits), " (khong co TP - thoat theo tin hieu nguoc lai)");

   string dirIcon = (type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string testTag = isTest ? "🧪 [TEST] " : "";
   string lotModeTxt = InpUseRiskPercent ? StringFormat(" (risk %.1f%%)", InpRiskPercent) : "";
   TelegramSendMessage(StringFormat("%s%s <b>MỞ LỆNH %s</b> — %s\n\n📍 Giá vào: <b>%.2f</b>\n🛑 SL: %.2f (2 đáy/đỉnh tương đối gần nhất)\n🎯 TP: Không có — thoát khi Chikou cắt ngược lại\n💰 Lot: %.2f%s",
                                      testTag, dirIcon, EnumToString(type), _Symbol, price, sl, lotToUse, lotModeTxt));
   return true;
}

//====================================================================
// I. Bao dong lenh ve Telegram
//====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagic) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                    HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                    HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   long   dealType    = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   long   reason      = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   string origDir     = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   string reasonTxt   = (reason == DEAL_REASON_SL) ? "Dinh SL" : (reason == DEAL_REASON_TP) ? "Dat TP" : "Tin hieu nguoc lai/dong khac";
   string resultIcon  = (profit >= 0) ? "✅" : "❌";

   TelegramSendMessage(StringFormat("%s <b>ĐÓNG LỆNH %s</b> — %s (%s)\n\n📍 Giá đóng: %.2f\n💵 Kết quả: <b>%s%.2f %s</b>",
                                      resultIcon, origDir, _Symbol, reasonTxt, closePrice,
                                      (profit >= 0 ? "+" : ""), profit, AccountInfoString(ACCOUNT_CURRENCY)));
}

//====================================================================
// J. Dashboard update
//====================================================================
void UpdateDashboard()
{
   if (!InpShowDashboard) return;

   SetLabel(DASH_PREFIX + "Title", StringFormat("=== IchimokuChikouEA (%s, %s) ===", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period())), clrWhite);

   string lastTxt = (g_lastSignalBarTime == 0) ? g_lastSignalTxt
                     : StringFormat("[%s] %s", TimeToString(g_lastSignalBarTime, TIME_DATE | TIME_MINUTES), g_lastSignalTxt);
   SetLabel(DASH_PREFIX + "LastSignal", "Tin hieu gan nhat: " + lastTxt, clrKhaki);

   long  posType   = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0 && PositionSelectByTicket(posTicket))
   {
      string dirTxt = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double slP   = PositionGetDouble(POSITION_SL);
      SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh: %s @ %.2f | SL %.2f | TP: khong co", dirTxt, openP, slP), clrKhaki);
   }
   else
   {
      SetLabel(DASH_PREFIX + "Position", "Lenh: Khong co", clrSilver);
   }

   double dayUSD = CalcDayProfitUSD();
   color  plClr  = (dayUSD >= 0) ? clrLimeGreen : clrTomato;
   SetLabel(DASH_PREFIX + "DayPL", StringFormat("Hom nay: %s%.2f %s", (dayUSD >= 0 ? "+" : ""), dayUSD, AccountInfoString(ACCOUNT_CURRENCY)), plClr);

   bool paused = (InpUseDailyLossLimit && InpMaxDailyLossUSD > 0 && dayUSD <= -MathAbs(InpMaxDailyLossUSD));
   SetLabel(DASH_PREFIX + "Status", paused ? "Trang thai: TAM DUNG (lo qua nguong ngay)" : "Trang thai: Binh thuong",
             paused ? clrOrange : clrLimeGreen);
}

//====================================================================
// K. Phat hien tin hieu Chikou/Span B moi lan co nen moi tren khung EA
// dang chay (vd M15), roi xac nhan them tren khung lon hon (vd H1).
//====================================================================
void CheckSignal()
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (barTime != 0 && barTime != g_LastBarTime);
   if (barTime != 0) g_LastBarTime = barTime;
   if (!isNewBar) return;

   g_DbgBarsProcessed++;

   // --- Buoc 1: tinh Chikou/Span B tren khung dang chay (dung CLOSE[0]=nen vua dong vs RawSpanB(2*N1)) ---
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   int needClose = 2 * InpKijunPeriod + InpSenkouBPeriod + 5;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 0, needClose, closeArr) < needClose) return;

   // shift=1 la nen VUA DONG (an toan, tranh repaint tren nen dang chay); shift=2 la nen truoc do, de xet "vua cat".
   double spanBNow, spanBPrev;
   if (!ComputeRawSpanB(_Symbol, PERIOD_CURRENT, InpSenkouBPeriod, 1 + 2 * InpKijunPeriod, spanBNow)) return;
   if (!ComputeRawSpanB(_Symbol, PERIOD_CURRENT, InpSenkouBPeriod, 2 + 2 * InpKijunPeriod, spanBPrev)) return;

   double closeNow  = closeArr[1];
   double closePrev = closeArr[2];

   bool crossUp   = (closePrev <= spanBPrev) && (closeNow > spanBNow);
   bool crossDown = (closePrev >= spanBPrev) && (closeNow < spanBNow);

   // --- Xu ly THOAT lenh truoc (tin hieu nguoc lai voi lenh dang mo) -- ap dung bat ke co vao lenh moi hay khong ---
   long posType = -1;
   ulong posTicket = GetOpenPosition(posType);
   if (posTicket != 0)
   {
      bool shouldExit = (posType == POSITION_TYPE_BUY && crossDown) || (posType == POSITION_TYPE_SELL && crossUp);
      if (shouldExit)
      {
         Print("IchimokuChikouEA: Chikou cat nguoc lai qua Span B - dong lenh dang mo (khong doi TP)");
         CloseAllPositions();
         posTicket = 0;
         posType = -1;
      }
   }

   if (!crossUp && !crossDown) return;
   if (crossUp) g_DbgCrossUp++;
   if (crossDown) g_DbgCrossDown++;

   if (InpOnePositionOnly && posTicket != 0)
   {
      g_DbgBlockedPyramid++;
      return; // van co lenh dang mo cung huong (khong bi dong o buoc tren) -- khong pyramid
   }

   int direction = crossUp ? 1 : -1;

   // --- Buoc 2: xac nhan tren khung lon hon (vd H1) ---
   if (InpUseH1Filter)
   {
      double confirmClose[];
      ArraySetAsSeries(confirmClose, true);
      int needConfirm = 2 * InpKijunPeriod + InpSenkouBPeriod + 5;
      if (CopyClose(_Symbol, InpConfirmTimeframe, 0, needConfirm, confirmClose) < needConfirm)
      {
         g_DbgBlockedH1Filter++;
         return;
      }
      double confirmSpanBRaw; // Span B "hien tai" cua khung xac nhan (khong dich chuyen -- chi can vi tri gia so voi may B goc tai day, dung y video: "gia phai o phia thuan loi so voi Span B")
      if (!ComputeRawSpanB(_Symbol, InpConfirmTimeframe, InpSenkouBPeriod, 1, confirmSpanBRaw))
      {
         g_DbgBlockedH1Filter++;
         return;
      }
      double confirmPrice = confirmClose[1];

      bool sideOK = (direction == 1) ? (confirmPrice > confirmSpanBRaw) : (confirmPrice < confirmSpanBRaw);
      if (!sideOK)
      {
         Print("IchimokuChikouEA: bi chan boi buoc xac nhan khung lon (gia khong o dung phia Span B)");
         g_DbgBlockedH1Filter++;
         return;
      }

      if (InpConfirmMinDistAtr > 0 && g_AtrHandleConfirm != INVALID_HANDLE)
      {
         double atrConfirm[];
         if (CopyBuffer(g_AtrHandleConfirm, 0, 1, 1, atrConfirm) >= 1)
         {
            double dist = MathAbs(confirmPrice - confirmSpanBRaw);
            if (dist < InpConfirmMinDistAtr * atrConfirm[0])
            {
               Print("IchimokuChikouEA: bi chan boi buoc xac nhan khung lon (khoang cach den Span B qua gan)");
               g_DbgBlockedH1Filter++;
               return;
            }
         }
      }
   }

   // --- Tinh SL theo 2 day/dinh tuong doi gan nhat (fractal), tren KHUNG DANG CHAY ---
   double lowArr[], highArr[];
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(highArr, true);
   int needSwing = InpFractalBars + InpMaxSwingSearch + 5;
   double slPrice = 0.0;
   if (direction == 1)
   {
      if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwing, lowArr) >= needSwing)
         slPrice = FindBuySlFromSwingLows(lowArr, ArraySize(lowArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
   }
   else
   {
      if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwing, highArr) >= needSwing)
         slPrice = FindSellSlFromSwingHighs(highArr, ArraySize(highArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
   }

   // Dem them 1 khoang nho ra ngoai day/dinh (tuy chon) de tranh SL bi cham do "rau nen"
   if (slPrice > 0 && InpSlBufferAtr > 0 && g_AtrHandleEntry != INVALID_HANDLE)
   {
      double atrEntry[];
      if (CopyBuffer(g_AtrHandleEntry, 0, 1, 1, atrEntry) >= 1)
      {
         double buf = InpSlBufferAtr * atrEntry[0];
         slPrice = (direction == 1) ? (slPrice - buf) : (slPrice + buf);
      }
   }

   g_lastSignalTxt = StringFormat("%s @ %.2f", (direction == 1 ? "BUY" : "SELL"), closeNow);
   g_lastSignalBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);

   if (OpenPosition(direction == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, slPrice, false))
   {
      if (direction == 1) g_DbgBuyOpened++; else g_DbgSellOpened++;
   }
}

//====================================================================
// L. Vong doi Expert
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(PriceDistanceToPoints(InpSlippageUSD) > 0 ? PriceDistanceToPoints(InpSlippageUSD) : 1);

   if (InpKijunPeriod <= 0 || InpSenkouBPeriod <= 0)
   {
      Print("IchimokuChikouEA: InpKijunPeriod/InpSenkouBPeriod phai > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpFractalBars <= 0)
   {
      Print("IchimokuChikouEA: InpFractalBars phai > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_AtrHandleEntry = iATR(_Symbol, PERIOD_CURRENT, 14);
   if (g_AtrHandleEntry == INVALID_HANDLE)
      Print("IchimokuChikouEA: canh bao - khong tao duoc ATR handle khung vao lenh, InpSlBufferAtr se bi bo qua");

   if (InpUseH1Filter)
   {
      g_AtrHandleConfirm = iATR(_Symbol, InpConfirmTimeframe, InpConfirmAtrPeriod);
      if (g_AtrHandleConfirm == INVALID_HANDLE)
         Print("IchimokuChikouEA: canh bao - khong tao duoc ATR handle khung xac nhan, InpConfirmMinDistAtr se bi bo qua");
   }

   g_LastBarTime = 0;

   Print("IchimokuChikouEA v1.00: OnInit THANH CONG -- EA bat dau chay tu day.");

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_AtrHandleEntry != INVALID_HANDLE) IndicatorRelease(g_AtrHandleEntry);
   if (g_AtrHandleConfirm != INVALID_HANDLE) IndicatorRelease(g_AtrHandleConfirm);
   DeleteDashboard();

   Print("IchimokuChikouEA: [CHAN DOAN] Tong ket -- nen da xu ly=", g_DbgBarsProcessed,
         " | crossUp=", g_DbgCrossUp, " (Buy mo thanh cong=", g_DbgBuyOpened, ")",
         " | crossDown=", g_DbgCrossDown, " (Sell mo thanh cong=", g_DbgSellOpened, ")");
   Print("IchimokuChikouEA: [CHAN DOAN] Bi chan boi -- xac nhan khung lon=", g_DbgBlockedH1Filter,
         " | spread=", g_DbgBlockedSpread, " | margin=", g_DbgBlockedMargin, " | free margin=", g_DbgBlockedFreeMargin,
         " | dang co lenh (khong pyramid)=", g_DbgBlockedPyramid, " | lo qua nguong ngay=", g_DbgBlockedDailyLoss,
         " | khong du 2 day/dinh tuong doi=", g_DbgBlockedNoSwing, " | gui lenh that bai=", g_DbgOrderSendFail);
}

void OnTick()
{
   UpdateDashboard();
   CheckSignal();
}

//====================================================================
// M. Nut Test tren chart (Test TG / Test BUY / Test SELL) -- Test BUY/SELL
// tu tim SL theo swing low/high that (khong bia so), roi goi dung
// OpenPosition() y het duong di cua tin hieu that.
//====================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == DASH_PREFIX + "BtnTestTg")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      bool tgOk = TelegramSendMessage(StringFormat("🧪 <b>TIN NHẮN TEST</b> — %s\n\nXác nhận Bot Token/Chat ID/định dạng HTML đang hoạt động đúng. Không liên quan lệnh giao dịch thật nào.", _Symbol));
      Alert(tgOk ? "IchimokuChikouEA [TEST]: Da gui tin nhan test len Telegram thanh cong."
                  : "IchimokuChikouEA [TEST]: Gui tin Telegram THAT BAI -- kiem tra Bot Token/Chat ID hoac whitelist api.telegram.org.");
   }
   else if (sparam == DASH_PREFIX + "BtnTestBuy" || sparam == DASH_PREFIX + "BtnTestSell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ENUM_ORDER_TYPE testType = (sparam == DASH_PREFIX + "BtnTestBuy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      long existingType = -1;
      if (GetOpenPosition(existingType) != 0)
      {
         Alert("IchimokuChikouEA [TEST]: Bo qua -- da co lenh dang mo, tranh chong lenh.");
         return;
      }

      double lowArr[], highArr[];
      ArraySetAsSeries(lowArr, true);
      ArraySetAsSeries(highArr, true);
      int needSwing = InpFractalBars + InpMaxSwingSearch + 5;
      double slPrice = 0.0;
      if (testType == ORDER_TYPE_BUY)
      {
         if (CopyLow(_Symbol, PERIOD_CURRENT, 0, needSwing, lowArr) >= needSwing)
            slPrice = FindBuySlFromSwingLows(lowArr, ArraySize(lowArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }
      else
      {
         if (CopyHigh(_Symbol, PERIOD_CURRENT, 0, needSwing, highArr) >= needSwing)
            slPrice = FindSellSlFromSwingHighs(highArr, ArraySize(highArr), InpFractalBars, InpFractalBars + 1, InpMaxSwingSearch);
      }

      bool openOk = OpenPosition(testType, slPrice, true);
      Alert(openOk ? StringFormat("IchimokuChikouEA [TEST]: Da mo lenh %s thanh cong -- xem chi tiet trong Journal.", EnumToString(testType))
                    : StringFormat("IchimokuChikouEA [TEST]: Mo lenh %s THAT BAI -- xem Journal de biet ly do.", EnumToString(testType)));
   }
}
//+------------------------------------------------------------------+
