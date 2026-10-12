import Foundation

public enum DocumentViewerMode: Equatable, Sendable {
    case pdf
    case image
    case quicklook
    case browserOnly

    public static func classify(mimeType: String) -> DocumentViewerMode {
        if mimeType == "application/pdf" { return .pdf }
        if mimeType.hasPrefix("image/") { return .image }
        if mimeType.hasPrefix("application/vnd.google-apps") { return .browserOnly }
        return .quicklook
    }
}

public enum DruckWeg: Equatable, Sendable {
    case direkt
    case oeffnenInApp
    case keiner

    public static func fuer(mode: DocumentViewerMode) -> DruckWeg {
        switch mode {
        case .pdf, .image: return .direkt
        case .quicklook:   return .oeffnenInApp
        case .browserOnly: return .keiner
        }
    }
}
