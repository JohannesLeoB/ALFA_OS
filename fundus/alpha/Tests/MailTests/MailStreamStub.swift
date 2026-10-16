import Foundation
import XCTest
@testable import MykilosServices
import MykilosKit

enum MailWireFixture {
    /// Lädt Fixtures/MailWire.txt. Fehlt die Datei, scheitert der Test laut (kein stilles "").
    static let values: [String: String] = {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("MailWire.txt")
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            XCTFail("Fixture-Datei fehlt oder ist nicht lesbar: \(path.path)")
            return [:]
        }
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let range = line.range(of: " = ") else { continue }
            let value = line[range.upperBound...]
                .replacingOccurrences(of: "<CRLF>", with: "\r\n")
                .replacingOccurrences(of: "<LF>", with: "\n")
            result[String(line[line.startIndex..<range.lowerBound])] = value
        }
        return result
    }()

    /// Liefert den Wert zum Schlüssel; ein fehlender Schlüssel lässt den Test scheitern.
    static func line(_ key: String, file: StaticString = #filePath, line lineNumber: UInt = #line) -> String {
        guard let value = values[key] else {
            XCTFail("Fixture-Schlüssel fehlt: \(key)", file: file, line: lineNumber)
            return ""
        }
        return value
    }

    static func retag(_ key: String, to tag: String) -> String {
        let words = line(key).split(separator: " ", maxSplits: 1).map(String.init)
        return ([tag] + words.dropFirst()).joined(separator: " ")
    }

    static func coded(_ key: String, _ code: Int) -> String {
        "\(code) " + line(key).split(separator: " ", maxSplits: 1).dropFirst().joined(separator: " ")
    }
}

final class ScriptedMailStream: MailByteStream, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [Data]
    private var replies: [[String]]
    private var sentLines: [String] = []
    private var closedFlag = false

    init(greeting: [String], replies: [[String]]) {
        pending = greeting.map { Data(($0 + "\r\n").utf8) }
        self.replies = replies
    }

    var sent: [String] { lock.withLock { sentLines } }
    var closed: Bool { lock.withLock { closedFlag } }

    func receive() async throws -> Data {
        let chunk = lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
        guard let chunk else { throw MailTransportError.connectionClosed }
        return chunk
    }

    func send(_ data: Data) async throws {
        let text = String(decoding: data, as: UTF8.self)
        lock.withLock {
            for line in text.components(separatedBy: "\r\n").dropLast() {
                sentLines.append(line)
                if replies.isEmpty == false {
                    pending.append(contentsOf: replies.removeFirst().map { Data(($0 + "\r\n").utf8) })
                }
            }
        }
    }

    func upgradeToTLS() async throws {}

    func close() {
        lock.withLock { closedFlag = true }
    }
}

final class ScriptedMailNetwork: @unchecked Sendable {
    struct Endpoint: Equatable {
        var host: String
        var port: Int
        var security: MailSecurity
    }

    private let lock = NSLock()
    private var streams: [ScriptedMailStream]
    private var opened: [Endpoint] = []

    init(_ streams: [ScriptedMailStream]) {
        self.streams = streams
    }

    var endpoints: [Endpoint] { lock.withLock { opened } }

    var opener: MailStreamOpener {
        { [self] host, port, security in
            try lock.withLock {
                opened.append(Endpoint(host: host, port: port, security: security))
                guard streams.isEmpty == false else { throw MailTransportError.connectionFailed(host) }
                return streams.removeFirst()
            }
        }
    }
}

final class LoopbackIMAPServer: @unchecked Sendable {
    private let listener: Int32
    private let uids: [Int]
    let port: Int

    init(uids: [Int]) throws {
        self.uids = uids
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 1) == 0 else { throw MailTransportError.connectionFailed("loopback") }
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        listener = fd
        port = Int(UInt16(bigEndian: assigned.sin_port))
        let thread = Thread { [self] in serve() }
        thread.start()
    }

    func stop() { close(listener) }

    private func serve() {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }
        write(client, "* OK [CAPABILITY IMAP4rev1] ready\r\n")
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(client, &chunk, chunk.count)
            if count <= 0 { return }
            buffer.append(chunk, count: count)
            while let end = buffer.range(of: Data("\r\n".utf8)) {
                let line = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
                buffer.removeSubrange(buffer.startIndex..<end.upperBound)
                if reply(to: line, on: client) == false { return }
            }
        }
    }

    private func reply(to line: String, on client: Int32) -> Bool {
        let words = line.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return true }
        let tag = words[0]
        switch words[1].uppercased() {
        case "CAPABILITY":
            write(client, "* CAPABILITY IMAP4rev1\r\n\(tag) OK done\r\n")
        case "LOGIN":
            write(client, "\(tag) OK logged in\r\n")
        case "LIST":
            write(client, "* LIST (\\HasNoChildren) \"/\" INBOX\r\n\(tag) OK done\r\n")
        case "EXAMINE", "SELECT":
            write(client, "* \(uids.count) EXISTS\r\n* OK [UIDVALIDITY 7] ok\r\n\(tag) OK done\r\n")
        case "UID" where words.count > 2 && words[2].uppercased() == "SEARCH":
            write(client, "* SEARCH \(uids.map(String.init).joined(separator: " "))\r\n\(tag) OK done\r\n")
        case "UID" where words.count > 3 && words[2].uppercased() == "FETCH":
            var out = ""
            for (index, uid) in words[3].split(separator: ",").compactMap({ Int($0) }).enumerated() {
                out += "* \(index + 1) FETCH (UID \(uid) FLAGS ())\r\n"
            }
            write(client, out + "\(tag) OK done\r\n")
        case "LOGOUT":
            write(client, "* BYE bye\r\n\(tag) OK done\r\n")
            return false
        default:
            write(client, "\(tag) BAD unknown\r\n")
        }
        return true
    }

    private func write(_ client: Int32, _ text: String) {
        let bytes = Array(text.utf8)
        var sent = 0
        while sent < bytes.count {
            let count = send(client, Array(bytes[sent...]), bytes.count - sent, 0)
            if count <= 0 { return }
            sent += count
        }
    }
}
