enum SignInFailure: Error, Equatable, Sendable {
    case clientConfigMissing(String)
    case clientConfigInvalid(String)
    case grantIncomplete(String)
    case refreshUnavailable
    case redirectStateMismatch
    case loopbackStartupFailed
    case loopbackCancelled
    case browserFailed
}
