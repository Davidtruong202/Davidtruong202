//+------------------------------------------------------------------+
//|                                         TelegramSignal_EA.mq5    |
//|  EA doc tin hieu tu 1 channel/group Telegram (qua Bot API,       |
//|  polling getUpdates) roi tu dong vao lenh MT5.                   |
//|                                                                    |
//|  DINH DANG TIN HIEU MAC DINH (khong phan biet hoa/thuong,         |
//|  cac tu khoa co the nam tren nhieu dong hoac cung 1 dong):        |
//|      BUY XAUUSD                                                   |
//|      SL 2350.00                                                   |
//|      TP 2365.00                                                   |
//|      LOT 0.02                                                     |
//|  (SL/TP/LOT deu tuy chon - thieu thi EA tu tinh theo ATR/LotSize  |
//|  mac dinh). Dung "CLOSE" de dong lenh dang mo.                    |
//|                                                                    |
//|  BAT BUOC: whitelist https://api.telegram.org trong Tools->       |
//|  Options->Expert Advisors->Allow WebRequest for listed URL.        |
//|  Bot phai da duoc them vao channel/group nguon tin hieu.           |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Telegram Bot ==="
input string InpBotToken     = "";   // Token bot (tao qua @BotFather) - GIU BI MAT, dung commit len git
input long   InpChatId       = 0;    // ID channel/group nguon tin hieu (0 = nhan tu bat ky chat nao bot thay - KHONG khuyen nghi)
input int    InpPollSeconds  = 5;    // Tan suat kiem tra tin nhan moi (giay)

input group "=== Tu khoa nhan dien tin hieu ==="
input string InpBuyKeyword   = "BUY";
input string InpSellKeyword  = "SELL";
input string InpCloseKeyword = "CLOSE";

input group "=== Quan ly lenh khi tin hieu thieu SL/TP/LOT ==="
input double InpDefaultLot   = 0.01;
input int    InpAtrPeriod    = 14;
input double InpDefaultSlAtr = 1.5;   // SL mac dinh = InpDefaultSlAtr x ATR neu tin hieu khong ghi SL
input double InpDefaultTpAtr = 3.0;   // TP mac dinh = InpDefaultTpAtr x ATR neu tin hieu khong ghi TP

input group "=== An toan ==="
input ulong  InpMagicNumber        = 20260919;
input bool   InpOnePositionOnly    = true;   // Chan tin hieu moi neu da co lenh dang mo
input bool   InpRequireSymbolMatch = true;   // Chi vao lenh neu tin hieu co nhac dung symbol dang gan EA
input double InpMaxLotCap          = 1.0;    // Chan lot toi da du tin hieu ghi lot lon hon

//====================================================================
// Globals
//====================================================================
int    atrHandle = INVALID_HANDLE;
long   g_offset  = 0;      // update_id tiep theo can lay tu Telegram
string g_lastSignalText = "";
datetime g_lastSignalTime = 0;
string g_lastStatus = "Chua ket noi";

#define DASH_PREFIX "TGSig_Dash_"

//====================================================================
// Helpers chung (giong quy uoc cac EA khac trong repo)
//====================================================================
bool GetBufferSeries(int handle, int bufferIndex, int count, double &arr[])
{
   if (handle == INVALID_HANDLE) return false;
   ArraySetAsSeries(arr, true);
   int copied = CopyBuffer(handle, bufferIndex, 0, count, arr);
   return copied >= count;
}

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

void ClosePosition()
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

//====================================================================
// Goi Telegram Bot API (getUpdates, long polling kieu don gian)
//====================================================================
bool TelegramGetUpdates(string &jsonOut)
{
   string url = "https://api.telegram.org/bot" + InpBotToken + "/getUpdates?offset=" + IntegerToString(g_offset) + "&timeout=0";
   char   post[];
   char   resultData[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      int err = GetLastError();
      if (err == 4060)
         g_lastStatus = "LOI: chua whitelist api.telegram.org trong Tools->Options->Expert Advisors";
      else
         g_lastStatus = StringFormat("LOI WebRequest #%d", err);
      Print("[TelegramSignal] ", g_lastStatus);
      return false;
   }
   jsonOut = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   g_lastStatus = "OK - dang lang nghe";
   return true;
}

