import Foundation
import Observation

@MainActor @Observable
public final class ContactSourceState {
    public private(set) var feeds: [ContactFeed] = []
    private var switches: [String: Bool] = [:]
    private var cached: [String: [ContactPerson]] = [:]

    @ObservationIgnored private let settings: SettingStore?

    public init(settings: SettingStore? = nil) {
        self.settings = settings
        load(ContactSource.mail.id)
    }

    public func configure(_ next: [ContactFeed]) {
        feeds = next
        for feed in next {
            load(feed.source.id)
            if let stored = try? settings?.value(SettingsKey.contactCache(feed.source.id), as: [ContactPerson].self) {
                cached[feed.source.id] = stored
            }
        }
    }

    public func isOn(_ id: String) -> Bool { switches[id] ?? true }

    public func set(_ id: String, on: Bool) {
        switches[id] = on
        try? settings?.store(on, forKey: SettingsKey.contactSource(id))
    }

    public var people: [ContactPerson] {
        ContactMergeEngine.merge(feeds.filter { isOn($0.source.id) }.map { cached[$0.source.id] ?? [] })
    }

    public func refresh() async {
        for feed in feeds where isOn(feed.source.id) {
            guard let fetched = try? await feed.port.people() else { continue }
            cached[feed.source.id] = fetched
            try? settings?.store(fetched, forKey: SettingsKey.contactCache(feed.source.id))
        }
    }

    private func load(_ id: String) {
        if let stored = try? settings?.value(SettingsKey.contactSource(id), as: Bool.self) { switches[id] = stored }
    }
}
