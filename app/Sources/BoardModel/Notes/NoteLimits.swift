import Foundation
import ALFAcolorCore

/// Cuts the notes of a document that was read from a file to the note limits: at most `ItemNote.maxPerItem`
/// notes per item, and at most `ItemNote.maxTextLength` characters per text. The cut keeps the order of the notes.
public enum NoteLimits {
    /// The notes with the limits applied, and whether anything was cut.
    public static func limited(_ notes: [ItemNote]) -> (notes: [ItemNote], changed: Bool) {
        var out = Array(notes.prefix(ItemNote.maxPerItem))
        var changed = notes.count > ItemNote.maxPerItem
        for index in out.indices where out[index].text.count > ItemNote.maxTextLength {
            out[index].text = String(out[index].text.prefix(ItemNote.maxTextLength))
            changed = true
        }
        return (out, changed)
    }
}
