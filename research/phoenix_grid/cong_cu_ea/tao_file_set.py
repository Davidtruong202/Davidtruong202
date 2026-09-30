"""Tạo file .set cho EA Phoenix từ chính mã nguồn .mq5 (tên input và giá trị mặc định luôn khớp EA).

File .set ghi như MT5: UTF-16 LE có BOM, xuống dòng CRLF, mỗi dòng `tên=giá trị`, dòng bắt đầu bằng ';' là ghi chú.
Enum ghi bằng số (PERIOD_M2 = 2, PERIOD_M5 = 5, PERIOD_H1 = 16385, MODE_SMA = 0, PG_CD_GIAO_DICH = 1).

Chạy:  python3 tao_file_set.py            (tạo các file trong MQL5/Presets/PhoenixGrid/)
       python3 tao_file_set.py --kiem-tra (đọc lại các file đã tạo, đối chiếu với input của EA)
"""
import os
import re
import sys

GOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
EXPERTS = os.path.join(GOC, "MQL5", "Experts", "PhoenixGrid")
PRESETS = os.path.join(GOC, "MQL5", "Presets", "PhoenixGrid")

ENUM = {"PERIOD_M1": 1, "PERIOD_M2": 2, "PERIOD_M3": 3, "PERIOD_M4": 4, "PERIOD_M5": 5, "PERIOD_M6": 6, "PERIOD_M10": 10,
        "PERIOD_M12": 12, "PERIOD_M15": 15, "PERIOD_M20": 20, "PERIOD_M30": 30, "PERIOD_H1": 16385, "PERIOD_H4": 16388,
        "PERIOD_D1": 16408, "PG_CD_QUAN_SAT": 0, "PG_CD_GIAO_DICH": 1,
        "MODE_SMA": 0, "MODE_EMA": 1, "MODE_SMMA": 2, "MODE_LWMA": 3}


def doc_input(file_mq5):
    """Danh sách (nhóm, tên, kiểu, giá trị mặc định, nhãn) theo thứ tự trong file."""
    src = open(os.path.join(EXPERTS, file_mq5), encoding="utf-8-sig").read()
    ds, nhom = [], ""
    for dong in src.splitlines():
        m = re.match(r'^input\s+group\s+"(.*)"', dong)
        if m:
            nhom = m.group(1)
            continue
        m = re.match(r"^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);\s*//\s*(.*)$", dong)
        if m:
            ds.append((nhom, m.group(2), m.group(1), m.group(3).strip(), m.group(4).strip()))
    return ds


def gia_tri(kieu, v):
    if v.startswith('"'):
        return v.strip('"')
    if v in ENUM:
        return str(ENUM[v])
    if v in ("true", "false"):
        return v
    float(v)                      # số: giữ nguyên cách viết
    return v


def ghi_set(file_mq5, ten_set, sua, mo_ta):
    ds = doc_input(file_mq5)
    ten_input = {t for _, t, _, _, _ in ds}
    for k in sua:
        assert k in ten_input, f"{k} không phải input của {file_mq5}"
    dong = [f"; {ten_set}", f"; EA: {file_mq5}"] + [f"; {x}" for x in mo_ta] + [";"]
    nhom_truoc = None
    for nhom, ten, kieu, v, nhan in ds:
        if nhom != nhom_truoc:
            dong.append(f"; === {nhom} ===")
            nhom_truoc = nhom
        gt = str(sua[ten]) if ten in sua else gia_tri(kieu, v)
        dong.append(f"{ten}={gt}")
    os.makedirs(PRESETS, exist_ok=True)
    with open(os.path.join(PRESETS, ten_set), "wb") as f:
        f.write(b"\xff\xfe" + ("\r\n".join(dong) + "\r\n").encode("utf-16-le"))
    return len(ds)


