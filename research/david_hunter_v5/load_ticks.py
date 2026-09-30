"""Doc tick MT5 xuat ra (zip, co the chia phan / thieu phan cuoi) -> npz (t_ms, bid, ask).

Dinh dang CSV MT5: <DATE>\t<TIME>\t<BID>\t<ASK>\t<LAST>\t<VOLUME>\t<FLAGS>; o trong = gia khong doi.
Doc giai nen deflate tu dau file zip (local header), bo dong cuoi bi cat.
"""
import glob, io, os, struct, sys, zlib
import numpy as np, pandas as pd

def read_zip_parts(pattern):
    parts = sorted(glob.glob(pattern))
    if not parts:
        raise FileNotFoundError(pattern)
    blob = b"".join(open(p, "rb").read() for p in parts)
    sig, _v, _f, method, _t, _d, _crc, csize, usize, nlen, xlen = struct.unpack("<IHHHHHIIIHH", blob[:30])
    assert sig == 0x04034B50, "khong phai zip"
    start = 30 + nlen + xlen
    comp = blob[start:start + csize] if csize else blob[start:]
    if method == 8:
        d = zlib.decompressobj(-15); raw = d.decompress(comp); complete = d.eof
    else:
        raw, complete = comp, True
    raw = raw[: raw.rfind(b"\n") + 1]
    return raw, complete, parts

def load(pattern, out):
    raw, complete, parts = read_zip_parts(pattern)
    df = pd.read_csv(io.BytesIO(raw), sep="\t", usecols=[0, 1, 2, 3], names=["d", "t", "bid", "ask"], header=0,
                     dtype={"d": str, "t": str})
    ts = pd.to_datetime(df["d"] + " " + df["t"], format="%Y.%m.%d %H:%M:%S.%f")
    t_ms = ts.values.astype("datetime64[ms]").astype(np.int64)
    bid = df["bid"].ffill().to_numpy(np.float64); ask = df["ask"].ffill().to_numpy(np.float64)
    ok = np.isfinite(bid) & np.isfinite(ask) & (bid > 0) & (ask >= bid)
    o = np.argsort(t_ms[ok], kind="stable")
    t_ms, bid, ask = t_ms[ok][o], bid[ok][o], ask[ok][o]
    np.savez(out, t_ms=t_ms, bid=bid, ask=ask)
    print("parts", [os.path.basename(p) for p in parts], "complete", complete)
    print("ticks", len(t_ms), pd.to_datetime(t_ms[0], unit="ms"), "->", pd.to_datetime(t_ms[-1], unit="ms"))

if __name__ == "__main__":
    load(sys.argv[1], sys.argv[2])
