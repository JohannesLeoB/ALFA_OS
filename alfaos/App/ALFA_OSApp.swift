import AppKit
import ShellCore
import SwiftUI

@main
struct ALFA_OSApp: App {
    private let resources: ShellResources?
    @State private var model: ShellModel?
    private let store = ShellStore()

    init() {
        let loaded = try? ShellResources(bundle: .main)
        resources = loaded
        if let loaded {
            let shell = ShellModel(
                directory: loaded.directory,
                geometry: loaded.geometry,
                window: loaded.geometry.windowMin,
                snapshot: store.load()
            )
            let store = store
            shell.onChange = { store.save($0) }
            _model = State(initialValue: shell)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let resources, let model {
                ShellView(resources: resources, bundle: .main, model: model)
                    .background(WindowConfigurator(minimum: CGSize(width: resources.geometry.windowMin.width, height: resources.geometry.windowMin.height)))
            } else {
                Text("error.resources")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct ShellStore {
    private let key = "shell.snapshot"

    func load() -> ShellSnapshot? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(ShellSnapshot.self, from: $0) }
    }

    func save(_ snapshot: ShellSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let minimum: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.contentMinSize = minimum
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
