//+------------------------------------------------------------------+
//|                                         MarketReport_EA.mq5      |
//|  EA phan tich da khung gio (giong kieu bot "AI Notification"     |
//|  ban gui lam mau): Stochastic K/D, MACD, xu huong UP/DOWN cho    |
//|  tung khung M1/M5/M15/M30/H1/H4/D1, gui thang vao Telegram.      |
//|  Khong vao lenh - chi bao cao, hoan toan doc lap voi cac EA giao |
//|  dich khac (TelegramSignal_EA...).                                |
//|                                                                    |
//|  2 CACH NHAN BAO CAO:                                             |
//|  1) Go lenh trong chat (vd "XAU DA KHUNG") -> EA tra loi ngay.    |
//|  2) Tu dong gui dinh ky moi InpAutoIntervalMinutes phut (0 = tat).|
//|                                                                    |
//|  BAT BUOC: whitelist https://api.telegram.org trong Tools->       |
//|  Options->Expert Advisors->Allow WebRequest for listed URL.        |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

//====================================================================
// Inputs
//====================================================================
input group "=== Telegram Bot ==="
input string InpBotToken    = "";   // Token bot (dung lai bot da co, vd bot cua TelegramSignal_EA)
input long   InpChatId      = 0;    // Chat ID group/channel muon nhan bao cao
input int    InpTopicId     = 0;    // message_thread_id cua topic muon gui vao (0 = topic General mac dinh)
input int    InpPollSeconds = 5;    // Tan suat kiem tra lenh go tay (giay)

input group "=== Lenh go tay de xin bao cao ngay ==="
input string InpReportKeyword = "DA KHUNG"; // Go chua cum tu nay (khong phan biet hoa/thuong) trong chat de xin bao cao ngay

input group "=== [MOI] Lich kinh te (Tin Hom Nay / Tin Ca Tuan) ==="
input string InpTodayNewsKeyword = "TIN HOM NAY"; // Go chua cum tu nay de xin lich kinh te trong ngay
input string InpWeekNewsKeyword  = "TIN CA TUAN";  // Go chua cum tu nay de xin lich kinh te ca tuan (Thu 2 - Chu Nhat)
input string InpCalendarCurrency = "USD";           // Chi lay tin cua dong tien nay ("" = lay tat ca dong tien)
input bool   InpCalendarOnlyImportant = true;       // true: chi lay tin muc Trung binh/Cao, bo qua tin Thap

input group "=== Tu dong gui dinh ky ==="
input int    InpAutoIntervalMinutes = 60;   // Tu dong gui bao cao moi X phut (0 = tat, chi gui khi co lenh go tay)

input group "=== Symbol phan tich ==="
input string InpAnalyzeSymbol = ""; // De trong = dung symbol cua chart dang gan EA nay

//====================================================================
// Danh sach khung gio phan tich - dung chung cho toan bo EA
//====================================================================
ENUM_TIMEFRAMES g_tfList[7] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
string          g_tfLabel[7] = {"1m", "5m", "15m", "30m", "1H", "4H", "1D"};

string g_symbol = "";
long   g_offset = 0;
string g_offsetGvName = "";
datetime g_lastAutoSend = 0;

#define DASH_PREFIX "MktReport_Dash_"

//====================================================================
// Ham tien ich Telegram (tuong tu TelegramSignal_EA, doc lap rieng)
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

// [MOI] Bo nut bam "Custom Keyboard" - gan kem vao tin nhan de AI ban dang
// hien luon o duoi khung chat, ai cung bam duoc (bam = tu dong gui dung
// chu do, xu ly y het go tay). "is_persistent" giu nut hien lien tuc,
// khong bi an di sau khi bam.
string BuildKeyboardMarkup()
{
   return "{\"keyboard\":[[{\"text\":\"📊 XAU DA KHUNG\"}],"
          "[{\"text\":\"📅 TIN HOM NAY\"},{\"text\":\"🗓 TIN CA TUAN\"}]],"
          "\"resize_keyboard\":true,\"is_persistent\":true}";
}

