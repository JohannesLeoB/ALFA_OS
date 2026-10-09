import SwiftUI
import AppTheme
import BoardModel
import Importers

/// The canvas: grid, items and aids, with zoom and pan. The area is content, not glass.
/// The math is in `CanvasController`; this view reports the size and passes gestures on.
/// Clicks, drags and keys on items are handled by `SelectionInput`.
/// Tab toggles all palettes, but only while the canvas has focus. Space plus drag grabs the canvas.
struct CanvasSurface: View {
    var controller: CanvasController
    var interaction: CanvasInteraction
    var importer: ImportCoordinator
    var onTogglePalettes: @MainActor () -> Void
    /// Changes each time a lab closes; the canvas then takes the keyboard focus back.
    var labClosings = 0

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
            CanvasItemsLayer(controller: controller, interaction: interaction)
            SelectionLayer(interaction: interaction)
            CanvasAidsLayer(controller: controller, interaction: interaction)
            if controller.isEmpty {
                emptyHint
            }
            ScrollCatcher { controller.scroll($0) }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            controller.resize(to: CanvasSize(width: size.width, height: size.height))
        }
        .contentShape(Rectangle())
        .onTapGesture { hasFocus = true }
        .simultaneousGesture(grab)
        .simultaneousGesture(pinch)
        .selectionInput(interaction, isFocused: hasFocus, panning: spaceDown)
        .modifier(LabKey(isFocused: hasFocus))
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
        .onChange(of: interaction.editing == nil) { _, ended in
            if ended { hasFocus = true }
        }
        .onChange(of: labClosings) { hasFocus = true }
        .onAppear { hasFocus = true }
        .modifier(ImportTargets(controller: controller, importer: importer))
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
        if spaceDown { return panStart == nil ? .grabIdle : .grabActive }
        return interaction.hoveredHandle.map { .frameResize(position: $0.resizePosition) }
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

private extension ResizeHandle {
    /// The position of the resize cursor for this handle.
    var resizePosition: FrameResizePosition {
        switch self {
        case .topLeft: .topLeading
        case .top: .top
        case .topRight: .topTrailing
        case .right: .trailing
        case .bottomRight: .bottomTrailing
        case .bottom: .bottom
        case .bottomLeft: .bottomLeading
        case .left: .leading
        }
    }
}
