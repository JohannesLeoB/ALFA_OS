import GRDB

func renameColumns(_ db: Database, _ renames: [(table: String, from: String, to: String)]) throws {
    for rename in renames {
        let names = try db.columns(in: rename.table).map(\.name)
        guard names.contains(rename.from), !names.contains(rename.to) else { continue }
        try db.alter(table: rename.table) { $0.rename(column: rename.from, to: rename.to) }
    }
}
