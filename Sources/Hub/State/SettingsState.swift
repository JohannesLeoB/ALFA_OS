import Design
import Foundation
import Observation

@MainActor @Observable
public final class SettingsState {
    public var group: SettingsGroup = .connections
    public private(set) var cards: [String] = []
    public private(set) var front: String?
    public private(set) var fanned = false
    public private(set) var opened = 0
    public private(set) var toast: String?
    public private(set) var toastName: String?
    public private(set) var toastSerial = 0
    public private(set) var appearance: AppearanceChoice = .system
    public private(set) var destination: StartDestination = .mail
    public private(set) var lockOn = true
    public private(set) var lockDelay: LockDelay = .minutes5
    public private(set) var privacy = PrivacyChoices()
    public private(set) var profile = UserProfile()
    public private(set) var company: [String: String] = [:]
    public private(set) var imprint: [String: String] = [:]
    private(set) var mailboxDisplays: [Inlet.ID: MailboxDisplay] = [:]
    private(set) var mailboxRanges: [Inlet.ID: MailboxRange] = [:]
    private(set) var mailboxNames: [Inlet.ID: String] = [:]
    private(set) var mailboxSignatures: [Inlet.ID: String] = [:]
    private(set) var signaturesOnNew: [Inlet.ID: Bool] = [:]
    private(set) var signaturesAbove: [Inlet.ID: Bool] = [:]

    @ObservationIgnored private let settings: SettingStore

    public init(settings: SettingStore) throws {
        self.settings = settings
        cards = [group.opening]
        front = group.opening
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
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxDisplayPrefix) {
            if let display = text(key).flatMap(MailboxDisplay.init(rawValue:)) {
                mailboxDisplays[String(key.dropFirst(SettingsKey.mailboxDisplayPrefix.count))] = display
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxNamePrefix) {
            if let name = text(key) {
                mailboxNames[String(key.dropFirst(SettingsKey.mailboxNamePrefix.count))] = name
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxSignaturePrefix) {
            if let signature = text(key) {
                mailboxSignatures[String(key.dropFirst(SettingsKey.mailboxSignaturePrefix.count))] = signature
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxSignatureNewPrefix) {
            if let value = flag(key) {
                signaturesOnNew[String(key.dropFirst(SettingsKey.mailboxSignatureNewPrefix.count))] = value
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxSignatureAbovePrefix) {
            if let value = flag(key) {
                signaturesAbove[String(key.dropFirst(SettingsKey.mailboxSignatureAbovePrefix.count))] = value
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxRangePrefix) {
            if let range = text(key).flatMap(MailboxRange.init(rawValue:)) {
                mailboxRanges[String(key.dropFirst(SettingsKey.mailboxRangePrefix.count))] = range
            }
        }
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

    public func display(_ inlet: Inlet.ID) -> MailboxDisplay {
        mailboxDisplays[inlet] ?? .ownName
    }

    public func setDisplay(_ value: MailboxDisplay, for inlet: Inlet.ID) {
        mailboxDisplays[inlet] = value
        save(SettingsKey.mailboxDisplay(inlet), value.rawValue)
    }

    public func mailboxName(_ inlet: Inlet.ID) -> String {
        mailboxNames[inlet] ?? ""
    }

    public func setMailboxName(_ value: String, for inlet: Inlet.ID) {
        mailboxNames[inlet] = value
        save(SettingsKey.mailboxName(inlet), value)
    }

    public func signature(_ inlet: Inlet.ID) -> MailboxSignature? {
        mailboxSignatures[inlet].map {
            MailboxSignature(text: $0, onNew: signaturesOnNew[inlet] ?? true, aboveQuote: signaturesAbove[inlet] ?? false)
        }
    }

    public func setSignature(_ value: String, for inlet: Inlet.ID) {
        mailboxSignatures[inlet] = value
        save(SettingsKey.mailboxSignature(inlet), value)
    }

    public func setSignatureOnNew(_ value: Bool, for inlet: Inlet.ID) {
        signaturesOnNew[inlet] = value
        save(SettingsKey.mailboxSignatureNew(inlet), value)
    }

    public func setSignatureAboveQuote(_ value: Bool, for inlet: Inlet.ID) {
        signaturesAbove[inlet] = value
        save(SettingsKey.mailboxSignatureAbove(inlet), value)
    }

    public func removeSignature(for inlet: Inlet.ID) {
        clearSignature(inlet)
    }

    private func clearSignature(_ inlet: Inlet.ID) {
        mailboxSignatures[inlet] = nil
        signaturesOnNew[inlet] = nil
        signaturesAbove[inlet] = nil
        try? settings.remove(key: SettingsKey.mailboxSignature(inlet))
        try? settings.remove(key: SettingsKey.mailboxSignatureNew(inlet))
        try? settings.remove(key: SettingsKey.mailboxSignatureAbove(inlet))
    }

    public func range(_ inlet: Inlet.ID) -> MailboxRange {
        mailboxRanges[inlet] ?? .standard
    }

    public func setRange(_ value: MailboxRange, for inlet: Inlet.ID) {
        mailboxRanges[inlet] = value
        save(SettingsKey.mailboxRange(inlet), value.rawValue)
    }

    public func forget(_ inlet: Inlet.ID) {
        mailboxDisplays[inlet] = nil
        mailboxRanges[inlet] = nil
        mailboxNames[inlet] = nil
        try? settings.remove(key: SettingsKey.mailboxName(inlet))
        try? settings.remove(key: SettingsKey.mailboxDisplay(inlet))
        try? settings.remove(key: SettingsKey.mailboxRange(inlet))
        clearSignature(inlet)
        let source = ContactSource.googleID(inlet)
        try? settings.remove(key: SettingsKey.contactSource(source))
        try? settings.remove(key: SettingsKey.contactCache(source))
    }

    public func select(_ next: SettingsGroup) {
        group = next
        open(next.opening)
    }

    public func open(_ id: String) {
        cards = [id]
        front = id
        fanned = false
        opened += 1
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
        toastSerial += 1
    }

    public func dismissToast() {
        toast = nil
        toastName = nil
    }

    private func save<V: Encodable>(_ key: String, _ value: V) {
        try? settings.store(value, forKey: key)
    }
}
