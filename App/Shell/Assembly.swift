import Airtable
import Assistant
import Calculation
import ClickUp
import Clockodo
import Core
import Design
import Foundation
import Google
import Hub
import Mail
import Microsoft
import Sevdesk
import Shipping
import Storage

@MainActor
final class Assembly {
    static let legacyHubFile = "hub.sqlite"
    static let attachmentsFolder = "attachments"
    static let workshopFactorsKey = "calculation.workshopFactors"
    static let localPerson = Person(id: "local", name: "local")
    static let cadences: [Capability: Cadence] = [.mail: .push]
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
    let mailEvents: Broadcast<MailboxEvent>
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
        let settings = try SettingsState(settings: settingStore, templates: TemplateStore())
        for (entry, key) in Self.companySeeds where settings.company[entry.rawValue]?.isEmpty != false {
            let value = CompanyValuesStore.valueOrEmpty(key)
            if !value.isEmpty { settings.setCompany(entry, value) }
        }
        let keychain = KeychainStore()
        let catalog = IntegrationCatalogStore.standard
        let http = URLSession.shared
        let person = Self.localPerson
        let configuration = Configuration(
            person: person, company: CompanySetup(),
            providers: Self.providers(directory: directory, catalog: catalog, http: http, roots: DriveRootStore(settings: settingStore),
                                      database: database,
                                      openBrowser: openBrowser),
            keychain: keychain, cadence: TimerCadence(), cost: CostStore(database: database), catalog: Self.ports(),
            cadences: Self.cadences,
            writeFailed: { [settings] in settings.notify(SettingsKeys.failedUnknown, failed: true) })
        let connections = try Connections.make(configuration, database: database)

        let events = Broadcast<MailboxEvent>()
        let outbox = OutboxStore(access: connections.access, database: database, events: events)
        let mailbox = MailboxStore(access: connections.access, database: database, outbox: outbox, events: events,
                                   range: { [settings] inlet in settings.range(inlet) },
                                   names: { [settings] inlet in
                                       SenderNames(chosen: settings.mailboxName(inlet), profile: settings.profile.name)
                                   },
                                   serverCopy: { [settings] inlet in settings.serverCopy(inlet) },
                                   attachmentDirectory: directory,
                                   attachmentSettings: { [settings] in settings.mailStore },
                                   attachmentRenew: { [settings] bookmark in settings.setStoreFolder(bookmark) })
        let inbox = InboxState(mailbox: mailbox, outbox: outbox, contacts: ContactState(book: ContactStore(defaults: defaults)),
                               directory: ContactSourceState(settings: settingStore),
                               signatures: { [settings] inlet in settings.signature(inlet) },
                               quoteTexts: {
                                   let appearance = Appearance(dark: false, still: true)
                                   return QuoteTexts(dated: appearance.string("mail.compose.quote.dated"),
                                                     undated: appearance.string("mail.compose.quote.undated"), locale: appearance.locale)
                               },
                               holdChoice: { [settings] in .seconds(settings.undoSend.seconds) },
                               unsubscribePost: UnsubscribeClient.post)

        let receipts = ReceiptStore(database: database)
        try receipts.adopt(legacy: defaults)
        let stored = try settingStore.value(Self.workshopFactorsKey, as: [String: Double].self)
        let workshop = WorkshopFactors(stored ?? [:])
        if stored == nil { try settingStore.store(workshop.values, forKey: Self.workshopFactorsKey) }

        let text = TextStore()
        let credential = ClaudeCredential(setup: connections.setup, keychain: keychain)
        let attachments = AttachmentStore(root: directory.appendingPathComponent(Self.attachmentsFolder, isDirectory: true))
        let usageStore = ClaudeUsageStore(database: database)
        let claude = ClaudeClient(keys: ClaudeKeyStore(credential: credential), http: http, attachments: attachments, usage: usageStore)
        let chatStore = ChatStore(database: database, userID: person.id)
        let shelf = ToolShelf(
            access: connections.access, setup: connections.setup, keychain: keychain, http: http, text: text,
            notes: NoteStore(database: database, userID: person.id), todos: TodoStore(database: database, userID: person.id),
            journal: JournalStore(database: database), alarm: TodoAlarmClient(text: text), receipts: receipts,
            learning: LearningStore(database: database), audit: AuditStore(database: database), workshop: workshop,
            personID: person.id, anchorsFailed: { [settings] in settings.notify(SettingsKeys.failedUnknown, failed: true) })

