import Foundation
import CryptoKit

public struct WarenkorbItem: Codable, Sendable, Equatable, Identifiable {
    public let artikelRecordID: String?

    public let label: String

    public let articleNumber: String

    public let quantity: Int

    public let ekNetto: Double?

    public let vkNetto: Double?

    public let source: String

    public let attribute: [String: String]

    public var id: String { "\(articleNumber)-\(quantity)-\(label)" }

    public init(
        artikelRecordID: String? = nil,
        label: String,
        articleNumber: String,
        quantity: Int,
        ekNetto: Double? = nil,
        vkNetto: Double? = nil,
        source: String,
        attribute: [String: String] = [:]
    ) {
        self.artikelRecordID = artikelRecordID
        self.label = label
        self.articleNumber = articleNumber
        self.quantity = quantity
        self.ekNetto = ekNetto
        self.vkNetto = vkNetto
        self.source = source
        self.attribute = attribute
    }

    private enum CodingKeys: String, CodingKey {
        case artikelRecordID, label, articleNumber, quantity, ekNetto, vkNetto, source, attribute
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.artikelRecordID = try c.decodeIfPresent(String.self, forKey: .artikelRecordID)
        self.label = try c.decode(String.self, forKey: .label)
        self.articleNumber = try c.decode(String.self, forKey: .articleNumber)
        self.quantity = try c.decode(Int.self, forKey: .quantity)
        self.ekNetto = try c.decodeIfPresent(Double.self, forKey: .ekNetto)
        self.vkNetto = try c.decodeIfPresent(Double.self, forKey: .vkNetto)
        self.source = try c.decode(String.self, forKey: .source)
        self.attribute = try c.decodeIfPresent([String: String].self, forKey: .attribute) ?? [:]
    }
}

public struct Warenkorb: Sendable, Equatable {
    public let items: [WarenkorbItem]

    public let projektRecordID: String?

    public let projektName: String?

    public init(
        items: [WarenkorbItem],
        projektRecordID: String? = nil,
        projektName: String? = nil
    ) {
        self.items = items
        self.projektRecordID = projektRecordID
        self.projektName = projektName
    }

    public var gesamtEKNetto: Double {
        items.reduce(0.0) { sum, item in
            sum + (item.ekNetto ?? 0.0) * Double(item.quantity)
        }
    }

    public var gesamtVKNetto: Double {
        items.reduce(0.0) { sum, item in
            sum + (item.vkNetto ?? 0.0) * Double(item.quantity)
        }
    }

    public var pruefsumme: String {
        let sortedItems = items.sorted {
            if $0.articleNumber != $1.articleNumber { return $0.articleNumber < $1.articleNumber }
            return $0.label < $1.label
        }
        let itemStrings = sortedItems.map { "\($0.articleNumber):\($0.quantity):\($0.label)" }
        var input = itemStrings.joined(separator: "|")
        if let name = projektName { input += "@" + name }
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
