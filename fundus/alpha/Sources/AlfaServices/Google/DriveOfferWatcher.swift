import Foundation
import Observation
import AlfaKit

@MainActor
@Observable
public final class DriveOfferWatcher {
    private let client: GoogleDriveFetching
    private var seen: Set<String> = []
    private var baselined = false

    public init(client: GoogleDriveFetching = GoogleDriveClient()) {
        self.client = client
    }

    public func poll(projectID: String, folderID: String) async -> [WidgetSignal] {
        guard folderID.isEmpty == false else { return [] }
        guard let files = try? await client.listFolder(folderID: folderID) else { return [] }

        let nonFolders = files.filter { $0.mimeType != "application/vnd.google-apps.folder" }

        guard baselined else {
            seen = Set(nonFolders.map(\.id))
            baselined = true
            return []
        }

        let fresh = nonFolders.filter { seen.contains($0.id) == false }
        seen.formUnion(fresh.map(\.id))
        return fresh.map { file in
            if Self.isOffer(file) { return .offerDetected(projectID: projectID, label: file.name) }
            if Self.isWerkzeichnung(file) { return .drawingDetected(projectID: projectID, label: file.name) }
            return .driveFileAdded(projectID: projectID, fileName: file.name)
        }
    }

    nonisolated public static let offerKeywords = ["angebot", "rechnung", "kostenvoranschlag", "offer", "invoice"]

    nonisolated public static let acceptedOfferExtensions: Set<String> = [
        "pdf",
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp",
        "eml", "msg"
    ]
    nonisolated public static let acceptedOfferMimeTypes: Set<String> = [
        "application/pdf",
        "message/rfc822"
    ]

    nonisolated public static func isAcceptedOfferFileType(_ file: GoogleDriveFile) -> Bool {
        if file.isFolder { return false }
        let ext = (file.name as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            return acceptedOfferMimeTypes.contains(file.mimeType)
                || file.mimeType.hasPrefix("image/")
        }
        return acceptedOfferExtensions.contains(ext)
    }

    nonisolated public static func detectOffers(in files: [GoogleDriveFile]) -> [GoogleDriveFile] {
        files.filter { isOffer($0) }
    }

    nonisolated public static func isOffer(_ file: GoogleDriveFile) -> Bool {
        guard isAcceptedOfferFileType(file) else { return false }
        let name = file.name.lowercased()
        return offerKeywords.contains { name.contains($0) }
    }

    nonisolated public static let drawingKeywords = ["zeichnung", "werkzeichnung"]

    nonisolated public static func isWerkzeichnung(_ file: GoogleDriveFile) -> Bool {
        guard isAcceptedOfferFileType(file) else { return false }
        let name = file.name.lowercased()
        return drawingKeywords.contains { name.contains($0) }
    }
}
