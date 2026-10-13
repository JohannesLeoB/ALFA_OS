import Foundation
import Observation

public struct ShellSnapshot: Sendable, Codable, Equatable {
    public var currentID: String
    public var lanes: [String: LaneState]
    public var blob: BlobPlacement
    public var openGroups: [String]
}

@MainActor
@Observable
public final class ShellModel {
    public let directory: AppDirectory
    public let geometry: ShellGeometry
    public private(set) var currentID: String
    public private(set) var window: Size
    public private(set) var lanes: [String: LaneState]
    public private(set) var blob: BlobPlacement
    public private(set) var openGroups: Set<String>
    public private(set) var menuOpen = false
    public private(set) var assistantOpen = false
    public private(set) var hovering = false
    public var query = ""
    @ObservationIgnored public var onChange: (@MainActor (ShellSnapshot) -> Void)?

    public init(directory: AppDirectory, geometry: ShellGeometry, window: Size, snapshot: ShellSnapshot? = nil) {
        self.directory = directory
        self.geometry = geometry
        self.window = window
        let valid = snapshot.flatMap { directory.app($0.currentID) != nil ? $0 : nil }
        currentID = valid?.currentID ?? directory.first?.id ?? ""
        lanes = valid?.lanes ?? [:]
        blob = valid?.blob ?? BlobPlacement.home(geometry: geometry)
        openGroups = Set(valid?.openGroups ?? [])
    }

    public var current: AppEntry? { directory.app(currentID) }

    public var phase: BlobPhase {
        if menuOpen { return .menuOpen }
        return hovering ? .awake : .rest
    }

    public var blobWidth: Double {
        phase == .rest ? geometry.blobWidth : geometry.blobAwakeWidth
    }

    public func laneState(_ id: String) -> LaneState {
        lanes[id] ?? LaneState(rest: geometry.laneRest)
    }

    public var widths: LaneWidths {
        LaneLayout.widths(windowWidth: window.width, state: laneState(currentID), geometry: geometry)
    }

    public var blobOrigin: Point {
        blob.origin(window: window, geometry: geometry)
    }

    public var snapshot: ShellSnapshot {
        ShellSnapshot(currentID: currentID, lanes: lanes, blob: blob, openGroups: openGroups.sorted())
    }

    private func changed() { onChange?(snapshot) }

    public func resize(_ size: Size) {
        guard size != window else { return }
        window = size
    }

    public func select(_ id: String) {
        guard directory.app(id) != nil else { return }
        currentID = id
        menuOpen = false
        query = ""
        changed()
    }

    public func toggleMenu() {
        assistantOpen = false
        menuOpen.toggle()
        if !menuOpen { query = "" }
    }

    public func closeMenu() {
        menuOpen = false
        query = ""
    }

    public func toggleAssistant() {
        menuOpen = false
        query = ""
        assistantOpen.toggle()
    }

    public func closeAssistant() { assistantOpen = false }

    public func setHovering(_ value: Bool) { hovering = value }

    public func isGroupOpen(_ group: AppGroup) -> Bool {
        !query.isEmpty || openGroups.contains(group.id) || group.contains(currentID)
    }

    public func toggleGroup(_ group: AppGroup) {
        let open = isGroupOpen(group)
        if open { openGroups.remove(group.id) } else { openGroups.insert(group.id) }
        changed()
    }

    public func dragLane(_ lane: Lane, proposed: Double) {
        lanes[currentID] = LaneLayout.drag(lane: lane, proposed: proposed, state: laneState(currentID), windowWidth: window.width, geometry: geometry)
    }

    public func endLaneDrag() { changed() }

    public func resetLane(_ lane: Lane) {
        lanes[currentID] = LaneLayout.reset(lane: lane, state: laneState(currentID), geometry: geometry)
        changed()
    }

    public func toggleFold(_ lane: Lane) {
        lanes[currentID] = LaneLayout.toggleFold(lane: lane, state: laneState(currentID), geometry: geometry)
        changed()
    }

    public func toggleMaximize(_ lane: Lane) {
        lanes[currentID] = LaneLayout.toggleMaximize(lane: lane, state: laneState(currentID))
        changed()
    }

    public func dropBlob(center: Point, velocity: Point) {
        blob = BlobPlacement.settle(dropAt: center, velocity: velocity, window: window, geometry: geometry)
        changed()
    }
}
