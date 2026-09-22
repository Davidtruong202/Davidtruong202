"""Doc tin hieu tu mot nhom Telegram (da la thanh vien, khong can quyen
comment/admin) va tu dong vao lenh tren MT5 theo % rui ro tai khoan.

Dinh dang tin hieu ho tro (vi du that tu nhom):

    BEST SIGNAL FOREX
    GOLD SELL 4359/4364

    TP1 4353
    TP2 4347
    TP3 4342
    TP4 4329
    TP5 4310

    SL: 4371

    USE LOT ACCORDING TO EQUITY

Chi lay TP1/TP2/TP3, bo qua TP4/TP5. Tong lot cho ca 3 lenh duoc tinh tu
RISK_PERCENT_PER_SIGNAL % equity tai khoan, chia deu cho 3 lenh, moi lenh
dung chung SL, rieng TP.

Yeu cau chay tren CHINH may Windows dang mo terminal MT5 (package
MetaTrader5 giao tiep voi terminal qua IPC noi bo, khong hoat dong tu xa).

Cai dat:
    pip install -r requirements.txt

Cau hinh:
    Sao chep config.example.py -> config.py va dien thong tin that.
    Chay list_my_groups.py mot lan de lay dung GROUP_ID.

Chay:
    python telegram_mt5_copier.py
"""
from __future__ import annotations

import asyncio
import logging
import re
from dataclasses import dataclass
from typing import Optional

import MetaTrader5 as mt5
from telethon import TelegramClient, events

import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("copier")

SYMBOL_RE = re.compile(
    r"(GOLD|XAU\s?USD)\s+(BUY|SELL)\s+([\d.]+)\s*(?:/\s*([\d.]+))?",
    re.IGNORECASE,
)
TP_RE = re.compile(r"TP\s*([1-5])\D{0,3}([\d]+(?:\.\d+)?)", re.IGNORECASE)
SL_RE = re.compile(r"\bSL\D{0,3}([\d]+(?:\.\d+)?)", re.IGNORECASE)


@dataclass
class Signal:
    symbol_raw: str
    direction: str  # "BUY" hoac "SELL"
    entry_low: float
    entry_high: float
    sl: float
    tps: dict  # {so_tp: gia}


def parse_signal(text: str) -> Optional[Signal]:
    sym_match = SYMBOL_RE.search(text)
    sl_match = SL_RE.search(text)
    if not sym_match or not sl_match:
        return None

    tps = {int(n): float(p) for n, p in TP_RE.findall(text)}
    if not tps:
        return None

    symbol_raw = sym_match.group(1).upper().replace(" ", "")
    direction = sym_match.group(2).upper()
    entry_a = float(sym_match.group(3))
    entry_b = float(sym_match.group(4)) if sym_match.group(4) else entry_a

    return Signal(
        symbol_raw=symbol_raw,
        direction=direction,
        entry_low=min(entry_a, entry_b),
        entry_high=max(entry_a, entry_b),
        sl=float(sl_match.group(1)),
        tps=tps,
    )


def resolve_symbol(symbol_raw: str) -> Optional[str]:
    return config.SYMBOL_MAP.get(symbol_raw)


def calc_total_lot(symbol: str, sl_distance: float) -> Optional[float]:
    info = mt5.symbol_info(symbol)
    account = mt5.account_info()
    if info is None or account is None:
        log.error("Khong lay duoc symbol_info/account_info cho %s", symbol)
        return None

    if info.trade_tick_size == 0:
        log.error("trade_tick_size = 0 cho %s, khong tinh duoc lot", symbol)
        return None

    ticks = sl_distance / info.trade_tick_size
    money_risk_per_lot = ticks * info.trade_tick_value
    if money_risk_per_lot <= 0:
        return None

    risk_money = account.equity * (config.RISK_PERCENT_PER_SIGNAL / 100)
    return risk_money / money_risk_per_lot


def round_volume(symbol: str, volume: float) -> float:
    info = mt5.symbol_info(symbol)
    step = info.volume_step
    volume = max(info.volume_min, min(info.volume_max, volume))
    steps = round(volume / step)
    return round(steps * step, 2)


def execute_signal(signal: Signal) -> None:
    symbol = resolve_symbol(signal.symbol_raw)
    if symbol is None:
        log.warning("Khong co mapping symbol cho '%s', bo qua tin hieu", signal.symbol_raw)
        return

    if not mt5.symbol_select(symbol, True):
        log.error("Khong select duoc symbol %s tren MT5", symbol)
        return

    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        log.error("Khong lay duoc gia hien tai cho %s", symbol)
        return

    is_buy = signal.direction == "BUY"
    order_type = mt5.ORDER_TYPE_BUY if is_buy else mt5.ORDER_TYPE_SELL
    price = tick.ask if is_buy else tick.bid

    sl_distance = abs(price - signal.sl)
    total_lot = calc_total_lot(symbol, sl_distance)
    if not total_lot or total_lot <= 0:
        log.error("Tinh lot that bai cho tin hieu %s", signal)
        return

    legs = sorted(signal.tps.items())[: config.NUM_LEGS]
    if not legs:
        log.warning("Tin hieu khong co TP nao trong %d muc dau, bo qua", config.NUM_LEGS)
        return

    per_leg_lot = round_volume(symbol, total_lot / len(legs))

    log.info(
        "Tin hieu %s %s | entry~%.2f-%.2f | SL=%.2f | risk=%.1f%% equity | "
        "total_lot~%.2f | %d lenh x %.2f lot",
        signal.direction, symbol, signal.entry_low, signal.entry_high,
        signal.sl, config.RISK_PERCENT_PER_SIGNAL, total_lot, len(legs), per_leg_lot,
    )

    for tp_number, tp_price in legs:
        if config.DRY_RUN:
            log.info(
                "[DRY_RUN] Se vao %s %s lot=%.2f SL=%.2f TP%d=%.2f",
                signal.direction, symbol, per_leg_lot, signal.sl, tp_number, tp_price,
            )
            continue

        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": per_leg_lot,
            "type": order_type,
            "price": price,
            "sl": signal.sl,
            "tp": tp_price,
            "deviation": 20,
            "magic": config.MAGIC_NUMBER,
            "comment": f"TG-TP{tp_number}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            log.error("order_send loi TP%d: %s", tp_number, result)
        else:
            log.info("Da vao lenh TP%d, ticket=%d, lot=%.2f", tp_number, result.order, per_leg_lot)


async def main() -> None:
    if not mt5.initialize():
        log.error("Khong ket noi duoc MT5 terminal: %s", mt5.last_error())
        return
    log.info("Da ket noi MT5, account=%s", mt5.account_info())

    client = TelegramClient(config.SESSION_NAME, config.API_ID, config.API_HASH)

    @client.on(events.NewMessage(chats=config.GROUP_ID))
    async def handler(event):
        text = event.raw_text
        signal = parse_signal(text)
        if signal is None:
            return
        log.info("Nhan tin hieu moi:\n%s", text)
        execute_signal(signal)

    await client.start()
    log.info("Dang lang nghe nhom %s ...", config.GROUP_ID)
    await client.run_until_disconnected()


if __name__ == "__main__":
    asyncio.run(main())
