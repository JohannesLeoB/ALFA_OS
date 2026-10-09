import Foundation
import ALFAcolorCore

/// Moving, copying, resizing and the lasso. A gesture works on a preview and ends with one command.
extension CanvasInteraction {
    // MARK: Move

    /// The pointer went far enough from the pressed item: the selection starts to move.
    /// With the Option key held at this moment, copies move instead and the items stay.
    func beginMove(modifiers: PointerModifiers, at start: (x: Double, y: Double)) {
        let ids = store.selection
        let items = movingItems(of: ids)
        guard let bounds = ResizeMath.bounds(of: items.map(\.rect)) else {
            phase = .blocked
            return
        }
        let copies = modifiers.contains(.option)
        let moving = Set(items.map(\.id))
        drag = Drag(ids: ids, items: items, duplicates: copies ? items.map(copy(of:)) : [], bounds: bounds, startBoard: start,
                    targets: targets(excluding: copies ? [] : moving))
        lifted = copies ? [] : moving
        liftedItems = copies ? drag!.duplicates : items
        phase = .moving
    }

    func updateMove(to point: (x: Double, y: Double), modifiers: PointerModifiers) {
        guard var state = drag else { return }
        var dx = point.x - state.startBoard.x, dy = point.y - state.startBoard.y
        // Shift holds the direction: only the axis with the larger distance moves.
        let keepsX = modifiers.contains(.shift) && abs(dx) < abs(dy)
        let keepsY = modifiers.contains(.shift) && !keepsX
        if keepsX { dx = 0 }
        if keepsY { dy = 0 }
        var guides: [SnapGuide] = []
        if let result = snapped(state.bounds.translated(dx: dx, dy: dy), motion: .move, targets: state.targets, modifiers: modifiers) {
            if !keepsX { dx = result.rect.x - state.bounds.x }
            if !keepsY { dy = result.rect.y - state.bounds.y }
            guides = result.guides.filter { $0.axis == .vertical ? !keepsX : !keepsY }
        }
        state.delta = (dx, dy)
        drag = state
        let source = state.duplicates.isEmpty ? state.items : state.duplicates
        liftedItems = source.map { item in
            var moved = item
            moved.rect = item.rect.translated(dx: dx, dy: dy)
            return moved
        }
        setGuides(guides)
        refreshDistances()
    }

    func commitMove() {
        guard let state = drag, state.delta.x != 0 || state.delta.y != 0 else { return }
        if state.duplicates.isEmpty {
            run(.move(state.ids, dx: state.delta.x, dy: state.delta.y))
        } else {
            let copies = state.duplicates.map { item -> Item in
                var moved = item
                moved.rect = item.rect.translated(dx: state.delta.x, dy: state.delta.y)
                return moved
            }
            run(.batch([.insert(copies)], nameKey: "undo.duplicate"))
        }
    }

    /// A copy with a new ID. It can be changed, because the original was.
    func copy(of item: Item) -> Item {
        var made = item
        made.id = makeID()
        made.locked = false
        return made
    }

    // MARK: Resize

    func beginResize(_ handle: ResizeHandle, at point: (x: Double, y: Double)) -> Bool {
        let items = editableSelection.filter { $0.rect.isFinite }
        guard let box = ResizeMath.bounds(of: items.map(\.rect)) else { return false }
        scale = Scale(handle: handle, box: box, items: items, startBoard: point,
                      targets: targets(excluding: Set(items.map(\.id))), result: box)
        lifted = Set(items.map(\.id))
        liftedItems = items
        resizeBox = box
        phase = .resizing
        return true
    }

    func updateResize(to point: (x: Double, y: Double), modifiers: PointerModifiers) {
        guard var state = scale else { return }
        let keepsRatio = modifiers.contains(.shift)
        var box = ResizeMath.resized(state.box, handle: state.handle, dx: point.x - state.startBoard.x,
                                     dy: point.y - state.startBoard.y, keepsRatio: keepsRatio)
        var guides: [SnapGuide] = []
        // Snapping would break a kept ratio, so a resize with Shift does not snap.
        if !keepsRatio,
           let result = snapped(box, motion: .resize(x: state.handle.xEdge, y: state.handle.yEdge), targets: state.targets, modifiers: modifiers),
           result.rect.w >= min(ResizeMath.minimumSide, state.box.w), result.rect.h >= min(ResizeMath.minimumSide, state.box.h) {
            box = result.rect
            guides = result.guides
        }
        state.result = box
        scale = state
        resizeBox = box
        liftedItems = state.items.map { item in
            var resized = item
            resized.rect = ResizeMath.mapped(item.rect, from: state.box, to: box)
            return resized
        }
        setGuides(guides)
        refreshDistances()
    }

    func commitResize() {
        guard let state = scale else { return }
        var rects: [ItemID: Rect] = [:]
        for item in liftedItems {
            if let original = state.items.first(where: { $0.id == item.id }), original.rect != item.rect { rects[item.id] = item.rect }
        }
        if !rects.isEmpty { run(.resize(rects)) }
    }

    // MARK: Lasso

    func updateLasso(to point: (x: Double, y: Double)) {
        guard let start = lassoStart, let space else { return }
        let rect = Lasso.rect(fromX: start.board.x, y: start.board.y, toX: point.x, y: point.y)
        lasso = rect
        store.select(start.base.union(Lasso.hits(in: rect, space: space)))
    }
}
