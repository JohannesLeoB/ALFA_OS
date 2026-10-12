import Foundation

public enum ProjektArchivMarker {
    public static let praefix = "🗄️ [Archiv] "

    public static func istArchiviert(_ name: String) -> Bool {
        name.hasPrefix(praefix)
    }

    public static func markiere(_ name: String) -> String {
        istArchiviert(name) ? name : praefix + name
    }

    public static func entmarkiere(_ name: String) -> String {
        istArchiviert(name) ? String(name.dropFirst(praefix.count)) : name
    }
}
