"""Phoenix Grid – vẽ biểu tượng phượng hoàng và nhúng vào mã nguồn EA.

Việc làm:
  1. Vẽ phượng hoàng (cánh vàng kim, thân cam lửa, đuôi lửa, quầng sáng) ở độ phân giải gấp 4, rồi thu nhỏ
     để cạnh mịn. Nền trong suốt.
  2. Ghi ảnh xem trước PNG (nền đen của bảng điều khiển).
  3. (--nhung) Thay đoạn giữa hai dòng đánh dấu `// >>> PG_PHOENIX_DATA` và `// <<< PG_PHOENIX_DATA` trong file
     .mq5 bằng mảng ARGB (định dạng COLOR_FORMAT_ARGB_NORMALIZE: màu không nhân trước với alpha).
     EA tạo ảnh bằng ResourceCreate lúc chạy, nên chỉ cần chép một file .mq5, không cần file ảnh riêng.

Chạy:
  python3 bieu_tuong_phuong_hoang.py --png phuong_hoang_64.png --nhung ../../../MQL5/Experts/PhoenixGrid/<EA>.mq5
"""
import argparse

from PIL import Image, ImageDraw, ImageFilter

KICH_THUOC = 64       # kích thước hiển thị trên bảng (pixel)
NHAN = 4              # vẽ ở kích thước gấp 4 rồi thu nhỏ
S = KICH_THUOC * NHAN

VANG = (255, 216, 92)
VANG_DAM = (255, 178, 36)
CAM = (255, 122, 20)
DO = (224, 56, 22)
DO_SAM = (150, 24, 10)
NEN_BANG = (12, 10, 8)


def _mix(c1, c2, t):
    t = min(max(t, 0.0), 1.0)
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2))


def _layer(polys, ellipses, top, bottom, y0, y1):
    """Một lớp màu gradient dọc (top → bottom trong khoảng y0..y1) phủ lên hình (đa giác + elip)."""
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    for p in polys:
        d.polygon(p, fill=255)
    for e in ellipses:
        d.ellipse(e, fill=255)
    grad = Image.new("RGBA", (S, S))
    gp = grad.load()
    for y in range(S):
        c = _mix(top, bottom, (y - y0) / max(1, y1 - y0))
        for x in range(S):
            gp[x, y] = (c[0], c[1], c[2], 255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out, mask


def _mirror(poly):
    return [(S - x, y) for x, y in poly]


def ve_phuong_hoang():
    k = NHAN / 4.0  # tọa độ dưới đây viết cho lưới 256 × 256
    sc = lambda poly: [(x * k, y * k) for x, y in poly]
    cach_trai = sc([(118, 124), (96, 98), (70, 70), (44, 42), (16, 14), (34, 58), (24, 66), (54, 80), (46, 94),
                    (76, 100), (70, 114), (100, 120), (98, 134), (120, 142)])
    cach_phai = _mirror(cach_trai)
    duoi_giua = sc([(116, 184), (128, 252), (140, 184)])
    duoi_trai = sc([(112, 178), (82, 236), (104, 214), (96, 246), (124, 194)])
    duoi_phai = _mirror(duoi_trai)
    duoi_ngoai_trai = sc([(106, 170), (58, 212), (96, 196), (84, 222), (112, 186)])
    duoi_ngoai_phai = _mirror(duoi_ngoai_trai)
    mao = [sc([(118, 82), (106, 58), (126, 76)]), sc([(124, 78), (130, 48), (135, 78)]),
           sc([(132, 80), (150, 60), (140, 84)])]
    than = [tuple(v * k for v in (108, 108, 148, 196))]
    dau = [tuple(v * k for v in (113, 76, 143, 106))]
    mo = sc([(123, 99), (128, 113), (133, 99)])

    lop_canh, m1 = _layer([cach_trai, cach_phai], [], VANG, DO, 14 * k, 142 * k)
    lop_duoi, m2 = _layer([duoi_ngoai_trai, duoi_ngoai_phai, duoi_trai, duoi_phai, duoi_giua], [],
                          CAM, DO_SAM, 170 * k, 252 * k)
    lop_than, m3 = _layer([], than, VANG_DAM, CAM, 108 * k, 196 * k)
    lop_dau, m4 = _layer(mao, dau, VANG, VANG_DAM, 48 * k, 106 * k)

    # quầng sáng lửa phía sau
    mask_all = Image.new("L", (S, S), 0)
    for m in (m1, m2, m3, m4):
        mask_all = Image.composite(Image.new("L", (S, S), 255), mask_all, m)
    glow_mask = mask_all.filter(ImageFilter.GaussianBlur(10 * k)).point(lambda v: int(v * 0.55))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow.paste(Image.new("RGBA", (S, S), CAM + (255,)), (0, 0), glow_mask)

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for lop in (glow, lop_canh, lop_duoi, lop_than, lop_dau):
        img = Image.alpha_composite(img, lop)
    d = ImageDraw.Draw(img)
    d.polygon(mo, fill=CAM + (255,))
    r = 3 * k
    for cx in (121 * k, 135 * k):
        d.ellipse((cx - r, 90 * k - r, cx + r, 90 * k + r), fill=(40, 16, 6, 255))

    # thu nhỏ trong không gian alpha nhân trước để viền không bị ám màu tối
    small = img.convert("RGBa").resize((KICH_THUOC, KICH_THUOC), Image.LANCZOS).convert("RGBA")
    return small


def mang_mql5(img):
    raw = img.tobytes()  # RGBA, 4 byte mỗi điểm, theo hàng từ trên xuống
    vals = [(raw[i + 3] << 24) | (raw[i] << 16) | (raw[i + 1] << 8) | raw[i + 2] for i in range(0, len(raw), 4)]
    lines = []
    for i in range(0, len(vals), 12):
        lines.append("   " + ",".join(f"0x{v:08X}" for v in vals[i:i + 12]) + ",")
    lines[-1] = lines[-1].rstrip(",")
    return ("#define PG_PHOENIX_W " + str(img.width) + "\n#define PG_PHOENIX_H " + str(img.height) + "\n"
            "uint PG_PHOENIX_DATA[] =\n  {\n" + "\n".join(lines) + "\n  };\n")


def nhung(path, block):
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    a = "// >>> PG_PHOENIX_DATA"
    b = "// <<< PG_PHOENIX_DATA"
    i, j = text.index(a), text.index(b)
    text = text[:i] + a + "\n" + block + text[j:]
    open(path, "wb").write((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--png", help="ghi ảnh xem trước (nền bảng điều khiển, phóng to ×4)")
    ap.add_argument("--nhung", help="file .mq5 cần nhúng mảng ARGB")
    a = ap.parse_args()
    img = ve_phuong_hoang()
    if a.png:
        prev = Image.new("RGBA", img.size, NEN_BANG + (255,))
        prev = Image.alpha_composite(prev, img).resize((img.width * 4, img.height * 4), Image.NEAREST)
        prev.save(a.png)
        img.save(a.png.replace(".png", "_trong_suot.png"))
    if a.nhung:
        nhung(a.nhung, mang_mql5(img))
        print("đã nhúng vào", a.nhung)


if __name__ == "__main__":
    main()
