import AlfaServices
import Foundation

public actor Session {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let attachmentLimit = 30_000_000
    static let requestLimit = 16_000
    static let removed = "image removed"

    private let credentials: ClaudeCredentialsStoring
    private let http: ClaudeHTTPClient
    private let url: URL
    private let effort: String
    private let pause: @Sendable (Double) async -> Void
    private var queue: [String] = []
    private var halted = false
    private var running = false
    private var work: Task<Void, Never>?

    public init(credentials: ClaudeCredentialsStoring,
                http: ClaudeHTTPClient,
                url: URL = Session.endpoint,
                effort: String = "medium",
                pause: @escaping @Sendable (Double) async -> Void = { seconds in
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }) {
        self.credentials = credentials
        self.http = http
        self.url = url
        self.effort = effort
        self.pause = pause
    }

    public func say(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard running, !trimmed.isEmpty else { return }
        queue.append(trimmed)
    }

    public func stop() {
        halted = true
        work?.cancel()
    }

    public func run(prompt: String, media: [Media] = [], toolbox: any Toolbox, skills: Skillset,
                    style: StyleMaster? = nil, budget: Budget = Budget()) -> AsyncStream<Event> {
        let (stream, out) = AsyncStream<Event>.makeStream()
        guard !running else {
            out.yield(.failed(.malformed("busy")))
            out.finish()
            return stream
        }
        running = true
        halted = false
        queue = []
        let task = Task { [self] in
            await loop(prompt: prompt, media: media, toolbox: toolbox, skills: skills, style: style, budget: budget, out: out)
            out.finish()
        }
        work = task
        out.onTermination = { _ in task.cancel() }
        return stream
    }

    private func loop(prompt: String, media: [Media], toolbox: any Toolbox, skills: Skillset, style: StyleMaster?,
                      budget: Budget, out: AsyncStream<Event>.Continuation) async {
        defer {
            running = false
            work = nil
        }
        do {
            try await drive(prompt: prompt, media: media, toolbox: toolbox, skills: skills, style: style, budget: budget, out: out)
        } catch let failure as Fault {
            out.yield(halted ? .stopped("stop") : .failed(failure))
        } catch {
            out.yield(halted || error is CancellationError ? .stopped("stop") : .failed(.transport(error.localizedDescription)))
        }
    }

    private func drive(prompt: String, media: [Media], toolbox: any Toolbox, skills: Skillset, style: StyleMaster?,
                       budget: Budget, out: AsyncStream<Event>.Continuation) async throws {
        let stored = try credentials.load()
        guard let key = stored?.apiKey, !key.isEmpty else { throw Fault.noKey }
        let model = stored?.model.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !model.isEmpty else { throw Fault.noModel }
        guard media.reduce(0, { $0 + $1.data.count + $1.note.utf8.count }) <= Self.attachmentLimit else { throw Fault.tooLarge }
        var messages: [JSON] = [try Self.opening(prompt, media)]
        let system = ([skills.prompt] + (style.map { [$0.block] } ?? [])).filter { !$0.isEmpty }.joined(separator: "\n\n")
        let tools = JSON.array(Self.cached(toolbox.tools.map(\.wire)))
        let marked: JSON = system.isEmpty ? .string(system) : .array([["type": "text", "text": .string(system), "cache_control": Self.mark]])
        var used = 0
        var round = 0
        while true {
            if halted || Task.isCancelled {
                out.yield(.stopped("stop"))
                return
            }
            guard round < budget.rounds else {
                out.yield(.stopped("rounds"))
                return
            }
            guard used < budget.tokens else {
                out.yield(.stopped("tokens"))
                return
            }
            round += 1
            let body: JSON = [
                "model": .string(model),
                "max_tokens": .number(Double(min(Self.requestLimit, budget.tokens - used))),
                "thinking": ["type": "adaptive"],
                "output_config": ["effort": .string(effort)],
                "system": marked,
                "tools": tools,
                "messages": .array(messages)
            ]
            let reply = try await exchange(try body.data(), key: key)
            used += Self.spent(reply["usage"])
            let content = reply["content"]?.array ?? []
            for block in content {
                switch block["type"]?.string {
                case "text": if let text = block["text"]?.string, !text.isEmpty { out.yield(.text(text)) }
                case "thinking": if let text = block["thinking"]?.string, !text.isEmpty { out.yield(.thinking(text)) }
                default: break
                }
            }
            messages.append(["role": "assistant", "content": .array(content)])
            let reason = reply["stop_reason"]?.string
            if reason == "refusal" {
                out.yield(.stopped("refusal"))
                return
            }
            if reason == "max_tokens" { throw Fault.truncated }
            let calls = content.filter { $0["type"]?.string == "tool_use" }
            if calls.isEmpty {
                guard !queue.isEmpty else {
                    out.yield(.stopped("end"))
                    return
                }
                messages.append(["role": "user", "content": .array(drain().map(Self.textBlock))])
                continue
            }
            var results: [JSON] = []
            var done: Finish?
            var shown = false
            for call in calls {
                let name = call["name"]?.string ?? ""
                let input = call["input"] ?? [:]
                out.yield(.toolCall(name: name, input: input))
                let result = await toolbox.call(name, input)
                out.yield(.toolResult(name: name, ok: !result.isError, summary: result.summary))
                if let png = result.image {
                    out.yield(.image(png))
                    shown = true
                }
                if !result.isError, done == nil { done = result.finish }
                results.append(result.wire(id: call["id"]?.string ?? ""))
            }
            if let done {
                out.yield(.finished(done))
                return
            }
            if shown { messages = messages.map(Self.withoutImages) }
            messages.append(["role": "user", "content": .array(results + drain().map(Self.textBlock))])
        }
    }

    private func drain() -> [String] {
        defer { queue = [] }
        return queue
    }

    private func exchange(_ body: Data, key: String) async throws -> JSON {
        var attempt = 0
        while true {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 600
            request.httpBody = body
            let (data, response) = try await http.data(for: request)
            guard let reply = response as? HTTPURLResponse else { throw Fault.malformed("response") }
            if (200...299).contains(reply.statusCode) {
                guard let json = JSON.parse(data) else { throw Fault.malformed("reply") }
                return json
            }
            let detail = String(decoding: data.prefix(400), as: UTF8.self)
            guard Retry.retryable(reply.statusCode), attempt < Retry.limit else { throw Fault.http(reply.statusCode, detail) }
            await pause(Retry.delay(attempt: attempt, retryAfter: reply.value(forHTTPHeaderField: "Retry-After")))
            attempt += 1
        }
    }

    static let mark: JSON = ["type": "ephemeral"]

    static func cached(_ tools: [JSON]) -> [JSON] {
        guard var last = tools.last?.object else { return tools }
        last["cache_control"] = mark
        return Array(tools.dropLast()) + [.object(last)]
    }

    static func spent(_ usage: JSON?) -> Int {
        ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"]
            .reduce(0) { $0 + Int(usage?[$1]?.number ?? 0) }
    }

    static func textBlock(_ text: String) -> JSON {
        ["type": "text", "text": .string(text)]
    }

    static func opening(_ prompt: String, _ media: [Media]) throws -> JSON {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !media.isEmpty else { throw Fault.emptyPrompt }
        var content: [JSON] = []
        for item in media {
            content.append(textBlock(item.label))
            if Media.images.contains(item.mediaType) || item.mediaType == Media.document {
                let kind = item.mediaType == Media.document ? "document" : "image"
                content.append(["type": .string(kind),
                                "source": ["type": "base64", "media_type": .string(item.mediaType),
                                           "data": .string(item.data.base64EncodedString())]])
            }
            if !item.note.isEmpty { content.append(textBlock("\(item.label):\n\(item.note)")) }
        }
        if !text.isEmpty { content.append(textBlock(text)) }
        return ["role": "user", "content": .array(content)]
    }

    static func withoutImages(_ message: JSON) -> JSON {
        guard message["role"]?.string == "user", let blocks = message["content"]?.array else { return message }
        let next: [JSON] = blocks.map { block in
            guard block["type"]?.string == "tool_result", let inner = block["content"]?.array,
                  inner.contains(where: { $0["type"]?.string == "image" }),
                  var fields = block.object else { return block }
            fields["content"] = .array(inner.map { $0["type"]?.string == "image" ? textBlock(removed) : $0 })
            return .object(fields)
        }
        return ["role": "user", "content": .array(next)]
    }
}
