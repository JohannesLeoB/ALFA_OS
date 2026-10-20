import Foundation
import AlfaServices

struct IMAPAppPasswordSignIn: SignInPort {
    let channels: IMAPChannelRegistry

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: try IMAPConnection(values: input).values)
    }

    func renew(_ grant: Grant) async throws -> Grant {
        _ = try IMAPConnection(values: grant.values)
        return grant
    }

    func signOut(_ inlet: Inlet) async throws {
        channels.release(inlet.id)
    }
}
