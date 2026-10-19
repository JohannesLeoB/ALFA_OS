import Foundation
import AlfaServices

struct HeldClickUp: ClickUpCredentialsStoring {
    let token: String

    func store(_ credentials: ClickUpCredentials) throws {}
    func load() throws -> ClickUpCredentials? { ClickUpCredentials(apiToken: token) }
    func clear() throws {}
}

struct HeldClockodo: ClockodoCredentialsStoring {
    let email: String
    let key: String

    func store(_ credentials: ClockodoCredentials) throws {}
    func load() throws -> ClockodoCredentials? { ClockodoCredentials(email: email, apiKey: key) }
    func clear() throws {}
}

struct HeldClaude: ClaudeCredentialsStoring {
    let key: String
    let model: String

    func store(_ credentials: ClaudeCredentials) throws {}
    func load() throws -> ClaudeCredentials? { ClaudeCredentials(apiKey: key, model: model) }
    func clear() throws {}
}

struct HeldAirtable: AirtableCredentialsStoring {
    let token: String
    let base: String

    func store(_ credentials: AirtableCredentials) throws {}
    func load() throws -> AirtableCredentials? { AirtableCredentials(pat: token, baseID: base) }
    func clear() throws {}
}

struct HeldSevdesk: SevdeskCredentialsStoring {
    let token: String

    func store(_ credentials: SevdeskCredentials) throws {}
    func load() throws -> SevdeskCredentials? { SevdeskCredentials(apiToken: token) }
    func clear() throws {}
}
