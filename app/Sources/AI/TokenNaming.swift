/// Picks the colour fields that still carry a default name, so that the assistant can suggest names for them.
public enum TokenNaming {
    /// True when the name is the default base, or the base followed by a number, such as "Color 3".
    public static func isUnnamed(_ name: String, base: String) -> Bool {
        if name == base {
            return true
        }
        guard name.hasPrefix(base + " ") else {
            return false
        }
        let number = name.dropFirst(base.count + 1)
        return !number.isEmpty && number.allSatisfy { ("0"..."9").contains($0) }
    }

    /// The unnamed fields as token candidates, in their order. The value is the hex text of the colour.
    public static func candidates(from fields: [(name: String, hex: String)], base: String) -> [TokenCandidate] {
        fields
            .filter { isUnnamed($0.name, base: base) }
            .map { TokenCandidate(id: $0.name, kind: "color", value: $0.hex) }
    }
}
