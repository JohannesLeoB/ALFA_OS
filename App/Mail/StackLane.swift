import AppKit
import Carbon.HIToolbox
import Core
import Design
import Mail
import Shell
import SwiftUI

private enum StackKeys {
    static let archive = "e"
    static let deletes: Set<String> = ["\u{7F}", "\u{F728}"]
}

struct StackLane: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var discarding: UUID?

    private var inbox: InboxState { session.inbox }

    private var desk: DeskState { session.desk }

    private var confirming: Bool {
        if let discarding, inbox.frontRef == .draft(discarding) { return true }
        return false
    }

    private var canFold: Bool {
        desk.widths.all.filter { $0 > desk.measure.laneFolded }.count > 1
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let commands = inbox.commands(confirmDiscard: confirming, canFold: canFold,
                                          sendLabelled: width - Tokens.Size.edge >= Tokens.Size.breakpointSendLabel)
            VStack(spacing: 0) {
                head(commands, width: width)
                StackDetail(session: session, commands: commands, perform: perform)
            }
        }
        .eventMonitor(.keyDown, active: desk.mode == nil) { sample in handle(sample) }
        .onChange(of: inbox.frontRef) { discarding = nil }
    }

    private func head(_ commands: CommandSet, width: Double) -> some View {
        let plan = CommandBarEngine.plan(main: commands.main, tail: commands.tail, fan: commands.fan, fold: commands.fold,
                                         staticMore: false, width: width - Tokens.Size.edge)
        return CommandHead(plan: plan, moreHelp: appearance.string("mail.action.more"), glyph: { $0.glyph },
                           help: { session.help($0, appearance: appearance) }, shortcut: { $0.shortcut }, perform: perform,
                           more: { actions in
                               MenuLine.entries(actions.map { MenuLine.item($0) }, appearance: appearance, warns: false) { perform($0) }
                           }) {
            ConfirmPill(label: nil, question: appearance.text("mail.confirm.discard.question"), yes: appearance.text("mail.confirm.discard.yes"),
                        no: appearance.text("confirm.no"),
                        holdHint: Text(verbatim: appearance.format("mail.confirm.hold", appearance.string("mail.confirm.discard.yes"))),
                        startsAsking: true, showsProgress: false, onYes: {
                            if let id = discarding { Task { await inbox.deleteDraft(id) } }
                            discarding = nil
                        }, onNo: { discarding = nil }) {
                Glyph(.trash)
            }
        }
    }

    private func perform(_ action: Action) {
        switch SlotRouter.route(action, front: inbox.frontRef) {
        case .openOverview: inbox.openOverview(true)
        case .closeOverview: inbox.openOverview(false)
        case .fold: desk.toggleFold(.trailing)
        case .saveDraft(let id): Task { await inbox.save(id) }
        case .discardDraft(let id): discarding = id
        case .send(let id): Task { await inbox.send(id) }
        case .attachFile(let id): session.attachFiles(to: id)
        case .toggleFormat: inbox.formatting.toggle()
        case .message(let routed, let id): session.perform(routed, message: id)
        case nil: break
        }
    }

    private func handle(_ sample: EventSample) -> Bool {
        guard sample.local != nil, !inbox.overview.open, case .message(let id) = inbox.frontRef else { return false }
        guard sample.event.modifierFlags.intersection([.command, .control]).isEmpty else { return false }
        if sample.event.window?.firstResponder is NSText { return false }
        let key = sample.event.charactersIgnoringModifiers?.lowercased() ?? ""
        if key == StackKeys.archive {
            session.perform(.archive, message: id)
            return true
        }
        if StackKeys.deletes.contains(key) {
            session.perform(.trash, message: id)
            return true
        }
        return false
    }
}

struct StackDetail: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let commands: CommandSet
    let perform: (Action) -> Void

    private var inbox: InboxState { session.inbox }

    var body: some View {
        CardStack(order: inbox.stackOrder, overviewOpen: inbox.overview.open) { ref, depth in
            MessageCard(session: session, ref: ref, depth: depth, commands: commands, perform: perform)
        } overview: {
            OverviewList(session: session)
        }
    }
}
