import Foundation
import Hub
import Mail

struct ProbeClient: ProbePort {
    static let grantKey = "hint.microsoft.grant"
    static let tokenKey = "hint.microsoft.token"

    let oauth: OAuthClient
    let mail: OAuthMailClient
    let clock: @Sendable () -> Date

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let state: TokenState
        do {
            state = try TokenState(grant: grant)
        } catch {
            return ProbeResult(account: inlet.id, rejection: Hint(text: Self.grantKey, detail: String(describing: error)))
        }
        let tokens = MailTokenClient(state: state, refresher: oauth, clock: clock)
        let token: String
        do {
            token = try await tokens.accessToken()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: state.identity.address, rejection: Self.hint(error))
        }
        return try await mail.probe(
            inlet: inlet.id, address: state.identity.address, name: state.identity.name, endpoints: OutlookAccess.endpoints,
            token: token)
    }

    static func hint(_ error: any Error) -> Hint {
        let classification = FailureEngine.classify(error) ?? Classification.generic(error)
        return Hint(text: tokenKey, detail: classification.detail ?? String(describing: error), kind: classification.kind,
                    original: classification.original)
    }
}
