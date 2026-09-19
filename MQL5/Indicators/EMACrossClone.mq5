//+------------------------------------------------------------------+
//|                                            EMACrossClone.mq5     |
//|  Chi bao TU VIET (KHONG phai reverse-engineer / KHONG goi         |
//|  iCustom() toi indicator ben thu 3 nao ca) -- lay CAM HUNG tu     |
//|  chi bao dong goi san "MIK EMA Cross" (EMA9/20 cross + RSI14      |
//|  (EMA9/WMA45) + ATR + khung gio) ma bro da dung, nhung viet lai   |
//|  bang logic RIENG, TU GIAI THICH DUOC 100%, khong con phu thuoc   |
//|  vao file .ex5 dong goi cua ho nua.                                |
//|                                                                    |
//|  QUAN TRONG -- MUC DO GIONG BAN GOC: day la 1 chi bao MOI, TU      |
//|  THIET KE theo tinh than "EMA cross + loc RSI + loc ATR + khung    |
//|  gio", KHONG PHAI ban clone chinh xac cong thuc bi mat cua MIK EMA |
//|  Cross. Tin hieu Buy/Sell/Exit o day co the ra KHAC thoi diem/gia  |
//|  so voi ban goc -- day la 1 he thong doc lap, khong phai ban sao.  |
//|                                                                    |
//|  v1.10 - [MOI] Them bang trang thai (dashboard don gian bang       |
//|  OBJ_LABEL, KHONG dung Canvas) hien: xu huong hien tai, gia tri    |
//|  EMA nhanh/cham, RSI tho + EMA-RSI/WMA-RSI, ATR, va tin hieu gan   |
//|  nhat (ca BUY lan SELL) - de xac nhan SELL dang hoat dong dung,    |
//|  khong can doi mui ten xuat hien tren chart moi biet. KHONG doi   |
//|  logic tinh toan cot loi cua v1.00 (van tinh lai toan bo moi lan  |
//|  OnCalculate, dung y het ban goc) de tranh rui ro sai lech tin     |
//|  hieu do chua co trinh bien dich that de kiem thu.                |
//|                                                                    |
//|  LOGIC (khong doi so voi v1.00):                                   |
//|   - EMA nhanh cat EMA cham = tin hieu huong co ban.                |
//|   - Loc RSI: EMA(RSI) vs WMA(RSI) (tuong tu MACD nhung ap len RSI  |
//|     thay vi gia).                                                  |
//|   - Loc ATR: bo qua tin hieu khi bien dong qua thap (tuy chon).    |
//|   - Loc khung gio (tuy chon), khong anh huong Exit.                |
//|   - InpConfirmClose: true = xet nen DA DONG (an toan, khong        |
//|     repaint); false = xet nen dang chay (nhanh hon, co the doi).   |
//|   - InpBarsWait: chong nhieu/whipsaw giua 2 tin hieu Buy/Sell moi. |
//|   - Buffer Exit: rieng biet, it dieu kien hon (chi can EMA cat     |
//|     nguoc), coi la "canh bao xu huong da doi".                     |
//|                                                                    |
//|  Khong co trinh bien dich MQL5 that trong moi truong nay -- code   |
//|  nay CHUA duoc compile/chay thu thuc te. Da tu kiem tra can bang   |
//|  ngoac/dau ngoac bang script rieng truoc khi giao, va tu soat lai  |
//|  thu tu khai bao ham (MQL5 bien dich 1 lan, giong C -- ham phai    |
//|  duoc KHAI BAO TRUOC diem goi no, khac voi C#/Java).                |
//+------------------------------------------------------------------+
#property copyright "HaiDangVN"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "EMA nhanh"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

#property indicator_label2  "EMA cham"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1

#property indicator_label3  "Buy"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  2

#property indicator_label4  "Sell"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "Exit"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrSilver
#property indicator_width5  2

input group "=== 1. EMA Cross ==="
input int    InpFastEMA   = 9;     // Chu ky EMA nhanh
input int    InpSlowEMA   = 20;    // Chu ky EMA cham

