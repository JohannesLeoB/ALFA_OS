import Design
import SwiftUI

struct InputField<Trailing: View>: View {
    @Environment(\.appearance) private var appearance
    @Binding var text: String
    let placeholder: Text?
    let labelKey: String
    var secret = false
    var focus: FocusState<Bool>.Binding?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        FieldLayout {
            field
            trailing
        }
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(appearance.color(\.ink))
                .frame(height: CGFloat(Tokens.Size.hairline))
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = Group {
            if secret {
                SecureField(text: $text, prompt: placeholder) { appearance.text(labelKey) }
            } else {
                TextField(text: $text, prompt: placeholder) { appearance.text(labelKey) }
            }
        }
        .textFieldStyle(.plain)
        .font(.face(Tokens.TextSize.body))
        .foregroundStyle(appearance.color(\.ink))
        .autocorrectionDisabled()
        .accessibilityLabel(appearance.text(labelKey))
        if let focus {
            base.focused(focus)
        } else {
            base
        }
    }
}

private struct FieldLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let field = subviews.first else { return }
        let gap = CGFloat(Tokens.Spacing.step8)
        var width: CGFloat = 0
        if subviews.count > 1 {
            let trailing = subviews[1]
            width = min(trailing.sizeThatFits(.unspecified).width, bounds.width * SheetValues.fieldTrailingMaxShare)
            if width > 0 {
                trailing.place(at: CGPoint(x: bounds.maxX - width, y: bounds.midY), anchor: .leading,
                               proposal: ProposedViewSize(width: width, height: bounds.height))
            }
        }
        let rest = bounds.width - (width > 0 ? width + gap : 0)
        field.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: rest, height: bounds.height))
    }
}

extension InputField where Trailing == EmptyView {
    init(text: Binding<String>, placeholder: Text?, labelKey: String, secret: Bool = false, focus: FocusState<Bool>.Binding? = nil) {
        self.init(text: text, placeholder: placeholder, labelKey: labelKey, secret: secret, focus: focus) { EmptyView() }
    }
}

struct ToggleSwitch: View {
    @Environment(\.appearance) private var appearance
    @Binding var isOn: Bool
    let labelKey: String

    var body: some View {
        let height = Tokens.Spacing.step20
        let knob = Tokens.Spacing.step16
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: .topLeading) {
                Capsule().fill(isOn ? appearance.color(\.ink) : Color.clear)
                Circle()
                    .fill(appearance.color(isOn ? \.lane : \.inkTertiary))
                    .frame(width: CGFloat(knob), height: CGFloat(knob))
                    .offset(
                        x: CGFloat(isOn ? Tokens.Size.toggleKnobOffsetOn : Tokens.Size.toggleKnobOffsetOff),
                        y: CGFloat(Tokens.Spacing.step2)
                    )
            }
            .frame(width: CGFloat(Tokens.Spacing.step32), height: CGFloat(height))
            .ring(Pill(), isOn ? nil : appearance.color(\.lineStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.text(labelKey))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(appearance.ease(Tokens.Duration.toggle), value: isOn)
    }
}

struct SegmentOption<ID: Hashable>: Identifiable {
    let id: ID
    let label: Text
}

struct SegmentedControl<ID: Hashable>: View {
    @Environment(\.appearance) private var appearance
    let options: [SegmentOption<ID>]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let on = option.id == selection
                Button(action: { selection = option.id }) {
                    option.label
                        .lineLimit(1)
                        .typeStyle(Tokens.TextStyle.control)
                        .foregroundStyle(appearance.color(on ? \.onInverse : \.inkSecondary))
                        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
                        .frame(height: CGFloat(Tokens.Spacing.step24))
                        .background(Capsule().fill(on ? appearance.color(\.inverse) : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(CGFloat(Tokens.Spacing.step2))
        .ring(Pill(), appearance.color(\.lineStrong))
    }
}
