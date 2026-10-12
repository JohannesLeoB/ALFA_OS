import Foundation
import MykilosKit

@MainActor
@Observable
public final class DHLLabelErstellungStore {
    public var projectNumber: String = ""
    public var projectTitle: String = ""

    public var empfaengerName: String = ""
    public var empfaengerZHd: String = ""
    public var empfaengerStrasse: String = ""
    public var empfaengerHausnummer: String = ""
    public var empfaengerPlz: String = ""
    public var empfaengerOrt: String = ""
    public var empfaengerLand: String = "DEU"

    public var absender: DHLAdresse?
    public var gewichtGramm: Int = 1000
    public var produkt: String = "V01PAK"
    public var abrechnungsnummer: String = ""

    public var referenzText: String = ""

    public var laengeCm: Int = 0
    public var breiteCm: Int = 0
    public var hoeheCm: Int = 0

    public var versicherungswertEuro: Double = 0
    public var nurEigenhaendig: Bool = false
    public var sperrgut: Bool = false
    public var mitUnterschrift: Bool = false

    public private(set) var saveState: SaveState = .idle
    public private(set) var result: VersandLabelErgebnis?
    public private(set) var vorpruefung: [DHLAuftragFehler] = []

    private let versand: SendungErstellend
    private let dataFlow: DataFlowLogger?
    private let audit: AuditStore?
    private let actorUserID: String
    private let userDefaults: UserDefaults

    public init(
        versand: SendungErstellend = DHLVersandClient.ausSchluesselbund(),
        credentials: DHLVersandCredentials? = try? KeychainDHLVersandCredentialsStore().load(),
        dataFlow: DataFlowLogger? = nil,
        audit: AuditStore? = nil,
        actorUserID: String = "",
        userDefaults: UserDefaults = .standard
    ) {
        self.versand = versand
        self.absender = credentials?.absender
        self.abrechnungsnummer = credentials?.abrechnungsnummer ?? ""
        self.dataFlow = dataFlow
        self.audit = audit
        self.actorUserID = actorUserID
        self.userDefaults = userDefaults
    }

    public func setzeProjekt(number: String, title: String) {
        projectNumber = number
        projectTitle = title
        referenzText = DHLReferenz.refNo(projectNumber: number, projektName: title) ?? ""
    }

    public func uebernimmProjekt(fund: ProjektAdressResolver.Fund?) {
        guard let kontakt = fund?.kontakt else { return }
        uebernimmKontakt(kontakt)
    }

    public func uebernimmKontakt(_ kontakt: StudioContact) {
        let firma = kontakt.organisation?.trimmingCharacters(in: .whitespaces)
        empfaengerName = (firma?.isEmpty == false ? firma! : kontakt.name)
        empfaengerZHd = (firma?.isEmpty == false) ? kontakt.name : ""
        empfaengerStrasse = kontakt.strasse ?? ""
        empfaengerHausnummer = kontakt.houseNumber ?? ""
        empfaengerPlz = kontakt.plz ?? ""
        empfaengerOrt = kontakt.ort ?? ""
        empfaengerLand = Self.landZuISO3(kontakt.land)
    }

    public nonisolated static func landZuISO3(_ value: String?) -> String {
        guard let w = value?.trimmingCharacters(in: .whitespaces).lowercased(), w.isEmpty == false else { return "DEU" }
        if w.contains("deutsch") || w == "de" || w == "deu" { return "DEU" }
        return value!.uppercased()
    }

    private func auftrag() -> DHLVersandAuftrag? {
        guard let absender else { return nil }
        let empfaenger = DHLAdresse(
            name1: empfaengerName, name2: empfaengerZHd, strasse: empfaengerStrasse,
            houseNumber: empfaengerHausnummer, plz: empfaengerPlz, ort: empfaengerOrt, land: empfaengerLand)
        let masse = DHLMasse(laengeCm: laengeCm, breiteCm: breiteCm, hoeheCm: hoeheCm)

        let referenz = referenzText.trimmingCharacters(in: .whitespaces).isEmpty
            ? DHLReferenz.refNo(projectNumber: projectNumber, projektName: projectTitle)
            : String(referenzText.trimmingCharacters(in: .whitespaces).prefix(DHLReferenz.maxLaenge))
        return DHLVersandAuftrag(
            absender: absender, empfaenger: empfaenger, gewichtGramm: gewichtGramm, produkt: produkt,
            abrechnungsnummer: abrechnungsnummer, referenz: referenz,
            masse: masse.istVollstaendig ? masse : nil,
            versicherungswertEuro: versicherungswertEuro > 0 ? versicherungswertEuro : nil,
            nurEigenhaendig: nurEigenhaendig, sperrgut: sperrgut, mitUnterschrift: mitUnterschrift)
    }

