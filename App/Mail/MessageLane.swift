import AppKit
import Core
import Design
import Mail
import Shell
import SwiftUI

struct MessageLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var scrolled = false
    @State private var text = ""
    @State private var filterAnchor = AnchorBox()
    @State private var window = SheetValues.listWindow
    @FocusState private var focused: Bool

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var title: String { FolderTitle.text(inbox.currentFolderName, localized: appearance.string) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header(width: proxy.size.width)
                if inbox.outboxUnsaved > 0 {
                    unsavedOutbox
                } else if case .offline = inbox.listState {
                    offline
                } else if let address = inbox.expiredAddress {
                    expired(address)
                } else if inbox.currentFolder?.role == .later {
                    laterNotice
                }
                content(width: proxy.size.width)
            }
        }
        .onChange(of: inbox.selectedFolder) {
            text = ""
            window = SheetValues.listWindow
        }
        .onChange(of: inbox.selectedInlet) { window = SheetValues.listWindow }
        .onChange(of: inbox.searching) { _, on in if !on { text = "" } }
        .onChange(of: text) { Task { await inbox.type(text) } }
    }

    private func header(width: Double) -> some View {
        LaneHead(scrolled: scrolled, lane: .center) {
            if inbox.picking {
                HeaderTitle(text: Text(verbatim: appearance.format("mail.pick.count", Format.number(inbox.pickedInList.count))))
                Spacer(minLength: 0)
                pickTools
            } else if inbox.searching {
                searchField
                tools(width: width)
            } else {
                HeaderTitle(text: Text(verbatim: title))
                Spacer(minLength: 0)
                tools(width: width)
            }
            laneTools(width: width)
        }
    }

    private func tools(width: Double) -> some View {
        let on = inbox.filter != .all
        let labelled = on && width >= Tokens.Size.breakpointFilterLabel
        return HStack(spacing: CGFloat(Tokens.Size.headGapList)) {
            filterButton(on: on, labelled: labelled)
            SymbolButton(help: appearance.string(inbox.searching ? "mail.search.close" : "mail.search.open"), glyph: .search,
                         selected: inbox.searching, hover: .none, pressed: false) {
                Task { await inbox.setSearching(!inbox.searching) }
            }
        }
    }

    @ViewBuilder
    private func filterButton(on: Bool, labelled: Bool) -> some View {
        let help = on ? appearance.format("mail.filter.named", filterName(inbox.filter)) : appearance.string("mail.filter")
        Group {
            if labelled {
                TextButton(label: Text(verbatim: filterName(inbox.filter)), kind: .accent, pressed: false, action: openFilter) { Glyph(.filter) }
            } else {
                SymbolButton(help: help, glyph: .filter, selected: on, hover: .none, pressed: false, action: openFilter)
            }
        }
        .help(Text(verbatim: help))
        .background(AnchorMarker(box: filterAnchor))
    }

    private func filterName(_ filter: InboxFilter) -> String {
        switch filter {
        case .all: appearance.string("mail.filter.all")
        case .unread: appearance.string("mail.filter.unread")
        case .attachments: appearance.string("mail.filter.attachments")
        }
    }

    private func openFilter() {
        let entries = InboxFilter.allCases.map { option in
            MenuEntry.row(MenuItem(id: filterName(option), label: Text(verbatim: filterName(option)),
                                   check: inbox.filter == option ? appearance.text("mail.menu.check") : nil) { inbox.setFilter(option) })
        }
        filterAnchor.showMenu(entries)
    }

    private var pickTools: some View {
        let all = inbox.pickedInList.count == inbox.rows.count
        return HStack(spacing: CGFloat(Tokens.Size.headGapList)) {
            SymbolButton(help: appearance.string(all ? "mail.pick.none" : "mail.pick.all"), glyph: .list, hover: .none, pressed: false) {
                inbox.pickAllToggle()
            }
            SymbolButton(help: appearance.string("mail.pick.read"), glyph: .envelope, hover: .none, pressed: false) {
                Task { await inbox.bulk(.read) }
            }
            if inbox.folderActions {
                SymbolButton(help: appearance.string("mail.action.archive"), glyph: .archive, hover: .none, pressed: false) {
                    Task { await inbox.bulk(.archive) }
                }
            }
            if inbox.currentFolder?.role != .trash {
                SymbolButton(help: appearance.string("mail.action.trash"), glyph: .trash, tone: \.signal, hover: .none, pressed: false) {
                    Task { await inbox.bulk(.trash) }
                }
            }
            SymbolButton(help: appearance.string("mail.pick.clear"), glyph: .close, hover: .none, pressed: false) { inbox.clearPicked() }
                .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder
    private func laneTools(width: Double) -> some View {
        let open = desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
        let maxed = desk.laneMode(desk.currentID).maximized == .center
        let tilesShown = inbox.offersTiles && (width >= SheetValues.tilesBreakpoint || inbox.tiles)
        if tilesShown {
            SymbolButton(help: appearance.string(inbox.tiles ? "mail.tiles.list" : "mail.tiles.grid"), glyph: .grid,
                         selected: inbox.tiles, hover: .none, pressed: false) {
                inbox.toggleTiles()
            }
        }
        if !(width < SheetValues.tilesBreakpoint && inbox.tiles && !maxed) {
            SymbolButton(help: maxed ? appearance.string("settings.account.back") : appearance.format("mail.grow.named", title),
                         glyph: maxed ? .shrink : .expand, hover: .none, pressed: false) {
                desk.toggleMaximize(.center)
            }
        }
        if open > 1 {
            SymbolButton(help: appearance.format("mail.fold.named", title), glyph: .minus, hover: .none, pressed: false) {
                desk.toggleFold(.center)
            }
        }
    }

    private var searchField: some View {
        let here = inbox.scope == .here
        let placeholder = here ? appearance.format("mail.search.placeholder.here", title) : appearance.string("mail.search.placeholder.all")
        return InputField(text: $text, placeholder: Text(verbatim: placeholder), labelKey: "mail.search.label", focus: $focused) {
            if inbox.offersScope {
                TextButton(label: Text(verbatim: here ? appearance.format("mail.search.scope.here", title) : appearance.string("mail.search.scope.all")),
                           kind: .quiet, size: .compact, truncates: true) {
                    Task { await inbox.toggleScope() }
                }
                .help(Text(verbatim: here ? appearance.format("mail.search.tip.here", title) : appearance.format("mail.search.tip.all", title)))
            }
        }
        .onSubmit { Task { await inbox.submit(text) } }
        .onKeyPress(.escape) {
            Task { await inbox.setSearching(false) }
            return .handled
        }
        .task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.searchFocusDelay))
            focused = true
        }
    }

    private var offline: some View {
        Notice(kind: .warning, title: appearance.text("mail.notice.offline.title"), text: appearance.text("mail.notice.offline.text"),
               glyph: { Glyph(.alert) },
               actions: { TextButton(label: appearance.text("mail.list.failed.act"), kind: .accent) { Task { await inbox.loadSelection() } } })
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
    }

    private var laterNotice: some View {
        Notice(kind: .warning, title: appearance.text("mail.later.notice.title"), text: appearance.text("mail.later.notice.text"),
               glyph: { Glyph(.clock) },
               actions: { EmptyView() })
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
    }

    private var unsavedOutbox: some View {
        Notice(kind: .failure, title: appearance.text("mail.notice.outboxUnsaved.title"),
               text: Text(verbatim: appearance.format("mail.notice.outboxUnsaved.text", Format.number(inbox.outboxUnsaved))),
               glyph: { Glyph(.alert) },
               actions: { TextButton(label: appearance.text("mail.draft.saveFailed.retry"), kind: .accent) { inbox.resaveOutbox() } })
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
    }

    private func expired(_ address: String) -> some View {
        Notice(kind: .failure, title: Text(verbatim: appearance.format("mail.list.signInExpired", address)),
               text: appearance.text("mail.list.signInExpired.text"),
               glyph: { Glyph(.alert) },
               actions: { TextButton(label: appearance.text("settings.action.reconnect"), kind: .accent) { openExpired() } })
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
    }

    private func openExpired() {
        if let service = inbox.fixCard(in: session.assembly.catalog) { session.openSettingsCard(service) } else { session.openMailCard(of: inbox.selectedAccount) }
    }

    @ViewBuilder
    private func content(width: Double) -> some View {
        if let kind = inbox.emptyKind {
            state(kind)
        } else if inbox.tiles && inbox.offersTiles {
            MessageTiles(session: session, window: $window)
        } else {
            rows(width: width)
        }
    }

    private func rows(width: Double) -> some View {
        let listed = inbox.rowWindow(limit: window + 1)
        let items = listed.items
        let picking = inbox.picking
        let spacer = ListWindowEngine.spacer(count: listed.total, window: window)
        return ScrollView {
            LazyVStack(spacing: 0) {
                if !inbox.typed.isEmpty, listed.total > 0 {
                    Text(verbatim: appearance.format("mail.search.results", Format.number(inbox.resultCount(loaded: listed.total))))
                        .designText(\.inkTertiary, size: Tokens.TextSize.small)
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                        .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step32), alignment: .bottomLeading)
                }
                ForEach(Array(items.prefix(window).enumerated()), id: \.element.id) { index, item in
                    let next = items.indices.contains(index + 1) ? items[index + 1] : nil
                    InboxRow(session: session, item: item,
                             separated: next != nil && !item.selected && next?.selected != true,
                             wide: width >= Tokens.Size.breakpointAttachments,
                             picking: picking)
                }
                if let tail = inbox.listTail, window >= listed.total {
                    let loading = inbox.listState == .loadingMore
                    TextButton(label: appearance.text(loading ? "mail.list.loadingMore" : tail.key), kind: .quiet) {
                        if !loading { Task { await inbox.loadTail() } }
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.top, CGFloat(Tokens.Spacing.step16))
                        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                }
                Color.clear
                    .frame(height: CGFloat(spacer))
                    .accessibilityHidden(true)
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.automatic)
        .scrolledSignal($scrolled)
        .loadsAhead(spacer: spacer) { inbox.extend(&window, total: listed.total) }
    }

    @ViewBuilder
    private func state(_ kind: EmptyKind) -> some View {
        switch kind {
        case .loading(let progress):
            ContentPlaceholder(loading: loadingText(progress))
        case .notConnected:
            ContentPlaceholder(kind: .permissionRequired, title: appearance.text("mail.list.notConnected"),
                               text: appearance.text("mail.list.notConnected.text"),
                               glyph: { Glyph(.envelope) },
                               action: { TextButton(label: appearance.text("mail.list.notConnected.act"), kind: .accent) { session.openMailCard(of: inbox.selectedAccount) } })
        case .failed(let last):
            ContentPlaceholder(kind: .failed, title: appearance.text("mail.list.failed"), text: failedText(last), glyph: { Glyph(.alert) },
                               action: { TextButton(label: appearance.text("mail.list.failed.act")) { Task { await inbox.loadSelection() } } })
        case .noResults(let query, let folder):
            ContentPlaceholder(kind: .noResults,
                               text: Text(verbatim: appearance.format("mail.list.emptySearch", query, FolderTitle.text(folder, localized: appearance.string))),
                               glyph: { Glyph(.search) },
                               action: { TextButton(label: appearance.text("mail.list.emptySearch.act")) { text = ""; Task { await inbox.submit("") } } })
        case .noFilterMatch:
            ContentPlaceholder(kind: .noResults, text: appearance.text("mail.list.noFilterMatch"), glyph: { Glyph(.filter) },
                               action: { TextButton(label: appearance.text("mail.list.noFilterMatch.act")) { inbox.setFilter(.all) } })
        case .empty:
            ContentPlaceholder(kind: .empty, text: appearance.text(emptyKey), glyph: { Glyph(inbox.currentFolderGlyph) },
                               action: {
                if inbox.offersCompose { TextButton(label: appearance.text("mail.action.compose")) { inbox.compose() } }
            })
        }
    }

    private func loadingText(_ progress: SyncProgress?) -> Text {
        guard let progress else { return appearance.text("mail.list.loading") }
        let line = appearance.format("mail.list.progress", String(progress.done), String(progress.total))
        return Text(verbatim: appearance.string("mail.list.loading") + "\n" + line)
    }

    private var emptyKey: String {
        guard let role = inbox.currentFolder?.role, role != .other, role != .outbox else { return "mail.empty.label" }
        return "mail.empty." + role.rawValue
    }

    private func failedText(_ last: Date?) -> Text {
        guard let last else { return appearance.text("mail.list.failed.text") }
        let now = inbox.now
        let relative = Self.relative.localizedString(for: min(last, now.addingTimeInterval(-1)), relativeTo: now)
        return Text(verbatim: appearance.string("mail.list.failed.text") + " " + appearance.format("mail.list.failed.last", relative))
    }
}

