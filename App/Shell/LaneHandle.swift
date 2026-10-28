import AppKit
import Design
import Shell
import SwiftUI

struct LaneHandle: View {
    let desk: DeskState
    let lane: LaneKind
    let height: CGFloat
    @Environment(\.appearance) private var appearance
    @State private var startWidth: Double?
    @State private var hovering = false
    @FocusState private var focused: Bool
    @State private var pointerFocus = false

    private var active: Bool { hovering || startWidth != nil }

    var body: some View {
        let width = desk.widths.width(lane)
        let thick = CGFloat(active ? Tokens.Size.handleThicknessActive : Tokens.Size.hairline)
        let long = CGFloat(active ? Tokens.Size.handleLengthActive : Tokens.Size.handleLength)
        let tone = appearance.color(active ? \.ink : \.inkTertiary)
        let plain = appearance.ease(Tokens.Duration.short, SheetValues.gripCurve)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(Tokens.Radius.stroke))
                .animation(plain) { $0.foregroundStyle(tone) }
                .animation(plain) { $0.frame(width: thick) }
                .animation(appearance.ease(Tokens.Duration.short)) { $0.frame(height: long) }
        }
        .frame(width: CGFloat(Tokens.Size.gutter), height: height)
        .overlay(alignment: .top) {
            if startWidth != nil {
                Text(verbatim: appearance.format("lane.handle.value", Int(width.rounded())))
                    .font(.face(Tokens.TextSize.small))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, CGFloat(Tokens.Size.menuRowPadding))
                    .frame(height: CGFloat(Tokens.Size.chipHeight))
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
                .onChanged { value in
                    pointerFocus = true
                    let start = startWidth ?? width
                    startWidth = start
                    let direction: Double = lane == .leading ? 1 : -1
                    desk.dragLane(lane, proposed: start + Double(value.translation.width) * direction)
                }
                .onEnded { _ in
                    startWidth = nil
                    desk.endLaneDrag()
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { desk.resetLane() })
        .accessibilityElement()
        .accessibilityLabel(appearance.text(lane == .leading ? "lane.handle.leading" : "lane.handle.trailing"))
        .dwellHint("shell.handle.down.tooltip", focused: focused && !pointerFocus)
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return {
            desk.resetLane()
            return .handled
        }
        let step = press.modifiers.contains(.shift) ? SheetValues.laneShiftStep : SheetValues.laneStep
        let direction: Double = press.key == .leftArrow ? -1 : 1
        desk.stepLane(lane, by: step * direction * (lane == .leading ? 1 : -1))
        return .handled
    }
}
