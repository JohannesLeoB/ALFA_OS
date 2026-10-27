import Foundation

enum NoteDuplicateEngine {
    static let threshold = 0.8

    static func words(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false })
    }

    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = words(lhs)
        let right = words(rhs)
        guard left.isEmpty == false, right.isEmpty == false else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    static func existing(for text: String, in notes: [Note]) -> Note? {
        notes
            .map { ($0, similarity(text, $0.body)) }
            .filter { $0.1 >= threshold }
            .max { $0.1 < $1.1 }?.0
    }
}