        self.directory = directory
        self.database = database
        self.settingStore = settingStore
        self.settings = settings
        self.keychain = keychain
        self.catalog = catalog
        self.connections = connections
        self.inbox = inbox
        self.mailEvents = events
        self.receipts = receipts
        self.chatStore = chatStore
        let privacyStore = PrivacyStore(database: database)
        self.privacyStore = privacyStore
        self.shelf = shelf
        let conversationEngine = ConversationEngine(
            chat: chatStore, provider: claude, registry: shelf.registry(), text: text,
            memory: MemoryStore(database: database, userID: person.id), log: IntegrationLogStore(database: database))
        self.conversationEngine = conversationEngine
        conversation = ChatState(chat: chatStore, engine: conversationEngine, attachments: attachments, privacy: privacyStore,
                                 usage: UsageState(store: usageStore))
        refreshContacts()
    }

    func reshelve() {
        conversationEngine.update(registry: shelf.registry())
        refreshContacts()
    }

    func refreshContacts() {
        let directory = inbox.directory
        directory.configure(shelf.contactFeeds())
        Task { await directory.refresh() }
    }

    private static func providers(directory: URL, catalog: IntegrationCatalogStore, http: URLSession, roots: DriveRootStore,
                                  database: SQLiteStore,
                                  openBrowser: @escaping @Sendable (URL) async -> Bool) -> [any ProviderPort] {
        let checks: [any ConnectionCheckPort] = [
            Airtable.ConnectionCheck(http: http), ClickUp.ConnectionCheck(http: http), Sevdesk.ConnectionCheck(http: http),
            Clockodo.ConnectionCheck(http: http), Shipping.ConnectionCheck(http: http), ClaudeCheck(http: http),
        ]
        var providers: [any ProviderPort] = []
        if let google = google(directory: directory, http: http, roots: roots, openBrowser: openBrowser) { providers.append(google) }
        if let outlook = outlook(directory: directory, http: http, openBrowser: openBrowser) { providers.append(outlook) }
        providers.append(IMAPAccess(database: database))
        return providers + KeyAccess.all(checks: checks, catalog: catalog)
    }

    private static func google(directory: URL, http: URLSession, roots: DriveRootStore,
                               openBrowser: @escaping @Sendable (URL) async -> Bool) -> AccessRouter? {
        guard let config = try? ClientConfigStore(directory: directory).load() else { return nil }
        return AccessRouter(
            config: config, drive: DriveConfigStore.load(in: directory), http: http, openBrowser: openBrowser,
            makeRedirect: {
                OAuthLoopback(
                    acceptedPage: signInPage(title: String(localized: String.LocalizationValue("google.oauth.accepted")), accepted: true),
                    unreadablePage: signInPage(title: String(localized: String.LocalizationValue("google.oauth.unreadable")), accepted: false))
            }, roots: roots)
    }

    private static func outlook(directory: URL, http: URLSession,
                                openBrowser: @escaping @Sendable (URL) async -> Bool) -> OutlookAccess? {
        guard let registration = try? RegistrationStore(directory: directory).load() else { return nil }
        return OutlookAccess(
            registration: registration, http: http, openBrowser: openBrowser,
            acceptedPage: signInPage(title: String(localized: String.LocalizationValue("microsoft.oauth.accepted")), accepted: true),
            unreadablePage: signInPage(title: String(localized: String.LocalizationValue("microsoft.oauth.unreadable")), accepted: false))
    }

    private nonisolated static var openURL: String {
        let types = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]]
        guard let scheme = (types?.first?["CFBundleURLSchemes"] as? [String])?.first else { return "" }
        return scheme + "://open"
    }

    private nonisolated static func signInPage(title: String, accepted: Bool) -> String {
        let line = accepted
            ? String(localized: String.LocalizationValue("shell.signin.close"))
            : String(localized: String.LocalizationValue("shell.signin.retry"))
        let texts = SignInPageEngine.Texts(
            language: Bundle.main.preferredLocalizations.first ?? Bundle.main.developmentLocalization ?? "",
            wordmark: AppIdentity.name, title: title, line: line, style: SignInStyle.css, openURL: openURL)
        return accepted ? SignInPageEngine.acceptedPage(texts) : SignInPageEngine.unreadablePage(texts)
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

@MainActor
struct ToolShelf {
    let access: any AccessPort
    let setup: any SetupPort
    let keychain: any KeychainPort
    let http: any Assistant.HttpPort
    let text: any TextPort
    let notes: NoteStore
    let todos: TodoStore
    let journal: JournalStore
    let alarm: any AlarmPort
    let receipts: ReceiptStore
    let learning: LearningStore
    let audit: AuditStore
    let workshop: WorkshopFactors
    let personID: String
    let anchorsFailed: @MainActor () -> Void

    func registry() -> ToolRegistry {
        ToolRegistry(tools: local() + google() + clickUp() + clockodo() + sevdesk() + shipping() + airtable())
    }

    func inlet(_ provider: String, _ capability: Capability? = nil) -> Inlet? {
        setup.inlets.first { inlet in
            inlet.provider == provider && inlet.state.isConnected && (capability.map { inlet.capabilities.contains($0) } ?? true)
        }
    }

    private func local() -> [any ToolPort] {
        [
            CreateNoteTool(notes: notes), UpdateNoteTool(notes: notes), DeleteNoteTool(notes: notes), ListNotesTool(notes: notes),
            CreateTodoTool(todos: todos, alarm: alarm), CompleteTodoTool(todos: todos, alarm: alarm),
            DeleteTodoTool(todos: todos, alarm: alarm), ListTodosTool(todos: todos),
            JournalTool(journal: journal),
            CalculationTool(estimation: estimation(inlet("airtable"))),
        ]
    }

    private func google() -> [any ToolPort] {
        var tools: [any ToolPort] = []
        if let mail = inlet("google", .mail), let port = try? access.port((any MailSearchPort).self, for: mail.id) {
            tools += [ReadMailTool(mail: port), SearchMailTool(mail: port), ProposeMailDraftTool()]
        }
        if let calendar = inlet("google", .calendar), let port = try? access.port((any CalendarPort).self, for: calendar.id) {
            tools += [ListEventsTool(calendar: port), ProposeEventTool(), SuggestEventLinkTool()]
        }
        if let contacts = inlet("google", .contacts), let port = try? access.port((any GoogleContactsPort).self, for: contacts.id) {
            tools += [SearchGoogleContactsTool(contacts: port), ProposeGoogleContactTool()]
        }
        if let files = inlet("google", .files), let port = try? access.port((any Assistant.DrivePort).self, for: files.id) {
            tools.append(ListFolderTool(drive: port))
        }
        return tools
    }

    private func clickUp() -> [any ToolPort] {
        guard let inlet = inlet("clickup") else { return [] }
        let client = ClickUp.ClickUpClient(credentials: ClickUp.CredentialsStore(keychain: keychain, inlet: inlet.id), http: http)
        let board = TaskBoardClient(read: client, write: client)
        return [ListTasksTool(board: board, lists: []), ProposeTaskChangeTool(board: board, lists: [])]
    }

    private func clockodo() -> [any ToolPort] {
        guard let inlet = inlet("clockodo") else { return [] }
        let client = ClockodoClient(credentials: Clockodo.CredentialsStore(keychain: keychain, inlet: inlet.id), http: http)
        return [ListTimeEntriesTool(time: client)]
    }

    private func sevdesk() -> [any ToolPort] {
        inlet("sevdesk") == nil ? [] : [ListDocumentsTool(receipts: receipts)]
    }

    private func shipping() -> [any ToolPort] {
        guard let inlet = inlet("dhl") else { return [] }
        let key = (try? keychain.get(KeySlot(inlet: inlet.id, name: "key"))) ?? nil
        return [TrackShipmentTool(shipments: ShipmentClient(tracking: TrackingClient(apiKey: key, http: http), text: text))]
    }

    func airtableClient(_ inlet: Inlet?) -> Airtable.AirtableClient? {
        inlet.map { Airtable.AirtableClient(credentials: Airtable.CredentialsStore(keychain: keychain, inlet: $0.id), http: http) }
    }

    private func airtable() -> [any ToolPort] {
        guard let client = airtableClient(inlet("airtable")) else { return [] }
        let articles = ArticleStore(fetch: client)
        let stock = StockStore(fetch: client)
        return [SearchCatalogTool(catalog: articles), ListStockTool(stock: stock),
                ProposeCartItemTool(catalog: articles, stock: stock), ProposeContactChangeTool()]
    }

    private func estimation(_ airtable: Inlet?) -> EstimationEngine {
        let client = airtableClient(airtable)
        let learned = LearnedAnchorStore(store: learning)
        let pdf = PdfAnchorStore(store: learning)
        var primary: any PriceAnchorPort = SeedAnchors()
        if let client {
            let anchors = AnchorStore(source: AnchorRowStore(fetch: client), fallback: SeedAnchors())
            Task {
                do { _ = try await anchors.warmUp() } catch { anchorsFailed() }
            }
            primary = anchors
        }
        return learning.estimationEngine(
            anchors: CompositeAnchorStore(primary: primary, learned: learned, pdfLearned: pdf),
            articlePrices: client.map { ArticleStore(fetch: $0) },
            auditStore: audit,
            parameterPort: client.map { EstimationParameterStore(fetch: $0) },
            workshopFactors: workshop,
            actorUserID: personID)
    }
}

extension ToolShelf {
    func contactFeeds() -> [ContactFeed] {
        var feeds: [ContactFeed] = []
        for inlet in setup.inlets where inlet.provider == "google" && inlet.state.isConnected && inlet.capabilities.contains(.contacts) {
            guard let port = try? access.port((any GoogleContactsPort).self, for: inlet.id),
                  let feed = port as? any ContactFeedPort else { continue }
            feeds.append(ContactFeed(source: .google(inlet), port: feed))
        }
        if let client = airtableClient(inlet("airtable")) {
            let customers = CustomerContactStore(fetch: client)
            if customers.configured { feeds.append(ContactFeed(source: .airtable, port: customers)) }
        }
        return feeds
    }
}
