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
    @discardableResult
    public func perform(_ field: InspectorField, to points: Double) throws -> Bool {
        guard let command = InspectorEdit.command(field, to: points, items: selectedItems) else { return false }
        return try perform(command)
    }
}
