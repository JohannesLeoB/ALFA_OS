import Foundation
import ALFAcolorCore

/// What the comment tool does on the canvas: a press on an item opens a draft at the press point, and the
/// finished text makes it a note at that place. The tool stays active after a note.
extension CanvasInteraction {
    /// A press on an item opens a draft at the press point, as a place in the item. A press that hits no item does nothing.
    func commentPress(at point: (x: Double, y: Double)) {
        guard let hit = HitTest.item(atX: point.x, y: point.y, among: controller.drawnItems, zoom: controller.viewport.zoom, bandHeight: bandHeight),
              let item = store.item(hit) else { return }
        let rect = displayedRect(of: item)
        let anchor = NoteAnchor(x: (point.x - rect.x) / rect.w, y: (point.y - rect.y) / rect.h)
        noteDraft = NoteDraft(itemID: hit, anchor: anchor)
    }

    /// Finishes the draft with its text and adds the note at the anchor. An empty text adds no note.
    /// The draft closes when the note is added or the text is empty. A refused note keeps the draft, and its text,
    /// and throws. Returns false when no note was added.
    @discardableResult
    public func finishNoteDraft(text: String) throws -> Bool {
        guard let draft = noteDraft else { return false }
        let note = ItemNote(text: text, author: .user, createdAt: .now, anchor: draft.anchor)
        let added = try store.perform(noteAdd: note, to: [draft.itemID])
        noteDraft = nil
        return added
    }

    /// Closes the draft without a note.
    public func cancelNoteDraft() {
        noteDraft = nil
    }
}
