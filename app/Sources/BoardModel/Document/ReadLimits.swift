import Foundation
import ALFAcolorCore
import Document
import Geometry

/// Cuts the positions and sizes of a document that was read from a file to the number limits. A value beyond
/// them would trap when the board draws or converts it, so the cut happens once, when the file opens.
public enum ReadLimits {
    /// The document with every item rectangle inside the limits, and one warning for each item that was cut.
    public static func limited(_ document: ALFAcolorDocument) -> (document: ALFAcolorDocument, warnings: [String]) {
        var result = document
        var warnings: [String] = []
        for spaceIndex in result.board.spaces.indices {
            for itemIndex in result.board.spaces[spaceIndex].items.indices {
                let item = result.board.spaces[spaceIndex].items[itemIndex]
                let cut = item.rect.limited
                guard cut != item.rect else { continue }
                result.board.spaces[spaceIndex].items[itemIndex].rect = cut
                warnings.append(String(localized: "package.warning.limitedRect \(item.id.raw)"))
            }
        }
        return (result, warnings)
    }
}
