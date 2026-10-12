import Foundation

public struct Kostenstelle: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String

    public let clockodoServiceID: Int?

    public init(id: String? = nil, name: String, clockodoServiceID: Int? = nil) {
        self.id = id ?? name
        self.name = name
        self.clockodoServiceID = clockodoServiceID
    }

    public static let defaults: [Kostenstelle] = [
        Kostenstelle(name: "Angebotserstellung", clockodoServiceID: 1384970),
        Kostenstelle(name: "Bestellungen", clockodoServiceID: 1384972),
        Kostenstelle(name: "Interne Arbeitszeit", clockodoServiceID: 1384967),
        Kostenstelle(name: "Konzeption, Recherche, Planung CAD", clockodoServiceID: 1418402),
        Kostenstelle(name: "Kundenberatung", clockodoServiceID: 1430450),
        Kostenstelle(name: "Ortstermin Baustelle", clockodoServiceID: 1418401),
        Kostenstelle(name: "Projektabrechnung", clockodoServiceID: 1384971),
        Kostenstelle(name: "Projektbesprechung", clockodoServiceID: 1535780),
        Kostenstelle(name: "Projektmanagement", clockodoServiceID: 1384969),
        Kostenstelle(name: "Versand", clockodoServiceID: 1384973)
    ]
}

public struct ClockodoKunde: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, name, isActive = "aktiv" }

    public let id: Int
    public let name: String
    public let isActive: Bool
    public init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct ClockodoProjekt: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, kundeID, name, isActive = "aktiv" }

    public let id: Int
    public let kundeID: Int
    public let name: String
    public let isActive: Bool
    public init(id: Int, kundeID: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.kundeID = kundeID
        self.name = name
        self.isActive = isActive
    }
}

public struct ClockodoLeistung: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, name, isActive = "aktiv" }

    public let id: Int
    public let name: String
    public let isActive: Bool
    public init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct ClockodoEintrag: Identifiable, Sendable, Equatable {
    public let id: Int
    public let kundeID: Int
    public let projektID: Int?
    public let leistungID: Int
    public let text: String?
    public let start: Date
    public let dauerSekunden: Int

    public let billable: Bool

    public init(id: Int, kundeID: Int, projektID: Int?, leistungID: Int,
                text: String?, start: Date, dauerSekunden: Int, billable: Bool = true) {
        self.id = id; self.kundeID = kundeID; self.projektID = projektID
        self.leistungID = leistungID; self.text = text; self.start = start
        self.dauerSekunden = dauerSekunden; self.billable = billable
    }

    public var dauerText: String {
        if dauerSekunden >= 3600 {
            return String(format: "%.1f h", Double(dauerSekunden) / 3600)
        }
        return "\(Int((Double(dauerSekunden) / 60).rounded())) min"
    }
}

public enum ClockodoZeitraum: String, CaseIterable, Sendable, Identifiable {
    case heute, woche, monat
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .heute: return "Heute"
        case .woche: return "Diese Woche"
        case .monat: return "Dieser Monat"
        }
    }

    public func spanne(jetzt: Date, kalender: Calendar = ClockodoZeitraum.deKalender) -> (seit: Date, bis: Date) {
        let seit: Date
        switch self {
        case .heute:
            seit = kalender.startOfDay(for: jetzt)
        case .woche:
            seit = kalender.dateInterval(of: .weekOfYear, for: jetzt)?.start ?? kalender.startOfDay(for: jetzt)
        case .monat:
            seit = kalender.dateInterval(of: .month, for: jetzt)?.start ?? kalender.startOfDay(for: jetzt)
        }
        return (seit, jetzt)
    }
    public static var deKalender: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = .current
        return c
    }
}

public struct ActiveTimer: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, runSince, pausedAccumulatedSeconds, isPaused, segmentStartedAt }

    public var projectNumber: String
    public var projectTitle: String
    public var kostenstelle: String

    public var runSince: Date

    public var pausedAccumulatedSeconds: Double
    public var isPaused: Bool

    public var segmentStartedAt: Date

    public init(
        projectNumber: String, projectTitle: String, kostenstelle: String,
        runSince: Date, pausedAccumulatedSeconds: Double = 0, isPaused: Bool = false,
        segmentStartedAt: Date
    ) {
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.kostenstelle = kostenstelle
        self.runSince = runSince
        self.pausedAccumulatedSeconds = pausedAccumulatedSeconds
        self.isPaused = isPaused
        self.segmentStartedAt = segmentStartedAt
    }

    public func elapsedSeconds(now: Date) -> Double {
        pausedAccumulatedSeconds + (isPaused ? 0 : max(0, now.timeIntervalSince(runSince)))
    }
}

public struct TimeSegmentDraft: Codable, Identifiable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, startedAt, endedAt, seconds }

    public let id: UUID
    public var projectNumber: String
    public var projectTitle: String
    public var kostenstelle: String
    public var startedAt: Date
    public var endedAt: Date
    public var seconds: Double

    public init(
        id: UUID = UUID(), projectNumber: String, projectTitle: String, kostenstelle: String,
        startedAt: Date, endedAt: Date, seconds: Double
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.kostenstelle = kostenstelle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.seconds = seconds
    }
}

