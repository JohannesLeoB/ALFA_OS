import ShellCore
import SwiftUI

struct MenuItem: Identifiable {
    let id: String
    let label: Text
    var meta: Text?
    var check: Text?
    var danger = false
    let action: () -> Void
}

enum MenuEntry: Identifiable {
    case row(MenuItem)
    case head(id: String, label: Text)
    case separator(id: String)

    var id: String {
        switch self {
        case .row(let row): row.id
        case .head(let id, _): id
        case .separator(let id): id
        }
    }
}

struct AnchoredMenu: View {
    @Environment(\.design) private var design
    var width = Design.Size.menuWidthRow
    let entries: [MenuEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                switch entry {
                case .row(let row): AnchoredMenuRow(row: row)
                case .head(_, let label): head(label)
                case .separator: separator
                }
            }
        }
        .padding(CGFloat(Design.Spacing.step4))
        .frame(width: CGFloat(width))
        .background(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu)).fill(design.color(\.menu)))
        .floatingShadow(RoundedRectangle(cornerRadius: CGFloat(Design.Radius.contextMenu)))
    }

    private func head(_ label: Text) -> some View {
        label
            .lineLimit(1)
            .font(.system(size: CGFloat(Design.TextSize.small)))
            .foregroundStyle(design.color(\.inkTertiary))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .padding(.bottom, CGFloat(Design.Spacing.step4))
            .frame(maxWidth: .infinity, minHeight: CGFloat(Design.Size.chipHeight), alignment: .bottomLeading)
    }

    private var separator: some View {
        Rectangle()
            .fill(design.color(\.line))
            .frame(height: CGFloat(Design.Size.hairline))
            .padding(.vertical, CGFloat(Design.Spacing.step4))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
    }
}

private struct AnchoredMenuRow: View {
    @Environment(\.design) private var design
    let row: MenuItem
    @State private var hovering = false

    var body: some View {
        Button(action: row.action) {
            HStack(spacing: CGFloat(Design.Size.menuRowGap)) {
                (row.check ?? Text(verbatim: ""))
                    .font(.system(size: CGFloat(Design.TextSize.small)))
                    .frame(width: CGFloat(Design.Spacing.step12))
                row.label
                    .lineLimit(1)
                    .font(.system(size: CGFloat(Design.TextSize.body)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let meta = row.meta {
                    meta
                        .font(.system(size: CGFloat(Design.TextSize.small)))
                        .foregroundStyle(design.color(\.inkTertiary))
                }
            }
            .foregroundStyle(design.color(row.danger ? \.signal : \.ink))
            .padding(.horizontal, CGFloat(Design.Spacing.step8))
            .frame(height: CGFloat(Design.Size.menuRowHeight))
            .background(
                RoundedRectangle(cornerRadius: CGFloat(Design.Radius.notice))
                    .fill(hovering ? design.color(\.hover) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
