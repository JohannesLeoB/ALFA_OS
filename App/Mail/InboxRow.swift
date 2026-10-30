import AppKit
import Core
import Design
import Mail
import Shell
import SwiftUI

struct InboxRow: View {
    @Environment(\.appearance) private var appearance
    let session: AppSession
    let item: RowPresentation
    let separated: Bool
    let wide: Bool
    let inTrash: Bool
    let picking: Bool
    @State private var hovering = false
    @State private var menuOpen = false

    private var inbox: InboxState { session.inbox }
    private var selected: Bool { item.selected && !item.picked }
    private var tone: RowTone { .of(selected) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)) }
    private var fill: Color { selected ? appearance.color(\.ink) : Color.clear }

    private var ringColor: Color? {
        if item.picked { return appearance.color(\.ink) }
        if (hovering || menuOpen) && !selected { return appearance.color(\.lineStrong) }
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
            confirmation
        }
        .contentShape(shape)
        .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { if !onMark($0.location) && NSEvent.modifierFlags.intersection([.shift, .command]).isEmpty { open(pin: true) } })
        .simultaneousGesture(SpatialTapGesture().onEnded { tap(on: $0.location) })
        .overlay(alignment: .topTrailing) { rowActions }
        .overlay { RightClickOverlay { point in contextMenu(at: point) } }
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.hover), value: hovering)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func onMark(_ point: CGPoint) -> Bool {
        CGRect(x: Tokens.Spacing.step8, y: Tokens.Spacing.step12, width: Tokens.Size.symbolSize, height: Tokens.Size.symbolSize)
            .contains(point)
    }

    private func tap(on point: CGPoint) {
        let keys = NSEvent.modifierFlags
        if keys.contains(.shift) {
            inbox.pickRange(to: item.id)
        } else if keys.contains(.command) || onMark(point) {
            inbox.pick(item.id)
        } else {
            open(pin: false)
        }
    }

    private func open(pin: Bool) {
        if picking {
            if !pin { inbox.pick(item.id) }
        } else if item.outbox != nil {
            inbox.openQueued(item.id)
        } else if item.draft {
            Task { await inbox.editDraft(item.id) }
        } else {
            Task { await inbox.open(item.id, pin: pin) }
        }
    }

    private var mark: some View {
        let key = item.picked ? "mail.pick.remove" : "mail.pick.add"
        return Group {
            if item.picked {
                Mark(fill: .filled) { Glyph(.tick) }
            } else {
                Mark(fill: item.unread ? .filled : .rest, inverted: selected) {
                    if item.initials.isEmpty { Glyph(.person) } else { Text(verbatim: item.initials) }
                }
            }
        }
        .help(appearance.text(key))
        .accessibilityLabel(appearance.text(key))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { inbox.pick(item.id) }
    }

    private var head: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            sender
            if let thread = item.thread {
                Counter(value: Format.number(thread), tone: tone.tertiary)
                    .help(appearance.text("mail.row.thread"))
            }
            Spacer(minLength: 0)
            if item.starred {
                Glyph.small(.flag).foregroundStyle(appearance.color(tone.secondary)).opacity(hovering ? 0 : 1)
            }
            MessageDate(label: item.date, draft: item.draft, tone: tone.tertiary).opacity(hovering ? 0 : 1)
        }
        .frame(height: CGFloat(SheetValues.rowTextLine))
    }

    private var sender: some View {
        let text: Text
        if item.outgoing && item.sender.isEmpty {
            text = appearance.text("mail.row.newMessage")
        } else if item.outgoing {
            text = Text(verbatim: appearance.format("mail.row.to", item.sender))
        } else if item.sender.isEmpty {
            text = appearance.text("mail.row.unknown")
        } else {
            text = Text(verbatim: item.sender)
        }
        return text
            .designText(tone.primary, size: Tokens.TextSize.body, weight: item.unread ? .semibold : .medium)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(Text(verbatim: item.address))
    }

    private var subject: some View {
        Group {
            if let subject = item.subject {
                Text(verbatim: subject)
                    .designText(item.unread ? tone.primary : tone.secondary, size: Tokens.TextSize.body, weight: item.unread ? .medium : .regular)
            } else {
                appearance.text("mail.row.noSubject")
                    .designText(tone.tertiary, size: Tokens.TextSize.body)
            }
        }
        .lineLimit(1)
        .frame(height: CGFloat(SheetValues.rowTextLine), alignment: .leading)
    }

    private var preview: some View {
        Group {
            if let state = item.outbox {
                appearance.text(state.key).designText(state.needsAttention && !selected ? \.signal : tone.secondary,
                                                      size: Tokens.TextSize.body, weight: .light)
            } else if let preview = item.preview {
                Text(verbatim: preview).designText(tone.secondary, size: Tokens.TextSize.body, weight: .light)
            } else {
                appearance.text("mail.row.noText").designText(tone.tertiary, size: Tokens.TextSize.body, weight: .light)
            }
        }
        .lineLimit(SheetValues.previewLines)
        .lineHeight(SheetValues.rowTextLine, size: Tokens.TextSize.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chips: some View {
        let shown = Array(item.attachments.prefix(wide ? Tokens.Count.attachmentsWide : Tokens.Count.attachmentsNarrow))
        let more = item.attachmentTotal - shown.count
        if !shown.isEmpty {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                ForEach(shown) { row in
                    AttachmentChip(name: PersonName.middle(row.name, limit: SheetValues.attachmentChipNameLimit),
                                   detail: row.name + " \u{00B7} " + row.size, inverted: selected) { Glyph.small(.doc) }
                }
                if more > 0 {
                    Counter(value: more.formatted(.number.sign(strategy: .always())), tone: tone.tertiary, ringTone: tone.line)
                        .help(appearance.text("mail.row.moreAttachments"))
                }
            }
            .padding(.top, CGFloat(Tokens.Spacing.step8))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var confirmation: some View {
        if case .unverified = item.outbox {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ConfirmPill(label: nil, question: appearance.text("mail.outbox.confirm.question"), yes: appearance.text("mail.outbox.confirm.yes"),
                            no: appearance.text("confirm.no"),
                            holdHint: Text(verbatim: appearance.format("mail.confirm.hold", appearance.string("mail.outbox.confirm.yes"))),
                            startsAsking: true, showsProgress: false, onYes: { Task { await inbox.confirmQueued(item.id) } }) {
                    Glyph(.send)
                }
            }
            .padding(.top, CGFloat(Tokens.Spacing.step8))
        }
    }

    @ViewBuilder
    private var queuedActions: some View {
        if let state = item.outbox, state != .sending {
            HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
                if case .failed = state {
                    rowAction("mail.outbox.retry.tooltip", glyph: .send, tone: tone.secondary) {
                        Task { await inbox.resendQueued(item.id) }
                    }
                }
                ConfirmPill(label: nil, question: appearance.text("mail.confirm.discard.question"), yes: appearance.text("mail.confirm.discard.yes"),
                            no: appearance.text("confirm.no"),
                            holdHint: Text(verbatim: appearance.format("mail.confirm.hold", appearance.string("mail.confirm.discard.yes"))),
                            showsProgress: false, onYes: { Task { await inbox.discardQueued(item.id) } }) {
                    Glyph(.trash)
                }
            }
            .padding(.leading, CGFloat(Tokens.Spacing.step8))
            .background(selected ? appearance.color(\.ink) : appearance.color(\.lane))
            .padding(.top, CGFloat(Tokens.Spacing.step12))
            .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        }
    }

    @ViewBuilder
    private var rowActions: some View {
        if hovering && !picking && item.outbox != nil {
            queuedActions
        } else if hovering && !picking && !item.draft {
            HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
                rowAction(item.starred ? "mail.action.unstar" : "mail.action.star", glyph: .flag, tone: item.starred ? tone.primary : \.inkTertiary) {
                    session.perform(item.starred ? .unstar : .star, message: item.id)
                }
                rowAction(item.unread ? "mail.action.markRead" : "mail.action.markUnread", glyph: .envelope, tone: tone.secondary) {
                    session.perform(item.unread ? .markRead : .markUnread, message: item.id)
                }
                rowAction("mail.action.archive", glyph: .archive, tone: tone.secondary) {
                    session.perform(.archive, message: item.id)
                }
                if inTrash && inbox.canPurge(item.id) {
                    ConfirmPill(label: nil, question: appearance.text("mail.confirm.purge.question"), yes: appearance.text("mail.confirm.purge.yes"),
                                no: appearance.text("confirm.no"),
                                holdHint: Text(verbatim: appearance.format("mail.confirm.hold", appearance.string("mail.confirm.purge.yes"))),
                                startsAsking: true, showsProgress: false, onYes: { session.perform(.purge, message: item.id) }) {
                        Glyph(.trash)
                    }
                } else if !inTrash {
                    rowAction("mail.action.trash", glyph: .trash, tone: tone.secondary) {
                        session.perform(.trash, message: item.id)
                    }
                }
            }
            .padding(.leading, CGFloat(Tokens.Spacing.step8))
            .background(selected ? appearance.color(\.ink) : appearance.color(\.lane))
            .padding(.top, CGFloat(Tokens.Spacing.step12))
            .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        }
    }

    private func rowAction(_ key: String, glyph: Icon, tone: KeyPath<Colors, ColorValue>, action: @escaping () -> Void) -> some View {
        SymbolButton(help: appearance.string(key), glyph: glyph, tone: tone, hoverTone: selected ? \.onInverse : \.ink, plate: selected ? \.ink : \.lane,
                     ringTone: selected ? \.onInverseLine : \.lineStrong, hover: .tint, action: action)
    }

    private func contextMenu(at point: NSPoint) {
        guard item.outbox == nil else { return }
        let lines = MenuEngine.row(unread: item.unread, draft: item.draft)
        let entries = MenuLine.entries(lines, appearance: appearance) { action in
            if action == .move {
                menuOpen = true
                MenuPanel.shared.show(entries: MoveFolderList.entries(session.inbox, appearance: appearance, message: item.id), anchor: .point(point),
                                      window: NSApp.keyWindow) { menuOpen = false }
            } else {
                session.perform(action, message: item.id, undoable: true, fromMenu: true)
            }
        }
        menuOpen = true
        MenuPanel.shared.show(entries: entries, anchor: .point(point), window: NSApp.keyWindow) {
            menuOpen = false
        }
    }
}

struct MessageDate: View {
    @Environment(\.appearance) private var appearance
    let label: DateLabel
    var draft = false
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary

    var body: some View {
        Self.text(label, draft: draft, appearance: appearance)
            .designText(tone, size: Tokens.TextSize.small)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    static func text(_ label: DateLabel, draft: Bool, appearance: Appearance) -> Text {
        if draft { return appearance.text("mail.date.draft") }
        switch label {
        case .time(let date): return Text(date, format: .dateTime.hour().minute())
        case .yesterday: return appearance.text("mail.date.yesterday")
        case .weekday(let date): return Text(date, format: .dateTime.weekday(.wide))
        case .day(let date): return Text(date, format: .dateTime.day().month(.abbreviated))
        case .none: return Text(verbatim: "")
        }
    }
}

struct RowTone {
    let primary: KeyPath<Colors, ColorValue>
    let secondary: KeyPath<Colors, ColorValue>
    let tertiary: KeyPath<Colors, ColorValue>
    let line: KeyPath<Colors, ColorValue>

    static func of(_ selected: Bool) -> RowTone {
        let ink = InkSet.of(selected)
        return RowTone(primary: ink.primary, secondary: ink.secondary, tertiary: ink.tertiary, line: ink.line)
    }
}
