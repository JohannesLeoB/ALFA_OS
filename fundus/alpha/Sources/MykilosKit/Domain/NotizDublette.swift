import Foundation

public enum NotizDublette {
    public static let schwelle = 0.8

    static func woerter(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false })
    }

    public static func aehnlichkeit(_ a: String, _ b: String) -> Double {
        let wa = woerter(a), wb = woerter(b)
        guard wa.isEmpty == false, wb.isEmpty == false else { return 0 }
        return Double(wa.intersection(wb).count) / Double(wa.union(wb).count)
    }

    public static func vorhandene(zu text: String, in notizen: [AssistantNote]) -> AssistantNote? {
        notizen
            .map { ($0, aehnlichkeit(text, $0.body)) }
            .filter { $0.1 >= schwelle }
            .max { $0.1 < $1.1 }?.0
    }
}
