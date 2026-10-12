import Foundation
import GRDB
import Hub
import enum MykilosServices.GoogleOAuthError
import enum MykilosServices.GoogleGmailError
import struct MykilosServices.GoogleAPIFault
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class FailureTests: XCTestCase {
    private let google = GoogleProvider(config: GoogleClientConfig(clientID: "id", clientSecret: ""),
                                        openBrowser: { _ in false })

    func testGmailKeepsStatusReasonTextAndBody() {
        let body = Data(#"{"error":{"code":403,"message":"User-rate limit exceeded.","errors":[{"domain":"usageLimits","reason":"userRateLimitExceeded","message":"User-rate limit exceeded."}],"status":"PERMISSION_DENIED"}}"#.utf8)
        let result = google.classify(GoogleGmailError.api(GoogleAPIFault(status: 403, data: body)))
        XCTAssertEqual(result.kind, .transient)
        XCTAssertEqual(result.original.provider, "gmail")
        XCTAssertEqual(result.original.status, 403)
        XCTAssertEqual(result.original.code, "userRateLimitExceeded")
        XCTAssertEqual(result.original.text, "User-rate limit exceeded.")
        XCTAssertEqual(result.original.extra["domain"], "usageLimits")
        XCTAssertEqual(result.original.extra["state"], "PERMISSION_DENIED")
        XCTAssertEqual(result.original.body, String(decoding: body, as: UTF8.self))
        let hint = Hint(text: "hint.provider.transient", classification: result)
        XCTAssertEqual(hint.code, "gmail.403.userRateLimitExceeded")
        XCTAssertEqual(hint.codeKey, "hint.code.gmail.403.userRateLimitExceeded")
        XCTAssertEqual(hint.detail, "User-rate limit exceeded.")
    }

    func testGmailTableOfTheGoogleErrorPage() {
        func kind(_ status: Int, _ reason: String?) -> FailureKind {
            google.classify(GoogleGmailError.api(GoogleAPIFault(status: status, reason: reason))).kind
        }
        XCTAssertEqual(kind(403, "rateLimitExceeded"), .transient)
        XCTAssertEqual(kind(403, "dailyLimitExceeded"), .rejected)
        XCTAssertEqual(kind(429, nil), .transient)
        XCTAssertEqual(kind(500, "backendError"), .transient)
        XCTAssertEqual(kind(503, nil), .transient)
        XCTAssertEqual(kind(401, "authError"), .signIn)
        XCTAssertEqual(kind(404, "notFound"), .rejected)
    }

    func testOAuthKeepsErrorAndDescription() {
        let body = Data(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#.utf8)
        let result = google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 400, data: body)))
        XCTAssertEqual(result.kind, .signIn)
        XCTAssertEqual(result.original.provider, "oauth")
        XCTAssertEqual(result.original.status, 400)
        XCTAssertEqual(result.original.code, "invalid_grant")
        XCTAssertEqual(result.original.text, "Token has been expired or revoked.")
        XCTAssertEqual(result.original.label, "oauth.400.invalid_grant")
        XCTAssertEqual(google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 400, reason: "invalid_request"))).kind,
                       .rejected)
        XCTAssertEqual(google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 503))).kind, .transient)
    }

    func testImapKeepsResponseCodeAndServerText() {
        let imap = IMAPProvider()
        let denied = imap.classify(MailTransportError.authenticationRejected("NO [AUTHENTICATIONFAILED] Invalid credentials"))
        XCTAssertEqual(denied.kind, .signIn)
        XCTAssertEqual(denied.original.provider, "imap")
        XCTAssertEqual(denied.original.code, "AUTHENTICATIONFAILED")
        XCTAssertEqual(denied.original.text, "NO [AUTHENTICATIONFAILED] Invalid credentials")
        XCTAssertEqual(denied.original.extra["status"], "NO")
        let down = imap.classify(MailTransportError.serverRejected("NO [UNAVAILABLE] Maintenance"))
        XCTAssertEqual(down.kind, .transient)
        XCTAssertEqual(down.original.code, "UNAVAILABLE")
        XCTAssertEqual(down.original.text, "NO [UNAVAILABLE] Maintenance")
        XCTAssertEqual(imap.classify(MailTransportError.serverRejected("BAD Command unknown")).kind, .rejected)
    }

    func testSmtpKeepsReplyCodeEnhancedCodeAndText() {
        let imap = IMAPProvider()
        let auth = imap.classify(MailTransportError.authenticationRejected("535 5.7.8 Authentication credentials invalid"))
        XCTAssertEqual(auth.kind, .signIn)
        XCTAssertEqual(auth.original.provider, "smtp")
        XCTAssertEqual(auth.original.status, 535)
        XCTAssertEqual(auth.original.code, "5.7.8")
        XCTAssertEqual(auth.original.text, "535 5.7.8 Authentication credentials invalid")
        let later = imap.classify(MailTransportError.smtpRejected(451, "4.3.0 Try again later"))
        XCTAssertEqual(later.kind, .transient)
        XCTAssertEqual(later.original.code, "4.3.0")
        XCTAssertEqual(later.original.text, "4.3.0 Try again later")
        let relay = imap.classify(MailTransportError.recipientRejected("a@x.test", 550, "5.7.1 Relay denied"))
        XCTAssertEqual(relay.kind, .rejected)
        XCTAssertEqual(relay.original.extra["recipient"], "a@x.test")
        XCTAssertEqual(relay.original.status, 550)
    }

    func testHealthFollowsTheDocumentedCases() async throws {
        let rig = try Repro3Rig.make()
        let inlet = try await rig.connect("a@x")
        XCTAssertEqual(rig.hub.setup.health(of: inlet.id), .online)
        rig.provider.mail.setFailure(.serverRejected("NO [UNAVAILABLE] Maintenance"))
        await rig.cadence.trigger(inlet.id, .mail)
        XCTAssertEqual(rig.hub.setup.health(of: inlet.id), .limited)
        XCTAssertEqual(rig.hub.access.health(of: inlet.id), .limited)
        XCTAssertTrue(rig.hub.setup.inlets[0].state.isConnected)
        rig.provider.mail.setFailure(nil)
        await rig.cadence.trigger(inlet.id, .mail)
        XCTAssertEqual(rig.hub.setup.health(of: inlet.id), .online)
        rig.provider.mail.setFailure(.authenticationRejected("NO [AUTHENTICATIONFAILED] Invalid credentials"))
        await rig.cadence.trigger(inlet.id, .mail)
        XCTAssertEqual(rig.hub.setup.health(of: inlet.id), .failed)
        let state = rig.hub.setup.inlets[0].state
        XCTAssertEqual(state.hint?.text, "hint.signin.expired")
        XCTAssertEqual(state.hint?.original?.code, "AUTHENTICATIONFAILED")
    }

    func testReportKeepsTheOriginalAcrossARestart() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let rig = try Repro3Rig.make(database: database, keychain: keychain)
        let inlet = try await rig.connect("a@x")
        rig.provider.mail.setFailure(.smtpRejected(451, "4.3.0 Try again later"))
        await rig.cadence.trigger(inlet.id, .mail)
        let again = try Repro3Rig.make(database: database, provider: rig.provider, keychain: keychain)
        let entry = try XCTUnwrap(again.hub.setup.report(for: inlet.id).first)
        XCTAssertEqual(entry.event, .sync)
        XCTAssertEqual(entry.capability, .mail)
        XCTAssertFalse(entry.ok)
        XCTAssertEqual(entry.kind, .transient)
        XCTAssertEqual(entry.original?.code, "4.3.0")
        XCTAssertEqual(entry.original?.status, 451)
        XCTAssertEqual(entry.original?.text, "4.3.0 Try again later")
        XCTAssertEqual(again.hub.setup.health(of: inlet.id), .limited)
        let stored = again.hub.setup.inlets[0].state
        XCTAssertTrue(stored.isConnected)
    }

    func testReportIsLimitedPerInlet() async throws {
        let provider = FakeProvider(capabilities: [.mail])
        let cadence = HandCadence()
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Repro3Rig.mailOffer]),
            providers: [provider], keychain: FakeKeychain(), cadence: cadence, cost: FakeCost(), catalog: .withMail,
            database: try DatabaseQueue(), reportLimit: 3))
        let inlet = try await hub.setup.add(Repro3Rig.mailOffer, input: .fields(["address": "a@x"]))
        for number in 1...5 {
            provider.mail.setFailure(.smtpRejected(450, "4.2.0 Attempt \(number)"))
            await cadence.trigger(inlet.id, .mail)
        }
        let entries = hub.setup.report(for: inlet.id)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map { $0.original?.text }, ["4.2.0 Attempt 5", "4.2.0 Attempt 4", "4.2.0 Attempt 3"])
    }

    func testSignInDeadlineEndsWithTheSignInTimeout() async throws {
        let stuck = StuckSignIn()
        let provider = FakeProvider(capabilities: [.mail], signIn: stuck)
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Repro3Rig.mailOffer]),
            providers: [provider], keychain: FakeKeychain(), cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue(),
            deadlines: HubDeadlines(signIn: .milliseconds(200), probe: .seconds(5))))
        do {
            _ = try await hub.setup.add(Repro3Rig.mailOffer, input: .none)
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            XCTAssertEqual(hint.text, "hint.signin.timeout")
        }
        XCTAssertEqual(hub.setup.inlets, [])
    }
}

private struct StuckSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        try await Task.sleep(for: .seconds(3600))
        return Grant(values: [:])
    }

    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}
