import Foundation

#if os(macOS)
final class BlockingStream: ByteStreamPort, @unchecked Sendable {
    private static let chunk = 65536
    private static let pollMicroseconds: UInt32 = 10_000
    private static let handleKey = "kCFStreamPropertySocketNativeHandle"

    private let input: InputStream
    private let output: OutputStream
    private let queue = DispatchQueue(label: "mail.blocking.stream")
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
                    queue.async {
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
            queue.async {
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
            queue.async {
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
        queue.async {
            self.input.close()
            self.output.close()
        }
    }
}
#endif