//====================================================================
// Trich xuat gia tri tu JSON tho (parser toi gian, chi du dung cho    |
// dung khuon dang cua Telegram getUpdates - khong phai JSON parser   |
// tong quat).                                                        |
//====================================================================
long ExtractLongAfter(const string &json, int fromPos, string key, int limitPos = -1)
{
   int p = StringFind(json, key, fromPos);
   if (p < 0) return -2147483648;
   if (limitPos >= 0 && p >= limitPos) return -2147483648;
   p += StringLen(key);
   int start = p;
   int len = StringLen(json);
   while (p < len)
   {
      ushort c = StringGetCharacter(json, p);
      if ((c >= '0' && c <= '9') || c == '-') { p++; continue; }
      break;
   }
   if (p == start) return -2147483648;
   return StringToInteger(StringSubstr(json, start, p - start));
}

string ExtractStringAfter(const string &json, int fromPos, string key, int limitPos = -1)
{
   int p = StringFind(json, key, fromPos);
   if (p < 0) return "";
   if (limitPos >= 0 && p >= limitPos) return "";
   p += StringLen(key);
   int start = p;
   int len = StringLen(json);
   bool esc = false;
   int end = start;
   while (end < len)
   {
      ushort c = StringGetCharacter(json, end);
      if (!esc && c == '"') break;
      esc = (!esc && c == '\\');
      end++;
   }
   string raw = StringSubstr(json, start, end - start);
   StringReplace(raw, "\\n", " ");
   StringReplace(raw, "\\\"", "\"");
   StringReplace(raw, "\\/", "/");
   return raw;
}

//====================================================================
// Xu ly noi dung 1 tin hieu (text da lay tu Telegram)
//====================================================================
void ExecuteSignal(int direction, double sl, double tp, double lot)
{
   if (InpOnePositionOnly && PositionExists())
   {
      Print("[TelegramSignal] Da co lenh mo - bo qua tin hieu moi");
      return;
   }

   double useLot = (lot > 0) ? MathMin(lot, InpMaxLotCap) : InpDefaultLot;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double atr = 0;
   if (sl <= 0 || tp <= 0)
   {
      double atrVal[];
      if (GetBufferSeries(atrHandle, 0, 2, atrVal)) atr = atrVal[1];
   }

   if (direction == 1)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double useSl = (sl > 0) ? sl : (atr > 0 ? price - atr * InpDefaultSlAtr : 0);
      double useTp = (tp > 0) ? tp : (atr > 0 ? price + atr * InpDefaultTpAtr : 0);
      trade.Buy(useLot, _Symbol, price, NormalizeDouble(useSl, digits), NormalizeDouble(useTp, digits), "TG Signal Buy");
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double useSl = (sl > 0) ? sl : (atr > 0 ? price + atr * InpDefaultSlAtr : 0);
      double useTp = (tp > 0) ? tp : (atr > 0 ? price - atr * InpDefaultTpAtr : 0);
      trade.Sell(useLot, _Symbol, price, NormalizeDouble(useSl, digits), NormalizeDouble(useTp, digits), "TG Signal Sell");
   }
}

