import Foundation
import MykilosKit
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
        case .dhlShipping: "dhl.versand"
        case .mail:     "mail"
        }
    }

    public var displayName: String {
        switch self {
        case .google:   "Google Workspace"
        case .clockodo: "Clockodo"
        case .clickup:  "ClickUp"
        case .sevdesk:  "Sevdesk"
        case .airtable: "Airtable"
        case .claude:   "Claude"
        case .konkaapps:   "Konkaapps"
        case .dhlTracking: "DHL Sendungsverfolgung"
        case .dhlShipping: "DHL Versand"
        case .mail:     "Mail"
        }
    }

    public var scope: KeyScope {
        switch self {
        case .google, .clockodo, .clickup, .claude, .mail: .persoenlich
        case .airtable, .sevdesk, .konkaapps, .dhlTracking, .dhlShipping: .geteilt
        }
    }
}

public enum KeyScope: Sendable {
    case persoenlich
    case geteilt

    public var label: String {
        switch self {
        case .persoenlich: "persönlich"
        case .geteilt:     "geteilt"
        }
    }
}

public struct KeyInventoryItem: Equatable, Sendable {
    public let integration: KeyIntegration
    public let scope: KeyScope
    public let connected: Bool
    public let isOrphaned: Bool
    public let orphanHint: String?

    public init(
        integration: KeyIntegration,
        scope: KeyScope,
        connected: Bool,
        isOrphaned: Bool,
        orphanHint: String?
    ) {
        self.integration = integration
        self.scope = scope
        self.connected = connected
        self.isOrphaned = isOrphaned
        self.orphanHint = orphanHint
    }
}

public protocol StoredKeyLister: Sendable {
    func storedServiceNames() -> [String]
}

public enum KeychainInventory {
    public static func build(
        activeUserID: String,
        storedServiceNames: [String],
        connected: [KeyIntegration: Bool]
    ) -> [KeyInventoryItem] {
        KeyIntegration.allCases.map { integration in
            let (orphaned, hint) = orphanState(
                for: integration,
                activeUserID: activeUserID,
                storedServiceNames: storedServiceNames
            )
            return KeyInventoryItem(
                integration: integration,
                scope: integration.scope,
                connected: connected[integration] ?? false,
                isOrphaned: orphaned,
                orphanHint: hint
            )
        }
    }

    static func orphanState(
        for integration: KeyIntegration,
        activeUserID: String,
        storedServiceNames: [String]
    ) -> (isOrphaned: Bool, hint: String?) {
        let base = integration.keychainBase
        let prefix = "\(AppKennung.schluesselbundPraefix)\(base)"
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

        let hint: String
        if suffixes.contains(where: { $0 == legacySuffixMarker }) {
            hint = "Schlüssel liegt unter der alten teamweiten Ablage (ohne Identität) — gehört zu einem älteren Stand."
        } else if suffixes.contains("local") {
            hint = "Schlüssel gehört zu einer abweichenden Identität (\u{201E}local\u{201C}), nicht zur aktiven."
        } else {
            hint = "Schlüssel gehört zu einer anderen/alten Identität, nicht zur aktiven."
        }
        return (true, hint)
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
    public init() {}

    public func storedServiceNames() -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,

            kSecReturnData: false,
            kSecUseAuthenticationUI: kSecUseAuthenticationUISkip,
            kSecUseDataProtectionKeychain: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[CFString: Any]] else {
            return []
        }
        let services = items.compactMap { attributes -> String? in
            attributes[kSecAttrService] as? String
        }
        return services.filter { $0.hasPrefix(AppKennung.schluesselbundPraefix) }
    }
}
