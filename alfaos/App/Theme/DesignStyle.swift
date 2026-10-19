import ShellCore
import SwiftUI

struct DesignStyle: Equatable {
    let dark: Bool

    private var colors: DesignColors { dark ? .dark : .light }

    func color(_ key: KeyPath<DesignColors, RGB>) -> Color {
        let value = colors[keyPath: key]
        return Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }
}

private struct DesignStyleKey: EnvironmentKey {
    static let defaultValue = DesignStyle(dark: false)
}

private struct LaneFillKey: EnvironmentKey {
    static let defaultValue = Color.white
}

enum CardSurface: Equatable {
    case flat
    case lacquer
}

private struct CardSurfaceKey: EnvironmentKey {
    static let defaultValue = CardSurface.flat
}

private struct NarrowCardKey: EnvironmentKey {
    static let defaultValue = false
}

private struct HairlineKey: EnvironmentKey {
    static let defaultValue = CGFloat(0)
}

extension EnvironmentValues {
    var cardSurface: CardSurface {
        get { self[CardSurfaceKey.self] }
        set { self[CardSurfaceKey.self] = newValue }
    }

    var narrowCard: Bool {
        get { self[NarrowCardKey.self] }
        set { self[NarrowCardKey.self] = newValue }
    }

    var hairline: CGFloat {
        get { self[HairlineKey.self] }
        set { self[HairlineKey.self] = newValue }
    }

    var design: DesignStyle {
        get { self[DesignStyleKey.self] }
        set { self[DesignStyleKey.self] = newValue }
    }

    var laneFill: Color {
        get { self[LaneFillKey.self] }
        set { self[LaneFillKey.self] = newValue }
    }
}

private struct DesignTextModifier: ViewModifier {
    @Environment(\.design) private var design
    let tone: KeyPath<DesignColors, RGB>
    let size: Double
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(Font(Typeface.font(size: size, weight: weight)))
            .foregroundStyle(design.color(tone))
    }
}

extension View {
    func designText(_ tone: KeyPath<DesignColors, RGB> = \.ink, size: Double = Design.TextSize.body, weight: Font.Weight = .regular) -> some View {
        modifier(DesignTextModifier(tone: tone, size: size, weight: weight))
    }
}

struct DesignRow<Content: View>: View {
    @Environment(\.design) private var design
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, CGFloat(Design.Spacing.step12))
                .padding(.vertical, CGFloat(Design.Spacing.step4))
                .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Size.rowHeight), alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(Design.Radius.row))
                        .fill(selected ? design.color(\.selection) : (hovering ? design.color(\.hover) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct DesignDot: View {
    @Environment(\.design) private var design
    let tone: KeyPath<DesignColors, RGB>

    var body: some View {
        Circle()
            .fill(design.color(tone))
            .frame(width: CGFloat(Design.Spacing.statusDot), height: CGFloat(Design.Spacing.statusDot))
    }
}
