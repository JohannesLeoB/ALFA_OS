public protocol SignInPort: Sendable {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant
    func signOut(_ inlet: Inlet) async throws
}
