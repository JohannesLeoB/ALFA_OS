import CoreGraphics
import Foundation

public struct FontFace: Sendable, Equatable {
    public var role: FontRole
    public var family: String

    public init(role: FontRole, family: String) {
        self.role = role; self.family = family
    }

    public static func family(_ role: FontRole, in faces: [FontFace]) -> String {
        faces.first { $0.role == role }?.family ?? (role == .sans ? "Helvetica" : "Menlo")
    }
}

public struct Page: Sendable {
    public var size: CGSize
    public var background: String?
    public var items: [Item]

    public init(size: CGSize, background: String? = nil, items: [Item] = []) {
        self.size = size; self.background = background; self.items = items
    }
}

public struct Document: Sendable {
    public var pages: [Page]
    public var fonts: [FontFace]

    public init(pages: [Page] = [], fonts: [FontFace] = []) {
        self.pages = pages; self.fonts = fonts
    }

    public func family(_ role: FontRole) -> String {
        FontFace.family(role, in: fonts)
    }
}
