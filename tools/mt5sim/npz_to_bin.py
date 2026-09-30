"""Xuat tick (npz t_ms/bid/ask) sang file nhi phan cho mt5sim: moi ban ghi <qdd (int64 ms, double bid, double ask)."""
import sys, numpy as np
z = np.load(sys.argv[1])
rec = np.empty(len(z["t_ms"]), dtype=[("t", "<i8"), ("b", "<f8"), ("a", "<f8")])
rec["t"], rec["b"], rec["a"] = z["t_ms"], z["bid"], z["ask"]
rec.tofile(sys.argv[2])
print("da ghi", len(rec), "tick ->", sys.argv[2])
