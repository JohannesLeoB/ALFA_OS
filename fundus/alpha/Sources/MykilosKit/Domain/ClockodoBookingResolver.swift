import Foundation

public struct ClockodoBookingResolution: Equatable, Sendable {
    public let customersID: Int
    public let servicesID: Int
    public init(customersID: Int, servicesID: Int) {
        self.customersID = customersID
        self.servicesID = servicesID
    }
}

public enum ClockodoBookingSkipReason: Error, Equatable, Sendable {
    case unbekannteKostenstelle(String)
    case kostenstelleOhneServiceID(String)
    case projektNichtGefunden(String)
    case projektOhneKunde(String)
    case kundeNichtGefunden(String)
    case kundeOhneClockodoID(String)

    public var beschreibung: String {
        switch self {
        case .unbekannteKostenstelle(let k):    "Unbekannte Kostenstelle/Leistung: \(k)"
        case .kostenstelleOhneServiceID(let k): "Leistung ohne Clockodo-ID (nicht buchbar): \(k)"
        case .projektNichtGefunden(let p):      "Projekt nicht gefunden: \(p)"
        case .projektOhneKunde(let p):          "Projekt ohne Kundennummer: \(p)"
        case .kundeNichtGefunden(let c):        "Kunde nicht gefunden: \(c)"
        case .kundeOhneClockodoID(let c):       "Kunde ohne Clockodo-ID (nicht gemappt): \(c)"
        }
    }
}

public enum ClockodoBookingResolver {
    public static func resolve(
        projectNumber: String,
        kostenstelle: String,
        projects: [Project],
        customers: [Customer],
        leistungen: [Kostenstelle] = Kostenstelle.defaults
    ) -> Result<ClockodoBookingResolution, ClockodoBookingSkipReason> {
        guard let leistung = leistungen.first(where: { $0.name == kostenstelle }) else {
            return .failure(.unbekannteKostenstelle(kostenstelle))
        }
        guard let servicesID = leistung.clockodoServiceID else {
            return .failure(.kostenstelleOhneServiceID(kostenstelle))
        }

        guard let projekt = projects.first(where: { $0.projectNumber == projectNumber }) else {
            return .failure(.projektNichtGefunden(projectNumber))
        }
        let kundenNummer = projekt.customerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kundenNummer.isEmpty == false else {
            return .failure(.projektOhneKunde(projectNumber))
        }
        guard let customer = customers.first(where: { $0.customerNumber == kundenNummer }) else {
            return .failure(.kundeNichtGefunden(kundenNummer))
        }
        guard let customersID = customer.clockodoCustomerID else {
            return .failure(.kundeOhneClockodoID(customer.name))
        }
        return .success(ClockodoBookingResolution(customersID: customersID, servicesID: servicesID))
    }
}
