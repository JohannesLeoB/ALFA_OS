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
            HStack(spacing: CGFloat(Design.Spacing.step4)) {
                ForEach(Source.allCases, id: \.self) { tile($0) }
            }
            .padding(.horizontal, CGFloat(Design.Spacing.step4))
            editor
            ForEach(model.attachments, id: \.name) { item in
                ListRow(name: item.name, symbol: item.mediaType == Attachment.document ? "doc.text" : "photo",
                        end: ("xmark", word("draws.brief.remove"), { model.detach(item.name) }))
            }
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: hint)
                    .font(style.font(Design.TextSize.small))
                    .foregroundStyle(style.color(model.failure == nil ? \.inkTertiary : \.signal))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Pill(key: model.designing ? "draws.claude.busy" : "draws.claude.run", accent: true) { model.design() }
                    .opacity(model.designing ? Proto.busy : 1)
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

    private var hint: String {
        if let failure = model.failure { return failure }
        if model.designing { return word("draws.claude.running") }
        return word(model.source == .text ? "draws.claude.hintText" : "draws.claude.hintFile")
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
