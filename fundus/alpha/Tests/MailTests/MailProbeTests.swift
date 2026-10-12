import XCTest
@testable import MykilosServices
import MykilosKit

final class MailProbeTests: XCTestCase {
    private func fx(_ key: String) -> String { MailWireFixture.line(key) }

    private var account: MailAccount {
        MailProviderPresets.preset(for: .ionos).account(id: "p", displayName: "", address: "jo@example.test")
    }

    private func imapScript(loginReply: String? = nil) -> ScriptedMailStream {
        let tag = { MailWireFixture.retag("tagged.ok", to: $0) }
        return ScriptedMailStream(
            greeting: [fx("status.validity")],
            replies: [
                ["* CAPABILITY IMAP4rev1", tag("A0001")],
                [loginReply ?? tag("A0002")],
                ["* CAPABILITY IMAP4rev1", tag("A0003")],
                [tag("A0004")],
                [tag("A0005")]
            ])
    }

    private func smtpScript(authReply: String? = nil) -> ScriptedMailStream {
        let multi = ["smtp.multi.1", "smtp.multi.2", "smtp.multi.3", "smtp.multi.4"].map(fx)
        return ScriptedMailStream(
            greeting: [MailWireFixture.coded("smtp.ok", 220)],
            replies: [multi, [authReply ?? MailWireFixture.coded("smtp.ok", 235)], [MailWireFixture.coded("smtp.ok", 221)]])
    }

    func testProbeIsGreenWithLoginNoopAndAuth() async throws {
        let incoming = imapScript()
        let outgoing = smtpScript()
        let net = ScriptedMailNetwork([incoming, outgoing])
        try await MailConnectionProbe.probe(account: account, password: "app-secret", opener: net.opener)
        XCTAssertEqual(incoming.sent.prefix(4), ["A0001 CAPABILITY", "A0002 LOGIN \"jo@example.test\" \"app-secret\"",
                                                "A0003 CAPABILITY", "A0004 NOOP"])
        let payload = Data("\0jo@example.test\0app-secret".utf8).base64EncodedString()
        XCTAssertEqual(outgoing.sent.prefix(3), ["EHLO localhost", "AUTH PLAIN \(payload)", "QUIT"])
        XCTAssertTrue(incoming.closed)
        XCTAssertTrue(outgoing.closed)
        XCTAssertEqual(net.endpoints, [
            ScriptedMailNetwork.Endpoint(host: "imap.ionos.de", port: 993, security: .ssl),
            ScriptedMailNetwork.Endpoint(host: "smtp.ionos.de", port: 465, security: .ssl)
        ])
    }

    func testProbeIsRedWhenLoginIsRefusedAndNamesTheServerAnswer() async {
        let incoming = imapScript(loginReply: MailWireFixture.retag("tagged.no", to: "A0002"))
        let net = ScriptedMailNetwork([incoming])
        do {
            try await MailConnectionProbe.probe(account: account, password: "x", opener: net.opener)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error as? MailProbeError,
                           MailProbeError(step: .incoming, reason: .authenticationRejected("NO " + fx("tagged.no.text"))))
        }
        XCTAssertEqual(net.endpoints.count, 1)
        XCTAssertTrue(incoming.closed)
    }

    func testProbeIsRedWhenSMTPRefusesTheAuthentication() async {
        let outgoing = smtpScript(authReply: MailWireFixture.coded("smtp.ok", 535))
        let net = ScriptedMailNetwork([imapScript(), outgoing])
        do {
            try await MailConnectionProbe.probe(account: account, password: "x", opener: net.opener)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error as? MailProbeError,
                           MailProbeError(step: .outgoing, reason: .authenticationRejected("535 " + fx("smtp.ok").dropFirst(4))))
        }
        XCTAssertTrue(outgoing.closed)
    }

    func testProbeIsRedWhenTheConnectionFails() async {
        let net = ScriptedMailNetwork([])
        do {
            try await MailConnectionProbe.probe(account: account, password: "x", opener: net.opener)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error as? MailProbeError,
                           MailProbeError(step: .incoming, reason: .connectionFailed("imap.ionos.de")))
        }
    }

    func testProbeWithEmptyPasswordIsRed() async {
        do {
            try await MailConnectionProbe.probe(account: account, password: "", opener: ScriptedMailNetwork([]).opener)
            XCTFail("probe must throw")
        } catch {
            XCTAssertEqual(error as? MailProbeError, MailProbeError(step: .incoming, reason: .credentialsMissing))
        }
    }

    func testIonosPresetCarriesServerAndPorts() {
        let preset = MailProviderPresets.preset(for: .ionos)
        XCTAssertEqual(preset.incoming, MailServerTemplate(host: "imap.ionos.de", port: 993, security: .ssl))
        XCTAssertEqual(preset.outgoing, MailServerTemplate(host: "smtp.ionos.de", port: 465, security: .ssl))
    }

    func testPasswordClosureReplacesTheKeychainForPasswordAccounts() async {
        let account = MailAccount(
            id: "pw", displayName: "", address: "jo@example.test", provider: .generic,
            incoming: MailServerSettings(host: "imap.example.test", port: 0, security: .ssl, authentication: .password,
                                         username: "jo"),
            outgoing: MailServerSettings(host: "smtp.example.test", port: 0, security: .ssl, authentication: .password,
                                         username: "jo"))
        let calls = CallCounter()
        let transport = IMAPSMTPMailTransport(account: account, password: { calls.bump(); return "app-secret" })
        do {
            try await transport.send(EmailDraft(to: "a@example.com", subject: "S", body: "b"))
            XCTFail("send must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .accountIncomplete("smtp.example.test"))
        }
        XCTAssertEqual(calls.value, 1)
        let empty = IMAPSMTPMailTransport(account: account, password: { "" })
        do {
            try await empty.send(EmailDraft(to: "a@example.com", subject: "S", body: "b"))
            XCTFail("send must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .credentialsMissing)
        }
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func bump() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
