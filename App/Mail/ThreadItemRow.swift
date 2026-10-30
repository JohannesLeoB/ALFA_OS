import AppKit
import Core
import Design
import Mail
import SwiftUI

struct ThreadItemRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage
    let item: ThreadItem
    let first: Bool
    let last: Bool
    @State private var anchor = AnchorBox()
    @State private var recipientsOpen = false

    private var loadImages: Bool { session.settings.privacy.loadImages }

    private var allowRemote: Bool { !card.remoteImagesBlocked(loadRemote: loadImages) }

    private func sheet(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.sheet(size: size, weight: weight))
    }

    var body: some View {
        let style = Tokens.TextStyle.mailBody
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Tokens.Spacing.step8)) {
                AddressButton(action: menu) {
                    Text(verbatim: item.name)
                        .font(sheet(style.size, .medium))
                        .lineHeight(style.lineHeight, size: style.size, sheet: true)
                }
                .background(AnchorMarker(box: anchor))
                Spacer(minLength: 0)
                if let date = item.date { threadDate(date) }
            }
            if !item.current, !item.recipients.all.isEmpty { recipientLines }
            if let html = item.html, case .html(_, let inline) = card.content {
                HTMLBody(inbox: session.inbox, card: card, html: allowRemote ? html : item.blockedHTML ?? html, inlineImages: inline,
                         allowRemote: allowRemote)
            } else {
                Text(linked(item.text))
                    .font(sheet(style.size))
                    .lineHeight(style.lineHeight, size: style.size, sheet: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let signature = item.signature {
                QuoteToggle(label: item.signatureOpen ? appearance.text("mail.signature.hide") : appearance.text("mail.signature.show")) {
                    session.inbox.toggleSignature(card.id, message: item.id)
                }
                if item.signatureOpen {
                    Text(linked(signature.text))
                        .font(sheet(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let quote = item.quote {
                QuoteToggle(label: item.quoteOpen ? appearance.text("mail.quote.hide") : Text(verbatim: appearance.format("mail.quote.show", quote.lines))) {
                    session.inbox.toggleQuote(card.id, message: item.id)
                }
                if item.quoteOpen {
                    Text(linked(quote.text))
                        .font(sheet(Tokens.TextSize.body))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                        .padding(.leading, CGFloat(Tokens.Spacing.step12))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(appearance.color(\.sheetLine)).frame(width: CGFloat(Tokens.Size.quoteBarWidth))
                        }
                }
            }
            if last, !card.attachmentEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(card.attachmentEntries) { row in
                        AttachmentRow(session: session, card: card, row: row)
                    }
                }
                .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                .padding(.top, CGFloat(Tokens.Spacing.step4))
            }
        }
        .padding(.top, CGFloat(first ? 0 : Tokens.Spacing.step16))
        .id(item.id)
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(appearance.color(\.sheetLine)).frame(height: CGFloat(Tokens.Size.hairline)) }
        }
        .padding(.top, CGFloat(Tokens.Spacing.step16))
    }

    @ViewBuilder
    private var recipientLines: some View {
        let people = item.recipients
        VStack(alignment: .leading, spacing: 0) {
            Disclosure(open: recipientsOpen, help: appearance.string(recipientsOpen ? "mail.read.less" : "mail.read.all")) {
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    appearance.text("mail.read.to").font(sheet(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    Text(verbatim: recipientsOpen ? appearance.format("mail.read.count", Format.number(people.all.count)) : people.summary)
                        .font(sheet(Tokens.TextSize.small, .medium))
                        .foregroundStyle(appearance.color(\.sheetInkSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !recipientsOpen, let more = people.more {
                        Text(verbatim: appearance.format("mail.read.more", Format.number(more)))
                            .font(sheet(Tokens.TextSize.small))
                            .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    }
                }
            } action: { recipientsOpen.toggle() }
            if recipientsOpen {
                recipientGroup("mail.read.to", people.to)
                recipientGroup("mail.read.cc", people.cc)
            }
        }
        .animation(appearance.ease(Tokens.Duration.recipientList), value: recipientsOpen)
    }

    @ViewBuilder
    private func recipientGroup(_ key: String, _ people: [Participant]) -> some View {
        if !people.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Tokens.Spacing.step8)) {
                appearance.text(key)
                    .font(sheet(Tokens.TextSize.small))
                    .foregroundStyle(appearance.color(\.sheetInkTertiary))
                Text(verbatim: people.map(\.label).joined(separator: ", "))
                    .font(sheet(Tokens.TextSize.small))
                    .foregroundStyle(appearance.color(\.sheetInkSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func linked(_ text: String) -> AttributedString {
        var result = LinkEngine.attributed(text)
        let ranges = result.runs.filter { $0.link != nil }.map(\.range)
        for range in ranges {
            result[range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = .single
        }
        return result
    }

    @ViewBuilder
    private func threadDate(_ date: ThreadDate) -> some View {
        Group {
            switch date {
            case .today(let value):
                Text(verbatim: appearance.string("mail.date.today") + ", " + value.formatted(.dateTime.hour().minute()))
            case .dated(let value, let withYear):
                withYear ? Text(value, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    : Text(value, format: .dateTime.day().month(.abbreviated).hour().minute())
            }
        }
        .font(sheet(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(\.sheetInkTertiary))
        .monospacedDigit()
        .lineLimit(1)
    }

    private func menu() {
        let entries = session.personEntries(name: item.name, address: item.address, appearance: appearance)
        anchor.showMenu(entries)
    }
}

struct QuoteToggle: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(Font(Typeface.sheet(size: Tokens.TextSize.small, weight: .medium)))
                .foregroundStyle(appearance.color(\.sheetInkSecondary))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                .frame(height: CGFloat(Tokens.Size.chipHeight))
                .ring(Pill(), appearance.color(\.lineStrong))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
