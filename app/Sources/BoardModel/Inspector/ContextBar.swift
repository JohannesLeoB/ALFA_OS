import ALFAcolorCore

/// An action of the context bar that floats over the selection.
public enum ContextAction: String, CaseIterable, Sendable {
    case alignLeft, alignTop, alignCenter, row, grid, pile, sameSize, group, ungroup, toFront, forward, backward, lock

    /// The arrangement of `arrange()` that the action runs. Nil for grouping and locking.
    public var arrangement: Arrangement? {
        switch self {
        case .alignLeft: .alignLeft
        case .alignTop: .alignTop
        case .alignCenter: .alignCenter
        case .row: .row
        case .grid: .grid
        case .pile: .pile
        case .sameSize: .sameSize
        case .group, .ungroup, .toFront, .forward, .backward, .lock: nil
        }
    }

    /// The key of the label in the string catalog. The lock label says what the next click does.
    public func labelKey(allLocked: Bool) -> String {
        switch self {
        case .alignLeft: "context.alignLeft"
        case .alignTop: "context.alignTop"
        case .alignCenter: "context.alignCenter"
        case .row: "context.row"
        case .grid: "context.grid"
        case .pile: "context.pile"
        case .sameSize: "context.sameSize"
        case .group: "context.group"
        case .ungroup: "context.ungroup"
        case .toFront: "context.toFront"
        case .forward: "context.forward"
        case .backward: "context.backward"
        case .lock: allLocked ? "context.unlock" : "context.lock"
        }
    }

    /// The key of the tooltip: the name of the undo step the action makes.
    public func helpKey(allLocked: Bool) -> String {
        if let arrangement { return "undo.arrange.\(arrangement.rawValue)" }
        if self == .group { return "undo.group" }
        if self == .ungroup { return "undo.ungroup" }
        if let move = stackMove { return "undo.reorder.\(move.rawValue)" }
        return allLocked ? "undo.unlock" : "undo.lock"
    }

    /// The move of the paint order that the action runs. Nil for the other actions.
    public var stackMove: StackMove? {
        switch self {
        case .toFront: .toFront
        case .forward: .forward
        case .backward: .backward
        default: nil
        }
    }

    /// Whether the bar offers the action for a selection of `count` items. Arrangements, groups and moves in the
    /// stack need two items; locking needs one; ungrouping needs a group in the selection.
    public func isOffered(count: Int, hasGroup: Bool) -> Bool {
        switch self {
        case .lock: count >= 1
        case .ungroup: hasGroup
        default: count >= 2
        }
    }

    /// The command that runs the action on the selection. `groupTitle` and `groupID` are used by grouping only.
    public func command(selection: Set<ItemID>, allLocked: Bool, groupTitle: String, groupID: ItemID) -> Command {
        if let arrangement { return .arrange(arrangement, selection) }
        if let stackMove { return .reorder(selection, stackMove) }
        if self == .lock { return .setLocked(selection, !allLocked) }
        if self == .ungroup { return .ungroup(selection) }
        return .group(selection, title: groupTitle, groupID: groupID)
    }
}

/// The context bar: which actions it offers for a selection.
public enum ContextBar {
    /// True when the selection holds a group, which grouping can take apart.
    public static func hasGroup(_ items: [Item]) -> Bool {
        items.contains { item in
            if case .group = item.content { return true }
            return false
        }
    }

    /// The actions for a selection of `count` items, in the order of the bar.
    public static func actions(count: Int, hasGroup: Bool = false) -> [ContextAction] {
        ContextAction.allCases.filter { $0.isOffered(count: count, hasGroup: hasGroup) }
    }
}
