import ALFAcolorCore

/// An action of the context bar that floats over the selection.
public enum ContextAction: String, CaseIterable, Sendable {
    case alignLeft, alignTop, alignCenter, row, grid, pile, sameSize, group, lock

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
        case .group, .lock: nil
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
        case .lock: allLocked ? "context.unlock" : "context.lock"
        }
    }

    /// The key of the tooltip: the name of the undo step the action makes.
    public func helpKey(allLocked: Bool) -> String {
        if let arrangement { return "undo.arrange.\(arrangement.rawValue)" }
        if self == .group { return "undo.group" }
        return allLocked ? "undo.unlock" : "undo.lock"
    }

    /// Whether the bar offers the action for `count` selected items. Arrangements and groups need two items; locking needs one.
    public func isOffered(count: Int) -> Bool {
        self == .lock ? count >= 1 : count >= 2
    }

    /// The command that runs the action on the selection. `groupTitle` and `groupID` are used by grouping only.
    public func command(selection: Set<ItemID>, allLocked: Bool, groupTitle: String, groupID: ItemID) -> Command {
        if let arrangement { return .arrange(arrangement, selection) }
        if self == .lock { return .setLocked(selection, !allLocked) }
        return .group(selection, title: groupTitle, groupID: groupID)
    }
}

/// The context bar: which actions it offers for a selection.
public enum ContextBar {
    /// The actions for a selection of `count` items, in the order of the bar.
    public static func actions(count: Int) -> [ContextAction] {
        ContextAction.allCases.filter { $0.isOffered(count: count) }
    }
}
