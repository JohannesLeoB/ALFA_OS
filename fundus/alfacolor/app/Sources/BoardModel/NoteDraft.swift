import Foundation
import ALFAcolorCore

/// A note that the comment tool is writing: the item, and the place on it where the press was.
/// The text is typed in the view. The draft becomes a note when the text is finished.
public struct NoteDraft: Equatable, Sendable {
    public var itemID: ItemID
    public var anchor: NoteAnchor

    public init(itemID: ItemID, anchor: NoteAnchor) {
        self.itemID = itemID
        self.anchor = anchor
    }
}
