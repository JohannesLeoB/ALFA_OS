public struct RichRun: Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var link: String?

    public init(_ text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false, link: String? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.link = link
    }

    var plain: Bool { !bold && !italic && !underline && link == nil }
}
