# Sao chep file nay thanh config.py roi dien thong tin that vao.
# config.py KHONG duoc commit len git (da liet ke trong .gitignore).

# --- Telegram ---
# Lay API_ID / API_HASH tai https://my.telegram.org -> API development tools
# Dang nhap bang chinh tai khoan CA NHAN cua ban (tai khoan da la thanh vien
# nhom can doc), khong can quyen admin/comment trong nhom.
API_ID = 12345678
API_HASH = "your_api_hash_here"
SESSION_NAME = "telegram_copier_session"

# ID cua nhom can doc tin hieu.
# Chay list_my_groups.py mot lan (sau khi dang nhap) de lay dung ID nhom ban da tham gia.
GROUP_ID = -1001234567890

# --- MT5 ---
# Map ten symbol xuat hien trong tin nhan -> symbol that tren san cua ban
SYMBOL_MAP = {
    "GOLD": "XAUUSDc",
    "XAUUSD": "XAUUSDc",
}

MAGIC_NUMBER = 990001

# --- Quan ly von ---
RISK_PERCENT_PER_SIGNAL = 1.0   # % equity chap nhan rui ro cho MOI tin hieu (tong ca 3 lenh)
NUM_LEGS = 3                     # chia lenh cho TP1, TP2, TP3 (bo qua TP4, TP5)

# --- An toan ---
# True: chi log ra console, KHONG dat lenh that. Chi doi thanh False sau khi
# da kiem tra ky log DRY_RUN khop voi ky vong cua ban.
DRY_RUN = True
