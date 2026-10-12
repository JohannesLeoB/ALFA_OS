import Foundation

public enum OfferPositionExtractor {
    public enum Confidence: String, Equatable, Sendable {
        case green   
        case amber   
        case red     
    }

    public struct ExtractedPosition: Equatable, Sendable {
        public let title: String

        public let netPrice: Decimal?

        public let listPrice: Decimal?

        public let lineTotal: Decimal?
        public let quantity: Double?
        public let unit: String?
        public let lengthM: Double?
        public let areaM2: Double?

        public let componentType: ComponentType

        public let isAlternative: Bool
        public let confidence: Confidence
        public let originalText: String

        public let artikelnummer: String?

        public init(title: String, netPrice: Decimal?, listPrice: Decimal?, lineTotal: Decimal?,
                    quantity: Double?, unit: String?, lengthM: Double?, areaM2: Double?,
                    componentType: ComponentType = .other, isAlternative: Bool = false,
                    confidence: Confidence, originalText: String, artikelnummer: String? = nil) {
            self.title = title
            self.netPrice = netPrice
            self.listPrice = listPrice
            self.lineTotal = lineTotal
            self.quantity = quantity
            self.unit = unit
            self.lengthM = lengthM
            self.areaM2 = areaM2
            self.componentType = componentType
            self.isAlternative = isAlternative
            self.confidence = confidence
            self.originalText = originalText
            self.artikelnummer = artikelnummer
        }
    }

    public static func extractPositions(fromPageText text: String) -> [ExtractedPosition] {
        blocks(inPageText: text)
            .map { extract(fromBlock: $0) }
            .filter { $0.netPrice != nil && isHeaderNoise($0.title) == false }
    }

