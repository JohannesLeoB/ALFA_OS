import AppKit
import Core
import Design
import Hub
import Mail
import SwiftUI
import UniformTypeIdentifiers

struct DraftEditor: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let card: OpenDraft
    @State private var showCopy = false
    @State private var expanded = false
    @State private var box = TextBox()
    @State private var dropOver = false

    private var inbox: InboxState { session.inbox }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                fields
            }
            .scrollIndicators(.automatic)
            if inbox.formatting { FormatRow(box: box) }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropOver) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in session.attach(urls: [url], to: card.id) }
                }
            }
            return true
        }
        .overlay { if dropOver { dropOverlay } }
    }

    private var dropOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.notice))
        return HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Glyph(.doc)
            appearance.text("mail.compose.drop")
        }
        .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(appearance.color(\.well)))
        .overlay(shape.strokeBorder(appearance.color(\.inkTertiary),
                                    style: StrokeStyle(lineWidth: CGFloat(Tokens.Size.hairline),
                                                       dash: SheetValues.dashedLine.map { CGFloat($0) })))
        .padding(CGFloat(Tokens.Spacing.step8))
        .allowsHitTesting(false)
    }

    private var fields: some View {
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
            if card.saveFailure != nil, !card.needsGrant, !card.failedToSend {
                Notice(kind: .failure, title: appearance.text("mail.draft.saveFailed.title"),
                       text: appearance.text(card.saveNeedsSignIn ? "mail.draft.saveFailed.auth" : "mail.draft.saveFailed.server"),
                       glyph: { Glyph(.alert) },
                       actions: {
                    if card.saveNeedsSignIn {
                        TextButton(label: appearance.text("mail.list.signInExpired.act"), kind: .accent) { session.openMailSettings() }
                    } else {
                        TextButton(label: appearance.text("mail.draft.saveFailed.retry"), kind: .accent) { Task { await inbox.save(card.id) } }
                    }
                })
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
        BodyEditor(text: card.draft.body, html: card.draft.bodyHTML, box: box) { text, html in
            inbox.setBody(card.id, text: text, html: html)
        }
            .frame(minHeight: CGFloat(Tokens.Size.composeTextMinHeight))
            .padding(.top, CGFloat(Tokens.Spacing.step16))
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.composeSheetMinHeight), alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.sheet)))
            .environment(\.colorScheme, .light)
            .padding(CGFloat(Tokens.Spacing.step8))
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
        .frame(height: CGFloat(Tokens.Spacing.step44))
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
    private var sender: Inlet? { inbox.accounts.first { $0.id == card.inlet } }
    private var name: String { card.draft.from?.name ?? "" }
    private var address: String { card.draft.from?.address ?? sender?.account ?? "" }

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
        var entries = inbox.senderChoices.map { choice in
            MenuEntry.row(MenuItem(id: choice.id, label: Text(verbatim: choice.sender.address),
                                   check: isCurrent(choice) ? appearance.text("mail.menu.check") : nil) {
                Task { await inbox.setFrom(card.id, inlet: choice.inlet, sender: choice.sender) }
            })
        }
        entries.append(contentsOf: signatureEntries())
        anchor.showMenu(entries)
        Task { await inbox.refreshSenders() }
    }

    private func signatureEntries() -> [MenuEntry] {
        let applied = inbox.signatureApplied(card.id)
        var entries: [MenuEntry] = [
            .separator(id: "signature.separator"),
            .row(MenuItem(id: "signature.none", label: appearance.text("mail.compose.signature.none"),
                          check: applied ? nil : appearance.text("mail.menu.check")) { inbox.useSignature(card.id, false) }),
        ]
        if let name = inbox.signatureName(card.id) {
            entries.append(.row(MenuItem(id: "signature.use", label: Text(verbatim: name),
                                         check: applied ? appearance.text("mail.menu.check") : nil) { inbox.useSignature(card.id, true) }))
        }
        entries.append(.row(MenuItem(id: "signature.edit", label: appearance.text("mail.compose.signature.edit")) {
            guard let service = sender.flatMap({ session.assembly.catalog.info(forProvider: $0.provider)?.id }) else {
                session.openMailSettings()
                return
            }
            session.openMailService(service)
        }))
        return entries
    }

    private func isCurrent(_ choice: SenderChoice) -> Bool {
        choice.inlet == card.inlet && choice.sender.address.lowercased() == address.lowercased()
    }
}
