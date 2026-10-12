import Foundation
import MykilosKit

public enum WorkBasketToCommercialDraftPackageMapper {
    public struct Result: Sendable, Equatable {
        public let package: CommercialDraftPackage

        public let blockedPositions: [CommercialDraftPosition]
        public let warnings: [String]
    }

    public static func map(
        basket: WorkBasket,
        contactID: String,
        processType: CommercialProcessType,
        title: String,
        steuerKontextID: String,
        actorUserID: String,
        projektCode: String? = nil,
        einleitungsText: String? = nil,
        schlussText: String? = nil,
        currency: String = "EUR",
        jetzt: @Sendable () -> Date = { Date() }
    ) -> Result {
        let packageID = UUID()
        let erstelltAm = jetzt()
        var warnings: [String] = []

        let positionen: [CommercialDraftPosition] = basket.picks.enumerated().map { index, pick in
            position(pick: pick, packageID: packageID, sequenz: index + 1, steuerKontextID: steuerKontextID)
        }

        let blockierte = positionen.filter { $0.mappingState == .blockedRequiresReview }
        if blockierte.isEmpty == false {
            warnings.append(
                "\(blockierte.count) Position\(blockierte.count == 1 ? "" : "en") ohne Verkaufspreis — "
                + "kein Preis im Paket (interner Einkaufspreis verlässt ALPHA nie). Review erforderlich.")
        }
        if basket.picks.isEmpty {
            warnings.append("Korb ist leer — Paket ohne Positionen.")
        }

        let expectedNet = positionen.reduce(Decimal(0)) { sum, pos in sum + (pos.summeNetto ?? 0) }

        let payloadHash = CommercialDraftHashing.packageHash(
            packageID: packageID, revision: 1, contactID: contactID, projektID: basket.projectNumber,
            processType: processType, title: title, einleitungsText: einleitungsText, schlussText: schlussText,
            currency: currency, steuerKontextID: steuerKontextID,
            positionHashes: positionen.map(\.positionSHA256))

        let package = CommercialDraftPackage(
            packageID: packageID,
            revision: 1,
            createdAt: erstelltAm,
            createdByUserID: actorUserID,
            projektID: basket.projectNumber,
            projektCode: projektCode ?? basket.projectNumber,
            contactID: contactID,
            processType: processType,
            title: title,
            einleitungsText: einleitungsText,
            schlussText: schlussText,
            currency: currency,
            steuerKontextID: steuerKontextID,
            positionen: positionen,
            expectedNet: expectedNet,
            expectedTax: 0,
            expectedGross: expectedNet,
            payloadSHA256: payloadHash
        )

        return Result(package: package, blockedPositions: blockierte, warnings: warnings)
    }

    static func position(
        pick: any Pick, packageID: UUID, sequenz: Int, steuerKontextID: String
    ) -> CommercialDraftPosition {
        let s = pick.snapshot
        let attr = s.attribute

        let vk = s.vkEinzel
        let articleNumber = attr["artikelnummer"]

        let beschreibung = attr["beschreibung"] ?? attr["originalText"]
        let einheitText = attr["einheit"] ?? "Stk"
        let mappingState: PositionMappingState = vk == nil ? .blockedRequiresReview : .supportedDirectly
        let kind: CommercialDraftPositionKind = articleNumber == nil ? .freeTextItem : .mappedCatalogArticle
        let vkDecimal = vk.map { Decimal($0) }
        let mengeDecimal = Decimal(s.quantity)

        let rabatt = attr["rabattProzent"].flatMap { Decimal(string: $0) }

        let sevdeskArtikelID = attr["sevdeskArtikelID"]

        let hash = CommercialDraftHashing.positionHash(
            sequenz: sequenz, kind: kind, mykilosArtikelID: articleNumber, label: s.label,
            beschreibung: beschreibung, quantity: mengeDecimal, einheitText: einheitText,
            vkNettoEinzel: vkDecimal, steuerKontextID: steuerKontextID, rabattProzent: rabatt)

        return CommercialDraftPosition(
            packageID: packageID,
            sequenz: sequenz,
            kind: kind,
            mykilosArtikelID: articleNumber,
            sevdeskPartID: sevdeskArtikelID,
            label: s.label,
            beschreibung: beschreibung,
            quantity: mengeDecimal,
            einheitText: einheitText,
            vkNettoEinzel: vkDecimal,
            rabattProzent: rabatt,
            steuerKontextID: steuerKontextID,
            mappingState: mappingState,
            positionSHA256: hash
        )
    }
}
