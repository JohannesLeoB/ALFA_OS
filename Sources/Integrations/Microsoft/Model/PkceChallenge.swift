import CryptoKit
import Foundation

struct PkceChallenge: Sendable {
    static let method = "S256"
    private static let verifierBytes = 64

    let verifier: String
    let challenge: String

    static func generate() -> PkceChallenge {
        var bytes = [UInt8](repeating: 0, count: verifierBytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Base64Engine.encodeURL(Data(bytes))
        let challenge = Base64Engine.encodeURL(Data(SHA256.hash(data: Data(verifier.utf8))))
        return PkceChallenge(verifier: verifier, challenge: challenge)
    }
}
