import Assistant
import Design
import SwiftUI

struct AssistantMessage: View {
    @Environment(\.appearance) private var appearance
    let turn: ChatTurn
    let retry: () -> Void

    private var user: Bool { turn.kind == .user }

    var body: some View {
        VStack(alignment: user ? .trailing : .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            if !turn.blocks.isEmpty {
                blocks
            }
            if turn.kind == .streaming {
                appearance.text("shell.assistantMessage.thinking")
                    .foregroundStyle(appearance.color(\.onInverseTertiary))
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            }
            if turn.kind == .failed {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
                        appearance.text("shell.assistantMessage.failed")
                            .fixedSize()
                        retryButton
                    }
                    VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step4)) {
                        appearance.text("shell.assistantMessage.failed")
                            .fixedSize(horizontal: false, vertical: true)
                        retryButton
                    }
                }
                .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
            }
        }
        .frame(maxWidth: .infinity, alignment: user ? .trailing : .leading)
        .padding(.leading, user ? CGFloat(Tokens.Spacing.step28) : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(appearance.text(user ? "shell.assistantMessage.user" : "shell.assistantMessage.assistant"))
    }

    private var retryButton: some View {
        TextButton(label: appearance.text("shell.textButton.assistantRetry.text"), kind: .inverse, action: retry)
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: CGFloat(Tokens.Spacing.step8)) {
            ForEach(Array(turn.blocks.enumerated()), id: \.offset) { _, block in
                piece(block)
            }
        }
        .padding(.vertical, user ? CGFloat(Tokens.Spacing.step8) : 0)
        .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
        .background(RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row)).fill(user ? appearance.color(\.inverseField) : Color.clear))
    }

    @ViewBuilder
    private func piece(_ block: TurnBlock) -> some View {
        switch block {
        case .activity(let label, let failed):
            AssistantActivity(label: label, failed: failed)
        case .text(let value):
            Text(verbatim: value)
                .fixedSize(horizontal: false, vertical: true)
        case .draft(let draft):
            AssistantCard(draft: draft)
        case .estimate(let minNet, let maxNet):
            AssistantCard(kindKey: "shell.assistantCard.kind.estimate",
                          title: appearance.format("shell.assistantCard.estimateRange", amount(minNet), amount(maxNet)), line: nil)
        case .breakdown(let lines):
            AssistantCard(kindKey: "shell.assistantCard.kind.estimate",
                          title: appearance.format("shell.assistantCard.breakdownLines", String(lines)), line: nil)
        case .file(let name):
            AssistantAttachment(name: name)
        case .unreadable:
            appearance.text("shell.assistantCard.unreadable")
                .foregroundStyle(appearance.color(\.onInverseTertiary))
        }
    }

    private func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
