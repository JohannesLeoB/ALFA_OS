import AppTheme
import SwiftUI
import Tokens
import CodePlayer

/// The controls of the CSS variables of the code: a slider for each number, a colour well for each colour.
struct LabControlsView: View {
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let controls = model.session.controls
        let props = model.session.props
        VStack(alignment: .leading, spacing: theme.space(.s2)) {
            Text(LocalizedStringKey("lab.controls"))
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            if controls.isEmpty && props.isEmpty {
                Text(LocalizedStringKey("lab.controls.empty"))
                    .themeText(theme.text(.caption))
                    .foregroundStyle(theme.color(.textMuted, scheme))
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: theme.space(.s4)) {
                        ForEach(controls) { control in
                            LabControlRow(control: control, model: model)
                        }
                        ForEach(props) { prop in
                            LabPropRow(prop: prop, model: model)
                        }
                    }
                    .padding(theme.space(.s2))
                }
            }
        }
        .padding(.horizontal, theme.space(.s3))
        .padding(.bottom, theme.space(.s2))
    }
}

/// One control: its name, the slider or colour well, and the value as CSS writes it.
struct LabControlRow: View {
    let control: LabControl
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            Text(verbatim: control.name)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            if let range = control.range {
                Slider(value: numberBinding, in: range, step: control.step)
            } else {
                ColorPicker(selection: colourBinding, supportsOpacity: false) {
                    Text(verbatim: control.value.css)
                }
            }
            Text(verbatim: control.value.css)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.text, scheme))
        }
        .frame(width: 200)
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: {
                if case .number(let value, _) = control.value { return value }
                return 0
            },
            set: { model.setNumber($0, for: control.name) }
        )
    }

    private var colourBinding: Binding<Color> {
        Binding(
            get: {
                let hex = control.value.pickerHex ?? ""
                return Color(RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0))
            },
            set: { model.setColour(LabControlRow.hex(of: $0), for: control.name) }
        )
    }

    /// The colour as a hex text in sRGB, as the colour well gives it.
    private static func hex(of color: Color) -> String {
        let resolved = color.resolve(in: EnvironmentValues())
        return RGB(r: Double(resolved.red), g: Double(resolved.green), b: Double(resolved.blue)).hex
    }
}
