import Foundation

public enum Stage: String, Sendable, CaseIterable {
    case plan = "Vorplanung"
    case preprint = "Vorabzug"

    public init?(status: String?) {
        let value = (status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = Self.allCases.first(where: { $0.rawValue.lowercased() == value }) else { return nil }
        self = match
    }
}

public struct Spot: Sendable, Equatable {
    public var project: String
    public var drawing: String
    public var date: String
    public var initials: String

    public init(project: String, drawing: String, date: String, initials: String) {
        self.project = project
        self.drawing = drawing
        self.date = date
        self.initials = initials
    }

    public var path: [String] {
        ["Pl\u{E4}ne", ExportName.clean(drawing), ExportName.clean(date) + "_" + ExportName.clean(initials), "plan.json"]
    }
}

public enum ExportName {
    public static func make(project: [String: String], number: String, trade: String, variants: [String],
                            now: Date, ext: String) -> String? {
        let id = clean(number)
        guard !id.isEmpty, let stage = Stage(status: project["status"]) else { return nil }
        let variant = clean(variants.filter { !$0.isEmpty }.joined(separator: "-"))
        let gear = clean(trade)
        var parts = [day(project["date"], now: now), id]
        if !variant.isEmpty { parts.append(variant) }
        parts.append(stage == .preprint && !gear.isEmpty ? stage.rawValue + "_" + gear : stage.rawValue)
        return parts.joined(separator: "_") + "." + ext
    }

    static func day(_ typed: String?, now: Date) -> String {
        let pieces = (typed ?? "").split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        if pieces.count == 3, let d = pieces[0], let m = pieces[1], let y = pieces[2], (1...31).contains(d), (1...12).contains(m), y >= 0 {
            return String(format: "%02d%02d%02d", d, m, y % 100)
        }
        let c = Calendar.current.dateComponents([.day, .month, .year], from: now)
        return String(format: "%02d%02d%02d", c.day ?? 0, c.month ?? 0, (c.year ?? 0) % 100)
    }

    public static func clean(_ text: String) -> String {
        let kept = text.filter { !"/\\:".contains($0) }
        return kept.split(whereSeparator: \.isWhitespace).joined(separator: "-")
    }
}
