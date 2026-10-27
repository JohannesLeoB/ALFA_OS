import Design
import Foundation
import Observation

@MainActor @Observable
public final class SettingsState {
    public var group: SettingsGroup = .connections
    public private(set) var cards: [String] = []
    public private(set) var front: String?
    public private(set) var fanned = false
    public private(set) var toast: String?
    public private(set) var toastName: String?
    public private(set) var appearance: AppearanceChoice = .system
    public private(set) var destination: StartDestination = .mail
    public private(set) var lockOn = true
    public private(set) var lockDelay: LockDelay = .minutes5
    public private(set) var privacy = PrivacyChoices()
    public private(set) var profile = UserProfile()
    public private(set) var company: [String: String] = [:]
    public private(set) var imprint: [String: String] = [:]

    @ObservationIgnored private let settings: SettingStore

    public init(settings: SettingStore) throws {
        self.settings = settings
        let stored = try settings.all()
        func text(_ key: String) -> String? { SettingStore.decoded(stored[key], as: String.self) }
        func flag(_ key: String) -> Bool? { SettingStore.decoded(stored[key], as: Bool.self) }
        appearance = text(SettingsKey.appearance).flatMap(AppearanceChoice.init(rawValue:)) ?? .system
        destination = StartDestination.stored(text(SettingsKey.startDestination))
        lockOn = flag(SettingsKey.lockOn) ?? true
        lockDelay = text(SettingsKey.lockDelay).flatMap(LockDelay.init(rawValue:)) ?? .minutes5
        privacy = PrivacyChoices(
            loadImages: flag(SettingsKey.loadImages) ?? false,
            assistantOff: flag(SettingsKey.assistantOff) ?? false,
            chatFiles: flag(SettingsKey.chatFiles) ?? true)
        profile = UserProfile(
            name: text(SettingsKey.identityName) ?? "", role: text(SettingsKey.identityRole) ?? "",
            code: text(SettingsKey.identityCode) ?? "", phone: text(SettingsKey.identityPhone) ?? "",
            birthdays: flag(SettingsKey.birthdays) ?? false)
        for entry in CompanyEntry.allCases { company[entry.rawValue] = text(entry.storageKey) ?? "" }
        for entry in ImprintEntry.allCases { imprint[entry.rawValue] = text(entry.storageKey) ?? "" }
    }

    public func setAppearance(_ value: AppearanceChoice) {
        appearance = value
        save(SettingsKey.appearance, value.rawValue)
    }

    public func setDestination(_ value: StartDestination) {
        destination = value
        save(SettingsKey.startDestination, value.rawValue)
    }

    public func setLockOn(_ value: Bool) {
        lockOn = value
        save(SettingsKey.lockOn, value)
    }

    public func setLockDelay(_ value: LockDelay) {
        lockDelay = value
        save(SettingsKey.lockDelay, value.rawValue)
    }

    public func updatePrivacy(_ change: (inout PrivacyChoices) -> Void) {
        change(&privacy)
        save(SettingsKey.loadImages, privacy.loadImages)
        save(SettingsKey.assistantOff, privacy.assistantOff)
        save(SettingsKey.chatFiles, privacy.chatFiles)
    }

    public func updateProfile(_ change: (inout UserProfile) -> Void) {
        change(&profile)
        save(SettingsKey.identityName, profile.name)
        save(SettingsKey.identityRole, profile.role)
        save(SettingsKey.identityCode, profile.code)
        save(SettingsKey.identityPhone, profile.phone)
        save(SettingsKey.birthdays, profile.birthdays)
    }

    public func setCompany(_ entry: CompanyEntry, _ text: String) {
        company[entry.rawValue] = text
        save(entry.storageKey, text)
    }

    public func setImprint(_ entry: ImprintEntry, _ text: String) {
        imprint[entry.rawValue] = text
        save(entry.storageKey, text)
    }

    public func open(_ id: String) {
        var next = cards.contains(id) ? cards : cards + [id]
        if next.count > Tokens.Count.stackMaxCards { next = Array(next.suffix(Tokens.Count.stackMaxCards)) }
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

    public func dismissToast() {
        toast = nil
        toastName = nil
    }

    private func save<V: Encodable>(_ key: String, _ value: V) {
        try? settings.store(value, forKey: key)
    }
}
