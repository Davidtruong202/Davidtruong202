// Lop gia lap API MQL5 toi thieu cho bo kiem thu mt5sim (chi phan EA David Hunter V5 dung).
// Khong thay the MetaEditor/MT5: dung de kiem tra cu phap, kieu, chi so mang va chay EA tren tick that.
#pragma once
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <string>
#include <type_traits>
#include <vector>

typedef std::string string;
typedef long datetime;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef unsigned short ushort;
typedef unsigned char uchar;
typedef unsigned int color;

[[noreturn]] void mql_fatal(const std::string &msg);
void __unknown_input(const std::string &k);

template <class T> struct DynArr
{
   std::vector<T> v;
   T &operator[](long i)
   {
      if(i < 0 || (size_t)i >= v.size()) mql_fatal("array out of range: index " + std::to_string(i) + " size " + std::to_string(v.size()));
      return v[(size_t)i];
   }
   const T &operator[](long i) const
   {
      if(i < 0 || (size_t)i >= v.size()) mql_fatal("array out of range: index " + std::to_string(i) + " size " + std::to_string(v.size()));
      return v[(size_t)i];
   }
};

template <class T, int N> struct StatArr
{
   T a[N];
   T &operator[](long i)
   {
      if(i < 0 || i >= N) mql_fatal("static array out of range: index " + std::to_string(i) + " size " + std::to_string(N));
      return a[i];
   }
   const T &operator[](long i) const
   {
      if(i < 0 || i >= N) mql_fatal("static array out of range: index " + std::to_string(i) + " size " + std::to_string(N));
      return a[i];
   }
};

template <class T> inline void ZeroMemory(T &x) { x = T(); }
template <class T> inline int ArraySize(const DynArr<T> &a) { return (int)a.v.size(); }
template <class T, int N> inline int ArraySize(const StatArr<T, N> &) { return N; }
template <class T> inline int ArrayResize(DynArr<T> &a, int n, int reserve = 0)
{
   if(n < 0) return -1;
   if(reserve > 0) a.v.reserve((size_t)n + (size_t)reserve);
   a.v.resize((size_t)n);
   return n;
}
template <class T> inline void ArrayFree(DynArr<T> &a) { a.v.clear(); }

// ---------------------------------------------------------------- hang so, enum
enum ENUM_TIMEFRAMES { PERIOD_CURRENT = 0, PERIOD_M1 = 1, PERIOD_M2 = 2, PERIOD_M3 = 3, PERIOD_M4 = 4, PERIOD_M5 = 5, PERIOD_M6 = 6,
                       PERIOD_M10 = 10, PERIOD_M12 = 12, PERIOD_M15 = 15, PERIOD_M20 = 20, PERIOD_M30 = 30, PERIOD_H1 = 16385,
                       PERIOD_H2 = 16386, PERIOD_H4 = 16388, PERIOD_D1 = 16408, PERIOD_W1 = 32769, PERIOD_MN1 = 49153 };
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY = 0, ORDER_TYPE_SELL = 1 };
enum ENUM_ORDER_TYPE_FILLING { ORDER_FILLING_FOK = 0, ORDER_FILLING_IOC = 1, ORDER_FILLING_RETURN = 2 };
enum ENUM_ORDER_TYPE_TIME { ORDER_TIME_GTC = 0 };
enum ENUM_TRADE_REQUEST_ACTIONS { TRADE_ACTION_DEAL = 1, TRADE_ACTION_PENDING = 5, TRADE_ACTION_SLTP = 6, TRADE_ACTION_MODIFY = 7,
                                  TRADE_ACTION_REMOVE = 8, TRADE_ACTION_CLOSE_BY = 10 };
const uint TRADE_RETCODE_REQUOTE = 10004, TRADE_RETCODE_REJECT = 10006, TRADE_RETCODE_PLACED = 10008, TRADE_RETCODE_DONE = 10009,
           TRADE_RETCODE_DONE_PARTIAL = 10010, TRADE_RETCODE_ERROR = 10011, TRADE_RETCODE_TIMEOUT = 10012, TRADE_RETCODE_INVALID = 10013,
           TRADE_RETCODE_INVALID_VOLUME = 10014, TRADE_RETCODE_INVALID_PRICE = 10015, TRADE_RETCODE_INVALID_STOPS = 10016,
           TRADE_RETCODE_TRADE_DISABLED = 10017, TRADE_RETCODE_MARKET_CLOSED = 10018, TRADE_RETCODE_NO_MONEY = 10019,
           TRADE_RETCODE_PRICE_CHANGED = 10020, TRADE_RETCODE_PRICE_OFF = 10021, TRADE_RETCODE_NO_CHANGES = 10025,
           TRADE_RETCODE_CONNECTION = 10031, TRADE_RETCODE_POSITION_CLOSED = 10036;
