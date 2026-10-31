import Foundation

public protocol ProviderPort: Sendable {
    typealias ID = String
    var id: ID { get }
    var capabilities: Set<Capability> { get }
    var form: [Field] { get }
    var presets: [Preset] { get }
    var signIn: any SignInPort { get }
    var probe: any ProbePort { get }
    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P
    func classify(_ error: any Error) -> Classification
    func offers(personal: Owner) -> [Offer]
}

extension ProviderPort {
    func classify(_ error: any Error) -> Classification { Classification.generic(error) }

    public func offers(personal: Owner) -> [Offer] {
        guard capabilities.contains(.mail) else { return [] }
        let way: Way = form.isEmpty ? .signIn : .form(form)
        let prefix = "offer." + id
        guard !presets.isEmpty else {
            return [Offer(id: prefix, provider: id, title: prefix, capabilities: [.mail], owner: personal, way: way)]
        }
        return presets.map { preset in
            Offer(id: prefix + "." + preset.id, provider: id, title: preset.title, capabilities: [.mail],
                  owner: personal, way: way, preset: preset)
        }
    }
}

public protocol SignInPort: Sendable {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant
    func signOut(_ inlet: Inlet) async throws
    func revoke(_ grant: Grant) async throws
}

extension SignInPort {
    public func revoke(_ grant: Grant) async throws {}
}

public protocol ProbePort: Sendable {
    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult
}

public protocol ConnectionCheckPort: Sendable {
    var integration: String { get }
    func check(_ values: KeyValues) async throws -> String?
}

public protocol ChangePort: Sendable {
    func changes() -> AsyncThrowingStream<Void, any Error>
}

public protocol ShapeErrorPort: Error {}

public protocol StatusErrorPort: Error {
    var status: Int { get }
}

public protocol FilesPort: Sendable {
    func projectFolders() async throws -> [FileFolder]
    func drives() async throws -> [FileFolder]
    func files(in folderID: String) async throws -> [FileEntry]
    func read(_ fileID: String) async throws -> Data
    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry
}

public protocol ContactFeedPort: Sendable {
    func people() async throws -> [ContactPerson]
}
