import Design
import SwiftUI

private struct DesignText: ViewModifier {
    @Environment(\.appearance) private var appearance
    let tone: KeyPath<Colors, ColorValue>
    let size: Double
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(Font(Typeface.font(size: size, weight: weight)))
            .foregroundStyle(appearance.color(tone))
    }
}

extension View {
    func designText(_ tone: KeyPath<Colors, ColorValue> = \.ink, size: Double = Tokens.TextSize.body, weight: Font.Weight = .regular) -> some View {
        modifier(DesignText(tone: tone, size: size, weight: weight))
    }

    func typeStyle(_ style: TypeStyle) -> some View {
        font(.face(style)).tracking(CGFloat(style.tracking * style.size))
    }
}
