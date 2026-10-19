import Foundation
import AlfaServices

struct KeyStatus: Error, Equatable, Sendable {
    let status: Int

    static func of(_ error: any Error) -> KeyStatus? {
        switch error {
        case let error as KeyStatus: return error
        case ClickUpError.httpError(let status): return KeyStatus(status: status)
        case ClockodoError.httpError(let status): return KeyStatus(status: status)
        case ClaudeClientError.httpError(let status): return KeyStatus(status: status)
        case ClaudeClientError.rateLimited: return KeyStatus(status: 429)
        case ClaudeClientError.overloaded: return KeyStatus(status: 529)
        case AirtableError.httpError(let status): return KeyStatus(status: status)
        case AirtableError.validationFailed(let status, _): return KeyStatus(status: status)
        case SevdeskError.httpError(let status): return KeyStatus(status: status)
        case SendungsFehler.keyAbgelehnt(let status): return KeyStatus(status: status)
        case SendungsFehler.netz(let text): return http(text)
        default: return nil
        }
    }

    static func isShape(_ error: any Error) -> Bool {
        switch error {
        case ClickUpError.decodingFailed, ClickUpError.invalidResponse,
             ClockodoError.decodingFailed, ClockodoError.invalidResponse,
             ClaudeClientError.decodingFailed, ClaudeClientError.invalidResponse, ClaudeClientError.emptyResponse,
             AirtableError.decodingFailed, AirtableError.invalidResponse,
             SevdeskError.decodingFailed, SevdeskError.invalidResponse,
             SendungsFehler.parse:
            true
        default:
            false
        }
    }

    private static func http(_ text: String) -> KeyStatus? {
        guard text.hasPrefix("HTTP "), let status = Int(text.dropFirst(5).prefix { $0.isNumber }) else { return nil }
        return KeyStatus(status: status)
    }
}