struct MessageCard: View {
    let session: AppSession
    let ref: CardRef
    let depth: Int
    let commands: CommandSet
    let perform: (Action) -> Void

    var body: some View {
        CardFace(depth: depth, lacquered: true, last: depth == session.inbox.stackOrder.count - 1,
                 bring: { session.inbox.bring(ref) }) { ink in
            Head(session: session, ref: ref, depth: depth, ink: ink)
        } content: {
            content
            if commands.hasFooter {
                Foot(session: session, commands: commands, perform: perform)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ref {
        case .message(let id):
            if let card = session.inbox.card(id) { MessageDetail(session: session, card: card) }
        case .draft(let id):
            if let card = session.inbox.draft(id) { DraftEditor(session: session, card: card) }
        }
    }
}

struct MessageDetail: View {
    let session: AppSession
    let card: OpenMessage

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    RecipientDetail(session: session, card: card)
                    SheetDetail(session: session, card: card)
                }
            }
            .scrollIndicators(.automatic)
            .task(id: card.id) {
                if !card.summary.threadID.isEmpty, card.conversation.isEmpty { await session.inbox.loadThreadTexts(card.id) }
                reveal(proxy)
            }
            .onChange(of: card.conversation.count) { reveal(proxy) }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        guard card.hasConversation, session.inbox.thread(card.id).first?.id != card.id else { return }
        proxy.scrollTo(card.id, anchor: .top)
    }
}

