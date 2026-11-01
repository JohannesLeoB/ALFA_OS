import Core
import Foundation
import Hub
import Observation

@MainActor @Observable
public final class ChatState {
    public enum Note: Equatable, Sendable {
        case cleared
        case rejected(AttachmentFailure)
        case privacyUnreadable
    }

    public struct Pending: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let file: AttachmentRef
    }

    public var draft = ""
    private(set) var scope = ConversationScope.home
    public private(set) var pending: [Pending] = []
    private(set) var busy = false
    public private(set) var note: Note?
    public private(set) var noteSerial = 0
    public private(set) var availableCategories: Set<PrivacyCategory> = []
    @ObservationIgnored private var cleared: [Message] = []
    public let usage: UsageState?
    @ObservationIgnored private let chat: any ChatPort
    @ObservationIgnored private let engine: ConversationEngine
    @ObservationIgnored private let attachments: any AttachmentPort
    @ObservationIgnored private let privacy: any PrivacyPort

    public init(chat: any ChatPort, engine: ConversationEngine, attachments: any AttachmentPort, privacy: any PrivacyPort,
                usage: UsageState? = nil) {
        self.usage = usage
        self.chat = chat
        self.engine = engine
        self.attachments = attachments
        self.privacy = privacy
        engine.observeCategories { [weak self] categories in self?.availableCategories = categories }
    }

    public var turns: [ChatTurn] {
        ThreadEngine.turns(chat.messages(for: scope))
    }

    public var canSend: Bool {
        busy == false && (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || pending.isEmpty == false)
    }

    public func load() {
        do {
            try chat.loadIfNeeded(scope)
        } catch {
            Log.failure("ChatUnloaded", detail: String(describing: error))
        }
    }

    public func attach(_ urls: [URL]) async {
        for url in urls {
            do {
                let file = try await attachments.save(url)
                pending.append(Pending(id: UUID(), file: file))
            } catch let failure as AttachmentFailure {
                show(.rejected(failure))
            } catch {
                show(.rejected(.unreadable(url.lastPathComponent)))
            }
        }
    }

    public func removePending(_ id: Pending.ID) {
        pending.removeAll { $0.id == id }
        sweep()
    }

    public func send(choices: PrivacyChoices, profile: UserProfile? = nil) async -> Bool {
        guard canSend else { return false }
        closeUndo()
        let text = draft
        let files = choices.chatFiles ? pending.map(\.file) : []
        draft = ""
        pending = []
        if choices.chatFiles == false { sweep() }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || files.isEmpty == false else { return false }
        return await run(text, files: files, choices: choices, profile: profile)
    }

    public func retry(choices: PrivacyChoices, profile: UserProfile? = nil) async -> Bool {
        load()
        let messages = chat.messages(for: scope)
        guard busy == false,
              let index = messages.lastIndex(where: { if case .failed = $0.status { true } else { false } }),
              index > 0, messages[index - 1].role == .user else { return false }
        let question = messages[index - 1]
        do {
            try chat.remove([question.id, messages[index].id], from: scope)
        } catch {
            return false
        }
        return await run(question.text, files: ThreadEngine.attachments(question), choices: choices, profile: profile)
    }

    public func stop() {
        engine.cancel()
    }

    public func clear() {
        load()
        let messages = chat.messages(for: scope)
        guard messages.isEmpty == false else { return }
        engine.cancel()
        do {
            try chat.clear(scope)
        } catch {
            return
        }
        cleared = messages.map(Self.settled)
        pending = []
        show(.cleared)
    }

    public func undo() {
        guard note == .cleared else { return }
        let restore = cleared
        note = nil
        if chat.messages(for: scope).isEmpty {
            do {
                for message in restore { try chat.append(message, to: scope) }
            } catch {
                do {
                    try chat.clear(scope)
                } catch {
                    Log.failure("ChatUncleared", detail: String(describing: error))
                }
                show(.cleared)
                return
            }
        }
        cleared = []
        sweep()
    }

    public func dismiss() {
        let closing = note == .cleared
        if closing { cleared = [] }
        note = nil
        if closing { sweep() }
    }

    private func closeUndo() {
        if note == .cleared { dismiss() }
    }

    private func show(_ next: Note) {
        if next != .cleared { closeUndo() }
        note = next
        noteSerial += 1
    }

    private func sweep() {
        guard let stored = try? chat.attachmentPaths() else { return }
        let held = cleared.flatMap(ThreadEngine.attachments) + pending.map(\.file)
        attachments.sweep(keeping: stored.union(held.map(\.relativePath)))
    }

    private func run(_ text: String, files: [AttachmentRef], choices: PrivacyChoices, profile: UserProfile?) async -> Bool {
        load()
        busy = true
        let reading = privacy.current()
        if reading.readable == false { show(.privacyUnreadable) }
        await engine.send(text, scope: scope, context: ConversationContext(profile: profile),
                          privacy: PrivacySnapshot(choices: choices, settings: reading.settings), attachments: files)
        busy = false
        guard let last = chat.messages(for: scope).last else { return false }
        return last.role == .assistant && last.status == .complete
    }

    static func settled(_ message: Message) -> Message {
        guard message.status == .streaming else { return message }
        var copy = message
        copy.id = UUID()
        copy.status = .failed("")
        return copy
    }
}
