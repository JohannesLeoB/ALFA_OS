import Foundation

public enum PlaceholderEngine {
    public static func fill(_ template: String, _ values: [String]) -> String {
        var result = ""
        var index = template.startIndex
        while index < template.endIndex {
            if template[index] == "{", let close = template[index...].firstIndex(of: "}"),
               let number = position(template[template.index(after: index)..<close]), values.indices.contains(number - 1) {
                result += values[number - 1]
                index = template.index(after: close)
            } else {
                result.append(template[index])
                index = template.index(after: index)
            }
        }
        return result
    }

    private static func position(_ digits: Substring) -> Int? {
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }
}
