import SwiftUI
import ALFAcolorCore
import BoardModel
import Motion

/// State of the window shell: which areas are visible.
/// It belongs to one window. Menu commands reach it through `focusedSceneValue`.
@MainActor
@Observable
final class ShellState {
    /// Sidebar: `.all` shows it, `.detailOnly` hides it. The system key of the toolbar writes here too.
    var columnVisibility: NavigationSplitViewVisibility = .all
    var inspectorVisible = true
    var statusBarVisible = true
    /// Blob mode: the blob menu replaces the sidebars. The sidebars and the inspector are hidden while it is on.
    private(set) var blobMode = false
    /// State of the blob menu. Only the views of the menu change it.
    var blob = BlobMenu()
    /// Unit of the position fields in the blob menu. It stays when the palette or the blob mode changes.
    var blobUnit: LengthUnit = .point
    /// Room whose name is being changed, and the name in the field. The tab row and the room menu set them.
    var renamingRoom: String?
    var roomDraft = ""
    /// Room that waits for the close confirmation, because it has content.
    var closingRoom: String?
    /// The labs of the code cards opened in this window. A lab keeps its draft when it closes.
    private(set) var labs: [ItemID: LabModel] = [:]
    /// The card whose lab is open, if any.
    private(set) var labOpen: ItemID?

    /// The open lab, shown over the canvas.
    var openLabModel: LabModel? { labOpen.flatMap { labs[$0] } }

    /// Opens the lab of a code card. Nothing happens for an item that is not web code on the board.
    func openLab(for item: ItemID, store: BoardStore) {
        if labs[item] == nil {
            labs[item] = LabModel(item: item, store: store)
        }
        guard let lab = labs[item] else { return }
        labOpen = item
        Task { await lab.reloadPage() }
    }

    /// Counts the closed labs. The canvas takes the keyboard focus back when this changes.
    private(set) var labClosings = 0

    /// Closes the open lab. Its draft stays for the next time.
    func closeLab() {
        openLabModel?.stopPage()
        labOpen = nil
        labClosings += 1
    }

    /// Closes the open lab when its card is gone, for example after an undo took the card back.
    func closeLabIfCardGone(in store: BoardStore) {
        guard let card = labOpen, !store.isCodeCard(card) else { return }
        closeLab()
    }

    var sidebarVisible: Bool {
        get { columnVisibility != .detailOnly }
        set { columnVisibility = newValue ? .all : .detailOnly }
    }

    func toggleSidebar() { sidebarVisible.toggle() }
    func toggleInspector() { inspectorVisible.toggle() }
    func toggleStatusBar() { statusBarVisible.toggle() }

    /// Switches between the sidebars and the blob menu. Leaving the blob mode shows the sidebars again.
    func toggleBlobMode() {
        blobMode.toggle()
        sidebarVisible = !blobMode
        inspectorVisible = !blobMode
    }

    /// Tab on the canvas: if any palette is open, both close. Otherwise both open.
    func togglePalettes() {
        let anyVisible = sidebarVisible || inspectorVisible
        sidebarVisible = !anyVisible
        inspectorVisible = !anyVisible
    }
}

extension FocusedValues {
    @Entry var shell: ShellState?
}
