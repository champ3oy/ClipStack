import AppKit
import SwiftUI

/// A small, non-activating floating panel that shows the quick-paste selection.
/// It never takes focus, so the app you're typing in stays frontmost.
@MainActor
final class QuickPasteHUD {
    private var panel: NSPanel?

    func show(items: [ClipboardItem], selected: Int) {
        let panel = ensurePanel()
        let view = QuickPasteHUDView(items: items, selected: selected)
        if let host = panel.contentView as? NSHostingView<QuickPasteHUDView> {
            host.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
        if let fitting = panel.contentView?.fittingSize {
            panel.setContentSize(fitting)
        }
        center(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel = p
        return p
    }

    private func center(_ p: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.frame else { return }
        p.setFrameOrigin(NSPoint(x: frame.midX - p.frame.width / 2,
                                 y: frame.midY - p.frame.height / 2))
    }
}

struct QuickPasteHUDView: View {
    let items: [ClipboardItem]
    let selected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                row(item, index: idx)
            }
        }
        .padding(10)
        .frame(width: 380, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func row(_ item: ClipboardItem, index: Int) -> some View {
        let isSelected = index == selected
        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: 16)
            thumbnail(for: item)
            Text(item.preview)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    /// Image items show an actual thumbnail; file items show the Finder icon.
    @ViewBuilder
    private func thumbnail(for item: ClipboardItem) -> some View {
        switch item.content {
        case .image(let data):
            if let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        case .files(let urls):
            if let first = urls.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                    .resizable()
                    .frame(width: 18, height: 18)
            }
        case .text:
            EmptyView()
        }
    }
}
