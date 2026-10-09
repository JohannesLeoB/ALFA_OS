import Foundation
import Observation
import ALFAcolorCore

/// Where a pointer action stands.
public enum InteractionPhase: Equatable, Sendable {
    case idle
    /// An item is pressed and the pointer has not moved far enough to drag it.
    case pressed
    case moving
    case resizing
    case lasso
    /// The press belongs to something else (the text editor, or items that cannot change). Nothing follows from it.
    case blocked
    /// A frame or a shape is drawn: the rectangle from the press to the pointer shows as the lasso.
    case drawing
}

/// Select, move, resize and duplicate items with the pointer and the keyboard.
/// The view reports the pointer in canvas points and the keys; everything else is decided here.
///
/// A drag works on a preview, which is not part of the document: `liftedItems` hold the items at their place
/// during the drag. At the end one command changes the document, so that a drag is one undo step.
@MainActor
@Observable
public final class CanvasInteraction {
    public let controller: CanvasController
    public var store: BoardStore { controller.store }

    // MARK: Settings, set by the view

    /// The height of the band of a frame or group on the board, in points.
    public var bandHeight = 0.0
    /// The size of a handle on the screen, in points.
    public var handleSize = 0.0
    /// The snapping of drags and resizes. `isOn` turns snapping off, `gridStep` turns the grid on (0 is off).
    /// Every change is reported to `onSnapChange`, so the app can keep the choice.
    public var snap = SnapSettings() { didSet { onSnapChange?(snap) } }
    /// Called after every change of `snap`.
    public var onSnapChange: ((SnapSettings) -> Void)?
    /// The step of the grid, in board points, while the grid is shown. It matches the dots the canvas draws.
    public var gridStep = 8.0
    /// The guides of the frames take part in snapping only while they are shown. The window sets it.
    public var guidesShown = true
    /// The marks of the notes show on the canvas while this is true. The menu View > Notes toggles it.
    public var notesShown = true
    /// The spacing tokens. They name the gaps that the Option key shows. Snapping to them is `SnapSettings.snapsToSpacing`.
    public var spacingStops: [SpacingStop] = [] { didSet { refreshDistances() } }
    /// True while the Option key is held. The gaps to the neighbours show then.
    public var optionHeld = false { didSet { if oldValue != optionHeld { refreshDistances() } } }
    /// Reads the spacing stops from the token sets of the document.
    public func reloadSpacingStops() {
        spacingStops = SpacingTokens.stops(in: store.document.tokenSets)
    }
    /// The active tool and the tool options. A change of the tool ends a measured line and the gaps shown for the old tool.
    public var tools = ToolState() {
        didSet {
            guard oldValue.active != tools.active else { return }
            measureLine = nil
            drawStart = nil
            lasso = nil
            noteDraft = nil
            refreshDistances()
        }
    }
    /// The note that the comment tool is writing: its item and the place on it. The view types the text.
    /// It is closed by `finishNoteDraft`, `cancelNoteDraft`, or a change of the tool.
    public internal(set) var noteDraft: NoteDraft?
    /// True while the measuring tool is on. A press and a drag then measure a line instead of selecting.
    public var measuring: Bool {
        get { tools.active == .measure }
        set { if newValue { tools.choose(.measure) } else { tools.leave() } }
    }
    /// The line of the measuring tool, in board points. Its value is the length. nil when nothing is measured.
    public internal(set) var measureLine: Measure?
    /// True while the gaps of the selection show, without the Option key. Set by the switch in the room inspector.
    public var showsDistances = false { didSet { if oldValue != showsDistances { refreshDistances() } } }
    /// The IDs of new items (copies). A test can set its own.
    @ObservationIgnored public var makeID: () -> ItemID = { ItemID() }

    // MARK: State for the views

