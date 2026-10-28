import Airtable
import Assistant
import Calculation
import ClickUp
import Clockodo
import Core
import Foundation
import Google
import Hub
import Mail
import Sevdesk
import Shipping
import Storage

@MainActor
final class Assembly {
    static let legacyHubFile = "hub.sqlite"
    static let attachmentsFolder = "attachments"
    static let workshopFactorsKey = "calculation.workshopFactors"
    static let localPerson = Person(id: "local", name: "local")
    static let cadences: [Capability: Duration] = [.mail: .seconds(SheetValues.mailSyncSeconds)]
    static let companySeeds: [(CompanyEntry, String)] = [
        (.address, "company.address"), (.phone, "company.phone"), (.web, "company.web"), (.mail, "company.mail.projects"),
    ]

    let directory: URL
    let database: SQLiteStore
    let settingStore: SettingStore
    let settings: SettingsState
    let keychain: KeychainStore
    let catalog: IntegrationCatalogStore
    let connections: Connections
    let inbox: InboxState
    let receipts: ReceiptStore
    let chatStore: ChatStore
    let privacyStore: PrivacyStore
    let conversationEngine: ConversationEngine
    let conversation: ChatState
    let shelf: ToolShelf

    init(openBrowser: @escaping @Sendable (URL) async -> Bool) throws {
        let directory = DatabaseStore.directory()
        let database = try DatabaseStore.open(in: directory)
        let defaults = UserDefaults.standard
        try LegacyImportStore(database: database, defaults: defaults, legacyFile: directory.appendingPathComponent(Self.legacyHubFile)).run()
        let settingStore = SettingStore(database: database)
        let settings = try SettingsState(settings: settingStore)
        for (entry, key) in Self.companySeeds where settings.company[entry.rawValue]?.isEmpty != false {
            let value = CompanyValues.valueOrEmpty(key)
            if !value.isEmpty { settings.setCompany(entry, value) }
        }
        let keychain = KeychainStore()
        let catalog = IntegrationCatalogStore.standard
        let http = URLSession.shared
        let person = Self.localPerson
        let configuration = Configuration(
            person: person, company: CompanySetup(),
            providers: Self.providers(directory: directory, catalog: catalog, http: http, openBrowser: openBrowser),
            keychain: keychain, cadence: TimerCadence(), cost: CostStore(database: database), catalog: Self.ports(),
            cadences: Self.cadences)
        let connections = try Connections.make(configuration, database: database)

        let events = Broadcast<MailboxEvent>()
        let outbox = OutboxStore(access: connections.access, database: database, events: events)
        let mailbox = MailboxStore(access: connections.access, database: database, outbox: outbox, events: events)
        let inbox = InboxState(mailbox: mailbox, outbox: outbox, contacts: ContactState(defaults: defaults))

        let receipts = ReceiptStore(database: database)
        try receipts.adopt(legacy: defaults)
        let stored = try settingStore.value(Self.workshopFactorsKey, as: [String: Double].self)
        let workshop = WorkshopFactors(stored ?? [:])
        if stored == nil { try settingStore.store(workshop.values, forKey: Self.workshopFactorsKey) }

        let text = TextStore()
        let credential = ClaudeCredential(setup: connections.setup, keychain: keychain)
        let attachments = AttachmentStore(root: directory.appendingPathComponent(Self.attachmentsFolder, isDirectory: true))
        let claude = ClaudeClient(keys: ClaudeKeyStore(credential: credential), http: http, attachments: attachments)
        let chatStore = ChatStore(database: database, userID: person.id)
        let shelf = ToolShelf(
            access: connections.access, setup: connections.setup, keychain: keychain, http: http, text: text,
            notes: NoteStore(database: database, userID: person.id), todos: TodoStore(database: database, userID: person.id),
            journal: JournalStore(database: database), alarm: TodoAlarmClient(text: text), receipts: receipts,
            learning: LearningStore(database: database), audit: AuditStore(database: database), workshop: workshop,
            personID: person.id)

        self.directory = directory
        self.database = database
        self.settingStore = settingStore
        self.settings = settings
        self.keychain = keychain
        self.catalog = catalog
        self.connections = connections
        self.inbox = inbox
        self.receipts = receipts
        self.chatStore = chatStore
        let privacyStore = PrivacyStore(database: database)
        self.privacyStore = privacyStore
        self.shelf = shelf
        let conversationEngine = ConversationEngine(
            chat: chatStore, provider: claude, registry: shelf.registry(), text: text,
            memory: MemoryStore(database: database, userID: person.id), log: IntegrationLogStore(database: database))
        self.conversationEngine = conversationEngine
        conversation = ChatState(chat: chatStore, engine: conversationEngine, attachments: attachments, privacy: privacyStore)
    }

