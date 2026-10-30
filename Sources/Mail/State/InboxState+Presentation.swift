import Core
import Foundation
import Hub
import Shell

extension InboxState {
    public func folderName(_ id: String?) -> FolderName {
        guard let folder = listedFolders.first(where: { $0.id == id }) else { return FolderName(key: nil, text: "") }
        if folder.role == .other { return FolderName(key: nil, text: folder.name) }
        return FolderName(key: folder.role.nameKey, text: folder.name)
    }

    public var currentFolderGlyph: Icon {
        guard let role = currentFolder?.role, role != .other else { return .tag }
        return Self.glyph(role)
    }

    public var offersCompose: Bool {
        switch currentFolder?.role {
        case .inbox, .sent, .drafts, .all: true
        default: false
        }
    }

    public var offersTiles: Bool {
        emptyKind == nil && hasRows && typed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var currentFolderName: FolderName { folderName(selectedFolder) }

    public var folderRows: [FolderEntry] {
        let inlet = selectedInlet ?? ""
        let count = unread[inlet] ?? 0
        return sortedFolders.filter { $0.role != .other }.map { folder in
            FolderEntry(folder: folder, glyph: Self.glyph(folder.role),
                        count: folder.role == .inbox ? count : folder.role == .drafts ? draftBadge(inlet) : folder.role == .outbox ? unsent(inlet) : 0,
                        selected: folder.id == selectedFolder,
                        attention: folder.role == .outbox && outbox.contains { $0.inlet == inlet && $0.state.needsAttention })
        }
    }

    func draftBadge(_ inlet: Inlet.ID) -> Int {
        let cards = drafts.filter { $0.inlet == inlet }
        let leaving = Set(cards.filter { Self.leaves($0.state) }.compactMap(\.mirrorID))
        let open = Set(cards.filter { !Self.leaves($0.state) }.compactMap(\.mirrorID))
        let kept = (mirroredDrafts[inlet] ?? []).subtracting(goneDrafts[inlet] ?? []).subtracting(leaving)
        return kept.union(open).count
    }

    private static func leaves(_ state: DraftState) -> Bool {
        switch state {
        case .sending, .queuedInOutbox, .sent: true
        default: false
        }
    }

    public var showsLabelHeading: Bool {
        selectedInlet.map { mailbox.usesLabels($0) } ?? false
    }

    public var labelRows: [FolderEntry] {
        sortedFolders.filter { $0.role == .other }.map { folder in
            FolderEntry(folder: folder, glyph: .tag, count: 0, selected: folder.id == selectedFolder, attention: false)
        }
    }

    public var outboxUnsaved: Int {
        _ = outbox
        return outboxPort.unsavedCount
    }

    public func resaveOutbox() {
        outboxPort.resave()
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
        presentations(of: rows)
    }

    public func rowWindow(limit: Int) -> RowWindow {
        let list = listed(limit: limit)
        return RowWindow(items: presentations(of: list.entries), total: list.total)
    }

    private func presentations(of entries: [ListEntry]) -> [RowPresentation] {
        let role = currentFolder?.role
        let outgoing = role == .sent || role == .drafts || role == .outbox
        let draftsFolder = role == .drafts
        let queued = role == .outbox ? Dictionary(outbox.map { ($0.id.uuidString, $0.state) }, uniquingKeysWith: { first, _ in first }) : [:]
        let now = clock()
        return entries.map { row in
            let item = row.summary
            let party = outgoing ? Self.firstParty(item.toRaw) : Self.sender(item)
            let name = party.name.isEmpty ? party.address : party.name
            let preview = PreviewEngine.text(item.snippet)
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
                preview: preview.isEmpty ? nil : preview,
                outbox: queued[item.id]
            )
        }
    }

    public func preview(_ item: MessageSummary) -> String {
        PreviewEngine.text(item.snippet)
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
        case .outbox: .send
        case .all: .allMail
        case .archive: .archive
        case .spam: .junk
        case .trash: .trash
        case .other: .folder
        }
    }
}
