import Design
import Mail
import Shell
import SwiftUI

struct LaneRow: View {
    @Environment(\.appearance) private var appearance
    let glyph: Icon
    let label: Text
    let selected: Bool
    var count: String?
    var countTone: KeyPath<Colors, ColorValue> = \.inkTertiary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step20)) {
                Mark(inverted: selected, tone: selected ? \.onInverse : \.inkTertiary) { Glyph(glyph) }
                label
                    .designText(selected ? \.onInverse : \.ink, size: Tokens.TextSize.body, weight: selected ? .medium : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let count {
                    Counter(value: count, tone: countTone)
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Size.rowHeight))
            .background(shape.fill(selected ? appearance.color(\.inverse) : Color.clear))
            .ring(shape, hovering && !selected ? appearance.color(\.lineStrong) : nil)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct LaneHead<Content: View>: View {
    @Environment(\.appearance) private var appearance
    var scrolled = false
    var lane = LaneKind.leading
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(lane.headGap)) { content }
            .padding(.leading, CGFloat(lane.headLeading))
            .padding(.trailing, CGFloat(lane.headTrailing))
            .frame(height: CGFloat(Tokens.Size.headerHeight))
            .frame(maxWidth: .infinity)
            .background(appearance.color(\.lane))
            .overlay(alignment: .bottom) {
                Rectangle().fill(scrolled ? appearance.color(\.line) : Color.clear).frame(height: CGFloat(Tokens.Size.hairline))
            }
            .animation(appearance.ease(scrolled ? Tokens.Duration.scrollLineIn : Tokens.Duration.scrollLineOut), value: scrolled)
    }
}

struct HeaderTitle: View {
    let text: Text

    var body: some View {
        text
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(text)
            .layoutPriority(1)
    }
}

struct Hairline: View {
    @Environment(\.appearance) private var appearance
    var tone: KeyPath<Colors, ColorValue> = \.line

    var body: some View {
        Rectangle().fill(appearance.color(tone)).frame(height: CGFloat(Tokens.Size.hairline))
    }
}

struct MessageRow<Mark: View, Content: View>: View {
    let fill: Color
    let ring: Color?
    let separated: Bool
    @ViewBuilder let mark: Mark
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
        HStack(alignment: .top, spacing: CGFloat(Tokens.Spacing.step20)) {
            mark
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.top, CGFloat(Tokens.Spacing.step4))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step12))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
        .background(shape.fill(fill))
        .ring(shape, ring)
        .overlay(alignment: .bottom) {
            if separated {
                Hairline()
                    .padding(.leading, CGFloat(Tokens.Spacing.step56))
                    .padding(.trailing, CGFloat(Tokens.Spacing.step8))
            }
        }
    }
}

enum MarkSize {
    case regular
    case small
}

enum MarkFill {
    case rest
    case filled
    case signal
}

struct Mark<Content: View>: View {
    @Environment(\.appearance) private var appearance
    var size = MarkSize.regular
    var fill = MarkFill.rest
    var inverted = false
    var tone: KeyPath<Colors, ColorValue>?
    @ViewBuilder let content: Content

    private var ink: InkSet { .of(inverted) }

    private var background: Color {
        switch fill {
        case .rest: size == .small ? appearance.color(\.lane) : Color.clear
        case .filled: appearance.color(ink.primary)
        case .signal: appearance.color(\.signal)
        }
    }

    private var foreground: Color {
        switch fill {
        case .rest: appearance.color(tone ?? ink.secondary)
        case .filled: appearance.color(inverted ? \.ink : \.lane)
        case .signal: appearance.color(\.onSignal)
        }
    }

    var body: some View {
        let side = CGFloat(size == .regular ? Tokens.Size.symbolSize : Tokens.Size.chipHeight)
        content
            .typeStyle(Tokens.TextStyle.mark)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .frame(width: side, height: side)
            .background(Circle().fill(background))
            .ring(Circle(), fill == .rest ? appearance.color(ink.line) : nil)
    }
}

struct Counter: View {
    @Environment(\.appearance) private var appearance
    let value: String
    var tone: KeyPath<Colors, ColorValue> = \.inkTertiary
    var ringTone: KeyPath<Colors, ColorValue>?

    var body: some View {
        let ringed = ringTone != nil
        let side = CGFloat(ringed ? Tokens.Size.chipHeight : Tokens.Spacing.step20)
        Text(verbatim: value)
            .typeStyle(Tokens.TextStyle.caption)
            .lineHeight(Tokens.LineHeight.counter * Tokens.TextStyle.caption.size, size: Tokens.TextStyle.caption.size)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(appearance.color(tone))
            .padding(.horizontal, CGFloat(ringed ? Tokens.Spacing.step8 : Tokens.Spacing.step4))
            .frame(minWidth: side, minHeight: side, maxHeight: side)
            .ring(Pill(), ringTone.map { appearance.color($0) })
    }
}

struct StripMarkItem: Identifiable {
    let id: String
    let face: StripFace
    let help: Text
    let selected: Bool
    let dot: Bool
    var accent = false
    let action: () -> Void
}

struct StripMarks: View {
    let items: [StripMarkItem]

    var body: some View {
        VStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            ForEach(items.filter { !$0.accent }) { item in
                StripMarkView(item: item)
            }
            Spacer(minLength: 0)
            ForEach(items.filter(\.accent)) { item in
                StripMarkView(item: item)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct StripMarkView: View {
    @Environment(\.appearance) private var appearance
    let item: StripMarkItem

    var body: some View {
        let side = CGFloat(Tokens.Size.symbolSize)
        let line = CGFloat(Tokens.Size.hairline)
        Button(action: item.action) {
            Group {
                switch item.face {
                case .glyph(let icon): Glyph(icon)
                case .text(let value): Text(verbatim: value).lineLimit(1)
                }
            }
            .designText(item.accent || item.selected ? \.lane : \.inkSecondary, size: Tokens.TextSize.small, weight: .medium)
            .frame(width: side, height: side)
            .background(Circle().fill(item.accent || item.selected ? appearance.color(\.ink) : Color.clear))
            .overlay(Circle().strokeBorder(item.accent || item.selected ? Color.clear : appearance.color(\.lineStrong), lineWidth: line))
            .overlay(alignment: .topTrailing) {
                if item.dot {
                    Circle().fill(appearance.color(\.ink))
                        .frame(width: CGFloat(Tokens.Spacing.statusDot), height: CGFloat(Tokens.Spacing.statusDot))
                        .background(Circle().fill(appearance.color(\.lane)).padding(-CGFloat(Tokens.Size.markSeparatorRing)))
                        .offset(x: line, y: -line)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.help)
        .accessibilityLabel(item.help)
    }
}

extension View {
    func loadsAhead(spacer: Double = 0, perform: @escaping () -> Void) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            ListWindowEngine.remaining(content: Double(geometry.contentSize.height), offset: Double(geometry.contentOffset.y),
                                       container: Double(geometry.containerSize.height), spacer: spacer) < SheetValues.listLoadAhead
        } action: { was, near in
            if !was, near { perform() }
        }
    }
}
