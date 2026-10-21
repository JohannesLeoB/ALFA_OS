import Foundation
import Pages

public struct SheetFonts: Sendable, Equatable {
    public var sans: String

    public init(sans: String) {
        self.sans = sans
    }

    public static func upload(_ folder: URL) -> SheetFonts? {
        Fonts.upload(folder).first { $0.role == .sans }.map { SheetFonts(sans: $0.family) }
    }
}
