import Foundation
import WebKit

/// Reads the error text that a card page posts through the error channel.
public enum CardError {
    /// Longest text kept. Longer text is cut.
    public static let maxLength = 500

    /// The trimmed text, or nil when the body is not text or is blank.
    public static func message(from body: Any) -> String? {
        guard let text = body as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

/// The script message handler behind the error channel. It holds its owner weakly, because the page keeps the handler.
@available(macOS 26.0, *)
final class CardErrorChannel: NSObject, WKScriptMessageHandler {
    weak var owner: LiveCard?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = CardError.message(from: message.body) else { return }
        // WebKit delivers script messages on the main thread.
        MainActor.assumeIsolated {
            owner?.record(text)
        }
    }
}
