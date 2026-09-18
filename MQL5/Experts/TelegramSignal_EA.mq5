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
//|  DIEU KHIEN TU TELEGRAM: nhan tin "TF M5" (hoac M1/M15/M30/H1/H4/  |
//|  D1/W1/MN1) de doi khung gio cua chart dang chay EA - doi luon ca  |
//|  EA lan indicator MIK vi cung gan tren 1 chart. Can BAT 1 trong 2  |
//|  cach xac thuc: InpAdminUserId (User ID cua ban, dung khi DM rieng |
//|  cho bot) hoac InpTrustSignalChannelForTf (tin thang tin nhan gui  |
//|  trong chinh channel tin hieu - chi bat neu chac chan chi minh ban |
//|  dang duoc trong channel do). Neu la Channel that (khong phai      |
//|  Group), Telegram KHONG lo danh tinh nguoi gui tin dang trong      |
//|  channel qua Bot API, nen InpAdminUserId se khong nhan dien duoc   |
//|  lenh gui THANG trong channel - phai dung DM hoac bat              |
//|  InpTrustSignalChannelForTf. Ca 2 deu tat mac dinh de an toan.     |
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
input double InpDefaultLot = 0.01;  // Lot co dinh, dung khi InpUseRiskPercent=false
input int    InpAtrPeriod  = 14;
input double InpSlAtrMik   = 1.5;   // SL = InpSlAtrMik x ATR (giong ENTRY/SL cua indicator MIK)
input double InpTp1Atr     = 1.5;   // TP lenh 1 = InpTp1Atr x ATR
input double InpTp2Atr     = 3.0;   // TP lenh 2 = InpTp2Atr x ATR

input group "=== [MOI] Tinh lot theo % so du tai khoan (thay cho lot co dinh) ==="
input bool   InpUseRiskPercent = false; // true: tu tinh lot theo % Balance thay vi dung InpDefaultLot - chi ap dung khi tin hieu KHONG tu ghi ro LOT
input double InpRiskPercent    = 1.0;   // % Balance chap nhan mat neu dinh dung SL (vd 1.0 = mat 1% Balance neu SL bi cham)

input group "=== [MOI] Giam nua lot khi Score thap ==="
input bool   InpHalfLotOnLowScore = true;  // Score duoi nguong -> lot giam con 1 nua so voi muc da tinh (lot co dinh, lot tu tin hieu, hay lot theo risk% deu ap dung)
input double InpLowScoreThreshold = 75.0;  // Score < muc nay (nhung van >= InpMinScore de qua duoc bo loc) thi giam lot

input group "=== [MOI] Vao 2 lenh TP1/TP2, doi SL lenh con lai ve Entry ==="
input bool   InpUseDualTpMode = true;  // true: moi tin hieu chia lam 2 lenh (TP1 va TP2); false: 1 lenh duy nhat (dung InpTp2Atr lam TP)
input bool   InpMoveToBreakevenOnTp1 = true; // Khi lenh TP1 dong, doi SL lenh TP2 ve dung gia vao lenh

input group "=== [MOI] Trailing SL cho lenh TP2 sau khi da ve breakeven ==="
input bool   InpUseTrailingAfterTp1 = true;  // Sau khi TP1 dong va SL da ve breakeven, tiep tuc keo SL theo gia thay vi giu co dinh
input double InpTrailStartAtr       = 0.5;   // Chi bat dau keo khi gia da di duoc it nhat bao nhieu x ATR tinh tu entry
input double InpTrailDistanceAtr    = 0.75;  // Khoang cach giu SL phia sau gia hien tai, boi so ATR
input double InpTrailStepAtr        = 0.1;   // Buoc toi thieu (boi so ATR) de cap nhat SL, tranh sua lenh lien tuc moi tick

input group "=== An toan ==="
input ulong  InpMagicNumber        = 20260919;
input bool   InpOnePositionOnly    = true;   // Chan tin hieu moi neu da co lenh dang mo
input bool   InpRequireSymbolMatch = true;   // Chi vao lenh neu tin hieu co nhac dung symbol dang gan EA
input double InpMaxLotCap          = 1.0;    // Chan lot toi da du tin hieu ghi lot lon hon

input group "=== [MOI] Loc chat luong tin hieu (MIK Score / win rate / gia) ==="
input double InpMinScore          = 70.0;  // Bo qua tin hieu neu "MIK Score" < muc nay (0 = tat loc)
input double InpMinWinRate        = 0.0;   // Bo qua tin hieu neu "Ty le thang lich su" < muc nay % (0 = tat loc)
input double InpMaxPriceDeviation = 5.0;   // Bo qua neu gia thi truong hien tai lech qua xa gia "@" trong tin hieu (don vi gia, 0 = tat kiem tra)

