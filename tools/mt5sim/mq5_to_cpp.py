"""Dich mot EA MQL5 (tap con ma EA David Hunter V5 dung) sang C++ de kiem tra cu phap/kieu bang g++
va chay trong bo gia lap mt5sim.

Khong phai trinh bien dich MQL5: chi xu ly cac cu phap rieng cua MQL5 ma EA dung:
  - #property, input group            -> bo
  - input/sinput TYPE NAME = VALUE;   -> bien toan cuc + ham __apply_input() de nap SET
  - TYPE name[];  TYPE &name[]        -> DynArr<TYPE> (co kiem tra tran chi so)
  - TYPE name[N];                     -> StatArr<TYPE, N> (co kiem tra tran chi so)
Moi khac biet ngu nghia MQL5/C++ con lai phai tranh trong ma EA (vd "chuoi" + "chuoi").
"""
import re
import sys

KEYWORDS = {"return", "else", "case", "goto", "throw", "delete", "new", "typedef", "sizeof"}
IDENT = r"[A-Za-z_][A-Za-z0-9_]*"


def translate(src: str):
    if src.startswith("﻿"):
        src = src[1:]
    inputs = []
    out_lines = []
    for line in src.splitlines():
        s = line.strip()
        if s.startswith("#property") or s.startswith("#include"):
            out_lines.append("// " + line)
            continue
        if re.match(r"^\s*(input|sinput)\s+group\b", line):
            out_lines.append("// " + line)
            continue
        m = re.match(rf"^(\s*)(input|sinput)\s+({IDENT})\s+({IDENT})\s*=\s*(.+?);(.*)$", line)
        if m:
            indent, _, typ, name, value, rest = m.groups()
            inputs.append((typ, name))
            out_lines.append(f"{indent}{typ} {name} = {value};{rest}")
            continue
        out_lines.append(line)
    code = "\n".join(out_lines) + "\n"

    # Tham so mang: [const] TYPE &name[]
    code = re.sub(rf"(const\s+)?({IDENT})\s*&\s*({IDENT})\s*\[\s*\]",
                  lambda m: f"{m.group(1) or ''}DynArr<{m.group(2)}> &{m.group(3)}", code)

    def decl_dyn(m):
        indent, typ, name = m.group(1), m.group(2), m.group(3)
        if typ.split()[-1] in KEYWORDS:
            return m.group(0)
        return f"{indent}DynArr<{typ}> {name};"

    code = re.sub(rf"^(\s*)((?:const\s+)?{IDENT})\s+({IDENT})\s*\[\s*\]\s*;", decl_dyn, code, flags=re.M)

    def decl_stat(m):
        indent, typ, name, size = m.group(1), m.group(2), m.group(3), m.group(4)
        if typ.split()[-1] in KEYWORDS:
            return m.group(0)
        return f"{indent}StatArr<{typ}, {size}> {name};"

    code = re.sub(rf"^(\s*)((?:const\s+)?{IDENT})\s+({IDENT})\s*\[\s*({IDENT}|\d+)\s*\]\s*;", decl_stat, code, flags=re.M)

    # Ham nap input tu file SET
    ap = ["void __apply_input(const std::string &k, const std::string &v)", "{"]
    for typ, name in inputs:
        if typ == "bool":
            conv = '(v == "true" || v == "1")'
        elif typ in ("int", "long", "short", "char"):
            conv = f"({typ})std::stoll(v)"
        elif typ in ("uint", "ulong", "ushort", "uchar", "color"):
            conv = f"({typ})std::stoull(v)"
        elif typ in ("double", "float"):
            conv = "std::stod(v)"
        elif typ == "string":
            conv = "v"
        elif typ == "datetime":
            conv = "(datetime)std::stoll(v)"
        else:  # enum
            conv = f"({typ})std::stoi(v)"
        ap.append(f'   if(k == "{name}") {{ {name} = {conv}; return; }}')
    ap.append('   __unknown_input(k);')
    ap.append("}")
    names = ["const char *__input_names[] = {"] + [f'   "{n}",' for _, n in inputs] + ["   0 };"]
    header = '#include "mql5.h"\n#line 1 "EA.mq5"\n'
    return header + code + "\n" + "\n".join(ap) + "\n" + "\n".join(names) + "\n", inputs


if __name__ == "__main__":
    src = open(sys.argv[1], encoding="utf-8").read()
    cpp, inputs = translate(src)
    open(sys.argv[2], "w", encoding="utf-8").write(cpp)
    print(f"da dich {sys.argv[1]} -> {sys.argv[2]} ({len(inputs)} input)")
