import Foundation

public enum ProjektAdressResolver {
    public enum Treffer: Equatable, Sendable {
        case ueberKundennummer

        case ueberProjektnummer
    }

    public struct Fund: Equatable, Sendable {
        public let adresse: String
        public let kontakt: StudioContact
        public let match: Treffer
        public init(adresse: String, kontakt: StudioContact, match: Treffer) {
            self.adresse = adresse; self.kontakt = kontakt; self.match = match
        }
    }

    public static func finde(
        customerNumber: String?, projektnummer: String?, kontakte: [StudioContact]
    ) -> Fund? {
        if let kdnr = bereinigt(customerNumber),
           let match = kontakte.first(where: { bereinigt($0.customerNumber) == kdnr }),
           let adresse = bereinigt(match.adresse) {
            return Fund(adresse: adresse, kontakt: match, match: .ueberKundennummer)
        }
        if let projektnr = bereinigt(projektnummer),
           let match = kontakte.first(where: { bereinigt($0.projekt) == projektnr }),
           let adresse = bereinigt(match.adresse) {
            return Fund(adresse: adresse, kontakt: match, match: .ueberProjektnummer)
        }
        return nil
    }

    public static func adresse(
        customerNumber: String?, projektnummer: String?, kontakte: [StudioContact]
    ) -> String? {
        finde(customerNumber: customerNumber, projektnummer: projektnummer, kontakte: kontakte)?.adresse
    }

    private static func bereinigt(_ value: String?) -> String? {
        guard let w = value?.trimmingCharacters(in: .whitespacesAndNewlines), w.isEmpty == false
        else { return nil }
        return w
    }
}