// [MOI] Gui tin dang HTML (dung <pre> de giu bang canh deu font monospace,
// giong bang K/D/MACD/Trend trong anh mau ban gui). replyMarkup: truyen
// chuoi JSON tra ve tu BuildKeyboardMarkup() de kem nut bam, hoac "" neu
// khong can kem nut.
// [SUA] Doi tu GET (nhet het vao URL) sang POST (noi dung nam trong body) -
// GET voi URL qua dai/phuc tap (tin nhieu dong + reply_markup JSON) de bi
// WebRequest tra ve loi (thuc te da gap loi 4002 khi test), trong khi cung
// noi dung do gui thu bang GET don gian qua trinh duyet lai thanh cong -
// chung to van de nam o do dai/cau truc URL, khong phai o bot/quyen group.
// POST khong bi gioi han bang URL nen tranh duoc loi nay.
bool TelegramSendHtml(long chatId, int topicId, const string htmlText, const string replyMarkup = "")
{
   if (StringLen(InpBotToken) == 0 || chatId == 0) return false;

   string url = "https://api.telegram.org/bot" + InpBotToken + "/sendMessage";

   string body = "chat_id=" + IntegerToString(chatId) + "&parse_mode=HTML&text=" + UrlEncode(htmlText);
   if (topicId > 0)
      body += "&message_thread_id=" + IntegerToString(topicId);
   if (StringLen(replyMarkup) > 0)
      body += "&reply_markup=" + UrlEncode(replyMarkup);

   char postData[];
   int  bodyLen = StringToCharArray(body, postData, 0, WHOLE_ARRAY, CP_UTF8) - 1; // bo byte NULL cuoi
   if (bodyLen > 0) ArrayResize(postData, bodyLen);

   char   resultData[];
   string resultHeaders;
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, postData, resultData, resultHeaders);
   if (res == -1)
   {
      Print("[MarketReport] Gui Telegram that bai, loi ", GetLastError());
      return false;
   }
   return true;
}

