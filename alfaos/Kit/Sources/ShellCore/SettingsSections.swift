import Foundation
import Observation

public enum SettingsGroup: String, CaseIterable, Sendable {
    case me
    case company
    case connections
    case protection

    public var key: String { "settings.group." + rawValue }

    public var symbol: String {
        switch self {
        case .me: "person"
        case .company: "building"
        case .connections: "plug"
        case .protection: "system"
        }
    }

    public var sections: [SettingsSection] { SettingsSection.allCases.filter { $0.group == self } }
}

public enum SettingsSection: String, CaseIterable, Sendable, Identifiable {
    case identity
    case appearance
    case companyData
    case folders
    case templates
    case integrations
    case keyInventory
    case contacts
    case privacy
    case system
    case imprint

    public var id: String { rawValue }

    public var group: SettingsGroup {
        switch self {
        case .identity, .appearance: .me
        case .companyData, .folders, .templates: .company
        case .integrations, .keyInventory, .contacts: .connections
        case .privacy, .system, .imprint: .protection
        }
    }

    public var symbol: String {
        switch self {
        case .identity: "person"
        case .appearance: "contrast"
        case .companyData: "building"
        case .folders: "folder"
        case .templates: "list"
        case .integrations: "plug"
        case .keyInventory: "key"
        case .contacts: "person"
        case .privacy: "shield"
        case .system: "system"
        case .imprint: "docText"
        }
    }

    public var key: String { "settings.section." + rawValue }

    public var detailKey: String { "settings.section." + rawValue + ".detail" }
}

public enum AppearanceChoice: String, CaseIterable, Sendable {
    case light
    case dark
    case system

    public var key: String { "settings.appearance." + rawValue }
}

public enum StartView: String, CaseIterable, Sendable {
    case mail
    case settings
    case lastOpen

    public var key: String { "settings.start." + rawValue }

    public var appID: String? {
        switch self {
        case .mail: "mail"
        case .settings: "settings"
        case .lastOpen: nil
        }
    }

    public static func stored(_ raw: String?) -> StartView { raw.flatMap(StartView.init(rawValue:)) ?? .mail }
}

public enum LockDelay: String, CaseIterable, Sendable {
    case immediately
    case minute1
    case minutes5
    case minutes15

    public var key: String { "settings.lock.delay." + rawValue }
}

public enum SettingsKey {
    public static let appearance = "appearance"
    public static let startView = "settings.startView"
    public static let lockOn = "settings.lock.on"
    public static let lockDelay = "settings.lock.delay"
    public static let loadImages = "settings.privacy.loadImages"
    public static let assistantOff = "settings.privacy.assistantOff"
    public static let chatFiles = "settings.privacy.chatFiles"
    public static let birthdays = "settings.identity.birthdays"
    public static let identityName = "settings.identity.name"
    public static let identityRole = "settings.identity.role"
    public static let identityCode = "settings.identity.code"
    public static let identityPhone = "settings.identity.phone"

    public static func companyRow(_ id: String) -> String { "settings.company." + id }
    public static func imprintRow(_ id: String) -> String { "settings.imprint." + id }
}

public enum CompanyRow: String, CaseIterable, Sendable {
    case name
    case address
    case phone
    case web
    case mail

    public var key: String { "settings.company.row." + rawValue }
}

public enum ImprintRow: String, CaseIterable, Sendable {
    case author
    case rights
    case signature

    public var key: String { "settings.imprint.row." + rawValue }
}

public enum SettingsLabel: String, CaseIterable, Sendable {
    case version
    case branch
    case database
    case diagnosis

    public var key: String { "settings.label." + rawValue }
}

public struct SettingsStripMark: Identifiable, Equatable, Sendable {
    public enum Run: Equatable, Sendable {
        case group(SettingsGroup)
        case open(String)
        case bring(String)
    }

    public let id: String
    public let face: StripFace
    public let titleKey: String?
    public let title: String
    public let selected: Bool
    public let dot: Bool
    public let run: Run
}

@MainActor
@Observable
public final class SettingsBoard {
    public var group: SettingsGroup = .connections
    public private(set) var cards: [String] = []
    public private(set) var front: String?
    public private(set) var fanned = false
    public private(set) var toast: String?
    public private(set) var toastName: String?

    public init() {}

    public func open(_ id: String) {
        var next = cards.contains(id) ? cards : cards + [id]
        if next.count > Design.Count.stackMaxCards { next = Array(next.suffix(Design.Count.stackMaxCards)) }
        cards = next
        front = id
        fanned = false
    }

    public func close(_ id: String) {
        cards.removeAll { $0 == id }
        if front == id { front = cards.last }
        if cards.isEmpty { fanned = false }
    }

    public func bring(_ id: String) {
        front = id
        fanned = false
    }

    public func toggleFan() {
        guard !cards.isEmpty || fanned else { return }
        fanned.toggle()
    }

    public func notify(_ key: String, name: String? = nil) {
        toast = key
        toastName = name
    }

    public func stripMarks(_ lane: Lane, height: Double, entries: [String], failed: Set<String>,
                           title: (String) -> String) -> [SettingsStripMark] {
        func initial(_ id: String) -> StripFace { .text(String(title(id).prefix(1))) }
        switch lane {
        case .leading:
            return SettingsGroup.allCases.map { item in
                SettingsStripMark(id: "group." + item.rawValue, face: .glyph(Icon(rawValue: item.symbol) ?? .system), titleKey: item.key, title: "",
                                  selected: group == item, dot: false, run: .group(item))
            }
        case .center:
            let room = max(1, Int((height - Design.Size.stripReserveTop - Design.Size.stripReserveBottom) / Design.Size.rowHeight))
            return entries.prefix(room).map { id in
                SettingsStripMark(id: "entry." + id, face: initial(id), titleKey: nil, title: title(id), selected: front == id,
                                  dot: failed.contains(id), run: .open(id))
            }
        case .trailing:
            return cards.map { id in
                SettingsStripMark(id: "card." + id, face: initial(id), titleKey: nil, title: title(id), selected: false, dot: false,
                                  run: .bring(id))
            }
        }
    }

    public func run(_ mark: SettingsStripMark.Run) {
        switch mark {
        case .group(let next): group = next
        case .open(let id): open(id)
        case .bring(let id): bring(id)
        }
    }

    public func dismissToast() {
        toast = nil
        toastName = nil
    }
}
