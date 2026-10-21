import Foundation
import Observation

public enum BlobMode: String, Sendable, Codable {
    case menu
    case assistant
}

public enum AssistantFace: String, Sendable, Codable, CaseIterable {
    case eyes
    case orb
}

public struct ShellSnapshot: Sendable, Codable, Equatable {
    public var currentID: String
    public var lanes: [String: LaneState]
    public var blob: BlobPlacement
    public var face: AssistantFace?
}

@MainActor
@Observable
public final class ShellModel {
    public let directory: AppDirectory
    public let geometry: ShellGeometry
    public private(set) var currentID: String
    public private(set) var window: Size
    public private(set) var lanes: [String: LaneState]
    @ObservationIgnored private var dragStart: [Double]?
    public private(set) var blob: BlobPlacement
    public private(set) var mode: BlobMode?
    public private(set) var awake = false
    public private(set) var hovering = false
    public private(set) var dragging = false
    public private(set) var laneDragging = false
    public private(set) var hot = -1
    public private(set) var ebb = false
    public private(set) var slowLane = false
    public private(set) var stackEmpty: Bool?
    public private(set) var face: AssistantFace
    public var labelWidth = 0.0
    public var query = "" {
        didSet { if query != oldValue { hot = -1 } }
    }
    @ObservationIgnored private var ebbTask: Task<Void, Never>?
    @ObservationIgnored private var slowTask: Task<Void, Never>?
    @ObservationIgnored public var onChange: (@MainActor (ShellSnapshot) -> Void)?

    public init(directory: AppDirectory, geometry: ShellGeometry, window: Size, snapshot: ShellSnapshot? = nil, start: StartView = .lastOpen) {
        self.directory = directory
        self.geometry = geometry
        self.window = window
        let valid = snapshot.flatMap { directory.app($0.currentID) != nil ? $0 : nil }
        currentID = start.appID.flatMap { directory.app($0)?.id } ?? valid?.currentID ?? directory.first?.id ?? ""
        lanes = valid?.lanes ?? [:]
        blob = valid?.blob.normalized ?? BlobPlacement.home(geometry: geometry)
        face = .orb
    }

    public var current: AppEntry? { directory.app(currentID) }

    public var menuOpen: Bool { mode == .menu }

    public var assistantOpen: Bool { mode == .assistant }

    public var docked: Bool { blob.isDocked && mode == nil && !dragging }

    public var phase: BlobPhase {
        if menuOpen { return .menuOpen }
        return awake ? .awake : .rest
    }

    public var blobWidth: Double {
        if mode != nil { return geometry.menuWidth }
        if docked { return geometry.blobDock + (hovering ? SheetValues.dockHoverGrow : 0) }
        return awake ? BlobPlacement.awakeWidth(label: labelWidth) : geometry.blobWidth
    }

    public func laneState(_ id: String) -> LaneState {
        lanes[id] ?? LaneState(rest: geometry.laneRest)
    }

    public var rules: AreaRules {
        AreaRules.rules(for: currentID, geometry: geometry)
    }

    public var widths: LaneWidths {
        LaneLayout.widths(windowWidth: window.width, state: laneState(currentID), geometry: geometry, rules: rules, foldTrailing: stackEmpty == true && ebb)
    }

    public var maximized: Bool { laneState(currentID).maximized != nil }

    public var blobOrigin: Point {
        blob.origin(window: window, geometry: geometry)
    }

    public var opensUpward: Bool {
        blob.opensUpward(window: window, geometry: geometry)
    }

    public var snapshot: ShellSnapshot {
        ShellSnapshot(currentID: currentID, lanes: lanes, blob: blob, face: face)
    }

    private func changed() { onChange?(snapshot) }

    public func resize(_ size: Size) {
        guard size != window else { return }
        window = size
    }

    public func select(_ id: String) {
        guard directory.app(id) != nil else { return }
        currentID = id
        close()
        changed()
    }

    public func open(_ next: BlobMode) {
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

    public func closeMenu() {
        if menuOpen { close() }
    }

    public func toggleAssistant() {
        assistantOpen ? close() : open(.assistant)
    }

    public func closeAssistant() {
        if assistantOpen { close() }
    }

    public func setHovering(_ value: Bool) { hovering = value }

    public func setAwake(_ value: Bool) {
        let next = value && mode == nil && !docked
        if next != awake { awake = next }
    }

    public func setFace(_ value: AssistantFace) {
        face = value
        changed()
    }

    public func menuLines(title: (String) -> String) -> [MenuLine] {
        directory.menu(matching: query, title: title)
    }

    public private(set) var openGroups: Set<String> = []

    public func isGroupOpen(_ group: AppGroup) -> Bool {
        !query.isEmpty || openGroups.contains(group.id) || group.contains(currentID)
    }

    public func toggleGroup(_ group: AppGroup) {
        if isGroupOpen(group) { openGroups.remove(group.id) } else { openGroups.insert(group.id) }
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

    public func dropBlob(center: Point, velocity: Point) {
        dragging = false
        blob = BlobPlacement.settle(dropAt: center, velocity: velocity, window: window, geometry: geometry)
        changed()
    }

    public func cancelBlobDrag() { dragging = false }

    public func dragLane(_ lane: Lane, proposed: Double) {
        let start = dragStart ?? widths.all
        dragStart = start
        laneDragging = true
        lanes[currentID] = LaneLayout.drag(lane: lane, proposed: proposed, start: start, state: laneState(currentID), geometry: geometry, rules: rules)
    }

    public func endLaneDrag() {
        dragStart = nil
        laneDragging = false
        changed()
    }

    public func stepLane(_ lane: Lane, by delta: Double) {
        let start = widths.all
        lanes[currentID] = LaneLayout.drag(lane: lane, proposed: start[lane.index] + delta, start: start, state: laneState(currentID), geometry: geometry, rules: rules)
        changed()
    }

    public func resetLane(_ lane: Lane) {
        lanes[currentID] = LaneLayout.reset(rest: geometry.laneRest)
        changed()
    }

    public func toggleFold(_ lane: Lane) {
        lanes[currentID] = LaneLayout.toggleFold(lane: lane, state: laneState(currentID))
        changed()
    }

    public func openStrip(_ lane: Lane) {
        var state = laneState(currentID)
        if state.maximized != nil {
            state.maximized = nil
        } else {
            state.folded[lane.index] = false
        }
        lanes[currentID] = state
        changed()
    }

    public func toggleMaximize(_ lane: Lane) {
        lanes[currentID] = LaneLayout.toggleMaximize(lane: lane, state: laneState(currentID))
        changed()
    }

    public func stack(empty: Bool, still: Bool) {
        guard empty != stackEmpty else { return }
        stackEmpty = empty
        ebbTask?.cancel()
        slowTask?.cancel()
        if empty && !still {
            ebbTask = later(Design.Duration.ebbDelay) { model in
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
        slowTask = later(Design.Duration.ebbSlow) { model in model.slowLane = false }
    }

    private func later(_ seconds: Double, _ work: @escaping @MainActor (ShellModel) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            work(self)
        }
    }
}
