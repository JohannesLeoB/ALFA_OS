import Core
import Design
import Hub
import Mail
import Shell
import SwiftUI

struct InboxLane: View {
    let session: AppSession
    let lane: LaneKind

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch lane {
        case .leading: FolderLane(session: session)
        case .center: MessageLane(session: session).switchGlass()
        case .trailing: StackLane(session: session).switchGlass()
        }
    }
}

@MainActor
struct InboxPane: Pane {
    let session: AppSession

    private var inbox: InboxState { session.inbox }

    var stackEmpty: Bool { inbox.stackCount == 0 }

    var badge: Int { inbox.totalUnread }

    var opened: Int { inbox.opened }

    var limits: AreaLimits {
        AreaLimits(minimum: [.leading: Tokens.Size.mailLaneMinimumLeft], maximum: [.leading: Tokens.Size.mailLaneMaximumLeft])
    }

    var toast: AnyView? { AnyView(MailToast(inbox: inbox)) }

    func ownsHead(_ lane: LaneKind) -> Bool { true }

    func title(_ lane: LaneKind) -> PaneTitle? {
        switch lane {
        case .leading: .key("mail.lane.title")
        case .center: .verbatim(FolderTitle.text(inbox.currentFolderName) { String(localized: String.LocalizationValue($0)) })
        case .trailing: nil
        }
    }

    func marks(_ lane: LaneKind, height: Double) -> AnyView? {
        AnyView(MarkList(session: session, lane: lane, height: height))
    }

    func content(_ lane: LaneKind) -> AnyView {
        AnyView(InboxLane(session: session, lane: lane))
    }
}

struct MarkList: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let lane: LaneKind
    let height: Double

    var body: some View {
        let inbox = session.inbox
        StripMarks(items: inbox.stripMarks(lane, height: height).map { mark in
            StripMarkItem(id: mark.id, face: mark.face, help: Text(verbatim: FolderTitle.text(mark.help, localized: appearance.string)),
                          selected: mark.selected, dot: mark.dot, accent: mark.accent) {
                session.desk.unfold(Self.revealed(mark.run))
                Task { await inbox.run(mark.run) }
            }
        })
    }

    private static func revealed(_ run: StripMark.Run) -> LaneKind {
        if case .folder = run { return .center }
        return .trailing
    }
}

struct FolderLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var scrolled = false

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var current: Inlet? { inbox.selectedAccount }

    private var openLanes: Int {
        desk.widths.all.filter { $0 > desk.measure.laneFolded }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                head
                list
            }
            .switchGlass()
            AccountDeck(session: session)
        }
    }

    private var head: some View {
        LaneHead(scrolled: scrolled, lane: .leading) {
            if let current {
                AccountTitle(account: current, display: session.settings.display(current.id)) {
                    session.settings.setDisplay($0, for: current.id)
                }
            } else {
                HeaderTitle(text: appearance.text("mail.lane.title"))
                Spacer(minLength: 0)
            }
            if openLanes > 1 {
                SymbolButton(help: appearance.string("mail.lane.fold"), glyph: .minus) { desk.toggleFold(.leading) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(inbox.folderRows) { row in
                    let live: Bool = switch inbox.listState {
                    case .loading, .notConnected: false
                    default: true
                    }
                    LaneRow(glyph: row.glyph, label: name(row), selected: row.selected,
                            count: live && row.count > 0 ? Format.number(row.count) : nil,
                            countTone: row.selected ? \.onInverseSecondary : row.attention ? \.signal : \.inkTertiary) {
                        Task { await inbox.selectFolder(row.folder.id) }
                    }
                }
                labels
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.hidden)
        .scrolledSignal($scrolled)
    }

    @ViewBuilder
    private var labels: some View {
        let rows = inbox.labelRows
        if !rows.isEmpty {
            if inbox.showsLabelHeading {
                appearance.text("mail.lane.labels")
                    .designText(\.inkTertiary, size: Tokens.TextSize.small)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                    .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Spacing.step32), alignment: .bottomLeading)
            }
            ForEach(rows) { row in
                LaneRow(glyph: row.glyph, label: Text(verbatim: row.folder.name), selected: row.selected, count: nil) {
                    Task { await inbox.selectFolder(row.folder.id) }
                }
            }
        }
    }

    private func name(_ row: FolderEntry) -> Text {
        row.folder.role == .other ? Text(verbatim: row.folder.name) : appearance.text(row.folder.role.nameKey)
    }
}

struct MailToast: View {
    @Environment(\.appearance) private var appearance
    let inbox: InboxState

    var body: some View {
        if let toast = inbox.toast {
            ToastView(message: text(toast),
                      undoLabel: toast.undoable ? appearance.text(toast.kind.actionKey) : nil,
                      onUndo: toast.undoable ? { Task { await inbox.undoToast() } } : nil, failed: toast.kind.failed,
                      lasts: toast.lasts.map { Double($0.components.seconds) },
                      onDismiss: { inbox.dismissToast(toast.serial) })
                .id(toast.serial)
        }
    }

    private func text(_ toast: Toast) -> Text {
        if let date = toast.kind.date {
            return Text(verbatim: appearance.format(toast.kind.key, MessageDate.plan(date, now: inbox.now, appearance: appearance)))
        }
        if let count = toast.kind.count { return Text(verbatim: appearance.format(toast.kind.key, String(count))) }
        if let name = toast.kind.name { return Text(verbatim: appearance.format(toast.kind.key, name)) }
        return appearance.text(toast.kind.key)
    }
}

private struct SwitchGlass: ViewModifier {
    @Environment(\.appearance) private var appearance
    @Environment(\.session) private var session

    func body(content: Content) -> some View {
        let on = session?.mailboxSwitching ?? false
        let timing = on ? appearance.ease(Tokens.Duration.switchIn, Tokens.Easing.glassIn) : appearance.ease(Tokens.Duration.switchOut, Tokens.Easing.glassOut)
        content.overlay {
            Rectangle()
                .fill(appearance.color(\.lane).opacity(Tokens.Opacity.switchGlass))
                .opacity(on ? 1 : 0)
                .animation(timing, value: on)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func switchGlass() -> some View {
        modifier(SwitchGlass())
    }
}

private struct ScrolledSignal: ViewModifier {
    @Binding var scrolled: Bool
    @State private var rest: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Double.self) { Double($0.contentOffset.y) } action: { _, now in
                rest?.cancel()
                guard now > 0 else {
                    scrolled = false
                    return
                }
                scrolled = true
                rest = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Tokens.Duration.scrollLineRest))
                    if !Task.isCancelled { scrolled = false }
                }
            }
            .onDisappear { rest?.cancel() }
    }
}

extension View {
    func scrolledSignal(_ scrolled: Binding<Bool>) -> some View {
        modifier(ScrolledSignal(scrolled: scrolled))
    }
}

extension InboxState {
    func extend(_ window: inout Int, total: Int) {
        if window < total {
            window += SheetValues.listWindowStep
        } else if listTail != nil {
            Task { await loadTail() }
        }
    }
}
