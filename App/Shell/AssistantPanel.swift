import Assistant
import Design
import Shell
import SwiftUI

struct AssistantPanel: View {
    let session: AppSession
    @Environment(\.appearance) private var appearance
    @State private var whole = CGFloat.zero
    @State private var thread = CGFloat.zero

    private var desk: DeskState { session.desk }

    var body: some View {
        let conversation = session.conversation
        let turns = conversation.turns
        let off = session.assistantOff
        let fixed = max(CGFloat(Tokens.Spacing.step40 + Tokens.Spacing.step28 + Tokens.Spacing.step44), whole - thread)
        let room = CGFloat(desk.blob.menuRoom(window: desk.window, measure: desk.measure)) - fixed
        VStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Rectangle()
                .fill(appearance.color(\.inverseLine))
                .frame(height: CGFloat(Tokens.Size.hairline))
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            if !turns.isEmpty {
                AssistantThread(turns: turns, room: room, retry: session.retryAssistant)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { thread = $0 }
                    .onDisappear { thread = 0 }
            }
            if !off && session.claudeFailed {
                settingsCard(session.assistantHintKey, offered: true, open: session.openClaudeSettings)
            } else if !off && turns.isEmpty {
                appearance.text(session.assistantHintKey)
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if off {
                settingsCard("shell.assistantCard.off", offered: session.assistantOffersSettings, open: session.openAssistantSettings)
            }
            if !turns.isEmpty {
                AssistantScope(clear: conversation.clear)
            }
            if !conversation.pending.isEmpty {
                ChipWrapLayout(gap: CGFloat(Tokens.Spacing.step8)) {
                    ForEach(conversation.pending) { pending in
                        AssistantAttachment(name: pending.file.fileName) { conversation.removePending(pending.id) }
                    }
                }
                .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            AssistantInput(conversation: conversation, off: off, files: session.assistantFiles,
                           attach: session.attachToAssistant, send: session.askAssistant, close: desk.close)
        }
        .typeStyle(Tokens.TextStyle.body)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .padding(.bottom, CGFloat(Tokens.Spacing.step8))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { whole = $0 }
        .onAppear { session.seeAssistant() }
    }

    private func settingsCard(_ key: String, offered: Bool, open: @escaping () -> Void) -> some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            appearance.text(key)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if offered {
                TextButton(label: appearance.text("mail.draft.grant.act"), kind: .inverse, plate: \.inverseHot, action: open)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
    }
}

struct AssistantActivity: View {
    @Environment(\.appearance) private var appearance
    let label: String
    let failed: Bool

    var body: some View {
        let dot = CGFloat(Tokens.Spacing.step4)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Circle()
                .fill(.foreground)
                .frame(width: dot, height: dot)
                .accessibilityHidden(true)
            Text(verbatim: label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .typeStyle(Tokens.TextStyle.caption)
        .foregroundStyle(appearance.color(failed ? \.onInverse : \.onInverseTertiary))
    }
}

struct AssistantAttachment: View {
    @Environment(\.appearance) private var appearance
    let name: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Glyph(.doc)
                .accessibilityHidden(true)
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.tail)
            if let onRemove {
                SymbolButton(help: appearance.string("shell.chipRemove.assistant.tooltip"), glyph: .close, side: Tokens.Spacing.step20,
                             glyphSize: SheetValues.smallIcon, tone: nil, hoverTone: nil, ringed: false, hover: .fill, hoverFill: \.inverseHot,
                             pressed: false, action: onRemove)
            }
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(onRemove == nil ? Tokens.Spacing.step12 : Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .background(Capsule().fill(appearance.color(\.inverseField)))
        .help(Text(verbatim: name))
    }
}

struct AssistantCard: View {
    @Environment(\.appearance) private var appearance
    let kindKey: String
    let title: String
    let line: String?
    var addressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
            appearance.text(kindKey)
                .typeStyle(Tokens.TextStyle.caption)
                .foregroundStyle(appearance.color(\.onInverseTertiary))
            Text(verbatim: title)
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(verbatim: addressed ? appearance.format("mail.row.to", line) : line)
                    .typeStyle(Tokens.TextStyle.caption)
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
    }
}

extension AssistantCard {
    init(draft: DraftSummary) {
        self.init(kindKey: Self.kindKey(draft.kind), title: draft.title, line: draft.line, addressed: draft.kind == .mail)
    }

