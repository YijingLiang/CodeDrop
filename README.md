# CodeDrop

A minimal macOS menu bar app that captures SMS verification codes from your iPhone — no server, no sign-up, fully local.

## How It Works

CodeDrop reads your Mac's local Messages database to detect incoming verification codes. When you click "Start", it monitors for new SMS messages for 3 minutes, extracts the code, copies it to your clipboard, and sends a desktop notification.

**One requirement:** Your iPhone and Mac must be signed in with the same Apple ID, and SMS Forwarding must be enabled on your iPhone.

> iPhone Settings → Messages → Text Message Forwarding → Enable your Mac

## Features

- One-click monitoring — watches for verification codes for 3 minutes
- Auto-copy to clipboard
- Desktop notifications with the code and sender
- Code history with one-tap copy
- Supports Chinese and English verification code formats
- Pure local processing — your messages never leave your Mac

## Tech Stack

- **SwiftUI** — native macOS menu bar app
- **SQLite3** — direct read from `~/Library/Messages/chat.db`
- **Regex-based extraction** — recognizes verification codes from common SMS patterns

## Setup

1. Open `CodeDrop.xcodeproj` in Xcode
2. Build and run (Cmd + R)
3. Grant **Full Disk Access** in System Settings → Privacy & Security → Full Disk Access
4. Click the drop icon in your menu bar to start

## Requirements

- macOS 13.0+
- Xcode 15+
- iPhone with SMS Forwarding enabled (same Apple ID)

## License

MIT
