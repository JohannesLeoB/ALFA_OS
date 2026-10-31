import Core
import Foundation

struct EstimateRequestParser: Sendable {
    func parse(_ text: String) -> EstimateInput {
        let lower = text.lowercased()
        let materials = MaterialLexicon.shared.materialCanonicals(in: lower)
        var scope = parseScope(lower)
        var components: [EstimateComponent] = []
        let drawerCount = parseDrawerCount(lower)

        if let run = parseRun(lower) {
            components.append(EstimateComponent(type: .baseCabinetRun, quantity: run, unit: "lfm", drawerCount: drawerCount, materials: materials, componentClass: .kitchenRun))
        } else if let width = parseBaseUnitWidth(lower) {
            components.append(EstimateComponent(type: .baseCabinetRun, quantity: 1, unit: "piece", widthM: width, drawerCount: drawerCount, materials: materials, componentClass: .baseUnit))
        } else if lower.contains("zeile") || lower.contains("rückzeile") || lower.contains("rueckzeile") || lower.contains("unterschränke") || lower.contains("unterschraenke") {
            components.append(EstimateComponent(type: .baseCabinetRun, quantity: 4.0, unit: "lfm", drawerCount: drawerCount, materials: materials, scopeNotes: [.sizeEstimated, Notice("calc.note.runMissing")], componentClass: .kitchenRun))
        }

        if lower.contains("gesamtküche") || lower.contains("gesamtkuche") || lower.contains("gesamtkueche") || lower.contains("einbauküche") || lower.contains("einbaukueche") {
            components.append(EstimateComponent(type: .aggregateKitchen, quantity: 1, unit: "scope", materials: materials, componentClass: .aggregateKitchen))
        }

        if lower.contains("insel") || lower.contains("küchenblock") || lower.contains("kuechenblock") {
            let dimensions = parseDimension(after: "insel", in: lower) ?? parseDimension(after: "", in: lower)
            let quantity = dimensions?.width ?? 1
            let footprint = (dimensions?.width ?? 0) * (dimensions?.height ?? 0)
            components.append(EstimateComponent(type: .island, quantity: footprint > 0 ? footprint : quantity, unit: footprint > 0 ? "m2" : "lfm", widthM: dimensions?.width, heightM: dimensions?.height, depthM: dimensions?.depth, materials: materials, componentClass: .island))
        }

        let standaloneTall = lower.contains("treppenschrank")
            || lower.contains("geräteschrank") || lower.contains("geraeteschrank")
            || lower.contains("schrankblock") || lower.contains("schrank block")
            || lower.contains("einbauschrank")
            || lower.contains("nischen-hochschrank") || lower.contains("nischenhochschrank")
        let genericTall = lower.contains("hochschrank") || lower.contains("hochschr") || lower.contains("hochschränke")
        let hasRun = components.contains { $0.componentClass == .kitchenRun }
        let hasIsland = components.contains { $0.componentClass == .island }

        let dimensions = hasIsland ? nil : parseDimension(after: "", in: lower)
        let hasExplicitTallDim = dimensions != nil

        if standaloneTall || (genericTall && (!hasRun || hasExplicitTallDim)) {
            let width = dimensions?.width
            let estimated = width == nil
            components.append(EstimateComponent(
                type: .tallCabinetBlock,
                quantity: width ?? 1.0,
                unit: "lfm",
                widthM: width,
                heightM: dimensions?.height,
                depthM: dimensions?.depth,
                materials: materials,
                scopeNotes: estimated ? [.sizeEstimated, Notice("calc.note.tallWidthMissing")] : [],
                componentClass: .tallCabinetBlock))
        }

        if lower.contains("hängeschrank") || lower.contains("haengeschrank") {
            components.append(EstimateComponent(type: .wallCabinets, quantity: parseRun(lower) ?? 1, unit: "lfm", materials: materials))
        }

        if lower.contains("arbeitsplatte") || lower.contains("waschtischplatte") || lower.contains("fensterbank") || lower.contains("ap ") || lower.contains("stein") || lower.contains("marmor") || lower.contains("granit") || lower.contains("dekton") || MaterialLexicon.shared.mentionsWorktopSurface(in: lower) {
            if !scope.excludesWorktop && !scope.excludesStone {
                let area = parseArea(lower) ?? 1
                components.append(EstimateComponent(type: .stoneCountertop, quantity: area, unit: area == 1 ? "scope" : "m2", materials: materials, componentClass: .worktopSurface))
            }
        }

        if lower.contains("lieferung") && !components.contains(where: { $0.type == .delivery }) {
            components.append(EstimateComponent(type: .delivery, quantity: 1, unit: "scope", materials: []))
        }

        if lower.contains("montage") && !components.contains(where: { $0.type == .installation }) {
            components.append(EstimateComponent(type: .installation, quantity: 1, unit: "scope", materials: []))
        }

        if components.isEmpty {
            components.append(EstimateComponent(type: .other, quantity: 1, unit: "scope", materials: materials))
            scope.notes.append(Notice("calc.scope.unmapped"))
        }

        components = components.map(normalizeImplausibleSize)
        return EstimateInput(rawText: text, components: components, materials: materials, scope: scope)
    }

    private func normalizeImplausibleSize(_ component: EstimateComponent) -> EstimateComponent {
        let cap: Double
        switch component.componentClass {
        case .kitchenRun, .tallCabinetBlock: cap = 20
        case .island: cap = component.unit == "m2" ? 12 : 8
        case .worktopSurface: cap = 30
        case .baseUnit where component.unit == "piece" && component.widthM != nil: cap = 1.5
        default: return component
        }
        let measured = (component.componentClass == .baseUnit ? (component.widthM ?? 0) : component.quantity)
        guard measured > cap, measured > 0 else { return component }
        var capped = component
        if component.componentClass == .baseUnit { capped.widthM = cap } else { capped.quantity = cap }
        capped.scopeNotes = component.scopeNotes + [
            .sizeImplausible,
            Notice("calc.note.sizeImplausible", [Notice.measure(measured), component.unit, Notice.measure(cap)]),
        ]
        return capped
    }

    private func parseScope(_ lower: String) -> ScopeFlags {
        var scope = ScopeFlags()
        scope.includesDelivery = lower.contains("lieferung") && !lower.contains("ohne lieferung")
        scope.includesInstallation = lower.contains("montage") && !lower.contains("ohne montage")
        scope.excludesAppliances = lower.contains("ohne geräte") || lower.contains("ohne geraete") || lower.contains("geräte bauseits") || lower.contains("geraete bauseits") || lower.contains("ohne elektro") || lower.contains("ohne anschlüsse") || lower.contains("ohne anschluesse") || lower.contains("/geräte") || lower.contains("/geraete")
        scope.excludesWorktop = lower.contains("ohne arbeitsplatte") || lower.contains("ohne ap") || lower.contains("ohne ap/")
        scope.excludesStone = lower.contains("ohne stein") || lower.contains("ohne dekton")
        if scope.excludesAppliances { scope.notes.append(Notice("calc.scope.appliancesExcluded")) }
        if scope.excludesWorktop { scope.notes.append(Notice("calc.scope.worktopExcluded")) }
        if scope.excludesStone { scope.notes.append(Notice("calc.scope.stoneExcluded")) }
        if scope.includesDelivery { scope.notes.append(Notice("calc.scope.deliveryIncluded")) }
        if scope.includesInstallation { scope.notes.append(Notice("calc.scope.installationIncluded")) }
        return scope
    }

    private func parseRun(_ lower: String) -> Double? {
        let patterns = [
            #"([0-9]+(?:[,.][0-9]+)?)\s*(?:laufmeter|lfm)\b"#,
            #"([0-9]+(?:[,.][0-9]+)?)\s*(?:laufende\s+meter|meter|m)\s+(?:küchenzeile|kuechenzeile|unterschränke|unterschraenke|us|unterbau|zeile|rückzeile|rueckzeile|wandzeile|spülenzeile|spuelenzeile|us-zeile)"#,
            #"([0-9]+(?:[,.][0-9]+)?)\s*(?:laufende\s+meter|meter|m)\s+(?:\w+)?küche\b"#,
        ]
        return firstDouble(patterns: patterns, in: lower)
    }

    private func parseBaseUnitWidth(_ lower: String) -> Double? {
        let mentionsUS = lower.hasPrefix("us ") || lower.contains(" us ")
        guard lower.contains("unterschrank") || lower.contains("unterschränk") || lower.contains("unterschraenk") || mentionsUS || lower.contains("unterbau") || lower.contains("korpus unten") else { return nil }
        let patterns = [
            #"([0-9]+(?:[,.][0-9]+)?)\s*cm\s+(?:[a-zäöüß-]+\s+){0,2}unterschrank"#,
            #"([0-9]+(?:[,.][0-9]+)?)\s*cm"#,
        ]
        guard let centimeters = firstDouble(patterns: patterns, in: lower) else { return 0.6 }
        return centimeters / 100
    }

