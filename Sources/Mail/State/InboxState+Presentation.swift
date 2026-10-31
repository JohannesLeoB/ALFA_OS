import Core
import Design
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
                        count: folderCount(folder, inbox: count, inlet: inlet),
                        selected: folder.id == selectedFolder,
                        attention: attention(folder.role, inlet: inlet))
        }
    }

    private func attention(_ role: FolderRole, inlet: Inlet.ID) -> Bool {
        switch role {
        case .outbox: outbox.contains { $0.inlet == inlet && $0.state.needsAttention }
        case .later: outbox.contains { $0.inlet == inlet && $0.state.missed }
        default: false
        }
    }

    private func folderCount(_ folder: Folder, inbox: Int, inlet: Inlet.ID) -> Int {
        switch folder.role {
        case .inbox: inbox
        case .drafts: draftBadge(inlet)
        case .outbox: outbox.filter { $0.inlet == inlet && $0.state.plannedAt == nil }.count
        case .later: outbox.filter { $0.inlet == inlet && $0.state.plannedAt != nil }.count
        case .spam, .archive, .other: folderUnseen[folder.id] ?? 0
        default: 0
        }
    }

    public var loadProgress: SyncProgress? {
        _ = progressSerial
        guard let inlet = selectedInlet, let folder = selectedFolder else { return nil }
        return mailbox.progress(inlet, folder: folder)
    }

    func draftBadge(_ inlet: Inlet.ID) -> Int {
        let cards = drafts.filter { $0.inlet == inlet }
        let leaving = Set(cards.filter { Self.leaves($0.state) }.compactMap(\.mirrorID))
        let open = Set(cards.filter { !Self.leaves($0.state) }.compactMap(\.mirrorID))
        let kept = (mirroredDrafts[inlet] ?? []).subtracting(goneDrafts[inlet] ?? []).subtracting(plannedDrafts(inlet))
            .subtracting(leaving)
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
            FolderEntry(folder: folder, glyph: .tag, count: folderUnseen[folder.id] ?? 0, selected: folder.id == selectedFolder, attention: false)
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
        case .loading: .loading(progress: loadProgress)
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
        let outgoing = role == .sent || role == .drafts || role == .outbox || role == .later
        let draftsFolder = role == .drafts
        let queued = role == .outbox || role == .later ? Dictionary(outbox.map { ($0.id.uuidString, $0.state) }, uniquingKeysWith: { first, _ in first }) : [:]
        let now = clock()
        let people = outgoing ? [:] : Self.participants(in: summaries)
        let signature = draftsFolder ? selectedInlet.flatMap { signatures($0)?.block } : nil
        let writing = draftsFolder ? Dictionary(drafts.filter { $0.inlet == selectedInlet && $0.state != .sent }
            .compactMap { card in card.mirrorID.map { ($0, card) } }, uniquingKeysWith: { first, _ in first }) : [:]
        return entries.map { row in
            let item = row.summary
            let addressed = outgoing ? Self.addressed(item, card: writing[item.id]) : ""
            let party = outgoing ? Self.firstParty(addressed) : Self.sender(item)
            let name = draftsFolder ? Self.recipients(addressed) : (party.name.isEmpty ? party.address : party.name)
            var preview = draftsFolder ? PreviewEngine.draft(item.snippet, signature: signature) : PreviewEngine.text(item.snippet)
            if preview.isEmpty, let card = writing[item.id] { preview = PreviewEngine.text(card.draft.unsignedBody) }
            return RowPresentation(
                id: item.id,
                initials: PersonName.initials(party.name),
                sender: Self.senderLine(thread: row.threadCount > 1 ? people[item.threadID] : nil, name: name, unnamed: party.name.isEmpty),
                address: party.address,
                outgoing: outgoing,
                draft: draftsFolder,
                unread: !item.flags.contains(.seen),
                starred: item.flags.contains(.flagged),
                answered: item.flags.contains(.answered),
                selected: row.selected && stack.contains(.message(item.id)),
                picked: picked.contains(item.id),
                thread: row.threadCount > 1 && !draftsFolder ? row.threadCount : nil,
                attachments: item.attachments.map { AttachmentEntry(id: $0.id, name: $0.filename, size: Format.bytes($0.sizeBytes)) },
                attachmentTotal: max(item.attachmentCount, item.attachments.count),
                date: DateLabel.of(item.receivedAt, now: now),
                subject: item.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.subject,
                preview: preview.isEmpty ? nil : preview,
                outbox: queued[item.id]
            )
        }
    }

    static func participants(in list: [MessageSummary]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        var seen: Set<String> = []
        for item in list where !item.threadID.isEmpty {
            let party = sender(item)
            let name = party.name.isEmpty ? party.address : party.name
            guard !name.isEmpty, seen.insert(item.threadID + "\u{0}" + name.lowercased()).inserted else { continue }
            result[item.threadID, default: []].append(name)
        }
        return result
    }

    static func senderLine(thread: [String]?, name: String, unnamed: Bool) -> String {
        if let thread, thread.count > 1 { return thread.joined(separator: ", ") }
        return unnamed ? PersonName.middle(name, limit: NameLimit.sender) : name
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

    static func addressed(_ item: MessageSummary, card: OpenDraft?) -> String {
        [item.toRaw, item.ccRaw, item.bccRaw, card?.draft.bcc ?? ""].first { !AddressListParser.split($0).isEmpty } ?? ""
    }

    static func recipients(_ raw: String) -> String {
        AddressListParser.split(raw).map(PersonName.display).map { $0.name.isEmpty ? $0.address : $0.name }
            .filter { !$0.isEmpty }.joined(separator: ", ")
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
        case .later: .clock
        case .all: .allMail
        case .archive: .archive
        case .spam: .junk
        case .trash: .trash
        case .other: .folder
        }
    }
}

