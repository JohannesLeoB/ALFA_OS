import AppKit
import Core
import Design
import Mail
import SwiftUI

struct DraftEditor: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenDraft
    @State private var showCopy = false
    @State private var expanded = false

    private var inbox: InboxState { session.inbox }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if card.needsGrant {
                    Notice(kind: .warning, title: appearance.text("mail.draft.grant.title"), text: appearance.text("mail.draft.grant.text"),
                           glyph: { Glyph(.alert) },
                           actions: { TextButton(label: appearance.text("mail.draft.grant.act"), kind: .accent) { session.openMailSettings() } })
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .padding(.top, CGFloat(Tokens.Spacing.step8))
                } else if card.failedToSend {
                    Notice(kind: .failure, title: appearance.text("mail.draft.sendFailed"), text: appearance.text("mail.draft.failed.text"),
                           glyph: { Glyph(.alert) },
                           actions: { TextButton(label: appearance.text("mail.draft.failed.act"), kind: .accent) { Task { await inbox.send(card.id) } } })
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .padding(.top, CGFloat(Tokens.Spacing.step8))
                }
                FieldRow(label: appearance.text("mail.compose.from"), width: Tokens.Size.fieldLabelWidth) {
                    FromButton(session: session, card: card)
                    Spacer(minLength: 0)
                }
                RecipientEditor(inbox: inbox, card: card, field: .to, showCopy: $showCopy, expanded: $expanded)
                if showCopy {
                    RecipientEditor(inbox: inbox, card: card, field: .cc, showCopy: $showCopy, expanded: $expanded)
                    RecipientEditor(inbox: inbox, card: card, field: .bcc, showCopy: $showCopy, expanded: $expanded)
                }
                subjectRow
                bodySheet
                if !card.draft.attachments.isEmpty { attachments }
            }
        }
        .scrollIndicators(.automatic)
    }

    private var subjectRow: some View {
        let binding = Binding(get: { card.draft.subject }, set: { value in inbox.edit(card.id) { $0.subject = value } })
        return FieldRow(label: appearance.text("mail.compose.subject"), width: Tokens.Size.recipientLabelColumn) {
            TextField(text: binding, prompt: appearance.text("mail.compose.subject")) { appearance.text("mail.compose.subject") }
                .textFieldStyle(.plain)
                .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
                .padding(.leading, CGFloat(Tokens.Spacing.step4))
                .autocorrectionDisabled()
        }
    }

    private var bodySheet: some View {
        let binding = Binding(get: { card.draft.body }, set: { value in inbox.edit(card.id) { $0.body = value } })
        return TextEditor(text: binding)
            .font(Font(Typeface.sheet(size: Tokens.TextSize.body)))
            .lineSpacing(Typeface.sheetSpacing(size: Tokens.TextSize.body, line: Tokens.LineHeight.mailBody * Tokens.TextSize.body))
            .scrollContentBackground(.hidden)
            .foregroundStyle(appearance.color(\.sheetInk))
            .padding(.top, CGFloat(SheetValues.bodyPadTop))
            .padding(.horizontal, CGFloat(SheetValues.bodyPadSide))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.composeSheetMinHeight), alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: CGFloat(SheetValues.bodyRadius)).fill(appearance.color(\.sheet)))
            .environment(\.colorScheme, .light)
            .padding(CGFloat(SheetValues.bodyMargin))
            .accessibilityLabel(appearance.text("mail.compose.body"))
    }

    private var attachments: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                ForEach(Array(card.draft.attachments.enumerated()), id: \.offset) { index, item in
                    AttachmentChip(name: PersonName.middle(item.filename, limit: SheetValues.attachmentChipNameLimit), size: item.humanSize,
                                   detail: item.filename, removeKey: "mail.compose.remove",
                                   onRemove: { inbox.removeAttachment(card.id, at: index) }, glyph: { Glyph.small(.doc) },
                                   removeGlyph: { Glyph.tiny(.close) })
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Size.edge))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
        }
        .scrollIndicators(.hidden)
    }
}

struct FieldRow<Content: View>: View {
    let label: Text
    let width: Double
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            label.designText(\.inkTertiary, size: Tokens.TextSize.small).frame(width: CGFloat(width), alignment: .leading)
            content
        }
        .padding(.leading, CGFloat(Tokens.Size.edge))
        .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(SheetValues.fieldRowHeight))
        .overlay(alignment: .bottom) {
            Hairline().padding(.horizontal, CGFloat(Tokens.Size.edge))
        }
    }
}

struct FromButton: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenDraft
    @State private var anchor = AnchorBox()

    private var inbox: InboxState { session.inbox }
    private var name: String { session.settings.profile.name }
    private var address: String { inbox.accounts.first { $0.id == card.inlet }?.account ?? "" }

    var body: some View {
        AddressButton(capsule: true, action: open) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                if name.isEmpty {
                    Text(verbatim: address).designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1)
                } else {
                    Text(verbatim: name).designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1).fixedSize()
                    Text(verbatim: address).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1).truncationMode(.tail)
                }
                Glyph.small(.chevron).foregroundStyle(appearance.color(\.inkTertiary))
            }
        }
        .background(AnchorMarker(box: anchor))
    }

    private func open() {
        let entries = inbox.fromChoices.map { inlet in
            MenuEntry.row(MenuItem(id: inlet.id, label: Text(verbatim: inlet.account.isEmpty ? inlet.title : inlet.account),
                                   check: inlet.id == card.inlet ? appearance.text("mail.menu.check") : nil) { inbox.setFrom(card.id, inlet: inlet.id) })
        }
        anchor.showMenu(entries)
    }
}
