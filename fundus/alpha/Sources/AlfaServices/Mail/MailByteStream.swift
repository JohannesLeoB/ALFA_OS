import Foundation
import Network
import AlfaKit

protocol MailByteStream: Sendable {
    func receive() async throws -> Data
    func receiveIdle() async throws -> Data
    func send(_ data: Data) async throws
    func upgradeToTLS() async throws
    func close()
}

extension MailByteStream {
    func receiveIdle() async throws -> Data {
        while true {
            do {
                return try await receive()
            } catch MailTransportError.timeout {
                try Task.checkCancellation()
            }
        }
    }
}

typealias MailStreamOpener = @Sendable (String, Int, MailSecurity) async throws -> any MailByteStream

enum MailStreams {
    static let timeout: TimeInterval = 60

    static func open(host: String, port: Int, security: MailSecurity) async throws -> any MailByteStream {
        guard host.isEmpty == false, port > 0, port <= 65535 else {
            throw MailTransportError.accountIncomplete(host)
        }
        switch security {
        case .ssl:
            return try await NetworkMailStream.open(host: host, port: port, tls: true)
        case .none:
            return try await NetworkMailStream.open(host: host, port: port, tls: false)
        case .starttls:
            #if os(macOS)
            return try await BlockingMailStream.open(host: host, port: port)
            #else
            throw MailTransportError.tlsUnavailable
            #endif
        }
    }
}

final class MailResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}

final class NetworkMailStream: MailByteStream, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "mail.network.stream")

    private init(connection: NWConnection) {
        self.connection = connection
    }

    static func open(host: String, port: Int, tls: Bool) async throws -> NetworkMailStream {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw MailTransportError.accountIncomplete(host)
        }
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = Int(MailStreams.timeout)
        let parameters = NWParameters(tls: tls ? NWProtocolTLS.Options() : nil, tcp: tcp)
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        let stream = NetworkMailStream(connection: connection)
        try await stream.start()
        return stream
    }

    private func start() async throws {
        let connection = self.connection
        let queue = self.queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = MailResumeGate()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.take() { continuation.resume() }
                case .failed(let error), .waiting(let error):
                    if gate.take() {
                        continuation.resume(throwing: MailTransportError.connectionFailed(String(describing: error)))
                    }
                    connection.cancel()
                case .cancelled:
                    if gate.take() { continuation.resume(throwing: MailTransportError.connectionClosed) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + MailStreams.timeout) {
                if gate.take() {
                    continuation.resume(throwing: MailTransportError.timeout)
                    connection.cancel()
                }
            }
        }
    }

    func receive() async throws -> Data {
        try await read(bounded: true)
    }

    func receiveIdle() async throws -> Data {
        try await read(bounded: false)
    }

    private func read(bounded: Bool) async throws -> Data {
        let connection = self.connection
        let queue = self.queue
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    let gate = MailResumeGate()
                    if bounded {
                        queue.asyncAfter(deadline: .now() + MailStreams.timeout) {
                            if gate.take() {
                                continuation.resume(throwing: MailTransportError.timeout)
                                connection.cancel()
                            }
                        }
                    }
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                        guard gate.take() else { return }
                        if let error {
                            continuation.resume(throwing: MailTransportError.connectionFailed(String(describing: error)))
                        } else if let data, data.isEmpty == false {
                            continuation.resume(returning: data)
                        } else if isComplete {
                            continuation.resume(throwing: MailTransportError.connectionClosed)
                        } else {
                            continuation.resume(returning: Data())
                        }
                    }
                }
            } onCancel: {
                connection.cancel()
            }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    func send(_ data: Data) async throws {
        let connection = self.connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: MailTransportError.connectionFailed(String(describing: error)))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func upgradeToTLS() async throws {
        throw MailTransportError.tlsUnavailable
    }

    func close() {
        connection.cancel()
    }
}

#if os(macOS)
final class BlockingMailStream: MailByteStream, @unchecked Sendable {
    private let input: InputStream
    private let output: OutputStream
    private let queue = DispatchQueue(label: "mail.blocking.stream")

    private init(input: InputStream, output: OutputStream) {
        self.input = input
        self.output = output
    }

