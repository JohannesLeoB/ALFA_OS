import Foundation

/// Collects the events of a streamed answer into the answer. It keeps what it has read, so a cancelled call
/// still gives the text that arrived before the cancel.
public struct AIStreamAssembler: Sendable {
    /// A block that is still open. Its text or input is complete only when its block stops.
    private enum Open: Sendable {
        case text(String)
        case toolUse(id: String, name: String, json: String)
        case serverToolUse(id: String, name: String, json: String)
    }

    private var open: [Int: Open] = [:]
    /// Finished blocks in their wire form, by index.
    private var finished: [Int: JSONValue] = [:]
    private var id = ""
    private var model = ""
    private var usage = AIUsage()
    private var stopReason: String?

    public init() {}

    /// Applies one event. An error event throws its error.
    public mutating func apply(_ event: AIStreamEvent) throws {
        switch event {
        case let .messageStart(id, model, usage):
            self.id = id
            self.model = model
            self.usage = usage
        case let .textDelta(index, text):
            switch open[index] {
            case let .text(existing)?:
                open[index] = .text(existing + text)
            case nil:
                open[index] = .text(text)
            default:
                break
            }
        case let .toolUseStart(index, id, name):
            open[index] = .toolUse(id: id, name: name, json: "")
        case let .serverToolUseStart(index, id, name):
            open[index] = .serverToolUse(id: id, name: name, json: "")
        case let .toolInputDelta(index, partial):
            switch open[index] {
            case let .toolUse(id, name, json)?:
                open[index] = .toolUse(id: id, name: name, json: json + partial)
            case let .serverToolUse(id, name, json)?:
                open[index] = .serverToolUse(id: id, name: name, json: json + partial)
            default:
                break
            }
        case let .rawBlock(index, block):
            finished[index] = block
        case let .blockStop(index):
            try finish(index)
        case let .messageDelta(stopReason, usage):
            if let stopReason {
                self.stopReason = stopReason
            }
            if let usage {
                self.usage = Self.merged(self.usage, usage)
            }
        case .messageStop:
            break
        case let .error(error):
            throw error
        }
    }

    /// The tool calls that are complete, in the order of the answer.
    public var toolCalls: [AIToolCall] {
        blocks.compactMap { block in
            guard block["type"]?.string == "tool_use",
                  let id = block["id"]?.string,
                  let name = block["name"]?.string,
                  let input = block["input"] else {
                return nil
            }
            return AIToolCall(id: id, name: name, input: input)
        }
    }

    /// The answer as far as it has come. Text of an open block is included; an open tool call is not.
    public var response: AIResponse {
        let text = blocks
            .filter { $0["type"]?.string == "text" }
            .compactMap { $0["text"]?.string }
            .joined()
        return AIResponse(
            text: text,
            stopReason: stopReason,
            usage: usage,
            model: model,
            requestID: id.isEmpty ? nil : id
        )
    }

    /// The blocks in the order of their index: finished blocks, then the open ones that have a complete form.
    private var blocks: [JSONValue] {
        var all = finished
        for (index, block) in open {
            if let wire = Self.partial(block) {
                all[index] = wire
            }
        }
        return all.sorted { $0.key < $1.key }.map(\.value)
    }

    /// Closes a block and stores it in its wire form. Broken tool input is a named error.
    private mutating func finish(_ index: Int) throws {
        guard let block = open.removeValue(forKey: index) else { return }
        switch block {
        case let .text(text):
            finished[index] = .object(["type": .string("text"), "text": .string(text)])
        case let .toolUse(id, name, json):
            finished[index] = .object([
                "type": .string("tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": try Self.input(json),
            ])
        case let .serverToolUse(id, name, json):
            finished[index] = .object([
                "type": .string("server_tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": try Self.input(json),
            ])
        }
    }

    /// The wire form of an open block, or nil when it cannot be complete yet (a tool call without its input).
    private static func partial(_ block: Open) -> JSONValue? {
        switch block {
        case let .text(text):
            return .object(["type": .string("text"), "text": .string(text)])
        case .toolUse, .serverToolUse:
            return nil
        }
    }

    /// The input of a tool call. Empty input is an empty object; text that is not JSON is a named error.
    private static func input(_ json: String) throws -> JSONValue {
        if json.isEmpty {
            return .object([:])
        }
        do {
            return try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        } catch {
            throw AIError.unusableAnswer("the input of a tool call is not valid JSON")
        }
    }

    /// The usage counts only grow while a stream runs, so the larger count of each field is kept.
    private static func merged(_ old: AIUsage, _ new: AIUsage) -> AIUsage {
        AIUsage(
            inputTokens: max(old.inputTokens, new.inputTokens),
            outputTokens: max(old.outputTokens, new.outputTokens),
            cacheReadTokens: max(old.cacheReadTokens, new.cacheReadTokens),
            cacheWriteTokens: max(old.cacheWriteTokens, new.cacheWriteTokens),
            cacheWrite5mTokens: max(old.cacheWrite5mTokens, new.cacheWrite5mTokens),
            cacheWrite1hTokens: max(old.cacheWrite1hTokens, new.cacheWrite1hTokens)
        )
    }
}
