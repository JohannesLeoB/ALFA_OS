import Foundation
import Observation
import ALFAcolorCore

/// What the canvas shows and how the user moves around: the size of the canvas, the view of the active space,
/// the items that get views, and the aids on top. The view reads it and sends gestures to it.
/// The view of a space is kept in the store.
@MainActor
@Observable
public final class CanvasController {
    public let store: BoardStore
    /// The size of the canvas in points. Zero until the view reports it.
    public private(set) var size: CanvasSize = .zero
    /// Lines that show where a moving item snaps. Set by whoever moves items.
    public var snapGuides: [SnapGuide] = []
    /// Distances to show. Set by whoever measures.
    public var measures: [Measure] = []

    public init(store: BoardStore) { self.store = store }

    // MARK: Reading

    public var viewport: Viewport { store.viewport }

    /// The zoom as a whole percentage.
    public var zoomPercent: Int { ZoomRange.percent(viewport.zoom) }

    /// True when the active space has no item at all, hidden ones included.
    public var isEmpty: Bool { store.activeSpace?.items.isEmpty ?? true }

    /// The items that get a view now, from back to front.
    public var drawnItems: [Item] {
        guard let space = store.activeSpace else { return [] }
        return Visibility.drawn(in: space, viewport: viewport, canvas: size)
    }

    /// The selected items as rectangles on the canvas.
    public var selectionFrames: [Rect] {
        let view = viewport
        return store.selectedItems.filter { $0.rect.isFinite }.map { view.canvasRect(of: $0.rect) }
    }

    public var snapSegments: [CanvasSegment] { snapGuides.compactMap { $0.segment(viewport: viewport, canvas: size) } }

    public var measureSegments: [(measure: Measure, segment: CanvasSegment)] {
        measures.compactMap { measure in measure.segment(viewport: viewport).map { (measure, $0) } }
    }

    public var gridDots: GridDots { GridDots.make(viewport: viewport, canvas: size) }

    // MARK: Size

    /// Reports the size of the canvas. A size that cannot be used is ignored. The top left of the canvas
    /// keeps its place on the board when the size changes.
    public func resize(to newSize: CanvasSize) {
        guard newSize.isUsable, newSize != size else { return }
        size = newSize
    }

    // MARK: Moving around

    /// Runs a zoom command for the active space.
    public func perform(_ action: ZoomAction) {
        guard let space = store.activeSpace else { return }
        let next = viewport.applying(action, canvas: size,
                                     all: Visibility.bounds(in: space),
                                     selection: Visibility.bounds(in: space, of: store.selection))
        store.setViewport(next)
    }

    /// Sets the view. Used by gestures that work from the view at their start.
    public func setViewport(_ viewport: Viewport) { store.setViewport(viewport) }

    public func scroll(_ input: ScrollInput) { store.setViewport(viewport.scrolled(by: input)) }
}
