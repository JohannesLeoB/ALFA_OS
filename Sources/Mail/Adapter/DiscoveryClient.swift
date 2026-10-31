import dnssd
import Foundation

public struct DiscoveryClient: DiscoveryPort {
    private static let timeout: TimeInterval = 8
    private static let pollStep: Int32 = 250
    private static let largest = 256 * 1024

    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    public func document(_ url: URL) async -> Data? {
        guard url.scheme == "https" else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https", data.count <= Self.largest else { return nil }
        return data
    }

    public func records(_ name: String, type: UInt16) async -> [Data] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.query(name, type: type))
            }
        }
    }

    private final class Answers {
        let type: UInt16
        var records: [Data] = []
        var done = false

        init(type: UInt16) {
            self.type = type
        }
    }

    private static func query(_ name: String, type: UInt16) -> [Data] {
        let answers = Answers(type: type)
        let context = Unmanaged.passRetained(answers)
        defer { context.release() }
        var reference: DNSServiceRef?
        let reply: DNSServiceQueryRecordReply = { _, flags, _, error, _, kind, _, length, data, _, context in
            guard let context else { return }
            let answers = Unmanaged<Answers>.fromOpaque(context).takeUnretainedValue()
            if error == kDNSServiceErr_NoError, kind == answers.type, let data {
                answers.records.append(Data(bytes: data, count: Int(length)))
            }
            if error != kDNSServiceErr_NoError || (kind == answers.type && flags & kDNSServiceFlagsMoreComing == 0) {
                answers.done = true
            }
        }
        let status = DNSServiceQueryRecord(&reference, kDNSServiceFlagsReturnIntermediates, 0, name, type,
                                           UInt16(kDNSServiceClass_IN), reply, context.toOpaque())
        guard status == kDNSServiceErr_NoError, let reference else { return [] }
        defer { DNSServiceRefDeallocate(reference) }
        let deadline = Date().addingTimeInterval(timeout)
        var socket = pollfd(fd: DNSServiceRefSockFD(reference), events: Int16(POLLIN), revents: 0)
        while !answers.done, Date() < deadline {
            socket.revents = 0
            guard poll(&socket, 1, pollStep) >= 0 else { break }
            if socket.revents & Int16(POLLIN) != 0, DNSServiceProcessResult(reference) != kDNSServiceErr_NoError { break }
        }
        return answers.records
    }
}

public enum UnsubscribeClient {
    private static let timeout: TimeInterval = 15

    public static func post(_ url: URL) async -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        guard let (_, response) = try? await session.data(for: UnsubscribeEngine.request(url)),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}
