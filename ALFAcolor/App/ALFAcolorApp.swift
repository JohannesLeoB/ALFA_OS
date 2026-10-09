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
            ShellView(session: configuration.document.session)
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
        .commands { ALFAcolorCommands() }

        // Shortcut table: overview of all shortcuts, opened through Help > Shortcut Table.
        Window("window.shortcutTable", id: ShortcutTableView.windowID) {
            ShortcutTableView()
                .environment(\.theme, theme)
        }
        .defaultSize(width: 460, height: 640)
    }
}
