import Foundation
import GRDB
import MykilosKit

@MainActor
@Observable
public final class ClickUpTaskSignalMirrorStore {
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private let fetching: any ClickUpFetching

    public init(db: GRDBDatabase, fetching: any ClickUpFetching) {
        self.db = db
        self.fetching = fetching
    }

    public func refresh(listID: String) async throws {
        saveState = .saving
        do {
            let signale = try await fetching.taskSignale(listID: listID)
            try speichere(signale, listID: listID)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(String(describing: error))
            throw error
        }
    }

    public func load(listID: String) throws -> [ClickUpTaskSignale] {
        try db.read { grdb in
            try Row.fetchAll(grdb, sql: "SELECT * FROM clickUpTaskSignalCache WHERE listID = ? ORDER BY taskName", arguments: [listID])
                .map(Self.signal(from:))
        }
    }

    public func loadMitSignal(listID: String) throws -> [ClickUpTaskSignale] {
        try load(listID: listID).filter(\.hatMindestensEinSignal)
    }

    private func speichere(_ signale: [ClickUpTaskSignale], listID: String) throws {
        let ts = Date().timeIntervalSince1970
        try db.write { grdb in
            try grdb.execute(sql: "DELETE FROM clickUpTaskSignalCache WHERE listID = ?", arguments: [listID])
            for s in signale {
                try grdb.execute(
                    sql: """
                        INSERT INTO clickUpTaskSignalCache
                        (taskID, listID, taskName, evidenceGrade, blockerType, sourceSystem,
                         financeRelevant, reviewRequired, changeOrderRelevant, driveFolderURL,
                         clientName, mykilosProjectID, projectPhase, fetchedAt)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        s.taskID, s.listID, s.taskName,
                        s.evidenceGrade?.rawValue, s.blockerType?.rawValue, s.sourceSystem?.rawValue,
                        s.financeRelevant, s.reviewRequired, s.changeOrderRelevant,
                        s.driveFolderURL, s.clientName, s.mykilosProjectID, s.projectPhase?.rawValue,
                        ts
                    ])
            }
        }
    }

    private static func signal(from row: Row) -> ClickUpTaskSignale {
        ClickUpTaskSignale(
            taskID: row["taskID"], taskName: row["taskName"], listID: row["listID"],
            evidenceGrade: (row["evidenceGrade"] as Int?).flatMap(ClickUpEvidenceGrade.init(rawValue:)),
            blockerType: (row["blockerType"] as Int?).flatMap(ClickUpBlockerType.init(rawValue:)),
            sourceSystem: (row["sourceSystem"] as Int?).flatMap(ClickUpSourceSystem.init(rawValue:)),
            financeRelevant: row["financeRelevant"], reviewRequired: row["reviewRequired"],
            changeOrderRelevant: row["changeOrderRelevant"],
            driveFolderURL: row["driveFolderURL"], clientName: row["clientName"],
            mykilosProjectID: row["mykilosProjectID"],
            projectPhase: (row["projectPhase"] as Int?).flatMap(ClickUpProjectPhase.init(rawValue:))
        )
    }
}
