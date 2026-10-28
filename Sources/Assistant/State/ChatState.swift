import Core
import Foundation
import Hub
import Observation

@MainActor @Observable
public final class ChatState {
    public enum Note: Equatable, Sendable {
        case cleared
        case rejected(AttachmentStore.Failure)
    }

    public var draft = ""
    public private(set) var scope = ConversationScope.home
    public private(set) var pending: [AttachmentRef] = []
    public private(set) var busy = false
    public private(set) var note: Note?
    public private(set) var noteSerial = 0
    @ObservationIgnored private var cleared: [Message] = []
    @ObservationIgnored private let chat: ChatStore
    @ObservationIgnored private let engine: ConversationEngine
    @ObservationIgnored private let attachments: AttachmentStore
    @ObservationIgnored private let privacy: PrivacyStore

    public init(chat: ChatStore, engine: ConversationEngine, attachments: AttachmentStore, privacy: PrivacyStore) {
        self.chat = chat
        self.engine = engine
        self.attachments = attachments
        self.privacy = privacy
    }

    public var turns: [ChatTurn] {
        ThreadEngine.turns(chat.messages(for: scope))
    }

    public var canSend: Bool {
        busy == false && (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || pending.isEmpty == false)
    }

    public func load() {
        try? chat.loadIfNeeded(scope)
    }

    public func attach(_ files: [Attachment]) {
        for file in files {
            do {
                pending.append(try attachments.save(file))
            } catch let failure as AttachmentStore.Failure {
                show(.rejected(failure))
            } catch {
                show(.rejected(.unreadable(file.filename)))
            }
        }
    }

    public func refuse(_ fileName: String) {
        show(.rejected(.unreadable(fileName)))
    }

    public func removePending(at index: Int) {
        guard pending.indices.contains(index) else { return }
        pending.remove(at: index)
    }

    public func send(choices: PrivacyChoices) async -> Bool {
        guard canSend else { return false }
        let text = draft
        let files = pending
        draft = ""
        pending = []
        return await run(text, files: files, choices: choices)
    }

    public func retry(choices: PrivacyChoices) async -> Bool {
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
        return await run(question.text, files: ThreadEngine.attachments(question), choices: choices)
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
        let restore = cleared
        cleared = []
        dismiss()
        for message in restore { try? chat.append(message, to: scope) }
    }

    public func dismiss() {
        if note == .cleared { cleared = [] }
        note = nil
    }

    private func show(_ next: Note) {
        note = next
        noteSerial += 1
    }

    private func run(_ text: String, files: [AttachmentRef], choices: PrivacyChoices) async -> Bool {
        load()
        busy = true
        let settings = (try? privacy.load()) ?? PrivacySettings()
        await engine.send(text, scope: scope, privacy: PrivacySnapshot(choices: choices, settings: settings), attachments: files)
        busy = false
        guard let last = chat.messages(for: scope).last else { return false }
        return last.role == .assistant && last.status == .complete
    }

    static func settled(_ message: Message) -> Message {
        guard message.status == .streaming else { return message }
        var copy = message
        copy.status = .failed("")
        return copy
    }
}
