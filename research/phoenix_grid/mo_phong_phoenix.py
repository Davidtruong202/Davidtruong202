"""Mô phỏng Python phần xử lý lệnh của EA Phoenix Grid V0.21 / V0.23 (và hedge của V0.22 không phát hành) trên nến M1 —
để tìm lỗi logic và so sánh cấu hình. KHÔNG phải backtest MT5.

Chép lại theo mã nguồn EA (cùng thứ tự trong một tick):
  TP phía server của từng tầng (khớp đúng giá TP) → QuanLyBasket: clear cả basket (trailing clear, hòa vốn khi sâu)
  → hedge theo Phoenix (chỉ V0.22, mặc định tắt) → tỉa bằng lời hedge → clear từng phần (XetXoaTang) → DCA (giãn cách
  InpGiayGiuaDCA, margin level sau lệnh ≥ InpMLVao, số lệnh mỗi ngày ≤ InpLenhToiDaNgay, InpTiaLapLai) → PP0 (lệnh đầu
  theo SMA H1, chờ InpGiayChoSauClear sau clear, chặn ngược xu hướng M5 Phoenix, không mở 15 phút trước giờ nghỉ).
Tài khoản cent: spread cố định 0,26 USD như đo trên XAUUSDc (R0.1), swap BUY −56 / lot / đêm (thứ Tư ×3), margin 1 lot =
giá × 100 / 2000, stop out 0%: vốn về 0 là "cháy" — đóng hết, nạp lại vốn ban đầu, chạy tiếp và đếm số lần cháy.
Kiểm tra bất biến trong lúc chạy (dừng và báo khi sai): không over-hedge quá 1 tick; không có hedge khi basket không còn
tầng; mỗi lần tỉa bằng hedge có tổng ≥ 0 theo giá lúc quyết định.

GIỚI HẠN (phải đọc khi xem số liệu):
  - không có tick thật: trong mỗi nến M1 giá đi mở → cực trị gần giá mở hơn → cực trị còn lại → đóng, nội suy thẳng
    từng bước ≤ ThamSo.duong_gia (mặc định 0,5 USD), thời gian chia theo quãng đường; giá là XAUUSDm (Bid), chưa có dữ
    liệu XAUUSDc; không trượt giá, lệnh thị trường khớp ở giá của điểm nội suy;
  - không có: chặn ngược breakout, hoãn DCA khi breakout, hedge theo breakout (cần bộ nhận diện breakout theo tick),
    lọc tin, lọc spread, PP1;
  - kết quả phụ thuộc đường giá: một lần vào lệnh khác có thể cho kết quả khác hẳn (đo bằng nhiễu thứ tự cực trị và giờ
    bắt đầu trong do_tim_set_cent.py).
Vì vậy số liệu chỉ dùng để so sánh cấu hình với nhau trên cùng dữ liệu, không phải dự báo lãi.

Chạy:
  python3 mo_phong_phoenix.py --m1 <nen_M1.csv> [--out <thư mục>]   (so sánh vài cấu hình hedge trên toàn bộ dữ liệu)
  python3 mo_phong_phoenix.py --tu-kiem-tra
"""
import argparse
import math
import os
import sys
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

VPL = 100.0          # tiền tài khoản mỗi 1 lot khi giá đi 1 USD (XAUUSDc: 100 USC; XAUUSDm: 100 USD)
ST = 0.01            # bước lot, lot tối thiểu
BANG_HYDRA = ((6, 1.2), (14, 1.05), (18, 1.5), (26, 1.05), (30, 1.3))


@dataclass
class ThamSo:
    lot0: float = 0.01
    he_so: float = 1.0            # InpHeSoLot (khi bảng hệ số tắt)
    bang_lot: bool = False        # InpDungBangLot (bảng theo cấp như Hydra)
    lot_max: float = 0.50         # InpLotTangToiDa
    so_tang: int = 40             # InpSoTangToiDa
    buoc_atr: float = 1.15        # InpBuocATR
    buoc_min: float = 6.0         # InpBuocMinUSD
    tia_tp: float = 1.0           # InpTiaTPBuoc
    giay_dca: int = 20            # InpGiayGiuaDCA
    tp_atr: float = 1.0           # InpGioTPATR
    trail: bool = True            # InpTrailClear
    trail_giu: float = 60.0       # InpTrailGiuPT
    hoa_von_tang: int = 4         # InpHoaVonTuTang
    xoa: bool = True              # InpXoaTangLo
    xoa_tu: int = 3               # InpXoaTuSoTang
    xoa_gom: int = 4              # InpXoaGomLai
    cho_clear: int = 10           # InpGiayChoSauClear
    loc_xh: bool = True           # InpChanNguocXH
    hedge: bool = False           # InpDungHedge (V0.22)
    hd_tu_buoc: float = 6.0
    hd_ty_le: tuple = (25.0, 50.0, 70.0, 100.0)
    hd_buoc_cap: float = 1.0
    hd_nha_buoc: float = 1.0
    hd_giu_phut: int = 15
    hd_tia: bool = True
    hd_giam: str = "bac"          # "bac": giảm một cấp khi giá hồi hd_nha_buoc bậc; "khong": không giảm cấp
    khoa_dca_sau_hd: bool = False # basket đã hedge thì không DCA thêm tới khi kết thúc
    tia_lap_lai: bool = True      # InpTiaLapLai (tắt: tầng đã tỉa / đã gộp lãi không mở lại)
    ml_vao: float = 500.0         # InpMLVao: margin level tối thiểu sau lệnh mở (%), áp cho lệnh đầu và DCA
    don_bay: float = 2000.0       # đòn bẩy tài khoản (XAUUSDc R0.1: margin 1 lot = giá × 100 / 2000)
    lenh_ngay: int = 1000         # InpLenhToiDaNgay: số lệnh mở (đầu + DCA) tối đa mỗi ngày
    duong_gia: float = 0.5        # bước giá tối đa của đường giá nội suy trong nến M1 (USD); <= 0: 4 điểm / nến (mô hình cũ)
    von: float = 5000.0
    ma_h1: int = 50               # InpPP0MA (SMA, khung H1); chuan_bi phải có cột tổng tương ứng
    spread: float = 0.26          # spread cố định (USD); <= 0: lấy theo cột spread của dữ liệu
    swap_long: float = -56.0      # tiền mỗi lot mỗi đêm cho lệnh BUY (XAUUSDc: −560 point); SELL 0


def lam_tron(v):
    return math.floor(v / ST + 0.5 + 1e-9) * ST


def lot_tang(ts, i):
    lot = ts.lot0
    for j in range(1, i + 1):
        if ts.bang_lot:
            hs = 1.0
            for den, m in BANG_HYDRA:
                if j <= den:
                    hs = m
                    break
        else:
            hs = ts.he_so
        lot *= hs
    lot = lam_tron(lot)
    lot = math.floor(min(lot, ts.lot_max) / ST + 1e-7) * ST
    return round(max(ST, lot), 2)


@dataclass
class Vt:                        # vị thế
    id: int
    huong: int                   # +1 BUY, -1 SELL
    lot: float
    gia: float
    tp: float = 0.0
    swap: float = 0.0


