import ALFAcolorCore

/// The zone colour of a group. The names are tokens of the contract (`zone-*`); the colour itself comes from the theme.
public enum GroupTint {
    /// The colour of a group that names none.
    public static let standard = "zone-papier"

    /// The seven zone colours in the order of the inspector.
    public static let choices = ["zone-stein", "zone-pflaume", "zone-nacht", "zone-aprikose", "zone-rose", "zone-papier", "zone-schwarz"]
}

extension BoardStore {
    /// Sets the zone colour of the selected groups. One undo step. Returns false when no selected group changes.
    @discardableResult
    public func perform(groupTint tint: String) throws -> Bool {
        let commands: [Command] = selectedItems.compactMap { item in
            guard case .group(let title, let current) = item.content, current != tint else { return nil }
            return .setContent(item.id, .group(title: title, tint: tint))
        }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.zone.tint"))
    }
}
