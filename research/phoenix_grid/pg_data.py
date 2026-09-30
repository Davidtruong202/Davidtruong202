"""Phoenix Grid – đọc tick MT5 và dựng nến M1 theo Bid.

Phần đọc zip (`_raw_zip_member_stream`, `read_tick_zip`) chép từ
research/david_hunter_v439/dh/data.py (nhánh claude/vibrant-turing-8b1e1v, commit 878f551), là bộ đọc đã được
đối chiếu 164/164 lệnh với MT5 ở dự án V4.39. Phần làm sạch được viết lại để ĐẾM các bất thường thay vì chỉ lọc bỏ.

Định dạng vào: file "Export ticks" của MT5 (phân cách tab: <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>).
`read_tick_zip` tự nhận ba dạng:
  - một file zip, có thể chia phần `*.zip.part001`, `*.zip.part002`… (thiếu phần cuối vẫn đọc được phần đã có);
  - nhiều file zip độc lập (mỗi file tự giải nén được, ví dụ XAUUSD_01.zip … XAUUSD_20.zip), đọc theo thứ tự tên;
  - file CSV không nén.
Mỗi phần có thể có hoặc không có dòng tiêu đề <DATE>…; nếu file bị cắt giữa một dòng, phần dòng dở ở cuối file này
được ghép với đầu file kế tiếp.
Thời gian là giờ server (Exness = GMT+0).
"""
import glob
import io
import os
import struct
import zipfile
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


def _doc_bang_tick(raw):
    """Đọc nội dung CSV tick MT5 (bytes), có hoặc không có dòng tiêu đề. Bỏ dòng cuối nếu bị cắt dở."""
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    raw = raw[: raw.rfind(b"\n") + 1]
    co_tieu_de = raw.startswith(b"<DATE>")
    df = pd.read_csv(io.BytesIO(raw), sep="\t", usecols=[0, 1, 2, 3], names=["date", "time", "bid", "ask"],
                     header=0 if co_tieu_de else None, dtype={"date": str, "time": str})
    return df, len(raw)


def _giai_nen_luong(parts):
    """Giải nén member đầu tiên của một zip (có thể ghép từ nhiều phần, có thể thiếu phần cuối)."""
    name, comp, method, usize, csize = _raw_zip_member_stream(parts)
    if method == 8:
        d = zlib.decompressobj(-15)
        raw = d.decompress(comp)
        complete = d.eof
    elif method == 0:
        raw, complete = comp, len(comp) >= csize
    else:
        raise ValueError("phương thức nén zip không hỗ trợ: %d" % method)
    return name, raw, bool(complete), int(usize)


def read_tick_zip(path_pattern):
    """Đọc tick MT5 thành DataFrame date/time/bid/ask. Nhận zip chia phần, nhiều zip độc lập, hoặc CSV."""
    parts = sorted(glob.glob(path_pattern))
    if not parts:
        raise FileNotFoundError(path_pattern)
    heads = [open(p, "rb").read(4) for p in parts]
    doc_lap = len(parts) > 1 and all(h == b"PK\x03\x04" for h in heads)
    csv_thuan = all(h != b"PK\x03\x04" for h in heads)
    if not doc_lap and not csv_thuan:
        # một file zip, có thể chia phần: ghép các phần thành một luồng
        name, raw, complete, usize = _giai_nen_luong(parts)
        df, n_read = _doc_bang_tick(raw)
        info = {"member": name, "parts": [os.path.basename(p) for p in parts], "complete": complete,
                "uncompressed_expected": usize, "uncompressed_read": n_read}
        return df, info
    frames, members = [], []
    tt = {"complete": True, "expected": 0, "read": 0, "carry": b""}

    def them(raw, ten, du=True):
        """Nối phần dòng dở của file trước, đọc các dòng đầy đủ, giữ lại phần dòng dở cuối cho file sau."""
        n0 = len(raw)
        if raw.startswith(b"\xef\xbb\xbf"):
            raw = raw[3:]
        if raw.startswith(b"<DATE>"):
            raw = raw[raw.find(b"\n") + 1:]
            tt["carry"] = b""  # dòng tiêu đề chỉ đứng đầu một file xuất đầy đủ
        cu = tt["carry"]
        data = cu + raw
        cut = data.rfind(b"\n") + 1
        du_lai = data[cut:]
        tt["carry"] = du_lai if du else b""  # file thiếu: bỏ dòng dở, không ghép sang file sau
        if cut:
            frames.append(_doc_bang_tick(data[:cut])[0])
        members.append(ten)
        tt["read"] += n0 + len(cu) - len(du_lai)  # byte đã đọc; phần dòng dở được tính ở file sau

    for p in parts:
        if csv_thuan:
            tt["expected"] += os.path.getsize(p)
            them(open(p, "rb").read(), os.path.basename(p))
            continue
        try:
            with zipfile.ZipFile(p) as z:
                for info_z in z.infolist():
                    if not info_z.is_dir():
                        tt["expected"] += info_z.file_size
                        them(z.read(info_z), os.path.basename(p) + ":" + info_z.filename)
        except zipfile.BadZipFile:
            # file zip không đủ (ví dụ tải lên dở): đọc phần giải nén được, đánh dấu chưa đủ
            name, raw, ok, usize = _giai_nen_luong([p])
            tt["expected"] += usize
            them(raw, os.path.basename(p) + ":" + name + " (thiếu)", du=ok)
            tt["complete"] = tt["complete"] and ok
    if tt["carry"].strip():
        frames.append(_doc_bang_tick(tt["carry"] + b"\n")[0])  # dòng cuối cùng không có ký tự xuống dòng
        tt["read"] += len(tt["carry"])
    df = pd.concat(frames, ignore_index=True)
    info = {"member": "; ".join(members), "parts": [os.path.basename(p) for p in parts], "complete": tt["complete"],
            "uncompressed_expected": tt["expected"], "uncompressed_read": tt["read"]}
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


