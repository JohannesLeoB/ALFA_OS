import Foundation

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
