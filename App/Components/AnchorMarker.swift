import AppKit
import Shell
import SwiftUI

@MainActor
final class AnchorBox {
    weak var view: NSView?
    weak var desk: DeskState?

    func screenRect() -> NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    func showMenu(_ entries: [MenuEntry]) {
        guard let rect = screenRect() else { return }
        MenuPanel.shared.show(entries: entries, anchor: .rect(rect), window: view?.window ?? NSApp.keyWindow, desk: desk)
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
