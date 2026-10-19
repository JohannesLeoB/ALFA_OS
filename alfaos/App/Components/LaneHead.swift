import ShellCore
import SwiftUI

struct LaneHead<Content: View>: View {
    @Environment(\.design) private var design
    @Environment(\.laneFill) private var laneFill
    @Environment(\.hairline) private var hairline
    @Environment(\.accessibilityReduceMotion) private var reduced
    var scrolled = false
    var lane = Lane.leading
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(lane.headGap)) { content }
            .padding(.leading, CGFloat(lane.headLeading))
            .padding(.trailing, CGFloat(lane.headTrailing))
            .frame(height: CGFloat(Design.Size.headerHeight))
            .frame(maxWidth: .infinity)
            .background(laneFill)
            .overlay(alignment: .bottom) {
                Rectangle().fill(scrolled ? design.color(\.line) : Color.clear).frame(height: hairline)
            }
            .animation(ComponentMotion(reduced: reduced).curve(Design.Duration.hover), value: scrolled)
    }
}

struct HeaderTitle: View {
    let text: Text

    var body: some View {
        text
            .designText(\.ink, size: Design.TextSize.body, weight: .medium)
            .lineLimit(1)
            .fixedSize()
    }
}

struct Hairline: View {
    @Environment(\.design) private var design
    @Environment(\.hairline) private var hairline
    var tone: KeyPath<DesignColors, RGB> = \.line

    var body: some View {
        Rectangle().fill(design.color(tone)).frame(height: hairline)
    }
}
