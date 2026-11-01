import Foundation

public struct ListFolderTool: ToolPort {
    static let rowLimit = 30

    private let drive: any DrivePort

    public init(drive: any DrivePort) {
        self.drive = drive
    }

    public var name: String { "list_drive_folder" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .drive }
    public var manifestID: String { "DRIVE_ASSISTANT_LIST" }
    public var focusNeed: FocusNeed { .driveFolder }
    public var parameters: [ToolParameter] { [ToolParameter("unterordner")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        guard let folderID = scope.driveFolderID else { return .failure("assistant.drive.noFolder") }
        let filter = input.text("unterordner").lowercased()
        do {
            var files = try await drive.list(folderID: folderID)
            var subfolder: String?
            if filter.isEmpty == false {
                guard let sub = files.first(where: { $0.isFolder && $0.name.lowercased().contains(filter) }) else {
                    let folders = files.filter(\.isFolder).map(\.name).joined(separator: ", ")
                    return ToolResult(.make("assistant.drive.subfolderMissing", filter, folders))
                }
                files = try await drive.list(folderID: sub.id)
                subfolder = sub.name
            }
            return format(files, subfolder: subfolder)
        } catch PortFailure.notConnected {
            return .failure("assistant.drive.notConnected")
        } catch {
            return .failure("assistant.drive.failed", PortFailure.detail(of: error))
        }
    }

    private func format(_ files: [DriveEntry], subfolder: String?) -> ToolResult {
        guard files.isEmpty == false else {
            return ToolResult(subfolder.map { .make("assistant.drive.emptySub", $0) } ?? .make("assistant.drive.emptyRoot"))
        }
        let header: Phrase = subfolder.map { .make("assistant.drive.headerSub", $0, String(files.count)) }
            ?? .make("assistant.drive.headerRoot", String(files.count))
        var lines = [header]
        for file in files.prefix(Self.rowLimit) {
            let day = file.modifiedAt.map { " \u{2014} " + ListingEngine.shortDay($0) } ?? ""
            lines.append(.raw("\u{2022} \(file.name) [\(file.typeLabel)]\(day)"))
        }
        if files.count > Self.rowLimit { lines.append(.make("assistant.drive.more", String(files.count - Self.rowLimit))) }
        return ToolResult(lines: lines)
    }
}

public struct ListDocumentsTool: ToolPort {
    private let receipts: any ReceiptPort

    public init(receipts: any ReceiptPort) {
        self.receipts = receipts
    }

    public var name: String { "list_belege" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .drive }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("projekt")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("projekt").lowercased()
        let all = await receipts.receipts()
        let match = query.isEmpty ? all : all.filter {
            $0.projectNumber.lowercased().contains(query)
                || $0.number.lowercased().contains(query)
                || ($0.customerName?.lowercased().contains(query) ?? false)
        }
        guard match.isEmpty == false else {
            return ToolResult(query.isEmpty ? .make("assistant.receipts.none") : .make("assistant.receipts.noMatch", query))
        }
        let rows: [Phrase] = match.sorted { $0.createdAt > $1.createdAt }.prefix(ListingEngine.rowLimit).map { entry in
            var text = "\u{2022} \(entry.kind) \(entry.number) | \(entry.projectNumber)"
            if let customer = entry.customerName, customer.isEmpty == false { text += " | \(customer)" }
            return .raw(text + " | \(ListingEngine.day(entry.createdAt))")
        }
        return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
    }
}

struct ReadFileTool: ToolPort {
    private let drive: any DrivePort
    private let projects: ProjectSearchEngine

    init(drive: any DrivePort, projects: ProjectSearchEngine) {
        self.drive = drive
        self.projects = projects
    }

