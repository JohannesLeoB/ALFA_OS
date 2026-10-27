import AppKit
import Core
import Design
import Mail
import SwiftUI

struct RecipientDetail: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    @State private var open = false

    var body: some View {
        let people = card.recipients
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                Group {
                    if open {
                        Color.clear
                    } else {
                        appearance.text("mail.read.to").designText(\.inkTertiary, size: Tokens.TextSize.small)
                    }
                }
                .frame(width: CGFloat(SheetValues.fieldLabelWidthRead), alignment: .leading)
                Disclosure(open: open, help: appearance.string(open ? "mail.read.less" : "mail.read.all")) {
                    if open {
                        SmallText(text: Text(verbatim: appearance.format("mail.read.count", Format.number(people.all.count))))
                    } else {
                        Text(verbatim: people.summary)
                            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let more = people.more {
                            SmallText(text: Text(verbatim: appearance.format("mail.read.more", Format.number(more))))
                        }
                    }
                } action: { toggle() }
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(Tokens.Size.edge))
            .padding(.trailing, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(SheetValues.fieldRowHeightRead))
            if open {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(people.all.enumerated()), id: \.offset) { index, person in
                            PersonRow(session: session, card: card, person: person, group: people.group(at: index))
                        }
                    }
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                    .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                }
                .frame(maxHeight: CGFloat(Tokens.Size.recipientListMaxHeight))
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step4))
        .animation(appearance.ease(Tokens.Duration.recipientList), value: open)
        .accessibilityElement(children: .contain)
    }

    private func toggle() {
        open.toggle()
        session.inbox.toggleRecipients(card.id)
    }
}

struct PersonRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    let person: Participant
    let group: RecipientGroup
    @State private var anchor = AnchorBox()

    private var label: Text {
        switch group {
        case .to: appearance.text("mail.read.to")
        case .cc: appearance.text("mail.read.cc")
        case .none: Text(verbatim: "")
        }
    }

    var body: some View {
        RecipientRow(label: label, initials: person.initials, title: person.label, detail: person.detail, help: person.full)
            .background(AnchorMarker(box: anchor))
            .onTapGesture { menu() }
    }

    private func menu() {
        let entries = session.personEntries(name: person.name, address: person.address, appearance: appearance)
        anchor.showMenu(entries, width: Tokens.Size.menuWidthWide)
    }
}
