public enum AttachmentKind: Equatable, Sendable {
    case image, pdf, text

    init?(mimeType mime: String) {
        if mime.hasPrefix("image/") { self = .image }
        else if mime == "application/pdf" { self = .pdf }
        else if mime.hasPrefix("text/") || mime == "application/json" { self = .text }
        else { return nil }
    }
}

public enum AttachmentFailure: Error, Equatable {
    case unsupported(String)
    case tooLarge(String)
    case unreadable(String)
}
