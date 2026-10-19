import AppKit
import Hub
import Mail
import ShellCore
import SwiftUI

struct ComposeView: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    @Environment(\.mailLaneLink) private var link
    let model: MailModel
    let card: MailDraftCard
    let formatOn: Bool
    @State private var showCopy = false
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if card.needsGrant {
                        Notice(kind: .warning, title: word("mail.draft.grant.title"), text: word("mail.draft.grant.text"),
                               glyph: { Glyph(.alert) },
                               actions: { TextButton(label: word("mail.draft.grant.act"), kind: .accent) { link?.openSettings() } })
                            .padding(.horizontal, CGFloat(Design.Spacing.step8))
                            .padding(.top, CGFloat(Design.Spacing.step8))
                    } else if card.failedToSend {
                        Notice(kind: .failure, title: word("mail.draft.sendFailed"), text: word("mail.draft.failed.text"),
                               glyph: { Glyph(.alert) },
                               actions: { TextButton(label: word("mail.draft.failed.act"), kind: .accent) { Task { await model.send(card.id) } } })
                            .padding(.horizontal, CGFloat(Design.Spacing.step8))
                            .padding(.top, CGFloat(Design.Spacing.step8))
                    }
                    fromRow
                    RecipientRow(model: model, card: card, field: .to, showCopy: $showCopy, expanded: $expanded)
                    if showCopy {
                        RecipientRow(model: model, card: card, field: .cc, showCopy: $showCopy, expanded: $expanded)
                        RecipientRow(model: model, card: card, field: .bcc, showCopy: $showCopy, expanded: $expanded)
                    }
                    subjectRow
                    bodySheet
                    if !card.draft.attachments.isEmpty { attachments }
                }
            }
            .scrollIndicators(.automatic)
            if formatOn { formatBar }
        }
    }

    private var fromRow: some View {
        FieldRow(label: word("mail.compose.from"), width: Design.Size.fieldLabelWidth) {
            FromButton(model: model, card: card)
            Spacer(minLength: 0)
        }
    }

    private var subjectRow: some View {
        let binding = Binding(get: { card.draft.subject }, set: { value in model.edit(card.id) { $0.subject = value } })
        return FieldRow(label: word("mail.compose.subject"), width: Design.Size.recipientLabelColumn) {
            TextField(text: binding, prompt: word("mail.compose.subject")) { word("mail.compose.subject") }
                .textFieldStyle(.plain)
                .designText(\.ink, size: Design.TextSize.body, weight: .medium)
                .padding(.leading, CGFloat(Design.Spacing.step4))
                .autocorrectionDisabled()
        }
    }

    private var bodySheet: some View {
        let binding = Binding(get: { card.draft.body }, set: { value in model.edit(card.id) { $0.body = value } })
        return TextEditor(text: binding)
            .font(.face(Design.TextSize.body))
            .lineSpacing(CGFloat(Design.LineHeight.mailBody * Design.TextSize.body - Design.TextSize.body) * 0.75)
            .scrollContentBackground(.hidden)
            .foregroundStyle(design.color(\.sheetInk))
            .padding(.top, CGFloat(SheetValues.bodyPadTop))
            .padding(.horizontal, CGFloat(SheetValues.bodyPadSide))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Size.composeSheetMinHeight), alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: CGFloat(SheetValues.bodyRadius)).fill(design.color(\.sheet)))
            .environment(\.colorScheme, .light)
            .padding(CGFloat(SheetValues.bodyMargin))
            .accessibilityLabel(word("mail.compose.body"))
    }

    private var attachments: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                ForEach(Array(card.draft.attachments.enumerated()), id: \.offset) { index, item in
                    AttachmentChip(name: MailNames.middle(item.filename, limit: SheetValues.attachmentChipNameLimit), size: item.humanSize,
                                   detail: item.filename, removeKey: "mail.compose.remove",
                                   onRemove: { model.removeAttachment(card.id, at: index) }, glyph: { Glyph.small(.doc) },
                                   removeGlyph: { Glyph.tiny(.close) })
                }
            }
            .padding(.horizontal, CGFloat(Design.Size.edge))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
        }
        .scrollIndicators(.hidden)
    }

    private var formatBar: some View {
        HStack(spacing: CGFloat(Design.Size.headGapStack)) {
            ForEach(MailFormatting.items, id: \.rawValue) { item in
                SymbolButton(help: words("mail.format." + item.rawValue), glyph: item.glyph, tone: \.inkSecondary, hover: .fill) {}
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.footerHeight))
        .overlay(alignment: .top) { Rectangle().fill(design.color(\.line)).frame(height: hairline) }
    }
}

