import Foundation

public enum HTMLText {
    public static func plain(_ html: String) -> String {
        var roh = html
        for tag in ["style", "script", "head", "title"] {
            roh = roh.replacingOccurrences(
                of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>",
                with: " ", options: [.regularExpression, .caseInsensitive])
        }
        roh = roh.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: " ", options: .regularExpression)
        roh = roh.replacingOccurrences(of: "<br\\s*/?>", with: "\n",
                                       options: [.regularExpression, .caseInsensitive])
        roh = roh.replacingOccurrences(of: "</(p|div|tr|li|h[1-6])\\s*>", with: "\n",
                                       options: [.regularExpression, .caseInsensitive])
        let out = decodeEntities(roh.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
        return out.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]*\n[ \\t]*", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "auml": "ä", "ouml": "ö", "uuml": "ü", "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß",
        "euro": "€", "ndash": "–", "mdash": "—", "hellip": "…", "laquo": "«", "raquo": "»",
        "bdquo": "„", "ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’", "copy": "©", "reg": "®",
        "agrave": "à", "aacute": "á", "acirc": "â", "egrave": "è", "eacute": "é", "ecirc": "ê",
        "iacute": "í", "oacute": "ó", "ocirc": "ô", "uacute": "ú", "ccedil": "ç", "ntilde": "ñ",
        "bull": "•", "middot": "·", "trade": "™", "deg": "°", "times": "×", "sect": "§", "para": "¶",
        "plusmn": "±", "pound": "£", "yen": "¥", "cent": "¢"
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.firstIndex(of: ";"), after.distance(from: after.startIndex, to: semi) <= 10 {
                let name = String(after[..<semi])
                if let value = entity(name) {
                    result += value
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }

    static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[name]
    }
}
