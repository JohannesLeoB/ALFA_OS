import AppKit
import DrawsAI
import ShellCore
import SwiftUI
import UniformTypeIdentifiers

struct BriefPanel: View {
    @Environment(\.style) private var style
    @Bindable var model: DrawsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Caption(key: "draws.section.brief")
            editor
            ForEach(model.attachments, id: \.name) { item in
                Row(label: Text(verbatim: item.name), detail: word("draws.brief.remove")) {
                    model.detach(item.name)
                }
            }
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Pill(key: "draws.brief.add") { pick() }
                Pill(key: model.designing ? "draws.brief.running" : "draws.brief.run", accent: true) {
                    model.design()
                }
            }
            .padding(.top, CGFloat(Design.Spacing.step8))
            if !model.assumptions.isEmpty {
                Caption(key: "draws.section.assumptions")
                ForEach(model.assumptions, id: \.self) { assumption in
                    Row(label: Text(verbatim: assumption))
                }
            }
            if !model.questions.isEmpty {
                Caption(key: "draws.section.questions")
                ForEach(model.questions, id: \.self) { question in
                    Row(label: Text(verbatim: question), detailTone: \.signal)
                }
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $model.brief)
                .scrollContentBackground(.hidden)
                .font(style.font())
                .foregroundStyle(style.color(\.ink))
                .padding(CGFloat(Design.Spacing.step8))
                .frame(minHeight: CGFloat(Design.Size.composeTextMinHeight))
                .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row)).fill(style.color(\.well)))
            if model.brief.isEmpty {
                say("draws.brief.placeholder")
                    .font(style.font())
                    .foregroundStyle(style.color(\.inkTertiary))
                    .padding(CGFloat(Design.Spacing.step8))
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.attach(urls)
            return true
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .pdf]
        if panel.runModal() == .OK { model.attach(panel.urls) }
    }
}
