import ALFAcolorCore

/// The kind of an item as the inspector names it. Each kind has its name in the string catalog.
public enum ItemKind: String, CaseIterable, Sendable {
    case code, frame, group, image, link, note, shape, swatch, text

    public init(_ content: Content) {
        switch content {
        case .code: self = .code
        case .frame: self = .frame
        case .group: self = .group
        case .image: self = .image
        case .link: self = .link
        case .note: self = .note
        case .shape: self = .shape
        case .swatch: self = .swatch
        case .text: self = .text
        }
    }

    /// The key of the name in the string catalog, for example "item.kind.note".
    public var nameKey: String { "item.kind.\(rawValue)" }
}
