import AppKit
import SwiftUI

@MainActor
final class AnchorBox {
    weak var view: NSView?

    func screenRect() -> NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    func showMenu(_ entries: [MenuEntry], width: Double) {
        guard let rect = screenRect() else { return }
        MenuPanel.shared.show(entries: entries, width: width, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct AnchorMarker: NSViewRepresentable {
    let box: AnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = MarkerView()
        box.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        box.view = view
    }
}

private final class MarkerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
