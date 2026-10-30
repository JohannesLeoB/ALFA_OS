import Design
import Foundation
import Observation

public struct Snapshot: Sendable, Codable, Equatable {
    public var currentID: String
    public var lanes: [String: LaneMode]
    public var blob: BlobPlacement
    public var face: AssistantFace?
}

public enum AssistantFace: String, Sendable, Codable, CaseIterable {
    case eyes
    case orb
}

public enum BlobMode: String, Sendable, Codable {
    case menu
    case assistant
}

@MainActor
@Observable
public final class DeskState {
    let directory: AppDirectory
    public let measure: Measure
    public private(set) var face: AssistantFace
    public private(set) var currentID: String
    public private(set) var window: BlobSize
    private(set) var lanes: [String: LaneMode]
    private var limits: [String: AreaLimits] = [:]
    @ObservationIgnored private var dragStart: [Double]?
    @ObservationIgnored private var dragMoved = false
    @ObservationIgnored private var laid: (key: LayoutKey, widths: LaneWidths)?
    public private(set) var blob: BlobPlacement
    public private(set) var mode: BlobMode?
    public private(set) var awake = false
    private(set) var hovering = false
    private(set) var dragging = false
    public private(set) var draggedLane: LaneKind?
    public private(set) var hot = -1
    private(set) var ebb = false
    public private(set) var slowLane = false
    private(set) var stackEmpty: Bool?
    public var labelWidth = 0.0
    public var query = "" {
        didSet { if query != oldValue { hot = -1 } }
    }
    @ObservationIgnored private var ebbTask: Task<Void, Never>?
    @ObservationIgnored private var slowTask: Task<Void, Never>?
    @ObservationIgnored public var onChange: (@MainActor (Snapshot) -> Void)?

    public init(directory: AppDirectory, measure: Measure, window: BlobSize, snapshot: Snapshot? = nil, startID: String? = nil) {
        self.directory = directory
        self.measure = measure
        self.window = window
        let valid = snapshot.flatMap { directory.app($0.currentID) != nil ? $0 : nil }
        currentID = startID.flatMap { directory.app($0)?.id } ?? valid?.currentID ?? directory.first?.id ?? ""
        lanes = valid?.lanes ?? [:]
        blob = valid?.blob.normalized ?? BlobPlacement.home(measure: measure)
        face = valid?.face ?? .orb
    }

    public var current: AppEntry? { directory.app(currentID) }

    public var menuOpen: Bool { mode == .menu }

    public var assistantOpen: Bool { mode == .assistant }

    public var docked: Bool { blob.isDocked && mode == nil && !dragging }

    public var blobWidth: Double {
        if mode != nil { return measure.menuWidth }
        if docked { return measure.blobDock + (hovering ? ShellValues.dockHoverGrow : 0) }
        return awake ? BlobPlacement.awakeWidth(label: labelWidth) : measure.blobWidth
    }

    public func laneMode(_ id: String) -> LaneMode {
        lanes[id] ?? LaneMode(rest: measure.laneRest)
    }

    var rules: AreaRules {
        AreaRules(measure: measure, limits: limits[currentID] ?? AreaLimits())
    }

    public var minimum: [Double] { rules.minimum }

    public var laneDragging: Bool { draggedLane != nil }

    public var widths: LaneWidths {
        let key = LayoutKey(window: window.width, mode: laneMode(currentID), rules: rules, foldTrailing: stackEmpty == true && ebb)
        if let laid, laid.key == key { return laid.widths }
        let next = LaneLayoutEngine.widths(windowWidth: key.window, mode: key.mode, measure: measure, rules: key.rules, foldTrailing: key.foldTrailing)
        laid = (key, next)
        return next
    }

    public func limit(_ id: String, _ value: AreaLimits) {
        limits[id] = value
    }

    public var blobOrigin: BlobPoint {
        blob.origin(window: window, measure: measure)
    }

    var opensUpward: Bool {
        blob.opensUpward(window: window, measure: measure)
    }

    var snapshot: Snapshot {
        Snapshot(currentID: currentID, lanes: lanes, blob: blob, face: face)
    }

    private func changed() { onChange?(snapshot) }

    public func resize(_ size: BlobSize) {
        guard size != window else { return }
        window = size
    }

    public func select(_ id: String) {
        guard directory.app(id) != nil else { return }
        currentID = id
        close()
        changed()
    }

    func open(_ next: BlobMode) {
        mode = next
        awake = false
        hot = -1
        query = ""
    }

    public func close() {
        mode = nil
        hot = -1
        query = ""
    }