def tu_kiem_tra():
    """Tự kiểm tra read_tick_zip trên dữ liệu giả, mọi dạng file. Trả về số lỗi."""
    import tempfile

    rng = np.random.default_rng(7)
    n = 900
    t0 = pd.Timestamp("2026-01-01 23:05:00")
    ts = t0 + pd.to_timedelta(np.cumsum(rng.integers(1, 400, n)), unit="ms")
    bid = np.round(4328.0 + np.cumsum(rng.normal(0, 0.05, n)), 3)
    ask = np.round(bid + 0.16, 3)
    rows = [f"{t:%Y.%m.%d}\t{t:%H:%M:%S}.{t.microsecond // 1000:03d}\t{b:.3f}\t{a:.3f}\t\t\t6"
            for t, b, a in zip(ts, bid, ask)]
    header = "<DATE>\t<TIME>\t<BID>\t<ASK>\t<LAST>\t<VOLUME>\t<FLAGS>"
    loi = 0

    def kiem(ten, pattern, n_mong_doi, du_mong_doi):
        nonlocal loi
        df, info = read_tick_zip(pattern)
        dung = (len(df) == n_mong_doi and info["complete"] == du_mong_doi and
                np.allclose(df["bid"].to_numpy(), bid[:n_mong_doi]) and
                list(df["time"].iloc[:2]) == [r.split("\t")[1] for r in rows[:2]])
        loi += 0 if dung else 1
        print(f"  {'ĐẠT ' if dung else 'LỖI '} {ten}: {len(df)} tick, đủ file = {info['complete']}")

    def zip_mot(path, members):
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
            for name, text in members:
                z.writestr(name, text)

    with tempfile.TemporaryDirectory() as d:
        full = header + "\n" + "\n".join(rows) + "\n"
        # 1) CSV thuần
        open(os.path.join(d, "a.csv"), "w").write(full)
        kiem("CSV thuần", os.path.join(d, "a.csv"), n, True)
        # 2) một zip, chia 3 phần (dạng cũ; nhận theo chữ ký zip chỉ có ở phần đầu)
        zip_mot(os.path.join(d, "b.zip"), [("XAUUSDc_x.csv", full)])
        blob = open(os.path.join(d, "b.zip"), "rb").read()
        k = len(blob) // 3
        for i, part in enumerate([blob[:k], blob[k:2 * k], blob[2 * k:]]):
            open(os.path.join(d, f"b.zip.part{i + 1:03d}"), "wb").write(part)
        kiem("zip chia 3 phần", os.path.join(d, "b.zip.part*"), n, True)
        # 3) nhiều zip độc lập, chỉ phần đầu có tiêu đề
        os.makedirs(os.path.join(d, "c"))
        for i in range(3):
            body = "\n".join(rows[i * 300:(i + 1) * 300]) + "\n"
            zip_mot(os.path.join(d, "c", f"XAUUSD_{i + 1:02d}.zip"), [(f"p{i + 1}.csv", (header + "\n" if i == 0 else "") + body)])
        kiem("3 zip độc lập, tiêu đề chỉ ở phần đầu", os.path.join(d, "c", "XAUUSD_*.zip"), n, True)
        # 4) nhiều zip độc lập, phần nào cũng có tiêu đề
        os.makedirs(os.path.join(d, "e"))
        for i in range(3):
            body = header + "\n" + "\n".join(rows[i * 300:(i + 1) * 300]) + "\n"
            zip_mot(os.path.join(d, "e", f"XAUUSD_{i + 1:02d}.zip"), [(f"p{i + 1}.csv", body)])
        kiem("3 zip độc lập, phần nào cũng có tiêu đề", os.path.join(d, "e", "XAUUSD_*.zip"), n, True)
        # 5) một zip chứa 3 file
        os.makedirs(os.path.join(d, "f"))
        zip_mot(os.path.join(d, "f", "XAUUSD_01.zip"),
                [(f"p{i + 1}.csv", header + "\n" + "\n".join(rows[i * 300:(i + 1) * 300]) + "\n") for i in range(2)])
        zip_mot(os.path.join(d, "f", "XAUUSD_02.zip"), [("p3.csv", "\n".join(rows[600:]) + "\n")])
        kiem("zip chứa nhiều file", os.path.join(d, "f", "XAUUSD_*.zip"), n, True)
        # 6) CSV cắt theo byte (giữa dòng) rồi nén thành 3 zip độc lập / để thành 3 file CSV
        os.makedirs(os.path.join(d, "h"))
        os.makedirs(os.path.join(d, "k"))
        blob_csv = full.encode()
        cuts = [0, len(blob_csv) // 3 + 7, 2 * len(blob_csv) // 3 + 11, len(blob_csv)]
        assert all(blob_csv[c - 1:c] != b"\n" for c in cuts[1:3])  # chỗ cắt nằm giữa dòng
        for i in range(3):
            chunk = blob_csv[cuts[i]:cuts[i + 1]]
            with zipfile.ZipFile(os.path.join(d, "h", f"XAUUSD_{i + 1:02d}.zip"), "w", zipfile.ZIP_DEFLATED) as z:
                z.writestr(f"p{i + 1}.csv", chunk)
            open(os.path.join(d, "k", f"XAUUSD_{i + 1:02d}.csv"), "wb").write(chunk)
        kiem("3 zip độc lập, CSV bị cắt giữa dòng", os.path.join(d, "h", "XAUUSD_*.zip"), n, True)
        kiem("3 file CSV, bị cắt giữa dòng", os.path.join(d, "k", "XAUUSD_*.csv"), n, True)
        # 7) zip độc lập cuối bị tải lên dở: đọc được phần đầu, báo chưa đủ
        os.makedirs(os.path.join(d, "g"))
        for i in range(3):
            zip_mot(os.path.join(d, "g", f"XAUUSD_{i + 1:02d}.zip"),
                    [(f"p{i + 1}.csv", (header + "\n" if i == 0 else "") + "\n".join(rows[i * 300:(i + 1) * 300]) + "\n")])
        cuoi = os.path.join(d, "g", "XAUUSD_03.zip")
        b3 = open(cuoi, "rb").read()
        open(cuoi, "wb").write(b3[: len(b3) // 2])
        df, info = read_tick_zip(os.path.join(d, "g", "XAUUSD_*.zip"))
        dung = 600 <= len(df) < n and not info["complete"] and np.allclose(df["bid"].to_numpy(), bid[:len(df)])
        loi += 0 if dung else 1
        print(f"  {'ĐẠT ' if dung else 'LỖI '} zip cuối tải lên dở: {len(df)} tick, đủ file = {info['complete']}")
    print("Tự kiểm tra read_tick_zip:", "ĐẠT" if loi == 0 else f"{loi} LỖI")
    return loi


if __name__ == "__main__":
    import sys

    if "--tu-kiem-tra" in sys.argv:
        sys.exit(1 if tu_kiem_tra() else 0)
    print("Dùng: python3 pg_data.py --tu-kiem-tra")
