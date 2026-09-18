//+------------------------------------------------------------------+
//|                                         TelegramSignal_EA.mq5    |
//|  EA doc tin hieu tu 1 channel/group Telegram (qua Bot API,       |
//|  polling getUpdates) roi tu dong vao lenh MT5.                   |
//|                                                                    |
//|  DINH DANG TIN HIEU (dung theo dung mau that tu kenh MIK EmaCross |
//|  - t.me/botfather6868):                                           |
//|      MIK EMA CROSS  XAUUSDc M1                                    |
//|      SELL  @ 4382.85                                              |
//|      MIK Score: 78/100                                            |
//|      Ty le thang lich su: 34.7%  (144)                            |
//|      Thoi gian: 2026.09.18 14:22                                  |
//|      eafree.net | t.me/botfather6868                              |
//|  Khong co SL/TP trong format nay -> EA tu tinh theo ATR. Neu kenh |
//|  khac co ghi them "SL x" / "TP x" / "LOT x" thi EA van doc duoc.  |
//|  Dung "CLOSE" de dong lenh dang mo.                                |
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

input group "=== Quan ly lenh khi tin hieu thieu SL/TP/LOT (theo dung ATR cua MIK) ==="
input double InpDefaultLot = 0.01;
input int    InpAtrPeriod  = 14;
input double InpSlAtrMik   = 1.5;   // SL = InpSlAtrMik x ATR (giong ENTRY/SL cua indicator MIK)
input double InpTp1Atr     = 1.5;   // TP lenh 1 = InpTp1Atr x ATR
input double InpTp2Atr     = 3.0;   // TP lenh 2 = InpTp2Atr x ATR

input group "=== [MOI] Vao 2 lenh TP1/TP2, doi SL lenh con lai ve Entry ==="
input bool   InpUseDualTpMode = true;  // true: moi tin hieu chia lam 2 lenh (TP1 va TP2); false: 1 lenh duy nhat (dung InpTp2Atr lam TP)
input bool   InpMoveToBreakevenOnTp1 = true; // Khi lenh TP1 dong, doi SL lenh TP2 ve dung gia vao lenh

input group "=== An toan ==="
input ulong  InpMagicNumber        = 20260919;
input bool   InpOnePositionOnly    = true;   // Chan tin hieu moi neu da co lenh dang mo
input bool   InpRequireSymbolMatch = true;   // Chi vao lenh neu tin hieu co nhac dung symbol dang gan EA
input double InpMaxLotCap          = 1.0;    // Chan lot toi da du tin hieu ghi lot lon hon

input group "=== [MOI] Loc chat luong tin hieu (MIK Score / win rate / gia) ==="
input double InpMinScore          = 70.0;  // Bo qua tin hieu neu "MIK Score" < muc nay (0 = tat loc)
input double InpMinWinRate        = 0.0;   // Bo qua tin hieu neu "Ty le thang lich su" < muc nay % (0 = tat loc)
input double InpMaxPriceDeviation = 5.0;   // Bo qua neu gia thi truong hien tai lech qua xa gia "@" trong tin hieu (don vi gia, 0 = tat kiem tra)

//====================================================================
// Globals
//====================================================================
int    atrHandle = INVALID_HANDLE;
long   g_offset  = 0;      // update_id tiep theo can lay tu Telegram
string g_lastSignalText = "";
datetime g_lastSignalTime = 0;
string g_lastStatus = "Chua ket noi";

// [MOI] Theo doi cap lenh TP1/TP2 dang mo (chi 1 cap tai 1 thoi diem, khop voi
// InpOnePositionOnly) de biet luc nao can doi SL lenh TP2 ve breakeven.
ulong g_tp1Ticket = 0;
ulong g_tp2Ticket = 0;

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
   g_tp1Ticket = 0;
   g_tp2Ticket = 0;
}

// [MOI] Lam tron lot theo buoc/lot toi thieu-toi da cua symbol
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

