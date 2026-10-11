import Foundation
import Security

public enum KeyIntegration: String, CaseIterable, Sendable {
    case google
    case clockodo
    case clickup
    case sevdesk
    case airtable
    case claude
    case konkaapps
    case dhlTracking
    case dhlShipping
    case mail

    public var keychainBase: String {
        switch self {
        case .google:   "google"
        case .clockodo: "clockodo"
        case .clickup:  "clickup"
        case .sevdesk:  "sevdesk"
        case .airtable: "airtable"
        case .claude:   "claude"
        case .konkaapps:   "konkaapps"
        case .dhlTracking: "dhl.tracking"
        case .dhlShipping: "dhl.shipping"
        case .mail:     "mail"
        }
    }

    public var scope: KeyScope {
        switch self {
        case .google, .clockodo, .clickup, .claude, .mail: .personal
        case .airtable, .sevdesk, .konkaapps, .dhlTracking, .dhlShipping: .shared
        }
    }
}

public enum KeyScope: Sendable {
    case personal
    case shared
}

public enum OrphanReason: Equatable, Sendable {
    case legacyShared
    case localIdentity
    case otherIdentity
}

public struct KeyInventoryItem: Equatable, Sendable {
    public let integration: KeyIntegration
    public let scope: KeyScope
    public let connected: Bool
    public let isOrphaned: Bool
    public let orphanReason: OrphanReason?

    public init(
        integration: KeyIntegration,
        scope: KeyScope,
        connected: Bool,
        isOrphaned: Bool,
        orphanReason: OrphanReason?
    ) {
        self.integration = integration
        self.scope = scope
        self.connected = connected
        self.isOrphaned = isOrphaned
        self.orphanReason = orphanReason
    }
}

public protocol StoredKeyLister: Sendable {
    func storedServiceNames() -> [String]
}

public enum KeychainInventory {
    public static func build(
        activeUserID: String,
        storedServiceNames: [String],
        connected: [KeyIntegration: Bool],
        namespace: KeychainNamespace
    ) -> [KeyInventoryItem] {
        KeyIntegration.allCases.map { integration in
            let (orphaned, reason) = orphanState(
                for: integration,
                activeUserID: activeUserID,
                storedServiceNames: storedServiceNames,
                namespace: namespace
            )
            return KeyInventoryItem(
                integration: integration,
                scope: integration.scope,
                connected: connected[integration] ?? false,
                isOrphaned: orphaned,
                orphanReason: reason
            )
        }
    }

    static func orphanState(
        for integration: KeyIntegration,
        activeUserID: String,
        storedServiceNames: [String],
        namespace: KeychainNamespace
    ) -> (isOrphaned: Bool, reason: OrphanReason?) {
        let base = integration.keychainBase
        let prefix = "\(namespace.servicePrefix)\(base)"
        let trimmedActive = activeUserID.trimmingCharacters(in: .whitespacesAndNewlines)

        let effectiveActive = trimmedActive.isEmpty ? "local" : trimmedActive

        var suffixes: [String] = []
        for name in storedServiceNames {
            guard let suffix = userIDSuffix(of: name, base: base, prefix: prefix) else { continue }
            suffixes.append(suffix)
        }

        guard suffixes.isEmpty == false else {
            return (false, nil)
        }

        if suffixes.contains(effectiveActive) {
            return (false, nil)
        }

        let reason: OrphanReason
        if suffixes.contains(where: { $0 == legacySuffixMarker }) {
            reason = .legacyShared
        } else if suffixes.contains("local") {
            reason = .localIdentity
        } else {
            reason = .otherIdentity
        }
        return (true, reason)
    }

    private static let legacySuffixMarker = "\u{0000}legacy"

    private static func userIDSuffix(of serviceName: String, base: String, prefix: String) -> String? {
        if serviceName == prefix {
            return legacySuffixMarker
        }
        let dotted = prefix + "."
        guard serviceName.hasPrefix(dotted) else { return nil }
        let rest = String(serviceName.dropFirst(dotted.count))

        let lastSegment = rest.split(separator: ".").last.map(String.init) ?? rest
        return lastSegment.isEmpty ? nil : lastSegment
    }
}

public struct KeychainMetadataLister: StoredKeyLister {
    private let namespace: KeychainNamespace

    public init(namespace: KeychainNamespace) {
        self.namespace = namespace
    }

    public func storedServiceNames() -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,

            kSecReturnData: false,
            kSecUseAuthenticationUI: kSecUseAuthenticationUISkip
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[CFString: Any]] else {
            return []
        }
        let services = items.compactMap { attributes -> String? in
            attributes[kSecAttrService] as? String
        }
        return services.filter { $0.hasPrefix(namespace.servicePrefix) }
    }
}