@dataclass
class Basket:
    huong: int
    p0: float
    buoc: float
    muc_tieu: float
    t_mo: float
    tang: dict = field(default_factory=dict)       # i -> Vt
    cho: int = -1
    gia_truoc: float = 0.0
    da_chot: float = 0.0
    dinh: float = 0.0
    tang_sau: int = 0
    ms_dca: float = -1e18
    hd: list = field(default_factory=list)        # list Vt (lệnh hedge)
    hd_cap: int = 0
    hd_moc: float = 0.0
    hd_cuc: float = 0.0
    hd_luc: float = 0.0
    so_hd: int = 0
    cap_max: int = 0
    so_tia_hd: int = 0
    so_doi_cap: int = 0
    t_hedge: float = 0.0
    t_khoa: float = 0.0
    dd_max: float = 0.0
    lot_max: float = 0.0
    da_tia: set = field(default_factory=set)      # tầng đã tỉa / đã gộp lãi ít nhất một lần (g_tangDaTia)


class MoPhong:
    def __init__(self, ts: ThamSo):
        self.ts = ts
        self.nap = 0.0
        self.chot = 0.0
        self.b = None
        self.id = 0
        self.t_clear = -1e18
        self.gui = False
        self.ket_qua = []
        self.chay = []
        self.su_kien_hd = []
        self.vi_pham = []
        self.qua_hedge = 0
        self.eq_dinh = ts.von
        self.dd_max_pt = 0.0
        self.dd_max_tien = 0.0
        self.bid = self.ask = 0.0
        self.t = 0.0
        self.swap_tong = 0.0
        self.lenh_hom_nay = 0
        self.tick_chan_ml = 0         # số tick có DCA chờ mà bị chặn vì margin level
        self.lan_chan_ml_dau = 0      # số lần không mở được lệnh đầu vì margin level
        self.tick_chan_ngay = 0       # số tick bị chặn vì đủ số lệnh trong ngày
        self.lenh_max_ngay = 0
        self.von_thap = ts.von        # Equity thấp nhất không tính tiền nạp lại (= vốn + lãi / lỗ tích lũy)
        self.tong_lot = 0.0           # tổng khối lượng các lệnh đã mở (lot)
        self.eq_ngay = {}             # ngày -> Equity cuối ngày (không tính tiền nạp lại), trước swap qua đêm
        self.chot_ngay = {}           # ngày -> lãi đã chốt lũy kế cuối ngày
        self.so_ngay = 0              # số ngày có nến đã chạy
        self._ag = None               # tổng của basket, tính lại khi vị thế thay đổi

    # ---------------------------------------------------------------- tiện ích
    def lai(self, v):
        gia_dong = self.bid if v.huong > 0 else self.ask
        return (gia_dong - v.gia) * v.huong * v.lot * VPL + v.swap

    def _tong(self):
        """(lot, Σ lot × giá vào, swap) của các tầng và của hedge, TP gần nhất của các tầng. Chỉ tính lại khi vị thế đổi
        (mo, dong, tinh_swap đặt _ag = None)."""
        ag = self._ag
        if ag is None:
            b = self.b
            lt = st = swt = lh = sh = swh = 0.0
            tp = None
            for v in b.tang.values():
                lt += v.lot
                st += v.lot * v.gia
                swt += v.swap
                if v.tp > 0 and (tp is None or (v.tp < tp if b.huong > 0 else v.tp > tp)):
                    tp = v.tp
            for v in b.hd:
                lh += v.lot
                sh += v.lot * v.gia
                swh += v.swap
            ag = self._ag = (lt, st, swt, lh, sh, swh, tp)
        return ag

    def tha_noi(self):
        b = self.b
        if b is None:
            return 0.0
        lt, st, swt, lh, sh, swh, _ = self._tong()
        if b.huong > 0:     # tầng BUY đóng ở Bid, hedge SELL đóng ở Ask
            return (self.bid * lt - st) * VPL + swt - (self.ask * lh - sh) * VPL + swh
        return -(self.ask * lt - st) * VPL + swt + (self.bid * lh - sh) * VPL + swh

    def tha_noi_tung_lenh(self):
        """Thả nổi cộng từng vị thế (để tự kiểm tra cách tính theo tổng)."""
        b = self.b
        if b is None:
            return 0.0
        return sum(self.lai(v) for v in b.tang.values()) + sum(self.lai(v) for v in b.hd)

    def lot_ro(self):
        return round(self._tong()[0], 2) if self.b else 0.0

    def lot_hd(self):
        return round(self._tong()[3], 2) if self.b else 0.0

    def nguoc_tu(self, x):
        return (x - self.bid) if self.b.huong > 0 else (self.ask - x)

    def gia_tang(self, i):
        b = self.b
        return b.p0 - b.huong * i * b.buoc

    def mo(self, huong, lot):
        self.id += 1
        self._ag = None
        self.tong_lot += round(lot, 2)
        return Vt(self.id, huong, round(lot, 2), self.ask if huong > 0 else self.bid)

    def dong(self, v, lot=None, gia=None):
        """Đóng (một phần) vị thế v tại giá hiện tại (gia: giá khớp cho trước, ví dụ TP phía server khớp đúng giá TP);
        swap tính theo tỷ lệ lot đóng; trả về lãi đã chốt."""
        self._ag = None
        lot = v.lot if lot is None else lot
        tl = lot / v.lot if v.lot > 0 else 1.0
        l = ((self.bid if v.huong > 0 else self.ask) if gia is None else gia) - v.gia
        sw = v.swap * tl
        ln = l * v.huong * lot * VPL + sw
        v.swap -= sw
        self.chot += ln
        self.b.da_chot += ln
        v.lot = round(v.lot - lot, 2)
        return ln

    def margin_dat(self, huong, lot):
        """MarginDat của EA: margin level sau lệnh ≥ InpMLVao. Margin đang dùng tính theo lot ròng (margin_hedged = 0),
        margin lệnh mới tính riêng như OrderCalcMargin."""
        mpl = self.bid * VPL / self.ts.don_bay
        rong = 0.0
        if self.b is not None:
            ag = self._tong()
            rong = ag[0] - ag[3]
        m_dung = abs(rong) * mpl
        m = lot * ((self.ask if huong > 0 else self.bid) * VPL / self.ts.don_bay)
        eq = self.equity()
        if eq - m_dung - m <= 0.0:
            return False
        return not (m_dung + m > 0.0 and eq / (m_dung + m) * 100.0 < self.ts.ml_vao)

    def tinh_swap(self, so_dem):
        if self.b is None or so_dem <= 0:
            return
        self._ag = None
        for v in list(self.b.tang.values()) + self.b.hd:
            if v.huong > 0:
                s = self.ts.swap_long * v.lot * so_dem
                v.swap += s
                self.swap_tong += s

    # ---------------------------------------------------------------- basket
    def mo_basket(self, huong, atr5):
        if self.lenh_hom_nay >= self.ts.lenh_ngay:
            self.tick_chan_ngay += 1
            return False
        if not self.margin_dat(huong, lot_tang(self.ts, 0)):
            self.lan_chan_ml_dau += 1
            return False
        buoc = max(self.ts.buoc_min, self.ts.buoc_atr * atr5)
        p0 = self.ask if huong > 0 else self.bid
        b = Basket(huong, p0, buoc, self.ts.tp_atr * atr5 * VPL * lot_tang(self.ts, 0), self.t)
        self.b = b
        v = self.mo(huong, lot_tang(self.ts, 0))
        v.tp = p0 + huong * self.ts.tia_tp * buoc
        b.tang[0] = v
        b.gia_truoc = p0
        b.ms_dca = self.t
        b.lot_max = v.lot
        self.gui = True
        self.lenh_hom_nay += 1
        return True

    def ket_thuc(self, ly):
        b = self.b
        self.ket_qua.append(dict(t_mo=b.t_mo, t_dong=self.t, huong=b.huong, ly=ly, lai=b.da_chot, sau=b.tang_sau,
                                 so_hd=b.so_hd, cap_max=b.cap_max, tia_hd=b.so_tia_hd, doi_cap=b.so_doi_cap,
                                 t_hedge=b.t_hedge, t_khoa=b.t_khoa, dd_max=b.dd_max, lot_max=b.lot_max))
        self.b = None
        self._ag = None
        self.t_clear = self.t

    def dong_ca(self, ly):
        b = self.b
        for i in sorted(b.tang):
            self.dong(b.tang[i])
        for v in list(b.hd):
            self.dong(v)
        b.tang.clear()
        b.hd.clear()
        self.ket_thuc(ly)

    # ---------------------------------------------------------------- một tick
    def tick(self, t, bid, ask, atr5, ma, ct=0, cho_mo=True):
        """ct: cấu trúc M5 Phoenix (1 TĂNG, −1 GIẢM, 0 khác); cho_mo: được mở basket (không sát giờ nghỉ)."""
        self.t, self.bid, self.ask = t, bid, ask
        self.gui = False
        b = self.b
        if b is not None:
            tp = self._tong()[6]
            if tp is not None and ((b.huong > 0 and bid >= tp) or (b.huong < 0 and ask <= tp)):
                for i in sorted(b.tang):
                    v = b.tang[i]
                    if v.tp > 0 and ((v.huong > 0 and bid >= v.tp) or (v.huong < 0 and ask <= v.tp)):
                        self.dong(v, gia=v.tp)        # TP phía server: khớp tại giá TP
                        del b.tang[i]
                        b.da_tia.add(i)
            if not b.tang:
                if b.hd:
                    for v in list(b.hd):
                        self.dong(v)
                    b.hd.clear()
                self.ket_thuc("TIA_HET")
            else:
                self.quan_ly(atr5)
        self.kiem_von()
        if self.b is None and cho_mo:
            self.pp0(atr5, ma, ct)
        self.bat_bien()

    def quan_ly(self, atr5):
        b, ts = self.b, self.ts
        tn = self.tha_noi()
        b.dd_max = max(b.dd_max, -tn)
        rong = b.da_chot + tn
        muc = 0.0 if (ts.hoa_von_tang > 0 and b.tang_sau >= ts.hoa_von_tang) else b.muc_tieu
        ly = ""
        if muc < b.muc_tieu:
            if rong >= muc:
                ly = "HOA_VON"
        elif not ts.trail:
            if rong >= muc:
                ly = "GIO_TP"
        else:
            if rong > b.dinh and (b.dinh > 0 or rong >= muc):
                b.dinh = rong
            if b.dinh > 0 and rong <= b.dinh * ts.trail_giu / 100.0:
                ly = "TRAIL_CLEAR"
        if ly:
            self.dong_ca(ly)
            return
        if ts.hedge:
            self.hedge()
            if ts.hd_tia:
                self.tia_hedge()
        if self.b is None:
            return
        if ts.xoa and len(b.tang) >= ts.xoa_tu:
            self.xoa_tang()
        self.dca()
        if b.hd:
            b.t_hedge += 15
        if b.hd_cap >= 4:
            b.t_khoa += 15

    def hedge(self):
        b, ts = self.b, self.ts
        gia = self.bid if b.huong > 0 else self.ask
        bac = ts.hd_buoc_cap * b.buoc
        su = ""
        if b.hd_cap == 0:
            sau = ts.hd_tu_buoc > 0 and self.nguoc_tu(b.p0) >= ts.hd_tu_buoc * b.buoc
            xa = b.hd_moc <= 0 or self.nguoc_tu(b.hd_moc) >= bac
            if sau and xa and b.tang:
                b.hd_cap = 1
                b.so_hd += 1
                b.hd_moc = gia
                su = "MO_HEDGE"
        else:
            if self.nguoc_tu(b.hd_cuc) > 0:
                b.hd_cuc = gia
            k = math.floor(self.nguoc_tu(b.hd_moc) / bac)
            if b.hd_cap < 4 and k >= 1:
                k = min(k, 4 - b.hd_cap)
                b.hd_cap += k
                b.hd_moc -= b.huong * k * bac
                su = "TANG_CAP"
            elif (ts.hd_giam == "bac" and -self.nguoc_tu(b.hd_cuc) >= ts.hd_nha_buoc * b.buoc
                  and self.t - b.hd_luc >= ts.hd_giu_phut * 60):
                b.hd_cap -= 1
                b.hd_moc = gia
                su = "NHA_HEDGE" if b.hd_cap == 0 else "GIAM_CAP"
        if su:
            b.hd_cuc = gia
            b.hd_luc = self.t
            b.cap_max = max(b.cap_max, b.hd_cap)
            b.so_doi_cap += 1
            self.su_kien_hd.append((self.t, su, b.hd_cap))
        if self.gui:
            return
        ty = 0.0 if b.hd_cap == 0 else ts.hd_ty_le[b.hd_cap - 1]
        lr = self.lot_ro()
        muc = min(lam_tron(ty / 100.0 * lr), lr)
        lech = round(muc - self.lot_hd(), 2)
        if lech >= ST - 1e-9:
            b.hd.append(self.mo(-b.huong, lech))
            self.gui = True
        elif -lech >= ST - 1e-9:
            con = -lech
            for v in sorted(b.hd, key=lambda x: -x.id):
                if con <= 1e-9:
                    break
                if v.lot <= con + 1e-9:
                    con = round(con - v.lot, 2)
                    self.dong(v)
                else:
                    self.dong(v, con)
                    con = 0.0
            b.hd = [v for v in b.hd if v.lot > 1e-9]
            self.gui = True

    def tia_hedge(self):
        b = self.b
        if self.gui or not b.hd or len(b.tang) < 2:
            return
        sau = max(b.tang)
        xa = min(b.tang)
        if xa >= sau:
            return
        lo = self.lai(b.tang[xa])
        if lo >= 0:
            return
        can = -lo
        chon, co = [], 0.0
        for v in sorted(b.hd, key=lambda x: -(self.lai(x) / x.lot)):
            p = self.lai(v)
            if p <= 0 or co >= can:
                break
            vc = v.lot
            if p > can - co:
                vc = math.ceil((can - co) / (p / v.lot) / ST - 1e-9) * ST
                vc = max(vc, ST)
                if vc > v.lot - ST + 1e-9:
                    vc = v.lot
            chon.append((v, round(vc, 2)))
            co += p * vc / v.lot
        if co < can - 1e-9:
            return
        if lo + co < -1e-6:
            self.vi_pham.append((self.t, f"tỉa bằng hedge tổng âm {lo + co:.4f}"))
        self.dong(b.tang[xa])
        del b.tang[xa]
        for v, vc in chon:
            self.dong(v, vc)
        b.hd = [v for v in b.hd if v.lot > 1e-9]
        b.so_tia_hd += 1
        self.gui = True
        self.su_kien_hd.append((self.t, "TIA_BANG_HEDGE", b.hd_cap))

    def xoa_tang(self):
        b = self.b
        if self.gui:
            return
        sau = max(b.tang)
        lai = {i: self.lai(v) for i, v in b.tang.items()}
        xau, lo_xau = -1, 0.0
        for i, l in lai.items():
            if i < sau and l < lo_xau:
                lo_xau, xau = l, i
        if xau < 0:
            return
        quy = max(0.0, b.da_chot)
        lai[xau] = 0.0
        chon = []
        while quy + lo_xau < 0 and len(chon) < self.ts.xoa_gom:
            tot = max((i for i in lai if i != sau and lai[i] > 0), key=lambda i: lai[i], default=-1)
            if tot < 0:
                break
            quy += lai[tot]
            lai[tot] = 0.0
            chon.append(tot)
        if quy + lo_xau < 0:
            return
        self.dong(b.tang[xau])
        del b.tang[xau]
        for i in chon:
            self.dong(b.tang[i])
            del b.tang[i]
            b.da_tia.add(i)
        self.gui = True

    def dca(self):
        b, ts = self.b, self.ts
        p = self.ask if b.huong > 0 else self.bid
        if b.gia_truoc > 0:
            for i in self.tang_bi_cat(b.gia_truoc, p):
                if i not in b.tang and (ts.tia_lap_lai or i not in b.da_tia) and i > b.cho:
                    b.cho = i
        b.gia_truoc = p
        if b.cho <= 0:
            return
        Lc = self.gia_tang(b.cho)
        if b.cho in b.tang or (b.huong > 0 and p > Lc) or (b.huong < 0 and p < Lc):
            b.cho = -1
            return
        if self.gui or self.t - b.ms_dca < ts.giay_dca:
            return
        if b.hd_cap > 0 or b.hd or (ts.khoa_dca_sau_hd and b.so_hd > 0):
            return
        if self.lenh_hom_nay >= ts.lenh_ngay:
            self.tick_chan_ngay += 1
            return
        if not self.margin_dat(b.huong, lot_tang(ts, b.cho)):
            self.tick_chan_ml += 1
            return
        v = self.mo(b.huong, lot_tang(ts, b.cho))
        v.tp = self.gia_tang(b.cho) + b.huong * ts.tia_tp * b.buoc
        b.tang[b.cho] = v
        b.tang_sau = max(b.tang_sau, b.cho)
        b.ms_dca = self.t
        b.lot_max = max(b.lot_max, self.lot_ro())
        self.gui = True
        self.lenh_hom_nay += 1
        b.cho = -1

    def tang_bi_cat(self, truoc, p):
        """Các tầng i (1 ≤ i < InpSoTangToiDa) mà giá vừa đi qua theo chiều ngược basket, như vòng for của EA:
        BUY: p ≤ L_i < giá trước; SELL: p ≥ L_i > giá trước. Chỉ duyệt các i nằm giữa hai giá (nhanh hơn duyệt hết)."""
        b = self.b
        d0 = b.huong * (b.p0 - truoc)
        d1 = b.huong * (b.p0 - p)
        if d1 <= d0:
            return []
        ra = []
        for i in range(max(1, int(math.floor(d0 / b.buoc))), min(self.ts.so_tang, int(math.floor(d1 / b.buoc)) + 2)):
            L = self.gia_tang(i)
            if (p <= L < truoc) if b.huong > 0 else (truoc < L <= p):
                ra.append(i)
        return ra

    def pp0(self, atr5, ma, ct):
        if self.gui or ma <= 0 or atr5 <= 0 or self.t - self.t_clear < self.ts.cho_clear:
            return
        huong = 1 if self.bid > ma else (-1 if self.ask < ma else 0)
        if huong == 0:
            return
        if self.ts.loc_xh and ((ct > 0 and huong < 0) or (ct < 0 and huong > 0)):
            return
        self.mo_basket(huong, atr5)

    # ---------------------------------------------------------------- vốn, bất biến
    def equity(self):
        return self.ts.von + self.nap + self.chot + self.tha_noi()

    def kiem_von(self):
        eq = self.equity()
        if eq - self.nap < self.von_thap:
            self.von_thap = eq - self.nap
        if eq > self.eq_dinh:
            self.eq_dinh = eq
        if self.eq_dinh > 0:
            self.dd_max_pt = max(self.dd_max_pt, (self.eq_dinh - eq) / self.eq_dinh * 100)
            self.dd_max_tien = max(self.dd_max_tien, self.eq_dinh - eq)
        if eq <= 0 and self.b is not None:
            b = self.b
            self.chay.append(dict(t=self.t, huong=b.huong, sau=b.tang_sau, lot=self.lot_ro(), hd=self.lot_hd(),
                                  cap=b.hd_cap, nguoc=self.nguoc_tu(b.p0)))
            self.dong_ca("CHAY")
            eq = self.ts.von + self.nap + self.chot
            self.nap += self.ts.von - eq
            self.eq_dinh = self.ts.von

    def bat_bien(self):
        b = self.b
        if b is None:
            self.qua_hedge = 0
            return
        if b.hd and not b.tang:
            self.vi_pham.append((self.t, "còn hedge khi basket không còn tầng"))
        if self.lot_hd() > self.lot_ro() + 1e-9:
            self.qua_hedge += 1
            if self.qua_hedge > 1:
                self.vi_pham.append((self.t, f"over-hedge {self.lot_hd()} > {self.lot_ro()} quá 1 tick"))
        else:
            self.qua_hedge = 0