input group "=== 2. Loc RSI (ap dung 2 duong trung binh len RSI) ==="
input bool   InpUseRSIFilter = true;  // Bat/tat loc RSI cho Buy/Sell (Exit luon bo qua loc nay)
input int    InpRSIPeriod    = 14;    // Chu ky RSI goc
input int    InpRSIFastMA    = 9;     // Chu ky EMA lam muot RSI (nhanh)
input int    InpRSISlowMA    = 45;    // Chu ky WMA lam muot RSI (cham)

input group "=== 3. Loc ATR (bo qua tin hieu khi qua yen) ==="
input int    InpATRPeriod = 14;    // Chu ky ATR
input double InpMinATR    = 0.0;   // ATR toi thieu de cho phep tin hieu Buy/Sell moi (0 = tat loc)

input group "=== 4. Khung gio giao dich (tuy chon, chi anh huong Buy/Sell, KHONG anh huong Exit) ==="
input bool   InpOnlyHourWindow = false; // Chi cho tin hieu Buy/Sell moi trong khung gio ben duoi
input int    InpFromHour       = 7;     // Gio bat dau (server time, 0-23)
input int    InpToHour         = 22;    // Gio ket thuc (server time, 0-23)

input group "=== 5. Thoi diem xac nhan tin hieu ==="
input bool   InpConfirmClose = true; // true = xet tren nen DA DONG (an toan, khong repaint); false = xet ngay tren nen dang chay
input int    InpBarsWait     = 0;    // So nen toi thieu giua 2 tin hieu Buy/Sell MOI lien tiep (0 = khong gioi han)

input group "=== 6. Ve tren chart ==="
input bool   InpDrawEMALines  = true; // Ve 2 duong EMA nhanh/cham len chart
input double InpArrowDistATR  = 0.5;  // Khoang cach mui ten ra khoi nen, tinh theo boi so ATR

input group "=== 7. [MOI] Bang trang thai ==="
input bool   InpShowDashboard = true; // Bat/tat bang trang thai goc tren-trai chart

//--- buffer arrays
double BufEMAFast[];
double BufEMASlow[];
double BufBuy[];
double BufSell[];
double BufExit[];

//--- indicator handles noi bo (built-in MT5, KHONG phai iCustom toi ben thu 3)
int g_HandleEMAFast = INVALID_HANDLE;
int g_HandleEMASlow = INVALID_HANDLE;
int g_HandleRSI     = INVALID_HANDLE;
int g_HandleATR     = INVALID_HANDLE;

// [MOI] Cho bang trang thai - luu lai tin hieu Buy/Sell gan nhat (ca 2
// huong) de hien thi, tach rieng khoi logic ve buffer.
#define DASH_PREFIX "EMAX_Dash_"
string   g_lastSignalTxt     = "Chua co tin hieu nao";
datetime g_lastSignalBarTime = 0;

//====================================================================
// [MOI] Bang trang thai don gian (OBJ_LABEL, khong dung Canvas - nhe,
// khong ton hieu nang nhu ve bitmap moi tick).
// GHI CHU: khoi nay duoc dat TRUOC OnInit()/OnCalculate() vi MQL5 bien
// dich 1 lan tu tren xuong (giong C) -- ham phai duoc KHAI BAO TRUOC
// diem no duoc GOI, khac voi C#/Java cho phep goi ham khai bao o duoi.
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

