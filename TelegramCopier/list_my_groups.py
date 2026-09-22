"""Chay mot lan de tim GROUP_ID cua nhom Telegram can doc tin hieu.

Lan dau chay se hoi so dien thoai + ma OTP Telegram gui ve (nhap ngay trong
terminal). Cac lan sau dung lai session da luu, khong hoi lai.

Chay:
    python list_my_groups.py
"""
import asyncio

from telethon import TelegramClient

import config


async def main():
    async with TelegramClient(config.SESSION_NAME, config.API_ID, config.API_HASH) as client:
        print(f"{'ID':<20}{'Ten':<50}{'Loai'}")
        async for dialog in client.iter_dialogs():
            if dialog.is_group or dialog.is_channel:
                kind = "channel" if dialog.is_channel else "group"
                print(f"{dialog.id:<20}{dialog.name:<50}{kind}")


if __name__ == "__main__":
    asyncio.run(main())
