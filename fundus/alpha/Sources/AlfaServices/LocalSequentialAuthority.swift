import Foundation
import GRDB
import AlfaKit

private struct VergebeneNummerRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case appFormat, jahr, laufendeNummer, status, source = "quelle", updatedAt }

    static var databaseTableName: String { "vergebeneNummern" }
    var appFormat: String
    var jahr: Int
    var laufendeNummer: Int
    var status: String
    var source: String?
    var updatedAt: Double

    var projektnummer: Projektnummer { Projektnummer(jahr: jahr, laufendeNummer: laufendeNummer) }
}

public final class LocalSequentialAuthority: NumberAuthority, @unchecked Sendable {
    private let db: GRDBDatabase
    private let aktiveNummern: @Sendable () async -> [Projektnummer]
    private let now: @Sendable () -> Date

    public init(
        db: GRDBDatabase,
        aktiveNummern: @escaping @Sendable () async -> [Projektnummer],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.db = db
        self.aktiveNummern = aktiveNummern
        self.now = now
    }

    private func alleBekannten() async throws -> [Projektnummer] {
        let isActive = await aktiveNummern()
        let gespeichert = try db.read { try VergebeneNummerRecord.fetchAll($0) }.map(\.projektnummer)
        return isActive + gespeichert
    }

    public func nextProjektnummer(jahr: Int) async throws -> Projektnummer {
        Projektnummer.next(jahr: jahr, vorhandene: try await alleBekannten())
    }

    public func nextProjektnummerKollisionsfrei(
        jahr: Int, istExternKollidiert: (Projektnummer) -> Bool, maxVersuche: Int = 25
    ) async throws -> Projektnummer {
        let bekannte = try await alleBekannten()
        var ausgeschlossen: [Projektnummer] = []
        for _ in 0..<maxVersuche {
            let kandidat = Projektnummer.next(jahr: jahr, vorhandene: bekannte + ausgeschlossen)
            if istExternKollidiert(kandidat) == false { return kandidat }
            ausgeschlossen.append(kandidat)
        }
        throw NumberAuthorityError.keineKollisionsfreieNummerGefunden(jahr: jahr, versuche: maxVersuche)
    }

    public func nextAndReserve(jahr: Int) async throws -> Projektnummer {
        let isActive = await aktiveNummern()
        let ts = now().timeIntervalSince1970
        return try db.write { dbc in
            let gespeichert = try VergebeneNummerRecord.fetchAll(dbc).map(\.projektnummer)
            let next = Projektnummer.next(jahr: jahr, vorhandene: isActive + gespeichert)
            try VergebeneNummerRecord(
                appFormat: next.appFormat, jahr: next.jahr, laufendeNummer: next.laufendeNummer,
                status: "reserviert", source: nil, updatedAt: ts).insert(dbc)
            return next
        }
    }

    public func nextAndReserveKollisionsfrei(
        jahr: Int, istExternKollidiert: (Projektnummer) -> Bool, maxVersuche: Int = 25
    ) async throws -> Projektnummer {
        for _ in 0..<maxVersuche {
            let kandidat = try await nextAndReserve(jahr: jahr)
            if istExternKollidiert(kandidat) == false { return kandidat }
        }
        throw NumberAuthorityError.keineKollisionsfreieNummerGefunden(jahr: jahr, versuche: maxVersuche)
    }

    public func isVergeben(_ number: Projektnummer) async throws -> Bool {
        try await alleBekannten().contains(number)
    }

    public func reserve(_ number: Projektnummer) async throws {
        guard try await isVergeben(number) == false else {
            throw NumberAuthorityError.bereitsVergeben(number)
        }
        try speichere(number, status: "reserviert", quelle: nil)
    }

    public func bindFromExternal(source: String, number: Projektnummer) async throws {
        guard try await isVergeben(number) == false else {
            throw NumberAuthorityError.bereitsVergeben(number)
        }
        try speichere(number, status: "extern", quelle: source)
    }

    public func archiviere(_ number: Projektnummer) throws {
        let bestehend = try db.read { try VergebeneNummerRecord.fetchOne($0, key: number.appFormat) }
        if bestehend?.status == "extern" { return }
        try speichere(number, status: "archiviert", quelle: nil)
    }

    private func speichere(_ number: Projektnummer, status: String, quelle: String?) throws {
        let ts = now().timeIntervalSince1970
        try db.write { dbc in
            try VergebeneNummerRecord(
                appFormat: number.appFormat, jahr: number.jahr, laufendeNummer: number.laufendeNummer,
                status: status, source: quelle, updatedAt: ts).save(dbc)
        }
    }

    public func gespeicherteNummern() throws -> [Projektnummer] {
        try db.read { try VergebeneNummerRecord.order(Column("jahr").desc, Column("laufendeNummer").desc).fetchAll($0) }
            .map(\.projektnummer)
    }
}
