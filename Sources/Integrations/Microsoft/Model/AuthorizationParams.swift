import Foundation

struct AuthorizationParams: Sendable {
    let url: URL
    let pkce: PkceChallenge
    let state: String
}