BO_SET = [
    ("EA_PHOENIX_GRID_V0_21_TEST.mq5", "PG_V021_DEMO_5000USD.set",
     {"InpChoPhepTKThat": "false"},
     ["V0.21: vào lệnh liên tục (PP0) — không có basket thì mở lệnh đầu ngay sau 10 giây chờ, hướng theo SMA50 H1.",
      "Demo Standard USD 5.000, symbol XAUUSDm (hoặc XAUUSD), đòn bẩy 1:2000, tài khoản hedging.",
      "Lot 0,01 giữ nguyên: demo 5.000 USD với 0,01 lot có cùng tỷ lệ rủi ro như real Standard Cent 5.000 USC với 0,01 lot",
      "(0,01 lot: 1 USD/oz = 1 USD trên demo, = 1 USC trên cent). Số trên log demo (USD) bằng số trên real cent (USC).",
      "InpChoPhepTKThat=false: nếu lỡ nạp file này trên tài khoản thật, EA không gửi lệnh."]),
    ("EA_PHOENIX_GRID_V0_20_TEST.mq5", "PG_V020_DEMO_5000USD.set",
     {"InpChoPhepTKThat": "false"},
     ["Demo Standard USD 5.000, symbol XAUUSDm (hoặc XAUUSD), đòn bẩy 1:2000, tài khoản hedging.",
      "Lot 0,01 giữ nguyên: demo 5.000 USD với 0,01 lot có cùng tỷ lệ rủi ro như real Standard Cent 5.000 USC với 0,01 lot",
      "(0,01 lot: 1 USD/oz = 1 USD trên demo, = 1 USC trên cent). Số trên log demo (USD) bằng số trên real cent (USC).",
      "InpChoPhepTKThat=false: nếu lỡ nạp file này trên tài khoản thật, EA không gửi lệnh."]),
    ("EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "PMI_V001_THEO_PHOENIX_d60n2.set",
     {"InpMagicTheoDoi": "20260930"},
     ["Shadow Breakout Detection, theo dõi basket Phoenix V0.20 / V0.21 (cùng magic 20260930). Chỉ ghi log, không gửi lệnh.",
      "Ngưỡng xác nhận mặc định: điểm 60, 2 nến."]),
    ("EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "PMI_V001_THEO_PHOENIX_d80n3.set",
     {"InpMagicTheoDoi": "20260930", "InpDiemXacNhanBO": "80", "InpSoNenXacNhan": "3"},
     ["Shadow Breakout Detection, theo dõi basket Phoenix V0.20 / V0.21 (cùng magic 20260930). Chỉ ghi log, không gửi lệnh.",
      "Ngưỡng xác nhận chặt: điểm 80, 3 nến (chạy song song với d60n2 trên chart khác để so sánh)."]),
    ("EA_PHOENIX_MI_SHADOW_V0_01_TEST.mq5", "PMI_V001_THEO_HYDRA_d60n2.set",
     {"InpMagicTheoDoi": "0"},
     ["Shadow Breakout Detection trên MT5 real đang chạy Hydra 4.5. Chỉ ghi log, không gửi lệnh.",
      "Magic 0 = theo dõi mọi lệnh XAUUSDc trên tài khoản. Lịch sử 30/09 cho thấy Hydra dùng HAI magic: 20260826 (lệnh",
      "DCA 'Hydra N') và 20260827 (lệnh pyramid 'Hydra Py N'). Đặt 20260826 sẽ sót lệnh pyramid, nên giữ 0 và không",
      "đánh tay / chạy EA khác trên symbol này của tài khoản đó."]),
]


def kiem_tra():
    for file_mq5, ten_set, sua, _ in BO_SET:
        raw = open(os.path.join(PRESETS, ten_set), "rb").read()
        assert raw.startswith(b"\xff\xfe"), ten_set
        txt = raw[2:].decode("utf-16-le")
        assert "\r\n" in txt and "\n" not in txt.replace("\r\n", "")
        kv = dict(l.split("=", 1) for l in txt.split("\r\n") if l and not l.startswith(";"))
        ds = doc_input(file_mq5)
        assert set(kv) == {t for _, t, _, _, _ in ds}, (ten_set, set(kv) ^ {t for _, t, _, _, _ in ds})
        for _, ten, kieu, v, _ in ds:
            mong = str(sua.get(ten, gia_tri(kieu, v)))
            assert kv[ten] == mong, (ten_set, ten, kv[ten], mong)
        print(f"{ten_set}: {len(kv)} input khớp {file_mq5}; đổi so với mặc định: {sua}")


if __name__ == "__main__":
    if "--kiem-tra" in sys.argv:
        kiem_tra()
    else:
        for file_mq5, ten_set, sua, mo_ta in BO_SET:
            n = ghi_set(file_mq5, ten_set, sua, mo_ta)
            print(f"ghi {ten_set} ({n} input)")
        kiem_tra()
