import CryptoKit
import Foundation

struct AuthorizationParams: Sendable {
    let url: URL
    let pkce: PkceChallenge
    let state: String
    let scopes: [OAuthScope]
}

enum OAuthScope: String, CaseIterable, Sendable {
    case drive = "https://www.googleapis.com/auth/drive"
    case calendarEventsReadonly = "https://www.googleapis.com/auth/calendar.events.readonly"
    case calendarReadonly = "https://www.googleapis.com/auth/calendar.readonly"
    case calendarEvents = "https://www.googleapis.com/auth/calendar.events"
    case gmailReadonly = "https://www.googleapis.com/auth/gmail.readonly"
    case gmailCompose = "https://www.googleapis.com/auth/gmail.compose"
    case gmailModify = "https://www.googleapis.com/auth/gmail.modify"
    case contacts = "https://www.googleapis.com/auth/contacts"
    case directoryReadonly = "https://www.googleapis.com/auth/directory.readonly"
    case userinfoEmail = "https://www.googleapis.com/auth/userinfo.email"
    case userinfoProfile = "https://www.googleapis.com/auth/userinfo.profile"
}

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
