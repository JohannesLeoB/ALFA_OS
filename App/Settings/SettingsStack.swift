import Design
import Hub
import Shell
import SwiftUI

struct SettingsStack: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var disconnecting: String?

    private var state: SettingsState { context.state }

    var body: some View {
        let readings = context.readings
        GeometryReader { proxy in
            VStack(spacing: 0) {
                SettingsCommandHead(context: context, readings: readings, width: proxy.size.width, disconnecting: $disconnecting)
                if let front = state.front {
                    ScrollView {
                        SettingsDetail(context: context, id: front, disconnecting: disconnecting == front, endDisconnect: { disconnecting = nil })
                            .padding(.top, CGFloat(Tokens.Spacing.step4))
                            .padding(.bottom, CGFloat(Tokens.Spacing.step8))
                    }
                    .mask { CardContentMask() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(appearance.color(\.lane))
                    .environment(\.narrowCard, proxy.size.width < Tokens.Size.breakpointNarrowCard)
                } else {
                    RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
                        .fill(appearance.color(\.lane))
                        .overlay {
                            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.card))
                                .strokeBorder(appearance.color(\.line), lineWidth: CGFloat(Tokens.Size.hairline))
                        }
                }
            }
        }
        .onChange(of: state.front) { disconnecting = nil }
    }
}

private struct CardContentMask: View {
    var body: some View {
        let inset = CGFloat(Tokens.Spacing.step8)
        let radius = CGFloat(Tokens.Radius.row)
        HStack(spacing: 0) {
            Rectangle().frame(width: inset)
            UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius)
            Rectangle().frame(width: inset)
        }
    }
}