    @discardableResult
    public func pruefe() -> [DHLAuftragFehler] {
        guard let auftrag = auftrag() else {
            vorpruefung = DHLAuftragFehler.allCases
            return vorpruefung
        }
        vorpruefung = DHLAuftragPruefung.pruefe(auftrag)
        return vorpruefung
    }

    public func erstelleLabel() async {
        result = nil
        guard let auftrag = auftrag() else {
            saveState = .failed("Keine Absender-Adresse hinterlegt — in den Einstellungen → DHL Versand eintragen.")
            return
        }
        let error = DHLAuftragPruefung.pruefe(auftrag)
        guard error.isEmpty else {
            vorpruefung = error
            saveState = .failed(error.map(\.rawValue).joined(separator: " · "))
            return
        }

        saveState = .saving
        do {
            let neuesErgebnis = try await versand.erstelleLabel(auftrag)
            result = neuesErgebnis
            saveState = .saved(Date())
            fuegeSendungHinzu(trackingNummer: neuesErgebnis.trackingNummer)
            schreibeTimelineEintrag(trackingNummer: neuesErgebnis.trackingNummer)
            dataFlow?.log(
                integrationID: "DHL_LABEL_ERSTELLUNG", actorUserID: actorUserID,
                action: .success, recordsWritten: 1,
                summary: "DHL-Label erstellt (Projekt \(projectNumber), Tracking \(neuesErgebnis.trackingNummer))")
        } catch {
            saveState = .failed(error.localizedDescription)
            dataFlow?.log(
                integrationID: "DHL_LABEL_ERSTELLUNG", actorUserID: actorUserID,
                action: .error, errorMessage: error.localizedDescription,
                summary: "DHL-Label-Erstellung fehlgeschlagen (Projekt \(projectNumber))")
        }
    }

    private func schreibeTimelineEintrag(trackingNummer: String) {
        let projekt = projectNumber.trimmingCharacters(in: .whitespaces)
        guard projekt.isEmpty == false, let audit else { return }
        let produktLabel = Self.produktLabel(produkt)
        let empf = empfaengerName.isEmpty ? "Empfänger" : empfaengerName
        try? audit.append(AuditEntry(
            actorUserID: actorUserID, projectID: projekt, action: .dhlLabelErstellt,
            summary: "DHL-Sendung an \(empf) · \(produktLabel) · \(trackingNummer)",
            source: "dhl-versand", idempotenzKey: "dhl-label:\(trackingNummer)"))
    }

    public nonisolated static func produktLabel(_ code: String) -> String {
        switch code {
        case "V01PAK": return "Paket national"
        case "V62KP": return "Kleinpaket national"
        case "V54EPAK": return "Europaket"
        default: return code
        }
    }

    public nonisolated static func widgetSchluessel(projectNumber: String) -> String {
        let target = projectNumber.trimmingCharacters(in: .whitespaces).isEmpty ? "home" : projectNumber
        return "widget.sendungen.\(target)"
    }

    private func fuegeSendungHinzu(trackingNummer: String) {
        let ohneProjekt = projectNumber.trimmingCharacters(in: .whitespaces).isEmpty
        let neu = Sendung(
            trackingNummer: trackingNummer, dienst: .dhl,
            label: empfaengerName, status: .erfasst,
            projectNumber: ohneProjekt ? nil : projectNumber)
        let key = Self.widgetSchluessel(projectNumber: projectNumber)
        let bestehend = Self.leseSendungen(userDefaults.string(forKey: key))
        let aktualisiert = Self.fuegeHinzu(neu, zu: bestehend)
        userDefaults.set(Self.schreibeSendungen(aktualisiert), forKey: key)
    }

    public nonisolated static func fuegeHinzu(_ sendung: Sendung, zu bestehende: [Sendung]) -> [Sendung] {
        guard bestehende.contains(where: { $0.trackingNummer == sendung.trackingNummer }) == false else {
            return bestehende
        }
        return bestehende + [sendung]
    }

    public nonisolated static func leseSendungen(_ raw: String?) -> [Sendung] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Sendung].self, from: data)) ?? []
    }

    public nonisolated static func schreibeSendungen(_ list: [Sendung]) -> String {
        (try? String(data: JSONEncoder().encode(list), encoding: .utf8) ?? "") ?? ""
    }
}
