import Foundation

public enum SpaltenSichtbarkeit {
    private static let praefix = "v1:"

    public static func isVisible(ausRoh raw: String, standard: Set<String>) -> Set<String> {
        guard raw.hasPrefix(praefix) else { return standard }
        let rest = raw.dropFirst(praefix.count)
        if rest.isEmpty { return [] }
        return Set(rest.split(separator: ",").map(String.init))
    }

    public static func roh(aus isVisible: Set<String>) -> String {
        praefix + isVisible.sorted().joined(separator: ",")
    }

    public static func umgeschaltet(_ raw: String, feld: String, standard: Set<String>) -> String {
        var quantity = isVisible(ausRoh: raw, standard: standard)
        if quantity.contains(feld) { quantity.remove(feld) } else { quantity.insert(feld) }
        return roh(aus: quantity)
    }
}
