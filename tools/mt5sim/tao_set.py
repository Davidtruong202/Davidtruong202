"""Tao file SET MT5 (UTF-16LE co BOM, CRLF) tu gia tri mac dinh cua cac input trong file .mq5.
Enum duoc ghi bang so (MT5 nap SET theo gia tri so)."""
import re, sys
src = open(sys.argv[1], encoding="utf-8-sig").read()
enum_val = {}
for body in re.findall(r"enum\s+\w+\s*\{(.*?)\};", src, re.S):
    for name, val in re.findall(r"(\w+)\s*=\s*(-?\d+)", body):
        enum_val[name] = val
lines = []
for line in src.splitlines():
    g = re.match(r'^\s*input\s+group\s+"(.*)"', line)
    if g:
        lines.append("; " + g.group(1))
        continue
    m = re.match(r"^\s*input\s+\w+\s+(\w+)\s*=\s*([^;]+);\s*(?://\s*(.*))?$", line)
    if m:
        name, val, cmt = m.group(1), m.group(2).strip(), (m.group(3) or "").strip()
        val = enum_val.get(val, val).strip('"')
        lines.append(f"; {cmt}")
        lines.append(f"{name}={val}")
open(sys.argv[2], "w", encoding="utf-16-le", newline="").write("﻿" + "\r\n".join(lines) + "\r\n")
print("da ghi", sys.argv[2], sum(1 for l in lines if not l.startswith(";")), "input")
