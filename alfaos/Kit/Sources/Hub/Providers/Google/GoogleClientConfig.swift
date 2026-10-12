import Foundation

public struct GoogleClientConfig: Equatable, Sendable {
    public let clientID: String
    public let clientSecret: String

    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    public static let fileName = "google-client.json"
    public static let directoryName = "ALFA_OS"

    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: false)
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func load(from directory: URL? = nil) throws -> GoogleClientConfig {
        let folder = try directory ?? defaultDirectory()
        let file = folder.appendingPathComponent(fileName)
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw GoogleProviderError.clientConfigMissing(file.path)
        }
        struct Raw: Decodable {
            let clientID: String?
            let clientSecret: String?
        }
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw GoogleProviderError.clientConfigInvalid(file.path)
        }
        let id = raw.clientID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secret = raw.clientSecret?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !id.isEmpty else { throw GoogleProviderError.clientConfigInvalid(file.path) }
        return GoogleClientConfig(clientID: id, clientSecret: secret)
    }
}

public enum GoogleProviderError: Error, Equatable, Sendable {
    case clientConfigMissing(String)
    case clientConfigInvalid(String)
    case grantIncomplete(String)
    case refreshUnavailable
    case http(Int)
    case network(String)
    case browserFailed
}
