import Foundation
import Network
import Synchronization

final class NetworkStream: ByteStreamPort, @unchecked Sendable {
    private static let chunk = 65536

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "mail.network.stream")

    private init(connection: NWConnection) {
        self.connection = connection
    }

    static func open(host: String, port: Int, tls: Bool) async throws -> NetworkStream {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw MailFailure.accountIncomplete(host)
        }
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = Int(StreamRouter.timeout)
        let parameters = NWParameters(tls: tls ? NWProtocolTLS.Options() : nil, tcp: tcp)
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        let stream = NetworkStream(connection: connection)
        try await stream.start()
        return stream
    }

    private func start() async throws {
        let connection = self.connection
        let queue = self.queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let latch = ResumeLatch()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if latch.take() { continuation.resume() }
                case .failed(let error), .waiting(let error):
                    if latch.take() {
                        continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                    }
                    connection.cancel()
                case .cancelled:
                    if latch.take() { continuation.resume(throwing: MailFailure.connectionClosed) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + StreamRouter.timeout) {
                if latch.take() {
                    continuation.resume(throwing: MailFailure.timeout)
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
                    let latch = ResumeLatch()
                    if bounded {
                        queue.asyncAfter(deadline: .now() + StreamRouter.timeout) {
                            if latch.take() {
                                continuation.resume(throwing: MailFailure.timeout)
                                connection.cancel()
                            }
                        }
                    }
                    connection.receive(minimumIncompleteLength: 1, maximumLength: Self.chunk) { data, _, isComplete, error in
                        guard latch.take() else { return }
                        if let error {
                            continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                        } else if let data, !data.isEmpty {
                            continuation.resume(returning: data)
                        } else if isComplete {
                            continuation.resume(throwing: MailFailure.connectionClosed)
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
                    continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func upgradeToTLS() async throws {
        throw MailFailure.tlsUnavailable
    }

    func close() {
        connection.cancel()
    }
}

final class ResumeLatch: Sendable {
    private let taken = Mutex(false)

    func take() -> Bool {
        taken.withLock { value in
            if value { return false }
            value = true
            return true
        }
    }
}

#if os(macOS)
final class BlockingStream: ByteStreamPort, @unchecked Sendable {
    private static let chunk = 65536
    private static let pollMicroseconds: UInt32 = 10_000
    private static let handleKey = "kCFStreamPropertySocketNativeHandle"

    private let input: InputStream
    private let output: OutputStream
    private let reading = DispatchQueue(label: "mail.blocking.read")
    private let writing = DispatchQueue(label: "mail.blocking.write")
    private let handle: Int32?
    private let closeLock = NSLock()
    private var isClosed = false

    private init(input: InputStream, output: OutputStream, handle: Int32?) {
        self.input = input
        self.output = output
        self.handle = handle
    }

    static func open(host: String, port: Int) async throws -> BlockingStream {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BlockingStream, Error>) in
            DispatchQueue.global().async {
                do {
                    continuation.resume(returning: try connect(host: host, port: port))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func connect(host: String, port: Int) throws -> BlockingStream {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        guard let input = inputStream, let output = outputStream else {
            throw MailFailure.connectionFailed(host)
        }
        input.open()
        output.open()
        let deadline = Date().addingTimeInterval(StreamRouter.timeout)
        while input.streamStatus == .opening || output.streamStatus == .opening {
            if Date() > deadline {
                input.close()
                output.close()
                throw MailFailure.timeout
            }
            usleep(pollMicroseconds)
        }
        let failed: Set<Stream.Status> = [.error, .closed, .atEnd, .notOpen]
        if failed.contains(input.streamStatus) || failed.contains(output.streamStatus) {
            let reason = input.streamError ?? output.streamError
            input.close()
            output.close()
            throw MailFailure.connectionFailed(reason.map { String(describing: $0) } ?? host)
        }
        let handle = nativeHandle(input)
        applyTimeouts(handle)
        return BlockingStream(input: input, output: output, handle: handle)
    }

    private static func nativeHandle(_ input: InputStream) -> Int32? {
        let key = Stream.PropertyKey(rawValue: handleKey)
        guard let data = input.property(forKey: key) as? Data, data.count >= MemoryLayout<Int32>.size else { return nil }
        return data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
    }

    private static func applyTimeouts(_ handle: Int32?) {
        guard let handle else { return }
        var interval = timeval(tv_sec: Int(StreamRouter.timeout), tv_usec: 0)
        setsockopt(handle, SOL_SOCKET, SO_RCVTIMEO, &interval, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(handle, SOL_SOCKET, SO_SNDTIMEO, &interval, socklen_t(MemoryLayout<timeval>.size))
    }

    func receive() async throws -> Data {
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    reading.async {
                        var buffer = [UInt8](repeating: 0, count: Self.chunk)
                        let count = self.input.read(&buffer, maxLength: buffer.count)
                        if count > 0 {
                            continuation.resume(returning: Data(buffer[0..<count]))
                        } else if count == 0 {
                            continuation.resume(throwing: MailFailure.connectionClosed)
                        } else if let error = self.input.streamError {
                            continuation.resume(throwing: MailFailure.connectionFailed(String(describing: error)))
                        } else {
                            continuation.resume(throwing: MailFailure.timeout)
                        }
                    }
                }
            } onCancel: {
                close()
            }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writing.async {
                let bytes = [UInt8](data)
                var offset = 0
                while offset < bytes.count {
                    let written = bytes.withUnsafeBufferPointer { pointer in
                        self.output.write(pointer.baseAddress! + offset, maxLength: bytes.count - offset)
                    }
                    if written <= 0 {
                        let reason = self.output.streamError.map { String(describing: $0) } ?? ""
                        continuation.resume(throwing: MailFailure.connectionFailed(reason))
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
            reading.async {
                self.writing.sync {}
                let level = StreamSocketSecurityLevel.negotiatedSSL
                let inputSet = self.input.setProperty(level, forKey: .socketSecurityLevelKey)
                let outputSet = self.output.setProperty(level, forKey: .socketSecurityLevelKey)
                if inputSet && outputSet {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MailFailure.tlsUnavailable)
                }
            }
        }
    }

    func close() {
        let first = closeLock.withLock { () -> Bool in
            defer { isClosed = true }
            return !isClosed
        }
        guard first else { return }
        if let handle { shutdown(handle, SHUT_RDWR) }
        reading.async { self.input.close() }
        writing.async { self.output.close() }
    }
}
#endif

actor StreamBuffer {
    static let maxLine = 16_777_216
    static let maxLiteral = 67_108_864

    private let stream: any ByteStreamPort
    private var buffer = Data()
    private var scanned = 0

    init(stream: any ByteStreamPort) {
        self.stream = stream
    }

    func readLine(idle: Bool = false) async throws -> Data {
        while true {
            if let end = terminator() {
                let line = Data(buffer[buffer.startIndex..<buffer.startIndex + end])
                buffer = Data(buffer[(buffer.startIndex + end + 2)...])
                scanned = 0
                return line
            }
            if buffer.count > Self.maxLine { throw MailFailure.malformedResponse("line") }
            buffer.append(try await (idle ? stream.receiveIdle() : stream.receive()))
        }
    }

    private func terminator() -> Int? {
        var index = scanned
        while index + 1 < buffer.count {
            if buffer[buffer.startIndex + index] == 13, buffer[buffer.startIndex + index + 1] == 10 { return index }
            index += 1
        }
        scanned = max(0, buffer.count - 1)
        return nil
    }

    func readBytes(_ count: Int) async throws -> Data {
        guard count >= 0, count <= Self.maxLiteral else { throw MailFailure.malformedResponse("literal") }
        while buffer.count < count {
            buffer.append(try await stream.receive())
        }
        let bytes = Data(buffer[buffer.startIndex..<(buffer.startIndex + count)])
        buffer = Data(buffer[(buffer.startIndex + count)...])
        scanned = 0
        return bytes
    }

    func write(_ data: Data) async throws {
        try await stream.send(data)
    }

    func upgradeToTLS() async throws {
        guard buffer.isEmpty else { throw MailFailure.malformedResponse("upgrade") }
        try await stream.upgradeToTLS()
    }

    func close() {
        stream.close()
    }
}

typealias StreamOpener = @Sendable (String, Int, TransportSecurity) async throws -> any ByteStreamPort

enum StreamRouter {
    static let timeout: TimeInterval = 60

    static func open(host: String, port: Int, security: TransportSecurity) async throws -> any ByteStreamPort {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            throw MailFailure.accountIncomplete(host)
        }
        switch security {
        case .ssl:
            return try await NetworkStream.open(host: host, port: port, tls: true)
        case .none:
            return try await NetworkStream.open(host: host, port: port, tls: false)
        case .starttls:
            #if os(macOS)
            return try await BlockingStream.open(host: host, port: port)
            #else
            throw MailFailure.tlsUnavailable
            #endif
        }
    }
}
