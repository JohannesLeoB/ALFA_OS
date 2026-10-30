import Assistant
import Foundation
import Hub
import Mail

public struct OutlookAccess: ProviderPort {
    public static let providerID = "microsoft"
    static let endpoints = OAuthMailEndpoints(
        incomingHost: "outlook.office365.com", incomingPort: 993, outgoingHost: "smtp.office365.com", outgoingPort: 587)

    public let id: ID = OutlookAccess.providerID
    public let capabilities: Set<Capability> = [.mail]
    public let form: [Field] = []
    public let presets: [Preset] = []
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let oauth: OAuthClient
    private let mail = OAuthMailClient()
    private let clock: @Sendable () -> Date

    public init(registration: Registration, http: any HttpPort = URLSession.shared,
                openBrowser: @escaping @Sendable (URL) async -> Bool, acceptedText: String, unreadableText: String) {
        self.init(registration: registration, http: http, openBrowser: openBrowser,
                  makeRedirect: { OAuthLoopback(acceptedText: acceptedText, unreadableText: unreadableText) },
                  clock: { Date() })
    }

    init(registration: Registration, http: any HttpPort, openBrowser: @escaping @Sendable (URL) async -> Bool,
         makeRedirect: @escaping @Sendable () -> any RedirectPort, clock: @escaping @Sendable () -> Date) {
        let oauth = OAuthClient(registration: registration, http: http)
        self.oauth = oauth
        self.clock = clock
        signIn = SignInClient(oauth: oauth, openBrowser: openBrowser, makeRedirect: makeRedirect, clock: clock)
        probe = ProbeClient(oauth: oauth, mail: mail, clock: clock)
    }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let key = ObjectIdentifier(port)
        let wantsChanges = key == ObjectIdentifier((any ChangePort).self)
        guard wantsChanges || key == ObjectIdentifier((any MailTransportPort).self) else {
            throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        let state = try TokenState(grant: grant)
        let tokens = MailTokenClient(state: state, refresher: oauth, clock: clock, renewal: renewal)
        let made: Any = wantsChanges
            ? mail.changes(for: inlet.id, address: state.identity.address, name: state.identity.name,
                           endpoints: Self.endpoints, tokens: tokens)
            : mail.transport(for: inlet.id, address: state.identity.address, name: state.identity.name,
                             endpoints: Self.endpoints, tokens: tokens)
        guard let typed = made as? P else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
        return typed
    }

    public func offers(personal: Owner) -> [Offer] {
        [Offer(id: "offer.microsoft", provider: id, title: "offer.microsoft", capabilities: [.mail], owner: personal,
               way: .signIn)]
    }

    public func classify(_ error: any Error) -> Classification {
        FailureEngine.classify(error) ?? mail.classify(error)
    }
}
