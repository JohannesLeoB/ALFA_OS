import Foundation

enum MIME {
    private static let base64Alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    private static let encodedWord = try? NSRegularExpression(pattern: "=\\?([^?\\s]+)\\?([BbQq])\\?([^?\\s]*)\\?=")

    static func decodeBase64(_ data: Data) -> Data {
        var filtered = data.filter { base64Alphabet.contains($0) }
        while filtered.count % 4 != 0 { filtered.append(61) }
        return Data(base64Encoded: filtered) ?? Data()
    }

    static func decodeQuotedPrintable(_ data: Data, header: Bool = false) -> Data {
        let bytes = [UInt8](data)
        var out = [UInt8]()
        out.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 61 {
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 2
                    continue
                }
                if index + 2 < bytes.count, bytes[index + 1] == 13, bytes[index + 2] == 10 {
                    index += 3
                    continue
                }
                if index + 2 < bytes.count, let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                    out.append(UInt8(high * 16 + low))
                    index += 3
                    continue
                }
                out.append(byte)
                index += 1
            } else if header && byte == 95 {
                out.append(32)
                index += 1
            } else {
                out.append(byte)
                index += 1
            }
        }
        return Data(out)
    }

    private static func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case 48...57: Int(byte) - 48
        case 65...70: Int(byte) - 55
        case 97...102: Int(byte) - 87
        default: nil
        }
    }

    static func decodeTransfer(_ data: Data, encoding: String) -> Data {
        switch encoding.lowercased() {
        case "base64": decodeBase64(data)
        case "quoted-printable": decodeQuotedPrintable(data)
        default: data
        }
    }

    static func string(from data: Data, charset: String?) -> String {
        if let name = charset?.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")), !name.isEmpty {
            let base = name.split(separator: "*", maxSplits: 1).first.map(String.init) ?? name
            let converted = CFStringConvertIANACharSetNameToEncoding(base as CFString)
            if converted != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(converted))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    static func decodeEncodedWords(_ text: String) -> String {
        guard text.contains("=?"), let regex = encodedWord else { return text }
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }
        var result = ""
        var cursor = 0
        var previousWasWord = false
        for match in matches {
            let gap = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let gapIsBlank = gap.allSatisfy(\.isWhitespace)
            if !(previousWasWord && gapIsBlank) { result += gap }
            let charset = source.substring(with: match.range(at: 1))
            let kind = source.substring(with: match.range(at: 2)).uppercased()
            let payload = Data(source.substring(with: match.range(at: 3)).utf8)
            let raw = kind == "B" ? decodeBase64(payload) : decodeQuotedPrintable(payload, header: true)
            result += string(from: raw, charset: charset)
            cursor = match.range.location + match.range.length
            previousWasWord = true
        }
        result += source.substring(from: cursor)
        return result
    }

    static func parseHeaders(_ data: Data) -> [HeaderField] {
        let text = string(from: data, charset: nil)
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var fields: [HeaderField] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty { break }
            if line.first == " " || line.first == "\t", !fields.isEmpty {
                fields[fields.count - 1].value += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colon = line.firstIndex(of: ":") {
                let name = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                fields.append(HeaderField(name: name, value: value))
            }
        }
        return fields
    }

    static func resolveExtended(_ pairs: [(String, String)]) -> [String: String] {
        var plain: [String: String] = [:]
        var segments: [String: [(Int, String, Bool)]] = [:]
        for (key, value) in pairs {
            guard let star = key.firstIndex(of: "*") else {
                plain[key] = decodeEncodedWords(value)
                continue
            }
            let base = String(key[key.startIndex..<star])
            let suffix = String(key[key.index(after: star)...])
            if suffix.isEmpty {
                segments[base, default: []].append((0, value, true))
            } else if suffix.hasSuffix("*"), let number = Int(suffix.dropLast()) {
                segments[base, default: []].append((number, value, true))
            } else if let number = Int(suffix) {
                segments[base, default: []].append((number, value, false))
            }
        }
        for (base, list) in segments {
            let ordered = list.sorted { $0.0 < $1.0 }
            var charset: String?
            var joined = Data()
            for (offset, entry) in ordered.enumerated() {
                var piece = entry.1
                if entry.2 {
                    if offset == 0 {
                        let sections = piece.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                        if sections.count == 3 {
                            charset = String(sections[0])
                            piece = String(sections[2])
                        }
                    }
                    joined.append(percentDecode(piece))
                } else {
                    joined.append(Data(piece.utf8))
                }
            }
            plain[base] = string(from: joined, charset: charset)
        }
        return plain
    }

    private static func percentDecode(_ text: String) -> Data {
        let bytes = [UInt8](text.utf8)
        var out = [UInt8]()
        var index = 0
        while index < bytes.count {
            if bytes[index] == 37, index + 2 < bytes.count,
               let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                out.append(UInt8(high * 16 + low))
                index += 3
            } else {
                out.append(bytes[index])
                index += 1
            }
        }
        return Data(out)
    }
}
