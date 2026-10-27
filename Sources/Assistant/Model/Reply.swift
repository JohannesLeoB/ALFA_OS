import Foundation

public struct Reply: Sendable, Equatable {
    public let text: String
    let toolUses: [ToolUse]
    let stopReason: String?
    public let usage: TokenUsage?

    public init(text: String, toolUses: [ToolUse], stopReason: String?, usage: TokenUsage? = nil) {
        self.text = text
        self.toolUses = toolUses
        self.stopReason = stopReason
        self.usage = usage
    }
}

public struct ToolUse: Sendable, Equatable {
    let id: String
    let name: String
    let inputJSON: Data

    init(id: String, name: String, inputJSON: Data) {
        self.id = id
        self.name = name
        self.inputJSON = inputJSON
    }
}

public struct TokenUsage: Sendable, Equatable {
    let input: Int
    let output: Int
    let cacheRead: Int
    let cacheWrite: Int

    init(input: Int, output: Int, cacheRead: Int, cacheWrite: Int) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    var cacheShare: Double {
        let total = input + cacheRead + cacheWrite
        return total == 0 ? 0 : Double(cacheRead) / Double(total)
    }
}
