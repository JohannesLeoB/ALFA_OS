import ShellCore
import SwiftUI

struct Chip<RemoveGlyph: View>: View {
    @Environment(\.design) private var design
    let name: String
    var detail: String?
    let removeKey: String
    let onRemove: () -> Void
    @ViewBuilder let removeGlyph: RemoveGlyph

    var body: some View {
        HStack(spacing: CGFloat(Design.Spacing.step4)) {
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.face(Design.TextSize.body))
                .foregroundStyle(design.color(\.ink))
            ChipRemove(titleKey: removeKey, action: onRemove) { removeGlyph }
        }
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(Design.Spacing.step4))
        .frame(height: CGFloat(Design.Size.chipHeight))
        .ring(Capsule(), design.color(\.lineStrong))
        .help(Text(verbatim: detail ?? name))
    }
}

struct AttachmentChip<Glyph: View, RemoveGlyph: View>: View {
    @Environment(\.design) private var design
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
        HStack(spacing: CGFloat(Design.Spacing.step8)) {
            glyph
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.tail)
            if let size {
                Text(verbatim: size).foregroundStyle(design.color(ink.tertiary))
            }
            if let removeKey, let onRemove {
                ChipRemove(titleKey: removeKey, action: onRemove) { removeGlyph }
            }
        }
        .font(.face(Design.TextSize.small))
        .foregroundStyle(design.color(ink.secondary))
        .padding(.leading, CGFloat(Design.Spacing.step8))
        .padding(.trailing, CGFloat(onRemove == nil ? Design.Spacing.step8 : Design.Spacing.step4))
        .frame(height: CGFloat(Design.Size.chipHeight))
        .ring(Capsule(), design.color(ink.line))
        .help(Text(verbatim: detail ?? name))
    }
}

extension AttachmentChip where RemoveGlyph == EmptyView {
    init(name: String, size: String? = nil, detail: String? = nil, inverted: Bool = false, @ViewBuilder glyph: () -> Glyph) {
        self.init(name: name, size: size, detail: detail, inverted: inverted, removeKey: nil, onRemove: nil, glyph: glyph) { EmptyView() }
    }
}

private struct ChipRemove<Glyph: View>: View {
    @Environment(\.design) private var design
    let titleKey: String
    let action: () -> Void
    @ViewBuilder let glyph: Glyph

    var body: some View {
        let side = CGFloat(Design.Spacing.step16)
        Button(action: action) {
            glyph
                .foregroundStyle(design.color(\.inkTertiary))
                .frame(width: side, height: side)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(word(titleKey))
        .accessibilityLabel(word(titleKey))
    }
}
