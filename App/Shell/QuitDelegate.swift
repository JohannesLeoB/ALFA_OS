import AppKit

@MainActor
final class QuitDelegate: NSObject, NSApplicationDelegate {
    var flush: (@MainActor () async -> Void)?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let flush else { return .terminateNow }
        Task {
            await flush()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
