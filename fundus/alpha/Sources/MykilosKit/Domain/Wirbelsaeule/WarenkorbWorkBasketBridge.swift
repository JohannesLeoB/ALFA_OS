import Foundation

public enum WarenkorbWorkBasketBridge {
    public static func workBasket(
        aus warenkorb: Warenkorb,
        projectNumber: String,
        id: WorkBasketID,
        erstellt: Date = Date()
    ) -> WorkBasket {
        let picks: [any Pick] = warenkorb.items.map { item in
            BasicPick(
                matrix: .artikel,
                objektID: CatalogObjectID(objektID(fuer: item)),
                snapshot: PickSnapshot(
                    label: item.label,
                    quantity: item.quantity,
                    ekEinzel: item.ekNetto,
                    vkEinzel: item.vkNetto,
                    attribute: attribute(fuer: item)
                ),
                content: .text(item.articleNumber)
            )
        }
        return WorkBasket(
            id: id,
            projectNumber: projectNumber,
            inhaltsArt: .artikel,
            picks: picks,
            version: 1,
            status: .kalkulation,
            erstellt: erstellt
        )
    }

    private static func objektID(fuer item: WarenkorbItem) -> String {
        if let artikelRecordID = item.artikelRecordID, artikelRecordID.isEmpty == false {
            return artikelRecordID
        }
        return item.articleNumber
    }

    private static func attribute(fuer item: WarenkorbItem) -> [String: String] {
        var attribute = item.attribute
        attribute["quelle"] = item.source
        if item.articleNumber.isEmpty == false {
            attribute["artikelnummer"] = item.articleNumber
        }
        return attribute
    }
}
