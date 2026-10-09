import SwiftUI
import AppTheme
import ALFAcolorCore
import BoardModel

/// The options of the active tool, at the top of the inspector. The selection tool has none.
/// Each option is a setting of the window or of the tool state; none of them changes the document.
struct ToolOptionsSection: View {
    var interaction: CanvasInteraction
    @Binding var unit: LengthUnit

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    /// The text styles that a text can take with the text tool. The names are keys of the string catalog.
    private static let textStyles = ["heading", "body", "caption"]

    var body: some View {
        switch interaction.tools.active {
        case .select, .lab:
            EmptyView()
        case .measure:
            Section(LocalizedStringKey(Tool.measure.nameKey)) {
                Picker("inspector.unit", selection: $unit) {
                    ForEach(LengthUnit.allCases, id: \.self) { choice in
                        Text(LocalizedStringKey(choice.symbolKey)).tag(choice)
                    }
                }
            }
        case .frame:
            Section(LocalizedStringKey(Tool.frame.nameKey)) {
                Picker("inspector.frame.device", selection: deviceBinding) {
                    ForEach(DeviceChoice.all) { choice in
                        Text(LocalizedStringKey(choice.nameKey)).tag(choice.id)
                    }
                }
            }
        case .shape:
            Section(LocalizedStringKey(Tool.shape.nameKey)) {
                Picker("tool.option.shape", selection: shapeBinding) {
                    ForEach(ShapeKind.allCases, id: \.self) { kind in
                        Text(LocalizedStringKey("tool.option.shape.\(kind.rawValue)")).tag(kind)
                    }
                }
            }
        case .text:
            Section(LocalizedStringKey(Tool.text.nameKey)) {
                Picker("tool.option.textStyle", selection: textStyleBinding) {
                    ForEach(Self.textStyles, id: \.self) { style in
                        Text(LocalizedStringKey("tool.option.text.\(style)")).tag(style)
                    }
                }
            }
        case .directSelect, .eyedropper, .comment, .hand, .zoom:
            Section(LocalizedStringKey(interaction.tools.active.nameKey)) {
                // Tools without an option say what they do; the help text carries the key of the tool.
                Text(LocalizedStringKey(interaction.tools.active.helpKey))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            }
        }
    }

    private var deviceBinding: Binding<String> {
        Binding(get: { interaction.tools.options.frameDeviceID },
                set: { interaction.tools.options.frameDeviceID = $0 })
    }

    private var shapeBinding: Binding<ShapeKind> {
        Binding(get: { interaction.tools.options.shapeKind },
                set: { interaction.tools.options.shapeKind = $0 })
    }

    private var textStyleBinding: Binding<String> {
        Binding(get: { interaction.tools.options.textStyle },
                set: { interaction.tools.options.textStyle = $0 })
    }
}
