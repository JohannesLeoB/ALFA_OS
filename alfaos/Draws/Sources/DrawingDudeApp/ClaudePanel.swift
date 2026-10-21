import DrawsAI
import ShellCore
import SwiftUI

struct ClaudePanel: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu))
        VStack(alignment: .leading, spacing: CGFloat(Design.Spacing.step4)) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                say("draws.claude.title").font(style.font(Design.TextSize.body, weight: Design.Weight.medium))
                    .foregroundStyle(style.color(\.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SymbolButton(symbol: "xmark", tip: word("draws.claude.close"), ring: false) { model.assistant = false }
            }
            .padding(.leading, CGFloat(Design.Spacing.step12))
            .padding(.trailing, CGFloat(Design.Spacing.step4))
            .frame(height: CGFloat(Design.Size.rowHeight))
            Segments(options: Approach.allCases.map { ($0, "draws.approach.\($0.rawValue)") }, selection: $model.approach, fill: true)
                .padding(.horizontal, CGFloat(Design.Spacing.step4))
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                ForEach(Source.allCases, id: \.self) { tile($0) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step4))
            if !model.presets.isEmpty { presets }
            editor
            ForEach(model.attachments, id: \.name) { item in
                HStack(spacing: CGFloat(Design.Spacing.step4)) {
                    ListRow(name: item.name, symbol: symbol(item),
                            end: ("xmark", word("draws.brief.remove"), { model.detach(item.name) }))
                    Choice(value: word("draws.role.\(item.role.rawValue)")) {
                        ForEach(Attachment.Role.allCases, id: \.self) { role in
                            Toggle(word("draws.role.\(role.rawValue)"), isOn: Binding(
                                get: { item.role == role }, set: { if $0 { model.role(item.name, role) } }))
                        }
                    }
                }
            }
            if model.approach == .live { trail }
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: hint)
                    .font(style.font(Design.TextSize.small))
                    .foregroundStyle(style.color(model.failure == nil ? \.inkTertiary : \.signal))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.approach == .live {
                    Pill(key: model.running ? "draws.live.stop" : "draws.live.run", accent: true) {
                        if model.running { model.stopLive() } else { model.startLive() }
                    }
                } else {
                    Pill(key: model.designing ? "draws.claude.busy" : "draws.claude.run", accent: true) { model.design() }
                        .opacity(model.designing ? Proto.busy : 1)
                }
            }
            .padding(.leading, CGFloat(Design.Spacing.step12))
            .padding(.trailing, CGFloat(Design.Spacing.step4))
            .frame(height: CGFloat(Design.Size.footerHeight))
        }
        .padding(CGFloat(Design.Spacing.step4))
        .frame(width: CGFloat(Proto.assistantWidth))
        .background(shape.fill(style.color(\.menu)))
        .shadowed(style, style.shadow(\.floating), shape)
        .onExitCommand { model.assistant = false }
    }

    private var presets: some View {
        HStack(spacing: CGFloat(Design.Spacing.step4)) {
            Choice(value: word("draws.preset.title")) {
                ForEach(model.presets) { preset in
                    Button(word(preset.title)) { model.brief = preset.prompt }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step4))
    }

    private func symbol(_ item: Attachment) -> String {
        switch item.mediaType {
        case Attachment.document: return "doc.text"
        case Attachment.text: return "ruler"
        default: return "photo"
        }
    }

    private var hint: String {
        if let failure = model.failure { return failure }
        guard model.approach == .live, !model.running, let ending = model.ending else { return "" }
        return word("draws.ending.\(ending.rawValue)")
    }

    @ViewBuilder
    private var trail: some View {
        if !model.moves.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.moves) { move in
                        ListRow(name: word("draws.tool.\(move.tool)"), symbol: move.phase.symbol,
                                meta: word("draws.move.\(move.phase.rawValue)"),
                                symbolTone: move.phase == .error ? \.signal : \.inkTertiary)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .frame(height: CGFloat(Design.Size.rowHeight * Proto.moveRows))
        }
        if !model.voice.isEmpty { Note(text: model.voice).lineLimit(Proto.voiceLines) }
        HStack(spacing: CGFloat(Design.Spacing.step4)) {
            TextField(text: $model.steer, prompt: say("draws.live.steer")) { EmptyView() }
                .textFieldStyle(.plain)
                .font(style.font())
                .foregroundStyle(style.color(\.ink))
                .onSubmit { model.send() }
            SymbolButton(symbol: "arrow.up", tip: word("draws.live.send"), enabled: model.running) { model.send() }
        }
        .padding(.leading, CGFloat(Design.Spacing.step12))
        .padding(.trailing, CGFloat(Design.Spacing.step4))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(style.color(\.well)))
        .padding(.horizontal, CGFloat(Design.Spacing.step4))
    }

    private func tile(_ kind: Source) -> some View {
        let on = model.source == kind
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        return VStack(spacing: CGFloat(Design.Spacing.step4)) {
            Glyph(name: ["photo", "doc.text", "text.alignleft"][Source.allCases.firstIndex(of: kind) ?? 0], size: Design.Spacing.step16)
            say("draws.source.\(kind.rawValue)").font(style.font(Design.TextSize.small))
        }
        .foregroundStyle(style.color(on ? \.ink : \.inkSecondary))
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(Proto.tileHeight))
        .background(shape.fill(on ? style.color(\.well) : Color.clear))
        .overlay(shape.strokeBorder(style.color(on ? \.ink : \.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
        .contentShape(shape)
        .onTapGesture { model.pick(kind) }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $model.brief)
                .scrollContentBackground(.hidden)
                .font(style.font(Design.TextSize.small))
                .foregroundStyle(style.color(\.ink))
                .padding(.horizontal, CGFloat(Design.Spacing.step8))
                .padding(.vertical, CGFloat(Design.Spacing.step8))
            if model.brief.isEmpty {
                say("draws.brief.placeholder")
                    .font(style.font(Design.TextSize.small))
                    .foregroundStyle(style.color(\.inkTertiary))
                    .padding(.horizontal, CGFloat(Design.Spacing.step12))
                    .padding(.vertical, CGFloat(Design.Spacing.step8))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: CGFloat(Design.Size.composeTextMinHeight))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(style.color(\.well)))
        .padding(.horizontal, CGFloat(Design.Spacing.step4))
        .dropDestination(for: URL.self) { urls, _ in
            model.attach(urls)
            return true
        }
    }
}

extension Phase {
    var symbol: String {
        switch self {
        case .run: return "ellipsis"
        case .ok: return "checkmark"
        case .error: return "exclamationmark.triangle"
        }
    }
}
