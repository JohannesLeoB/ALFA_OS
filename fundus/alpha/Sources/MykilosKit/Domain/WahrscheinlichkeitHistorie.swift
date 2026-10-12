import Foundation

public struct WahrscheinlichkeitHistorie: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let prozent: Int
        public let date: Date
        public init(prozent: Int, date: Date) {
            self.prozent = min(max(prozent, 0), 100)
            self.date = date
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = Array(entries.prefix(5))
    }

    public var aktuell: Int? { entries.first?.prozent }

    public func hinzugefuegt(_ prozent: Int, am date: Date, kalender: Calendar = .current) -> WahrscheinlichkeitHistorie {
        let neu = Entry(prozent: prozent, date: date)
        if let erster = entries.first,
           erster.prozent == neu.prozent,
           kalender.isDate(erster.date, inSameDayAs: date) {
            return self
        }
        return WahrscheinlichkeitHistorie(entries: [neu] + entries)
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public var airtableText: String {
        entries
            .map { "\($0.prozent) % (\(Self.dateFormat.string(from: $0.date)))" }
            .joined(separator: " · ")
    }

    public static func parse(_ text: String) -> WahrscheinlichkeitHistorie {
        let teile = text.components(separatedBy: "·")
        let entries: [Entry] = teile.compactMap { teil in

            let trimmed = teil.trimmingCharacters(in: .whitespaces)
            guard let prozentStr = trimmed.split(separator: "%").first?.trimmingCharacters(in: .whitespaces),
                  let prozent = Int(prozentStr),
                  let klammerAuf = trimmed.firstIndex(of: "("),
                  let klammerZu = trimmed.firstIndex(of: ")") else { return nil }
            let datumStr = String(trimmed[trimmed.index(after: klammerAuf)..<klammerZu])
            guard let date = dateFormat.date(from: datumStr) else { return nil }
            return Entry(prozent: prozent, date: date)
        }
        return WahrscheinlichkeitHistorie(entries: entries)
    }
}