extension InboxState {
    func post(_ kind: ToastKind, undo: (@MainActor () async -> Void)? = nil, lasts: Duration? = nil) {
        toastSerial += 1
        toast = Toast(serial: toastSerial, kind: kind, undoable: undo != nil, lasts: lasts)
        undoAction = undo
    }

    public func announce(_ kind: ToastKind) {
        post(kind)
    }

    public func dismissToast(_ serial: Int) {
        guard toast?.serial == serial else { return }
        toast = nil
        undoAction = nil
    }

    public func undoToast() async {
        let action = undoAction
        toast = nil
        undoAction = nil
        await action?()
    }
}

extension InboxState {
    public func stripMarks(_ lane: LaneKind, height: Double) -> [StripMark] {
        switch lane {
        case .leading:
            return folderRows.map { row in
                StripMark(id: "folder." + row.folder.id, face: .glyph(row.glyph),
                          help: row.attention ? FolderName(key: "mail.strip.outboxNotSent", text: "") : folderName(row.folder.id),
                          selected: row.selected, dot: row.attention, run: .folder(row.folder.id))
            } + [StripMark(id: "compose", face: .glyph(.compose), help: FolderName(key: "mail.action.compose", text: ""),
                           selected: false, dot: false, accent: true, run: .compose)]
        case .center:
            let room = max(1, Int((height - Tokens.Size.stripReserveTop - Tokens.Size.stripReserveBottom) / Tokens.Size.rowHeight))
            return rowWindow(limit: room).items.map { row in
                StripMark(id: "row." + row.id, face: row.initials.isEmpty ? .glyph(.person) : .text(row.initials),
                          help: FolderName(key: nil, text: row.subject ?? ""), selected: row.selected, dot: row.unread,
                          run: .row(row.id))
            }
        case .trailing:
            let order = visibleStack
            if order.isEmpty { return [composeMark] }
            var marks: [StripMark] = []
            if case .message(let id) = frontRef {
                marks.append(StripMark(id: "reply", face: .glyph(.reply), help: FolderName(key: Action.reply.key, text: ""),
                                       selected: false, dot: false, run: .reply(id)))
                marks.append(StripMark(id: "forward", face: .glyph(.forward), help: FolderName(key: Action.forward.key, text: ""),
                                       selected: false, dot: false, run: .forward(id)))
            }
            return marks + order.compactMap { ref in
                switch ref {
                case .message(let id):
                    guard let card = card(id) else { return nil }
                    let initials = PersonName.initials(Self.sender(card.summary).name)
                    return StripMark(id: ref.id, face: initials.isEmpty ? .glyph(.person) : .text(initials),
                                     help: FolderName(key: nil, text: card.summary.subject), selected: false, dot: false, run: .card(ref))
                case .draft(let id):
                    guard let card = draft(id) else { return nil }
                    let help = card.draft.subject.isEmpty ? FolderName(key: "mail.row.newMessage", text: "")
                        : FolderName(key: nil, text: card.draft.subject)
                    return StripMark(id: ref.id, face: .glyph(.compose), help: help, selected: false, dot: false, run: .card(ref))
                }
            }
        }
    }

