import Mail
import SwiftUI

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
