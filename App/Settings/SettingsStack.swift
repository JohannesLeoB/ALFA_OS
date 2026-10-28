import Design
import Hub
import Shell
import SwiftUI

struct SettingsStack: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    @State private var size = OverviewSize.medium
    @State private var hot: String?
    @State private var disconnecting: String?

    private var state: SettingsState { context.state }

    var body: some View {
        let readings = context.readings
        let front = state.front ?? state.cards.last
        let order = state.cards.filter { $0 != front } + state.cards.filter { $0 == front }
        GeometryReader { proxy in
            VStack(spacing: 0) {
                SettingsCommandHead(context: context, readings: readings, width: proxy.size.width, disconnecting: $disconnecting)
                CardStack(order: order, fanned: state.fanned, fans: true, top: 0) { id, depth in
                    StackCard(context: context, face: SettingsFace(id: id, readings: readings, appearance: appearance), depth: depth,
                              disconnecting: disconnecting)
                        .environment(\.narrowCard, proxy.size.width < Tokens.Size.breakpointNarrowCard)
                } overview: {
                    CardOverview(entries: order.map { entry(SettingsFace(id: $0, readings: readings, appearance: appearance), current: $0 == front) },
                                 size: size, resize: { size = $0 }, hot: hot, aim: { hot = $0 }) {
                        EmptyView()
                    }
                } note: {
                    EmptyView()
                }
            }
        }
        .onChange(of: state.front) { disconnecting = nil }
    }

    private func entry(_ face: SettingsFace, current: Bool) -> OverviewEntry {
        OverviewEntry(id: face.id, mark: .text(face.mark), title: Text(verbatim: face.title), date: Text(verbatim: ""), unread: false,
                      subject: face.detail, preview: face.preview, current: current, close: { state.close(face.id) },
                      choose: { state.bring(face.id) })
    }
}

struct StackCard: View {
    @Environment(\.appearance) private var appearance
    let context: SettingsContext
    let face: SettingsFace
    let depth: Int
    let disconnecting: String?

    private var front: Bool { depth == 0 }

    var body: some View {
        CardFace(depth: depth, bring: { context.state.bring(face.id) }) { ink in
            header(ink)
        } content: {
            ScrollView {
                SettingsDetail(context: context, id: face.id, disconnecting: disconnecting == face.id)
                    .padding(.top, CGFloat(Tokens.Spacing.step4))
                    .padding(.bottom, CGFloat(Tokens.Spacing.step8))
            }
            .scrollIndicators(.never)
        }
    }

    private func header(_ ink: Color) -> some View {
        CardHeader(front: front, ink: ink) {
            Text(verbatim: face.mark)
        } title: {
            Text(verbatim: face.title)
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .lineLimit(1)
        } meta: {
            Text(verbatim: face.meta)
                .font(.face(Tokens.TextSize.small))
                .monospacedDigit()
                .lineLimit(1)
                .opacity(CardStackEngine.metaOpacity(depth: depth))
                .frame(maxWidth: .infinity, alignment: .leading)
        } trailing: {
            CardHeadButton(help: appearance.string("card.close"), glyph: .close, ink: ink, fills: false) { context.state.close(face.id) }
        }
    }
}
