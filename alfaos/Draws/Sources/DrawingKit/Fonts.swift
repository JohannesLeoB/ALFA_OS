import Foundation
import Pages

public struct SheetFonts: Sendable, Equatable {
    public var sans: String
    public var mono: String

    public init(sans: String, mono: String? = nil) {
        self.sans = sans
        self.mono = mono ?? sans
    }

    public static func upload(_ folder: URL) -> SheetFonts? {
        let faces = Fonts.upload(folder)
        return faces.first { $0.role == .sans }.map { sans in
            SheetFonts(sans: sans.family, mono: faces.first { $0.role == .mono }?.family)
        }
    }
}
