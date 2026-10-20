import Foundation
import XCTest
@testable import AlfaServices
import AlfaKit

struct IMAPReply {
    var untagged: [String] = []
    var status = "OK done"
}

final class EmulatedIMAPStream: MailByteStream, @unchecked Sendable {
    typealias Handler = (_ command: String, _ literal: Data?) -> IMAPReply

    private let lock = NSLock()
    private let handler: Handler
    private var pending: [Data]
    private var buffer = Data()
    private var awaiting: (tag: String, command: String, size: Int)?
    private var logged: [String] = []
    private var bodies: [Data] = []
    private var closedFlag = false
    private let capabilities: String

    init(capabilities: String = "IMAP4rev1", handler: @escaping Handler) {
        self.capabilities = capabilities
        self.handler = handler
        pending = [Data("* OK [CAPABILITY \(capabilities)] ready\r\n".utf8)]
    }

    var commands: [String] { lock.withLock { logged } }
    var literals: [Data] { lock.withLock { bodies } }
    var closed: Bool { lock.withLock { closedFlag } }

    func receive() async throws -> Data {
        let chunk = lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
        guard let chunk else { throw MailTransportError.connectionClosed }
        return chunk
    }

    func send(_ data: Data) async throws {
        lock.withLock {
            buffer.append(data)
            drain()
        }
    }

    func upgradeToTLS() async throws {}

    func close() { lock.withLock { closedFlag = true } }

    private func drain() {
        while true {
            if let waiting = awaiting {
                guard buffer.count >= waiting.size + 2 else { return }
                let payload = Data(buffer.prefix(waiting.size))
                buffer = Data(buffer.dropFirst(waiting.size + 2))
                awaiting = nil
                bodies.append(payload)
                logged.append(waiting.command)
                answer(tag: waiting.tag, command: waiting.command, literal: payload)
                continue
            }
            guard let end = buffer.range(of: Data("\r\n".utf8)) else { return }
            let line = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
            buffer = Data(buffer.dropFirst(line.utf8.count + 2))
            let words = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard words.count == 2 else { continue }
            let tag = words[0]
            let command = words[1]
            if let open = command.lastIndex(of: "{"), command.hasSuffix("}"),
               let size = Int(command[command.index(after: open)..<command.index(before: command.endIndex)]) {
                awaiting = (tag, command, size)
                pending.append(Data("+ go ahead\r\n".utf8))
                continue
            }
            logged.append(command)
            answer(tag: tag, command: command, literal: nil)
        }
    }

    private func answer(tag: String, command: String, literal: Data?) {
        let reply: IMAPReply
        switch command.split(separator: " ").first.map({ $0.uppercased() }) {
        case "CAPABILITY":
            reply = IMAPReply(untagged: ["* CAPABILITY \(capabilities)"])
        case "LOGIN":
            reply = IMAPReply()
        case "LOGOUT":
            reply = IMAPReply(untagged: ["* BYE bye"])
        default:
            reply = handler(command, literal)
        }
        var text = reply.untagged.map { $0 + "\r\n" }.joined()
        text += "\(tag) \(reply.status)\r\n"
        pending.append(Data(text.utf8))
    }
}

final class EmulatedSMTPStream: MailByteStream, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [Data] = [Data("220 ready\r\n".utf8)]
    private var buffer = Data()
    private var inData = false
    private var lines: [String] = []
    private var message = Data()
    private let sizeLine: String

    init(size: Int? = nil) {
        sizeLine = size.map { "250 SIZE \($0)\r\n" } ?? ""
    }

    var commands: [String] { lock.withLock { lines } }
    var delivered: String { lock.withLock { String(decoding: message, as: UTF8.self) } }

    func receive() async throws -> Data {
        let chunk = lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
        guard let chunk else { throw MailTransportError.connectionClosed }
        return chunk
    }

    func send(_ data: Data) async throws {
        lock.withLock {
            buffer.append(data)
            while true {
                if inData {
                    guard let end = buffer.range(of: Data("\r\n.\r\n".utf8)) else { return }
                    message = Data(buffer[buffer.startIndex..<end.lowerBound])
                    buffer = Data(buffer[end.upperBound...])
                    inData = false
                    pending.append(Data("250 OK queued\r\n".utf8))
                    continue
                }
                guard let end = buffer.range(of: Data("\r\n".utf8)) else { return }
                let line = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
                buffer = Data(buffer[end.upperBound...])
                lines.append(line)
                let word = line.split(separator: " ").first.map { $0.uppercased() } ?? ""
                switch word {
                case "EHLO": pending.append(Data((sizeLine.isEmpty ? "250-ready\r\n250 AUTH PLAIN\r\n" : "250-ready\r\n250-AUTH PLAIN\r\n" + sizeLine).utf8))
                case "AUTH": pending.append(Data("235 ok\r\n".utf8))
                case "DATA":
                    inData = true
                    pending.append(Data("354 go\r\n".utf8))
                case "QUIT": pending.append(Data("221 bye\r\n".utf8))
                default: pending.append(Data("250 OK\r\n".utf8))
                }
            }
        }
    }

    func upgradeToTLS() async throws {}

    func close() {}
}

