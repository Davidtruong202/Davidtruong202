//+------------------------------------------------------------------+
//|                                              EMACross_EA.mq5     |
//|  EA TU DONG VAO LENH - khong qua Telegram, khong phu thuoc MIK.   |
//|  Tu tinh tin hieu ngay trong EA bang dung logic cua chi bao        |
//|  EMACrossClone.mq5 (EMA9/20 cross + loc RSI(EMA9/WMA45) + loc ATR  |
//|  + loc khung gio), roi tu mo lenh TP1/TP2 + doi SL ve breakeven +  |
//|  trailing - dung y het co che da kiem chung trong TelegramSignal_EA.|
//|                                                                    |
//|  BANG TREN CHART: moi tin hieu la 1 dong (Gio/Huong/Entry/SL/TP1/  |
//|  TP2), tu cap nhat tich OK (dat TP) hoac SL (dinh SL/dong som)     |
//|  ngay khi lenh tuong ung dong - khong can doi tin nhan Telegram.   |
//|                                                                    |
//|  CHUA co thong bao Telegram (theo dung yeu cau: lam EA vao lenh    |
//|  truoc, phan bao TP/SL qua Telegram se lam sau).                  |
//+------------------------------------------------------------------+
#property copyright "HaiDangVN"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== 1. EMA Cross ==="
input int    InpFastEMA   = 9;     // Chu ky EMA nhanh
input int    InpSlowEMA   = 20;    // Chu ky EMA cham

input group "=== 2. Loc RSI (EMA(RSI) vs WMA(RSI), giong logic MIK) ==="
input bool   InpUseRSIFilter = true;  // Bat/tat loc RSI cho tin hieu vao lenh
input int    InpRSIPeriod    = 14;
input int    InpRSIFastMA    = 9;
input int    InpRSISlowMA    = 45;

input group "=== 3. Loc ATR (bo qua tin hieu khi qua yen) ==="
input int    InpATRPeriod = 14;
input double InpMinATR    = 0.0;   // ATR toi thieu de cho phep vao lenh (0 = tat loc)

input group "=== 4. Khung gio giao dich (tuy chon) ==="
input bool   InpOnlyHourWindow = false;
input int    InpFromHour       = 7;
input int    InpToHour         = 22;

input group "=== 5. Chong nhieu/whipsaw ==="
input int    InpMinBarsBetweenTrades = 0; // So nen toi thieu giua 2 lan vao lenh MOI (0 = khong gioi han)

input group "=== 6. SL/TP1/TP2 theo boi so ATR (mac dinh giong quy uoc MIK) ==="
input double InpSlAtr  = 1.5;
input double InpTp1Atr = 1.5;
input double InpTp2Atr = 3.0;

input group "=== 7. Khoi luong lenh ==="
input bool   InpUseRiskPercent = false; // true: tu tinh lot theo % Balance; false: dung lot co dinh
input double InpRiskPercent    = 1.0;
input double InpDefaultLot     = 0.01;
input double InpMaxLotCap      = 1.0;

input group "=== 8. Vao 2 lenh TP1/TP2 + breakeven + trailing (giong TelegramSignal_EA) ==="
input bool   InpUseDualTpMode        = true;
input bool   InpMoveToBreakevenOnTp1 = true;
input bool   InpUseTrailingAfterTp1  = true;
input double InpTrailStartAtr        = 0.5;
input double InpTrailDistanceAtr     = 0.75;
input double InpTrailStepAtr         = 0.1;

input group "=== 9. Tu dong dong lenh som khi xu huong dao chieu ==="
input bool   InpUseEarlyExit = true; // Neu trang thai EMA/RSI doi huong nguoc voi lenh dang mo, dong lenh ngay (khong doi SL)

input group "=== 10. An toan ==="
input ulong  InpMagicNumber     = 20260919;
input bool   InpOnePositionOnly = true;

input group "=== 11. Bang lenh tren chart ==="
input bool   InpShowDashboard = true;
input int    InpMaxTableRows  = 8;  // So dong lenh gan nhat hien trong bang (1-20)