    private static func kindKey(_ kind: DraftSummary.Kind) -> String {
        switch kind {
        case .mail: "shell.assistantCard.kind.mail"
        case .contact: "shell.assistantCard.kind.contact"
        case .task: "shell.assistantCard.kind.task"
        case .appointment: "shell.assistantCard.kind.appointment"
        case .cart: "shell.assistantCard.kind.cart"
        case .file: "shell.assistantCard.kind.file"
        case .calendar: "shell.assistantCard.kind.calendar"
        }
    }
}

struct AssistantInput: View {
    @Environment(\.appearance) private var appearance
    @Bindable var conversation: ChatState
    let off: Bool
    let files: Bool
    let attach: () -> Void
    let send: () -> Void
    let close: () -> Void
    @FocusState private var focused: Bool

    private var ready: Bool { !off && conversation.canSend }

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
            SymbolButton(help: appearance.string(files ? "mail.action.attachFile" : "shell.symbolButton.assistantAttachOff.tooltip"),
                         glyph: .attach, disabled: !files, tone: nil, hoverTone: nil, ringed: false, hover: .fill, hoverFill: \.inverseHot, pressed: false,
                         action: attach)
            ZStack(alignment: .leading) {
                if conversation.draft.isEmpty {
                    appearance.text("shell.assistantInput.field")
                        .lineLimit(1)
                        .opacity(SheetValues.placeholderOpacity)
                        .allowsHitTesting(false)
                }
                TextField("", text: $conversation.draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .disabled(off)
                    .onSubmit { send() }
                    .onKeyPress(.escape) {
                        close()
                        return .handled
                    }
                    .accessibilityLabel(appearance.text("shell.assistantInput.field"))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step4))
            .frame(maxWidth: .infinity)
            SymbolButton(help: appearance.string("mail.action.send"), glyph: .send, disabled: !ready, dimmed: false,
                         tone: ready ? \.inverse : \.onInverseTertiary, hoverTone: nil, ringed: false, plate: ready ? \.onInverse : nil, hover: .none,
                         pressed: false, action: send)
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step4))
        .padding(.trailing, CGFloat(Tokens.Spacing.step8))
        .frame(height: CGFloat(Tokens.Spacing.step40))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
        .opacity(off ? Tokens.Opacity.disabled : 1)
        .task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.toggle))
            focused = true
        }
    }
}

struct AssistantMessage: View {
    @Environment(\.appearance) private var appearance
    let turn: ChatTurn
    let retry: () -> Void

    private var user: Bool { turn.kind == .user }

    var body: some View {
        VStack(alignment: user ? .trailing : .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            if !turn.blocks.isEmpty {
                blocks
            }
            if turn.kind == .streaming {
                appearance.text("shell.assistantMessage.thinking")
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            }
            if turn.kind == .failed {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                        appearance.text("shell.assistantMessage.failed")
                            .fixedSize()
                        retryButton
                    }
                    VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
                        appearance.text("shell.assistantMessage.failed")
                            .fixedSize(horizontal: false, vertical: true)
                        retryButton
                    }
                }
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            }
        }
        .frame(maxWidth: .infinity, alignment: user ? .trailing : .leading)
        .padding(.leading, user ? CGFloat(Tokens.Spacing.step28) : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(appearance.text(user ? "shell.assistantMessage.user" : "shell.assistantMessage.assistant"))
    }

    private var retryButton: some View {
        TextButton(label: appearance.text("mail.list.failed.act"), kind: .inverse, action: retry)
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            ForEach(Array(turn.blocks.enumerated()), id: \.offset) { _, block in
                piece(block)
            }
        }
        .padding(.vertical, user ? CGFloat(Tokens.Spacing.step8) : 0)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(user ? appearance.color(\.inverseField) : Color.clear))
    }

    @ViewBuilder
    private func piece(_ block: TurnBlock) -> some View {
        switch block {
        case .activity(let label, let failed):
            AssistantActivity(label: label, failed: failed)
        case .text(let value):
            Text(verbatim: value)
                .fixedSize(horizontal: false, vertical: true)
        case .draft(let draft):
            AssistantCard(draft: draft)
        case .estimate(let minNet, let maxNet):
            AssistantCard(kindKey: "shell.assistantCard.kind.estimate",
                          title: appearance.format("shell.assistantCard.estimateRange", amount(minNet), amount(maxNet)), line: nil)
        case .breakdown(let lines):
            AssistantCard(kindKey: "shell.assistantCard.kind.estimate",
                          title: appearance.format("shell.assistantCard.breakdownLines", String(lines)), line: nil)
        case .file(let name):
            AssistantAttachment(name: name)
        case .unreadable:
            appearance.text("shell.assistantCard.unreadable")
                .foregroundStyle(appearance.color(\.onInverseTertiary))
        }
    }

    private func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