    public internal(set) var phase: InteractionPhase = .idle
    /// The lasso on the board, while it is drawn.
    public internal(set) var lasso: Rect?
    /// The real items that the preview draws instead of the base layer.
    public internal(set) var lifted: Set<ItemID> = []
    /// The items of the preview at their place: the items that move or resize, or the copies of a duplicating drag.
    public internal(set) var liftedItems: [Item] = []
    /// The box of the selection while it resizes, on the board.
    public internal(set) var resizeBox: Rect?
    /// Counts how often the snap lines changed to a new set. The view plays the haptic feedback on each change.
    public internal(set) var snapTick = 0
    /// The labels of `controller.measures`, in the same order.
    public internal(set) var distanceLabels: [DistanceLabel] = []
    /// The handle under the pointer, for the cursor.
    public internal(set) var hoveredHandle: ResizeHandle?
    /// The text edit in progress, if any.
    public internal(set) var editing: TextEdit?
    /// The swatch whose colour fan is open, if any. The view shows the fan over that item.
    public internal(set) var fanItem: ItemID?
    /// The image item whose file the user wants to find. The view opens the file panel and answers with `replaceImage`.
    public var fileSearchRequest: ItemID?
    /// Counts the requests to choose files for import. The canvas presents the chooser on each change.
    public internal(set) var importRequest = 0
    /// The error of the last command that failed, nil after a command that worked.
    public internal(set) var lastError: (any Error)?
    /// The pieces of the last copy or cut in this window, and the mark that the system pasteboard carries for them.
    public internal(set) var clipboard: [Item] = []
    public internal(set) var clipboardMark = ""

    // MARK: Gesture state

    struct Press {
        var id: ItemID
        var canvas: (x: Double, y: Double)
        var release: Release
    }

    enum Release {
        case keep
        /// A plain click on an item of a larger selection narrows the selection to it.
        case narrow(ItemID)
        /// A click with Shift or Command on a selected item takes it out again.
        case remove(ItemID)
    }

    struct Drag {
        /// The selection when the drag began: the target of the move command.
        var ids: Set<ItemID>
        var items: [Item]
        var duplicates: [Item]
        var bounds: Rect
        var startBoard: (x: Double, y: Double)
        var targets: SnapTargets
        var delta: (x: Double, y: Double) = (0, 0)
    }

    struct Scale {
        var handle: ResizeHandle
        var box: Rect
        var items: [Item]
        var startBoard: (x: Double, y: Double)
        var targets: SnapTargets
        var result: Rect
    }

    struct LassoStart {
        var board: (x: Double, y: Double)
        var base: Set<ItemID>
    }

    @ObservationIgnored var press: Press?
    @ObservationIgnored var drag: Drag?
    @ObservationIgnored var scale: Scale?
    @ObservationIgnored var lassoStart: LassoStart?
    /// The corner where a frame or a shape is drawn, in board points.
    @ObservationIgnored var drawStart: (x: Double, y: Double)?
    @ObservationIgnored var lastGuides: [SnapGuide] = []

    /// The pointer must move this far before an item moves, in screen points.
    public static let dragThreshold = 3.0

    public init(controller: CanvasController) {
        self.controller = controller
        controller.store.onWillSwitchSpace = { [weak self] in self?.prepareSpaceChange() }
    }

    // MARK: Reading

    var space: Space? { store.activeSpace }

    private var zoom: Double { controller.viewport.zoom }

    func board(fromCanvasX x: Double, y: Double) -> (x: Double, y: Double) {
        controller.viewport.boardPoint(canvasX: x, canvasY: y)
    }

    func isEditable(_ item: Item) -> Bool {
        guard !item.locked, let space else { return false }
        return !space.layers.contains { $0.id == item.layerID && $0.locked }
    }

    /// The selected items that can be changed.
    var editableSelection: [Item] { store.selectedItems.filter(isEditable) }

    /// The items a move touches: the selected items that can change, and the items that can change inside the selected frames and groups.
    func movingItems(of ids: Set<ItemID>) -> [Item] {
        guard let space else { return [] }
        var taken = Set<ItemID>()
        for item in space.items where ids.contains(item.id) && isEditable(item) {
            taken.insert(item.id)
            if item.isContainer {
                for child in children(of: item, in: space.items) where isEditable(child) { taken.insert(child.id) }
            }
        }
        return space.items.filter { taken.contains($0.id) }
    }

