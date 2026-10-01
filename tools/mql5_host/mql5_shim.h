// mql5_shim.h — giả lập NGÔN NGỮ/RUNTIME MQL5 tối thiểu để chạy logic IDHG trên host.
// KHÔNG phải MQL5 thật. Chỉ phục vụ self-test khi không có MetaEditor.
#ifndef MQL5_SHIM_H
#define MQL5_SHIM_H

#include <algorithm>
#include <cfloat>
#include <climits>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <map>
#include <string>
#include <type_traits>
#include <vector>

typedef std::string string;
typedef long datetime;
typedef unsigned long ulong;
typedef unsigned int uint;
typedef unsigned char uchar;
typedef unsigned short ushort;
typedef int color;

#define EMPTY_VALUE DBL_MAX
#define WRONG_VALUE (-1)
#define INVALID_HANDLE (-1)
#define CHARTS_MAX 100

// ---------------------------------------------------------------- arrays
// Mảng động MQL5: truy cập ngoài phạm vi = lỗi nghiêm trọng (MQL5 dừng chương trình).
template <typename T>
struct MqlArray {
    std::vector<T> v;
    T &operator[](long i) {
        if (i < 0 || i >= (long)v.size()) {
            fprintf(stderr, "CRITICAL: array out of range (%ld / %zu)\n", i, v.size());
            abort();
        }
        return v[(size_t)i];
    }
    const T &operator[](long i) const {
        if (i < 0 || i >= (long)v.size()) {
            fprintf(stderr, "CRITICAL: array out of range (%ld / %zu)\n", i, v.size());
            abort();
        }
        return v[(size_t)i];
    }
};
template <typename T> int ArrayResize(MqlArray<T> &a, int n, int reserve = 0) {
    (void)reserve;
    if (n < 0) return -1;
    a.v.resize((size_t)n);
    return n;
}
template <typename T> int ArraySize(const MqlArray<T> &a) { return (int)a.v.size(); }
template <typename T> void ArrayFree(MqlArray<T> &a) { a.v.clear(); }
template <typename T, typename V> void ArrayInitialize(MqlArray<T> &a, V val) {
    for (auto &x : a.v) x = (T)val;
}
template <typename T> bool ArraySort(MqlArray<T> &a) { std::sort(a.v.begin(), a.v.end()); return true; }
template <typename T> void ZeroMemory(T &x) { x = T(); }

// ---------------------------------------------------------------- math
inline double MathAbs(double x) { return std::fabs(x); }
template <typename A, typename B> inline typename std::common_type<A, B>::type MathMax(A a, B b) { return a > b ? a : b; }
template <typename A, typename B> inline typename std::common_type<A, B>::type MathMin(A a, B b) { return a < b ? a : b; }
inline double MathPow(double a, double b) { return std::pow(a, b); }
inline double MathRound(double x) { return std::round(x); }
inline double MathFloor(double x) { return std::floor(x); }
inline double MathCeil(double x) { return std::ceil(x); }
inline double MathSqrt(double x) { return std::sqrt(x); }
inline double MathLog(double x) { return std::log(x); }
inline bool MathIsValidNumber(double x) { return std::isfinite(x); }
inline double NormalizeDouble(double v, int digits) {
    double p = std::pow(10.0, digits);
    return std::round(v * p) / p;
}

// ---------------------------------------------------------------- strings
inline int StringLen(const string &s) { return (int)s.size(); }
inline string StringSubstr(const string &s, int start, int len = -1) {
    if (start < 0 || start >= (int)s.size()) return "";
    if (len < 0) return s.substr((size_t)start);
    return s.substr((size_t)start, (size_t)len);
}
inline int StringFind(const string &s, const string &sub, int start = 0) {
    size_t p = s.find(sub, (size_t)std::max(0, start));
    return p == string::npos ? -1 : (int)p;
}
inline int StringSplit(const string &s, ushort sep, MqlArray<string> &out) {
    out.v.clear();
    string cur;
    for (char c : s) {
        if ((ushort)(unsigned char)c == sep) { out.v.push_back(cur); cur.clear(); }
        else cur += c;
    }
    out.v.push_back(cur);
    return (int)out.v.size();
}
inline ushort StringGetCharacter(const string &s, int pos) { return (pos >= 0 && pos < (int)s.size()) ? (ushort)(unsigned char)s[(size_t)pos] : 0; }
inline long StringToInteger(const string &s) { return std::strtol(s.c_str(), nullptr, 10); }
inline double StringToDouble(const string &s) { return std::strtod(s.c_str(), nullptr); }
inline string IntegerToString(long v, int width = 0, ushort fill = ' ') {
    string s = std::to_string(v);
    while ((int)s.size() < width) s = string(1, (char)fill) + s;
    return s;
}
inline string DoubleToString(double v, int digits = 8) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%.*f", digits, v);
    return buf;
}
inline bool StringToUpper(string &s) { for (auto &c : s) c = (char)toupper((unsigned char)c); return true; }
inline bool StringToLower(string &s) { for (auto &c : s) c = (char)tolower((unsigned char)c); return true; }
inline int StringReplace(string &s, const string &f, const string &r) {
    if (f.empty()) return 0;
    int n = 0;
    size_t p = 0;
    while ((p = s.find(f, p)) != string::npos) { s.replace(p, f.size(), r); p += r.size(); ++n; }
    return n;
}
inline int StringTrimLeft(string &s) { size_t p = s.find_first_not_of(" \t\r\n"); int n = (int)(p == string::npos ? s.size() : p); s.erase(0, (size_t)n); return n; }
inline int StringTrimRight(string &s) { size_t p = s.find_last_not_of(" \t\r\n"); int n = (int)(p == string::npos ? s.size() : s.size() - p - 1); s.erase(s.size() - (size_t)n); return n; }

