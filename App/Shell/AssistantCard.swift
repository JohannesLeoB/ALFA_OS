import Assistant
import Design
import SwiftUI

struct AssistantCard: View {
    @Environment(\.appearance) private var appearance
    let kindKey: String
    let title: String
    let line: String?
    var addressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
            appearance.text(kindKey)
                .typeStyle(Tokens.TextStyle.caption)
                .foregroundStyle(appearance.color(\.onInverseTertiary))
            Text(verbatim: title)
                .typeStyle(Tokens.TextStyle.bodyEmphasis)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(verbatim: addressed ? appearance.format("shell.assistantCard.mailTo", line) : line)
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
    init(draft: DraftSummary) {
        self.init(kindKey: Self.kindKey(draft.kind), title: draft.title, line: draft.line, addressed: draft.kind == .mail)
    }

    private static func kindKey(_ kind: DraftSummary.Kind) -> String {
        switch kind {
        case .mail: "shell.assistantCard.kind.mail"
        case .contact: "shell.assistantCard.kind.contact"
        case .task: "shell.assistantCard.kind.task"
        case .appointment: "shell.assistantCard.kind.appointment"
        case .cart: "shell.assistantCard.kind.cart"
        case .file: "shell.assistantCard.kind.file"
        case .calendar: "shell.assistantCard.kind.calendar"
        }
    }
}
