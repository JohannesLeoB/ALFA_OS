import AppKit
import Mail
import ShellCore
import SwiftUI

extension MailMenuLine {
    @MainActor
    static func entries(_ lines: [MailMenuLine], warns: Bool = true, run: @escaping (MailAction) -> Void) -> [MenuEntry] {
        lines.enumerated().map { index, line in
            let id = String(index)
            switch line {
            case .separator: return .separator(id: id)
            case .head(let text): return .head(id: id, label: Text(verbatim: text))
            case .item(let action, let checked):
                return .row(MenuItem(id: id, label: word(action.key), check: checked ? word("mail.menu.check") : nil,
                                     danger: warns && action.danger) { run(action) })
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