// StringFormat có kiểm tra kiểu đối số theo định dạng (bắt lỗi %d với double ...)
namespace shimfmt {
enum Kind { K_INT, K_LONG, K_DBL, K_STR };
struct Arg { Kind k; long long i; double d; string s; };
inline Arg mk(int v) { return {K_INT, v, 0, ""}; }
inline Arg mk(uint v) { return {K_INT, (long long)v, 0, ""}; }
inline Arg mk(bool v) { return {K_INT, v ? 1 : 0, 0, ""}; }
inline Arg mk(long v) { return {K_LONG, v, 0, ""}; }
inline Arg mk(ulong v) { return {K_LONG, (long long)v, 0, ""}; }
inline Arg mk(double v) { return {K_DBL, 0, v, ""}; }
inline Arg mk(const string &v) { return {K_STR, 0, 0, v}; }
inline Arg mk(const char *v) { return {K_STR, 0, 0, v}; }
template <typename E, typename = typename std::enable_if<std::is_enum<E>::value>::type>
inline Arg mk(E v) { return {K_INT, (long long)v, 0, ""}; }
inline string format(const string &f, const std::vector<Arg> &a) {
    string out;
    size_t ai = 0;
    for (size_t i = 0; i < f.size(); ++i) {
        if (f[i] != '%') { out += f[i]; continue; }
        if (i + 1 < f.size() && f[i + 1] == '%') { out += '%'; ++i; continue; }
        size_t j = i + 1;
        while (j < f.size() && strchr("-+ #0123456789.", f[j])) ++j;
        string mods;
        while (j < f.size() && strchr("lhI6", f[j])) { mods += f[j]; ++j; }
        if (j >= f.size()) { fprintf(stderr, "CRITICAL: bad format '%s'\n", f.c_str()); abort(); }
        char conv = f[j];
        string spec = f.substr(i, j - i - mods.size());
        if (ai >= a.size()) { fprintf(stderr, "CRITICAL: StringFormat thiếu đối số: '%s'\n", f.c_str()); abort(); }
        const Arg &x = a[ai++];
        char buf[512];
        if (conv == 'd' || conv == 'i' || conv == 'u' || conv == 'x' || conv == 'X') {
            if (x.k == K_DBL || x.k == K_STR) { fprintf(stderr, "CRITICAL: %%%c với đối số không phải số nguyên: '%s'\n", conv, f.c_str()); abort(); }
            if (x.k == K_LONG && mods.empty()) { fprintf(stderr, "CRITICAL: %%%c với long (cần IntegerToString): '%s'\n", conv, f.c_str()); abort(); }
            snprintf(buf, sizeof(buf), (spec + "ll" + conv).c_str(), x.i);
        } else if (conv == 'f' || conv == 'g' || conv == 'e' || conv == 'G' || conv == 'E') {
            if (x.k != K_DBL) { fprintf(stderr, "CRITICAL: %%%c với đối số không phải double: '%s'\n", conv, f.c_str()); abort(); }
            snprintf(buf, sizeof(buf), (spec + conv).c_str(), x.d);
        } else if (conv == 's') {
            if (x.k != K_STR) { fprintf(stderr, "CRITICAL: %%s với đối số không phải string: '%s'\n", f.c_str()); abort(); }
            snprintf(buf, sizeof(buf), (spec + "s").c_str(), x.s.c_str());
        } else { fprintf(stderr, "CRITICAL: định dạng không hỗ trợ %%%c\n", conv); abort(); }
        out += buf;
        i = j;
    }
    if (ai != a.size()) { fprintf(stderr, "CRITICAL: StringFormat thừa đối số: '%s'\n", f.c_str()); abort(); }
    return out;
}
inline string tostr(const string &s) { return s; }
inline string tostr(const char *s) { return s; }
inline string tostr(int v) { return std::to_string(v); }
inline string tostr(uint v) { return std::to_string(v); }
inline string tostr(long v) { return std::to_string(v); }
inline string tostr(ulong v) { return std::to_string(v); }
inline string tostr(bool v) { return v ? "true" : "false"; }
inline string tostr(double v) { char b[64]; snprintf(b, sizeof(b), "%.8g", v); return b; }
template <typename E, typename = typename std::enable_if<std::is_enum<E>::value>::type>
inline string tostr(E v) { return std::to_string((long)v); }
}  // namespace shimfmt

