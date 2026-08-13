import Foundation

/// Pure selection math for the ⌘⌃ quick-paste chord (no AppKit — unit-testable).
/// `index` is nil until a number or arrow chooses something.
struct QuickPasteSelection: Equatable {
    let count: Int
    private(set) var index: Int?

    init(count: Int) { self.count = count }

    /// 1-based index from a number key; out-of-range presses are ignored.
    mutating func setNumber(_ n: Int) {
        guard count > 0, n >= 1, n <= count else { return }
        index = n - 1
    }

    mutating func moveDown() {
        guard count > 0 else { index = nil; return }
        guard let cur = index else { index = 0; return }   // first arrow → newest
        index = min(cur + 1, count - 1)
    }

    mutating func moveUp() {
        guard count > 0 else { index = nil; return }
        guard let cur = index else { index = 0; return }
        index = max(cur - 1, 0)
    }
}
