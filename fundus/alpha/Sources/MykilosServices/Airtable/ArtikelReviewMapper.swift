import Foundation
import MykilosKit

public enum ArtikelReviewMapper {
    static let feldReviewStatus = "Review-Status"
    static let feldKonfidenz    = "Konfidenz"
    static let feldQuellBeleg   = "Quell-Beleg"
    static let feldFundstelle   = "Fundstelle"
    static let feldBelegRohtext = "Beleg-Rohtext"
    static let feldKlaerung     = "Klärung offen"

    public static func status(aus fields: [String: AirtableFieldValue]) -> ArtikelReviewZustand? {
        guard let roh = fields[feldReviewStatus]?.anyStringValue,
              let status = ArtikelReviewStatus(airtable: roh) else { return nil }
        return ArtikelReviewZustand(
            status: status,
            konfidenz: fields[feldKonfidenz]?.numberValue,
            quellBeleg: nichtLeer(fields[feldQuellBeleg]?.anyStringValue),
            fundstelle: nichtLeer(fields[feldFundstelle]?.anyStringValue),
            belegRohtext: nichtLeer(fields[feldBelegRohtext]?.anyStringValue),
            klaerungOffen: nichtLeer(fields[feldKlaerung]?.anyStringValue)
        )
    }

    private static func nichtLeer(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), s.isEmpty == false else { return nil }
        return s
    }
}
