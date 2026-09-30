#!/bin/sh
# Dich EA .mq5 -> C++ roi bien dich cung bo gia lap. Dung: ./build.sh <duong_dan_ea.mq5> <thu_muc_ra>
set -e
EA="$1"; OUT="${2:-build}"
mkdir -p "$OUT"
python3 "$(dirname "$0")/mq5_to_cpp.py" "$EA" "$OUT/ea.cpp"
g++ -std=c++17 -O2 -g -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-variable \
    -Wno-sign-compare -I"$(dirname "$0")" -c "$OUT/ea.cpp" -o "$OUT/ea.o"
g++ -std=c++17 -O2 -g -Wall -I"$(dirname "$0")" -c "$(dirname "$0")/mt5sim.cpp" -o "$OUT/mt5sim.o"
g++ "$OUT/ea.o" "$OUT/mt5sim.o" -o "$OUT/mt5sim"
echo "OK: $OUT/mt5sim"
