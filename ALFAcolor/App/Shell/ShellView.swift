import SwiftUI
import AppTheme
import ALFAcolorCore
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
    /// Where the canvas starts in window coordinates (the top edge, under the toolbar too). Views on top of the canvas measure their area against it.
    @State private var canvasOrigin = CGPoint.zero
    /// Where the canvas column starts in window coordinates. The rulers sit here, below the toolbar.
    @State private var columnOrigin = CGPoint.zero
    /// The first thing that reading the document noticed, shown in the status bar.
    private let readNotice: String?

    /// The window shows the document of `session`. The undo history belongs to this window.
    init(session: DocumentSession) {
        let controller = CanvasController(store: session.store)
        _canvas = State(initialValue: controller)
        _interaction = State(initialValue: CanvasInteraction(controller: controller))
        _importer = State(initialValue: ImportCoordinator(store: session.store))
        readNotice = session.readReport?.statusNotice
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $shell.columnVisibility) {
            SidebarView(store: canvas.store, shell: shell)
        } detail: {
            VStack(spacing: 0) {
                CanvasSurface(controller: canvas, interaction: interaction, importer: importer,
                              onTogglePalettes: { shell.togglePalettes() }, labClosings: shell.labClosings,
                              origin: $canvasOrigin)
                if shell.statusBarVisible {
                    StatusBarView(saveState: canvas.store.saveState, saveError: canvas.store.lastSaveError,
                                  zoomPercent: canvas.zoomPercent, selectionCount: canvas.store.selectedItems.count,
                                  gridStep: interaction.snap.gridStep, unit: shell.lengthUnit,
                                  notice: shell.labNotice ?? shell.roomNotice ?? readNotice)
                }
            }
            .onGeometryChange(for: CGPoint.self, of: { $0.frame(in: .global).origin }) { columnOrigin = $0 }
            // Rulers on top of the canvas, not in it: they stay below the toolbar and take clicks on their strips only.
            .overlay(alignment: .topLeading) {
                if shell.rulersVisible {
                    RulersOverlay(canvas: canvas, shell: shell,
                                  lead: CGPoint(x: columnOrigin.x - canvasOrigin.x, y: columnOrigin.y - canvasOrigin.y))
                }
            }
            // On the stack, not on the canvas: the canvas ignores the top safe area, so its overlays
            // would reach under the toolbar, where they cannot be clicked. The lab and the blob menu sit here.
            .overlay {
                if let lab = shell.openLabModel {
                    LabView(model: lab, onClose: { shell.closeLab() })
                        .keepsCanvasScroll("lab", canvas, origin: canvasOrigin)
                }
            }
            .overlay {
                if shell.blobMode {
                    BlobMenuHost(shell: shell, store: canvas.store)
                        .keepsCanvasScroll("blob", canvas, origin: canvasOrigin)
                }
            }
            // Content never sets the minimum size of a split column; a changing minimum loops the window layout.
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .inspector(isPresented: $shell.inspectorVisible) {
                InspectorView(canvas: canvas, interaction: interaction, shell: shell)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            }
        }
        .toolbar { ShellToolbar(shell: shell, store: canvas.store) }
        .modifier(RoomDialogs(shell: shell, store: canvas.store))
        .focusedSceneValue(\.shell, shell)
        .focusedSceneValue(\.canvas, canvas)
        .focusedSceneValue(\.interaction, interaction)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .onChange(of: undoManager.map(ObjectIdentifier.init), initial: true) {
            if let undoManager { canvas.store.useUndoManager(undoManager) }
        }
        .onChange(of: canvas.store.revision) {
            shell.closeLabIfCardGone(in: canvas.store)
        }
    }
}

extension View {
    /// Keeps the canvas below from taking the scroll wheel while this view is shown. The area is in canvas points.
    func keepsCanvasScroll(_ name: String, _ canvas: CanvasController, origin: CGPoint) -> some View {
        modifier(CanvasScrollKeep(name: name, canvas: canvas, origin: origin))
    }
}

private struct CanvasScrollKeep: ViewModifier {
    let name: String
    let canvas: CanvasController
    let origin: CGPoint

    // `Self.Content` is the modifier's input: a bare `Content` means the model type of ALFAcolorCore here.
    func body(content: Self.Content) -> some View {
        content
            .onGeometryChange(for: Rect.self, of: { proxy in
                let frame = proxy.frame(in: .global)
                return Rect(x: Double(frame.minX - origin.x), y: Double(frame.minY - origin.y),
                            w: Double(frame.width), h: Double(frame.height))
            }) { area in
                canvas.setScrollKeep(name, area)
            }
            .onDisappear { canvas.setScrollKeep(name, nil) }
    }
}
