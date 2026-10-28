import AppKit
import SwiftUI

struct RightClickOverlay: NSViewRepresentable {
    let handler: (NSPoint) -> Void

    func makeNSView(context: Context) -> ClickView {
        ClickView()
    }

    func updateNSView(_ view: ClickView, context: Context) {
        view.handler = handler
    }

    final class ClickView: NSView {
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
}
