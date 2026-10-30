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

    static func spacing(size: Double, line: Double) -> CGFloat {
        let face = font(size: size, weight: Tokens.Weight.regular)
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