//====================================================================
// Globals
//====================================================================
int      g_HandleEMAFast = INVALID_HANDLE;
int      g_HandleEMASlow = INVALID_HANDLE;
int      g_HandleRSI     = INVALID_HANDLE;
int      g_HandleATR     = INVALID_HANDLE;

datetime g_lastBarTime     = 0;
datetime g_lastEntryBarTime = 0;

ulong    g_trailingTicket = 0;

string   g_trendTxt = "Chua co du lieu";
double   g_dashEmaFast = 0, g_dashEmaSlow = 0, g_dashRsi = 0, g_dashRsiEma = 0, g_dashRsiWma = 0, g_dashAtr = 0;

#define DASH_PREFIX "EMAX_EA_Dash_"
#define TABLE_ROW_PREFIX "EMAX_EA_Row_"

//--- 1 dong trong bang lenh tren chart, ung voi 1 tin hieu (1 hoac 2 lenh TP1/TP2)
struct TradeRow
{
   datetime openTime;
   int      dir;        // 1 = BUY, -1 = SELL
   double   entry;
   double   sl;
   double   tp1;
   double   tp2;
   bool     hasTp2;      // true = che do 2 lenh (dual TP), false = 1 lenh don
   ulong    tp1Ticket;
   ulong    tp2Ticket;
   bool     tp1Closed;
   bool     tp1WasTp;    // true = dong do dat TP1, false = dong do dinh SL/dong som
   bool     tp2Closed;
   bool     tp2WasTp;
};
TradeRow g_rows[];

//====================================================================
// A. Helpers thuan tuy (khong goi ham tu viet khac)
//====================================================================
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
   if (slDistancePrice <= 0) return InpDefaultLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || tickValue <= 0) return InpDefaultLot;

   double valuePerPriceUnit = tickValue / tickSize;
   if (valuePerPriceUnit <= 0) return InpDefaultLot;

   double lot = riskAmount / (slDistancePrice * valuePerPriceUnit);
   return NormalizeLot(lot);
}

bool IsInHourWindow(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int h = dt.hour;
   if (InpFromHour <= InpToHour)
      return (h >= InpFromHour && h < InpToHour);
   else
      return (h >= InpFromHour || h < InpToHour);
}

//====================================================================
// B. Vi the cua EA nay (theo magic+symbol)
//====================================================================
bool PositionExists()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      return true;
   }
   return false;
}

int GetPositionDirection()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}

void CloseAllPositions()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      trade.PositionClose(ticket);
   }
}

ulong FindPositionByComment(string tag)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      if (StringFind(PositionGetString(POSITION_COMMENT), tag) >= 0) return ticket;
   }
   return 0;
}

//====================================================================
// C. Bang lenh (du lieu) - g_rows[], moi phan tu la 1 tin hieu da vao lenh
//====================================================================
void AddTradeRow(int dir, double entry, double sl, double tp1, double tp2, bool hasTp2, ulong tp1Ticket, ulong tp2Ticket)
{
   int n = ArraySize(g_rows);
   ArrayResize(g_rows, n + 1);
   g_rows[n].openTime  = TimeCurrent();
   g_rows[n].dir       = dir;
   g_rows[n].entry     = entry;
   g_rows[n].sl        = sl;
   g_rows[n].tp1       = tp1;
   g_rows[n].tp2       = tp2;
   g_rows[n].hasTp2    = hasTp2;
   g_rows[n].tp1Ticket = tp1Ticket;
   g_rows[n].tp2Ticket = tp2Ticket;
   g_rows[n].tp1Closed = false;
   g_rows[n].tp1WasTp  = false;
   g_rows[n].tp2Closed = !hasTp2; // che do 1 lenh: coi TP2 la "khong ap dung", khong can cho dong
   g_rows[n].tp2WasTp  = false;

   int maxRows = InpMaxTableRows;
   if (maxRows < 1) maxRows = 1;
   if (maxRows > 20) maxRows = 20;
   int cur = ArraySize(g_rows);
   if (cur > maxRows)
   {
      int removeCount = cur - maxRows;
      for (int i = 0; i < cur - removeCount; i++)
         g_rows[i] = g_rows[i + removeCount];
      ArrayResize(g_rows, cur - removeCount);
   }
}

