import Design
import SwiftUI

extension View {
    func ring<S: InsettableShape>(_ shape: S, _ color: Color?) -> some View {
        overlay(shape.strokeBorder(color ?? .clear, lineWidth: CGFloat(Tokens.Size.hairline)))
    }
}
