import ShellCore
import SwiftUI

struct Head<Content: View>: View {
    var stack = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(stack ? Design.Size.headGapStack : Design.Size.headGapList)) { content }
            .padding(.leading, CGFloat(stack ? Design.Size.headPadLeftStack : Design.Size.headPadLeftList))
            .padding(.trailing, CGFloat(Design.Size.headPadRight))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Line() }
    }
}

struct Line: View {
    @Environment(\.style) private var style

    var body: some View {
        Rectangle().fill(style.color(\.line)).frame(height: CGFloat(Design.Size.hairline))
    }
}

struct HeadTitle: View {
    @Environment(\.style) private var style
    let key: String
    var detail: String?

    var body: some View {
        say(key)
            .font(style.font(Design.TextSize.body, weight: Design.Weight.medium))
            .foregroundStyle(style.color(\.ink))
            .lineLimit(1)
            .fixedSize()
        Text(verbatim: detail ?? "")
            .font(style.font(Design.TextSize.small))
            .foregroundStyle(style.color(\.inkTertiary))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Glyph: View {
    let name: String
    var size = Proto.glyph

    var body: some View {
        Image(systemName: name).font(.system(size: CGFloat(size)))
    }
}

struct SymbolButton: View {
    @Environment(\.style) private var style
    let symbol: String
    let tip: String
    var on = false
    var ring = true
    var enabled = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Glyph(name: symbol)
            .foregroundStyle(style.color(on ? \.lane : (hovering ? \.ink : \.inkSecondary)))
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .background(Circle().fill(on ? style.color(\.ink) : (hovering && !ring ? style.color(\.hover) : Color.clear)))
            .overlay(Circle().strokeBorder(ring && !on ? style.color(\.lineStrong) : Color.clear, lineWidth: CGFloat(Design.Size.hairline)))
            .opacity(enabled ? 1 : Proto.disabled)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .onTapGesture { if enabled { action() } }
            .help(tip)
    }
}

struct Mark: View {
    @Environment(\.style) private var style
    let symbol: String
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var on = false

    var body: some View {
        Glyph(name: symbol)
            .foregroundStyle(style.color(on ? \.lane : tone))
            .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
            .overlay(Circle().strokeBorder(on ? style.color(\.onInverseLine) : style.color(\.lineStrong),
                                           lineWidth: CGFloat(Design.Size.hairline)))
    }
}

struct SectionHead: View {
    @Environment(\.style) private var style
    let key: String
    var meta = ""
    var metaTone: KeyPath<DesignColors, RGB> = \.inkTertiary

    var body: some View {
        HStack(alignment: .bottom, spacing: CGFloat(Design.Spacing.step8)) {
            say(key).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            Text(verbatim: meta).foregroundStyle(style.color(metaTone)).monospacedDigit()
        }
        .font(style.font(Design.TextSize.small))
        .foregroundStyle(style.color(\.inkTertiary))
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .padding(.bottom, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Spacing.step32), alignment: .bottom)
    }
}

struct Note: View {
    @Environment(\.style) private var style
    let text: String
    var tone: KeyPath<DesignColors, RGB> = \.inkTertiary

    var body: some View {
        Text(verbatim: text)
            .font(style.font(Design.TextSize.small))
            .lineSpacing(CGFloat(Design.LineHeight.small - Design.TextSize.small))
            .foregroundStyle(style.color(tone))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.top, CGFloat(Design.Spacing.step4))
            .padding(.bottom, CGFloat(Design.Spacing.step8))
    }
}

struct ListRow: View {
    @Environment(\.style) private var style
    let name: String
    let symbol: String
    var meta = ""
    var selected = false
    var bold = false
    var dim = false
    var tone: KeyPath<DesignColors, RGB> = \.ink
    var symbolTone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var metaTone: KeyPath<DesignColors, RGB> = \.inkTertiary
    var end: (symbol: String, tip: String, action: () -> Void)?
    var action: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            Mark(symbol: symbol, tone: symbolTone, on: selected)
            Text(verbatim: name)
                .font(style.font(Design.TextSize.body, weight: selected || bold ? Design.Weight.medium : Design.Weight.regular))
                .foregroundStyle(style.color(selected ? \.lane : tone))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: meta)
                .font(style.font(Design.TextSize.small))
                .monospacedDigit()
                .foregroundStyle(style.color(selected ? \.lane : metaTone))
                .lineLimit(1)
            if let end {
                SymbolButton(symbol: end.symbol, tip: end.tip, ring: false, action: end.action)
            }
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(end == nil ? Design.Spacing.step8 : Design.Spacing.step4))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .background(shape.fill(selected ? style.color(\.ink) : Color.clear))
        .overlay(shape.strokeBorder(hovering && !selected ? style.color(\.lineStrong) : Color.clear, lineWidth: CGFloat(Design.Size.hairline)))
        .opacity(dim ? Proto.hidden : 1)
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture { action?() }
        .animation(style.ease(Design.Duration.hover), value: selected)
    }
}

