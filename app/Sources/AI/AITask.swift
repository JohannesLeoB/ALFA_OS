import Foundation

/// The kinds of task. The raw values are the keys that the model choice and the settings use.
public enum AITaskKind: String, Sendable, CaseIterable {
    case codeVariant
    case htmlForCSS
    case codeFromScreenshot
    case tokenNames
    case explain
}

/// A design token without a name, as the naming task receives it.
public struct TokenCandidate: Sendable, Equatable, Codable {
    public var id: String
    public var kind: String
    public var value: String

    public init(id: String, kind: String, value: String) {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

/// One task of the assistant. Each task builds its request and reads the answer. Nothing is applied here.
public enum AITask: Sendable, Equatable {
    /// Change a card by an instruction. The files are name and content.
    case codeVariant(language: String, files: [String: String], instruction: String)
    /// Build a page that fits the given CSS.
    case htmlForCSS(css: String)
    /// Build a page from a picture, with a hint.
    case codeFromScreenshot(image: AIImage, hint: String)
    /// Suggest names for unnamed tokens.
    case tokenNames(tokens: [TokenCandidate], scheme: String)
    /// Explain a piece of code.
    case explain(code: String)

    public var kind: AITaskKind {
        switch self {
        case .codeVariant: .codeVariant
        case .htmlForCSS: .htmlForCSS
        case .codeFromScreenshot: .codeFromScreenshot
        case .tokenNames: .tokenNames
        case .explain: .explain
        }
    }

    /// The request for this task with the given model.
    public func request(model: String) -> AIRequest {
        switch self {
        case let .codeVariant(language, files, instruction):
            return AIRequest(
                model: model,
                system: AITaskPrompts.codeSystem,
                messages: [AIMessage(role: .user, blocks: [.text(Self.variantText(language, files, instruction))])],
                maxTokens: AITaskPrompts.codeMaxTokens
            )
        case let .htmlForCSS(css):
            return AIRequest(
                model: model,
                system: AITaskPrompts.htmlSystem,
                messages: [AIMessage(role: .user, blocks: [.text("CSS:\n" + css)])],
                maxTokens: AITaskPrompts.codeMaxTokens
            )
        case let .codeFromScreenshot(image, hint):
            return AIRequest(
                model: model,
                system: AITaskPrompts.codeSystem,
                messages: [AIMessage(role: .user, blocks: [
                    .text("Build this as HTML and CSS. Hint: " + hint),
                    .image(image),
                ])],
                maxTokens: AITaskPrompts.codeMaxTokens
            )
        case let .tokenNames(tokens, scheme):
            return AIRequest(
                model: model,
                system: AITaskPrompts.namesSystem,
                messages: [AIMessage(role: .user, blocks: [.text(Self.namesText(tokens, scheme))])],
                maxTokens: AITaskPrompts.shortMaxTokens
            )
        case let .explain(code):
            return AIRequest(
                model: model,
                system: AITaskPrompts.explainSystem,
                messages: [AIMessage(role: .user, blocks: [.text(code)])],
                maxTokens: AITaskPrompts.shortMaxTokens
            )
        }
    }

    /// Reads the answer of this task. A broken answer throws `AIError.unusableAnswer`.
    public func parse(_ response: AIResponse) throws -> AIProposal {
        switch self {
        case .codeVariant, .htmlForCSS, .codeFromScreenshot:
            return try AITaskParsing.code(response.text)
        case let .tokenNames(tokens, _):
            return try AITaskParsing.names(response.text, tokens: tokens)
        case .explain:
            return try AITaskParsing.explanation(response.text)
        }
    }

    private static func variantText(_ language: String, _ files: [String: String], _ instruction: String) -> String {
        var text = "Language: \(language)\nInstruction: \(instruction)\nFiles:\n"
        for name in files.keys.sorted() {
            text += "```datei:\(name)\n\(files[name] ?? "")\n```\n"
        }
        return text
    }

    private static func namesText(_ tokens: [TokenCandidate], _ scheme: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let list = (try? encoder.encode(tokens)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        return "Scheme: \(scheme)\nTokens: \(list)"
    }
}

/// The result of a task. It is a proposal: nothing is applied to the document.
public enum AIProposal: Sendable, Equatable {
    /// Files with their content, and a note from the answer.
    case code(files: [String: String], note: String)
    /// Token id to the suggested name.
    case names([String: String])
    /// A plain text answer.
    case text(String)
}