// [MOI] Tim ticket vi the (cua EA nay, symbol nay) co comment chua tag cho truoc
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
// Mo 1 lenh don (dung khi InpUseDualTpMode=false hoac khong lay duoc ATR)
void OpenSingleLeg(int direction, double lot, double sl, double tp, double atr, string tag)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if (direction == 1)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double useSl = (sl > 0) ? sl : (atr > 0 ? price - atr * InpSlAtrMik : 0);
      double useTp = (tp > 0) ? tp : (atr > 0 ? price + atr * InpTp2Atr  : 0);
      trade.Buy(lot, _Symbol, price, NormalizeDouble(useSl, digits), NormalizeDouble(useTp, digits), tag);
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double useSl = (sl > 0) ? sl : (atr > 0 ? price + atr * InpSlAtrMik : 0);
      double useTp = (tp > 0) ? tp : (atr > 0 ? price - atr * InpTp2Atr  : 0);
      trade.Sell(lot, _Symbol, price, NormalizeDouble(useSl, digits), NormalizeDouble(useTp, digits), tag);
   }
}

// [SUA] Theo yeu cau: EA tu tinh SL/TP1/TP2 dung boi so ATR cua ban goc MIK
// (SL=1.5xATR, TP1=1.5xATR, TP2=3.0xATR). Khi bat InpUseDualTpMode, moi tin
// hieu chia lam 2 lenh cung SL - 1 lenh nham TP1, 1 lenh nham TP2. Khi lenh
// TP1 dong (chay ve dich), lenh TP2 tu doi SL ve gia vao lenh (breakeven) -
// xu ly trong OnTradeTransaction ben duoi.
void ExecuteSignal(int direction, double sl, double tp, double lot)
{
   if (InpOnePositionOnly && PositionExists())
   {
      Print("[TelegramSignal] Da co lenh mo - bo qua tin hieu moi");
      return;
   }

   double totalLot = (lot > 0) ? MathMin(lot, InpMaxLotCap) : InpDefaultLot;

   double atr = 0;
   double atrVal[];
   if (GetBufferSeries(atrHandle, 0, 2, atrVal)) atr = atrVal[1];

   if (!InpUseDualTpMode || atr <= 0)
   {
      OpenSingleLeg(direction, totalLot, sl, tp, atr, "TG Signal");
      return;
   }

   double legLot = NormalizeLot(totalLot / 2.0);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (direction == 1)
   {
      double price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double useSl  = (sl > 0) ? sl : NormalizeDouble(price - atr * InpSlAtrMik, digits);
      double useTp1 = NormalizeDouble(price + atr * InpTp1Atr, digits);
      double useTp2 = (tp > 0) ? tp : NormalizeDouble(price + atr * InpTp2Atr, digits);
      trade.Buy(legLot, _Symbol, price, useSl, useTp1, "TG Signal TP1");
      trade.Buy(legLot, _Symbol, price, useSl, useTp2, "TG Signal TP2");
   }
   else
   {
      double price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double useSl  = (sl > 0) ? sl : NormalizeDouble(price + atr * InpSlAtrMik, digits);
      double useTp1 = NormalizeDouble(price - atr * InpTp1Atr, digits);
      double useTp2 = (tp > 0) ? tp : NormalizeDouble(price - atr * InpTp2Atr, digits);
      trade.Sell(legLot, _Symbol, price, useSl, useTp1, "TG Signal TP1");
      trade.Sell(legLot, _Symbol, price, useSl, useTp2, "TG Signal TP2");
   }

   g_tp1Ticket = FindPositionByComment("TP1");
   g_tp2Ticket = FindPositionByComment("TP2");
}

