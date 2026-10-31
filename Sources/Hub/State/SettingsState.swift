import Design
import Foundation
import Observation

@MainActor @Observable
public final class SettingsState {
    public var group: SettingsGroup = .connections
    public private(set) var front: String?
    public private(set) var opened = 0
    public private(set) var toast: String?
    public private(set) var toastName: String?
    public private(set) var toastSerial = 0
    public private(set) var toastFailed = false
    public private(set) var toastRetry: (@MainActor () -> Void)?
    public private(set) var appearance: AppearanceChoice = .system
    public private(set) var destination: StartDestination = .mail
    public private(set) var lockOn = true
    public private(set) var lockDelay: LockDelay = .minutes5
    public private(set) var privacy = PrivacyChoices()
    public private(set) var templates: [TemplateStore.Template] = []
    public private(set) var profile = UserProfile()
    public private(set) var company: [String: String] = [:]
    public private(set) var imprint: [String: String] = [:]
    public private(set) var mailStore = MailStoreSettings()
    public private(set) var undoSend = UndoSend.standard
    private(set) var mailboxDisplays: [Inlet.ID: MailboxDisplay] = [:]
    private(set) var mailboxRanges: [Inlet.ID: MailboxRange] = [:]
    private(set) var serverCopies: [Inlet.ID: ServerCopy] = [:]
    private(set) var mailboxImages: [Inlet.ID: Bool] = [:]
    private(set) var mailboxNames: [Inlet.ID: String] = [:]
    private(set) var mailboxSignatures: [Inlet.ID: String] = [:]
    private(set) var signaturesOnNew: [Inlet.ID: Bool] = [:]
    private(set) var signaturesAbove: [Inlet.ID: Bool] = [:]

    @ObservationIgnored private let settings: SettingStore
    @ObservationIgnored private let templateStore: TemplateStore

    public var hasTemplates: Bool { !templates.isEmpty }

    public var currentTemplate: TemplateStore.Template? { templates.first }

    public var currentTemplateText: String? { currentTemplate.flatMap(templateStore.text) }

    public func addTemplate(from url: URL) -> Bool {
        let added = (try? templateStore.add(from: url)) != nil
        templates = templateStore.templates
        return added
    }

    public func removeTemplate(_ template: TemplateStore.Template) -> Bool {
        let removed = (try? templateStore.remove(template)) != nil
        templates = templateStore.templates
        return removed
    }

    public func detailKey(of section: SettingsSection) -> String? {
        section == .templates && hasTemplates ? nil : section.detailKey
    }