// Tim dong (con dang mo) chua ticket nay - dung khi 1 lenh dong de biet no
// thuoc tin hieu nao va la chan TP1 hay TP2. legOut: 1=TP1, 2=TP2.
int FindRowByTicket(ulong ticket, int &legOut)
{
   legOut = 0;
   for (int i = ArraySize(g_rows) - 1; i >= 0; i--)
   {
      if (g_rows[i].tp1Ticket == ticket && !g_rows[i].tp1Closed) { legOut = 1; return i; }
      if (g_rows[i].hasTp2 && g_rows[i].tp2Ticket == ticket && !g_rows[i].tp2Closed) { legOut = 2; return i; }
   }
   return -1;
}

//====================================================================
// D. Tinh EMA(RSI)/WMA(RSI) tai 1 diem cu the (dung chung cho tin hieu vao
// lenh va cho bang trang thai) - copy tu EMACrossClone.mq5 (da kiem chung).
//====================================================================
bool ComputeRsiCrossAt(const double &rsiSeries[], int n, int shiftFromEnd, double &outEma, double &outWma)
{
   int wn = InpRSISlowMA;
   int idx = shiftFromEnd;
   if (idx + wn > n) return false;

   double alpha = 2.0 / (InpRSIFastMA + 1.0);
   int seedPos = n - 1;
   double ema = rsiSeries[seedPos];
   for (int p = seedPos - 1; p >= idx; p--)
      ema = rsiSeries[p] * alpha + ema * (1.0 - alpha);
   outEma = ema;

   double sum = 0.0, wsum = 0.0;
   for (int j = 0; j < wn; j++)
   {
      double w = (double)(wn - j);
      sum += rsiSeries[idx + j] * w;
      wsum += w;
   }
   outWma = sum / wsum;
   return true;
}

//====================================================================
// E. Dashboard (trang thai + bang lenh)
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   if (!InpShowDashboard) return;

   string headKeys[] = {"Title", "Trend", "EMA", "RSI", "ATR", "Position", "TableHead"};
   int x = 10, y = 18, dy = 16;
   for (int i = 0; i < ArraySize(headKeys); i++)
   {
      string name = DASH_PREFIX + headKeys[i];
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

   int maxRows = InpMaxTableRows;
   if (maxRows < 1) maxRows = 1;
   if (maxRows > 20) maxRows = 20;
   int tableY = y + ArraySize(headKeys) * dy;
   for (int i = 0; i < maxRows; i++)
   {
      string name = TABLE_ROW_PREFIX + IntegerToString(i);
      if (ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, tableY + i * dy);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT, "");
   }
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
   ObjectsDeleteAll(0, TABLE_ROW_PREFIX);
}

// "OK" = dat TP, "SL" = dinh SL/dong som, ".." = con dang mo, "--" = khong dung (che do 1 lenh)
string LegStatusTxt(bool applicable, bool closed, bool wasTp)
{
   if (!applicable) return "--";
   if (!closed) return "..";
   return wasTp ? "OK" : "SL";
}

