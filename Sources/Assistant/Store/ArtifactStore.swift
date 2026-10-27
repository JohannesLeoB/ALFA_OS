import Foundation

struct ArtifactStore: Sendable {
    private let root: URL

    init(root: URL) {
        self.root = root
    }

    var folder: URL { root.appendingPathComponent("erzeugnisse", isDirectory: true) }

    static func stamp(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func safeName(_ raw: String, at date: Date) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. \u{E4}\u{F6}\u{FC}\u{C4}\u{D6}\u{DC}\u{DF}"))
        var cleaned = String(raw.unicodeScalars.filter { allowed.contains($0) })
        while cleaned.contains("..") { cleaned = cleaned.replacingOccurrences(of: "..", with: ".") }
        let core = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return "\(stamp(date, "HHmmss"))_\(core.isEmpty ? "file" : core)"
    }

    @discardableResult
    func write(_ data: Data, name: String, at date: Date = Date()) throws -> URL {
        let day = folder.appendingPathComponent(Self.stamp(date, "yyyy-MM-dd"), isDirectory: true)
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        let target = day.appendingPathComponent(Self.safeName(name, at: date))
        try data.write(to: target, options: .atomic)
        return target
    }
}