extension MessageCard {
    struct Head: View {
        @Environment(\.appearance) private var appearance
        let session: AppSession
        let ref: CardRef
        let depth: Int
        let ink: Color
        @State private var titleAnchor = AnchorBox()

        private var inbox: InboxState { session.inbox }

        private var front: Bool { depth == 0 }

        private var saving: Bool {
            guard front, case .draft(let id) = ref else { return false }
            return inbox.draft(id)?.state == .saving
        }

        var body: some View {
            CardHeader(front: front, ink: ink) {
                markView
            } title: {
                titleView
            } meta: {
                metaView
                    .font(.face(Tokens.TextSize.small))
                    .foregroundStyle(ink)
                    .opacity(CardStackEngine.metaOpacity(depth: depth))
            } trailing: {
                if case .message(let id) = ref, inbox.card(id)?.pinned == false {
                    CardHeadButton(help: appearance.string("mail.card.pin.tip"), glyph: .pin, ink: ink) { inbox.pin(id) }
                }
                CardHeadButton(help: appearance.string("card.close"), glyph: .close, ink: ink, fills: false, disabled: saving) { close() }
            }
        }

        private func close() {
            switch ref {
            case .message(let id): inbox.close(id)
            case .draft(let id): Task { await inbox.closeDraft(id) }
            }
        }