void UpdateDashboardTable()
{
   int maxRows = InpMaxTableRows;
   if (maxRows < 1) maxRows = 1;
   if (maxRows > 20) maxRows = 20;

   SetLabel(DASH_PREFIX + "TableHead", "Gio      Huong Entry     SL       TP1[..]    TP2[..]", clrWhite);

   int n = ArraySize(g_rows);
   for (int slot = 0; slot < maxRows; slot++)
   {
      string name = TABLE_ROW_PREFIX + IntegerToString(slot);
      int rowIdx = n - 1 - slot; // dong moi nhat hien tren cung
      if (rowIdx < 0)
      {
         SetLabel(name, "", clrSilver);
         continue;
      }

      string dirTxt = (g_rows[rowIdx].dir == 1) ? "BUY " : "SELL";
      string tp1St  = LegStatusTxt(true, g_rows[rowIdx].tp1Closed, g_rows[rowIdx].tp1WasTp);
      string tp2St  = LegStatusTxt(g_rows[rowIdx].hasTp2, g_rows[rowIdx].tp2Closed, g_rows[rowIdx].tp2WasTp);

      bool allDone = g_rows[rowIdx].tp1Closed && g_rows[rowIdx].tp2Closed;
      bool anyWin  = (g_rows[rowIdx].tp1Closed && g_rows[rowIdx].tp1WasTp) ||
                     (g_rows[rowIdx].hasTp2 && g_rows[rowIdx].tp2Closed && g_rows[rowIdx].tp2WasTp);
      color rowClr = !allDone ? clrKhaki : (anyWin ? clrLimeGreen : clrTomato);

      string txt = StringFormat("%s %s %-9.2f %-8.2f TP1:%-8.2f[%s] TP2:%-8.2f[%s]",
                                  TimeToString(g_rows[rowIdx].openTime, TIME_MINUTES), dirTxt,
                                  g_rows[rowIdx].entry, g_rows[rowIdx].sl,
                                  g_rows[rowIdx].tp1, tp1St, g_rows[rowIdx].tp2, tp2St);
      SetLabel(name, txt, rowClr);
   }
}

void UpdateDashboard()
{
   if (!InpShowDashboard) return;

   SetLabel(DASH_PREFIX + "Title", "=== EMACross_EA (" + IntegerToString(InpFastEMA) + "/" + IntegerToString(InpSlowEMA) + ") ===", clrWhite);
   SetLabel(DASH_PREFIX + "Trend", "Xu huong: " + g_trendTxt,
             (StringFind(g_trendTxt, "TANG") >= 0) ? clrLimeGreen : (StringFind(g_trendTxt, "GIAM") >= 0 ? clrTomato : clrSilver));
   SetLabel(DASH_PREFIX + "EMA", StringFormat("EMA nhanh=%.2f  EMA cham=%.2f", g_dashEmaFast, g_dashEmaSlow), clrSilver);
   SetLabel(DASH_PREFIX + "RSI", StringFormat("RSI=%.1f  E(RSI)=%.1f  W(RSI)=%.1f", g_dashRsi, g_dashRsiEma, g_dashRsiWma), clrSilver);
   SetLabel(DASH_PREFIX + "ATR", StringFormat("ATR(%d)=%.2f", InpATRPeriod, g_dashAtr), clrSilver);

   bool hasPos = PositionExists();
   SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh dang mo: %s", hasPos ? "CO" : "KHONG"), hasPos ? clrLimeGreen : clrSilver);

   UpdateDashboardTable();
}

