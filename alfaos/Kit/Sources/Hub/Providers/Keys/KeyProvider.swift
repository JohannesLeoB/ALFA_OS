import Foundation

struct KeyValues: Sendable {
    let values: [String: String]

    subscript(id: String) -> String { values[id] ?? "" }
}

struct KeyConnector: Sendable {
    let info: ServiceInfo
    let check: @Sendable (KeyValues) async throws -> String?

    var fields: [Field] {
        info.fields.map { Field(id: $0.id, title: info.fieldKey($0), secret: $0.secret) }
    }
}

struct KeySignIn: SignInPort {
    let ids: [String]

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        var values: [String: String] = [:]
        for id in ids {
            let text = (input[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { values[id] = text }
        }
        return Grant(values: values)
    }

    func renew(_ grant: Grant) async throws -> Grant { grant }

    func signOut(_ inlet: Inlet) async throws {}
}

struct KeyProbe: ProbePort {
    let connector: KeyConnector

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let id = connector.info.id
        let missing = connector.info.fields.filter { !$0.optional && (grant.values[$0.id] ?? "").isEmpty }
        guard missing.isEmpty else {
            return ProbeResult(account: inlet.account, rejection: Hint(text: "hint.key.fields.invalid", fixIn: .inlet(inlet.id)))
        }
        do {
            return ProbeResult(account: try await connector.check(KeyValues(values: grant.values)) ?? id)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as KeyFieldError {
            return ProbeResult(account: inlet.account, rejection: Hint(
                text: "hint.key.fields.invalid", detail: error.field, fixIn: .inlet(inlet.id)))
        } catch {
            if let status = KeyStatus.of(error) {
                let kind = KeyProvider.kind(of: status)
                guard kind != .transient else { throw status }
                let text = kind == .signIn ? "hint.key.rejected" : "hint.key.failed"
                let classification = Classification(kind: kind, original: Original(provider: id, status: status.status))
                return ProbeResult(account: inlet.account, rejection: Hint(
                    text: text, classification: classification, fixIn: .inlet(inlet.id)))
            }
            if KeyStatus.isShape(error) {
                let classification = Classification(kind: .rejected, original: Original(
                    provider: id, text: String(describing: error)))
                return ProbeResult(account: inlet.account, rejection: Hint(
                    text: "hint.key.failed", classification: classification, fixIn: .inlet(inlet.id)))
            }
            throw error
        }
    }
}

struct KeyFieldError: Error, Equatable, Sendable {
    let field: String
}

struct KeyProvider: Provider {
    let connector: KeyConnector
    let signIn: any SignInPort
    let probe: any ProbePort

    init(_ connector: KeyConnector) {
        self.connector = connector
        signIn = KeySignIn(ids: connector.info.fields.map(\.id))
        probe = KeyProbe(connector: connector)
    }

    var id: ID { connector.info.id }
    var capabilities: Set<Capability> { [] }
    var form: [Field] { connector.fields }
    var presets: [Preset] { [] }

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        throw HubError.provider(Hint(text: "hint.port.unknown", detail: String(describing: port)))
    }

    func classify(_ error: any Error) -> Classification {
        guard let status = KeyStatus.of(error) else { return Classification.generic(error) }
        return Classification(kind: Self.kind(of: status), original: Original(provider: id, status: status.status))
    }

    static func kind(of status: KeyStatus) -> FailureKind {
        switch status.status {
        case 401, 403: .signIn
        case 408, 425, 429, 500...599: .transient
        default: .rejected
        }
    }

    var offer: Offer {
        Offer(id: "offer." + id, provider: id, title: connector.info.nameKey, capabilities: [],
              owner: connector.info.companyOwned ? .company : ServiceCatalog.ownPerson, way: .key(form))
    }
}
