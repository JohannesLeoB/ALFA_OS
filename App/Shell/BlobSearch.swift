import Design
import Shell
import SwiftUI

struct BlobSearch: View {
    @Bindable var desk: DeskState
    @Environment(\.appearance) private var appearance
    @FocusState private var focused: Bool
    @State private var tape = 0.0
    @State private var fade = 0.0

    var body: some View {
        HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
            ZStack(alignment: .leading) {
                if desk.query.isEmpty {
                    appearance.text("menu.search")
                        .opacity(SheetValues.placeholderOpacity)
                        .allowsHitTesting(false)
                }
                TextField("", text: $desk.query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onKeyPress(.downArrow) { step(down: true) }
                    .onKeyPress(.upArrow) { step(down: false) }
                    .onKeyPress(.escape) {
                        desk.close()
                        return .handled
                    }
                    .onSubmit { desk.chooseHot(entries) }
                    .accessibilityLabel(appearance.text("menu.search"))
            }
            .font(.face(Tokens.TextSize.body))
            .searchFade(progress: fade)
            Glyph(.search)
                .opacity(SheetValues.iconOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(Tokens.Size.symbolSize))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.foreground)
                .frame(height: CGFloat(Tokens.Size.hairline))
                .scaleEffect(x: CGFloat(tape), y: 1, anchor: .trailing)
        }
        .padding(.leading, CGFloat(Tokens.Spacing.step8))
        .padding(.trailing, CGFloat(Tokens.Spacing.step16))
        .task {
            if appearance.still {
                tape = 1
                fade = 1
            } else {
                withAnimation(appearance.ease(Tokens.Duration.searchUnderline)) { tape = 1 }
                withAnimation(.linear(duration: Tokens.Duration.searchUnderline)) { fade = 1 }
            }
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuFocusDelay))
            focused = true
        }
    }

    private var entries: [AppEntry] {
        desk.menuLines(title: { appearance.string($0) }).compactMap(\.entry)
    }

    private func step(down: Bool) -> KeyPress.Result {
        let count = entries.count
        guard count > 0 else { return .ignored }
        desk.moveHot(down: down, count: count)
        return .handled
    }
}
