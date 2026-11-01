import Assistant
import Foundation
import Hub
import Mail

public struct AccessRouter: ProviderPort {
    public static let providerID = "google"

    public let id: ID = AccessRouter.providerID
    public let capabilities: Set<Capability> = [.mail, .calendar, .contacts, .files]
    public let form: [Field] = []
    public let presets: [Preset] = []
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let oauth: OAuthClient
    private let drive: DriveConfig
    private let roots: DriveRootStore?
    private let clock: @Sendable () -> Date
    private let policy: RequestPolicy
    private let cache = MessageCacheStore()

    public init(config: ClientConfig, drive: DriveConfig, http: any HttpPort = URLSession.shared,
                openBrowser: @escaping @Sendable (URL) async -> Bool,
                makeRedirect: @escaping @Sendable () -> any RedirectPort,
                signIn: (any SignInPort)? = nil, roots: DriveRootStore? = nil,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.init(config: config, drive: drive, http: http, openBrowser: openBrowser, makeRedirect: makeRedirect,
                  signIn: signIn, roots: roots, clock: clock, policy: .standard)
    }

    init(config: ClientConfig, drive: DriveConfig, http: any HttpPort, openBrowser: @escaping @Sendable (URL) async -> Bool,
         makeRedirect: @escaping @Sendable () -> any RedirectPort, signIn: (any SignInPort)?, roots: DriveRootStore?,
         clock: @escaping @Sendable () -> Date, policy: RequestPolicy) {
        let oauth = OAuthClient(config: config, http: http)
        self.oauth = oauth
        self.drive = drive
        self.roots = roots
        self.clock = clock
        self.policy = policy
        self.signIn = signIn ?? SignInClient(oauth: oauth, openBrowser: openBrowser, makeRedirect: makeRedirect, clock: clock)
        self.probe = ProbeClient(oauth: oauth, clock: clock, policy: policy)
    }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let key = ObjectIdentifier(port)
        guard let capability = Self.capability(of: key) else {
            throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        guard inlet.capabilities.contains(capability) else { throw HubFailure.capabilityMissing(inlet.id, capability) }
        let tokens = AccessTokenClient(state: try StoredToken(grant: grant), refresher: oauth, clock: clock, renewal: renewal)
        guard let typed = make(key, inlet: inlet, tokens: tokens) as? P else {
            throw HubFailure.capabilityMissing(inlet.id, capability)
        }
        return typed
    }

    public func offers(personal: Owner) -> [Offer] {
        [
            Offer(id: "offer.gmail", provider: id, title: "offer.gmail", capabilities: [.mail], owner: personal, way: .signIn),
            Offer(id: "offer.google", provider: id, title: "offer.google", capabilities: capabilities, owner: personal,
                  way: .signIn),
        ]
    }

    public func classify(_ error: any Error) -> Classification { GoogleFailureEngine.classify(error) }

    private func make(_ key: ObjectIdentifier, inlet: Inlet, tokens: AccessTokenClient) -> Any? {
        func requests(_ product: Product) -> RequestClient {
            RequestClient(http: oauth.http, tokens: tokens, product: product)
        }
        func driveClient() -> DriveClient {
            DriveClient(requests: requests(.drive), forbiddenFolderIDs: drive.forbiddenFolderIDs)
        }
        switch key {
        case ObjectIdentifier((any MailTransportPort).self), ObjectIdentifier((any GmailPort).self):
            return GmailMailClient(gmail: GmailClient(requests: requests(.gmail), policy: policy))
        case ObjectIdentifier((any MailSearchPort).self):
            return MailSearchClient(gmail: GmailClient(requests: requests(.gmail), policy: policy), cache: cache,
                                    account: inlet.id)
        case ObjectIdentifier((any FilesPort).self):
            return DriveFilesClient(drive: driveClient(), projectsRoot: roots?.current()?.id ?? drive.projectsRoot)
        case ObjectIdentifier((any Assistant.DrivePort).self):
            return DriveListingClient(drive: driveClient(), offers: drive.offers)
        case ObjectIdentifier((any CalendarPort).self):
            return CalendarListingClient(calendar: CalendarClient(requests: requests(.calendar), clock: clock))
        case ObjectIdentifier((any GoogleContactsPort).self):
            return ContactSearchClient(contacts: ContactsClient(requests: requests(.contacts)))
        default:
            return nil
        }
    }

    private static func capability(of key: ObjectIdentifier) -> Capability? {
        switch key {
        case ObjectIdentifier((any MailTransportPort).self), ObjectIdentifier((any GmailPort).self),
             ObjectIdentifier((any MailSearchPort).self): .mail
        case ObjectIdentifier((any FilesPort).self), ObjectIdentifier((any Assistant.DrivePort).self): .files
        case ObjectIdentifier((any CalendarPort).self): .calendar
        case ObjectIdentifier((any GoogleContactsPort).self): .contacts
        default: nil
        }
    }
}

struct ContactSearchClient: GoogleContactsPort {
    let contacts: any ContactsFetchPort

    func search(query: String) async throws -> [GoogleContact] {
        do {
            return try await contacts.searchContacts(query: query).map {
                GoogleContact(displayName: $0.displayName, organization: $0.organization, email: $0.email,
                              phone: $0.phone)
            }
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }
}

struct CalendarListingClient: CalendarPort {
    let calendar: any CalendarFetchPort

    var hasTeamCalendars: Bool { true }

    func calendars() async throws -> [CalendarRef] {
        do {
            return try await calendar.listCalendars().map { CalendarRef(id: $0.id, title: $0.title) }
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }

    func events(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEntry] {
        do {
            return try await calendar.upcomingEvents(calendarID: calendarID, query: query, withinDays: withinDays)
                .map { CalendarEntry(id: $0.id, title: $0.title, startsAt: $0.startsAt, isAllDay: $0.isAllDay,
                                     location: $0.location) }
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }
}

struct DriveFilesClient: FilesPort {
    let drive: any DriveFetchPort
    let projectsRoot: String

    func projectFolders() async throws -> [FileFolder] {
        try await drive.listFolder(folderID: projectsRoot).filter(\.isFolder).map { FileFolder(id: $0.id, name: $0.name) }
    }

    func drives() async throws -> [FileFolder] {
        [FileFolder(id: FileFolder.ownDrive, name: "")] + (try await drive.listDrives()).map { FileFolder(id: $0.id, name: $0.name) }
    }

    func files(in folderID: String) async throws -> [FileEntry] {
        try await drive.listFolder(folderID: folderID)
            .filter { $0.isFolder || !$0.isNative }
            .map { FileEntry(id: $0.id, name: $0.name, mimeType: $0.mimeType, isFolder: $0.isFolder, size: $0.size) }
    }

    func read(_ fileID: String) async throws -> Data {
        try await drive.downloadContent(fileID: fileID)
    }

    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        let file = try await drive.uploadFile(name: name, mimeType: mimeType, data: data, parentFolderID: folderID)
        return FileEntry(id: file.id, name: file.name, mimeType: file.mimeType)
    }
}

extension ContactSearchClient: ContactFeedPort {
    func people() async throws -> [ContactPerson] {
        do {
            return try await contacts.allContacts().compactMap { contact in
                contact.email.map { ContactPerson(name: contact.displayName, address: $0) }
            }
        } catch {
            throw GoogleFailureEngine.port(error)
        }
    }
}