    /// The items that can be seen: not hidden, and not on a hidden layer.
    var visibleItems: [Item] { space?.visibleItems ?? [] }

    /// The items of the preview layer, drawn above the base layer: the items of a drag, and the item whose text is edited.
    public var previewItems: [Item] {
        guard let editing, !liftedItems.contains(where: { $0.id == editing.itemID }), let item = store.item(editing.itemID) else { return liftedItems }
        return liftedItems + [item]
    }

    /// The rectangle of an item as it is drawn now.
    public func displayedRect(of item: Item) -> Rect {
        liftedItems.first { $0.id == item.id }?.rect ?? item.rect
    }

    /// The rectangles of the outlines around the selection, on the board. While a drag copies, the outlines are around the copies.
    public var outlineRects: [Rect] {
        if let drag, !drag.duplicates.isEmpty { return liftedItems.map(\.rect) }
        return store.selectedItems.filter { $0.rect.isFinite }.map(displayedRect(of:))
    }

    /// The box with the handles, on the board. nil when no handles show: nothing that can change is selected, or a drag, a lasso or a text edit is going on.
    public var handleBox: Rect? {
        guard editing == nil, handleSize > 0 else { return nil }
        switch phase {
        case .moving, .lasso, .blocked, .drawing: return nil
        case .resizing: return resizeBox
        case .idle, .pressed: return ResizeMath.bounds(of: editableSelection.map(\.rect))
        }
    }

    /// The box with the handles on the canvas, with the gap of the outline around it. nil when no handles show.
    public var handleRectOnCanvas: Rect? {
        guard let box = handleBox else { return nil }
        let rect = controller.viewport.canvasRect(of: box)
        let gap = SelectionStyle.outlineGap
        return Rect(x: rect.x - gap, y: rect.y - gap, w: rect.w + 2 * gap, h: rect.h + 2 * gap)
    }

    /// The handles to draw, with their places on the canvas.
    public var handles: [(handle: ResizeHandle, x: Double, y: Double)] {
        guard let rect = handleRectOnCanvas else { return [] }
        return HandleLayout.visible(in: rect, handleSize: handleSize).map { handle in
            let p = HandleLayout.position(of: handle, in: rect)
            return (handle, p.x, p.y)
        }
    }

    // MARK: Pointer

    /// The pointer went down at a point of the canvas.
    public func pointerDown(atCanvasX x: Double, y: Double, modifiers: PointerModifiers = []) {
        switch tools.active {
        case .measure:
            measureDown(atBoard: board(fromCanvasX: x, y: y), modifiers: modifiers)
            return
        case .zoom:
            zoomPress(canvasX: x, y: y, out: modifiers.contains(.option))
            return
        case .hand:
            // The view pans with the drag. A press selects nothing.
            return
        default:
            break
        }
        resetGesture()
        let point = board(fromCanvasX: x, y: y)
        if let editing {
            if let rect = store.item(editing.itemID)?.rect, rect.contains(x: point.x, y: point.y) {
                phase = .blocked
                return
            }
            commitEdit()
        }
        switch tools.active {
        case .frame, .shape:
            drawPress(at: point)
            return
        case .text:
            textPress(at: point)
            return
        case .comment:
            commentPress(at: point)
            return
        default:
            break
        }
        if let handle = handle(atCanvasX: x, y: y), beginResize(handle, at: point) { return }
        let hit = HitTest.item(atX: point.x, y: point.y, among: controller.drawnItems, zoom: zoom, bandHeight: bandHeight)
        guard let hit else {
            lassoStart = LassoStart(board: point, base: modifiers.extendsSelection ? store.selection : [])
            if !modifiers.extendsSelection { store.clearSelection() }
            phase = .lasso
            refreshDistances()
            return
        }
        var release = Release.keep
        if modifiers.extendsSelection {
            if store.selection.contains(hit) { release = .remove(hit) } else { store.select(store.selection.union([hit])) }
        } else if !store.selection.contains(hit) {
            store.select([hit])
        } else if store.selection.count > 1 {
            release = .narrow(hit)
        }
        press = Press(id: hit, canvas: (x, y), release: release)
        phase = .pressed
        refreshDistances()
    }