    var composeMark: StripMark {
        StripMark(id: "compose", face: .glyph(.compose), help: FolderName(key: "mail.action.compose", text: ""),
                  selected: false, dot: false, run: .compose)
    }

    public func run(_ mark: StripMark.Run) async {
        switch mark {
        case .folder(let id): await selectFolder(id)
        case .compose: compose()
        case .row(let id): await open(id)
        case .reply(let id): await reply(to: id)
        case .forward(let id): await forward(id)
        case .card(let ref): bring(ref)
        }
    }
}

extension InboxState {
    var visibleStack: [CardRef] {
        stack.filter { ref in
            if case .draft(let id) = ref, draft(id)?.state == .sent || (draft(id)?.state == .sending && isHeld(id)) {
                return false
            }
            return true
        }
    }

    public var frontRef: CardRef? {
        let visible = visibleStack
        if let front, visible.contains(front) { return front }
        return visible.last
    }

    public var stackOrder: [CardRef] {
        let visible = visibleStack
        guard let front = frontRef else { return visible }
        return visible.filter { $0 != front } + [front]
    }

    public var stackCount: Int { visibleStack.count }

    public func bring(_ ref: CardRef) {
        guard visibleStack.contains(ref) else { return }
        front = ref
        if case .message(let id) = ref { selectedMessage = id }
    }

    public func pin(_ id: String) {
        update(id) { $0.pinned = true }
    }

    public func card(_ id: String) -> OpenMessage? {
        cardIndex(id, in: selectedInlet).map { cards[$0] }
    }

    func cardIndex(_ id: String, in inlet: Inlet.ID?) -> Int? {
        cards.firstIndex { $0.id == id && $0.inlet == inlet }
    }

    func attach(_ ref: CardRef) {
        if !stack.contains(ref) { stack.append(ref) }
        front = ref
        opened += 1
        openOverview(false)
    }

    func detach(_ ref: CardRef) {
        stack.removeAll { $0 == ref }
        if front == ref { front = stack.last }
    }

    func dropPreviews() {
        let inlet = selectedInlet
        let gone = cards.filter { $0.inlet == inlet && !$0.pinned }.map(\.id)
        cards.removeAll { $0.inlet == inlet && !$0.pinned }
        for id in gone { detach(.message(id)) }
    }

    public func openOverview(_ open: Bool) {
        overview.open = open
        if !open { overview.hot = nil }
    }

    public func toggleTiles() {
        tiles.toggle()
        tileHot = nil
    }

    public func aimTile(_ id: String?) {
        tileHot = id
    }

    public func aimOverview(_ ref: CardRef?) {
        overview.hot = ref
    }

    func trimCards() {
        let inlet = selectedInlet
        while cards.filter({ $0.inlet == inlet }).count > Tokens.Count.stackMaxCards,
              let index = cards.firstIndex(where: { $0.inlet == inlet }) {
            detach(.message(cards.remove(at: index).id))
        }
    }

    public func commands(confirmDiscard: Bool, canFold: Bool, sendLabelled: Bool) -> CommandSet {
        var front: CommandEngine.Front?
        var trashes = true
        if case .message(let id) = frontRef, let card = card(id) {
            trashes = !inTrash(id)
            front = .message(hasCopy: !card.summary.ccRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else if case .draft(let id) = frontRef, let card = draft(id) {
            front = .draft(canSend: card.canSend)
        }
        return CommandEngine.commands(front: front, stackCount: stackCount, fanned: overview.open,
                                      hasFiles: mailbox.hasFiles, confirmDiscard: confirmDiscard, canFold: canFold,
                                      sendLabelled: sendLabelled, formatting: formatting, folders: folderActions, trashes: trashes)
    }
}
