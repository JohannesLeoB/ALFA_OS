import Foundation
import CryptoKit
import AlfaKit

public struct CheckoutLedgerPort: CheckoutPort {
    public let id: PortID
    public let name: String

    private let airtableCreate: any AirtableRecordCreating
    private let airtableFetch: any AirtableFetching
    private let baseID: String
    private let table: String
    private let logger: DataFlowLogger?
    private let jetzt: @Sendable () -> Date

    public static let integrationID = "CHECKOUT_LEDGER_APPEND"

    public init(
        id: PortID = PortID("checkout-ledger"),
        name: String = "Checkout-Hauptbuch",
        airtableCreate: any AirtableRecordCreating,
        airtableFetch: any AirtableFetching,
        baseID: String = CompanySetup.valueOrEmpty("airtable.base.checkout_cart"),
        table: String = "Checkouts",
        logger: DataFlowLogger? = nil,
        jetzt: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.id = id
        self.name = name
        self.airtableCreate = airtableCreate
        self.airtableFetch = airtableFetch
        self.baseID = baseID
        self.table = table
        self.logger = logger
        self.jetzt = jetzt
    }

    public func erlaubteInhaltsArten() -> Set<InhaltsArt> {
        Set(InhaltsArt.allCases)
    }

    public func preview(basket: WorkBasket, target: PortZiel) async throws -> CheckoutPreview {
        let count = basket.picks.count
        return CheckoutPreview(
            zusammenfassung: "Zusätzlich als Hauptbuch-Zeile in mykilOS_checkouts vermerkt "
                + "(\(count) Position\(count == 1 ? "" : "en"), Projekt \(basket.projectNumber)).",
            warnungen: [])
    }

    public func execute(basket: WorkBasket, target: PortZiel) async throws -> CheckoutResult {
        let start = jetzt()
        let checkoutID = "CO-" + String(Self.checkoutHash(basket: basket, target: target).prefix(16))

        if let vorhandeneID = try await bestehendeZeile(checkoutID: checkoutID) {
            await protokolliere(recordsWritten: 0, durationMs: 0,
                summary: "Checkout-Hauptbuch: \(checkoutID) bereits vorhanden (idempotent).")
            return CheckoutResult(
                erfolg: true, referenz: vorhandeneID,
                message: "Bereits im Hauptbuch (idempotent, keine doppelte Zeile).")
        }

        var felder: [String: AirtableFieldValue] = [
            "Checkout-ID": .string(checkoutID),
            "Projekt": .string(basket.projectNumber),
            "Zeitstempel": .string(ISO8601DateFormatter().string(from: start)),
            "Status": .string(Self.statusText(basket.status)),
            "Summe-EK": .number(Self.summeEK(basket)),
            "Summe-VK": .number(Self.sumVk(basket))
        ]
        Self.setzeFalls(&felder, "Typ", target.parameter["typ"])
        Self.setzeFalls(&felder, "Kunde", target.parameter["kunde"])
        Self.setzeFalls(&felder, "Drive-Link", target.parameter["driveLink"])
        Self.setzeFalls(&felder, "Dateiname", target.parameter["dateiname"])

        let recordID = try await airtableCreate.createRecord(baseID: baseID, table: table, fields: felder)

        let dauerMs = Int(jetzt().timeIntervalSince(start) * 1000)
        await protokolliere(
            recordsWritten: 1, durationMs: dauerMs,
            summary: "Checkout-Hauptbuch: \(checkoutID) angelegt (\(basket.picks.count) Position(en)).")

        return CheckoutResult(erfolg: true, referenz: recordID, message: "Im Hauptbuch vermerkt: \(checkoutID).")
    }

    private func protokolliere(recordsWritten: Int, durationMs: Int, summary: String) async {
        guard let logger else { return }
        await MainActor.run {
            logger.log(
                integrationID: Self.integrationID, actorUserID: "system", action: .success,
                recordsWritten: recordsWritten, durationMs: durationMs, summary: summary)
        }
    }

    private func bestehendeZeile(checkoutID: String) async throws -> String? {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: table)
        for record in records where record["Checkout-ID"]?.stringValue == checkoutID {
            return record["_airtableRecordID"]?.stringValue
        }
        return nil
    }

    static func checkoutHash(basket: WorkBasket, target: PortZiel) -> String {
        let teile = [basket.id.raw, String(basket.version), target.kind]
            + target.parameter.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        let digest = SHA256.hash(data: Data(teile.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func statusText(_ status: WorkBasketStatus) -> String {
        switch status {
        case .kalkulation: return "Entwurf"
        case .bestaetigt: return "Bestätigt"
        case .nachtrag, .gutschrift: return "Eingefroren"
        }
    }

    static func summeEK(_ basket: WorkBasket) -> Double {
        basket.picks.reduce(0.0) { sum, pick in
            guard let einzel = pick.snapshot.ekEinzel else { return sum }
            return sum + einzel * Double(pick.snapshot.quantity)
        }
    }

    static func sumVk(_ basket: WorkBasket) -> Double {
        basket.picks.reduce(0.0) { sum, pick in
            guard let einzel = pick.snapshot.vkEinzel else { return sum }
            return sum + einzel * Double(pick.snapshot.quantity)
        }
    }

    static func setzeFalls(_ felder: inout [String: AirtableFieldValue], _ key: String, _ value: String?) {
        guard let value, value.isEmpty == false else { return }
        felder[key] = .string(value)
    }
}
