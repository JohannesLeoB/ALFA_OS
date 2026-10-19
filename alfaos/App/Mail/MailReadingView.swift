import AppKit
import Mail
import ShellCore
import SwiftUI
import UniformTypeIdentifiers

struct ReadingView: View {
    let model: MailModel
    let card: ReadingCard

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RecipientHeader(model: model, card: card)
                SheetBody(model: model, card: card)
            }
        }
        .scrollIndicators(.automatic)
        .task(id: card.id) {
            if !card.summary.threadID.isEmpty, card.conversation.isEmpty { await model.loadThreadTexts(card.id) }
        }
    }
}

struct RecipientHeader: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let model: MailModel
    let card: ReadingCard
    @State private var open = false

    var body: some View {
        let people = card.recipients
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Group {
                    if open {
                        Color.clear
                    } else {
                        word("mail.read.to").designText(\.inkTertiary, size: Design.TextSize.small)
                    }
                }
                .frame(width: CGFloat(SheetValues.fieldLabelWidthRead), alignment: .leading)
                Disclosure(open: open, help: words(open ? "mail.read.less" : "mail.read.all")) {
                    if open {
                        SmallText(text: line("mail.read.count", people.all.count))
                    } else {
                        Text(verbatim: people.summary)
                            .designText(\.ink, size: Design.TextSize.body, weight: .medium)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let more = people.more {
                            SmallText(text: line("mail.read.more", more))
                        }
                    }
                } action: { toggle() }
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(Design.Size.edge))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(SheetValues.fieldRowHeightRead))
            if open {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(people.all.enumerated()), id: \.offset) { index, person in
                            PersonRow(model: model, card: card, person: person, group: people.group(at: index))
                        }
                    }
                    .padding(.horizontal, CGFloat(Design.Spacing.step8))
                    .padding(.bottom, CGFloat(Design.Spacing.step8))
                }
                .frame(maxHeight: CGFloat(Design.Size.recipientListMaxHeight))
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
        }
        .padding(.vertical, CGFloat(Design.Spacing.step4))
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.recipientList), value: open)
        .accessibilityElement(children: .contain)
    }

    private func toggle() {
        open.toggle()
        model.toggleRecipients(card.id)
    }
}

struct Disclosure<Content: View>: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let open: Bool
    let help: String
    @ViewBuilder let content: Content
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                content
                Glyph.small(.chevron)
                    .foregroundStyle(design.color(\.inkTertiary))
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .background(Capsule().fill(hovering ? design.color(\.hover) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScaleDisclosure))
        .padding(.leading, -CGFloat(Design.Spacing.step8))
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.chevron), value: open)
    }
}

struct PersonRow: View {
    @Environment(\.design) private var design
    let model: MailModel
    let card: ReadingCard
    let person: MailPerson
    let group: MailRecipientGroup
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            Group {
                switch group {
                case .to: word("mail.read.to")
                case .cc: word("mail.read.cc")
                case .none: Text(verbatim: "")
                }
            }
            .designText(\.inkTertiary, size: Design.TextSize.small)
            .frame(width: CGFloat(Design.Size.recipientLabelColumn), alignment: .leading)
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
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(Design.Spacing.step4))
        .frame(height: CGFloat(SheetValues.recipientRowHeight))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.field)).fill(hovering ? design.color(\.hover) : Color.clear))
        .contentShape(Rectangle())
        .help(Text(verbatim: person.full))
        .background(AnchorProbe(box: anchor))
        .onHover { hovering = $0 }
        .onTapGesture { menu() }
    }

    private func menu() {
        guard let rect = anchor.screenRect() else { return }
        let actions = MailDo(model: model)
        let entries = MailMenuLine.entries(MailMenus.person(address: person.address)) { action in
            actions.person(action, name: person.name, address: person.address, message: card.id)
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct SheetBody: View {
    @Environment(\.design) private var design
    let model: MailModel
    let card: ReadingCard

    private func system(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    var body: some View {
        let items = model.thread(card.id)
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: card.summary.subject.isEmpty ? words("mail.row.noSubject") : card.summary.subject)
                .font(system(Design.TextSize.title, .medium))
                .tracking(CGFloat(SheetValues.subjectTracking * Design.TextSize.title))
                .lineHeight(Design.LineHeight.title * Design.TextSize.title, size: Design.TextSize.title)
                .fixedSize(horizontal: false, vertical: true)
            if card.hasConversation {
                line("mail.read.conversation", card.conversation.count)
                    .font(system(Design.TextSize.small))
                    .foregroundStyle(design.color(\.sheetInkTertiary))
                    .padding(.top, CGFloat(Design.Spacing.step4))
            }
            if card.remoteImagesBlocked {
                Notice(kind: .warning, title: word("mail.read.images.title"), text: word("mail.read.images.text"), onSheet: true,
                       glyph: { Glyph(.alert) },
                       actions: { SheetButton(label: word("mail.action.loadImages")) { model.allowRemoteImages(card.id) } })
                    .padding(.horizontal, -CGFloat(SheetValues.bodyPadSide))
                    .padding(.top, CGFloat(SheetValues.bodyPadTop))
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ThreadItemView(model: model, card: card, item: item, first: index == 0, last: index == items.count - 1)
            }
        }
        .padding(.top, CGFloat(SheetValues.bodyPadTop))
        .padding(.bottom, CGFloat(SheetValues.bodyPadBottom))
        .padding(.horizontal, CGFloat(SheetValues.bodyPadSide))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(design.color(\.sheetInk))
        .background(RoundedRectangle(cornerRadius: CGFloat(SheetValues.bodyRadius)).fill(design.color(\.sheet)))
        .environment(\.colorScheme, .light)
        .textSelection(.enabled)
        .padding(.horizontal, CGFloat(SheetValues.bodyMargin))
        .padding(.bottom, CGFloat(SheetValues.bodyMargin))
    }
}

struct SheetButton: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .designText(\.sheetInk, size: Design.TextSize.small, weight: .medium)
                .padding(.horizontal, CGFloat(Design.Spacing.step12))
                .frame(height: CGFloat(Design.Spacing.step28))
                .background(Capsule().fill(design.color(\.sheet)))
                .overlay(Capsule().strokeBorder(design.color(\.sheetLineStrong), lineWidth: hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScale(scale: SheetValues.pressScale))
    }
}

