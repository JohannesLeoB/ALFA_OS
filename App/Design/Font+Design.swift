import Design
import SwiftUI

extension Font {
    static func face(_ size: Double, weight: Int = Tokens.Weight.regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    static func face(_ style: TypeStyle) -> Font {
        face(style.size, weight: style.weight)
    }
}
