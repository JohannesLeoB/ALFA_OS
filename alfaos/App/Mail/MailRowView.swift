import AppKit
import Mail
import ShellCore
import SwiftUI

struct RowTone {
    let primary: KeyPath<DesignColors, RGB>
    let secondary: KeyPath<DesignColors, RGB>
    let tertiary: KeyPath<DesignColors, RGB>
    let line: KeyPath<DesignColors, RGB>

    static func of(_ selected: Bool) -> RowTone {
        let ink = InkSet.of(selected)
        return RowTone(primary: ink.primary, secondary: ink.secondary, tertiary: ink.tertiary, line: ink.line)
    }
}

struct MailRowView: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let model: MailModel
    let item: MailRowPresentation
    let separated: Bool
    let wide: Bool
    let inTrash: Bool
    let picking: Bool
    @State private var hovering = false
    @State private var menuOpen = false

    private var selected: Bool { item.selected && !item.picked }
    private var tone: RowTone { .of(selected) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)) }
    private var actions: MailDo { MailDo(model: model) }

    private var fill: Color { selected ? design.color(\.ink) : Color.clear }

    private var ringColor: Color? {
        if item.picked { return design.color(\.ink) }
        if (hovering || menuOpen) && !selected { return design.color(\.lineStrong) }
        return nil
    }

    var body: some View {
        MessageRow(fill: fill, ring: ringColor, separated: separated) {
            mark
        } content: {
            head
            subject
            preview
            chips
        }
        .task { await model.measureRow(item.id) }
        .overlay(alignment: .topTrailing) { rowActions }
        .contentShape(shape)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { if !onMark($0.location) { open(pin: true) } })
        .simultaneousGesture(SpatialTapGesture().onEnded { if !onMark($0.location) { open(pin: false) } })
        .overlay { RightClick { point in contextMenu(at: point) } }
        .onHover { hovering = $0 }
        .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: hovering)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func onMark(_ point: CGPoint) -> Bool {
        CGRect(x: Design.Spacing.step8, y: SheetValues.rowPadding, width: Design.Size.symbolSize, height: Design.Size.symbolSize)
            .contains(point)
    }

    private func open(pin: Bool) {
        if picking {
            if !pin { model.pick(item.id) }
        } else if item.draft {
            Task { _ = await model.editDraft(item.id) }
        } else {
            Task { await model.open(item.id, pin: pin) }
        }
    }

    private var mark: some View {
        Button { model.pick(item.id) } label: {
            Group {
                if item.picked {
                    Mark(fill: .filled) { Glyph(.tick) }
                } else {
                    Mark(fill: item.unread ? .filled : .rest, inverted: selected) {
                        if item.initials.isEmpty { Glyph(.person) } else { Text(verbatim: item.initials) }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help(word(item.picked ? "mail.pick.remove" : "mail.pick.add"))
        .accessibilityLabel(word(item.picked ? "mail.pick.remove" : "mail.pick.add"))
    }

    private var head: some View {
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            sender
            if let thread = item.thread {
                Counter(value: MailNames.number(thread), tone: tone.tertiary)
                    .help(word("mail.row.thread"))
            }
            Spacer(minLength: 0)
            if item.starred {
                Glyph.small(.flag).foregroundStyle(design.color(tone.secondary)).opacity(hovering ? 0 : 1)
            }
            MailDate(label: item.date, tone: tone.tertiary).opacity(hovering ? 0 : 1)
        }
        .frame(height: CGFloat(SheetValues.rowTextLine))
    }

    private var sender: some View {
        let text: Text
        if item.outgoing && item.sender.isEmpty {
            text = word("mail.row.newMessage")
        } else if item.outgoing {
            text = line("mail.row.to", item.sender)
        } else if item.sender.isEmpty {
            text = word("mail.row.unknown")
        } else {
            text = Text(verbatim: item.sender)
        }
        return text
            .designText(tone.primary, size: Design.TextSize.body, weight: item.unread ? .semibold : .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(Text(verbatim: item.address))
    }

    private var subject: some View {
        Group {
            if let subject = item.subject {
                Text(verbatim: subject)
                    .designText(item.unread ? tone.primary : tone.secondary, size: Design.TextSize.body, weight: item.unread ? .medium : .regular)
            } else {
                word("mail.row.noSubject")
                    .designText(tone.tertiary, size: Design.TextSize.body)
            }
        }
        .lineLimit(1)
        .frame(height: CGFloat(SheetValues.rowTextLine), alignment: .leading)
    }

    private var preview: some View {
        Group {
            if let preview = item.preview {
                Text(verbatim: preview).designText(tone.secondary, size: Design.TextSize.body, weight: .light)
            } else {
                word("mail.row.noText").designText(tone.tertiary, size: Design.TextSize.body, weight: .light)
            }
        }
        .lineLimit(SheetValues.previewLines)
        .lineHeight(SheetValues.rowTextLine, size: Design.TextSize.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chips: some View {
        let shown = Array(item.attachments.prefix(wide ? Design.Count.attachmentsWide : Design.Count.attachmentsNarrow))
        let more = item.attachmentTotal - shown.count
        if !shown.isEmpty {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                ForEach(shown) { row in
                    AttachmentChip(name: MailNames.middle(row.name, limit: SheetValues.attachmentChipNameLimit), detail: row.name + " · " + row.size,
                                   inverted: selected) { Glyph.small(.doc) }
                }
                if more > 0 {
                    Counter(value: "+" + MailNames.number(more), tone: tone.tertiary, ringTone: tone.line)
                        .help(word("mail.row.moreAttachments"))
                }
            }
            .padding(.top, CGFloat(Design.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var rowActions: some View {
        if hovering && !picking && !item.draft {
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                rowAction(item.starred ? "mail.action.unstar" : "mail.action.star", glyph: .flag, tone: item.starred ? tone.primary : \.inkTertiary) {
                    actions.message(item.starred ? .unstar : .star, item.id)
                }
                rowAction(item.unread ? "mail.action.markRead" : "mail.action.markUnread", glyph: .envelope, tone: tone.secondary) {
                    actions.message(item.unread ? .markRead : .markUnread, item.id)
                }
                rowAction("mail.action.archive", glyph: .archive, tone: tone.secondary) {
                    actions.message(.archive, item.id)
                }
                if inTrash {
                    ConfirmPill(label: nil, question: word("mail.confirm.purge.question"), yes: word("mail.confirm.purge.yes"),
                                no: word("confirm.no"), holdHint: line("mail.confirm.hold", words("mail.confirm.purge.yes")),
                                startsAsking: true, showsProgress: false, onYes: { actions.message(.purge, item.id) }) {
                        Glyph(.trash)
                    }
                } else {
                    rowAction("mail.action.trash", glyph: .trash, tone: tone.secondary) {
                        actions.message(.trash, item.id)
                    }
                }
            }
            .padding(.leading, CGFloat(Design.Spacing.step8))
            .padding(.top, CGFloat(SheetValues.rowPadding))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .background(selected ? design.color(\.ink) : design.color(\.lane))
        }
    }

    private func rowAction(_ key: String, glyph: Icon, tone: KeyPath<DesignColors, RGB>, action: @escaping () -> Void) -> some View {
        SymbolButton(help: words(key), glyph: glyph, tone: tone, hoverTone: selected ? \.onInverse : \.ink, plate: selected ? \.ink : \.lane,
                     ringTone: selected ? \.onInverseLine : \.lineStrong, hover: .tint, action: action)
    }

    private func contextMenu(at point: NSPoint) {
        let lines = MailMenus.row(unread: item.unread, draft: item.draft)
        let entries = MailMenuLine.entries(lines) { action in actions.message(action, item.id, undoable: true, fromMenu: true) }
        menuOpen = true
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthRow, anchor: .point(point), window: NSApp.keyWindow) {
            menuOpen = false
        }
    }
}

struct MailDate: View {
    let label: MailDateLabel
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary

    var body: some View {
        text
            .designText(tone, size: Design.TextSize.small)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private var text: Text {
        switch label {
        case .time(let date): Text(date, format: .dateTime.hour().minute())
        case .yesterday: word("mail.date.yesterday")
        case .weekday(let date): Text(date, format: .dateTime.weekday(.wide))
        case .day(let date): Text(date, format: .dateTime.day().month(.abbreviated))
        case .draft: word("mail.date.draft")
        case .none: Text(verbatim: "")
        }
    }
}
