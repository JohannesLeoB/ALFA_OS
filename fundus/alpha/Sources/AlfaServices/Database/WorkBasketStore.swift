import Foundation
import Observation
import SwiftUI
import GRDB
import AlfaKit

struct WorkBasketRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", inhaltsArt, version, statusJSON, erstellt }

    static var databaseTableName: String { "workBaskets" }

    var id: String
    var projectNumber: String
    var inhaltsArt: String
    var version: Int
    var statusJSON: String
    var erstellt: Double

    init(from basket: WorkBasket) throws {
        id = basket.id.raw
        projectNumber = basket.projectNumber
        inhaltsArt = basket.inhaltsArt.rawValue
        version = basket.version
        statusJSON = try WorkBasketStatusCoding.encode(basket.status)
        erstellt = basket.erstellt.timeIntervalSince1970
    }

    func toDomain(picks: [any Pick]) throws -> WorkBasket {
        WorkBasket(
            id: WorkBasketID(id),
            projectNumber: projectNumber,
            inhaltsArt: InhaltsArt(rawValue: inhaltsArt) ?? .gemischt,
            picks: picks,
            version: version,
            status: try WorkBasketStatusCoding.decode(statusJSON),
            erstellt: Date(timeIntervalSince1970: erstellt)
        )
    }
}

