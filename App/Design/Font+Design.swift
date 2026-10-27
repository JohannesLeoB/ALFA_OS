import Design
import SwiftUI

extension Font {
    static func face(_ size: Double, weight: Int = Tokens.Weight.regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }
}
