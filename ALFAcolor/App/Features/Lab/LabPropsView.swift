import AppTheme
import Renderers
import SwiftUI

/// One property of the component as a control: a slider for a number, segments for a choice, a field for a text
/// and a switch for a flag. The name is the name in the code, so it is shown as it is.
struct LabPropRow: View {
    let prop: LabProp
    let model: LabModel

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.s1)) {
            Text(verbatim: prop.name)
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.textMuted, scheme))
            control
        }
        .frame(width: LabPropsLayout.width, alignment: .leading)
    }

    @ViewBuilder
    private var control: some View {
        switch prop.kind {
        case .number(let range, let step):
            Slider(value: numberBinding, in: range, step: step)
            Text(verbatim: numberBinding.wrappedValue.formatted(.number.precision(.fractionLength(0...2))))
                .themeText(theme.text(.caption))
                .foregroundStyle(theme.color(.text, scheme))
        case .choice(let options):
            Picker(selection: textBinding) {
                ForEach(options, id: \.self) { option in
                    Text(verbatim: option).tag(option)
                }
            } label: {
                Text(verbatim: prop.name)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        case .text:
            TextField(text: textBinding) {
                Text(verbatim: prop.name)
            }
            .textFieldStyle(.roundedBorder)
        case .flag:
            Toggle(isOn: flagBinding) {
                Text(verbatim: prop.name)
            }
            .toggleStyle(.switch)
        }
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: {
                if case .number(let value) = prop.value { return value }
                return 0
            },
            set: { model.setProp(.number($0), for: prop.name) }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                if case .text(let value) = prop.value { return value }
                return ""
            },
            set: { model.setProp(.text($0), for: prop.name) }
        )
    }

    private var flagBinding: Binding<Bool> {
        Binding(
            get: {
                if case .flag(let value) = prop.value { return value }
                return false
            },
            set: { model.setProp(.flag($0), for: prop.name) }
        )
    }
}

/// The width of a property control in the row of controls.
enum LabPropsLayout {
    static let width: CGFloat = 200
}
