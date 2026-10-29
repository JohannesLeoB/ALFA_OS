import Design
import Mail
import SwiftUI

extension View {
    func loadsAhead(spacer: Double = 0, perform: @escaping () -> Void) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            ListWindowEngine.remaining(content: Double(geometry.contentSize.height), offset: Double(geometry.contentOffset.y),
                                       container: Double(geometry.containerSize.height), spacer: spacer) < SheetValues.listLoadAhead
        } action: { was, near in
            if !was, near { perform() }
        }
    }
}
