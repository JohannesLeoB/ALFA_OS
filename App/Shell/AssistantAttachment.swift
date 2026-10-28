import Design
import SwiftUI

struct AssistantAttachment: View {
    @Environment(\.appearance) private var appearance
    let name: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            Glyph(.doc)
                .accessibilityHidden(true)
            Text(verbatim: name)
                .lineLimit(1)
                .truncationMode(.tail)
            if let onRemove {
                SymbolButton(help: appearance.string("shell.chipRemove.assistant.tooltip"), glyph: .close, side: Tokens.Spacing.step20,
                             glyphSize: SheetValues.smallIcon, tone: nil, hoverTone: nil, ringed: false, hover: .fill, hoverFill: \.inverseHot,
                             pressed: false, action: onRemove)
            }
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(onRemove == nil ? Tokens.Spacing.step12 : Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Spacing.step28))
        .background(Capsule().fill(appearance.color(\.inverseField)))
        .help(Text(verbatim: name))
    }
}
