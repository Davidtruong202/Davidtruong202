# Telegram -> MT5 Signal Copier

Doc tin hieu tu mot nhom Telegram private ma ban DA la thanh vien (khong can
quyen admin/comment) va tu dong vao lenh tren MT5 theo % rui ro tai khoan.

Chi lay TP1/TP2/TP3 (bo qua TP4, TP5), chia deu lot cho 3 lenh, dung chung SL.

## Yeu cau

- Chay tren **chinh may Windows dang mo terminal MT5** (VPS cua ban). Package
  `MetaTrader5` giao tiep voi terminal qua IPC noi bo, khong hoat dong tu xa.
- Python 3.10+ da cai tren VPS.
- Terminal MT5 dang dang nhap san vao tai khoan giao dich.

## Cai dat

```bash
cd TelegramCopier
pip install -r requirements.txt
```

## Cau hinh

1. Sao chep `config.example.py` thanh `config.py`.
2. Lay `API_ID` / `API_HASH` tai https://my.telegram.org -> API development tools.
   Dang ky bang **chinh tai khoan Telegram ca nhan** cua ban (tai khoan da
   tham gia nhom can doc tin hieu).
3. Dien `API_ID`, `API_HASH` vao `config.py`.
4. Chay `python list_my_groups.py` mot lan de tim `GROUP_ID` cua nhom (lan
   dau se hoi so dien thoai + ma OTP Telegram gui ve, nhap ngay trong
   terminal; cac lan sau dung session da luu).
5. Dien `GROUP_ID` vao `config.py`.
6. Kiem tra `SYMBOL_MAP` khop voi ten symbol that tren san cua ban (vi du
   `XAUUSDc`).
7. Chinh `RISK_PERCENT_PER_SIGNAL` theo khau vi rui ro cua ban.

## Chay thu an toan truoc (BAT BUOC)

`config.py` mac dinh `DRY_RUN = True` — script chi doc tin hieu va **log ra
console**, khong dat lenh that. Chay:

```bash
python telegram_mt5_copier.py
```

Gui thu mot tin hieu test vao nhom (hoac doi tin that xuat hien), kiem tra
log in ra dung: symbol, huong lenh, SL, 3 muc TP, so lot tinh duoc co hop ly
khong. Chi khi da chac chan moi doi `DRY_RUN = False` trong `config.py` de
vao lenh that.

## Luu y

- Doc tin nhan cua nhom ma minh da la thanh vien la binh thuong, khong lien
  quan gi den quyen comment hay admin. Che do "chan luu noi dung" cua nhom
  (neu admin bat) chi an nut Forward/Save tren giao dien, khong chan viec
  doc text qua API cua chinh tai khoan da tham gia.
- Nhieu nhom tin hieu tra phi co dieu khoan cam sao chep tu dong — nen kiem
  tra truoc voi nguoi dieu hanh nhom.
- Day la cong cu giao dich tu dong bang tien that — luon test ky voi
  `DRY_RUN = True` va lot nho truoc khi tin dung hoan toan.