const int SYMBOL_FILLING_FOK = 1, SYMBOL_FILLING_IOC = 2;
enum ENUM_SYMBOL_INFO_DOUBLE { SYMBOL_BID, SYMBOL_ASK, SYMBOL_POINT, SYMBOL_TRADE_TICK_SIZE, SYMBOL_TRADE_TICK_VALUE, SYMBOL_VOLUME_MIN,
                               SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP, SYMBOL_TRADE_CONTRACT_SIZE };
enum ENUM_SYMBOL_INFO_INTEGER { SYMBOL_DIGITS, SYMBOL_SPREAD, SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_FILLING_MODE,
                                SYMBOL_TRADE_CALC_MODE, SYMBOL_TRADE_MODE, SYMBOL_TRADE_EXEMODE };
enum ENUM_SYMBOL_CALC_MODE { SYMBOL_CALC_MODE_FOREX = 0, SYMBOL_CALC_MODE_FUTURES = 1, SYMBOL_CALC_MODE_CFD = 2, SYMBOL_CALC_MODE_CFDINDEX = 3,
                             SYMBOL_CALC_MODE_CFDLEVERAGE = 4, SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE = 5 };
enum ENUM_ACCOUNT_INFO_DOUBLE { ACCOUNT_BALANCE, ACCOUNT_EQUITY, ACCOUNT_MARGIN, ACCOUNT_MARGIN_FREE, ACCOUNT_MARGIN_LEVEL, ACCOUNT_PROFIT };
enum ENUM_ACCOUNT_INFO_INTEGER { ACCOUNT_LOGIN, ACCOUNT_TRADE_MODE, ACCOUNT_LEVERAGE, ACCOUNT_MARGIN_MODE, ACCOUNT_TRADE_ALLOWED, ACCOUNT_TRADE_EXPERT };
enum ENUM_ACCOUNT_INFO_STRING { ACCOUNT_CURRENCY, ACCOUNT_SERVER, ACCOUNT_NAME, ACCOUNT_COMPANY };
enum ENUM_ACCOUNT_TRADE_MODE { ACCOUNT_TRADE_MODE_DEMO = 0, ACCOUNT_TRADE_MODE_CONTEST = 1, ACCOUNT_TRADE_MODE_REAL = 2 };
enum ENUM_ACCOUNT_MARGIN_MODE { ACCOUNT_MARGIN_MODE_RETAIL_NETTING = 0, ACCOUNT_MARGIN_MODE_EXCHANGE = 1, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING = 2 };
enum ENUM_POSITION_PROPERTY_INTEGER { POSITION_TICKET, POSITION_TIME, POSITION_TIME_MSC, POSITION_TYPE, POSITION_MAGIC, POSITION_IDENTIFIER };
enum ENUM_POSITION_PROPERTY_DOUBLE { POSITION_VOLUME, POSITION_PRICE_OPEN, POSITION_SL, POSITION_TP, POSITION_PRICE_CURRENT, POSITION_SWAP, POSITION_PROFIT };
enum ENUM_POSITION_PROPERTY_STRING { POSITION_SYMBOL, POSITION_COMMENT };
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY = 0, POSITION_TYPE_SELL = 1 };
enum ENUM_DEAL_PROPERTY_INTEGER { DEAL_TICKET, DEAL_ORDER, DEAL_TIME, DEAL_TIME_MSC, DEAL_TYPE, DEAL_ENTRY, DEAL_MAGIC, DEAL_REASON, DEAL_POSITION_ID };
enum ENUM_DEAL_PROPERTY_DOUBLE { DEAL_VOLUME, DEAL_PRICE, DEAL_COMMISSION, DEAL_SWAP, DEAL_PROFIT, DEAL_FEE };
enum ENUM_DEAL_PROPERTY_STRING { DEAL_SYMBOL, DEAL_COMMENT };
enum ENUM_DEAL_TYPE { DEAL_TYPE_BUY = 0, DEAL_TYPE_SELL = 1, DEAL_TYPE_BALANCE = 2, DEAL_TYPE_CREDIT = 3, DEAL_TYPE_CHARGE = 4, DEAL_TYPE_CORRECTION = 5 };
enum ENUM_DEAL_ENTRY { DEAL_ENTRY_IN = 0, DEAL_ENTRY_OUT = 1, DEAL_ENTRY_INOUT = 2, DEAL_ENTRY_OUT_BY = 3 };
enum ENUM_DEAL_REASON { DEAL_REASON_CLIENT = 0, DEAL_REASON_MOBILE = 1, DEAL_REASON_WEB = 2, DEAL_REASON_EXPERT = 3, DEAL_REASON_SL = 4,
                        DEAL_REASON_TP = 5, DEAL_REASON_SO = 6 };