struct FieldRow<Content: View>: View {
    @Environment(\.design) private var design
    let label: Text
    let width: Double
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            label.designText(\.inkTertiary, size: Design.TextSize.small).frame(width: CGFloat(width), alignment: .leading)
            content
        }
        .padding(.leading, CGFloat(Design.Size.edge))
        .padding(.trailing, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(SheetValues.fieldRowHeight))
        .overlay(alignment: .bottom) {
            Hairline().padding(.horizontal, CGFloat(Design.Size.edge))
        }
    }
}

struct FromButton: View {
    @Environment(\.design) private var design
    let model: MailModel
    let card: MailDraftCard
    @State private var anchor = AnchorBox()
    @State private var hovering = false

    private var address: String { model.accounts.first { $0.id == card.inlet }?.account ?? "" }

    var body: some View {
        Button { open() } label: {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: address).designText(\.ink, size: Design.TextSize.body, weight: .medium).lineLimit(1)
                Glyph.small(.chevron).foregroundStyle(design.color(\.inkTertiary))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.leading, -CGFloat(Design.Spacing.step8))
        .background(AnchorProbe(box: anchor))
        .onHover { hovering = $0 }
    }

    private func open() {
        guard let rect = anchor.screenRect() else { return }
        let entries = model.fromChoices.map { inlet in
            MenuEntry.row(MenuItem(id: inlet.id, label: Text(verbatim: inlet.account.isEmpty ? inlet.title : inlet.account),
                                   check: inlet.id == card.inlet ? word("mail.menu.check") : nil) { model.setFrom(card.id, inlet: inlet.id) })
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct RecipientRow: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let model: MailModel
    let card: MailDraftCard
    let field: RecipientField
    @Binding var showCopy: Bool
    @Binding var expanded: Bool
    @State private var input = ""
    @FocusState private var focused: Bool

    private var people: [MailPerson] { card.people(field) }
    private var inline: Bool { MailRecipients.isInline(people.count) }
    private var open: Bool { expanded || inline }
    private var label: Text { word("mail.compose." + field.rawValue) }

    private var placeholder: Text {
        switch field {
        case .to: people.isEmpty ? word("mail.compose.to.placeholder") : Text(verbatim: "")
        case .cc: word("mail.compose.cc.placeholder")
        case .bcc: word("mail.compose.bcc.placeholder")
        }
    }

    var body: some View {
        let found = model.suggestions(card.id, field, query: input)
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                label.designText(\.inkTertiary, size: Design.TextSize.small)
                    .frame(width: CGFloat(Design.Size.recipientLabelColumn), alignment: .leading)
                if inline || !expanded {
                    summaryOrChips
                } else {
                    Disclosure(open: true, help: words("mail.read.less")) {
                        SmallText(text: line("mail.read.count", people.count))
                    } action: { expanded = false }
                    Spacer(minLength: 0)
                }
                if field == .to {
                    SymbolButton(help: words("mail.compose.copy"), glyph: .people, selected: showCopy, hover: .none) { showCopy.toggle() }
                }
            }
            .padding(.leading, CGFloat(Design.Size.edge))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .frame(minHeight: CGFloat(SheetValues.fieldRowHeight))
            if !found.isEmpty { suggestions(found) }
            if !inline && expanded { list }
        }
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, CGFloat(Design.Size.edge)) }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.recipientList), value: expanded)
    }

    @ViewBuilder
    private var summaryOrChips: some View {
        if inline {
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                ForEach(people) { person in
                    Chip(name: person.label, detail: person.address, removeKey: "mail.compose.remove",
                         onRemove: { model.removeRecipient(card.id, field, at: person.id) }, removeGlyph: { Glyph.tiny(.close) })
                }
                inputField
            }
        } else {
            Disclosure(open: false, help: words("mail.compose.showAll", people.count)) {
                Text(verbatim: people.first?.first ?? "").designText(\.ink, size: Design.TextSize.body, weight: .medium).lineLimit(1)
                SmallText(text: line("mail.read.more", people.count - 1))
            } action: { expanded = true }
            Spacer(minLength: 0)
        }
    }

    private var inputField: some View {
        TextField(text: $input, prompt: placeholder) { label }
            .textFieldStyle(.plain)
            .designText(\.ink, size: Design.TextSize.body)
            .frame(minWidth: CGFloat(Design.Size.recipientInputMinWidth))
            .padding(.leading, CGFloat(Design.Spacing.step4))
            .autocorrectionDisabled()
            .focused($focused)
            .onSubmit { commit() }
            .onChange(of: input) { _, value in
                if value.hasSuffix(",") {
                    input = String(value.dropLast())
                    commit()
                }
            }
            .onKeyPress(.delete) {
                guard input.isEmpty, !people.isEmpty else { return .ignored }
                model.removeLastRecipient(card.id, field)
                return .handled
            }
    }

    private func commit() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !value.contains("@"), let first = model.suggestions(card.id, field, query: value).first {
            model.addRecipient(card.id, field, entry: first.name.isEmpty ? first.address : "\"" + first.name + "\" <" + first.address + ">")
        } else {
            model.addRecipient(card.id, field, entry: value)
        }
        input = ""
    }

    private func suggestions(_ found: [MailSuggestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(found) { item in
                SuggestionRow(item: item) {
                    model.addRecipient(card.id, field, entry: item.name.isEmpty ? item.address : "\"" + item.name + "\" <" + item.address + ">")
                    input = ""
                }
            }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .padding(.bottom, CGFloat(Design.Spacing.step8))
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(people) { person in
                    ComposePersonRow(person: person) { model.removeRecipient(card.id, field, at: person.id) }
                }
                HStack(spacing: CGFloat(Design.Spacing.step8)) {
                    Color.clear.frame(width: CGFloat(Design.Size.recipientLabelColumn))
                    Glyph.tiny(.close)
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(design.color(\.inkTertiary))
                        .frame(width: CGFloat(Design.Size.recipientMarkColumn), height: CGFloat(Design.Size.recipientMarkColumn))
                        .overlay(Circle().strokeBorder(design.color(\.lineStrong), style: StrokeStyle(lineWidth: CGFloat(Design.Size.hairline), dash: [2, 2])))
                    TextField(text: $input, prompt: word("mail.compose.add")) { word("mail.compose.add") }
                        .textFieldStyle(.plain)
                        .designText(\.ink, size: Design.TextSize.body)
                        .autocorrectionDisabled()
                        .onSubmit { commit() }
                }
                .padding(.leading, CGFloat(Design.Spacing.step8))
                .padding(.trailing, CGFloat(Design.Spacing.step4))
                .frame(height: CGFloat(SheetValues.recipientInputHeight))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
        }
        .frame(maxHeight: CGFloat(Design.Size.recipientListMaxHeight))
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SuggestionRow: View {
    @Environment(\.design) private var design
    let item: MailSuggestion
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(SheetValues.suggestionColumnGap)) {
                Mark(size: .small) {
                    if item.initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: item.initials) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: item.name.isEmpty ? item.shown : item.name).designText().lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                    Text(verbatim: item.shown).designText(\.inkTertiary, size: Design.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
                Spacer(minLength: 0)
                word("mail.suggest.sender").designText(\.inkTertiary, size: Design.TextSize.small).lineLimit(1)
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(SheetValues.recipientRowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.field)).fill(hovering ? design.color(\.hover) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: item.address))
        .onHover { hovering = $0 }
    }
}

struct ComposePersonRow: View {
    @Environment(\.design) private var design
    let person: MailPerson
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Color.clear.frame(width: CGFloat(Design.Size.recipientLabelColumn))
            Mark(size: .small) {
                if person.initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: person.initials) }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: person.label).designText().lineLimit(1).frame(height: CGFloat(SheetValues.conversationLine))
                if !person.detail.isEmpty {
                    Text(verbatim: person.detail).designText(\.inkTertiary, size: Design.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
            }
            Spacer(minLength: 0)
            Button(action: remove) {
                Glyph.tiny(.close)
                    .foregroundStyle(design.color(\.inkTertiary))
                    .frame(width: CGFloat(SheetValues.removeRowSize), height: CGFloat(SheetValues.removeRowSize))
                    .contentShape(Circle())
            }
            .buttonStyle(PressScale(scale: SheetValues.pressScaleChip))
            .help(word("mail.compose.remove"))
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(Design.Spacing.step4))
        .frame(height: CGFloat(SheetValues.recipientRowHeight))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.field)).fill(hovering ? design.color(\.hover) : Color.clear))
        .help(Text(verbatim: person.full))
        .onHover { hovering = $0 }
    }
}
