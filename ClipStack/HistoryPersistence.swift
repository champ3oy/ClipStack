import AppKit

/// Loads/saves clipboard history under Application Support.
///
/// Text and file paths live in `history.json`; image bytes are written once
/// each as `blobs/<uuid>.png`. Images larger than `maxPersistedImageBytes`
/// are never written, so they stay in memory only (and vanish on restart).
struct HistoryPersistence {
    let dir: URL
    var blobsDir: URL { dir.appendingPathComponent("blobs", isDirectory: true) }
    var indexURL: URL { dir.appendingPathComponent("history.json") }

    let maxPersistedImageBytes = 10 * 1024 * 1024

    init(directory: URL? = nil) {
        if let directory {
            dir = directory
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = base.appendingPathComponent("ClipStack", isDirectory: true)
        }
    }

    /// On-disk row. Image bytes are NOT inlined — they're referenced by id.
    private struct StoredItem: Codable {
        let id: UUID
        let date: Date
        let kind: String            // "text" | "image" | "files"
        let text: String?
        let files: [String]?
    }

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: indexURL),
              let stored = try? JSONDecoder().decode([StoredItem].self, from: data) else {
            return []
        }
        var items: [ClipboardItem] = []
        for s in stored {
            switch s.kind {
            case "text":
                guard let t = s.text else { continue }
                items.append(ClipboardItem(id: s.id, content: .text(t), date: s.date))
            case "files":
                guard let paths = s.files else { continue }
                items.append(ClipboardItem(id: s.id,
                                           content: .files(paths.map { URL(fileURLWithPath: $0) }),
                                           date: s.date))
            case "image":
                let blob = blobsDir.appendingPathComponent("\(s.id.uuidString).png")
                guard let bytes = try? Data(contentsOf: blob) else { continue } // missing → drop
                items.append(ClipboardItem(id: s.id, content: .image(bytes), date: s.date))
            default:
                continue
            }
        }
        return items
    }

    func save(_ items: [ClipboardItem]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        var stored: [StoredItem] = []
        var keepBlobs = Set<String>()

        for item in items {
            switch item.content {
            case .text(let t):
                stored.append(StoredItem(id: item.id, date: item.date, kind: "text",
                                         text: t, files: nil))
            case .files(let urls):
                stored.append(StoredItem(id: item.id, date: item.date, kind: "files",
                                         text: nil, files: urls.map { $0.path }))
            case .image(let data):
                guard data.count <= maxPersistedImageBytes else { continue } // memory only
                let name = "\(item.id.uuidString).png"
                let blob = blobsDir.appendingPathComponent(name)
                if !fm.fileExists(atPath: blob.path) {
                    try? data.write(to: blob)
                }
                keepBlobs.insert(name)
                stored.append(StoredItem(id: item.id, date: item.date, kind: "image",
                                         text: nil, files: nil))
            }
        }

        if let encoded = try? JSONEncoder().encode(stored) {
            try? encoded.write(to: indexURL)
        }

        // Remove blobs no longer referenced (evicted / deleted / cleared).
        if let existing = try? fm.contentsOfDirectory(atPath: blobsDir.path) {
            for file in existing where file.hasSuffix(".png") && !keepBlobs.contains(file) {
                try? fm.removeItem(at: blobsDir.appendingPathComponent(file))
            }
        }
    }
}
