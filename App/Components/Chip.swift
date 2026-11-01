import Design
import Shell
import SwiftUI

struct Chip<RemoveGlyph: View>: View {
    @Environment(\.appearance) private var appearance
    let name: String
    var detail: String?
    let removeKey: String
    let onRemove: () -> Void
    @ViewBuilder let removeGlyph: RemoveGlyph

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step4)) {
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.face(Tokens.TextSize.body))
                .foregroundStyle(appearance.color(\.ink))
            ChipRemove(titleKey: removeKey, action: onRemove) { removeGlyph }
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Size.chipHeight))
        .ring(Pill(), appearance.color(\.lineStrong))
        .help(Text(verbatim: detail ?? name))
    }
}

struct AttachmentChip<Glyph: View, RemoveGlyph: View>: View {
    @Environment(\.appearance) private var appearance
    let name: String
    var size: String?
    var detail: String?
    var inverted = false
    var removeKey: String?
    var onRemove: (() -> Void)?
    @ViewBuilder let glyph: Glyph
    @ViewBuilder let removeGlyph: RemoveGlyph

    var body: some View {
        let ink = InkSet.of(inverted)
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            glyph
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.middle)
            if let size {
                Text(verbatim: size).foregroundStyle(appearance.color(ink.tertiary))
            }
            if let removeKey, let onRemove {
                ChipRemove(titleKey: removeKey, action: onRemove) { removeGlyph }
            }
        }
        .font(.face(Tokens.TextSize.small))
        .foregroundStyle(appearance.color(ink.secondary))
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(onRemove == nil ? Tokens.Spacing.step8 : Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Size.chipHeight))
        .ring(Pill(), appearance.color(ink.line))
        .help(Text(verbatim: detail ?? name))
    }
}

extension AttachmentChip where RemoveGlyph == EmptyView {
    init(name: String, size: String? = nil, detail: String? = nil, inverted: Bool = false, @ViewBuilder glyph: () -> Glyph) {
        self.init(name: name, size: size, detail: detail, inverted: inverted, removeKey: nil, onRemove: nil, glyph: glyph) { EmptyView() }
    }
}

private struct ChipRemove<Glyph: View>: View {
    @Environment(\.appearance) private var appearance
    let titleKey: String
    let action: () -> Void
    @ViewBuilder let glyph: Glyph

    var body: some View {
        let side = CGFloat(Tokens.Spacing.step16)
        Button(action: action) {
            glyph
                .foregroundStyle(appearance.color(\.inkTertiary))
                .frame(width: side, height: side)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(appearance.text(titleKey))
        .accessibilityLabel(appearance.text(titleKey))
    }
}

struct ChipWrapLayout: Layout {
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let rows = arrange(subviews, width: limit ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: limit ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(item.size))
                x += item.size.width + gap
            }
        }
    }

    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: ideal.height)) : ideal
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [WrapRow] {
        var rows: [WrapRow] = []
        var current = WrapRow(y: 0)
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            let next = current.items.isEmpty ? size.width : current.width + gap + size.width
            if next > width && !current.items.isEmpty {
                rows.append(current)
                current = WrapRow(y: current.y + current.height + gap)
            }
            current.width = current.items.isEmpty ? size.width : current.width + gap + size.width
            current.height = max(current.height, size.height)
            current.items.append(WrapItem(index: index, size: size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

private struct WrapItem {
    let index: Int
    let size: CGSize
}

private struct WrapRow {
    let y: CGFloat
    var width: CGFloat = 0
    var height: CGFloat = 0
    var items: [WrapItem] = []
}

struct Disclosure<Content: View>: View {
    @Environment(\.appearance) private var appearance
    let open: Bool
    let help: String
    @ViewBuilder let content: Content
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                content
                Glyph.small(.chevron)
                    .foregroundStyle(appearance.color(\.inkTertiary))
                    .rotationEffect(.degrees(open ? SheetValues.halfTurn : 0))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Spacing.step28))
            .background(Capsule().fill(hovering ? appearance.color(\.hover) : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: Tokens.Scale.pressRow))
        .padding(.leading, -CGFloat(Tokens.Spacing.step8))
        .help(Text(verbatim: help))
        .onHover { hovering = $0 }
        .animation(appearance.ease(Tokens.Duration.chevron), value: open)
    }
}
