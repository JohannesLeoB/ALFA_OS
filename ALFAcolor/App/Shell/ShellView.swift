import SwiftUI
import AppTheme
import BoardModel
import Importers

/// Main window: sidebar, canvas, inspector, toolbar, status bar.
/// The system draws the glass for sidebar, inspector and toolbar. There is no own background for it here.
struct ShellView: View {
    /// Minimum size of the main window, konzept/05-OBERFLAECHE.txt section 2.3.
    static let minimumSize = CGSize(width: 1000, height: 640)

    @Environment(\.undoManager) private var undoManager
    @State private var shell = ShellState()
    @State private var canvas: CanvasController
    @State private var interaction: CanvasInteraction
    @State private var importer: ImportCoordinator

    /// The window shows the document of `session`. The undo history belongs to this window.
    init(session: DocumentSession) {
        let controller = CanvasController(store: session.store)
        _canvas = State(initialValue: controller)
        _interaction = State(initialValue: CanvasInteraction(controller: controller))
        _importer = State(initialValue: ImportCoordinator(store: session.store))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $shell.columnVisibility) {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                CanvasSurface(controller: canvas, interaction: interaction, importer: importer,
                              onTogglePalettes: { shell.togglePalettes() })
                    .overlay { ContextBarHost(canvas: canvas) }
                    .overlay { if shell.blobMode { BlobMenuHost(shell: shell, store: canvas.store) } }
                if shell.statusBarVisible {
                    StatusBarView(saveState: canvas.store.saveState, saveError: canvas.store.lastSaveError)
                }
            }
            .inspector(isPresented: $shell.inspectorVisible) {
                InspectorView(canvas: canvas, interaction: interaction)
            }
        }
        .toolbar { ShellToolbar(shell: shell) }
        .focusedSceneValue(\.shell, shell)
        .focusedSceneValue(\.canvas, canvas)
        .focusedSceneValue(\.interaction, interaction)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .onChange(of: undoManager.map(ObjectIdentifier.init), initial: true) {
            if let undoManager { canvas.store.useUndoManager(undoManager) }
        }
    }
}
