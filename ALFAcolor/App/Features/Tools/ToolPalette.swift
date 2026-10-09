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

    private func button(_ tool: Tool) -> some View {
        let active = interaction.tools.active == tool
        let tint: Color = active ? theme.color(.accent, scheme) : theme.color(.text, scheme)
        return Button {
            shell.pick(tool, in: interaction, canvas: canvas)
        } label: {
            Image(systemName: tool.symbol)
                .themeText(theme.text(.body))
                .foregroundStyle(tool.isWired ? tint : theme.color(.textMuted, scheme))
                .frame(width: theme.space(.s6), height: theme.space(.s6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if active { Circle().fill(theme.color(.accent, scheme).opacity(0.18)) }
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