//====================================================================
// F. Mo lenh (dual TP1/TP2 giong TelegramSignal_EA, hoac 1 lenh don)
//====================================================================
void ExecuteSignal(int direction)
{
   if (InpOnePositionOnly && PositionExists())
      return;

   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   if (CopyBuffer(g_HandleATR, 0, 0, 2, atrVal) < 2) return;
   double atr = atrVal[1];
   if (atr <= 0) return;

   double totalLot = InpUseRiskPercent ? MathMin(CalcRiskLot(atr * InpSlAtr), InpMaxLotCap)
                                        : MathMin(InpDefaultLot, InpMaxLotCap);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (!InpUseDualTpMode)
   {
      double price = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble((direction == 1) ? price - atr * InpSlAtr  : price + atr * InpSlAtr,  digits);
      double tp = NormalizeDouble((direction == 1) ? price + atr * InpTp2Atr : price - atr * InpTp2Atr, digits);

      bool ok = (direction == 1) ? trade.Buy(totalLot, _Symbol, price, sl, tp, "EMAX Signal")
                                  : trade.Sell(totalLot, _Symbol, price, sl, tp, "EMAX Signal");
      if (!ok) { PrintFormat("[EMACross_EA] Mo lenh don that bai, retcode=%d", trade.ResultRetcode()); return; }

      ulong ticket = FindPositionByComment("EMAX Signal");
      AddTradeRow(direction, price, sl, tp, 0, false, ticket, 0);
      g_lastEntryBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);
      PrintFormat("[EMACross_EA] Da mo lenh don %s @ %.2f SL=%.2f TP=%.2f Lot=%.2f",
                   (direction == 1 ? "BUY" : "SELL"), price, sl, tp, totalLot);
      return;
   }

   double legLot1 = NormalizeLot(totalLot / 2.0);
   double legLot2 = NormalizeLot(totalLot - legLot1);

   double entryPrice, useSl, useTp1, useTp2;
   bool ok1, ok2;
   if (direction == 1)
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      useSl  = NormalizeDouble(entryPrice - atr * InpSlAtr,  digits);
      useTp1 = NormalizeDouble(entryPrice + atr * InpTp1Atr, digits);
      useTp2 = NormalizeDouble(entryPrice + atr * InpTp2Atr, digits);
      ok1 = trade.Buy(legLot1, _Symbol, entryPrice, useSl, useTp1, "EMAX TP1");
      ok2 = trade.Buy(legLot2, _Symbol, entryPrice, useSl, useTp2, "EMAX TP2");
   }
   else
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      useSl  = NormalizeDouble(entryPrice + atr * InpSlAtr,  digits);
      useTp1 = NormalizeDouble(entryPrice - atr * InpTp1Atr, digits);
      useTp2 = NormalizeDouble(entryPrice - atr * InpTp2Atr, digits);
      ok1 = trade.Sell(legLot1, _Symbol, entryPrice, useSl, useTp1, "EMAX TP1");
      ok2 = trade.Sell(legLot2, _Symbol, entryPrice, useSl, useTp2, "EMAX TP2");
   }

   if (!ok1 && !ok2)
   {
      PrintFormat("[EMACross_EA] Mo ca 2 lenh TP1/TP2 deu that bai, retcode=%d", trade.ResultRetcode());
      return;
   }

   ulong tp1Ticket = FindPositionByComment("EMAX TP1");
   ulong tp2Ticket = FindPositionByComment("EMAX TP2");
   AddTradeRow(direction, entryPrice, useSl, useTp1, useTp2, true, tp1Ticket, tp2Ticket);
   g_lastEntryBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);

   PrintFormat("[EMACross_EA] Da mo tin hieu %s @ %.2f | SL=%.2f TP1=%.2f(#%I64u) TP2=%.2f(#%I64u) | Lot moi lenh=%.2f/%.2f",
                (direction == 1 ? "BUY" : "SELL"), entryPrice, useSl, useTp1, tp1Ticket, useTp2, tp2Ticket, legLot1, legLot2);
}

// [Giong TelegramSignal_EA] Khi lenh TP1 dong (dat TP), doi SL lenh TP2 ve
// dung gia vao lenh (breakeven) - de "khong bao gio lo" tren lenh con lai.
void MoveToBreakeven(ulong ticket)
{
   if (!PositionSelectByTicket(ticket)) return;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl = PositionGetDouble(POSITION_SL);
   double curTp = PositionGetDouble(POSITION_TP);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double newSl = NormalizeDouble(openPrice, digits);
   if (MathAbs(curSl - newSl) < _Point) return;
   if (trade.PositionModify(ticket, newSl, curTp))
      PrintFormat("[EMACross_EA] TP1 da dong - doi SL lenh TP2 (#%I64u) ve breakeven", ticket);
   else
      PrintFormat("[EMACross_EA] Loi doi SL ve breakeven cho lenh #%I64u: %d", ticket, trade.ResultRetcode());
}

