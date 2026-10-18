import Foundation

public enum GoogleOAuthScope: String, CaseIterable, Codable, Sendable {
    case driveMetadataReadonly  = "https://www.googleapis.com/auth/drive.metadata.readonly"

    case driveReadonly          = "https://www.googleapis.com/auth/drive.readonly"
    case calendarEventsReadonly = "https://www.googleapis.com/auth/calendar.events.readonly"

    case calendarReadonly       = "https://www.googleapis.com/auth/calendar.readonly"
    case calendarEvents         = "https://www.googleapis.com/auth/calendar.events"

    case gmailReadonly          = "https://www.googleapis.com/auth/gmail.readonly"

    case gmailCompose           = "https://www.googleapis.com/auth/gmail.compose"

    case gmailModify            = "https://www.googleapis.com/auth/gmail.modify"
    case contactsReadonly       = "https://www.googleapis.com/auth/contacts.readonly"

    case contacts               = "https://www.googleapis.com/auth/contacts"

    case directoryReadonly      = "https://www.googleapis.com/auth/directory.readonly"

    case userinfoEmail          = "https://www.googleapis.com/auth/userinfo.email"
    case userinfoProfile        = "https://www.googleapis.com/auth/userinfo.profile"

    case driveFile              = "https://www.googleapis.com/auth/drive.file"

    public static let standardScopes: [GoogleOAuthScope] = [

        .driveReadonly, .driveMetadataReadonly,

        .driveFile,
        .calendarEventsReadonly, .calendarReadonly, .calendarEvents, .gmailReadonly,

        .gmailCompose, .gmailModify,

        .contacts, .directoryReadonly,
        .userinfoEmail, .userinfoProfile
    ]
}

public struct GoogleTokens: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date

    public init(accessToken: String, refreshToken: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool { Date() >= expiresAt }
}

public enum GoogleOAuthError: Error, Sendable, Equatable {
    case invalidEndpoint
    case invalidResponse
    case httpError(Int)
    case api(GoogleAPIFault)
    case decodingFailed
    case redirectStateMismatch
    case missingClientID
    case loopbackStartupFailed
    case loopbackCancelled
    case notConnected
    case refreshUnavailable
}

func urlEncodedFormBody(_ values: [String: String]) -> Data {
    values
        .map { key, value in "\(formEscape(key))=\(formEscape(value))" }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
}

private func formEscape(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}
