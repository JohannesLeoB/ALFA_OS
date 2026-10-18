import Foundation
import AlfaKit

public enum ClaudeClientError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case emptyResponse
    case rateLimited(retryAfter: Int?)
    case overloaded
    case streamInterrupted
}

public protocol AssistantLLMProviding: Sendable {
    func summarize(projectID: String, signals: [WidgetSignal], insights: [AssistantInsight]) async throws -> String
}

public protocol ClaudeHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ClaudeHTTPClient {}

public struct ClaudeMessagesClient: AssistantLLMProviding {
    private let credentialsStore: ClaudeCredentialsStoring
    private let httpClient: ClaudeHTTPClient
    private let baseURL: URL

    public init(
        credentialsStore: ClaudeCredentialsStoring = KeychainClaudeCredentialsStore(),
        httpClient: ClaudeHTTPClient = URLSession.shared,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.credentialsStore = credentialsStore
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func summarize(projectID: String, signals: [WidgetSignal], insights: [AssistantInsight]) async throws -> String {
        guard let credentials = try credentialsStore.load() else { throw ClaudeClientError.notConnected }
        let request = try Self.buildRequest(
            url: baseURL,
            credentials: credentials,
            projectID: projectID,
            signals: signals,
            insights: insights
        )

        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClaudeClientError.httpError(http.statusCode) }
        return try Self.parseSummary(from: data)
    }

    static func buildRequest(
        url: URL,
        credentials: ClaudeCredentials,
        projectID: String,
        signals: [WidgetSignal],
        insights: [AssistantInsight]
    ) throws -> URLRequest {
        let payload = buildRequestPayload(
            model: credentials.model,
            projectID: projectID,
            signals: signals,
            insights: insights
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    static func buildRequestPayload(
        model: String,
        projectID: String,
        signals: [WidgetSignal],
        insights: [AssistantInsight]
    ) -> ClaudeMessagesRequest {
        ClaudeMessagesRequest(
            model: model,
            maxTokens: 420,
            system: """
            Du bist der mykilOS-Projektassistent. Formuliere knapp, konkret und auf Deutsch. \
            Erfinde keine Fakten. Schreibaktionen duerfen nur als Vorschlag erscheinen und nie als erledigt.
            """,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: """
                    Projekt: \(projectID)

                    Signale:
                    \(signals.isEmpty ? "- Keine Signale" : signals.map(describe(signal:)).joined(separator: "\n"))

                    Regelbasierte Insights:
                    \(insights.map(describe(insight:)).joined(separator: "\n"))

                    Erzeuge eine natuerlichsprachliche Zusammenfassung in maximal drei kurzen Saetzen.
                    """
                )
            ]
        )
    }

    static func parseSummary(from data: Data) throws -> String {
        do {
            let response = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)
            let text = response.content
                .compactMap { $0.type == "text" ? $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) : nil }
                .filter { $0.isEmpty == false }
                .joined(separator: "\n\n")
            guard text.isEmpty == false else { throw ClaudeClientError.emptyResponse }
            return text
        } catch let error as ClaudeClientError {
            throw error
        } catch {
            throw ClaudeClientError.decodingFailed
        }
    }

    private static func describe(signal: WidgetSignal) -> String {
        switch signal {
        case .projectFocused(let projectID):
            "- Projekt fokussiert: \(projectID)"
        case .driveFileAdded(let projectID, let fileName):
            "- Drive-Datei in \(projectID): \(fileName)"
        case .offerDetected(let projectID, let label):
            "- Angebot in \(projectID): \(label)"
        case .drawingDetected(let projectID, let label):
            "- Neue Werkzeichnung in \(projectID): \(label)"
        case .reviewSuggested(let projectID, let label):
            "- Review-Vorschlag in \(projectID): \(label)"
        case .budgetThresholdCrossed(let projectID, let ratio):
            "- Budget in \(projectID): \(Int(ratio * 100)) Prozent"
        case .deadlineNear(let projectID, let days):
            "- Deadline in \(projectID): \(days) Tage"
        case .myClickUpTaskDueSoon(let projectID, let taskName, let days):
            "- Eigene Aufgabe in \(projectID): \(taskName) (\(days) Tage)"
        }
    }

    private static func describe(insight: AssistantInsight) -> String {
        let detail = insight.detail.map { " | \($0)" } ?? ""
        return "- [\(insight.priority)] \(insight.summary)\(detail)"
    }
}

struct ClaudeMessagesRequest: Encodable, Equatable {
    var model: String
    var maxTokens: Int
    var system: String
    var messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct ClaudeMessage: Encodable, Equatable {
    var role: String
    var content: String
}

private struct ClaudeMessagesResponse: Decodable {
    var content: [ClaudeContentBlock]
}

private struct ClaudeContentBlock: Decodable {
    var type: String
    var text: String?
}