struct FieldRow: View {
    @Environment(\.style) private var style
    let label: String
    @Binding var value: String
    @State private var hovering = false

    var body: some View {
        let empty = value.trimmingCharacters(in: .whitespaces).isEmpty
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            Text(verbatim: label)
                .font(style.font(Design.TextSize.small))
                .foregroundStyle(style.color(empty ? \.signal : \.inkTertiary))
                .lineLimit(1)
                .frame(width: CGFloat(Design.Size.fieldLabelWidth), alignment: .leading)
            TextField(text: $value, prompt: empty ? say("draws.field.missing") : nil) { EmptyView() }
                .textFieldStyle(.plain)
                .font(style.font())
                .foregroundStyle(style.color(\.ink))
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
            .strokeBorder(hovering ? style.color(\.lineStrong) : Color.clear, lineWidth: CGFloat(Design.Size.hairline)))
        .onHover { hovering = $0 }
    }
}

struct Labeled<Content: View>: View {
    @Environment(\.style) private var style
    let key: String
    var enabled = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            say(key)
                .font(style.font())
                .foregroundStyle(style.color(\.inkSecondary))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .opacity(enabled ? 1 : Proto.disabled)
        .allowsHitTesting(enabled)
    }
}

struct Segments<ID: Hashable>: View {
    @Environment(\.style) private var style
    let options: [(id: ID, key: String)]
    @Binding var selection: ID
    var fill = false
    var literal = false

