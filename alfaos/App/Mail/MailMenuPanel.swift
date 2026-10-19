import AppKit
import Mail
import ShellCore
import SwiftUI

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

extension MailMenuLine {
    @MainActor
    static func entries(_ lines: [MailMenuLine], run: @escaping (MailAction) -> Void) -> [MenuEntry] {
        lines.enumerated().map { index, line in
            let id = String(index)
            switch line {
            case .separator: return .separator(id: id)
            case .head(let text): return .head(id: id, label: Text(verbatim: text))
            case .item(let action, let checked):
                return .row(MenuItem(id: id, label: word(action.key), check: checked ? word("mail.menu.check") : nil,
                                     danger: action.danger) { run(action) })
            }
        }
    }
}

struct RightClick: NSViewRepresentable {
    let handler: (NSPoint) -> Void

    func makeNSView(context: Context) -> RightClickView {
        RightClickView()
    }

    func updateNSView(_ view: RightClickView, context: Context) {
        view.handler = handler
    }
}

final class RightClickView: NSView {
    var handler: (NSPoint) -> Void = { _ in }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent else { return nil }
        let secondary = event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        return secondary ? super.hitTest(point) : nil
    }

    override func rightMouseDown(with event: NSEvent) {
        handler(NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { handler(NSEvent.mouseLocation) } else { super.mouseDown(with: event) }
    }
}
