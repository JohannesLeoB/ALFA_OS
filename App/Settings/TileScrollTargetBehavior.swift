import Design
import Shell
import SwiftUI

struct TileScrollTargetBehavior: ScrollTargetBehavior {
    let rows: [Double]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let limit = Double(context.contentSize.height - context.containerSize.height)
        let y = TileGrid.snap(Double(target.rect.minY), rows: rows, inset: Tokens.Size.reelTopOffset, limit: limit)
        target.rect.origin.y = CGFloat(y)
    }
}
