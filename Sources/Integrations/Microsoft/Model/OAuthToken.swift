struct OAuthToken: Decodable, Equatable, Sendable {
    var accessToken: String
    var expiresIn: Int?
    var refreshToken: String?
    var idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}
