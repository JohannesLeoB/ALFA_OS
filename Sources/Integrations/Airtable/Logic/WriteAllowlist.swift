import Core

public struct WriteAllowlist: Sendable {
    private let writable: [String: Set<String>]
    private let deletable: [String: Set<String>]

    init(writable: [String: Set<String>], deletable: [String: Set<String>] = [:]) {
        self.writable = Self.pruned(writable)
        self.deletable = Self.pruned(deletable)
    }

    static public func standard() -> WriteAllowlist {
        func value(_ key: String) -> String { CompanyValues.valueOrEmpty(key) }
        let entries: [(String, [String])] = [
            (value("airtable.base.golden_customers"), [value("airtable.table.golden_customers"), value("airtable.table.contacts")]),
            (value("airtable.base.projects"), [
                value("airtable.table.projects"), value("airtable.table.projects_extra_1"),
                value("airtable.table.projects_extra_2"), value("airtable.table.projects_extra_3"),
                value("airtable.table.lead_cards"), value("airtable.table.document_register"),
            ]),
            (value("airtable.base.questionnaire_intake"), [
                value("airtable.table.questionnaire_intake"), value("airtable.table.questionnaire_extra"),
            ]),
            (value("airtable.base.data_flow"), ["Datenstrom-Log"]),
            (value("airtable.base.article_catalog"), [value("airtable.table.article_catalog")]),
            (value("airtable.base.own_catalog"), [
                value("airtable.table.own_catalog_positions"), value("airtable.table.own_catalog_hourly_rates"),
            ]),
            (value("airtable.base.estimation_model"), [value("airtable.table.estimation_model")]),
            (value("airtable.base.media_library"), [value("airtable.table.media_staging")]),
        ]
        let merged = Dictionary(entries.map { ($0.0, Set($0.1)) }, uniquingKeysWith: { $0.union($1) })
        return WriteAllowlist(writable: merged)
    }

    func allowsWrite(baseID: String, table: String) -> Bool {
        writable[baseID]?.contains(table) == true
    }

    func allowsDelete(baseID: String, table: String) -> Bool {
        deletable[baseID]?.contains(table) == true
    }

    private static func pruned(_ map: [String: Set<String>]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for (base, tables) in map where base.isEmpty == false {
            let kept = tables.filter { $0.isEmpty == false }
            if kept.isEmpty == false { result[base] = kept }
        }
        return result
    }
}
