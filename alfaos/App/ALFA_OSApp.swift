import AppKit
import ShellCore
import SwiftUI

@main
struct ALFA_OSApp: App {
    private let resources: ShellResources?
    @State private var model: ShellModel?
    @State private var host = AppHost()
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue
    private let store = ShellStore()

    init() {
        let loaded = try? ShellResources(bundle: .main)
        resources = loaded
        if let loaded {
            let shell = ShellModel(
                directory: loaded.directory,
                geometry: loaded.geometry,
                window: loaded.geometry.windowMin,
                snapshot: store.load(),
                start: StartView.stored(UserDefaults.standard.string(forKey: SettingsKey.startView))
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
                    .environment(\.appHost, host)
                    .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.scheme)
                    .frame(minWidth: CGFloat(minimum(resources).width), minHeight: CGFloat(minimum(resources).height))
                    .background(WindowConfigurator())
            } else {
                Text(LocalizedStringKey("error.resources"))
            }
        }
        .windowResizability(.contentMinSize)
    }

    private func minimum(_ resources: ShellResources) -> ShellCore.Size {
        guard let frame = NSScreen.main?.frame else { return resources.geometry.windowMin }
        return resources.geometry.windowMin(screen: ShellCore.Size(width: Double(frame.width), height: Double(frame.height)))
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
