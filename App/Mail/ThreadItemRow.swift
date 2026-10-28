import AppKit
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

    private var loadImages: Bool { session.settings.privacy.loadImages }

    private var showsHTML: Bool {
        if item.current, case .html = card.content { true } else { false }
    }

    private func sheet(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.sheet(size: size, weight: weight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Tokens.Spacing.step8)) {
                AddressButton(action: menu) {
                    Text(verbatim: item.name)
                        .font(sheet(Tokens.TextSize.body, .medium))
                        .lineHeight(Tokens.LineHeight.mailBody * Tokens.TextSize.body, size: Tokens.TextSize.body, sheet: true)
                }
                .background(AnchorMarker(box: anchor))
                Spacer(minLength: 0)
                if let date = item.date { threadDate(date) }
            }
            if item.current, case .html(let html, let inline) = card.content {
                HTMLBody(inbox: session.inbox, card: card, html: html, inlineImages: inline,
                         allowRemote: !card.remoteImagesBlocked(loadRemote: loadImages))
            } else {
                Text(verbatim: item.text)
                    .font(sheet(Tokens.TextStyle.mailBody.size))
                    .lineHeight(Tokens.TextStyle.mailBody.lineHeight * Tokens.TextStyle.mailBody.size, size: Tokens.TextStyle.mailBody.size, sheet: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let quote = item.quote, !showsHTML {
                QuoteToggle(label: item.quoteOpen ? appearance.text("mail.quote.hide") : Text(verbatim: appearance.format("mail.quote.show", quote.lines))) {
                    session.inbox.toggleQuote(card.id, message: item.id)
                }
                if item.quoteOpen {
                    Text(verbatim: quote.text)
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
        .padding(.top, CGFloat(first ? 0 : SheetValues.bodyPadTop))
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(appearance.color(\.sheetLine)).frame(height: CGFloat(Tokens.Size.hairline)) }
        }
        .padding(.top, CGFloat(SheetValues.bodyPadTop))
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
