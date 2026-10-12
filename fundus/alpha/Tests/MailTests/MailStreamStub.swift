import Foundation
@testable import MykilosServices
import MykilosKit

enum MailWireFixture {
    static let values: [String: String] = {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("MailWire.txt")
        let text = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let range = line.range(of: " = ") else { continue }
            result[String(line[line.startIndex..<range.lowerBound])] = String(line[range.upperBound...])
        }
        return result
    }()

    static func line(_ key: String) -> String { values[key] ?? "" }

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
    private var upgradedFlag = false
    private var closedFlag = false

    init(greeting: [String], replies: [[String]]) {
        pending = greeting.map { Data(($0 + "\r\n").utf8) }
        self.replies = replies
    }

    var sent: [String] { lock.withLock { sentLines } }
    var upgraded: Bool { lock.withLock { upgradedFlag } }
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

    func upgradeToTLS() async throws {
        lock.withLock { upgradedFlag = true }
    }

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
