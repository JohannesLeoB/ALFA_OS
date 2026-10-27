import Assistant
import Foundation

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
