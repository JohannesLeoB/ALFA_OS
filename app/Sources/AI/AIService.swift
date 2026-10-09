/// Runs one task end to end: model, call, reading of the answer.
/// The result is a proposal. The app decides what to apply.
public struct AIService: Sendable {
    private let client: any AIClient
    private let choice: AIModelChoice

    public init(client: any AIClient, choice: AIModelChoice = AIModelChoice()) {
        self.client = client
        self.choice = choice
    }

    public func run(_ task: AITask) async throws -> AIProposal {
        let request = task.request(model: choice.model(for: task.kind))
        let response = try await client.complete(request)
        return try task.parse(response)
    }
}