struct AssistantScope: View {
    @Environment(\.appearance) private var appearance
    let clear: () -> Void

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Spacer(minLength: 0)
            SymbolButton(help: appearance.string("shell.symbolButton.assistantClear.tooltip"), glyph: .trash, tone: nil, hoverTone: nil, ringed: false,
                         hover: .fill, hoverFill: \.inverseHot, pressed: false, action: clear)
        }
        .typeStyle(Tokens.TextStyle.caption)
        .foregroundStyle(appearance.color(\.onInverseTertiary))
        .padding(.leading, CGFloat(Tokens.Spacing.step12))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Spacing.step28))
    }
}

struct AssistantThread: View {
    let turns: [ChatTurn]
    let room: CGFloat
    let retry: () -> Void
    @State private var height = CGFloat.zero

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: CGFloat(Tokens.Spacing.step12)) {
                ForEach(turns) { turn in
                    AssistantMessage(turn: turn, retry: retry)
                }
            }
            .padding(.vertical, CGFloat(Tokens.Spacing.step4))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollIndicators(.never)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .frame(height: min(height, max(0, room)))
    }
}

struct AssistantToast: View {
    @Environment(\.appearance) private var appearance
    let conversation: ChatState

    var body: some View {
        if let note = conversation.note {
            switch note {
            case .cleared:
                ToastView(message: appearance.text("shell.assistantThread.cleared"), undoLabel: appearance.text("mail.toast.undo"),
                          onUndo: conversation.undo, onDismiss: conversation.dismiss)
                    .id(conversation.noteSerial)
            case .rejected(let failure):
                ToastView(message: Text(verbatim: message(failure)), failed: true, onDismiss: conversation.dismiss)
                    .id(conversation.noteSerial)
            case .privacyUnreadable:
                ToastView(message: appearance.text("assistant.failure.generic"), failed: true, onDismiss: conversation.dismiss)
                    .id(conversation.noteSerial)
            }
        }
    }

    private func message(_ failure: AttachmentFailure) -> String {
        switch failure {
        case .unsupported(let name): appearance.format("shell.assistantAttachment.unsupported", name)
        case .tooLarge(let name): appearance.format("shell.assistantAttachment.tooLarge", name)
        case .unreadable(let name): appearance.format("shell.assistantAttachment.unreadable", name)
        }
    }
}

struct ThinkingOrb: View {
    @Environment(\.appearance) private var appearance
    let size: Double
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: appearance.still)) { context in
            orb(elapsed: appearance.still ? 0 : context.date.timeIntervalSince(start))
        }
    }

    private func orb(elapsed: Double) -> some View {
        let side = CGFloat(size)
        let spot = side * CGFloat(SheetValues.orbSpot)
        let orbits = [Tokens.Duration.orbOrbitFirst, Tokens.Duration.orbOrbitSecond, Tokens.Duration.orbOrbitThird]
        let colors = [appearance.mood(\.coral), appearance.mood(\.apricot), appearance.mood(\.rose)]
        let reach = appearance.still ? 0 : Double(spot) * SheetValues.orbOrbit
        return ZStack {
            appearance.color(\.orb)
            ForEach(0..<SheetValues.orbCount, id: \.self) { index in
                let direction: Double = index == 1 ? -1 : 1
                let angle = 2 * Double.pi * elapsed / orbits[index] * direction
                Circle()
                    .fill(colors[index])
                    .frame(width: spot, height: spot)
                    .blur(radius: CGFloat(Tokens.Size.orbGlowBlur))
                    .blendMode(.screen)
                    .offset(x: CGFloat(cos(angle) * reach), y: CGFloat(sin(angle) * reach))
            }
            RadialGradient(
                colors: [appearance.color(\.orbGloss), appearance.color(\.orbGloss).opacity(0)],
                center: UnitPoint(x: SheetValues.orbGlossX, y: SheetValues.orbGlossY),
                startRadius: 0,
                endRadius: glossRadius(side)
            )
        }
        .compositingGroup()
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(appearance.color(\.orbRim), lineWidth: CGFloat(Tokens.Size.hairline)))
    }

    private func glossRadius(_ side: CGFloat) -> CGFloat {
        let rx = 2.0.squareRoot() * max(SheetValues.orbGlossX, 1 - SheetValues.orbGlossX)
        let ry = 2.0.squareRoot() * max(SheetValues.orbGlossY, 1 - SheetValues.orbGlossY)
        return side * CGFloat(SheetValues.orbGlossStop * (rx + ry) / 2)
    }
}
