# ClipStack

**A tiny, fast, native macOS clipboard-history manager.** Lives in the menu bar,
remembers what you copy — text, images, and files — and pastes it back with a
keystroke. Written in Swift + AppKit, no dependencies, one small binary.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black)
![Language](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Features

- 📋 **Captures everything you copy** — plain text, images, and files — newest first, up to 100 items.
- ⌨️ **Quick-paste chords** — grab a recent item without ever leaving the keyboard (see below).
- 🖼️ **Rich previews** — image thumbnails and Finder file icons in both the menu and the quick-paste HUD.
- 💾 **Survives restarts** — history is persisted to disk (`~/Library/Application Support/ClipStack`), images included.
- 🔒 **Skips secrets** — items flagged concealed/transient by password managers (1Password, Keychain, …) are never captured or written to disk.
- 🚀 **Launch at login** — one toggle in the menu.
- 🪶 **Lightweight & native** — menu-bar only (no Dock icon), no frameworks, ~250 KB.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| **⌘⌃V** | Open the clipboard menu |
| **⌘⌃1** … **⌘⌃9** | Instantly paste history item 1–9 |
| **⌘⌃↑ / ⌘⌃↓** | Hold to show a HUD, cycle the selection, **release to paste** |

Quick-paste fires the moment you **release ⌘⌃** — you can't cleanly inject a paste
while those modifiers are still held, so ClipStack waits the split second until
they're up. For a number tap that feels instant; for the arrow-cycle it's the
natural "let go to paste."

While the menu is open you can also type a letter to jump, or press ⌘1–9.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode command-line tools (`xcode-select --install`) — for `swiftc`

## Build & run

```bash
git clone https://github.com/champ3oy/ClipStack.git
cd ClipStack
./build.sh
cp -R build/ClipStack.app ~/Applications/
open ~/Applications/ClipStack.app
```

`build.sh` compiles the sources, assembles the `.app` bundle from `Info.plist`,
and ad-hoc-signs it. It builds for your Mac's architecture automatically.

### Making the Accessibility grant stick (optional)

Auto-paste needs Accessibility permission (below). macOS ties that grant to the
app's **code signature**, and an ad-hoc signature changes on every rebuild — so
you'd re-grant each time. To avoid that, sign with a stable self-signed identity:

```bash
# one-time: create a self-signed code-signing cert named "ClipStack Self-Signed"
# in Keychain Access ▸ Certificate Assistant ▸ Create a Certificate
#   (Identity Type: Self-Signed Root, Certificate Type: Code Signing)
CODESIGN_IDENTITY="ClipStack Self-Signed" ./build.sh
```

The grant then persists across rebuilds because the signing certificate — not the
exact binary — is what the permission is bound to.

## Permissions

Auto-paste works by simulating **⌘V** into the app you were last using, which
macOS gates behind **Accessibility**. On first launch you'll be prompted; enable
**ClipStack** under **System Settings ▸ Privacy & Security ▸ Accessibility**.

Without it, ClipStack still works — the selected item is placed on the clipboard,
you just press ⌘V yourself. (If a paste is attempted without permission, it shows
a one-time reminder and leaves the item on the clipboard.)

## Where your data lives

```
~/Library/Application Support/ClipStack/
├── history.json      # text, file paths, and metadata
└── blobs/<uuid>.png  # image bytes (images > 10 MB stay in memory only)
```

Everything is stored **locally**. Nothing leaves your machine. Copied files are
stored by path — move or delete the file and that entry won't resolve anymore.

## How it works

| File | Responsibility |
| --- | --- |
| `ClipStackApp.swift` | App entry point (SwiftUI `App`, accessory lifecycle) |
| `AppDelegate.swift` | Menu-bar item, dropdown menu, hotkey wiring, paste + Accessibility prompt |
| `ClipboardStore.swift` | Pasteboard polling, capped history, capture/paste of text·image·files, secret filtering |
| `ClipboardItem.swift` | History entry (`text` / `image` / `files`) + single-line preview |
| `HistoryPersistence.swift` | Load/save `history.json` + image blobs |
| `HotKey.swift` | `HotKeyCenter` — global Carbon hotkeys, dispatched by id |
| `QuickPasteController.swift` | ⌘⌃ chord logic, commit-on-release, HUD driving |
| `QuickPasteSelection.swift` | Pure selection math (unit-tested) |
| `QuickPasteHUD.swift` | Non-activating floating HUD panel + row view |
| `LoginItem.swift` | Launch-at-login via `SMAppService` |

The clipboard has no "changed" event on macOS, so ClipStack polls the pasteboard
every 0.5s. Global shortcuts use the Carbon hotkey API (no permission needed);
only the synthetic paste needs Accessibility.

## Roadmap

- [ ] Search / filter within the menu
- [ ] Configurable hotkeys and history size
- [ ] Pin favorites
- [ ] Rich-text / RTF capture

## License

[MIT](LICENSE) © cirlorm
