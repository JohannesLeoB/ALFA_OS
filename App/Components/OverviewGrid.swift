import Design
import Shell
import SwiftUI

enum OverviewMark {
    case text(String)
    case icon(Icon)
}

struct OverviewCommand: Identifiable {
    let id: String
    let help: String
    let icon: Icon
    let tone: KeyPath<Colors, ColorValue>
    let run: () -> Void
}

struct OverviewEntry: Identifiable {
    let id: String
    let mark: OverviewMark
    let title: Text
    let date: Text
    let unread: Bool
    let subject: String
    let preview: String
    let current: Bool
    var close: (() -> Void)?
    var commands: [OverviewCommand] = []
    let choose: () -> Void
}

struct OverviewGrid: View {
    let entries: [OverviewEntry]
    let size: OverviewSize
    let hot: String?
    var still = false
    let aim: (String?) -> Void
    var more: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(size.tileMinWidth)), spacing: CGFloat(Tokens.Spacing.step8), alignment: .top)],
                      spacing: CGFloat(Tokens.Spacing.step8)) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    OverviewTile(entry: entry, index: index, size: size, hot: hot == entry.id,
                                 dimmed: hot != nil && hot != entry.id, still: still, aim: aim)
                }
            }
            .padding(CGFloat(Tokens.Spacing.step8))
        }
        .loadsAhead { more?() }
    }
}