public struct TimeSegment: Codable, Identifiable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", projectTitle = "projektTitel", kostenstelle, startedAt, endedAt, seconds, bookedAt }

    public let id: UUID
    public var projectNumber: String
    public var projectTitle: String
    public var kostenstelle: String
    public var startedAt: Date
    public var endedAt: Date
    public var seconds: Double
    public var bookedAt: Date

    public init(
        id: UUID = UUID(), projectNumber: String, projectTitle: String, kostenstelle: String,
        startedAt: Date, endedAt: Date, seconds: Double, bookedAt: Date = Date()
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.kostenstelle = kostenstelle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.seconds = seconds
        self.bookedAt = bookedAt
    }

    public init(fromDraft draft: TimeSegmentDraft, bookedAt: Date = Date()) {
        self.init(
            id: draft.id, projectNumber: draft.projectNumber, projectTitle: draft.projectTitle,
            kostenstelle: draft.kostenstelle, startedAt: draft.startedAt, endedAt: draft.endedAt,
            seconds: draft.seconds, bookedAt: bookedAt)
    }
}

public struct ClockodoZeitZeile: Identifiable, Equatable, Sendable {
    public enum Herkunft: Equatable, Sendable { case timer, manuell }

    public let id: UUID
    public var projectNumber: String
    public var projectTitle: String
    public var kostenstelle: String
    public var startedAt: Date
    public var endedAt: Date
    public var text: String
    public var billable: Bool
    public let herkunft: Herkunft

    public let timerSekunden: Double?

    public var clockodoKundeID: Int?
    public var clockodoProjektID: Int?
    public var clockodoLeistungID: Int?

    public var seconds: Double { timerSekunden ?? max(0, endedAt.timeIntervalSince(startedAt)) }

    public init(
        id: UUID = UUID(), projectNumber: String = "", projectTitle: String = "", kostenstelle: String = "",
        startedAt: Date = Date(), endedAt: Date = Date(), text: String = "", billable: Bool = true,
        herkunft: Herkunft = .manuell, timerSekunden: Double? = nil,
        clockodoKundeID: Int? = nil, clockodoProjektID: Int? = nil, clockodoLeistungID: Int? = nil
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.kostenstelle = kostenstelle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.text = text
        self.billable = billable
        self.herkunft = herkunft
        self.timerSekunden = timerSekunden
        self.clockodoKundeID = clockodoKundeID
        self.clockodoProjektID = clockodoProjektID
        self.clockodoLeistungID = clockodoLeistungID
    }

    public init(ausSegment segment: TimeSegment) {
        self.init(
            id: segment.id, projectNumber: segment.projectNumber, projectTitle: segment.projectTitle,
            kostenstelle: segment.kostenstelle, startedAt: segment.startedAt, endedAt: segment.endedAt,
            herkunft: .timer, timerSekunden: segment.seconds)
    }

    public nonisolated static func timerRows(
        ausSegmenten segmente: [TimeSegment], mindestdauerSekunden: Double = 60
    ) -> [ClockodoZeitZeile] {
        segmente.map(ClockodoZeitZeile.init(ausSegment:))
            .filter { $0.seconds >= mindestdauerSekunden }
            .sorted { $0.startedAt > $1.startedAt }
    }
}

public enum ZielkontingentHerkunft: String, Codable, Sendable {
    case auto
    case manuell

    case auftrag
}

public enum StundenkontingentRechner {
    public static let attributSchluessel = "stundenKontingent"

    public static func sum(aus positionen: [(attribute: [String: String], quantity: Int)]) -> Double {
        positionen.reduce(0.0) { sum, position in
            guard let roh = position.attribute[attributSchluessel],
                  let stunden = Double(roh), stunden > 0 else { return sum }
            return sum + stunden * Double(max(1, position.quantity))
        }
    }
}

public struct ProjectZielkontingent: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case projectNumber = "projektNummer", zielStunden, herkunft, updatedAt }

    public var id: String { projectNumber }
    public var projectNumber: String
    public var zielStunden: Double
    public var herkunft: ZielkontingentHerkunft
    public var updatedAt: Date

    public init(projectNumber: String, zielStunden: Double, herkunft: ZielkontingentHerkunft = .manuell, updatedAt: Date = Date()) {
        self.projectNumber = projectNumber
        self.zielStunden = zielStunden
        self.herkunft = herkunft
        self.updatedAt = updatedAt
    }
}

public enum TimerFormat {
    public static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    public static func human(_ seconds: Double) -> String {
        let totalMin = Int((seconds / 60).rounded())
        if totalMin < 60 { return "\(totalMin) Min" }
        let h = totalMin / 60, m = totalMin % 60
        return m == 0 ? "\(h) Std" : "\(h) Std \(m) Min"
    }
}
