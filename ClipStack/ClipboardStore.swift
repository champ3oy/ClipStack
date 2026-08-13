import AppKit
import Combine

/// Polls the system pasteboard, keeps a capped history (text / image / files),
/// persists it to disk, and writes selections back.
@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastWrittenChangeCount: Int = -1
    private let maxItems = 100
    private let persistence: HistoryPersistence

    // nspasteboard.org markers set by password managers — never captured.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    init(persistence: HistoryPersistence = HistoryPersistence()) {
        self.persistence = persistence
    }

    func start() {
        items = persistence.load()
        lastChangeCount = pasteboard.changeCount
        // macOS has no reliable "clipboard changed" event, so we poll.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Capture

    func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        // Don't capture writes we made ourselves.
        guard changeCount != lastWrittenChangeCount else { return }

        // Skip anything a password manager flagged as secret/transient.
        if let types = pasteboard.types,
           types.contains(Self.concealedType) || types.contains(Self.transientType) {
            return
        }

        guard let content = readContent() else { return }
        insert(content)
    }

    /// Read the richest available representation: files > image > text.
    private func readContent() -> ClipboardContent? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return .files(urls)
        }
        if let data = imageData() {
            return .image(data)
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .text(text)
        }
        return nil
    }

    /// Normalize whatever image is on the pasteboard to PNG bytes.
    private func imageData() -> Data? {
        guard let img = NSImage(pasteboard: pasteboard),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }

    private func insert(_ content: ClipboardContent) {
        // Skip an exact duplicate of the current top item.
        if let first = items.first, first.content == content { return }
        items.insert(ClipboardItem(content: content, date: Date()), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        persist()
    }

    // MARK: - Use

    /// Put an item on the pasteboard and move it to the top of history.
    /// Does NOT simulate a paste — call `sendPaste()` after re-activating the target app.
    func write(_ item: ClipboardItem) {
        lastWrittenChangeCount = pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .png)
            if let img = NSImage(data: data), let tiff = img.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
        lastWrittenChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let moved = items.remove(at: index)
            items.insert(moved, at: 0)
            persist()
        }
    }

    /// Post a synthetic Cmd+V. Requires Accessibility permission.
    func sendPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode = 0x09 // V

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func persist() {
        persistence.save(items)
    }
}