enum ENUM_MQL_INFO_INTEGER { MQL_TESTER, MQL_OPTIMIZATION, MQL_VISUAL_MODE, MQL_TRADE_ALLOWED };
enum ENUM_TERMINAL_INFO_INTEGER { TERMINAL_CONNECTED, TERMINAL_TRADE_ALLOWED };
const int FILE_READ = 1, FILE_WRITE = 2, FILE_BIN = 4, FILE_CSV = 8, FILE_TXT = 16, FILE_ANSI = 32, FILE_UNICODE = 64, FILE_SHARE_READ = 128,
          FILE_SHARE_WRITE = 256, FILE_REWRITE = 512, FILE_COMMON = 4096;
const uint CP_ACP = 0, CP_UTF8 = 65001;
const int INVALID_HANDLE = -1;
const int INIT_SUCCEEDED = 0, INIT_FAILED = 1, INIT_PARAMETERS_INCORRECT = 2;
const int REASON_PROGRAM = 0, REASON_REMOVE = 1, REASON_RECOMPILE = 2, REASON_CHARTCHANGE = 3, REASON_CHARTCLOSE = 4, REASON_PARAMETERS = 5,
          REASON_ACCOUNT = 6, REASON_TEMPLATE = 7, REASON_INITFAILED = 8, REASON_CLOSE = 9;
const int TIME_DATE = 1, TIME_MINUTES = 2, TIME_SECONDS = 4;

// ---------------------------------------------------------------- cau truc
struct MqlTick { datetime time; double bid; double ask; double last; ulong volume; long time_msc; uint flags; double volume_real; };
struct MqlRates { datetime time; double open; double high; double low; double close; long tick_volume; int spread; long real_volume; };
struct MqlDateTime { int year; int mon; int day; int hour; int min; int sec; int day_of_week; int day_of_year; };
struct MqlTradeRequest
{
   ENUM_TRADE_REQUEST_ACTIONS action; ulong magic; ulong order; string symbol; double volume; double price; double stoplimit;
   double sl; double tp; ulong deviation; ENUM_ORDER_TYPE type; ENUM_ORDER_TYPE_FILLING type_filling; ENUM_ORDER_TYPE_TIME type_time;
   datetime expiration; string comment; ulong position; ulong position_by;
};
struct MqlTradeResult { uint retcode; ulong deal; ulong order; double volume; double price; double bid; double ask; string comment; uint request_id; int retcode_external; };

// ---------------------------------------------------------------- toan hoc
inline double MathAbs(double x) { return std::fabs(x); }
inline double MathMax(double a, double b) { return a > b ? a : b; }
inline double MathMin(double a, double b) { return a < b ? a : b; }
inline double MathSqrt(double x) { return std::sqrt(x); }
inline double MathExp(double x) { return std::exp(x); }
inline double MathLog(double x) { return std::log(x); }
inline double MathPow(double a, double b) { return std::pow(a, b); }
inline double MathFloor(double x) { return std::floor(x); }
inline double MathCeil(double x) { return std::ceil(x); }
inline double MathRound(double x) { return std::round(x); }
inline bool MathIsValidNumber(double x) { return std::isfinite(x); }
inline double NormalizeDouble(double v, int d)
{
   double p = std::pow(10.0, d);
   return std::round(v * p) / p;
}

