import SwiftUI
import AppKit
import AppTheme
import BoardModel
import Tokens

/// The output sheet: the token sets of the document in one of five formats, with the code as preview.
/// The text comes from `TokenFormat`; the sheet only shows it, saves it to a file the person picks, or copies it.
struct ExportSheet: View {
    var store: BoardStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    @State private var format: TokenFormat = .dtcg

    /// All colour, dimension and text tokens of the document, in one set.
    private var set: TokenSet {
        TokenSet(name: "tokens", tokens: store.document.tokenSets.flatMap(\.tokens))
    }

    private var preview: String {
        (try? format.text(set)) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s4)) {
            HStack {
                Text("workshop.title")
                    .font(theme.text(.heading).font)
                Spacer()
                Button("command.file.close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            if set.tokens.isEmpty {
                Text("workshop.empty")
                    .foregroundStyle(theme.color(.textMuted, scheme))
            } else {
                Picker("workshop.format", selection: $format) {
                    ForEach(TokenFormat.allCases, id: \.self) { option in
                        Text(label(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                ScrollView([.vertical, .horizontal]) {
                    Text(verbatim: preview)
                        .font(theme.text(.caption).font.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                HStack {
                    Spacer()
                    Button("command.edit.copy", action: copy)
                    Button("workshop.save", action: save)
                }
            }
        }
        .padding(theme.space(.s6))
        .frame(minWidth: 640, minHeight: 420)
    }

    private func label(_ format: TokenFormat) -> LocalizedStringKey {
        switch format {
        case .dtcg: "workshop.format.dtcg"
        case .css: "workshop.format.css"
        case .swiftUI: "workshop.format.swiftui"
        case .tailwind: "workshop.format.tailwind"
        case .compose: "workshop.format.compose"
        }
    }

    // MARK: Actions

    /// Puts the shown text on the pasteboard, as plain text.
    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preview, forType: .string)
    }

    /// Asks where to save, then writes the shown text. A failed write shows the reason and writes nothing more.
    private func save() {
        let text = preview
        let panel = NSSavePanel()
        panel.nameFieldStringValue = format.fileName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert()
                alert.messageText = String(localized: "export.failed.title")
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}