void ProcessSignalText(const string text)
{
   g_lastSignalText = text;
   g_lastSignalTime = TimeCurrent();

   string flat = text;
   StringReplace(flat, "\r", " ");
   StringReplace(flat, "\n", " ");
   string flatUpper = flat;
   StringToUpper(flatUpper);

   string buyKw = InpBuyKeyword,  sellKw = InpSellKeyword, closeKw = InpCloseKeyword;
   StringToUpper(buyKw); StringToUpper(sellKw); StringToUpper(closeKw);

   string symUpper = _Symbol;
   StringToUpper(symUpper);

   string parts[];
   int cnt = StringSplit(flatUpper, ' ', parts);

   int    direction     = 0; // 0=khong nhan dien, 1=buy, -1=sell, 2=close
   double sl = 0, tp = 0, lot = 0;
   bool   symbolMatched = !InpRequireSymbolMatch;

   for (int i = 0; i < cnt; i++)
   {
      string tk = parts[i];
      if (tk == "") continue;

      if (tk == buyKw)             direction = 1;
      else if (tk == sellKw)       direction = -1;
      else if (tk == closeKw)      direction = 2;
      else if (tk == "SL" && i + 1 < cnt) sl  = StringToDouble(parts[i + 1]);
      else if (tk == "TP" && i + 1 < cnt) tp  = StringToDouble(parts[i + 1]);
      else if (tk == "LOT" && i + 1 < cnt) lot = StringToDouble(parts[i + 1]);
      else if (StringLen(tk) >= 3 && StringFind(symUpper, tk) >= 0) symbolMatched = true;
   }

   if (direction == 0)
   {
      Print("[TelegramSignal] Khong nhan dien duoc tu khoa BUY/SELL/CLOSE trong tin nhan, bo qua: ", text);
      return;
   }
   if (!symbolMatched)
   {
      Print("[TelegramSignal] Tin hieu khong nhac ten symbol dang gan EA (", _Symbol, "), bo qua: ", text);
      return;
   }

   if (direction == 2)
   {
      ClosePosition();
      Print("[TelegramSignal] Nhan tin hieu CLOSE - da dong lenh");
      return;
   }

   ExecuteSignal(direction, sl, tp, lot);
   Print("[TelegramSignal] Da xu ly tin hieu ", (direction == 1 ? "BUY" : "SELL"),
         " SL=", sl, " TP=", tp, " LOT=", lot, " | goc: ", text);
}

//====================================================================
// Vong lap poll Telegram - tim tung "update_id" va cac truong lien   |
// quan trong pham vi block cua update do.                            |
//====================================================================
void PollTelegram()
{
   string json;
   if (!TelegramGetUpdates(json)) return;
   if (StringLen(json) < 10) return;

   int pos = 0;
   int len = StringLen(json);

   while (pos < len)
   {
      int idPos = StringFind(json, "\"update_id\":", pos);
      if (idPos < 0) break;

      long updateId = ExtractLongAfter(json, idPos, "\"update_id\":");
      if (updateId == -2147483648) break;

      int nextIdPos = StringFind(json, "\"update_id\":", idPos + 1);
      int blockEnd  = (nextIdPos < 0) ? len : nextIdPos;

      long   chatId = ExtractLongAfter(json, idPos, "\"chat\":{\"id\":", blockEnd);
      string text   = ExtractStringAfter(json, idPos, "\"text\":\"", blockEnd);

      if (updateId >= g_offset) g_offset = updateId + 1;

      if (StringLen(text) > 0 && (InpChatId == 0 || chatId == InpChatId))
         ProcessSignalText(text);

      if (nextIdPos < 0) break;
      pos = blockEnd;
   }
}

//====================================================================
// Dashboard
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   string keys[] = {"Title", "Status", "LastSignal", "Position"};
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

void DeleteDashboard() { ObjectsDeleteAll(0, DASH_PREFIX); }

void UpdateDashboard()
{
   SetLabel(DASH_PREFIX + "Title", "=== Telegram Signal EA ===", clrWhite);
   SetLabel(DASH_PREFIX + "Status", "Telegram: " + g_lastStatus,
             StringFind(g_lastStatus, "LOI") >= 0 ? clrTomato : clrLimeGreen);

   string lastTxt = (g_lastSignalTime == 0) ? "Chua co tin hieu nao"
                     : StringFormat("[%s] %s", TimeToString(g_lastSignalTime, TIME_MINUTES),
                                      StringSubstr(g_lastSignalText, 0, 40));
   SetLabel(DASH_PREFIX + "LastSignal", "Tin hieu gan nhat: " + lastTxt, clrSilver);

   bool hasPos = PositionExists();
   SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh dang mo: %s", hasPos ? "CO" : "KHONG"), hasPos ? clrLimeGreen : clrSilver);
}

//====================================================================
// Expert lifecycle
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   if (StringLen(InpBotToken) == 0)
   {
      Print("[TelegramSignal] Chua nhap InpBotToken - EA se khong hoat dong");
   }

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   if (atrHandle == INVALID_HANDLE)
   {
      Print("[TelegramSignal] Khong tao duoc ATR handle");
      return INIT_FAILED;
   }

   CreateDashboard();
   EventSetTimer(MathMax(1, InpPollSeconds));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if (atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   DeleteDashboard();
}

void OnTimer()
{
   if (StringLen(InpBotToken) > 0)
      PollTelegram();
   UpdateDashboard();
}

void OnTick()
{
   UpdateDashboard();
}
