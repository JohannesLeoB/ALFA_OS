import Foundation
import AlfaServices

public struct GoogleProvider: Provider {
    public let id = "google"
    public let capabilities: Set<Capability> = [.mail, .calendar, .contacts, .files]
    public let form: [Field] = []
    public let presets: [Preset] = []
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let config: GoogleClientConfig
    private let session: URLSession
    private let clock: @Sendable () -> Date
    private let projectsRoot: String?

    public init(config: GoogleClientConfig, openBrowser: @escaping @Sendable (URL) async -> Bool,
                session: URLSession = .shared, signIn: (any SignInPort)? = nil,
                projectsRoot: String? = nil,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.projectsRoot = projectsRoot
        self.session = session
        self.clock = clock
        self.signIn = signIn ?? GoogleSignIn(config: config, session: session, openBrowser: openBrowser, clock: clock)
        self.probe = GoogleProbe(config: config, session: session, clock: clock)
    }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        guard let capability = Self.capability(of: port), inlet.capabilities.contains(capability) else {
            throw HubError.capabilityMissing(inlet.id, Self.capability(of: port) ?? .mail)
        }
        let tokens = GoogleGrantTokenProvider(state: try GoogleTokenState(grant: grant), config: config,
                                              refresher: GoogleTokenRefreshService(session: session), clock: clock,
                                              renewal: renewal)
        let made: Any
        switch capability {
        case .mail:
            made = GmailMailTransport(client: GoogleGmailClient(tokenProvider: tokens, session: session))
        case .files:
            made = GoogleDriveFiles(client: GoogleDriveClient(tokenProvider: tokens, session: session), tokens: tokens,
                                    session: session, root: projectsRoot)
        default:
            throw HubError.capabilityMissing(inlet.id, capability)
        }
        guard let typed = made as? P else { throw HubError.capabilityMissing(inlet.id, capability) }
        return typed
    }

    public func classify(_ error: any Error) -> Classification { GoogleFailure.classify(error) }

    private static func capability(of port: Any.Type) -> Capability? {
        switch port {
        case is (any MailTransport).Type: .mail
        case is (any CalendarPort).Type: .calendar
        case is (any ContactsPort).Type: .contacts
        case is (any FilesPort).Type: .files
        default: nil
        }
    }
}
