import AppKit
import Mail
import ShellCore
import SwiftUI

func folderTitle(_ name: MailFolderName) -> String {
    name.key.map { words($0) } ?? name.text
}

struct MailListLane: View {
    let model: MailModel
    @Environment(\.design) private var design
    @Environment(\.mailLaneLink) private var link
    @State private var scrolled = false
    @State private var text = ""
    @State private var filterAnchor = AnchorBox()
    @FocusState private var focused: Bool

    private var title: String { folderTitle(model.currentFolderName) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header(width: proxy.size.width)
                if let address = model.expiredAddress { expired(address) }
                content(width: proxy.size.width)
            }
        }
        .onChange(of: model.selectedFolder) { text = "" }
        .onChange(of: model.searching) { _, on in if !on { text = "" } }
        .task(id: text) {
            guard model.searching || !text.isEmpty else { return }
            if !text.isEmpty { try? await Task.sleep(for: .seconds(MailSheet.searchDelay)) }
            if !Task.isCancelled { await model.search(text) }
        }
    }

    private func header(width: Double) -> some View {
        LaneHead(scrolled: scrolled) {
            if model.picking {
                HeaderTitle(text: line("mail.pick.count", model.pickedInList.count))
                Spacer(minLength: 0)
                pickTools
            } else if model.searching {
                searchField
                tools(width: width)
            } else {
                HeaderTitle(text: Text(verbatim: title))
                if MailSheet.listCountShown, model.listUnread > 0 {
                    Counter(value: MailNames.number(model.listUnread))
                }
                Spacer(minLength: 0)
                tools(width: width)
            }
            laneTools
        }
    }

    private func tools(width: Double) -> some View {
        let on = model.filter != .all
        let labelled = on && width >= Design.Size.breakpointFilterLabel
        return HStack(spacing: CGFloat(Design.Size.headGapList)) {
            filterButton(on: on, labelled: labelled)
            HeadSymbol(help: words(model.searching ? "mail.search.close" : "mail.search.open"), glyph: .search, selected: model.searching, hover: .none) {
                Task { await model.setSearching(!model.searching) }
            }
        }
    }

    @ViewBuilder
    private func filterButton(on: Bool, labelled: Bool) -> some View {
        let help = on ? words("mail.filter.named", filterName(model.filter)) : words("mail.filter")
        Group {
            if labelled {
                TextButton(label: Text(verbatim: filterName(model.filter)), kind: .accent, action: openFilter) { Glyph(.filter) }
            } else {
                HeadSymbol(help: help, glyph: .filter, selected: on, hover: .none, action: openFilter)
            }
        }
        .help(Text(verbatim: help))
        .background(AnchorProbe(box: filterAnchor))
    }

    private func filterName(_ filter: MailFilter) -> String {
        switch filter {
        case .all: words("mail.filter.all")
        case .unread: words("mail.filter.unread")
        case .attachments: words("mail.filter.attachments")
        }
    }

    private func openFilter() {
        guard let rect = filterAnchor.screenRect() else { return }
        let entries = MailFilter.allCases.map { option in
            MenuEntry.row(MenuItem(id: filterName(option), label: Text(verbatim: filterName(option)),
                                   check: model.filter == option ? word("mail.menu.check") : nil) { model.setFilter(option) })
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthNarrow, anchor: .rect(rect), window: NSApp.keyWindow)
    }

    private var pickTools: some View {
        let all = model.pickedInList.count == model.rows.count
        return HStack(spacing: CGFloat(Design.Size.headGapList)) {
            HeadSymbol(help: words(all ? "mail.pick.none" : "mail.pick.all"), glyph: .list, hover: .none) { model.pickAllToggle() }
            HeadSymbol(help: words("mail.pick.read"), glyph: .envelope, hover: .none) { Task { await model.bulk(.read) } }
            HeadSymbol(help: words("mail.action.archive"), glyph: .archive, hover: .none) { Task { await model.bulk(.archive) } }
            HeadSymbol(help: words("mail.action.trash"), glyph: .trash, tone: \.signal, hover: .none) { Task { await model.bulk(.trash) } }
            HeadSymbol(help: words("mail.pick.clear"), glyph: .close, hover: .none) { model.clearPicked() }
        }
    }

    @ViewBuilder
    private var laneTools: some View {
        if let link {
            if link.openLanes > 1 {
                HeadSymbol(help: words("mail.fold.named", title), glyph: .minus) { link.fold(.center) }
            }
            let maxed = link.maximized == .center
            HeadSymbol(help: maxed ? words("mail.lane.back") : words("mail.grow.named", title), glyph: maxed ? .shrink : .expand) {
                link.toggleMaximize(.center)
            }
        }
    }

    private var searchField: some View {
        let here = model.searchScope == .here
        let placeholder = here ? words("mail.search.placeholder.here", title) : words("mail.search.placeholder.all")
        return HStack(spacing: CGFloat(Design.Spacing.step8)) {
            TextField(text: $text, prompt: Text(verbatim: placeholder)) { word("mail.search.label") }
                .textFieldStyle(.plain)
                .designText(\.ink, size: Design.TextSize.body)
                .focused($focused)
                .autocorrectionDisabled()
                .onKeyPress(.escape) {
                    Task { await model.setSearching(false) }
                    return .handled
                }
                .accessibilityLabel(word("mail.search.label"))
            ScopeButton(label: here ? words("mail.search.scope.here", title) : words("mail.search.scope.all"),
                        help: here ? words("mail.search.tip.here", title) : words("mail.search.tip.all", title)) {
                Task { await model.toggleScope() }
            }
        }
        .frame(height: CGFloat(Design.Spacing.step28))
        .overlay(alignment: .bottom) { Rectangle().fill(design.color(\.ink)).frame(height: CGFloat(Design.Size.hairline)) }
        .task {
            try? await Task.sleep(for: .seconds(Design.Duration.searchFocusDelay))
            focused = true
        }
    }

    private func expired(_ address: String) -> some View {
        Notice(kind: .failure, title: line("mail.list.signInExpired", address), text: word("mail.list.signInExpired.text"),
               glyph: { Glyph(.alert) },
               actions: { TextButton(label: word("mail.list.signInExpired.act"), kind: .accent) { link?.openSettings() } })
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.top, CGFloat(Design.Spacing.step8))
    }

    @ViewBuilder
    private func content(width: Double) -> some View {
        if let kind = model.emptyKind {
            state(kind)
        } else {
            rows(width: width)
        }
    }

    private func rows(width: Double) -> some View {
        let items = model.rowPresentations
        let trash = model.currentFolder?.role == .trash
        let picking = model.picking
        return ScrollView {
            LazyVStack(spacing: 0) {
                if !model.query.isEmpty, model.searchScope == .all {
                    Text(verbatim: words("mail.search.results", items.count))
                        .designText(\.inkTertiary, size: Design.TextSize.small)
                        .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Spacing.step32), alignment: .bottomLeading)
                        .padding(.horizontal, CGFloat(Design.Spacing.step8))
                        .padding(.bottom, CGFloat(Design.Spacing.step8))
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let next = items.indices.contains(index + 1) ? items[index + 1] : nil
                    MailRowView(model: model, item: item,
                                separated: next != nil && !item.selected && next?.selected != true,
                                inTrash: trash, picking: picking)
                }
                if model.canLoadMore {
                    TextButton(label: word("mail.loadMore"), kind: .neutral) { Task { await model.loadMore() } }
                        .padding(.top, CGFloat(Design.Spacing.step16))
                        .padding(.bottom, CGFloat(Design.Spacing.step8))
                }
            }
            .padding(CGFloat(Design.Spacing.step8))
        }
        .scrollIndicators(.automatic)
        .scrolledSignal($scrolled)
    }

    @ViewBuilder
    private func state(_ kind: MailEmptyKind) -> some View {
        switch kind {
        case .loading:
            ContentState(kind: .noResults, text: word("mail.list.loading"), glyph: { Spinner() }, action: { EmptyView() })
        case .notConnected:
            ContentState(kind: .permissionRequired, title: word("mail.list.notConnected"), text: word("mail.list.notConnected.text"),
                         glyph: { Glyph(.envelope) },
                         action: { TextButton(label: word("mail.list.notConnected.act"), kind: .accent) { link?.openSettings() } })
        case .failed(let last):
            ContentState(kind: .failed, title: word("mail.list.failed"), text: failedText(last), glyph: { Glyph(.alert) },
                         action: { TextButton(label: word("mail.list.failed.act")) { Task { await model.loadSelection() } } })
        case .noResults(let query, let folder):
            ContentState(kind: .noResults, text: line("mail.list.emptySearch", query, folderTitle(folder)), glyph: { Glyph(.search) },
                         action: { TextButton(label: word("mail.list.emptySearch.act")) { Task { await model.search("") } } })
        case .noFilterMatch:
            ContentState(kind: .noResults, text: word("mail.list.noFilterMatch"), glyph: { Glyph(.filter) },
                         action: { TextButton(label: word("mail.list.noFilterMatch.act")) { model.setFilter(.all) } })
        case .empty(let folder):
            ContentState(kind: .empty, text: line("mail.list.empty", folderTitle(folder)), glyph: { Glyph(.inbox) },
                         action: { TextButton(label: word("mail.list.empty.act")) { _ = model.compose() } })
        }
    }

    private func failedText(_ last: Date?) -> Text {
        guard let last else { return word("mail.list.failed.text") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: last, relativeTo: model.now)
        return Text(verbatim: words("mail.list.failed.text") + " " + words("mail.list.failed.last", relative))
    }
}

struct ScopeButton: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let label: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: label)
                .designText(\.inkSecondary, size: Design.TextSize.small, weight: .medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, CGFloat(Design.Spacing.step12))
                .frame(height: CGFloat(Design.Size.chipHeight))
                .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
                .overlay(Capsule().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScale))
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}

struct Spinner: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var turn = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(MailSheet.spinnerArc))
            .stroke(design.color(\.ink), lineWidth: hairline)
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .rotationEffect(.degrees(turn))
            .task {
                guard !reduced else { return }
                withAnimation(.linear(duration: Design.Duration.thinking).repeatForever(autoreverses: false)) { turn = 360 }
            }
    }
}