struct WorkBasketPickRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "workBasketPicks" }

    var id: String
    var basketID: String
    var position: Int
    var matrix: String
    var objektID: String
    var snapshotJSON: String
    var inhaltJSON: String

    init(basketID: String, position: Int, pick: any Pick, content: PickContent) throws {
        self.id = "\(basketID)#\(position)"
        self.basketID = basketID
        self.position = position
        self.matrix = pick.matrix.rawValue
        self.objektID = pick.objektID.raw
        self.snapshotJSON = try Self.encodeSnapshot(pick.snapshot)
        self.inhaltJSON = try Self.encodeInhalt(content)
    }

    func toDomain() throws -> any Pick {
        BasicPick(
            matrix: CatalogMatrix(rawValue: matrix) ?? .sonstige,
            objektID: CatalogObjectID(objektID),
            snapshot: try Self.decodeSnapshot(snapshotJSON),
            content: try Self.decodeInhalt(inhaltJSON)
        )
    }

    private static func encodeSnapshot(_ snapshot: PickSnapshot) throws -> String {
        let data = try JSONEncoder().encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeSnapshot(_ json: String) throws -> PickSnapshot {
        try JSONDecoder().decode(PickSnapshot.self, from: Data(json.utf8))
    }

    private static func encodeInhalt(_ content: PickContent) throws -> String {
        let data = try JSONEncoder().encode(content)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeInhalt(_ json: String) throws -> PickContent {
        try JSONDecoder().decode(PickContent.self, from: Data(json.utf8))
    }
}

enum WorkBasketStatusCoding {
    private struct Wire: Codable {
        var fall: String
        var elternID: String?
    }

    static func encode(_ status: WorkBasketStatus) throws -> String {
        let wire: Wire
        switch status {
        case .kalkulation:
            wire = Wire(fall: "kalkulation", elternID: nil)
        case .bestaetigt:
            wire = Wire(fall: "bestaetigt", elternID: nil)
        case .nachtrag(let zu):
            wire = Wire(fall: "nachtrag", elternID: zu.raw)
        case .gutschrift(let zu):
            wire = Wire(fall: "gutschrift", elternID: zu.raw)
        }
        let data = try JSONEncoder().encode(wire)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ json: String) throws -> WorkBasketStatus {
        let wire = try JSONDecoder().decode(Wire.self, from: Data(json.utf8))
        switch wire.fall {
        case "bestaetigt":
            return .bestaetigt
        case "nachtrag":
            guard let elternID = wire.elternID else { throw WorkBasketStoreError.korrupterStatus }
            return .nachtrag(zu: WorkBasketID(elternID))
        case "gutschrift":
            guard let elternID = wire.elternID else { throw WorkBasketStoreError.korrupterStatus }
            return .gutschrift(zu: WorkBasketID(elternID))
        default:
            return .kalkulation
        }
    }
}

public enum WorkBasketStoreError: Error, Sendable, Equatable {
    case korrupterStatus

    case unerlaubterUebergang

    case nichtGefunden
}

@MainActor
@Observable
public final class WorkBasketStore {
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    @discardableResult
    public func speichere(_ basket: WorkBasket) async throws -> WorkBasket {
        saveState = .saving
        do {
            var aufgeloest: [(pick: any Pick, content: PickContent)] = []
            for pick in basket.picks {
                aufgeloest.append((pick, try await pick.resolve()))
            }
            let basketID = basket.id.raw
            let headRecord = try WorkBasketRecord(from: basket)
            let pickRecords = try aufgeloest.enumerated().map { index, entry in
                try WorkBasketPickRecord(basketID: basketID, position: index, pick: entry.pick, content: entry.content)
            }
            try db.write { conn in
                try headRecord.save(conn)
                try WorkBasketPickRecord
                    .filter(Column("basketID") == basketID)
                    .deleteAll(conn)
                for record in pickRecords {
                    try record.insert(conn)
                }
            }
            saveState = .saved(Date())
            return basket
        } catch {
            saveState = .failed(String(describing: error))
            throw error
        }
    }

    @discardableResult
    public func wechsleStatus(basketID: WorkBasketID, zu neuerStatus: WorkBasketStatus) async throws -> WorkBasket {
        guard var basket = try load(id: basketID) else {
            throw WorkBasketStoreError.nichtGefunden
        }
        guard basket.status.darfWechselnZu(neuerStatus) else {
            throw WorkBasketStoreError.unerlaubterUebergang
        }
        basket.status = neuerStatus
        return try await speichere(basket)
    }

    private var anhaengenLaeuft = false

    @discardableResult
    public func fuegePositionHinzu(
        projectNumber: String,
        label: String,
        quantity: Int,
        ekEinzel: Double?,
        vkEinzel: Double?,
        objektID: String,
        attribute: [String: String] = [:]
    ) async throws -> WorkBasket {
        while anhaengenLaeuft { await Task.yield() }
        anhaengenLaeuft = true
        defer { anhaengenLaeuft = false }
        let pick = BasicPick(
            matrix: .artikel,
            objektID: CatalogObjectID(objektID),
            snapshot: PickSnapshot(label: label, quantity: max(1, quantity),
                                   ekEinzel: ekEinzel, vkEinzel: vkEinzel, attribute: attribute))
        let vorhandene = try alle(projectNumber: projectNumber)
        if var basket = vorhandene.max(by: { $0.erstellt < $1.erstellt }) {
            if let idx = basket.picks.firstIndex(where: { ($0 as? BasicPick)?.objektID == CatalogObjectID(objektID) }),
               let alt = basket.picks[idx] as? BasicPick {
                let s = alt.snapshot
                basket.picks[idx] = BasicPick(
                    matrix: alt.matrix, objektID: alt.objektID,
                    snapshot: PickSnapshot(label: s.label, quantity: s.quantity + max(1, quantity),
                                           ekEinzel: s.ekEinzel, vkEinzel: s.vkEinzel, attribute: s.attribute),
                    content: alt.content)
            } else {
                basket.picks.append(pick)
            }
            return try await speichere(basket)
        }
        let neu = WorkBasket(
            id: WorkBasketID("WK-\(projectNumber)-\(UUID().uuidString.prefix(8))"),
            projectNumber: projectNumber,
            inhaltsArt: .artikel,
            picks: [pick])
        return try await speichere(neu)
    }

    public func load(id: WorkBasketID) throws -> WorkBasket? {
        try db.read { conn in
            guard let head = try WorkBasketRecord.fetchOne(conn, key: id.raw) else { return nil }
            let pickRecords = try WorkBasketPickRecord
                .filter(Column("basketID") == id.raw)
                .order(Column("position"))
                .fetchAll(conn)
            let picks = try pickRecords.map { try $0.toDomain() }
            return try head.toDomain(picks: picks)
        }
    }

    public func alle(projectNumber: String? = nil) throws -> [WorkBasket] {
        try db.read { conn in
            var request = WorkBasketRecord.all()
            if let projectNumber, !projectNumber.isEmpty {
                request = request.filter(Column("projektNummer") == projectNumber)
            }
            let heads = try request.fetchAll(conn)
            return try heads.map { head in
                let pickRecords = try WorkBasketPickRecord
                    .filter(Column("basketID") == head.id)
                    .order(Column("position"))
                    .fetchAll(conn)
                let picks = try pickRecords.map { try $0.toDomain() }
                return try head.toDomain(picks: picks)
            }
        }
    }
}
