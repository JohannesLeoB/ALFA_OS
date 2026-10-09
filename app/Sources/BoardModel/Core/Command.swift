import Foundation
import ALFAcolorCore

/// How an item moves in the paint order of its layer.
public enum StackMove: String, Sendable, CaseIterable {
    case toFront, toBack, forward, backward
}

/// A change to the document, as a value. Every command acts on one space.
/// Applying a command gives an `Edit`, and the edit knows how to undo it.
///
/// Rules that all commands share:
/// - An item that is locked, or lies on a locked layer, is skipped by every command except `setLocked` and `setHidden`.
/// - A command that changes nothing is not an error. It gives no edit and no undo step.
/// - An unknown item, layer or space is an error and changes nothing.
public enum Command: Sendable {
    /// Adds items at the top of the item list. The new items are selected.
    case insert([Item])
    /// Removes items. Items inside a deleted frame or group stay.
    case delete(Set<ItemID>)
    /// Moves items by a distance. Items inside a moved frame or group move with it.
    case move(Set<ItemID>, dx: Double, dy: Double)
    /// Sets new rectangles.
    case resize([ItemID: Rect])
    /// Changes the paint order inside each layer.
    case reorder(Set<ItemID>, StackMove)
    /// Makes a group around items. The group rectangle is the union of the item rectangles.
    /// The ID is part of the command, so that applying it again gives the same result.
    case group(Set<ItemID>, title: String, groupID: ItemID)
    /// Removes groups. Their items stay and are selected.
    case ungroup(Set<ItemID>)
    /// Replaces the content of one item, for example the text of a note or the image of a placeholder.
    /// The rectangle, the layer and the place in the stack stay.
    case setContent(ItemID, Content)
    /// Sets or removes the origin of one item: its address, file, way in and licence. Nil removes it.
    case setSource(ItemID, Source?)
    /// Sets the colour of shapes and swatches. A shape takes the fill, or the stroke when it is a line.
    /// A swatch takes the colour and loses its name. Other items keep what they have.
    case setFill(Set<ItemID>, hex: String)
    case setLocked(Set<ItemID>, Bool)
    case setHidden(Set<ItemID>, Bool)
    /// Moves items to another layer of the same space.
    case moveToLayer(Set<ItemID>, layerID: String)
    /// Arranges items with `arrange()` of the core. Items inside moved frames and groups move with them.
    case arrange(Arrangement, Set<ItemID>, reference: ItemID? = nil, options: ArrangeOptions = ArrangeOptions())
    /// Makes another space the active one. It changes the view, not the document, so it gives no undo step.
    case switchSpace(String)
    /// Several commands as one step. If one fails, none is applied.
    case batch([Command], nameKey: String? = nil)
}

/// Why a command was refused.
public enum CommandError: Error, Equatable, Sendable {
    case noActiveSpace
    case unknownSpace(String)
    case unknownItem(ItemID)
    case unknownLayer(String)
    case duplicateItem(ItemID)
    /// A rectangle or distance is not a finite number, or a size is negative.
    case invalidGeometry
    /// `switchSpace` is a change of view and cannot be part of a batch.
    case notBatchable
}
