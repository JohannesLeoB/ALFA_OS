import Foundation
import CryptoKit

public enum CommercialDraftHashing {
    public static func positionHash(
        sequenz: Int,
        kind: CommercialDraftPositionKind,
        mykilosArtikelID: String?,
        label: String,
        beschreibung: String?,
        quantity: Decimal,
        einheitText: String,
        vkNettoEinzel: Decimal?,
        steuerKontextID: String,
        rabattProzent: Decimal? = nil
    ) -> String {
        var teile = [
            String(sequenz), kind.rawValue, mykilosArtikelID ?? "", label, beschreibung ?? "",
            quantity.description, einheitText, vkNettoEinzel.map(\.description) ?? "", steuerKontextID
        ]
        if let rabattProzent { teile.append("rabatt:" + rabattProzent.description) }
        return sha256Hex(teile)
    }

    public static func packageHash(
        packageID: UUID,
        revision: Int,
        contactID: String,
        projektID: String,
        processType: CommercialProcessType,
        title: String,
        einleitungsText: String?,
        schlussText: String?,
        currency: String,
        steuerKontextID: String,
        positionHashes: [String]
    ) -> String {
        sha256Hex(
            [
                packageID.uuidString, String(revision), contactID, projektID, processType.rawValue,
                title, einleitungsText ?? "", schlussText ?? "", currency, steuerKontextID
            ] + positionHashes
        )
    }

    static func sha256Hex(_ teile: [String]) -> String {
        SHA256.hash(data: Data(teile.joined(separator: "|").utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
