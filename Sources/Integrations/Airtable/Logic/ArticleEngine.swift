import Assistant
import Core
import Foundation
import Hub

enum ArticleEngine {
    static let numberField = "Artikelnummer"
    static let manufacturerField = "Hersteller"
    static let categoryField = "Kategorie"
    static let titleField = "Bezeichnung"
    static let variantField = "Variante"
    static let measurementsField = "Ma\u{00DF}e"
    static let descriptionField = "Beschreibung"
    static let purchaseField = "Netto-EK (\u{20AC})"
    static let eanField = "EAN/GTIN"
    static let nameField = "Name"

    static func entries(from records: [Record], manufacturers: [String: String],
                        categories: [String: String], saleField: String) throws -> [CatalogEntry] {
        guard saleField.isEmpty == false else { throw KeyFieldFailure(field: "airtable.field.sale_price") }
        return records.compactMap { record in
            let fields = record.fields
            guard let number = fields[numberField]?.anyStringValue,
                  number.trimmingCharacters(in: .whitespaces).isEmpty == false else { return nil }
            return CatalogEntry(
                id: record.id,
                articleNumber: number,
                manufacturer: fields[manufacturerField]?.firstArrayValue.flatMap { manufacturers[$0] },
                category: fields[categoryField]?.firstArrayValue.flatMap { categories[$0] },
                summary: fields[titleField]?.anyStringValue ?? fields[descriptionField]?.anyStringValue,
                detailText: detailText(from: fields),
                ean: fields[eanField]?.anyStringValue,
                purchaseNet: fields[purchaseField]?.numberValue,
                saleNet: fields[saleField]?.numberValue,
                review: ReviewStateEngine.state(from: fields))
        }
    }

    static func names(of records: [Record]) -> [String: String] {
        var result: [String: String] = [:]
        for record in records {
            guard let name = record.fields[nameField]?.anyStringValue, name.isEmpty == false else { continue }
            result[record.id] = name
        }
        return result
    }

    static func detailText(from fields: [String: FieldValue]) -> String? {
        let title = fields[titleField]?.anyStringValue
        var parts: [String] = []
        if let description = fields[descriptionField]?.anyStringValue, description.isEmpty == false, description != title {
            parts.append(description)
        }
        if let variant = fields[variantField]?.anyStringValue, variant.isEmpty == false { parts.append(variant) }
        if let measurements = fields[measurementsField]?.anyStringValue, measurements.isEmpty == false {
            parts.append(measurements)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 }
    }

    static func searchTokens(of entry: CatalogEntry) -> Set<String> {
        let texts = [entry.articleNumber, entry.manufacturer, entry.summary, entry.detailText, entry.category, entry.ean]
        return Set(texts.compactMap { $0 }.flatMap(tokens))
    }

    static func search(_ entries: [CatalogEntry], term: String) -> [CatalogEntry] {
        let wanted = Set(tokens(term))
        guard wanted.isEmpty == false else { return entries }
        var scored: [(entry: CatalogEntry, score: Int)] = []
        for entry in entries {
            let own = searchTokens(of: entry)
            let exact = own.intersection(wanted).count
            var prefix = 0
            for word in wanted.subtracting(own) where own.contains(where: { $0.hasPrefix(word) }) { prefix += 1 }
            let score = exact * 2 + prefix
            if score > 0 { scored.append((entry, score)) }
        }
        return scored.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.entry.articleNumber < $1.entry.articleNumber
        }.map(\.entry)
    }

    static func article(_ entry: CatalogEntry) -> Article {
        Article(id: entry.id, articleNumber: entry.articleNumber, manufacturer: entry.manufacturer,
                summary: entry.summary, purchaseNet: entry.purchaseNet, saleNet: entry.saleNet)
    }
}

public enum StockEngine {
    static let labelField = "Bezeichnung"
    static let categoryField = "Kategorie"
    static let manufacturerField = "Hersteller"
    static let numberField = "Artikelnummer"
    static let quantityField = "Bestand"
    static let purchaseField = "EK netto (\u{20AC})"
    static let saleField = "VK netto (\u{20AC})"

    static func items(from records: [Record]) -> [StockItem] {
        records.compactMap { record in
            let fields = record.fields
            guard let label = fields[labelField]?.stringValue,
                  label.trimmingCharacters(in: .whitespaces).isEmpty == false else { return nil }
            return StockItem(
                id: record.id,
                label: label,
                manufacturer: fields[manufacturerField]?.stringValue,
                category: fields[categoryField]?.stringValue,
                articleNumber: fields[numberField]?.stringValue,
                quantity: fields[quantityField]?.numberValue.map { Int($0) },
                purchaseNet: fields[purchaseField]?.numberValue,
                saleNet: fields[saleField]?.numberValue)
        }
    }
}

enum ReviewStateEngine {
    static let statusField = "Review-Status"
    static let confidenceField = "Konfidenz"
    static let sourceField = "Quell-Beleg"
    static let locationField = "Fundstelle"
    static let rawTextField = "Beleg-Rohtext"
    static let questionField = "Kl\u{00E4}rung offen"

    static func state(from fields: [String: FieldValue]) -> ReviewState? {
        guard let raw = fields[statusField]?.anyStringValue, let status = status(of: raw) else { return nil }
        return ReviewState(
            status: status,
            confidence: fields[confidenceField]?.numberValue,
            sourceDocument: trimmed(fields[sourceField]?.anyStringValue),
            location: trimmed(fields[locationField]?.anyStringValue),
            rawText: trimmed(fields[rawTextField]?.anyStringValue),
            openQuestion: trimmed(fields[questionField]?.anyStringValue))
    }

    static func status(of raw: String) -> ReviewState.Status? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ungepr\u{00FC}ft", "ungeprueft": .unchecked
        case "verifiziert": .verified
        case "beanstandet": .disputed
        default: nil
        }
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else { return nil }
        return text
    }
}

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
