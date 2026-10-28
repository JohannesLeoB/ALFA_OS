import Shell
import SwiftUI

enum PaneTitle {
    case key(String)
    case verbatim(String)

    func text(_ appearance: Appearance) -> Text {
        switch self {
        case .key(let key): appearance.text(key)
        case .verbatim(let value): Text(verbatim: value)
        }
    }

    func string(_ appearance: Appearance) -> String {
        switch self {
        case .key(let key): appearance.string(key)
        case .verbatim(let value): value
        }
    }
}

@MainActor
protocol Pane {
    var stackEmpty: Bool { get }
    var badge: Int { get }
    var opened: Int { get }
    var limits: AreaLimits { get }
    var toast: AnyView? { get }
    func ownsHead(_ lane: LaneKind) -> Bool
    func title(_ lane: LaneKind) -> PaneTitle?
    func name(_ lane: LaneKind) -> PaneTitle?
    func hidesTitle(_ lane: LaneKind) -> Bool
    func marks(_ lane: LaneKind, height: Double) -> AnyView?
    func content(_ lane: LaneKind) -> AnyView
}

extension Pane {
    var stackEmpty: Bool { false }

    var badge: Int { 0 }

    var opened: Int { 0 }

    var limits: AreaLimits { AreaLimits() }

    var toast: AnyView? { nil }

    func ownsHead(_ lane: LaneKind) -> Bool { false }

    func title(_ lane: LaneKind) -> PaneTitle? { nil }

    func name(_ lane: LaneKind) -> PaneTitle? { title(lane) }

    func hidesTitle(_ lane: LaneKind) -> Bool { false }

    func marks(_ lane: LaneKind, height: Double) -> AnyView? { nil }
}
