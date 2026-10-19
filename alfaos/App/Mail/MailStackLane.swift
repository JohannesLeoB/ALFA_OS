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
        .background(StackKeys(model: model, blobOpen: link?.blobOpen ?? false))
        .onChange(of: model.frontRef) { discarding = nil }
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
        if action == .overview { return words("mail.overview.tip", String(model.stackCount)) }
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
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
            group(plan.main, plan: plan)
            Spacer(minLength: 0)
            group(plan.end, plan: plan)
        }
        .padding(.leading, CGFloat(Lane.trailing.headLeading))
        .padding(.trailing, CGFloat(Lane.trailing.headTrailing))
        .frame(height: CGFloat(Design.Size.headerHeight))
        .frame(maxWidth: .infinity)
        .background(design.color(\.lane))
    }

    private func group(_ slots: [CommandSlot], plan: CommandPlan) -> some View {
        HStack(spacing: CGFloat(Lane.trailing.headGap)) {
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
                        no: word("confirm.no"), holdHint: line("mail.confirm.hold", words("mail.confirm.discard.yes")),
                        startsAsking: true, showsProgress: false, onYes: {
                            if let id = discarding { model.discard(id) }
                            discarding = nil
                        }, onNo: { discarding = nil }) {
                Glyph(.trash)
            }
        case .button:
            if slot.action == .more {
                SymbolButton(help: words("mail.action.more"), glyph: .more, hover: .fill) { openMore(plan) }
                    .background(AnchorProbe(box: moreAnchor))
            } else if let action = slot.action, let glyph = action.glyph {
                SymbolButton(help: run.help(slot), glyph: glyph, selected: slot.accent, disabled: slot.off,
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
        let entries = MailMenuLine.entries(lines, warns: false) { run.perform($0) }
        MenuPanel.shared.show(entries: entries, width: Design.Size.menuWidthWide, anchor: .rect(rect), window: NSApp.keyWindow)
    }
}

struct StackArea: View {
    let model: MailModel
    let commands: MailCommands
    let width: Double
    @Binding var discarding: UUID?
    @Binding var formatOn: Bool

    var body: some View {
        CardPile(order: model.stackOrder, fanned: model.overview.open) { ref, depth, first in
            StackCardView(model: model, ref: ref, depth: depth, first: first, commands: commands,
                          discarding: $discarding, formatOn: $formatOn)
        } overview: {
            OverviewView(model: model)
        } note: {
            if let toast = model.toast {
                Toast(message: toastText(toast), undoLabel: toast.undoable ? word("mail.toast.undo") : nil,
                      onUndo: toast.undoable ? { Task { await model.undoToast() } } : nil,
                      onDismiss: { model.dismissToast(toast.serial) })
                    .id(toast.serial)
            }
        }
    }

    private func toastText(_ toast: MailToast) -> Text {
        if let count = toast.kind.count { return line(toast.kind.key, String(count)) }
        return word(toast.kind.key)
    }
}

struct StackKeys: NSViewRepresentable {
    let model: MailModel
    let blobOpen: Bool

    func makeNSView(context: Context) -> StackKeysView {
        StackKeysView()
    }

    func updateNSView(_ view: StackKeysView, context: Context) {
        view.model = model
        view.blobOpen = blobOpen
        view.listen(true)
    }

    static func dismantleNSView(_ view: StackKeysView, coordinator: ()) {
        view.listen(false)
    }
}

final class StackKeysView: NSView {
    var model: MailModel?
    var blobOpen = false
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func listen(_ on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) ?? false } ? nil : event
            }
        } else if !on, let current = monitor {
            NSEvent.removeMonitor(current)
            monitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let model, !blobOpen, event.window === window, !model.overview.open, case .message(let id) = model.frontRef else { return false }
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else { return false }
        if window?.firstResponder is NSText { return false }
        let actions = MailDo(model: model)
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "e":
            actions.message(.archive, id)
            return true
        case "\u{7F}", "\u{F728}":
            actions.message(.trash, id)
            return true
        default:
            return false
        }
    }
}
