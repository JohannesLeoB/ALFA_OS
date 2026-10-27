import Foundation

public struct KeyAccess: ProviderPort {
    let connection: KeyConnection
    public let signIn: any SignInPort
    public let probe: any ProbePort

    init(_ connection: KeyConnection) {
        self.connection = connection
        signIn = KeySignIn(ids: connection.info.fields.map(\.id))
        probe = KeyCheck(connection: connection)
    }

    public static func all(checks: [any ConnectionCheckPort], catalog: IntegrationCatalogStore) -> [KeyAccess] {
        checks.sorted { $0.integration < $1.integration }.compactMap { check in
            catalog.info(check.integration).map { KeyAccess(KeyConnection(info: $0, check: check)) }
        }
    }

    public var id: ID { connection.info.id }

    public var capabilities: Set<Capability> { [] }

    public var form: [Field] { connection.fields }

    public var presets: [Preset] { [] }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        throw HubFailure.provider(Hint(text: HintEngine.unknownPortText, detail: String(describing: port)))
    }

    public func classify(_ error: any Error) -> Classification {
        guard let status = HttpStatus.of(error) else { return Classification.generic(error) }
        return Classification(kind: status.kind, original: Original(provider: id, status: status.code))
    }

    public func offers(personal: Owner) -> [Offer] {
        [Offer(id: "offer." + id, provider: id, title: connection.info.nameKey, capabilities: [],
               owner: connection.info.companyOwned ? .company : personal, way: .key(form))]
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

    func signOut(_ inlet: Inlet) async throws {}
}

struct KeyCheck: ProbePort {
    let connection: KeyConnection

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let id = connection.info.id
        let missing = connection.info.fields.filter { !$0.optional && (grant.values[$0.id] ?? "").isEmpty }
        guard missing.isEmpty else {
            return ProbeResult(account: inlet.account, rejection: Hint(text: HintEngine.keyFieldsInvalidText, fixIn: .inlet(inlet.id)))
        }
        do {
            return ProbeResult(account: try await connection.check.check(KeyValues(values: grant.values)) ?? id)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as KeyFieldFailure {
            return ProbeResult(account: inlet.account, rejection: Hint(
                text: HintEngine.keyFieldsInvalidText, detail: error.field, fixIn: .inlet(inlet.id)))
        } catch {
            if let status = HttpStatus.of(error) {
                let kind = status.kind
                guard kind != .transient else { throw status }
                let text = kind == .signIn ? HintEngine.keyRejectedText : HintEngine.keyFailedText
                let classification = Classification(kind: kind, original: Original(provider: id, status: status.code))
                return ProbeResult(account: inlet.account, rejection: Hint(
                    text: text, classification: classification, fixIn: .inlet(inlet.id)))
            }
            if HttpStatus.isShape(error) {
                let classification = Classification(kind: .rejected, original: Original(
                    provider: id, text: String(describing: error)))
                return ProbeResult(account: inlet.account, rejection: Hint(
                    text: HintEngine.keyFailedText, classification: classification, fixIn: .inlet(inlet.id)))
            }
            throw error
        }
    }
}

struct KeyConnection: Sendable {
    let info: IntegrationInfo
    let check: any ConnectionCheckPort

    var fields: [Field] {
        info.fields.map { Field(id: $0.id, title: info.fieldKey($0), secret: $0.secret) }
    }
}
