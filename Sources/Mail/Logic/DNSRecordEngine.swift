import Foundation

enum DNSRecordEngine {
    static let mailExchangerType: UInt16 = 15
    static let serviceType: UInt16 = 33

    static func mailExchanger(_ data: Data) -> (preference: Int, host: String)? {
        let bytes = [UInt8](data)
        guard bytes.count > 2, let host = name(bytes, from: 2), !host.isEmpty else { return nil }
        return (number(bytes, at: 0), host)
    }

    static func service(_ data: Data) -> SRVRecord? {
        let bytes = [UInt8](data)
        guard bytes.count > 6, let target = name(bytes, from: 6) else { return nil }
        return SRVRecord(priority: number(bytes, at: 0), weight: number(bytes, at: 2), port: number(bytes, at: 4),
                         target: target)
    }

    private static func number(_ bytes: [UInt8], at index: Int) -> Int {
        Int(bytes[index]) << 8 | Int(bytes[index + 1])
    }

    private static func name(_ bytes: [UInt8], from start: Int) -> String? {
        var labels: [String] = []
        var index = start
        while index < bytes.count {
            let length = Int(bytes[index])
            if length == 0 { return labels.joined(separator: ".").lowercased() }
            guard length < 64, index + 1 + length <= bytes.count,
                  let label = String(bytes: bytes[(index + 1)..<(index + 1 + length)], encoding: .utf8) else { return nil }
            labels.append(label)
            index += 1 + length
        }
        return nil
    }
}
