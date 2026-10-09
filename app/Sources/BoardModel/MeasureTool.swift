import Foundation
import ALFAcolorCore

/// The measuring tool: while it is on, a press and a drag measure a line between two points of the board.
/// Nothing is selected or moved, and the line stays until the tool is switched off with Escape.
extension CanvasInteraction {
    /// The press of the measuring tool starts the line at the point, snapped to the edges when snapping is on.
    func measureDown(atBoard point: (x: Double, y: Double), modifiers: PointerModifiers) {
        let start = measureSnapped(point, modifiers: modifiers)
        measureLine = Measure(fromX: start.x, fromY: start.y, toX: start.x, toY: start.y, value: 0)
    }

    /// The drag moves the end of the line. Without a press, the drag starts the line.
    func measureDrag(toBoard point: (x: Double, y: Double), modifiers: PointerModifiers) {
        guard let line = measureLine else {
            measureDown(atBoard: point, modifiers: modifiers)
            return
        }
        let end = measureSnapped(point, modifiers: modifiers)
        var moved = Measure(fromX: line.fromX, fromY: line.fromY, toX: end.x, toY: end.y, value: 0)
        moved.value = MeasureReading.of(moved)?.length ?? 0
        measureLine = moved
    }

    /// The point, snapped to the edges and middles of the visible items when snapping is on.
    private func measureSnapped(_ point: (x: Double, y: Double), modifiers: PointerModifiers) -> (x: Double, y: Double) {
        let rects = visibleItems.map(\.rect)
        guard let result = snapped(Rect(x: point.x, y: point.y, w: 0, h: 0), motion: .move,
                                   targets: SnapTargets(rects: rects), modifiers: modifiers) else {
            return point
        }
        return (result.rect.x, result.rect.y)
    }
}
