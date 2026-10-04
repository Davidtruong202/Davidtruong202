#!/bin/bash
# Kiểm tra sức chịu đựng một file set: ./stress.sh sets.csv tiento
S=$1; P=$2
./dh710sim --ticks du_lieu/ticks_bridge.bin --sets $S --out ket_qua/${P}_9thang.csv --threads 4
./dh710sim --ticks du_lieu/ticks_bridge.bin --sets $S --out ket_qua/${P}_spread100.csv --threads 4 --extra_spread 100
./dh710sim --ticks du_lieu/ticks_bridge.bin --sets $S --out ket_qua/${P}_chartM5.csv --threads 4 --chart_tf 5
./dh710sim --ticks du_lieu/ticks_real.bin --sets $S --out ket_qua/${P}_tickthat.csv --threads 4
./dh710sim --ticks du_lieu/ticks_bridge_s8.bin --sets $S --out ket_qua/${P}_seed8.csv --threads 4
echo XONG
