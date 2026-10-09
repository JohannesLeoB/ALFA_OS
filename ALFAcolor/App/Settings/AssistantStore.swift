import Foundation
import ALFAcolorCore
import AI

/// The keychain account of the key of the platform console. Only the app writes it.
private let assistantKeyAccount = "claude.apiKey"

/// The assistant of the app: the key in the keychain, the model of each task from the settings, and the calls.
/// Credits and limits belong to the console; the app keeps no ledger and no limit of its own.
@MainActor
final class AssistantStore {
    static let shared = AssistantStore()

    private let settings = AppSettings.shared.store
    private let keychain = KeychainStore()

    /// True when a key is stored. A key that is only blanks counts as none.
    var hasKey: Bool {
        guard let key = try? keychain.read(account: assistantKeyAccount) else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Stores the key that the person typed. A blank text removes the stored key.
    func saveKey(_ text: String) throws {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            try keychain.delete(account: assistantKeyAccount)
        } else {
            try keychain.write(key, account: assistantKeyAccount)
        }
    }

    /// Removes the stored key.
    func removeKey() throws {
        try keychain.delete(account: assistantKeyAccount)
    }

    /// Runs one task with the models of the settings. The result is a proposal; nothing is applied here.
    func run(_ task: AITask) async throws -> AIProposal {
        let service = AIService(client: client(), choice: AssistantSettings.modelChoice(settings))
        return try await service.run(task)
    }

    /// Sends one short call with the small model to see whether the key works. The answer is not shown.
    func checkKey() async throws {
        let service = AIService(client: client())
        do {
            _ = try await service.run(.explain(code: "Reply with one word."))
        } catch AIError.unusableAnswer {
            // The call itself worked; only the text was not a result. The key is fine.
        }
    }

    /// The models that the key may use, from the platform. Throws without a key.
    func listModels() async throws -> [AIModelInfo] {
        try await client().listModels()
    }

    private func client() -> AnthropicClient {
        let keychain = self.keychain
        return AnthropicClient(
            transport: URLSessionTransport(),
            keyProvider: { try keychain.read(account: assistantKeyAccount) }
        )
    }
}
