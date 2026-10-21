import Foundation
import AlfaServices

enum GoogleFailure {
    static func classify(_ error: any Error) -> Classification {
        switch error {
        case GoogleGmailError.api(let fault): return gmail(fault)
        case GoogleGmailError.httpError(let status): return gmail(GoogleAPIFault(status: status))
        case GoogleDriveError.httpError(403):
            return Classification(kind: .signIn, original: Original(provider: "drive", status: 403))
        case GoogleDriveError.httpError(let status): return api("drive", GoogleAPIFault(status: status))
        case GoogleDriveError.notConnected:
            return Classification(kind: .transient, original: Original(provider: "drive", code: "notConnected"))
        case GoogleProviderError.projectRootMissing:
            return Classification(kind: .rejected, original: Original(provider: "drive", code: "projectRootMissing"))
        case GoogleOAuthError.api(let fault): return oauth(fault)
        case GoogleOAuthError.httpError(let status): return oauth(GoogleAPIFault(status: status))
        case GoogleOAuthError.refreshUnavailable, GoogleProviderError.refreshUnavailable:
            return Classification(kind: .signIn, original: Original(provider: "oauth", code: "refreshUnavailable"))
        case GoogleGmailError.notConnected, GoogleOAuthError.notConnected:
            return Classification(kind: .transient, original: Original(provider: "gmail", code: "notConnected"))
        default: return Classification.generic(error)
        }
    }

    static func gmail(_ fault: GoogleAPIFault) -> Classification { api("gmail", fault) }

    static func api(_ provider: String, _ fault: GoogleAPIFault) -> Classification {
        let kind: FailureKind
        if fault.status == 401 {
            kind = .signIn
        } else if fault.isRateLimit || fault.isServerFault {
            kind = .transient
        } else {
            kind = .rejected
        }
        return Classification(kind: kind, original: original(provider, fault))
    }

    static func oauth(_ fault: GoogleAPIFault) -> Classification {
        let kind: FailureKind
        switch fault.reason {
        case "invalid_grant", "invalid_client", "unauthorized_client": kind = .signIn
        case "server_error", "temporarily_unavailable": kind = .transient
        case "invalid_request", "invalid_scope", "unsupported_grant_type": kind = .rejected
        default:
            if fault.status == 400 || fault.status == 401 {
                kind = .signIn
            } else if fault.isRetryable {
                kind = .transient
            } else {
                kind = .rejected
            }
        }
        return Classification(kind: kind, original: original("oauth", fault))
    }

    private static func original(_ provider: String, _ fault: GoogleAPIFault) -> Original {
        var extra: [String: String] = [:]
        if let state = fault.state { extra["state"] = state }
        if let domain = fault.domain { extra["domain"] = domain }
        if let uri = fault.errorURI { extra["errorURI"] = uri }
        return Original(provider: provider, status: fault.status, code: fault.reason, text: fault.message,
                        extra: extra, body: fault.body.isEmpty ? nil : fault.body)
    }
}
