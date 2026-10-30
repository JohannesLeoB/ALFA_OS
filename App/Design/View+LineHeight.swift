import Design
import SwiftUI

extension View {
    func lineHeight(_ height: Double, size: Double) -> some View {
        let gap = Typeface.spacing(size: size, line: height)
        return lineSpacing(gap).padding(.vertical, gap / 2)
    }
}
