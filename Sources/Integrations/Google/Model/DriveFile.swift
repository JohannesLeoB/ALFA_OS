import Foundation

struct DriveFile: Identifiable, Equatable, Sendable {
    static let folderMime = "application/vnd.google-apps.folder"
    static let nativePrefix = "application/vnd.google-apps."

    var id: String
    var name: String
    var mimeType: String
    var modifiedAt: Date?
    var webViewLink: String?
    var size: Int?

    var isFolder: Bool { mimeType == Self.folderMime }

    var isNative: Bool { mimeType.hasPrefix(Self.nativePrefix) }

    var typeLabel: String {
        switch mimeType {
        case Self.folderMime: "google.drive.type.folder"
        case "application/pdf": "google.drive.type.pdf"
        case "application/vnd.google-apps.spreadsheet": "google.drive.type.sheet"
        case "application/vnd.google-apps.document": "google.drive.type.document"
        case "application/vnd.google-apps.presentation": "google.drive.type.presentation"
        default:
            if mimeType.hasPrefix("image/") { "google.drive.type.image" }
            else if let subtype = mimeType.split(separator: "/").last, !subtype.isEmpty { subtype.uppercased() }
            else { "google.drive.type.file" }
        }
    }
}
