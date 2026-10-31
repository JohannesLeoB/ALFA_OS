import Design
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
