import AppKit

/// The kinds of content ClipStack can hold in its history.
enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)      // PNG bytes
    case files([URL])
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let date: Date

    init(id: UUID = UUID(), content: ClipboardContent, date: Date) {
        self.id = id
        self.content = content
        self.date = date
    }

    /// Single-line label shown in the menu.
    var preview: String {
        switch content {
        case .text(let text):
            let collapsed = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return collapsed.isEmpty ? "(empty)" : String(collapsed.prefix(160))
        case .image(let data):
            if let rep = NSBitmapImageRep(data: data) {
                return "Image \(rep.pixelsWide) × \(rep.pixelsHigh)"
            }
            return "Image"
        case .files(let urls):
            if urls.count == 1 { return urls[0].lastPathComponent }
            return "\(urls.count) files"
        }
    }
}
