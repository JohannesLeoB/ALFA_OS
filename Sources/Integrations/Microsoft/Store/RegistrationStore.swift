import Foundation

public struct RegistrationStore: Sendable {
    public static let fileName = "microsoft-client.json"

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load() throws -> Registration {
        struct Raw: Decodable {
            let clientID: String?
        }
        let file = directory.appendingPathComponent(Self.fileName)
        guard let data = try? Data(contentsOf: file) else { throw SignInFailure.clientConfigMissing(file.path) }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data) else {
            throw SignInFailure.clientConfigInvalid(file.path)
        }
        let id = raw.clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !id.isEmpty else { throw SignInFailure.clientConfigInvalid(file.path) }
        return Registration(clientID: id)
    }
}

public struct Registration: Equatable, Sendable {
    let clientID: String

    init(clientID: String) {
        self.clientID = clientID
    }
}