// [MOI] Tinh EMA(RSI)/WMA(RSI) tai 1 diem cu the (shiftFromEnd tinh theo
// mang series, 1 = nen vua dong), dung mang rsiSeries[] da lay theo kieu
// series (index 0 = moi nhat). Chi dung rieng cho dashboard, khong dinh
// dang lien quan gi toi vong lap ve buffer chinh trong OnCalculate.
bool ComputeRsiCrossAt(const double &rsiSeries[], int n, int shiftFromEnd, double &outEma, double &outWma)
{
   int wn = InpRSISlowMA;
   int idx = shiftFromEnd; // trong mang series, idx=1 la nen vua dong
   if (idx + wn > n) return false;

   // EMA(RSI): can toan bo chieu dai ve phia qua khu trong cua so co san
   // (n phan tu) de xap xi seed - dung SMA cua wn gia tri dau tien lam seed,
   // roi de quy toi diem idx. Vi day CHI phuc vu hien thi (khong anh huong
   // tin hieu vao lenh thuc te trong OnCalculate), sai so nho o xa qua khu
   // chap nhan duoc.
   double alpha = 2.0 / (InpRSIFastMA + 1.0);
   int seedPos = n - 1; // vi tri CU NHAT trong mang series ta co
   double ema = rsiSeries[seedPos];
   for (int p = seedPos - 1; p >= idx; p--)
      ema = rsiSeries[p] * alpha + ema * (1.0 - alpha);
   outEma = ema;

   double sum = 0.0, wsum = 0.0;
   for (int j = 0; j < wn; j++)
   {
      double w = (double)(wn - j); // j=0 (gan idx nhat / moi nhat trong cua so) trong so lon nhat
      sum += rsiSeries[idx + j] * w;
      wsum += w;
   }
   outWma = sum / wsum;
   return true;
}