// ---------------------------------------------------------------- chuoi
inline string IntegerToString(long v, int len = 0, ushort fill = ' ')
{
   string s = std::to_string(v);
   while((int)s.size() < len) s = string(1, (char)fill) + s;
   return s;
}
inline string DoubleToString(double v, int digits = 8)
{
   if(!std::isfinite(v)) return std::isnan(v) ? "nan" : (v > 0 ? "inf" : "-inf");
   char b[64];
   snprintf(b, sizeof(b), "%.*f", digits < 0 ? 8 : digits, v);
   return b;
}
inline int StringLen(const string &s) { return (int)s.size(); }
inline string StringSubstr(const string &s, int start, int len = -1)
{
   if(start < 0 || start >= (int)s.size()) return "";
   if(len < 0) return s.substr((size_t)start);
   return s.substr((size_t)start, (size_t)len);
}
inline int StringFind(const string &s, const string &sub, int start = 0)
{
   size_t p = s.find(sub, (size_t)start);
   return p == string::npos ? -1 : (int)p;
}
inline int StringReplace(string &s, const string &f, const string &r)
{
   if(f.empty()) return 0;
   int n = 0;
   size_t p = 0;
   while((p = s.find(f, p)) != string::npos) { s.replace(p, f.size(), r); p += r.size(); n++; }
   return n;
}
inline int StringSplit(const string &s, ushort sep, DynArr<string> &out)
{
   out.v.clear();
   if(s.empty()) return 0;
   size_t st = 0;
   for(size_t i = 0; i <= s.size(); i++)
      if(i == s.size() || (unsigned char)s[i] == sep) { out.v.push_back(s.substr(st, i - st)); st = i + 1; }
   return (int)out.v.size();
}
inline long StringToInteger(const string &s) { return std::strtol(s.c_str(), nullptr, 10); }
inline double StringToDouble(const string &s) { return std::strtod(s.c_str(), nullptr); }

template <class T> inline typename std::enable_if<!std::is_same<T, string>::value, T>::type __fa(const T &v) { return v; }
inline const char *__fa(const string &s) { return s.c_str(); }
template <class... A> inline string StringFormat(const string &fmt, A... a)
{
   string f = fmt;
   StringReplace(f, "%I64d", "%lld");
   StringReplace(f, "%I64u", "%llu");
   int n = snprintf(nullptr, 0, f.c_str(), __fa(a)...);
   if(n < 0) return "";
   std::vector<char> b((size_t)n + 1);
   snprintf(b.data(), b.size(), f.c_str(), __fa(a)...);
   return string(b.data(), (size_t)n);
}

inline string __to_s(const string &s) { return s; }
inline string __to_s(const char *s) { return s; }
inline string __to_s(bool b) { return b ? "true" : "false"; }
inline string __to_s(double d) { return DoubleToString(d, 8); }
template <class T> inline typename std::enable_if<std::is_integral<T>::value || std::is_enum<T>::value, string>::type __to_s(T v)
{
   return std::to_string((long long)v);
}
void __emit_print(const string &s);
template <class... A> inline void Print(A... a)
{
   string s;
   using expand = int[];
   (void)expand{0, (s += __to_s(a), 0)...};
   __emit_print(s);
}

// ---------------------------------------------------------------- thoi gian
inline bool TimeToStruct(datetime t, MqlDateTime &d)
{
   time_t tt = (time_t)t;
   struct tm g;
   gmtime_r(&tt, &g);
   d.year = g.tm_year + 1900; d.mon = g.tm_mon + 1; d.day = g.tm_mday; d.hour = g.tm_hour; d.min = g.tm_min; d.sec = g.tm_sec;
   d.day_of_week = g.tm_wday; d.day_of_year = g.tm_yday;
   return true;
}
inline datetime StructToTime(MqlDateTime &d)
{
   struct tm g;
   memset(&g, 0, sizeof(g));
   g.tm_year = d.year - 1900; g.tm_mon = d.mon - 1; g.tm_mday = d.day; g.tm_hour = d.hour; g.tm_min = d.min; g.tm_sec = d.sec;
   return (datetime)timegm(&g);
}
inline string TimeToString(datetime t, int mode = TIME_DATE | TIME_MINUTES)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   char b[64];
   string s;
   if(mode & TIME_DATE) { snprintf(b, sizeof(b), "%04d.%02d.%02d", d.year, d.mon, d.day); s = b; }
   if(mode & TIME_SECONDS) { snprintf(b, sizeof(b), "%s%02d:%02d:%02d", s.empty() ? "" : " ", d.hour, d.min, d.sec); s += b; }
   else if(mode & TIME_MINUTES) { snprintf(b, sizeof(b), "%s%02d:%02d", s.empty() ? "" : " ", d.hour, d.min); s += b; }
   return s;
}
int PeriodSeconds(ENUM_TIMEFRAMES p = PERIOD_CURRENT);

