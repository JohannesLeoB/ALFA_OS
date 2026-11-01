import AppKit
import CoreText
import Design
import SwiftUI

enum Typeface {
    private final class Anchor {}

    private static let ready: Bool = {
        guard let url = Bundle(for: Anchor.self).url(forResource: "Geist-VariableFont_wght", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func font(size: Double, weight: Int) -> NSFont {
        _ = ready
        let size = CGFloat(size)
        if let family = Tokens.Family.text.first {
            let variation = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
            let descriptor = NSFontDescriptor(fontAttributes: [.family: family, variation: [SheetValues.weightAxis: weight]])
            if let font = NSFont(descriptor: descriptor, size: size), font.familyName == family { return font }
        }
        return NSFont.systemFont(ofSize: size, weight: systemWeight(weight))
    }

    static func font(size: Double, weight: Font.Weight) -> NSFont {
        font(size: size, weight: value(weight))
    }

    static func draft(size: Double) -> NSFont {
        NSFont.systemFont(ofSize: CGFloat(size))
    }

    static func spacing(size: Double, line: Double, face: NSFont? = nil) -> CGFloat {
        let face = face ?? font(size: size, weight: Tokens.Weight.regular)
        return max(0, CGFloat(line) - (face.ascender - face.descender + face.leading))
    }

    static func width(_ text: String, size: Double, weight: Int) -> Double {
        Double((text as NSString).size(withAttributes: [.font: font(size: size, weight: weight)]).width)
    }

    private static func value(_ weight: Font.Weight) -> Int {
        switch weight {
        case .light: Tokens.Weight.light
        case .medium: Tokens.Weight.medium
        case .semibold: Tokens.Weight.semibold
        default: Tokens.Weight.regular
        }
    }

    private static func systemWeight(_ value: Int) -> NSFont.Weight {
        switch value {
        case ..<Tokens.Weight.regular: .light
        case ..<Tokens.Weight.medium: .regular
        case ..<Tokens.Weight.semibold: .medium
        default: .semibold
        }
    }
}

extension Font {
    static func face(_ size: Double, weight: Int = Tokens.Weight.regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    static func face(_ style: TypeStyle) -> Font {
        face(style.size, weight: style.weight)
    }
}

extension View {
    func lineHeight(_ height: Double, size: Double) -> some View {
        let gap = Typeface.spacing(size: size, line: height)
        return lineSpacing(gap).padding(.vertical, gap / 2)
    }
}

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
        let face = Typeface.font(size: style.size, weight: style.weight)
        let natural = face.ascender - face.descender + face.leading
        return font(.face(style))
            .tracking(CGFloat(style.tracking * style.size))
            .lineSpacing(max(0, CGFloat(style.lineHeight) - natural))
    }
}
