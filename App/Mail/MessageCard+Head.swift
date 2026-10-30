import AppKit
import Core
import Design
import Mail
import Shell
import SwiftUI

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
            return card.people(.to)
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
                    Text(verbatim: appearance.format("mail.card.more", Format.number(more)))
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
