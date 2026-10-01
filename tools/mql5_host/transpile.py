#!/usr/bin/env python3
"""
Host harness cho IDHG — chuyển mã MQL5 (tập con được dùng trong dự án) sang C++
để biên dịch và chạy self-test trên Linux khi KHÔNG có MetaEditor.

LƯU Ý QUAN TRỌNG:
  - Đây KHÔNG phải trình biên dịch MQL5. Biên dịch thành công ở đây không thay
    thế cho việc compile bằng MetaEditor. Nó chỉ kiểm tra cú pháp/kiểu ở mức C++
    và cho phép CHẠY logic thật của các module.
  - Bước lint bên dưới bắt một số lỗi mà C++ chấp nhận nhưng MQL5 từ chối
    (truyền struct theo giá trị, dùng '->', nullptr, std::, auto ...).

Cách dùng:
  transpile.py <src_root> <out_root>      # chuyển toàn bộ *.mqh / *.mq5
  transpile.py --lint <src_root>          # chỉ lint
"""
import os
import re
import sys

ARRAY_PARAM = re.compile(r'\b(const\s+)?([A-Za-z_]\w*)\s*&\s*([A-Za-z_]\w*)\s*\[\s*\]')
ARRAY_DECL = re.compile(r'^(\s*(?:static\s+)?)([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*\[\s*\]\s*;', re.M)
INPUT_DECL = re.compile(r'^(\s*)(?:sinput|input)\s+', re.M)
PROPERTY = re.compile(r'^\s*#property\b.*$', re.M)
INCLUDE = re.compile(r'^(\s*#include\s+")([^"]+)(")', re.M)

FORBIDDEN = [
    (re.compile(r'->'), "MQL5 không có toán tử '->' (dùng '.')"),
    (re.compile(r'\bnullptr\b'), "MQL5 không có nullptr (dùng NULL)"),
    (re.compile(r'\bstd::'), "MQL5 không có namespace std"),
    (re.compile(r'\bauto\s+\w'), "MQL5 không có 'auto'"),
    (re.compile(r'\b(static_cast|reinterpret_cast|dynamic_cast|const_cast)\b'), "MQL5 không có *_cast<>"),
    (re.compile(r'\bunsigned\s+(int|long|char|short)\b'), "MQL5 dùng uint/ulong/uchar/ushort"),
    (re.compile(r'\bsize_t\b'), "MQL5 không có size_t"),
    (re.compile(r'#pragma\s+once'), "MQL5 không có #pragma once"),
    (re.compile(r'\+\s*\'.\'|\'.\'\s*\+'), "cộng string với ký tự '...' trong MQL5 là cộng SỐ (ushort)"),
    (re.compile(r'\bthis\s*\.'), "tránh dùng this. (khác biệt MQL5/C++)"),
    (re.compile(r'\boperator\s*[^\w\s]'), "tránh overload operator"),
    (re.compile(r'\btemplate\s*<'), "tránh template trong mã dự án"),
]


def strip_comments_and_strings(text):
    """Thay comment/chuỗi bằng khoảng trắng (giữ số dòng) để lint không bắt nhầm."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r'[^\n]', ' ', text[i:j]))
            i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            out.append('""' + ' ' * max(0, j - i - 1))
            i = j + 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def collect_object_types(texts):
    names = set()
    for t in texts:
        for m in re.finditer(r'\b(?:struct|class)\s+([A-Za-z_]\w*)\s*(?::[^{;]*)?\{', t):
            names.add(m.group(1))
    # kiểu struct chuẩn của MQL5
    names.update(['MqlTradeRequest', 'MqlTradeResult', 'MqlTradeTransaction', 'MqlTick',
                  'MqlDateTime', 'MqlTradeCheckResult'])
    return names


def lint_text(path, text, obj_types):
    errs = []
    clean = strip_comments_and_strings(text)
    lines = clean.split('\n')
    for ln, line in enumerate(lines, 1):
        for rx, msg in FORBIDDEN:
            if rx.search(line):
                errs.append(f"{path}:{ln}: {msg}: {line.strip()}")
    # struct/class truyền theo giá trị trong danh sách tham số
    if obj_types:
        alt = '|'.join(sorted(obj_types, key=len, reverse=True))
        rx = re.compile(r'[(,]\s*(?:const\s+)?(' + alt + r')\s+([A-Za-z_]\w*)\s*(?=[,)=])')
        for m in rx.finditer(clean):
            ln = clean.count('\n', 0, m.start()) + 1
            # bỏ qua khai báo biến kiểu 'for(... ; ...)' — chỉ quan tâm tham số hàm
            errs.append(f"{path}:{ln}: MQL5 chỉ truyền struct/class THEO THAM CHIẾU: {m.group(1)} {m.group(2)}")
    # khởi tạo thành viên trong thân class/struct (MQL5 không cho phép)
    depth_stack = []
    brace_kind = []
    pending_kind = None
    for ln, line in enumerate(lines, 1):
        if re.search(r'\b(struct|class)\s+\w+[^;]*$', line) and not line.strip().endswith(';'):
            pending_kind = 'type'
        for ch in line:
            if ch == '{':
                brace_kind.append(pending_kind or 'block')
                pending_kind = None
            elif ch == '}':
                if brace_kind:
                    brace_kind.pop()
        if brace_kind and brace_kind[-1] == 'type':
            s = line.strip()
            if re.match(r'^(?:static\s+)?(?:const\s+)?[A-Za-z_]\w*\s+[A-Za-z_]\w*\s*=\s*[^=]', s) and '(' not in s.split('=')[0]:
                if not s.startswith('return') and not s.startswith('static const'):
                    errs.append(f"{path}:{ln}: MQL5 không cho khởi tạo thành viên trong thân class/struct: {s}")
    return errs


def transpile_text(text):
    if text.startswith('﻿'):
        text = text[1:]
    text = PROPERTY.sub('', text)
    text = re.sub(r'^\s*input\s+group\b.*$', '', text, flags=re.M)
    text = INPUT_DECL.sub(r'\1static ', text)
    text = INCLUDE.sub(lambda m: m.group(1) + m.group(2).replace('\\', '/') + m.group(3), text)
    text = ARRAY_PARAM.sub(lambda m: (m.group(1) or '') + f'MqlArray<{m.group(2)}> &{m.group(3)}', text)
    text = ARRAY_DECL.sub(lambda m: f'{m.group(1)}MqlArray<{m.group(2)}> {m.group(3)};', text)
    return text


def walk(src_root):
    for d, _, files in os.walk(src_root):
        for f in files:
            if f.endswith('.mqh') or f.endswith('.mq5'):
                yield os.path.join(d, f)


def read(p):
    with open(p, encoding='utf-8-sig') as fh:
        return fh.read()


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    lint_only = args[0] == '--lint'
    if lint_only:
        args = args[1:]
    src = args[0]
    files = [p for p in walk(src) if '/Experts/XAUUSD' not in p and '/PhoenixGrid/' not in p]
    texts = {p: read(p) for p in files}
    obj_types = collect_object_types(texts.values())
    errs = []
    for p, t in texts.items():
        errs += lint_text(os.path.relpath(p, src), t, obj_types)
    if errs:
        print("MQL5 LINT FAIL:")
        for e in errs:
            print("  " + e)
        return 1
    print(f"MQL5 LINT PASS ({len(files)} file)")
    if lint_only:
        return 0
    out = args[1]
    for p, t in texts.items():
        dst = os.path.join(out, os.path.relpath(p, src))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, 'w', encoding='utf-8') as fh:
            fh.write(transpile_text(t))
    return 0


if __name__ == '__main__':
    sys.exit(main())