    static func open(host: String, port: Int) async throws -> BlockingMailStream {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BlockingMailStream, Error>) in
            DispatchQueue.global().async {
                do {
                    continuation.resume(returning: try connect(host: host, port: port))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func connect(host: String, port: Int) throws -> BlockingMailStream {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        guard let input = inputStream, let output = outputStream else {
            throw MailTransportError.connectionFailed(host)
        }
        input.open()
        output.open()
        let deadline = Date().addingTimeInterval(MailStreams.timeout)
        while input.streamStatus == .opening || output.streamStatus == .opening {
            if Date() > deadline {
                input.close()
                output.close()
                throw MailTransportError.timeout
            }
            usleep(10_000)
        }
        let failed: Set<Stream.Status> = [.error, .closed, .atEnd, .notOpen]
        if failed.contains(input.streamStatus) || failed.contains(output.streamStatus) {
            let reason = input.streamError ?? output.streamError
            input.close()
            output.close()
            throw MailTransportError.connectionFailed(reason.map { String(describing: $0) } ?? host)
        }
        applyTimeouts(input)
        return BlockingMailStream(input: input, output: output)
    }

    private static func applyTimeouts(_ input: InputStream) {
        let key = Stream.PropertyKey(rawValue: "kCFStreamPropertySocketNativeHandle")
        guard let data = input.property(forKey: key) as? Data, data.count >= MemoryLayout<Int32>.size else { return }
        let handle = data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var interval = timeval(tv_sec: Int(MailStreams.timeout), tv_usec: 0)
        setsockopt(handle, SOL_SOCKET, SO_RCVTIMEO, &interval, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(handle, SOL_SOCKET, SO_SNDTIMEO, &interval, socklen_t(MemoryLayout<timeval>.size))
    }

    func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                var buffer = [UInt8](repeating: 0, count: 65536)
                let count = self.input.read(&buffer, maxLength: buffer.count)
                if count > 0 {
                    continuation.resume(returning: Data(buffer[0..<count]))
                } else if count == 0 {
                    continuation.resume(throwing: MailTransportError.connectionClosed)
                } else if let error = self.input.streamError {
                    continuation.resume(throwing: MailTransportError.connectionFailed(String(describing: error)))
                } else {
                    continuation.resume(throwing: MailTransportError.timeout)
                }
            }
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let bytes = [UInt8](data)
                var offset = 0
                while offset < bytes.count {
                    let written = bytes.withUnsafeBufferPointer { pointer in
                        self.output.write(pointer.baseAddress! + offset, maxLength: bytes.count - offset)
                    }
                    if written <= 0 {
                        let reason = self.output.streamError.map { String(describing: $0) } ?? ""
                        continuation.resume(throwing: MailTransportError.connectionFailed(reason))
                        return
                    }
                    offset += written
                }
                continuation.resume()
            }
        }
    }

    func upgradeToTLS() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let level = StreamSocketSecurityLevel.negotiatedSSL
                let inputSet = self.input.setProperty(level, forKey: .socketSecurityLevelKey)
                let outputSet = self.output.setProperty(level, forKey: .socketSecurityLevelKey)
                if inputSet && outputSet {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MailTransportError.tlsUnavailable)
                }
            }
        }
    }

    func close() {
        queue.async {
            self.input.close()
            self.output.close()
        }
    }
}
#endif

actor MailReader {
    static let maxLine = 1_048_576
    static let maxLiteral = 67_108_864

    private let stream: any MailByteStream
    private var buffer = Data()

    init(stream: any MailByteStream) {
        self.stream = stream
    }

    func readLine(idle: Bool = false) async throws -> Data {
        let terminator = Data([13, 10])
        while true {
            if let range = buffer.firstRange(of: terminator) {
                let line = Data(buffer[buffer.startIndex..<range.lowerBound])
                buffer = Data(buffer[range.upperBound...])
                return line
            }
            if buffer.count > Self.maxLine { throw MailTransportError.malformedResponse("line") }
            buffer.append(try await (idle ? stream.receiveIdle() : stream.receive()))
        }
    }

    func readBytes(_ count: Int) async throws -> Data {
        guard count >= 0, count <= Self.maxLiteral else { throw MailTransportError.malformedResponse("literal") }
        while buffer.count < count {
            buffer.append(try await stream.receive())
        }
        let bytes = Data(buffer[buffer.startIndex..<(buffer.startIndex + count)])
        buffer = Data(buffer[(buffer.startIndex + count)...])
        return bytes
    }

    func write(_ data: Data) async throws {
        try await stream.send(data)
    }

    func upgradeToTLS() async throws {
        guard buffer.isEmpty else { throw MailTransportError.malformedResponse("upgrade") }
        try await stream.upgradeToTLS()
    }

    func close() {
        stream.close()
    }
}
