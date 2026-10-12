import Foundation

public struct CheckoutPortAsCheckInAdapter: CheckInAdapter {
    private let port: any CheckoutPort

    private let kanal: AuditKanal

    public init(port: any CheckoutPort, kanal: AuditKanal = .checkoutAusgefuehrt) {
        self.port = port
        self.kanal = kanal
    }

    public var id: PortID { port.id }
    public var name: String { port.name }

    public func erlaubteInhaltsArten() -> Set<InhaltsArt> {
        port.erlaubteInhaltsArten()
    }

    public func idempotenzSchluessel(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) -> String {
        let sortierteParameter = absicht.target.parameter
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        let roh = "\(port.id.raw)|\(gegenstand.id.raw)|v\(gegenstand.version)|\(absicht.target.kind)|\(sortierteParameter)"
        return CheckInHash.stabil(roh)
    }

    public func vorschau(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInVorschau {
        let preview = try await port.preview(basket: gegenstand, target: absicht.target)
        return CheckInVorschau(
            vorschau: preview,
            idempotenzSchluessel: idempotenzSchluessel(gegenstand, absicht),
            istDuplikat: false
        )
    }

    public func fuehreAus(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInAusfuehrung {
        let result = try await port.execute(basket: gegenstand, target: absicht.target)
        return CheckInAusfuehrung(result: result, kanal: kanal, summaryDetail: result.referenz)
    }
}

public enum CheckInHash {
    public static func stabil(_ input: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }
}
