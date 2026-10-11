import Foundation

public enum Lane: String, Sendable, Codable, CaseIterable {
    case leading
    case center
    case trailing
}

public struct LaneState: Sendable, Codable, Equatable {
    public var leading: Double
    public var trailing: Double
    public var leadingFolded: Bool
    public var trailingFolded: Bool
    public var maximized: Lane?

    public init(rest: Double) {
        leading = rest
        trailing = rest
        leadingFolded = false
        trailingFolded = false
        maximized = nil
    }
}

public enum LaneNote: String, Sendable, Equatable {
    case trailingNarrowed
    case leadingNarrowed
    case trailingFolded
    case leadingFolded
}

public struct LaneWidths: Sendable, Equatable {
    public let leading: Double
    public let center: Double
    public let trailing: Double
    public let notes: [LaneNote]

    public func width(_ lane: Lane) -> Double {
        switch lane {
        case .leading: return leading
        case .center: return center
        case .trailing: return trailing
        }
    }
}

public enum LaneLayout {
    public static func widths(windowWidth: Double, state: LaneState, geometry g: ShellGeometry) -> LaneWidths {
        let available = windowWidth - 2 * g.margin - 2 * g.gap
        var leading = state.leadingFolded ? g.laneFolded : state.leading
        var trailing = state.trailingFolded ? g.laneFolded : state.trailing
        var notes: [LaneNote] = []
        switch state.maximized {
        case .center?:
            leading = g.laneFolded
            trailing = g.laneFolded
        case .leading?:
            trailing = g.laneFolded
            leading = max(g.laneMin, available - trailing - g.centerMin)
        case .trailing?:
            leading = g.laneFolded
            trailing = max(g.laneMin, available - leading - g.centerMin)
        case nil:
            func need() -> Double { leading + trailing + g.centerMin }
            if need() > available, trailing > g.laneMin {
                let next = max(g.laneMin, trailing - (need() - available))
                if next < trailing { notes.append(.trailingNarrowed) }
                trailing = next
            }
            if need() > available, leading > g.laneMin {
                let next = max(g.laneMin, leading - (need() - available))
                if next < leading { notes.append(.leadingNarrowed) }
                leading = next
            }
            if need() > available, trailing > g.laneFolded {
                trailing = g.laneFolded
                notes.append(.trailingFolded)
            }
            if need() > available, leading > g.laneFolded {
                leading = g.laneFolded
                notes.append(.leadingFolded)
            }
        }
        return LaneWidths(leading: leading, center: available - leading - trailing, trailing: trailing, notes: notes)
    }

    public static func drag(lane: Lane, proposed: Double, state: LaneState, windowWidth: Double, geometry g: ShellGeometry) -> LaneState {
        guard lane != .center, state.maximized == nil else { return state }
        var next = state
        let current = widths(windowWidth: windowWidth, state: state, geometry: g)
        let other = lane == .leading ? current.trailing : current.leading
        let room = windowWidth - 2 * g.margin - 2 * g.gap - other - g.centerMin
        let folded = proposed < g.foldAt
        let value = min(g.laneMax, max(g.laneMin, min(proposed, room))).rounded()
        if lane == .leading {
            next.leadingFolded = folded
            if !folded { next.leading = value }
        } else {
            next.trailingFolded = folded
            if !folded { next.trailing = value }
        }
        return next
    }

    public static func reset(lane: Lane, state: LaneState, geometry g: ShellGeometry) -> LaneState {
        var next = state
        next.maximized = nil
        if lane == .leading {
            next.leading = g.laneRest
            next.leadingFolded = false
        } else if lane == .trailing {
            next.trailing = g.laneRest
            next.trailingFolded = false
        }
        return next
    }

    public static func toggleFold(lane: Lane, state: LaneState, geometry g: ShellGeometry) -> LaneState {
        guard lane != .center else {
            var next = state
            next.maximized = nil
            return next
        }
        var next = state
        next.maximized = nil
        if lane == .leading {
            next.leadingFolded.toggle()
            if !next.leadingFolded, next.leading < g.laneMin { next.leading = g.laneRest }
        } else {
            next.trailingFolded.toggle()
            if !next.trailingFolded, next.trailing < g.laneMin { next.trailing = g.laneRest }
        }
        return next
    }

    public static func toggleMaximize(lane: Lane, state: LaneState) -> LaneState {
        var next = state
        next.maximized = state.maximized == lane ? nil : lane
        return next
    }
}
