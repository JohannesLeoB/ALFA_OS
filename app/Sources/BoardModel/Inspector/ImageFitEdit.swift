import ALFAcolorCore

extension BoardStore {
    /// Sets how the selected images sit in their areas. The other items keep their place. One undo step.
    /// Returns false when no selected image changes.
    @discardableResult
    public func perform(imageFit fit: ImageFit) throws -> Bool {
        let commands: [Command] = selectedItems.compactMap { item in
            guard case .image(let assetID, let crop, _) = item.content else { return nil }
            return .setContent(item.id, .image(assetID: assetID, crop: crop, fit: fit))
        }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.fit"))
    }
}
