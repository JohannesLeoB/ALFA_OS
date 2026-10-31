import Foundation

enum CarrierEngine {
    static func detect(_ raw: String) -> Carrier {
        let number = normalize(raw)
        guard number.isEmpty == false else { return .unknown }
        if number.hasPrefix("JJD") || number.hasPrefix("GM") || number.hasPrefix("LX") { return .dhl }
        if number.hasPrefix("H"), number.dropFirst().allSatisfy(\.isNumber), number.count >= 8 { return .hermes }
        if number.allSatisfy(\.isNumber), (12...22).contains(number.count) { return .dhl }
        return .unknown
    }

    static func normalize(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace }.uppercased()
    }
}
