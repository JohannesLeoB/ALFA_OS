import AppKit
import QuickLookUI
import Shell

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
