import Assistant
import Observation

@MainActor
@Observable
final class AssistantPrivacy {
    private(set) var settings: PrivacySettings

    @ObservationIgnored private let store: PrivacyStore

    init(store: PrivacyStore) {
        self.store = store
        settings = (try? store.load()) ?? PrivacySettings()
    }

    func shares(_ category: PrivacyCategory) -> Bool { settings.shares(category) }

    func set(_ category: PrivacyCategory, shares: Bool) {
        if shares { settings.disabled.remove(category) } else { settings.disabled.insert(category) }
        try? store.save(settings)
    }
}
