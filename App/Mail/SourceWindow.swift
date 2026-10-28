import AppKit
import Design
import Mail
import SwiftUI

@MainActor
enum SourceWindow {
    private static var open: [NSWindow] = []

    static func show(_ inbox: InboxState, message id: String, appearance: Appearance) {
        let title = inbox.card(id)?.summary.subject ?? ""
        Task {
            guard let source = await inbox.original(id) else { return }
            open.removeAll { !$0.isVisible }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Tokens.Size.previewMinWidth, height: Tokens.Size.previewMinHeight),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = title
            window.contentView = NSHostingView(rootView: SourceText(source: source).environment(\.appearance, appearance))
            window.center()
            window.makeKeyAndOrderFront(nil)
            open.append(window)
        }
    }
}

private struct SourceText: View {
    @Environment(\.appearance) private var appearance
    let source: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(verbatim: source)
                .font(.system(size: CGFloat(Tokens.TextSize.small), design: .monospaced))
                .foregroundStyle(appearance.color(\.ink))
                .textSelection(.enabled)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(CGFloat(Tokens.Spacing.step16))
        }
        .background(appearance.color(\.lane))
    }
}
