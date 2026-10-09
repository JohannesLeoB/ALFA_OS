/// Runs one task end to end: model, call, reading of the answer.
/// The result is a proposal. The app decides what to apply.
public struct AIService: Sendable {
    private let client: any AIClient
    private let plan: AssistantPlan

    /// The service with the settings of a plan: the models, effort, thinking and answer length of each task.
    public init(client: any AIClient, plan: AssistantPlan) {
        self.client = client
        self.plan = plan
    }

    /// The service with the models that the user chose, on the stage Normal.
    public init(client: any AIClient, choice: AIModelChoice = AIModelChoice()) {
        var overrides = AssistantOverrides(tier: .normal)
        overrides.models = choice.overrides
        self.init(client: client, plan: AssistantPlan.resolve(overrides))
    }

    public func run(_ task: AITask) async throws -> AIProposal {
        let request = task.request(plan: plan.task(task.kind))
        let response = try await client.complete(request)
        return try task.parse(response)
    }
}
