"""Kiểm tra tĩnh file MQL5 của Phoenix Grid. KHÔNG thay được compile bằng MetaEditor.

Kiểm tra:
- ngoặc (), [], {} cân bằng (bỏ qua chuỗi, ký tự màu C'..', chú thích); chuỗi hằng không bị cắt ngang dòng
- mọi lời gọi hàm có định nghĩa trong file hoặc thuộc danh sách hàm MQL5 đã biết (BUILTIN); không có hàm trùng
- không có từ khóa giao dịch (danh sách CAM) - dùng cho các bản EA quan sát
- mọi input có nhãn (chú thích //)

Chạy:  python3 kiem_tra_tinh_mq5.py ../../../MQL5/Experts/PhoenixGrid/<EA>.mq5
"""
import re
import sys

BUILTIN = set("""
OnInit OnDeinit OnTick OnTimer OnChartEvent
SymbolInfoDouble SymbolInfoInteger SymbolInfoString SymbolInfoTick SymbolInfoSessionTrade
Print PrintFormat iATR iADX iTime iClose IndicatorRelease CopyBuffer CopyRates CopyTicksRange BarsCalculated Bars
ArrayInitialize ArrayResize ArraySort FolderCreate ResetLastError GetLastError EventSetTimer EventKillTimer
ObjectsDeleteAll ResourceFree ResourceCreate ChartSetInteger ChartSetDouble ChartGetInteger ChartGetDouble ChartRedraw
TimeLocal TimeCurrent TimeTradeServer TimeToStruct TimeToString StringFormat
ObjectSetInteger ObjectSetString ObjectSetDouble ObjectGetInteger ObjectGetString ObjectFind ObjectCreate ObjectDelete ObjectMove
MathMax MathMin MathAbs MathRound
AccountInfoInteger AccountInfoDouble AccountInfoString IntegerToString DoubleToString
GlobalVariableCheck GlobalVariableGet GlobalVariableSet
OrderCalcMargin PositionsTotal PositionGetTicket PositionGetInteger PositionGetString
FileOpen FileClose FileSize FileWrite FileSeek FileFlush
MQLInfoInteger TerminalInfoInteger PeriodSeconds
EnumToString HistorySelect HistoryDealsTotal HistoryDealGetTicket HistoryDealGetDouble HistoryDealGetInteger
HistoryDealGetString MathCeil MathFloor MathSqrt MathPow MathLog MathExp OrderCalcProfit OrdersTotal StringReplace
StringLen StringSubstr StringFind StringSplit StringToDouble StringToInteger StringToTime SymbolInfoMarginRate
SymbolInfoSessionQuote SymbolSelect TerminalInfoString MQLInfoString TimeGMT NormalizeDouble ArraySize
ArraySetAsSeries ArrayCopy ArrayFill CopyTicks CopyTime CopyClose CopyHigh CopyLow iHigh iLow iOpen iBars
FileWriteString FileReadString FileIsEnding Comment Alert GetTickCount Sleep ObjectsTotal ObjectName
ObjectGetDouble ColorToARGB
C
""".split())
KEYWORDS = set("if for while switch return sizeof else do case".split())
CAM = ["OrderSend", "OrderSendAsync", "CTrade", "PositionClose", "OrderModify", "PositionModify", "Trade.mqh",
       "OrderCloseBy", "PositionCloseBy", "TRADE_ACTION"]


def strip(src):
    out, i, n = [], 0, len(src)
    line = 1
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif src.startswith("/*", i):
            j = src.find("*/", i) + 2
            out.append(re.sub(r"[^\n]", " ", src[i:j]))
            i = j
        elif c == '"':
            j = i + 1
            while src[j] != '"':
                if src[j] == "\\":
                    j += 1
                if src[j] == "\n":
                    raise SystemExit(f"chuỗi bị cắt ngang dòng ở dòng {src.count(chr(10), 0, i) + 1}")
                j += 1
            out.append('"' + " " * (j - i - 1) + '"')
            i = j + 1
        elif c == "'":
            j = src.find("'", i + 1)
            out.append("'" + " " * (j - i - 1) + "'")
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def main(path):
    raw = open(path, "rb").read()
    print("BOM:", raw.startswith(b"\xef\xbb\xbf"), "| CRLF:", b"\r\n" in raw)
    src = raw.decode("utf-8-sig")
    s = strip(src)
    # ngoặc
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for k, ch in enumerate(s):
        if ch in "([{":
            stack.append((ch, k))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                raise SystemExit(f"ngoặc lệch ở dòng {s.count(chr(10), 0, k) + 1}")
            stack.pop()
    if stack:
        raise SystemExit(f"ngoặc chưa đóng ở dòng {s.count(chr(10), 0, stack[-1][1]) + 1}")
    print("Ngoặc: cân bằng")
    # định nghĩa hàm
    defs = set(re.findall(r"^\s*(?:void|bool|int|double|string|color|datetime|long|uint|ulong)\s+(\w+)\s*\(", s, re.M))
    calls = set(re.findall(r"\b([A-Za-z_]\w*)\s*\(", s))
    unknown = sorted(c for c in calls - defs - BUILTIN - KEYWORDS if not c.isupper())
    print("Số hàm tự định nghĩa:", len(defs))
    print("Lời gọi chưa rõ nguồn:", unknown or "không có")
    # hàm định nghĩa nhưng không dùng
    used = {c for c in re.findall(r"\b([A-Za-z_]\w*)\b", s)}
    counts = {d: len(re.findall(r"\b" + d + r"\b", s)) for d in defs}
    unused = sorted(d for d, c in counts.items() if c <= 1 and not d.startswith("On"))
    print("Hàm định nghĩa nhưng không gọi:", unused or "không có")
    # lệnh giao dịch
    # chỉ xét phần mã (đã bỏ chú thích và chuỗi) và các dòng #include
    includes = "\n".join(l for l in s.splitlines() if l.lstrip().startswith("#include"))
    hits = [w for w in CAM if re.search(r"\b" + re.escape(w) + r"\b", s) or w in includes]
    print("Từ khóa giao dịch trong mã:", hits or "không có")
    # định nghĩa trùng
    allf = re.findall(r"^\s*(?:void|bool|int|double|string|color|datetime|long|uint|ulong)\s+(\w+)\s*\(", s, re.M)
    dup = sorted({f for f in allf if allf.count(f) > 1})
    print("Hàm định nghĩa trùng:", dup or "không có")
    # biến toàn cục g_ khai báo và dùng
    decl = set(re.findall(r"\b(g_\w+)\s*(?:=|\[|,|;)", s))
    used_g = set(re.findall(r"\b(g_\w+)\b", s))
    print("Biến g_ dùng mà không thấy khai báo:", sorted(used_g - decl) or "không có")
    inputs = re.findall(r"^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);\s*//\s*(.*)$", src, re.M)
    print("Số input:", len(inputs))
    for t, name, val, label in inputs:
        if not label.strip():
            print("  input thiếu nhãn:", name)


if __name__ == "__main__":
    main(sys.argv[1])
