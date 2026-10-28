@MainActor
public final class ClaudeCredential {
    public static let provider = "claude"

    private let setup: any SetupPort
    private let keychain: any KeychainPort

    public init(setup: any SetupPort, keychain: any KeychainPort) {
        self.setup = setup
        self.keychain = keychain
    }

    public func current() -> ClaudeKey? {
        guard let inlet = setup.inlets.first(where: { $0.provider == Self.provider && $0.state.isConnected }),
              let key = try? keychain.get(KeySlot(inlet: inlet.id, name: "key")), !key.isEmpty else { return nil }
        let model = (try? keychain.get(KeySlot(inlet: inlet.id, name: "model"))) ?? ""
        return ClaudeKey(apiKey: key, model: model.isEmpty ? ClaudeKey.defaultModel : model)
    }
}