// [Giong TelegramSignal_EA] Sau khi da ve breakeven, tiep tuc keo SL theo gia
// (chi keo theo huong co loi) de giu them loi nhuan neu gia chay gan TP2 roi
// dao chieu, thay vi tra het ve dung breakeven.
void TrailTp2Leg()
{
   if (!InpUseTrailingAfterTp1) return;
   if (g_trailingTicket == 0) return;
   if (!PositionSelectByTicket(g_trailingTicket)) { g_trailingTicket = 0; return; }

   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   if (CopyBuffer(g_HandleATR, 0, 0, 2, atrVal) < 2) return;
   double atr = atrVal[1];
   if (atr <= 0) return;

   long   type      = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl = PositionGetDouble(POSITION_SL);
   double curTp = PositionGetDouble(POSITION_TP);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double startDist = InpTrailStartAtr    * atr;
   double trailDist = InpTrailDistanceAtr * atr;
   double stepDist  = InpTrailStepAtr     * atr;

   if (type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if (bid < openPrice + startDist) return;
      double newSl = NormalizeDouble(bid - trailDist, digits);
      if (newSl > curSl + stepDist)
      {
         if (trade.PositionModify(g_trailingTicket, newSl, curTp))
            PrintFormat("[EMACross_EA] Trailing SL lenh #%I64u: %.2f -> %.2f", g_trailingTicket, curSl, newSl);
      }
   }
   else if (type == POSITION_TYPE_SELL)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (ask > openPrice - startDist) return;
      double newSl = NormalizeDouble(ask + trailDist, digits);
      if (newSl < curSl - stepDist || curSl == 0)
      {
         if (trade.PositionModify(g_trailingTicket, newSl, curTp))
            PrintFormat("[EMACross_EA] Trailing SL lenh #%I64u: %.2f -> %.2f", g_trailingTicket, curSl, newSl);
      }
   }
}

//====================================================================
// H. Phat hien tin hieu MOI moi khi co 1 nen dong (giong logic cua chi bao
// EMACrossClone.mq5, nhung chi xet nen VUA DONG thay vi quet lai toan bo
// lich su, vi EA chi can biet "co nen vao lenh bay gio khong").
//====================================================================
void CheckNewSignal()
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (t != 0 && t != g_lastBarTime);
   if (t != 0) g_lastBarTime = t;

   double emaFastArr[], emaSlowArr[], atrArr[];
   ArraySetAsSeries(emaFastArr, true);
   ArraySetAsSeries(emaSlowArr, true);
   ArraySetAsSeries(atrArr, true);
   if (CopyBuffer(g_HandleEMAFast, 0, 0, 3, emaFastArr) < 3) return;
   if (CopyBuffer(g_HandleEMASlow, 0, 0, 3, emaSlowArr) < 3) return;
   if (CopyBuffer(g_HandleATR, 0, 0, 2, atrArr) < 2) return;

   int need = InpRSISlowMA + InpRSIFastMA + 5;
   double rsiRaw[];
   ArraySetAsSeries(rsiRaw, true);
   if (CopyBuffer(g_HandleRSI, 0, 0, need, rsiRaw) < need) return;

   double rEma = 0, rWma = 0;
   bool okRsi = ComputeRsiCrossAt(rsiRaw, need, 1, rEma, rWma);

   // --- cap nhat gia tri cho dashboard (luon lam, du co nen moi hay khong) ---
   g_dashEmaFast = emaFastArr[1];
   g_dashEmaSlow = emaSlowArr[1];
   g_dashRsi     = rsiRaw[1];
   g_dashAtr     = atrArr[1];
   if (okRsi) { g_dashRsiEma = rEma; g_dashRsiWma = rWma; }
   g_trendTxt = (emaFastArr[1] > emaSlowArr[1]) ? "TANG (EMA nhanh > cham)" : "GIAM (EMA nhanh < cham)";

   if (!isNewBar) return; // chi xet vao lenh/thoat lenh 1 lan cho moi nen moi dong

   double fastPrev = emaFastArr[2], slowPrev = emaSlowArr[2];
   double fastNow  = emaFastArr[1], slowNow  = emaSlowArr[1];
   bool crossUp   = (fastPrev <= slowPrev) && (fastNow > slowNow);
   bool crossDown = (fastPrev >= slowPrev) && (fastNow < slowNow);

   // --- [MOI] Thoat lenh som neu trang thai EMA/RSI da dao chieu nguoc voi lenh dang mo ---
   if (InpUseEarlyExit && okRsi && PositionExists())
   {
      int state = 0;
      if (fastNow > slowNow && rEma > rWma) state = 1;
      else if (fastNow < slowNow && rEma < rWma) state = -1;

      int posDir = GetPositionDirection();
      if (state != 0 && posDir != 0 && state != posDir)
      {
         Print("[EMACross_EA] Xu huong EMA/RSI da dao chieu nguoc voi lenh dang mo - dong lenh som, khong doi SL");
         CloseAllPositions();
      }
   }

   if (!crossUp && !crossDown) return;
   if (InpOnePositionOnly && PositionExists()) return;

   if (InpMinBarsBetweenTrades > 0 && g_lastEntryBarTime > 0)
   {
      int periodSec = PeriodSeconds(PERIOD_CURRENT);
      datetime closedBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);
      if (periodSec > 0)
      {
         long elapsedBars = (long)((closedBarTime - g_lastEntryBarTime) / periodSec);
         if (elapsedBars < InpMinBarsBetweenTrades) return;
      }
   }

   bool atrOK  = (InpMinATR <= 0.0) || (atrArr[1] >= InpMinATR);
   bool hourOK = (!InpOnlyHourWindow) || IsInHourWindow(iTime(_Symbol, PERIOD_CURRENT, 1));

   if (crossUp)
   {
      bool rsiBull = !InpUseRSIFilter || (okRsi && rEma > rWma);
      if (rsiBull && atrOK && hourOK) ExecuteSignal(1);
   }
   else if (crossDown)
   {
      bool rsiBear = !InpUseRSIFilter || (okRsi && rEma < rWma);
      if (rsiBear && atrOK && hourOK) ExecuteSignal(-1);
   }
}