    var body: some View {
        let inset = CGFloat(Design.Spacing.step28 - Design.Size.chipHeight) / 2
        HStack(spacing: 0) {
            ForEach(options, id: \.id) { option in
                let on = option.id == selection
                (literal ? Text(verbatim: option.key) : say(option.key))
                    .lineLimit(1)
                    .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
                    .foregroundStyle(style.color(on ? \.onInverse : \.inkSecondary))
                    .padding(.horizontal, CGFloat(Design.Spacing.step8))
                    .frame(minWidth: CGFloat(Design.Size.chipHeight), maxWidth: fill ? .infinity : nil)
                    .frame(height: CGFloat(Design.Size.chipHeight))
                    .background(Capsule().fill(on ? style.color(\.inverse) : Color.clear))
                    .contentShape(Capsule())
                    .onTapGesture { selection = option.id }
                    .animation(style.ease(Design.Duration.hover), value: on)
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
    var tone: KeyPath<DesignColors, RGB> = \.ink
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        say(key)
            .lineLimit(1)
            .fixedSize()
            .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(style.color(accent ? \.onInverse : tone))
            .padding(.horizontal, CGFloat(Design.Spacing.step12))
            .frame(height: CGFloat(Design.Spacing.step28))
            .background(Capsule().fill(accent ? style.color(\.inverse) : (hovering ? style.color(\.hover) : Color.clear)))
            .overlay(Capsule().strokeBorder(accent ? Color.clear : style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
    }
}

struct Choice<Items: View>: View {
    @Environment(\.style) private var style
    let value: String
    @ViewBuilder let items: Items

    var body: some View {
        Menu {
            items
        } label: {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                Text(verbatim: value).lineLimit(1)
                Glyph(name: "chevron.down", size: Proto.chevron)
            }
            .font(style.font(Design.TextSize.small, weight: Design.Weight.medium))
            .foregroundStyle(style.color(\.ink))
            .padding(.leading, CGFloat(Design.Spacing.step12))
            .padding(.trailing, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Spacing.step28))
            .overlay(Capsule().strokeBorder(style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct Switch: View {
    @Environment(\.style) private var style
    @Binding var on: Bool

    var body: some View {
        let height = Design.Spacing.step20
        let knob = Design.Spacing.step16
        ZStack(alignment: .topLeading) {
            Capsule().fill(style.color(on ? \.ink : \.lineStrong))
            Circle()
                .fill(style.color(\.lane))
                .frame(width: CGFloat(knob), height: CGFloat(knob))
                .shadowed(style, style.shadow(\.knob), Circle())
                .offset(x: CGFloat(on ? Design.Size.toggleKnobOffsetOn : Design.Size.toggleKnobOffsetOff),
                        y: CGFloat(height - knob) / 2)
        }
        .frame(width: CGFloat(Design.Spacing.step32), height: CGFloat(height))
        .animation(style.ease(Design.Duration.toggle), value: on)
        .contentShape(Capsule())
        .onTapGesture { on.toggle() }
    }
}

struct SliderRow: View {
    @Environment(\.style) private var style
    let key: String
    let dial: Dial
    @Binding var value: Double
    let text: String
    var enabled = true

    var body: some View {
        VStack(spacing: CGFloat(Design.Spacing.step4)) {
            HStack(spacing: CGFloat(Design.Spacing.step12)) {
                say(key).font(style.font()).foregroundStyle(style.color(\.inkSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: text).font(style.font(Design.TextSize.small)).monospacedDigit().foregroundStyle(style.color(\.ink))
            }
            GeometryReader { proxy in
                let w = Double(proxy.size.width), knob = Design.Spacing.step16
                let x = dial.share(value) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(style.color(\.lineStrong)).frame(height: CGFloat(Design.Radius.stroke))
                    Capsule().fill(style.color(\.ink)).frame(width: CGFloat(x), height: CGFloat(Design.Radius.stroke))
                    Circle().fill(style.color(\.lane))
                        .frame(width: CGFloat(knob), height: CGFloat(knob))
                        .overlay(Circle().strokeBorder(style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
                        .shadowed(style, style.shadow(\.knob), Circle())
                        .offset(x: CGFloat(x - knob / 2))
                }
                .frame(height: CGFloat(Design.Spacing.step20))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let share = min(1, max(0, Double(drag.location.x) / max(1, w)))
                    value = dial.clamp(dial.low + share * (dial.high - dial.low))
                })
            }
            .frame(height: CGFloat(Design.Spacing.step20))
        }
        .padding(.horizontal, CGFloat(Design.Spacing.step8))
        .padding(.top, CGFloat(Design.Spacing.step8))
        .padding(.bottom, CGFloat(Design.Spacing.step4))
        .opacity(enabled ? 1 : Proto.disabled)
        .allowsHitTesting(enabled)
    }
}

struct Swatches: View {
    @Environment(\.style) private var style
    let key: String
    let colors: [String]
    let selected: String?
    let choose: (String) -> Void

    var body: some View {
        Labeled(key: key) {
            HStack(spacing: CGFloat(Design.Spacing.step8)) {
                ForEach(colors, id: \.self) { hex in
                    let on = hex == selected
                    Circle()
                        .fill(Paint.color(hex))
                        .frame(width: CGFloat(Design.Spacing.step20), height: CGFloat(Design.Spacing.step20))
                        .overlay(Circle().strokeBorder(style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
                        .padding(CGFloat(on ? Design.Size.selectionRingWidth : 0))
                        .overlay(Circle().strokeBorder(on ? style.color(\.ink) : Color.clear, lineWidth: CGFloat(Design.Size.hairline)))
                        .padding(CGFloat(on ? 0 : Design.Size.selectionRingWidth))
                        .contentShape(Circle())
                        .onTapGesture { choose(hex) }
                }
            }
        }
    }
}

struct Compose: View {
    @Environment(\.style) private var style
    let key: String
    let symbol: String
    var extra = ""
    var inverse = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
        HStack(spacing: CGFloat(Design.Spacing.step12)) {
            Glyph(name: symbol)
                .frame(width: CGFloat(Design.Size.symbolSize), height: CGFloat(Design.Size.symbolSize))
                .overlay(Circle().strokeBorder(style.color(inverse ? \.onInverseLine : \.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
            Text(verbatim: word(key) + extra).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(style.font())
        .foregroundStyle(style.color(inverse ? \.onInverse : \.ink))
        .padding(.leading, CGFloat(Design.Spacing.step4))
        .padding(.trailing, CGFloat(Design.Spacing.step12))
        .frame(height: CGFloat(Design.Size.rowHeight))
        .background(shape.fill(inverse ? style.color(\.inverse) : Color.clear))
        .overlay(shape.strokeBorder(inverse ? Color.clear : style.color(\.lineStrong), lineWidth: CGFloat(Design.Size.hairline)))
        .opacity(hovering ? Proto.pressed : 1)
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
        .padding(CGFloat(Design.Spacing.step8))
    }
}

enum Paint {
    static func color(_ hex: String) -> Color {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return .clear }
        return Color(.sRGB, red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255,
                     blue: Double(v & 0xff) / 255, opacity: 1)
    }
}
