import Foundation
import ALFAcolorCore

/// What the tools do on the canvas: zoom, draw a frame or a shape, set a text. The pointer methods of
/// `CanvasInteraction` pass a press to these when the active tool is one of them.
extension CanvasInteraction {
    /// The size of a text that is set with a press, in board points.
    static let textBox = (w: 160.0, h: 32.0)
    /// A drawn frame or shape smaller than this on one side is not made: it is a click, not a drawing.
    static let minimumDrawSize = 2.0

    /// A press with the zoom tool zooms one step in around the point, or one step out with Option.
    func zoomPress(canvasX x: Double, y: Double, out: Bool) {
        let view = controller.viewport
        let zoom = out ? ZoomRange.stepDown(from: view.zoom) : ZoomRange.stepUp(from: view.zoom)
        controller.setViewport(view.zoomed(to: zoom, aroundCanvasX: x, y: y))
    }

    /// A press with the frame or the shape tool starts a rectangle at the point. The rectangle shows as the lasso.
    func drawPress(at point: (x: Double, y: Double)) {
        drawStart = point
        lasso = Rect(x: point.x, y: point.y, w: 0, h: 0)
        phase = .drawing
    }

    /// The drag moves the far corner of the rectangle.
    func drawDrag(to point: (x: Double, y: Double)) {
        guard let start = drawStart else { return }
        lasso = DrawBox.between(start, point)
    }

    /// The release makes the frame or the shape, as one command. Returns true when an item was made.
    @discardableResult
    func drawEnd(to point: (x: Double, y: Double)) -> Bool {
        guard let start = drawStart, let layer = drawLayer() else { return false }
        let box = DrawBox.between(start, point)
        guard box.w >= Self.minimumDrawSize, box.h >= Self.minimumDrawSize else { return false }
        let item: Item
        switch tools.active {
        case .frame:
            item = Item(title: "", content: .frame(deviceID: tools.options.frameDeviceID, gridID: nil), rect: box, layerID: layer)
        case .shape:
            let style = ShapeStyle(fill: ShapeFill.standard(in: store.document.tokenSets)?.hex)
            item = Item(title: "", content: .shape(kind: tools.options.shapeKind, style: style), rect: box, layerID: layer)
        default:
            return false
        }
        return run(.insert([item]))
    }

    /// A press with the text tool sets a text at the point and starts its edit, so that the user types at once.
    func textPress(at point: (x: Double, y: Double)) {
        guard let layer = drawLayer() else { return }
        let rect = Rect(x: point.x, y: point.y, w: Self.textBox.w, h: Self.textBox.h)
        let item = Item(title: "", content: .text(text: "", style: tools.options.textStyle), rect: rect, layerID: layer)
        guard run(.insert([item])) else { return }
        _ = beginEditing(item.id)
    }

    /// The layer that a new item goes on: the first one that is visible and not locked.
    func drawLayer() -> String? {
        space?.layers.first { $0.visible && !$0.locked }?.id
    }
}

/// The rectangle between two corners, with a positive width and height.
public enum DrawBox {
    public static func between(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Rect {
        Rect(x: min(a.x, b.x), y: min(a.y, b.y), w: abs(b.x - a.x), h: abs(b.y - a.y))
    }
}