bool TelegramGetUpdates(string &jsonOut)
{
   string url = "https://api.telegram.org/bot" + InpBotToken + "/getUpdates?offset=" + IntegerToString(g_offset) + "&timeout=0";
   char   post[];
   char   resultData[];
   string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, resultData, resultHeaders);
   if (res == -1) return false;
   jsonOut = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   return true;
}

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
// [MOI] Tinh Stochastic K/D + MACD + Trend (EMA20 vs EMA50) cho 1 khung
//====================================================================
bool GetTfRow(ENUM_TIMEFRAMES tf, double &k, double &d, double &macdHist, bool &trendUp)
{
   int stochH = iStochastic(g_symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   int macdH  = iMACD(g_symbol, tf, 12, 26, 9, PRICE_CLOSE);
   int emaFastH = iMA(g_symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowH = iMA(g_symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);

   if (stochH == INVALID_HANDLE || macdH == INVALID_HANDLE ||
       emaFastH == INVALID_HANDLE || emaSlowH == INVALID_HANDLE)
      return false;

   double kBuf[], dBuf[], macdMain[], macdSig[], emaFast[], emaSlow[];
   bool ok = true;
   ok = ok && CopyBuffer(stochH, 0, 1, 1, kBuf) > 0;
   ok = ok && CopyBuffer(stochH, 1, 1, 1, dBuf) > 0;
   ok = ok && CopyBuffer(macdH, 0, 1, 1, macdMain) > 0;
   ok = ok && CopyBuffer(macdH, 1, 1, 1, macdSig) > 0;
   ok = ok && CopyBuffer(emaFastH, 0, 1, 1, emaFast) > 0;
   ok = ok && CopyBuffer(emaSlowH, 0, 1, 1, emaSlow) > 0;

   IndicatorRelease(stochH);
   IndicatorRelease(macdH);
   IndicatorRelease(emaFastH);
   IndicatorRelease(emaSlowH);

   if (!ok) return false;

   k = kBuf[0];
   d = dBuf[0];
   macdHist = macdMain[0] - macdSig[0];
   trendUp = emaFast[0] > emaSlow[0];
   return true;
}

//====================================================================
// [MOI] Dung html-escape toi thieu (chi can & < > khi dung parse_mode=HTML)
//====================================================================
string HtmlEscape(const string s)
{
   string r = s;
   StringReplace(r, "&", "&amp;");
   StringReplace(r, "<", "&lt;");
   StringReplace(r, ">", "&gt;");
   return r;
}

//====================================================================
// [MOI] Dung ham nay de build toan bo noi dung bao cao da khung
//====================================================================
string BuildReport()
{
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double openToday = iOpen(g_symbol, PERIOD_D1, 0);
   string dirIcon = (bid >= openToday) ? "🟢" : "🔴";

   string table = StringFormat("%-4s %6s %6s %7s %s\n", "TF", "K", "D", "MACD", "Trend");
   table += "--------------------------------\n";

   int upCount = 0, downCount = 0, validCount = 0;
   for (int i = 0; i < 7; i++)
   {
      double k, d, macdHist;
      bool trendUp;
      if (!GetTfRow(g_tfList[i], k, d, macdHist, trendUp))
      {
         table += StringFormat("%-4s   không lấy được dữ liệu\n", g_tfLabel[i]);
         continue;
      }
      string trendTxt = trendUp ? "UP" : "DOWN";
      table += StringFormat("%-4s %6.1f %6.1f %+7.1f %s\n", g_tfLabel[i], k, d, macdHist, trendTxt);

      // Chi tinh xu huong chinh tu 3 khung lon (H1/H4/D1), giong logic "xu huong
      // chinh 4H-1D" trong mau ban gui - tranh nhieu tin hieu tu khung nho.
      if (g_tfList[i] == PERIOD_H1 || g_tfList[i] == PERIOD_H4 || g_tfList[i] == PERIOD_D1)
      {
         validCount++;
         if (trendUp) upCount++; else downCount++;
      }
   }

   string mainTrend;
   if (validCount == 0) mainTrend = "Không đủ dữ liệu";
   else if (upCount == validCount) mainTrend = "TĂNG (đồng thuận)";
   else if (downCount == validCount) mainTrend = "GIẢM (đồng thuận)";
   else mainTrend = "GIẰNG CO / CHƯA RÕ XU HƯỚNG";

   string symDisp = g_symbol;
   string msg = StringFormat("%s <b>%s Da Khung</b>\n💰 Gia hien tai: <b>%.2f</b>\n📌 Mo cua hom nay: %.2f\n\n<pre>%s</pre>\n🎯 Xu huong chinh (H1-D1): <b>%s</b>",
                               dirIcon, symDisp, bid, openToday, HtmlEscape(table), mainTrend);
   return msg;
}

void SendReport()
{
   string msg = BuildReport();
   TelegramSendHtml(InpChatId, InpTopicId, msg, BuildKeyboardMarkup());
   g_lastAutoSend = TimeCurrent();
}

// [MOI] Icon theo muc do quan trong cua tin ("importance"), dung ham lich
// kinh te co san cua MT5 (CalendarValueHistory/CalendarEventById) - khong
// can API ben ngoai nao ca.
string ImportanceIcon(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   if (imp == CALENDAR_IMPORTANCE_HIGH)     return "🔴";
   if (imp == CALENDAR_IMPORTANCE_MODERATE) return "🟠";
   return "⚪";
}

// [MOI] Lay lich kinh te trong khoang [fromTime, toTime), loc theo
// InpCalendarCurrency va muc do quan trong (neu InpCalendarOnlyImportant),
// gom nhom theo tung ngay giong dinh dang mau ban gui ("Thu Tu 16/09: ...").
string BuildCalendarReport(datetime fromTime, datetime toTime, const string title)
{
   MqlCalendarValue values[];
   if (!CalendarValueHistory(values, fromTime, toTime, NULL, InpCalendarCurrency))
      return "📅 <b>" + title + "</b>\n⚠️ Không lấy được lịch kinh tế (kiểm tra lại kết nối Calendar của MT5).";

   string msg = "📅 <b>" + title + "</b>\n";
   datetime lastDay = -1;
   int count = 0;

   for (int i = 0; i < ArraySize(values); i++)
   {
      MqlCalendarEvent ev;
      if (!CalendarEventById(values[i].event_id, ev)) continue;
      if (InpCalendarOnlyImportant && ev.importance != CALENDAR_IMPORTANCE_MODERATE && ev.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      datetime evTime = values[i].time;
      datetime dayOnly = evTime - (evTime % 86400);
      if (dayOnly != lastDay)
      {
         lastDay = dayOnly;
         msg += "\n📆 " + TimeToString(evTime, TIME_DATE) + ":\n";
      }

      msg += StringFormat("⏰ %s %s %s\n", TimeToString(evTime, TIME_MINUTES), ImportanceIcon(ev.importance), HtmlEscape(ev.name));
      count++;
   }

   if (count == 0)
      msg += "\nKhông có tin " + (InpCalendarOnlyImportant ? "quan trọng (Trung bình/Cao) " : "") + "nào trong khoảng thời gian này.";

   return msg;
}

void SendTodayNews()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   string msg = BuildCalendarReport(dayStart, dayStart + 86400, "Tin Hôm Nay");
   TelegramSendHtml(InpChatId, InpTopicId, msg, BuildKeyboardMarkup());
}

void SendWeekNews()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   // day_of_week: 0=Chu Nhat...6=Thu Bay. Quy ve dau tuan la Thu Hai.
   int daysSinceMonday = (dt.day_of_week == 0) ? 6 : dt.day_of_week - 1;
   datetime weekStart = dayStart - daysSinceMonday * 86400;
   datetime weekEnd   = weekStart + 7 * 86400;

   string msg = BuildCalendarReport(weekStart, weekEnd, "Tin Cả Tuần");
   TelegramSendHtml(InpChatId, InpTopicId, msg, BuildKeyboardMarkup());
}

// [MOI] Tin chao gui 1 lan luc EA khoi dong, kem nut bam - de nut hien ra
// ngay trong khung chat tu dau, khong phai cho ai go lenh xin bao cao dau
// tien thi nut moi xuat hien.
void SendWelcomeMenu()
{
   string msg = StringFormat("🤖 <b>Market Report EA</b> đã sẵn sàng cho %s.\nBấm nút bên dưới để xem báo cáo đa khung bất cứ lúc nào.", g_symbol);
   TelegramSendHtml(InpChatId, InpTopicId, msg, BuildKeyboardMarkup());
}

//====================================================================
// [MOI] Nhan lenh go tay tu Telegram, xin bao cao ngay
//====================================================================
void PollTelegram()
{
   string json;
   if (!TelegramGetUpdates(json)) return;
   if (StringLen(json) < 10) return;

   int pos = 0;
   int len = StringLen(json);
   string kwUpper = InpReportKeyword;
   StringToUpper(kwUpper);
   string kwTodayUpper = InpTodayNewsKeyword;
   StringToUpper(kwTodayUpper);
   string kwWeekUpper = InpWeekNewsKeyword;
   StringToUpper(kwWeekUpper);

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

      if (updateId >= g_offset)
      {
         g_offset = updateId + 1;
         if (StringLen(g_offsetGvName) > 0) GlobalVariableSet(g_offsetGvName, (double)g_offset);
      }

      if (StringLen(text) > 0 && (InpChatId == 0 || chatId == InpChatId))
      {
         string textUpper = text;
         StringToUpper(textUpper);
         if (StringFind(textUpper, kwTodayUpper) >= 0)
         {
            Print("[MarketReport] Nhan lenh xin lich kinh te hom nay");
            SendTodayNews();
         }
         else if (StringFind(textUpper, kwWeekUpper) >= 0)
         {
            Print("[MarketReport] Nhan lenh xin lich kinh te ca tuan");
            SendWeekNews();
         }
         else if (StringFind(textUpper, kwUpper) >= 0)
         {
            Print("[MarketReport] Nhan lenh xin bao cao da khung");
            SendReport();
         }
      }

      if (nextIdPos < 0) break;
      pos = blockEnd;
   }
}

