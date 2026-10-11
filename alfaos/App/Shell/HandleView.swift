import ShellCore
import SwiftUI

struct HandleView: View {
    let theme: Theme
    let model: ShellModel
    let lane: Lane
    let height: CGFloat
    @State private var startWidth: Double?
    @State private var hovering = false

    private var active: Bool { hovering || startWidth != nil }

    var body: some View {
        let widths = model.widths
        let length = theme.length(active ? .componentLaneHandleLengthActive : .componentLaneHandleLength)
        ZStack {
            RoundedRectangle(cornerRadius: theme.length(.componentLaneHandleRadius))
                .fill(theme.color(active ? .colorControlHandleActive : .colorControlHandle))
                .frame(width: theme.length(.componentLaneHandleThickness), height: length)
        }
        .frame(width: theme.length(.componentLaneHandleWidth), height: height)
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .onHover { hovering = $0 }
        .animation(theme.animation(.motionDurationChange), value: active)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let start = startWidth ?? widths.width(lane)
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
        .accessibilityElement()
        .accessibilityLabel(theme.text("lane.handle"))
    }
}