final class StreamQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [any MailByteStream]
    private var opened = 0

    init(_ streams: [any MailByteStream]) {
        self.streams = streams
    }

    var openedCount: Int { lock.withLock { opened } }

    var opener: MailStreamOpener {
        { [self] host, _, _ in
            try lock.withLock {
                guard streams.isEmpty == false else { throw MailTransportError.connectionFailed(host) }
                opened += 1
                return streams.removeFirst()
            }
        }
    }
}

enum ActionFixture {
    static var account: MailAccount {
        MailProviderPresets.preset(for: .ionos).account(id: "p", displayName: "", address: "jo@example.test")
    }

    static func transport(_ queue: StreamQueue) -> IMAPSMTPMailTransport {
        IMAPSMTPMailTransport(account: account, accessToken: nil, password: { "app-secret" }, opener: queue.opener)
    }

    static let folders = [
        "* LIST (\\HasNoChildren) \"/\" INBOX",
        "* LIST (\\HasNoChildren \\Archive) \"/\" \"Archive\"",
        "* LIST (\\HasNoChildren \\Trash) \"/\" \"Trash\"",
        "* LIST (\\HasNoChildren \\Junk) \"/\" \"Junk\"",
        "* LIST (\\HasNoChildren \\Drafts) \"/\" \"Drafts\"",
        "* LIST (\\HasNoChildren) \"/\" \"Projects\"",
    ]

    static let selected = ["* 3 EXISTS", "* OK [UIDVALIDITY 7] ok", "* OK [UIDNEXT 9] next"]

    static func server(capabilities: String, folders: [String] = ActionFixture.folders,
                       extra: @escaping (String, Data?) -> IMAPReply? = { _, _ in nil }) -> EmulatedIMAPStream {
        EmulatedIMAPStream(capabilities: capabilities) { command, literal in
            if let reply = extra(command, literal) { return reply }
            if command.hasPrefix("LIST") { return IMAPReply(untagged: folders) }
            if command.hasPrefix("SELECT") || command.hasPrefix("EXAMINE") { return IMAPReply(untagged: selected) }
            return IMAPReply()
        }
    }

    static func withoutLogin(_ commands: [String]) -> [String] {
        commands.filter { $0.hasPrefix("LOGIN") == false && $0 != "CAPABILITY" && $0 != "LOGOUT" }
    }
}

final class RecordingGmail: URLProtocol, @unchecked Sendable {
    struct Call: Equatable {
        var method: String
        var path: String
        var body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var recorded: [Call] = []
    nonisolated(unsafe) private static var router: (Call) -> (Int, String) = { _ in (200, "{}") }

    static var calls: [Call] { lock.withLock { recorded } }

    static func reset(_ route: @escaping (Call) -> (Int, String) = { _ in (200, "{}") }) {
        lock.withLock {
            recorded = []
            router = route
        }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingGmail.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        let call = Call(method: request.httpMethod ?? "GET", path: request.url?.path ?? "", body: body)
        let route = Self.lock.withLock { () -> (Call) -> (Int, String) in
            Self.recorded.append(call)
            return Self.router
        }
        let (status, text) = route(call)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct ActionToken: GoogleAccessTokenProviding {
    func validAccessToken() async throws -> String { "token" }
}
