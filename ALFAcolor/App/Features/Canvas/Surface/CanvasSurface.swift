import SwiftUI
import AppTheme
import BoardModel

/// The canvas: grid, items and aids, with zoom and pan. The area is content, not glass.
/// The math is in `CanvasController`; this view reports the size and passes gestures on.
/// Tab toggles all palettes, but only while the canvas has focus. Space plus drag grabs the canvas.
struct CanvasSurface: View {
    var controller: CanvasController
    var onTogglePalettes: @MainActor () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @FocusState private var hasFocus: Bool
    @State private var spaceDown = false
    @State private var panStart: Viewport?
    @State private var pinchStart: Viewport?

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.color(.background, scheme)
            CanvasGridLayer(controller: controller)
            CanvasItemsLayer(controller: controller)
            CanvasAidsLayer(controller: controller)
            if controller.isEmpty {
                emptyHint
            }
            ScrollCatcher { controller.scroll($0) }
        }
        .clipped()
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            controller.resize(to: CanvasSize(width: size.width, height: size.height))
        }
        .contentShape(Rectangle())
        .onTapGesture { hasFocus = true }
        .simultaneousGesture(grab)
        .simultaneousGesture(pinch)
        .pointerStyle(pointer)
        .focusable()
        .focusEffectDisabled()
        .focused($hasFocus)
        .onKeyPress(.tab) {
            guard hasFocus else { return .ignored }
            onTogglePalettes()
            return .handled
        }
        .onKeyPress(.space, phases: [.down, .up]) { press in
            guard hasFocus else { return .ignored }
            spaceDown = press.phase == .down
            return .handled
        }
        .onChange(of: hasFocus) { _, focused in
            if !focused { spaceDown = false }
        }
        .onAppear { hasFocus = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("canvas.accessibility")
    }

    private var emptyHint: some View {
        VStack(spacing: theme.space(.s2)) {
            Text("canvas.title")
                .font(theme.text(.caption).font)
            Text("canvas.hint")
                .font(theme.text(.body).font)
        }
        .foregroundStyle(theme.color(.textMuted, scheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var pointer: PointerStyle? {
        guard spaceDown else { return nil }
        return panStart == nil ? .grabIdle : .grabActive
    }

    /// Space plus drag moves the view. The view at the start of the drag is the base, so the move does not drift.
    private var grab: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard spaceDown else { return }
                let start = panStart ?? controller.viewport
                panStart = start
                controller.setViewport(start.panned(byCanvasX: value.translation.width, y: value.translation.height))
            }
            .onEnded { _ in panStart = nil }
    }

    /// A pinch zooms around the point where it began.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? controller.viewport
                pinchStart = start
                controller.setViewport(start.zoomed(by: value.magnification,
                                                    aroundCanvasX: value.startLocation.x, y: value.startLocation.y))
            }
            .onEnded { _ in pinchStart = nil }
    }
}
