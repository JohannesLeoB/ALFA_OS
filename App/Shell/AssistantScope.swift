import Assistant
import Design
import SwiftUI

struct AssistantScope: View {
    @Environment(\.appearance) private var appearance
    let scope: ConversationScope
    let clearable: Bool
    let clear: () -> Void

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Spacing.step8)) {
            label
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if clearable {
                BlobSymbolButton(help: appearance.string("shell.symbolButton.assistantClear.tooltip"), glyph: .trash, action: clear)
            }
        }
        .typeStyle(Tokens.TextStyle.caption)
        .foregroundStyle(appearance.color(\.onInverseTertiary))
        .padding(.leading, CGFloat(Tokens.Spacing.step12))
        .padding(.trailing, CGFloat(Tokens.Spacing.step4))
        .frame(height: CGFloat(Tokens.Size.menuRowHeight))
    }

    private var label: Text {
        switch scope {
        case .home: appearance.text("shell.assistantScope.home")
        case .project(let number): Text(verbatim: number)
        }
    }
}
