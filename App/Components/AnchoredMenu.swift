import AppKit
import Carbon.HIToolbox
import Design
import SwiftUI

struct AnchoredMenu: View {
    @Environment(\.appearance) private var appearance
    var width: Double?
    let entries: [MenuEntry]
    var dismiss: () -> Void = {}

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.contextMenu))
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                switch entry {
                case .row(let row): MenuRow(row: row)
                case .head(_, let label): head(label)
                case .separator: separator
                }
            }
        }
        .padding(CGFloat(Tokens.Spacing.step4))
        .frame(width: width.map { CGFloat($0) })
        .fixedSize(horizontal: width == nil, vertical: false)
        .background(shape.fill(appearance.color(\.menu)))
        .shadowLayers(shape)
        .eventMonitor([.leftMouseDown, .rightMouseDown, .keyDown]) { sample in
            if sample.event.type == .keyDown {
                guard sample.event.keyCode == UInt16(kVK_Escape) else { return false }
                dismiss()
                return true
            }
            if sample.local == nil { dismiss() }
            return false
        }
    }

    private func head(_ label: Text) -> some View {
        label
            .lineLimit(1)
            .font(.face(Tokens.TextSize.small))
            .foregroundStyle(appearance.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset))
            .padding(.bottom, CGFloat(Tokens.Spacing.step4))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Tokens.Size.chipHeight), alignment: .bottomLeading)
    }

    private var separator: some View {
        Rectangle()
            .fill(appearance.color(\.line))
            .frame(height: CGFloat(Tokens.Size.hairline))
            .padding(.vertical, CGFloat(Tokens.Spacing.step4))
            .padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset))
    }
}

struct MenuRow: View {
    @Environment(\.appearance) private var appearance
    let row: MenuItem
    @State private var hovering = false

    var body: some View {
        Button(action: row.action) {
            HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
                (row.check ?? Text(verbatim: ""))
                    .font(.face(Tokens.TextSize.small))
                    .frame(width: CGFloat(Tokens.Spacing.step12))
                row.label
                    .lineLimit(1)
                    .help(row.label)
                    .font(.face(Tokens.TextSize.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let meta = row.meta {
                    meta
                        .font(.face(Tokens.TextSize.small))
                        .foregroundStyle(appearance.color(\.inkTertiary))
                        .fixedSize()
                }
            }
            .foregroundStyle(appearance.color(row.danger ? \.signal : \.ink))
            .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
            .frame(height: CGFloat(Tokens.Size.menuRowHeight))
            .background(
                RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
                    .fill(hovering ? appearance.color(\.hover) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