# -------------------------------------------------------------------- dữ liệu và chỉ báo
def adx_mt5(h, l, c, n=14):
    """ADX như iADX của MT5 (EMA của +DI, −DI theo từng nến, rồi EMA của DX)."""
    pc = np.r_[c[0], c[:-1]]
    tr = np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))
    up = h - np.r_[h[0], h[:-1]]
    dn = np.r_[l[0], l[:-1]] - l
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    mdm = np.where((dn > up) & (dn > 0), dn, 0.0)
    a = 2.0 / (n + 1)
    N = len(c)
    adx, dip, dim = np.zeros(N), np.zeros(N), np.zeros(N)
    sp = sm = sa = 0.0
    for i in range(1, N):
        trr = tr[i] if tr[i] > 0 else 1e-9
        sp += a * (100.0 * pdm[i] / trr - sp)
        sm += a * (100.0 * mdm[i] / trr - sm)
        s = sp + sm
        sa += a * ((100.0 * abs(sp - sm) / s if s > 0 else 0.0) - sa)
        adx[i], dip[i], dim[i] = sa, sp, sm
    return adx, dip, dim


def cau_truc_m5(m5, n_box=48, n_er=24, wmin=1.5, wmax=6.0, adx_sw=22.0, adx_tr=27.0, er_sw=0.30, er_tr=0.40,
                beta_sw=0.05, beta_tr=0.10, tau=0.15, min_cham=2, h_vao=2, h_ra=2):
    """Trạng thái cấu trúc Phoenix theo TinhM5 của EA: 1 TĂNG, −1 GIẢM, 2 SIDEWAYS, 0 KHÔNG RÕ (có chống nhấp nháy)."""
    o, h, l, c = (m5[x].values for x in ("open", "high", "low", "close"))
    pc = np.r_[c[0], c[:-1]]
    tr = np.maximum(h - l, np.maximum(np.abs(h - pc), np.abs(l - pc)))
    atr = pd.Series(tr).rolling(14).mean().values
    adx, dip, dim = adx_mt5(h, l, c)
    N = len(c)
    ct = np.zeros(N, dtype=int)
    cur, ung, chuoi = 0, 0, 0
    xs = np.arange(n_er, dtype=float)
    sx, sxx = xs.sum(), (xs * xs).sum()
    can = max(n_box, n_er + 1) + 2
    for i in range(can, N):
        a5 = atr[i]
        if not (a5 > 0):
            ct[i] = cur
            continue
        dau = i - n_box + 1
        U, L = h[dau:i + 1].max(), l[dau:i + 1].min()
        W = U - L
        tU = tL = 0
        for j in range(dau + 2, i - 1):
            if h[j] > h[j - 1] and h[j] > h[j - 2] and h[j] >= h[j + 1] and h[j] >= h[j + 2] and h[j] >= U - tau * W:
                tU += 1
            if l[j] < l[j - 1] and l[j] < l[j - 2] and l[j] <= l[j + 1] and l[j] <= l[j + 2] and l[j] <= L + tau * W:
                tL += 1
        ms = np.abs(np.diff(c[i - n_er:i + 1])).sum()
        er = abs(c[i] - c[i - n_er]) / ms if ms > 0 else 0.0
        y = c[i - n_er + 1:i + 1]
        md = n_er * sxx - sx * sx
        beta = ((n_er * (xs * y).sum() - sx * y.sum()) / md) / a5 if md != 0 else 0.0
        wa = W / a5
        if wmin <= wa <= wmax and adx[i] < adx_sw and er < er_sw and tU >= min_cham and tL >= min_cham and abs(beta) < beta_sw:
            tho = 2
        elif adx[i] >= adx_tr and dip[i] > dim[i] and er >= er_tr and beta >= beta_tr:
            tho = 1
        elif adx[i] >= adx_tr and dim[i] > dip[i] and er >= er_tr and beta <= -beta_tr:
            tho = -1
        else:
            tho = 0
        if tho == ung:
            chuoi += 1
        else:
            ung, chuoi = tho, 1
        if ung != cur and chuoi >= (h_ra if ung == 0 else h_vao):
            cur = ung
        ct[i] = cur
    return ct