input group "=== [MOI] Chi nhan tin hieu tu dung nguon (channel co nhieu bot/indicator khac) ==="
input bool   InpRequireSourceTag = true;    // Chi xu ly tin nhan CO chua chuoi InpSourceTag - bo qua het tin cua bot/indicator khac trong cung channel
input string InpSourceTag        = "MIK";   // Chuoi dac trung nhan dien dung nguon (vd "MIK", "MIK EMA CROSS"...)

input group "=== [MOI] Bao ket qua nguoc lai Telegram ==="
input bool InpNotifyOnOpen  = true;   // Gui tin nhan ve Telegram khi EA vao lenh moi
input bool InpNotifyOnClose = true;   // Gui tin nhan ve Telegram khi EA dong lenh (TP/SL/breakeven/CLOSE)
input long InpNotifyChatId  = 0;      // Chat ID nhan bao cao (0 = gui ve cung InpChatId cua kenh tin hieu)

input group "=== [MOI] Chuyen tiep tin hieu 'sach' sang channel rieng ==="
input long InpMirrorChatId = 0;   // Chat ID channel MOI cua ban (0 = tat). Chi gom huong lenh/entry/SL/TP/Score/WinRate, khong con "eafree.net | t.me/botfather6868"

input group "=== [MOI] Tu tinh dieu kien EXIT tai cho (khong phu thuoc indicator gui Telegram) ==="
input bool InpUseLocalExit   = true;  // Tu tinh dung cong thuc EMA9/EMA20 + RSI cua MIK, dong lenh ngay khi gay - khong can cho tin CLOSE qua Telegram
input int  InpLocalEma9      = 9;
input int  InpLocalEma20     = 20;
input int  InpLocalRsiPeriod = 14;
input int  InpLocalRsiEma    = 9;
input int  InpLocalRsiWma    = 45;

input group "=== [MOI] Dieu khien EA tu Telegram (doi khung gio chart...) ==="
input bool InpEnableTfCommand         = true;  // Cho phep doi khung gio chart bang lenh chat, vd "TF M5"
input long InpAdminUserId             = 0;     // Telegram User ID duoc phep goi lenh (dung khi nhan rieng cho bot) - 0 = khong dung cach nay
input bool InpTrustSignalChannelForTf = false; // true: tin lenh TF gui THANG trong channel tin hieu (InpChatId), khong can biet User ID - chi bat neu chac chan chi minh ban dang duoc trong channel do

//====================================================================
// Globals
//====================================================================
int    atrHandle = INVALID_HANDLE;
long   g_offset  = 0;      // update_id tiep theo can lay tu Telegram
string g_lastSignalText = "";
datetime g_lastSignalTime = 0;
string g_lastStatus = "Chua ket noi";
string g_offsetGvName = "";  // ten Global Variable luu g_offset, gan trong OnInit theo magic number

// [MOI] Theo doi cap lenh TP1/TP2 dang mo (chi 1 cap tai 1 thoi diem, khop voi
// InpOnePositionOnly) de biet luc nao can doi SL lenh TP2 ve breakeven.
ulong g_tp1Ticket = 0;
ulong g_tp2Ticket = 0;

// [MOI] Ticket lenh dang duoc trailing (= lenh TP2 sau khi TP1 da dong va
// SL da ve breakeven). Tach rieng khoi g_tp2Ticket vi bien do bi reset ve 0
// ngay sau khi MoveToBreakeven chay xong.
ulong g_trailingTicket = 0;

// [MOI] Handle + trang thai cho viec tu tinh EXIT tai cho
int      emaFastHandleLocal = INVALID_HANDLE;
int      emaSlowHandleLocal = INVALID_HANDLE;
int      rsiHandleLocal     = INVALID_HANDLE;
datetime g_lastBarTimeLocal = 0;

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

// [SUA] Ham nay bi thieu (dung o CheckLocalExit nhung chua tung khai bao -
// gay loi bien dich "undeclared identifier"). Tra ve 1 (buy), -1 (sell),
// 0 (khong co lenh nao cua EA nay dang mo).
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

// [MOI] Tinh lot sao cho neu gia di dung "slDistancePrice" (don vi gia) thi
// mat dung InpRiskPercent% so du tai khoan. Dung SYMBOL_TRADE_TICK_VALUE/
// TICK_SIZE de quy doi khoang cach gia sang tien te tai khoan cho dung voi
// moi loai symbol (vang, forex, chi so...).
double CalcRiskLot(double slDistancePrice)
{
   if (slDistancePrice <= 0) return InpDefaultLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || tickValue <= 0) return InpDefaultLot; // thieu du lieu symbol, an toan dung lot co dinh

   double valuePerPriceUnit = tickValue / tickSize; // tien (theo tien te tai khoan) cho 1 lot khi gia doi 1 don vi
   if (valuePerPriceUnit <= 0) return InpDefaultLot;

   double lot = riskAmount / (slDistancePrice * valuePerPriceUnit);
   return NormalizeLot(lot);
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

