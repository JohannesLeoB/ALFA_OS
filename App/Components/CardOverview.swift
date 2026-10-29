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

struct CardOverview<Lead: View>: View {
    @Environment(\.appearance) private var appearance
    let entries: [OverviewEntry]
    let size: OverviewSize
    let resize: (OverviewSize) -> Void
    let hot: String?
    let aim: (String?) -> Void
    @ViewBuilder let lead: Lead

    private var sizes: [SegmentOption<OverviewSize>] {
        [SegmentOption(id: .small, label: appearance.text("overview.small")),
         SegmentOption(id: .medium, label: appearance.text("overview.medium")),
         SegmentOption(id: .large, label: appearance.text("overview.large"))]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                lead
                Spacer(minLength: 0)
                SegmentedControl(options: sizes, selection: Binding(get: { size }, set: { resize($0) }))
            }
            .padding(.horizontal, CGFloat(Tokens.Spacing.step8))
            .frame(height: CGFloat(Tokens.Size.headerHeight))
            .overlay(alignment: .bottom) { Hairline() }
            OverviewGrid(entries: entries, size: size, hot: hot, aim: aim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.color(\.lane))
    }
}
