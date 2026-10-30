import AppKit
import Design
import Shell
import SwiftUI

struct LaneHandle: View {
    let desk: DeskState
    let lane: LaneKind
    let height: CGFloat
    @Environment(\.appearance) private var appearance
    @GestureState private var pressing = false
    @State private var hovering = false
    @FocusState private var focused: Bool
    @State private var pointerFocus = false

    private var dragging: Bool { desk.draggedLane == lane }

    private var active: Bool { hovering || dragging }

    var body: some View {
        let width = desk.widths.width(lane)
        let value = appearance.format("lane.handle.value", Int(width.rounded()))
        let thick = CGFloat(active ? Tokens.Size.handleThicknessActive : Tokens.Size.hairline)
        let long = CGFloat(active ? Tokens.Size.handleLengthActive : Tokens.Size.handleLength)
        let tone = appearance.color(active ? \.ink : \.inkTertiary)
        let plain = appearance.ease(Tokens.Duration.short, SheetValues.cssEase)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.stroke))
                .animation(plain) { $0.foregroundStyle(tone) }
                .animation(plain) { $0.frame(width: thick) }
                .animation(appearance.ease(Tokens.Duration.short)) { $0.frame(height: long) }
        }
        .frame(width: CGFloat(Tokens.Size.gutter), height: height)
        .overlay(alignment: .top) {
            if dragging {
                Text(verbatim: value)
                    .font(.face(Tokens.TextSize.small))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, CGFloat(Tokens.Spacing.step12))
                    .frame(height: CGFloat(Tokens.Spacing.step24))
                    .foregroundStyle(appearance.color(\.onInverse))
                    .background(Capsule().fill(appearance.color(\.inverse)))
                    .padding(.top, CGFloat(Tokens.Spacing.step12))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if focused && !pointerFocus {
                Rectangle()
                    .strokeBorder(appearance.color(\.focus), lineWidth: CGFloat(Tokens.Size.focusRingWidth))
                    .padding(-CGFloat(Tokens.Size.focusRingOffset + Tokens.Size.focusRingWidth))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .onHover { hovering = $0 }
        .focusable()
        .focused($focused)
        .onChange(of: focused) { _, now in pointerFocus = now && NSApp.currentEvent?.type != .keyDown }
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .return]) { press in
            pointerFocus = false
            return key(press)
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($pressing) { _, state, _ in state = true }
                .onChanged { drag in
                    pointerFocus = true
                    desk.dragLane(lane, translation: Double(drag.translation.width))
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { desk.resetLane() })
        .onChange(of: pressing) { _, now in if !now { desk.endLaneDrag() } }
        .onDisappear { desk.endLaneDrag() }
        .accessibilityElement()
        .accessibilityLabel(appearance.text(lane == .leading ? "lane.handle.leading" : "lane.handle.trailing"))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
        .dwellHint("shell.handle.down.tooltip", focused: focused && !pointerFocus)
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return {
            desk.resetLane()
            return .handled
        }
        let size = press.modifiers.contains(.shift) ? SheetValues.laneShiftStep : desk.measure.laneFolded
        let direction: Double = press.key == .leftArrow ? -1 : 1
        desk.stepLane(lane, by: size * direction * (lane == .leading ? 1 : -1))
        return .handled
    }

    private func step(by sign: Double) {
        desk.stepLane(lane, by: desk.measure.laneFolded * sign)
    }
}
