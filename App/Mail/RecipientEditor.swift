import Core
import Design
import Mail
import SwiftUI

struct RecipientEditor: View {
    @Environment(\.appearance) private var appearance
    let inbox: InboxState
    let card: OpenDraft
    let field: RecipientField
    @Binding var showCopy: Bool
    @Binding var expanded: Bool
    @State private var input = ""
    @FocusState private var focused: Bool

    private var people: [Participant] { card.people(field) }
    private var inline: Bool { people.count <= NameLimit.recipientsInline }
    private var label: Text { appearance.text("mail.compose." + field.rawValue) }

    private var placeholder: Text {
        switch field {
        case .to: people.isEmpty ? appearance.text("mail.compose.to.placeholder") : Text(verbatim: "")
        case .cc: appearance.text("mail.compose.cc.placeholder")
        case .bcc: appearance.text("mail.compose.bcc.placeholder")
        }
    }

    var body: some View {
        let found = inbox.suggestions(card.id, field, query: input)
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                label.designText(\.inkTertiary, size: Tokens.TextSize.small)
                    .frame(width: CGFloat(Tokens.Size.recipientLabelColumn), alignment: .leading)
                if inline || !expanded {
                    summaryOrChips
                } else {
                    Disclosure(open: true, help: appearance.string("mail.read.less")) {
                        SmallText(text: Text(verbatim: appearance.format("mail.read.count", Format.number(people.count))))
                    } action: { expanded = false }
                    Spacer(minLength: 0)
                }
                if field == .to {
                    SymbolButton(help: appearance.string("mail.compose.copy"), glyph: .people, selected: showCopy, hover: .none) { showCopy.toggle() }
                }
            }
            .padding(.leading, CGFloat(Tokens.Size.edge))
            .padding(.trailing, CGFloat(Tokens.Spacing.step8))
            .frame(minHeight: CGFloat(SheetValues.fieldRowHeight))
            if !found.isEmpty { suggestions(found) }
            if !inline && expanded { list }
        }
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, CGFloat(Tokens.Size.edge)) }
        .animation(appearance.ease(Tokens.Duration.recipientList), value: expanded)
    }

    @ViewBuilder
    private var summaryOrChips: some View {
        if inline {
            HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
                ForEach(people) { person in
                    Chip(name: person.chipLabel, detail: person.address, removeKey: "mail.compose.remove",
                         onRemove: { inbox.removeRecipient(card.id, field, at: person.id) }, removeGlyph: { Glyph.tiny(.close) })
                }
                inputField
            }
        } else {
            Disclosure(open: false, help: appearance.format("mail.compose.showAll", Format.number(people.count))) {
                Text(verbatim: people.first.map { $0.name.isEmpty ? $0.chipLabel : $0.name } ?? "")
                    .designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1)
                SmallText(text: Text(verbatim: appearance.format("mail.read.more", Format.number(people.count - 1))))
            } action: { expanded = true }
            Spacer(minLength: 0)
        }
    }

    private var inputField: some View {
        TextField(text: $input, prompt: placeholder) { label }
            .textFieldStyle(.plain)
            .designText(\.ink, size: Tokens.TextSize.body)
            .frame(minWidth: CGFloat(Tokens.Size.recipientInputMinWidth))
            .padding(.leading, CGFloat(Tokens.Spacing.step4))
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
                inbox.removeLastRecipient(card.id, field)
                return .handled
            }
    }

    private func commit() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !value.contains("@"), let first = inbox.suggestions(card.id, field, query: value).first {
            inbox.addRecipient(card.id, field, entry: first.entry)
        } else {
            inbox.addRecipient(card.id, field, entry: value)
        }
        input = ""
    }

    private func suggestions(_ found: [Suggestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(found) { item in
                SuggestionRow(item: item) {
                    inbox.addRecipient(card.id, field, entry: item.entry)
                    input = ""
                }
            }
        }
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(people) { person in
                    RecipientRow(label: Text(verbatim: ""), initials: person.initials, title: person.label, detail: person.detail,
                                 help: person.full) {
                        RowRemove { inbox.removeRecipient(card.id, field, at: person.id) }
                    }
                }
                HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                    Color.clear.frame(width: CGFloat(Tokens.Size.recipientLabelColumn))
                    Glyph.tiny(.plus)
                        .foregroundStyle(appearance.color(\.inkTertiary))
                        .frame(width: CGFloat(Tokens.Size.recipientMarkColumn), height: CGFloat(Tokens.Size.recipientMarkColumn))
                        .overlay(Circle().strokeBorder(appearance.color(\.lineStrong),
                                                       style: StrokeStyle(lineWidth: CGFloat(Tokens.Size.hairline),
                                                                          dash: SheetValues.dashedLine.map { CGFloat($0) })))
                    TextField(text: $input, prompt: appearance.text("mail.compose.add")) { appearance.text("mail.compose.add") }
                        .textFieldStyle(.plain)
                        .designText(\.ink, size: Tokens.TextSize.body)
                        .autocorrectionDisabled()
                        .onSubmit { commit() }
                }
                .padding(.leading, CGFloat(Tokens.Spacing.step8))
                .padding(.trailing, CGFloat(Tokens.Spacing.step4))
                .frame(height: CGFloat(SheetValues.recipientInputHeight))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
        }
        .frame(maxHeight: CGFloat(Tokens.Size.recipientListMaxHeight))
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RowRemove: View {
    @Environment(\.appearance) private var appearance
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Glyph.tiny(.close)
                .foregroundStyle(appearance.color(hovering ? \.ink : \.inkTertiary))
                .frame(width: CGFloat(SheetValues.removeRowSize), height: CGFloat(SheetValues.removeRowSize))
                .background(Circle().fill(hovering ? appearance.color(\.selection) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: SheetValues.pressScaleChip))
        .help(appearance.text("mail.compose.remove"))
        .onHover { hovering = $0 }
    }
}
