import AppKit
import ApplicationServices

/// Drives the ⌘⌃ quick-paste chord:
///   ⌘⌃1–9        → select that history item
///   ⌘⌃↓ / ⌘⌃↑    → pop a HUD and cycle the selection
/// The paste fires when ⌘⌃ is released (you can't inject a clean ⌘V while the
/// user still holds ⌘⌃), detected by polling the live modifier state — so no
/// extra Input-Monitoring permission is needed.
@MainActor
final class QuickPasteController {
    private let store: ClipboardStore
    private let hud = QuickPasteHUD()
    private let maxVisible = 9

    private var selection: QuickPasteSelection?
    private var pollTimer: Timer?
    private var hudVisible = false

    // cmdKey | controlKey
    private let cmdCtrl: UInt32 = 0x0100 | 0x1000

    init(store: ClipboardStore) {
        self.store = store
    }

    func registerHotKeys() {
        // ⌘⌃ + 1…9  (ANSI digit key codes)
        let digits: [UInt32] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        for (i, code) in digits.enumerated() {
            let n = i + 1
            HotKeyCenter.shared.register(keyCode: code, modifiers: cmdCtrl) { [weak self] in
                self?.onNumber(n)
            }
        }
        // ⌘⌃ + Down / Up
        HotKeyCenter.shared.register(keyCode: 0x7D, modifiers: cmdCtrl) { [weak self] in
            self?.onArrow(down: true)
        }
        HotKeyCenter.shared.register(keyCode: 0x7E, modifiers: cmdCtrl) { [weak self] in
            self?.onArrow(down: false)
        }
    }

    private func visibleItems() -> [ClipboardItem] {
        Array(store.items.prefix(maxVisible))
    }

    // MARK: - Chord input

    private func onNumber(_ n: Int) {
        let items = visibleItems()
        guard !items.isEmpty else { return }
        beginSessionIfNeeded(count: items.count)
        selection?.setNumber(n)
        if hudVisible { hud.show(items: items, selected: selection?.index ?? 0) }
    }

    private func onArrow(down: Bool) {
        let items = visibleItems()
        guard !items.isEmpty else { return }
        beginSessionIfNeeded(count: items.count)
        if down { selection?.moveDown() } else { selection?.moveUp() }
        hudVisible = true
        hud.show(items: items, selected: selection?.index ?? 0)
    }

    private func beginSessionIfNeeded(count: Int) {
        guard selection == nil else { return }
        selection = QuickPasteSelection(count: count)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkRelease() }
        }
    }

    // MARK: - Commit on release

    private func checkRelease() {
        // NSEvent.modifierFlags reflects the last event *this app* received, which
        // is stale here — ClipStack gets no key events while another app is focused.
        // Read the live hardware state instead.
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let held = flags.contains(.maskCommand) && flags.contains(.maskControl)
        if !held { commit() }
    }

    private func commit() {
        pollTimer?.invalidate(); pollTimer = nil
        let chosen = selection?.index
        selection = nil
        if hudVisible { hud.hide(); hudVisible = false }

        guard let idx = chosen else { return }
        let items = visibleItems()
        guard idx < items.count else { return }

        store.write(items[idx])          // focus never left the target app
        guard AXIsProcessTrusted() else {
            NSLog("ClipStack: quick-paste needs Accessibility; item left on clipboard")
            return
        }
        // Modifiers just released — let the key-ups settle, then post ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.store.sendPaste()
        }
    }
}