CAC_MA = (20, 50, 100, 200)


def chuan_bi(m1_csv, cac_ma=CAC_MA):
    """Đọc M1 và thêm: atr5 (ATR14 M5, SMA của TR như iATR), ct (cấu trúc M5), s{n−1} (tổng n−1 giá đóng H1 đã đóng,
    để SMA n H1 = (tổng + giá hiện tại) / n như iMA ở nến 0), sat_nghi, ngay, thang."""
    m1 = pd.read_csv(m1_csv, sep=";")
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M:%S")
    m1 = m1.sort_values("time").reset_index(drop=True)
    m5 = m1.set_index("time").resample("5min", label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}).dropna()
    pc = m5["close"].shift(1)
    tr = np.maximum(m5["high"] - m5["low"], np.maximum((m5["high"] - pc).abs(), (m5["low"] - pc).abs()))
    atr = tr.rolling(14).mean()
    ct = pd.Series(cau_truc_m5(m5), index=m5.index)
    # giá trị của nến M5 dùng được từ lúc nến đó đóng
    atr.index = atr.index + pd.Timedelta(minutes=5)
    ct.index = ct.index + pd.Timedelta(minutes=5)
    m1["atr5"] = atr.reindex(m1["time"], method="ffill").values
    m1["ct"] = ct.reindex(m1["time"], method="ffill").fillna(0).astype(int).values
    h1 = m1.set_index("time")["close"].resample("1h", label="left", closed="left").last().dropna()
    for n in cac_ma:
        sn = h1.rolling(n - 1).sum()
        sn.index = sn.index + pd.Timedelta(hours=1)
        m1[f"s{n - 1}"] = sn.reindex(m1["time"], method="ffill").values
    # 15 phút trước giờ nghỉ (khoảng trống ≥ 30 phút tới nến kế tiếp): không mở basket mới
    t = m1["time"].values.astype("datetime64[s]").astype(np.int64)
    gap = np.r_[np.diff(t), 0]
    bat_dau_nghi = t[gap >= 1800] + 60
    k = np.searchsorted(bat_dau_nghi, t)
    sau = np.where(k < len(bat_dau_nghi), bat_dau_nghi[np.minimum(k, len(bat_dau_nghi) - 1)] - t, 10 ** 9)
    m1["sat_nghi"] = sau <= 15 * 60
    m1["ngay"] = m1["time"].dt.normalize()
    m1["thang"] = m1["time"].dt.to_period("M").astype(str)
    return m1


