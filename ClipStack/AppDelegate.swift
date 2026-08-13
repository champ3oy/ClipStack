import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var quickPaste: QuickPasteController?
    private let store = ClipboardStore()
    private let menu = NSMenu()
    private var didWarnAccessibility = false

    /// How many recent entries to show in the dropdown (history keeps more).
    private let maxMenuItems = 20
    /// Truncate long previews so menu rows stay a sane width.
    private let titleMaxChars = 52

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        store.start()
        quickPaste = QuickPasteController(store: store)
        registerHotKeys()
        promptForAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "ClipStack")
        }
        // Attaching the menu makes clicking the icon drop it down. The menu is
        // (re)built on demand via NSMenuDelegate so it always reflects history.
        menu.delegate = self
        item.menu = menu
    }

    private func registerHotKeys() {
        // ⌘⌃V opens the dropdown (cmdKey | controlKey).
        HotKeyCenter.shared.register(keyCode: 0x09, modifiers: 0x0100 | 0x1000) { [weak self] in
            self?.openMenu()
        }
        // ⌘⌃1–9 / ⌘⌃↑↓ quick-paste.
        quickPaste?.registerHotKeys()
    }

    /// Pop the status-item menu programmatically (from the global hotkey).
    private func openMenu() {
        statusItem?.button?.performClick(nil)
    }

    // MARK: - Menu contents

    private func rebuildMenu() {
        menu.removeAllItems()

        let recent = Array(store.items.prefix(maxMenuItems))
        if recent.isEmpty {
            let empty = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, clip) in recent.enumerated() {
                let mi = NSMenuItem(title: menuTitle(for: clip),
                                    action: #selector(selectItem(_:)),
                                    keyEquivalent: index < 9 ? "\(index + 1)" : "")
                if index < 9 { mi.keyEquivalentModifierMask = [.command] }
                mi.target = self
                mi.representedObject = clip
                mi.toolTip = clip.preview
                mi.image = icon(for: clip)
                menu.addItem(mi)
            }
        }

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at Login",
                               action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let clear = NSMenuItem(title: "Clear History",
                               action: #selector(clearHistory(_:)), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !store.items.isEmpty
        menu.addItem(clear)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit ClipStack",
                              action: #selector(quit(_:)), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
    }

    private func menuTitle(for clip: ClipboardItem) -> String {
        let preview = clip.preview
        guard preview.count > titleMaxChars else { return preview }
        return String(preview.prefix(titleMaxChars - 1)) + "…"
    }

    /// A small thumbnail (images) or Finder icon (files) for the row; nil for text.
    private func icon(for clip: ClipboardItem) -> NSImage? {
        switch clip.content {
        case .text:
            return nil
        case .image(let data):
            guard let img = NSImage(data: data) else { return nil }
            return thumbnail(img, fitting: 28)
        case .files(let urls):
            guard let first = urls.first else { return nil }
            let icon = NSWorkspace.shared.icon(forFile: first.path)
            icon.size = NSSize(width: 18, height: 18)
            return icon
        }
    }

    private func thumbnail(_ image: NSImage, fitting maxSide: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }

    // MARK: - Actions

    @objc private func selectItem(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipboardItem else { return }
        store.write(clip)              // now on the clipboard + promoted to top
        pasteIntoPreviousApp()
    }

    /// The dropdown returns focus to the previously-active app on its own, so we
    /// just wait a beat and post ⌘V — no manual re-activation needed.
    private func pasteIntoPreviousApp() {
        guard AXIsProcessTrusted() else {
            warnAccessibilityOnce()    // item is on the clipboard; user can ⌘V
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.store.sendPaste()
        }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func clearHistory(_ sender: NSMenuItem) {
        store.clear()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - Accessibility

    /// Auto-paste simulates Cmd+V, which needs Accessibility permission.
    private func promptForAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Shown at most once per launch when a paste is attempted without permission.
    private func warnAccessibilityOnce() {
        guard !didWarnAccessibility else { return }
        didWarnAccessibility = true

        let alert = NSAlert()
        alert.messageText = "Enable auto-paste for ClipStack"
        alert.informativeText = """
        The item is already on your clipboard — press ⌘V to paste it now.

        To paste automatically next time, grant ClipStack Accessibility permission \
        in System Settings ▸ Privacy & Security ▸ Accessibility.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }
}