    public init(settings: SettingStore, templates: TemplateStore) throws {
        self.settings = settings
        templateStore = templates
        self.templates = templates.templates
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
            name: UserProfile.normalized(text(SettingsKey.identityName) ?? "", finished: true),
            role: UserProfile.normalized(text(SettingsKey.identityRole) ?? "", finished: true),
            code: text(SettingsKey.identityCode) ?? "", phone: text(SettingsKey.identityPhone) ?? "",
            birthdays: flag(SettingsKey.birthdays) ?? false)
        mailStore = MailStoreSettings(
            attachments: flag(SettingsKey.mailStoreAttachments) ?? false,
            limit: text(SettingsKey.mailStoreLimit).flatMap(MailStoreLimit.init(rawValue:)) ?? .standard,
            folder: SettingStore.decoded(stored[SettingsKey.mailStoreFolder], as: Data.self))
        undoSend = text(SettingsKey.undoSend).flatMap(UndoSend.init(rawValue:)) ?? .standard
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
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxServerCopyPrefix) {
            if let copy = text(key).flatMap(ServerCopy.init(rawValue:)) {
                serverCopies[String(key.dropFirst(SettingsKey.mailboxServerCopyPrefix.count))] = copy
            }
        }
        for key in stored.keys where key.hasPrefix(SettingsKey.mailboxImagesPrefix) {
            if let value = flag(key) {
                mailboxImages[String(key.dropFirst(SettingsKey.mailboxImagesPrefix.count))] = value
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
        storeProfile(finished: false)
    }

    public func finishProfile() {
        storeProfile(finished: true)
    }

    private func storeProfile(finished: Bool) {
        profile.name = UserProfile.normalized(profile.name, finished: finished)
        profile.role = UserProfile.normalized(profile.role, finished: finished)
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

    public func setUndoSend(_ value: UndoSend) {
        undoSend = value
        save(SettingsKey.undoSend, value.rawValue)
    }

    public func setStoreAttachments(_ value: Bool) {
        mailStore.attachments = value
        save(SettingsKey.mailStoreAttachments, value)
    }

    public func setStoreLimit(_ value: MailStoreLimit) {
        mailStore.limit = value
        save(SettingsKey.mailStoreLimit, value.rawValue)
    }

    public func setStoreFolder(_ value: Data?) {
        mailStore.folder = value
        guard let value else {
            try? settings.remove(key: SettingsKey.mailStoreFolder)
            return
        }
        save(SettingsKey.mailStoreFolder, value)
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

    public func serverCopy(_ inlet: Inlet.ID) -> ServerCopy {
        serverCopies[inlet] ?? .standard
    }

    public func setServerCopy(_ value: ServerCopy, for inlet: Inlet.ID) {
        serverCopies[inlet] = value
        save(SettingsKey.mailboxServerCopy(inlet), value.rawValue)
    }

    public func loadImages(_ inlet: Inlet.ID) -> Bool {
        mailboxImages[inlet] ?? privacy.loadImages
    }

    public func setLoadImages(_ value: Bool, for inlet: Inlet.ID) {
        mailboxImages[inlet] = value
        save(SettingsKey.mailboxImages(inlet), value)
    }

    public func forget(_ inlet: Inlet.ID) {
        mailboxImages[inlet] = nil
        try? settings.remove(key: SettingsKey.mailboxImages(inlet))
        mailboxDisplays[inlet] = nil
        mailboxRanges[inlet] = nil
        serverCopies[inlet] = nil
        try? settings.remove(key: SettingsKey.mailboxServerCopy(inlet))
        mailboxNames[inlet] = nil
        try? settings.remove(key: SettingsKey.mailboxName(inlet))
        try? settings.remove(key: SettingsKey.mailboxDisplay(inlet))
        try? settings.remove(key: SettingsKey.mailboxRange(inlet))
        clearSignature(inlet)
        let source = ContactSource.googleID(inlet)
        try? settings.remove(key: SettingsKey.contactSource(source))
        try? settings.remove(key: SettingsKey.contactCache(source))
    }

    public func select(_ next: SettingsGroup, showing card: String?) {
        group = next
        front = card
    }

    public func open(_ id: String) {
        front = id
        opened += 1
    }

    public func notify(_ key: String, name: String? = nil, failed: Bool = false, retry: (@MainActor () -> Void)? = nil) {
        toast = key
        toastName = name
        toastFailed = failed
        toastRetry = retry
        toastSerial += 1
    }

    public func dismissToast() {
        toast = nil
        toastName = nil
        toastFailed = false
        toastRetry = nil
    }

    private func save<V: Encodable>(_ key: String, _ value: V) {
        try? settings.store(value, forKey: key)
    }
}

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

@MainActor @Observable
public final class ExportState {
    public private(set) var running = false

    @ObservationIgnored private let port: any ExportPort

    public init(port: any ExportPort = ExportStore()) {
        self.port = port
    }

    public var canRun: Bool { port.isAvailable }

    public var fileName: String { ExportEngine.fileName(at: Date()) }

    public func run(to url: URL) async -> Bool {
        guard !running else { return false }
        running = true
        defer { running = false }
        let port = self.port
        let now = Date()
        return await Task.detached(priority: .utility) { () -> Bool in
            do {
                let source = try port.collect(at: now)
                let archive = try ArchiveEngine.archive(ExportEngine.files(from: source), at: now)
                try port.save(archive, to: url)
                return true
            } catch {
                return false
            }
        }.value
    }
}
