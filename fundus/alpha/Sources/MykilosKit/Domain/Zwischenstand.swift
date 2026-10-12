import Foundation

public struct Zwischenstand: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case area = "bereich", wann, haltung }

    public let area: String

    public let wann: Date

    public let haltung: [String: String]

    public init(area: String, wann: Date, haltung: [String: String]) {
        self.area = area
        self.wann = wann
        self.haltung = haltung
    }

    public var weiterBei: String? {
        for key in ["auswahl", "blatt", "suchtext", "filter", "modus"] {
            if let value = haltung[key], !value.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Weiter bei \(value)"
            }
        }
        return nil
    }
}

public struct ZwischenstandAblage: Sendable {
    private let lesen: @Sendable (String) -> Data?
    private let schreiben: @Sendable (String, Data?) -> Void

    public init(lesen: @escaping @Sendable (String) -> Data?,
                schreiben: @escaping @Sendable (String, Data?) -> Void) {
        self.lesen = lesen
        self.schreiben = schreiben
    }

    private func key(_ area: String) -> String { "zwischenstand.\(area)" }

    public func ablegen(area: String, haltung: [String: String], wann: Date) {
        let gefuellt = haltung.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !gefuellt.isEmpty else {
            schreiben(key(area), nil)
            return
        }
        let state = Zwischenstand(area: area, wann: wann, haltung: gefuellt)
        schreiben(key(area), try? JSONEncoder().encode(state))
    }

    public func holen(area: String) -> Zwischenstand? {
        guard let data = lesen(key(area)) else { return nil }
        return try? JSONDecoder().decode(Zwischenstand.self, from: data)
    }

    public func verbrauchen(area: String) {
        schreiben(key(area), nil)
    }

    public func irgendwoEinStand(areas: [String]) -> Bool {
        areas.contains { holen(area: $0) != nil }
    }
}

public extension ZwischenstandAblage {
    static func lokal(_ defaults: UserDefaults = .standard) -> ZwischenstandAblage {
        ZwischenstandAblage(
            lesen: { defaults.data(forKey: $0) },
            schreiben: { key, data in
                if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        )
    }

    static func imSpeicher() -> ZwischenstandAblage {
        let kiste = SpeicherKiste()
        return ZwischenstandAblage(lesen: { kiste.lesen($0) },
                                   schreiben: { kiste.schreiben($0, $1) })
    }
}

private final class SpeicherKiste: @unchecked Sendable {
    private var content: [String: Data] = [:]
    private let sperre = NSLock()
    func lesen(_ k: String) -> Data? { sperre.lock(); defer { sperre.unlock() }; return content[k] }
    func schreiben(_ k: String, _ d: Data?) {
        sperre.lock(); defer { sperre.unlock() }
        if let d { content[k] = d } else { content.removeValue(forKey: k) }
    }
}
