import Foundation

/// A place in the app that can be empty. Each place has exactly one next step.
public enum EmptyPlace: String, CaseIterable, Sendable {
    case canvas, collection, tokens, inspector, lab, search
}

/// What a button on an empty place does. The shell maps each case to a command.
public enum NextAction: String, CaseIterable, Sendable {
    case openExample, newSwatch, newCodeCard, clearSearch
}

/// The one next step of an empty place: a sentence and, when there is something to do, one button.
/// The keys are keys of the string catalog. A step without a button is a hint only.
public struct NextStep: Equatable, Sendable {
    public let textKey: String
    public let buttonKey: String?
    public let action: NextAction?

    public init(textKey: String, buttonKey: String? = nil, action: NextAction? = nil) {
        self.textKey = textKey
        self.buttonKey = buttonKey
        self.action = action
    }
}

extension EmptyPlace {
    /// The next step for this empty place. Every place has one; the text is never empty.
    public var nextStep: NextStep {
        switch self {
        case .canvas:
            NextStep(textKey: "empty.canvas.text", buttonKey: "empty.canvas.button", action: .openExample)
        case .collection:
            NextStep(textKey: "empty.collection.text")
        case .tokens:
            NextStep(textKey: "empty.tokens.text", buttonKey: "empty.tokens.button", action: .newSwatch)
        case .inspector:
            NextStep(textKey: "empty.inspector.text")
        case .lab:
            NextStep(textKey: "empty.lab.text", buttonKey: "empty.lab.button", action: .newCodeCard)
        case .search:
            NextStep(textKey: "empty.search.text", buttonKey: "empty.search.button", action: .clearSearch)
        }
    }
}
