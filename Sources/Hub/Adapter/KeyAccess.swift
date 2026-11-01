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

    public static func all(checks: [any ConnectionCheckPort], catalog: any IntegrationCatalogPort) -> [KeyAccess] {
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
        info.fields.map { Field(id: $0.id, title: info.fieldKey($0), secret: $0.secret, optional: $0.optional) }
    }
}

@MainActor
public final class ClaudeCredential {
    public static let provider = "claude"

    private let setup: any SetupPort
    private let keychain: any KeychainPort

    public init(setup: any SetupPort, keychain: any KeychainPort) {
        self.setup = setup
        self.keychain = keychain
    }

    public func current() -> ClaudeKey? {
        guard let inlet = setup.inlets.first(where: { $0.provider == Self.provider && $0.state.isConnected }),
              let key = try? keychain.get(KeySlot(inlet: inlet.id, name: "key")), !key.isEmpty else { return nil }
        let model = (try? keychain.get(KeySlot(inlet: inlet.id, name: "model"))) ?? ""
        return ClaudeKey(apiKey: key, model: model.isEmpty ? ClaudeKey.defaultModel : model)
    }
}

@MainActor
final class PresetSetup: SetupPort {
    private let wrapped: any SetupPort
    private let rules: any RulesPort
    private let cadences: [Capability: Cadence]

    init(wrapped: any SetupPort, rules: any RulesPort, cadences: [Capability: Cadence]) {
        self.wrapped = wrapped
        self.rules = rules
        self.cadences = cadences
    }

    var inlets: [Inlet] { wrapped.inlets }

    var offers: [Offer] { wrapped.offers }

    func add(_ offer: Offer, input: Input) async throws(SetupFailure) -> Inlet {
        let known = Set(wrapped.inlets.map(\.id))
        let inlet = try await wrapped.add(offer, input: input)
        guard !known.contains(inlet.id) else { return inlet }
        for capability in inlet.capabilities {
            if let preset = cadences[capability] { rules.setCadence(inlet.id, capability, preset) }
        }
        return inlet
    }

    func probe(_ inlet: Inlet.ID) async throws(SetupFailure) -> ProbeResult {
        try await wrapped.probe(inlet)
    }

    func remove(_ inlet: Inlet.ID) async throws {
        try await wrapped.remove(inlet)
    }

    func revoke(_ inlet: Inlet.ID) async throws {
        try await wrapped.revoke(inlet)
    }

    func report(for inlet: Inlet.ID) -> [ReportEntry] { wrapped.report(for: inlet) }

    func heldSlots(of inlet: Inlet.ID) -> Set<String> { wrapped.heldSlots(of: inlet) }
}

struct MeteredFiles: FilesPort {
    let wrapped: any FilesPort
    let meter: CostMeter

    func projectFolders() async throws -> [FileFolder] {
        meter.record()
        return try await wrapped.projectFolders()
    }

    func drives() async throws -> [FileFolder] {
        meter.record()
        return try await wrapped.drives()
    }

    func files(in folderID: String) async throws -> [FileEntry] {
        meter.record()
        return try await wrapped.files(in: folderID)
    }

    func read(_ fileID: String) async throws -> Data {
        meter.record()
        let data = try await wrapped.read(fileID)
        meter.record(calls: 0, bytes: data.count)
        return data
    }

    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        meter.record()
        meter.record(calls: 0, bytes: data.count)
        return try await wrapped.put(name: name, mimeType: mimeType, data: data, into: folderID)
    }
}

extension PortRegistry {
    public func withFiles() -> PortRegistry {
        var registry = self
        registry.register(
            (any FilesPort).self,
            capability: .files,
            wrap: { MeteredFiles(wrapped: $0, meter: $1) },
            sync: { port, inlet, _ in
                let folders = try await port.projectFolders()
                return SyncOutcome(deliveries: [.files: folders.map { ProjectFolder(inlet: inlet, folder: $0) }])
            }
        )
        return registry
    }
}
