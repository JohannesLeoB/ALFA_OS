import Assistant

struct DriveListingClient: Assistant.DrivePort {
    let drive: any DrivePort
    let reader: DriveTextClient
    let convention: OfferConvention

    init(drive: any DrivePort, offers: OfferConvention) {
        self.drive = drive
        self.reader = DriveTextClient(drive: drive)
        self.convention = offers
    }

    func list(folderID: String) async throws -> [DriveEntry] {
        do {
            return try await drive.listFolder(folderID: folderID).map(Self.entry)
        } catch {
            throw FailureEngine.port(error)
        }
    }

    func offers(folderID: String) async throws -> OfferListing {
        do {
            let result = try await OfferScanEngine.load(rootFolderID: folderID, drive: drive, convention: convention)
            return OfferListing(outgoing: result.outgoing.map(Self.offer), incoming: result.incoming.map(Self.offer))
        } catch {
            throw FailureEngine.port(error)
        }
    }

    func findFile(named name: String, in folderID: String) async throws -> DriveEntry? {
        do {
            return try await reader.findFile(named: name, in: folderID).map(Self.entry)
        } catch {
            throw FailureEngine.port(error)
        }
    }

    func text(of file: DriveEntry) async throws -> String? {
        do {
            return try await reader.text(of: DriveFile(id: file.id, name: file.name, mimeType: file.mimeType,
                                                     modifiedAt: file.modifiedAt, webViewLink: file.webViewLink))
        } catch {
            throw FailureEngine.port(error)
        }
    }

    static func entry(_ file: DriveFile) -> DriveEntry {
        DriveEntry(id: file.id, name: file.name, mimeType: file.mimeType, isFolder: file.isFolder,
                   typeLabel: file.typeLabel, modifiedAt: file.modifiedAt, webViewLink: file.webViewLink)
    }

    static func offer(_ classified: ClassifiedOffer) -> OfferListing.Offer {
        OfferListing.Offer(file: entry(classified.file), typeLabel: classified.type.labelKey,
                           documentNumber: classified.documentNumber)
    }
}