template <typename... A> string StringFormat(const string &f, A... a) {
    std::vector<shimfmt::Arg> v{shimfmt::mk(a)...};
    return shimfmt::format(f, v);
}

extern bool g_shim_quiet;
extern std::vector<string> g_shim_log;
inline void shim_emit(const string &s) {
    g_shim_log.push_back(s);
    if (!g_shim_quiet) printf("%s\n", s.c_str());
}
template <typename... A> void PrintFormat(const string &f, A... a) { shim_emit(StringFormat(f, a...)); }
template <typename... A> void Print(A... a) {
    string s;
    using expand = int[];
    (void)expand{0, (s += shimfmt::tostr(a), 0)...};
    shim_emit(s);
}

// ---------------------------------------------------------------- time
struct MqlDateTime { int year, mon, day, hour, min, sec, day_of_week, day_of_year; };
inline bool TimeToStruct(datetime t, MqlDateTime &s) {
    time_t tt = (time_t)t;
    struct tm g;
    gmtime_r(&tt, &g);
    s.year = g.tm_year + 1900; s.mon = g.tm_mon + 1; s.day = g.tm_mday;
    s.hour = g.tm_hour; s.min = g.tm_min; s.sec = g.tm_sec;
    s.day_of_week = g.tm_wday; s.day_of_year = g.tm_yday;
    return true;
}
inline datetime StructToTime(MqlDateTime &s) {
    struct tm g = {};
    g.tm_year = s.year - 1900; g.tm_mon = s.mon - 1; g.tm_mday = s.day;
    g.tm_hour = s.hour; g.tm_min = s.min; g.tm_sec = s.sec;
    return (datetime)timegm(&g);
}
#define TIME_DATE 1
#define TIME_MINUTES 2
#define TIME_SECONDS 4
inline string TimeToString(datetime t, int flags = TIME_DATE | TIME_MINUTES) {
    MqlDateTime s;
    TimeToStruct(t, s);
    char b[64] = "";
    string r;
    if (flags & TIME_DATE) { snprintf(b, sizeof(b), "%04d.%02d.%02d", s.year, s.mon, s.day); r += b; }
    if (flags & (TIME_MINUTES | TIME_SECONDS)) {
        if (!r.empty()) r += " ";
        if (flags & TIME_SECONDS) snprintf(b, sizeof(b), "%02d:%02d:%02d", s.hour, s.min, s.sec);
        else snprintf(b, sizeof(b), "%02d:%02d", s.hour, s.min);
        r += b;
    }
    return r;
}

// colors (giá trị tuỳ ý — chỉ cần biên dịch)
#define clrNONE (-1)
#define clrWhite 0xFFFFFF
#define clrBlack 0x000000
#define clrRed 0x0000FF
#define clrLime 0x00FF00
#define clrGreen 0x008000
#define clrYellow 0x00FFFF
#define clrOrange 0x00A5FF
#define clrGold 0x00D7FF
#define clrSilver 0xC0C0C0
#define clrGray 0x808080
#define clrDimGray 0x696969
#define clrDarkSlateGray 0x4F4F2F
#define clrMidnightBlue 0x701919
#define clrDodgerBlue 0xFF901E
#define clrTomato 0x4763FF
#define clrLightGray 0xD3D3D3
#define clrDarkGreen 0x006400
#define clrMaroon 0x000080
#define clrNavy 0x800000
#define clrSteelBlue 0xB48246
#define clrCrimson 0x3C14DC
#define clrTeal 0x808000
#define clrSlateGray 0x908070
#define clrAqua 0xFFFF00
#define clrDarkOrange 0x008CFF
#define clrFireBrick 0x2222B2
#define clrSeaGreen 0x578B2E

#endif
