import CryptoKit
import Foundation

public enum URLSafeEngine {
    public static func encodeURL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decodeURL(_ text: String) -> Data? {
        var padded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }
}

public enum FormBodyEngine {
    public static func encode(_ values: [String: String]) -> Data {
        Data(values.map { key, value in "\(escape(key))=\(escape(value))" }.sorted().joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public struct PkceChallenge: Sendable {
    public static let method = "S256"
    private static let verifierBytes = 64

    public let verifier: String
    public let challenge: String

    public static func generate(unavailable: any Error) throws -> PkceChallenge {
        var bytes = [UInt8](repeating: 0, count: verifierBytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw unavailable }
        let verifier = URLSafeEngine.encodeURL(Data(bytes))
        let challenge = URLSafeEngine.encodeURL(Data(SHA256.hash(data: Data(verifier.utf8))))
        return PkceChallenge(verifier: verifier, challenge: challenge)
    }
}