// ---------------------------------------------------------------- API do bo gia lap cung cap
extern string _Symbol;
extern double _Point;
extern int _Digits;
datetime TimeCurrent();
ulong GetTickCount64();
int GetLastError();
void ResetLastError();
int MQLInfoInteger(ENUM_MQL_INFO_INTEGER p);
int TerminalInfoInteger(ENUM_TERMINAL_INFO_INTEGER p);
double AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE p);
long AccountInfoInteger(ENUM_ACCOUNT_INFO_INTEGER p);
string AccountInfoString(ENUM_ACCOUNT_INFO_STRING p);
bool SymbolInfoTick(const string &sym, MqlTick &t);
double SymbolInfoDouble(const string &sym, ENUM_SYMBOL_INFO_DOUBLE p);
long SymbolInfoInteger(const string &sym, ENUM_SYMBOL_INFO_INTEGER p);
bool OrderCalcProfit(ENUM_ORDER_TYPE t, const string &sym, double vol, double open, double close, double &profit);
bool OrderCalcMargin(ENUM_ORDER_TYPE t, const string &sym, double vol, double price, double &margin);
bool OrderSend(MqlTradeRequest &rq, MqlTradeResult &rs);
int PositionsTotal();
ulong PositionGetTicket(int i);
bool PositionSelectByTicket(ulong t);
long PositionGetInteger(ENUM_POSITION_PROPERTY_INTEGER p);
double PositionGetDouble(ENUM_POSITION_PROPERTY_DOUBLE p);
string PositionGetString(ENUM_POSITION_PROPERTY_STRING p);
bool HistorySelect(datetime from, datetime to);
bool HistorySelectByPosition(long id);
bool HistoryDealSelect(ulong t);
int HistoryDealsTotal();
ulong HistoryDealGetTicket(int i);
long HistoryDealGetInteger(ulong t, ENUM_DEAL_PROPERTY_INTEGER p);
double HistoryDealGetDouble(ulong t, ENUM_DEAL_PROPERTY_DOUBLE p);
string HistoryDealGetString(ulong t, ENUM_DEAL_PROPERTY_STRING p);
int CopyRates(const string &sym, ENUM_TIMEFRAMES tf, int start, int count, DynArr<MqlRates> &r);
int CopyRates(const string &sym, ENUM_TIMEFRAMES tf, datetime from, datetime to, DynArr<MqlRates> &r);
datetime GlobalVariableSet(const string &n, double v);
double GlobalVariableGet(const string &n);
bool GlobalVariableCheck(const string &n);
bool GlobalVariableDel(const string &n);
void GlobalVariablesFlush();
int FileOpen(const string &name, int flags, int delim = '\t', uint cp = 0);
void FileClose(int h);
void FileFlush(int h);
ulong FileSize(int h);
bool FileSeek(int h, long off, int origin);
uint FileWriteString(int h, const string &s, int len = -1);
string FileReadString(int h, int len = -1);
bool FileIsEnding(int h);
bool FileIsExist(const string &name, int common = 0);
bool FolderCreate(const string &name, int common = 0);
void Comment(const string &s);
bool EventSetTimer(int sec);
void EventKillTimer();
void ExpertRemove();

// Ham xu ly su kien cua EA
int OnInit();
void OnDeinit(const int reason);
void OnTick();
__attribute__((weak)) void OnTimer();
__attribute__((weak)) double OnTester();
void __apply_input(const std::string &k, const std::string &v);
extern const char *__input_names[];
