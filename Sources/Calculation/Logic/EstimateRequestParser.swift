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