// [MOI] Khi lenh TP1 dong, doi SL lenh TP2 ve dung gia vao lenh (breakeven)
void MoveToBreakeven(ulong ticket)
{
   if (!PositionSelectByTicket(ticket)) return;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl      = PositionGetDouble(POSITION_SL);
   double curTp      = PositionGetDouble(POSITION_TP);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double newSl = NormalizeDouble(openPrice, digits);
   if (MathAbs(curSl - newSl) < _Point) return; // da o breakeven roi, khong sua lai
   if (trade.PositionModify(ticket, newSl, curTp))
      PrintFormat("[TelegramSignal] TP1 da dong - doi SL lenh TP2 (#%I64u) ve gia vao lenh (breakeven)", ticket);
   else
      PrintFormat("[TelegramSignal] Loi doi SL ve breakeven cho lenh #%I64u: %d", ticket, trade.ResultRetcode());
}

// [MOI] Bat su kien dong lenh de phat hien luc TP1 dong -> kich hoat breakeven
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (!InpUseDualTpMode || !InpMoveToBreakevenOnTp1) return;
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if (g_tp1Ticket == 0 && g_tp2Ticket == 0) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   if (posId == g_tp1Ticket && g_tp2Ticket != 0)
   {
      MoveToBreakeven(g_tp2Ticket);
      g_tp1Ticket = 0;
      g_tp2Ticket = 0; // cap nay coi nhu da xu ly xong
   }
   else if (posId == g_tp2Ticket)
   {
      // TP2 dong truoc khi TP1 dong (gia chay thang), khong can lam gi them
      g_tp1Ticket = 0;
      g_tp2Ticket = 0;
   }
}

// Tim gia tri so ngay sau 1 marker (vd "SCORE:" -> "78/100", "@" -> "4382.85")
// trong nguyen ban khong phan biet hoa/thuong (truyen ca 2 chuoi upper+goc).
double ExtractNumberAfterMarker(const string &haystackUpper, const string &raw, const string markerUpper)
{
   int p = StringFind(haystackUpper, markerUpper);
   if (p < 0) return -1;
   p += StringLen(markerUpper);
   int len = StringLen(raw);
   while (p < len && StringGetCharacter(raw, p) == ' ') p++;
   int start = p;
   bool seenDigit = false;
   while (p < len)
   {
      ushort c = StringGetCharacter(raw, p);
      if ((c >= '0' && c <= '9') || c == '.') { p++; seenDigit = true; continue; }
      break;
   }
   if (!seenDigit) return -1;
   return StringToDouble(StringSubstr(raw, start, p - start));
}

// Tim so ngay TRUOC ky tu '%' gan nhat (dung cho "34.7%")
double ExtractNumberBeforePercent(const string &raw)
{
   int pctPos = StringFind(raw, "%");
   if (pctPos <= 0) return -1;
   int e = pctPos;
   int s = e;
   while (s > 0)
   {
      ushort c = StringGetCharacter(raw, s - 1);
      if ((c >= '0' && c <= '9') || c == '.') s--;
      else break;
   }
   if (s >= e) return -1;
   return StringToDouble(StringSubstr(raw, s, e - s));
}