//====================================================================
// I. OnTradeTransaction - cap nhat bang lenh + breakeven khi 1 chan dong
//====================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   long  reason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   bool  wasTp = (reason == DEAL_REASON_TP);

   int leg = 0;
   int rowIdx = FindRowByTicket(posId, leg);
   if (rowIdx < 0) return; // lenh khong thuoc bang nay (vd lenh thu cong khac cung magic - hiem)

   if (leg == 1)
   {
      g_rows[rowIdx].tp1Closed = true;
      g_rows[rowIdx].tp1WasTp  = wasTp;

      if (g_rows[rowIdx].hasTp2 && !g_rows[rowIdx].tp2Closed)
      {
         if (wasTp)
         {
            // [SUA LOI] Truoc day dieu kien nay gop chung voi nhanh "TP1 dinh SL"
            // o duoi bang if/else if - hau qua: khi TP1 THANG (wasTp=true) nhung
            // InpMoveToBreakevenOnTp1=false, code roi xuong nhanh else va DONG
            // LUON lenh TP2 dang chay tot, dung ra phai de no tiep tuc chay voi
            // SL goc. Tach rieng: TP1 thang -> chi doi breakeven NEU bat tinh nang
            // do, tuyet doi KHONG dong lenh TP2 trong moi truong hop TP1 thang.
            if (InpUseDualTpMode && InpMoveToBreakevenOnTp1)
            {
               MoveToBreakeven(g_rows[rowIdx].tp2Ticket);
               g_trailingTicket = g_rows[rowIdx].tp2Ticket;
            }
         }
         else
         {
            // TP1 dinh SL (khong phai dat TP) -> ca cap deu coi nhu da dong theo
            // SL chung, dong not lenh TP2 con lai ngay, khong cho no chay tiep 1 minh.
            ulong otherTicket = g_rows[rowIdx].tp2Ticket;
            if (PositionSelectByTicket(otherTicket)) trade.PositionClose(otherTicket);
         }
      }
   }
   else if (leg == 2)
   {
      g_rows[rowIdx].tp2Closed = true;
      g_rows[rowIdx].tp2WasTp  = wasTp;
      if (g_trailingTicket == posId) g_trailingTicket = 0;

      if (!g_rows[rowIdx].tp1Closed)
      {
         // TP2 dong truoc (gia chay thang qua ca 2 dich, hoac dinh SL truoc ca TP1
         // - hiem vi cung SL, nhung van xu ly an toan): dong not lenh TP1 con lai.
         ulong otherTicket = g_rows[rowIdx].tp1Ticket;
         if (PositionSelectByTicket(otherTicket)) trade.PositionClose(otherTicket);
      }
   }

   PrintFormat("[EMACross_EA] Lenh #%I64u (leg %d) da dong, ly do=%s", posId, leg, wasTp ? "TP" : "SL/khac");
}

