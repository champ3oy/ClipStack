# ClipStack

A tiny, fast, native macOS clipboard-history manager. It lives in the menu bar, remembers what you copy (text, images, and files), and pastes it back with a keystroke. Written in Swift and AppKit with no dependencies.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black)
![Language](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- Captures plain text, images, and files. Newest first, up to 100 items.
- Quick-paste chords to grab a recent item without leaving the keyboard.
- Rich previews: image thumbnails and Finder file icons in the menu and quick-paste HUD.
- Survives restarts: history persists to disk, images included.
- Skips secrets: items flagged concealed or transient by password managers are never captured or written to disk.
- Launch at login with one toggle.
- Lightweight and native: menu-bar only, no Dock icon, no frameworks, about 250 KB.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘⌃V | Open the clipboard menu |
| ⌘⌃1 through ⌘⌃9 | Paste history item 1 to 9 |
| ⌘⌃↑ / ⌘⌃↓ | Hold to show a HUD, cycle the selection, release to paste |

Quick-paste fires when you release ⌘⌃. ClipStack waits until the modifiers are up before injecting the paste.

While the menu is open, type a letter to jump or press ⌘1 to ⌘9.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode command-line tools (`xcode-select --install`) for `swiftc`

## Build and run

```bash
git clone https://github.com/champ3oy/ClipStack.git
cd ClipStack
./build.sh
cp -R build/ClipStack.app ~/Applications/
open ~/Applications/ClipStack.app
```

`build.sh` compiles the sources, assembles the `.app` bundle from `Info.plist`, and ad-hoc-signs it for your Mac's architecture.

### Keep the Accessibility grant across rebuilds (optional)

Auto-paste needs Accessibility permission, which macOS ties to the app's code signature. An ad-hoc signature changes on every rebuild, so you would re-grant each time. Sign with a stable self-signed identity instead:

```bash
CODESIGN_IDENTITY="ClipStack Self-Signed" ./build.sh
```

Create the "ClipStack Self-Signed" certificate in Keychain Access first (Certificate Assistant > Create a Certificate, Code Signing type). The grant then persists across rebuilds because the permission is bound to the certificate, not the exact binary.

## Permissions

Auto-paste simulates ⌘V into the app you were last using, which macOS gates behind Accessibility. On first launch you are prompted. Enable ClipStack under System Settings > Privacy & Security > Accessibility.

Without the grant, ClipStack still works: the selected item is placed on the clipboard and you press ⌘V yourself.

## Where your data lives

```
~/Library/Application Support/ClipStack/
├── history.json      # text, file paths, and metadata
└── blobs/<uuid>.png  # image bytes (images over 10 MB stay in memory only)
```

Everything is stored locally. Nothing leaves your machine.

## How it works

| File | Responsibility |
| --- | --- |
| `ClipStackApp.swift` | App entry point |
| `AppDelegate.swift` | Menu-bar item, menu, hotkeys, paste and Accessibility prompt |
| `ClipboardStore.swift` | Pasteboard polling, capped history, capture and paste of text, images and files |
| `ClipboardItem.swift` | History entry and single-line preview |
| `HistoryPersistence.swift` | Load and save history plus image blobs |
| `HotKey.swift` | Global Carbon hotkeys |
| `QuickPasteController.swift` | Chord logic, commit on release, HUD |
| `QuickPasteSelection.swift` | Pure selection math (unit-tested) |
| `QuickPasteHUD.swift` | Floating HUD panel and row view |
| `LoginItem.swift` | Launch at login via SMAppService |

macOS has no "clipboard changed" event, so ClipStack polls the pasteboard every 0.5 seconds. Global shortcuts use the Carbon hotkey API. Only the synthetic paste needs Accessibility.

## Roadmap

- Search and filter within the menu
- Configurable hotkeys and history size
- Pin favorites
- Rich-text and RTF capture

## License

[MIT](LICENSE) © cirlorm