    var name: String { "read_drive_file" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .drive }
    var manifestID: String { "DRIVE_FILE_READ" }
    var parameters: [ToolParameter] { [ToolParameter("datei", required: true), ToolParameter("projekt")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let fileName = input.text("datei")
        guard fileName.isEmpty == false else { return .failure("assistant.file.whichFile") }
        var folderID = scope.driveFolderID ?? ""
        let query = input.text("projekt")
        if query.isEmpty == false, let folder = projects.resolve(query)?.driveFolderID, folder.isEmpty == false {
            folderID = folder
        } else if folderID.isEmpty {
            return .failure("assistant.file.noProject")
        }
        do {
            guard let file = try await drive.findFile(named: fileName, in: folderID) else {
                return .failure("assistant.file.notFound", fileName)
            }
            guard let text = try await drive.text(of: file) else {
                return ToolResult(.make("assistant.file.noText", file.name))
            }
            return ToolResult(lines: [.make("assistant.file.content", file.name), .raw(""), .raw(text)])
        } catch PortFailure.notConnected {
            return .failure("assistant.file.noAccess")
        } catch {
            return .failure("assistant.file.readFailed", PortFailure.detail(of: error))
        }
    }
}

struct ProposeFileTool: ToolPort {
    private let artifacts: any ArtifactPort
    private let projects: ProjectSearchEngine
    private let pdf: (any PdfRenderPort)?
    private let clock: @Sendable () -> Date

    init(artifacts: any ArtifactPort, projects: ProjectSearchEngine, pdf: (any PdfRenderPort)? = nil,
         clock: @escaping @Sendable () -> Date = { Date() }) {
        self.artifacts = artifacts
        self.projects = projects
        self.pdf = pdf
        self.clock = clock
    }

    var name: String { "erzeuge_datei" }
    var access: ToolAccess { .write }
    var privacy: PrivacyCategory { .drive }
    var documented: Bool { false }
    var parameters: [ToolParameter] {
        [
            ToolParameter("dateiname", required: true), ToolParameter("format", required: true),
            ToolParameter("inhalt", required: true), ToolParameter("titel"), ToolParameter("projekt"),
        ]
    }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let fileName = input.text("dateiname")
        guard fileName.isEmpty == false else { return .failure("assistant.file.noName") }
        let rawFormat = input.text("format").lowercased()
        guard let format = FileDraft.Format(rawValue: rawFormat) else { return .failure("assistant.file.badFormat", rawFormat) }
        let content = input.values["inhalt"] ?? ""
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .failure("assistant.file.empty")
        }
        var projectNumber: String?
        let wanted = input.text("projekt")
        if wanted.isEmpty == false {
            guard let match = projects.resolve(wanted) else { return .failure("assistant.file.noProjectMatch", wanted) }
            guard let folder = match.driveFolderID, folder.isEmpty == false else {
                return .failure("assistant.file.noProjectFolder", match.projectNumber)
            }
            projectNumber = match.projectNumber
        }
        let title = input.text("titel")
        var draft = FileDraft(fileName: fileName, format: format, title: title.isEmpty ? fileName : title,
                              content: content, projectNumber: projectNumber)
        let data: Data
        do {
            data = try await Self.data(for: draft, pdf: pdf)
        } catch PortFailure.notConnected {
            return .failure("assistant.file.noPdf")
        } catch {
            return .failure("assistant.file.writeFailed", error.localizedDescription)
        }
        do {
            draft.savedPath = try artifacts.write(data, name: draft.fullName, at: clock()).path
        } catch {
            return .failure("assistant.file.writeFailed", error.localizedDescription)
        }
        let line: Phrase = projectNumber.map { .make("assistant.file.savedProject", draft.fullName, $0) }
            ?? .make("assistant.file.saved", draft.fullName)
        return ToolResult(line, cards: [.fileDraft(draft)])
    }

    private static func data(for draft: FileDraft, pdf: (any PdfRenderPort)?) async throws -> Data {
        switch draft.format {
        case .text, .csv:
            return Data(draft.content.utf8)
        case .pdf:
            guard let pdf else { throw PortFailure.notConnected }
            return try await pdf.render(title: draft.title, rows: draft.rows)
        }
    }
}

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
