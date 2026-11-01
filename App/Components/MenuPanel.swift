import AppKit
import Carbon.HIToolbox
import Design
import Shell
import SwiftUI

enum MenuAnchor {
    case rect(NSRect)
    case point(NSPoint)
}

@MainActor
final class MenuPanel {
    static let shared = MenuPanel()

    private var panel: NSPanel?
    private var closing: () -> Void = {}
    private var generation = 0

    @discardableResult
    func show(entries: [MenuEntry], anchor: MenuAnchor, window: NSWindow?, desk: DeskState? = nil, onClose: @escaping () -> Void = {}) -> Int {
        generation += 1
        let ticket = generation
        close()
        closing = onClose
        guard let window = window ?? NSApp.keyWindow else { return ticket }
        let appearance = Appearance(dark: window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua, still: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        let margin = CGFloat(ShadowLayer.reach(appearance.shadows.floating))
        let wrapped = entries.map { entry -> MenuEntry in
            guard case .row(let row) = entry else { return entry }
            return .row(MenuItem(id: row.id, label: row.label, meta: row.meta, check: row.check, danger: row.danger) { [weak self] in
                self?.close()
                row.action()
            })
        }
        let natural = NSHostingView(rootView: AnchoredMenu(entries: wrapped).environment(\.appearance, appearance)).fittingSize.width
        let width = MenuWidthEngine.width(fitting: Double(natural))
        let root = AnchoredMenu(width: width, entries: wrapped, dismiss: { [weak self] in self?.close() })
            .padding(margin)
            .environment(\.appearance, appearance)
        let host = NSHostingView(rootView: root)
        let size = host.fittingSize
        let menuHeight = size.height - 2 * margin
        let menuWidth = size.width - 2 * margin
        let bounds = window.frame
        let gap = CGFloat(Tokens.Spacing.step4)
        let edge = CGFloat(Tokens.Size.edge)
        let left: CGFloat
        var top: CGFloat
        switch anchor {
        case .rect(let rect):
            if let desk {
                left = bounds.minX + CGFloat(MenuAlignEngine.left(anchor: Double(rect.minX - bounds.minX), anchorWidth: Double(rect.width), width: Double(menuWidth),
                                                                  lanes: desk.widths, measure: desk.measure, windowWidth: Double(bounds.width)))
            } else {
                left = rect.minX
            }
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
        return ticket
    }

    func isCurrent(_ ticket: Int) -> Bool { ticket == generation && panel != nil }

    func close() {
        if let panel {
            panel.contentView = nil
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        panel = nil
        let done = closing
        closing = {}
        done()
    }
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

struct MenuItem: Identifiable {
    let id: String
    let label: Text
    var meta: Text?
    var check: Text?
    var danger = false
    let action: () -> Void
}

struct AnchoredMenu: View {
    @Environment(\.appearance) private var appearance
    var width: Double?
    let entries: [MenuEntry]
    var dismiss: () -> Void = {}

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.contextMenu))
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                switch entry {
                case .row(let row): MenuRow(row: row)
                case .head(_, let label): head(label)
                case .separator: separator
                }
            }
        }
        .padding(CGFloat(Tokens.Spacing.step4))
        .frame(width: width.map { CGFloat($0) })
        .fixedSize(horizontal: width == nil, vertical: false)
        .background(shape.fill(appearance.color(\.menu)))
        .shadowLayers(shape)
        .eventMonitor([.leftMouseDown, .rightMouseDown, .keyDown]) { sample in
            if sample.event.type == .keyDown {
                guard sample.event.keyCode == UInt16(kVK_Escape) else { return false }
                dismiss()
                return true
            }
            if sample.local == nil { dismiss() }
            return false
        }
    }

    private func head(_ label: Text) -> some View {
        label
            .lineLimit(1)
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset))
            .padding(.bottom, CGFloat(Tokens.Spacing.step4))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.chipHeight), alignment: .bottomLeading)
    }

    private var separator: some View {
        Rectangle()
            .fill(appearance.color(\.line))
            .frame(height: CGFloat(Tokens.Size.hairline))
            .padding(.vertical, CGFloat(Tokens.Spacing.step4))
            .padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset))
    }
}

