import Foundation
import AlfaKit
import AlfaServices

enum KeyProviders {
    typealias Check = @Sendable (KeyValues) async throws -> String?

    static let probeTracking = "00000000000000000000"

    static func table(_ session: URLSession) -> [String: Check] {
        [
            "clickup": { values in
                let user = try await ClickUpClient(credentialsStore: HeldClickUp(token: values["token"]), session: session)
                    .currentUser()
                return user.username
            },
            "clockodo": { values in
                var user: Int?
                if !values["user"].isEmpty {
                    guard let number = Int(values["user"]) else { throw KeyFieldError(field: "user") }
                    user = number
                }
                _ = try await ClockodoClient(credentialsStore: HeldClockodo(email: values["email"], key: values["key"]),
                                             session: session).todaysEntries(userID: user)
                return values["email"]
            },
            "claude": { values in
                let fallback = await ClaudeAuthService.defaultModel
                let model = values["model"].isEmpty ? fallback : values["model"]
                let client = ClaudeChatClient(credentialsStore: HeldClaude(key: values["key"], model: model), httpClient: session)
                _ = try await client.respond(messages: [ChatMessage.text(".", role: .user)], system: ".", tools: [], maxTokens: 1)
                return nil
            },
            "airtable": { values in
                let base = values["base"]
                guard base.hasPrefix("app"), (15...22).contains(base.count) else { throw KeyFieldError(field: "base") }
                let client = AirtableClient(credentialsStore: HeldAirtable(token: values["token"], base: base), session: session)
                let projects = (try? AlfaKit.CompanySetup.value("airtable.table.projects")) ?? AirtableRegistry().projectsTable
                _ = try await client.fetchRecords(baseID: base, table: projects, filterByFormula: "FALSE()")
                return base
            },
            "sevdesk": { values in
                _ = try await SevdeskMandantSonde(credentialsStore: HeldSevdesk(token: values["token"]), session: session)
                    .sondiere(angebotsNummer: nil)
                return nil
            },
            "dhl": { values in
                let client = DHLSendungsClient(apiKey: values["key"], session: session)
                do {
                    _ = try await client.verfolge(Sendung(trackingNummer: probeTracking, dienst: .dhl, label: ""))
                } catch SendungsFehler.netz(let text) {
                    guard let status = KeyStatus.of(SendungsFehler.netz(text)) else { throw URLError(.networkConnectionLost) }
                    guard status.status == 404 else { throw status }
                } catch SendungsFehler.parse {
                }
                return nil
            }
        ]
    }

    static let standard: [KeyProvider] = all()

    static func all(session: URLSession = .shared) -> [KeyProvider] {
        table(session).sorted { $0.key < $1.key }.compactMap { id, check in
            ServiceCatalog.info(id).map { KeyProvider(KeyConnector(info: $0, check: check)) }
        }
    }
}
