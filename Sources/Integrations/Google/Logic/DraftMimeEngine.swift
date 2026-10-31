import Foundation
import Mail

enum DraftMimeEngine {
    static let messageIDDomain = "mail.gmail.com"

    static func payload(_ draft: Draft) -> [String: String] {
        var message = ["raw": URLSafeEngine.encodeURL(MessageEngine.buildRaw(draft, domain: messageIDDomain))]
        if let thread = draft.threadID?.trimmingCharacters(in: .whitespacesAndNewlines), !thread.isEmpty {
            message["threadId"] = thread
        }
        return message
    }
}
