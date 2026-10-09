import Foundation
import ALFAcolorCore

extension BoardStore {
    /// True while the item is on the active space and is a code card. A lab of a card that is gone closes.
    public func isCodeCard(_ id: ItemID) -> Bool {
        guard let item = item(id), case .code = item.content else { return false }
        return true
    }
}