    private func parseArea(_ lower: String) -> Double? {
        firstDouble(patterns: [#"([0-9]+(?:[,.][0-9]+)?)\s*(?:m2|m²|qm)\b"#], in: lower)
    }

    private func parseDrawerCount(_ lower: String) -> Int {
        let drawerWords = ["schubkästen", "schubkaesten", "schubladen", "legraboxen", "legrabox"]
        var total = 0
        for word in drawerWords {
            let pattern = #"([0-9]+|ein|eine|einen|zwei|drei|vier|fünf|fuenf|sechs|sieben|acht|neun|zehn|elf|zwölf|zwoelf|dreizehn|vierzehn|fünfzehn|fuenfzehn)\s+(?:[a-zäöüß-]+\s+){0,2}[a-zäöüß-]*\#(word)\b"#
            for match in matches(pattern: pattern, in: lower) {
                let token = String(match.1)
                total += Int(token) ?? NumberParser.integerWord(token) ?? 0
            }
        }
        return total
    }

    private func parseDimension(after marker: String, in lower: String) -> (width: Double, height: Double?, depth: Double?)? {
        let searchArea: String
        if marker.isEmpty {
            searchArea = lower
        } else if let range = lower.range(of: marker) {
            searchArea = String(lower[range.lowerBound...])
        } else {
            searchArea = lower
        }
        let pattern = #"([0-9]+(?:[,.][0-9]+)?)\s*x\s*([0-9]+(?:[,.][0-9]+)?)(?:\s*x\s*([0-9]+(?:[,.][0-9]+)?))?\s*m?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(searchArea.startIndex..<searchArea.endIndex, in: searchArea)
        guard let result = regex.firstMatch(in: searchArea, range: nsRange),
              let firstRange = Range(result.range(at: 1), in: searchArea),
              let secondRange = Range(result.range(at: 2), in: searchArea) else { return nil }
        let width = NumberParser.double(String(searchArea[firstRange])) ?? 0
        let second = NumberParser.double(String(searchArea[secondRange]))
        let third: Double?
        if result.numberOfRanges > 3,
           result.range(at: 3).location != NSNotFound,
           let thirdRange = Range(result.range(at: 3), in: searchArea) {
            third = NumberParser.double(String(searchArea[thirdRange]))
        } else {
            third = nil
        }
        return (width, second, third)
    }

    private func firstDouble(patterns: [String], in text: String) -> Double? {
        for pattern in patterns {
            if let match = matches(pattern: pattern, in: text).first,
               let value = NumberParser.double(String(match.1)) {
                return value
            }
        }
        return nil
    }

    private func matches(pattern: String, in text: String) -> [(Substring, Substring)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { result in
            guard result.numberOfRanges >= 2,
                  let r0 = Range(result.range(at: 0), in: text),
                  let r1 = Range(result.range(at: 1), in: text) else { return nil }
            return (text[r0], text[r1])
        }
    }
}

enum NumberParser {
    static func decimal(_ input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutCurrency = trimmed
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String
        if withoutCurrency.contains(",") {
            normalized = withoutCurrency
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = withoutCurrency
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func double(_ input: String) -> Double? {
        guard let decimal = decimal(input) else { return nil }
        return decimal.double
    }

    static let integerWords: [String: Int] = [
        "ein": 1, "eine": 1, "einen": 1, "eins": 1, "zwei": 2, "drei": 3,
        "vier": 4, "fünf": 5, "fuenf": 5, "sechs": 6, "sieben": 7,
        "acht": 8, "neun": 9, "zehn": 10, "elf": 11, "zwölf": 12,
        "zwoelf": 12, "dreizehn": 13, "vierzehn": 14, "fünfzehn": 15,
        "fuenfzehn": 15,
    ]

    static func integerWord(_ input: String) -> Int? {
        integerWords[input.lowercased()]
    }
}

public extension Dictionary where Key == String, Value == String {
    func decimal(_ key: String) -> Decimal {
        NumberParser.decimal(string(key)) ?? 0
    }

    func optionalDecimal(_ key: String) -> Decimal? {
        NumberParser.decimal(string(key))
    }

    func double(_ key: String) -> Double {
        let value = string(key)
        if let double = Double(value) { return double }
        return NumberParser.double(value) ?? 0
    }
}

struct MaterialLexicon: Sendable {
    struct Hit: Equatable, Sendable {
        let canonical: String
        let category: String
        let emit: String?
    }

    struct Entry: Sendable {
        let canonical: String
        let category: String
        let emit: String?
        let surfaces: [String]
    }

    private struct IndexItem: Sendable {
        let surface: [Character]
        let entry: Int
        let boundary: Bool
    }

    static let shared = MaterialLexicon()

    static let rewrites: [(String, String)] = [
        ("wrichenfurnier", "eiche furnier"),
        ("eichefurnier", "eiche furnier"),
    ]

    static let wordChars: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzäöüß")

    let entries: [Entry]

    private let index: [IndexItem]

    init() {
        let all = Self.allEntries()
        self.entries = all
        var items: [IndexItem] = []
        for (position, entry) in all.enumerated() {
            for surface in entry.surfaces {
                let chars = Array(surface)
                items.append(IndexItem(surface: chars, entry: position, boundary: chars.count <= 3))
            }
        }
        self.index = items.enumerated()
            .sorted { lhs, rhs in
                lhs.element.surface.count != rhs.element.surface.count
                    ? lhs.element.surface.count > rhs.element.surface.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func allEntries() -> [Entry] {
        woodEntries()
            + decorLinoleumEntries()
            + lacquerEntries()
            + naturalStoneEntries()
            + mineralSurfaceEntries()
            + worktopEntries()
            + metalGlassEntries()
            + handleHardwareEntries()
            + componentEntries()
            + unitEntries()
    }

    private static func woodEntries() -> [Entry] { [
        Entry(canonical: "eiche", category: "veneer", emit: "eiche", surfaces: ["aiche", "asteiche", "echie", "eiceh", "eiche", "eiche fronten", "eichefronten", "eichen", "eichenfronten", "eichenholz", "eichw", "eihce", "eihe", "europäische eiche", "knoteiche", "oak", "roteiche", "weiseiche", "weißeiche", "wildeiche"]),
        Entry(canonical: "mooreiche", category: "solid_wood", emit: "mooreiche", surfaces: ["bog oak", "moor eiche", "moor eihce", "moor-eiche", "mooreiche", "mooreichenholz", "mooreihe", "moreiche", "morreiche", "schwarzeiche"]),
        Entry(canonical: "raeuchereiche", category: "veneer", emit: "raeuchereiche", surfaces: ["geräucherte eiche", "raeuchereiche", "rauchereiche", "raucheriche", "reuchereiche", "räucher-eiche", "räuchereich", "räuchereiche", "räuchereichenholz", "räuchereihe", "smoked oak", "thermo-eiche", "thermoeiche"]),
        Entry(canonical: "nussbaum", category: "veneer", emit: "nussbaum", surfaces: ["amerik. nussbaum", "amerikanischer nussbaum", "europäischer nussbaum", "nissbaum", "nusbaum", "nusbsum", "nussbam", "nussbaum", "nussbaum fronten", "nussbaumfronten", "nussbaumholz", "nussbsum", "nußbam", "nußbaum", "nußbsum", "schwarznuss", "walnus", "walnuss", "walnut", "walnuus", "walnuß"]),
        Entry(canonical: "esche", category: "veneer", emit: "esche", surfaces: ["ash", "esceh", "esche", "esche fronten", "eschenfronten", "eschenholz", "eshe", "essche", "kernesche", "oliv-esche", "olivesche", "weißesche", "weißsche"]),
        Entry(canonical: "ahorn", category: "veneer", emit: "ahorn", surfaces: ["aborn", "achorn", "ahonr", "ahorm", "ahorn", "ahorn fronten", "ahornfronten", "ahornholz", "ahron", "berg-ahorn", "bergahorn", "kanadischer ahorn", "maple", "riegelahorn", "vogelaugenahorn"]),
        Entry(canonical: "buche", category: "veneer", emit: "buche", surfaces: ["bcuhe", "beech", "buche", "buche fronten", "buchee", "buchen", "buchenfronten", "buchenholz", "bueche", "buhce", "buhe", "dampfbuche", "hainbuche", "kernbuche", "rotbuche", "weißbuche"]),
        Entry(canonical: "kirsche", category: "veneer", emit: "kirsche", surfaces: ["amerik. kirsche", "amerikanische kirsche", "cherry", "kirsce", "kirsch", "kirschbaum", "kirschbaumholz", "kirsche", "kirsche fronten", "kirschfronten", "kirschholz", "kirschr", "kirshce", "kirshe", "kische"]),
        Entry(canonical: "laerche", category: "solid_wood", emit: "laerche", surfaces: ["laerche", "larch", "larche", "lerche", "lähre", "lärceh", "lärch", "lärche", "lärche sib.", "lärchenfronten", "lärchenholz", "lärrche", "sibirische lärche"]),
        Entry(canonical: "fichte", category: "solid_wood", emit: "fichte", surfaces: ["altholz fichte", "fchte", "ficht", "fichte", "fichte altholz", "fichten", "fichtenfronten", "fichtenholz", "fichtte", "fichtw", "fihcte", "fitche", "spruce"]),
        Entry(canonical: "kiefer", category: "solid_wood", emit: "kiefer", surfaces: ["föhre", "keifer", "kiefer", "kiefern", "kiefernfronten", "kiefernholz", "kieferr", "kieffer", "kiefr", "kifer", "kiffer", "pine"]),
        Entry(canonical: "teak", category: "solid_wood", emit: "teak", surfaces: ["alt-teak", "altteak", "taek", "teack", "teak", "teakfronten", "teakholz", "teakk", "teakwood", "teek"]),
        Entry(canonical: "furnier", category: "veneer", emit: "furnier", surfaces: ["deckfurnier", "echtholz-furnier", "echtholzfurnier", "echtholzfurniert", "edelfurnier", "fournier", "funier", "furier", "furneir", "furnier", "furnier fronten", "furnier-fronten", "furniere", "furnierfronten", "furnierkorpus", "furnierplatte", "furnierspan", "furnierspanplatte", "furniert", "furnierte", "furnierte spanplatte", "furnir", "furnoer", "holzfurnier", "holzfurniert", "messerfurnier", "schälfurnier", "veneer", "vurnier", "wrichenfurnier"]),
        Entry(canonical: "massivholz", category: "solid_wood", emit: "massivholz", surfaces: ["durchgehend massiv", "echtholz massiv", "masiv", "masivholz", "massholz", "massifholz", "massiv", "massiv-front", "massiv-holz", "massivfront", "massivhloz", "massivholz", "massivholz fronten", "massivholzausführung", "massivholzfronten", "massivholzkorpus", "massivholzplatte", "massivolz", "solid wood", "voll-holz", "vollholz", "vollholzfronten", "vollhoz"]),
        Entry(canonical: "leimholz", category: "solid_wood", emit: "leimholz", surfaces: ["3-schicht", "dreischicht", "durchgehende lamelle", "durchgehendes leimholz", "laimholz", "leihmholz", "leim-holz", "leimholtz", "leimholz", "leimholz-platte", "leimholzausführung", "leimholzfronten", "leimholzkorpus", "leimholzplatte", "leimhoz", "leinholz"]),
        Entry(canonical: "multiplex", category: "solid_wood", emit: "multiplex", surfaces: ["birke multiplex", "birken-multiplex", "mulitplex", "multipex", "multipleks", "multiplex", "multiplex sichtkante", "multiplex-korpus", "multiplex-platte", "multiplexfronten", "multiplexkanten", "multiplexkorpus", "multiplexplatte", "multiplexx", "multipllex", "multplex", "schichtsperrholz", "sperrholz"]),
        Entry(canonical: "staebchenplatte", category: "solid_wood", emit: "staebchenplatte", surfaces: ["stabchenplatte", "stabsperrholz", "staebchenplatte", "stebchenplatte", "stäbchen", "stäbchen-korpus", "stäbchen-platte", "stäbchenpaltte", "stäbchenplate", "stäbchenplatte", "stäbchenplattenkorpus", "tischler-platte", "tischlerpaltte", "tischlerplate", "tischlerplatte", "tischlerplattenkorpus"]),
    ] }

    private static func decorLinoleumEntries() -> [Entry] { [
        Entry(canonical: "melamin", category: "decor_laminate", emit: "dekorspan", surfaces: ["mealmin", "melamiin", "melamim", "melamin", "melamin beschichtete spanplatte", "melamin-beschichtet", "melamin-front", "melamin-platte", "melaminbeschichtet", "melaminbeschichtung", "melamine", "melaminfront", "melaminharz", "melaminharz-beschichtet", "melaminharzbeschichtet", "melaminharzplatte", "melaminkorpus", "melaminn", "melaminplatte", "melaminplatten", "melamn", "mellamin", "mfc"]),
        Entry(canonical: "egger", category: "decor_laminate", emit: "dekorspan", surfaces: ["eger", "egga", "eggar", "egger", "egger dekor", "egger dekr", "egger eurodekor", "egger feelwood", "egger h-dekor", "egger melamin", "egger platte", "egger spanplatte", "egger u-dekor", "egger w-dekor", "egger-dekor", "egger-dekore", "egger-dekoren", "egger-dekorplatte", "egger-dekr", "egger-platte", "egger-platten", "eggerdekor", "eggerdekore", "eggerplatten", "eggr"]),
        Entry(canonical: "dekorspan", category: "decor_laminate", emit: "dekorspan", surfaces: ["beschichtete spanplatte", "decorspan", "dekor beschichtete spanplatte", "dekor span", "dekor span platte", "dekor-platte", "dekor-spanplatte", "dekor-spanplatten", "dekorbeschichtet", "dekorierte spanplatte", "dekorplatte", "dekorplatten", "dekorspan", "dekorspan platte", "dekorspan-korpus", "dekorspan-platte", "dekorspankorpus", "dekorspann", "dekorspanplate", "dekorspanplatte", "dekorspanplatten", "dekrospan"]),
        Entry(canonical: "dekor", category: "decor_laminate", emit: "dekorspan", surfaces: ["decor", "dekoer", "dekoor", "dekor", "dekor-", "dekor-oberfläche", "dekorausführung", "dekore", "dekoren", "dekorfarbe", "dekorfläche", "dekorgruppe", "dekoriert", "dekoroberfläche", "dekorr", "dekors", "dekorvariante", "dekorvarianten", "dekro", "dekur", "farbdekor", "im dekor", "in dekor"]),
        Entry(canonical: "schichtstoff", category: "decor_laminate", emit: "dekorspan", surfaces: ["high pressure laminate", "hochdrucklaminat", "hpl", "hpl beschichtet", "hpl platte", "hpl-beschichtet", "hpl-platte", "hpl-platten", "hplplatte", "laminat", "schichstoff", "schichtsoff", "schichtstof", "schichtstoff", "schichtstoff-front", "schichtstoff-platte", "schichtstoff-platten", "schichtstoffbeschichtet", "schichtstoffbeschichtung", "schichtstoffe", "schichtstofffront", "schichtstoffplatte", "schichtstoffplatten", "schihtstoff"]),
        Entry(canonical: "resopal", category: "decor_laminate", emit: "dekorspan", surfaces: ["resapal", "resapol", "resopal", "resopal beschichtet", "resopal dekor", "resopal-platte", "resopal-platten", "resopalbeschichtet", "resopall", "resopaloberfläche", "resopalplatte", "resopalplatten", "resoplal", "resopol", "respoal"]),
        Entry(canonical: "kunstharz", category: "decor_laminate", emit: "dekorspan", surfaces: ["harzbeschichtet", "kunsharz", "kunstarz", "kunsthars", "kunstharz", "kunstharz beschichtet", "kunstharz beschichtete platte", "kunstharz-beschichtet", "kunstharz-platte", "kunstharzbeschichtet", "kunstharzbeschichtung", "kunstharzoberfläche", "kunstharzplatte", "kunstharzplatten", "kunstharzz"]),
        Entry(canonical: "kunststoff", category: "decor_laminate", emit: "dekorspan", surfaces: ["kunsstoff", "kunstoff", "kunstsoff", "kunststof", "kunststoff", "kunststoff beschichtet", "kunststoff-beschichtet", "kunststoff-platte", "kunststoffbeschichtet", "kunststoffbeschichtung", "kunststoffe", "kunststoffoberfläche", "kunststoffplatte", "kunststoffplatten", "plastikbeschichtet"]),
        Entry(canonical: "beschichtet", category: "decor_laminate", emit: "dekorspan", surfaces: ["beschchtet", "beschichted", "beschichten", "beschichtet", "beschichtete", "beschichtete platte", "beschichtete spanplatte", "beschichteter", "beschichtetes", "beschichtetet", "beschichtung", "beschichtungen", "beschictet", "beschihtet", "beschtet", "dekorbeschichtet", "kunstharzbeschichtet", "melaminbeschichtet", "oberflächenbeschichtet"]),
        Entry(canonical: "folie", category: "decor_laminate", emit: "dekorspan", surfaces: ["dekorfolie", "foile", "foli", "folie", "folien", "folien-", "folien-front", "folien-fronten", "folienbeschichtet", "folienfront", "folienfronten", "folienoberfläche", "folienplatte", "foliert", "foliert beschichtet", "folierte", "folierter", "foliertes", "folierung", "folje", "follie", "fooie", "kunststofffolie", "pp-folie", "pvc-folie"]),
        Entry(canonical: "foliert", category: "decor_laminate", emit: "dekorspan", surfaces: ["foeliert", "foiliert", "folie", "folienbeschichtet", "folierd", "folieren", "foliert", "foliert beschichtet", "folierte", "folierte fronten", "folierte-fronten", "folierter", "foliertes", "folierung", "foliret", "folliert", "umfoliert"]),
        Entry(canonical: "mdf", category: "decor_laminate", emit: "mdf", surfaces: ["lackträger mdf", "mdf", "mdf beschichtet", "mdf platte", "mdf träger", "mdf-front", "mdf-fronten", "mdf-korpus", "mdf-plate", "mdf-platt", "mdf-platte", "mdf-platten", "mdf-roh", "mdfkorpus", "mdfplatte", "mdfplatten", "mitteldichte faserplatte"]),
        Entry(canonical: "unidekor", category: "decor_laminate", emit: "dekorspan", surfaces: ["einfarbig dekor", "uni color", "uni dekor", "uni dekr", "uni-dekor", "uni-dekore", "uni-farbe", "uni-farbig", "unicolor", "unidecor", "unidekoor", "unidekor", "unidekore", "unidekoren", "unidekr", "unifarbe", "unifarben", "unifarbig", "uunidekor"]),
        Entry(canonical: "holzdekor", category: "decor_laminate", emit: "dekorspan", surfaces: ["dekor holzoptik", "holz dekr", "holz nachbildung", "holz-dekor", "holz-dekore", "holz-optik", "holzdecor", "holzdekoor", "holzdekor", "holzdekor span", "holzdekore", "holzdekoren", "holzdekorplatte", "holzdekorplatten", "holzdekorr", "holzdekr", "holznachbildung", "holzoptik", "holzoptik-dekor"]),
        Entry(canonical: "betondekor", category: "decor_laminate", emit: "dekorspan", surfaces: ["beton dekr", "beton-dekor", "beton-dekore", "beton-optik", "betondecor", "betondekoor", "betondekor", "betondekore", "betondekoren", "betondekr", "betongrau dekor", "betonnachbildung", "betonndekor", "betonoptik", "betonoptik dekor", "betonoptik-dekor", "dekor beton"]),
        Entry(canonical: "linoleum", category: "linoleum", emit: "linoleum", surfaces: ["beidseitig linoleum", "echtlinoleum", "furniture linoleum", "furniturelinoleum", "in linoleum", "laminoleum", "linaleum", "lino", "linoleom", "linoleum", "linoleum auf mdf", "linoleum beleg", "linoleum farbton", "linoleum verkleidet", "linoleum-front", "linoleum-fronten", "linoleumbeleg", "linoleumbeschichtung", "linoleumfläche", "linoleumfront", "linoleumfronten", "linoleumoberflaeche", "linoleumoberfläche", "linoleumplatte", "linoleun", "linoleuum", "linolium", "linoljum", "linoluem", "mdf linoleum", "mdf-linoleum", "mit linoleum", "moebellinoleum", "möbellinoleum"]),
        Entry(canonical: "forbo", category: "linoleum", emit: "linoleum", surfaces: ["beidseitig forbo", "forbe", "forbo", "forbo desktop", "forbo desktop linoleum", "forbo furniture", "forbo furniture linoleum", "forbo linoleum", "forbo linolium", "forbo möbellinoleum", "forbo-front", "forbo-linoleum", "forbofront", "forbofronten", "forbolinoleum", "forbolinolium", "forboo", "in forbo", "linoleum forbo", "mit forbo", "vorbo", "zum forbo linoleum"]),
        Entry(canonical: "desktop", category: "linoleum", emit: "linoleum", surfaces: ["desctop", "desktop", "desktop linoleum", "desktop-front", "desktop-linoleum", "desktopfront", "desktopoberfläche", "destop", "forbo desktop", "forbo desktop linoleum", "mit desktop"]),
    ] }

    private static func lacquerEntries() -> [Entry] { [
        Entry(canonical: "lack", category: "lacquer", emit: "lack", surfaces: ["ablackiert", "deckend lackiert", "dekend lackierd", "endlackiert", "endlackierung", "farbig lackiert", "farblos lackiert", "front lackiert", "fronten lackiert", "klar lackiert", "klar matt lackiert", "lack", "lack-front", "lackfläche", "lackfront", "lackfronten", "lackierd", "lackieren", "lackiert", "lackierte", "lackierte front", "lackierte fronten", "lackierten", "lackierung", "lackiret", "lackirt", "lackmuster", "lackoberflaeche", "lackoberfläche", "lackton", "lacquer", "lakiert", "matt lackiert", "mdf lackiert", "ncs lackiert", "ral lackiert", "seidenmatt lackiert", "stumpfmatt lackiert"]),
        Entry(canonical: "hochglanzlack", category: "lacquer", emit: "lack", surfaces: ["glanzlack", "glänzend", "hochglaenzend", "hochglanz", "hochglanz lackiert", "hochglanz-front", "hochglanzd", "hochglanzfront", "hochglanzfronten", "hochglanzlack", "hochglanzlackiert", "hochglanzlak", "hochglanzoberfläche", "hochglanzt", "hochglnz", "hochglänzend", "in hochglanz", "klavierlack", "klavierlackfront", "klavierlackiert", "klavierlak", "perfectsense gloss", "pianolack"]),
        Entry(canonical: "seidenmatt", category: "lacquer", emit: "lack", surfaces: ["in seidenmatt", "satiniert", "seidemmatt", "seidenglanz", "seidenmat", "seidenmatd", "seidenmatt", "seidenmatt geölt", "seidenmatt lackiert", "seidenmatt-front", "seidenmatte fronten", "seidenmatte oberfläche", "seidenmattfront", "seidenmmatt"]),
        Entry(canonical: "matt", category: "lacquer", emit: "lack", surfaces: ["anti-fingerprint matt", "fenix matt", "in matt", "kanten matt", "mat lackiert", "mathlack", "matlack", "matt", "matt lackiert", "matt pulverbeschichtet", "matte front", "matte fronten", "mattfront", "mattfronten", "mattlack", "mattlackiert", "mattoberfläche", "mattt", "perfectsense matt", "stumpfmat", "stumpfmatd", "stumpfmatt", "stumpfmatt lackiert", "super-matt", "supermat", "supermatt", "supermatt lackiert", "tiefmatt", "ultramatt"]),
        Entry(canonical: "pulverbeschichtet", category: "lacquer", emit: "lack", surfaces: ["alu pulverbeschichtet", "aluminium pulverbeschichtet", "aluminiumteile pulverbeschichtet", "edelstahl pulverbeschichtet", "frontmaterial pulverbeschichtet", "matt pulverbeschichtet", "pulferbeschichtet", "pulverbeschichte", "pulverbeschichtet", "pulverbeschichtet matt", "pulverbeschichtete front", "pulverbeschichtete fronten", "pulverbeschichtung", "pulverbeschihten", "pulverbeschihtet", "pulverbeschtichtet", "pulverlack", "pulverlackiert", "stahl pulverbeschichtet", "stahlfronten pulverbeschichtet"]),
        Entry(canonical: "naturholzeffektlack", category: "lacquer", emit: "lack", surfaces: ["holzeffektlack", "in naturholzeffektlack", "naturholz-effektlack", "naturholzefektlack", "naturholzeffeklack", "naturholzeffekt lack", "naturholzeffekt lackiert", "naturholzeffektlack", "naturholzeffektlack front", "naturholzeffektlackiert", "naturholzeffektlak"]),
        Entry(canonical: "öl", category: "lacquer", emit: "oel", surfaces: ["fingerzinken geölt", "geoelt", "geolt", "geöllt", "geölt", "geölt herstellen", "geölte front", "geölte fronten", "geölten", "gölt", "kanten geölt", "klar geölt", "matt geölt", "mdf geölt", "natur geölt", "oberfläche geölt", "oel", "oeoelt", "schwarz geölt", "seidenmatt geölt", "öl", "öl-finish", "öller"]),
        Entry(canonical: "hartwachsöl", category: "lacquer", emit: "oel", surfaces: ["hartwachs", "hartwachs-öl", "hartwachsoel", "hartwachsöel", "hartwachsöl", "hartwachsöl behandelt", "hartwachsölfinish", "hartwaxoel", "hartwaxöl", "hartöl", "mit hartwachsöl", "monocoat", "osmo", "osmo geölt", "osmo hartwachsöl", "osmoo", "rubio", "rubio monocoat", "wachsöl"]),
        Entry(canonical: "gewachst", category: "lacquer", emit: "oel", surfaces: ["bienenwachs", "gewachsd", "gewachst", "gewachste front", "gewachste fronten", "gewachste oberfläche", "gewaxed", "gewaxst", "gewaxt", "mit wachs", "natur gewachst", "naturwachs", "wachs", "wachsfinish", "wachsoberfläche"]),
        Entry(canonical: "naturöl", category: "lacquer", emit: "oel", surfaces: ["holzoel", "holzöl", "leinoel", "leinöel", "leinöl", "mit naturöl", "natur geölt", "natur-öl", "naturoel", "naturöel", "naturöl", "naturöl behandelt", "naturöl finish", "naturölfinish", "naturöll", "pflanzenöl"]),
        Entry(canonical: "lasur", category: "lacquer", emit: "oel", surfaces: ["farbig lasiert", "farblasur", "getönt lasiert", "holzlasur", "lasierd", "lasieren", "lasiert", "lasierte front", "lasierte fronten", "lasierte oberfläche", "lasirt", "lassur", "lasuhr", "lasur", "lasurfinish", "laziert", "mit lasur"]),
        Entry(canonical: "farblos", category: "lacquer", emit: nil, surfaces: ["farblos", "farblos lackiert", "farblose lackierung", "farbloss", "farbloß", "klar", "klar geölt", "klar lackierd", "klar lackiert", "klar matt", "klar matt lackiert", "klarlack", "klarlak", "natur lackierd", "natur lackiert", "transparent"]),
        Entry(canonical: "deckend", category: "lacquer", emit: nil, surfaces: ["deckend", "deckend lackierd", "deckend lackiert", "deckend lackierte fronten", "deckende front", "deckende lackierung", "deckent", "dekend", "dekend lackierd", "ncs lackiert", "ral lackiert", "uni-farbe", "vollton"]),
    ] }

    private static func naturalStoneEntries() -> [Entry] { [
        Entry(canonical: "naturstein", category: "natural_stone", emit: "stein", surfaces: ["echter stein", "echtstein", "natur stein", "naturstain", "naturstei", "naturstein", "naturstein-apl", "naturstein-fronten", "naturstein-platte", "natursteine", "natursteinen", "natursteinplatte", "natursteinplatten", "naturstien", "naturwerkstein"]),
        Entry(canonical: "marmor", category: "natural_stone", emit: "stein", surfaces: ["echter marmor", "mamor", "marble", "marmar", "marmer", "marmor", "marmor-apl", "marmor-arbeitsplatte", "marmore", "marmoren", "marmorfensterbank", "marmorplatte", "marmorplatten", "marmr"]),
        Entry(canonical: "granit", category: "natural_stone", emit: "stein", surfaces: ["granit", "granit-apl", "granitarbeitsplatte", "granite", "graniten", "granitfensterbank", "granitplatte", "granitplatten", "granitt", "grannit", "granti", "hartgranit"]),
        Entry(canonical: "quarzit", category: "natural_stone", emit: "quarzit", surfaces: ["kwarzit", "naturquarzit", "quarcit", "quarsit", "quartzit", "quartzite", "quarzit", "quarzit-apl", "quarzit-arbeitsplatte", "quarzite", "quarziten", "quarzitplatte", "quarzitplatten", "quarzitt"]),
        Entry(canonical: "quarz", category: "mineral_surface", emit: "quarz", surfaces: ["engineered quartz", "kwarz", "quars", "quartz", "quarz", "quarz komposit", "quarz-apl", "quarz-arbeitsplatte", "quarz-komposit", "quarze", "quarzkomposit", "quarzkompositplatte", "quarzplatte", "quarzplatten", "quarzstein", "quarzwerkstoff", "quarzz"]),
        Entry(canonical: "hartgestein", category: "natural_stone", emit: "hartgestein", surfaces: ["hart gestein", "hartgestain", "hartgesteim", "hartgestein", "hartgestein-apl", "hartgesteine", "hartgesteinen", "hartgesteinplatte", "hartstein"]),
        Entry(canonical: "taj mahal", category: "natural_stone", emit: "stein", surfaces: ["taj mahal", "taj mahal platte", "taj mahal quartzite", "taj mahal quarzit", "taj mahel", "taj mahl", "taj-mahal", "taj-mahal-apl", "tajmahal", "tay mahal"]),
        Entry(canonical: "nero marquina", category: "natural_stone", emit: "nero marquina", surfaces: ["marquina", "negro marquina", "nero markina", "nero marqina", "nero marquena", "nero marquina", "nero marquina marmor", "nero marquina platte", "nero marquinha", "nero-marquina-apl", "neromarquina"]),
        Entry(canonical: "basalt", category: "natural_stone", emit: "basalt", surfaces: ["basallt", "basalt", "basalt-apl", "basalte", "basalten", "basalth", "basaltplatte", "basaltstein", "basanit", "basart", "basat"]),
        Entry(canonical: "schiefer", category: "natural_stone", emit: "schiefer", surfaces: ["naturschiefer", "schiefer", "schiefer-apl", "schieferfliesen", "schieferplatte", "schieferstein", "schieffer", "schifer", "schiffer", "shiefer", "slate"]),
        Entry(canonical: "kalkstein", category: "natural_stone", emit: "kalkstein", surfaces: ["jura kalkstein", "jurakalk", "kalk stein", "kalkstain", "kalkstein", "kalkstein-apl", "kalksteine", "kalksteinplatte", "kalkstien", "kallkstein", "kalstein", "limestone"]),
        Entry(canonical: "travertin", category: "natural_stone", emit: "travertin", surfaces: ["tarvertin", "traventin", "travertien", "travertin", "travertin-apl", "travertine", "travertinn", "travertinplatte", "travertinstein", "trevertin"]),
        Entry(canonical: "onyx", category: "natural_stone", emit: "onyx", surfaces: ["naturonyx", "ohnyx", "onix", "onyks", "onyx", "onyx marmor", "onyx-apl", "onyx-platte", "onyxplatte", "onyxx"]),
    ] }

    private static func mineralSurfaceEntries() -> [Entry] { [
        Entry(canonical: "silestone", category: "mineral_surface", emit: "quarz", surfaces: ["cosentino silestone", "sileston", "silestone", "silestone quarz", "silestone-apl", "silestone-arbeitsplatte", "silestoneplatte", "silestonne", "sillestone", "silstone"]),
        Entry(canonical: "caesarstone", category: "mineral_surface", emit: "quarz", surfaces: ["caesar stone", "caesarstone", "caesarstone quarz", "caesarstone-apl", "caesarstoneplatte", "caeserstone", "ceasarstone", "ceaserstone", "cesar stone", "cesarstone"]),
        Entry(canonical: "dekton", category: "mineral_surface", emit: "dekton", surfaces: ["cosentino dekton", "dakton", "deckton", "decton", "dekton", "dekton sintered", "dekton ultrakompakt", "dekton-apl", "dekton-arbeitsplatte", "dektonn", "dektonplatte"]),
        Entry(canonical: "neolith", category: "mineral_surface", emit: "neolith", surfaces: ["neoligth", "neolit", "neolith", "neolith keramik", "neolith sintered", "neolith-apl", "neolithh", "neolithplatte", "neolyth"]),
        Entry(canonical: "lapitec", category: "mineral_surface", emit: "lapitec", surfaces: ["lapitec", "lapitec sintered", "lapitec vollsinterstein", "lapitec-apl", "lapitecc", "lapitech", "lapitecplatte", "lapitek"]),
        Entry(canonical: "cosentino", category: "mineral_surface", emit: "cosentino", surfaces: ["consentino", "cosentina", "cosentino", "cosentino-apl", "cosentino-platte", "cossentino"]),
        Entry(canonical: "technistone", category: "mineral_surface", emit: "quarz", surfaces: ["techni stone", "technistne", "techniston", "technistone", "technistone quarz", "technistone-apl", "technistoneplatte", "technstone", "tecnistone"]),
        Entry(canonical: "compac", category: "mineral_surface", emit: "quarz", surfaces: ["compac", "compac quarz", "compac surfaces", "compac-apl", "compacc", "compacplatte", "compak", "compaq", "kompac"]),
        Entry(canonical: "hi-macs", category: "mineral_surface", emit: "hi-macs", surfaces: ["hi macs", "hi-macs", "hi-macs solid surface", "hi-macs-arbeitsplatte", "hi-macs-platte", "hi-max", "highmacs", "himacks", "himacs", "himacs-apl", "himax", "lg hi-macs", "mineralwerkstoff"]),
        Entry(canonical: "corian", category: "mineral_surface", emit: "corian", surfaces: ["corean", "corian", "corian solid surface", "corian-apl", "corian-arbeitsplatte", "corian-becken", "coriann", "corianplatte", "corion", "corjan", "dupont corian", "korian", "mineralwerkstoff corian"]),
        Entry(canonical: "varicor", category: "mineral_surface", emit: "varicor", surfaces: ["vaicor", "vari cor", "varicor", "varicor mineralwerkstoff", "varicor-apl", "varicore", "varicorplatte", "varikor", "varricor"]),
        Entry(canonical: "hanex", category: "mineral_surface", emit: "hanex", surfaces: ["hanecks", "haneks", "hanex", "hanex solid surface", "hanex-apl", "hanexplatte", "hanexx", "hannex"]),
        Entry(canonical: "staron", category: "mineral_surface", emit: "staron", surfaces: ["samsung staron", "staaron", "starohn", "staron", "staron solid surface", "staron-apl", "staronn", "staronplatte", "starron"]),
        Entry(canonical: "keramik", category: "mineral_surface", emit: "keramik", surfaces: ["ceramic", "ceramik", "keramic", "keramick", "keramik", "keramik oberflaeche", "keramik-apl", "keramik-arbeitsplatte", "keramikarbeitsplatte", "keramiken", "keramikfront", "keramikplatte", "keramikplatten", "keramink", "kermaik"]),
        Entry(canonical: "feinsteinzeug", category: "mineral_surface", emit: "keramik", surfaces: ["fein steinzeug", "feinsteinzeig", "feinsteinzeug", "feinsteinzeug platte", "feinsteinzeug-apl", "feinsteinzeugplatte", "feinsteinzeuk", "feinsteinzug", "feinstenzeug", "porcelain"]),
        Entry(canonical: "laminam", category: "mineral_surface", emit: "keramik", surfaces: ["lamiman", "laminam", "laminam keramik", "laminam platte", "laminam-apl", "laminamm", "laminamplatte", "laminan", "laminham"]),
        Entry(canonical: "sintered stone", category: "mineral_surface", emit: "keramik", surfaces: ["gesinterter stein", "sinter stein", "sinter stone", "sintered stein", "sintered stone", "sintered-stone-apl", "sinterstain", "sinterstein", "sinterstein-platte", "sintersteinplatte", "sinterstone"]),
    ] }

    private static func worktopEntries() -> [Entry] { [
        Entry(canonical: "arbeitsplatte", category: "component_worktop", emit: nil, surfaces: ["apl-platte", "arbaitsplatte", "arbeitplatte", "arbeits platte", "arbeitsflaeche", "arbeitsfläche", "arbeitsplate", "arbeitsplatt", "arbeitsplatte", "arbeitsplatten", "arbeitsplatten-", "arbetsplatte", "kuechenarbeitsplatte", "küchenarbeitsplatte", "abdeckplatte", "abdeckung", "ap", "ap.", "apl", "apl.", "arbeitsplat", "arbeitsplatte-", "arbeitsplattenfläche", "arbeitsplattte", "fensterbank", "küchenplatte", "rückwandplatte", "spülenplatte", "steinarbeitsplatte", "steinplatte", "waschtischplatte", "worktop"]),
        Entry(canonical: "apl", category: "component_worktop", emit: nil, surfaces: ["a.p.l.", "abl", "aopl", "ap l", "apl", "apl-naturstein", "apl-platte", "apl.", "apls", "appl", "naturstein-apl", "quarz-apl"]),
        Entry(canonical: "ap", category: "component_worktop", emit: nil, surfaces: ["a p", "a.p.", "ap", "ap-platte", "ap.", "aps"]),
        Entry(canonical: "abdeckplatte", category: "component_worktop", emit: nil, surfaces: ["abdeck platte", "abdeckplate", "abdeckplatte", "abdeckplatten", "abdeckplatten-", "abdeckplattte", "abdeckung platte", "abdekplatte", "apdeckplatte", "stein-abdeckplatte"]),
        Entry(canonical: "abdeckung", category: "component_worktop", emit: nil, surfaces: ["abdeck", "abdeckkung", "abdeckug", "abdeckung", "abdeckungen", "abdeckungs-", "abdekung", "apdeckung", "platten-abdeckung", "stein-abdeckung"]),
        Entry(canonical: "steinplatte", category: "component_worktop", emit: nil, surfaces: ["stainplatte", "stein platte", "stein-platte", "steinabdeckung", "steinarbeitsplatte", "steinplate", "steinplatte", "steinplatten", "steinplatten-apl", "steinplattte", "stienplatte"]),
        Entry(canonical: "waschtischplatte", category: "component_worktop", emit: nil, surfaces: ["waschtisch platte", "waschtisch-platte", "waschtischabdeckung", "waschtischplate", "waschtischplatte", "waschtischplatten", "waschtischplatten-", "waschtischplattte", "waschtisplatte", "wt-platte"]),
        Entry(canonical: "fensterbank", category: "component_worktop", emit: nil, surfaces: ["fenster bank", "fensterbaenke", "fensterbang", "fensterbank", "fensterbank-", "fensterbankabdeckung", "fensterbankk", "fensterbrett", "fensterbänke", "fenstersims", "fenterbank", "innenfensterbank", "stein-fensterbank"]),
        Entry(canonical: "spülenplatte", category: "component_worktop", emit: nil, surfaces: ["spuelen platte", "spuelenabdeckung", "spuelenplate", "spuelenplatte", "spuelenplatten", "spuhlenplatte", "spühlenplatte", "spülen platte", "spülen-platte", "spülenabdeckung", "spülenplate", "spülenplatte", "spülenplatten"]),
        Entry(canonical: "rückwand", category: "component_worktop", emit: nil, surfaces: ["küchenrückwand", "ruckwand", "rueckwaende", "rueckwand", "rueckwant", "rück wand", "rückwand", "rückwand-", "rückwant", "rückwände", "rükwand", "spritzschutz", "stein-rückwand", "wandabschluss", "wandanschluss"]),
        Entry(canonical: "nischenrückwand", category: "component_worktop", emit: nil, surfaces: ["küchennische", "nischen rückwand", "nischen-rückwand", "nischenrueckwaende", "nischenrueckwand", "nischenrueckwant", "nischenrukwand", "nischenrückwand", "nischenrückwant", "nischenrückwände", "nischenwand"]),
    ] }

    private static func metalGlassEntries() -> [Entry] { [
        Entry(canonical: "spiegel", category: "glass", emit: "spiegel", surfaces: ["speigel", "spiegel", "spiegel-apl", "spiegel-rückwand", "spiegelflaeche", "spiegelglas", "spiegell", "spiegelplatte", "spiegl", "spigel", "altspiegel", "antikspiegel", "bronzespiegel", "grauspiegel", "mirror", "rauchspiegel", "rauchspiegelglas", "spegel", "spiegelblende", "spiegelfront", "spiegelfronten", "spiegelrueckwand", "spiegeltuer", "spieggel", "spiehgel"]),
        Entry(canonical: "glas", category: "glass", emit: "glas", surfaces: ["echtglas", "gals", "galss", "glaas", "glaeser", "glas", "glas-apl", "glas-rückwand", "glasfront", "glasplatte", "glasplatten", "glasrückwand", "glass", "lacobel", "esg", "floatglas", "gkas", "glaesern", "glasapl", "glasblende", "glaseinsatz", "glasfronten", "glasrahmen", "glasrueckwand", "glastuer", "glastueren", "glasvitrine", "glasz", "glaß", "klarglas", "sicherheitsglas", "vsg", "weissglas"]),
        Entry(canonical: "edelstahl", category: "metal", emit: "edelstahl", surfaces: ["1.4301", "1.4404", "chromstahl", "cns", "cns-front", "edelstaal", "edelstaehle", "edelstah", "edelstahel", "edelstahl", "edelstahl-apl", "edelstahlapl", "edelstahlblende", "edelstahlfront", "edelstahlfronten", "edelstahlkorpus", "edelstahll", "edelstahloberflaeche", "edelstahlplatte", "edelstahlrahmen", "edelstahlsockel", "edelstal", "edelsthal", "edestahl", "inox", "niro", "nirosta", "rostfrei", "rostfreier stahl", "v 2a", "v2 a", "v2a", "v2a-front", "v4a"]),
        Entry(canonical: "wirbelfinish", category: "metal", emit: "edelstahl", surfaces: ["edelstahl-wirbelfinish", "kreisschliff", "swirl", "swirl-finish", "vibrationsschliff", "wirbel finish", "wirbel-finish", "wirbelfinis", "wirbelfinisch", "wirbelfinish", "wirbelfinish-edelstahl", "wirbelfinnish", "wirbelschlif", "wirbelschliff", "wirbelschliffe", "zirkularschliff"]),
        Entry(canonical: "stahl", category: "metal", emit: "stahl", surfaces: ["baustahl", "blech", "eisen", "roh stahl", "roheisen", "rohstahl", "rohstahlfront", "rohstal", "staehle", "stahel", "stahk", "stahl", "stahlblech", "stahlblende", "stahlfront", "stahlfronten", "stahlgestell", "stahlkorpus", "stahll", "stahlplatte", "stahlrahmen", "stahlsockel", "stal", "sthal"]),
        Entry(canonical: "schwarzstahl", category: "metal", emit: "schwarzstahl", surfaces: ["blackened steel", "bruenierung", "brunierter stahl", "geschwaerzter stahl", "schwartzstahl", "schwarz oxidiert", "schwarz stahl", "schwarzblech", "schwarzer stahl", "schwarzstahl", "schwarzstahl-apl", "schwarzstahlblende", "schwarzstahlfront", "schwarzstahlfronten", "schwarzstahll", "schwarzstahlrahmen", "schwarzstal", "schwarzsthal"]),
        Entry(canonical: "messing", category: "metal", emit: "messing", surfaces: ["altmessing", "brass", "gelbmetall", "mesing", "messig", "messin", "messing", "messing gebuerstet", "messing poliert", "messing-applikation", "messingbeschlag", "messingblech", "messingblende", "messingfront", "messingfronten", "messingg", "messinggriff", "messinggriffe", "messingrahmen", "messingsockel", "messsing", "mässing"]),
        Entry(canonical: "bronze", category: "metal", emit: "bronze", surfaces: ["antikbronze", "brombze", "bronnze", "bronse", "bronz", "bronze", "bronze gebuerstet", "bronze-applikation", "bronzeblech", "bronzeblende", "bronzefarben", "bronzefront", "bronzefronten", "bronzegriff", "bronzegriffe", "bronzerahmen", "broze", "dunkelbronze"]),
        Entry(canonical: "aluminium", category: "metal", emit: "aluminium", surfaces: ["allu", "alluminium", "alu", "alu eloxiert", "alu-dibond", "alublech", "alublende", "aludibond", "alufront", "alufronten", "alugriff", "alugriffe", "aluminim", "aluminium", "aluminiumblech", "aluminiumblende", "aluminiumfront", "aluminiumfronten", "aluminiumrahmen", "aluminiumsockel", "aluminiun", "aluminuim", "aluminum", "alumium", "aluprofil", "alurahmen", "alusockel", "aluverbund", "eloxal", "eloxiert"]),
        Entry(canonical: "kupfer", category: "metal", emit: "kupfer", surfaces: ["copper", "cupfer", "kuper", "kupfa", "kupfer", "kupfer gebuerstet", "kupfer-applikation", "kupferblech", "kupferblende", "kupferfront", "kupferfronten", "kupfergriff", "kupfergriffe", "kupferr", "kupferrahmen", "kupfersockel", "kupffer", "patiniertes kupfer", "rotmetall"]),
        Entry(canonical: "satiniert", category: "glass", emit: "glas", surfaces: ["geaetztes glas", "matt geaetzt", "mattglas", "mattglasfront", "mattglastuer", "milchglas", "milchglasfront", "milchglastuer", "opalglas", "saeuregeaetzt", "sateniert", "satieniert", "satinato", "satinglas", "satinglasfront", "satiniert", "satiniertes glas", "satinniert", "satniert"]),
        Entry(canonical: "lacobel", category: "glass", emit: "glas", surfaces: ["colorglas", "farbglas", "glaslack", "laccobel", "lackglas", "lackglasfront", "lackglasfronten", "lackglasrueckwand", "lackiertes glas", "lacobel", "lacobel-front", "lacobel-glas", "lacobel-rueckwand", "lacobelglas", "lacobell", "lacovel", "lakkobel", "lakobel", "opaque glass", "ruecklackiertes glas"]),
    ] }

    private static func handleHardwareEntries() -> [Entry] { [
        Entry(canonical: "griff", category: "handle", emit: nil, surfaces: ["alugriff", "edelstahlgriff", "edelstahlgriffe", "frontgriff", "giff", "grff", "grfif", "grif", "griff", "griff-set", "griffe", "griffen", "griffleiste", "griffloch", "griffstange", "griffvariante", "griiff", "handgriff", "messinggriff", "moebelgriff", "ziehgriff"]),
        Entry(canonical: "griffleiste", category: "handle", emit: nil, surfaces: ["alu-griffleiste", "c-griff", "c-profil", "edelstahl-griffleiste", "einfraesgriff", "fraesgriff", "grif-leiste", "griffleeste", "griffleist", "griffleiste", "griffleisten", "griffleistenfront", "griffleistte", "griffprofil", "grifleiste", "j-griff", "j-griffleiste", "j-profil", "l-profil", "profilgriff", "profilgriffleiste"]),
        Entry(canonical: "grifflos", category: "handle", emit: nil, surfaces: ["griff-los", "grifffrei", "grifflohs", "grifflos", "grifflosausfuehrung", "grifflose", "grifflose ausfuehrung", "grifflose front", "grifflose fronten", "grifflose kueche", "grifflosen", "griffloses design", "griflos", "grifloss", "handle-less", "ohne griff", "ohne griffe"]),
        Entry(canonical: "push-to-open", category: "handle", emit: nil, surfaces: ["antipp-oeffnung", "antippmechanik", "druck-auf", "druckmechanik", "klick-mechanik", "pto", "ptosystem", "puschtoopen", "push to open", "push-to open", "push-to-open", "push-to-open-front", "push-to-open-mechanik", "pushtoopen", "tip on", "tip-on", "tip-on blumotion", "tip-on-mechanik", "tip-on-system", "tip-onn", "tipon", "tipp-on", "tippon"]),
        Entry(canonical: "muldengriff", category: "handle", emit: nil, surfaces: ["einfraesung", "einlassgriff", "fingerzug", "griffmuhlde", "griffmulde", "griffmulden", "griffschale", "mulde", "mulden-griff", "muldengrif", "muldengriff", "muldengriffe", "muldengrifffront", "muschelgriff", "muschelgriffe", "schalengrif", "schalengriff", "schalengriffe"]),
        Entry(canonical: "stangengriff", category: "handle", emit: nil, surfaces: ["balkengriff", "buegel", "buegel-griff", "buegelgrif", "buegelgriff", "buegelgriffe", "bügelgriff", "edelstahl-stangengriff", "reling", "relinggriff", "relinggriffe", "rohrgriff", "rohrgriffe", "stange", "stangen-griff", "stangengrif", "stangengriff", "stangengriffe", "u-griff"]),
        Entry(canonical: "knopf", category: "handle", emit: nil, surfaces: ["knaeufe", "knauf", "knaufe", "knaufgrif", "knaufgriff", "knaufgriffe", "knoepfe", "knopf", "knopff", "knopfgrif", "knopfgriff", "knopfgriffe", "knpf", "kugelgriff", "messingknoepfe", "messingknopf", "moebelknauf", "moebelknoepfe", "moebelknopf", "pilzgriff", "punktgriff"]),
        Entry(canonical: "legrabox", category: "fitting", emit: "legrabox", surfaces: ["antaro", "blum legrabox", "innenauszug legrabox", "legarbox", "legarobox", "legra box", "legrabbox", "legrabocks", "legrabos", "legrabox", "legrabox blum", "legrabox-auszug", "legrabox-schubkasten", "legrabox-set", "legrabox-zarge", "legraboxen", "legrobox", "lergabox", "metabox", "schubkastensystem legrabox", "tandembox"]),
        Entry(canonical: "blum", category: "fitting", emit: nil, surfaces: ["blhum", "blum", "blum beschlaege", "blum beschlag", "blum-auszug", "blum-band", "blum-beschlaege", "blum-beschlag", "blum-scharnier", "blum-scharniere", "blum-system", "blumm", "blumotion", "blump", "blun", "clip top", "fa. blum"]),
        Entry(canonical: "hettich", category: "fitting", emit: nil, surfaces: ["actro", "atira", "hetich", "hettic", "hettich", "hettich beschlaege", "hettich beschlag", "hettich-auszug", "hettich-band", "hettich-beschlaege", "hettich-beschlag", "hettich-scharnier", "hettich-scharniere", "hettichh", "hettig", "hettisch", "hetttich", "innotech", "intermat", "quadro", "sensys"]),
        Entry(canonical: "grass", category: "fitting", emit: nil, surfaces: ["dynapro", "gras", "grass", "grass beschlaege", "grass beschlag", "grass-auszug", "grass-band", "grass-beschlaege", "grass-beschlag", "grass-scharnier", "grass-scharniere", "grass-system", "grasss", "grasz", "graß", "grras", "nova pro", "tiomos"]),
        Entry(canonical: "scharnier", category: "fitting", emit: nil, surfaces: ["blum-scharnier", "clip-scharnier", "eckscharnier", "mittelscharnier", "moebelscharnier", "schanier", "scharner", "scharnie", "scharnier", "scharnierband", "scharniere", "scharnieren", "scharnierr", "scharnir", "scharnnier", "topfbaender", "topfband", "topfbant", "topfscharnier", "topfscharniere", "tuerscharnier"]),
        Entry(canonical: "auszug", category: "fitting", emit: "legrabox", surfaces: ["ausszug", "auszg", "auszuege", "auszug", "auszuge", "auszugsfuehrung", "auszugsfuehrungen", "auszugssystem", "auzug", "fuehrung", "innenauszuege", "innenauszug", "schubkastenfuehrung", "teilauszuege", "teilauszug", "teilauszuge", "teleskopauszug", "unterflurfuehrung", "vollauszuege", "vollauszug", "vollauszuge", "vollauszüge"]),
        Entry(canonical: "schubkasten", category: "fitting", emit: nil, surfaces: ["auszugkasten", "innenschubkasten", "innenschubladen", "lade", "laden", "schub", "schubkaesten", "schubkasen", "schubkasstn", "schubkasten", "schubkastenset", "schubkastenzarge", "schubkstn", "schublade", "schubladee", "schubladen", "schublde", "ausug", "auszug", "auszüge", "schubkaste", "schubkasten-", "schubkästen", "schubladenelement", "schubladenfront", "schubladn", "schupkasten", "vollauszug"]),
        Entry(canonical: "soft-close", category: "fitting", emit: nil, surfaces: ["blumotion", "daempfung", "daempfungen", "daempfungssystem", "dämpfung", "einzugsdaempfung", "gedaempft", "gedaempfte", "schliessdaempfung", "selbsteinzug", "self-close", "soft close", "soft-clos", "soft-close", "soft-close-daempfer", "soft-close-system", "softclos", "softclose", "softcloseing"]),
        Entry(canonical: "klappenbeschlag", category: "fitting", emit: nil, surfaces: ["aventos", "aventos-beschlag", "aventoss", "avventos", "free flap", "hochklappbeschlag", "klapenbeschlag", "klappen-beschlag", "klappenbeschlaege", "klappenbeschlag", "klappenbeschlag-set", "klappenbschlag", "klappenhalter", "klappenlift", "klappenstuetze", "kraftband", "lifttechnik", "oberschrankklappe"]),
        Entry(canonical: "servo-drive", category: "fitting", emit: nil, surfaces: ["e-drive", "elektrische oeffnung", "elektroauszug", "elektrooeffnung", "servo drive", "servo-antrieb", "servo-drife", "servo-drive", "servo-drive-auszug", "servo-drive-system", "servo-driwe", "servodriev", "servodrive", "servodrive-set", "servodriwe", "tip-on blumotion"]),
        Entry(canonical: "korpusverbinder", category: "fitting", emit: nil, surfaces: ["exenter", "exzenter", "exzenterverbinder", "exzentr", "korpus-verbinder", "korpusverbinder", "korpusverbinder-set", "korpusverbindr", "korpusverbnder", "moebelverbinder", "rastecks", "rastex", "schrankverbinder", "topfverbinder", "vb-beschlag", "verbinder"]),
    ] }

    private static func componentEntries() -> [Entry] { [
        Entry(canonical: "korpus", category: "component_base_unit", emit: nil, surfaces: ["body", "kopien", "korpen", "korpi", "korpie", "korpius", "korpos", "korpus", "korpus-", "korpusausführung", "korpusfront", "korpuskörper", "korpusmaterial", "korpuss", "korpusse", "korups", "kropus", "möbelkorpus", "schrankkorpus", "schrankkörper"]),
        Entry(canonical: "schrank", category: "component_base_unit", emit: nil, surfaces: ["body", "cabinet", "einbauschrank", "element", "möbel", "schraenke", "schrak", "schrank", "schrank-", "schrankblock", "schrankkorpus", "schrankwand", "schrnak", "schränke", "schänke", "wandschrank"]),
        Entry(canonical: "möbel", category: "component_base_unit", emit: nil, surfaces: ["einbaumöbel", "element", "korpusmöbel", "mobel", "moebel", "möbel", "möbel-", "möbelelement", "möbelkorpus", "möbelstück", "möbl"]),
        Entry(canonical: "element", category: "component_base_unit", emit: nil, surfaces: ["bauteil", "einbauelement", "element", "element-", "elemente", "elemnt", "elemt", "elment", "korpuselement", "modul", "möbelelement", "schrankelement"]),
        Entry(canonical: "unterschrank", category: "component_base_unit", emit: nil, surfaces: ["60er-unterschrank", "basisschrank", "eckschrank", "herdschrank", "spülenschrank", "spülenunterschrank", "unterbau", "unterbauschrank", "unterschank", "unterschrak", "unterschrank", "unterschrank-", "unterschrankzeile", "unterschränke", "untershrank", "untrschrank", "us", "us-schrank"]),
        Entry(canonical: "oberschrank", category: "component_base_unit", emit: nil, surfaces: ["haengeschrank", "hängeschrank", "hängeschrank-", "hängeschränke", "hängeshrank", "oberschank", "oberschrank", "oberschrank-", "oberschrankzeile", "oberschränke", "obershrank", "os", "os-schrank", "wandschrank"]),
        Entry(canonical: "hochschrank", category: "component_tall", emit: nil, surfaces: ["apothekerschrank", "einbauschrank", "einbauschränke", "geraeteschrank", "geräteschrank", "geräteschränke", "hochschank", "hochschraenke", "hochschrak", "hochschrank", "hochschrank-", "hochschrankblock", "hochschrankzeile", "hochschränke", "hochshrank", "schrankblock", "schrankwand", "treppenschrank", "treppenschränke", "vollauszugschrank", "vorratschrank", "vorratsschrank", "vorratsschränke"]),
        Entry(canonical: "küchenzeile", category: "component_kitchen_run", emit: nil, surfaces: ["kuchenzeile", "kuechenzeile", "küchenreihe", "küchenzeie", "küchenzeile", "küchenzeile-", "küchenzeilen", "küchenzeule", "pantry", "rückzeile", "spuelenzeile", "spülenzeile", "unterschrankzeile", "wandseite", "wandzeile", "zeile"]),
        Entry(canonical: "insel", category: "component_island", emit: nil, surfaces: ["insel", "insel-", "inselblock", "inseln", "insl", "kochblock", "kochinsel", "kochinsl", "kuecheninsel", "kücheblock", "küchenblock", "küchenblok", "küchenbock", "kücheninsel", "kücheninsl", "mittelblock"]),
        Entry(canonical: "gesamtküche", category: "component_aggregate", emit: nil, surfaces: ["einbaukueche", "einbauküche", "einbauküchen", "gesammtküche", "gesamtkueche", "gesamtküche", "gesamtküche-", "gesamtleistung küche", "komplettküche", "küche gemäß", "küche gesamt", "küche komlett", "küche komplett", "küche nach", "küche per", "küchenarbeiten", "projekt küche"]),
        Entry(canonical: "lieferung", category: "component_logistics", emit: nil, surfaces: ["anfahrt", "anlieferng", "anlieferung", "auf- und abladen", "aufmas", "aufmass", "aufmaß", "aufmaßkosten", "fahrt", "handling", "lieferkosten", "lieferng", "lieferung", "lieferung und montage", "lieferung-", "lieferungen", "liferung", "montaage", "montage", "montagekosten", "montagge", "projektlogistik", "transport", "transportkosten", "transprt", "verpackung", "übernachtung"]),
        Entry(canonical: "regal", category: "component_base_unit", emit: nil, surfaces: ["einlegeboden", "fachboden", "offenes regal", "ragal", "reagl", "regal", "regal-", "regalboden", "regale", "regalelement", "regl", "wandregal"]),
        Entry(canonical: "vitrine", category: "component_base_unit", emit: nil, surfaces: ["glaselement", "glasvitrine", "highboard", "kommode", "lowboard", "sideboard", "vitirne", "vitriene", "vitrine", "vitrine-", "vitrinen", "vitrinenschrank", "vitrne"]),
    ] }

    private static func unitEntries() -> [Entry] { [
        Entry(canonical: "laufmeter", category: "unit", emit: nil, surfaces: ["9lfm", "laufende meter", "laufender meter", "laufmeer", "laufmeeter", "laufmeter", "laufmeter.", "laufmetern", "laufmetr", "lfd m", "lfd. m", "lfd.m", "lfdm", "lfdm.", "lfm", "lfm-preis", "lfm.", "lm", "running meter"]),
        Entry(canonical: "meter", category: "unit", emit: nil, surfaces: ["laufmeter", "lfd. m", "lfdm", "m.", "meeter", "meter", "metern", "metr", "quadratmeter"]),
        Entry(canonical: "zentimeter", category: "unit", emit: nil, surfaces: ["60cm", "60er", "80cm", "cm", "cm.", "zentimeter", "zentimter", "ztm"]),
        Entry(canonical: "millimeter", category: "unit", emit: nil, surfaces: ["18mm", "19mm", "millimeter", "millimter", "mm", "mm."]),
        Entry(canonical: "quadratmeter", category: "unit", emit: nil, surfaces: ["m2", "m2-preis", "m2.", "qm", "qm.", "quadratmeer", "quadratmeter", "quadratmetern", "quadratmter", "quadtratmeter", "sqm"]),
        Entry(canonical: "stück", category: "unit", emit: nil, surfaces: ["1stk", "anzahl", "each", "pos", "position", "pro stück", "stck", "stk", "stk.", "stueck", "stüc", "stück", "stücke", "stükc"]),
        Entry(canonical: "paar", category: "unit", emit: nil, surfaces: ["1paar", "paar", "paar.", "paare", "par", "pro paar", "pärchen", "satz", "set"]),
        Entry(canonical: "pauschal", category: "unit", emit: nil, surfaces: ["festpreis", "pausch", "pauschal", "pauschalbetrag", "pauschale", "pauschalpreis", "pauschl", "pauschla", "psch", "psch.", "pschl"]),
        Entry(canonical: "fenix", category: "mineral_surface", emit: "fenix", surfaces: ["fenix", "fenix nano", "fenix ntm", "fenix-platte", "fenixplatte"]),
        Entry(canonical: "valchromat", category: "mineral_surface", emit: "valchromat", surfaces: ["durchgefaerbt", "durchgefärbt", "valchromat", "valchromat-platte", "valchromatplatte"]),
    ] }

    private func isBoundary(_ chars: [Character], _ pos: Int) -> Bool {
        if pos < 0 || pos >= chars.count { return true }
        return !MaterialLexicon.wordChars.contains(chars[pos])
    }

    private func match(_ pattern: [Character], in chars: [Character], consumed: [Bool], boundary: Bool) -> Range<Int>? {
        let n = chars.count, m = pattern.count
        if m == 0 || m > n { return nil }
        var i = 0
        while i <= n - m {
            var ok = true
            var k = 0
            while k < m {
                if consumed[i + k] || chars[i + k] != pattern[k] { ok = false; break }
                k += 1
            }
            if ok && boundary {
                if !isBoundary(chars, i - 1) || !isBoundary(chars, i + m) { ok = false }
            }
            if ok { return i ..< (i + m) }
            i += 1
        }
        return nil
    }

    func hits(in rawText: String) -> [Hit] {
        var text = rawText.lowercased()
        for (a, b) in MaterialLexicon.rewrites { text = text.replacingOccurrences(of: a, with: b) }
        let chars = Array(text)
        var consumed = [Bool](repeating: false, count: chars.count)
        var hits: [Hit] = []
        var seen = Set<String>()
        for item in index {
            if let range = match(item.surface, in: chars, consumed: consumed, boundary: item.boundary) {
                for j in range { consumed[j] = true }
                let entry = entries[item.entry]
                let key = entry.canonical + "|" + entry.category
                if !seen.contains(key) {
                    seen.insert(key)
                    hits.append(Hit(canonical: entry.canonical, category: entry.category, emit: entry.emit))
                }
            }
        }
        return hits
    }

    func materialCanonicals(in text: String) -> Set<String> {
        var set = Set<String>()
        for hit in hits(in: text) { if let emit = hit.emit { set.insert(emit) } }
        return set
    }

    func mentionsWorktopSurface(in text: String) -> Bool {
        let categories = Set(hits(in: text).map { $0.category })
        return categories.contains("component_worktop") || categories.contains("natural_stone") || categories.contains("mineral_surface")
    }
}