// [MOI] URL-encode 1 chuoi UTF-8 (can cho ky tu co dau, khoang trang, xuong dong...
// khi nhet vao query string cua sendMessage)
string UrlEncode(const string text)
{
   uchar bytes[];
   int n = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   string result = "";
   for (int i = 0; i < n; i++)
   {
      uchar b = bytes[i];
      if (b == 0) break; // StringToCharArray ket thuc bang byte NULL
      if ((b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') ||
          b == '-' || b == '_' || b == '.' || b == '~')
         result += CharToString(b);
      else
         result += StringFormat("%%%02X", b);
   }
   return result;
}

// [MOI] Gui tin nhan TU EA len 1 chat_id cu the (dung chung cho ca bao cao
// va mirror sang channel rieng).
bool TelegramSendMessageTo(long chatId, const string text)
{
   if (StringLen(InpBotToken) == 0) return false;
   if (chatId == 0) return false;

   string url = "https://api.telegram.org/bot" + InpBotToken + "/sendMessage?chat_id=" +
                IntegerToString(chatId) + "&text=" + UrlEncode(text);
   char   post[];
   char   resultData[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, resultData, resultHeaders);
   if (res == -1)
   {
      Print("[TelegramSignal] Gui tin Telegram (chat_id=", chatId, ") that bai, loi ", GetLastError());
      return false;
   }
   return true;
}

// Gui bao cao ve chat mac dinh (InpNotifyChatId hoac InpChatId)
bool TelegramSendMessage(const string text)
{
   long chatId = (InpNotifyChatId != 0) ? InpNotifyChatId : InpChatId;
   if (chatId == 0)
   {
      Print("[TelegramSignal] Khong gui duoc bao cao - chua khai bao InpChatId hoac InpNotifyChatId");
      return false;
   }
   return TelegramSendMessageTo(chatId, text);
}

// [MOI] Icon dai dien cho huong lenh, dung chung cho cac tin gui Telegram
string DirIcon(int direction) { return (direction == 1) ? "🟢" : "🔴"; }

// [MOI] Ten symbol de hien thi trong tin nhan - bo ky tu 'c' cuoi cung neu co
// (hau to cent-account cua mot so broker, vd "XAUUSDc" -> "XAUUSD"). Chi anh
// huong hien thi, KHONG doi _Symbol thuc te dung de giao dich.
string CleanSymbolForDisplay()
{
   string s = _Symbol;
   int len = StringLen(s);
   if (len > 0 && StringGetCharacter(s, len - 1) == 'c')
      return StringSubstr(s, 0, len - 1);
   return s;
}

// [MOI] Tong loi/lo cac lenh CUA EA NAY da dong trong ngay hien tai (tinh tu
// 00:00 gio server toi hien tai), dung de hien thi thay cho ty le thang.
double CalcDayProfit()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   datetime now = TimeCurrent();

   double profit = 0.0;
   if (!HistorySelect(dayStart, now + 86400)) return 0.0;

   int total = HistoryDealsTotal();
   for (int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if (ticket == 0) continue;
      if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_SWAP) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return profit;
}

