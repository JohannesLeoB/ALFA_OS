import Assistant
import Design
import SwiftUI

struct AssistantCard: View {
    @Environment(\.appearance) private var appearance
    let kindKey: String
    let title: String
    let line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
            appearance.text(kindKey)
                .typeStyle(Tokens.TextStyle.caption)
                .foregroundStyle(appearance.color(\.onInverseTertiary))
            Text(verbatim: title)
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(verbatim: line)
                    .typeStyle(Tokens.TextStyle.caption)
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, CGFloat(Tokens.Spacing.step8))
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(appearance.color(\.inverseField)))
    }
}

extension AssistantCard {
    init(draft: DraftSummary, appearance: Appearance) {
        kindKey = "shell.assistantCard.kind." + draft.kind.rawValue
        title = draft.title
        line = draft.line.map { draft.kind == .mail ? appearance.format("shell.assistantCard.mailTo", $0) : $0 }
    }
}
