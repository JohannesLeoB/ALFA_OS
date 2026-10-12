import Foundation

public struct AufmassDokument: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public var aufmass: Aufmass
    public var erstelltAm: Date

    public var zusammenfassung: String

    public static let aktuelleVersion = 1

    public static let dateiEndung = "mykaufmass.json"

    public init(aufmass: Aufmass, erstelltAm: Date,
                formatVersion: Int = AufmassDokument.aktuelleVersion) {
        self.formatVersion = formatVersion
        self.aufmass = aufmass
        self.erstelltAm = erstelltAm
        self.zusammenfassung = Self.baueZusammenfassung(aufmass)
    }

    public func kodiere() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(self)
    }

    public var fileName: String {
        let title = aufmass.title.isEmpty ? "Aufmass" : aufmass.title
        let sicher = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return "Aufmass_\(aufmass.projectNumber)_\(sicher).\(Self.dateiEndung)"
    }

    public static func dekodiere(_ data: Data) throws -> AufmassDokument {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(AufmassDokument.self, from: data)
    }

    public static func istAufmassDatei(_ fileName: String) -> Bool {
        fileName.lowercased().hasSuffix(dateiEndung)
    }

    static func baueZusammenfassung(_ a: Aufmass) -> String {
        let rowItems = a.positionen.map { p in
            "• \(p.label): \(Masseinheit.mm.formatiere(p.meter))"
        }
        let header = "Aufmaß „\(a.title)“ · Projekt \(a.projectNumber) · \(a.count) Maße · " +
            "Summe \(Masseinheit.m.formatiere(a.gesamtMeter))"
        return ([header] + rowItems).joined(separator: "\n")
    }
}
