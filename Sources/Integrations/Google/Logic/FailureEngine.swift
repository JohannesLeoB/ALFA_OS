import Assistant
import Foundation
import Hub

enum FailureEngine {
    static func classify(_ error: any Error) -> Classification {
        switch error {
        case let failure as GoogleFailure: classify(failure, error: error)
        case SignInFailure.refreshUnavailable:
            Classification(kind: .signIn, original: Original(provider: Product.oauth.rawValue, code: "refreshUnavailable"))
        default: Classification.generic(error)
        }
    }

    static func port(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError: error
        case GoogleFailure.notConnected: PortFailure.notConnected
        default: PortFailure.failed(String(describing: error))
        }
    }

    private static func classify(_ failure: GoogleFailure, error: any Error) -> Classification {
        switch failure {
        case .api(.drive, let fault) where fault.status == 403:
            Classification(kind: .signIn, original: Original(provider: Product.drive.rawValue, status: 403))
        case .api(.oauth, let fault): oauth(fault)
        case .api(let product, let fault): api(product, fault)
        case .notConnected(let product):
            Classification(kind: .transient, original: Original(provider: product.rawValue, code: "notConnected"))
        case .uploadDestinationForbidden:
            Classification(kind: .rejected,
                           original: Original(provider: Product.drive.rawValue, code: "uploadDestinationForbidden"))
        case .invalidResponse, .invalidEndpoint, .decodingFailed: Classification.generic(error)
        }
    }

    private static func api(_ product: Product, _ fault: APIFault) -> Classification {
        let kind: FailureKind
        if fault.status == 401 {
            kind = .signIn
        } else if fault.isRetryable {
            kind = .transient
        } else {
            kind = .rejected
        }
        return Classification(kind: kind, original: original(product, fault))
    }

    private static func oauth(_ fault: APIFault) -> Classification {
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
        return Classification(kind: kind, original: original(.oauth, fault))
    }

    private static func original(_ product: Product, _ fault: APIFault) -> Original {
        var extra: [String: String] = [:]
        if let state = fault.state { extra["state"] = state }
        if let domain = fault.domain { extra["domain"] = domain }
        if let uri = fault.errorURI { extra["errorURI"] = uri }
        return Original(provider: product.rawValue, status: fault.status, code: fault.reason, text: fault.message,
                        extra: extra)
    }
}

enum ScopeEngine {
    static func scopes(for capabilities: Set<Capability>) -> [OAuthScope] {
        var scopes: [OAuthScope] = [.userinfoEmail, .userinfoProfile]
        if capabilities.contains(.mail) { scopes.append(.gmailModify) }
        if capabilities.contains(.calendar) { scopes += [.calendarReadonly, .calendarEvents] }
        if capabilities.contains(.contacts) { scopes += [.contacts, .directoryReadonly] }
        if capabilities.contains(.files) { scopes.append(.drive) }
        return scopes
    }
}

