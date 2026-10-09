import ALFAcolorCore

extension BoardStore {
    /// Runs a context action on the selection. One action is one undo step. Returns true when the document changed.
    @discardableResult
    public func perform(_ action: ContextAction, groupTitle: String, groupID: ItemID = ItemID()) throws -> Bool {
        let items = selectedItems
        let allLocked = !items.isEmpty && items.allSatisfy(\.locked)
        return try perform(action.command(selection: selection, allLocked: allLocked, groupTitle: groupTitle, groupID: groupID))
    }

    /// Sets one field of the selection. One field is one undo step. Returns true when the document changed.
    /// Locked items keep their place: the field moves only the items that can move.
    @discardableResult
    public func perform(_ field: InspectorField, to points: Double) throws -> Bool {
        try perform(field, to: points, on: selection)
    }

    /// Sets one field of the given items, which need not be the selection any more. One undo step.
    /// A draft typed for items that were selected a moment ago is applied to them, not to the new selection.
    @discardableResult
    public func perform(_ field: InspectorField, to points: Double, on ids: Set<ItemID>) throws -> Bool {
        let lockedLayers = Set(activeSpace?.layers.filter(\.locked).map(\.id) ?? [])
        let items = InspectorEdit.movable(ids.compactMap { item($0) }, lockedLayers: lockedLayers)
        guard let command = InspectorEdit.command(field, to: points, items: items) else { return false }
        return try perform(command)
    }
}
