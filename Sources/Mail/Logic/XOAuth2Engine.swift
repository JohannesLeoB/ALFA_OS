import Foundation

enum XOAuth2Engine {
    static let mechanism = "XOAUTH2"

    static func initialResponse(user: String, token: String) -> String {
        Data("user=\(user)\u{01}auth=Bearer \(token)\u{01}\u{01}".utf8).base64EncodedString()
    }
}
