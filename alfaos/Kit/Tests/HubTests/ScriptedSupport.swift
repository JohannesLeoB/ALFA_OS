import Foundation
import GRDB
import Hub
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessageSummary
import struct MykilosServices.MailStoredDraft
import enum MykilosServices.MailFlag
import XCTest

struct ScriptedProvider: Provider {
    let id: String
    let capabilities: Set<Capability>
    let form: [Field] = []
    let presets: [Preset] = []
    let signIn: any SignInPort
    let probe: any ProbePort
    let make: @Sendable (Inlet, Grant, GrantRenewal) throws -> any MailTransport

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        guard ObjectIdentifier(port) == ObjectIdentifier((any MailTransport).self),
              let typed = try make(inlet, grant, renewal) as? P else {
            throw HubError.capabilityMissing(inlet.id, .mail)
        }
        return typed
    }
}

struct SlotsSignIn: SignInPort {
    let values: [String: String]

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { Grant(values: values) }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

struct AcceptingProbe: ProbePort {
    let account: String

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult { ProbeResult(account: account) }
}

struct RenewingTransport: MailTransport {
    let renewal: GrantRenewal
    let gate: Gate

    func listFolders() async throws -> [MailFolder] {
        renewal.renewed(Grant(values: ["token": "renewed"]))
        await gate.wait()
        return []
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        MailMessagePage(messages: [])
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody { MailMessageBody(text: "") }
    func send(_ draft: EmailDraft) async throws {}
    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {}
    func archive(messageID: String) async throws {}
    func move(messageID: String, toFolderID: String) async throws {}
    func trash(messageID: String) async throws {}
    func markSpam(messageID: String) async throws {}
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data { Data() }
    func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] { [] }
    func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String { "" }
    func fetchDraft(messageID: String) async throws -> MailStoredDraft { MailStoredDraft(id: "", draft: EmailDraft(subject: "", body: "")) }
    func deleteDraft(id: String) async throws {}
    func sendDraft(id: String) async throws {}
}

struct CalendarDown: Error {}

@MainActor
struct ScriptedRig {
    let hub: Hub
    let provider: FakeProvider
    let keychain: FakeKeychain
    let cadence: HandCadence
    let database: DatabaseQueue

    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail],
                                 owner: .person("p1"), way: .signIn)
    static let bothOffer = Offer(id: "fake.both", provider: "fake", title: "Both", capabilities: [.mail, .calendar],
                                 owner: .person("p1"), way: .signIn)

    static func make(capabilities: Set<Capability> = [.mail], offer: Offer = ScriptedRig.mailOffer,
                     catalog: PortCatalog = .withMail, database: DatabaseQueue? = nil,
                     provider: FakeProvider? = nil, keychain: FakeKeychain? = nil) throws -> ScriptedRig {
        let provider = provider ?? FakeProvider(capabilities: capabilities)
        let keychain = keychain ?? FakeKeychain()
        let cadence = HandCadence()
        let database = try database ?? DatabaseQueue()
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [offer]), providers: [provider],
            keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: catalog, database: database
        ))
        return ScriptedRig(hub: hub, provider: provider, keychain: keychain, cadence: cadence, database: database)
    }

    func connect(_ address: String, offer: Offer = ScriptedRig.mailOffer) async throws(SetupError) -> Inlet {
        try await hub.setup.add(offer, input: .fields(["address": address]))
    }
}

@MainActor
func scriptedHub(providers: [any Provider], offer: Offer, keychain: any KeychainPort, cadence: any CadencePort,
               database: DatabaseQueue, catalog: PortCatalog = .withMail) throws -> Hub {
    try Hub.make(HubConfiguration(
        person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [offer]), providers: providers,
        keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: catalog, database: database
    ))
}

@MainActor
func eventually(_ timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

struct GoogleRig {
    let hub: Hub
    let keychain: FakeKeychain
    let cadence: HandCadence
    let inlet: Inlet
    let clock: Locked<Date>
}

struct GivenSignIn: SignInPort {
    let grant: Grant

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { grant }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

@MainActor
func scriptedGoogleRig(token: @escaping @Sendable () -> (Int, Data),
                     other: @escaping @Sendable (String) -> (Int, Data)? = { _ in nil },
                     expire: Bool = true) async throws -> GoogleRig {
    let clock = Locked(Date())
    let grant = Grant(values: [
        "accessToken": "old-access",
        "refreshToken": "old-refresh",
        "expiresAt": String(clock.with { $0 }.addingTimeInterval(3600).timeIntervalSince1970)
    ])
    GoogleStubNet.install { request in
        let path = request.url?.path ?? ""
        if path.hasSuffix("/token") { return token() }
        if path.hasSuffix("/userinfo") { return (200, Data(#"{"email":"a@example.test"}"#.utf8)) }
        if path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"}]}"#.utf8)) }
        return other(path) ?? (404, Data())
    }
    let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail],
                      owner: .person("p1"), way: .signIn)
    let keychain = FakeKeychain()
    let cadence = HandCadence()
    let provider = GoogleProvider(
        config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false },
        session: GoogleStubNet.session(), signIn: GivenSignIn(grant: grant), clock: { clock.with { $0 } }
    )
    let hub = try Hub.make(HubConfiguration(
        person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [offer]), providers: [provider],
        keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: .withMail, database: try DatabaseQueue()
    ))
    let inlet = try await hub.setup.add(offer)
    if expire { clock.with { $0 = $0.addingTimeInterval(7200) } }
    return GoogleRig(hub: hub, keychain: keychain, cadence: cadence, inlet: inlet, clock: clock)
}