def duong_gia(o, h, l, c, delta, day_truoc=None):
    """Đường giá trong mỗi nến M1: mở → cực trị thứ nhất → cực trị thứ hai → đóng.
    delta > 0: mỗi đoạn chia thành các bước giá ≤ delta (USD), thời gian trong nến (0–59 giây) chia theo quãng đường;
    delta <= 0: 4 điểm cách nhau 15 giây (mô hình cũ).
    day_truoc: None = cực trị gần giá mở đi trước; mảng bool = True thì đáy trước.
    Trả về (số điểm của từng nến, giá, giây trong nến)."""
    o, h, l, c = (np.asarray(x, dtype=float) for x in (o, h, l, c))
    lo = (np.abs(o - l) <= np.abs(o - h)) if day_truoc is None else np.asarray(day_truoc, dtype=bool)
    x1, x2 = np.where(lo, l, h), np.where(lo, h, l)
    d1, d2, d3 = np.abs(x1 - o), np.abs(x2 - x1), np.abs(c - x2)
    if delta > 0:
        n1, n2, n3 = (np.maximum(1, np.ceil(d / delta - 1e-9)).astype(np.int64) for d in (d1, d2, d3))
    else:
        n1 = n2 = n3 = np.ones(len(o), dtype=np.int64)
    dem = 1 + n1 + n2 + n3
    nen = np.repeat(np.arange(len(o)), dem)
    r = np.arange(int(dem.sum())) - np.repeat(np.r_[0, np.cumsum(dem)[:-1]], dem)
    N1, N2, N3 = n1[nen], n2[nen], n3[nen]
    O, X1, X2, C = o[nen], x1[nen], x2[nen], c[nen]
    D1, D2, D3 = d1[nen], d2[nen], d3[nen]
    m2, m3 = r - N1, r - N1 - N2
    doan1, doan2, doan3 = (r >= 1) & (r <= N1), (m2 >= 1) & (m2 <= N2), m3 >= 1
    gia = np.where(doan1, O + (X1 - O) * r / N1, O)
    gia = np.where(doan2, X1 + (X2 - X1) * m2 / N2, gia)
    gia = np.where(doan3, X2 + (C - X2) * m3 / N3, gia)
    qd = np.where(doan1, D1 * r / N1, 0.0)
    qd = np.where(doan2, D1 + D2 * m2 / N2, qd)
    qd = np.where(doan3, D1 + D2 + D3 * m3 / N3, qd)
    tq = D1 + D2 + D3
    if delta > 0:
        giay = np.where(tq > 0, 59.0 * qd / np.where(tq > 0, tq, 1.0), 15.0 * np.minimum(r, 3))
    else:
        giay = 15.0 * r
    return dem, gia, giay


