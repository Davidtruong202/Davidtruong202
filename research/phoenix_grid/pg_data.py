"""Phoenix Grid – đọc tick MT5 và dựng nến M1 theo Bid.

Phần đọc zip (`_raw_zip_member_stream`, `read_tick_zip`) chép từ
research/david_hunter_v439/dh/data.py (nhánh claude/vibrant-turing-8b1e1v, commit 878f551), là bộ đọc đã được
đối chiếu 164/164 lệnh với MT5 ở dự án V4.39. Phần làm sạch được viết lại để ĐẾM các bất thường thay vì chỉ lọc bỏ.

Định dạng vào: file "Export ticks" của MT5 (phân cách tab: <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>),
nén zip, có thể chia phần `*.zip.part001`, `*.zip.part002`… Thiếu phần cuối vẫn đọc được phần đã có.
Thời gian là giờ server (Exness = GMT+0).
"""
import glob
import io
import os
import struct
import zlib

import numpy as np
import pandas as pd


def _raw_zip_member_stream(parts):
    """Ghép các phần và trả về (tên file bên trong, dữ liệu nén, phương thức nén, kích thước gốc, kích thước nén)."""
    blob = b"".join(open(p, "rb").read() for p in parts)
    sig, _ver, _flag, method, _t, _d, _crc, csize, usize, nlen, xlen = struct.unpack("<IHHHHHIIIHH", blob[:30])
    if sig != 0x04034B50:
        raise ValueError("không phải local header của zip: %s" % parts[0])
    name = blob[30:30 + nlen].decode("utf-8", "replace")
    start = 30 + nlen + xlen
    return name, blob[start:start + csize] if csize else blob[start:], method, usize, csize


def read_tick_zip(path_pattern):
    """Giải nén file tick MT5 (có thể chia phần, có thể thiếu phần cuối) thành DataFrame date/time/bid/ask."""
    parts = sorted(glob.glob(path_pattern))
    if not parts:
        raise FileNotFoundError(path_pattern)
    name, comp, method, usize, csize = _raw_zip_member_stream(parts)
    if method == 8:
        d = zlib.decompressobj(-15)
        raw = d.decompress(comp)
        complete = d.eof
    elif method == 0:
        raw, complete = comp, len(comp) >= csize
    else:
        raise ValueError("phương thức nén zip không hỗ trợ: %d" % method)
    raw = raw[: raw.rfind(b"\n") + 1]  # bỏ dòng cuối bị cắt dở
    df = pd.read_csv(io.BytesIO(raw), sep="\t", usecols=[0, 1, 2, 3], names=["date", "time", "bid", "ask"], header=0,
                     dtype={"date": str, "time": str})
    info = {"member": name, "parts": [os.path.basename(p) for p in parts], "complete": bool(complete),
            "uncompressed_expected": int(usize), "uncompressed_read": len(raw)}
    return df, info


def clean_ticks(df):
    """Làm sạch tick và đếm từng loại bất thường.

    - Bid hoặc Ask trống: MT5 chỉ ghi phía thay đổi, nên điền tiếp giá trị trước (ffill). Được đếm, không phải lỗi.
    - Bỏ: giá ≤ 0 hoặc không hữu hạn; Ask < Bid; thời gian lùi (sắp xếp lại, có đếm); tick trùng hoàn toàn.
    Trả về (t_ms, bid, ask, bảng đếm).
    """
    counts = {"so_dong_goc": int(len(df)),
              "bid_trong_duoc_dien_tiep": int(df["bid"].isna().sum()),
              "ask_trong_duoc_dien_tiep": int(df["ask"].isna().sum())}
    ts = pd.to_datetime(df["date"] + " " + df["time"], format="%Y.%m.%d %H:%M:%S.%f")
    t_ms = ts.values.astype("datetime64[ms]").astype(np.int64)
    bid = df["bid"].ffill().to_numpy(np.float64)
    ask = df["ask"].ffill().to_numpy(np.float64)
    finite = np.isfinite(bid) & np.isfinite(ask) & (bid > 0) & (ask > 0)
    counts["gia_khong_hop_le"] = int((~finite).sum())
    crossed = finite & (ask < bid)
    counts["ask_nho_hon_bid"] = int(crossed.sum())
    ok = finite & ~crossed
    t_ms, bid, ask = t_ms[ok], bid[ok], ask[ok]
    counts["thoi_gian_lui"] = int((np.diff(t_ms) < 0).sum())
    order = np.argsort(t_ms, kind="stable")
    t_ms, bid, ask = t_ms[order], bid[order], ask[order]
    dup = np.r_[False, (np.diff(t_ms) == 0) & (np.diff(bid) == 0) & (np.diff(ask) == 0)]
    counts["tick_trung_hoan_toan"] = int(dup.sum())
    keep = ~dup
    t_ms, bid, ask = t_ms[keep], bid[keep], ask[keep]
    counts["so_tick_sau_lam_sach"] = int(len(t_ms))
    return t_ms, bid, ask, counts


def build_m1(t_ms, bid, ask, point):
    """Nến M1 theo Bid giống MT5 (nhãn = giờ mở nến; chỉ có nến khi có tick) + các cách đo spread trong nến."""
    minute = t_ms // 60000
    starts = np.flatnonzero(np.r_[True, minute[1:] != minute[:-1]])
    ends = np.r_[starts[1:], len(minute)] - 1
    spread_pts = np.rint((ask - bid) / point).astype(np.int64)
    return pd.DataFrame({
        "time": pd.to_datetime(minute[starts] * 60, unit="s"),
        "open": bid[starts],
        "high": np.maximum.reduceat(bid, starts),
        "low": np.minimum.reduceat(bid, starts),
        "close": bid[ends],
        "tick_count": (ends - starts + 1),
        "spread_min": np.minimum.reduceat(spread_pts, starts),
        "spread_max": np.maximum.reduceat(spread_pts, starts),
        "spread_open": spread_pts[starts],
        "spread_close": spread_pts[ends],
    })
