import Design
import Shell
import SwiftUI

struct BlobMenu: View {
    let session: AppSession
    let up: Bool
    @Environment(\.appearance) private var appearance
    @State private var reel = false
    @State private var height = CGFloat.zero
    @State private var aim: Task<Void, Never>?

    private var desk: DeskState { session.desk }

    var body: some View {
        let lines = desk.menuLines(title: { appearance.string($0) })
        let room = CGFloat(desk.blob.menuRoom(window: desk.window, measure: desk.measure))
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                line.padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset)).padding(.bottom, CGFloat(Tokens.Spacing.step8))
                ForEach(Array(lines.enumerated()), id: \.element.id) { index, item in
                    reeled(index) {
                        switch item {
                        case .separator:
                            line.padding(.horizontal, CGFloat(Tokens.Size.menuSeparatorInset)).padding(.vertical, CGFloat(Tokens.Size.menuSeparatorSpace))
                        case .entry(let entry, let hit):
                            row(entry, hit: hit)
                        }
                    }
                }
                if lines.isEmpty {
                    appearance.text("menu.empty")
                        .opacity(SheetValues.mutedOpacity)
                        .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: CGFloat(Tokens.Size.menuRowHeight))
                }
            }
            .padding(.horizontal, CGFloat(Tokens.Size.menuEdge))
            .padding(.bottom, CGFloat(Tokens.Size.menuEdge))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollIndicators(.never)
        .frame(height: min(height, room))
        .font(.face(Tokens.TextSize.body))
        .onHover { inside in if !inside { leave() } }
        .task {
            if appearance.still {
                reel = true
                return
            }
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuReelDelay))
            reel = true
        }
    }

    private var line: some View {
        Rectangle().fill(appearance.color(\.inverseLine)).frame(height: CGFloat(Tokens.Size.hairline))
    }

    private func reeled<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        let delay = Double(min(index, Tokens.Count.menuStaggerMax)) * Tokens.Duration.reelStagger
        let shown = reel || appearance.still
        return content()
            .reel(angle: shown ? 0 : (up ? Tokens.Motion.menuReelTilt : -Tokens.Motion.menuReelTilt), bottom: up)
            .animation(appearance.ease(Tokens.Duration.menuReelTransform, delay: delay), value: shown)
            .opacity(shown ? 1 : 0)
            .animation(appearance.ease(Tokens.Duration.rowSequence, delay: delay), value: shown)
    }

    private func row(_ entry: AppEntry, hit: Int) -> some View {
        let current = entry.id == desk.currentID
        let count = session.panes[entry.id]?.badge ?? 0
        return HStack(spacing: CGFloat(Tokens.Size.menuRowGap)) {
            appearance.text(entry.titleKey)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if count > 0 {
                Text(verbatim: String(count))
                    .font(.face(Tokens.TextSize.small))
                    .monospacedDigit()
                    .opacity(SheetValues.mutedOpacity)
            }
        }
        .font(.face(Tokens.TextSize.body, weight: current ? Tokens.Weight.semibold : Tokens.Weight.regular))
        .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
        .frame(height: CGFloat(Tokens.Size.menuRowHeight))
        .background(
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.row))
                .fill(desk.hot == hit ? appearance.color(\.inverseHot) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { inside in if inside { target(hit) } }
        .onTapGesture { desk.select(entry.id) }
        .accessibilityAddTraits(.isButton)
    }

    private func target(_ hit: Int) {
        guard desk.hot != hit else { return }
        aim?.cancel()
        aim = Task {
            try? await Task.sleep(for: .seconds(Tokens.Duration.menuHoverDelay))
            guard !Task.isCancelled else { return }
            desk.aim(hit)
        }
    }

    private func leave() {
        aim?.cancel()
        desk.clearHot()
    }
}
