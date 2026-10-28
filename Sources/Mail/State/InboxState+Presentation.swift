import Core
import Foundation
import Hub
import Shell

extension InboxState {
    public func folderName(_ id: String?) -> FolderName {
        guard let folder = folders.first(where: { $0.id == id }) else { return FolderName(key: nil, text: "") }
        if folder.role == .other { return FolderName(key: nil, text: folder.name) }
        return FolderName(key: "mail.role." + folder.role.rawValue, text: folder.name)
    }

    public var currentFolderName: FolderName { folderName(selectedFolder) }

    public var folderRows: [FolderEntry] {
        let count = unread[selectedInlet ?? ""] ?? 0
        return sortedFolders.filter { $0.role != .other }.map { folder in
            FolderEntry(folder: folder, glyph: Self.glyph(folder.role),
                        count: folder.role == .inbox ? count : folder.role == .drafts ? savedDraftCount : 0,
                        selected: folder.id == selectedFolder)
        }
    }

    public var labelRows: [FolderEntry] {
        sortedFolders.filter { $0.role == .other }.map { folder in
            FolderEntry(folder: folder, glyph: .tag, count: 0, selected: folder.id == selectedFolder)
        }
    }

    var savedDraftCount: Int {
        drafts.filter { card in
            switch card.state {
            case .sent, .queuedInOutbox, .sending: false
            default: card.remoteID != nil || { if case .saved = card.state { true } else { false } }()
            }
        }.count
    }

    var address: String { selectedAccount?.account ?? "" }

    public var accountReachable: Bool {
        switch listState {
        case .signInExpired, .failed: false
        default: true
        }
    }

    public var expiredAddress: String? {
        if case .signInExpired = listState { return address }
        return nil
    }

    public func fixService(in catalog: IntegrationCatalogStore) -> String? {
        guard let account = selectedAccount, case .failed(let hint) = account.state, hint.fixIn == .inlet(account.id) else { return nil }
        return catalog.info(forProvider: account.provider)?.id
    }

    public var emptyKind: EmptyKind? {
        switch listState {
        case .loading: .loading
        case .notConnected: .notConnected
        case .failed:
            .failed(lastLoaded: selectedInlet.flatMap { inlet in selectedFolder.flatMap { mailbox.lastSync(inlet, folder: $0) } })
        case .emptySearch(let query, let folder): .noResults(query: query, folder: folderName(folder))
        case .noFilterMatch: .noFilterMatch
        case .empty(let folder): .empty(folder: folderName(folder))
        case .signInExpired, .loadingMore, .loaded, .offline: nil
        }
    }

    public var rowPresentations: [RowPresentation] {
        let role = currentFolder?.role
        let outgoing = role == .sent || role == .drafts
        let draftsFolder = role == .drafts
        let now = clock()
        return rows.map { row in
            let item = row.summary
            let party = outgoing ? Self.firstParty(item.toRaw) : Self.sender(item)
            let name = party.name.isEmpty ? party.address : party.name
            return RowPresentation(
                id: item.id,
                initials: PersonName.initials(party.name),
                sender: party.name.isEmpty ? PersonName.middle(name, limit: NameLimit.sender) : name,
                address: party.address,
                outgoing: outgoing,
                draft: draftsFolder,
                unread: !item.flags.contains(.seen),
                starred: item.flags.contains(.flagged),
                selected: row.selected && stack.contains(.message(item.id)),
                picked: picked.contains(item.id),
                thread: row.threadCount > 1 ? row.threadCount : nil,
                attachments: item.attachments.map { AttachmentEntry(id: $0.id, name: $0.filename, size: Format.bytes($0.sizeBytes)) },
                attachmentTotal: max(item.attachmentCount, item.attachments.count),
                date: DateLabel.of(item.receivedAt, now: now),
                subject: item.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.subject,
                preview: item.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.snippet
            )
        }
    }

    public func party(_ item: MessageSummary) -> (name: String, address: String) {
        Self.sender(item)
    }

    static func sender(_ item: MessageSummary) -> (name: String, address: String) {
        let parsed = PersonName.display(item.fromRaw)
        let named = !item.from.isEmpty && !item.from.contains("@") ? item.from : parsed.name
        return (named, parsed.address.isEmpty ? item.from : parsed.address)
    }

    static func firstParty(_ raw: String) -> (name: String, address: String) {
        guard let first = AddressListParser.split(raw).first else { return ("", "") }
        return PersonName.display(first)
    }

    static func glyph(_ role: FolderRole) -> Icon {
        switch role {
        case .inbox: .inbox
        case .starred: .flag
        case .sent: .sent
        case .drafts: .docText
        case .all: .allMail
        case .archive: .archive
        case .spam: .junk
        case .trash: .trash
        case .other: .folder
        }
    }
}
