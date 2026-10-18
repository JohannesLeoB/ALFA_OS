import Foundation
import Observation
import GRDB
import AlfaKit

private struct ClickUpRoutingRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case routingID, ebene, richtung, appObjekt, clickUpObjekt, trigger, userScope, frequenz, noGo, clickUpRef, isActive = "aktiv", optin, updatedAt }

    static var databaseTableName: String { "clickUpRouting" }
    var routingID: String
    var ebene: String
    var richtung: String
    var appObjekt: String
    var clickUpObjekt: String
    var trigger: String
    var userScope: String
    var frequenz: String
    var noGo: String?
    var clickUpRef: String?
    var isActive: Bool
    var optin: Bool
    var updatedAt: Double

    init(from z: ClickUpRoutingZeile, now: Double) {
        routingID = z.routingID; ebene = z.ebene; richtung = z.richtung
        appObjekt = z.appObjekt; clickUpObjekt = z.clickUpObjekt; trigger = z.trigger
        userScope = z.userScope; frequenz = z.frequenz; noGo = z.noGo
        clickUpRef = z.clickUpRef; isActive = z.isActive; optin = z.optin; updatedAt = now
    }
    var toDomain: ClickUpRoutingZeile {
        ClickUpRoutingZeile(routingID: routingID, ebene: ebene, richtung: richtung, appObjekt: appObjekt,
            clickUpObjekt: clickUpObjekt, trigger: trigger, userScope: userScope, frequenz: frequenz,
            noGo: noGo, clickUpRef: clickUpRef, isActive: isActive, optin: optin)
    }
}

@MainActor
@Observable
public final class ClickUpRoutingStore {
    public private(set) var rowItems: [ClickUpRoutingZeile] = []
    private let db: GRDBDatabase

    public init(db: GRDBDatabase) { self.db = db }

    public func load() throws {
        let records = try db.read { try ClickUpRoutingRecord.fetchAll($0) }
        if records.isEmpty {
            try seedDefaults()
        } else {
            rowItems = records.map(\.toDomain)

            try ergaenzeFehlende()
        }
    }

    private func seedDefaults() throws {
        let ts = Date().timeIntervalSince1970
        try db.write { dbc in
            for z in ClickUpRoutingZeile.defaults { try ClickUpRoutingRecord(from: z, now: ts).insert(dbc) }
        }
        rowItems = ClickUpRoutingZeile.defaults
    }

    private func ergaenzeFehlende() throws {
        let vorhanden = Set(rowItems.map(\.routingID))
        let fehlende = ClickUpRoutingZeile.defaults.filter { vorhanden.contains($0.routingID) == false }
        guard fehlende.isEmpty == false else { return }
        let ts = Date().timeIntervalSince1970
        try db.write { dbc in for z in fehlende { try ClickUpRoutingRecord(from: z, now: ts).insert(dbc) } }
        rowItems.append(contentsOf: fehlende)
    }
}
