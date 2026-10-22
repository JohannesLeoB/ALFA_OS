import ShellCore
import SwiftUI

struct HandleView: View {
    let theme: Theme
    let model: ShellModel
    let lane: Lane
    let height: CGFloat
    @State private var startWidth: Double?
    @State private var hovering = false
    @FocusState private var focused: Bool
    @State private var pointerFocus = false

    private var active: Bool { hovering || startWidth != nil }

    var body: some View {
        let width = model.widths.width(lane)
        let thick = CGFloat(active ? Design.Size.handleThicknessActive : Design.Size.hairline)
        let long = CGFloat(active ? Design.Size.handleLengthActive : Design.Size.handleLength)
        let tone = theme.design(active ? \.ink : \.inkTertiary)
        let plain = theme.ease(Design.Duration.short, SheetValues.gripCurve)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(Design.Radius.stroke))
                .animation(plain) { $0.foregroundStyle(tone) }
                .animation(plain) { $0.frame(width: thick) }
                .animation(theme.ease(Design.Duration.short)) { $0.frame(height: long) }
        }
        .frame(width: CGFloat(Design.Size.gutter), height: height)
        .overlay(alignment: .top) {
            if startWidth != nil {
                Text(verbatim: String(format: theme.string("lane.handle.value"), Int(width.rounded())))
                    .font(theme.font(Design.TextSize.small))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, CGFloat(Design.Size.menuRowPadding))
                    .frame(height: CGFloat(Design.Size.chipHeight))
                    .foregroundStyle(theme.design(\.onInverse))
                    .background(Capsule().fill(theme.design(\.inverse)))
                    .padding(.top, CGFloat(Design.Spacing.step12))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if focused && !pointerFocus {
                Rectangle()
                    .strokeBorder(theme.design(\.focus), lineWidth: CGFloat(Design.Size.focusRingWidth))
                    .padding(-CGFloat(Design.Size.focusRingOffset + Design.Size.focusRingWidth))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .onHover { hovering = $0 }
        .focusable()
        .focused($focused)
        .onChange(of: focused) { _, now in if !now { pointerFocus = false } }
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .return]) { press in key(press) }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    pointerFocus = true
                    let start = startWidth ?? width
                    startWidth = start
                    let direction: Double = lane == .leading ? 1 : -1
                    model.dragLane(lane, proposed: start + Double(value.translation.width) * direction)
                }
                .onEnded { _ in
                    startWidth = nil
                    model.endLaneDrag()
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.resetLane(lane) })
        .help(theme.string("lane.handle.help"))
        .accessibilityElement()
        .accessibilityLabel(theme.text(lane == .leading ? "lane.handle.leading" : "lane.handle.trailing"))
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return {
            model.resetLane(lane)
            return .handled
        }
        let step = press.modifiers.contains(.shift) ? SheetValues.laneShiftStep : Design.Size.foldedWidth
        let direction: Double = press.key == .leftArrow ? -1 : 1
        model.stepLane(lane, by: step * direction * (lane == .leading ? 1 : -1))
        return .handled
    }
}
