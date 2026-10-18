import Foundation
import AlfaKit

@MainActor
@Observable
public final class AirtableContactsLoader {
    public enum LoadState: Equatable {
        case idle
        case loading
        case content([StudioContact])
        case empty
        case notConnected
        case error(String)
    }

    @MainActor public static let geteilt = AirtableContactsLoader()

    public private(set) var state: LoadState = .idle

    public private(set) var zuletztGeladen: Date?

    public static let frischeDauer: TimeInterval = 300

    private var laufenderLauf: Task<Void, Never>?

    public var istFrisch: Bool {
        guard case .content = state, let zuletztGeladen else { return false }
        return Date().timeIntervalSince(zuletztGeladen) < Self.frischeDauer
    }

    public var contacts: [StudioContact] {
        if case .content(let c) = state { return c }
        return []
    }

    private let konfiguration: KontaktSyncKonfiguration
    private let client: AirtableFetching

    public init(
        konfiguration: KontaktSyncKonfiguration = .live,
        client: AirtableFetching = AirtableClient()
    ) {
        self.konfiguration = konfiguration
        self.client = client
    }

    public func load(erzwingen: Bool = false) async {
        if erzwingen == false, istFrisch { return }

        if let laufenderLauf {
            await laufenderLauf.value
            return
        }
        let lauf = Task { await ladeAusDemNetz() }
        laufenderLauf = lauf
        await lauf.value
        laufenderLauf = nil
    }

    private func ladeAusDemNetz() async {
        if case .content = state {} else { state = .loading }
        do {
            async let golden  = fetch(konfiguration.kundenGoldenTable)
            async let liefer  = fetch(konfiguration.lieferantenTable)
            async let weitere = fetch(konfiguration.weitereKontakteTable)
            let mapped = try await KontaktQuellenMapper.vereinigeAlle(
                kundenGolden: golden, lieferanten: liefer, weitereKontakte: weitere)
            zuletztGeladen = Date()
            if mapped.isEmpty {
                state = .empty
            } else {
                state = .content(mapped)
            }
        } catch AirtableError.notConnected {
            state = .notConnected
        } catch AirtableError.httpError(let code) {
            state = .error("HTTP \(code)")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func fetch(_ table: String) async throws -> [[String: AirtableFieldValue]] {
        guard table.trimmingCharacters(in: .whitespaces).isEmpty == false else { return [] }
        return try await client.fetchRecords(baseID: konfiguration.baseID, table: table)
    }
}
