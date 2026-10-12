import AppTheme
import CodePlayer
import SwiftUI

/// The source of a card: the file that is chosen, highlighted, with a menu when the card has more files.
struct CodeSourceView: View {
    let model: CodeCardModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let state = model.state
        let name = state.file ?? ""
        let source = CodeText.shown(model.content.files[name] ?? "")
        let family = SyntaxFamily.of(fileName: name, language: model.content.language)
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            if state.fileNames.count > 1 {
                filePicker(state)
            }
            if !state.canPlay {
                Text(LocalizedStringKey("code.notRunning"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
            ScrollView([.vertical, .horizontal]) {
                HighlightedText(code: source.text, family: family)
                    .padding(theme.space(.s3))
            }
            if source.isCut {
                Text(LocalizedStringKey("code.truncated"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
        .padding(theme.space(.s2))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func filePicker(_ state: CodeCardState) -> some View {
        Picker(selection: Binding(get: { model.state.file ?? "" }, set: { model.select($0) })) {
            ForEach(state.fileNames, id: \.self) { name in
                Text(verbatim: name).tag(name)
            }
        } label: {
            Text(LocalizedStringKey("code.file"))
        }
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
    }
}

/// Source text in the colors of its syntax kinds. The pieces are tokenized once for each text and color scheme.
struct HighlightedText: View {
    let code: String
    let family: SyntaxFamily

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var highlighted = AttributedString()

    var body: some View {
        Text(highlighted)
            .font(theme.text(.body).font.monospaced())
            .fixedSize()
            .task(id: Key(code: code, family: family, scheme: scheme)) {
                highlighted = attributed(SyntaxTokenizer.tokens(code, family: family))
            }
    }

    private func attributed(_ tokens: [SyntaxToken]) -> AttributedString {
        var text = AttributedString()
        for token in tokens {
            var piece = AttributedString(token.text)
            piece.foregroundColor = SyntaxColor.color(token.kind, theme: theme, scheme: scheme)
            text += piece
        }
        return text
    }

    private struct Key: Hashable {
        let code: String
        let family: SyntaxFamily
        let scheme: ColorScheme
    }
}
