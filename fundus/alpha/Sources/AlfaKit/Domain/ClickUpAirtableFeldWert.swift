import Foundation

public enum ClickUpAirtableFeldWert: Equatable, Sendable {
    case text(String)
    case zahl(Double)
    case date(Date)
    case dropdown(label: String)

    public static func ausClickUpRoh(
        typ: ClickUpAirtableSyncFeld.Typ, rawValue: String,
        dropdownOptionen: [(orderindex: Int, label: String)] = []
    ) -> ClickUpAirtableFeldWert? {
        let getrimmt = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard getrimmt.isEmpty == false else { return nil }
        switch typ {
        case .text:
            return .text(getrimmt)
        case .zahl:
            guard let value = Double(getrimmt) else { return nil }
            return .zahl(value)
        case .date:
            guard let millis = Double(getrimmt) else { return nil }
            return .date(Date(timeIntervalSince1970: millis / 1000))
        case .dropdown:
            guard let orderindex = Int(getrimmt),
                  let match = dropdownOptionen.first(where: { $0.orderindex == orderindex }) else { return nil }
            return .dropdown(label: match.label)
        }
    }

    public static func ausAirtableRoh(
        typ: ClickUpAirtableSyncFeld.Typ, text: String?, zahl: Double?
    ) -> ClickUpAirtableFeldWert? {
        switch typ {
        case .text:
            guard let getrimmt = text?.trimmingCharacters(in: .whitespacesAndNewlines), getrimmt.isEmpty == false else { return nil }
            return .text(getrimmt)
        case .dropdown:
            guard let getrimmt = text?.trimmingCharacters(in: .whitespacesAndNewlines), getrimmt.isEmpty == false else { return nil }
            return .dropdown(label: getrimmt)
        case .zahl:
            guard let value = zahl else { return nil }
            return .zahl(value)
        case .date:
            guard let getrimmt = text?.trimmingCharacters(in: .whitespacesAndNewlines), getrimmt.isEmpty == false,
                  let date = Self.dateFormat.date(from: getrimmt) else { return nil }
            return .date(date)
        }
    }

    public var kanonischerVergleichswert: String {
        switch self {
        case .text(let s): return s
        case .dropdown(let label): return label
        case .zahl(let d): return Self.zahlAlsString(d)
        case .date(let date): return Self.dateFormat.string(from: date)
        }
    }

    public var alsAirtableText: String? {
        switch self {
        case .text(let s): return s
        case .dropdown(let label): return label
        case .date(let date): return Self.dateFormat.string(from: date)
        case .zahl: return nil
        }
    }

    public var alsAirtableZahl: Double? {
        if case .zahl(let d) = self { return d }
        return nil
    }

    private static func zahlAlsString(_ d: Double) -> String {
        if d.isFinite, d == d.rounded(), abs(d) < 1e15 {
            return String(Int64(d))
        }
        return String(d)
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
