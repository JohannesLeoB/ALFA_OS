import AppKit
import ShellCore
import SwiftUI

struct MenuItem: Identifiable {
    let id: String
    let label: Text
    var meta: Text?
    var check: Text?
    var danger = false
    let action: () -> Void
}

enum MenuEntry: Identifiable {
    case row(MenuItem)
    case head(id: String, label: Text)
    case separator(id: String)

    var id: String {
        switch self {
        case .row(let row): row.id
        case .head(let id, _): id
        case .separator(let id): id
        }
    }
}

struct AnchoredMenu: View {
    @Environment(\.design) private var design
    var width = Design.Size.menuWidthRow
    let entries: [MenuEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                switch entry {
                case .row(let row): AnchoredMenuRow(row: row)
                case .head(_, let label): head(label)
                case .separator: separator
                }
            }
        }
        .padding(CGFloat(Design.Spacing.step4))
        .frame(width: CGFloat(width))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu)).fill(design.color(\.menu)))
        .floatingShadow(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu)))
    }

    private func head(_ label: Text) -> some View {
        label
            .lineLimit(1)
            .font(.face(Design.TextSize.small))
            .foregroundStyle(design.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.bottom, CGFloat(Design.Spacing.step4))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Size.chipHeight), alignment: .bottomLeading)
    }

    private var separator: some View {
        Rectangle()
            .fill(design.color(\.line))
            .frame(height: CGFloat(Design.Size.hairline))
            .padding(.vertical, CGFloat(Design.Spacing.step4))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
    }
}

private struct AnchoredMenuRow: View {
    @Environment(\.design) private var design
    let row: MenuItem
    @State private var hovering = false

    var body: some View {
        Button(action: row.action) {
            HStack(spacing: CGFloat(Design.Size.menuRowGap)) {
                (row.check ?? Text(verbatim: ""))
                    .font(.face(Design.TextSize.small))
                    .frame(width: CGFloat(Design.Spacing.step12))
                row.label
                    .lineLimit(1)
                    .font(.face(Design.TextSize.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let meta = row.meta {
                    meta
                        .font(.face(Design.TextSize.small))
                        .foregroundStyle(design.color(\.inkTertiary))
                }
            }
            .foregroundStyle(design.color(row.danger ? \.signal : \.ink))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.menuRowHeight))
            .background(
                RoundedRectangle(cornerRadius: CGFloat(Design.Radius.notice))
                    .fill(hovering ? design.color(\.hover) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

@MainActor
final class AnchorBox {
    weak var view: NSView?

    func screenRect() -> NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

struct AnchorProbe: NSViewRepresentable {
    let box: AnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = ProbeView()
        box.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        box.view = view
    }
}

final class ProbeView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

enum MenuAnchor {
    case rect(NSRect)
    case point(NSPoint)
}

@MainActor
final class MenuPanel {
    static let shared = MenuPanel()

    private var panel: NSPanel?
    private var monitor: Any?
    private var closing: () -> Void = {}

    func show(entries: [MenuEntry], width: Double, anchor: MenuAnchor, window: NSWindow?, onClose: @escaping () -> Void = {}) {
        close()
        closing = onClose
        guard let window = window ?? NSApp.keyWindow else { return }
        let dark = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let margin = CGFloat(ShadowLayer.reach((dark ? DesignShadows.dark : DesignShadows.light).floating))
        let wrapped = entries.map { entry -> MenuEntry in
            guard case .row(let row) = entry else { return entry }
            return .row(MenuItem(id: row.id, label: row.label, meta: row.meta, check: row.check, danger: row.danger) { [weak self] in
                self?.close()
                row.action()
            })
        }
        let root = AnchoredMenu(width: width, entries: wrapped)
            .padding(margin)
            .environment(\.design, DesignStyle(dark: dark))
        let host = NSHostingView(rootView: root)
        let size = host.fittingSize
        let menuHeight = size.height - 2 * margin
        let menuWidth = size.width - 2 * margin
        let bounds = window.frame
        let gap = CGFloat(Design.Spacing.step4)
        let edge = CGFloat(SheetValues.menuMargin)
        let left: CGFloat
        var top: CGFloat
        switch anchor {
        case .rect(let rect):
            left = rect.minX
            top = rect.minY - gap
            if top - menuHeight < bounds.minY + edge { top = rect.maxY + gap + menuHeight }
        case .point(let point):
            left = point.x
            top = point.y
            if top - menuHeight < bounds.minY + edge { top = max(bounds.minY + edge + menuHeight, point.y + menuHeight) }
        }
        let x = max(bounds.minX + edge, min(left, bounds.maxX - menuWidth - edge))
        let frame = NSRect(x: x - margin, y: top - menuHeight - margin, width: size.width, height: size.height)
        let made = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        made.isOpaque = false
        made.backgroundColor = .clear
        made.hasShadow = false
        made.level = window.level
        made.contentView = host
        window.addChildWindow(made, ordered: .above)
        made.orderFront(nil)
        panel = made
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
            if event.window !== panel { self.close() }
            return event
        }
    }

    func close() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        panel = nil
        let done = closing
        closing = {}
        done()
    }
}