//====================================================================
// J. Vong doi Expert
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   if (InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
   {
      Print("[EMACross_EA] InpFastEMA phai > 0 va < InpSlowEMA");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_HandleEMAFast = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleEMASlow = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_HandleRSI     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_HandleATR     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   if (g_HandleEMAFast == INVALID_HANDLE || g_HandleEMASlow == INVALID_HANDLE ||
       g_HandleRSI == INVALID_HANDLE || g_HandleATR == INVALID_HANDLE)
   {
      Print("[EMACross_EA] Khong tao duoc 1 trong cac indicator built-in (EMA/RSI/ATR)");
      return INIT_FAILED;
   }

   // [MOI] Neu EA khoi dong lai luc dang co lenh mo (vd restart terminal),
   // dung nhan lenh do vao bang de bang khong bi "trong khong" khi da co
   // lenh that dang chay. Trang thai dong/TP-SL se duoc ghi nhan binh thuong
   // tu day ve sau qua OnTradeTransaction.
   ulong tp1 = FindPositionByComment("EMAX TP1");
   ulong tp2 = FindPositionByComment("EMAX TP2");
   ulong single = FindPositionByComment("EMAX Signal");
   if (tp1 != 0 || tp2 != 0)
   {
      if (PositionSelectByTicket(tp1 != 0 ? tp1 : tp2))
      {
         long type = PositionGetInteger(POSITION_TYPE);
         int dir = (type == POSITION_TYPE_BUY) ? 1 : -1;
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp1Price = (tp1 != 0 && PositionSelectByTicket(tp1)) ? PositionGetDouble(POSITION_TP) : 0;
         double tp2Price = (tp2 != 0 && PositionSelectByTicket(tp2)) ? PositionGetDouble(POSITION_TP) : 0;
         AddTradeRow(dir, entry, sl, tp1Price, tp2Price, true, tp1, tp2);
         if (tp1 == 0) g_rows[ArraySize(g_rows) - 1].tp1Closed = true; // TP1 da dong tu truoc khi EA khoi dong lai
         Print("[EMACross_EA] Khoi phuc 1 tin hieu TP1/TP2 dang mo tu truoc vao bang lenh");
      }
   }
   else if (single != 0 && PositionSelectByTicket(single))
   {
      long type = PositionGetInteger(POSITION_TYPE);
      int dir = (type == POSITION_TYPE_BUY) ? 1 : -1;
      AddTradeRow(dir, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL),
                   PositionGetDouble(POSITION_TP), 0, false, single, 0);
      Print("[EMACross_EA] Khoi phuc 1 lenh don dang mo tu truoc vao bang lenh");
   }

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (g_HandleEMAFast != INVALID_HANDLE) IndicatorRelease(g_HandleEMAFast);
   if (g_HandleEMASlow != INVALID_HANDLE) IndicatorRelease(g_HandleEMASlow);
   if (g_HandleRSI     != INVALID_HANDLE) IndicatorRelease(g_HandleRSI);
   if (g_HandleATR     != INVALID_HANDLE) IndicatorRelease(g_HandleATR);
   DeleteDashboard();
}

void OnTick()
{
   CheckNewSignal();
   TrailTp2Leg();
   UpdateDashboard();
}
//+------------------------------------------------------------------+
