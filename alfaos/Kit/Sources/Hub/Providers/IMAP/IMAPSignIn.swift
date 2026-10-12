import Foundation

struct IMAPAppPasswordSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: try IMAPConnection(values: input).values)
    }

    func renew(_ grant: Grant) async throws -> Grant {
        _ = try IMAPConnection(values: grant.values)
        return grant
    }

    func signOut(_ inlet: Inlet) async throws {}
}
