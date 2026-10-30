import Hub

enum FailureEngine {
    static let provider = "oauth"

    static func classify(_ error: any Error) -> Classification? {
        switch error {
        case MicrosoftFailure.api(let fault): oauth(fault)
        case SignInFailure.refreshUnavailable:
            Classification(kind: .signIn, original: Original(provider: provider, code: "refreshUnavailable"))
        case MicrosoftFailure.identityMissing:
            Classification(kind: .rejected, original: Original(provider: provider, code: "identityMissing"))
        case is MicrosoftFailure: Classification.generic(error)
        default: nil
        }
    }

    static func isRejection(_ error: any Error) -> Bool {
        classify(error)?.kind == .signIn
    }

    private static func oauth(_ fault: OAuthFault) -> Classification {
        let kind: FailureKind
        switch fault.reason {
        case "invalid_grant", "invalid_client", "unauthorized_client", "interaction_required", "consent_required",
             "login_required": kind = .signIn
        case "server_error", "temporarily_unavailable": kind = .transient
        case "invalid_request", "invalid_scope", "unsupported_grant_type", "access_denied": kind = .rejected
        default:
            if fault.isServerFault {
                kind = .transient
            } else if fault.status == 400 || fault.status == 401 {
                kind = .signIn
            } else {
                kind = .rejected
            }
        }
        return Classification(kind: kind, original: Original(
            provider: provider, status: fault.status, code: fault.reason, text: fault.message))
    }
}
