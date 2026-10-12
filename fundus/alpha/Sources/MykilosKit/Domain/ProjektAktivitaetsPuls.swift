import Foundation

public enum ProjektAktivitaetsPuls {
    public struct Tag: Equatable, Sendable {
        public let date: Date
        public let isActive: Bool
        public init(date: Date, isActive: Bool) { self.date = date; self.isActive = isActive }
    }

    public struct Streak: Equatable, Sendable {
        public let aktuelleTageInFolge: Int

        public let besteSerieJemals: Int

        public let tage: [Tag]
        public init(aktuelleTageInFolge: Int, besteSerieJemals: Int, tage: [Tag]) {
            self.aktuelleTageInFolge = aktuelleTageInFolge
            self.besteSerieJemals = besteSerieJemals
            self.tage = tage
        }
    }

    public static func streak(
        ereignisZeitpunkte: [Date], heute: Date, calendar: Calendar = .current, fensterTage: Int = 21
    ) -> Streak {
        let aktiveTage = Set(ereignisZeitpunkte.map { calendar.startOfDay(for: $0) })
        let heuteTag = calendar.startOfDay(for: heute)

        var aktuelle = 0
        var cursor = heuteTag
        if aktiveTage.contains(cursor) == false {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while aktiveTage.contains(cursor) {
            aktuelle += 1
            guard let vorher = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = vorher
        }

        let sortiert = aktiveTage.sorted()
        var beste = 0, lauf = 0
        var vorherigerTag: Date?
        for tag in sortiert {
            if let v = vorherigerTag, calendar.date(byAdding: .day, value: 1, to: v) == tag {
                lauf += 1
            } else {
                lauf = 1
            }
            beste = max(beste, lauf)
            vorherigerTag = tag
        }

        let tage: [Tag] = (0..<fensterTage).reversed().compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: heuteTag) else { return nil }
            return Tag(date: d, isActive: aktiveTage.contains(d))
        }

        return Streak(aktuelleTageInFolge: aktuelle, besteSerieJemals: beste, tage: tage)
    }
}

public enum ProjektFokusScore {
    public struct Result: Equatable, Sendable {
        public let score: Int
        public let tiefeBloeckeAnzahl: Int
        public let gesamtSekundenHeute: Double
        public init(score: Int, tiefeBloeckeAnzahl: Int, gesamtSekundenHeute: Double) {
            self.score = score
            self.tiefeBloeckeAnzahl = tiefeBloeckeAnzahl
            self.gesamtSekundenHeute = gesamtSekundenHeute
        }
    }

    public static func berechne(
        segmenteHeute: [TimeSegment], tiefSchwelleSekunden: Double = 20 * 60
    ) -> Result {
        let total = segmenteHeute.reduce(0.0) { $0 + $1.seconds }
        guard total > 0 else {
            return Result(score: 0, tiefeBloeckeAnzahl: 0, gesamtSekundenHeute: 0)
        }
        let depth = segmenteHeute.filter { $0.seconds >= tiefSchwelleSekunden }
        let tiefeSekunden = depth.reduce(0.0) { $0 + $1.seconds }
        let score = Int((tiefeSekunden / total * 100).rounded())
        return Result(score: score, tiefeBloeckeAnzahl: depth.count, gesamtSekundenHeute: total)
    }
}
