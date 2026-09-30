"""Kiểm tra tĩnh file MQL5 của Phoenix Grid. KHÔNG thay được compile bằng MetaEditor.

Kiểm tra:
- ngoặc (), [], {} cân bằng (bỏ qua chuỗi, ký tự màu C'..', chú thích); chuỗi hằng không bị cắt ngang dòng
- mọi lời gọi hàm có định nghĩa trong file hoặc thuộc danh sách hàm MQL5 đã biết (BUILTIN); không có hàm trùng
- từ khóa giao dịch (danh sách CAM): bản EA quan sát phải là "không có"; bản giao dịch (V0.20+) có là đúng
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
iMA iBands OrderSend ZeroMemory GetMicrosecondCount HistorySelectByPosition HistoryDealSelect PositionSelectByTicket
PositionGetDouble OrderGetTicket OrderGetInteger GlobalVariableDel GlobalVariablesDeleteAll GlobalVariablesFlush
CalendarValueHistory CalendarEventById SendNotification MathLog10 OnTradeTransaction StringTrimRight StringTrimLeft
HistoryOrdersTotal HistoryOrderGetTicket HistoryOrderGetInteger HistoryOrderGetDouble HistoryOrderGetString
StringGetCharacter ShortToString OnStart
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


KIEU_BIEN = set("""bool char uchar short ushort int uint long ulong float double string datetime color void
MqlTick MqlTradeRequest MqlTradeResult MqlTradeCheckResult MqlRates MqlDateTime MqlCalendarValue MqlCalendarEvent
MqlCalendarCountry MqlBookInfo""".split())
TU_KHOA = set("""if for while switch return sizeof else do case default break continue const static input sinput
true false NULL new delete this class struct enum public private protected virtual template typename operator
extern group""".split())
TEN_MQL5 = set("""_Symbol _Point _Digits _Period _LastError _StopFlag _UninitReason""".split())


def la_kieu(t):
    return t in KIEU_BIEN or re.match(r"^(ENUM_\w+|PG_[A-Z_]+|PMI_[A-Z_]+|C[A-Z]\w*)$", t) is not None


def ten_khai_bao(cau):
    """Tên các biến khai báo trong một câu 'const static TYPE a = .., b[3], c;' (rỗng nếu không phải khai báo)."""
    t = cau.strip()
    t = re.sub(r"^(?:(?:const|static|input|sinput)\s+)+", "", t)
    m = re.match(r"^([A-Za-z_]\w*)\s+(.*)$", t, re.S)
    if not m or not la_kieu(m.group(1)):
        return []
    phan, sau, sau_bang = [], m.group(2), 0
    # tách theo dấu phẩy ở mức ngoặc 0
    muc, cur = 0, ""
    for ch in sau:
        if ch in "([{":
            muc += 1
        elif ch in ")]}":
            muc -= 1
        if ch == "," and muc == 0:
            phan.append(cur)
            cur = ""
        else:
            cur += ch
    phan.append(cur)
    ten = []
    for x in phan:
        mm = re.match(r"^\s*&?\s*([A-Za-z_]\w*)", x)
        if mm:
            ten.append(mm.group(1))
    return ten


def cac_ham(s):
    """(tên, tham số, thân) của mọi hàm định nghĩa ở mức ngoài cùng."""
    out = []
    kieu = r"(?:void|bool|int|uint|long|ulong|double|string|color|datetime|ENUM_\w+|PMI_\w+|PG_\w+)"
    for m in re.finditer(r"^[ \t]*" + kieu + r"[ \t]+([A-Za-z_]\w*)[ \t]*\(", s, re.M):
        i = m.end() - 1
        muc, j = 0, i
        while j < len(s):
            if s[j] == "(":
                muc += 1
            elif s[j] == ")":
                muc -= 1
                if muc == 0:
                    break
            j += 1
        k = j + 1
        while k < len(s) and s[k] in " \t\r\n":
            k += 1
        if k >= len(s) or s[k] != "{":
            continue                                   # khai báo trước, không có thân
        muc, e = 0, k
        while e < len(s):
            if s[e] == "{":
                muc += 1
            elif s[e] == "}":
                muc -= 1
                if muc == 0:
                    break
            e += 1
        out.append((m.group(1), s[i + 1:j], s[k + 1:e], s.count("\n", 0, k) + 1))
    return out


def kiem_bien(s):
    """Định danh dùng trong thân hàm mà không có khai báo nào nhìn thấy được (theo hàm, không xét phạm vi khối)."""
    ham = cac_ham(s)
    ten_ham = {h[0] for h in ham}
    # khai báo mức ngoài cùng: bỏ thân hàm và thân class / struct / enum
    ngoai, muc = [], 0
    for ch in s:
        if ch == "{":
            muc += 1
            ngoai.append(";")
        elif ch == "}":
            muc -= 1
            ngoai.append(";")
        elif muc == 0:
            ngoai.append(ch)
    toan_cuc = set()
    for cau in re.split(r"[;\n]", "".join(ngoai)):
        c = re.sub(r"^\s*input\s+group\b.*$", "", cau)
        toan_cuc.update(ten_khai_bao(c))
    # thành viên của class / struct (thân class là các khai báo)
    for m in re.finditer(r"\b(?:class|struct)\s+\w+[^{;]*\{", s):
        muc, e = 0, m.end() - 1
        while e < len(s):
            if s[e] == "{":
                muc += 1
            elif s[e] == "}":
                muc -= 1
                if muc == 0:
                    break
            e += 1
        than = s[m.end():e]
        for cau in re.split(r"[;{}]", than):
            toan_cuc.update(ten_khai_bao(re.sub(r"^\s*(?:public|private|protected)\s*:", "", cau)))
    loi = []
    for ten, ts, than, dong in ham:
        cuc_bo = set()
        for x in ts.split(","):
            x = re.sub(r"=.*$", "", x, flags=re.S)
            mm = re.findall(r"[A-Za-z_]\w*", x.replace("[]", ""))
            if mm:
                cuc_bo.add(mm[-1])
        for cau in re.split(r"[;{}]", than):
            cau2 = re.sub(r"^\s*(?:for|while|if|switch)\s*\(", "", cau)
            cuc_bo.update(ten_khai_bao(cau2))
            cuc_bo.update(ten_khai_bao(cau))
        # biến khai báo trong for(...) ở bất kỳ đâu (kể cả sau if / else trên cùng câu)
        for kt, tb in re.findall(r"\bfor\s*\(\s*(?:const\s+)?([A-Za-z_]\w*)\s+([A-Za-z_]\w*)", than):
            if la_kieu(kt):
                cuc_bo.add(tb)
        # tên lớp của hàm thành viên C::f: thành viên lớp đã ở toan_cuc
        for m in re.finditer(r"(?<![.\w])([A-Za-z_]\w*)\b(?!\s*\()", than):
            w = m.group(1)
            if (w in cuc_bo or w in toan_cuc or w in ten_ham or w in TU_KHOA or la_kieu(w) or w in TEN_MQL5
                    or w.isupper() or re.match(r"^[A-Z0-9_]+$", w) or w.startswith("clr")):
                continue
            # thành viên struct sau dấu '.' đã loại bởi (?<![.\w]); tên sau '::' là thành viên lớp
            loi.append(f"{ten} (dòng {dong}): {w}")
    return sorted(set(loi))


def tach_tham_so(x):
    """Tách danh sách tham số / đối số theo dấu phẩy ở mức ngoặc 0 (bỏ phần tử rỗng)."""
    phan, muc, cur = [], 0, ""
    for ch in x:
        if ch in "([{":
            muc += 1
        elif ch in ")]}":
            muc -= 1
        if ch == "," and muc == 0:
            phan.append(cur)
            cur = ""
        else:
            cur += ch
    phan.append(cur)
    return [p for p in (q.strip() for q in phan) if p]


def kiem_so_tham_so(s):
    """Mỗi lời gọi hàm tự định nghĩa phải có số đối số nằm giữa (số tham số không có mặc định) và (tổng số tham số)."""
    ham = {}
    for ten, ts, _than, _dong in cac_ham(s):
        ps = tach_tham_so(ts)
        ham.setdefault(ten, []).append((sum(1 for p in ps if "=" not in p), len(ps)))
    loi = []
    for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", s):
        ten = m.group(1)
        if ten not in ham:
            continue
        # bỏ chính dòng định nghĩa hàm (có kiểu trả về đứng trước)
        dau = s.rfind("\n", 0, m.start()) + 1
        if re.match(r"^\s*(?:void|bool|int|uint|long|ulong|double|string|color|datetime|ENUM_\w+|PMI_\w+|PG_\w+)\s+$",
                    s[dau:m.start()]):
            continue
        i, muc = m.end() - 1, 0
        j = i
        while j < len(s):
            if s[j] == "(":
                muc += 1
            elif s[j] == ")":
                muc -= 1
                if muc == 0:
                    break
            j += 1
        n = len(tach_tham_so(s[i + 1:j]))
        if not any(lo <= n <= hi for lo, hi in ham[ten]):
            loi.append(f"{ten} (dòng {s.count(chr(10), 0, m.start()) + 1}): {n} đối số, cần {ham[ten]}")
    return loi


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
    kieu = r"(?:void|bool|int|double|string|color|datetime|long|uint|ulong|ENUM_\w+|PMI_\w+|PG_\w+)"
    defs = set(re.findall(r"^\s*" + kieu + r"\s+(\w+)\s*\(", s, re.M))
    defs |= set(re.findall(r"\bclass\s+(\w+)", s))            # constructor trùng tên lớp
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
    allf = re.findall(r"^\s*" + kieu + r"\s+(\w+)\s*\(", s, re.M)
    dup = sorted({f for f in allf if allf.count(f) > 1})
    print("Hàm định nghĩa trùng:", dup or "không có")
    # biến toàn cục g_ khai báo và dùng
    decl = set(re.findall(r"\b(g_\w+)\s*(?:=|\[|,|;)", s))
    used_g = set(re.findall(r"\b(g_\w+)\b", s))
    print("Biến g_ dùng mà không thấy khai báo:", sorted(used_g - decl) or "không có")
    # biến cục bộ / tham số: mỗi định danh trong thân hàm phải là tham số, biến khai báo trong hàm, biến toàn cục,
    # input, hàm, hằng / enum (viết hoa) hoặc tên MQL5 đã biết. Bắt lỗi gõ sai tên biến mà MetaEditor mới báo.
    thieu = kiem_bien(s)
    print("Biến dùng mà không thấy khai báo (theo hàm):", thieu or "không có")
    sai = kiem_so_tham_so(s)
    print("Lời gọi sai số tham số:", sai or "không có")
    inputs = re.findall(r"^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);\s*//\s*(.*)$", src, re.M)
    print("Số input:", len(inputs))
    for t, name, val, label in inputs:
        if not label.strip():
            print("  input thiếu nhãn:", name)


if __name__ == "__main__":
    main(sys.argv[1])