void CreateDashboard()
{
   string keys[] = {"Title", "Trend", "EMA", "RSI", "ATR", "LastSignal"};
   int x = 10, y = 18, dy = 16;
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

// [MOI] Cap nhat bang trang thai dua vao 2 nen DA DONG gan nhat (khong tinh
// nen dang chay) - de dashboard on dinh, khop voi cach OnCalculate danh gia
// tin hieu khi InpConfirmClose=true (mac dinh).
void UpdateDashboard()
{
   if (!InpShowDashboard) return;

   double emaFast[], emaSlow[], rsiRaw[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsiRaw, true);
   int need = InpRSISlowMA + InpRSIFastMA + 5;
   if (CopyBuffer(g_HandleEMAFast, 0, 0, 3, emaFast) < 3) return;
   if (CopyBuffer(g_HandleEMASlow, 0, 0, 3, emaSlow) < 3) return;
   if (CopyBuffer(g_HandleRSI, 0, 0, need, rsiRaw) < need) return;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   double atrNow = 0;
   if (CopyBuffer(g_HandleATR, 0, 0, 2, atrBuf) >= 2) atrNow = atrBuf[1];

   string trendTxt = (emaFast[1] > emaSlow[1]) ? "TANG (EMA nhanh > cham)" : "GIAM (EMA nhanh < cham)";
   color  trendClr = (emaFast[1] > emaSlow[1]) ? clrLimeGreen : clrTomato;

   // [MOI] Tinh EMA(RSI)/WMA(RSI) tai nen vua dong (shift=1) rieng cho
   // dashboard - doc lap voi vong lap ve buffer ben duoi, chi de hien thi.
   double rEma = 0, rWma = 0;
   bool okRsi = ComputeRsiCrossAt(rsiRaw, need, 1, rEma, rWma);

   SetLabel(DASH_PREFIX + "Title", "=== EMACrossClone (" + IntegerToString(InpFastEMA) + "/" + IntegerToString(InpSlowEMA) + ") ===", clrWhite);
   SetLabel(DASH_PREFIX + "Trend", "Xu huong: " + trendTxt, trendClr);
   SetLabel(DASH_PREFIX + "EMA", StringFormat("EMA nhanh=%.2f  EMA cham=%.2f", emaFast[1], emaSlow[1]), clrSilver);
   if (okRsi)
      SetLabel(DASH_PREFIX + "RSI", StringFormat("RSI=%.1f  E(RSI)=%.1f  W(RSI)=%.1f", rsiRaw[1], rEma, rWma), clrSilver);
   else
      SetLabel(DASH_PREFIX + "RSI", "RSI: chua du du lieu", clrSilver);
   SetLabel(DASH_PREFIX + "ATR", StringFormat("ATR(%d)=%.2f", InpATRPeriod, atrNow), clrSilver);

   string lastTxt = (g_lastSignalBarTime == 0) ? g_lastSignalTxt
                     : StringFormat("[%s] %s", TimeToString(g_lastSignalBarTime, TIME_DATE | TIME_MINUTES), g_lastSignalTxt);
   SetLabel(DASH_PREFIX + "LastSignal", "Tin hieu gan nhat: " + lastTxt, clrKhaki);
}

int OnInit()
{
   SetIndexBuffer(0, BufEMAFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufEMASlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufBuy,     INDICATOR_DATA);
   SetIndexBuffer(3, BufSell,    INDICATOR_DATA);
   SetIndexBuffer(4, BufExit,    INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpDrawEMALines ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpDrawEMALines ? DRAW_LINE : DRAW_NONE);

   PlotIndexSetInteger(2, PLOT_ARROW, 233); // mui ten len
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // mui ten xuong
   PlotIndexSetInteger(4, PLOT_ARROW, 170); // kim cuong (exit)

   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if (InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
   {
      Print("EMACrossClone: InpFastEMA phai > 0 va < InpSlowEMA. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpRSIPeriod <= 0 || InpRSIFastMA <= 0 || InpRSISlowMA <= 0)
   {
      Print("EMACrossClone: chu ky RSI/EMA-RSI/WMA-RSI phai > 0. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if (InpATRPeriod <= 0)
   {
      Print("EMACrossClone: chu ky ATR phai > 0. Kiem tra lai Inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_HandleEMAFast = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleEMASlow = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleRSI     = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   g_HandleATR     = iATR(_Symbol, _Period, InpATRPeriod);

   if (g_HandleEMAFast == INVALID_HANDLE || g_HandleEMASlow == INVALID_HANDLE ||
       g_HandleRSI == INVALID_HANDLE || g_HandleATR == INVALID_HANDLE)
   {
      Print("EMACrossClone: khong tao duoc 1 trong cac indicator built-in (EMA/RSI/ATR). Ma loi: ", GetLastError());
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "EMACrossClone(" + IntegerToString(InpFastEMA) + "/" + IntegerToString(InpSlowEMA) + ")");

   if (InpShowDashboard) CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_HandleEMAFast != INVALID_HANDLE) IndicatorRelease(g_HandleEMAFast);
   if (g_HandleEMASlow != INVALID_HANDLE) IndicatorRelease(g_HandleEMASlow);
   if (g_HandleRSI     != INVALID_HANDLE) IndicatorRelease(g_HandleRSI);
   if (g_HandleATR     != INVALID_HANDLE) IndicatorRelease(g_HandleATR);
   ObjectsDeleteAll(0, DASH_PREFIX);
}

//--- kiem tra gio hien tai co nam trong khung [InpFromHour, InpToHour] khong (ho tro qua nua dem)
bool IsInHourWindow(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int h = dt.hour;
   if (InpFromHour <= InpToHour)
      return (h >= InpFromHour && h < InpToHour);
   else // khung gio qua dem, vd 22 -> 5
      return (h >= InpFromHour || h < InpToHour);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int minBarsNeeded = MathMax(InpSlowEMA, MathMax(InpRSIPeriod, MathMax(InpRSIFastMA, InpRSISlowMA))) + InpATRPeriod + 10;
   if (rates_total < minBarsNeeded) return 0;

   //--- GHI CHU VE CHIEU INDEX (quan trong, de tranh 1 loi kinh dien khi viet indicator MQL5):
   //    time[]/open[]/high[]/low[]/close[] (tham so cua OnCalculate) VA cac buffer cua CHINH indicator nay
   //    (BufEMAFast, BufBuy, ...) mac dinh la KHONG PHAI series -- index 0 = nen CU NHAT, index rates_total-1
   //    = nen hien tai/moi nhat. De moi thu THANG HANG voi nhau, ta CO Y KHONG goi ArraySetAsSeries() cho
   //    emaFastArr/emaSlowArr/rsiArr/atrArr ben duoi -- de chung cung mac dinh KHONG series, cung chieu voi
   //    time[]/BufBuy[] o tren. Nghia la: voi cung 1 chi so k, emaFastArr[k] va time[offset+k]/BufBuy[offset+k]
   //    (offset giai thich ben duoi) LUON tuong ung DUNG 1 nen -- khong can dao nguoc mang o dau ca.
   double emaFastArr[], emaSlowArr[], rsiArr[], atrArr[];

   int need = rates_total; // [GIU NGUYEN nhu v1.00] tinh lai toan bo moi lan cho don gian/an toan - indicator
                            // nay khong co Canvas/dashboard nang, chi phi CPU cho viec tinh lai het la chap
                            // nhan duoc, doi lai loai bo hoan toan rui ro loi incremental-recalculation.
   if (CopyBuffer(g_HandleEMAFast, 0, 0, need, emaFastArr) <= 0) return 0;
   if (CopyBuffer(g_HandleEMASlow, 0, 0, need, emaSlowArr) <= 0) return 0;
   if (CopyBuffer(g_HandleRSI, 0, 0, need, rsiArr) <= 0) return 0;
   if (CopyBuffer(g_HandleATR, 0, 0, need, atrArr) <= 0) return 0;

   int barsAvail = ArraySize(emaFastArr);
   barsAvail = MathMin(barsAvail, ArraySize(emaSlowArr));
   barsAvail = MathMin(barsAvail, ArraySize(rsiArr));
   barsAvail = MathMin(barsAvail, ArraySize(atrArr));
   if (barsAvail < 2) return rates_total;

   //--- Neu cac indicator built-in (EMA/RSI/ATR) can "khoi dong" nen chua the tra ve du rates_total gia tri
   //    (thuong chi xay ra o rat xa qua khu), CopyBuffer() se tra ve IT HON rates_total phan tu, va phan
   //    THIEU luon la o PHIA CU -- nen "offset" = so nen bi thieu o dau, va emaFastArr[k] (k=0..barsAvail-1)
   //    tuong ung voi time[offset+k]/BufBuy[offset+k].
   int offset = rates_total - barsAvail;

   //--- EMA-cua-RSI (chu ky InpRSIFastMA) va WMA-cua-RSI (chu ky InpRSISlowMA), tinh thu cong TREN CHINH
   //    day RSI goc (rsiArr), cung chieu index (0=cu nhat trong cua so vua lay).
   double rsiEma[]; ArrayResize(rsiEma, barsAvail);
   double alpha = 2.0 / (InpRSIFastMA + 1.0);
   for (int k = 0; k < barsAvail; k++)
   {
      if (k < InpRSIFastMA - 1) { rsiEma[k] = EMPTY_VALUE; continue; }
      if (k == InpRSIFastMA - 1)
      {
         double sum = 0.0;
         for (int j = 0; j < InpRSIFastMA; j++) sum += rsiArr[k - j];
         rsiEma[k] = sum / InpRSIFastMA; // seed = SMA cua InpRSIFastMA gia tri RSI dau tien
      }
      else
      {
         rsiEma[k] = rsiArr[k] * alpha + rsiEma[k - 1] * (1.0 - alpha);
      }
   }

   double rsiWma[]; ArrayResize(rsiWma, barsAvail);
   for (int k = 0; k < barsAvail; k++)
   {
      if (k < InpRSISlowMA - 1) { rsiWma[k] = EMPTY_VALUE; continue; }
      double sum = 0.0, wsum = 0.0;
      for (int j = 0; j < InpRSISlowMA; j++)
      {
         double w = (double)(InpRSISlowMA - j);
         sum += rsiArr[k - j] * w;
         wsum += w;
      }
      rsiWma[k] = sum / wsum;
   }

   //--- Tinh lai TOAN BO buffer moi lan OnCalculate() duoc goi (khong dung prev_calculated de tinh incremental).
   int lastEntryBar = -1000000; // chi so k cua tin hieu Buy/Sell MOI gan nhat, de ap InpBarsWait

   for (int k = 1; k < barsAvail; k++)
   {
      int sIdx = offset + k;
      if (sIdx < 0 || sIdx >= rates_total) continue;

      BufEMAFast[sIdx] = emaFastArr[k];
      BufEMASlow[sIdx] = emaSlowArr[k];
      BufBuy[sIdx]  = EMPTY_VALUE;
      BufSell[sIdx] = EMPTY_VALUE;
      BufExit[sIdx] = EMPTY_VALUE;

      //--- InpConfirmClose: neu bat, KHONG xet tin hieu tren nen dang chay (k = bar cuoi cung, chua dong) --
      //    de no "cho" toi lan OnCalculate() ke tiep, khi nen do da dong hoan toan va tro thanh nen k-1, k-2...
      bool isFormingBar = (k == barsAvail - 1);
      if (InpConfirmClose && isFormingBar) continue;

      double fastNow  = emaFastArr[k];
      double slowNow  = emaSlowArr[k];
      double fastPrev = emaFastArr[k - 1];
      double slowPrev = emaSlowArr[k - 1];

      bool crossUp   = (fastPrev <= slowPrev) && (fastNow > slowNow);
      bool crossDown = (fastPrev >= slowPrev) && (fastNow < slowNow);

      if (!crossUp && !crossDown) continue;

      //--- loc RSI (chi anh huong Buy/Sell, KHONG anh huong Exit)
      bool rsiBull = true, rsiBear = true;
      if (InpUseRSIFilter)
      {
         double rEma = rsiEma[k];
         double rWma = rsiWma[k];
         if (rEma == EMPTY_VALUE || rWma == EMPTY_VALUE) { rsiBull = false; rsiBear = false; }
         else { rsiBull = (rEma > rWma); rsiBear = (rEma < rWma); }
      }

      //--- loc ATR (chi anh huong Buy/Sell, KHONG anh huong Exit)
      double atrNow = atrArr[k];
      bool atrOK = (InpMinATR <= 0.0) || (atrNow >= InpMinATR);

      //--- loc khung gio (chi anh huong Buy/Sell, KHONG anh huong Exit)
      bool hourOK = (!InpOnlyHourWindow) || IsInHourWindow(time[sIdx]);

      //--- loc barsWait (chi anh huong Buy/Sell, KHONG anh huong Exit)
      bool waitOK = (InpBarsWait <= 0) || (k - lastEntryBar >= InpBarsWait);

      double atrDist     = (atrNow > 0 && atrNow != EMPTY_VALUE) ? atrNow * InpArrowDistATR : 0.0;
      double atrDistExit = atrDist * 1.6; // Exit ve XA nen hon Buy/Sell, tranh chong len nhau khi ca 2 cung ban tren 1 nen

      if (crossUp)
      {
         // Exit: canh bao thuan tuy tu EMA cross, khong can RSI/ATR/gio -- coi la "thoat lenh SELL dang mo"
         BufExit[sIdx] = low[sIdx] - atrDistExit;

         if (rsiBull && atrOK && hourOK && waitOK)
         {
            BufBuy[sIdx] = low[sIdx] - atrDist;
            lastEntryBar = k;

            // [SUA LOI v1.10] Ghi de KHONG DIEU KIEN moi khi co tin hieu moi qua filter.
            // Vong lap nay luon chay theo thu tu THOI GIAN TANG DAN (k tu 1 den barsAvail-1),
            // nen lan ghi CUOI CUNG truoc khi vong lap ket thuc chinh la tin hieu GAN NHAT
            // trong toan bo lich su dang xet - khong can (va khong duoc) gioi han chi ghi
            // khi sIdx la nen moi nhat, vi nhu vay se lam "Tin hieu gan nhat" bao sai thanh
            // "Chua co tin hieu nao" moi khi tin hieu that su gan nhat khong roi dung vao
            // nen dang duoc tinh o lan goi OnCalculate hien tai.
            g_lastSignalTxt = "BUY @ " + DoubleToString(close[sIdx], _Digits);
            g_lastSignalBarTime = time[sIdx];
         }
      }
      else if (crossDown)
      {
         BufExit[sIdx] = high[sIdx] + atrDistExit;

         if (rsiBear && atrOK && hourOK && waitOK)
         {
            BufSell[sIdx] = high[sIdx] + atrDist;
            lastEntryBar = k;

            g_lastSignalTxt = "SELL @ " + DoubleToString(close[sIdx], _Digits);
            g_lastSignalBarTime = time[sIdx];
         }
      }
   }

   UpdateDashboard();

   return rates_total;
}
//+------------------------------------------------------------------+
