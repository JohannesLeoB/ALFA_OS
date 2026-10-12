import Foundation
import MykilosServices

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

    public init(config: GoogleClientConfig, openBrowser: @escaping @Sendable (URL) async -> Bool,
                session: URLSession = .shared, signIn: (any SignInPort)? = nil,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.session = session
        self.clock = clock
        self.signIn = signIn ?? GoogleSignIn(config: config, session: session, openBrowser: openBrowser, clock: clock)
        self.probe = GoogleProbe(config: config, session: session, clock: clock)
    }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        guard ObjectIdentifier(port) == ObjectIdentifier((any MailTransport).self), inlet.capabilities.contains(.mail) else {
            throw HubError.capabilityMissing(inlet.id, Self.capability(of: port) ?? .mail)
        }
        let tokens = GoogleGrantTokenProvider(state: try GoogleTokenState(grant: grant), config: config,
                                              refresher: GoogleTokenRefreshService(session: session), clock: clock,
                                              renewal: renewal)
        let client = GoogleGmailClient(tokenProvider: tokens, session: session)
        guard let made = GmailMailTransport(client: client) as? P else {
            throw HubError.capabilityMissing(inlet.id, .mail)
        }
        return made
    }

    private static func capability(of port: Any.Type) -> Capability? {
        switch port {
        case is (any CalendarPort).Type: .calendar
        case is (any ContactsPort).Type: .contacts
        case is (any FilesPort).Type: .files
        default: nil
        }
    }
}
