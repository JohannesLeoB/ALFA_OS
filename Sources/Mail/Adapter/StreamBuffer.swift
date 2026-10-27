import Foundation

actor StreamBuffer {
    static let maxLine = 1_048_576
    static let maxLiteral = 67_108_864

    private let stream: any ByteStreamPort
    private var buffer = Data()

    init(stream: any ByteStreamPort) {
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
            if buffer.count > Self.maxLine { throw MailFailure.malformedResponse("line") }
            buffer.append(try await (idle ? stream.receiveIdle() : stream.receive()))
        }
    }

    func readBytes(_ count: Int) async throws -> Data {
        guard count >= 0, count <= Self.maxLiteral else { throw MailFailure.malformedResponse("literal") }
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
        guard buffer.isEmpty else { throw MailFailure.malformedResponse("upgrade") }
        try await stream.upgradeToTLS()
    }

    func close() {
        stream.close()
    }
}
