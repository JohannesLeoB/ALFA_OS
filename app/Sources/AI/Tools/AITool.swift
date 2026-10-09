import Foundation

/// A tool that a request offers to the model.
public enum AITool: Sendable, Equatable {
    /// A tool that the app runs itself. The model calls it, and the app answers with `AIBlock.toolResult`.
    case client(name: String, description: String, inputSchema: JSONValue)
    /// The web search of the platform. The platform runs the searches and cites the results.
    case webSearch(
        maxUses: Int? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        userLocation: AIUserLocation? = nil
    )
    /// The fetch of web pages and PDF documents by the platform.
    case webFetch(
        maxUses: Int? = nil,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil,
        citations: Bool? = nil,
        maxContentTokens: Int? = nil
    )

    /// The name that the model sees. The tools of a request are sent in the order of these names.
    var name: String {
        switch self {
        case let .client(name, _, _):
            return name
        case .webSearch:
            return "web_search"
        case .webFetch:
            return "web_fetch"
        }
    }
}

/// The region of the user, to localize the web search. At least one field must be set.
public struct AIUserLocation: Sendable, Equatable {
    public var city: String?
    public var region: String?
    /// The two-letter country code (ISO 3166-1 alpha-2).
    public var country: String?
    /// The IANA time zone name.
    public var timezone: String?

    public init(city: String? = nil, region: String? = nil, country: String? = nil, timezone: String? = nil) {
        self.city = city
        self.region = region
        self.country = country
        self.timezone = timezone
    }
}

/// The type names of the platform's server tools. Each is the basic version; later versions add options.
public enum AIToolVersion {
    public static let webSearch = "web_search_20250305"
    public static let webFetch = "web_fetch_20250910"
}