    public func toggleMenu() {
        menuOpen ? close() : open(.menu)
    }

    public func toggleAssistant() {
        assistantOpen ? close() : open(.assistant)
    }

    public func choose(face next: AssistantFace) {
        guard next != face else { return }
        face = next
        changed()
    }

    public func setHovering(_ value: Bool) { hovering = value }

    public func setAwake(_ value: Bool) {
        let next = value && mode == nil && !docked
        if next != awake { awake = next }
    }

    public func menuLines(title: (String) -> String) -> [AppMenuLine] {
        directory.menu(matching: query, title: title)
    }

    public func aim(_ hit: Int) { hot = hit }

    public func clearHot() { hot = -1 }

    public func moveHot(down: Bool, count: Int) {
        guard count > 0 else { return }
        let step = down != opensUpward ? 1 : -1
        let start = hot < 0 ? (step > 0 ? -1 : count) : hot
        hot = max(0, min(count - 1, start + step))
    }

    public func chooseHot(_ entries: [AppEntry]) {
        guard let entry = entries.indices.contains(hot) ? entries[hot] : entries.first else { return }
        select(entry.id)
    }

    public func beginBlobDrag() {
        dragging = true
        awake = false
        close()
    }

    public func dropBlob(center: BlobPoint, velocity: BlobPoint) {
        dragging = false
        blob = BlobPlacement.settle(dropAt: center, velocity: velocity, window: window, measure: measure)
        changed()
    }

    public func dragLane(_ lane: LaneKind, translation offset: Double) {
        guard lane != .center else { return }
        guard let start = dragStart else {
            dragStart = widths.all
            draggedLane = lane
            dragMoved = false
            var state = laneMode(currentID)
            if state.maximized != nil {
                state.maximized = nil
                lanes[currentID] = state
                changed()
            }
            if offset != 0 { dragLane(lane, translation: offset) }
            return
        }
        guard offset != 0 || dragMoved, draggedLane == lane else { return }
        dragMoved = true
        let direction: Double = lane == .leading ? 1 : -1
        lanes[currentID] = LaneLayoutEngine.drag(lane: lane, proposed: start[lane.index] + offset * direction, start: start,
                                                 mode: laneMode(currentID), measure: measure, rules: rules)
    }

    public func endLaneDrag() {
        guard dragStart != nil else { return }
        dragStart = nil
        draggedLane = nil
        if dragMoved { changed() }
        dragMoved = false
    }

    public func stepLane(_ lane: LaneKind, by delta: Double) {
        let start = widths.all
        lanes[currentID] = LaneLayoutEngine.drag(lane: lane, proposed: start[lane.index] + delta, start: start, mode: laneMode(currentID), measure: measure, rules: rules)
        changed()
    }

    public func resetLane() {
        lanes[currentID] = LaneMode(rest: measure.laneRest)
        changed()
    }

    public func toggleFold(_ lane: LaneKind) {
        lanes[currentID] = LaneLayoutEngine.toggleFold(lane: lane, mode: laneMode(currentID))
        changed()
    }

    public func openStrip(_ lane: LaneKind) {
        var state = laneMode(currentID)
        if state.maximized != nil {
            state.maximized = nil
        } else {
            state.folded[lane.index] = false
        }
        lanes[currentID] = state
        changed()
    }

    public func reveal(_ lane: LaneKind, in id: String? = nil) {
        let area = id ?? currentID
        var state = laneMode(area)
        guard state.folded[lane.index] else { return }
        state.folded[lane.index] = false
        lanes[area] = state
        changed()
    }

    public func toggleMaximize(_ lane: LaneKind) {
        lanes[currentID] = LaneLayoutEngine.toggleMaximize(lane: lane, mode: laneMode(currentID))
        changed()
    }

    public func stack(empty: Bool, still: Bool) {
        guard empty != stackEmpty else { return }
        stackEmpty = empty
        ebbTask?.cancel()
        slowTask?.cancel()
        if empty && !still {
            ebbTask = later(Tokens.Duration.ebbDelay) { model in
                model.ebb = true
                model.slow()
            }
        } else if empty {
            ebb = true
        } else if ebb {
            ebb = false
            slow()
        }
    }

    private func slow() {
        slowLane = true
        slowTask = later(Tokens.Duration.ebbSlow) { model in model.slowLane = false }
    }

    private func later(_ seconds: Double, _ work: @escaping @MainActor (DeskState) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            work(self)
        }
    }
}

private struct LayoutKey: Equatable {
    let window: Double
    let mode: LaneMode
    let rules: AreaRules
    let foldTrailing: Bool
}