def chay(m1, ts, tu=None, den=None, hat=None):
    """Chạy trên các nến có thời gian trong [tu, den). Vốn ban đầu ts.von; cuối kỳ tính Equity theo giá (không đóng).
    Đường giá trong nến theo duong_gia(…, ts.duong_gia). hat: None = cực trị gần giá mở đi trước; số nguyên = thứ tự
    cực trị ngẫu nhiên theo hạt này (nhiễu đường giá để đo độ nhạy)."""
    sim = MoPhong(ts)
    chon = np.ones(len(m1), dtype=bool)
    if tu is not None:
        chon &= (m1["time"] >= pd.Timestamp(tu)).values
    if den is not None:
        chon &= (m1["time"] < pd.Timestamp(den)).values
    idx = np.flatnonzero(chon)
    cot = f"s{ts.ma_h1 - 1}"
    if cot not in m1.columns:
        raise ValueError(f"dữ liệu chưa có tổng H1 cho SMA{ts.ma_h1} (chuan_bi cac_ma)")
    t0 = m1["time"].iloc[0]
    tt = ((m1["time"].values[idx] - np.datetime64(t0)) / np.timedelta64(1, "s")).tolist()
    sp = (np.full(len(idx), ts.spread) if ts.spread > 0 else
          np.maximum(m1["spread_points"].values[idx] * 0.001, 0.05)).tolist()
    atr5 = m1["atr5"].values[idx].tolist()
    s_ma = m1[cot].values[idx].tolist()
    ct = m1["ct"].values[idx].astype(int).tolist()
    mo_duoc = (~m1["sat_nghi"].values[idx].astype(bool)).tolist()
    ngay = m1["ngay"].values[idx].astype("datetime64[D]").astype(np.int64).tolist()
    thang = m1["thang"].values[idx].tolist()
    day = (np.random.default_rng(hat).random(len(m1)) < 0.5)[idx] if hat is not None else None
    dem, gia, giay = duong_gia(m1["open"].values[idx], m1["high"].values[idx], m1["low"].values[idx],
                               m1["close"].values[idx], ts.duong_gia, day)
    dau = np.r_[0, np.cumsum(dem)].tolist()
    gia, giay = gia.tolist(), giay.tolist()
    n_ma = float(ts.ma_h1)
    eq_thang, ngay_truoc = {}, None
    for jj in range(len(idx)):
        nd = ngay[jj]
        if ngay_truoc is not None and nd != ngay_truoc:
            sim.eq_ngay[ngay_truoc] = sim.equity() - sim.nap
            sim.chot_ngay[ngay_truoc] = sim.chot
            so = 0
            for d in range(ngay_truoc, nd):        # số ngày từ 1970-01-01 (thứ Năm): thứ = (d + 3) % 7, 0 = thứ Hai
                w = (d + 3) % 7
                if w < 5:
                    so += 3 if w == 2 else 1
            sim.tinh_swap(so)
            sim.lenh_max_ngay = max(sim.lenh_max_ngay, sim.lenh_hom_nay)
            sim.lenh_hom_nay = 0
        if nd != ngay_truoc:
            sim.so_ngay += 1
        ngay_truoc = nd
        a5, sm = atr5[jj], s_ma[jj]
        if not (a5 > 0) or not (sm > 0):
            continue
        tk, spk, ck, md = tt[jj], sp[jj], ct[jj], mo_duoc[jj]
        for q in range(dau[jj], dau[jj + 1]):
            g = gia[q]
            sim.tick(tk + giay[q], g, g + spk, a5, (sm + g) / n_ma, ck, md)
            if sim.vi_pham:
                return sim, eq_thang
        eq_thang[thang[jj]] = sim.equity() - sim.nap
    if ngay_truoc is not None:
        sim.eq_ngay[ngay_truoc] = sim.equity() - sim.nap
        sim.chot_ngay[ngay_truoc] = sim.chot
    return sim, eq_thang


def tom_tat(sim, eq_thang, ts):
    """Các chỉ số của một lần chạy."""
    kq = pd.DataFrame(sim.ket_qua)
    von = ts.von
    eq_cuoi = sim.equity() - sim.nap
    net = eq_cuoi - von
    thang = pd.Series(eq_thang).sort_index()
    loi_thang = thang.diff().fillna(thang.iloc[0] - von) if len(thang) else pd.Series(dtype=float)
    r = dict(net=round(net, 1), chay=len(sim.chay), dd_pt=round(sim.dd_max_pt, 1), dd_tien=round(sim.dd_max_tien, 1),
             basket=len(kq), vi_pham=len(sim.vi_pham), swap=round(sim.swap_tong, 1),
             net_dd=round(net / sim.dd_max_tien, 2) if sim.dd_max_tien > 0 else 0.0,
             thang_am=int((loi_thang < 0).sum()), bo1thang=round(loi_thang.sum() - loi_thang.nlargest(1).sum(), 1),
             bo2thang=round(loi_thang.sum() - loi_thang.nlargest(2).sum(), 1),
             gio_chan_ml=round(sim.tick_chan_ml * 15 / 3600, 1), chan_ml_dau=sim.lan_chan_ml_dau,
             lenh_max_ngay=max(sim.lenh_max_ngay, sim.lenh_hom_nay), chan_ngay=sim.tick_chan_ngay)
    r.update(so_lenh=sim.id, von_thap=round(sim.von_thap, 1),
             basket_ngay=round(len(kq) / sim.so_ngay, 2) if sim.so_ngay else 0.0)
    # tiền mỗi ngày (theo Equity cuối ngày, gồm cả thả nổi) và khối lượng giao dịch
    if sim.eq_ngay:
        e = pd.Series(sim.eq_ngay).sort_index()
        ln = e.diff().fillna(e.iloc[0] - von)
        c = pd.Series(sim.chot_ngay).sort_index()
        r.update(so_ngay=len(e), lai_ngay_tb=round(float(ln.mean()), 2), lai_ngay_tv=round(float(ln.median()), 2),
                 ngay_lo_pt=round(float((ln < 0).mean() * 100), 1), ngay_xau=round(float(ln.min()), 1),
                 ngay_tot=round(float(ln.max()), 1), chot_ngay_tb=round(float(c.iloc[-1] / len(c)), 2),
                 lot_gd=round(sim.tong_lot, 2), lot_ngay=round(sim.tong_lot / len(e), 2))
    if len(kq):
        dur = (kq["t_dong"] - kq["t_mo"]) / 3600
        r.update(gio_tv=round(float(dur.median()), 2), gio_p95=round(float(dur.quantile(0.95)), 1),
                 gio_max=round(dur.max(), 1), sau_max=int(kq["sau"].max()), lot_max=round(kq["lot_max"].max(), 2),
                 buy=round(kq.loc[kq["huong"] > 0, "lai"].sum(), 1), sell=round(kq.loc[kq["huong"] < 0, "lai"].sum(), 1),
                 co_hd=int((kq["so_hd"] > 0).sum()), gio_khoa=round(kq["t_khoa"].sum() / 3600, 1))
    return r


