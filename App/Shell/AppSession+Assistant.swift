import AppKit
import Assistant
import Core
import Hub
import UniformTypeIdentifiers

extension AppSession {
    var conversation: ChatState { assembly.conversation }

    var assistantOff: Bool { settings.privacy.assistantOff }

    var assistantFiles: Bool { !assistantOff && settings.privacy.chatFiles }

    var claudeFailed: Bool {
        assembly.connections.setup.inlets.contains { $0.provider == ClaudeCredential.provider && LinkState($0.state) == .failed }
    }

    var assistantHintKey: String {
        if claudeFailed { return "assistant.failed" }
        if panes[desk.currentID] is InboxPane && stackEmpty { return "assistant.noMessage" }
        return "assistant.idle"
    }

    var assistantOffersSettings: Bool { !(panes[desk.currentID] is SettingsPane) }

    func seeAssistant() {
        assistantUnseen = false
        conversation.load()
    }

    func askAssistant() {
        let conversation = conversation
        let choices = settings.privacy
        guard !choices.assistantOff, conversation.canSend else { return }
        Task { answered(await conversation.send(choices: choices)) }
    }

    func retryAssistant() {
        let conversation = conversation
        let choices = settings.privacy
        guard !choices.assistantOff else { return }
        Task { answered(await conversation.retry(choices: choices)) }
    }

    func attachToAssistant() {
        guard assistantFiles else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else {
                conversation.refuse(url.lastPathComponent)
                continue
            }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            conversation.attach([Attachment(filename: url.lastPathComponent, mimeType: mime, data: data)])
        }
    }

    func openAssistantSettings() {
        desk.select("settings")
    }

    private func answered(_ complete: Bool) {
        if complete && !desk.assistantOpen { assistantUnseen = true }
    }
}