// [MOI] Gui ban tin tin hieu da lam sach (khong con "eafree.net | t.me/...")
// sang channel rieng cua ban, dung dung SL/TP thuc te EA vua tinh/dat lenh.
void SendMirrorSignal(int direction, double entryRef, double score, double winRate,
                        double sl, double tp1, double tp2)
{
   if (InpMirrorChatId == 0) return;

   string dirTxt = (direction == 1) ? "BUY" : "SELL";
   string symDisp = CleanSymbolForDisplay();
   double dayProfit = CalcDayProfit();
   string msg;
   if (tp2 > 0)
      msg = StringFormat("%s %s %s\n📍 Entry: %.2f\n🛑 SL: %.2f\n🎯 TP1: %.2f\n🎯 TP2: %.2f\n⭐ Score: %.0f/100\n📆 Lãi/lỗ hôm nay: %.2f %s",
                           DirIcon(direction), dirTxt, symDisp, entryRef, sl, tp1, tp2, score, dayProfit, AccountInfoString(ACCOUNT_CURRENCY));
   else
      msg = StringFormat("%s %s %s\n📍 Entry: %.2f\n🛑 SL: %.2f\n🎯 TP: %.2f\n⭐ Score: %.0f/100\n📆 Lãi/lỗ hôm nay: %.2f %s",
                           DirIcon(direction), dirTxt, symDisp, entryRef, sl, tp1, score, dayProfit, AccountInfoString(ACCOUNT_CURRENCY));

   TelegramSendMessageTo(InpMirrorChatId, msg);
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
// [MOI] Tinh EMA(RSI) va WMA(RSI) tai nen vua dong (shift=1), dung cong thuc
// giong het indicator MIK EmaCross de tu phat hien dieu kien EXIT tai cho,
// khong phu thuoc indicator co gui tin CLOSE qua Telegram hay khong.
bool ComputeRsiCrossLocal(double &rsiEma1, double &rsiWma1)
{
   int need = InpLocalRsiWma + InpLocalRsiEma + 60;
   double rsiRaw[];
   if (!GetBufferSeries(rsiHandleLocal, 0, need, rsiRaw)) return false;
   ArraySetAsSeries(rsiRaw, false); // dao ve thu tu thoi gian tang dan de tinh de quy

   double rsiEma[];
   ArrayResize(rsiEma, need);
   double kEma = 2.0 / (InpLocalRsiEma + 1.0);
   for (int i = 0; i < need; i++)
   {
      if (i == 0) rsiEma[i] = rsiRaw[i];
      else        rsiEma[i] = rsiRaw[i] * kEma + rsiEma[i - 1] * (1.0 - kEma);
   }

   double rsiWma[];
   ArrayResize(rsiWma, need);
   int wn = InpLocalRsiWma;
   for (int i = 0; i < need; i++)
   {
      if (i + 1 < wn) { rsiWma[i] = rsiRaw[i]; continue; }
      double sumW = 0, sumWX = 0;
      for (int k = 0; k < wn; k++)
      {
         double w = (wn - k);
         sumWX += w * rsiRaw[i - k];
         sumW  += w;
      }
      rsiWma[i] = sumWX / sumW;
   }

   rsiEma1 = rsiEma[need - 2]; // shift1 = nen vua dong
   rsiWma1 = rsiWma[need - 2];
   return true;
}

int BarStateLocal(double e9, double e20, double re, double rw)
{
   if (e9 > e20 && re > rw) return 1;
   if (e9 < e20 && re < rw) return -1;
   return 0;
}

// [MOI] Kiem tra moi khi co nen moi: neu dang co lenh mo va dieu kien
// EMA9/EMA20+RSI cua MIK khong con khop huong lenh dang giu (tuc la "EXIT"
// hoac dao han) thi tu dong dong lenh NGAY, khong can cho tin nhan Telegram.
void CheckLocalExit()
{
   if (!InpUseLocalExit) return;
   if (!PositionExists()) return;

   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (t == 0 || t == g_lastBarTimeLocal) return;
   g_lastBarTimeLocal = t;

   double ema9[], ema20[];
   if (!GetBufferSeries(emaFastHandleLocal, 0, 2, ema9)) return;
   if (!GetBufferSeries(emaSlowHandleLocal, 0, 2, ema20)) return;

   double rsiEma1, rsiWma1;
   if (!ComputeRsiCrossLocal(rsiEma1, rsiWma1)) return;

   int posDir = GetPositionDirection();
   if (posDir == 0) return;

   int state = BarStateLocal(ema9[1], ema20[1], rsiEma1, rsiWma1);
   if (state != posDir)
   {
      Print("[TelegramSignal] Dieu kien EMA/RSI cua MIK da gay (tu tinh tai cho) - tu dong dong lenh, khong doi tin Telegram");
      ClosePosition();
   }
}

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
void ExecuteSignal(int direction, double sl, double tp, double lot, double score, double winRate)
{
   if (InpOnePositionOnly && PositionExists())
   {
      Print("[TelegramSignal] Da co lenh mo - bo qua tin hieu moi");
      return;
   }

   double atr = 0;
   double atrVal[];
   if (GetBufferSeries(atrHandle, 0, 2, atrVal)) atr = atrVal[1];

   // [MOI] Neu tin hieu tu ghi ro LOT thi luon uu tien dung dung so do (giu
   // nguyen y dinh nguoi gui tin hieu). Chi khi KHONG co LOT rieng thi moi
   // xet InpUseRiskPercent - tinh lot theo % Balance dua tren khoang cach SL
   // thuc te (SL tin hieu neu co, khong thi theo ATR nhu binh thuong).
   double totalLot;
   if (lot > 0)
   {
      totalLot = MathMin(lot, InpMaxLotCap);
   }
   else if (InpUseRiskPercent)
   {
      double refForSizing = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slDistance = (sl > 0) ? MathAbs(refForSizing - sl) : (atr > 0 ? atr * InpSlAtrMik : 0);
      totalLot = MathMin(CalcRiskLot(slDistance), InpMaxLotCap);
      PrintFormat("[TelegramSignal] Lot theo risk %.2f%% cua Balance: %.2f", InpRiskPercent, totalLot);
   }
   else
   {
      totalLot = InpDefaultLot;
   }

   // [MOI] Score thap (nhung van du de qua InpMinScore) -> giam nua lot,
   // ap dung sau khi da xac dinh totalLot theo bat ky cach nao o tren.
   if (InpHalfLotOnLowScore && score >= 0 && score < InpLowScoreThreshold)
   {
      double before = totalLot;
      totalLot = NormalizeLot(totalLot / 2.0);
      PrintFormat("[TelegramSignal] Score %.0f < %.0f - giam lot tu %.2f con %.2f", score, InpLowScoreThreshold, before, totalLot);
   }

   if (!InpUseDualTpMode || atr <= 0)
   {
      double refPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int digitsS = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double slS = (sl > 0) ? sl : (atr > 0 ? (direction == 1 ? refPrice - atr * InpSlAtrMik : refPrice + atr * InpSlAtrMik) : 0);
      double tpS = (tp > 0) ? tp : (atr > 0 ? (direction == 1 ? refPrice + atr * InpTp2Atr  : refPrice - atr * InpTp2Atr)  : 0);
      OpenSingleLeg(direction, totalLot, sl, tp, atr, "TG Signal");
      if (InpNotifyOnOpen)
         TelegramSendMessage(StringFormat("%s EA %s — Đã mở lệnh %s\n💰 Lot: %.2f",
                                            DirIcon(direction), _Symbol, (direction == 1 ? "BUY" : "SELL"), totalLot));
      SendMirrorSignal(direction, refPrice, score, winRate, NormalizeDouble(slS, digitsS), NormalizeDouble(tpS, digitsS), 0);
      return;
   }

   // [SUA] Truoc day lam tron NUA lot roi dung CHUNG cho ca 2 lenh, nen khi
   // nua lot khong chia het theo buoc lot (vd 0.15/2=0.075 -> lam tron thanh
   // 0.08), tong 2 lenh bi thoi phong thanh 0.16 thay vi dung 0.15 nhu ban
   // dat. Sua lai: lenh 1 lam tron nua lot binh thuong, lenh 2 lay PHAN CON
   // LAI cua tong lot (roi moi lam tron), de tong 2 lenh luon sat dung
   // totalLot nhat co the theo buoc lot cua broker.
   double legLot1 = NormalizeLot(totalLot / 2.0);
   double legLot2 = NormalizeLot(totalLot - legLot1);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double entryPrice, useSl, useTp1, useTp2;
   if (direction == 1)
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      useSl  = (sl > 0) ? sl : NormalizeDouble(entryPrice - atr * InpSlAtrMik, digits);
      useTp1 = NormalizeDouble(entryPrice + atr * InpTp1Atr, digits);
      useTp2 = (tp > 0) ? tp : NormalizeDouble(entryPrice + atr * InpTp2Atr, digits);
      trade.Buy(legLot1, _Symbol, entryPrice, useSl, useTp1, "TG Signal TP1");
      trade.Buy(legLot2, _Symbol, entryPrice, useSl, useTp2, "TG Signal TP2");
   }
   else
   {
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      useSl  = (sl > 0) ? sl : NormalizeDouble(entryPrice + atr * InpSlAtrMik, digits);
      useTp1 = NormalizeDouble(entryPrice - atr * InpTp1Atr, digits);
      useTp2 = (tp > 0) ? tp : NormalizeDouble(entryPrice - atr * InpTp2Atr, digits);
      trade.Sell(legLot1, _Symbol, entryPrice, useSl, useTp1, "TG Signal TP1");
      trade.Sell(legLot2, _Symbol, entryPrice, useSl, useTp2, "TG Signal TP2");
   }

   g_tp1Ticket = FindPositionByComment("TP1");
   g_tp2Ticket = FindPositionByComment("TP2");

   if (InpNotifyOnOpen)
      TelegramSendMessage(StringFormat("%s EA %s — Đã mở lệnh %s (2 lệnh: TP1 + TP2)\n💰 Lot mỗi lệnh: %.2f | Tổng lot: %.2f",
                                         DirIcon(direction), _Symbol, (direction == 1 ? "BUY" : "SELL"), legLot1, legLot1 + legLot2));

   SendMirrorSignal(direction, entryPrice, score, winRate, useSl, useTp1, useTp2);
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

// [MOI] Sau khi da ve breakeven, tiep tuc keo SL theo gia (chi keo theo huong
// co loi, khong bao gio lui lai) de giu lai them loi nhuan neu gia chay gan
// TP2 roi dao chieu, thay vi tra het ve dung breakeven.
void TrailTp2Leg()
{
   if (!InpUseTrailingAfterTp1) return;
   if (g_trailingTicket == 0) return;
   if (!PositionSelectByTicket(g_trailingTicket)) { g_trailingTicket = 0; return; }

   double atrVal[];
   if (!GetBufferSeries(atrHandle, 0, 2, atrVal)) return;
   double atr = atrVal[1];
   if (atr <= 0) return;

   long   type      = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSl      = PositionGetDouble(POSITION_SL);
   double curTp      = PositionGetDouble(POSITION_TP);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double startDist = InpTrailStartAtr    * atr;
   double trailDist = InpTrailDistanceAtr * atr;
   double stepDist  = InpTrailStepAtr     * atr;

   if (type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if (bid < openPrice + startDist) return; // chua di du xa de bat dau keo
      double newSl = NormalizeDouble(bid - trailDist, digits);
      if (newSl > curSl + stepDist)
      {
         if (trade.PositionModify(g_trailingTicket, newSl, curTp))
            PrintFormat("[TelegramSignal] Trailing SL lenh #%I64u: %.2f -> %.2f", g_trailingTicket, curSl, newSl);
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
            PrintFormat("[TelegramSignal] Trailing SL lenh #%I64u: %.2f -> %.2f", g_trailingTicket, curSl, newSl);
      }
   }
}

// [MOI] Bat MOI su kien dong lenh cua EA nay: (1) bao ket qua ve Telegram,
// (2) neu la lenh TP1 trong cap TP1/TP2 thi kich hoat breakeven cho lenh con lai.
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
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return; // chi quan tam luc DONG lenh

   // --- [MOI] Bao ket qua ve Telegram, ap dung cho MOI kieu dong lenh --
   // (cham TP, cham SL, breakeven, hay CLOSE thu cong tu tin hieu deu duoc bao)
   if (InpNotifyOnClose)
   {
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                       HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                       HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      long   dealType   = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      string origDir    = (dealType == DEAL_TYPE_SELL) ? "BUY" : "SELL"; // deal dong nguoc huong voi lenh goc
      string resultIcon = (profit >= 0) ? "✅" : "❌";
      string resultTxt  = (profit >= 0) ? "LỜI" : "LỖ";

      TelegramSendMessage(StringFormat("%s EA %s — Đã đóng lệnh %s\n📍 Giá đóng: %.2f\n💵 Kết quả: %s %.2f %s",
                                         resultIcon, _Symbol, origDir, closePrice, resultTxt, profit, AccountInfoString(ACCOUNT_CURRENCY)));
   }

   // --- Breakeven cho cap TP1/TP2 (giu nguyen logic cu) ----------------
   if (InpUseDualTpMode && InpMoveToBreakevenOnTp1 && (g_tp1Ticket != 0 || g_tp2Ticket != 0))
   {
      ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

      if (posId == g_tp1Ticket && g_tp2Ticket != 0)
      {
         MoveToBreakeven(g_tp2Ticket);
         g_trailingTicket = g_tp2Ticket; // [MOI] bat dau theo doi de trail tiep tu day
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

   // [MOI] Neu chinh lenh dang duoc trail vua dong (cham SL trailing hoac
   // van chinh dich TP2), dung theo doi lai.
   if (g_trailingTicket != 0 && (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == g_trailingTicket)
      g_trailingTicket = 0;
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
   string upper = text;
   StringToUpper(upper);

   // [MOI] Chan tu dau: neu channel co nhieu bot/indicator, chi xu ly tin
   // nhan THUC SU den tu nguon mong muon (co chua InpSourceTag). Tin cua
   // bot/indicator khac se bi bo qua hoan toan, du co chua BUY/SELL hay khong.
   if (InpRequireSourceTag)
   {
      string tagUpper = InpSourceTag;
      StringToUpper(tagUpper);
      if (StringLen(tagUpper) > 0 && StringFind(upper, tagUpper) < 0)
         return; // khong phai nguon minh dang theo doi - im lang bo qua, khong log rac
   }

   g_lastSignalText = text;
   g_lastSignalTime = TimeCurrent();

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

   // [SIET] Neu bat loc nhung khong doc duoc Score/WinRate tu tin nhan (vd
   // dinh dang bi doi khac di), coi nhu KHONG DAT thay vi im lang bo qua
   // buoc loc - tranh vo tinh vao lenh du tin nhan khong du thong tin.
   if (InpMinScore > 0 && score < InpMinScore)
   {
      Print("[TelegramSignal] MIK Score ", score, " < nguong ", InpMinScore, " (hoac khong doc duoc) - bo qua tin hieu: ", text);
      return;
   }
   if (InpMinWinRate > 0 && winRate < InpMinWinRate)
   {
      Print("[TelegramSignal] Ty le thang lich su ", winRate, "% < nguong ", InpMinWinRate, "% (hoac khong doc duoc) - bo qua tin hieu: ", text);
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

   ExecuteSignal(direction, sl, tp, lot, score, winRate);
   PrintFormat("[TelegramSignal] Da xu ly tin hieu %s | Score=%.0f WinRate=%.1f%% RefPrice=%.2f SL=%.2f TP=%.2f LOT=%.2f | goc: %s",
               (direction == 1 ? "BUY" : "SELL"), score, winRate, refPrice, sl, tp, lot, text);
}

// [MOI] Doi ma khung gio dang go trong chat ("M5", "H1"...) sang ENUM_TIMEFRAMES.
// Tra ve -1 neu khong nhan dien duoc.
ENUM_TIMEFRAMES ParseTimeframeCode(const string codeUpper)
{
   if (codeUpper == "M1")  return PERIOD_M1;
   if (codeUpper == "M5")  return PERIOD_M5;
   if (codeUpper == "M15") return PERIOD_M15;
   if (codeUpper == "M30") return PERIOD_M30;
   if (codeUpper == "H1")  return PERIOD_H1;
   if (codeUpper == "H4")  return PERIOD_H4;
   if (codeUpper == "D1")  return PERIOD_D1;
   if (codeUpper == "W1")  return PERIOD_W1;
   if (codeUpper == "MN1") return PERIOD_MN1;
   return (ENUM_TIMEFRAMES)(-1);
}

// [MOI] Nhan tin nhan dang "TF M5" de doi khung gio cua chinh chart dang chay
// EA nay (dong thoi doi luon khung tinh cua indicator MIK vi cung gan tren 1
// chart). Cho phep qua 1 trong 2 cach xac thuc: (1) dung Telegram User ID
// (InpAdminUserId, dung khi nhan rieng cho bot - hoat dong voi ca Group lan
// Channel), hoac (2) tin thang theo Chat ID cua channel tin hieu
// (InpTrustSignalChannelForTf, dung khi gui ngay trong channel do - LUU Y:
// voi Channel that su (khong phai Group), Telegram khong tra ve danh tinh
// nguoi gui qua Bot API nen cach (1) se khong nhan dien duoc tin gui trong
// channel, phai dung DM rieng cho bot). Tra ve true neu tin nhan nay DA
// duoc xu ly nhu 1 lenh dieu khien (du hop le hay khong), de PollTelegram
// biet khong can dua xuong ProcessSignalText nua.
bool TryHandleTfCommand(const string text, long fromUserId, long msgChatId)
{
   if (!InpEnableTfCommand) return false;

   string upper = text;
   StringToUpper(upper);
   StringTrimLeft(upper);
   StringTrimRight(upper);

   string parts[];
   int cnt = StringSplit(upper, ' ', parts);
   if (cnt < 2 || parts[0] != "TF") return false; // khong phai dang "TF ..." - bo qua hoan toan, khong log

   // [SUA] Tu day chac chan la 1 lenh "TF ..." that su - kiem tra quyen va
   // LOG RO LY DO neu bi tu choi, de debug duoc thay vi im lang bo qua nhu
   // truoc (nguoi dung khong biet dang vuong o dau).
   bool authorized = false;
   if (InpAdminUserId != 0 && fromUserId == InpAdminUserId) authorized = true;
   if (!authorized && InpTrustSignalChannelForTf && InpChatId != 0 && msgChatId == InpChatId) authorized = true;

   if (!authorized)
   {
      PrintFormat("[TelegramSignal] Lenh TF bi TU CHOI - tin nhan tu from.id=%I64d, chat.id=%I64d | Dieu kien: from.id phai == InpAdminUserId(%I64d), HOAC InpTrustSignalChannelForTf=true VA chat.id phai == InpChatId(%I64d)",
                  fromUserId, msgChatId, InpAdminUserId, InpChatId);
      return true; // van la lenh dieu khien (khong phai tin hieu giao dich), khong dua xuong ProcessSignalText
   }

   ENUM_TIMEFRAMES tf = ParseTimeframeCode(parts[1]);
   if ((int)tf < 0)
   {
      TelegramSendMessage("⚠️ Không nhận diện khung giờ '" + parts[1] + "'. Dùng: M1/M5/M15/M30/H1/H4/D1/W1/MN1");
      return true;
   }
   if (tf == (ENUM_TIMEFRAMES)Period())
   {
      TelegramSendMessage("ℹ️ Chart " + _Symbol + " đang ở khung " + parts[1] + " rồi.");
      return true;
   }

   // Gui xac nhan TRUOC khi doi khung, vi ChartSetSymbolPeriod se lam EA
   // nay khoi dong lai (OnDeinit/OnInit) ngay sau do.
   TelegramSendMessage("🔄 Đang đổi chart " + _Symbol + " sang khung " + parts[1] + "...");
   if (!ChartSetSymbolPeriod(0, _Symbol, tf))
      TelegramSendMessage("❌ Đổi khung giờ thất bại.");

   return true;
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
      long   fromId = ExtractLongAfter(json, idPos, "\"from\":{\"id\":", blockEnd);
      string text   = ExtractStringAfter(json, idPos, "\"text\":\"", blockEnd);

      if (updateId >= g_offset)
      {
         g_offset = updateId + 1;
         if (StringLen(g_offsetGvName) > 0) GlobalVariableSet(g_offsetGvName, (double)g_offset);
      }

      if (StringLen(text) > 0)
      {
         // Lenh dieu khien (vd doi TF) tu kiem tra quyen rieng (User ID hoac
         // tin channel), khong bi rang buoc boi bo loc InpChatId ben duoi.
         if (!TryHandleTfCommand(text, fromId, chatId))
         {
            if (InpChatId == 0 || chatId == InpChatId)
               ProcessSignalText(text);
         }
      }

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
   string keys[] = {"Title", "Status", "LastSignal", "Position", "Legs", "Trailing", "LocalCalc", "TfControl"};
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

   if (!InpUseTrailingAfterTp1)
      SetLabel(DASH_PREFIX + "Trailing", "Trailing sau TP1: TAT", clrSilver);
   else if (g_trailingTicket == 0)
      SetLabel(DASH_PREFIX + "Trailing", "Trailing sau TP1: cho TP1 dong...", clrSilver);
   else if (PositionSelectByTicket(g_trailingTicket))
      SetLabel(DASH_PREFIX + "Trailing",
                StringFormat("Trailing #%I64u: SL=%.2f", g_trailingTicket, PositionGetDouble(POSITION_SL)),
                clrKhaki);

   // [MOI] Hien thi 4 gia tri EA dang tu tinh, de doi chieu truc tiep voi so
   // hien tren panel RSI cua indicator MIK that (kiem chung do chinh xac).
   if (InpUseLocalExit)
   {
      double ema9[], ema20[];
      double rsiEma1 = 0, rsiWma1 = 0;
      bool okEma = GetBufferSeries(emaFastHandleLocal, 0, 2, ema9) && GetBufferSeries(emaSlowHandleLocal, 0, 2, ema20);
      bool okRsi = ComputeRsiCrossLocal(rsiEma1, rsiWma1);
      if (okEma && okRsi)
         SetLabel(DASH_PREFIX + "LocalCalc",
                   StringFormat("Tu tinh: EMA9=%.2f EMA20=%.2f | E(RSI)=%.1f W(RSI)=%.1f", ema9[1], ema20[1], rsiEma1, rsiWma1),
                   clrKhaki);
      else
         SetLabel(DASH_PREFIX + "LocalCalc", "Tu tinh: chua du du lieu", clrSilver);
   }
   else
      SetLabel(DASH_PREFIX + "LocalCalc", "Tu tinh EXIT: TAT", clrSilver);

   bool tfAuthAny = InpEnableTfCommand && (InpAdminUserId != 0 || InpTrustSignalChannelForTf);
   string tfMode = !InpEnableTfCommand ? "TAT"
                    : (InpAdminUserId != 0 && InpTrustSignalChannelForTf) ? "BAT (User ID + Channel)"
                    : (InpAdminUserId != 0) ? "BAT (chi qua User ID / DM)"
                    : InpTrustSignalChannelForTf ? "BAT (tin thang channel tin hieu)"
                    : "TAT (chua khai bao cach xac thuc nao)";
   string tfControlTxt = StringFormat("TF hien tai: %s | Dieu khien tu Telegram: %s",
                                        EnumToString((ENUM_TIMEFRAMES)Period()), tfMode);
   SetLabel(DASH_PREFIX + "TfControl", tfControlTxt, tfAuthAny ? clrLimeGreen : clrSilver);
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

   // [MOI] EA co the tu khoi dong lai giua chung khi doi TF qua lenh Telegram
   // (ChartSetSymbolPeriod lam OnInit chay lai). Khoi phuc lai trang thai de
   // khong xu ly lai tin nhan cu va khong mat dau vet cap lenh TP1/TP2.
   g_offsetGvName = "TGSig_Offset_" + IntegerToString(InpMagicNumber);
   if (GlobalVariableCheck(g_offsetGvName))
      g_offset = (long)GlobalVariableGet(g_offsetGvName);
   g_tp1Ticket = FindPositionByComment("TP1");
   g_tp2Ticket = FindPositionByComment("TP2");
   g_trailingTicket = 0;
   if (g_tp1Ticket == 0 && g_tp2Ticket != 0)
   {
      // TP1 da dong tu truoc khi EA khoi dong lai - lenh TP2 dang la "runner"
      // (co the da o breakeven hoac dang trail), tiep tuc theo doi no.
      g_trailingTicket = g_tp2Ticket;
      g_tp2Ticket = 0;
   }

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   if (atrHandle == INVALID_HANDLE)
   {
      Print("[TelegramSignal] Khong tao duoc ATR handle");
      return INIT_FAILED;
   }

   if (InpUseLocalExit)
   {
      emaFastHandleLocal = iMA(_Symbol, PERIOD_CURRENT, InpLocalEma9,  0, MODE_EMA, PRICE_CLOSE);
      emaSlowHandleLocal = iMA(_Symbol, PERIOD_CURRENT, InpLocalEma20, 0, MODE_EMA, PRICE_CLOSE);
      rsiHandleLocal      = iRSI(_Symbol, PERIOD_CURRENT, InpLocalRsiPeriod, PRICE_CLOSE);
      if (emaFastHandleLocal == INVALID_HANDLE || emaSlowHandleLocal == INVALID_HANDLE || rsiHandleLocal == INVALID_HANDLE)
      {
         Print("[TelegramSignal] Khong tao duoc handle cho tu tinh EXIT tai cho");
         return INIT_FAILED;
      }
   }

   CreateDashboard();
   EventSetTimer(MathMax(1, InpPollSeconds));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if (atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if (emaFastHandleLocal != INVALID_HANDLE) IndicatorRelease(emaFastHandleLocal);
   if (emaSlowHandleLocal != INVALID_HANDLE) IndicatorRelease(emaSlowHandleLocal);
   if (rsiHandleLocal      != INVALID_HANDLE) IndicatorRelease(rsiHandleLocal);
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
   CheckLocalExit();
   TrailTp2Leg();
   UpdateDashboard();
}