# -------------------------------------------------------------------- tự kiểm tra trên đường giá giả
def tu_kiem_tra():
    loi = []
    ts = ThamSo(he_so=1.2, hedge=True, spread=0.2, swap_long=0.0)
    sim = MoPhong(ts)
    gia = [4000.0] * 2 + list(np.arange(3999.0, 3939.0, -1.0)) + list(np.arange(3941.0, 3961.0, 1.0)) + [3960.0] * 120
    for k, g in enumerate(gia):
        sim.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
        if sim.vi_pham:
            break
    su = [s for _, s, _ in sim.su_kien_hd]
    if sim.vi_pham:
        loi.append(f"vi phạm bất biến: {sim.vi_pham[:3]}")
    if "MO_HEDGE" not in su:
        loi.append("không kích hoạt hedge khi giá đi ngược 60 USD (mốc 36)")
    if su.count("TANG_CAP") < 1:
        loi.append("không tăng cấp hedge khi giá đi ngược thêm")
    b = sim.b
    if (sim.ket_qua and max(k["sau"] for k in sim.ket_qua) >= 6) or (b is not None and b.tang_sau >= 6):
        loi.append("DCA mở tới tầng 6 dù hedge đã kích hoạt ở mốc 6 bậc")
    if "GIAM_CAP" not in su and "NHA_HEDGE" not in su:
        loi.append("không giảm cấp khi giá hồi đủ một bậc và đã giữ 15 phút")
    ts2 = ThamSo(he_so=1.0, hedge=True, spread=0.2, swap_long=0.0)
    sim2 = MoPhong(ts2)
    for k, g in enumerate([4000.0] * 2 + list(np.arange(3999.0, 3899.0, -0.5))):
        sim2.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
        if sim2.vi_pham:
            break
    if sim2.vi_pham:
        loi.append(f"vi phạm bất biến (2): {sim2.vi_pham[:3]}")
    if not any(s == "TIA_BANG_HEDGE" for _, s, _ in sim2.su_kien_hd):
        loi.append("không tỉa bằng lời hedge khi giá đi ngược 100 USD")
    if sim2.b is None or sim2.b.hd_cap != 4:
        loi.append("giá đi ngược 100 USD mà hedge chưa ở cấp 4")
    # lọc xu hướng: MA dưới giá (BUY) nhưng cấu trúc GIẢM -> không mở basket
    sim3 = MoPhong(ThamSo(spread=0.2, swap_long=0.0))
    sim3.tick(0.0, 4000.0, 4000.2, 5.0, 3000.0, ct=-1)
    if sim3.b is not None:
        loi.append("mở BUY khi cấu trúc M5 GIẢM (phải chặn)")
    sim3.tick(15.0, 4000.0, 4000.2, 5.0, 3000.0, ct=0, cho_mo=False)
    if sim3.b is not None:
        loi.append("mở basket sát giờ nghỉ (phải chặn)")
    sim3.tick(30.0, 4000.0, 4000.2, 5.0, 3000.0, ct=1)
    if sim3.b is None or sim3.b.huong != 1:
        loi.append("không mở BUY khi cấu trúc TĂNG và giá trên MA")
    # swap: BUY 0,01 lot, 1 đêm thường -0,56; thứ Tư ×3
    ts4 = ThamSo(spread=0.2, swap_long=-56.0)
    sim4 = MoPhong(ts4)
    sim4.tick(0.0, 4000.0, 4000.2, 5.0, 3000.0)
    sim4.tinh_swap(3)
    if abs(sim4.swap_tong - (-56.0 * 0.01 * 3)) > 1e-9 or abs(sim4.tha_noi() - (-0.2 - 1.68)) > 1e-6:
        loi.append(f"swap tính sai: {sim4.swap_tong}, thả nổi {sim4.tha_noi()}")
    # bảng hệ số kiểu Hydra
    lb = [lot_tang(ThamSo(bang_lot=True), i) for i in range(10)]
    if lb != [0.01, 0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.03, 0.03]:
        loi.append(f"lot theo bảng Hydra sai: {lb}")
    if lot_tang(ThamSo(he_so=1.3, lot_max=0.2), 30) != 0.2:
        loi.append("trần lot mỗi tầng không có tác dụng")
    # tầng bị cắt: cách duyệt nhanh phải cho đúng kết quả như vòng for đầy đủ của EA
    rng = np.random.default_rng(7)
    sim5 = MoPhong(ThamSo(so_tang=40))
    for _ in range(20000):
        h = 1 if rng.random() < 0.5 else -1
        sim5.b = Basket(h, 4000.0 + rng.normal() * 3, float(rng.choice([1.5, 6.0, 7.3, 0.9])), 1.0, 0.0)
        truoc = sim5.b.p0 + rng.normal() * 40
        p = truoc + rng.normal() * (25 if rng.random() < 0.5 else 3)
        if rng.random() < 0.1:
            p = sim5.gia_tang(int(rng.integers(1, 40)))        # giá đúng bằng mức tầng
        du = [i for i in range(1, 40) if ((p <= sim5.gia_tang(i) and truoc > sim5.gia_tang(i)) if h > 0
                                          else (p >= sim5.gia_tang(i) and truoc < sim5.gia_tang(i)))]
        if sim5.tang_bi_cat(truoc, p) != du:
            loi.append(f"duyệt tầng nhanh sai: {sim5.tang_bi_cat(truoc, p)} ≠ {du}")
            break
    # margin level 500%: vốn 20, margin 0,01 lot ở giá 4000 = 2; sau khi lỗ 6 USD, ML của lệnh DCA thứ hai < 500%
    sim6 = MoPhong(ThamSo(von=20.0, spread=0.2, swap_long=0.0))
    for k, g in enumerate([4000.0] * 2 + list(np.arange(3999.0, 3990.0, -1.0)) + [3990.0] * 4):
        sim6.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
    if sim6.b is None or len(sim6.b.tang) != 1 or sim6.tick_chan_ml == 0:
        loi.append("không chặn DCA khi margin level sau lệnh < 500%")
    sim6b = MoPhong(ThamSo(von=5000.0, spread=0.2, swap_long=0.0))
    for k, g in enumerate([4000.0] * 2 + list(np.arange(3999.0, 3990.0, -1.0)) + [3990.0] * 4):
        sim6b.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
    if sim6b.b is None or len(sim6b.b.tang) != 2 or sim6b.tick_chan_ml != 0:
        loi.append("vốn đủ mà DCA vẫn bị chặn margin")
    # số lệnh tối đa mỗi ngày
    sim7 = MoPhong(ThamSo(lenh_ngay=1, spread=0.2, swap_long=0.0))
    for k, g in enumerate([4000.0] * 2 + list(np.arange(3999.0, 3990.0, -1.0)) + [3990.0] * 4):
        sim7.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
    if sim7.b is None or len(sim7.b.tang) != 1 or sim7.tick_chan_ngay == 0:
        loi.append("không chặn lệnh khi đủ số lệnh trong ngày")
    # InpTiaLapLai: tầng 1 đã tỉa thì (tắt) không mở lại, (bật) mở lại khi giá quay xuống
    duong = [4000.0] * 2 + [3996.0, 3993.9, 3993.9, 3993.9, 3997.0, 4000.1, 4000.1, 3996.0, 3993.9, 3993.9, 3993.9]
    for lap, can in ((True, 2), (False, 1)):
        sim8 = MoPhong(ThamSo(tia_lap_lai=lap, trail=False, tp_atr=50.0, xoa=False, spread=0.0001, swap_long=0.0))
        mo = 0
        for k, g in enumerate(duong):
            n0 = sim8.id
            sim8.tick(30.0 * k, g, g + 0.0001, 5.0, 3000.0)
            mo += sim8.id - n0
        if mo - 1 != can:
            loi.append(f"InpTiaLapLai={lap}: số lệnh DCA {mo - 1}, cần {can}")
    # đường giá nội suy: bắt đầu ở giá mở, qua hai cực trị, kết thúc ở giá đóng, mỗi bước ≤ delta, thời gian tăng dần
    rng = np.random.default_rng(3)
    o = 4000 + rng.normal(0, 3, 300)
    c = o + rng.normal(0, 4, 300)
    h = np.maximum(o, c) + np.abs(rng.normal(0, 3, 300))
    l = np.minimum(o, c) - np.abs(rng.normal(0, 3, 300))
    h[:5] = l[:5] = o[:5] = c[:5] = 4000.0                         # nến phẳng
    for delta in (0.5, 0.0):
        dem, g, gy = duong_gia(o, h, l, c, delta)
        dau = np.r_[0, np.cumsum(dem)]
        for k in range(300):
            gk, yk = g[dau[k]:dau[k + 1]], gy[dau[k]:dau[k + 1]]
            dung = (abs(gk[0] - o[k]) < 1e-9 and abs(gk[-1] - c[k]) < 1e-9 and abs(gk.max() - h[k]) < 1e-9
                    and abs(gk.min() - l[k]) < 1e-9 and yk[0] == 0.0 and yk[-1] <= 59.0 + 1e-9 and np.all(np.diff(yk) >= -1e-9))
            if delta > 0:
                dung = dung and np.max(np.abs(np.diff(gk))) <= delta + 1e-9
            else:
                dung = dung and len(gk) == 4 and list(yk) == [0.0, 15.0, 30.0, 45.0]
            if not dung:
                loi.append(f"đường giá nội suy sai ở nến {k} (delta {delta})")
                break
    # thả nổi tính theo tổng = cộng từng lệnh (có hedge, tỉa, đóng một phần, swap)
    sim9 = MoPhong(ThamSo(he_so=1.2, hedge=True, spread=0.2, swap_long=-56.0))
    duong9 = [4000.0] * 2 + list(np.arange(3999.0, 3920.0, -0.7)) + list(np.arange(3921.0, 3960.0, 0.9)) + [3960.0] * 50
    for k, g in enumerate(duong9):
        sim9.tick(15.0 * k, g, g + 0.2, 5.0, 3000.0)
        if k % 40 == 0:
            sim9.tinh_swap(1)
        if sim9.b is not None and (abs(sim9.tha_noi() - sim9.tha_noi_tung_lenh()) > 1e-6 or
                                   abs(sim9.lot_ro() - round(sum(v.lot for v in sim9.b.tang.values()), 2)) > 1e-9 or
                                   abs(sim9.lot_hd() - round(sum(v.lot for v in sim9.b.hd), 2)) > 1e-9):
            loi.append(f"thả nổi / lot theo tổng khác cộng từng lệnh ở tick {k}")
            break
    # TP phía server khớp đúng giá TP dù giá vượt qua
    sim10 = MoPhong(ThamSo(trail=False, tp_atr=50.0, xoa=False, spread=0.0001, swap_long=0.0))
    sim10.tick(0.0, 4000.0, 4000.0001, 5.0, 3000.0)
    sim10.tick(30.0, 3993.0, 3993.0001, 5.0, 3000.0)                # tầng 1 (mức 3994,0001) mở tại 3993,0001, TP 4000,0001
    v1 = sim10.b.tang.get(1)
    tp1 = v1.tp if v1 is not None else None
    chot0 = sim10.chot
    sim10.tick(60.0, 4003.0, 4003.0001, 5.0, 3000.0)                # Bid vượt TP tầng 1 (chưa tới TP tầng 0 = 4006,0001)
    if v1 is None or abs(sim10.chot - chot0 - (tp1 - v1.gia) * 0.01 * VPL) > 1e-6:
        loi.append(f"TP không khớp đúng giá TP: chốt {sim10.chot - chot0:.4f}, cần {(tp1 - v1.gia) * 0.01 * VPL if v1 else 0:.4f}")
    # tiền mỗi ngày và khối lượng: chạy chay() trên 3 ngày nến giả; tổng lãi các ngày = lãi ròng, khối lượng = tổng lot mở
    t = pd.date_range("2026-01-05 00:00", periods=3 * 1440, freq="1min")
    x = np.arange(len(t))
    gia = 4000 + 8 * np.sin(x / 90.0) - 0.004 * x
    m1g = pd.DataFrame(dict(time=t, open=gia, high=gia + 0.6, low=gia - 0.6, close=gia + 0.1, spread_points=260))
    m1g["atr5"], m1g["ct"], m1g["s49"], m1g["sat_nghi"] = 3.0, 0, 3000.0 * 49, False
    m1g["ngay"] = m1g["time"].dt.normalize()
    m1g["thang"] = m1g["time"].dt.to_period("M").astype(str)
    ts11 = ThamSo(he_so=1.2, spread=0.2, swap_long=-56.0)
    sim11, eq11 = chay(m1g, ts11)
    r11 = tom_tat(sim11, eq11, ts11)
    mo_lot = sum(v.lot for v in (list(sim11.b.tang.values()) + sim11.b.hd)) if sim11.b else 0.0
    if r11.get("so_ngay") != 3 or abs(r11["lai_ngay_tb"] * 3 - r11["net"]) > 0.05 or r11["lot_gd"] < mo_lot - 1e-9 \
            or r11["lot_gd"] <= 0 or abs(r11["lot_ngay"] * 3 - r11["lot_gd"]) > 0.02:
        loi.append(f"lãi mỗi ngày / khối lượng sai: {r11}")
    print("TỰ KIỂM TRA:", "ĐẠT" if not loi else "LỖI")
    for x in loi:
        print("  -", x)
    return 0 if not loi else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1")
    ap.add_argument("--out")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        return tu_kiem_tra()
    m1 = chuan_bi(a.m1)
    cac = [("Tắt hedge (như V0.21), lot 1,2", ThamSo(he_so=1.2)),
           ("V0.22 hiện tại, lot 1,2", ThamSo(he_so=1.2, hedge=True)),
           ("Tắt hedge (như V0.21), lot đều", ThamSo()),
           ("V0.22 hiện tại, lot đều", ThamSo(hedge=True))]
    dong = []
    for ten, ts in cac:
        sim, eq = chay(m1, ts)
        r = tom_tat(sim, eq, ts)
        r["cau_hinh"] = ten
        dong.append(r)
        print(r, flush=True)
    df = pd.DataFrame(dong)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        df.to_csv(os.path.join(a.out, "mo_phong_v022_so_sanh.csv"), index=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
