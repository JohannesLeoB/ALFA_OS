import AppKit
import Mail
import ShellCore
import SwiftUI
import UniformTypeIdentifiers

struct MailStackLane: View {
    let model: MailModel
    @Environment(\.mailLaneLink) private var link
    @State private var discarding: UUID?
    @State private var formatOn = false

    private var confirming: Bool {
        if let discarding, model.frontRef == .draft(discarding) { return true }
        return false
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let commands = model.commands(confirmDiscard: confirming, canFold: (link?.openLanes ?? 1) > 1, formatOn: formatOn,
                                          sendLabelled: width - Design.Size.edge >= Design.Size.breakpointSendLabel)
            VStack(spacing: 0) {
                CommandHeader(model: model, commands: commands, width: width, discarding: $discarding, formatOn: $formatOn)
                StackArea(model: model, commands: commands, width: width, discarding: $discarding, formatOn: $formatOn)
            }
        }
        .replacingLaneHeader()
    }
}

struct SlotRun {
    let model: MailModel
    let link: MailLaneLink?
    var discarding: Binding<UUID?>
    var formatOn: Binding<Bool>

    @MainActor
    func perform(_ action: MailAction) {
        let actions = MailDo(model: model)
        switch (action, model.frontRef) {
        case (.overview, _): model.openOverview(true)
        case (.backToStack, _): model.openOverview(false)
        case (.foldColumn, _): link?.fold(.trailing)
        case (.format, _): formatOn.wrappedValue.toggle()
        case (.saveDraft, .draft(let id)): Task { await model.save(id) }
        case (.discardDraft, .draft(let id)): discarding.wrappedValue = id
        case (.send, .draft(let id)):
            Task { await model.send(id) }
        case (.attachFile, .draft(let id)): Self.pick(model, id)
        case (_, .message(let id)): actions.message(action, id)
        default: break
        }
    }

    @MainActor
    static func pick(_ model: MailModel, _ id: UUID) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            model.attach(id, filename: url.lastPathComponent, mimeType: mime, data: data)
        }
    }

    @MainActor
    func help(_ slot: CommandSlot) -> String {
        guard let action = slot.action else { return "" }
        if action == .overview { return words("mail.overview.tip", model.stackCount) }
        return words(action.key)
    }
}

struct CommandHeader: View {
    @Environment(\.design) private var design
    @Environment(\.mailLaneLink) private var link
    let model: MailModel
    let commands: MailCommands
    let width: Double
    @Binding var discarding: UUID?
    @Binding var formatOn: Bool
    @State private var moreAnchor = AnchorBox()

    private var run: SlotRun { SlotRun(model: model, link: link, discarding: $discarding, formatOn: $formatOn) }

    var body: some View {
        let plan = CommandBar.plan(main: commands.main, tail: commands.tail, fan: commands.fan, fold: commands.fold,
                                   staticMore: commands.staticMore, width: width - Design.Size.edge)
        HStack(spacing: CGFloat(Design.Size.headGapStack)) {
            group(plan.main, plan: plan)
            Spacer(minLength: 0)
            group(plan.end, plan: plan)
        }
        .padding(.horizontal, CGFloat(Design.Size.headPadRight))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(design.color(\.lane))
    }

    private func group(_ slots: [CommandSlot], plan: CommandPlan) -> some View {
        HStack(spacing: CGFloat(Design.Size.headGapStack)) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                view(slot, plan: plan)
            }
        }
    }

    @ViewBuilder
    private func view(_ slot: CommandSlot, plan: CommandPlan) -> some View {
        switch slot.kind {
        case .separator:
            Rectangle().fill(design.color(\.line)).frame(width: CGFloat(Design.Size.hairline), height: CGFloat(Design.Spacing.step20))
                .padding(.horizontal, CGFloat(Design.Spacing.step4))
        case .pill:
            ConfirmPill(label: nil, question: word("mail.confirm.discard.question"), yes: word("mail.confirm.discard.yes"),
                        no: word("text.common.cancel"), holdHint: line("mail.confirm.hold", words("mail.confirm.discard.yes")),
                        startsAsking: true, showsProgress: false, onYes: {
                            if let id = discarding { model.discard(id) }
                            discarding = nil
                        }, onNo: { discarding = nil }) {
                Glyph(.trash)
            }
        case .button:
            if slot.action == .more {
                HeadSymbol(help: words("mail.action.more"), glyph: .more, hover: .fill) { openMore(plan) }
                    .background(AnchorProbe(box: moreAnchor))
            } else if let action = slot.action, let glyph = action.glyph {
                HeadSymbol(help: run.help(slot), glyph: glyph, selected: slot.accent, disabled: slot.off,
                           tone: slot.signal ? \.signal : \.inkSecondary, hoverTone: slot.signal ? \.signal : \.ink, hover: .fill) {
                    run.perform(action)
                }
                .keyboardShortcut(action.shortcut)
            }
        }
    }

    private func openMore(_ plan: CommandPlan) {
        guard let rect = moreAnchor.screenRect() else { return }
        let lines = plan.overflow.compactMap { slot in slot.action.map { MailMenuLine.item($0) } }
        let entries = MailMenuLine.entries(lines) { run.perform($0) }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct StackArea: View {
    @Environment(\.design) private var design
    @Environment(\.accessibilityReduceMotion) private var reduced
    let model: MailModel
    let commands: MailCommands
    let width: Double
    @Binding var discarding: UUID?
    @Binding var formatOn: Bool

    private var reorder: Animation? {
        let curve = Design.Easing.stack
        return reduced ? nil : .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Design.Duration.stack)
    }

    var body: some View {
        GeometryReader { proxy in
            let order = model.stackOrder
            let tops = CardStack.tops(count: order.count)
            ZStack(alignment: .top) {
                if order.isEmpty {
                    RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card))
                        .fill(design.color(\.lane))
                        .overlay(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.card)).strokeBorder(design.color(\.line), lineWidth: CGFloat(Design.Size.hairline)))
                        .accessibilityLabel(word("mail.stack.empty"))
                }
                ForEach(Array(order.enumerated()), id: \.element) { index, ref in
                    StackCardView(model: model, ref: ref, depth: order.count - 1 - index, first: index == 0, commands: commands,
                                  discarding: $discarding, formatOn: $formatOn)
                        .frame(height: max(0, proxy.size.height - CGFloat(tops[index])))
                        .offset(y: CGFloat(tops[index]))
                        .zIndex(Double(index))
                        .opacity(model.overview.open ? 0 : 1)
                        .allowsHitTesting(!model.overview.open)
                }
                if model.overview.open {
                    OverviewView(model: model)
                        .zIndex(Double(order.count + 1))
                }
                if let toast = model.toast {
                    VStack {
                        Spacer(minLength: 0)
                        Toast(message: toastText(toast), undoLabel: toast.undoable ? word("mail.toast.undo") : nil,
                              onUndo: toast.undoable ? { Task { await model.undoToast() } } : nil,
                              onDismiss: { model.dismissToast(toast.serial) })
                            .id(toast.serial)
                            .padding(.bottom, CGFloat(MailSheet.toastBottom))
                    }
                    .zIndex(Double(order.count + 2))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .animation(reorder, value: order)
        }
    }

    private func toastText(_ toast: MailToast) -> Text {
        if let count = toast.kind.count { return line(toast.kind.key, count) }
        return word(toast.kind.key)
    }
}