    /// The pointer moved with the button down.
    public func pointerDragged(toCanvasX x: Double, y: Double, modifiers: PointerModifiers = []) {
        if measuring {
            measureDrag(toBoard: board(fromCanvasX: x, y: y), modifiers: modifiers)
            return
        }
        let point = board(fromCanvasX: x, y: y)
        switch phase {
        case .pressed:
            guard let press, hypot(x - press.canvas.x, y - press.canvas.y) >= Self.dragThreshold else { return }
            beginMove(modifiers: modifiers, at: board(fromCanvasX: press.canvas.x, y: press.canvas.y))
            if phase == .moving { updateMove(to: point, modifiers: modifiers) }
        case .moving:
            updateMove(to: point, modifiers: modifiers)
        case .resizing:
            updateResize(to: point, modifiers: modifiers)
        case .lasso:
            updateLasso(to: point)
        case .drawing:
            drawDrag(to: point)
        case .idle, .blocked:
            break
        }
    }

    /// The pointer went up.
    public func pointerUp(atCanvasX x: Double, y: Double, modifiers: PointerModifiers = []) {
        // The measured line stays on the canvas after the release.
        if measuring { return }
        switch phase {
        case .pressed:
            switch press?.release {
            case .narrow(let id)?: store.select([id])
            case .remove(let id)?: store.select(store.selection.subtracting([id]))
            case .keep?, nil: break
            }
        case .moving: commitMove()
        case .resizing: commitResize()
        case .drawing: drawEnd(to: board(fromCanvasX: x, y: y))
        case .lasso, .idle, .blocked: break
        }
        resetGesture()
        refreshDistances()
    }

    /// Stops the pointer action without a change of the document. A selection made by the lasso stays.
    public func cancelGesture() {
        resetGesture()
        refreshDistances()
    }

    /// Clears the state of a pointer action.
    func resetGesture() {
        phase = .idle
        press = nil
        drag = nil
        scale = nil
        lassoStart = nil
        drawStart = nil
        lasso = nil
        lifted = []
        liftedItems = []
        resizeBox = nil
        setGuides([])
    }

    /// The pointer moved without a button, for the cursor.
    public func hover(atCanvasX x: Double, y: Double) {
        let found = phase == .idle ? handle(atCanvasX: x, y: y) : nil
        if found != hoveredHandle { hoveredHandle = found }
    }

    func handle(atCanvasX x: Double, y: Double) -> ResizeHandle? {
        guard let rect = handleRectOnCanvas else { return nil }
        return HandleLayout.hit(atX: x, y: y, in: rect, handleSize: handleSize)
    }

    // MARK: Snapping

    /// True when the grid shows and drags snap to it. The grid is one switch: showing it and snapping to it go together.
    public var gridShown: Bool { snap.gridStep > 0 }

    /// Shows the grid and makes drags snap to it, or hides the grid and stops the grid snapping.
    public func setGridShown(_ shown: Bool) {
        snap.gridStep = shown ? gridStep : 0
    }

    /// The dots the canvas draws: none while the grid is off. They use the same step as the snapping.
    public var shownGridDots: GridDots {
        gridShown ? GridDots.make(viewport: controller.viewport, canvas: controller.size, baseStep: gridStep) : .empty
    }

    /// True when drags and resizes snap at all (to the grid, the edges and the spacing).
    public var snapsAtAll: Bool { snap.isOn }

    /// Turns the snapping of drags and resizes on or off. A drag can still suspend it with the Command key.
    public func setSnapsAtAll(_ on: Bool) {
        snap.isOn = on
    }

