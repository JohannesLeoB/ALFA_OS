import Foundation

/// The licences of the library. A licence is free when the work may be used in a package without asking.
/// The names are the values that a source keeps; the free ones are the list below, compared without case.
/// Any other text is not free, including a licence typed by hand: it is shown as given, and it is a warning.
public enum License {
    /// Own work. Its value is "eigen", as `Source.via` uses it too.
    public static let own = "eigen"
    /// The licence is not known. Not free.
    public static let unknown = "unbekannt"

    /// The choices of the inspector, in order. The last one is free text.
    public static let presets: [String] = ["eigen", "MIT", "Apache-2.0", "BSD", "ISC", "CC0", "CC-BY", "CC-BY-SA", "CC-BY-NC", "unbekannt"]

    /// The free names, in lower case.
    static let freeNames: Set<String> = Set(["eigen", "MIT", "Apache-2.0", "BSD", "ISC", "CC0", "CC-BY", "CC-BY-SA"].map { $0.lowercased() })

    /// True when the text names a free licence. Nil, empty and unknown texts are not free.
    public static func isFree(_ text: String?) -> Bool {
        guard let key = normalized(text) else { return false }
        return freeNames.contains(key)
    }

    /// True for own work: a source with the via "eigen" or the licence "eigen". No source at all is own work too,
    /// because an item that came in without an origin was made here.
    public static func isOwn(_ source: Source?) -> Bool {
        guard let source else { return true }
        return source.via.lowercased() == own || normalized(source.license) == own
    }

    /// True when the item may be used freely: own work, or a source with a free licence.
    public static func isFreeItem(_ source: Source?) -> Bool {
        guard let source else { return true }
        return isOwn(source) || isFree(source.license)
    }

    /// The text without spaces at the ends and in lower case. Nil for nil and for empty text.
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }
}
