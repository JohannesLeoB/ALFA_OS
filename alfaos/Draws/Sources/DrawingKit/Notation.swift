import Foundation

public enum Notation {
    static let appliances = ["oven", "dishwasher", "fridge", "hob", "sink"]

    public static func format(_ fronts: [Front]) -> String {
        fronts.map { f in
            var text: String
            switch f.type {
            case .door: text = f.side?.rawValue ?? FrontType.door.rawValue
            case .glass: text = FrontType.glass.rawValue + (f.side.map { ":" + $0.rawValue } ?? "")
            case .open: text = FrontType.open.rawValue
            case .appliance: text = f.appliance?.rawValue ?? FrontType.appliance.rawValue
            case .drawers: text = f.drawers?.joined(separator: ",") ?? String(f.count ?? 1)
            }
            if let h = f.height { text += "@" + String(format: "%g", h) }
            return text
        }.joined(separator: " / ")
    }

    public static func parse(_ text: String) -> [Front]? {
        var out: [Front] = []
        for raw in text.split(separator: "/") {
            let pair = raw.split(separator: "@", omittingEmptySubsequences: false)
            let token = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
            var height: Double?
            if pair.count > 1 {
                guard pair.count == 2, let value = Double(pair[1].trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
                height = value
            }
            var front: Front
            if let side = HingeSide(rawValue: token) {
                front = Front(type: .door, side: side)
            } else if token == FrontType.door.rawValue {
                front = Front(type: .door)
            } else if token == FrontType.open.rawValue {
                front = Front(type: .open)
            } else if token.hasPrefix(FrontType.glass.rawValue) {
                let side = token.split(separator: ":").dropFirst().first.flatMap { HingeSide(rawValue: String($0)) }
                front = Front(type: .glass, side: side)
            } else if let a = Appliance(rawValue: token) {
                front = Front(type: .appliance, appliance: a)
            } else if let n = Int(token), n > 0 {
                front = Front(type: .drawers, count: n)
            } else if !token.isEmpty, token.allSatisfy({ $0.isLetter || $0 == "," }) {
                front = Front(type: .drawers, drawers: token.split(separator: ",").map(String.init))
            } else {
                return nil
            }
            front.height = height
            out.append(front)
        }
        return out.isEmpty ? nil : out
    }
}
