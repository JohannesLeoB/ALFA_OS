import Foundation

enum UIDSetEngine {
    static func text(_ uids: [Int]) -> String {
        let sorted = Array(Set(uids)).sorted()
        var parts: [String] = []
        var index = 0
        while index < sorted.count {
            var end = index
            while end + 1 < sorted.count, sorted[end + 1] == sorted[end] + 1 { end += 1 }
            parts.append(end == index ? String(sorted[index]) : "\(sorted[index]):\(sorted[end])")
            index = end + 1
        }
        return parts.joined(separator: ",")
    }
}
