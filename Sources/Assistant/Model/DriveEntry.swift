import Foundation

public struct DriveEntry: Sendable, Equatable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let isFolder: Bool
    public let typeLabel: String
    public let modifiedAt: Date?
    public let webViewLink: String?

    public init(id: String, name: String, mimeType: String = "", isFolder: Bool = false, typeLabel: String = "",
                modifiedAt: Date? = nil, webViewLink: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.isFolder = isFolder
        self.typeLabel = typeLabel
        self.modifiedAt = modifiedAt
        self.webViewLink = webViewLink
    }
}

public struct OfferListing: Sendable, Equatable {
    public struct Offer: Sendable, Equatable {
        public let file: DriveEntry
        public let typeLabel: String
        public let documentNumber: String?

        public init(file: DriveEntry, typeLabel: String, documentNumber: String? = nil) {
            self.file = file
            self.typeLabel = typeLabel
            self.documentNumber = documentNumber
        }
    }

    public let outgoing: [Offer]
    public let incoming: [Offer]

    public init(outgoing: [Offer] = [], incoming: [Offer] = []) {
        self.outgoing = outgoing
        self.incoming = incoming
    }
}

public struct DriveLink: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    var name: String
    var mimeType: String
    var webViewLink: String?
    var subtitle: Phrase?

    init(id: String, name: String, mimeType: String, webViewLink: String? = nil, subtitle: Phrase? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.webViewLink = webViewLink
        self.subtitle = subtitle
    }
}