void ProcessSignalText(const string text)
{
   g_lastSignalText = text;
   g_lastSignalTime = TimeCurrent();

   string upper = text;
   StringToUpper(upper);

   string buyKw = InpBuyKeyword,  sellKw = InpSellKeyword, closeKw = InpCloseKeyword;
   StringToUpper(buyKw); StringToUpper(sellKw); StringToUpper(closeKw);

   // Huong lenh: lay tu khoa xuat hien SOM NHAT trong tin nhan (line 2 cua mau MIK)
   int pBuy = StringFind(upper, buyKw);
   int pSell = StringFind(upper, sellKw);
   int pClose = StringFind(upper, closeKw);
   int direction = 0, bestPos = -1;
   if (pBuy >= 0)                              { direction = 1;  bestPos = pBuy; }
   if (pSell  >= 0 && (bestPos < 0 || pSell  < bestPos)) { direction = -1; bestPos = pSell; }
   if (pClose >= 0 && (bestPos < 0 || pClose < bestPos)) { direction = 2;  bestPos = pClose; }

   if (direction == 0)
   {
      Print("[TelegramSignal] Khong nhan dien duoc tu khoa BUY/SELL/CLOSE trong tin nhan, bo qua: ", text);
      return;
   }

   // Symbol: so sanh 6 ky tu dau cua _Symbol (vd XAUUSD) voi noi dung tin nhan,
   // de khong bi vuong hau to broker khac nhau (XAUUSDc, XAUUSDm, XAUUSD...)
   string symUpper = _Symbol;
   StringToUpper(symUpper);
   string symCore = StringSubstr(symUpper, 0, MathMin(6, StringLen(symUpper)));
   bool symbolMatched = !InpRequireSymbolMatch || StringFind(upper, symCore) >= 0;
   if (!symbolMatched)
   {
      Print("[TelegramSignal] Tin hieu khong nhac symbol dang gan EA (", _Symbol, "), bo qua: ", text);
      return;
   }

   if (direction == 2)
   {
      ClosePosition();
      Print("[TelegramSignal] Nhan tin hieu CLOSE - da dong lenh");
      return;
   }

   // SL/TP/LOT kieu tu khoa (tuong thich nguoc voi cac kenh khac co ghi ro)
   string parts[];
   int cnt = StringSplit(upper, ' ', parts);
   double sl = 0, tp = 0, lot = 0;
   for (int i = 0; i < cnt; i++)
   {
      if (parts[i] == "SL"  && i + 1 < cnt) sl  = StringToDouble(parts[i + 1]);
      if (parts[i] == "TP"  && i + 1 < cnt) tp  = StringToDouble(parts[i + 1]);
      if (parts[i] == "LOT" && i + 1 < cnt) lot = StringToDouble(parts[i + 1]);
   }

   // Cac truong rieng cua mau MIK EmaCross: MIK Score, ty le thang lich su, gia "@"
   double score    = ExtractNumberAfterMarker(upper, text, "SCORE:");
   double winRate  = ExtractNumberBeforePercent(text);
   double refPrice = ExtractNumberAfterMarker(upper, text, "@");

   if (InpMinScore > 0 && score >= 0 && score < InpMinScore)
   {
      Print("[TelegramSignal] MIK Score ", score, " < nguong ", InpMinScore, " - bo qua tin hieu: ", text);
      return;
   }
   if (InpMinWinRate > 0 && winRate >= 0 && winRate < InpMinWinRate)
   {
      Print("[TelegramSignal] Ty le thang lich su ", winRate, "% < nguong ", InpMinWinRate, "% - bo qua tin hieu: ", text);
      return;
   }
   if (InpMaxPriceDeviation > 0 && refPrice > 0)
   {
      double curPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if (MathAbs(curPrice - refPrice) > InpMaxPriceDeviation)
      {
         PrintFormat("[TelegramSignal] Gia hien tai (%.2f) lech qua xa gia tin hieu (%.2f) - bo qua (tin hieu co the bi tre)", curPrice, refPrice);
         return;
      }
   }

   ExecuteSignal(direction, sl, tp, lot);
   PrintFormat("[TelegramSignal] Da xu ly tin hieu %s | Score=%.0f WinRate=%.1f%% RefPrice=%.2f SL=%.2f TP=%.2f LOT=%.2f | goc: %s",
               (direction == 1 ? "BUY" : "SELL"), score, winRate, refPrice, sl, tp, lot, text);
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
   string keys[] = {"Title", "Status", "LastSignal", "Position", "Legs"};
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

   if (InpUseDualTpMode)
      SetLabel(DASH_PREFIX + "Legs", StringFormat("TP1=#%I64u  TP2=#%I64u", g_tp1Ticket, g_tp2Ticket), clrSilver);
   else
      SetLabel(DASH_PREFIX + "Legs", "Che do: 1 lenh don", clrSilver);
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
