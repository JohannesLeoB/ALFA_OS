import Foundation
import GRDB
import Hub
import protocol MykilosServices.MailTransport
import XCTest

private struct GivenSignIn: SignInPort {
    let grant: Grant

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { grant }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

@MainActor
final class GoogleProviderTests: XCTestCase {
    static let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail],
                             owner: .person("p1"), way: .signIn)

    static let grant = Grant(values: [
        "accessToken": "stub-access",
        "refreshToken": "stub-refresh",
        "expiresAt": String(Date().addingTimeInterval(3600).timeIntervalSince1970)
    ])

    func rig(keychain: FakeKeychain) throws -> Hub {
        let provider = GoogleProvider(
            config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false },
            session: GoogleStubNet.session(),
            signIn: GivenSignIn(grant: Self.grant)
        )
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [provider], keychain: keychain, cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue()
        )
        return try Hub.make(configuration)
    }

    func testGoogleProviderDeliversMailTransportAfterGreenProbe() async throws {
        GoogleStubNet.install { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/userinfo") {
                return (200, Data(#"{"email":"a@example.test","name":"A"}"#.utf8))
            }
            if path.hasSuffix("/labels") {
                return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"},{"id":"Label_1","name":"Kunden","type":"user"},{"id":"Label_2","name":"Archiv","type":"user"}]}"#.utf8))
            }
            return (404, Data())
        }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        let inlet = try await hub.setup.add(Self.offer)
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        XCTAssertEqual(inlet.account, "a@example.test")
        let transport = try hub.access.port(MailTransport.self, for: inlet.id)
        let folders = try await transport.listFolders()
        XCTAssertEqual(folders.first?.role, .inbox)
        XCTAssertEqual(folders.filter { $0.role == .other }.map(\.id), ["Label_2", "Label_1"])
        XCTAssertEqual(folders.filter { $0.role == .other }.map(\.name), ["Archiv", "Kunden"])
        XCTAssertThrowsError(try hub.access.port(CalendarPort.self, for: inlet.id)) {
            XCTAssertEqual($0 as? HubError, .capabilityMissing(inlet.id, .calendar))
        }
    }

    func testRedProbeFailsAndLeavesNothingInTheKeychain() async throws {
        GoogleStubNet.install { _ in (401, Data()) }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        do {
            _ = try await hub.setup.add(Self.offer)
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            XCTAssertEqual(hint.text, "hint.google.userinfo")
            XCTAssertEqual(hint.detail, "HTTP 401")
        }
        XCTAssertEqual(hub.setup.inlets, [])
        XCTAssertTrue(keychain.slots.isEmpty)
    }

    func testRedLabelsProbeNamesTheStatus() async throws {
        GoogleStubNet.install { request in
            if request.url?.path.hasSuffix("/userinfo") == true {
                return (200, Data(#"{"email":"a@example.test"}"#.utf8))
            }
            return (403, Data())
        }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        do {
            _ = try await hub.setup.add(Self.offer)
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            XCTAssertEqual(hint.text, "hint.google.labels")
            XCTAssertEqual(hint.detail, "HTTP 403")
        }
        XCTAssertTrue(keychain.slots.isEmpty)
    }

    func testClientConfigLoadsFromFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try GoogleClientConfig.load(from: folder))
        try Data(#"{"clientID":"cid","clientSecret":"sec"}"#.utf8)
            .write(to: folder.appendingPathComponent(GoogleClientConfig.fileName))
        XCTAssertEqual(try GoogleClientConfig.load(from: folder), GoogleClientConfig(clientID: "cid", clientSecret: "sec"))
    }
}
