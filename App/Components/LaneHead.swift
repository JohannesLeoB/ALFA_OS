import Design
import Shell
import SwiftUI

struct LaneHead<Content: View>: View {
    @Environment(\.appearance) private var appearance
    var scrolled = false
    var lane = LaneKind.leading
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: CGFloat(lane.headGap)) { content }
            .padding(.leading, CGFloat(lane.headLeading))
            .padding(.trailing, CGFloat(lane.headTrailing))
            .frame(height: CGFloat(Tokens.Size.headerHeight))
            .frame(maxWidth: .infinity)
            .background(appearance.color(\.lane))
            .overlay(alignment: .bottom) {
                Rectangle().fill(scrolled ? appearance.color(\.line) : Color.clear).frame(height: CGFloat(Tokens.Size.hairline))
            }
            .animation(appearance.ease(scrolled ? Tokens.Duration.scrollLineIn : Tokens.Duration.scrollLineOut), value: scrolled)
    }
}

struct HeaderTitle: View {
    let text: Text

    var body: some View {
        text
            .designText(\.ink, size: Tokens.TextSize.body, weight: .medium)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(text)
            .layoutPriority(1)
    }
}

struct Hairline: View {
    @Environment(\.appearance) private var appearance
    var tone: KeyPath<Colors, ColorValue> = \.line

    var body: some View {
        Rectangle().fill(appearance.color(tone)).frame(height: CGFloat(Tokens.Size.hairline))
    }
}
