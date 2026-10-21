import CoreText
import DrawingKit
import Foundation
import ShellCore

public enum DrawsFonts {
    private static let ready: Bool = {
        guard let url = Bundle.module.url(forResource: "Geist-VariableFont_wght", withExtension: "ttf") else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    public static func register() {
        _ = ready
    }

    public static var fallback: SheetFonts {
        register()
        return SheetFonts(sans: Design.Family.text.first ?? "")
    }

    public static func resolve(upload folder: URL?) -> SheetFonts {
        folder.flatMap(SheetFonts.upload) ?? fallback
    }
}
