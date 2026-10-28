import Assistant
import Design
import SwiftUI

struct AssistantThread: View {
    let turns: [ChatTurn]
    let room: CGFloat
    let retry: () -> Void
    @State private var height = CGFloat.zero

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: CGFloat(Tokens.Spacing.step12)) {
                ForEach(turns) { turn in
                    AssistantMessage(turn: turn, retry: retry)
                }
            }
            .padding(.vertical, CGFloat(Tokens.Spacing.step4))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollIndicators(.never)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .frame(height: min(height, max(0, room)))
    }
}
