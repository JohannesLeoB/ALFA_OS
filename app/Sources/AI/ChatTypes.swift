import Foundation

/// One line of the chat as the view shows it, in order.
public enum ChatEntry: Equatable, Sendable {
    /// The text that the user sent.
    case user(text: String)
    /// The text of the assistant so far. It grows while the answer streams.
    case answer(text: String)
    /// The proposals of one answer, waiting for a decision or already decided.
    case proposals(ProposalGroup)
    /// A failure, as a notice with the text key and the button.
    case notice(AssistantNotice)
}

/// Where the conversation stands.
public enum ChatPhase: Equatable, Sendable {
    case idle
    /// The answer is streaming, or a tool result is on its way.
    case streaming
    /// Proposals wait for the user. Nothing goes to the model until the group is accepted or discarded.
    case awaitingDecision(groupID: String)
    /// The call failed. The turn is rolled back, so the user can send again.
    case failed(AIError)
    /// The user stopped the answer. The turn is rolled back.
    case cancelled
}
