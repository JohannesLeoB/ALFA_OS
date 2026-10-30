enum MicrosoftFailure: Error, Equatable, Sendable {
    case invalidResponse
    case invalidEndpoint
    case decodingFailed
    case identityMissing
    case api(OAuthFault)
}