        private var party: (name: String, address: String)? {
            guard case .message(let id) = ref, let card = inbox.card(id) else { return nil }
            return inbox.party(card.summary)
        }

        private var draftPeople: [Participant] {
            guard case .draft(let id) = ref, let card = inbox.draft(id) else { return [] }
            return card.addressees
        }

        @ViewBuilder
        private var markView: some View {
            if let party {
                let initials = PersonName.initials(party.name)
                if initials.isEmpty { Glyph(.person) } else { Text(verbatim: initials) }
            } else {
                Glyph(.compose)
            }
        }

        @ViewBuilder
        private var titleView: some View {
            if case .message = ref, let party {
                let name = party.name.isEmpty ? PersonName.middle(party.address, limit: SheetValues.cardTitleLimit) : party.name
                Text(verbatim: name)
                    .designText(size: Tokens.TextSize.body, weight: .medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(Text(verbatim: front ? party.address : ""))
                    .background(AnchorMarker(box: titleAnchor))
                    .onTapGesture { if front { personMenu(party: party) } }
            } else if case .draft = ref {
                Group {
                    if let first = draftPeople.first {
                        Text(verbatim: appearance.format("mail.row.to", first.label))
                    } else {
                        appearance.text("mail.row.newMessage")
                    }
                }
                .designText(size: Tokens.TextSize.body, weight: .medium)
                .lineLimit(1)
                .truncationMode(.tail)
            }
        }

        private func personMenu(party: (name: String, address: String)) {
            let entries = session.personEntries(name: party.name, address: party.address, appearance: appearance)
            titleAnchor.showMenu(entries)
        }

        @ViewBuilder
        private var metaView: some View {
            if case .message(let id) = ref, let card = inbox.card(id), let party {
                if front {
                    Text(verbatim: party.name.isEmpty ? "" : PersonName.middle(party.address, limit: SheetValues.cardAddressLimit))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                    MessageDate.text(DateLabel.of(card.summary.receivedAt, now: inbox.now), draft: false, appearance: appearance)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            } else if case .draft(let id) = ref, let card = inbox.draft(id) {
                let more = max(0, draftPeople.count - 1)
                if !front && more > 0 {
                    Spacer(minLength: 0)
                    Text(verbatim: appearance.format("mail.read.more", Format.number(more)))
                        .lineLimit(1)
                } else {
                    draftMeta(card)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        private func draftMeta(_ card: OpenDraft) -> Text {
            guard front else { return Text(verbatim: card.draft.subject) }
            return card.status.map { appearance.text($0.key) } ?? Text(verbatim: card.draft.subject)
        }
    }
}

extension MessageCard {
    struct Foot: View {
        @Environment(\.appearance) private var appearance
        let session: AppSession
        let commands: CommandSet
        let perform: (Action) -> Void
        @State private var moreAnchor = AnchorBox()
        @State private var projectAnchor = AnchorBox()

        private var inbox: InboxState { session.inbox }

        var body: some View {
            HStack(spacing: CGFloat(Tokens.Size.headGapList)) {
                group(commands.footLeft)
                Spacer(minLength: 0)
                group(commands.footRight)
            }
            .padding(.horizontal, CGFloat(Tokens.Size.headPadRight))
            .frame(height: CGFloat(Tokens.Size.footerHeight))
            .overlay(alignment: .top) { Hairline() }
        }

        private func group(_ slots: [Slot]) -> some View {
            HStack(spacing: CGFloat(Tokens.Size.headGapStack)) {
                ForEach(slots) { slot in
                    slotView(slot).background { if slot.action == .send { sendKey } }
                }
            }
        }

        @ViewBuilder
        private func slotView(_ slot: Slot) -> some View {
            if slot.kind == .more {
                SymbolButton(help: appearance.string("settings.action.more"), glyph: .more, tone: \.inkSecondary, hover: .fill) { openMore() }
                    .background(AnchorMarker(box: moreAnchor))
            } else if slot.action == .send, slot.cost > ShellValues.commandIconCost {
                TextButton(label: appearance.text("mail.action.send"), kind: .accent, disabled: slot.off, action: { perform(.send) }) { Glyph(.send) }
            } else if let action = slot.action, action == .fromProject || action == .toProject, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, disabled: slot.off, tone: \.inkSecondary, hover: .fill) { openProjects() }
                    .background(AnchorMarker(box: projectAnchor))
            } else if let action = slot.action, let glyph = action.glyph {
                SymbolButton(help: session.help(action, appearance: appearance), glyph: glyph, selected: slot.accent, disabled: slot.off, tone: \.inkSecondary,
                             hover: .fill) {
                    perform(action)
                }
                .keyboardShortcut(action.shortcut)
            }
        }

        private var sendKey: some View {
            Button("") { submit() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        private func submit() {
            NSApp.keyWindow?.makeFirstResponder(nil)
            Task { @MainActor in
                await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
                guard case .draft(let id) = inbox.frontRef else { return }
                if inbox.draft(id)?.canSend == true { perform(.send) } else { inbox.refuseSend(id) }
            }
        }

        private func openProjects() {
            switch inbox.frontRef {
            case .draft(let id): ProjectFolderList.show(session, appearance: appearance, draft: id, anchor: projectAnchor)
            case .message(let id): ProjectFolderList.save(session, appearance: appearance, message: id, anchor: projectAnchor)
            case nil: break
            }
        }

        private func openMore() {
            if case .draft(let id) = inbox.frontRef {
                moreAnchor.showMenu(MenuLine.entries(MenuEngine.draftMore(receipt: inbox.asksReceipt(id)), appearance: appearance) { action in
                    switch action {
                    case .print: MessageExport.printDraft(inbox, id, settings: session.settings)
                    case .laterSend: moreAnchor.showMenu(planEntries(id))
                    default: inbox.toggleReceipt(id)
                    }
                })
                return
            }
            guard case .message(let id) = inbox.frontRef else { return }
            let lines = MenuEngine.readingMore(starred: inbox.card(id)?.summary.flags.contains(.flagged) ?? false, original: inbox.offersOriginal,
                                               unread: !(inbox.card(id)?.summary.flags.contains(.seen) ?? true),
                                               folders: inbox.folderActions, spam: inbox.offersSpam)
            let entries = MenuLine.entries(lines, appearance: appearance) { action in
                if action == .move {
                    moreAnchor.showMenu(MoveFolderList.entries(inbox, appearance: appearance, message: id))
                } else if action == .original {
                    SourceWindow.show(inbox, message: id, appearance: appearance)
                } else {
                    perform(action)
                }
            }
            moreAnchor.showMenu(entries)
        }

        private func planEntries(_ id: UUID) -> [MenuEntry] {
            let now = inbox.now
            let rows = inbox.planChoices.enumerated().map { index, date in
                MenuEntry.row(MenuItem(id: String(index), label: Text(verbatim: MessageDate.plan(date, now: now, appearance: appearance))) {
                    Task { await inbox.plan(id, at: date) }
                })
            }
            let custom = MenuEntry.row(MenuItem(id: "custom", label: appearance.text("mail.later.custom")) { inbox.pickPlan(id) })
            return [.head(id: "head", label: appearance.text("mail.later.folder"))] + rows + [.separator(id: "line"), custom]
        }
    }
}
