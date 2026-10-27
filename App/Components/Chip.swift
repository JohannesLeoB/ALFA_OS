import Design
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
                .truncationMode(.tail)
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
