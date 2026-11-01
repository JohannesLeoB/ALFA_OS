import AppKit
import Design
import QuickLookUI
import Shell
import SwiftUI

@main
struct AlfaApp: App {
    @State private var start: Result<AppSession, StartProblem>
    @NSApplicationDelegateAdaptor(QuitDelegate.self) private var quit

    init() {
        _start = State(initialValue: Result { try AppSession.live() }.mapError { StartProblem($0) })
    }

    private var session: AppSession? {
        if case .success(let session) = start { return session }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            switch start {
            case .success(let session):
                Content(session: session)
                    .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                    .onAppear { quit.flush = { await session.inbox.flushDrafts() } }
            case .failure(let problem):
                StartScreen(problem: problem)
            }
        }
        .windowResizability(.contentMinSize)
        .commands { MailCommands(session: session) }
    }
}

struct StartProblem: Error {
    let resources: Bool
    let code: String
    let reading: String

    init(_ error: any Error) {
        let cause = (error as? ResourcesMissing)?.underlying ?? error
        let bridged = cause as NSError
        resources = error is ResourcesMissing
        code = bridged.domain + " " + String(bridged.code)
        reading = String(describing: cause)
    }
}

private struct StartScreen: View {
    @Environment(\.appearance) private var appearance
    let problem: StartProblem

    var body: some View {
        ContentPlaceholder(kind: .failed,
                           title: problem.resources ? appearance.text("error.resources") : Text(verbatim: appearance.format("settings.failed.title", problem.code)),
                           text: Text(verbatim: problem.reading),
                           glyph: { Glyph(.alert) },
                           action: { TextButton(label: appearance.text("card.close")) { NSApplication.shared.terminate(nil) } })
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
            .background(WindowConfigurator(adopt: session.shield.adopt))
            .task { await session.start() }
            .onChange(of: session.inbox.totalUnread, initial: true) { _, total in session.attention.badge(total) }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let adopt: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowAnchor {
        let view = WindowAnchor()
        view.adopt = adopt
        return view
    }

    func updateNSView(_ view: WindowAnchor, context: Context) {
        view.adopt = adopt
    }
}

final class WindowAnchor: NSView {
    var adopt: @MainActor (NSWindow) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        adopt(window)
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.styleMask.remove(.fullSizeContentView)
            window.isMovableByWindowBackground = false
        }
    }
}

@MainActor
final class WindowShield {
    private let faces = NSHashTable<NSWindow>.weakObjects()
    private let center: NotificationCenter
    private var hidden: [NSWindow] = []
    private var shut = false
    private var observers: [any NSObjectProtocol] = []

    init(lock: LockState, center: NotificationCenter = .default) {
        self.center = center
        lock.watch { [weak self] phase in self?.follow(phase.shut) }
        let names = [NSWindow.didBecomeKeyNotification, NSWindow.didUpdateNotification, NSApplication.didUpdateNotification]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sweep() }
            }
        }
    }

    isolated deinit {
        for observer in observers { center.removeObserver(observer) }
    }

    func adopt(_ window: NSWindow) {
        faces.add(window)
        if let index = hidden.firstIndex(of: window) {
            hidden.remove(at: index)
            window.orderFront(nil)
        }
        guard shut else { return }
        window.makeFirstResponder(nil)
        sweep()
    }

    private func follow(_ now: Bool) {
        guard now != shut else { return }
        shut = now
        if now {
            MenuPanel.shared.close()
            for face in faces.allObjects { face.makeFirstResponder(nil) }
            sweep()
        } else {
            let windows = hidden
            hidden = []
            for window in windows { window.orderFront(nil) }
        }
    }

    private func sweep() {
        guard shut, !faces.allObjects.isEmpty else { return }
        dismissPanels()
        for window in NSApp.windows where shields(window) {
            window.orderOut(nil)
            hidden.append(window)
        }
    }

    private func shields(_ window: NSWindow) -> Bool {
        guard window.isVisible, !faces.contains(window), !window.isSheet, !(window is NSSavePanel) else { return false }
        return window.styleMask.contains(.titled) || window is QLPreviewPanel
    }

    private func dismissPanels() {
        let windows = NSApp.windows
        for case let panel as NSSavePanel in windows { panel.cancel(nil) }
        for candidate in windows {
            guard let sheet = candidate.attachedSheet, !(sheet is NSSavePanel) else { continue }
            candidate.endSheet(sheet, returnCode: .cancel)
        }
        if let modal = NSApp.modalWindow, !(modal is NSSavePanel) {
            NSApp.stopModal(withCode: .cancel)
            modal.orderOut(nil)
        }
    }
}

@MainActor
final class QuitDelegate: NSObject, NSApplicationDelegate {
    var flush: (@MainActor () async -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        application.activate(ignoringOtherApps: true)
        guard let window = application.windows.first(where: { $0.styleMask.contains(.titled) && $0.canBecomeMain }) else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let flush else { return .terminateNow }
        Task {
            await flush()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        AttachmentPreview.shared.discard()
    }
}
