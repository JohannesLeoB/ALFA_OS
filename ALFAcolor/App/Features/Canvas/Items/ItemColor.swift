import SwiftUI
import Tokens

extension Color {
    /// A color from the data of an item (a swatch or a shape). It is content, not a value of the interface.
    init(_ rgb: RGB) {
        let components = [rgb.r, rgb.g, rgb.b, rgb.a].map { CGFloat($0) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let color = CGColor(colorSpace: space, components: components) else {
            self = .clear
            return
        }
        self.init(cgColor: color)
    }
}
