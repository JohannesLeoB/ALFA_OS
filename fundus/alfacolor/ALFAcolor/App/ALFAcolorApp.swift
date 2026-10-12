import SwiftUI
import AppTheme

@main
struct ALFAcolorApp: App {
    /// Start size of the main window, konzept/05-OBERFLAECHE.txt section 2.3.
    private static let defaultSize = CGSize(width: 1280, height: 800)

    /// The contract from the app bundle (light and dark). Without a valid file the placeholder applies.
    private let theme = Theme.bundled()

    var body: some Scene {
        // One window per document. The system provides New, Open, Open Recent, Save, Duplicate and Revert.
        DocumentGroup(newDocument: { BoardFile() }) { configuration in
            // Revert and versions give the window a new session. The id makes the view and its state follow it.
            ShellView(session: configuration.document.session, fileURL: configuration.fileURL)
                .id(configuration.document.session.id)
                .environment(\.theme, theme)
        }
        .defaultSize(width: Self.defaultSize.width, height: Self.defaultSize.height)
        .defaultWindowPlacement { _, context in
            // Intent: center of the visible area of the main display, size never beyond the visible area.
            // Observed (macOS 26.6): the system sets the position itself. A point given here did not change it.
            let visible = context.defaultDisplay.visibleRect
            let width = min(Self.defaultSize.width, visible.width)
            let height = min(Self.defaultSize.height, visible.height)
            return WindowPlacement(
                CGPoint(x: visible.midX - width / 2, y: visible.midY - height / 2),
                size: CGSize(width: width, height: height)
            )
        }
        .commands {
            ALFAcolorCommands()
            SetupCommands()
        }

        // Start window: shown when the app starts without a document; it closes when a document window comes forward.
        Window("start.window.title", id: StartWindowView.windowID) {
            StartWindowView()
                .environment(\.theme, theme)
        }
        .defaultLaunchBehavior(.presented)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        // Shortcut table: overview of all shortcuts, opened through Help > Shortcut Table.
        Window("window.shortcutTable", id: ShortcutTableView.windowID) {
            ShortcutTableView()
                .environment(\.theme, theme)
        }
        .defaultSize(width: 460, height: 640)

        // Settings window, opened by the app menu (Settings...). Its tabs keep the saved values.
        Settings {
            SettingsView()
                .environment(\.theme, theme)
        }
    }
}
