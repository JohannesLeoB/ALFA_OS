import ShellCore
import SwiftUI

struct Head<Content: View>: View {
    @Environment(\.style) private var style
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(Design.Size.headGapList)) { content }
            .padding(.leading, CGFloat(Design.Size.headPadLeftList))
            .padding(.trailing, CGFloat(Design.Size.headPadRight))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .frame(maxWidth: .infinity)
    }
}

struct HeadTitle: View {
    @Environment(\.style) private var style
    let key: String

    var body: some View {
        say(key)
            .font(style.font(Design.TextSize.body, weight: Design.Weight.medium))
            .foregroundStyle(style.color(\.ink))
            .lineLimit(1)
            .fixedSize()
    }
}

struct Caption: View {
    @Environment(\.style) private var style
    let key: String

    var body: some View {
        say(key)
            .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(style.color(\.inkTertiary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.menuRowHeight))
    }
}

struct Row: View {
    @Environment(\.style) private var style
    let label: Text
    var detail: String?
    var detailTone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var selected = false
    var action: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            label
                .font(style.font(Design.TextSize.body, weight: selected ? Design.Weight.medium : Design.Weight.regular))
                .foregroundStyle(style.color(selected ? \.lane : \.ink))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let detail {
                Text(verbatim: detail)
                    .font(style.font(Design.TextSize.small))
                    .monospacedDigit()
                    .foregroundStyle(style.color(selected ? \.lane : detailTone))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .background(shape.fill(selected ? style.color(\.ink) : Color.clear))
        .overlay(shape.strokeBorder(hovering && action != nil && !selected ? style.color(\.lineStrong) : Color.clear,
                                    lineWidth: CGFloat(Design.Size.hairline)))
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture { action?() }
    }
}

struct Segments<ID: Hashable>: View {
    @Environment(\.style) private var style
    let options: [(id: ID, key: String)]
    @Binding var selection: ID

    var body: some View {
        let inset = CGFloat(Design.Spacing.step28 - Design.Size.chipHeight) / 2
        HStack(spacing: 0) {
            ForEach(options, id: \.id) { option in
                let on = option.id == selection
                say(option.key)
                    .lineLimit(1)
                    .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
                    .foregroundStyle(style.color(on ? \.onInverse : \.inkSecondary))
                    .padding(.horizontal, CGFloat(Design.Spacing.step8))
                    .frame(height: CGFloat(Design.Size.chipHeight))
                    .background(Capsule().fill(on ? style.color(\.inverse) : Color.clear))
                    .contentShape(Capsule())
                    .onTapGesture { selection = option.id }
            }
        }
        .padding(inset)
        .overlay(Capsule().strokeBorder(style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
    }
}

struct Pill: View {
    @Environment(\.style) private var style
    let key: String
    var accent = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        say(key)
            .lineLimit(1)
            .fixedSize()
            .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(style.color(accent ? \.onInverse : \.ink))
            .padding(.horizontal, CGFloat(Design.Spacing.step12))
            .frame(height: CGFloat(Design.Spacing.step28))
            .background(Capsule().fill(accent ? style.color(\.inverse) : (hovering ? style.color(\.hover) : Color.clear)))
            .overlay(Capsule().strokeBorder(accent ? Color.clear : style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
    }
}

struct Switch: View {
    @Environment(\.style) private var style
    @Binding var on: Bool

    var body: some View {
        let height = Design.Spacing.step20
        let knob = Design.Spacing.step16
        ZStack(alignment: .topLeading) {
            Capsule().fill(on ? style.color(\.ink) : Color.clear)
            Circle()
                .fill(style.color(on ? \.lane : \.inkTertiary))
                .frame(width: CGFloat(knob), height: CGFloat(knob))
                .offset(x: CGFloat(on ? Design.Size.toggleKnobOffsetOn : Design.Size.toggleKnobOffsetOff),
                        y: CGFloat(height - knob) / 2)
        }
        .frame(width: CGFloat(Design.Spacing.step32), height: CGFloat(height))
        .overlay(Capsule().strokeBorder(on ? Color.clear : style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
        .animation(style.ease(Design.Duration.toggle), value: on)
        .contentShape(Capsule())
        .onTapGesture { on.toggle() }
    }
}