//====================================================================
// Dashboard don gian
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   string keys[] = {"Title", "Status", "LastSend"};
   int x = 10, y = 18, dy = 16;
   for (int i = 0; i < ArraySize(keys); i++)
   {
      string name = DASH_PREFIX + keys[i];
      if (ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
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
   SetLabel(DASH_PREFIX + "Title", "=== Market Report EA (" + g_symbol + ") ===", clrWhite);
   SetLabel(DASH_PREFIX + "Status", StringFormat("Lenh go tay: '%s' | Tu dong: %s",
             InpReportKeyword, (InpAutoIntervalMinutes > 0) ? StringFormat("moi %d phut", InpAutoIntervalMinutes) : "TAT"),
             clrSilver);
   string lastTxt = (g_lastAutoSend == 0) ? "Chua gui lan nao" : TimeToString(g_lastAutoSend, TIME_DATE | TIME_MINUTES);
   SetLabel(DASH_PREFIX + "LastSend", "Lan gui gan nhat: " + lastTxt, clrKhaki);
}

//====================================================================
// Expert lifecycle
//====================================================================
int OnInit()
{
   g_symbol = (StringLen(InpAnalyzeSymbol) > 0) ? InpAnalyzeSymbol : _Symbol;

   if (StringLen(InpBotToken) == 0)
      Print("[MarketReport] Chua nhap InpBotToken - EA se khong hoat dong");

   g_offsetGvName = "MktReport_Offset_" + g_symbol;
   if (GlobalVariableCheck(g_offsetGvName))
      g_offset = (long)GlobalVariableGet(g_offsetGvName);

   CreateDashboard();
   if (StringLen(InpBotToken) > 0 && InpChatId != 0)
      SendWelcomeMenu();
   EventSetTimer(MathMax(1, InpPollSeconds));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
}

void OnTimer()
{
   if (StringLen(InpBotToken) > 0)
      PollTelegram();

   if (InpAutoIntervalMinutes > 0)
   {
      datetime now = TimeCurrent();
      if (g_lastAutoSend == 0 || now - g_lastAutoSend >= InpAutoIntervalMinutes * 60)
         SendReport();
   }

   UpdateDashboard();
}

void OnTick()
{
   // Khong giao dich - EA nay chi bao cao, khong can xu ly gi moi tick.
}
