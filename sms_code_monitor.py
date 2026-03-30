#!/usr/bin/env python3
"""
短信验证码桌面提醒工具（菜单栏版）

在 macOS 菜单栏显示自定义图标：
  - 点击「开始接收验证码」→ 监听 3 分钟，期间自动检测验证码
  - 收到验证码 → 弹通知 + 自动复制到剪贴板，直接 Cmd+V 粘贴
  - 3 分钟后自动停止

使用前需授予终端「完全磁盘访问权限」：
  系统设置 > 隐私与安全性 > 完全磁盘访问权限 > 添加 Terminal.app
"""

import os
import re
import sys
import sqlite3
import subprocess
import threading

import rumps

# ── 配置 ──────────────────────────────────────────────
DB_PATH = os.path.expanduser("~/Library/Messages/chat.db")
POLL_INTERVAL = 3      # 轮询间隔（秒）
MONITOR_DURATION = 180  # 监听时长（秒）= 3 分钟

# ── 验证码正则 ────────────────────────────────────────
CODE_PATTERN = re.compile(
    r'(?:'
    r'(?:验证码|校验码|动态码|安全码|确认码|提取码|登录码|认证码)'
    r'|(?:verification\s*code|security\s*code|'
    r'confirm(?:ation)?\s*code|'
    r'code\s*is|code\s*[:：]|your\s*code|PIN\s*code)'
    r')'
    r'[：:）)\s\]】]*'
    r'(\d{4,8})',
    re.IGNORECASE
)

KEYWORD_PATTERN = re.compile(
    r'验证码|校验码|动态码|code|verify|OTP|认证|登录码',
    re.IGNORECASE
)
DIGIT_PATTERN = re.compile(r'(?<!\d)(\d{4,8})(?!\d)')


def extract_code(text: str) -> str | None:
    if not text:
        return None
    m = CODE_PATTERN.search(text)
    if m:
        return m.group(1)
    if KEYWORD_PATTERN.search(text):
        m = DIGIT_PATTERN.search(text)
        if m:
            return m.group(1)
    return None


# ── macOS 通知 & 剪贴板 ──────────────────────────────
def notify(title: str, message: str):
    safe_title = title.replace('\\', '\\\\').replace('"', '\\"')
    safe_msg = message.replace('\\', '\\\\').replace('"', '\\"')
    script = (
        f'display notification "{safe_msg}" '
        f'with title "{safe_title}" '
        f'sound name "default"'
    )
    subprocess.run(["osascript", "-e", script], capture_output=True)


def copy_to_clipboard(text: str):
    subprocess.run(["pbcopy"], input=text.encode(), check=True)


# ── 数据库操作 ────────────────────────────────────────
def open_db():
    uri = f"file:{DB_PATH}?mode=ro"
    return sqlite3.connect(uri, uri=True)


def get_max_rowid() -> int:
    conn = open_db()
    try:
        result = conn.execute("SELECT MAX(ROWID) FROM message").fetchone()[0]
        return result or 0
    finally:
        conn.close()


def fetch_new_messages(since_rowid: int) -> list[tuple]:
    conn = open_db()
    try:
        cursor = conn.execute(
            """
            SELECT message.ROWID, message.text, handle.id AS sender
            FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            WHERE message.ROWID > ?
              AND message.is_from_me = 0
            ORDER BY message.ROWID ASC
            """,
            (since_rowid,),
        )
        return cursor.fetchall()
    finally:
        conn.close()


# ── 图标路径 ──────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ICON_PATH = os.path.join(SCRIPT_DIR, "icon.png")


# ── 菜单栏应用 ────────────────────────────────────────
class SMSCodeApp(rumps.App):
    def __init__(self):
        icon = ICON_PATH if os.path.exists(ICON_PATH) else None
        super().__init__("", icon=icon, template=True, quit_button="退出")
        self.menu = [
            rumps.MenuItem("开始接收验证码", callback=self.start_monitor),
        ]
        self._monitoring = False
        self._stop_event = threading.Event()

    def start_monitor(self, sender):
        if self._monitoring:
            return

        # 检查权限
        if not os.path.exists(DB_PATH):
            rumps.alert("错误", "找不到短信数据库，请确认 iPhone 已开启 iMessage 同步。")
            return
        try:
            open_db().close()
        except sqlite3.OperationalError:
            rumps.alert(
                "需要授权",
                "请在「系统设置 > 隐私与安全性 > 完全磁盘访问权限」中添加 Terminal.app，然后重启终端。"
            )
            return

        self._monitoring = True
        self._stop_event.clear()
        self.icon = None
        self.title = "📩 3:00"
        sender.title = "监听中… (3分钟)"
        notify("验证码监听已开启", "接下来 3 分钟内收到的验证码会自动弹出并复制")

        thread = threading.Thread(target=self._poll_loop, args=(sender,), daemon=True)
        thread.start()

    def _poll_loop(self, menu_item):
        last_rowid = get_max_rowid()
        elapsed = 0

        while elapsed < MONITOR_DURATION and not self._stop_event.is_set():
            try:
                messages = fetch_new_messages(last_rowid)
                for rowid, text, sender_id in messages:
                    last_rowid = max(last_rowid, rowid)
                    code = extract_code(text)
                    if code:
                        sender_display = sender_id or "未知号码"
                        notify("收到验证码", f"验证码: {code}\n来自: {sender_display}")
                        copy_to_clipboard(code)
            except Exception:
                pass

            remaining = MONITOR_DURATION - elapsed
            mins, secs = divmod(remaining, 60)
            self.title = f"📩 {mins}:{secs:02d}"

            self._stop_event.wait(POLL_INTERVAL)
            elapsed += POLL_INTERVAL

        # 监听结束
        self.title = ""
        if os.path.exists(ICON_PATH):
            self.icon = ICON_PATH
        menu_item.title = "开始接收验证码"
        self._monitoring = False
        notify("监听已结束", "3 分钟验证码监听已停止")


# ── 入口 ──────────────────────────────────────────────
def main():
    SMSCodeApp().run()


if __name__ == "__main__":
    main()
