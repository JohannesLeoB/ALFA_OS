import Foundation
import Observation
import SwiftUI
import GRDB
import MykilosKit

@MainActor
@Observable
public final class WidgetBoardStore {
    public let boardID: String
    public private(set) var instances: [WidgetInstance] = []
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private let defaultLayout: () -> [WidgetInstance]

    public init(
        boardID: String,
        db: GRDBDatabase,
        defaultLayout: @escaping () -> [WidgetInstance] = { [] }
    ) {
        self.boardID       = boardID
        self.db            = db
        self.defaultLayout = defaultLayout
    }

    public func load() throws {
        let records = try db.read { dbConn in
            try WidgetInstanceRecord
                .filter(Column("boardID") == boardID)
                .order(Column("position"))
                .fetchAll(dbConn)
        }
        if records.isEmpty {
            instances = defaultLayout()
            try save()
        } else {
            instances = records.map(\.toDomain)

            try reconcileCanonicalWidgetsOnce()

            try ensureWidgetOnce(.warenkorb, size: .wide)

            try ensureWidgetOnce(.barcode, size: .medium)
            try ensureWidgetOnce(.rechner, size: .medium)

            try ensureWidgetOnce(.heuteAnstehend, size: .full)

            try ensureWidgetOnce(.nachfassen, size: .wide)
        }
    }

    private func ensureWidgetOnce(_ kind: WidgetKind, size: WidgetSize) throws {
        guard defaultLayout().contains(where: { $0.kind == kind }) else { return }
        let marker = "\(boardID)#\(kind.rawValue)"
        let alreadyDone = try db.read { dbConn in
            try Row.fetchOne(dbConn,
                sql: "SELECT 1 FROM reconciledBoards WHERE boardID = ?",
                arguments: [marker]) != nil
        }
        guard !alreadyDone else { return }
        if !instances.contains(where: { $0.kind == kind }) {
            let next = (instances.map(\.position).max() ?? -1) + 1
            instances.append(WidgetInstance(kind: kind, size: size, position: next))
            try save()
        }
        try db.write { dbConn in
            try dbConn.execute(
                sql: "INSERT OR IGNORE INTO reconciledBoards (boardID) VALUES (?)",
                arguments: [marker])
        }
    }

    private func reconcileCanonicalWidgetsOnce() throws {
        let alreadyDone = try db.read { dbConn in
            try Row.fetchOne(dbConn,
                sql: "SELECT 1 FROM reconciledBoards WHERE boardID = ?",
                arguments: [boardID]) != nil
        }
        guard !alreadyDone else { return }
        let presentKinds = Set(instances.map(\.kind))
        let missing = defaultLayout().filter { !presentKinds.contains($0.kind) }
        if !missing.isEmpty {
            var nextPosition = (instances.map(\.position).max() ?? -1) + 1
            for template in missing {
                instances.append(WidgetInstance(kind: template.kind, size: template.size, position: nextPosition))
                nextPosition += 1
            }
            try save()
        }
        try db.write { dbConn in
            try dbConn.execute(
                sql: "INSERT OR IGNORE INTO reconciledBoards (boardID) VALUES (?)",
                arguments: [boardID])
        }
    }

    public func save() throws {
        saveState = .saving
        let boardID = self.boardID
        let snapshot = instances
        do {
            try db.write { dbConn in

                try WidgetInstanceRecord
                    .filter(Column("boardID") == boardID)
                    .deleteAll(dbConn)
                for instance in snapshot {
                    try WidgetInstanceRecord(from: instance, boardID: boardID)
                        .insert(dbConn)
                }
            }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) throws {
        instances.move(fromOffsets: fromOffsets, toOffset: toOffset)
        reindex()
        try save()
    }

    public func remove(id: UUID) throws {
        instances.removeAll { $0.id == id }
        reindex()
        try save()
    }

    public func add(kind: WidgetKind, size: WidgetSize = .medium) throws {
        let next = (instances.map(\.position).max() ?? -1) + 1
        instances.append(WidgetInstance(kind: kind, size: size, position: next))
        try save()
    }

    public func toggle(id: UUID) throws {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].isVisible.toggle()
        try save()
    }

    public func aufDesignVorgabeZuruecksetzen() throws {
        instances = defaultLayout()
        reindex()
        try save()
    }

    public func resize(id: UUID, to size: WidgetSize) throws {
        guard let i = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[i].size = size
        try save()
    }

    private func reindex() {
        for i in instances.indices { instances[i].position = i }
    }
}

@MainActor
@Observable
public final class NoteStore {
    public let boardID: String
    public private(set) var body: String = ""
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private var noteID: UUID = UUID()
    private var hasLoaded = false
    private var dirty = false

    public var hasUnsavedChanges: Bool { dirty }

    public init(boardID: String, db: GRDBDatabase) {
        self.boardID = boardID
        self.db      = db
    }

    public func load() throws {
        guard !hasLoaded else { return }
        if let record = try db.read({ dbConn in
            try NoteRecord
                .filter(Column("boardID") == boardID)
                .fetchOne(dbConn)
        }) {
            body   = record.body
            noteID = UUID(uuidString: record.id) ?? UUID()
        }
        hasLoaded = true
    }

    public func update(_ newBody: String) {
        body      = newBody
        saveState = .idle
        dirty     = true
    }

    public func save() throws {
        saveState = .saving
        do {
            let record = NoteRecord(id: noteID, boardID: boardID, body: body)
            try db.write { dbConn in
                try record.save(dbConn)
            }
            saveState = .saved(Date())
            dirty = false
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