struct ThreadItemView: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let model: MailModel
    let card: ReadingCard
    let item: MailThreadItem
    let first: Bool
    let last: Bool
    @State private var anchor = AnchorBox()

    private func system(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        Font(Typeface.font(size: size, weight: weight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step8)) {
            HStack(alignment: .firstTextBaseline, spacing: CGFloat(Design.Spacing.step8)) {
                Button { menu() } label: {
                    Text(verbatim: item.name).font(system(Design.TextSize.body, .medium))
                }
                .buttonStyle(.plain)
                .background(AnchorProbe(box: anchor))
                Spacer(minLength: 0)
                if let date = item.date { threadDate(date) }
            }
            Text(verbatim: item.text)
                .font(system(Design.TextSize.body))
                .lineHeight(Design.LineHeight.mailBody * Design.TextSize.body, size: Design.TextSize.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let quote = item.quote {
                Button { model.toggleQuote(card.id, message: item.id) } label: {
                    (item.quoteOpen ? word("mail.quote.hide") : line("mail.quote.show", quote.lines))
                        .designText(\.sheetInkSecondary, size: Design.TextSize.small, weight: .medium)
                        .padding(.horizontal, CGFloat(Design.Spacing.step8))
                        .frame(height: CGFloat(Design.Size.chipHeight))
                        .overlay(Capsule().strokeBorder(design.color(\.lineStrong), lineWidth: hairline))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                if item.quoteOpen {
                    Text(verbatim: quote.text)
                        .font(system(Design.TextSize.body))
                        .foregroundStyle(design.color(\.sheetInkTertiary))
                        .padding(.leading, CGFloat(Design.Spacing.step12))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(design.color(\.sheetLine)).frame(width: CGFloat(Design.Size.quoteBarWidth))
                        }
                }
            }
            if last, !card.attachmentRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(card.attachmentRows) { row in
                        AttachmentLine(model: model, card: card, row: row)
                    }
                }
                .padding(.horizontal, -CGFloat(Design.Spacing.step8))
                .padding(.top, CGFloat(Design.Spacing.step4))
            }
        }
        .padding(.top, CGFloat(first ? 0 : SheetValues.bodyPadTop))
        .overlay(alignment: .top) {
            if !first { Rectangle().fill(design.color(\.sheetLine)).frame(height: hairline) }
        }
        .padding(.top, CGFloat(first ? SheetValues.bodyPadTop : SheetValues.bodyPadTop))
    }

    @ViewBuilder
    private func threadDate(_ date: MailThreadDate) -> some View {
        Group {
            switch date {
            case .today(let value): Text(verbatim: words("mail.date.today") + ", " + value.formatted(.dateTime.hour().minute()))
            case .dated(let value, let withYear):
                withYear ? Text(value, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                    : Text(value, format: .dateTime.day().month(.abbreviated).hour().minute())
            }
        }
        .font(system(Design.TextSize.small))
        .foregroundStyle(design.color(\.sheetInkTertiary))
        .monospacedDigit()
        .lineLimit(1)
    }

    private func menu() {
        guard let rect = anchor.screenRect() else { return }
        let actions = MailDo(model: model)
        let entries = MailMenuLine.entries(MailMenus.person(address: item.address)) { action in
            actions.person(action, name: item.name, address: item.address, message: card.id)
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct AttachmentLine: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    let model: MailModel
    let card: ReadingCard
    let row: MailAttachmentRow
    @State private var hovering = false
    @State private var anchor = AnchorBox()

    var body: some View {
        HStack(spacing: CGFloat(SheetValues.attachmentGap)) {
            Glyph(.doc)
                .foregroundStyle(design.color(\.sheetInkTertiary))
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .overlay(RoundedRectangle(cornerRadius: CGFloat(SheetValues.attachmentMarkRadius)).strokeBorder(design.color(\.sheetLineStrong), lineWidth: hairline))
            Text(verbatim: row.name)
                .font(.face(Design.TextSize.body, weight: Design.Weight.medium))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(verbatim: row.size)
                .font(.face(Design.TextSize.small))
                .foregroundStyle(design.color(\.sheetInkTertiary))
                .fixedSize()
            Spacer(minLength: 0)
            Glyph.small(.chevron).foregroundStyle(design.color(\.sheetInkTertiary))
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(SheetValues.attachmentRowHeight))
        .background(Capsule().fill(hovering ? design.color(\.sheetWell) : Color.clear))
        .contentShape(Capsule())
        .help(Text(verbatim: row.name))
        .background(AnchorProbe(box: anchor))
        .onHover { hovering = $0 }
        .onTapGesture { menu() }
    }

    private func menu() {
        guard let rect = anchor.screenRect() else { return }
        let actions = MailDo(model: model)
        let entries = MailMenuLine.entries(MailMenus.attachment()) { action in
            actions.attachment(action, message: card.id, attachment: row)
        }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthPerson, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}
