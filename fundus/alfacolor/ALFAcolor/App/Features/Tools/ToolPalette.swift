import SwiftUI
import AppTheme
import BoardModel

/// The palette of the tools: one column of symbol buttons that floats over the canvas. It is the only glass on
/// the canvas level besides the context bar. A click chooses the tool; a double click opens the inspector with its options.
/// The palette has no background of its own, so the canvas keeps the clicks beside it.
struct ToolPalette: View {
    var shell: ShellState
    var interaction: CanvasInteraction
    var canvas: CanvasController?

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    /// The system colour sampler of the eyedropper. It is started by a click on the tool and shows nothing else.
    @State private var sampler = NSColorSampler()

    var body: some View {
        GlassEffectContainer(spacing: theme.space(.s1)) {
            VStack(spacing: theme.space(.s1)) {
                ForEach(Tool.allCases, id: \.self) { tool in
                    button(tool)
                }
            }
            .padding(theme.space(.s2))
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.leading, theme.space(.s6))
    }

    /// Samples a colour on the screen and adds it as a colour field of the document. Cancelling changes nothing.
    private func startSampler() {
        let store = interaction.store
        sampler.show { picked in
            Task { @MainActor in
                guard let picked, let color = ColorFieldsSection.rgb(from: Color(nsColor: picked)) else { return }
                let name = ColorFields.freeName(base: String(localized: "tokens.newName"), in: store.document.tokenSets)
                try? store.changeTokenSets(nameKey: "undo.color.add") { try ColorFields.add(name: name, color: color, to: &$0) }
            }
        }
    }

    private func button(_ tool: Tool) -> some View {
        let active = interaction.tools.active == tool
        // Active: filled with the text colour and the symbol in the content colour, as the contract's control rule says.
        let ink: Color = active ? theme.color(.surfaceContent, scheme) : theme.color(.text, scheme)
        let usable = tool.isWired || tool == .eyedropper
        return Button {
            if tool == .eyedropper { startSampler() } else { shell.pick(tool, in: interaction, canvas: canvas) }
        } label: {
            Image(systemName: tool.symbol)
                .themeText(theme.text(.body))
                .foregroundStyle(usable ? ink : theme.color(.textMuted, scheme))
                .frame(width: theme.space(.s6), height: theme.space(.s6))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background {
            if active { Capsule().fill(theme.color(.text, scheme)) }
        }
        .help(Text(LocalizedStringKey(tool.nameKey)) + Text(verbatim: tool.key.map { "  \($0)" } ?? ""))
        .accessibilityLabel(Text(LocalizedStringKey(tool.nameKey)))
        .simultaneousGesture(TapGesture(count: 2).onEnded { shell.inspectorVisible = true })
    }
}

extension ToolPointer {
    /// The system pointer for the tool. The arrow is the default; the eyedropper has none until it works.
    var style: PointerStyle? {
        switch self {
        case .arrow, .eyedropper: nil
        case .hand: .grabIdle
        case .crosshair: .rectSelection
        case .zoomIn: .zoomIn
        case .text: .horizontalText
        }
    }
}

/// The letter keys of the working tools. They act with focus on the canvas and no modifier. The lab key is in `LabKey`.
struct ToolKeys: ViewModifier {
    /// True while the canvas has the keyboard focus.
    var isFocused: Bool

    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas
    @FocusedValue(\.interaction) private var interaction

    private static let letters = CharacterSet(charactersIn: Tool.wired.subtracting([.lab]).compactMap(\.key).joined().lowercased())

    func body(content: Content) -> some View {
        content.onKeyPress(characters: Self.letters) { press in
            guard isFocused, press.modifiers.isEmpty, let shell, let interaction,
                  let tool = Tool.forKey(press.characters) else { return .ignored }
            shell.pick(tool, in: interaction, canvas: canvas)
            return .handled
        }
    }
}
