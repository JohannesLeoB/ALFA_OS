import AppKit
import Design
import Shell
import SwiftUI

@main
struct AlfaApp: App {
    @State private var session: AppSession?
    @NSApplicationDelegateAdaptor(QuitDelegate.self) private var quit

    init() {
        _session = State(initialValue: try? AppSession.live())
    }

    var body: some Scene {
        WindowGroup {
            if let session {
                Content(session: session)
                    .onAppear { quit.flush = { await session.inbox.flushDrafts() } }
            } else {
                Text(LocalizedStringKey("error.resources"))
            }
        }
        .windowResizability(.contentMinSize)
        .commands { MailCommands(session: session) }
    }
}

private struct Content: View {
    let session: AppSession

    private var minimum: BlobSize {
        let measure = session.desk.measure
        guard let frame = NSScreen.main?.frame else { return measure.windowMin }
        return measure.windowMin(screen: BlobSize(width: Double(frame.width), height: Double(frame.height)))
    }

    var body: some View {
        Frame(session: session)
            .preferredColorScheme(session.settings.appearance.scheme)
            .frame(minWidth: CGFloat(minimum.width), minHeight: CGFloat(minimum.height))
            .background(WindowConfigurator())
            .task { await session.start() }
            .onChange(of: session.inbox.totalUnread, initial: true) { _, total in session.attention.badge(total) }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.styleMask.remove(.fullSizeContentView)
            window.isMovableByWindowBackground = false
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
