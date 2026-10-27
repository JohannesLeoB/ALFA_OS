import AppKit
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

    func show(entries: [MenuEntry], anchor: MenuAnchor, window: NSWindow?, onClose: @escaping () -> Void = {}) {
        close()
        closing = onClose
        guard let window = window ?? NSApp.keyWindow else { return }
        let appearance = Appearance(dark: window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua, still: false)
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
    }

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
