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
    /// Unit of the position fields: the inspector and the blob menu share it. It stays when either one is hidden.
    var lengthUnit: LengthUnit = .point
    /// The rulers along the top and left edge of the canvas.
    var rulersVisible = true
    /// The guides of the frames: shown or hidden, and locked against pulling and editing with the pointer.
    var guidesVisible = true
    var guidesLocked = false
    /// The frame that the rulers measured from last. It is the fallback when no frame holds the selection.
    var rulerFrame: ItemID?
    /// Room whose name is being changed, and the name in the field. The tab row and the room menu set them.
    var renamingRoom: String?
    var roomDraft = ""
    /// A short message about the last room action, as a catalog key. nil when there is none.
    var roomNotice: String?
    /// The layer that the layer list marks as active. It is chosen by a click and is not part of the document.
    var activeLayer: String?
    /// Room that waits for the close confirmation, because it has content.
    var closingRoom: String?
    /// The labs of the code cards opened in this window. A lab keeps its draft when it closes.
    private(set) var labs: [ItemID: LabModel] = [:]
    /// The card whose lab is open, if any.
    private(set) var labOpen: ItemID?
    /// A short message about the last lab action, as a catalog key. nil when there is none.
    private(set) var labNotice: String?

    /// The open lab, shown over the canvas.
    var openLabModel: LabModel? { labOpen.flatMap { labs[$0] } }

    /// Help text of a tool that does not work yet, as a catalog key. The status bar shows it until the next choice.
    var toolNotice: String?

    /// A choice from the palette or a key. The lab opens; a tool that does not work yet shows its help text.
    /// The active tool itself lives in the canvas model (`CanvasInteraction.tools`), next to the presses it changes.
    func pick(_ tool: Tool, in interaction: CanvasInteraction, canvas: CanvasController?) {
        if tool == .lab {
            if let canvas { openLab(in: canvas) }
            return
        }
        if interaction.tools.choose(tool) {
            toolNotice = nil
        } else {
            toolNotice = tool.helpKey
        }
    }

    /// Opens the lab of a code card. A draft is built anew when the card changed on the board since the lab last saw it.
    /// Returns false, with a notice, for an item that is not web code on the board.
    @discardableResult
    func openLab(for item: ItemID, store: BoardStore) -> Bool {
        if labs[item]?.isCurrent(in: store) != true {
            labs[item] = LabModel(item: item, store: store)
        }
        guard let lab = labs[item] else {
            labNotice = "lab.notWeb"
            return false
        }
        labNotice = nil
        labOpen = item
        Task { await lab.reloadPage() }
        return true
    }

    /// Opens the lab of the selected code card, or of a new card on the canvas. A card that cannot be made shows its notice.
    func openLab(in canvas: CanvasController) {
        do {
            openLab(for: try LabEntry.card(in: canvas), store: canvas.store)
        } catch let error as LabEntryError {
            labNotice = error.noticeKey
        } catch {
            labNotice = "lab.noCard"
        }
    }

    /// Counts the closed labs. The canvas takes the keyboard focus back when this changes.
    private(set) var labClosings = 0

    /// Closes the open lab. Its draft stays for the next time.
    func closeLab() {
        openLabModel?.stopPage()
        labOpen = nil
        labClosings += 1
    }

    /// Drops the labs of cards that are gone, and closes the open lab when its card is gone,
    /// for example after an undo took the card back.
    func closeLabIfCardGone(in store: BoardStore) {
        for card in Array(labs.keys) where !store.isCodeCard(card) {
            labs[card]?.stopPage()
            labs[card] = nil
        }
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

    /// Escape in blob mode: closes the open palette and returns true. False when no palette is open.
    func closeBlobPalette() -> Bool {
        guard blobMode, blob.open != nil else { return false }
        blob.close()
        return true
    }

    /// Tab on the canvas: if any palette is open, both close. Otherwise both open.
    /// In blob mode the blob menu replaces the palettes, so Tab does nothing there.
    func togglePalettes() {
        guard !blobMode else { return }
        let anyVisible = sidebarVisible || inspectorVisible
        sidebarVisible = !anyVisible
        inspectorVisible = !anyVisible
    }
}

extension FocusedValues {
    @Entry var shell: ShellState?
}