    /// The targets of a drag or resize. `rect` is the box that the moving items cover at the start: the column
    /// lines of frames count only when that box lies inside the frame.
    func targets(excluding ids: Set<ItemID>, around rect: Rect?) -> SnapTargets {
        let others = visibleItems.filter { !ids.contains($0.id) }
        return SnapTargets(gridStep: snap.gridStep, rects: others.map(\.rect),
                           guides: FrameGuides.snapLines(around: rect, in: others, guidesShown: guidesShown),
                           frameLines: FrameGrid.snapLines(around: rect, in: others),
                           spacing: snap.snapsToSpacing ? spacingStops : [])
    }

    /// Snaps a rectangle unless snapping is off or the Command key suspends it.
    func snapped(_ rect: Rect, motion: SnapMotion, targets: SnapTargets, modifiers: PointerModifiers) -> SnapResult? {
        guard snap.isOn, !modifiers.contains(.command) else { return nil }
        return Snapper.snap(rect, motion: motion, targets: targets, tolerance: snap.tolerance, zoom: zoom)
    }

    /// Sets the snap lines on the canvas. A new, non-empty set of lines counts as one tick for the haptic feedback.
    func setGuides(_ guides: [SnapGuide]) {
        if !guides.isEmpty, guides != lastGuides { snapTick += 1 }
        lastGuides = guides
        if controller.snapGuides != guides { controller.snapGuides = guides }
    }

    // MARK: Distances

    /// Shows the gaps from a rectangle to its neighbours while the Option key is held, and clears them otherwise.
    func showDistances(of rect: Rect?, among others: [Rect]) {
        guard !measuring, optionHeld || showsDistances, let rect else {
            if !controller.measures.isEmpty { controller.measures = [] }
            if !distanceLabels.isEmpty { distanceLabels = [] }
            return
        }
        let stops = spacingStops.filter { $0.value.isFinite && $0.value >= 0 }.sorted { $0.value < $1.value }
        var list = Neighbours.distances(of: rect, among: others, stops: stops)
        // A box inside a frame also shows its gaps to the frame edges. The selected frames do not count.
        let frames = visibleItems.compactMap { item -> Rect? in
            guard case .frame = item.content, !store.selection.contains(item.id) else { return nil }
            return item.rect
        }
        if let frame = Neighbours.frame(holding: rect, among: frames) {
            list += Neighbours.frameGaps(of: rect, in: frame, stops: stops)
        }
        controller.measures = list.map(\.measure)
        distanceLabels = list.map(DistanceLabel.init)
    }

    /// Shows the gaps of the selection again, after the selection, the keys or the settings changed.
    func refreshDistances() {
        switch phase {
        case .moving:
            guard let drag else { return }
            showDistances(of: drag.bounds.translated(dx: drag.delta.x, dy: drag.delta.y), among: drag.targets.rects)
        case .resizing:
            guard let scale else { return }
            showDistances(of: scale.result, among: scale.targets.rects)
        case .lasso, .blocked, .drawing:
            showDistances(of: nil, among: [])
        case .idle, .pressed:
            let selected = store.selectedItems.filter { $0.rect.isFinite }
            let box = ResizeMath.bounds(of: selected.map(\.rect))
            let chosen = Set(selected.map(\.id))
            showDistances(of: box, among: box == nil ? [] : visibleItems.filter { !chosen.contains($0.id) }.map(\.rect))
        }
    }

    // MARK: Commands

    /// Runs a command on the store. A command that fails leaves its error in `lastError`.
    @discardableResult
    func run(_ command: Command) -> Bool {
        do {
            let changed = try store.perform(command)
            lastError = nil
            return changed
        } catch {
            lastError = error
            return false
        }
    }
}

extension Rect {
    func translated(dx: Double, dy: Double) -> Rect { Rect(x: x + dx, y: y + dy, w: w, h: h) }
}

extension Space {
    /// The items that can be seen: not hidden, not on a hidden layer, and with a finite rectangle.
    /// The selection, the snapping, the guides and the drops all use this one rule.
    public var visibleItems: [Item] {
        let hiddenLayers = Set(layers.filter { !$0.visible }.map(\.id))
        return items.filter { !$0.hidden && !hiddenLayers.contains($0.layerID) && $0.rect.isFinite }
    }
}
