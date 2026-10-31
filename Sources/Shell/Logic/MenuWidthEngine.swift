import Design
import Foundation

public enum MenuWidthEngine {
    public static func width(fitting natural: Double) -> Double {
        let step = Tokens.Size.menuWidthStep
        let rounded = (natural / step).rounded(.up) * step
        return min(max(rounded, Tokens.Size.menuMinWidth), Tokens.Size.menuMaxWidth)
    }
}
