/// Runs one task end to end: model, limit check, call, booking, reading of the answer.
/// The result is a proposal. The app decides what to apply.
public struct AIService: Sendable {
    private let client: any AIClient
    private let book: SpendBook
    private let choice: AIModelChoice

    public init(client: any AIClient, book: SpendBook, choice: AIModelChoice = AIModelChoice()) {
        self.client = client
        self.book = book
        self.choice = choice
    }

    public func run(_ task: AITask) async throws -> AIProposal {
        let request = task.request(model: choice.model(for: task.kind))
        try await book.checkBeforeSending(request)
        let response = try await client.complete(request)
        // The usage is booked as soon as an answer came, so a broken answer still counts.
        await book.book(response.usage, model: request.model, task: task.kind.rawValue)
        return try task.parse(response)
    }
}
