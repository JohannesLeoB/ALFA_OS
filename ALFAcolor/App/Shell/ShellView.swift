import SwiftUI
import AppTheme
import BoardModel
import Document

/// Main window: sidebar, canvas, inspector, toolbar, status bar.
/// The system draws the glass for sidebar, inspector and toolbar. There is no own background for it here.
struct ShellView: View {
    /// Minimum size of the main window, konzept/05-OBERFLAECHE.txt section 2.3.
    static let minimumSize = CGSize(width: 1000, height: 640)

    @State private var shell = ShellState()
    @State private var canvas = CanvasController(store: BoardStore(document: ALFAcolorDocument()))

    var body: some View {
        NavigationSplitView(columnVisibility: $shell.columnVisibility) {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                CanvasSurface(controller: canvas, onTogglePalettes: { shell.togglePalettes() })
                if shell.statusBarVisible {
                    StatusBarView()
                }
            }
            .inspector(isPresented: $shell.inspectorVisible) {
                InspectorView()
            }
        }
        .toolbar { ShellToolbar(shell: shell) }
        .focusedSceneValue(\.shell, shell)
        .focusedSceneValue(\.canvas, canvas)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }
}
