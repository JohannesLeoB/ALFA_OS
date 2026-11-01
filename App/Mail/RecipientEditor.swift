import AppKit
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
    @State private var rejected = false
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
            .frame(minHeight: CGFloat(Tokens.Spacing.step44))
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
                Text(verbatim: people.first?.first ?? "")
                    .designText(\.ink, size: Tokens.TextSize.body, weight: .medium).lineLimit(1)
                SmallText(text: Text(verbatim: appearance.format("mail.read.more", Format.number(people.count - 1))))
            } action: { expanded = true }
            Spacer(minLength: 0)
        }
    }

    private var inputField: some View {
        TextField(text: $input, prompt: placeholder) { label }
            .textFieldStyle(.plain)
            .designText(rejected ? \.signal : \.ink, size: Tokens.TextSize.body)
            .frame(minWidth: CGFloat(Tokens.Size.recipientInputMinWidth))
            .padding(.leading, CGFloat(Tokens.Spacing.step4))
            .autocorrectionDisabled()
            .focused($focused)
            .onSubmit { commit() }
            .onAppear { if field == .to, people.isEmpty { focused = true } }
            .onChange(of: focused) { _, now in
                if !now { commitTyped() }
            }
            .onChange(of: input) { _, value in
                rejected = false
                if let last = value.last, last == "," || last == ";" || (last == " " && value.contains("@")) {
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
        if value.contains("@") {
            inbox.addRecipient(card.id, field, entry: value)
        } else if let first = inbox.suggestions(card.id, field, query: value).first {
            inbox.addRecipient(card.id, field, entry: first.entry)
        } else {
            rejected = true
            return
        }
        input = ""
    }

    private func commitTyped() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.contains("@") else { return }
        commit()
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
                .frame(height: CGFloat(Tokens.Size.rowHeight))
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
                .frame(width: CGFloat(Tokens.Spacing.step24), height: CGFloat(Tokens.Spacing.step24))
                .background(Circle().fill(hovering ? appearance.color(\.selection) : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressStrong))
        .help(appearance.text("mail.compose.remove"))
        .onHover { hovering = $0 }
    }
}

struct RecipientRow<Trailing: View>: View {
    @Environment(\.appearance) private var appearance
    let label: Text
    let initials: String
    let title: String
    let detail: String
    let help: String
    @ViewBuilder let trailing: Trailing
    @State private var hovering = false

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            label
                .designText(\.inkTertiary, size: Tokens.TextSize.small)
                .frame(width: CGFloat(Tokens.Size.recipientLabelColumn), alignment: .leading)
            Mark(size: .small) {
                if initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: initials) }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title).designText().lineLimit(1).frame(height: CGFloat(SheetValues.conversationLine))
                if !detail.isEmpty {
                    Text(verbatim: detail).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Spacing.step44))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(hovering ? appearance.color(\.hover) : Color.clear))
        .contentShape(Rectangle())
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
    }
}

extension RecipientRow where Trailing == EmptyView {
    init(label: Text, initials: String, title: String, detail: String, help: String) {
        self.init(label: label, initials: initials, title: title, detail: detail, help: help) { EmptyView() }
    }
}

extension Suggestion {
    var entry: String { name.isEmpty ? address : "\"" + name + "\" <" + address + ">" }
}

struct SuggestionRow: View {
    @Environment(\.appearance) private var appearance
    let item: Suggestion
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step12)) {
                Mark(size: .small) {
                    if item.initials.isEmpty { Glyph.small(.person) } else { Text(verbatim: item.initials) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: item.name.isEmpty ? item.shown : item.name).designText().lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                    Text(verbatim: item.shown).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
                        .frame(height: CGFloat(SheetValues.conversationLine))
                }
                Spacer(minLength: 0)
                appearance.text(item.tag.key).designText(\.inkTertiary, size: Tokens.TextSize.small).lineLimit(1)
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Size.suggestionRowHeight))
            .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.field)).fill(hovering ? appearance.color(\.hover) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: item.address))
        .onHover { hovering = $0 }
    }
}

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
                .frame(width: CGFloat(Tokens.Spacing.step40), alignment: .leading)
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
            .frame(height: CGFloat(Tokens.Spacing.step36))
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
        anchor.showMenu(entries)
    }
}

struct SmallText: View {
    let text: Text
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary

    var body: some View {
        text
            .designText(tone, size: Tokens.TextSize.small)
            .lineLimit(1)
    }
}
