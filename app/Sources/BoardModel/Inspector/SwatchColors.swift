import Tokens

public extension BoardStore {
    /// The colors of the swatch items on the active space, in stacking order, each one once.
    /// A swatch whose hex text is not a color is left out.
    var swatchColors: [RGB] {
        var seen: Set<RGB> = []
        var colors: [RGB] = []
        for item in activeSpace?.items ?? [] {
            guard case .swatch(let hex, _) = item.content, let color = RGB(hex: hex), !seen.contains(color) else { continue }
            seen.insert(color)
            colors.append(color)
        }
        return colors
    }
}
