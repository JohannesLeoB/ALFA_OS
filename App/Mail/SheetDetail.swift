import Core
import Design
import Mail
import SwiftUI

struct SheetDetail: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenMessage

    private var loadImages: Bool { session.settings.privacy.loadImages }

    var body: some View {
        let items = session.inbox.thread(card.id)
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: card.summary.subject.isEmpty ? appearance.string("mail.row.noSubject") : card.summary.subject)
                .font(Font(Typeface.sheet(size: Tokens.TextStyle.title.size, weight: .medium)))
                .tracking(CGFloat(Tokens.TextStyle.title.tracking * Tokens.TextStyle.title.size))
                .lineHeight(Tokens.TextStyle.title.lineHeight, size: Tokens.TextStyle.title.size, sheet: true)
                .fixedSize(horizontal: false, vertical: true)
            if card.hasConversation {
                Text(verbatim: appearance.format("mail.read.conversation", card.conversation.count))
                    .font(Font(Typeface.sheet(size: Tokens.TextSize.small)))
                    .foregroundStyle(appearance.color(\.sheetInkTertiary))
                    .padding(.top, CGFloat(Tokens.Spacing.step4))
            }
            if card.remoteImagesBlocked(loadRemote: loadImages) {
                Notice(kind: .warning, title: appearance.text("mail.read.images.title"), text: nil, onSheet: true,
                       glyph: { Glyph(.alert) },
                       actions: { TextButton(label: appearance.text("mail.action.loadImages"), kind: .sheet) { session.inbox.allowRemoteImages(card.id) } })
                    .padding(.horizontal, -CGFloat(Tokens.Spacing.step8))
                    .padding(.top, CGFloat(Tokens.Spacing.step16))
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ThreadItemRow(session: session, card: card, item: item, first: index == 0, last: index == items.count - 1)
            }
        }
        .padding(.top, CGFloat(Tokens.Spacing.step16))
        .padding(.bottom, CGFloat(Tokens.Spacing.step24))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(appearance.color(\.sheetInk))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.sheet)))
        .environment(\.colorScheme, .light)
        .textSelection(.enabled)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
    }
}
