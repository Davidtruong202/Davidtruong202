#!/usr/bin/env bash
# Chạy host harness: lint MQL5 → transpile → biên dịch C++ (-Werror) → chạy self-test.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
H="$ROOT/tools/mql5_host"
B="${IDHG_BUILD_DIR:-$ROOT/build/host}"
rm -rf "$B"; mkdir -p "$B"
python3 "$H/transpile.py" "$ROOT/MQL5" "$B/mql5"
# Bước 1: clang -fsyntax-only với cảnh báo chuyển kiểu (MQL5 cũng cảnh báo "possible loss of data")
WARN=(-std=c++17 -Wall -Wextra -Werror -Wno-unused-parameter -Wno-unused-function -Wno-unused-but-set-variable
      -Wfloat-conversion -Wshorten-64-to-32 -I "$H" -I "$B/mql5")
# Bước 2: g++ + AddressSanitizer/UBSan để CHẠY test
RUN=(-std=c++17 -O1 -g -Wall -Werror -Wno-unused-function -fsanitize=address,undefined -fno-sanitize-recover=all
     -I "$H" -I "$B/mql5")
echo "== Kiểm tra kiểu (clang++ -fsyntax-only) =="
clang++ "${WARN[@]}" -fsyntax-only "$H/host_main.cpp"
echo "== Biên dịch EA + test (g++ + sanitizer) =="
g++ "${RUN[@]}" "$H/host_main.cpp" -o "$B/host_tests"
for s in "$ROOT"/MQL5/Scripts/IDHG/*.mq5; do
  n="$(basename "$s" .mq5)"
  echo "== Biên dịch script $n =="
  clang++ "${WARN[@]}" -fsyntax-only -DSCRIPT_PATH="\"Scripts/IDHG/$n.mq5\"" "$H/script_main.cpp"
  g++ "${RUN[@]}" -DSCRIPT_PATH="\"Scripts/IDHG/$n.mq5\"" "$H/script_main.cpp" -o "$B/$n"
done
echo "== Chạy self-test EA =="
"$B/host_tests"
for s in "$ROOT"/MQL5/Scripts/IDHG/*.mq5; do
  n="$(basename "$s" .mq5)"
  echo "== Chạy script $n =="
  "$B/$n" > "$B/$n.log" 2>&1 || { cat "$B/$n.log"; echo "SCRIPT FAIL: $n"; exit 1; }
  tail -n 1 "$B/$n.log"
done
echo "HOST HARNESS: ALL PASS"