struct MenuRow: View {
    @Environment(\.appearance) private var appearance
    let row: MenuItem
    @State private var hovering = false

    var body: some View {
        Button(action: row.action) {
            HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
                (row.check ?? Text(verbatim: ""))
                    .font(.face(Tokens.TextSize.small))
                    .frame(width: CGFloat(Tokens.Spacing.step12))
                row.label
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.label)
                    .font(.face(Tokens.TextSize.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let meta = row.meta {
                    meta
                        .font(.face(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(\.inkTertiary))
                        .fixedSize()
                }
            }
            .foregroundStyle(appearance.color(row.danger ? \.signal : \.ink))
            .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
            .frame(height: CGFloat(Tokens.Size.menuRowHeight))
            .background(
                RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
                    .fill(hovering ? appearance.color(\.hover) : Color.clear)
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
    weak var desk: DeskState?

    func screenRect() -> NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    @discardableResult
    func showMenu(_ entries: [MenuEntry]) -> Int? {
        guard let rect = screenRect() else { return nil }
        return MenuPanel.shared.show(entries: entries, anchor: .rect(rect), window: view?.window ?? NSApp.keyWindow, desk: desk)
    }
}

struct AnchorMarker: NSViewRepresentable {
    let box: AnchorBox
    @Environment(\.session) private var session

    func makeNSView(context: Context) -> NSView {
        let view = MarkerView()
        box.view = view
        box.desk = session?.desk
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        box.view = view
        box.desk = session?.desk
    }
}

private final class MarkerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct CommandHead<Action: Equatable & Sendable, Slot: View>: View {
    @Environment(\.appearance) private var appearance
    let plan: CommandPlan<Action>
    let moreHelp: String
    let glyph: (Action) -> Icon?
    let help: (Action) -> String
    var shortcut: (Action) -> KeyboardShortcut? = { _ in nil }
    let perform: (Action) -> Void
    let more: ([Action]) -> [MenuEntry]
    @ViewBuilder let pill: () -> Slot
    @State private var moreAnchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(LaneKind.trailing.headGap)) {
            group(plan.main)
            Spacer(minLength: 0)
            group(plan.end)
        }
        .padding(.leading, CGFloat(LaneKind.trailing.headLeading))
        .padding(.trailing, CGFloat(LaneKind.trailing.headTrailing))
        .frame(height: CGFloat(Tokens.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(appearance.color(\.lane))
    }

    private func group(_ slots: [CommandSlot<Action>]) -> some View {
        HStack(spacing: CGFloat(LaneKind.trailing.headGap)) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                view(slot)
            }
        }
    }

    @ViewBuilder
    private func view(_ slot: CommandSlot<Action>) -> some View {
        switch slot.kind {
        case .separator:
            Rectangle().fill(appearance.color(\.line)).frame(width: CGFloat(Tokens.Size.hairline), height: CGFloat(Tokens.Spacing.step20))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
        case .pill:
            pill()
        case .more:
            SymbolButton(help: moreHelp, glyph: .more, tone: \.inkSecondary, hover: .fill) { openMore() }
                .background(AnchorMarker(box: moreAnchor))
        case .button:
            if let action = slot.action, let icon = glyph(action) {
                SymbolButton(help: help(action), glyph: icon, selected: slot.accent, disabled: slot.off,
                             tone: slot.signal ? \.signal : \.inkSecondary, hoverTone: slot.signal ? \.signal : \.ink, hover: .fill) {
                    perform(action)
                }
                .keyboardShortcut(shortcut(action))
            }
        }
    }

    private func openMore() {
        moreAnchor.showMenu(more(plan.overflow.compactMap(\.action)))
    }
}
