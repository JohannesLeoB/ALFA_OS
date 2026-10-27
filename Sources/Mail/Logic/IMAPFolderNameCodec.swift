import Foundation

enum IMAPFolderNameCodec {
    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&" else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            guard let dash = text[index...].firstIndex(of: "-") else {
                result += text[index...]
                break
            }
            let body = text[text.index(after: index)..<dash]
            if body.isEmpty {
                result.append("&")
            } else {
                var base64 = body.replacingOccurrences(of: ",", with: "/")
                while base64.count % 4 != 0 { base64.append("=") }
                if let data = Data(base64Encoded: base64), let decoded = String(data: data, encoding: .utf16BigEndian) {
                    result += decoded
                } else {
                    result += text[index...dash]
                }
            }
            index = text.index(after: dash)
        }
        return result
    }

    static func encode(_ text: String) -> String {
        var result = ""
        var pending: [UInt16] = []
        func flush() {
            guard !pending.isEmpty else { return }
            var data = Data()
            for unit in pending {
                data.append(UInt8(unit >> 8))
                data.append(UInt8(unit & 0xFF))
            }
            let base64 = data.base64EncodedString()
                .replacingOccurrences(of: "/", with: ",")
                .replacingOccurrences(of: "=", with: "")
            result += "&" + base64 + "-"
            pending.removeAll()
        }
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x20 && scalar.value <= 0x7E {
                flush()
                if scalar == "&" { result += "&-" } else { result.unicodeScalars.append(scalar) }
            } else {
                pending.append(contentsOf: Array(String(scalar).utf16))
            }
        }
        flush()
        return result
    }
}
