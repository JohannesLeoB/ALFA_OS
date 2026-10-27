import Assistant
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