    func reshelve() {
        conversationEngine.update(registry: shelf.registry())
    }

    private static func providers(directory: URL, catalog: IntegrationCatalogStore, http: URLSession,
                                  openBrowser: @escaping @Sendable (URL) async -> Bool) -> [any ProviderPort] {
        let checks: [any ConnectionCheckPort] = [
            Airtable.ConnectionCheck(http: http), ClickUp.ConnectionCheck(http: http), Sevdesk.ConnectionCheck(http: http),
            Clockodo.ConnectionCheck(http: http), Shipping.ConnectionCheck(http: http), ClaudeCheck(http: http), LabelCheck(),
        ]
        var providers: [any ProviderPort] = []
        if let google = google(directory: directory, http: http, openBrowser: openBrowser) { providers.append(google) }
        providers.append(IMAPAccess())
        return providers + KeyAccess.all(checks: checks, catalog: catalog)
    }

    private static func google(directory: URL, http: URLSession,
                               openBrowser: @escaping @Sendable (URL) async -> Bool) -> AccessRouter? {
        guard let config = try? ClientConfigStore(directory: directory).load() else { return nil }
        return AccessRouter(
            config: config, drive: DriveConfigStore.load(in: directory), http: http, openBrowser: openBrowser,
            makeRedirect: {
                OAuthLoopback(
                    acceptedText: String(localized: String.LocalizationValue("google.oauth.accepted")),
                    unreadableText: String(localized: String.LocalizationValue("google.oauth.unreadable")))
            })
    }

    private static func ports() -> PortRegistry {
        var registry = PortRegistry().withMail().withFiles()
        registry.register((any MailSearchPort).self, capability: .mail)
        registry.register((any CalendarPort).self, capability: .calendar)
        registry.register((any GoogleContactsPort).self, capability: .contacts)
        registry.register((any Assistant.DrivePort).self, capability: .files)
        return registry
    }
}

struct ClaudeKeyStore: KeyPort {
    let credential: ClaudeCredential

    func claudeKey() async -> ClaudeKey? {
        await credential.current()
    }
}

struct LabelCheck: ConnectionCheckPort {
    var integration: String { "dhlship" }

    func check(_ values: KeyValues) async throws -> String? {
        nil
    }
}

struct TextStore: TextPort {
    func text(_ key: String, _ arguments: [String]) -> String {
        var result = String(localized: String.LocalizationValue(key))
        for (index, value) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index + 1)}", with: value)
        }
        return result
    }
}

enum DriveConfigStore {
    static let fileName = "google-drive.json"

    private static let inert = DriveConfig(
        projectsRoot: "", forbiddenFolderIDs: [],
        offers: OfferConvention(
            incomingFolderKeyword: "", outgoingFolderKeyword: "", purchaseOrderFolderKeyword: "", invoiceFolderKeyword: "",
            offerFolderKeyword: "", orderFolderKeyword: "", prefixes: [:], documentNumberPattern: "",
            customerNumberPattern: "", versionPattern: ""))

    static func load(in directory: URL) -> DriveConfig {
        (try? Data(contentsOf: directory.appendingPathComponent(fileName)))
            .flatMap { try? JSONDecoder().decode(DriveConfig.self, from: $0) } ?? inert
    }
}