    private static let headerNoiseRegex = try! NSRegularExpression(
        pattern: #"(?i)(seite\s+\d+\s+von\s+\d+|\biban\b|\bbic\b|bankverbindung|ust[-\s.]?id|steuer[-\s.]?nr|nettobetrag|gesamtbetrag|mehrwertsteuer|zwischensumme|bruttobetrag)"#)

    private static let alternativeRegex = try! NSRegularExpression(
        pattern: #"(?i)(wie\s+pos|\balternativ|optional\b|eventual|bedarfsposition|wahlweise|zzgl\.\s*wenn)"#)

    private static let artikelnummerRegex = try! NSRegularExpression(
        pattern: #"(?i)art\.?\s*-?\s*nr\.?\s*:?\s*([0-9]{2,}(?:[.\-][0-9]+){0,3})"#)

    static func artikelnummer(in text: String) -> String? {
        let ns = text as NSString
        guard let match = artikelnummerRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        let raw = ns.substring(with: match.range(at: 1))
        return raw.isEmpty ? nil : raw
    }

    static func isAlternativePosition(_ text: String) -> Bool {
        let ns = text as NSString
        return alternativeRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    static func isHeaderNoise(_ title: String) -> Bool {
        let ns = title as NSString
        return headerNoiseRegex.firstMatch(in: title, range: NSRange(location: 0, length: ns.length)) != nil
    }

    static func blocks(inPageText text: String) -> [String] {
        let ns = text as NSString
        let anchors = anchorRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard anchors.isEmpty == false else {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? [] : [t]
        }
        var blocks: [String] = []
        for (i, m) in anchors.enumerated() {
            let start = m.range.location
            let end = (i + 1 < anchors.count) ? anchors[i + 1].range.location : ns.length
            let block = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if block.isEmpty == false { blocks.append(block) }
        }
        return blocks
    }

    private static let anchorRegex = try! NSRegularExpression(
        pattern: #"(?:^|[\n\r])\s*(?:Pos\.?\s*)?\d{1,3}(?:\.\d{1,3})?\s+(?=(?:\d+(?:,\d+)?\s+)*(?:\d+(?:,\d+)?\s*(?:Stk|Stck|Stück|Stueck|St|m²|m2|lfm)\b|(?!(?:Stk|Stck|Stück|Stueck|St|EUR)\b)[A-ZÄÖÜ]))"#,
        options: [])

    public static func extract(fromBlock text: String) -> ExtractedPosition {
        let deGlued = deGlue(text)
        let amounts = germanAmounts(in: text)
        let qty = leadingQuantity(in: text)
        let (lengthM, areaM2) = dimensions(in: text)
        let unitToken = unit(in: text)
        let category = OfferPositionClassifier.classify(text: text)
        let alternativ = isAlternativePosition(text)
        let artNr = artikelnummer(in: text)

        let disc = discount(in: deGlued)

        let candidateQuantities: [Double] = [qty, 1.0].compactMap { $0 }.filter { $0 > 0 }

        if let proof = selfProof(amounts: amounts, quantities: candidateQuantities) {
            let list = (disc.map { near($0.net, proof.einzel) } ?? false) ? disc?.list : nil
            return ExtractedPosition(
                title: firstTextLine(text), netPrice: proof.einzel, listPrice: list, lineTotal: proof.gesamt,
                quantity: proof.quantity, unit: unitToken, lengthM: lengthM, areaM2: areaM2,
                componentType: category, isAlternative: alternativ, confidence: .green, originalText: text, artikelnummer: artNr)
        }

        if let disc {
            return ExtractedPosition(
                title: firstTextLine(text), netPrice: disc.net, listPrice: disc.list, lineTotal: nil,
                quantity: qty, unit: unitToken, lengthM: lengthM, areaM2: areaM2,
                componentType: category, isAlternative: alternativ, confidence: .green, originalText: text, artikelnummer: artNr)
        }

        if let first = amounts.first {
            return ExtractedPosition(
                title: firstTextLine(text), netPrice: first, listPrice: nil, lineTotal: nil,
                quantity: qty, unit: unitToken, lengthM: lengthM, areaM2: areaM2,
                componentType: category, isAlternative: alternativ, confidence: .amber, originalText: text, artikelnummer: artNr)
        }

        return ExtractedPosition(
            title: firstTextLine(text), netPrice: nil, listPrice: nil, lineTotal: nil, quantity: qty,
            unit: unitToken, lengthM: lengthM, areaM2: areaM2,
            componentType: category, isAlternative: alternativ, confidence: .red, originalText: text, artikelnummer: artNr)
    }

    struct Proof: Equatable { let einzel: Decimal; let gesamt: Decimal; let quantity: Double }

    static func selfProof(amounts: [Decimal], quantities: [Double]) -> Proof? {
        guard amounts.count >= 2 else { return nil }
        for g in 1..<amounts.count {
            let gesamt = amounts[g]
            guard gesamt > 0 else { continue }
            for e in 0..<g {
                let einzel = amounts[e]

                guard einzel >= Decimal(5) else { continue }
                for q in quantities {
                    let erwartet = decimalDouble(einzel) * q
                    let ziel = decimalDouble(gesamt)
                    guard ziel > 0 else { continue }
                    if abs(erwartet - ziel) / ziel <= 0.01 {
                        return Proof(einzel: einzel, gesamt: gesamt, quantity: q)
                    }
                }
            }
        }
        return nil
    }

    struct Discount: Equatable { let list: Decimal; let percent: Double; let net: Decimal }

    private static let discountRegex = try! NSRegularExpression(
        pattern: #"((?:\d{1,3}(?:\.\d{3})+|\d+),\d{2})\s*(\d{1,2}(?:,\d{1,2})?)\s*%\s*((?:\d{1,3}(?:\.\d{3})+|\d+),\d{2})"#)

    static func discount(in text: String) -> Discount? {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        for m in discountRegex.matches(in: text, range: range) where m.numberOfRanges > 3 {
            guard let list = decimal(fromGerman: ns.substring(with: m.range(at: 1))),
                  let pct = germanDouble(ns.substring(with: m.range(at: 2))),
                  let net = decimal(fromGerman: ns.substring(with: m.range(at: 3))),
                  pct > 0, pct < 100 else { continue }
            let expected = decimalDouble(list) * (1 - pct / 100)
            let actual = decimalDouble(net)
            if actual > 0, abs(expected - actual) / actual <= 0.01 {
                return Discount(list: list, percent: pct, net: net)
            }
        }
        return nil
    }

    static func near(_ a: Decimal, _ b: Decimal) -> Bool {
        let x = decimalDouble(a), y = decimalDouble(b)
        guard y != 0 else { return x == 0 }
        return abs(x - y) / abs(y) <= 0.01
    }

    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])(?:\d{1,3}(?:\.\d{3})+,\d{2}(?![\d])|\d+,\d{2}(?![\d])(?![ \t]*(?:Stk|Stck|Stück|Stueck|St\b|m²|m2\b|lfm\b|m\b|cm\b|mm\b|%|x\b)))"#)

    private static let deGlueRegex = try! NSRegularExpression(pattern: #"(,\d{2})(?=\d)"#)

    static func germanAmounts(in text: String) -> [Decimal] {
        let deGlued = deGlue(text)
        let ns = deGlued as NSString
        return amountRegex.matches(in: deGlued, range: NSRange(location: 0, length: ns.length))
            .compactMap { m in decimal(fromGerman: ns.substring(with: m.range)) }
    }

    static func deGlue(_ text: String) -> String {
        let ns = text as NSString
        return deGlueRegex.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "$1 ")
    }

    static func decimal(fromGerman s: String) -> Decimal? {
        let normalized = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private static let quantityRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:,\d+)?)\s*(Stk|Stck|Stück|Stueck|St\b|x)"#, options: [.caseInsensitive])

    static func leadingQuantity(in text: String) -> Double? {
        let ns = text as NSString
        guard let m = quantityRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return germanDouble(ns.substring(with: m.range(at: 1)))
    }

    private static let lengthRegex = try! NSRegularExpression(pattern: #"(\d+(?:,\d+)?)\s*m(?![²2a-zA-Z])"#)
    private static let areaRegex = try! NSRegularExpression(pattern: #"(\d+(?:,\d+)?)\s*m(?:²|2)"#)

    static func dimensions(in text: String) -> (lengthM: Double?, areaM2: Double?) {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let area = areaRegex.firstMatch(in: text, range: full).flatMap { m in
            m.numberOfRanges > 1 ? germanDouble(ns.substring(with: m.range(at: 1))) : nil }
        let length = lengthRegex.firstMatch(in: text, range: full).flatMap { m in
            m.numberOfRanges > 1 ? germanDouble(ns.substring(with: m.range(at: 1))) : nil }
        return (length, area)
    }

    private static let unitRegex = try! NSRegularExpression(
        pattern: #"\b(Stk|Stck|Stück|Stueck|lfm|m²|m2|m|cm|h|psch|pauschal)\b"#, options: [.caseInsensitive])

    static func unit(in text: String) -> String? {
        let ns = text as NSString
        guard let m = unitRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range)
    }

    static func firstTextLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text

        let cleaned = line.replacingOccurrences(
            of: #"^\s*(?:Pos\.?\s*)?\d+(?:[.)]\d*)?\s+(?:\d+(?:,\d+)?\s+)?(?:Stck\.?|Stk\.?|Stück|Stueck|St\.?|x)?\s*"#,
            with: "", options: .regularExpression)
        return String(cleaned.prefix(120)).trimmingCharacters(in: .whitespaces)
    }

    static func germanDouble(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
    }

    static func decimalDouble(_ d: Decimal) -> Double {
        (d as NSDecimalNumber).doubleValue
    }
}
