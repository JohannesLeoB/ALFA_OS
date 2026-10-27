struct FindOffersTool: ToolPort {
    static let textLimit = 20
    static let cardLimit = 40

    private let drive: any DrivePort
    private let projects: ProjectSearchEngine

    init(drive: any DrivePort, projects: ProjectSearchEngine) {
        self.drive = drive
        self.projects = projects
    }

    var name: String { "find_offers" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .drive }
    var manifestID: String { "DRIVE_OFFERS_FIND" }
    var parameters: [ToolParameter] { [ToolParameter("projekt")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        var folderID = scope.driveFolderID ?? ""
        var label: String?
        let query = input.text("projekt")
        if folderID.isEmpty || query.isEmpty == false {
            guard query.isEmpty == false else { return .failure("assistant.offers.whichProject") }
            guard let entry = projects.resolve(query) else { return .failure("assistant.offers.projectMissing", query) }
            guard let folder = entry.driveFolderID, folder.isEmpty == false else {
                return .failure("assistant.offers.noFolder", entry.title, entry.projectNumber)
            }
            folderID = folder
            label = "\(entry.title) (\(entry.projectNumber))"
        }
        do {
            let listing = try await drive.offers(folderID: folderID)
            return Self.result(listing, label: label)
        } catch PortFailure.notConnected {
            return .failure("assistant.drive.notConnected")
        } catch {
            return .failure("assistant.offers.failed", PortFailure.detail(of: error))
        }
    }

    static func result(_ listing: OfferListing, label: String?) -> ToolResult {
        guard listing.incoming.isEmpty == false || listing.outgoing.isEmpty == false else {
            return ToolResult(label.map { .make("assistant.offers.emptyNamed", $0) } ?? .make("assistant.offers.emptyCurrent"))
        }
        var lines: [Phrase] = [label.map { .make("assistant.offers.headerNamed", $0) } ?? .make("assistant.offers.headerCurrent")]
        if listing.outgoing.isEmpty == false {
            lines += [.raw(""), .make("assistant.offers.outgoingHeader", String(listing.outgoing.count))]
            lines += rows(listing.outgoing)
        }
        if listing.incoming.isEmpty == false {
            lines += [.raw(""), .make("assistant.offers.incomingHeader", String(listing.incoming.count))]
            lines += rows(listing.incoming)
        }
        let links = links(listing.outgoing, direction: "assistant.offers.outgoing") + links(listing.incoming, direction: "assistant.offers.incoming")
        return ToolResult(lines: lines, cards: links.isEmpty ? [] : [.driveFiles(links)])
    }

    static func rows(_ offers: [OfferListing.Offer]) -> [Phrase] {
        offers.prefix(textLimit).map { offer in
            var text = "\u{2022} \(offer.file.name) [\(offer.typeLabel)]"
            if let number = offer.documentNumber { text += " \u{00B7} \(number)" }
            if let date = offer.file.modifiedAt { text += " \u{00B7} \(ListingEngine.shortDay(date))" }
            return .raw(text)
        }
    }

    static func links(_ offers: [OfferListing.Offer], direction: String) -> [DriveLink] {
        offers.prefix(cardLimit).map { offer in
            var parts: [Phrase] = [.make(direction), .raw(" \u{00B7} \(offer.typeLabel)")]
            if let date = offer.file.modifiedAt { parts.append(.raw(" \u{00B7} \(ListingEngine.shortDay(date))")) }
            return DriveLink(id: offer.file.id, name: offer.file.name, mimeType: offer.file.mimeType,
                             webViewLink: offer.file.webViewLink, subtitle: .join(parts, ""))
        }
    }
}
