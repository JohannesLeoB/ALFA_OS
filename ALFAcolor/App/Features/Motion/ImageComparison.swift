import SwiftUI
import AppTheme
import Motion

/// Width of the divider line of an image comparison.
private let dividerWidth: CGFloat = 1

/// Two views on top of each other, with a divider that is dragged or moved with the arrow keys.
/// The leading view shows left of the divider and the trailing view right of it. The position is `CompareSplit`.
struct ImageComparison<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    @State private var split = CompareSplit()
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = CGFloat(split.fraction) * width
            ZStack(alignment: .topLeading) {
                trailing
                leading
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: x)
                    }
                Rectangle()
                    .fill(theme.color(.text, scheme))
                    .frame(width: dividerWidth)
                    .offset(x: x - dividerWidth / 2)
            }
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        split.set(fraction: CompareSplit.fraction(atX: value.location.x, width: width))
                    }
            )
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            step(-CompareSplit.step)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            step(CompareSplit.step)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LocalizedStringKey("motion.compare.label"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(CompareSplit.step)
            case .decrement: step(-CompareSplit.step)
            @unknown default: break
            }
        }
    }

    private func step(_ delta: Double) {
        split.move(by: delta)
    }
}
