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
                if let address = inbox.expiredAddress { expired(address) }
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
            laneTools
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
            SymbolButton(help: appearance.string("mail.action.archive"), glyph: .archive, hover: .none, pressed: false) {
                Task { await inbox.bulk(.archive) }
            }
            SymbolButton(help: appearance.string("mail.action.trash"), glyph: .trash, tone: \.signal, hover: .none, pressed: false) {
                Task { await inbox.bulk(.trash) }
            }
            SymbolButton(help: appearance.string("mail.pick.clear"), glyph: .close, hover: .none, pressed: false) { inbox.clearPicked() }
        }
    }

    @ViewBuilder
    private var laneTools: some View {
        let open = desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
        if open > 1 {
            SymbolButton(help: appearance.format("mail.fold.named", title), glyph: .minus, pressed: false) { desk.toggleFold(.center) }
        }
        let maxed = desk.laneMode(desk.currentID).maximized == .center
        SymbolButton(help: maxed ? appearance.string("mail.lane.back") : appearance.format("mail.grow.named", title),
                     glyph: maxed ? .shrink : .expand, pressed: false) {
            desk.toggleMaximize(.center)
        }
    }

    private var searchField: some View {
        let here = inbox.searchScope == .here
        let placeholder = here ? appearance.format("mail.search.placeholder.here", title) : appearance.string("mail.search.placeholder.all")
        return InputField(text: $text, placeholder: Text(verbatim: placeholder), labelKey: "mail.search.label", focus: $focused) {
            TextButton(label: Text(verbatim: here ? appearance.format("mail.search.scope.here", title) : appearance.string("mail.search.scope.all")),
                       kind: .quiet, size: .compact) {
                Task { await inbox.toggleScope() }
            }
            .help(Text(verbatim: here ? appearance.format("mail.search.tip.here", title) : appearance.format("mail.search.tip.all", title)))
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

    private func expired(_ address: String) -> some View {
        Notice(kind: .failure, title: Text(verbatim: appearance.format("mail.list.signInExpired", address)),
               text: appearance.text("mail.list.signInExpired.text"),
               glyph: { Glyph(.alert) },
               actions: { TextButton(label: appearance.text("mail.list.signInExpired.act"), kind: .accent) { openExpired() } })
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.top, CGFloat(Tokens.Spacing.step8))
    }

    private func openExpired() {
        if let service = inbox.fixService(in: session.assembly.catalog) { session.openMailService(service) } else { session.openMailSettings() }
    }

    @ViewBuilder
    private func content(width: Double) -> some View {
        if let kind = inbox.emptyKind {
            state(kind)
        } else {
            rows(width: width)
        }
    }

    private func rows(width: Double) -> some View {
        let items = inbox.rowPresentations
        let trash = inbox.currentFolder?.role == .trash
        let picking = inbox.picking
        let spacer = ListWindowEngine.spacer(count: items.count, window: window)
        return ScrollView {
            LazyVStack(spacing: 0) {
                if !inbox.typed.isEmpty, !items.isEmpty {
                    Text(verbatim: appearance.format("mail.search.results", Format.number(items.count)))
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
                             inTrash: trash, picking: picking)
                }
                Color.clear
                    .frame(height: CGFloat(spacer))
                    .accessibilityHidden(true)
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.automatic)
        .scrolledSignal($scrolled)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            ListWindowEngine.remaining(content: Double(geometry.contentSize.height), offset: Double(geometry.contentOffset.y),
                                       container: Double(geometry.containerSize.height), spacer: spacer) < SheetValues.listLoadAhead
        } action: { was, near in
            if !was, near, window < items.count { window += SheetValues.listWindowStep }
        }
    }

    @ViewBuilder
    private func state(_ kind: EmptyKind) -> some View {
        switch kind {
        case .loading:
            ContentPlaceholder(loading: appearance.text("mail.list.loading"))
        case .notConnected:
            ContentPlaceholder(kind: .permissionRequired, title: appearance.text("mail.list.notConnected"),
                               text: appearance.text("mail.list.notConnected.text"),
                               glyph: { Glyph(.envelope) },
                               action: { TextButton(label: appearance.text("mail.list.notConnected.act"), kind: .accent) { session.openMailSettings() } })
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
        case .empty(let folder):
            ContentPlaceholder(kind: .empty,
                               text: Text(verbatim: appearance.format("mail.list.empty", FolderTitle.text(folder, localized: appearance.string))),
                               glyph: { Glyph(.inbox) },
                               action: { TextButton(label: appearance.text("mail.list.empty.act")) { inbox.compose() } })
        }
    }

    private func failedText(_ last: Date?) -> Text {
        guard let last else { return appearance.text("mail.list.failed.text") }
        let relative = Self.relative.localizedString(for: last, relativeTo: inbox.now)
        return Text(verbatim: appearance.string("mail.list.failed.text") + " " + appearance.format("mail.list.failed.last", relative))
    }
}
