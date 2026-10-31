import Foundation
import Hub

public struct ClientConfigStore: Sendable {
    public static let fileName = "google-client.json"

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load() throws -> ClientConfig {
        struct Raw: Decodable {
            let clientID: String?
            let clientSecret: String?
        }
        let file = directory.appendingPathComponent(Self.fileName)
        guard let data = try? Data(contentsOf: file) else { throw SignInFailure.clientConfigMissing(file.path) }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data) else {
            throw SignInFailure.clientConfigInvalid(file.path)
        }
        let id = raw.clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secret = raw.clientSecret?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !id.isEmpty else { throw SignInFailure.clientConfigInvalid(file.path) }
        return ClientConfig(clientID: id, clientSecret: secret)
    }
}

public struct ClientConfig: Equatable, Sendable {
    let clientID: String
    let clientSecret: String

    init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }
}

public struct DriveRootStore: Sendable {
    static let key = "google.drive.projectsRoot"

    private let settings: SettingStore

    public init(settings: SettingStore) {
        self.settings = settings
    }

    public func current() -> DriveRoot? {
        guard let root = try? settings.value(Self.key, as: DriveRoot.self), !root.id.isEmpty else { return nil }
        return root
    }

    public func choose(_ root: DriveRoot) {
        try? settings.store(root, forKey: Self.key)
    }
}
