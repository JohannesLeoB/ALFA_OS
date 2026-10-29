import Design
import Shell
import SwiftUI

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
